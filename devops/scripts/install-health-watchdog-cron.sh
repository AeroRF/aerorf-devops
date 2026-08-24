#!/usr/bin/env bash
# Instala cron do health-watchdog (a cada 5 min) no usuário do deploy
set -euo pipefail

log() { printf '[watchdog-cron] %s\n' "$*"; }

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
SCRIPT="${DEVOPS_DIR}/devops/scripts/health-watchdog.sh"
CRON_LINE="*/5 * * * * DEVOPS_DIR=${DEVOPS_DIR} ${SCRIPT} >> ${DEVOPS_DIR}/logs/health-watchdog/cron.log 2>&1"

if [[ ! -x "${SCRIPT}" ]]; then
  chmod +x "${SCRIPT}" 2>/dev/null || true
fi

if [[ ! -f "${SCRIPT}" ]]; then
  log "Script ausente: ${SCRIPT}"
  exit 1
fi

mkdir -p "${DEVOPS_DIR}/logs/health-watchdog"

existing="$(crontab -l 2>/dev/null || true)"
if echo "${existing}" | grep -Fq "health-watchdog.sh"; then
  log "Cron já instalado — atualizando entrada"
  filtered="$(echo "${existing}" | grep -Fv "health-watchdog.sh" || true)"
  printf '%s\n%s\n' "${filtered}" "${CRON_LINE}" | crontab -
else
  { echo "${existing}"; echo "${CRON_LINE}"; } | crontab -
fi

log "Cron instalado: ${CRON_LINE}"
crontab -l | grep health-watchdog || true
