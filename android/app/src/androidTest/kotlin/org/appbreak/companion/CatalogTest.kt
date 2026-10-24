package org.appbreak.companion
import android.test.AndroidTestCase
import org.json.JSONObject
@Suppress("DEPRECATION")
class CatalogTest: AndroidTestCase() {
    private fun sample(): JSONObject {
        val pack=JSONObject(context.assets.open("flutter_assets/assets/activities.json").bufferedReader().use { it.readText() })
        val list=pack.getJSONArray("activities")
        for(i in 0 until list.length()) list.getJSONObject(i).put("id","community."+list.getJSONObject(i).getString("id"))
        return pack
    }
    fun testMediaNeedsAlternativeAndContentVersion() {
        val p=sample();val a=p.getJSONArray("activities").getJSONObject(0)
        a.put("media",org.json.JSONArray().put(JSONObject().put("url","https://example.org/a.png").put("alt","A blue circle").put("fallbackText","Imagine a blue circle")))
        ActivityCatalog.validate(p.toString())
        a.getJSONArray("media").getJSONObject(0).put("alt"," ")
        try { ActivityCatalog.validate(p.toString());fail("Accepted blank alt") } catch(_:IllegalArgumentException) {}
        a.remove("media");a.put("contentVersion",0)
        try { ActivityCatalog.validate(p.toString());fail("Accepted invalid version") } catch(_:IllegalArgumentException) {}
    }
    fun testLegacyPackWithoutAdditiveMetadataStillWorks() {
        val p=sample();val list=p.getJSONArray("activities")
        for(i in 0 until list.length()) {list.getJSONObject(i).remove("contentVersion");list.getJSONObject(i).remove("source");list.getJSONObject(i).remove("reveal")}
        ActivityCatalog.validate(p.toString())
    }
    fun testValidContent() { ActivityCatalog.validate(sample().toString()) }
    fun testNoBuiltinReplacement() {
        val p=sample();p.getJSONArray("activities").getJSONObject(0).put("id","quiet.soft")
        try { ActivityCatalog.validate(p.toString()); fail("Accepted builtin ID") } catch(_:IllegalArgumentException) {}
    }
    fun testUnknownPayloadRejected() {
        val p=sample();p.getJSONArray("activities").getJSONObject(0).put("url","https://example.com")
        try { ActivityCatalog.validate(p.toString()); fail("Accepted URL field") } catch(_:IllegalArgumentException) {}
    }
    fun testOversizeAndDeepInput() {
        for(body in listOf(" ".repeat(ActivityCatalog.MAX_BYTES+1), "[".repeat(1000))) {
            try { ActivityCatalog.validate(body);fail("Accepted resource exhaustion input") } catch(_:IllegalArgumentException) {}
        }
    }
}
