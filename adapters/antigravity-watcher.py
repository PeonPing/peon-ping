#!/usr/bin/env python3
"""
peon-ping Antigravity watcher — event emitter for antigravity-py.sh

Monitors Antigravity conversation stores for file changes and emits
CESP-compatible JSON events to stdout.

This script is a pure event emitter — it does NOT play sounds directly.
The parent shell wrapper (antigravity-py.sh) reads these JSON lines and
pipes each one into peon.sh, which handles sound playback, config,
pack rotation, volume, notifications, etc.

Output format (one JSON object per line):
  {"event": "SessionStart", "session_id": "antigravity-abc12345", "cwd": "/path"}
  {"event": "UserPromptSubmit", "session_id": "antigravity-abc12345", "cwd": "/path"}
  {"event": "Stop", "session_id": "antigravity-abc12345", "cwd": "/path"}

Event mapping:
  New conversation file       → SessionStart
  IDLE → ACTIVE transition    → UserPromptSubmit  (agent starts working)
  ACTIVE → IDLE (25s silence) → Stop              (agent finished)

Watched layouts:
  ~/.gemini/antigravity/conversations/*.pb
  ~/.gemini/antigravity*/conversations/*.db
  ~/.gemini/antigravity*/brain/<guid>/.system_generated/logs/transcript*.jsonl

Not detectable from filesystem alone:
  task.error, input.required, resource.limit, user.spam
  (would require reading protobuf content or IDE lifecycle hooks)

Requires: Python 3.8+, watchdog

Usage (called by antigravity-py.sh, not directly):
  python3 antigravity-watcher.py [--cwd /path]
"""

import json
import os
import sys
import time
import signal
import logging
from pathlib import Path

try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
    from watchdog.observers.polling import PollingObserver
except ImportError:  # Allow state-machine tests to import without watchdog.
    Observer = None
    PollingObserver = None

    class FileSystemEventHandler:
        pass

# --- Paths ---
HOME = Path.home()
ANTIGRAVITY_DIRS = [
    Path(os.path.expanduser(os.environ.get("ANTIGRAVITY_DIR", "~/.gemini/antigravity"))),
    HOME / ".gemini/antigravity-cli",
    HOME / ".gemini/antigravity-ide",
]

CONVERSATIONS_DIR = os.path.expanduser(
    os.environ.get("ANTIGRAVITY_CONVERSATIONS_DIR", str(ANTIGRAVITY_DIRS[0] / "conversations"))
)
BRAIN_DIR = os.path.expanduser(
    os.environ.get("ANTIGRAVITY_BRAIN_DIR", str(ANTIGRAVITY_DIRS[0] / "brain"))
)

# --- Timing ---
# Calibrated to avoid false triggers during tool calls.
# Agents write to .pb files every 1-5s during active work. Tool calls
# and thinking pauses can create 10-15s gaps. 25s of silence means
# the agent is genuinely done, not just thinking.
IDLE_THRESHOLD = float(os.environ.get("ANTIGRAVITY_IDLE_SECONDS", "25"))
CHECK_INTERVAL = 1.0        # how often to poll for completions
PER_GUID_COOLDOWN = 30.0    # min seconds between Stop events per GUID
STARTUP_GRACE = float(os.environ.get("ANTIGRAVITY_STARTUP_GRACE", "30"))

# --- Logging (to stderr so stdout stays clean for JSON events) ---
logging.basicConfig(
    stream=sys.stderr,
    level=logging.INFO,
    format="%(asctime)s [antigravity-watcher] %(message)s",
    datefmt="%H:%M:%S"
)
log = logging.getLogger("antigravity-watcher")

# --- States ---
IDLE = "idle"
ACTIVE = "active"


def watched_roots():
    """Return existing directories that may contain Antigravity conversation state."""
    candidates = [Path(CONVERSATIONS_DIR), Path(BRAIN_DIR)]
    if not os.environ.get("ANTIGRAVITY_CONVERSATIONS_DIR") and not os.environ.get("ANTIGRAVITY_BRAIN_DIR"):
        for base in ANTIGRAVITY_DIRS:
            candidates.extend([base / "conversations", base / "brain"])

    roots = []
    seen = set()
    for root in candidates:
        expanded = Path(os.path.expanduser(str(root)))
        key = str(expanded)
        if key in seen or not expanded.is_dir():
            continue
        seen.add(key)
        roots.append(expanded)
    return roots


def path_is_watched(path):
    """Return True for files that represent Antigravity conversation activity."""
    path = Path(path)
    if path.suffix in (".pb", ".db"):
        return True
    return path.name.startswith("transcript") and path.suffix == ".jsonl"


def extract_guid(path):
    """Extract conversation GUID from supported Antigravity state file paths."""
    path = Path(path)
    if path.suffix in (".pb", ".db"):
        return path.stem

    if path.name.startswith("transcript") and path.suffix == ".jsonl":
        parts = path.parts
        if "brain" in parts:
            idx = parts.index("brain")
            if idx + 1 < len(parts):
                return parts[idx + 1]

    return ""


