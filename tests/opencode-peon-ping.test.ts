import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

const stdin = {
  write: vi.fn(),
  end: vi.fn(),
}
const spawnedProcess = {
  stdin,
  unref: vi.fn(),
}

vi.mock("node:fs", () => ({
  existsSync: vi.fn(() => true),
}))

vi.mock("node:child_process", () => ({
  spawn: vi.fn(() => spawnedProcess),
}))

import { spawn } from "node:child_process"
import { PeonPingPlugin } from "../adapters/opencode/peon-ping.js"

async function createEventHandler() {
  const plugin = await PeonPingPlugin({ directory: "/tmp/example-project" } as any)
  return plugin.event!
}

function payloads(): Array<Record<string, unknown>> {
  return stdin.write.mock.calls.map(([payload]) => JSON.parse(payload))
}

describe("PeonPingPlugin question events", () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.clearAllMocks()
    vi.spyOn(process.stdout, "write").mockImplementation(() => true)
  })

  afterEach(() => {
    vi.clearAllTimers()
    vi.useRealTimers()
    vi.restoreAllMocks()
  })

  it("dispatches a private elicitation notification for question.asked", async () => {
    const event = await createEventHandler()
    const sensitiveText = "SENTINEL_SECRET_QUESTION_V1"

    await event({
      event: {
        type: "question.asked",
        properties: {
          id: "question-request-v1",
          sessionID: "primary-session",
          questions: [{ question: sensitiveText, options: [{ label: "Secret option" }] }],
        },
      },
    } as any)

    expect(payloads()).toEqual([{
      hook_event_name: "Notification",
      notification_type: "elicitation_dialog",
      cwd: "/tmp/example-project",
      session_id: expect.stringMatching(/^oc-\d+$/),
      permission_mode: "",
      source: "opencode",
    }])
    expect(stdin.write.mock.calls[0][0]).not.toContain(sensitiveText)
    expect(stdin.write.mock.calls[0][0]).not.toContain("question-request-v1")
  })

  it("dispatches a private elicitation notification for question.v2.asked", async () => {
    const event = await createEventHandler()
    const sensitiveText = "SENTINEL_SECRET_QUESTION_V2"

    await event({
      event: {
        type: "question.v2.asked",
        properties: {
          id: "question-request-v2",
          sessionID: "primary-session",
          questions: [{ question: sensitiveText, options: ["Never serialize me"] }],
        },
      },
    } as any)

    expect(payloads()[0]).toMatchObject({
      hook_event_name: "Notification",
      notification_type: "elicitation_dialog",
    })
    expect(stdin.write.mock.calls[0][0]).not.toContain(sensitiveText)
    expect(stdin.write.mock.calls[0][0]).not.toContain("question-request-v2")
  })

  it("suppresses duplicate v1 and v2 representations with the same id", async () => {
    const event = await createEventHandler()
    const properties = { id: "same-question", sessionID: "primary-session", questions: [] }

    await event({ event: { type: "question.asked", properties } } as any)
    await event({ event: { type: "question.v2.asked", properties } } as any)

    expect(spawn).toHaveBeenCalledTimes(1)
  })

  it("bounds pending question ids and evicts the oldest request", async () => {
    const event = await createEventHandler()

    for (let id = 0; id <= 100; id += 1) {
      await event({
        event: {
          type: "question.asked",
          properties: { id: `question-${id}`, sessionID: "primary-session", questions: [] },
        },
      } as any)
    }
    await event({
      event: {
        type: "question.v2.asked",
        properties: { id: "question-0", sessionID: "primary-session", questions: [] },
      },
    } as any)

    expect(spawn).toHaveBeenCalledTimes(102)
  })

  it("suppresses question notifications from tracked subagent sessions", async () => {
    const event = await createEventHandler()

    await event({
      event: {
        type: "session.created",
        properties: { info: { id: "subagent-session", parentID: "primary-session" } },
      },
    } as any)
    await event({
      event: {
        type: "question.asked",
        properties: { id: "subagent-question", sessionID: "subagent-session", questions: [] },
      },
    } as any)

    expect(spawn).not.toHaveBeenCalled()
  })

  it.each([
    "question.replied",
    "question.rejected",
    "question.v2.replied",
    "question.v2.rejected",
  ])("cleans deduplication state on %s", async (settledType) => {
    const event = await createEventHandler()
    const properties = { id: "reusable-question", sessionID: "primary-session", questions: [] }

    await event({ event: { type: "question.asked", properties } } as any)
    await event({
      event: {
        type: settledType,
        properties: { requestID: "reusable-question", sessionID: "primary-session" },
      },
    } as any)
    await event({ event: { type: "question.v2.asked", properties } } as any)

    expect(spawn).toHaveBeenCalledTimes(2)
  })
})
