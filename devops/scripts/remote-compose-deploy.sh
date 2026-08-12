#!/usr/bin/env bash
# Deploy/atualização no VPS (HostGator) — invocado via GitHub Actions (compose-ssh)
set -euo pipefail

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
COMPOSE_DIR="${DEVOPS_DIR}/compose"
KEYS_DIR="${DEVOPS_DIR}/keys"
BACKEND_DIR="${AERORF_BACKEND_DIR:-$HOME/aerorf/aerorf-backend}"

log() { printf '[deploy] %s\n' "$*"; }

ensure_devops_repo() {
  if [[ ! -d "${DEVOPS_DIR}/.git" ]]; then
    log "Clonando aerorf-devops em ${DEVOPS_DIR}..."
    mkdir -p "$(dirname "${DEVOPS_DIR}")"
    git clone https://github.com/AeroRF/aerorf-devops.git "${DEVOPS_DIR}"
  fi
  log "Atualizando aerorf-devops (origin/main)..."
  git -C "${DEVOPS_DIR}" fetch origin main
  if [[ -n "$(git -C "${DEVOPS_DIR}" status --porcelain 2>/dev/null)" ]]; then
    log "Descartando alterações locais — deploy usa versão publicada no GitHub."
  fi
  git -C "${DEVOPS_DIR}" reset --hard origin/main
}

ensure_jwt_keys() {
  mkdir -p "${KEYS_DIR}"
  if [[ -f "${KEYS_DIR}/jwt-private.pem" && -f "${KEYS_DIR}/jwt-public.pem" ]]; then
    return 0
  fi
  log "Gerando chaves JWT..."
  openssl genrsa -out "${KEYS_DIR}/jwt-private.pem" 2048 2>/dev/null
  openssl rsa -in "${KEYS_DIR}/jwt-private.pem" -pubout -out "${KEYS_DIR}/jwt-public.pem" 2>/dev/null
  chmod 600 "${KEYS_DIR}/jwt-private.pem"
}

set_env_var() {
  local key="$1"
  local val="$2"
  if grep -q "^${key}=" "${COMPOSE_DIR}/.env.dev" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "${COMPOSE_DIR}/.env.dev"
  else
    echo "${key}=${val}" >> "${COMPOSE_DIR}/.env.dev"
  fi
}

ensure_env_dev() {
  [[ -f "${COMPOSE_DIR}/.env.dev" ]] || cp "${COMPOSE_DIR}/.env.dev.example" "${COMPOSE_DIR}/.env.dev"

  # DATABASE_URL no .env.dev é só para migrate no host — API usa compose environment
  if grep -q '^DATABASE_URL=' "${COMPOSE_DIR}/.env.dev" 2>/dev/null; then
    sed -i 's|^DATABASE_URL=|# DATABASE_URL=host-only-removed-by-deploy |' "${COMPOSE_DIR}/.env.dev"
  fi

  local vps_host="${VPS_HOST:-}"
  if [[ -z "${vps_host}" ]]; then
    vps_host="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  fi
  if [[ -z "${vps_host}" ]]; then
    vps_host="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  if [[ -n "${vps_host}" ]]; then
    sed -i "s/SEU_IP_OU_DOMINIO/${vps_host}/g" "${COMPOSE_DIR}/.env.dev"
    sed -i "s|^CORS_ORIGIN=.*|CORS_ORIGIN=http://${vps_host}:3000|" "${COMPOSE_DIR}/.env.dev"
    log "CORS_ORIGIN → http://${vps_host}:3000"
  fi

  if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
    set_env_var SLACK_WEBHOOK_URL "${SLACK_WEBHOOK_URL}"
    log "SLACK_WEBHOOK_URL configurado (Alertmanager → Slack)"
  elif [[ -n "${ALERT_WEBHOOK_URL:-}" ]]; then
    set_env_var SLACK_WEBHOOK_URL "${ALERT_WEBHOOK_URL}"
    log "SLACK_WEBHOOK_URL ← ALERT_WEBHOOK_URL (legado)"
  fi

  if [[ -n "${GRAFANA_ADMIN_USER:-}" ]]; then
    set_env_var GRAFANA_ADMIN_USER "${GRAFANA_ADMIN_USER}"
  fi
  if [[ -n "${GRAFANA_ADMIN_PASSWORD:-}" ]]; then
    set_env_var GRAFANA_ADMIN_PASSWORD "${GRAFANA_ADMIN_PASSWORD}"
    log "GRAFANA_ADMIN_PASSWORD configurado"
  fi
}

compose_dev() {
  docker compose --project-name aerorf-dev --env-file "${COMPOSE_DIR}/.env.dev" -f "${COMPOSE_DIR}/docker-compose.dev.yml" "$@"
}

