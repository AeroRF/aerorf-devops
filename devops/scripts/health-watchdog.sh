#!/usr/bin/env bash
# Watchdog leve no host — pinga API/Web localmente e avisa Slack (independente do Prometheus)
set -euo pipefail

log() { printf '[health-watchdog] %s\n' "$*"; }

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
COMPOSE_DIR="${COMPOSE_DIR:-$DEVOPS_DIR/compose}"
STATE_DIR="${DEVOPS_DIR}/logs/health-watchdog"
STATE_FILE="${STATE_DIR}/state"
ENV_FILE="${COMPOSE_DIR}/.env.dev"

mkdir -p "${STATE_DIR}"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "${ENV_FILE}" 2>/dev/null || true
  set +a
fi

WEBHOOK="${SLACK_WEBHOOK_URL:-}"
AMBIENTE="${AERORF_ENV:-development}"

check_url() {
  local url="$1"
  curl -sf --max-time 8 "${url}" >/dev/null 2>&1
}

api_ok=0
web_ok=0
check_url "http://127.0.0.1:4000/api/v1/health" && api_ok=1
check_url "http://127.0.0.1:3000/api/health" && web_ok=1

if [[ "${api_ok}" -eq 1 && "${web_ok}" -eq 1 ]]; then
  current="up"
else
  current="down"
fi

previous="unknown"
[[ -f "${STATE_FILE}" ]] && previous="$(cat "${STATE_FILE}" 2>/dev/null || echo unknown)"

echo "${current}" > "${STATE_FILE}"

if [[ "${current}" == "${previous}" ]]; then
  exit 0
fi

if [[ -z "${WEBHOOK}" ]]; then
  log "Estado ${previous} → ${current} (Slack não configurado)"
  exit 0
fi

if [[ "${current}" == "down" ]]; then
  title="AeroRF Host Watchdog — apps offline"
  emoji="🚨"
  detail="API local: $([[ ${api_ok} -eq 1 ]] && echo OK || echo FAIL)\nWeb local: $([[ ${web_ok} -eq 1 ]] && echo OK || echo FAIL)\nHost: $(hostname -f 2>/dev/null || hostname)\nAmbiente: ${AMBIENTE}"
else
  title="AeroRF Host Watchdog — apps recuperados"
  emoji="✅"
  detail="API e Web respondendo em localhost.\nAmbiente: ${AMBIENTE}"
fi

export emoji title detail WEBHOOK
python3 <<'PY'
import json, os, urllib.request

webhook = os.environ["WEBHOOK"]
payload = {
    "blocks": [
        {"type": "header", "text": {"type": "plain_text", "text": f"{os.environ['emoji']} {os.environ['title']}", "emoji": True}},
        {"type": "section", "text": {"type": "mrkdwn", "text": os.environ["detail"].replace("\\n", "\n")}},
        {"type": "context", "elements": [{"type": "mrkdwn", "text": "_Watchdog do host — funciona mesmo se Prometheus/Alertmanager estiverem offline_"}]},
    ]
}
req = urllib.request.Request(webhook, data=json.dumps(payload).encode(),
    headers={"Content-Type": "application/json"}, method="POST")
urllib.request.urlopen(req, timeout=15)
print("[health-watchdog] Slack OK")
PY

log "Estado ${previous} → ${current} (Slack enviado)"
