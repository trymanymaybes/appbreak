# Read aloud

The built-in **Read aloud** activity (`read-aloud.web`, category `read-aloud`)
lets Android users listen to a public HTTPS page using the existing offline TTS
engine. Choose it while browsing break activities, or enable its category in a
routine with at least a 60-second break.

1. Paste a full HTTPS URL and tap **Load page**.
2. Check **Preview extracted text**. Article extraction prefers `article`, then
   `main`, then the page body. Navigation, scripts, forms and hidden elements are
   excluded where identifiable; this is a heuristic, not a guarantee that all
   non-article content is removed.
3. Turn off **Quiet break** and press **Play page** (or the existing
   narration toolbar control). **Pause / Resume** preserves your position;
   **Restart** returns to the beginning and **Stop** ends playback. Existing session deadlines,
   activity changes, audio focus and accessibility restrictions still apply.

Loading never starts speech automatically. The last successfully loaded URL is
stored locally in settings and included in backups. Extracted text stays in memory;
reopen the app and load the page again to fetch it. The original page is requested
directly from the device without browser cookies or an extraction service.
The web page's content is not covered by the activity instructions' CC-BY license.

Supported content: HTML, XHTML and plain text; at most five HTTPS redirects, 2 MiB
response data, 60,000 extracted characters and 25 seconds total download time.
Speech is queued in Unicode-safe chunks below Android TTS's input limit. HTML
`lang` selects the requested language; an appropriate installed offline voice is
required. Pages without language metadata default to English (India).

Not supported: PDFs, audio/video transcription, authenticated/paywalled pages,
JavaScript rendering, restoring playback after process death, or continuing past the break timer.
Some blocked/JavaScript pages return a notice as ordinary HTML; preview it before
playing. Desktop preview can load/display text but does not yet offer narration.

The new category is bundled with this app version only. Do not publish activities
using it into the existing v1 remote catalogue until older clients can be excluded
or a compatible catalogue version is introduced. Earlier app versions reject the
new category and cannot restore backups containing it. The activity schema and
Dart/Android/Python validators have been extended together; existing categories,
activities and bundles remain valid.

## Background playback and controls

Android read-aloud runs in a user-started media-playback foreground service,
independent of the popup/activity lifecycle. Locking the screen or switching apps
keeps reading. The media notification and lock-screen/headset media controls offer
play/pause and stop; the notification also offers restart. No article text is
written to disk or displayed on the lock screen.

Pause releases audio focus and the CPU wake lock. Resume continues at the last
reported word (that word may repeat); engines without range callbacks repeat the
current chunk. Stop and normal completion release the service. Process death does
not automatically restart playback: load the page and press Play again.

The service checks the saved session and its elapsed-time deadline independently
of Flutter. Ending, pausing or changing the break, Quiet mode, and the break deadline
stop playback; pausing narration alone does not pause the break timer. Audio focus
loss, disconnected headphones and TalkBack activation pause narration without an
automatic resume. Wake-lock ownership is limited to active playback with a two-hour
hard safety cap. Ordinary activity narration keeps its existing foreground behavior.

Acceptance checks (real device still required): start a long article, lock for
several minutes, pause/resume from the notification and lock screen, restart/stop,
unplug headphones, interrupt with other audio, change activity, complete the break,
and allow its timer to expire while locked. Verify no speech restarts after stop or
process death and notification actions do not affect the separate break reminder.
