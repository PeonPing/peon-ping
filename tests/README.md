# Targeted native macOS checks

The regular BATS fixtures replace audio and AppleEvents. For notification routing,
`bats tests/mac-notifications.bats` exercises the real `notify.sh` through a local
pseudo-terminal and checks the real Ghostty focus predicate at the AppleEvent
boundary. The external notification sender and queried terminal identity are
controlled; the routing and emitted bytes are real. The same targeted BATS file
also runs `sound_concurrency.py`, which forces six local macOS launchers through
the previous PID-read race using long-lived owned audio fixture processes, and
checks that stale or incomplete PID ownership records cannot authorize a signal.

To compile and play an actual silent WAV through AVFoundation on a logged-in Mac:

```bash
python3 tests/peon_play_native.py
```

This optional native check needs a working audio output device. It verifies that
the default trailing buffer keeps playback alive after the file, and that SIGTERM
can interrupt even a long tail immediately. It writes only into a temporary
folder and plays silence at volume zero. It does not verify audible Bluetooth
playback or imply that an unavailable Bluetooth device was tested.

For the complete hook-to-desktop-notification path, run:

```bash
bats tests/ghostty-focus-integration.bats
```

This isolates real hook configuration/state while controlling process-table and
AppleEvent responses. No session TTY is preseeded. It checks focused suppression
with the default sound-focus setting, delivery to a background terminal, and
notification delivery when session identity or Ghostty TTY scripting is unavailable.
The focused case also requires reuse of the hook's single process-table read.
