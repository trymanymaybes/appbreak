// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion
import android.test.AndroidTestCase
import android.content.Intent
import android.os.SystemClock
import org.json.*
@Suppress("DEPRECATION")
class ReminderRecoveryTest:AndroidTestCase() {
    override fun setUp() {super.setUp();context.deleteDatabase("companion.db");ReminderHealth.clear(context);context.getSharedPreferences("reminder_alarm",0).edit().clear().commit()}
    override fun tearDown() {Store(context).use {it.write(JSONObject(),true)};Reminders.schedule(context);ReminderHealth.clear(context);context.deleteDatabase("companion.db");super.tearDown()}
    private fun session()=JSONObject().put("id","test").put("routineId","r").put("phase","due").put("wallDue",System.currentTimeMillis()).put("elapsedDue",SystemClock.elapsedRealtime()).put("boot",Reminders.boot(context))
    private fun save(s:JSONObject) {Store(context).use {val d=it.read();d.put("session",s).put("settings",JSONObject().put("profiles",JSONArray().put(JSONObject().put("id","r").put("enabled",true).put("trigger","manual").put("repeat",true).put("workSeconds",120))));it.write(d)}}
    fun testPopupAndNotificationAreOneAttemptAfterReload() {
        val s=session();ReminderHealth.record(context,s,"one",true)
        ReminderHealth.record(context,JSONObject(s.toString()),"one",false,true)
        val e=ReminderHealth.entry(ReminderHealth.read(context),s)
        assertEquals(1,e.getInt("unanswered"));assertTrue(e.has("lastPopupAt"));assertTrue(e.has("lastNotificationAt"))
        ReminderHealth.response(context,s);assertEquals(0,ReminderHealth.entry(ReminderHealth.read(context),s).getInt("unanswered"))
    }
    fun testFailedDeliveryDoesNotCountAsUnanswered() {
        val s=session();ReminderHealth.record(context,s,"failed",false)
        val e=ReminderHealth.entry(ReminderHealth.read(context),s)
        assertEquals(0,e.optInt("unanswered"));assertEquals(1,e.getInt("failedAttempts"));assertFalse(e.has("lastNotificationAt"))
    }
    fun testClockChangeAndRebootDoNotCreateRetryBurst() {
        val e=JSONObject().put("lastAttemptAt",1000000L).put("lastAttemptElapsed",500L).put("boot",7)
        assertEquals(ReminderHealth.RETRY_MS-1000,ReminderHealth.waitMs(e,999999999,1500,7))
        assertEquals(ReminderHealth.RETRY_MS,ReminderHealth.waitMs(e,1,10,8))
        assertEquals(0L,ReminderHealth.waitMs(e,2000000,10,8))
    }
    fun testPostponeRearmsAndResetsUnanswered() {
        val s=session();save(s);ReminderHealth.record(context,s,"one",true)
        ReminderReceiver().onReceive(context,Intent("postpone").putExtra("sessionId","test"))
        val next=Store(context).use{it.read()}.getJSONObject("session")
        assertEquals("work",next.getString("phase"));assertTrue(Reminders.remaining(context,next)>290000)
        assertEquals(0,ReminderHealth.entry(ReminderHealth.read(context),s).getInt("unanswered"))
        assertTrue(context.getSharedPreferences("reminder_alarm",0).getLong("target",0)>SystemClock.elapsedRealtime())
    }
    fun testOrphanPresentedRoutineRecovers() {
        val s=session();save(s)
        Store(context).use {val d=it.read();d.remove("session");d.put("routineState",JSONObject().put("r",JSONObject().put("phase","presented")));it.write(d)}
        Routines.refresh(context)
        assertEquals("work",Store(context).use{it.read()}.getJSONObject("routineState").getJSONObject("r").getString("phase"))
    }
    fun testRepeatedScheduleDoesNotMoveAlarmLater() {
        save(session().put("phase","work").put("elapsedDue",SystemClock.elapsedRealtime()+120000))
        Reminders.schedule(context);val prefs=context.getSharedPreferences("reminder_alarm",0);val first=prefs.getLong("target",0)
        Reminders.schedule(context);assertEquals(first,prefs.getLong("target",0))
    }
    fun testThirdUnansweredLogsOnceAndReleasesSlot() {
        val s=session();save(s)
        for(n in 1..3) ReminderHealth.record(context,s,"attempt-$n",true)
        val prefs=context.getSharedPreferences("reminder_health",0);val d=ReminderHealth.read(context);val e=ReminderHealth.entry(d,s)
        e.put("lastAttemptElapsed",SystemClock.elapsedRealtime()-ReminderHealth.RETRY_MS-1)
        prefs.edit().putString("state",d.toString()).commit()
        Reminders.recover(context);Reminders.recover(context)
        assertNull(Store(context).use{it.read()}.optJSONObject("session"))
        assertEquals(1,ReminderHealth.read(context).getJSONArray("issues").length())
        assertFalse(ReminderHealth.entry(ReminderHealth.read(context),s).has("lastResponseAt"))
    }
    fun testOldDismissedStateDoesNotBlockFollowingRoutine() {
        val s=session();save(s)
        Store(context).use {val d=it.read();d.put("dismissedNotification","test:due");it.write(d)}
        Reminders.recover(context)
        assertNull(Store(context).use{it.read()}.optJSONObject("session"))
        assertFalse(ReminderHealth.read(context).has("issues"))
    }
    fun testQuietHoursSuppressRecoveryWithoutCountingAttempts() {
        val s=session();save(s)
        Store(context).use {val d=it.read();d.getJSONObject("settings").put("quietHours",true).put("quietStart",0).put("quietEnd",0);it.write(d)}
        Reminders.recover(context)
        assertFalse(ReminderHealth.entry(ReminderHealth.read(context),s).has("lastAttemptAt"))
        assertEquals("test",Store(context).use{it.read()}.getJSONObject("session").getString("id"))
    }
}
