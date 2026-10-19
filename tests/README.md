# Targeted native macOS checks

The regular BATS fixtures replace audio and AppleEvents. For notification routing,
`bats tests/mac-notifications.bats` exercises the real `notify.sh` through a local
pseudo-terminal and checks the real Ghostty focus predicate at the AppleEvent
boundary. The external notification sender and queried terminal identity are
controlled; the routing and emitted bytes are real.

To compile and play an actual silent WAV through AVFoundation on a logged-in Mac:

```bash
python3 tests/peon_play_native.py
```

This optional native check needs a working audio output device. It verifies that
the default trailing buffer keeps playback alive after the file, and that SIGTERM
can interrupt even a long tail immediately. It writes only into a temporary
folder and plays silence at volume zero. It does not verify audible Bluetooth
playback or imply that an unavailable Bluetooth device was tested.
