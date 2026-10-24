// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion
import android.test.AndroidTestCase
import org.json.JSONObject
import org.json.JSONArray
@Suppress("DEPRECATION")
class StorageTest: AndroidTestCase() {
    override fun setUp() { super.setUp(); context.deleteDatabase("companion.db") }
    override fun tearDown() { context.deleteDatabase("companion.db"); super.tearDown() }
    fun testPlannerViewsSurviveBackup() {
        for(view in listOf("calendar","day","list")) {
            Store(context).use { store -> val state=store.read();state.put("schemaVersion",1).put("settings",JSONObject().put("plannerView",view));store.write(state) }
            val backup=Backups.validate(Backups.make(context,false));Backups.restore(context,backup)
            assertEquals(view,Store(context).use{it.read()}.getJSONObject("settings").getString("plannerView"))
        }
    }
    fun testCompareAndSwapRejectsStaleWriter() {
        Store(context).use { store -> val old=store.read(); store.write(JSONObject(old.toString())); try { store.write(old); fail("Accepted stale data") } catch(_:IllegalStateException) {} }
    }
    fun testCorruptedBackupCannotReplaceState() {
        Store(context).use { it.write(JSONObject().put("schemaVersion",1).put("marker","safe")) }
        val bytes=Backups.make(context,false); bytes[bytes.size/2]=(bytes[bytes.size/2].toInt() xor 1).toByte()
        try { Backups.validate(bytes); fail("Accepted corruption") } catch(_:Exception) {}
        assertEquals("safe",Store(context).use { it.read().getString("marker") })
    }
    fun testRoundTripRestoresNotesWithoutRunningSession() {
        val d=JSONObject().put("schemaVersion",1).put("ideas",JSONArray().put(JSONObject().put("id","one").put("title","Test").put("text","Private").put("recording",JSONObject.NULL)))
        Store(context).use { it.write(d) }
        val p=Backups.validate(Backups.make(context,false)); Backups.restore(context,p)
        val restored=Store(context).use { it.read() }; assertEquals("Private",restored.getJSONArray("ideas").getJSONObject(0).getString("text")); assertFalse(restored.has("session"))
    }
    fun testUnknownPackSchemaRejected() {
        try { ActivityPacks.validate(JSONObject().put("schemaVersion",2).put("activities",JSONArray())); fail("Accepted newer schema") } catch(_:Exception) {}
    }
    fun testOversizeBackupRejected() {
        try { Backups.validate(ByteArray(Backups.MAX+1)); fail("Accepted oversized backup") } catch(_:Exception) {}
    }
    fun testBackupRejectsWrongBooleanType() {
        Store(context).use { it.write(JSONObject().put("schemaVersion",1).put("settings",JSONObject().put("quiet","true"))) }
        try { Backups.validate(Backups.make(context,false)); fail("Coerced string to boolean") } catch(_:Exception) {}
    }
    fun testBackupRejectsWrongArrayType() {
        Store(context).use { it.write(JSONObject().put("schemaVersion",1).put("history",JSONObject())) }
        try { Backups.validate(Backups.make(context,false)); fail("Accepted object as history") } catch(_:Exception) {}
    }

    fun testBackupDropsRoutineCursors() {
        Store(context).use { it.write(JSONObject().put("schemaVersion",1).put("routineState",JSONObject().put("short",JSONObject().put("phase","presented")))) }
        val p=Backups.validate(Backups.make(context,false));assertFalse(p.getJSONObject("data").has("routineState"))
    }
    fun testBackupRejectsInvalidRoutineThreshold() {
        val profile=JSONObject().put("id","short").put("name","Rest").put("breakSeconds",30).put("selection","rotation").put("categories",JSONArray().put("quiet")).put("resetSeconds",0)
        Store(context).use {it.write(JSONObject().put("schemaVersion",1).put("settings",JSONObject().put("profiles",JSONArray().put(profile))))}
        try {Backups.validate(Backups.make(context,false));fail("Accepted zero reset interval")} catch(_:IllegalArgumentException) {}
    }

    fun testHistoryTimesSurviveBackupAndRejectInvalidOffsets() {
        val record=BreakStats.stamp(JSONObject().put("id","timed").put("date","2026-10-23").put("category","quiet"),1234567L)
        val d=JSONObject().put("schemaVersion",1).put("history",JSONArray().put(record))
        Store(context).use {it.write(d)}
        val restored=Backups.validate(Backups.make(context,false)).getJSONObject("data").getJSONArray("history").getJSONObject(0)
        assertEquals(1234567L,restored.getLong("recordedAt"))
        Store(context).use {val state=it.read();state.getJSONArray("history").getJSONObject(0).put("utcOffsetMinutes",9999);it.write(state)}
        try {Backups.validate(Backups.make(context,false));fail("Accepted invalid offset")} catch(_:IllegalArgumentException) {}
    }
    fun testBundleProvenanceAndPinnedContentSurviveBackup() {
        val a=JSONObject(context.assets.open("flutter_assets/assets/activities.json").bufferedReader().use{it.readText()}).getJSONArray("activities").getJSONObject(0)
        a.put("id","community.backup-test").put("contentVersion",2)
        val p=JSONObject().put("id","bundle-stable").put("name","My reading").put("breakSeconds",60).put("workSeconds",2100).put("selection","rotation").put("categories",JSONArray().put("quiet"))
            .put("enabled",false).put("bundleId","example.reading").put("bundleVersion",2).put("activityIds",JSONArray().put(a.getString("id"))).put("bundleActivityIds",JSONArray().put(a.getString("id")))
        Store(context).use{it.write(JSONObject().put("schemaVersion",1).put("settings",JSONObject().put("profiles",JSONArray().put(p))).put("customActivities",JSONArray().put(a)))}
        val backup=Backups.validate(Backups.make(context,false));Backups.restore(context,backup)
        val restored=Store(context).use{it.read()};val profile=restored.getJSONObject("settings").getJSONArray("profiles").getJSONObject(0)
        assertEquals("bundle-stable",profile.getString("id"));assertEquals(2100,profile.getInt("workSeconds"));assertEquals(2,profile.getInt("bundleVersion"))
        assertEquals(2,restored.getJSONArray("customActivities").getJSONObject(0).getInt("contentVersion"))
    }
}
