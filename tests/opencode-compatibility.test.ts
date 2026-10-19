import { afterEach, expect, it, vi } from "vitest"
import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import plugin from "../adapters/opencode/peon-ping.js"

let root: string
let cleanup: (() => void) | undefined
afterEach(() => {
  cleanup?.()
  vi.unstubAllEnvs()
  if (root) fs.rmSync(root, { recursive: true, force: true })
})

function captureHook() {
  root = fs.mkdtempSync(path.join(os.tmpdir(), "peon-contract-"))
  const directory = path.join(root, "project α")
  const hook = path.join(root, "custom hook")
  const capture = path.join(root, "events")
  fs.mkdirSync(directory)
  fs.mkdirSync(hook)
  fs.mkdirSync(capture)
  vi.stubEnv("CLAUDE_PEON_DIR", hook)
  vi.stubEnv("PEON_CAPTURE", capture)
  // Each event has its own process. Concurrent AppendAllText calls can overwrite
  // one another even when every PowerShell process exits successfully.
  fs.writeFileSync(path.join(hook, "peon.sh"), '#!/bin/bash\npayload=$(cat)\nprintf "%s" "$payload" > "$PEON_CAPTURE/$$.json"\n')
  fs.writeFileSync(path.join(hook, "peon.ps1"), `
$stream = [Console]::OpenStandardInput()
$reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
$payload = $reader.ReadToEnd()
$reader.Close()
$capture = Join-Path $env:PEON_CAPTURE "$PID.json"
[System.IO.File]::WriteAllText($capture, $payload, (New-Object System.Text.UTF8Encoding $false))
`)
  return { directory, read: () => fs.readdirSync(capture).map(file => JSON.parse(fs.readFileSync(path.join(capture, file), "utf8"))) }
}

it("v1 server forwards independent native sessions and suppresses child permission events", async () => {
  const capture = captureHook()
  expect((plugin as any).server).toBeTypeOf("function")
  const hooks = await (plugin as any).server({
    directory: capture.directory,
    client: { session: { get: async ({ path: { id } }: any) => ({ data: { id, directory: capture.directory, parentID: id === "child" ? "a" : undefined } }) } },
  })
  cleanup = () => hooks.event({ event: { type: "server.instance.disposed" } })
  for (const id of ["a", "b", "child"]) {
    await hooks.event({ event: { type: "session.created", properties: { info: { id, directory: capture.directory, parentID: id === "child" ? "a" : undefined } } } })
  }
  await hooks.event({ event: { type: "permission.asked", properties: { id: "private", sessionID: "child" } } })
  await hooks.event({ event: { type: "session.idle", properties: { sessionID: "a" } } })
  await hooks.event({ event: { type: "session.idle", properties: { sessionID: "b" } } })
  await vi.waitFor(() => {
    const events = capture.read()
    expect(events).toHaveLength(4)
    expect(events.map(e => [e.hook_event_name, e.session_id]).sort()).toEqual([
      ["SessionStart", "opencode-a"], ["SessionStart", "opencode-b"], ["Stop", "opencode-a"], ["Stop", "opencode-b"],
    ])
    expect(events.every(e => e.cwd === capture.directory && e.source === "opencode")).toBe(true)
  }, { timeout: 5000 })
}, 10000)

it("v2 setup forwards native session identities within one physical project", async () => {
  const capture = captureHook()
  cleanup = await plugin.setup({
    location: { directory: capture.directory },
    session: { get: async () => ({ location: { directory: capture.directory } }) },
    event: { subscribe: async function* () {
      for (const sessionID of ["a", "b"]) {
        yield { type: "session.execution.started", data: { sessionID } }
        yield { type: "session.execution.succeeded", data: { sessionID } }
      }
    } },
  })
  await vi.waitFor(() => {
    expect(capture.read().map(e => [e.hook_event_name, e.session_id]).sort()).toEqual([
      ["SessionStart", "opencode-a"], ["SessionStart", "opencode-b"], ["Stop", "opencode-a"], ["Stop", "opencode-b"],
    ])
  }, { timeout: 5000 })
}, 10000)
