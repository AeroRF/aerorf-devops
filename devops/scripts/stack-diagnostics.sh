#!/usr/bin/env bash
# Diagnóstico da stack Docker na VPS — invocado pelo deploy ou manualmente
set -euo pipefail

log() { printf '[stack-diag] %s\n' "$*"; }

COMPOSE_DIR="${COMPOSE_DIR:-$HOME/aerorf/aerorf-devops/compose}"

log "=== Docker daemon ==="
if ! docker info >/dev/null 2>&1; then
  log "ERRO: Docker daemon offline"
  exit 1
fi
docker info 2>/dev/null | grep -E 'Server Version|Operating System|Total Memory|Docker Root Dir' || true

log ""
log "=== Containers AeroRF ==="
docker ps -a --filter "name=aerorf" --format "table {{.Names}}\t{{.Status}}\t{{.State}}" 2>/dev/null || docker ps -a

log ""
log "=== Restart count (containers que reiniciaram) ==="
for c in aerorf_api aerorf_web aerorf_postgres aerorf_pgbouncer aerorf_grafana aerorf_minio; do
  if docker inspect "$c" >/dev/null 2>&1; then
    restarts="$(docker inspect "$c" --format '{{.RestartCount}}' 2>/dev/null || echo '?')"
    status="$(docker inspect "$c" --format '{{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}}' 2>/dev/null || echo '?')"
    log "  ${c}: restarts=${restarts} ${status}"
  fi
done

log ""
log "=== OOM recente (dmesg) ==="
if command -v dmesg >/dev/null 2>&1; then
  dmesg -T 2>/dev/null | grep -i 'killed process\|out of memory' | tail -5 || log "  (sem entradas OOM recentes ou dmesg indisponível)"
else
  log "  dmesg não disponível"
fi

log ""
log "=== Memória / disco host ==="
free -h 2>/dev/null || true
df -h / 2>/dev/null | tail -1 || true

log ""
log "=== Últimas linhas de log (api/web) ==="
for c in aerorf_api aerorf_web; do
  if docker inspect "$c" >/dev/null 2>&1; then
    log "--- ${c} (tail 15) ---"
    docker logs "$c" --tail 15 2>&1 || true
  fi
done

log ""
log "=== Health endpoints locais ==="
curl -sf http://127.0.0.1:4000/api/v1/health && log "api :4000 OK" || log "api :4000 FAIL"
curl -sf http://127.0.0.1:3000/api/health && log "web :3000 OK" || log "web :3000 FAIL"
