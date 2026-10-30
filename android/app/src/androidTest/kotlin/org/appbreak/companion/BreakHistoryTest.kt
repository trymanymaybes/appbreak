package org.appbreak.companion
import android.test.AndroidTestCase
import org.json.JSONObject
import org.json.JSONArray

@Suppress("DEPRECATION")
class BreakHistoryTest: AndroidTestCase() {
    override fun setUp() { super.setUp(); context.deleteDatabase("companion.db") }
    override fun tearDown() { context.deleteDatabase("companion.db"); super.tearDown() }
    private fun seed(remaining:Long) {
        val profile=JSONObject().put("id","a").put("trigger","manual").put("enabled",true).put("workSeconds",600)
        val session=JSONObject().put("id","old").put("routineId","a").put("phase","pending")
            .put("boot",-1).put("wallDue",System.currentTimeMillis()+remaining).put("activity","quiet.soft")
        Store(context).use { it.write(JSONObject().put("schemaVersion",1).put("session",session)
            .put("settings",JSONObject().put("profiles",JSONArray().put(profile)))
            .put("routineState",JSONObject().put("a",JSONObject().put("phase","presented")))) }
    }
    fun testUnfinishedBreakStillOwnsSlot() {
        seed(600000); Routines.refresh(context)
        val d=Store(context).use { it.read() }
        assertFalse(d.has("missedBreaks"))
        assertEquals("presented",d.getJSONObject("routineState").getJSONObject("a").getString("phase"))
    }
    fun testExpiredBreakWaitsForBoundedRecoveryInsteadOfDisappearing() {
        seed(-1000); Routines.refresh(context)
        val first=Store(context).use { it.read() }
        assertFalse(first.has("missedBreaks"))
        assertEquals("old",first.getJSONObject("session").getString("id"))
        assertEquals("presented",first.getJSONObject("routineState").getJSONObject("a").getString("phase"))
        // The recovery tests exercise archive/reset after the third response window.
        Routines.refresh(context)
        assertFalse(Store(context).use { it.read() }.has("history"))
    }
}
