#!/usr/bin/env bash
# Deploy/atualização no VPS (HostGator) — invocado via GitHub Actions (compose-ssh)
set -euo pipefail

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
COMPOSE_DIR="${DEVOPS_DIR}/compose"
KEYS_DIR="${DEVOPS_DIR}/keys"
BACKEND_DIR="${AERORF_BACKEND_DIR:-$HOME/aerorf/aerorf-backend}"

log() { printf '[deploy] %s\n' "$*"; }

ensure_docker_boot() {
  if command -v systemctl >/dev/null 2>&1; then
    if [[ "$(id -u)" -eq 0 ]]; then
      systemctl enable docker 2>/dev/null || true
      systemctl start docker 2>/dev/null || true
    else
      sudo systemctl enable docker 2>/dev/null || true
      sudo systemctl start docker 2>/dev/null || true
    fi
    log "Docker daemon: $(systemctl is-active docker 2>/dev/null || echo unknown)"
  fi
}

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
    if [[ -z "${APP_PUBLIC_URL:-}" && -z "${CORS_ORIGIN:-}" ]]; then
      sed -i "s|^CORS_ORIGIN=.*|CORS_ORIGIN=http://${vps_host}:3000|" "${COMPOSE_DIR}/.env.dev"
      log "CORS_ORIGIN → http://${vps_host}:3000"
    fi
  fi

  if [[ -n "${CORS_ORIGIN:-}" ]]; then
    set_env_var CORS_ORIGIN "${CORS_ORIGIN}"
    log "CORS_ORIGIN → ${CORS_ORIGIN}"
  fi

  if [[ -n "${COOKIE_SECURE:-}" ]]; then
    set_env_var COOKIE_SECURE "${COOKIE_SECURE}"
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

  if [[ -n "${RESEND_API_KEY:-}" ]]; then
    set_env_var RESEND_API_KEY "${RESEND_API_KEY}"
    log "RESEND_API_KEY configurado (notificações e-mail)"
  fi
  if [[ -n "${RESEND_FROM_EMAIL:-}" ]]; then
    set_env_var RESEND_FROM_EMAIL "${RESEND_FROM_EMAIL}"
    log "RESEND_FROM_EMAIL configurado"
  fi
  if [[ -n "${DEV_OPS_TOKEN:-}" ]]; then
    set_env_var DEV_OPS_TOKEN "${DEV_OPS_TOKEN}"
    log "DEV_OPS_TOKEN configurado (reset admin via pipeline)"
  fi
  if [[ -n "${APP_PUBLIC_URL:-}" ]]; then
    set_env_var APP_PUBLIC_URL "${APP_PUBLIC_URL}"
    set_env_var NEXT_PUBLIC_APP_URL "${APP_PUBLIC_URL}"
  elif [[ -n "${vps_host:-}" ]]; then
    set_env_var APP_PUBLIC_URL "http://${vps_host}:3000"
    set_env_var NEXT_PUBLIC_APP_URL "http://${vps_host}:3000"
  fi

  set_env_var NEXT_PUBLIC_API_URL "/api/v1"
  set_env_var API_INTERNAL_URL "http://host.docker.internal:4000"
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
  if [[ -f "${COMPOSE_DIR}/migrations/008_unidades_meta.sql" ]]; then
    local uni_meta
    uni_meta="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='unidades' AND column_name='metadata';" \
      2>/dev/null || echo 0)"
    if [[ "${uni_meta}" -eq 0 ]]; then
      log "Aplicando migration unidades metadata (008)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/008_unidades_meta.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/009_aviation_hour_logs_meta.sql" ]]; then
    local hour_meta
    hour_meta="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='aviation_hour_logs' AND column_name='metadata';" \
      2>/dev/null || echo 0)"
    if [[ "${hour_meta}" -eq 0 ]]; then
      log "Aplicando migration aviation hour logs meta (009)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/009_aviation_hour_logs_meta.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/010_aviation_manutencao.sql" ]]; then
    local rr_tables
    rr_tables="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='aviation_rr_history';" \
      2>/dev/null || echo 0)"
    if [[ "${rr_tables}" -eq 0 ]]; then
      log "Aplicando migration aviation manutenção (010)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/010_aviation_manutencao.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/011_aviation_documents.sql" ]]; then
    local av_docs
    av_docs="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='aviation_documents';" \
      2>/dev/null || echo 0)"
    if [[ "${av_docs}" -eq 0 ]]; then
      log "Aplicando migration aviation documentos (011)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/011_aviation_documents.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/012_notifications.sql" ]]; then
    local notif_tables
    notif_tables="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='notification_queue';" \
      2>/dev/null || echo 0)"
    if [[ "${notif_tables}" -eq 0 ]]; then
      log "Aplicando migration notificações (012)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/012_notifications.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/013_aviation_transfer_cross_tenant.sql" ]]; then
    local trf_status_col
    trf_status_col="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='aviation_transfers' AND column_name='status';" \
      2>/dev/null || echo 0)"
    if [[ "${trf_status_col}" -eq 0 ]]; then
      log "Aplicando migration transferência cross-tenant (013)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/013_aviation_transfer_cross_tenant.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/014_aviation_transfer_invites.sql" ]]; then
    local trf_invite_table
    trf_invite_table="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='aviation_transfer_invites';" \
      2>/dev/null || echo 0)"
    if [[ "${trf_invite_table}" -eq 0 ]]; then
      log "Aplicando migration convites transferência (014)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/014_aviation_transfer_invites.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/015_aviation_documents_versions.sql" ]]; then
    local doc_version_col
    doc_version_col="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='aviation_documents' AND column_name='version';" \
      2>/dev/null || echo 0)"
    if [[ "${doc_version_col}" -eq 0 ]]; then
      log "Aplicando migration versionamento documentos (015)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/015_aviation_documents_versions.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/016_truck_documents_versions.sql" ]]; then
    local truck_doc_version_col
    truck_doc_version_col="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='truck_documents' AND column_name='version';" \
      2>/dev/null || echo 0)"
    if [[ "${truck_doc_version_col}" -eq 0 ]]; then
      log "Aplicando migration versionamento caminhões (016)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/016_truck_documents_versions.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/017_telemetry_storage.sql" ]]; then
    local tel_storage_col
    tel_storage_col="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='telemetry_missions' AND column_name='storage_key';" \
      2>/dev/null || echo 0)"
    if [[ "${tel_storage_col}" -eq 0 ]]; then
      log "Aplicando migration telemetria storage (017)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/017_telemetry_storage.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/018_user_invites.sql" ]]; then
    local user_invites_table
    user_invites_table="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='user_invites';" \
      2>/dev/null || echo 0)"
    if [[ "${user_invites_table}" -eq 0 ]]; then
      log "Aplicando migration convites de usuário (018)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/018_user_invites.sql"
    fi
  fi
  if [[ -f "${COMPOSE_DIR}/migrations/019_contract_pendencies.sql" ]]; then
    local mech_tables
    mech_tables="$(docker exec aerorf_postgres psql -U aerorf -d aerorf -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='aviation_mechanics';" \
      2>/dev/null || echo 0)"
    if [[ "${mech_tables}" -eq 0 ]]; then
      log "Aplicando migration pendências contrato (019)..."
      docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
        < "${COMPOSE_DIR}/migrations/019_contract_pendencies.sql"
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
ensure_docker_boot
docker info >/dev/null 2>&1 || { log "Docker daemon não está rodando."; exit 1; }

