#!/usr/bin/env bash
# Executado no servidor de dev via SSH (workflow deploy-development, target compose-ssh)
set -euo pipefail

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
COMPOSE_DIR="${DEVOPS_DIR}/compose"

log() { printf '[deploy] %s\n' "$*"; }

log "Login GHCR..."
echo "${GHCR_TOKEN:?GHCR_TOKEN required}" | docker login ghcr.io -u "${GHCR_USER:?GHCR_USER required}" --password-stdin

cd "${COMPOSE_DIR}"
export AERORF_BACKEND_TAG="${AERORF_BACKEND_TAG:-latest}"
export AERORF_FRONTEND_TAG="${AERORF_FRONTEND_TAG:-latest}"

[[ -f .env.dev ]] || cp .env.dev.example .env.dev

log "Pull imagens backend=${AERORF_BACKEND_TAG} frontend=${AERORF_FRONTEND_TAG}"
docker compose -f docker-compose.dev.yml --profile apps pull api web

log "Subindo stack..."
docker compose -f docker-compose.dev.yml --profile apps up -d

log "Aguardando API..."
for _ in $(seq 1 30); do
  curl -sf http://localhost:4000/api/v1/health >/dev/null && break
  sleep 2
done

curl -sf http://localhost:4000/api/v1/health >/dev/null || { log "API não respondeu"; exit 1; }
curl -sf http://localhost:3000/api/health >/dev/null || log "Web ainda inicializando (verifique logs)"

log "Deploy concluído — API :4000 Web :3000"
