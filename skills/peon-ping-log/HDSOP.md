---
standard: "https://hypercontext.wiki/standards/hdsop/v2"
title: "Log exercise reps for the Peon Trainer"
id: peon-ping-log
version: 0.1
skill: peon-ping-log
doc_status: drafting
tags: [peon-ping, trainer, fitness]
frequency: "unknown"
est_time_per_run: "unknown"
automation_potential: "unknown"
related_skills: []
related_workflows: []
concepts: []
---

# Purpose
A number of push-ups or squats the user did is recorded with the Peon Trainer, which prints the updated rep count and plays a trainer voice line. Without it, the reps are not counted.

# When to use (Trigger)
The user says they did push-ups or squats, or wants to log reps. Examples: "/peon-ping-log 25 pushups", "/peon-ping-log 30 squats", "log 50 pushups".

# Inputs / Prerequisites
- A rep count and an exercise, either `pushups` or `squats`.
- peon-ping installed, with `~/.claude/hooks/peon-ping/peon.sh`.
- The trainer turned on. If it is off, the command says so.

# Roles
| Role | Responsibility |
|---|---|
| **Human operator** | Gives the count and the exercise. |
| **Agent executor** | Runs the command and reports its output. |
| **Script** | `peon.sh trainer log` records the reps and plays the voice line. |

# Procedure

Steps say WHAT happens and who does it. The map is drawn from the block below.

```json steps
{
  "ends": [
    {
      "id": "reps-logged",
      "what": "The reps are recorded and the user has seen the updated count."
    },
    {
      "id": "trainer-off",
      "what": "The trainer is not enabled and the user has been told how to enable it."
    }
  ],
  "steps": [
    {
      "id": "read-count-and-exercise",
      "what": "Take the number and the exercise (pushups or squats) from the user's request.",
      "actor": "agent"
    },
    {
      "id": "run-log-command",
      "what": "Run bash ~/.claude/hooks/peon-ping/peon.sh trainer log <count> <exercise>.",
      "actor": "script:peon.sh",
      "after": [
        "read-count-and-exercise"
      ],
      "outcomes": [
        {
          "when": "output says the trainer is not enabled",
          "then": "tell-how-to-enable"
        },
        {
          "when": "the count is logged",
          "then": "report-output"
        }
      ]
    },
    {
      "id": "tell-how-to-enable",
      "what": "Tell the user to run /peon-ping-toggle or peon trainer on first.",
      "actor": "agent",
      "after": [
        "run-log-command"
      ],
      "outcomes": [
        {
          "when": "told",
          "then": "trainer-off"
        }
      ]
    },
    {
      "id": "report-output",
      "what": "Report the output to the user. It prints the updated rep count.",
      "actor": "agent",
      "after": [
        "run-log-command"
      ],
      "outcomes": [
        {
          "when": "reported",
          "then": "reps-logged"
        }
      ]
    }
  ]
}
```

# Done / Verification
- The command printed the updated rep count.
- The user has seen that output.
- If the user asked for progress, the status command was also run: `bash ~/.claude/hooks/peon-ping/peon.sh trainer status`.

# Exceptions & Troubleshooting
- **The trainer is not enabled.** Tell the user to run `/peon-ping-toggle` or `peon trainer on` first.

# Automation Opportunities
- unknown. The skill does not list any.

# Related
- `/peon-ping-toggle`: turns the trainer on when it is off.

# Revision History
| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-11-06T21:51:00Z | First map, drafted from SKILL.md. |
