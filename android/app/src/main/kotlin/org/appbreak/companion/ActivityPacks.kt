// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion
import org.json.JSONObject
object ActivityPacks {
    fun validate(pack:JSONObject):JSONObject {
        require(pack.get("schemaVersion") is Int && pack.getInt("schemaVersion")==1)
        val list=pack.getJSONArray("activities"); require(list.length() in 1..200)
        val ids=mutableSetOf<String>()
        for(i in 0 until list.length()) {
            val a=list.getJSONObject(i); require(a.get("schemaVersion") is Int && a.getInt("schemaVersion")==1)
            for(key in listOf("id","category","title","language","description","author","attribution","contentLicense")) require(a.get(key) is String)
            require(a.get("estimatedSeconds") is Int)
            require(a.getString("id").matches(Regex("[a-z0-9._-]{1,80}")) && ids.add(a.getString("id")))
            require(a.getString("category") in listOf("quiet","movement","breathing","hydration","quiz","imagination"))
            require(a.getInt("estimatedSeconds") in 20..300)
            for(key in listOf("title","language","description","author","attribution","contentLicense")) require(a.getString(key).length in 1..2000)
            require(a.get("requiresVisualAttention") is Boolean && a.get("requiresInput") is Boolean)
            val alternatives=a.getJSONArray("accessibleAlternatives"); require(alternatives.length() in 1..20)
            for(j in 0 until alternatives.length()) require(alternatives.get(j) is String && alternatives.getString(j).length in 1..2000)
            val steps=a.getJSONArray("steps"); require(steps.length() in 1..30)
            var silence=0
            for(j in 0 until steps.length()) {
                val step=steps.getJSONObject(j); require(step.get("kind") is String)
                require(step.getString("kind") in listOf("instruction","narration","silence","thinking","completion"))
                if(step.getString("kind") in listOf("silence","thinking")) { require(step.get("seconds") is Int); val time=step.getInt("seconds");require(time in 1..300);silence+=time }
                else require(step.get("text") is String && step.getString("text").length in 1..2000)
            }
            require(silence<=a.getInt("estimatedSeconds"))
            for(key in listOf("answer","reflectionQuestion")) if(a.has(key)) require(a.get(key) is String && a.getString(key).length<=2000)
        }
        return pack
    }
}
