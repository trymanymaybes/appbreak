// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion
import android.test.AndroidTestCase
import org.json.JSONObject
import org.json.JSONArray
@Suppress("DEPRECATION")
class StorageTest: AndroidTestCase() {
    override fun setUp() { super.setUp(); context.deleteDatabase("companion.db") }
    override fun tearDown() { context.deleteDatabase("companion.db"); super.tearDown() }
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
}
