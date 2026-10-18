// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process
import android.os.PowerManager
import android.os.SystemClock
import org.json.JSONObject
import kotlin.math.abs

/** Stores counters only. App/package names are never read or retained. */
object ScreenTime {
    fun granted(c:Context):Boolean {
        if(Build.VERSION.SDK_INT<28) return false
        @Suppress("DEPRECATION")
        return c.getSystemService(AppOpsManager::class.java).checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,Process.myUid(),c.packageName)==AppOpsManager.MODE_ALLOWED
    }
    fun initialize(c:Context,s:JSONObject,now:Long=System.currentTimeMillis()) {
        s.put("activeCursor",now).put("activeMono",SystemClock.elapsedRealtime()).put("activeBoot",Reminders.boot(c))
            .put("activeOn",c.getSystemService(PowerManager::class.java).isInteractive)
            .put("activeUnlocked",!c.getSystemService(KeyguardManager::class.java).isKeyguardLocked)
            .put("activeOffSince",if(c.getSystemService(PowerManager::class.java).isInteractive) -1L else now)
    }
    fun update(c:Context,s:JSONObject):Boolean {
        if(s.optString("phase")!="work" || s.optString("timing")!="screen") return false
        val now=System.currentTimeMillis(); val mono=SystemClock.elapsedRealtime()
        if(!s.has("activeCursor")) { initialize(c,s,now); return true }
        if(mono-s.optLong("activeMono") in 0..1999 && s.optInt("activeBoot")==Reminders.boot(c)) return false
        if(!granted(c)) { initialize(c,s,now);s.put("activeUnavailable",true);return true }
        val from=s.getLong("activeCursor")
        // Wall-clock events cannot be safely reconstructed over reboot/clock jumps.
        if(s.optInt("activeBoot")!=Reminders.boot(c) || abs((now-from)-(mono-s.optLong("activeMono")))>5000 || now-from>43200000 || s.optBoolean("activeUnavailable")) {
            initialize(c,s,now);s.put("activeUnavailable",false).put("activeRecovery","Uncertain screen time was excluded after a gap, clock change or access loss.");return true
        }
        val events=c.getSystemService(UsageStatsManager::class.java).queryEvents(from,now)
        if(events==null) { s.put("activeUnavailable",true); initialize(c,s,now); return true }
        val changes=mutableListOf<Pair<Long,Int>>()
        val event=UsageEvents.Event()
        while(events.hasNextEvent()) { events.getNextEvent(event);if(event.eventType in listOf(15,16,17,18)) changes.add(event.timeStamp to event.eventType) }
        val result=ScreenIntervals.withReset(from,now,s.optBoolean("activeOn"),s.optBoolean("activeUnlocked"),changes, s.optLong("activeRemaining"),s.optLong("activeInterval",1500000),s.optLong("activeResetMs",30000),s.optLong("activeOffSince",-1))
        val on=result.on;val unlocked=result.unlocked
        s.put("activeRemaining",result.remaining).put("activeOffSince",result.offSince)
            .put("activeOn",on).put("activeUnlocked",unlocked).put("activeCursor",now).put("activeMono",mono).put("activeUnavailable",false)
        if(s.optLong("activeRemaining")==0L) s.put("phase","due")
        return true
    }
    fun refresh(c:Context) {
        Store(c).use { store ->
            val d=store.read();val s=d.optJSONObject("session") ?: return
            val before=s.optString("phase")
            if(update(c,s)) {
                val due=before=="work" && s.optString("phase")=="due"
                val allowed=Reminders.allowed(d.optJSONObject("settings") ?: JSONObject())
                if(due && !allowed) s.put("phase","idle")
                store.write(d)
                if(due && allowed) Reminders.notify(c,false)
            }
        }
    }
}
