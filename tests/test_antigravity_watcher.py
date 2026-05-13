#!/usr/bin/env python3
"""
Smoke tests for antigravity-watcher.py

Verifies the ConversationWatcher state machine, event emission,
cooldown enforcement, and startup grace period logic.

Run: python3 tests/test_antigravity_watcher.py
  or: python3 -m pytest tests/test_antigravity_watcher.py -v
"""

import json
import os
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from io import StringIO

# Add the adapters directory to the path so we can import the watcher
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "adapters"))


class TestEmitEvent(unittest.TestCase):
    """Verify JSON event output format."""

    def test_emit_event_produces_valid_json(self):
        """emit_event should write a single valid JSON line to stdout."""
        # Import here so path setup above takes effect
        from importlib import import_module
        watcher_mod = import_module("antigravity-watcher")

        captured = StringIO()
        with patch("sys.stdout", captured):
            watcher_mod.emit_event("Stop", "abc12345-full-guid", "/tmp/test")

        line = captured.getvalue().strip()
        data = json.loads(line)

        self.assertEqual(data["event"], "Stop")
        # session_id uses first 8 chars of GUID
        self.assertEqual(data["session_id"], "antigravity-abc12345")
        self.assertEqual(data["cwd"], "/tmp/test")

    def test_emit_event_session_start(self):
        """SessionStart event should have correct structure."""
        from importlib import import_module
        watcher_mod = import_module("antigravity-watcher")

        captured = StringIO()
        with patch("sys.stdout", captured):
            watcher_mod.emit_event("SessionStart", "deadbeef-1234", "/home/user")

        data = json.loads(captured.getvalue().strip())
        self.assertEqual(data["event"], "SessionStart")
        self.assertEqual(data["session_id"], "antigravity-deadbeef")


class TestConversationWatcher(unittest.TestCase):
    """Verify the per-GUID state machine logic."""

    def setUp(self):
        """Create a temp conversations directory."""
        self.tmpdir = tempfile.mkdtemp()
        self.orig_dir = os.environ.get("ANTIGRAVITY_CONVERSATIONS_DIR")

        # Patch the module-level constant
        from importlib import import_module
        self.watcher_mod = import_module("antigravity-watcher")
        self._orig_conv_dir = self.watcher_mod.CONVERSATIONS_DIR
        self.watcher_mod.CONVERSATIONS_DIR = self.tmpdir

    def tearDown(self):
        self.watcher_mod.CONVERSATIONS_DIR = self._orig_conv_dir
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def _create_watcher(self, grace=0):
        """Create a ConversationWatcher with configurable grace period."""
        handler = self.watcher_mod.ConversationWatcher(cwd="/tmp/test")
        # Override startup grace to zero for immediate testing
        handler.start_time = time.time() - grace - 1
        return handler

    def test_new_conversation_emits_session_start(self):
        """A new .pb file should emit SessionStart."""
        handler = self._create_watcher(grace=30)

        events = []
        with patch.object(self.watcher_mod, "emit_event", side_effect=lambda *a: events.append(a)):
            # Simulate a new .pb file creation
            guid = "test-guid-001"
            pb_path = os.path.join(self.tmpdir, f"{guid}.pb")
            open(pb_path, "w").close()

            handler._on_file_activity(pb_path)

        # Should have emitted SessionStart
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0][0], "SessionStart")
        self.assertEqual(events[0][1], guid)

    def test_known_idle_guid_emits_prompt_submit(self):
        """An IDLE → ACTIVE transition should emit UserPromptSubmit."""
        handler = self._create_watcher(grace=30)

        guid = "test-guid-002"
        pb_path = os.path.join(self.tmpdir, f"{guid}.pb")
        open(pb_path, "w").close()

        # Pre-register as idle
        handler.conversations[guid] = {
            "state": "idle",
            "last_mod": 0,
            "last_stop": 0,
        }

        events = []
        with patch.object(self.watcher_mod, "emit_event", side_effect=lambda *a: events.append(a)):
            handler._on_file_activity(pb_path)

        self.assertEqual(len(events), 1)
        self.assertEqual(events[0][0], "UserPromptSubmit")

    def test_active_guid_no_event(self):
        """An ACTIVE → ACTIVE modification should NOT emit any event."""
        handler = self._create_watcher(grace=30)

        guid = "test-guid-003"
        pb_path = os.path.join(self.tmpdir, f"{guid}.pb")
        open(pb_path, "w").close()

        handler.conversations[guid] = {
            "state": "active",
            "last_mod": time.time(),
            "last_stop": 0,
        }

        events = []
        with patch.object(self.watcher_mod, "emit_event", side_effect=lambda *a: events.append(a)):
            handler._on_file_activity(pb_path)

        self.assertEqual(len(events), 0)

    def test_idle_timeout_emits_stop(self):
        """ACTIVE conversation past idle threshold should emit Stop."""
        handler = self._create_watcher(grace=30)

        guid = "test-guid-004"
        handler.conversations[guid] = {
            "state": "active",
            "last_mod": time.time() - 30,  # 30s ago, past the 25s default
            "last_stop": 0,
        }

        events = []
        with patch.object(self.watcher_mod, "emit_event", side_effect=lambda *a: events.append(a)):
            handler.check_completions()

        self.assertEqual(len(events), 1)
        self.assertEqual(events[0][0], "Stop")
        # State should be idle now
        self.assertEqual(handler.conversations[guid]["state"], "idle")

    def test_cooldown_suppresses_duplicate_stop(self):
        """Stop should be suppressed if within per-GUID cooldown."""
        handler = self._create_watcher(grace=30)

        guid = "test-guid-005"
        handler.conversations[guid] = {
            "state": "active",
            "last_mod": time.time() - 30,
            "last_stop": time.time() - 5,  # 5s ago, within 30s cooldown
        }

        events = []
        with patch.object(self.watcher_mod, "emit_event", side_effect=lambda *a: events.append(a)):
            handler.check_completions()

        # No Stop event due to cooldown
        self.assertEqual(len(events), 0)
        # But state should still transition to idle
        self.assertEqual(handler.conversations[guid]["state"], "idle")

    def test_startup_grace_suppresses_events(self):
        """Events during startup grace period should be suppressed."""
        handler = self.watcher_mod.ConversationWatcher(cwd="/tmp/test")
        # Do NOT override start_time — grace is active

        guid = "test-guid-006"
        pb_path = os.path.join(self.tmpdir, f"{guid}.pb")
        open(pb_path, "w").close()

        events = []
        with patch.object(self.watcher_mod, "emit_event", side_effect=lambda *a: events.append(a)):
            handler._on_file_activity(pb_path)

        # No event during grace period
        self.assertEqual(len(events), 0)
        # But the conversation should still be registered
        self.assertIn(guid, handler.conversations)

    def test_pre_registers_existing_pb_files(self):
        """Existing .pb files at startup should be pre-registered as idle."""
        guid = "existing-guid-007"
        pb_path = os.path.join(self.tmpdir, f"{guid}.pb")
        open(pb_path, "w").close()

        handler = self._create_watcher(grace=30)

        self.assertIn(guid, handler.conversations)
        self.assertEqual(handler.conversations[guid]["state"], "idle")

    def test_non_pb_files_ignored(self):
        """Non-.pb files should be completely ignored."""
        handler = self._create_watcher(grace=30)

        events = []
        with patch.object(self.watcher_mod, "emit_event", side_effect=lambda *a: events.append(a)):
            handler._on_file_activity("/tmp/not-a-proto.txt")

        self.assertEqual(len(events), 0)


if __name__ == "__main__":
    unittest.main()
