#!/usr/bin/env python3
"""
peon-ping Antigravity watcher — event emitter for antigravity-py.sh

Monitors ~/.gemini/antigravity/conversations/ for .pb file changes
and emits CESP-compatible JSON events to stdout.

This script is a pure event emitter — it does NOT play sounds directly.
The parent shell wrapper (antigravity-py.sh) reads these JSON lines and
pipes each one into peon.sh, which handles sound playback, config,
pack rotation, volume, notifications, etc.

Output format (one JSON object per line):
  {"event": "SessionStart", "session_id": "antigravity-abc12345", "cwd": "/path"}
  {"event": "UserPromptSubmit", "session_id": "antigravity-abc12345", "cwd": "/path"}
  {"event": "Stop", "session_id": "antigravity-abc12345", "cwd": "/path"}

Event mapping:
  New .pb file created        → SessionStart
  IDLE → ACTIVE transition    → UserPromptSubmit  (agent starts working)
  ACTIVE → IDLE (25s silence) → Stop              (agent finished)

Not detectable from filesystem alone:
  task.error, input.required, resource.limit, user.spam
  (would require reading protobuf content or IDE lifecycle hooks)

Requires: Python 3.8+, watchdog

Usage (called by antigravity-py.sh, not directly):
  python3 antigravity-watcher.py [--cwd /path]
"""

import argparse
import json
import os
import sys
import time
import signal
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# --- Paths ---
CONVERSATIONS_DIR = os.path.expanduser("~/.gemini/antigravity/conversations")

# --- Timing ---
# Calibrated to avoid false triggers during tool calls.
# Agents write to .pb files every 1-5s during active work. Tool calls
# and thinking pauses can create 10-15s gaps. 25s of silence means
# the agent is genuinely done, not just thinking.
IDLE_THRESHOLD = float(os.environ.get("ANTIGRAVITY_IDLE_SECONDS", "25"))
CHECK_INTERVAL = 1.0        # how often to poll for completions
PER_GUID_COOLDOWN = 30.0    # min seconds between Stop events per GUID
STARTUP_GRACE = 30.0        # ignore events for this long after startup

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

    New .pb file created   → emit SessionStart      → ACTIVE

    Tool call gaps (5-15s) never cross the 25s threshold,
    so the state stays ACTIVE and no spurious events fire.
    """

    def __init__(self, cwd):
        super().__init__()
        self.cwd = cwd
        self.start_time = time.time()
        # guid → {"state", "last_mod", "last_stop"}
        self.conversations = {}

        # Pre-register existing .pb files as IDLE so we don't
        # false-trigger events on startup
        if os.path.isdir(CONVERSATIONS_DIR):
            for f in os.listdir(CONVERSATIONS_DIR):
                if f.endswith(".pb"):
                    guid = f.replace(".pb", "")
                    self.conversations[guid] = {
                        "state": IDLE,
                        "last_mod": 0,
                        "last_stop": 0,
                    }
            log.info(f"Pre-registered {len(self.conversations)} existing conversations")

    def _in_grace_period(self):
        """Suppress events during the startup grace period."""
        return (time.time() - self.start_time) < STARTUP_GRACE

    def _extract_guid(self, path):
        """Extract conversation GUID from filename (e.g. 'abc123.pb' → 'abc123')."""
        return os.path.basename(path).split(".")[0]

    def _on_file_activity(self, path):
        """Handle any .pb file modification or creation."""
        if not path.endswith(".pb"):
            return

        guid = self._extract_guid(path)
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
    parser = argparse.ArgumentParser(description="Antigravity conversation watcher")
    parser.add_argument("--cwd", default=os.getcwd(), help="Working directory for event payloads")
    args = parser.parse_args()

    # Wait for conversations directory
    if not os.path.isdir(CONVERSATIONS_DIR):
        log.info(f"Waiting for {CONVERSATIONS_DIR}...")
        while not os.path.isdir(CONVERSATIONS_DIR):
            time.sleep(2)

    handler = ConversationWatcher(cwd=args.cwd)

    log.info(f"Watching: {CONVERSATIONS_DIR}")
    log.info(f"Idle threshold: {IDLE_THRESHOLD}s")
    log.info(f"Grace period: {STARTUP_GRACE}s")

    observer = Observer()
    observer.schedule(handler, CONVERSATIONS_DIR, recursive=False)
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
