// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import android.app.*
import android.content.*
import android.media.*
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.*
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.view.accessibility.AccessibilityManager
import org.json.JSONObject

/** User-started article playback belongs to the service, never the Activity lifecycle. */
class ReadAloudService : Service() {
    companion object {
        private var instance: ReadAloudService? = null
        private var lastError: String? = null
        fun state(): Map<String, Any?> = mapOf(
            "state" to (instance?.status ?: "stopped"), "error" to lastError)
        fun stop(context: Context) { instance?.finishPlayback(); context.stopService(Intent(context, ReadAloudService::class.java)) }
        fun control(action: String) { instance?.command(action) }
        fun start(context: Context, payload: JSONObject) {
            lastError = null
            context.startForegroundService(Intent(context, ReadAloudService::class.java).setAction("start").putExtra("payload", payload.toString()))
        }
    }
    private val handler = Handler(Looper.getMainLooper())
    private var engine: TextToSpeech? = null
    private var ready = false
    private var payload = JSONObject()
    private var cursor = SpeechCursor(emptyList())
    private var generation = 0
    private var status = "loading"
    private var focus: AudioFocusRequest? = null
    private lateinit var media: MediaSession
    private lateinit var wake: PowerManager.WakeLock
    private var expires = 0L
    private val accessibility by lazy { getSystemService(AccessibilityManager::class.java) }
    private val screenReader = AccessibilityManager.TouchExplorationStateChangeListener { enabled -> if (enabled) pause() }
    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) { pause() }
    }
    private val guard = object : Runnable {
        override fun run() {
            if (!valid()) { finishPlayback(); return }
            handler.postDelayed(this, 1000)
        }
    }
    override fun onBind(intent: Intent?) = null
    override fun onCreate() {
        super.onCreate()
        instance = this
        wake = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AppBreak:readAloud")
        media = MediaSession(this, "AppBreak read aloud").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() { command("resume") }
                override fun onPause() { pause() }
                override fun onStop() { finishPlayback() }
            }, handler)
            isActive = true
        }
        accessibility.addTouchExplorationStateChangeListener(screenReader)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(noisy, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY), RECEIVER_NOT_EXPORTED)
        else registerReceiver(noisy, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
        getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("read_aloud", "Read aloud playback", NotificationManager.IMPORTANCE_LOW))
        startForeground(42, notification())
        engine = TextToSpeech(applicationContext) { result -> handler.post {
            ready = result == TextToSpeech.SUCCESS
            if (!ready) fail("No local speech engine available.")
            else if (status == "loading") play()
        } }
        engine?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}
            override fun onDone(id: String?) { handler.post {
                if (id == "$generation" && status == "playing") { cursor.next(); speakChunk() }
            } }
            @Deprecated("Android callback")
            override fun onError(id: String?) { handler.post {
                if (id == "$generation") fail("Speech failed. Check your installed offline voice and try again.")
            } }
            override fun onRangeStart(id: String?, start: Int, end: Int, frame: Int) { handler.post {
                if (id == "$generation" && status == "playing") cursor.progress(start)
            } }
        })
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "start") {
            generation++
            engine?.stop()
            payload = JSONObject(intent.getStringExtra("payload") ?: "{}")
            val steps = payload.optJSONArray("steps")
            cursor = SpeechCursor((0 until (steps?.length() ?: 0)).map { steps!!.getJSONObject(it).optString("text") }.filter { it.isNotBlank() })
            expires = SystemClock.elapsedRealtime() + 2 * 60 * 60 * 1000L
            status = "loading"
            handler.removeCallbacks(guard)
            handler.post(guard)
            if (ready) play() else publish()
        } else command(intent?.action ?: "stop")
        return START_NOT_STICKY // Never restart speech unexpectedly after process death.
    }
    private fun valid(): Boolean {
        if (SystemClock.elapsedRealtime() >= expires) return false
        val d = Store(this).use { it.read() }
        val s = d.optJSONObject("session") ?: return false
        val p = Routines.profile(d, s.optString("routineId"))
        val quiet = if (p.has("quiet")) p.optBoolean("quiet") else d.optJSONObject("settings")?.optBoolean("quiet", true) ?: true
        return !quiet && s.optString("id") == payload.optString("sessionId") &&
            s.optString("activity") == payload.optString("activityId") && s.optString("phase") == "rest" && Reminders.remaining(this, s) > 0
    }
    private fun play() {
        if (!valid()) { finishPlayback(); return }
        if (accessibility.isTouchExplorationEnabled) { fail("TalkBack is active. Use its reading controls."); return }
        if (!ready) { status = "loading"; publish(); return }
        val tts = engine ?: return
        val language = java.util.Locale.forLanguageTag(payload.optString("language", "en-IN")).language
        val voices = tts.voices.orEmpty().filter { it.locale.language == language && !it.isNetworkConnectionRequired && !it.features.orEmpty().contains("notInstalled") }
        val voice = voices.firstOrNull { it.name == payload.optString("voice") } ?: voices.firstOrNull()
        if (voice == null) { fail("Install an offline voice matching the page language ($language)."); return }
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
        tts.setAudioAttributes(attributes)
        focus?.let { getSystemService(AudioManager::class.java).abandonAudioFocusRequest(it) }
        focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener({ change -> if (change < 0) pause() }, handler).build()
        if (getSystemService(AudioManager::class.java).requestAudioFocus(focus!!) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            lastError = "Audio is in use. Tap Resume to try again."; pause(); return
        }
        tts.voice = voice
        tts.setSpeechRate(payload.optDouble("rate", 1.0).toFloat().coerceIn(0.5f, 1.5f))
        lastError = null
        status = "playing"
        if (!wake.isHeld) wake.acquire((expires - SystemClock.elapsedRealtime()).coerceAtLeast(1))
        publish()
        speakChunk()
    }
    private fun speakChunk() {
        if (!valid()) { finishPlayback(); return }
        val text = cursor.remaining() ?: run { finishPlayback(); return }
        generation++
        val params = Bundle().apply { putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, payload.optDouble("volume", 0.8).toFloat().coerceIn(0f, 1f)) }
        if (engine?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "$generation") == TextToSpeech.ERROR) fail("Unable to start speech. Try again.")
    }
    private fun pause() {
        generation++ // Ignore completion/range callbacks from the cancelled utterance.
        engine?.stop()
        status = "paused"
        releaseAudio()
        publish()
    }
    private fun command(action: String) {
        when (action) {
            "pause" -> pause()
            "resume" -> if (status != "playing") play()
            "restart" -> { generation++; engine?.stop(); cursor.restart(); play() }
            "stop" -> finishPlayback()
        }
    }
    private fun releaseAudio() {
        if (wake.isHeld) wake.release()
        focus?.let { getSystemService(AudioManager::class.java).abandonAudioFocusRequest(it) }
        focus = null
    }
    private fun fail(message: String) { lastError = message; finishPlayback() }
    private fun finishPlayback() {
        generation++; engine?.stop(); status = "stopped"
        handler.removeCallbacks(guard)
        releaseAudio()
        media.isActive = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    private fun notification(): Notification {
        fun action(name: String) = PendingIntent.getService(this, name.hashCode(), Intent(this, ReadAloudService::class.java).setAction(name), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val playing = status == "playing"
        val open = PendingIntent.getActivity(this, 42, Intent(this, MainActivity::class.java).setAction("openBreak").putExtra("sessionId", payload.optString("sessionId")), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, "read_aloud").setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("AppBreak · Read aloud").setContentText(if (playing) "Reading page" else if (status == "loading") "Preparing voice…" else "Paused")
            .setContentIntent(open).setOnlyAlertOnce(true).setOngoing(true).setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(Notification.Action.Builder(null, if (playing) "Pause" else "Resume", action(if (playing) "pause" else "resume")).build())
            .addAction(Notification.Action.Builder(null, "Restart", action("restart")).build())
            .addAction(Notification.Action.Builder(null, "Stop", action("stop")).build())
            .setStyle(Notification.MediaStyle().setMediaSession(media.sessionToken).setShowActionsInCompactView(0, 2)).build()
    }
    private fun publish() {
        media.setPlaybackState(PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_STOP)
            .setState(if (status == "playing") PlaybackState.STATE_PLAYING else if (status == "loading") PlaybackState.STATE_BUFFERING else PlaybackState.STATE_PAUSED, PlaybackState.PLAYBACK_POSITION_UNKNOWN, if (status == "playing") 1f else 0f).build())
        getSystemService(NotificationManager::class.java).notify(42, notification())
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        generation++; engine?.stop(); engine?.shutdown(); releaseAudio()
        accessibility.removeTouchExplorationStateChangeListener(screenReader)
        unregisterReceiver(noisy)
        media.release()
        if (instance === this) instance = null
        super.onDestroy()
    }
}
