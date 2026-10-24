package org.appbreak.companion
import android.content.Context
import org.json.*
import java.text.SimpleDateFormat
import java.util.*
object BreakStats {
    fun stamp(record:JSONObject, now:Long=System.currentTimeMillis()):JSONObject = record
        .put("recordedAt",now).put("utcOffsetMinutes",TimeZone.getDefault().getOffset(now)/60000)

    fun metadata(c:Context,d:JSONObject,s:JSONObject):JSONObject {
        val bundled=JSONObject(c.assets.open("flutter_assets/assets/activities.json").bufferedReader().use{it.readText()}).getJSONArray("activities")
        val custom=d.optJSONArray("customActivities") ?: JSONArray();val remote=ActivityCatalog.cached(c)
        val challenges=d.optJSONArray("manyMaybesActivities") ?: JSONArray()
        for(list in listOf(challenges,bundled,custom,remote)) for(i in 0 until list.length()) {
            val a=list.getJSONObject(i);if(a.optString("id")==s.optString("activity")) return a
        }
        val cats=Routines.profile(d,s.optString("routineId")).optJSONArray("categories")
        return JSONObject().put("category",if(cats?.length()==1) cats.getString(0) else "unknown").put("title","Break")
    }
    fun snapshot(c:Context,d:JSONObject,s:JSONObject) {
        val a=metadata(c,d,s)
        if(!s.has("category")) s.put("category",a.optString("category","unknown"))
        if(!s.has("title")) s.put("title",a.optString("title","Break"))
    }
    fun skipped(d:JSONObject,category:String?=null,today:String=SimpleDateFormat("yyyy-MM-dd",Locale.US).format(Date())):Int {
        val completed=d.optJSONArray("history") ?: JSONArray()
        val done=(0 until completed.length()).map{completed.getJSONObject(it).optString("id")}.toSet()
        val list=d.optJSONArray("missedBreaks") ?: JSONArray();val seen=mutableSetOf<String>()
        return (0 until list.length()).count { val r=list.getJSONObject(it);val id=r.optString("id")
            id.isNotEmpty() && id !in done && r.optString("reason")=="skipped" && r.optString("date")==today &&
                (category==null || r.optString("category","unknown")==category) && seen.add(id)
        }
    }
    fun summary(c:Context,d:JSONObject,s:JSONObject):String {
        val category=metadata(c,d,s).optString("category","unknown")
        val total=skipped(d)
        return if(category=="unknown") "$total skipped today" else "${skipped(d,category)} $category skipped today · $total skipped overall today"
    }
}
