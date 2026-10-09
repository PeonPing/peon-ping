import { EventEmitter } from "node:events"
import { beforeEach, describe, expect, it, vi } from "vitest"

class FakeStdin extends EventEmitter {
  written = ""
  write = vi.fn((chunk: string) => {
    this.written += chunk
    return true
  })
  end = vi.fn((chunk?: string) => {
    if (chunk) this.written += chunk
  })
}

class FakeProcess extends EventEmitter {
  stdin = new FakeStdin()
  unref = vi.fn()
}

const spawned: FakeProcess[] = []

vi.mock("node:fs", () => ({
  existsSync: vi.fn(() => true),
}))

vi.mock("node:os", () => ({
  homedir: () => "/tmp/omp-test-home",
}))

vi.mock("node:child_process", () => ({
  spawn: vi.fn(() => {
    const proc = new FakeProcess()
    spawned.push(proc)
    return proc
  }),
}))

import peonPingExtension from "../adapters/omp/peon-ping.js"

type Handler = (event: Record<string, unknown>, ctx: Record<string, unknown>) => unknown

const MAIN = { hasUI: false, agent: { kind: "main", id: "0-Main", name: "main", depth: 0 } }
const SUB = { hasUI: false, agent: { kind: "sub", id: "0-Explore", name: "explore", depth: 1, parentId: "0-Main" } }
// omp before 18.3.2 has no ctx.agent at all.
const OLD_OMP = { hasUI: false }

function loadExtension() {
  const handlers = new Map<string, Handler[]>()
  const fakePi = {
    on: (name: string, handler: Handler) => {
      handlers.set(name, [...(handlers.get(name) ?? []), handler])
    },
  }
  // The adapter only calls pi.on; the real ExtensionAPI has dozens of members this
  // test has no use for.
  const pi = fakePi as unknown as Parameters<typeof peonPingExtension>[0]
  peonPingExtension(pi)
  return async (name: string, event: Record<string, unknown> = {}, ctx: Record<string, unknown> = MAIN) => {
    for (const handler of handlers.get(name) ?? []) await handler({ type: name, ...event }, ctx)
  }
}

function firedEvents(): string[] {
  return spawned.map((proc) => JSON.parse(proc.stdin.written).hook_event_name)
}

describe("omp adapter", () => {
  beforeEach(() => {
    spawned.length = 0
  })

  it("fires UserPromptSubmit and Stop once per prompt, however many model turns it takes", async () => {
    const emit = loadExtension()
    await emit("agent_start")
    for (let turn = 0; turn < 3; turn++) {
      await emit("turn_start", { turnIndex: turn })
      await emit("tool_result", { isError: false })
      await emit("turn_end", { turnIndex: turn })
    }
    await emit("agent_end")

    expect(firedEvents()).toEqual(["UserPromptSubmit", "Stop"])
  })

  it("sends nothing to peon.sh for a subagent's events", async () => {
    const emit = loadExtension()
    await emit("session_start", {}, SUB)
    await emit("agent_start", {}, SUB)
    await emit("turn_start", { turnIndex: 0 }, SUB)
    await emit("tool_result", { isError: true }, SUB)
    await emit("turn_end", { turnIndex: 0 }, SUB)
    await emit("auto_compaction_start", {}, SUB)
    await emit("agent_end", {}, SUB)
    await emit("session_shutdown", {}, SUB)

    expect(firedEvents()).toEqual([])
  })

  it("does not fire Stop for an agent_end that omp will continue", async () => {
    const emit = loadExtension()
    // A retry: omp ends the first run with willContinue, then runs the agent again
    // as a new loop, with its own agent_start and agent_end.
    await emit("agent_start")
    await emit("agent_end", { willContinue: true })
    await emit("agent_start")
    await emit("agent_end")

    expect(firedEvents()).toEqual(["UserPromptSubmit", "UserPromptSubmit", "Stop"])
  })

  it("still fires every event on omp versions without ctx.agent", async () => {
    const emit = loadExtension()
    await emit("session_start", {}, OLD_OMP)
    await emit("agent_start", {}, OLD_OMP)
    await emit("tool_result", { isError: true }, OLD_OMP)
    await emit("auto_compaction_start", {}, OLD_OMP)
    await emit("agent_end", {}, OLD_OMP)
    await emit("session_shutdown", {}, OLD_OMP)

    expect(firedEvents()).toEqual([
      "SessionStart",
      "UserPromptSubmit",
      "PostToolUseFailure",
      "PreCompact",
      "Stop",
      "SessionEnd",
    ])
  })

  it("a failed spawn or a closed stdin does not throw into omp", async () => {
    const emit = loadExtension()
    await emit("agent_start")
    const [proc] = spawned

    // Both arrive asynchronously in real life. An EventEmitter with no "error"
    // listener rethrows, which inside omp is an uncaught exception.
    expect(() => proc.emit("error", Object.assign(new Error("spawn bash EAGAIN"), { code: "EAGAIN" }))).not.toThrow()
    expect(() => proc.stdin.emit("error", Object.assign(new Error("write EPIPE"), { code: "EPIPE" }))).not.toThrow()
  })
})
