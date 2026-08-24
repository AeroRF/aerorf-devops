#!/usr/bin/env bash
# Captura estado dos containers ANTES do force-recreate (evidência de crash)
set -euo pipefail

log() { printf '[crash-forensics] %s\n' "$*"; }

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
LOG_DIR="${DEVOPS_DIR}/logs/crash-forensics"
mkdir -p "${LOG_DIR}"

TS="$(date -u +%Y-%m-%dT%H%M%SZ)"
REPORT="${LOG_DIR}/${TS}.log"
LATEST="${LOG_DIR}/latest.log"

{
  echo "=== AeroRF crash forensics ${TS} (UTC) ==="
  echo ""
  echo "=== Host ==="
  uptime 2>/dev/null || true
  who -b 2>/dev/null || last reboot 2>/dev/null | head -3 || true
  free -h 2>/dev/null || true
  df -h / 2>/dev/null | tail -1 || true
  echo ""
  echo "=== Docker ==="
  docker info 2>/dev/null | grep -E 'Server Version|Operating System|Total Memory' || true
  echo ""
  echo "=== Containers (all aerorf) ==="
  docker ps -a --filter "name=aerorf" --format "table {{.Names}}\t{{.Status}}\t{{.State}}" 2>/dev/null || true
  echo ""
  echo "=== Inspect api/web (exit, OOM, restarts, timestamps) ==="
  for c in aerorf_api aerorf_web aerorf_postgres aerorf_pgbouncer; do
    if docker inspect "$c" >/dev/null 2>&1; then
      docker inspect "$c" --format \
        '{{.Name}} status={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} restarts={{.RestartCount}} started={{.State.StartedAt}} finished={{.State.FinishedAt}} error={{.State.Error}}' 2>/dev/null
    else
      echo "${c}: (container não existe)"
    fi
  done
  echo ""
  echo "=== OOM kernel (dmesg) ==="
  dmesg -T 2>/dev/null | grep -iE 'killed process|out of memory|oom' | tail -20 || echo "(sem entradas ou dmesg indisponível)"
  echo ""
  echo "=== API logs (últimas 80 linhas do container anterior) ==="
  docker logs aerorf_api --tail 80 2>&1 || echo "(sem logs api)"
  echo ""
  echo "=== Web logs (últimas 40 linhas) ==="
  docker logs aerorf_web --tail 40 2>&1 || echo "(sem logs web)"
} | tee "${REPORT}"

cp -f "${REPORT}" "${LATEST}"
log "Relatório salvo: ${REPORT}"

# Resumo curto para o log do GitHub Actions
if docker inspect aerorf_api >/dev/null 2>&1; then
  api_state="$(docker inspect aerorf_api --format '{{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} restarts={{.RestartCount}}' 2>/dev/null || echo unknown)"
  log "API antes do recreate: ${api_state}"
  if [[ "${api_state}" == *"oom=true"* ]]; then
    log "CAUSA PROVÁVEL: OOM killer (memória insuficiente na VPS)"
  elif [[ "${api_state}" == *"status=exited"* && "${api_state}" == *"exit=0"* ]]; then
    log "CAUSA PROVÁVEL: container parado (reboot VPS ou docker compose down) — sem restart policy"
  elif [[ "${api_state}" == *"status=exited"* ]]; then
    log "CAUSA PROVÁVEL: crash da aplicação (exit != 0) — ver logs acima"
  fi
else
  log "Container aerorf_api não existia antes deste deploy"
fi

# Mantém só os 10 relatórios mais recentes
ls -1t "${LOG_DIR}"/*.log 2>/dev/null | tail -n +11 | xargs -r rm -f
