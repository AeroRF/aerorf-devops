#!/usr/bin/env bash

cmd_install_dev() {
  local local_apps=0
  for arg in "$@"; do
    [[ "${arg}" == "--local-apps" ]] && local_apps=1
  done

  log "=== Instalação DEV (stack completa) ==="
  validate_prerequisites
  init_directories
  init_env_dev
  init_jwt_keys

  if [[ "${local_apps}" -eq 1 ]]; then
    log "Modo --local-apps: subindo apenas infra (sem containers api/web)..."
    compose_dev up -d postgres pgbouncer redis minio minio-init prometheus grafana loki promtail
  else
    log "Subindo stack com imagens GHCR (profile apps)..."
    compose_dev --profile apps up -d
  fi

  wait_for_postgres
  cmd_migrate
  cmd_seed

  if [[ "${local_apps}" -eq 1 ]]; then
    log_ok "Infra pronta. Inicie apps nos repos backend/frontend:"
    log "  cd ../aerorf-backend && npm run dev   # :4000"
    log "  cd ../aerorf-frontend && npm run dev  # :3000"
  else
    wait_for_http "http://localhost:4000/api/v1/health" "API" 60 || true
    wait_for_http "http://localhost:3000/api/health" "Web" 60 || true
  fi

  print_endpoints_dev
  log_ok "Instalação DEV concluída."
}

cmd_up_dev() {
  local build=0
  local profile_args=()
  for arg in "$@"; do
    [[ "${arg}" == "--build" ]] && build=1
    [[ "${arg}" == "--apps" ]] && profile_args=(--profile apps)
  done

  validate_dev_config
  if [[ "${build}" -eq 1 ]]; then
    compose_dev "${profile_args[@]}" up -d --pull always
  else
    compose_dev "${profile_args[@]}" up -d
  fi
  print_endpoints_dev
}

cmd_down_dev() {
  log "Parando stack DEV..."
  compose_dev --profile apps down
  compose_dev down
  log_ok "Stack DEV parada."
}

cmd_migrate() {
  load_dev_env
  export DATABASE_URL="${DATABASE_URL:-postgres://aerorf:aerorf@localhost:5432/aerorf}"
  log "Executando migrations..."

  if [[ -d "${BACKEND_DIR}" && -f "${BACKEND_DIR}/package.json" ]]; then
    (cd "${BACKEND_DIR}" && npm run migrate) && {
      log_ok "Migrations aplicadas via aerorf-backend."
      return 0
    }
    log_warn "Migration via npm falhou — tentando SQL direto..."
  else
    log_warn "Repo backend não encontrado em ${BACKEND_DIR} — SQL direto."
  fi

  docker exec -i aerorf_postgres psql -U aerorf -d aerorf \
    < "${COMPOSE_DIR}/migrations/001_initial.sql" || true
  log_ok "Migrations aplicadas."
}

cmd_seed() {
  load_dev_env
  export DATABASE_URL="postgres://aerorf:aerorf@localhost:5432/aerorf"

  if [[ ! -d "${BACKEND_DIR}" || ! -f "${BACKEND_DIR}/package.json" ]]; then
    log_warn "Repo backend não encontrado em ${BACKEND_DIR} — pule seed ou clone aerorf-backend."
    return 0
  fi

  log "Executando seed via aerorf-backend..."
  (cd "${BACKEND_DIR}" && npm run seed)
  log_ok "Seed concluído."
}

cmd_status() {
  local env="${1:-dev}"
  case "${env}" in
    dev)
      compose_dev ps
      ;;
    prod)
      compose_prod ps 2>/dev/null || log_warn "Stack prod não está rodando."
      ;;
    *)
      die "Ambiente inválido"
      ;;
  esac
}

cmd_logs() {
  local env="${1:-dev}"
  local service="${2:-}"
  case "${env}" in
    dev)
      if [[ -n "${service}" ]]; then
        compose_dev logs -f "${service}"
      else
        compose_dev logs -f
      fi
      ;;
    prod)
      if [[ -n "${service}" ]]; then
        compose_prod logs -f "${service}"
      else
        compose_prod logs -f
      fi
      ;;
  esac
}
