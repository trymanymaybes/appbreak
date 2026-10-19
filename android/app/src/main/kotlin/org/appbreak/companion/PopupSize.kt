package org.appbreak.companion

/** Dimensions are always bounded by the current usable task area. */
object PopupSize {
    fun calculate(width:Int,height:Int,expanded:Boolean):Pair<Int,Int> {
        val w=width.coerceAtLeast(1); val h=height.coerceAtLeast(1)
        return if(expanded) Pair(w,h) else Pair((w*0.96).toInt().coerceAtLeast(1),(h*0.90).toInt().coerceAtLeast(1))
    }
}
