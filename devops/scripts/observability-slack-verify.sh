#!/usr/bin/env bash
# Verifica observabilidade + ping Slack (Alertmanager) após deploy
set -euo pipefail

log() { printf '[observability] %s\n' "$*"; }

COMPOSE_DIR="${COMPOSE_DIR:-$HOME/aerorf/aerorf-devops/compose}"
DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"

WEBHOOK="${SLACK_WEBHOOK_URL:-}"
if [[ -z "${WEBHOOK}" && -f "${COMPOSE_DIR}/.env.dev" ]]; then
  WEBHOOK="$(grep '^SLACK_WEBHOOK_URL=' "${COMPOSE_DIR}/.env.dev" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
fi

compose_dev() {
  docker compose --project-name aerorf-dev --env-file "${COMPOSE_DIR}/.env.dev" \
    -f "${COMPOSE_DIR}/docker-compose.dev.yml" "$@"
}

reload_alertmanager() {
  if [[ -z "${WEBHOOK}" ]]; then
    log "SLACK_WEBHOOK_URL vazio — Alertmanager em modo null (sem Slack)"
    return 0
  fi
  log "Recarregando Alertmanager com webhook Slack..."
  compose_dev up -d --force-recreate alertmanager
  sleep 4
  if curl -sf http://127.0.0.1:9093/-/healthy >/dev/null 2>&1; then
    log "Alertmanager healthy (:9093)"
  else
    log "Alertmanager não responde — logs:"
    docker logs "$(docker ps -qf 'name=alertmanager' | head -1)" --tail 25 2>&1 || docker ps -a | grep -i alert || true
  fi
}

check_prometheus() {
  if ! curl -sf http://127.0.0.1:9090/-/healthy >/dev/null 2>&1; then
    log "Prometheus offline"
    return 1
  fi
  local groups targets_up targets_down
  groups="$(curl -sf 'http://127.0.0.1:9090/api/v1/rules' 2>/dev/null | grep -c '"name":' || echo 0)"
  targets_up="$(curl -sf 'http://127.0.0.1:9090/api/v1/targets' 2>/dev/null | grep -c '"health":"up"' || echo 0)"
  targets_down="$(curl -sf 'http://127.0.0.1:9090/api/v1/targets' 2>/dev/null | grep -c '"health":"down"' || echo 0)"
  log "Prometheus OK — ${groups} rule groups, targets up=${targets_up} down=${targets_down}"
}

slack_ping() {
  [[ -n "${WEBHOOK}" ]] || return 0
  log "Ping Slack (observabilidade configurada)..."
  export WEBHOOK
  python3 <<'PY'
import json, os, urllib.request
webhook = os.environ["WEBHOOK"]
payload = {
    "blocks": [
        {"type": "header", "text": {"type": "plain_text", "text": "📊 AeroRF Observability", "emoji": True}},
        {"type": "section", "text": {"type": "mrkdwn", "text": (
            "Alertmanager conectado ao Slack após deploy.\n"
            "Alertas Prometheus (5xx, CPU, login, disco, etc.) serão enviados a este canal."
        )}},
    ]
}
req = urllib.request.Request(webhook, data=json.dumps(payload).encode(),
    headers={"Content-Type": "application/json"}, method="POST")
urllib.request.urlopen(req, timeout=15)
print("[observability] Slack ping OK")
PY
}

reload_alertmanager
check_prometheus || true
slack_ping
