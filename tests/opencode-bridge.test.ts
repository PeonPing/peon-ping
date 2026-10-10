import { afterEach, expect, it, vi } from "vitest"
import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import plugin from "../adapters/opencode/peon-ping.js"

let temporaryDirectory: string | undefined
let cleanup: (() => void) | undefined

afterEach(() => {
  cleanup?.()
  vi.unstubAllEnvs()
  if (temporaryDirectory) fs.rmSync(temporaryDirectory, { recursive: true, force: true })
})

it.each(["direct", "symlink"])("delivers UTF-8 stdin JSON through a literal native script path and %s project location", async (locationKind) => {
  temporaryDirectory = fs.mkdtempSync(path.join(process.env.PEON_TEST_TMPDIR || os.tmpdir(), "peon-opencode-bridge-"))
  const hookDirectory = path.join(temporaryDirectory, "hook $bridge 'α space")
  fs.mkdirSync(hookDirectory)
  const capture = path.join(temporaryDirectory, "payload.json")
  vi.stubEnv("CLAUDE_PEON_DIR", hookDirectory)
  vi.stubEnv("PEON_BRIDGE_TEST_CAPTURE", capture)

  if (process.platform === "win32") {
    fs.writeFileSync(path.join(hookDirectory, "peon.ps1"), `
$stream = [Console]::OpenStandardInput()
$reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
$payload = $reader.ReadToEnd()
$reader.Close()
[System.IO.File]::WriteAllText($env:PEON_BRIDGE_TEST_CAPTURE, $payload, (New-Object System.Text.UTF8Encoding $false))
`)
  } else {
    fs.writeFileSync(path.join(hookDirectory, "peon.sh"), '#!/bin/bash\ncat > "$PEON_BRIDGE_TEST_CAPTURE"\n')
  }

  const directory = path.join(temporaryDirectory, "project 日本語")
  fs.mkdirSync(directory)
  const eventDirectory = locationKind === "direct" ? directory : path.join(temporaryDirectory, "project alias")
  if (locationKind === "symlink") fs.symlinkSync(directory, eventDirectory, "junction")
  cleanup = await plugin.setup({
    location: { directory },
    session: { get: async () => ({ location: { directory } }) },
    event: {
      subscribe: async function* () {
        yield { type: "permission.asked", location: { directory: eventDirectory }, data: { sessionID: "ses_primary", id: "private_request" } }
      },
    },
  })

  await vi.waitFor(() => {
    const payload = JSON.parse(fs.readFileSync(capture, "utf8"))
    expect(payload).toEqual({
      hook_event_name: "PermissionRequest",
      notification_type: "",
      cwd: directory,
      session_id: expect.stringMatching(/^oc-\d+$/),
      permission_mode: "",
      source: "opencode",
    })
  }, { timeout: 10000 })
}, 10000)
