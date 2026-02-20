# Multi-Window Click-to-Focus (Tabled)

## Problem
When multiple Cursor windows are open, click-to-focus brings Cursor to front but raises the wrong window (last-focused, not the one running the agent).

## What works
- Single-window click-to-focus works reliably (bundle ID via System Events query)
- Bundle ID detection for Cursor/Code/Windsurf via `TERM_PROGRAM=vscode` + osascript System Events
- Project name is correctly extracted from cwd and passed through to overlay

## Approaches tried (all failed for multi-window)

### 1. System Events AXRaise after activateWithOptions
- `NSRunningApplication.activateWithOptions` is async, brings wrong window first
- AXRaise fires after but the wrong window is already visible

### 2. System Events AXRaise before set frontmost
- Reorder: AXRaise first, then `set frontmost to true`
- Still didn't reliably raise the correct window

### 3. System Events AXRaise + frontmost in one AppleScript
- Single atomic AppleScript: `set frontmost to true` + iterate windows + AXRaise matching window
- Window title matching worked (confirmed via debug logging: `result=matched`)
- Still didn't visually raise the correct window

### 4. `open -a "Cursor" /path/to/project`
- Should focus the existing window for that folder
- Didn't work

### 5. `cursor /path/to/project` CLI
- Cursor's CLI tool to open/focus a folder
- Didn't work either

## Technical notes
- Cursor window titles contain the project folder name (e.g., "config.json -- peonping-repos")
- System Events can list/query Cursor windows (accessibility permissions granted)
- AXRaise reports success but doesn't visually change window order
- macOS may be preventing programmatic window reordering for Electron apps
- Cursor is an Electron app (bundle: com.todesktop.230313mzl4w4u92)

## Current state
Click-to-focus works for single-window setups. For multi-window, it brings Cursor to front but may show the wrong window. The window-matching code is in place but AXRaise doesn't reliably reorder Electron app windows on macOS.
