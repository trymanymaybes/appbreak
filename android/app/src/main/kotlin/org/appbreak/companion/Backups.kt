// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import android.content.Context
import org.json.JSONObject
import org.json.JSONArray
import java.security.MessageDigest
import java.io.File
import android.util.Base64

object Backups {
    const val MAX = 24 * 1024 * 1024
    private fun hash(s: String) = MessageDigest.getInstance("SHA-256").digest(s.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    fun make(c:Context, includeAudio:Boolean): ByteArray {
        val data=Store(c).use { it.read() }
        data.remove("routineState"); data.remove("session"); data.remove("pendingDelete"); data.remove("revision")
        val audio=JSONObject(); val notes=data.optJSONArray("ideas") ?: JSONArray()
        for(i in 0 until notes.length()) {
            val note=notes.getJSONObject(i); val name=note.optString("recording")
            if(includeAudio && name.matches(Regex("[a-f0-9-]{36}\\.m4a"))) {
                val file=File(c.filesDir,"recordings/$name")
                if(file.exists()) audio.put(name,Base64.encodeToString(file.readBytes(),Base64.NO_WRAP)) else note.put("recording",JSONObject.NULL)
            } else note.put("recording",JSONObject.NULL)
        }
        val payload=JSONObject().put("data",data).put("audio",audio).toString()
        val bytes=JSONObject().put("format","appbreak-backup").put("version",1).put("payload",payload).put("sha256",hash(payload)).toString().toByteArray()
        require(bytes.size<=MAX) { "Backup exceeds 24 MiB; exclude recordings" }
        return bytes
    }
    fun validate(bytes: ByteArray): JSONObject {
        require(bytes.size<=MAX) { "Backup too large" }
        val envelope=JSONObject(String(bytes,Charsets.UTF_8))
        require(envelope.getString("format")=="appbreak-backup" && envelope.getInt("version")==1)
        val raw=envelope.getString("payload"); require(hash(raw)==envelope.getString("sha256")) { "Integrity check failed" }
        val p=JSONObject(raw); val d=p.getJSONObject("data"); require(d.getInt("schemaVersion")==1)
        for(key in listOf("ideas","history")) {
            require(!d.has(key) || d.get(key) is JSONArray) { "Invalid $key array" }; val list=d.optJSONArray(key) ?: JSONArray(); require(list.length()<=10000)
            val seen=mutableSetOf<String>()
            for(i in 0 until list.length()) {
                val item=list.getJSONObject(i); require(item.get("id") is String); val id=item.getString("id"); require(id.length in 1..100 && seen.add(id)) { "Duplicate or invalid IDs" }
                if(key=="ideas") { require(item.get("text") is String && (!item.has("title") || item.get("title") is String)); for(field in listOf("recording","activity","session")) if(!item.isNull(field)) require(item.get(field) is String); require(item.getString("text").length<=100000); require(item.optString("title").length<=200) }
                else { require(item.get("date") is String && item.get("category") is String); require(item.getString("date").matches(Regex("\\d{4}-\\d{2}-\\d{2}"))); require(item.getString("category") in listOf("quiet","movement","breathing","hydration","quiz","imagination")) }
            }
        }
        if(d.has("ideaDraft")) { val draft=d.getJSONObject("ideaDraft");require(draft.get("text") is String && draft.getString("text").length<=100000 && draft.get("title") is String && draft.getString("title").length<=200) }
        require(!d.has("settings") || d.get("settings") is JSONObject); val s=d.optJSONObject("settings") ?: JSONObject()
        for(key in listOf("workSeconds","breakSeconds","activeStart","activeEnd","quietStart","quietEnd","goal")) if(s.has(key)) require(s.get(key) is Int || s.get(key) is Long)
        for(key in listOf("rate","volume")) if(s.has(key)) require(s.get(key) is Number)
        if(s.has("voice")) require(s.get("voice") is String)
        require(s.optInt("workSeconds",1500) in 60..14400 && s.optInt("breakSeconds",60) in 20..300)
        for(key in listOf("activeStart","activeEnd","quietStart","quietEnd")) if(s.has(key)) require(s.getInt(key) in 0..23)
        for(key in listOf("quiet","cues","gamification","activeEnabled","quietHours","popup","focusMode")) if(s.has(key)) require(s.get(key) is Boolean)
        if(s.has("rate")) require(s.getDouble("rate") in 0.5..1.5)
        if(s.has("volume")) require(s.getDouble("volume") in 0.0..1.0)
        if(s.has("goal")) require(s.getInt("goal") in 1..30)
        if(s.has("categories")) { val cats=s.getJSONArray("categories"); for(i in 0 until cats.length()) { require(cats.get(i) is String); require(cats.getString(i) in listOf("quiet","movement","breathing","hydration","quiz","imagination")) } }
        if(s.has("timing")) require(s.get("timing") in listOf("elapsed","screen"))
        if(s.has("profile")) require(s.get("profile") is String)
        if(s.has("dictationLanguage")) require(s.get("dictationLanguage") in listOf("en-IN","hi-IN","kn-IN","ta-IN"))
        if(s.has("profiles")) {
            val profiles=s.getJSONArray("profiles"); require(profiles.length() in 1..20)
            val ids=mutableSetOf<String>()
            for(i in 0 until profiles.length()) {
                val profile=profiles.getJSONObject(i)
                require(profile.get("id") is String && profile.getString("id").matches(Regex("[a-z0-9._-]{1,80}")) && ids.add(profile.getString("id")))
                require(profile.get("name") is String && profile.getString("name").length in 1..100)
                require(profile.get("breakSeconds") is Int && profile.getInt("breakSeconds") in 20..300)
                require(profile.opt("selection") in listOf("rotation","fixed","choose"))
                for(key in listOf("enabled","popup","notifications","repeat","resetByBreak")) if(profile.has(key)) require(profile.get(key) is Boolean)
                if(profile.has("trigger")) require(profile.getString("trigger") in listOf("screen","manual","interval","scheduled"))
                if(profile.has("goalPeriod")) require(profile.getString("goalPeriod") in listOf("daily","weekly"))
                for((key,range) in listOf("workSeconds" to 60..14400,"resetSeconds" to 1..3600,"minuteOfDay" to 0..1439,"startHour" to 0..23,"endHour" to 0..23,"goal" to 0..100)) if(profile.has(key)) require(profile.get(key) is Int && profile.getInt(key) in range)
                if(profile.has("message")) require(profile.get("message") is String && profile.getString("message").length<=200)
                if(profile.has("color")) require(profile.getLong("color") in listOf(0xff356859L,0xff365e9dL,0xff754f84L,0xff89552eL))
                if(profile.has("days")) { val days=profile.getJSONArray("days");require(days.length()<=7);val seenDays=mutableSetOf<Int>();for(j in 0 until days.length()) require(days.get(j) is Int && days.getInt(j) in 1..7 && seenDays.add(days.getInt(j))) }
                if(profile.has("quiet")) require(profile.get("quiet") is Boolean)
                if(profile.has("favourite")) require(profile.get("favourite") is String && profile.getString("favourite").length<=80)
                val cats=profile.getJSONArray("categories");require(cats.length()<=6)
                for(j in 0 until cats.length()) require(cats.get(j) in listOf("quiet","movement","breathing","hydration","quiz","imagination"))
                if(profile.has("disabledActivities")) { val disabled=profile.getJSONArray("disabledActivities");require(disabled.length()<=212);for(j in 0 until disabled.length()) require(disabled.get(j) is String && disabled.getString(j).length<=80) }
            }
            if(s.has("profile")) require(s.getString("profile") in ids)
        }
        if(d.has("customActivities") && d.getJSONArray("customActivities").length()>0) ActivityPacks.validate(JSONObject().put("schemaVersion",1).put("activities",d.getJSONArray("customActivities")))
        val a=p.getJSONObject("audio"); var total=0
        a.keys().forEach { name ->
            require(name.matches(Regex("[a-f0-9-]{36}\\.m4a"))) { "Invalid recording path" }
            val decoded=Base64.decode(a.getString(name),Base64.NO_WRAP); total+=decoded.size
            require(decoded.size<=5*1024*1024 && total<=16*1024*1024)
            require(decoded.size>=12 && String(decoded.copyOfRange(4,8),Charsets.US_ASCII)=="ftyp") { "Not MPEG-4 audio" }
        }
        val notes=d.optJSONArray("ideas") ?: JSONArray()
        for(i in 0 until notes.length()) {
            val note=notes.getJSONObject(i)
            if(!note.isNull("recording")) require(a.has(note.getString("recording"))) { "Missing audio" }
        }
        return p
    }
    fun restore(c:Context,p:JSONObject) {
        // New random file identities avoid overwriting files referenced by old data.
        val dir=File(c.filesDir,"recordings").apply { mkdirs() }
        val staged=mutableListOf<File>(); val mapping=mutableMapOf<String,String>()
        try {
            val a=p.getJSONObject("audio")
            a.keys().forEach { old ->
                val name=java.util.UUID.randomUUID().toString()+".m4a"
                val f=File(dir,name); staged.add(f); f.outputStream().use { it.write(Base64.decode(a.getString(old),Base64.NO_WRAP)); it.fd.sync() }; mapping[old]=name
            }
            val d=p.getJSONObject("data"); d.remove("routineState"); d.remove("session"); d.remove("pendingDelete")
            val notes=d.optJSONArray("ideas") ?: JSONArray()
            for(i in 0 until notes.length()) { val n=notes.getJSONObject(i); if(!n.isNull("recording")) n.put("recording",mapping[n.getString("recording")]) }
            Store(c).use { it.write(d,true) }
        } catch(e:Exception) { staged.forEach { it.delete() }; throw e }
        Reminders.clear(c); Reminders.schedule(c)
        // Orphan cleanup only after successful transaction.
        val keep=mapping.values.toSet(); dir.listFiles()?.filter { it.name !in keep }?.forEach { it.delete() }
    }
}
