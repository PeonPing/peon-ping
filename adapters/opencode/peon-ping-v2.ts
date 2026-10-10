/**
 * peon-ping for OpenCode — Thin Adapter (v2 contract)
 *
 * OpenCode 2.x uses the v2 plugin contract: default export must be an object
 * with `id` and `setup` properties. This file is served to OpenCode 2.x by the
 * installer.
 *
 * Routes OpenCode events through peon.sh instead of re-implementing
 * sound playback, notifications, and trainer features in TypeScript.
 *
 * Event mapping (OpenCode v2 events → peon.sh hook_event_name):
 *   session.created (no parent)   → SessionStart
 *   session.execution.started      → SessionStart (first) / UserPromptSubmit (subsequent)
 *   session.execution.succeeded    → Stop
 *   session.execution.failed       → PostToolUseFailure
 *   session.execution.interrupted  → (silent cleanup)
 *   permission.asked              → PermissionRequest
 *   form.created                 → Notification (elicitation_dialog)
 *
 * Requires peon-ping installed: brew install PeonPing/tap/peon-ping
 *   or: curl -fsSL peonping.com/install | bash
 */

import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { spawn } from "node:child_process"

const MAX_PENDING_QUESTION_IDS = 100
const LOCATION_OWNERS = Symbol.for("peon-ping.opencode.location-owners")
const SCOPED_EVENT_TYPES = new Set([
  "session.created", "session.deleted", "session.execution.started",
  "session.execution.succeeded", "session.execution.failed", "session.execution.interrupted",
  "permission.asked", "form.created", "form.replied", "form.cancelled",
])

