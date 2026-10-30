package org.appbreak.companion
import android.app.*
import android.content.*
import org.json.*
import java.util.*
import java.text.SimpleDateFormat
object Planner {
    fun date(now:Long=System.currentTimeMillis())=SimpleDateFormat("yyyy-MM-dd",Locale.US).format(Date(now))
    fun plans(d:JSONObject):List<JSONObject> {val a=d.optJSONArray("plans") ?: return emptyList();return (0 until a.length()).map{a.getJSONObject(it)}}
    fun records(d:JSONObject)=d.optJSONObject("planRecords") ?: JSONObject().also{d.put("planRecords",it)}
    fun active(d:JSONObject)=records(d).let{rs -> rs.keys().asSequence().any{rs.getJSONObject(it).optString("status")=="active"}}
    fun occurs(p:JSONObject,day:String,weekday:Int):Boolean {val ds=p.getJSONArray("days");return if(ds.length()==0) p.getString("date")==day else day>=p.getString("date") && (0 until ds.length()).any{ds.getInt(it)==weekday}}
    fun startAt(p:JSONObject,day:String):Long=Calendar.getInstance().apply {time=SimpleDateFormat("yyyy-MM-dd",Locale.US).parse(day)!!;set(Calendar.HOUR_OF_DAY,p.getInt("minute")/60);set(Calendar.MINUTE,p.getInt("minute")%60)}.timeInMillis
    fun stopWork(d:JSONObject) {val s=d.optJSONObject("session");if(s?.optString("phase") in listOf("work","due") || (s?.optString("phase")=="paused" && s.optString("resumePhase")=="work")) d.remove("session")}
    fun work(c:Context,d:JSONObject,p:JSONObject) {val profile=Routines.profile(d,p.getString("routine"));check(profile.has("id")){"Routine removed; edit this plan"};d.put("session",Routines.fresh(c,profile).put("id",UUID.randomUUID().toString()).put("routineId",profile.getString("id")).put("remainingMs",0).put("resumePhase","work"))}
    fun action(c:Context,id:String,day:String,action:String) {
        Store(c).use {store -> val d=store.read();val p=plans(d).firstOrNull{it.optString("id")==id} ?: error("Plan no longer exists");val rs=records(d);val key="$id@$day";val r=rs.optJSONObject(key) ?: JSONObject();val status=r.optString("status","planned");val now=System.currentTimeMillis()
            when(action) {
                "start" -> {check(day==date()){ "Select today to start" };check(status in listOf("planned","prompted","delayed","missed"));check(!active(d) && d.optJSONObject("session")?.optString("phase") in listOf(null,"idle")){"Finish or skip the current session first"};val profile=Routines.profile(d,p.getString("routine"));if(profile.optString("trigger")=="screen")check(ScreenTime.granted(c)){"Enable Usage access first"};work(c,d,p);r.put("status","active").put("end",now+p.getLong("minutes")*60000)}
                "delay" -> {check(status in listOf("planned","prompted","delayed"));r.put("status","delayed").put("remindAt",maxOf(now,r.optLong("remindAt",startAt(p,day)))+600000)}
                "extend" -> {check(status=="active");r.put("end",r.getLong("end")+900000)}
                "complete","skip" -> {if(action=="complete")check(status in listOf("active","ended"));if(status=="active")stopWork(d);r.put("status",if(action=="complete")"completed" else "skipped")}
                "delete" -> {check(status!="active");d.put("plans",JSONArray(plans(d).filter{it.optString("id")!=id}))}
                else -> error("Unknown action")
            }
            if(action!="delete")rs.put(key,r);store.write(d)
        }
        c.getSystemService(NotificationManager::class.java).cancel(2);Reminders.schedule(c)
    }
    fun nextDelay(d:JSONObject,now:Long=System.currentTimeMillis()):Long? {
        val rs=records(d);val delays=mutableListOf<Long>();for(key in rs.keys()){val r=rs.getJSONObject(key);if(r.optString("status")=="active")delays.add((r.getLong("end")-now).coerceAtLeast(1000))}
        for(p in plans(d))for(offset in 0..7){val cal=Calendar.getInstance().apply{timeInMillis=now;add(Calendar.DAY_OF_YEAR,offset)};val day=date(cal.timeInMillis);if(!occurs(p,day,(cal.get(Calendar.DAY_OF_WEEK)+5)%7+1))continue;val r=rs.optJSONObject(p.getString("id")+"@"+day) ?: JSONObject();if(r.optString("status") !in listOf("","planned","prompted","delayed"))continue;val target=r.optLong("remindAt",startAt(p,day))+if(r.optString("status")=="prompted")p.getLong("minutes")*60000 else 0;delays.add(if(target>now)target-now else 60000)}
        return delays.minOrNull()
    }
    fun refresh(c:Context) {
        var prompt=false;var endSettings:JSONObject?=null
        Store(c).use{store ->val d=store.read();if(plans(d).isEmpty())return;val before=d.toString();val rs=records(d);val now=System.currentTimeMillis();val today=date(now);val weekday=(Calendar.getInstance().get(Calendar.DAY_OF_WEEK)+5)%7+1
            for(key in rs.keys().asSequence().toList()){val r=rs.getJSONObject(key);if(r.optString("status")!="active")continue;val p=plans(d).firstOrNull{key.startsWith(it.getString("id")+"@")};if(p==null || now>=r.optLong("end")){stopWork(d);r.put("status","ended");continue};if(d.optJSONObject("session")?.optString("phase") in listOf(null,"idle"))work(c,d,p)}
            for(p in plans(d)){if(!occurs(p,today,weekday))continue;val key=p.getString("id")+"@"+today;val r=rs.optJSONObject(key) ?: JSONObject();val status=r.optString("status");if(status !in listOf("","planned","prompted","delayed"))continue;val target=r.optLong("remindAt",startAt(p,today));if(now<target)continue;if(status=="prompted"){if(now>=target+p.getLong("minutes")*60000)r.put("status","missed")}else if(now-target>900000)r.put("status","missed") else if(Reminders.allowed(d.optJSONObject("settings") ?: JSONObject())){r.put("status","prompted");prompt=true};rs.put(key,r)}
            if(before!=d.toString())store.write(d)
        }
        endSettings?.let{BreakCues.play(c,"end",it)}
        if(prompt){val manager=c.getSystemService(NotificationManager::class.java);manager.createNotificationChannel(NotificationChannel("planner","Planned activities",NotificationManager.IMPORTANCE_DEFAULT));val open=PendingIntent.getActivity(c,40,Intent(c,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE);try{manager.notify(2,Notification.Builder(c,"planner").setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle("A planned activity is ready").setContentText("Open My Day and start when ready.").setContentIntent(open).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build())}catch(_:SecurityException){}}
    }
}

