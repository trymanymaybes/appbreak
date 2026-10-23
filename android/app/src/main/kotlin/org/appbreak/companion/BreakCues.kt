package org.appbreak.companion
import android.app.NotificationManager
import android.content.Context
import android.media.*
import android.os.*
import org.json.*
object BreakCues {
    // Persist the event key in the same transaction as the transition, before output.
    // At-most-once: a process kill between commit and output may omit a cue, never replay it.
    fun prepare(d:JSONObject,s:JSONObject,event:String):Boolean {
        val id=s.optString("id");if(id.isEmpty()) return false
        val key="$id:$event";val seen=d.optJSONArray("cueEvents") ?: JSONArray()
        if((0 until seen.length()).any{seen.optString(it)==key}) return false
        val next=JSONArray();for(i in maxOf(0,seen.length()-63) until seen.length()) next.put(seen.getString(i));next.put(key);d.put("cueEvents",next)
        return true
    }
    fun play(c:Context,event:String,settings:JSONObject) {
        val audio=c.getSystemService(AudioManager::class.java)
        if(c.getSystemService(NotificationManager::class.java).currentInterruptionFilter!=NotificationManager.INTERRUPTION_FILTER_ALL) return
        if(audio.ringerMode==AudioManager.RINGER_MODE_SILENT) return
        if(settings.optBoolean("cueVibration",true)) {
            val pattern=if(event=="end") longArrayOf(0,80,100,80) else longArrayOf(0,80)
            @Suppress("DEPRECATION") val vibrator=c.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator.vibrate(VibrationEffect.createWaveform(pattern,-1),AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT).build())
        }
        if(settings.optBoolean("cueSound",settings.optBoolean("cues",false)) && audio.ringerMode==AudioManager.RINGER_MODE_NORMAL && audio.getStreamVolume(AudioManager.STREAM_NOTIFICATION)>0) {
            try {
                val tone=ToneGenerator(AudioManager.STREAM_NOTIFICATION,25)
                tone.startTone(if(event=="end") ToneGenerator.TONE_PROP_ACK else ToneGenerator.TONE_PROP_BEEP,180)
                Handler(Looper.getMainLooper()).postDelayed({tone.release()},300)
            } catch(_:RuntimeException) { }
        }
    }
    fun transition(d:JSONObject,previous:JSONObject?,active:JSONObject?):String? {
        if(active==null) return null
        val phase=active.optString("phase")
        val event=when {
            phase=="rest" -> "start"
            phase=="finished" && previous?.optString("phase") in listOf("rest","pending") -> "end"
            else -> return null
        }
        return if(prepare(d,active,event)) event else null
    }
}
