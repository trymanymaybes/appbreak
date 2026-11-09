package org.appbreak.companion

/** A missing preference is supplied as enabled by callers; an explicit opt-out wins. */
object PopupPolicy {
    // Unknown foreground state is notification-only when exclusions are configured.
    fun excluded(current: String?, packages: Set<String>): Boolean =
        packages.isNotEmpty() && (current == null || current in packages)

    fun allowed(enabled: Boolean, pausedUntil: Long, now: Long): Boolean =
        enabled && pausedUntil <= now
}
