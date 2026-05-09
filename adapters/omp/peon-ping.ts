/**
 * peon-ping for oh-my-pi (omp) — Thin Adapter
 *
 * Routes omp ExtensionAPI events through peon.sh instead of re-implementing
 * sound playback, notifications, and trainer features in TypeScript.
 *
 * This gives omp users access to ALL peon-ping features:
 * - Sound packs & rotation
 * - Desktop notifications
 * - Trainer reminders (pushups, squats, etc.)
 * - Spam detection
 * - SSH/devcontainer relay
 * - All config options via `peon` CLI
 * - Tab title updates
 *
 * Event mapping (omp ExtensionAPI → peon.sh hook_event_name):
 *   session_start                       → SessionStart
 *   turn_start                          → UserPromptSubmit
 *   turn_end                            → Stop
 *   tool_result (event.isError === true) → PostToolUseFailure
 *   auto_compaction_start               → PreCompact
 *   session_shutdown                    → SessionEnd
 *
 * Requires peon-ping installed: brew install PeonPing/tap/peon-ping
 *   or: curl -fsSL peonping.com/install | bash
 */

import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { spawn } from "node:child_process"
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent"

const PEON_SH_PATHS = [
  path.join(os.homedir(), ".claude", "hooks", "peon-ping", "peon.sh"),
  path.join(os.homedir(), ".openclaw", "hooks", "peon-ping", "peon.sh"),
]

function findPeonSh(): string | null {
  for (const p of PEON_SH_PATHS) {
    try {
      if (fs.existsSync(p)) return p
    } catch {}
  }
  return null
}

function setTabTitle(title: string): void {
  process.stdout.write(`\x1b]0;${title}\x07`)
}

export default function peonPingExtension(pi: ExtensionAPI): void {
  const peonSh = findPeonSh()
  if (!peonSh) {
    console.warn("[peon-ping] peon.sh not found. Install peon-ping first:")
    console.warn("  brew install PeonPing/tap/peon-ping")
    console.warn("  # or: curl -fsSL peonping.com/install | bash")
    return
  }

  const cwd = process.cwd()
  const projectName = path.basename(cwd) || "omp"
  const sessionId = `omp-${Date.now()}`

  function firePeon(event: string): void {
    const payload = JSON.stringify({
      hook_event_name: event,
      notification_type: "",
      cwd,
      session_id: sessionId,
      permission_mode: "",
      source: "omp",
    })

    try {
      const proc = spawn("bash", [peonSh], {
        stdio: ["pipe", "ignore", "ignore"],
      })
      proc.stdin.write(payload)
      proc.stdin.end()
      proc.unref()
    } catch {}
  }

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.hasUI) setTabTitle(`${projectName}: ready`)
    firePeon("SessionStart")
  })

  pi.on("turn_start", async (_event, ctx) => {
    if (ctx.hasUI) setTabTitle(`${projectName}: working`)
    firePeon("UserPromptSubmit")
  })

  pi.on("turn_end", async (_event, ctx) => {
    if (ctx.hasUI) setTabTitle(`\u25cf ${projectName}: done`)
    firePeon("Stop")
  })

  pi.on("tool_result", async (event, ctx) => {
    if (!event.isError) return
    if (ctx.hasUI) setTabTitle(`\u25cf ${projectName}: error`)
    firePeon("PostToolUseFailure")
  })

  pi.on("auto_compaction_start", async () => {
    firePeon("PreCompact")
  })

  pi.on("session_shutdown", async () => {
    firePeon("SessionEnd")
  })
}