if [[ "${AERORF_IMAGES_PRELOADED:-}" == "1" ]]; then
  log "Imagens pré-carregadas pelo pipeline GitHub Actions — skip login/pull GHCR"
else
  log "Login GHCR..."
  echo "${GHCR_TOKEN:?GHCR_TOKEN required}" | docker login ghcr.io -u "${GHCR_USER:?GHCR_USER required}" --password-stdin
fi

cd "${COMPOSE_DIR}"
export AERORF_BACKEND_TAG="${AERORF_BACKEND_TAG:-latest}"
export AERORF_FRONTEND_TAG="${AERORF_FRONTEND_TAG:-latest}"

log "Forensics — capturar estado ANTES de recriar containers..."
if [[ -f "${DEVOPS_DIR}/devops/scripts/capture-crash-forensics.sh" ]]; then
  DEVOPS_DIR="${DEVOPS_DIR}" bash "${DEVOPS_DIR}/devops/scripts/capture-crash-forensics.sh" || true
elif [[ -f "${COMPOSE_DIR}/../devops/scripts/capture-crash-forensics.sh" ]]; then
  DEVOPS_DIR="${DEVOPS_DIR}" bash "${COMPOSE_DIR}/../devops/scripts/capture-crash-forensics.sh" || true
fi

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

log "Parando API/Web antes de recriar PgBouncer (evita ENOTFOUND pgbouncer)..."
compose_dev --profile apps stop api web 2>/dev/null || true

