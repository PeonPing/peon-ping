import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

const stdin = {
  write: vi.fn(),
  end: vi.fn(),
  on: vi.fn(),
}
const spawnedProcess = {
  stdin,
  unref: vi.fn(),
  on: vi.fn(),
}

vi.mock("node:fs", () => ({
  existsSync: vi.fn(() => true),
}))

vi.mock("node:child_process", () => ({
  spawn: vi.fn(() => spawnedProcess),
}))

vi.mock("node:os", () => ({
  homedir: () => "/tmp/opencode-test-home",
  platform: vi.fn(() => "darwin"),
}))

import * as fs from "node:fs"
import * as os from "node:os"
import { spawn } from "node:child_process"
import { EventEmitter } from "node:events"
import * as path from "node:path"
import plugin from "../adapters/opencode/peon-ping.js"

/**
 * Drives the plugin through a fake v2 host context and yields the events fed
 * to it, so a test can step the stream one event at a time.
 */
async function createHost(events: Array<Record<string, any>> = [], sessionDirectory = "/tmp/example-project", sessionLookup?: Promise<Record<string, any>>) {
  const queue = [...events]
  let wake: (() => void) | undefined
  let signal: AbortSignal

  const ctx: any = {
    location: { directory: "/tmp/example-project" },
    session: {
      get: vi.fn(async ({ sessionID }: { sessionID: string }) => sessionLookup ?? ({
        id: sessionID,
        projectID: "fixture-project",
        title: "Fixture session",
        cost: 0,
        tokens: { input: 0, output: 0, reasoning: 0, cache: { read: 0, write: 0 } },
        time: { created: 0, updated: 0 },
        location: { directory: sessionDirectory },
      })),
    },
    event: {
      subscribe: async function* (opts: { signal: AbortSignal }) {
        signal = opts.signal
        while (!signal.aborted) {
          if (queue.length > 0) {
            yield queue.shift()!
            continue
          }
          let onAbort: () => void
          await new Promise<void>((resolve) => {
            onAbort = () => resolve()
            wake = resolve
            signal.addEventListener("abort", onAbort, { once: true })
          })
          signal.removeEventListener("abort", onAbort!)
        }
      },
    },
  }

  const cleanup = await plugin.setup(ctx)
  // Let the loop subscribe before the test pushes anything.
  await new Promise((resolve) => setTimeout(resolve, 0))

  return {
    async emit(event: Record<string, any>) {
      queue.push(event)
      wake?.()
      await new Promise((resolve) => setTimeout(resolve, 0))
      await new Promise((resolve) => setTimeout(resolve, 0))
    },
    cleanup,
    getSession: ctx.session.get,
    aborted: () => signal?.aborted,
  }
}

function payloads(): Array<Record<string, unknown>> {
  return stdin.write.mock.calls.map(([payload]) => JSON.parse(payload))
}

function hookEvents(): string[] {
  return payloads().map((p) => p.hook_event_name as string)
}

describe("peon-ping OpenCode v2 plugin definition", () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(fs.existsSync).mockReturnValue(true)
    vi.mocked(os.platform).mockReturnValue("darwin")
    vi.stubEnv("CLAUDE_PEON_DIR", "")
    vi.stubEnv("CLAUDE_CONFIG_DIR", "")
    vi.spyOn(process.stdout, "write").mockImplementation(() => true)
  })

  afterEach(() => {
    vi.restoreAllMocks()
    vi.unstubAllEnvs()
  })

  it("exports a v2 definition object with an id and a setup function", () => {
    expect(typeof plugin).toBe("object")
    expect(plugin.id).toBe("peon-ping")
    expect(typeof plugin.setup).toBe("function")
  })
})

