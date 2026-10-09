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
 *   agent_start                         → UserPromptSubmit
 *   agent_end (not willContinue)        → Stop
 *   tool_result (event.isError === true) → PostToolUseFailure
 *   auto_compaction_start               → PreCompact
 *   session_shutdown                    → SessionEnd
 *
 * agent_start/agent_end fire once per prompt. turn_start/turn_end fire once per
 * model call, so a prompt that runs ten tool steps would fire peon.sh ten times.
 * Subagents load this extension too and get their own copy of every event; those
 * are skipped, so one prompt gives one Stop however many subagents it starts.
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
      // Both errors arrive after this function returns, so the catch below never
      // sees them, and an EventEmitter with no "error" listener throws. A failed
      // spawn (EAGAIN near the process limit) or an EPIPE (peon.sh exiting before
      // reading stdin) would then be an uncaught exception inside omp.
      proc.on("error", () => {})
      proc.stdin?.on("error", () => {})
      proc.stdin?.end(payload)
      proc.unref()
    } catch {}
  }

  // ctx.agent arrived in omp 18.3.2. On older omp it is undefined, every session
  // looks like the main one, and events still fire as before.
  const isSubagent = (ctx: { agent?: { kind?: string } }): boolean => ctx.agent?.kind === "sub"

  pi.on("session_start", async (_event, ctx) => {
    if (isSubagent(ctx)) return
    if (ctx.hasUI) setTabTitle(`${projectName}: ready`)
    firePeon("SessionStart")
  })

  pi.on("agent_start", async (_event, ctx) => {
    if (isSubagent(ctx)) return
    if (ctx.hasUI) setTabTitle(`${projectName}: working`)
    firePeon("UserPromptSubmit")
  })

  pi.on("agent_end", async (event, ctx) => {
    if (isSubagent(ctx)) return
    // omp has already scheduled another run of the agent (a retry after an error,
    // a recovery, a reminder), which starts with its own agent_start and ends with
    // its own agent_end. Only the last one is the real stop. omp before 17.0.2
    // never sets willContinue.
    if ("willContinue" in event && event.willContinue === true) return
    if (ctx.hasUI) setTabTitle(`\u25cf ${projectName}: done`)
    firePeon("Stop")
  })

  pi.on("tool_result", async (event, ctx) => {
    if (!event.isError || isSubagent(ctx)) return
    if (ctx.hasUI) setTabTitle(`\u25cf ${projectName}: error`)
    firePeon("PostToolUseFailure")
  })

  pi.on("auto_compaction_start", async (_event, ctx) => {
    if (isSubagent(ctx)) return
    firePeon("PreCompact")
  })

  pi.on("session_shutdown", async (_event, ctx) => {
    if (isSubagent(ctx)) return
    firePeon("SessionEnd")
  })
}