log "PgBouncer (force-recreate — AUTH scram-sha-256)..."
compose_dev up -d --force-recreate pgbouncer
log "Aguardando PgBouncer healthy..."
for i in $(seq 1 30); do
  if docker inspect aerorf_pgbouncer --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy; then
    log "PgBouncer healthy (tentativa ${i})"
    break
  fi
  if [[ "${i}" -eq 30 ]]; then
    log "PgBouncer ainda não healthy — logs:"
    docker logs aerorf_pgbouncer --tail 20 2>&1 || true
  fi
  sleep 2
done

run_migrate_if_needed

if [[ "${AERORF_IMAGES_PRELOADED:-}" == "1" ]]; then
  log "Apps backend=${AERORF_BACKEND_TAG} frontend=${AERORF_FRONTEND_TAG} (imagens já na VPS)"
else
  log "Pull apps backend=${AERORF_BACKEND_TAG} frontend=${AERORF_FRONTEND_TAG}"
  compose_dev --profile apps pull api web
fi

PULL_FLAG="always"
[[ "${AERORF_IMAGES_PRELOADED:-}" == "1" ]] && PULL_FLAG="never"

log "Subindo API + Web (force-recreate, pull=${PULL_FLAG})..."
compose_dev --profile apps up -d --force-recreate --pull "${PULL_FLAG}" api web

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
login_ok=0
for i in $(seq 1 12); do
  if docker exec aerorf_web wget -qO- http://host.docker.internal:4000/api/v1/health 2>/dev/null | grep -q ok; then
    log "Web→API interno OK (tentativa ${i})"
  fi
  login_code="$(curl -s -o /tmp/aerorf-login.json -w '%{http_code}' \
    -X POST http://127.0.0.1:3000/api/v1/auth/login \
    -H 'Content-Type: application/json' \
    -d '{"email":"admin@aerorf.com.br","password":"admin123"}')"
  if [[ "${login_code}" == "200" ]]; then
    log "Login smoke test OK (tentativa ${i})."
    login_ok=1
    break
  fi
  log "Login smoke tentativa ${i} — HTTP ${login_code}"
  sleep 3
done
if [[ "${login_ok}" -ne 1 ]]; then
  log "Login smoke test falhou (último HTTP ${login_code}):"
  head -c 400 /tmp/aerorf-login.json 2>/dev/null || true
  echo ""
  docker logs aerorf_web --tail 30 2>&1 || true
  docker logs aerorf_api --tail 30 2>&1 || true
  exit 1
fi

if [[ "${AERORF_SETUP_NGINX:-1}" == "1" ]]; then
  log "Nginx — LiteSpeed → reverse proxy (pipeline)..."
  # shellcheck source=/dev/null
  source "${DEVOPS_DIR}/nginx/setup-vps-nginx.sh"
  setup_vps_nginx
else
  log "Nginx skip (AERORF_SETUP_NGINX=${AERORF_SETUP_NGINX:-})"
fi

log "Observabilidade — Alertmanager + ping Slack..."
if [[ -f "${DEVOPS_DIR}/devops/scripts/observability-slack-verify.sh" ]]; then
  COMPOSE_DIR="${COMPOSE_DIR}" DEVOPS_DIR="${DEVOPS_DIR}" SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}" \
    bash "${DEVOPS_DIR}/devops/scripts/observability-slack-verify.sh" || log "Observability verify falhou (não bloqueia deploy)"
else
  log "observability-slack-verify.sh ausente — atualize aerorf-devops (git pull)"
fi

log "Diagnóstico da stack..."
if [[ -f "${DEVOPS_DIR}/devops/scripts/stack-diagnostics.sh" ]]; then
  COMPOSE_DIR="${COMPOSE_DIR}" bash "${DEVOPS_DIR}/devops/scripts/stack-diagnostics.sh" || true
fi

if [[ -f "${DEVOPS_DIR}/logs/crash-forensics/latest.log" ]]; then
  log "Último relatório forensics (início deste deploy):"
  head -40 "${DEVOPS_DIR}/logs/crash-forensics/latest.log" 2>/dev/null || true
fi

log "Health watchdog (cron host — Slack independente do Prometheus)..."
if [[ -f "${DEVOPS_DIR}/devops/scripts/install-health-watchdog-cron.sh" ]]; then
  DEVOPS_DIR="${DEVOPS_DIR}" bash "${DEVOPS_DIR}/devops/scripts/install-health-watchdog-cron.sh" || log "Watchdog cron falhou (não bloqueia deploy)"
  DEVOPS_DIR="${DEVOPS_DIR}" bash "${DEVOPS_DIR}/devops/scripts/health-watchdog.sh" || true
else
  log "install-health-watchdog-cron.sh ausente — atualize aerorf-devops (git pull)"
fi

log "Deploy concluído."
compose_dev --profile apps ps
