package org.appbreak.companion
import android.test.AndroidTestCase
import org.json.*
@Suppress("DEPRECATION")
class BreakOutcomeTest:AndroidTestCase(){
 fun testSkipCountsDeduplicateAndSeparateMissed(){
  val d=JSONObject().put("history",JSONArray().put(JSONObject().put("id","done")))
  val rows=JSONArray();for(id in listOf("one","one","done"))rows.put(JSONObject().put("id",id).put("category","imagination").put("reason","skipped").put("date","2026-10-23"))
  rows.put(JSONObject().put("id","missed").put("reason","unconfirmed").put("date","2026-10-23"));d.put("missedBreaks",rows)
  assertEquals(1,BreakStats.skipped(d,"imagination","2026-10-23"));assertEquals(0,BreakStats.skipped(d,"movement","2026-10-23"))
 }
 fun testCueKeySurvivesRecreationAndActivitySwitch(){val d=JSONObject();val s=JSONObject().put("id","one").put("phase","rest");assertEquals("start",BreakCues.transition(d,null,s));val restored=JSONObject(d.toString());s.put("activity","new");assertNull(BreakCues.transition(restored,s,s));assertTrue(BreakCues.prepare(restored,s,"end"));assertFalse(BreakCues.prepare(restored,s,"end"))}
 fun testPlanRecurrenceDoesNotStartBeforeFirstDate(){val p=JSONObject().put("date","2026-10-23").put("days",JSONArray().put(5));assertFalse(Planner.occurs(p,"2026-10-16",5));assertTrue(Planner.occurs(p,"2026-10-23",5));assertFalse(Planner.occurs(p,"2026-10-24",6))}
 fun testIdeaCardProducesPng(){val bytes=IdeaCard.render("Challenge 01","My own idea");assertTrue(bytes.size>8);assertEquals(137,bytes[0].toInt() and 255)}
}