def emit_event(event_name, guid, cwd):
    """
    Write a single JSON event line to stdout.
    The parent shell wrapper reads this and pipes it to peon.sh.
    """
    session_id = f"antigravity-{guid[:8]}"
    payload = {
        "event": event_name,
        "session_id": session_id,
        "cwd": cwd,
    }
    # Flush immediately so the shell wrapper sees it without buffering
    print(json.dumps(payload), flush=True)


class ConversationWatcher(FileSystemEventHandler):
    """
    Tracks ALL conversations with a two-state machine each.

    IDLE   → file modified → emit UserPromptSubmit → ACTIVE
    ACTIVE → file modified → update timestamp (no event)
    ACTIVE → 25s silence   → emit Stop             → IDLE

    New state file created → emit SessionStart      → ACTIVE

    Tool call gaps (5-15s) never cross the 25s threshold,
    so the state stays ACTIVE and no spurious events fire.
    """

    def __init__(self, cwd):
        super().__init__()
        self.cwd = cwd
        self.start_time = time.time()
        # guid → {"state", "last_mod", "last_stop"}
        self.conversations = {}

        # Pre-register existing files as IDLE so we don't
        # false-trigger events on startup
        for root in watched_roots():
            for path in root.rglob("*"):
                if not path.is_file() or not path_is_watched(path):
                    continue
                guid = extract_guid(path)
                if not guid:
                    continue
                self.conversations[guid] = {
                    "state": IDLE,
                    "last_mod": 0,
                    "last_stop": 0,
                }
        log.info(f"Pre-registered {len(self.conversations)} existing conversations")

    def _in_grace_period(self):
        """Suppress events during the startup grace period."""
        return (time.time() - self.start_time) < STARTUP_GRACE

    def _on_file_activity(self, path):
        """Handle any supported conversation file modification or creation."""
        if not path_is_watched(path):
            return

        guid = extract_guid(path)
        if not guid:
            return

        now = time.time()

        if guid not in self.conversations:
            # Brand new conversation — genuine session.start
            self.conversations[guid] = {
                "state": ACTIVE,
                "last_mod": now,
                "last_stop": 0,
            }
            if not self._in_grace_period():
                log.info(f"New session: {guid[:8]}")
                emit_event("SessionStart", guid, self.cwd)
            return

        conv = self.conversations[guid]

        if conv["state"] == IDLE:
            # IDLE → ACTIVE: user sent a new message
            conv["state"] = ACTIVE
            conv["last_mod"] = now
            if not self._in_grace_period():
                log.info(f"Agent activated: {guid[:8]}")
                emit_event("UserPromptSubmit", guid, self.cwd)

        elif conv["state"] == ACTIVE:
            # Still working — just update the timestamp
            conv["last_mod"] = now

    def on_modified(self, event):
        if not event.is_directory:
            self._on_file_activity(event.src_path)

    def on_created(self, event):
        if not event.is_directory:
            self._on_file_activity(event.src_path)

    def check_completions(self):
        """Poll all ACTIVE conversations for idle timeout → completion."""
        now = time.time()

        for guid, conv in self.conversations.items():
            if conv["state"] != ACTIVE:
                continue
            if conv["last_mod"] == 0:
                continue

            elapsed = now - conv["last_mod"]
            if elapsed < IDLE_THRESHOLD:
                continue

            # Per-GUID cooldown — don't spam for the same agent
            since_last = now - conv["last_stop"]
            if since_last < PER_GUID_COOLDOWN:
                conv["state"] = IDLE
                continue

            # ACTIVE → IDLE with Stop event
            conv["state"] = IDLE
            if not self._in_grace_period():
                log.info(f"Agent done: {guid[:8]} (silent {elapsed:.0f}s)")
                emit_event("Stop", guid, self.cwd)
                conv["last_stop"] = now


def main():
    if Observer is None:
        log.error("Python 'watchdog' module not found. Install it: pip3 install watchdog")
        return 1

    cwd = os.getcwd()
    if "--cwd" in sys.argv:
        idx = sys.argv.index("--cwd")
        if idx + 1 < len(sys.argv):
            cwd = sys.argv[idx + 1]

    roots = watched_roots()
    if not roots:
        expected = ", ".join(str(p) for base in ANTIGRAVITY_DIRS for p in (base / "conversations", base / "brain"))
        log.info(f"Waiting for Antigravity conversation state directories: {expected}")
        while not roots:
            time.sleep(2)
            roots = watched_roots()

    handler = ConversationWatcher(cwd=cwd)

    log.info("Watching: " + ", ".join(str(root) for root in roots))
    log.info(f"Idle threshold: {IDLE_THRESHOLD}s")
    log.info(f"Grace period: {STARTUP_GRACE}s")

    observer_kind = os.environ.get("ANTIGRAVITY_OBSERVER", "").strip().lower()
    if observer_kind == "polling":
        observer = PollingObserver(timeout=CHECK_INTERVAL)
        log.info("Observer: polling")
    else:
        observer = Observer()
        log.info("Observer: native")

    for root in roots:
        observer.schedule(handler, str(root), recursive=True)
    observer.start()

    def shutdown(signum, frame):
        log.info("Shutting down...")
        observer.stop()
        observer.join()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    try:
        while True:
            time.sleep(CHECK_INTERVAL)
            handler.check_completions()
    except KeyboardInterrupt:
        shutdown(None, None)


if __name__ == "__main__":
    main()
