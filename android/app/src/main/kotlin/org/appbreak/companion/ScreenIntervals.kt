// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

/** Pure interval accounting; Android adapters supply only timestamp/event-type pairs. */
object ScreenIntervals {
    data class Result(val used:Long,val on:Boolean,val unlocked:Boolean)
    fun count(from:Long,to:Long,initialOn:Boolean,initialUnlocked:Boolean,events:List<Pair<Long,Int>>):Result {
        require(to>=from)
        var on=initialOn;var unlocked=initialUnlocked;var cursor=from;var used=0L
        for((at,type) in events) {
            if(at<cursor || at>to || type !in listOf(15,16,17,18)) continue
            if(on && unlocked) used+=at-cursor
            cursor=at
            when(type) {15->on=true;16->on=false;17->unlocked=false;18->unlocked=true}
        }
        if(on && unlocked)used+=to-cursor
        return Result(used,on,unlocked)
    }
    data class ResetResult(val remaining:Long,val on:Boolean,val unlocked:Boolean,val offSince:Long)
    fun withReset(from:Long,to:Long,initialOn:Boolean,initialUnlocked:Boolean,events:List<Pair<Long,Int>>,remaining:Long,interval:Long,resetMs:Long,offSince:Long):ResetResult {
        require(to>=from && interval>0 && resetMs>0)
        var on=initialOn;var unlocked=initialUnlocked;var cursor=from;var left=remaining;var off=offSince
        fun advance(at:Long) {
            if(on && unlocked) left=(left-(at-cursor)).coerceAtLeast(0)
            if(!on && off>=0 && at-off>=resetMs) left=interval
            cursor=at
        }
        for((at,type) in events) {
            if(at<cursor || at>to || type !in listOf(15,16,17,18)) continue
            advance(at)
            when(type) {15->{on=true;off=-1};16->{if(on || off<0) off=at;on=false};17->unlocked=false;18->unlocked=true}
        }
        advance(to)
        return ResetResult(left,on,unlocked,off)
    }

}
