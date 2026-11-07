// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

/** Range callbacks are relative to the current utterance, including after resume. */
internal class SpeechCursor(private val chunks: List<String>) {
    private var index = 0
    private var offset = 0
    private var utteranceOffset = 0
    fun remaining(): String? {
        val text = chunks.getOrNull(index) ?: return null
        utteranceOffset = offset
        return text.substring(offset)
    }
    fun progress(start: Int) {
        val text = chunks.getOrNull(index) ?: return
        var position = (utteranceOffset + start).coerceIn(0, text.length)
        if (position in 1 until text.length && Character.isLowSurrogate(text[position]) && Character.isHighSurrogate(text[position - 1])) position--
        offset = position
    }
    fun next() { index++; offset = 0; utteranceOffset = 0 }
    fun restart() { index = 0; offset = 0; utteranceOffset = 0 }
}
