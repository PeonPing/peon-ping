import { EventEmitter } from "node:events"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

class FakeProcess extends EventEmitter {
  stdin = Object.assign(new EventEmitter(), { end: vi.fn() })
  unref = vi.fn()
}

vi.mock("node:fs", () => ({
  existsSync: vi.fn(() => true),
}))

vi.mock("node:os", () => ({
  homedir: () => "/tmp/omp-test-home",
}))

vi.mock("node:child_process", () => ({
  spawn: vi.fn(() => new FakeProcess()),
}))

import peonPingExtension from "../adapters/omp/peon-ping.js"

type Handler = (event: Record<string, unknown>, ctx: Record<string, unknown>) => unknown

// What omp passes in the TUI and in --mode rpc / rpc-ui alike: both report hasUI.
const MAIN_WITH_UI = { hasUI: true, agent: { kind: "main", id: "0-Main", name: "main", depth: 0 } }

type Emit = (name: string, event?: Record<string, unknown>) => Promise<void>

function loadExtension(): Emit {
  const handlers = new Map<string, Handler[]>()
  const fakePi = {
    on: (name: string, handler: Handler) => {
      handlers.set(name, [...(handlers.get(name) ?? []), handler])
    },
  }
  const pi = fakePi as unknown as Parameters<typeof peonPingExtension>[0]
  peonPingExtension(pi)
  return async (name: string, event: Record<string, unknown> = {}) => {
    for (const handler of handlers.get(name) ?? []) await handler({ type: name, ...event }, MAIN_WITH_UI)
  }
}

async function runOnePrompt(emit: Emit) {
  await emit("session_start")
  await emit("agent_start")
  await emit("tool_result", { isError: true, toolName: "bash", content: [{ type: "text", text: "exit 1" }] })
  await emit("agent_end")
}

describe("omp adapter tab titles", () => {
  const originalIsTTY = Object.getOwnPropertyDescriptor(process.stdout, "isTTY")
  let titles: string[]

  // Node and Bun leave isTTY undefined on a pipe; it is never false. The own
  // property shadows tty.WriteStream.prototype.isTTY when the runner is on a pty.
  function setStdoutIsTTY(isTTY: true | undefined) {
    Object.defineProperty(process.stdout, "isTTY", { value: isTTY, configurable: true })
  }

  beforeEach(() => {
    titles = []
    vi.spyOn(process, "cwd").mockReturnValue("/tmp/work/my-project")
    vi.spyOn(process.stdout, "write").mockImplementation((chunk: string | Uint8Array) => {
      const match = /^\x1b\]0;(.*)\x07$/s.exec(String(chunk))
      if (match) titles.push(match[1])
      return true
    })
  })

  afterEach(() => {
    vi.restoreAllMocks()
    if (originalIsTTY) Object.defineProperty(process.stdout, "isTTY", originalIsTTY)
    else Reflect.deleteProperty(process.stdout, "isTTY")
  })

  it("sets no tab title when stdout is a pipe, as in omp --mode rpc", async () => {
    // In RPC mode stdout carries the JSON-lines protocol; a title escape glued to
    // the front of a line makes it invalid JSON for the embedder.
    setStdoutIsTTY(undefined)
    await runOnePrompt(loadExtension())

    expect(titles).toEqual([])
  })

  it("still sets the tab title when stdout is a terminal, as in the omp TUI", async () => {
    setStdoutIsTTY(true)
    await runOnePrompt(loadExtension())

    expect(titles).toEqual([
      "my-project: ready",
      "my-project: working",
      "\u25cf my-project: error",
      "\u25cf my-project: done",
    ])
  })
})
