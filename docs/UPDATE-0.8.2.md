# AppBreak 0.8.2

Microphone and read-aloud attention outlines now appear only while in use. Starting recording or playback triggers three gentle pulses followed by a steady active outline. Stopping, pausing or completing use removes the outline without a fresh pulse. Reduced-motion mode shows a steady active outline only.

The popup narration button observes both the Activity speech engine and background read-aloud playback. Foreground status refreshes every 500 ms and after actions; backgrounded UI clears its indication and refreshes on return. Errors do not leave an active indicator. Timers, routines, exclusions and audio playback controls are unchanged.

Validation: Flutter analysis passed and all 130 Flutter tests passed, including inactive rendering, stop during animation, reduced motion, popup playback completion/pause/error and microphone permission handling. Android build, native tests and emulator checks are required before publication. Physical-device acceptance remains outstanding.
