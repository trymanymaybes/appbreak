package org.appbreak.companion
import org.junit.Assert.*
import org.junit.Test
class PopupPolicyTest {
    @Test fun exclusionsOnlySuppressSelectedOrUnknownApps() {
        assertFalse(PopupPolicy.excluded(null, emptySet()))
        assertTrue(PopupPolicy.excluded("maps", setOf("maps")))
        assertFalse(PopupPolicy.excluded("reader", setOf("maps")))
        assertTrue(PopupPolicy.excluded(null, setOf("maps")))
    }
    @Test fun defaultEnabledAllowsPopup() { assertTrue(PopupPolicy.allowed(true,0,1000)) }
    @Test fun pauseSuppressesUntilExpiry() {
        assertFalse(PopupPolicy.allowed(true,2000,1999))
        assertTrue(PopupPolicy.allowed(true,2000,2000))
    }
    @Test fun optOutWinsAfterPauseExpiry() { assertFalse(PopupPolicy.allowed(false,2000,3000)) }
}
