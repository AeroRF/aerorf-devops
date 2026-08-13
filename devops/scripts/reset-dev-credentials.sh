#!/usr/bin/env bash
# Reset credenciais dev — invocado via GitHub Actions (workflow reset-dev-credentials)
# - Grafana: grafana-cli admin reset-admin-password
# - AeroRF admin: POST /api/v1/public/dev/reset-admin-invite (convite Resend)
set -euo pipefail

log() { printf '[reset-dev] %s\n' "$*"; }

RESET_GRAFANA="${RESET_GRAFANA:-1}"
RESET_PLATFORM_ADMIN="${RESET_PLATFORM_ADMIN:-1}"
DEV_ADMIN_EMAIL="${DEV_ADMIN_EMAIL:-admin@aerorf.com.br}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"
DEV_OPS_TOKEN="${DEV_OPS_TOKEN:-}"

reset_grafana() {
  if [[ "${RESET_GRAFANA}" != "1" ]]; then
    log "Grafana skip (RESET_GRAFANA=${RESET_GRAFANA})"
    return 0
  fi
  if ! docker ps --format '{{.Names}}' | grep -qx aerorf_grafana; then
    log "Container aerorf_grafana não está rodando — skip Grafana"
    return 0
  fi
  log "Reset senha Grafana (admin)..."
  docker exec aerorf_grafana grafana-cli admin reset-admin-password "${GRAFANA_ADMIN_PASSWORD}"
  log "Grafana OK — user: admin (ou GRAFANA_ADMIN_USER do compose)"
}

reset_platform_admin() {
  if [[ "${RESET_PLATFORM_ADMIN}" != "1" ]]; then
    log "Plataforma skip (RESET_PLATFORM_ADMIN=${RESET_PLATFORM_ADMIN})"
    return 0
  fi
  if [[ -z "${DEV_OPS_TOKEN}" ]]; then
    log "ERRO: DEV_OPS_TOKEN não definido — configure secret no GitHub e redeploy API"
    exit 1
  fi
  if ! curl -sf http://127.0.0.1:4000/api/v1/health >/dev/null 2>&1; then
    log "ERRO: API não responde em :4000 — rode Deploy Development antes"
    exit 1
  fi
  log "Reenviando convite Resend para ${DEV_ADMIN_EMAIL}..."
  local code
  code="$(curl -s -o /tmp/aerorf-reset-admin.json -w '%{http_code}' \
    -X POST "http://127.0.0.1:4000/api/v1/public/dev/reset-admin-invite" \
    -H "Content-Type: application/json" \
    -H "X-Dev-Ops-Token: ${DEV_OPS_TOKEN}" \
    -d "{\"email\":\"${DEV_ADMIN_EMAIL}\"}")"
  if [[ "${code}" != "200" ]]; then
    log "Falha reset admin (HTTP ${code}):"
    head -c 500 /tmp/aerorf-reset-admin.json 2>/dev/null || true
    echo ""
    exit 1
  fi
  log "Plataforma OK — $(tr -d '\n' < /tmp/aerorf-reset-admin.json | head -c 200)"
  log "Verifique a caixa de e-mail de ${DEV_ADMIN_EMAIL} (link /ativar-conta, válido 24h)"
}

reset_grafana
reset_platform_admin
log "Reset concluído."
