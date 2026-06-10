/**
 * peon-ping for Pi (earendil-works/pi, badlogic/pi-mono) — Thin Extension
 *
 * Routes Pi coding-agent lifecycle events through peon.sh (or peon.ps1 on
 * Windows) instead of re-implementing sound playback, notifications, and
 * trainer features in TypeScript. Pi users get ALL peon-ping features:
 * sound packs & rotation, desktop/mobile notifications, trainer reminders,
 * spam detection, SSH/devcontainer relay, and all `peon` CLI config.
 *
 * Pi extensions are default-export factory functions `(pi: ExtensionAPI)`
 * auto-discovered from ~/.pi/agent/extensions/ and loaded via jiti (no
 * compile step). Events are subscribed with `pi.on(name, cb)`.
 *
 * Event mapping (Pi -> peon hook_event_name):
 *   session_start   -> SessionStart       (greeting)
 *   agent_end       -> Stop               (task complete)
 *   tool_result*    -> PostToolUseFailure (only on a failed tool result)
 *
 * Original community adapter: npm `pi-peon-ping`. Vendored first-party here
 * with thanks to its author; coordinate upstream attribution on release.
 *
 * Requires peon-ping installed: brew install PeonPing/tap/peon-ping
 *   or: curl -fsSL peonping.com/install | bash
 */

import { spawn } from "node:child_process"
import * as fs from "node:fs"
import * as os from "node:os"
import * as path from "node:path"

// `@earendil-works/pi-coding-agent` is provided by the Pi runtime at load
// time; type it loosely so the extension stays dependency-light and resilient
// to Pi API drift (event payloads vary per event).
type ExtensionAPI = {
  on: (event: string, cb: (event: any, ctx: any) => any) => void
}

const PEON_SH_CANDIDATES = [
  path.join(os.homedir(), ".claude", "hooks", "peon-ping", "peon.sh"),
  path.join(os.homedir(), ".openpeon", "hooks", "peon-ping", "peon.sh"),
  path.join(os.homedir(), ".openclaw", "hooks", "peon-ping", "peon.sh"),
]

const PEON_PS1_CANDIDATES = [
  path.join(os.homedir(), ".claude", "hooks", "peon-ping", "peon.ps1"),
  path.join(os.homedir(), ".openpeon", "hooks", "peon-ping", "peon.ps1"),
]

function firstExisting(candidates: string[]): string | null {
  for (const p of candidates) {
    try {
      if (fs.existsSync(p)) return p
    } catch {
      /* ignore */
    }
  }
  return null
}

export default function (pi: ExtensionAPI): void {
  const isWindows = process.platform === "win32"
  const peonScript = isWindows ? firstExisting(PEON_PS1_CANDIDATES) : firstExisting(PEON_SH_CANDIDATES)

  if (!peonScript) {
    console.warn("[peon-ping] peon.sh/peon.ps1 not found. Install peon-ping first:")
    console.warn("  brew install PeonPing/tap/peon-ping")
    console.warn("  # or: curl -fsSL peonping.com/install | bash")
    return
  }

  const cwd = process.cwd()
  const sessionId = `pi-${Date.now().toString(36)}`

  function firePeon(event: string, extra: Record<string, unknown> = {}): void {
    const payload = JSON.stringify({
      hook_event_name: event,
      notification_type: "",
      cwd,
      session_id: sessionId,
      permission_mode: "",
      source: "pi",
      ...extra,
    })

    try {
      const child = isWindows
        ? spawn("powershell", ["-NoProfile", "-NonInteractive", "-File", peonScript!], {
            stdio: ["pipe", "ignore", "ignore"],
            detached: true,
          })
        : spawn("bash", [peonScript!], {
            stdio: ["pipe", "ignore", "ignore"],
            detached: true,
          })
      child.stdin.write(payload)
      child.stdin.end()
      child.unref()
    } catch {
      /* never let a sound failure break the agent */
    }
  }

  pi.on("session_start", () => {
    firePeon("SessionStart")
  })

  pi.on("agent_end", () => {
    firePeon("Stop")
  })

  // Best-effort failure cue: only fire on a tool result that clearly errored.
  pi.on("tool_result", (event: any) => {
    const result = event?.result ?? event
    const failed = result?.isError === true || result?.is_error === true || !!event?.error
    if (!failed) return
    const toolName = event?.toolName ?? event?.tool_name ?? "Bash"
    const error = (event?.error ?? result?.error ?? "Tool failed").toString().slice(0, 180)
    firePeon("PostToolUseFailure", { tool_name: String(toolName).slice(0, 64), error })
  })
}