function findPeonScript(windows: boolean): string | null {
  const filename = windows ? "peon.ps1" : "peon.sh"
  const directories = [
    process.env.CLAUDE_PEON_DIR,
    path.join(process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude"), "hooks", "peon-ping"),
    path.join(os.homedir(), ".openpeon", "hooks", "peon-ping"),
    path.join(os.homedir(), ".openpeon"),
    path.join(os.homedir(), ".openclaw", "hooks", "peon-ping"),
  ]
  for (const directory of directories) {
    if (!directory) continue
    const candidate = path.join(directory, filename)
    try {
      if (fs.existsSync(candidate)) return candidate
    } catch {}
  }
  return null
}

function setTabTitle(title: string): void {
  if (!process.stdout.isTTY) return
  process.stdout.write(`\x1b]0;${title}\x07`)
}

/**
 * OpenCode v2 payloads carry the event body under `data`. Only the fields this
 * adapter reads are typed; the rest of the union is intentionally open.
 */
type V2Event = {
  id?: string
  type: string
  data?: Record<string, any>
  location?: { directory?: string }
}

/**
 * v2 plugin module export.
 * OpenCode 2.x expects: { id: string, setup: (ctx) => Promise<void> }
 */
export default {
  id: "peon-ping",

  setup: async (ctx: any) => {
    const projectName = path.basename(ctx?.location?.directory || process.cwd()) || "opencode"
    const windows = os.platform() === "win32"
    const peonScript = findPeonScript(windows)

    if (!peonScript) {
      console.warn(`[peon-ping] ${windows ? "peon.ps1" : "peon.sh"} not found. Install peon-ping first:`)
      if (windows) {
        console.warn("  https://github.com/PeonPing/peon-ping#option-3-installer-for-windows")
      } else {
        console.warn("  brew install PeonPing/tap/peon-ping")
        console.warn("  # or: curl -fsSL peonping.com/install | bash")
      }
      return
    }

    const cwd = ctx?.location?.directory || process.cwd()
    function directoryIdentity(directory: string): string {
      let resolved = path.resolve(directory)
      try { resolved = fs.realpathSync(resolved) } catch {}
      return windows ? resolved.toLowerCase() : resolved
    }
    const pluginDirectory = directoryIdentity(cwd)
    const shared = globalThis as any
    const locationOwners: Map<string, Set<object>> = shared[LOCATION_OWNERS] ??= new Map()
    const owners = locationOwners.get(pluginDirectory) ?? new Set<object>()
    const owner = {}
    owners.add(owner)
    locationOwners.set(pluginDirectory, owners)
    const sessionId = `oc-${Date.now()}`
    const subagentSessionIds = new Set<string>()
    const busySessions = new Set<string>()
    const sessionStarts = new Map<string, number>()
    const pendingQuestionIds = new Set<string>()

    function firePeon(event: string, notificationType = ""): void {
      const payload = JSON.stringify({
        hook_event_name: event,
        notification_type: notificationType,
        cwd,
        session_id: sessionId,
        permission_mode: "",
        source: "opencode",
      })

      try {
        const proc = spawn(windows ? "powershell.exe" : "bash", windows
          ? ["-NoProfile", "-NonInteractive", "-File", peonScript!]
          : [peonScript!], {
          stdio: ["pipe", "ignore", "ignore"],
        })
        proc.on("error", () => {})
        proc.stdin?.on("error", () => {})
        proc.stdin?.write(payload)
        proc.stdin?.end()
        proc.unref()
      } catch {}
    }

    function isSubagent(sid: unknown): boolean {
      return typeof sid === "string" && subagentSessionIds.has(sid)
    }

    async function handle(event: V2Event): Promise<void> {
      if (!SCOPED_EVENT_TYPES.has(event.type) || owners.values().next().value !== owner) return
      const data = event.data ?? {}
      const sid = data.sessionID ?? data.form?.sessionID
      if (event.type === "session.deleted") {
        if (typeof sid === "string") {
          subagentSessionIds.delete(sid)
          busySessions.delete(sid)
          sessionStarts.delete(sid)
        }
        return
      }
      let eventDirectory = event.location?.directory ?? data.location?.directory
      let parentID = data.parentID
      if (!eventDirectory && typeof sid === "string") {
        const session = await ctx.session.get({ sessionID: sid })
        if (owners.values().next().value !== owner) return
        eventDirectory = session.location?.directory
        parentID = session.parentID
        if (!eventDirectory) return
      }
      if (eventDirectory && directoryIdentity(eventDirectory) !== pluginDirectory) return
      if (parentID && typeof sid === "string") subagentSessionIds.add(sid)

      switch (event.type) {
        case "session.created": {
          if (data.parentID && typeof data.sessionID === "string") subagentSessionIds.add(data.sessionID)
          break
        }

        case "session.execution.started": {
          const sid = data.sessionID
          if (typeof sid !== "string" || isSubagent(sid) || busySessions.has(sid)) break
          busySessions.add(sid)
          const lastSessionStart = sessionStarts.get(sid)
          if (lastSessionStart === undefined) {
            sessionStarts.set(sid, Date.now())
            setTabTitle(`${projectName}: ready`)
            firePeon("SessionStart")
          } else if (Date.now() - lastSessionStart > 3000) {
            setTabTitle(`${projectName}: working`)
            firePeon("UserPromptSubmit")
          }
          break
        }

        case "session.execution.succeeded": {
          const sid = data.sessionID
          if (isSubagent(sid)) break
          if (sid) busySessions.delete(sid)
          setTabTitle(`\u25cf ${projectName}: done`)
          firePeon("Stop")
          break
        }

        case "session.execution.failed": {
          const sid = data.sessionID
          if (isSubagent(sid)) break
          if (sid) busySessions.delete(sid)
          setTabTitle(`\u25cf ${projectName}: error`)
          firePeon("PostToolUseFailure")
          break
        }

        case "session.execution.interrupted": {
          if (typeof data.sessionID === "string") busySessions.delete(data.sessionID)
          break
        }

        case "permission.asked": {
          if (isSubagent(data.sessionID)) break
          setTabTitle(`\u25cf ${projectName}: needs approval`)
          firePeon("PermissionRequest")
          break
        }

        case "form.created": {
          const form = data.form
          const sid = form?.sessionID
          if (isSubagent(sid)) break
          const requestId = form?.id
          if (typeof requestId !== "string" || pendingQuestionIds.has(requestId)) break
          if (pendingQuestionIds.size >= MAX_PENDING_QUESTION_IDS) {
            pendingQuestionIds.delete(pendingQuestionIds.values().next().value!)
          }
          pendingQuestionIds.add(requestId)
          setTabTitle(`\u25cf ${projectName}: needs input`)
          firePeon("Notification", "elicitation_dialog")
          break
        }

        case "form.replied":
        case "form.cancelled": {
          const requestId = data.id
          if (typeof requestId === "string") pendingQuestionIds.delete(requestId)
          break
        }
      }
    }

    setTabTitle(`${projectName}: ready`)

    const controller = new AbortController()

    void (async () => {
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        try {
          await handle(event as V2Event)
        } catch (err: any) {
          console.error("[peon-ping] failed to handle event:", err?.message ?? err)
        }
      }
    })().catch((err: any) => {
      if (!controller.signal.aborted) console.error("[peon-ping] event stream ended:", err?.message ?? err)
    })

    return () => {
      controller.abort()
      owners.delete(owner)
      if (owners.size === 0) locationOwners.delete(pluginDirectory)
    }
  },
}
