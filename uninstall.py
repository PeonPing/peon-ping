#!/usr/bin/env python3
"""peon-ping cross-platform uninstaller.

Removes peon hooks and optionally restores notify.sh.
Works on Windows, macOS, and WSL.
"""

import sys
import os
import json
import shutil

HOME = os.path.expanduser("~")
INSTALL_DIR = os.path.join(HOME, ".claude", "hooks", "peon-ping")
SETTINGS = os.path.join(HOME, ".claude", "settings.json")
NOTIFY_BACKUP = os.path.join(HOME, ".claude", "hooks", "notify.sh.backup")
NOTIFY_SH = os.path.join(HOME, ".claude", "hooks", "notify.sh")

def main():
    print("=== peon-ping uninstaller ===")
    print()

    # Remove hook entries from settings.json
    if os.path.isfile(SETTINGS):
        print("Removing peon hooks from settings.json...")
        with open(SETTINGS) as f:
            settings = json.load(f)

        hooks = settings.get("hooks", {})
        events_cleaned = []

        for event in list(hooks.keys()):
            entries = hooks[event]
            original_count = len(entries)
            entries = [
                h for h in entries
                if not any(
                    "peon.sh" in hk.get("command", "") or
                    "peon.py" in hk.get("command", "")
                    for hk in h.get("hooks", [])
                )
            ]
            if len(entries) < original_count:
                events_cleaned.append(event)
            if entries:
                hooks[event] = entries
            else:
                del hooks[event]

        settings["hooks"] = hooks
        with open(SETTINGS, "w") as f:
            json.dump(settings, f, indent=2)
            f.write("\n")

        if events_cleaned:
            print("Removed hooks for: " + ", ".join(events_cleaned))
        else:
            print("No peon hooks found in settings.json")

    # Restore notify.sh backup
    if os.path.isfile(NOTIFY_BACKUP):
        print()
        try:
            reply = input("Restore original notify.sh from backup? [Y/n] ").strip()
        except (EOFError, KeyboardInterrupt):
            reply = "n"

        if reply.lower() != "n":
            # Re-register notify.sh hooks
            if os.path.isfile(SETTINGS):
                with open(SETTINGS) as f:
                    settings = json.load(f)
            else:
                settings = {}

            hooks = settings.setdefault("hooks", {})
            notify_hook = {
                "matcher": "",
                "hooks": [{
                    "type": "command",
                    "command": NOTIFY_SH,
                    "timeout": 10
                }]
            }

            for event in ["SessionStart", "UserPromptSubmit", "Stop", "Notification"]:
                event_hooks = hooks.get(event, [])
                has_notify = any(
                    "notify.sh" in hk.get("command", "")
                    for h in event_hooks
                    for hk in h.get("hooks", [])
                )
                if not has_notify:
                    event_hooks.append(notify_hook)
                hooks[event] = event_hooks

            settings["hooks"] = hooks
            with open(SETTINGS, "w") as f:
                json.dump(settings, f, indent=2)
                f.write("\n")

            print("Restored notify.sh hooks for: SessionStart, UserPromptSubmit, Stop, Notification")
            shutil.copy2(NOTIFY_BACKUP, NOTIFY_SH)
            os.remove(NOTIFY_BACKUP)
            print("notify.sh restored")

    # Remove skill directory
    skill_dir = os.path.join(HOME, ".claude", "skills", "peon-ping-toggle")
    if os.path.isdir(skill_dir):
        shutil.rmtree(skill_dir)
        print("Removed skill: peon-ping-toggle")

    # Remove install directory
    if os.path.isdir(INSTALL_DIR):
        print()
        print(f"Removing {INSTALL_DIR}...")
        shutil.rmtree(INSTALL_DIR)
        print("Removed")

    print()
    print("=== Uninstall complete ===")
    print("Me go now.")

if __name__ == "__main__":
    main()
