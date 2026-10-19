/**
 * peon-ping for OpenCode — event bridge
 *
 * Routes OpenCode events through peon.sh instead of re-implementing
 * sound playback, notifications, and trainer features in TypeScript.
 *
 * This gives OpenCode users access to ALL peon-ping features:
 * - Sound packs & rotation
 * - Desktop notifications
 * - Trainer reminders (pushups, squats, etc.)
 * - Spam detection
 * - SSH/devcontainer relay
 * - All config options via `peon` CLI
 * - Tab title updates
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

async function createBridge(ctx: any) {
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
      // Hosts can retain the caller's symlink path in event locations while
      // loading the plugin at its canonical path (for example /tmp on macOS).
      try { resolved = fs.realpathSync(resolved) } catch {}
      return windows ? resolved.toLowerCase() : resolved
    }
    const pluginDirectory = directoryIdentity(cwd)
    // The host may load one physical directory through more than one alias.
    // Keep a single active bridge for that directory across plugin generations.
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

    function firePeon(event: string, notificationType = "", nativeSessionId?: string): void {
      const payload = JSON.stringify({
        hook_event_name: event,
        notification_type: notificationType,
        cwd,
        session_id: nativeSessionId ? `opencode-${nativeSessionId}` : sessionId,
        permission_mode: "",
        source: "opencode",
      })

      try {
        const proc = spawn(windows ? "powershell.exe" : "bash", windows
          ? ["-NoProfile", "-NonInteractive", "-File", peonScript!]
          : [peonScript!], {
          stdio: ["pipe", "ignore", "ignore"],
        })
        // Launch failures and early child exits arrive asynchronously, outside
        // this try/catch. Notifications must never take down the plugin host.
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

    /**
     * Map an OpenCode v2 event onto a peon.sh hook_event_name.
     *
     * v2 replaced the event taxonomy this adapter was written against; see
     * `docs/opencode-v2-events.md` for the full table. The cases below are the
     * only v2 events that map onto a peon-ping category.
     */
    async function handle(event: V2Event): Promise<void> {
      if (!SCOPED_EVENT_TYPES.has(event.type) || owners.values().next().value !== owner) return
      const data = event.data ?? {}
      const sid = data.sessionID ?? data.form?.sessionID
      // Deletion is silent cleanup. The host has already removed the session,
      // so a location lookup can no longer succeed. Other projects hold no
      // state for this globally unique session ID and are safe to clear too.
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
      // Durable execution events have no location envelope. Resolve the
      // session through the actual host rather than treating them as local.
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
          if (ctx.greetOnCreate && typeof sid === "string" && !isSubagent(sid) && !sessionStarts.has(sid)) {
            sessionStarts.set(sid, Date.now())
            setTabTitle(`${projectName}: ready`)
            firePeon("SessionStart", "", sid)
          }
          break
        }

        // A new execution is both "a turn began" and, the first time we see a
        // session, "a session began". SessionStart is emitted first so the
        // debounce below suppresses the UserPromptSubmit that immediately
        // follows it, matching the pre-v2 behaviour.
        case "session.execution.started": {
          const sid = data.sessionID
          if (typeof sid !== "string" || isSubagent(sid) || busySessions.has(sid)) break
          busySessions.add(sid)
          const lastSessionStart = sessionStarts.get(sid)
          if (lastSessionStart === undefined) {
            sessionStarts.set(sid, Date.now())
            setTabTitle(`${projectName}: ready`)
            firePeon("SessionStart", "", sid)
          } else if (Date.now() - lastSessionStart > 3000) {
            setTabTitle(`${projectName}: working`)
            firePeon("UserPromptSubmit", "", sid)
          }
          break
        }

        case "session.execution.succeeded": {
          const sid = data.sessionID
          if (isSubagent(sid)) break
          if (sid) busySessions.delete(sid)
          setTabTitle(`\u25cf ${projectName}: done`)
          firePeon("Stop", "", sid)
          break
        }

        case "session.execution.failed": {
          const sid = data.sessionID
          if (isSubagent(sid)) break
          if (sid) busySessions.delete(sid)
          setTabTitle(`\u25cf ${projectName}: error`)
          firePeon("PostToolUseFailure", "", sid)
          break
        }

        case "session.execution.interrupted": {
          if (typeof data.sessionID === "string") busySessions.delete(data.sessionID)
          break
        }

        case "permission.asked": {
          if (isSubagent(data.sessionID)) break
          setTabTitle(`\u25cf ${projectName}: needs approval`)
          firePeon("PermissionRequest", "", sid)
          break
        }

        // v2 renamed the "agent needs input" elicitation surface from
        // question.* to form.*.
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
          firePeon("Notification", "elicitation_dialog", sid)
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

    return {
      handle,
      cleanup() {
        owners.delete(owner)
        if (owners.size === 0) locationOwners.delete(pluginDirectory)
      },
    }
}

/** Both host loaders inspect their own entrypoint and permit the other key. */
export default {
  id: "peon-ping",

  // OpenCode 1.x uses properties payloads and SDK { data } responses.
  server: async (ctx: any) => {
    const directory = ctx.directory || process.cwd()
    const bridge = await createBridge({
      location: { directory },
      greetOnCreate: true,
      session: { get: async ({ sessionID }: { sessionID: string }) => {
        const response = await ctx.client.session.get({ path: { id: sessionID } })
        const info = response.data
        return { ...info, location: { directory: info?.directory } }
      } },
    })
    if (!bridge) return {}
    async function dispatch(event: V2Event): Promise<void> {
      try {
        await bridge!.handle(event)
      } catch (err: any) {
        console.error("[peon-ping] failed to handle event:", err?.message ?? err)
      }
    }
    return {
      dispose: () => bridge.cleanup(),
      event: async ({ event }: any) => {
        if (event.type === "server.instance.disposed") {
          bridge.cleanup()
          return
        }
        const data = event.properties ?? {}
        const info = data.info
        const sessionID = data.sessionID ?? info?.id
        const location = info?.directory ? { directory: info.directory } : undefined
        let type: string
        switch (event.type) {
          case "session.created": type = "session.created"; break
          case "session.updated":
            if (!info?.parentID) return
            type = "session.created"
            break
          case "session.deleted": type = "session.deleted"; break
          case "session.status":
            if (data.status?.type !== "busy" && data.status?.type !== "running") return
            type = "session.execution.started"
            break
          case "session.idle": type = "session.execution.succeeded"; break
          case "session.error": type = "session.execution.failed"; break
          case "permission.asked": type = "permission.asked"; break
          case "question.asked":
          case "question.v2.asked":
            await dispatch({ type: "form.created", data: { form: data } })
            return
          case "question.replied":
          case "question.rejected":
          case "question.v2.replied":
          case "question.v2.rejected":
            await dispatch({ type: "form.replied", data: { id: data.requestID ?? data.id } })
            return
          default: return
        }
        if (typeof sessionID !== "string") return
        await dispatch({ type, location, data: { ...data, sessionID, parentID: info?.parentID } })
      },
    }
  },

  setup: async (ctx: any) => {
    const bridge = await createBridge(ctx)
    if (!bridge) return
    const controller = new AbortController()
    void (async () => {
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        try {
          await bridge.handle(event as V2Event)
        } catch (err: any) {
          console.error("[peon-ping] failed to handle event:", err?.message ?? err)
        }
      }
    })().catch((err: any) => {
      if (!controller.signal.aborted) console.error("[peon-ping] event stream ended:", err?.message ?? err)
    })
    return () => {
      controller.abort()
      bridge.cleanup()
    }
  },
}
