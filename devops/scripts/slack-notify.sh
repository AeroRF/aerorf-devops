#!/usr/bin/env bash
# Notificação Slack — CI/CD AeroRF (mensagens legíveis com blocks)
set -euo pipefail

STATUS="${1:-unknown}"
TITLE="${2:-AeroRF}"
BODY="${3:-}"

WEBHOOK="${SLACK_WEBHOOK_URL:-}"
if [[ -z "${WEBHOOK}" ]]; then
  echo "[slack] SLACK_WEBHOOK_URL não configurado — skip."
  exit 0
fi

EMOJI="ℹ️"
case "${STATUS}" in
  success) EMOJI="✅" ;;
  failure) EMOJI="❌" ;;
  started) EMOJI="🚀" ;;
esac

export EMOJI TITLE BODY STATUS SLACK_WEBHOOK_URL="${WEBHOOK}"
python3 <<'PY'
import json
import os
import urllib.request

emoji = os.environ.get("EMOJI", "")
title = os.environ.get("TITLE", "AeroRF")
body = os.environ.get("BODY", "").replace("\\n", "\n")
status = os.environ.get("STATUS", "unknown")

fields = []
for line in body.strip().splitlines():
    line = line.strip()
    if not line:
        continue
    if ":" in line:
        key, val = line.split(":", 1)
        fields.append({"type": "mrkdwn", "text": f"*{key.strip()}*\n`{val.strip()}`"})
    else:
        fields.append({"type": "mrkdwn", "text": line})

blocks = [
    {
        "type": "header",
        "text": {"type": "plain_text", "text": f"{emoji} {title}", "emoji": True},
    },
    {
        "type": "context",
        "elements": [{"type": "mrkdwn", "text": f"*Status:* `{status}`"}],
    },
]

if fields:
    for i in range(0, len(fields), 10):
        blocks.append({"type": "section", "fields": fields[i : i + 10]})

payload = json.dumps({"blocks": blocks}).encode()
req = urllib.request.Request(
    os.environ["SLACK_WEBHOOK_URL"],
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST",
)
urllib.request.urlopen(req, timeout=15)
print("[slack] OK")
PY
