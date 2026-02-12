#!/usr/bin/env python3
"""peon-ping cross-platform installer.

Works on Windows (natively), macOS, and WSL.
Python port of install.sh — no external dependencies required.
"""

import sys
import os
import json
import glob
import shutil
import subprocess

# --- Constants ---

REPO_BASE = "https://raw.githubusercontent.com/tonyyont/peon-ping/main"
PACKS = "peon peon_fr peon_pl peasant peasant_fr ra2_soviet_engineer sc_battlecruiser sc_kerrigan".split()

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
HOME = os.path.expanduser("~")
INSTALL_DIR = os.path.join(HOME, ".claude", "hooks", "peon-ping")
SETTINGS = os.path.join(HOME, ".claude", "settings.json")

# --- Helpers ---

def download_file(url, dest):
    import urllib.request
    req = urllib.request.Request(url, headers={"User-Agent": "peon-ping-installer"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        with open(dest, "wb") as f:
            f.write(resp.read())

def detect_script_dir():
    """Detect if running from a local clone."""
    script_path = os.path.abspath(__file__)
    candidate = os.path.dirname(script_path)
    if os.path.isfile(os.path.join(candidate, "peon.sh")):
        return candidate
    return None

# --- Main installer ---

def main():
    print("=== peon-ping installer ===")
    print()

    # Detect update vs fresh install
    updating = os.path.isfile(os.path.join(INSTALL_DIR, "peon.sh")) or os.path.isfile(os.path.join(INSTALL_DIR, "peon.py"))
    if updating:
        print("Existing install found. Updating...")
    else:
        print()

    # Prerequisites
    if PLATFORM not in ("mac", "wsl", "windows"):
        print("Error: peon-ping requires macOS, WSL, or Windows")
        sys.exit(1)

    if PLATFORM == "mac":
        if shutil.which("afplay") is None:
            print("Error: afplay is required (should be built into macOS)")
            sys.exit(1)
    elif PLATFORM == "wsl":
        if shutil.which("powershell.exe") is None:
            print("Error: powershell.exe is required (should be available in WSL)")
            sys.exit(1)
        if shutil.which("wslpath") is None:
            print("Error: wslpath is required (should be built into WSL)")
            sys.exit(1)
    elif PLATFORM == "windows":
        if shutil.which("powershell") is None:
            print("Error: powershell is required (should be built into Windows)")
            sys.exit(1)

    claude_dir = os.path.join(HOME, ".claude")
    if not os.path.isdir(claude_dir):
        print("Error: ~/.claude/ not found. Is Claude Code installed?")
        sys.exit(1)

    # Detect local clone vs remote
    script_dir = detect_script_dir()

    # Create pack directories
    for pack in PACKS:
        os.makedirs(os.path.join(INSTALL_DIR, "packs", pack, "sounds"), exist_ok=True)

    # Core files to copy/download
    core_files = ["peon.sh", "peon.py", "completions.bash", "VERSION", "uninstall.sh", "uninstall.py", "install.py"]

    if script_dir:
        # Local clone — copy files directly
        # Copy packs
        src_packs = os.path.join(script_dir, "packs")
        if os.path.isdir(src_packs):
            for pack in PACKS:
                src_pack = os.path.join(src_packs, pack)
                dst_pack = os.path.join(INSTALL_DIR, "packs", pack)
                if os.path.isdir(src_pack):
                    # Copy manifest and sounds
                    for item in os.listdir(src_pack):
                        src_item = os.path.join(src_pack, item)
                        dst_item = os.path.join(dst_pack, item)
                        if os.path.isdir(src_item):
                            if os.path.exists(dst_item):
                                shutil.rmtree(dst_item)
                            shutil.copytree(src_item, dst_item)
                        else:
                            shutil.copy2(src_item, dst_item)

        # Copy core files
        for fname in core_files:
            src = os.path.join(script_dir, fname)
            if os.path.isfile(src):
                shutil.copy2(src, os.path.join(INSTALL_DIR, fname))

        # Copy config only on fresh install
        if not updating:
            src_config = os.path.join(script_dir, "config.json")
            if os.path.isfile(src_config):
                shutil.copy2(src_config, os.path.join(INSTALL_DIR, "config.json"))
    else:
        # Download from GitHub
        print("Downloading from GitHub...")
        for fname in core_files:
            try:
                download_file(f"{REPO_BASE}/{fname}", os.path.join(INSTALL_DIR, fname))
            except Exception as e:
                print(f"Warning: could not download {fname}: {e}")

        # Download pack manifests and sounds
        for pack in PACKS:
            manifest_path = os.path.join(INSTALL_DIR, "packs", pack, "manifest.json")
            try:
                download_file(f"{REPO_BASE}/packs/{pack}/manifest.json", manifest_path)
            except Exception as e:
                print(f"Warning: could not download {pack}/manifest.json: {e}")
                continue

            # Download sound files referenced in manifest
            try:
                manifest = json.load(open(manifest_path))
                seen = set()
                for cat in manifest.get("categories", {}).values():
                    for s in cat.get("sounds", []):
                        fname = s["file"]
                        if fname not in seen:
                            seen.add(fname)
                            try:
                                download_file(
                                    f"{REPO_BASE}/packs/{pack}/sounds/{fname}",
                                    os.path.join(INSTALL_DIR, "packs", pack, "sounds", fname)
                                )
                            except Exception:
                                pass
            except Exception:
                pass

        # Download config only on fresh install
        if not updating:
            try:
                download_file(f"{REPO_BASE}/config.json", os.path.join(INSTALL_DIR, "config.json"))
            except Exception:
                pass

    # Make peon.sh executable (macOS/WSL)
    peon_sh = os.path.join(INSTALL_DIR, "peon.sh")
    if os.path.isfile(peon_sh) and PLATFORM != "windows":
        os.chmod(peon_sh, 0o755)

    # Install skill (slash command)
    skill_dir = os.path.join(HOME, ".claude", "skills", "peon-ping-toggle")
    os.makedirs(skill_dir, exist_ok=True)
    if script_dir:
        src_skill = os.path.join(script_dir, "skills", "peon-ping-toggle", "SKILL.md")
        if os.path.isfile(src_skill):
            shutil.copy2(src_skill, os.path.join(skill_dir, "SKILL.md"))
    else:
        try:
            download_file(f"{REPO_BASE}/skills/peon-ping-toggle/SKILL.md", os.path.join(skill_dir, "SKILL.md"))
        except Exception:
            print("Warning: could not download SKILL.md")

    # Add shell alias / Windows cmd alias
    if PLATFORM == "windows":
        # Create peon.cmd in install dir
        peon_py_path = os.path.join(INSTALL_DIR, "peon.py")
        peon_cmd_path = os.path.join(INSTALL_DIR, "peon.cmd")
        with open(peon_cmd_path, "w") as f:
            f.write(f'@python "{peon_py_path}" %*\n')
        print(f"Created peon.cmd at {peon_cmd_path}")
        print(f"  Add {INSTALL_DIR} to your PATH to use 'peon' from any terminal.")
    else:
        alias_line = 'alias peon="bash ~/.claude/hooks/peon-ping/peon.sh"'
        for rcfile_path in [os.path.join(HOME, ".zshrc"), os.path.join(HOME, ".bashrc")]:
            if os.path.isfile(rcfile_path):
                content = open(rcfile_path).read()
                if "alias peon=" not in content:
                    with open(rcfile_path, "a") as f:
                        f.write("\n# peon-ping quick controls\n")
                        f.write(alias_line + "\n")
                    print(f"Added peon alias to {os.path.basename(rcfile_path)}")

        # Add tab completion
        completion_line = '[ -f ~/.claude/hooks/peon-ping/completions.bash ] && source ~/.claude/hooks/peon-ping/completions.bash'
        for rcfile_path in [os.path.join(HOME, ".zshrc"), os.path.join(HOME, ".bashrc")]:
            if os.path.isfile(rcfile_path):
                content = open(rcfile_path).read()
                if "peon-ping/completions.bash" not in content:
                    with open(rcfile_path, "a") as f:
                        f.write(completion_line + "\n")
                    print(f"Added tab completion to {os.path.basename(rcfile_path)}")

    # Verify sounds are installed
    print()
    for pack in PACKS:
        sound_dir = os.path.join(INSTALL_DIR, "packs", pack, "sounds")
        sound_files = (
            glob.glob(os.path.join(sound_dir, "*.wav")) +
            glob.glob(os.path.join(sound_dir, "*.mp3")) +
            glob.glob(os.path.join(sound_dir, "*.ogg"))
        )
        if not sound_files:
            print(f"[{pack}] Warning: No sound files found!")
        else:
            print(f"[{pack}] {len(sound_files)} sound files installed.")

    # Backup existing notify.sh (fresh install only)
    if not updating:
        notify_sh = os.path.join(HOME, ".claude", "hooks", "notify.sh")
        if os.path.isfile(notify_sh):
            shutil.copy2(notify_sh, notify_sh + ".backup")
            print()
            print("Backed up notify.sh -> notify.sh.backup")

    # Update settings.json
    print()
    print("Updating Claude Code hooks in settings.json...")

    if os.path.isfile(SETTINGS):
        with open(SETTINGS) as f:
            settings = json.load(f)
    else:
        settings = {}

    hooks = settings.setdefault("hooks", {})

    # Determine hook command based on platform
    if PLATFORM == "windows":
        peon_py_path = os.path.join(INSTALL_DIR, "peon.py")
        hook_cmd = f"python {peon_py_path}"
    else:
        hook_cmd = os.path.expanduser("~/.claude/hooks/peon-ping/peon.sh")

    peon_hook = {
        "type": "command",
        "command": hook_cmd,
        "timeout": 10
    }
    peon_entry = {
        "matcher": "",
        "hooks": [peon_hook]
    }

    events = ["SessionStart", "UserPromptSubmit", "Stop", "Notification", "PermissionRequest"]
    for event in events:
        event_hooks = hooks.get(event, [])
        # Remove any existing notify.sh, peon.sh, or peon.py entries
        event_hooks = [
            h for h in event_hooks
            if not any(
                "notify.sh" in hk.get("command", "") or
                "peon.sh" in hk.get("command", "") or
                "peon.py" in hk.get("command", "")
                for hk in h.get("hooks", [])
            )
        ]
        event_hooks.append(peon_entry)
        hooks[event] = event_hooks

    settings["hooks"] = hooks
    with open(SETTINGS, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")

    print("Hooks registered for: " + ", ".join(events))

    # Initialize state (fresh install only)
    if not updating:
        state_file = os.path.join(INSTALL_DIR, ".state.json")
        with open(state_file, "w") as f:
            f.write("{}")

    # Test sound
    print()
    print("Testing sound...")
    try:
        cfg = json.load(open(os.path.join(INSTALL_DIR, "config.json")))
        active_pack = cfg.get("active_pack", "peon")
    except Exception:
        active_pack = "peon"

    pack_dir = os.path.join(INSTALL_DIR, "packs", active_pack)
    test_sounds = (
        glob.glob(os.path.join(pack_dir, "sounds", "*.wav")) +
        glob.glob(os.path.join(pack_dir, "sounds", "*.mp3")) +
        glob.glob(os.path.join(pack_dir, "sounds", "*.ogg"))
    )
    if test_sounds:
        test_sound = test_sounds[0]
        try:
            if PLATFORM == "mac":
                subprocess.run(["afplay", "-v", "0.3", test_sound], timeout=10)
            elif PLATFORM == "windows":
                wpath = test_sound.replace("\\", "/")
                ps_cmd = (
                    "Add-Type -AssemblyName PresentationCore; "
                    "$p = New-Object System.Windows.Media.MediaPlayer; "
                    f"$p.Open([Uri]::new('file:///{wpath}')); "
                    "$p.Volume = 0.3; "
                    "Start-Sleep -Milliseconds 200; "
                    "$p.Play(); "
                    "Start-Sleep -Seconds 3; "
                    "$p.Close()"
                )
                subprocess.run(
                    ["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_cmd],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10
                )
            elif PLATFORM == "wsl":
                wpath = subprocess.check_output(["wslpath", "-w", test_sound], text=True).strip()
                wpath = wpath.replace("\\", "/")
                ps_cmd = (
                    "Add-Type -AssemblyName PresentationCore; "
                    "$p = New-Object System.Windows.Media.MediaPlayer; "
                    f"$p.Open([Uri]::new('file:///{wpath}')); "
                    "$p.Volume = 0.3; "
                    "Start-Sleep -Milliseconds 200; "
                    "$p.Play(); "
                    "Start-Sleep -Seconds 3; "
                    "$p.Close()"
                )
                subprocess.run(
                    ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ps_cmd],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10
                )
            print("Sound working!")
        except Exception:
            print("Warning: Sound test failed. Sounds may not play.")
    else:
        print("Warning: No sound files found. Sounds may not play.")

    # Final output
    print()
    if updating:
        print("=== Update complete! ===")
        print()
        print("Updated: core files, manifests")
        print("Preserved: config.json, state")
    else:
        print("=== Installation complete! ===")
        print()
        print(f"Config: {os.path.join(INSTALL_DIR, 'config.json')}")
        print("  - Adjust volume, toggle categories, switch packs")
        print()
        if PLATFORM == "windows":
            print(f"Uninstall: python {os.path.join(INSTALL_DIR, 'uninstall.py')}")
        else:
            print(f"Uninstall: bash {os.path.join(INSTALL_DIR, 'uninstall.sh')}")

    print()
    print("Quick controls:")
    print("  /peon-ping-toggle  -- toggle sounds in Claude Code")
    print("  peon --toggle      -- toggle sounds from any terminal")
    print("  peon --status      -- check if sounds are paused")
    print()
    print("Ready to work!")

if __name__ == "__main__":
    main()
