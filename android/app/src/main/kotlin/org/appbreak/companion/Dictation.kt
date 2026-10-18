// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** Explicit on-device service only; never create the network-capable recognizer. */
class Dictation(private val c:Context,private val event:(Map<String,Any>)->Unit) {
    private var engine:SpeechRecognizer?=null
    private var id=""
    private var text=""
    private var saveFailed=false
    private var activity:Any?=null
    private var session:Any?=null
    private val handler=Handler(Looper.getMainLooper())
    private val limit=Runnable { stop() }
    val running get()=engine!=null
    companion object {
        fun available(c:Context)=Build.VERSION.SDK_INT>=31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(c)
    }
    fun start(language:String) {
        check(!running);check(available(c)) { "No on-device recognizer installed. Use Type or record an audio note; no cloud fallback is used." }
        id=UUID.randomUUID().toString();text="";saveFailed=false
        val token=id
        val s=Store(c).use { it.read().optJSONObject("session") };activity=s?.opt("activity");session=s?.opt("id")
        engine=SpeechRecognizer.createOnDeviceSpeechRecognizer(c)
        engine!!.setRecognitionListener(object:RecognitionListener {
            override fun onReadyForSpeech(p:Bundle?) { event(mapOf("status" to "Listening on device", "listening" to true)) }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(r:Float) {}
            override fun onBufferReceived(b:ByteArray?) {} // Audio is intentionally not retained.
            override fun onEndOfSpeech() { event(mapOf("status" to "Finishing transcript", "listening" to true)) }
            override fun onError(code:Int) { if(token!=id || engine==null)return; finish("Dictation stopped (code $code). Any recognized draft was kept. Check the offline language model or use Type.") }
            override fun onResults(results:Bundle?) { if(token!=id || engine==null)return;accept(results);finish("Transcript saved locally. Review and edit in Ideas.") }
            override fun onPartialResults(results:Bundle?) { if(token==id && engine!=null) accept(results) }
            override fun onEvent(type:Int,p:Bundle?) {}
        })
        engine!!.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE,language).putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS,true)
            .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE,true))
        handler.postDelayed(limit,60000)
    }
    private fun accept(b:Bundle?) {
        val next=b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: return
        text=next.take(100000)
        save()
        event(mapOf("text" to text,"listening" to true,"status" to "Draft saved locally"))
    }
    private fun save() {
        if(text.isBlank()) return
        try { Store(c).use { store ->
            val d=store.read();val notes=d.optJSONArray("ideas") ?: JSONArray()
            val note=JSONObject().put("id",id).put("title","Spoken idea").put("text",text).put("activity",activity).put("session",session)
            val index=(0 until notes.length()).firstOrNull { notes.getJSONObject(it).optString("id")==id }
            if(index==null) notes.put(note) else notes.put(index,note)
            d.put("ideas",notes);store.write(d);saveFailed=false
        } } catch(_:Exception) { saveFailed=true;event(mapOf("text" to text,"status" to "Could not save transcript. Copy the visible text before leaving.","listening" to true)) }
    }
    private fun finish(status:String) { handler.removeCallbacks(limit);engine?.destroy();engine=null;event(mapOf("text" to text,"listening" to false,"status" to if(saveFailed) "Save failed. Copy the visible transcript before leaving." else status)) }
    fun stop() { if(!running)return;engine?.cancel();save();finish("Dictation stopped. Recognized draft kept locally.") }
}
