// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import org.junit.Assert.*
import org.junit.Test

class SpeechCursorTest {
    @Test fun resumeUsesLatestWordAndAccumulatesRelativeOffsets() {
        val cursor = SpeechCursor(listOf("one two three four", "next"))
        assertEquals("one two three four", cursor.remaining())
        cursor.progress(4)
        assertEquals("two three four", cursor.remaining())
        cursor.progress(4)
        assertEquals("three four", cursor.remaining())
        cursor.next()
        assertEquals("next", cursor.remaining())
        cursor.next()
        assertNull(cursor.remaining())
        cursor.restart()
        assertEquals("one two three four", cursor.remaining())
    }
    @Test fun enginesWithoutRangeCallbacksRepeatOnlyCurrentChunk() {
        val cursor = SpeechCursor(listOf("first", "second"))
        cursor.remaining(); cursor.next()
        assertEquals("second", cursor.remaining())
        assertEquals("second", cursor.remaining())
    }
    @Test fun resumeNeverSplitsSurrogatePair() {
        val cursor = SpeechCursor(listOf("a😀b"))
        cursor.remaining(); cursor.progress(2)
        assertEquals("😀b", cursor.remaining())
    }
}
