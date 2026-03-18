#!/bin/bash
AGENT_LOG_FILE=".gitban/agents/executor/logs/TECHDEBT2-augpn7-executor-1.jsonl"
agent_log_event() {
  local event="$1" data="$2"
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"$event\",\"data\":$data}" >> "$AGENT_LOG_FILE"
}
agent_log_summary() {
  agent_log_event "summary" '{"status":"complete"}'
}
# Init
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"init\",\"data\":{\"role\":\"executor\",\"sprint\":\"TECHDEBT2\",\"card\":\"augpn7\",\"cycle\":1}}" > "$AGENT_LOG_FILE"
