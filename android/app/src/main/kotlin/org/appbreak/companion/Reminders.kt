// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import android.app.*
import android.content.*
import android.os.*
import android.provider.Settings
import org.json.JSONObject
import java.util.Calendar

object Reminders {
    var visible = false
    fun boot(c: Context): Int = Settings.Global.getInt(c.contentResolver,Settings.Global.BOOT_COUNT,0)
    fun remaining(c: Context,s: JSONObject): Long = if(s.optString("timing")=="screen" && s.optString("phase")=="work") s.optLong("activeRemaining") else if(s.optInt("boot",-1)==boot(c)) s.optLong("elapsedDue")-SystemClock.elapsedRealtime() else s.optLong("wallDue")-System.currentTimeMillis()
    private fun alarm(c: Context) = PendingIntent.getBroadcast(c, 1, Intent(c,ReminderReceiver::class.java).setAction("alarm"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun schedule(c: Context) {
        val manager = c.getSystemService(AlarmManager::class.java)

        val d=Store(c).use { it.read() };val s=d.optJSONObject("session")
        val delays=mutableListOf<Long>()
        if(s?.optString("phase") in listOf("work","rest","paused")) delays.add(if(s!!.optString("timing")=="screen" && s.optString("phase")=="work") 60000L else remaining(c,s))
        if(s?.optString("phase")=="pending" && remaining(c,s)>0) delays.add(remaining(c,s))
        Planner.nextDelay(d)?.let{delays.add(it)}
        Routines.nextDelay(c,d)?.let { delays.add(it) }
        if(s?.optString("phase") in listOf("due","finished") || (s?.optString("phase")=="pending" && remaining(c,s)<=0)) {
            val settings=d.optJSONObject("settings") ?: JSONObject()
            val p=Routines.profile(d,s!!.optString("routineId"))
            val eligible=allowed(settings) && (!p.has("id") || Routines.allowed(p)) && settings.optLong("popupPausedUntil")<=System.currentTimeMillis()
            delays.add(if(eligible) maxOf(1000L,ReminderHealth.waitMs(c,s)) else 60000L)
        }
        val pauseUntil=d.optJSONObject("settings")?.optLong("popupPausedUntil",0) ?: 0L
        if(pauseUntil>System.currentTimeMillis()) delays.add(pauseUntil-System.currentTimeMillis())
        val saved=c.getSharedPreferences("reminder_alarm",Context.MODE_PRIVATE)
        if(delays.isEmpty()) { manager.cancel(alarm(c));saved.edit().clear().commit();return }
        val target=SystemClock.elapsedRealtime()+delays.min().coerceAtLeast(1000)
        val old=saved.getLong("target",0)
        // Foreground refresh must not continually push an already armed alarm back.
        if(saved.getInt("boot",-1)==boot(c) && old>SystemClock.elapsedRealtime() && old<=target) return
        try {
            if(Build.VERSION.SDK_INT<31 || manager.canScheduleExactAlarms()) manager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP,target,alarm(c))
            else manager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP,target,alarm(c))
        } catch(_:SecurityException) { manager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP,target,alarm(c)) }
        saved.edit().putLong("target",target).putInt("boot",boot(c)).commit()
    }

    fun allowed(settings: JSONObject): Boolean {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        fun within(start: Int,end: Int): Boolean = if(start==end) true else if(start<end) hour>=start && hour<end else hour>=start || hour<end
        if(settings.optBoolean("activeEnabled") && !within(settings.optInt("activeStart",9),settings.optInt("activeEnd",18))) return false
        if(settings.optBoolean("quietHours") && within(settings.optInt("quietStart",22),settings.optInt("quietEnd",7))) return false
        return true
    }
    fun clear(c: Context) { c.getSystemService(NotificationManager::class.java).cancel(1) }
    fun channel(c:Context,p:JSONObject):String {
        val id="routine_"+p.optString("id","manual")
        val ch=NotificationChannel(id,p.optString("name","Break reminders"),NotificationManager.IMPORTANCE_HIGH)
        ch.enableVibration(true)
        c.getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        return id
    }
    fun skippedSummary(c:Context) {
        val d=Store(c).use {it.read()};val manager=c.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("skip_summary","Skipped break totals",NotificationManager.IMPORTANCE_LOW))
        val open=PendingIntent.getActivity(c,31,Intent(c,MainActivity::class.java).setAction("openProgress").addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        try {manager.notify(3,Notification.Builder(c,"skip_summary").setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle("${BreakStats.skipped(d)} breaks skipped today").setContentText("Open Progress to see counts by activity type.").setContentIntent(open).setOnlyAlertOnce(true).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build())} catch(_:SecurityException){}
    }
    private fun release(c:Context,s:JSONObject,responded:Boolean=false) {
        Store(c).use { store -> val d=store.read();val active=d.optJSONObject("session")
            if(active?.optString("id")==s.optString("id")) {
                BreakStats.snapshot(c,d,active);Routines.archive(d,active,"unconfirmed")
                Routines.reset(c,d,active.optString("routineId"));d.remove("session");store.write(d)
            }
        }
        clear(c);ReminderHealth.response(c,s,responded)
    }
    fun recover(c:Context) {
        val d=Store(c).use { it.read() };val s=d.optJSONObject("session") ?: return
        if(s.optString("phase") !in listOf("due","finished","pending")) return
        if(s.optString("phase")=="pending" && remaining(c,s)>0) return
        val settings=d.optJSONObject("settings") ?: JSONObject()
        val p=Routines.profile(d,s.optString("routineId"))
        val dismissed=d.optString("dismissedNotification")==s.optString("id")+":"+s.optString("phase")
        val disabled=p.has("id") && !p.optBoolean("enabled") && p.optString("trigger")!="manual"
        val outsideWindow=p.has("id") && !Routines.allowed(p)
        val silent=!p.optBoolean("notifications",true) && (!p.optBoolean("popup",true) || !settings.optBoolean("popup",true))
        if(dismissed || disabled || outsideWindow || silent) {release(c,s,dismissed);return}
        if(!allowed(settings) || settings.optLong("popupPausedUntil")>System.currentTimeMillis()) return
        val e=ReminderHealth.entry(ReminderHealth.read(c),s)
        if(ReminderHealth.waitMs(c,s)>0) return
        if(e.optInt("unanswered")>=ReminderHealth.MAX_ATTEMPTS || e.optInt("failedAttempts")>=ReminderHealth.MAX_ATTEMPTS) {
            ReminderHealth.issue(c,s,if(e.optInt("unanswered")>=3) "No response recorded after three reminders. The routine will continue." else "Reminder delivery could not be confirmed. Check notification and popup permissions.")
            release(c,s);return
        }
        notify(c,s.optString("phase")!="due",retry=true)
    }
    fun notify(c: Context, finished: Boolean, popup:Boolean=true, retry:Boolean=false) {
        val d=Store(c).use { it.read() };val s=d.optJSONObject("session") ?: return
        val phase=s.optString("phase");val p=Routines.profile(d,s.optString("routineId"));val settings=d.optJSONObject("settings") ?: JSONObject()
        if(d.optString("dismissedNotification")==s.optString("id")+":"+phase) return
        val confirmation=phase in listOf("pending","finished") || finished
        val running=phase=="rest"
        val tracked=!running && ReminderHealth.waitMs(c,s)==0L
        val token=s.optString("id")+":"+phase+":"+SystemClock.elapsedRealtime()
        val manager=c.getSystemService(NotificationManager::class.java)
        val open=PendingIntent.getActivity(c,10,Intent(c,MainActivity::class.java).setAction("openBreak").putExtra("sessionId",s.optString("id")).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val b=Notification.Builder(c,channel(c,p)).setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(if(confirmation) "Did you take your break?" else if(running) "Break in progress" else p.optString("name","Time for a gentle break"))
            .setContentText(if(confirmation) "Confirm participation, or skip this break." else if(running) "Return when ready. Completion is yours to confirm." else p.optString("message","Break ready. Start when you are ready."))
            .setSubText(BreakStats.summary(c,d,s))
            .setColor(p.optLong("color",0xff356859).toInt()).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setContentIntent(open).setOnlyAlertOnce(!retry || !tracked).setAutoCancel(false)
        val dismiss=Intent(c,ReminderReceiver::class.java).setAction("dismissed").putExtra("sessionId",s.optString("id")).putExtra("phase",phase)
        b.setDeleteIntent(PendingIntent.getBroadcast(c,24,dismiss,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        fun action(code:Int,label:String,action:String) {
            val i=Intent(c,ReminderReceiver::class.java).setAction(action).putExtra("sessionId",s.optString("id"))
            val pi=PendingIntent.getBroadcast(c,code,i,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            b.addAction(Notification.Action.Builder(null,label,pi).build())
        }
        if(confirmation) { action(21,"Yes, I did","confirm");action(22,"Skip","skip") }
        else if(running) {
            b.setWhen(System.currentTimeMillis()+remaining(c,s).coerceAtLeast(0)).setUsesChronometer(true).setChronometerCountDown(true)
            action(23,"Pause break","pauseBreak")
        } else {
            b.addAction(Notification.Action.Builder(null,"Start break",open).build())
            action(11,"Postpone 5 min","postpone");action(12,"Pause 15 min","pause")
        }
        var posted=false
        if(p.optBoolean("notifications",true) && manager.areNotificationsEnabled() && manager.getNotificationChannel(channel(c,p))?.importance!=NotificationManager.IMPORTANCE_NONE) {
            try { manager.notify(1,b.build());posted=true } catch(_:SecurityException) { }
        } else clear(c)
        if(tracked) ReminderHealth.record(c,s,token,posted)
        if(popup && tracked && !visible && !running && p.optBoolean("popup",true) && PopupPolicy.allowed(settings.optBoolean("popup",true), settings.optLong("popupPausedUntil",0), System.currentTimeMillis()) && Settings.canDrawOverlays(c) && c.getSystemService(PowerManager::class.java).isInteractive && !c.getSystemService(KeyguardManager::class.java).isKeyguardLocked) {
            try { c.startActivity(Intent(c,BreakPopupActivity::class.java).putExtra("breakPopup",true).putExtra("reminderToken",token).putExtra("reminderSession",s.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)) } catch(_:Exception) { }
        }
    }

}
class ReminderReceiver: BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        if(intent.action!="foreground") c.getSharedPreferences("reminder_alarm",Context.MODE_PRIVATE).edit().clear().commit()
        try { receive(c,intent) } finally { Reminders.schedule(c) }
    }
    private fun receive(c: Context, intent: Intent) {
        if(intent.action=="dismissed") {
            Store(c).use { store -> val d=store.read();val s=d.optJSONObject("session");if(s!=null && s.optString("id")==intent.getStringExtra("sessionId")) {d.put("dismissedNotification",s.optString("id")+":"+intent.getStringExtra("phase"));ReminderHealth.response(c,s);Routines.archive(d,s,"unconfirmed");Routines.reset(c,d,s.optString("routineId"));d.remove("session");store.write(d)} };return
        }
        if(intent.action=="testReminder") {
            Store(c).use { store -> val d=store.read(); if(d.optJSONObject("session")?.optString("phase") in listOf(null,"idle")) {
                d.put("session",JSONObject().put("id",java.util.UUID.randomUUID().toString()).put("phase","due").put("wallDue",0).put("elapsedDue",0).put("boot",Reminders.boot(c)).put("remainingMs",0).put("resumePhase","work"));store.write(d)
            } }; Reminders.notify(c,false);return
        }
        if(intent.action in listOf("confirm","skip")) { Routines.resolve(c,intent.getStringExtra("sessionId") ?: "",intent.action=="confirm");return }
        // Expiry is persisted, so it resumes even after process death/reboot.
        var resumeDue=false
        Store(c).use { store ->
            val d=store.read();val settings=d.optJSONObject("settings")
            val until=settings?.optLong("popupPausedUntil",0) ?: 0L
            if(until>0 && until<=System.currentTimeMillis()) {
                settings!!.put("popupPausedUntil",0);store.write(d)
                resumeDue=d.optJSONObject("session")?.optString("phase")=="due"
            }
        }
        if(resumeDue) Reminders.notify(c,false)
        if(!intent.hasExtra("sessionId")) { Reminders.recover(c);Routines.refresh(c);ScreenTime.refresh(c) }
        Store(c).use { store ->
            val d=store.read(); val s=d.optJSONObject("session") ?: run { Reminders.schedule(c);return }
            if(intent.hasExtra("sessionId") && intent.getStringExtra("sessionId")!=s.optString("id")) return
            val phase=s.optString("phase"); val savedRemaining=Reminders.remaining(c,s).coerceAtLeast(0); val now=System.currentTimeMillis(); val mono=SystemClock.elapsedRealtime()
            fun deadline(duration: Long) { s.put("wallDue",now+duration).put("elapsedDue",mono+duration).put("boot",Reminders.boot(c)) }
            when(intent.action) {
                "pauseBreak" -> { if(phase!="rest") return;s.put("phase","paused").put("resumePhase","rest").put("remainingMs",savedRemaining);deadline(900000);Reminders.clear(c) }
                "postpone" -> { if(phase !in listOf("work","due")) return; s.put("phase","work").put("activeRemaining",300000); ScreenTime.initialize(c,s); deadline(300000); Reminders.clear(c) }
                "pause" -> { if(phase !in listOf("work","due")) return; s.put("phase","paused").put("resumePhase","work").put("remainingMs",savedRemaining); deadline(900000); Reminders.clear(c) }
                else -> {
                    if(phase !in listOf("work","rest","pending","paused")) { Reminders.schedule(c);return }
                    if(Reminders.remaining(c,s)< -43200000L) { d.remove("session"); store.write(d); Reminders.schedule(c); return }
                    if(Reminders.remaining(c,s)>0) { Reminders.schedule(c); return }
                    if(phase=="paused") { s.put("phase",s.optString("resumePhase","work")); deadline(s.optLong("remainingMs")); s.put("activeRemaining",s.optLong("remainingMs")); ScreenTime.initialize(c,s) }
                    else {
                        val permitted=Reminders.allowed(d.optJSONObject("settings") ?: JSONObject())
                        val breakEnded=phase in listOf("rest","pending")
                        s.put("phase",if(breakEnded) "finished" else if(permitted) "due" else "idle")
                        val endCue=breakEnded && BreakCues.prepare(d,s,"end")
                        store.write(d) // Persist before posting: repeat delivery cannot notify twice.
                        if(endCue) BreakCues.play(c,"end",d.optJSONObject("settings") ?: JSONObject())
                        if(permitted) Reminders.notify(c,breakEnded)
                        Reminders.schedule(c); return
                    }
                }
            }
            store.write(d)
            if(intent.action in listOf("postpone","pause","pauseBreak")) ReminderHealth.response(c,s)
        }
        Reminders.schedule(c)
    }
}

