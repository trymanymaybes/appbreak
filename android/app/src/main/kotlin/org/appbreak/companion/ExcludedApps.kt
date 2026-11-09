package org.appbreak.companion

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import org.json.JSONObject

/** Only user-selected exclusions persist; observed app usage is never stored. */
object ExcludedApps {
    fun installed(c: Context): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return c.packageManager.queryIntentActivities(intent, 0)
            .filter { it.activityInfo.packageName != c.packageName }
            .map { mapOf("package" to it.activityInfo.packageName, "label" to it.loadLabel(c.packageManager).toString()) }
            .distinctBy { it["package"] }.sortedBy { it["label"]?.lowercase() }
    }

    fun suppressPopup(c: Context, settings: JSONObject): Boolean {
        val entries = settings.optJSONArray("excludedApps") ?: return false
        val excluded = (0 until entries.length()).map { entries.optString(it) }.filter { it.isNotBlank() }.toSet()
        if (excluded.isEmpty()) return false
        if (!ScreenTime.granted(c)) return true
        return try {
            val now = System.currentTimeMillis()
            val events = c.getSystemService(UsageStatsManager::class.java).queryEvents(now - 86400000L, now)
            val event = UsageEvents.Event()
            var current: String? = null
            while (events != null && events.hasNextEvent()) {
                events.getNextEvent(event)
                // ACTIVITY_RESUMED / MOVE_TO_FOREGROUND have the same value (1).
                if (event.eventType == 1) current = event.packageName
                if (event.eventType == 26) current = null // device shutdown
            }
            PopupPolicy.excluded(current, excluded)
        } catch (_: Exception) { true }
    }
}