describe("peon-ping event mapping", () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(fs.existsSync).mockReturnValue(true)
    vi.mocked(os.platform).mockReturnValue("darwin")
    vi.stubEnv("CLAUDE_PEON_DIR", "")
    vi.stubEnv("CLAUDE_CONFIG_DIR", "")
    vi.spyOn(process.stdout, "write").mockImplementation(() => true)
  })

  afterEach(() => {
    vi.clearAllTimers()
    vi.restoreAllMocks()
    vi.unstubAllEnvs()
  })

  it("v1 permissions use native Windows bridge and resolve resumed child sessions before forwarding", async () => {
    vi.mocked(os.platform).mockReturnValue("win32")
    vi.stubEnv("CLAUDE_PEON_DIR", "/custom hook")
    const hooks = await plugin.server({
      directory: "/tmp/example-project",
      client: { session: { get: async ({ path: { id } }: any) => ({ data: {
        id, directory: "/tmp/example-project", parentID: id === "child" ? "parent" : undefined,
      } }) } },
    })
    await hooks.event!({ event: { type: "permission.asked", properties: { sessionID: "parent" } } })
    await hooks.event!({ event: { type: "permission.asked", properties: { sessionID: "child" } } })
    expect(payloads()).toHaveLength(1)
    expect(payloads()[0]).toMatchObject({ hook_event_name: "PermissionRequest", session_id: "opencode-parent" })
    expect(spawn).toHaveBeenCalledWith("powershell.exe", ["-NoProfile", "-NonInteractive", "-File", path.join("/custom hook", "peon.ps1")], { stdio: ["pipe", "ignore", "ignore"] })
    await hooks.event!({ event: { type: "server.instance.disposed" } })
  })

  it("v1 contains host session lookup failures without rejecting the event callback", async () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => {})
    const hooks = await plugin.server({
      directory: "/tmp/example-project",
      client: { session: { get: async () => { throw new Error("session was removed") } } },
    })
    try {
      await expect(hooks.event!({ event: { type: "session.idle", properties: { sessionID: "gone" } } })).resolves.toBeUndefined()
      expect(payloads()).toEqual([])
      expect(log).toHaveBeenCalled()
    } finally {
      await hooks.event!({ event: { type: "server.instance.disposed" } })
    }
  })

  it("v1 host disposal releases project ownership for the next plugin generation", async () => {
    const ctx = { directory: "/tmp/example-project" }
    const original = await plugin.server(ctx)
    expect(original.dispose).toBeTypeOf("function")
    await original.dispose!()
    const replacement = await plugin.server(ctx)
    try {
      await replacement.event!({ event: { type: "session.created", properties: { info: { id: "after-reload", directory: ctx.directory } } } })
      expect(payloads().map(p => p.session_id)).toEqual(["opencode-after-reload"])
    } finally {
      await replacement.dispose!()
    }
  })

  it("v1 session creation does not leave a delayed first prompt marked busy", async () => {
    const now = vi.spyOn(Date, "now").mockReturnValue(0)
    const ctx = { directory: "/tmp/example-project", client: { session: { get: async () => ({ data: { directory: "/tmp/example-project" } }) } } }
    const hooks = await plugin.server(ctx)
    try {
      await hooks.event!({ event: { type: "session.created", properties: { info: { id: "first-turn", directory: ctx.directory } } } })
      now.mockReturnValue(4000)
      await hooks.event!({ event: { type: "session.status", properties: { sessionID: "first-turn", status: { type: "busy" } } } })
      expect(hookEvents()).toEqual(["SessionStart", "UserPromptSubmit"])
    } finally {
      await hooks.dispose!()
    }
  })

  it("v1 metadata updates do not announce a new primary session", async () => {
    const hooks = await plugin.server({ directory: "/tmp/example-project" })
    try {
      await hooks.event!({ event: { type: "session.updated", properties: { info: { id: "background", directory: "/tmp/example-project" } } } })
      expect(hookEvents()).toEqual([])
    } finally {
      await hooks.dispose!()
    }
  })

  it("maps session execution lifecycle onto peon hook events", async () => {
    const host = await createHost([
      { id: "evt_1", type: "session.execution.started", data: { sessionID: "ses_a" } },
      { id: "evt_2", type: "session.execution.succeeded", data: { sessionID: "ses_a" } },
    ])

    await new Promise((resolve) => setTimeout(resolve, 20))
    host.cleanup?.()

    expect(hookEvents()).toEqual(["SessionStart", "Stop"])
  })

  it("reports a failed execution as PostToolUseFailure", async () => {
    const host = await createHost([
      { id: "evt_1", type: "session.execution.failed", data: { sessionID: "ses_a" } },
    ])

    await new Promise((resolve) => setTimeout(resolve, 20))
    host.cleanup?.()

    expect(hookEvents()).toContain("PostToolUseFailure")
  })

  it("dispatches a private elicitation notification for form.created", async () => {
    const sensitiveText = "SENTINEL_SECRET_FORM_V1"
    const host = await createHost([
      {
        id: "evt_1",
        type: "form.created",
        data: {
          form: {
            id: "form-request-v1",
            sessionID: "primary-session",
            title: sensitiveText,
            fields: [{ type: "string", key: "answer", label: "Secret option" }],
          },
        },
      },
    ])

    await new Promise((resolve) => setTimeout(resolve, 20))
    host.cleanup?.()

    expect(payloads()).toEqual([
      {
        hook_event_name: "Notification",
        notification_type: "elicitation_dialog",
        cwd: "/tmp/example-project",
        session_id: "opencode-primary-session",
        permission_mode: "",
        source: "opencode",
      },
    ])
    // The question text and id must never reach the peon.sh payload.
    expect(stdin.write.mock.calls[0][0]).not.toContain(sensitiveText)
    expect(stdin.write.mock.calls[0][0]).not.toContain("form-request-v1")
  })

  it("suppresses duplicate form notifications with the same id", async () => {
    const host = await createHost([
      { id: "evt_1", type: "form.created", data: { form: { id: "same-form", sessionID: "primary-session", title: "Input", fields: [{ type: "string", key: "answer", label: "Answer" }] } } },
      { id: "evt_2", type: "form.created", data: { form: { id: "same-form", sessionID: "primary-session", title: "Input", fields: [{ type: "string", key: "answer", label: "Answer" }] } } },
    ])

    await new Promise((resolve) => setTimeout(resolve, 20))
    host.cleanup?.()

    expect(spawn).toHaveBeenCalledTimes(1)
  })

  it("bounds pending form ids and evicts the oldest request", async () => {
    const events = []
    for (let id = 0; id <= 100; id += 1) {
      events.push({ id: `evt_${id}`, type: "form.created", data: { form: { id: `form-${id}`, sessionID: "ses_a", title: "Input", fields: [{ type: "string", key: "answer", label: "Answer" }] } } })
    }
    // Re-use the oldest id, which must have been evicted to make room.
    events.push({ id: "evt_x", type: "form.created", data: { form: { id: "form-0", sessionID: "ses_a", title: "Input", fields: [{ type: "string", key: "answer", label: "Answer" }] } } })

    const host = await createHost(events)
    await new Promise((resolve) => setTimeout(resolve, 50))
    host.cleanup?.()

    expect(spawn).toHaveBeenCalledTimes(102)
  })

  it("suppresses notifications from tracked subagent sessions", async () => {
    const host = await createHost([
      { id: "evt_1", type: "session.created", data: { sessionID: "subagent-session", parentID: "ses_a" } },
      { id: "evt_2", type: "form.created", data: { form: { id: "f1", sessionID: "subagent-session", title: "Input", fields: [{ type: "string", key: "answer", label: "Answer" }] } } },
    ])

    await new Promise((resolve) => setTimeout(resolve, 20))
    host.cleanup?.()

    expect(spawn).not.toHaveBeenCalled()
  })

  it.each(["form.replied", "form.cancelled"])("cleans deduplication state on %s", async (settledType) => {
    const host = await createHost([
      { id: "evt_1", type: "form.created", data: { form: { id: "reusable-form", sessionID: "ses_a", title: "Input", fields: [{ type: "string", key: "answer", label: "Answer" }] } } },
      { id: "evt_2", type: settledType, data: { id: "reusable-form", sessionID: "ses_a" } },
      { id: "evt_3", type: "form.created", data: { form: { id: "reusable-form", sessionID: "ses_a", title: "Input", fields: [{ type: "string", key: "answer", label: "Answer" }] } } },
    ])

    await new Promise((resolve) => setTimeout(resolve, 20))
    host.cleanup?.()

    expect(spawn).toHaveBeenCalledTimes(2)
  })

  it("passes the project directory from ctx.location to peon.sh", async () => {
    const host = await createHost([
      { id: "evt_1", type: "permission.asked", data: { sessionID: "ses_a", id: "p1" } },
    ])

    await new Promise((resolve) => setTimeout(resolve, 20))
    host.cleanup?.()

    expect(payloads()[0]).toMatchObject({
      hook_event_name: "PermissionRequest",
      cwd: "/tmp/example-project",
      source: "opencode",
    })
  })

  it("handles events arriving after setup and aborts the stream on cleanup", async () => {
    const host = await createHost()
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_a" } })
    await host.emit({ type: "session.execution.succeeded", data: { sessionID: "ses_a" } })
    host.cleanup?.()
    expect(hookEvents()).toEqual(["SessionStart", "Stop"])
    expect(host.aborted()).toBe(true)
  })

  it("suppresses duplicate execution starts after the debounce window", async () => {
    vi.spyOn(Date, "now").mockReturnValue(10000)
    const host = await createHost()
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_a" } })
    vi.mocked(Date.now).mockReturnValue(15000)
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_a" } })
    host.cleanup?.()
    expect(hookEvents()).toEqual(["SessionStart"])
  })

  it("starts each primary session independently", async () => {
    const host = await createHost()
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_a" } })
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_b" } })
    host.cleanup?.()
    expect(hookEvents()).toEqual(["SessionStart", "SessionStart"])
  })

  it("suppresses child lifecycle and permission events using v2 sessionID", async () => {
    const host = await createHost()
    await host.emit({ type: "session.created", data: { sessionID: "ses_child", parentID: "ses_a" } })
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_child" } })
    await host.emit({ type: "permission.asked", data: { sessionID: "ses_child", id: "p1" } })
    await host.emit({ type: "session.execution.succeeded", data: { sessionID: "ses_child" } })
    host.cleanup?.()
    expect(hookEvents()).toEqual([])
  })

  it("routes Unix payloads to the explicit hook directory and closes stdin", async () => {
    vi.stubEnv("CLAUDE_PEON_DIR", "/tmp/hook override")
    const host = await createHost()
    await host.emit({ type: "permission.asked", data: { sessionID: "ses_a", id: "p1" } })
    host.cleanup?.()
    expect(spawn).toHaveBeenCalledWith("bash", [path.normalize("/tmp/hook override/peon.sh")], {
      stdio: ["pipe", "ignore", "ignore"],
    })
    expect(stdin.end).toHaveBeenCalledOnce()
    expect(payloads()[0].hook_event_name).toBe("PermissionRequest")
  })

  it("uses PowerShell directly on Windows without requiring peon.sh", async () => {
    vi.mocked(os.platform).mockReturnValue("win32")
    vi.mocked(fs.existsSync).mockImplementation((candidate) => String(candidate).endsWith("peon.ps1"))
    const host = await createHost()
    await host.emit({ type: "permission.asked", data: { sessionID: "ses_a", id: "p1" } })
    host.cleanup?.()
    expect(spawn).toHaveBeenCalledWith("powershell.exe", [
      "-NoProfile", "-NonInteractive", "-File", path.normalize("/tmp/opencode-test-home/.claude/hooks/peon-ping/peon.ps1"),
    ], { stdio: ["pipe", "ignore", "ignore"] })
    expect(payloads()[0].hook_event_name).toBe("PermissionRequest")
    expect(stdin.end).toHaveBeenCalledOnce()
  })

  it("discovers the Windows OpenPeon installation", async () => {
    vi.mocked(os.platform).mockReturnValue("win32")
    vi.mocked(fs.existsSync).mockImplementation((candidate) => String(candidate) === path.normalize("/tmp/opencode-test-home/.openpeon/hooks/peon-ping/peon.ps1"))
    const host = await createHost()
    await host.emit({ type: "permission.asked", data: { sessionID: "ses_a", id: "p1" } })
    host.cleanup?.()
    expect(spawn).toHaveBeenCalledWith("powershell.exe", [
      "-NoProfile", "-NonInteractive", "-File", path.normalize("/tmp/opencode-test-home/.openpeon/hooks/peon-ping/peon.ps1"),
    ], { stdio: ["pipe", "ignore", "ignore"] })
  })

  it("contains asynchronous launch and stdin failures", async () => {
    const child = Object.assign(new EventEmitter(), {
      stdin: Object.assign(new EventEmitter(), { write: vi.fn(), end: vi.fn() }),
      unref: vi.fn(),
    })
    vi.mocked(spawn).mockReturnValueOnce(child as any)
    const host = await createHost()
    await host.emit({ type: "permission.asked", data: { sessionID: "ses_a", id: "p1" } })
    expect(() => child.emit("error", new Error("ENOENT"))).not.toThrow()
    expect(() => child.stdin.emit("error", new Error("EPIPE"))).not.toThrow()
    host.cleanup?.()
  })

  it("clears busy state on interruption without announcing successful completion", async () => {
    vi.spyOn(Date, "now").mockReturnValue(10000)
    const host = await createHost()
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_a" } })
    await host.emit({ type: "session.execution.interrupted", data: { sessionID: "ses_a", reason: "user" } })
    vi.mocked(Date.now).mockReturnValue(15000)
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_a" } })
    host.cleanup?.()
    expect(hookEvents()).toEqual(["SessionStart", "UserPromptSubmit"])
  })

  it("ignores another location on the global server stream", async () => {
    const host = await createHost()
    await host.emit({
      type: "session.execution.started",
      location: { directory: "/tmp/another-project" },
      data: { sessionID: "ses_elsewhere" },
    })
    await host.emit({
      type: "permission.asked",
      location: { directory: "/tmp/example-project" },
      data: { sessionID: "ses_a", id: "p1" },
    })
    host.cleanup?.()
    expect(hookEvents()).toEqual(["PermissionRequest"])
  })

  it("resolves an unscoped execution's session before forwarding a global event", async () => {
    const host = await createHost([], "/tmp/another-project")
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_elsewhere" } })
    await host.emit({ type: "session.execution.succeeded", data: { sessionID: "ses_elsewhere" } })
    host.cleanup?.()
    expect(hookEvents()).toEqual([])
  })

  it("forwards each global event once when two plugin instances share a project", async () => {
    const first = await createHost()
    const second = await createHost()
    const event = { id: "evt_shared", type: "permission.asked", data: { sessionID: "ses_a", id: "p1" } }
    await first.emit(event)
    await second.emit(event)
    first.cleanup?.()
    second.cleanup?.()
    expect(hookEvents()).toEqual(["PermissionRequest"])
  })

  it("allows a surviving project instance to own notifications after cleanup", async () => {
    const first = await createHost()
    const second = await createHost()
    first.cleanup?.()
    await second.emit({ type: "permission.asked", data: { sessionID: "ses_a", id: "p1" } })
    second.cleanup?.()
    expect(hookEvents()).toEqual(["PermissionRequest"])
  })

  it("clears deleted session state even when the host can no longer retrieve it", async () => {
    const host = await createHost()
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_a" } })
    host.getSession.mockRejectedValueOnce(new Error("Session was deleted"))
    await host.emit({ type: "session.deleted", data: { sessionID: "ses_a" } })
    host.getSession.mockReset()
    host.getSession.mockResolvedValue({ id: "ses_a", location: { directory: "/tmp/example-project" } })
    await host.emit({ type: "session.execution.started", data: { sessionID: "ses_a" } })
    host.cleanup?.()
    expect(hookEvents()).toEqual(["SessionStart", "SessionStart"])
  })

  it("does not deliver an in-flight session lookup after cleanup", async () => {
    let resolveSession!: (session: Record<string, any>) => void
    const lookup = new Promise<Record<string, any>>((resolve) => { resolveSession = resolve })
    const host = await createHost([], "/tmp/example-project", lookup)
    await host.emit({ type: "permission.asked", data: { sessionID: "ses_a", id: "p1" } })
    host.cleanup?.()
    resolveSession({ id: "ses_a", location: { directory: "/tmp/example-project" } })
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(hookEvents()).toEqual([])
  })
})
