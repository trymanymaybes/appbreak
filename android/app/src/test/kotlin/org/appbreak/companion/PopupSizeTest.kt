package org.appbreak.companion
import org.junit.Assert.*
import org.junit.Test

class PopupSizeTest {
    @Test fun rotationUsesNewBounds() {
        assertEquals(Pair(374,630),PopupSize.calculate(390,700,false))
        assertEquals(Pair(672,351),PopupSize.calculate(700,390,false))
    }
    @Test fun expandedStaysInsideTask() {
        assertEquals(Pair(320,240),PopupSize.calculate(320,240,true))
        val compact=PopupSize.calculate(320,240,false)
        assertTrue(compact.first<=320 && compact.second<=240)
    }
    @Test fun transientEmptyBoundsNeverProduceZeroWindow() {
        assertEquals(Pair(1,1),PopupSize.calculate(0,0,false))
    }
}
