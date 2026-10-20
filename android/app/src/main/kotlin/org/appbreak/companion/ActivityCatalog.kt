// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import android.content.Context
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HttpsURLConnection

/** Public, inert content only. Never reads Store, notes, recordings or device IDs. */
object ActivityCatalog {
    const val URL_TEXT = "https://raw.githubusercontent.com/trymanymaybes/appbreak/main/activity-catalog/catalog.json"
    const val MAX_BYTES = 256 * 1024
    private const val DAY = 86400000L
    private val running = AtomicBoolean(false)
    private fun prefs(c: Context) = c.getSharedPreferences("activity_catalog", Context.MODE_PRIVATE)
    fun enabled(c: Context) = prefs(c).getBoolean("enabled", true)
    @Synchronized fun setEnabled(c: Context, enabled: Boolean) {
        check(prefs(c).edit().putBoolean("enabled", enabled).commit())
    }
    @Synchronized fun clear(c: Context) {
        check(prefs(c).edit().clear().putBoolean("enabled", false).commit())
    }
    fun cached(c: Context): JSONArray { return try {
        validate(prefs(c).getString("body", null) ?: return JSONArray()).getJSONArray("activities")
    } catch (_: Exception) { JSONArray() } }
    fun snapshot(c: Context): String = JSONObject()
        .put("activities", cached(c)).put("enabled", enabled(c))
        .put("status", prefs(c).getString("status", "Built-in activities ready; catalogue not checked yet."))
        .put("lastSuccess", prefs(c).getLong("success", 0)).toString()

    fun validate(body: String): JSONObject {
        require(body.toByteArray(Charsets.UTF_8).size <= MAX_BYTES)
        // Bound nesting before the recursive JSON parser sees untrusted input.
        var depth = 0; var quoted = false; var escape = false
        for (ch in body) {
            if (quoted) { if (escape) escape = false else if (ch == '\\') escape = true else if (ch == '"') quoted = false }
            else when (ch) { '"' -> quoted = true; '{', '[' -> { depth++; require(depth <= 8) }; '}', ']' -> { depth--; require(depth >= 0) } }
        }
        require(depth == 0 && !quoted)
        val pack = JSONObject(body)
        require(pack.keys().asSequence().toSet() == setOf("schemaVersion", "activities"))
        ActivityPacks.validate(pack)
        val keys = setOf("schemaVersion", "id", "title", "category", "language", "estimatedSeconds", "description", "steps", "requiresVisualAttention", "requiresInput", "accessibleAlternatives", "author", "attribution", "contentLicense", "answer", "reflectionQuestion")
        val list = pack.getJSONArray("activities")
        for (i in 0 until list.length()) {
            val a = list.getJSONObject(i)
            require(a.keys().asSequence().all { it in keys })
            require(a.getString("id").startsWith("community."))
            require(a.getString("contentLicense") == "CC-BY-4.0")
            val steps = a.getJSONArray("steps")
            for (j in 0 until steps.length()) {
                val step = steps.getJSONObject(j)
                val allowed = if (step.getString("kind") in listOf("thinking", "silence")) setOf("kind", "seconds") else setOf("kind", "text")
                require(step.keys().asSequence().toSet() == allowed)
            }
        }
        return pack
    }

    /** Worker thread only. Refreshes are independent of session persistence. */
    fun refresh(c: Context, manual: Boolean): String {
        if (!running.compareAndSet(false, true)) return snapshot(c)
        try {
            val p = prefs(c)
            val now = System.currentTimeMillis()
            synchronized(this) {
                if (!enabled(c)) return snapshot(c)
                val last = p.getLong("attempt", 0)
                val next = p.getLong("next", 0)
                // Manual refresh also respects a one-day floor and server cooldown.
                if (last > now || now < p.getLong("retryAfter", 0) || now - last < DAY || (!manual && now < next)) return snapshot(c)
                check(p.edit().putLong("attempt", now).putLong("next", now + DAY).commit())
            }
            var connection: HttpsURLConnection? = null
            try {
                connection = URL(URL_TEXT).openConnection() as HttpsURLConnection
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 8000; connection.readTimeout = 8000
                connection.useCaches = false
                connection.setRequestProperty("Accept-Encoding", "identity")
                connection.setRequestProperty("Accept", "application/json, text/plain")
                connection.setRequestProperty("User-Agent", "AppBreak-Catalog/1")
                val oldBody = p.getString("body", null)
                val hasCache = oldBody != null && runCatching { validate(oldBody) }.isSuccess
                if (hasCache) p.getString("etag", null)?.let { connection.setRequestProperty("If-None-Match", it) }
                val deadline = SystemClock.elapsedRealtime() + 20000
                val status = connection.responseCode
                if (status == 429 || status == 503) {
                    val raw = connection.getHeaderField("Retry-After")
                    val delay = raw?.toLongOrNull()
                    val retryAt = if (delay != null) now + delay.coerceIn(0L, 30L * 86400) * 1000 else connection.getHeaderFieldDate("Retry-After", now + DAY)
                    p.edit().putLong("retryAfter", retryAt.coerceIn(now + DAY, now + 30 * DAY)).commit()
                }
                require(status == 200 || (status == 304 && hasCache))
                val edit = p.edit()
                if (status == 200) {
                    require(connection.contentLengthLong <= MAX_BYTES)
                    require(connection.contentEncoding == null || connection.contentEncoding == "identity")
                    val bytes = java.io.ByteArrayOutputStream()
                    connection.inputStream.use { input ->
                        val buffer = ByteArray(4096)
                        while (true) {
                            require(SystemClock.elapsedRealtime() <= deadline)
                            val n = input.read(buffer); if (n == -1) break
                            require(bytes.size() + n <= MAX_BYTES)
                            bytes.write(buffer, 0, n)
                        }
                    }
                    val body = bytes.toByteArray().toString(Charsets.UTF_8)
                    validate(body)
                    edit.putString("body", body)
                    val etag = connection.getHeaderField("ETag")
                    if (etag != null && etag.length <= 256 && etag.all { it.code in 32..126 }) edit.putString("etag", etag) else edit.remove("etag")
                }
                synchronized(this) {
                    // Turning updates off during a download discards its result.
                    if (enabled(c)) check(edit.putLong("success", now).putLong("retryAfter", 0)
                        .putLong("next", now + 7 * DAY + java.util.Random().nextInt(86400000))
                        .putString("status", "Catalogue checked. Cached activities are available offline.").commit())
                }
            } catch (_: Exception) {
                p.edit().putString("status", "Could not update catalogue. Existing activities remain available; retry after one day.").commit()
            } finally { connection?.disconnect() }
            return snapshot(c)
        } finally { running.set(false) }
    }
}