run_migrate_if_needed() {
  local tables
  tables="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
    "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='users';" \
    2>/dev/null || echo 0)"
  if [[ "${tables}" -eq 0 ]]; then
    log "Aplicando schema inicial..."
    docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
      < "${COMPOSE_DIR}/migrations/001_initial.sql"
  else
    log "Schema já presente — migrate skip."
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/003_aviation.sql" ]]; then
    local av_tables
    av_tables="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='aviation_operators';" \
      2>/dev/null || echo 0)"
    if [[ "${av_tables}" -eq 0 ]]; then
      log "Aplicando migration aviação (003)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/003_aviation.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/004_caminhoes.sql" ]]; then
    local tr_tables
    tr_tables="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='trucks';" \
      2>/dev/null || echo 0)"
    if [[ "${tr_tables}" -eq 0 ]]; then
      log "Aplicando migration caminhões (004)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/004_caminhoes.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/005_combustiveis.sql" ]]; then
    local fuel_tables
    fuel_tables="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='fuel_tanks';" \
      2>/dev/null || echo 0)"
    if [[ "${fuel_tables}" -eq 0 ]]; then
      log "Aplicando migration combustíveis (005)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/005_combustiveis.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/006_estoque.sql" ]]; then
    local stock_tables
    stock_tables="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='stock_products';" \
      2>/dev/null || echo 0)"
    if [[ "${stock_tables}" -eq 0 ]]; then
      log "Aplicando migration estoque (006)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/006_estoque.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/007_telemetria.sql" ]]; then
    local tel_tables
    tel_tables="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='telemetry_missions';" \
      2>/dev/null || echo 0)"
    if [[ "${tel_tables}" -eq 0 ]]; then
      log "Aplicando migration telemetria (007)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/007_telemetria.sql"
    fi
  fi
}

run_seed() {
  if [[ -d "${BACKEND_DIR}" && -f "${BACKEND_DIR}/package.json" ]] && command -v node >/dev/null 2>&1; then
    log "Seed via aerorf-backend..."
    export DATABASE_URL="postgres://aerorf:aerorf@localhost:5433/aerorf"
    (cd "${BACKEND_DIR}" && npm run seed 2>/dev/null) && return 0
  fi
  log "Seed SQL demo..."
  docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
    < "${COMPOSE_DIR}/migrations/002_seed_demo.sql"
}

ensure_devops_repo
ensure_jwt_keys
ensure_env_dev

command -v docker >/dev/null 2>&1 || { log "Docker não encontrado no VPS."; exit 1; }
docker info >/dev/null 2>&1 || { log "Docker daemon não está rodando."; exit 1; }

log "Login GHCR..."
echo "${GHCR_TOKEN:?GHCR_TOKEN required}" | docker login ghcr.io -u "${GHCR_USER:?GHCR_USER required}" --password-stdin

cd "${COMPOSE_DIR}"
export AERORF_BACKEND_TAG="${AERORF_BACKEND_TAG:-latest}"
export AERORF_FRONTEND_TAG="${AERORF_FRONTEND_TAG:-latest}"

log "Infra (Postgres, Redis, MinIO, observabilidade + exporters)..."
compose_dev up -d \
  postgres redis minio minio-init \
  prometheus alertmanager grafana loki promtail \
  node-exporter postgres-exporter redis-exporter

log "Grafana — force-recreate (garante container saudável)..."
compose_dev up -d --force-recreate grafana
sleep 8
if curl -sf http://127.0.0.1:3001/api/health >/dev/null 2>&1; then
  log "Grafana health OK (:3001)"
else
  log "Grafana ainda inicializando — logs:"
  docker logs aerorf_grafana --tail 25 2>&1 || true
fi

log "PgBouncer (force-recreate — AUTH scram-sha-256)..."
compose_dev up -d --force-recreate pgbouncer
sleep 5

run_migrate_if_needed

log "Pull apps backend=${AERORF_BACKEND_TAG} frontend=${AERORF_FRONTEND_TAG}"
compose_dev --profile apps pull api web

log "Subindo API + Web (force-recreate + pull)..."
compose_dev --profile apps up -d --force-recreate --pull always api web web-api-proxy

log "Web image: $(docker inspect aerorf_web --format '{{.Config.Image}}' 2>/dev/null || echo unknown)"

run_seed

log "Aguardando API..."
for i in $(seq 1 45); do
  if curl -sf http://127.0.0.1:4000/api/v1/health >/dev/null 2>&1; then
    log "API health OK (tentativa ${i})"
    break
  fi
  if [[ "${i}" -eq 1 || $((i % 5)) -eq 0 ]]; then
    curl -s http://127.0.0.1:4000/api/v1/health 2>/dev/null | head -c 200 || true
    echo ""
  fi
  sleep 2
done

if ! curl -sf http://127.0.0.1:4000/api/v1/health >/dev/null; then
  log "API health falhou — resposta:"
  curl -s http://127.0.0.1:4000/api/v1/health || true
  echo ""
  docker logs aerorf_api --tail 40 2>&1 || true
  docker logs aerorf_pgbouncer --tail 20 2>&1 || true
  exit 1
fi

curl -sf http://127.0.0.1:3000/api/health >/dev/null || log "Web ainda inicializando — docker logs aerorf_web"

log "Aguardando Web..."
for i in $(seq 1 30); do
  if curl -sf http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
    log "Web health OK (tentativa ${i})"
    break
  fi
  sleep 2
done

log "Smoke test login (via proxy Next :3000)..."
login_code="$(curl -s -o /tmp/aerorf-login.json -w '%{http_code}' \
  -X POST http://127.0.0.1:3000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@aerorf.com.br","password":"admin123"}')"
if [[ "${login_code}" != "200" ]]; then
  log "Login smoke test falhou (HTTP ${login_code}):"
  head -c 400 /tmp/aerorf-login.json 2>/dev/null || true
  echo ""
  docker logs aerorf_web --tail 30 2>&1 || true
  exit 1
fi
log "Login smoke test OK."

log "Deploy concluído."
compose_dev --profile apps ps
