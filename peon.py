#!/usr/bin/env python3
"""peon-ping: Warcraft III Peon voice lines for Claude Code hooks.

Cross-platform hook script — works on Windows, macOS, and WSL.
Standalone Python replacement for peon.sh.
"""

import sys
import os
import json
import re
import random
import time
import glob
import subprocess
import threading
import tempfile

# --- Platform detection ---

def detect_platform():
    if sys.platform == "win32":
        return "windows"
    elif sys.platform == "darwin":
        return "mac"
    elif sys.platform.startswith("linux"):
        try:
            with open("/proc/version") as f:
                if "microsoft" in f.read().lower():
                    return "wsl"
        except OSError:
            pass
        return "linux"
    return "unknown"

PLATFORM = detect_platform()

PEON_DIR = os.environ.get("CLAUDE_PEON_DIR", os.path.join(os.path.expanduser("~"), ".claude", "hooks", "peon-ping"))
CONFIG = os.path.join(PEON_DIR, "config.json")
STATE = os.path.join(PEON_DIR, ".state.json")
PAUSED_FILE = os.path.join(PEON_DIR, ".paused")

# --- Platform-aware audio playback ---

def play_sound(filepath, volume):
    try:
        if PLATFORM == "mac":
            subprocess.Popen(
                ["afplay", "-v", str(volume), filepath],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        elif PLATFORM == "windows":
            # Native Windows — paths are already Windows-native, no wslpath needed
            wpath = filepath.replace("\\", "/")
            ps_cmd = (
                "Add-Type -AssemblyName PresentationCore; "
                "$p = New-Object System.Windows.Media.MediaPlayer; "
                f"$p.Open([Uri]::new('file:///{wpath}')); "
                f"$p.Volume = {volume}; "
                "Start-Sleep -Milliseconds 200; "
                "$p.Play(); "
                "Start-Sleep -Seconds 3; "
                "$p.Close()"
            )
            subprocess.Popen(
                ["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_cmd],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        elif PLATFORM == "wsl":
            wpath = subprocess.check_output(["wslpath", "-w", filepath], text=True).strip()
            wpath = wpath.replace("\\", "/")
            ps_cmd = (
                "Add-Type -AssemblyName PresentationCore; "
                "$p = New-Object System.Windows.Media.MediaPlayer; "
                f"$p.Open([Uri]::new('file:///{wpath}')); "
                f"$p.Volume = {volume}; "
                "Start-Sleep -Milliseconds 200; "
                "$p.Play(); "
                "Start-Sleep -Seconds 3; "
                "$p.Close()"
            )
            subprocess.Popen(
                ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ps_cmd],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
    except Exception:
        pass

# --- Platform-aware notification ---

def send_notification(msg, title, color="red"):
    def _notify():
        try:
            if PLATFORM == "mac":
                subprocess.Popen(
                    ["osascript", "-e",
                     f'display notification "{msg}" with title "{title}"'],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )
            elif PLATFORM in ("windows", "wsl"):
                color_map = {
                    "red": (180, 0, 0),
                    "blue": (30, 80, 180),
                    "yellow": (200, 160, 0),
                }
                rgb_r, rgb_g, rgb_b = color_map.get(color, (180, 0, 0))

                # Claim a popup slot for vertical stacking
                slot_dir = os.path.join(tempfile.gettempdir(), "peon-ping-popups")
                os.makedirs(slot_dir, exist_ok=True)
                slot = 0
                slot_path = None
                while True:
                    slot_path = os.path.join(slot_dir, f"slot-{slot}")
                    try:
                        os.mkdir(slot_path)
                        break
                    except OSError:
                        slot += 1

                y_offset = 40 + slot * 90
                # Escape single quotes in msg for PowerShell
                safe_msg = msg.replace("'", "''")
                ps_cmd = (
                    "Add-Type -AssemblyName System.Windows.Forms; "
                    "Add-Type -AssemblyName System.Drawing; "
                    "foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) { "
                    "$form = New-Object System.Windows.Forms.Form; "
                    "$form.FormBorderStyle = 'None'; "
                    f"$form.BackColor = [System.Drawing.Color]::FromArgb({rgb_r}, {rgb_g}, {rgb_b}); "
                    "$form.Size = New-Object System.Drawing.Size(500, 80); "
                    "$form.TopMost = $true; "
                    "$form.ShowInTaskbar = $false; "
                    "$form.StartPosition = 'Manual'; "
                    "$form.Location = New-Object System.Drawing.Point("
                    f"($screen.WorkingArea.X + ($screen.WorkingArea.Width - 500) / 2), "
                    f"($screen.WorkingArea.Y + {y_offset})); "
                    "$label = New-Object System.Windows.Forms.Label; "
                    f"$label.Text = '{safe_msg}'; "
                    "$label.ForeColor = [System.Drawing.Color]::White; "
                    "$label.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold); "
                    "$label.TextAlign = 'MiddleCenter'; "
                    "$label.Dock = 'Fill'; "
                    "$form.Controls.Add($label); "
                    "$form.Show() } "
                    "Start-Sleep -Seconds 4; "
                    "[System.Windows.Forms.Application]::Exit()"
                )
                ps_exe = "powershell" if PLATFORM == "windows" else "powershell.exe"
                try:
                    subprocess.run(
                        [ps_exe, "-NoProfile", "-NonInteractive", "-Command", ps_cmd],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                        timeout=10
                    )
                finally:
                    try:
                        os.rmdir(slot_path)
                    except OSError:
                        pass
        except Exception:
            pass

    t = threading.Thread(target=_notify, daemon=True)
    t.start()
    return t

# --- Platform-aware terminal focus check ---

def terminal_is_focused():
    if PLATFORM == "mac":
        try:
            result = subprocess.run(
                ["osascript", "-e",
                 'tell application "System Events" to get name of first process whose frontmost is true'],
                capture_output=True, text=True, timeout=3
            )
            frontmost = result.stdout.strip()
            return frontmost in ("Terminal", "iTerm2", "Warp", "Alacritty", "kitty", "WezTerm", "Ghostty")
        except Exception:
            return False
    # Windows/WSL: checking focus adds too much latency; always notify
    return False

# --- Update check (background, non-blocking) ---

def check_for_updates():
    try:
        check_file = os.path.join(PEON_DIR, ".last_update_check")
        now = int(time.time())
        last_check = 0
        if os.path.exists(check_file):
            try:
                last_check = int(open(check_file).read().strip())
            except (ValueError, OSError):
                pass
        if now - last_check <= 86400:
            return
        with open(check_file, "w") as f:
            f.write(str(now))

        local_version = ""
        version_file = os.path.join(PEON_DIR, "VERSION")
        if os.path.exists(version_file):
            local_version = open(version_file).read().strip()

        import urllib.request
        req = urllib.request.Request(
            "https://raw.githubusercontent.com/tonyyont/peon-ping/main/VERSION",
            headers={"User-Agent": "peon-ping"}
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            remote_version = resp.read().decode().strip()

        update_file = os.path.join(PEON_DIR, ".update_available")
        if remote_version and local_version and remote_version != local_version:
            with open(update_file, "w") as f:
                f.write(remote_version)
        else:
            try:
                os.remove(update_file)
            except OSError:
                pass
    except Exception:
        pass

# --- CLI subcommands ---

def handle_cli():
    if len(sys.argv) < 2:
        return False

    cmd = sys.argv[1]

    if cmd == "--pause":
        open(PAUSED_FILE, "w").close()
        print("peon-ping: sounds paused")
        sys.exit(0)
    elif cmd == "--resume":
        try:
            os.remove(PAUSED_FILE)
        except OSError:
            pass
        print("peon-ping: sounds resumed")
        sys.exit(0)
    elif cmd == "--toggle":
        if os.path.exists(PAUSED_FILE):
            try:
                os.remove(PAUSED_FILE)
            except OSError:
                pass
            print("peon-ping: sounds resumed")
        else:
            open(PAUSED_FILE, "w").close()
            print("peon-ping: sounds paused")
        sys.exit(0)
    elif cmd == "--status":
        if os.path.exists(PAUSED_FILE):
            print("peon-ping: paused")
        else:
            print("peon-ping: active")
        sys.exit(0)
    elif cmd == "--packs":
        try:
            active = json.load(open(CONFIG)).get("active_pack", "peon")
        except Exception:
            active = "peon"
        packs_dir = os.path.join(PEON_DIR, "packs")
        for m in sorted(glob.glob(os.path.join(packs_dir, "*/manifest.json"))):
            info = json.load(open(m))
            name = info.get("name", os.path.basename(os.path.dirname(m)))
            display = info.get("display_name", name)
            marker = " *" if name == active else ""
            print(f"  {name:24s} {display}{marker}")
        sys.exit(0)
    elif cmd == "--pack":
        pack_arg = sys.argv[2] if len(sys.argv) > 2 else ""
        packs_dir = os.path.join(PEON_DIR, "packs")
        names = sorted([
            os.path.basename(os.path.dirname(m))
            for m in glob.glob(os.path.join(packs_dir, "*/manifest.json"))
        ])
        if not pack_arg:
            # Cycle to next pack
            try:
                cfg = json.load(open(CONFIG))
            except Exception:
                cfg = {}
            active = cfg.get("active_pack", "peon")
            if not names:
                print("Error: no packs found", file=sys.stderr)
                sys.exit(1)
            try:
                idx = names.index(active)
                next_pack = names[(idx + 1) % len(names)]
            except ValueError:
                next_pack = names[0]
            cfg["active_pack"] = next_pack
            json.dump(cfg, open(CONFIG, "w"), indent=2)
            mpath = os.path.join(packs_dir, next_pack, "manifest.json")
            display = json.load(open(mpath)).get("display_name", next_pack)
            print(f"peon-ping: switched to {next_pack} ({display})")
        else:
            # Set specific pack
            if pack_arg not in names:
                print(f'Error: pack "{pack_arg}" not found.', file=sys.stderr)
                print(f'Available packs: {", ".join(names)}', file=sys.stderr)
                sys.exit(1)
            try:
                cfg = json.load(open(CONFIG))
            except Exception:
                cfg = {}
            cfg["active_pack"] = pack_arg
            json.dump(cfg, open(CONFIG, "w"), indent=2)
            mpath = os.path.join(packs_dir, pack_arg, "manifest.json")
            display = json.load(open(mpath)).get("display_name", pack_arg)
            print(f"peon-ping: switched to {pack_arg} ({display})")
        sys.exit(0)
    elif cmd in ("--help", "-h"):
        print("""Usage: peon <command>

Commands:
  --pause        Mute sounds
  --resume       Unmute sounds
  --toggle       Toggle mute on/off
  --status       Check if paused or active
  --packs        List available sound packs
  --pack <name>  Switch to a specific pack
  --pack         Cycle to the next pack
  --help         Show this help""")
        sys.exit(0)
    elif cmd.startswith("--"):
        print(f"Unknown option: {cmd}", file=sys.stderr)
        print("Run 'peon --help' for usage.", file=sys.stderr)
        sys.exit(1)

    return False

# --- Core event logic ---

def process_event(input_data):
    paused = os.path.exists(PAUSED_FILE)
    agent_modes = {"delegate"}

    # Load config
    try:
        cfg = json.load(open(CONFIG))
    except Exception:
        cfg = {}

    if str(cfg.get("enabled", True)).lower() == "false":
        return None

    volume = cfg.get("volume", 0.5)
    active_pack = cfg.get("active_pack", "peon")
    pack_rotation = cfg.get("pack_rotation", [])
    annoyed_threshold = int(cfg.get("annoyed_threshold", 3))
    annoyed_window = float(cfg.get("annoyed_window_seconds", 10))
    cats = cfg.get("categories", {})
    cat_enabled = {}
    for c in ["greeting", "acknowledge", "complete", "error", "permission", "resource_limit", "annoyed"]:
        cat_enabled[c] = str(cats.get(c, True)).lower() == "true"

    # Parse event JSON
    event_data = json.loads(input_data)
    event = event_data.get("hook_event_name", "")
    ntype = event_data.get("notification_type", "")
    cwd = event_data.get("cwd", "")
    session_id = event_data.get("session_id", "")
    perm_mode = event_data.get("permission_mode", "")

    # Load state
    try:
        state = json.load(open(STATE))
    except Exception:
        state = {}

    state_dirty = False

    # Agent detection
    agent_sessions = set(state.get("agent_sessions", []))
    if perm_mode and perm_mode in agent_modes:
        agent_sessions.add(session_id)
        state["agent_sessions"] = list(agent_sessions)
        os.makedirs(os.path.dirname(STATE) or ".", exist_ok=True)
        json.dump(state, open(STATE, "w"))
        return None
    elif session_id in agent_sessions:
        return None

    # Pack rotation: pin a random pack per session
    if pack_rotation:
        session_packs = state.get("session_packs", {})
        if session_id in session_packs and session_packs[session_id] in pack_rotation:
            active_pack = session_packs[session_id]
        else:
            active_pack = random.choice(pack_rotation)
            session_packs[session_id] = active_pack
            state["session_packs"] = session_packs
            state_dirty = True

    # Project name — handle both forward and backslash paths
    cwd_normalized = cwd.replace("\\", "/")
    project = cwd_normalized.rsplit("/", 1)[-1] if cwd_normalized else "claude"
    if not project:
        project = "claude"
    project = re.sub(r"[^a-zA-Z0-9 ._-]", "", project)

    # Event routing
    category = ""
    status = ""
    marker = ""
    notify = False
    notify_color = ""
    msg = ""

    if event == "SessionStart":
        category = "greeting"
        status = "ready"
    elif event == "UserPromptSubmit":
        status = "working"
        if cat_enabled.get("annoyed", True):
            all_ts = state.get("prompt_timestamps", {})
            if isinstance(all_ts, list):
                all_ts = {}
            now = time.time()
            ts = [t for t in all_ts.get(session_id, []) if now - t < annoyed_window]
            ts.append(now)
            all_ts[session_id] = ts
            state["prompt_timestamps"] = all_ts
            state_dirty = True
            if len(ts) >= annoyed_threshold:
                category = "annoyed"
    elif event == "Stop":
        category = "complete"
        status = "done"
        marker = "\u25cf "
        notify = True
        notify_color = "blue"
        msg = project + "  \u2014  Task complete"
    elif event == "Notification":
        if ntype == "permission_prompt":
            category = "permission"
            status = "needs approval"
            marker = "\u25cf "
            notify = True
            notify_color = "red"
            msg = project + "  \u2014  Permission needed"
        elif ntype == "idle_prompt":
            status = "done"
            marker = "\u25cf "
            notify = True
            notify_color = "yellow"
            msg = project + "  \u2014  Waiting for input"
        else:
            return None
    elif event == "PermissionRequest":
        category = "permission"
        status = "needs approval"
        marker = "\u25cf "
        notify = True
        notify_color = "red"
        msg = project + "  \u2014  Permission needed"
    else:
        return None

    # Check if category is enabled
    if category and not cat_enabled.get(category, True):
        category = ""

    # Pick sound (skip if no category or paused)
    sound_file = ""
    if category and not paused:
        pack_dir = os.path.join(PEON_DIR, "packs", active_pack)
        try:
            manifest = json.load(open(os.path.join(pack_dir, "manifest.json")))
            sounds = manifest.get("categories", {}).get(category, {}).get("sounds", [])
            if sounds:
                last_played = state.get("last_played", {})
                last_file = last_played.get(category, "")
                candidates = sounds if len(sounds) <= 1 else [s for s in sounds if s["file"] != last_file]
                pick = random.choice(candidates)
                last_played[category] = pick["file"]
                state["last_played"] = last_played
                state_dirty = True
                sound_file = os.path.join(pack_dir, "sounds", pick["file"])
        except Exception:
            pass

    # Write state once
    if state_dirty:
        os.makedirs(os.path.dirname(STATE) or ".", exist_ok=True)
        json.dump(state, open(STATE, "w"))

    return {
        "event": event,
        "volume": volume,
        "project": project,
        "status": status,
        "marker": marker,
        "notify": notify,
        "notify_color": notify_color,
        "msg": msg,
        "sound_file": sound_file,
        "paused": paused,
    }

# --- Main ---

def main():
    # Handle CLI subcommands before reading stdin
    handle_cli()

    # Read hook event from stdin
    input_data = sys.stdin.read()

    result = process_event(input_data)
    if result is None:
        sys.exit(0)

    event = result["event"]
    paused = result["paused"]

    # Check for updates (SessionStart only, background)
    if event == "SessionStart":
        t = threading.Thread(target=check_for_updates, daemon=True)
        t.start()

    # Show update notice (SessionStart only)
    if event == "SessionStart":
        update_file = os.path.join(PEON_DIR, ".update_available")
        if os.path.exists(update_file):
            try:
                new_ver = open(update_file).read().strip()
                cur_ver = ""
                version_file = os.path.join(PEON_DIR, "VERSION")
                if os.path.exists(version_file):
                    cur_ver = open(version_file).read().strip()
                if new_ver:
                    if PLATFORM == "windows":
                        print(f"peon-ping update available: {cur_ver or '?'} \u2192 {new_ver} \u2014 run: python install.py", file=sys.stderr)
                    else:
                        print(f"peon-ping update available: {cur_ver or '?'} \u2192 {new_ver} \u2014 run: curl -fsSL https://raw.githubusercontent.com/tonyyont/peon-ping/main/install.sh | bash", file=sys.stderr)
            except Exception:
                pass

    # Show pause status on SessionStart
    if event == "SessionStart" and paused:
        print("peon-ping: sounds paused \u2014 run 'peon --resume' or '/peon-ping-toggle' to unpause", file=sys.stderr)

    # Set tab title via ANSI escape
    title = f"{result['marker']}{result['project']}: {result['status']}"
    if title:
        sys.stdout.buffer.write(f"\033]0;{title}\007".encode("utf-8"))
        sys.stdout.buffer.flush()

    # Play sound
    sound_file = result["sound_file"]
    if sound_file and os.path.isfile(sound_file):
        play_sound(sound_file, result["volume"])

    # Smart notification: only when terminal is NOT frontmost
    notification_thread = None
    if result["notify"] and not paused:
        if not terminal_is_focused():
            notification_thread = send_notification(result["msg"], title, result["notify_color"] or "red")

    # Wait for notification thread to finish (if any)
    if notification_thread:
        notification_thread.join(timeout=12)

if __name__ == "__main__":
    main()
