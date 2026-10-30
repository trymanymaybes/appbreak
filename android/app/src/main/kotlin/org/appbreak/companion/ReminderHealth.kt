// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import android.app.*
import android.content.*
import android.os.SystemClock
import org.json.*

/** Device-local delivery diagnostics, separate from revision-checked Flutter state. */
object ReminderHealth {
    const val RETRY_MS = 5 * 60000L
    const val MAX_ATTEMPTS = 3
    private fun prefs(c:Context)=c.getSharedPreferences("reminder_health",Context.MODE_PRIVATE)
    fun read(c:Context)=JSONObject(prefs(c).getString("state","{}") ?: "{}")
    private fun write(c:Context,d:JSONObject) { prefs(c).edit().putString("state",d.toString()).commit() }
    fun key(s:JSONObject)=s.optString("routineId").ifEmpty { "manual" }
    fun entry(d:JSONObject,s:JSONObject):JSONObject {
        val all=d.optJSONObject("routines") ?: JSONObject().also { d.put("routines",it) }
        return all.optJSONObject(key(s)) ?: JSONObject().also { all.put(key(s),it) }
    }
    fun waitMs(e:JSONObject,wall:Long,mono:Long,boot:Int):Long {
        if(!e.has("lastAttemptAt")) return 0
        val age=if(e.optInt("boot",-1)==boot) mono-e.optLong("lastAttemptElapsed") else wall-e.optLong("lastAttemptAt")
        return (RETRY_MS-age.coerceAtLeast(0)).coerceIn(0,RETRY_MS)
    }
    fun waitMs(c:Context,s:JSONObject)=waitMs(entry(read(c),s),System.currentTimeMillis(),SystemClock.elapsedRealtime(),Reminders.boot(c))
    fun response(c:Context,s:JSONObject,userResponse:Boolean=true) {
        val d=read(c);val e=entry(d,s)
        e.put("unanswered",0).put("failedAttempts",0)
        if(userResponse) e.put("lastResponseAt",System.currentTimeMillis())
        e.remove("lastAttemptAt");e.remove("token");write(c,d)
    }
    /** Same token joins the notification and confirmed popup into ONE attempt. */
    fun record(c:Context,s:JSONObject,token:String,posted:Boolean,popup:Boolean=false) {
        val d=read(c);val e=entry(d,s);val now=System.currentTimeMillis()
        val same=e.optString("token")==token
        if(!same) {
            e.put("token",token).put("lastAttemptAt",now).put("lastAttemptElapsed",SystemClock.elapsedRealtime()).put("boot",Reminders.boot(c))
            e.put("attemptIssued",false)
        }
        if((posted || popup) && !e.optBoolean("attemptIssued")) {
            e.put("unanswered",e.optInt("unanswered")+1).put("attemptIssued",true).put("failedAttempts",0)
        } else if(!same && !posted && !popup) e.put("failedAttempts",e.optInt("failedAttempts")+1)
        if(posted) e.put("lastNotificationAt",now)
        if(popup) e.put("lastPopupAt",now)
        write(c,d)
    }
    fun issue(c:Context,s:JSONObject,message:String) {
        val d=read(c);val rows=d.optJSONArray("issues") ?: JSONArray()
        val id=s.optString("id")+":"+message
        if((0 until rows.length()).any { rows.getJSONObject(it).optString("id")==id }) return
        rows.put(JSONObject().put("id",id).put("routine",key(s)).put("at",System.currentTimeMillis()).put("message",message))
        d.put("issues",JSONArray((maxOf(0,rows.length()-50) until rows.length()).map {rows.getJSONObject(it)}));write(c,d)
        val nm=c.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("reminder_health","Reminder issues",NotificationManager.IMPORTANCE_LOW))
        val open=PendingIntent.getActivity(c,45,Intent(c,MainActivity::class.java).setAction("openProgress"),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        try { nm.notify(4,Notification.Builder(c,"reminder_health").setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle("AppBreak reminder issue").setContentText(message).setContentIntent(open).setAutoCancel(true).setOnlyAlertOnce(true).build()) } catch(_:SecurityException) { }
    }
    fun clear(c:Context) { prefs(c).edit().clear().commit() }
}
