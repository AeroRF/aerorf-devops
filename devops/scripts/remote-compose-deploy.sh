#!/usr/bin/env bash
# Deploy/atualização no VPS (HostGator) — usa compose/ existente
set -euo pipefail

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
COMPOSE_DIR="${DEVOPS_DIR}/compose"
BACKEND_DIR="${AERORF_BACKEND_DIR:-$HOME/aerorf/aerorf-backend}"

log() { printf '[deploy] %s\n' "$*"; }

[[ -d "${COMPOSE_DIR}" ]] || { log "Repo devops não encontrado em ${DEVOPS_DIR}"; exit 1; }

log "Login GHCR..."
echo "${GHCR_TOKEN:?GHCR_TOKEN required}" | docker login ghcr.io -u "${GHCR_USER:?GHCR_USER required}" --password-stdin

cd "${COMPOSE_DIR}"
export AERORF_BACKEND_TAG="${AERORF_BACKEND_TAG:-latest}"
export AERORF_FRONTEND_TAG="${AERORF_FRONTEND_TAG:-latest}"

[[ -f .env.dev ]] || cp .env.dev.example .env.dev

log "Infra (Postgres, Redis, MinIO, observabilidade)..."
docker compose --project-name aerorf-dev -f docker-compose.dev.yml up -d \
  postgres pgbouncer redis minio minio-init prometheus grafana loki promtail

log "Pull apps backend=${AERORF_BACKEND_TAG} frontend=${AERORF_FRONTEND_TAG}"
docker compose --project-name aerorf-dev -f docker-compose.dev.yml --profile apps pull api web

log "Subindo API + Web..."
docker compose --project-name aerorf-dev -f docker-compose.dev.yml --profile apps up -d api web

if [[ -d "${BACKEND_DIR}" && -f "${BACKEND_DIR}/package.json" ]]; then
  log "Migrate/seed via backend..."
  export DATABASE_URL="postgres://aerorf:aerorf@localhost:5433/aerorf"
  (cd "${BACKEND_DIR}" && npm run migrate 2>/dev/null) || log "migrate skip (node ou já aplicado)"
  (cd "${BACKEND_DIR}" && npm run seed 2>/dev/null) || log "seed skip"
fi

log "Aguardando API..."
for _ in $(seq 1 45); do
  curl -sf http://127.0.0.1:4000/api/v1/health >/dev/null && break
  sleep 2
done

curl -sf http://127.0.0.1:4000/api/v1/health >/dev/null || { log "API não respondeu — docker logs aerorf_api"; exit 1; }
curl -sf http://127.0.0.1:3000/api/health >/dev/null || log "Web ainda inicializando — docker logs aerorf_web"

log "Deploy concluído."
docker compose --project-name aerorf-dev -f docker-compose.dev.yml ps
