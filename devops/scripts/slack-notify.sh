#!/usr/bin/env bash
# Notificação Slack — CI/CD AeroRF
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

export EMOJI TITLE BODY SLACK_WEBHOOK_URL="${WEBHOOK}"
python3 <<'PY'
import json, os, urllib.request
emoji = os.environ.get("EMOJI", "")
title = os.environ.get("TITLE", "AeroRF")
body = os.environ.get("BODY", "")
text = f"{emoji} *{title}*\n{body}"
payload = json.dumps({"text": text}).encode()
req = urllib.request.Request(
    os.environ["SLACK_WEBHOOK_URL"],
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST",
)
urllib.request.urlopen(req, timeout=15)
print("[slack] OK")
PY
