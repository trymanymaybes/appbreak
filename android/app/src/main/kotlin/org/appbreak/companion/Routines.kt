// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import android.content.Context
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.UUID

/** Independent work counters; a single presentation slot prevents overlapping breaks. */
object Routines {
    fun profiles(d:JSONObject):List<JSONObject> {
        val a=d.optJSONObject("settings")?.optJSONArray("profiles") ?: return emptyList()
        return (0 until a.length()).map { a.getJSONObject(it) }
    }
    fun profile(d:JSONObject,id:String)=profiles(d).firstOrNull { it.optString("id")==id } ?: JSONObject()
    fun state(d:JSONObject):JSONObject = d.optJSONObject("routineState") ?: JSONObject().also { d.put("routineState",it) }
    fun fresh(c:Context,p:JSONObject):JSONObject {
        val duration=p.optLong("workSeconds",1500)*1000
        return JSONObject().put("phase","work").put("timing",if(p.optString("trigger")=="screen") "screen" else "elapsed")
            .put("wallDue",System.currentTimeMillis()+duration).put("elapsedDue",SystemClock.elapsedRealtime()+duration).put("boot",Reminders.boot(c))
            .put("activeRemaining",duration).put("activeInterval",duration)
            .put("activeResetMs",if(p.optBoolean("resetByBreak")) p.optLong("breakSeconds",30)*1000 else p.optLong("resetSeconds",30)*1000)
            .also { ScreenTime.initialize(c,it) }
    }
    fun allowed(p:JSONObject):Boolean {
        val cal=Calendar.getInstance();val day=(cal.get(Calendar.DAY_OF_WEEK)+5)%7+1
        val days=p.optJSONArray("days")
        if(days!=null && (0 until days.length()).none { days.optInt(it)==day }) return false
        val h=cal.get(Calendar.HOUR_OF_DAY);val start=p.optInt("startHour",0);val end=p.optInt("endHour",0)
        return start==end || if(start<end) h in start until end else h>=start || h<end
    }
    fun reset(c:Context,d:JSONObject,id:String) {
        if(id.isEmpty()) return
        val p=profile(d,id);val old=state(d).optJSONObject(id)
        val n=fresh(c,p)
        if(old?.has("lastDay")==true) n.put("lastDay",old.optString("lastDay"))
        if(p.optString("trigger")=="manual" && !p.optBoolean("repeat",true)) n.put("stopped",true)
        state(d).put(id,n)
    }
    fun resetScreenRoutines(c:Context,d:JSONObject) {
        for(p in profiles(d)) if(p.optString("trigger")=="screen" && p.optBoolean("enabled")) reset(c,d,p.getString("id"))
    }
    fun start(c:Context,id:String) {
        Store(c).use { store -> val d=store.read();val p=profile(d,id);check(p.has("id"));state(d).put(id,fresh(c,p));store.write(d) }
        Reminders.schedule(c)
    }
    fun refresh(c:Context) {
        var notify=false
        Store(c).use { store ->
            val d=store.read();val ps=profiles(d);if(ps.isEmpty()) return
            val before=d.toString();val states=state(d);val settings=d.optJSONObject("settings") ?: JSONObject()
            val now=System.currentTimeMillis();val cal=Calendar.getInstance()
            val day="${cal.get(Calendar.YEAR)}-${cal.get(Calendar.DAY_OF_YEAR)}"
            val active=d.optJSONObject("session")
            val expired=active!=null && (active.optString("phase")=="finished" ||
                (active.optString("phase") in listOf("rest","pending") && Reminders.remaining(c,active)<=0))
            if(expired && archive(d,active!!,"unconfirmed")) reset(c,d,active.optString("routineId"))
            var occupied=active?.optString("phase") !in listOf(null,"idle") && !expired
            for(p in ps) {
                val id=p.getString("id");if(!p.optBoolean("enabled",false)) { states.remove(id);continue }
                var s=states.optJSONObject(id)
                if(s==null) { if(p.optString("trigger")=="manual") continue; s=fresh(c,p);states.put(id,s) }
                if(!expired && d.optJSONObject("session")?.optString("routineId")==id && d.optJSONObject("session")?.optString("phase")!="idle") { s.put("phase","presented");continue }
                if(s.optBoolean("stopped")) continue
                if(!allowed(p) || !Reminders.allowed(settings)) { val n=fresh(c,p);if(s.has("lastDay")) n.put("lastDay",s.optString("lastDay"));states.put(id,n);continue }
                if(s.optString("phase")=="presented") continue
                var due=false
                when(p.optString("trigger","manual")) {
                    "scheduled" -> {
                        val minutes=cal.get(Calendar.HOUR_OF_DAY)*60+cal.get(Calendar.MINUTE)
                        val target=p.optInt("minuteOfDay",540)
                        // Only a 15-minute grace period; never replay yesterday's alarms.
                        if(minutes>=target && s.optString("lastDay")!=day) {
                            s.put("lastDay",day);due=minutes-target<=15
                        }
                    }
                    "screen" -> { ScreenTime.update(c,s);due=s.optString("phase")=="due" }
                    else -> { val left=Reminders.remaining(c,s);if(left< -43200000L) { states.put(id,fresh(c,p));continue };due=left<=0 }
                }
                if(due) { s.put("phase","due");if(!s.has("dueSince")) s.put("dueSince",now) }
                if(s.optString("phase")=="due") {
                    if(now-s.optLong("dueSince",now)>900000) { reset(c,d,id);continue }
                    if(!occupied) {
                        d.put("session",JSONObject().put("id",UUID.randomUUID().toString()).put("routineId",id).put("phase","due")
                            .put("wallDue",now).put("elapsedDue",SystemClock.elapsedRealtime()).put("boot",Reminders.boot(c)).put("remainingMs",0).put("resumePhase","work"))
                        s.put("phase","presented");occupied=true;notify=true
                    }
                }
            }
            if(before!=d.toString()) store.write(d)
        }
        if(notify) Reminders.notify(c,false)
    }
    /** Missed means unconfirmed, not evidence that the person stayed on screen. */
    fun archive(d:JSONObject,s:JSONObject,reason:String):Boolean {
        val list=d.optJSONArray("missedBreaks") ?: JSONArray().also { d.put("missedBreaks",it) }
        if((0 until list.length()).any { list.getJSONObject(it).optString("id")==s.optString("id") }) return false
        val record=JSONObject(s.toString()).put("reason",reason)
            .put("date",java.text.SimpleDateFormat("yyyy-MM-dd",java.util.Locale.US).format(java.util.Date()))
        list.put(record)
        return true
    }
    fun removeMissed(d:JSONObject,id:String) {
        val list=d.optJSONArray("missedBreaks") ?: return
        d.put("missedBreaks",JSONArray((0 until list.length()).map { list.getJSONObject(it) }.filter { it.optString("id")!=id }))
    }
    fun resolve(c:Context,id:String,yes:Boolean) {
        Store(c).use { store ->
            val d=store.read();val s=d.optJSONObject("session") ?: return
            if(s.optString("id")!=id || s.optString("phase") !in listOf("pending","rest","finished")) return
            if(!yes) { removeMissed(d,id); archive(d,s,"skipped") }
            if(yes) {
                removeMissed(d,id)
                val history=d.optJSONArray("history") ?: JSONArray().also { d.put("history",it) }
                if((0 until history.length()).none { history.getJSONObject(it).optString("id")==id }) {
                    val activities=JSONObject(c.assets.open("flutter_assets/assets/activities.json").bufferedReader().use { it.readText() }).getJSONArray("activities")
                    val custom=d.optJSONArray("customActivities") ?: JSONArray()
                    val all=(0 until activities.length()).map { activities.getJSONObject(it) }+(0 until custom.length()).map {custom.getJSONObject(it)}
                    val remote=ActivityCatalog.cached(c)
                    val withCatalog=all+(0 until remote.length()).map { remote.getJSONObject(it) }
                    val a=withCatalog.firstOrNull {it.optString("id")==s.optString("activity")}
                    if(a!=null) history.put(JSONObject().put("id",id).put("routine",s.optString("routineId")).put("activity",a.getString("id")).put("category",a.getString("category"))
                        .put("date",java.text.SimpleDateFormat("yyyy-MM-dd",java.util.Locale.US).format(java.util.Date())).put("selfReported",true))
                }
            }
            reset(c,d,s.optString("routineId"));if(yes) resetScreenRoutines(c,d);d.remove("session");store.write(d)
        }
        Reminders.clear(c);Reminders.schedule(c)
    }
}
