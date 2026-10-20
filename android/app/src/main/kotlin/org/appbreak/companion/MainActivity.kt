// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.media.*
import android.os.*
import android.speech.tts.TextToSpeech
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.UUID

open class MainActivity: FlutterActivity() {
    private var dictation: Dictation?=null
    private var tts: TextToSpeech?=null
    private var ttsReady=false
    private val screenReaderListener=AccessibilityManager.TouchExplorationStateChangeListener { enabled -> if(enabled) tts?.stop() }
    private var recorder: MediaRecorder?=null
    private var recordingName: String?=null
    private var player: MediaPlayer?=null
    private var pending: MethodChannel.Result?=null
    private var fileBytes: ByteArray?=null
    private var restorePreview: JSONObject?=null
    private var channel: MethodChannel?=null
    private var recordStarted=0L
    private var audioRequest: AudioFocusRequest?=null
    private val handler=Handler(Looper.getMainLooper())
    private val stopLimit=Runnable { finishRecording() }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        getSystemService(AccessibilityManager::class.java).addTouchExplorationStateChangeListener(screenReaderListener)
        tts=TextToSpeech(this) { status -> ttsReady=status==TextToSpeech.SUCCESS }
        channel=MethodChannel(engine.dartExecutor.binaryMessenger,"org.appbreak/device")
        dictation=Dictation(this) { channel?.invokeMethod("dictation",it) }
        channel!!.setMethodCallHandler { call,result ->
            try {
                when(call.method) {
                    "isBreakPopup" -> result.success(this is BreakPopupActivity)
                    "resizeBreakPopup" -> {
                        check(this is BreakPopupActivity) { "Not a break popup" }
                        val expanded=call.argument<Boolean>("expanded") == true
                        intent.putExtra("popupExpanded",expanded)
                        configurePopup()
                        result.success(expanded)
                    }
                    "consumeBreakOpen" -> {
                        // Retained on the Activity until Flutter has loaded session state.
                        // Handles both launcher creation and onNewIntent (warm notification tap).
                        val open = intent?.action == "openBreak"
                        val sessionId = intent?.getStringExtra("sessionId")
                        if(open) { intent?.action = null; intent?.removeExtra("sessionId") }
                        result.success(if(open) mapOf("sessionId" to sessionId) else null)
                    }
                    "catalogLoad" -> result.success(ActivityCatalog.snapshot(this))
                    "catalogEnabled" -> { ActivityCatalog.setEnabled(this, call.argument<Boolean>("enabled") == true); result.success(ActivityCatalog.snapshot(this)) }
                    "catalogRefresh" -> {
                        if(this is BreakPopupActivity) result.success(ActivityCatalog.snapshot(this))
                        else Thread {
                            try {
                                val value = ActivityCatalog.refresh(applicationContext, call.argument<Boolean>("manual") == true)
                                handler.post { result.success(value) }
                            } catch (_: Exception) {
                                handler.post { result.error("catalog", "Catalogue unavailable; local activities remain available.", null) }
                            }
                        }.start()
                    }
                    "closePopup" -> { result.success(null); if(this is BreakPopupActivity) finish() }
                    "saveDraft" -> {
                        val text=call.argument<String>("text") ?: "";val title=call.argument<String>("title") ?: "Idea"
                        require(text.length<=100000 && title.length<=200)
                        Store(this).use { store -> val d=store.read();d.put("ideaDraft",JSONObject().put("text",text).put("title",title));store.write(d) };result.success(null)
                    }
                    "clearDraft" -> { Store(this).use { store -> val d=store.read();d.remove("ideaDraft");store.write(d) };result.success(null) }
                    "capabilities" -> {
                        val manager=getSystemService(NotificationManager::class.java)
                        val ch=manager.getNotificationChannel("breaks_v2")
                        result.success(mapOf("notifications" to (manager.areNotificationsEnabled() && (ch==null || ch.importance!=NotificationManager.IMPORTANCE_NONE)), "overlay" to android.provider.Settings.canDrawOverlays(this), "usage" to ScreenTime.granted(this), "screenSupported" to (Build.VERSION.SDK_INT>=28), "dictation" to Dictation.available(this), "microphone" to (checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED)))
                    }
                    "overlayAccess" -> { startActivity(Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,android.net.Uri.parse("package:$packageName")));result.success(null) }
                    "usageAccess" -> { startActivity(Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS,android.net.Uri.parse("package:$packageName")));result.success(null) }
                    "startRoutine" -> { Routines.start(this,call.argument<String>("id")!!);result.success(null) }
                    "routineChannel" -> {
                        val p=Store(this).use { Routines.profile(it.read(),call.argument<String>("id")!!) }
                        val id=Reminders.channel(this,p)
                        startActivity(Intent(android.provider.Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).putExtra(android.provider.Settings.EXTRA_APP_PACKAGE,packageName).putExtra(android.provider.Settings.EXTRA_CHANNEL_ID,id));result.success(null)
                    }
                    "notificationSettings" -> { startActivity(Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(android.provider.Settings.EXTRA_APP_PACKAGE,packageName));result.success(null) }
                    "testReminder" -> {
                        val alarm=getSystemService(AlarmManager::class.java)
                        val pi=PendingIntent.getBroadcast(this,99,Intent(this,ReminderReceiver::class.java).setAction("testReminder"),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        alarm.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP,SystemClock.elapsedRealtime()+10000,pi)
                        result.success("Test scheduled in about 10 seconds. Leave the app; Android may delay delivery.")
                    }
                    "dictate" -> {
                        check(recorder==null) { "Stop audio recording first" }
                        if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO),52);result.error("permission","Allow microphone access, then tap Speak again.",null)
                        } else { tts?.stop();player?.release();player=null;check(requestFocus());dictation!!.start(call.argument<String>("language") ?: "en-IN");result.success(null) }
                    }
                    "stopDictation" -> { dictation?.stop();result.success(null) }
                    "allowed" -> result.success(Reminders.allowed(Store(this).use { it.read().optJSONObject("settings") ?: JSONObject() }))
                    "now" -> result.success(mapOf("wall" to System.currentTimeMillis(),"elapsed" to SystemClock.elapsedRealtime(),"boot" to Reminders.boot(this)))
                    "load" -> { Routines.refresh(this); ScreenTime.refresh(this); result.success(Store(this).use { it.read().toString() }) }
                    "save" -> {
                        val d=JSONObject(call.argument<String>("json")!!)
                        val doomed=d.optString("pendingDelete"); d.remove("pendingDelete")
                        val active=d.optJSONObject("session")
                        if(active?.optString("timing")=="screen" && active.optString("phase")=="work" && !active.has("activeCursor")) ScreenTime.initialize(this,active)
                        Store(this).use {
                            val previous=it.read().optJSONObject("session")
                            if(previous!=null && previous.optString("phase")!="idle" && active?.optString("phase") in listOf(null,"idle")) {
                                Routines.reset(this,d,previous.optString("routineId"))
                                val history=d.optJSONArray("history")
                                if(history!=null && (0 until history.length()).any { history.getJSONObject(it).optString("id")==previous.optString("id") }) Routines.resetScreenRoutines(this,d)
                            }
                            it.write(d)
                        }
                        if(doomed.matches(Regex("[a-f0-9-]{36}\\.m4a"))) File(filesDir,"recordings/$doomed").delete()
                        Reminders.schedule(this)
                        val phase=d.optJSONObject("session")?.optString("phase")
                        if(phase in listOf("rest","pending","finished")) Reminders.notify(this,phase!="rest",false)
                        else if(phase!="due") Reminders.clear(this)
                        result.success(null)
                    }
                    "microphoneAccess" -> { if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED) requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO),52);result.success(null) }
                    "appSettings" -> { startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,android.net.Uri.parse("package:$packageName")));result.success(null) }
                    "notifications" -> { if(Build.VERSION.SDK_INT>=33) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),51); result.success(getSystemService(NotificationManager::class.java).areNotificationsEnabled()) }
                    "voices" -> { check(ttsReady) { "Speech engine is still starting. Try again, or use quiet mode." }; result.success(tts!!.voices.orEmpty().filter { !it.isNetworkConnectionRequired && !it.features.orEmpty().contains("notInstalled") }.map { mapOf("name" to it.name,"language" to it.locale.toLanguageTag()) }) }
                    "installVoice" -> { startActivity(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)); result.success(null) }
                    "speak" -> {
                        check(recorder==null && dictation?.running!=true) { "Stop recording or dictation before narration" }
                        check(ttsReady) { "No local speech engine ready. Use text or quiet mode." }
                        check(!getSystemService(AccessibilityManager::class.java).isTouchExplorationEnabled) { "TalkBack is active. Use its reading controls to avoid competing speech." }
                        val voiceName=call.argument<String>("voice")
                        val voice=tts!!.voices.orEmpty().firstOrNull { it.name==voiceName && !it.isNetworkConnectionRequired && !it.features.orEmpty().contains("notInstalled") }
                            ?: throw IllegalStateException("Select an installed offline voice in Settings. Text and quiet mode remain available.")
                        val language=java.util.Locale.forLanguageTag(call.argument<String>("language") ?: "en-IN").language
                        check(voice.locale.language==language) { "Select an offline voice matching the activity language ($language)" }
                        check(requestFocus()) { "Audio is in use; try later" }
                        tts!!.stop(); tts!!.voice=voice
                        tts!!.setSpeechRate((call.argument<Double>("rate") ?: 1.0).toFloat().coerceIn(0.5f,1.5f))
                        val params=Bundle().apply { putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME,(call.argument<Double>("volume") ?: 0.8).toFloat().coerceIn(0f,1f)) }
                        val steps=call.argument<List<Map<String,Any>>>("steps") ?: emptyList()
                        for((i,s) in steps.withIndex()) {
                            // Completion is signalled by the actual session deadline, not narration length.
                            if(s["kind"]=="completion") continue
                            if(s["kind"]=="silence" || s["kind"]=="thinking") tts!!.playSilentUtterance(((s["seconds"] as? Number)?.toLong() ?: 5)*1000,TextToSpeech.QUEUE_ADD,"silence-$i")
                            else tts!!.speak(s["text"] as? String ?: "",TextToSpeech.QUEUE_ADD,params,"step-$i")
                        }
                        result.success(null)
                    }
                    "stopSpeech" -> { tts?.stop(); result.success(null) }
                    "cue" -> { if(call.argument<Boolean>("enabled")==true) { window.decorView.performHapticFeedback(android.view.HapticFeedbackConstants.CONFIRM); val tone=ToneGenerator(AudioManager.STREAM_NOTIFICATION,35); tone.startTone(ToneGenerator.TONE_PROP_ACK,120); handler.postDelayed({tone.release()},250) }; result.success(null) }
                    "record" -> {
                        check(recorder==null && dictation?.running!=true) { "Stop dictation or the current recording first" }
                        if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO),52)
                            result.error("permission","Microphone permission requested. Tap Record again after granting it.",null)
                        } else { startRecording(); result.success(recordingName) }
                    }
                    "stopRecord" -> result.success(finishRecording())
                    "play" -> {
                        val name=call.argument<String>("name")!!; require(name.matches(Regex("[a-f0-9-]{36}\\.m4a")))
                        check(recorder==null); tts?.stop(); player?.release(); check(requestFocus())
                        player=MediaPlayer().apply { setDataSource(File(filesDir,"recordings/$name").path); prepare(); setOnCompletionListener { it.release(); player=null }; start() }; result.success(null)
                    }
                    "stopAudio" -> { dictation?.stop();player?.release(); player=null; tts?.stop(); result.success(null) }
                    "shareText" -> { val text=call.argument<String>("text")!!; require(text.length<=100000); startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,text),"Share selected content")); result.success(null) }
                    "shareAudio" -> {
                        val name=call.argument<String>("name")!!; require(name.matches(Regex("[a-f0-9-]{36}\\.m4a")))
                        val token=UUID.randomUUID().toString(); val directory=File(cacheDir,"shares").apply { mkdirs() }
                        directory.listFiles()?.filter { System.currentTimeMillis()-it.lastModified()>86400000 }?.forEach { it.deleteRecursively() }
                        val dest=File(directory,"$token/voice-note.m4a"); dest.parentFile!!.mkdirs(); File(filesDir,"recordings/$name").copyTo(dest)
                        val uri=android.net.Uri.parse("content://$packageName.share/$token/voice-note.m4a")
                        val send=Intent(Intent.ACTION_SEND).setType("audio/mp4").putExtra(Intent.EXTRA_STREAM,uri).putExtra(Intent.EXTRA_TEXT,call.argument<String>("text") ?: "")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION).apply { clipData=ClipData.newRawUri("Selected voice note",uri) }
                        startActivity(Intent.createChooser(send,"Share selected recording")); result.success(null)
                    }
                    "saveText" -> { fileBytes=call.argument<String>("text")!!.toByteArray(); beginFile(result,Intent(Intent.ACTION_CREATE_DOCUMENT).setType("text/plain").putExtra(Intent.EXTRA_TITLE,"idea.txt"),60) }
                    "saveAudio" -> { val name=call.argument<String>("name")!!; require(name.matches(Regex("[a-f0-9-]{36}\\.m4a"))); fileBytes=File(filesDir,"recordings/$name").readBytes(); beginFile(result,Intent(Intent.ACTION_CREATE_DOCUMENT).setType("audio/mp4").putExtra(Intent.EXTRA_TITLE,"voice-note.m4a"),60) }
                    "backup" -> { check(recorder==null); fileBytes=Backups.make(this,call.argument<Boolean>("audio")==true); beginFile(result,Intent(Intent.ACTION_CREATE_DOCUMENT).setType("application/json").putExtra(Intent.EXTRA_TITLE,"appbreak-backup.json"),60) }
                    "importPack" -> { beginFile(result,Intent(Intent.ACTION_OPEN_DOCUMENT).setType("application/json"),62) }
                    "previewRestore" -> { check(recorder==null); beginFile(result,Intent(Intent.ACTION_OPEN_DOCUMENT).setType("application/json"),61) }
                    "restore" -> { check(recorder==null); val p=restorePreview ?: error("Choose a backup first"); Backups.restore(this,p); restorePreview=null; result.success(null) }
                    "usage" -> result.success(filesDir.walkTopDown().filter { it.isFile }.sumOf { it.length() } + getDatabasePath("companion.db").length())
                    "deleteAll" -> { ActivityCatalog.clear(this); finishRecording(); tts?.stop(); player?.release(); player=null; Store(this).use { it.write(JSONObject().put("schemaVersion",1).put("settings",JSONObject().put("autoSetup",false)),true) }; File(filesDir,"recordings").deleteRecursively(); File(cacheDir,"shares").deleteRecursively(); Reminders.clear(this); Reminders.schedule(this); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch(e:Exception) { result.error("device",e.message ?: "Operation failed",null) }
        }
    }
    private fun requestFocus(): Boolean {
        val manager=getSystemService(AudioManager::class.java)
        audioRequest?.let { manager.abandonAudioFocusRequest(it) }
        val req=AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            .setOnAudioFocusChangeListener { if(it<0) { dictation?.stop();tts?.stop(); player?.pause(); finishRecording() } }.build()
        audioRequest=req; return manager.requestAudioFocus(req)==AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }
    private fun startRecording() {
        val dir=File(filesDir,"recordings").apply { mkdirs() }
        check(dir.usableSpace>10*1024*1024 && dir.walk().filter { it.isFile }.sumOf { it.length() }<100*1024*1024) { "Not enough recording storage (100 MiB limit)" }
        tts?.stop(); player?.release(); player=null; check(requestFocus()) { "Audio is in use" }
        val name=UUID.randomUUID().toString()+".m4a"; val file=File(dir,name)
        @Suppress("DEPRECATION") val r=MediaRecorder()
        try {
            r.setAudioSource(MediaRecorder.AudioSource.MIC); r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC); r.setAudioEncodingBitRate(64000); r.setAudioSamplingRate(22050)
            r.setOutputFile(file.path); r.setMaxDuration(300000); r.setMaxFileSize(5*1024*1024L)
            r.setOnErrorListener { _,_,_ -> finishRecording() }; r.setOnInfoListener { _,what,_ -> if(what==MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED || what==MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED) finishRecording() }
            r.prepare(); r.start(); recorder=r; recordingName=name; recordStarted=SystemClock.elapsedRealtime()
            handler.postDelayed(stopLimit,300000); window.decorView.announceForAccessibility("Recording started. Five minute limit.")
        } catch(e:Exception) { r.release(); file.delete(); throw e }
    }
    private fun finishRecording(): String? {
        val r=recorder ?: return null; recorder=null; handler.removeCallbacks(stopLimit)
        val name=recordingName; recordingName=null; var good=true
        try { r.stop() } catch(_:Exception) { good=false } finally { r.release() }
        if(!good || SystemClock.elapsedRealtime()-recordStarted<400) { File(filesDir,"recordings/$name").delete(); channel?.invokeMethod("recordEnded",mapOf("error" to "Recording was too short or interrupted")); return null }
        // Persist immediately, including when lifecycle or audio interruption stops it.
        try { Store(this).use { store -> val d=store.read(); val notes=d.optJSONArray("ideas") ?: org.json.JSONArray(); notes.put(JSONObject().put("id",UUID.randomUUID().toString()).put("title","Voice idea").put("text","").put("recording",name).put("activity",d.optJSONObject("session")?.opt("activity"))); d.put("ideas",notes); store.write(d) } } catch(e:Exception) { channel?.invokeMethod("recordEnded",mapOf("error" to "Recording file retained, but note could not be saved: ${e.message}")); return null }
        channel?.invokeMethod("recordEnded",mapOf("name" to name)); window.decorView.announceForAccessibility("Recording stopped and saved")
        return name
    }
    private fun beginFile(result:MethodChannel.Result,intent:Intent,request:Int) {
        check(pending==null) { "A file picker is already open" }; pending=result
        try { startActivityForResult(intent.addCategory(Intent.CATEGORY_OPENABLE),request) } catch(e:Exception) { pending=null; fileBytes=null; throw e }
    }
    @Deprecated("Android activity result bridge")
    override fun onActivityResult(requestCode:Int,resultCode:Int,data:Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if(requestCode !in listOf(60,61,62)) return
        val result=pending ?: return; pending=null
        try {
            val uri=data?.data
            if(resultCode!=Activity.RESULT_OK || uri==null) { result.success(null); return }
            if(requestCode==60) { contentResolver.openOutputStream(uri,"wt")!!.use { it.write(fileBytes ?: error("No export")) }; result.success("Saved to selected provider: ${uri.authority}. This may be cloud-backed.") }
            else { val bytes=contentResolver.openInputStream(uri)!!.use { input -> val out=java.io.ByteArrayOutputStream(); val buffer=ByteArray(8192); while(out.size()<=Backups.MAX) { val count=input.read(buffer); if(count<0) break; out.write(buffer,0,count) }; out.toByteArray() }; if(requestCode==62) { require(bytes.size<=1024*1024); result.success(ActivityPacks.validate(JSONObject(String(bytes,Charsets.UTF_8))).toString()); return }; val p=Backups.validate(bytes); restorePreview=p; val d=p.getJSONObject("data"); result.success(mapOf("ideas" to (d.optJSONArray("ideas")?.length() ?: 0),"sessions" to (d.optJSONArray("history")?.length() ?: 0),"provider" to uri.authority)) }
        } catch(e:Exception) { restorePreview=null; result.error("file",e.message,null) } finally { fileBytes=null }
    }
    protected fun configurePopup() {
        if(this !is BreakPopupActivity) return
        // Use the current task bounds, not the physical display: split-screen and
        // freeform windows may occupy only part of it. Never force orientation.
        val width:Int
        val height:Int
        if(Build.VERSION.SDK_INT>=30) {
            val metrics=windowManager.currentWindowMetrics
            val insets=metrics.windowInsets.getInsetsIgnoringVisibility(
                android.view.WindowInsets.Type.systemBars() or android.view.WindowInsets.Type.displayCutout())
            width=(metrics.bounds.width()-insets.left-insets.right).coerceAtLeast(1)
            height=(metrics.bounds.height()-insets.top-insets.bottom).coerceAtLeast(1)
        } else {
            val config=resources.configuration
            val density=resources.displayMetrics.density
            width=(config.screenWidthDp*density).toInt().coerceAtLeast(1)
            height=(config.screenHeightDp*density).toInt().coerceAtLeast(1)
        }
        val expanded=intent?.getBooleanExtra("popupExpanded",false)==true
        val size=PopupSize.calculate(width,height,expanded)
        if(window.attributes.width!=size.first || window.attributes.height!=size.second)
            window.setLayout(size.first,size.second)
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.setDimAmount(0.35f)
    }
    override fun onConfigurationChanged(newConfig:android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        configurePopup()
        window.decorView.post { if(!isFinishing && !isDestroyed) configurePopup() }
    }
    override fun onRequestPermissionsResult(requestCode:Int, permissions:Array<out String>, grantResults:IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        channel?.invokeMethod("permissionsChanged", null)
    }
    override fun onNewIntent(intent:Intent) { super.onNewIntent(intent);setIntent(intent);configurePopup() }
    override fun onResume() { super.onResume(); configurePopup(); Reminders.visible=true; if(Store(this).use { it.read().optJSONObject("session")?.optString("phase") } in listOf(null,"idle")) Reminders.clear(this) }
    override fun onPause() { dictation?.stop();Reminders.visible=false; finishRecording(); tts?.stop(); player?.pause(); super.onPause() }
    override fun onDestroy() { dictation?.stop();getSystemService(AccessibilityManager::class.java).removeTouchExplorationStateChangeListener(screenReaderListener); finishRecording(); tts?.shutdown(); player?.release(); audioRequest?.let { getSystemService(AudioManager::class.java).abandonAudioFocusRequest(it) }; super.onDestroy() }
}

/** Separate floating surface; the normal launcher activity keeps its normal layout. */
class BreakPopupActivity: MainActivity() {
    override fun getBackgroundMode()=io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode.transparent
    override fun onCreate(state:Bundle?) {
        super.onCreate(state)
        setFinishOnTouchOutside(false)
        configurePopup()
    }
}
