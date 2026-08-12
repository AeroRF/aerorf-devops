#!/usr/bin/env bash
# Funções compartilhadas DevOps AeroRF

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_DIR="${ROOT_DIR}/compose"
KEYS_DIR="${ROOT_DIR}/keys"
K8S_DIR="${ROOT_DIR}/k8s"
DEV_ENV_FILE="${COMPOSE_DIR}/.env.dev"
PROD_ENV_FILE="${COMPOSE_DIR}/.env.prod"
DEV_COMPOSE="${COMPOSE_DIR}/docker-compose.dev.yml"
PROD_COMPOSE="${COMPOSE_DIR}/docker-compose.prod-apps.yml"
TEST_COMPOSE="${COMPOSE_DIR}/docker-compose.test.yml"

# Caminho para o repo aerorf-backend (clone ao lado ou override via .env.dev)
BACKEND_DIR="${AERORF_BACKEND_DIR:-${ROOT_DIR}/../aerorf-backend}"

log()   { printf '\033[1;34m[devops]\033[0m %s\n' "$*"; }
log_ok(){ printf '\033[1;32m[devops]\033[0m %s\n' "$*"; }
log_warn(){ printf '\033[1;33m[devops]\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31m[devops] ERRO:\033[0m %s\n' "$*" >&2; exit 1; }

compose_dev() {
  docker compose --project-name aerorf-dev -f "${DEV_COMPOSE}" "$@"
}

compose_prod() {
  docker compose --project-name aerorf-prod -f "${PROD_COMPOSE}" --env-file "${PROD_ENV_FILE}" "$@"
}

load_dev_env() {
  if [[ -f "${DEV_ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${DEV_ENV_FILE}"
    set +a
  fi
  BACKEND_DIR="${AERORF_BACKEND_DIR:-${BACKEND_DIR}}"
}

ghcr_login_if_needed() {
  if [[ -n "${GHCR_TOKEN:-}" ]]; then
    log "Login GHCR (${GHCR_USER:-git})..."
    echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GHCR_USER:-git}" --password-stdin
    return 0
  fi
  log_warn "GHCR_TOKEN não definido — pull pode falhar se imagens forem privadas."
}

wait_for_postgres() {
  local host="${1:-localhost}"
  local port="${2:-5432}"
  local user="${3:-aerorf}"
  local db="${4:-aerorf}"
  local retries="${5:-30}"

  log "Aguardando PostgreSQL em ${host}:${port}..."
  for i in $(seq 1 "${retries}"); do
    if docker exec aerorf_postgres pg_isready -U "${user}" -d "${db}" >/dev/null 2>&1; then
      log_ok "PostgreSQL pronto."
      return 0
    fi
    sleep 2
  done
  die "PostgreSQL não respondeu a tempo."
}

wait_for_http() {
  local url="$1"
  local name="${2:-serviço}"
  local retries="${3:-30}"

  log "Aguardando ${name} (${url})..."
  for _ in $(seq 1 "${retries}"); do
    if curl -sf "${url}" >/dev/null 2>&1; then
      log_ok "${name} pronto."
      return 0
    fi
    sleep 2
  done
  log_warn "${name} ainda não respondeu (pode estar inicializando)."
}

print_endpoints_dev() {
  cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║  AeroRF DEV — endpoints                                      ║
╠══════════════════════════════════════════════════════════════╣
║  Web (Next.js)     http://localhost:3000                     ║
║  API               http://localhost:4000/api/v1/health       ║
║  Grafana           http://localhost:3001  (admin/admin)      ║
║  Prometheus        http://localhost:9090                     ║
║  MinIO Console     http://localhost:9001  (aerorf/aerorf_secret)
║  Postgres          localhost:5433 / PgBouncer 127.0.0.1:6432   ║
║  Redis             rede interna (sem porta no host)            ║
╠══════════════════════════════════════════════════════════════╣
║  Login demo: admin@aerorf.com.br / admin123                  ║
╚══════════════════════════════════════════════════════════════╝

EOF
}

print_endpoints_prod() {
  cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║  AeroRF PROD — apps stateless (tier aplicação)               ║
╠══════════════════════════════════════════════════════════════╣
║  Configure serviços EXTERNOS em compose/.env.prod:           ║
║    DATABASE_URL, REDIS_URL, S3_ENDPOINT, observabilidade     ║
║  Web/API expostos conforme compose prod-apps ou K8s ingress  ║
╚══════════════════════════════════════════════════════════════╝

EOF
}
