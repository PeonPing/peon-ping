import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest"
import * as fs from "node:fs"
import * as path from "node:path"
import { execFileSync } from "node:child_process"
import { fileURLToPath } from "node:url"

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")

// This crosses the Unix peon.sh boundary. Native PowerShell has its own CI gate.
describe.skipIf(process.platform === "win32")("native adapter failures reach the real core", () => {
  let root: string
  let omp: typeof import("../adapters/omp/peon-ping.js").default
  let opencode: typeof import("../adapters/opencode/peon-ping.js").default
  let cleanup: (() => void) | undefined
  const read = (name: string) => {
    const p = path.join(root, name)
    return fs.existsSync(p) ? fs.readFileSync(p, "utf8") : ""
  }

  beforeAll(async () => {
    const fixture = JSON.parse(execFileSync("bash", ["-c", `
      source "$1"
      setup_test_env
      "$PEON_PY" -c 'import os,json; print(json.dumps({k:os.environ[k] for k in ["TEST_DIR","CLAUDE_PEON_DIR","PATH","PEON_TEST"]}))'
    `, "fixture", path.join(repo, "tests/setup.bash")], { encoding: "utf8" }))
    root = fixture.TEST_DIR
    for (const [key, value] of Object.entries(fixture)) vi.stubEnv(key, value as string)
    vi.stubEnv("HOME", path.join(root, "home"))
    vi.stubEnv("PEON_CORE", path.join(repo, "peon.sh"))
    const hook = '#!/bin/bash\npayload=$(cat)\nprintf "%s\\n" "$payload" >> "$CLAUDE_PEON_DIR/payloads.jsonl"\nprintf "%s" "$payload" | bash "$PEON_CORE"\n'
    const ompHook = path.join(root, "home/.claude/hooks/peon-ping")
    fs.mkdirSync(ompHook, { recursive: true })
    fs.writeFileSync(path.join(ompHook, "peon.sh"), hook)
    fs.writeFileSync(path.join(root, "peon.sh"), hook)
    const configPath = path.join(root, "config.json")
    const config = JSON.parse(fs.readFileSync(configPath, "utf8"))
    Object.assign(config, { desktop_notifications: false, terminal_tab_title: false, use_sound_effects_device: false })
    fs.writeFileSync(configPath, JSON.stringify(config))
    omp = (await import("../adapters/omp/peon-ping.js")).default
    opencode = (await import("../adapters/opencode/peon-ping.js")).default
  })

  beforeEach(() => {
    for (const name of ["afplay.log", "linux_audio.log", "payloads.jsonl"]) {
      fs.rmSync(path.join(root, name), { force: true })
    }
    fs.writeFileSync(path.join(root, ".state.json"), "{}")
  })
  afterEach(() => { cleanup?.(); cleanup = undefined })
  afterAll(() => {
    vi.unstubAllEnvs()
    if (root) fs.rmSync(root, { recursive: true, force: true })
  })

  it.each(["omp", "opencode-v1", "opencode-v2"])("%s preserves real failure detail and plays task.error without a fabricated Bash tool", async (kind) => {
    const cwd = repo
    if (kind === "omp") {
      const handlers = new Map<string, Function>()
      omp({ on: (name: string, handler: Function) => handlers.set(name, handler) } as any)
      await handlers.get("tool_result")!({
        type: "tool_result", toolName: "read", toolCallId: "call-1", input: { path: "missing.txt" },
        content: [{ type: "text", text: "File missing: missing.txt" }], isError: true, details: undefined,
      }, { hasUI: false, agent: { kind: "main", id: "main", depth: 0 } })
    } else if (kind === "opencode-v1") {
      const hooks = await opencode.server({ directory: cwd, client: { session: { get: async () => ({ data: { directory: cwd } }) } } })
      cleanup = hooks.dispose
      await hooks.event!({ event: { type: "session.error", properties: {
        sessionID: "native-error", error: { name: "APIError", data: { message: "Provider unavailable" } },
      } } })
    } else {
      cleanup = await opencode.setup({ location: { directory: cwd }, session: { get: async () => ({ location: { directory: cwd } }) }, event: {
        subscribe: async function* () { yield { type: "session.execution.failed", data: {
          sessionID: "native-error", error: { type: "provider.no-route", message: "Provider unavailable" },
        } } },
      } })
    }
    await vi.waitFor(() => {
      expect(read("afplay.log") + read("linux_audio.log")).toContain("/packs/peon/sounds/Error1.wav")
    }, { timeout: 5000 })
    const [payload] = read("payloads.jsonl").trim().split("\n").map(s => JSON.parse(s))
    expect(payload.hook_event_name).toBe("PostToolUseFailure")
    expect(payload.error).toBe(kind === "omp" ? "File missing: missing.txt" : "Provider unavailable")
    if (kind === "omp") expect(payload.tool_name).toBe("read")
    else {
      expect(payload.tool_name).not.toBe("Bash")
      expect(payload.session_id).toBe("opencode-native-error")
    }
  }, 10000)
})
