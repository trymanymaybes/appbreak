package org.appbreak.companion

/** A missing preference is supplied as enabled by callers; an explicit opt-out wins. */
object PopupPolicy {
    fun allowed(enabled: Boolean, pausedUntil: Long, now: Long): Boolean =
        enabled && pausedUntil <= now
}
