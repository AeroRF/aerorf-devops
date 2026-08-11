#!/usr/bin/env bash

validate_prerequisites() {
  log "Verificando pré-requisitos..."

  command -v docker >/dev/null 2>&1 || die "Docker não encontrado. Instale Docker Desktop ou Engine."
  docker info >/dev/null 2>&1 || die "Docker daemon não está rodando."

  if ! docker compose version >/dev/null 2>&1; then
    die "Docker Compose v2 não encontrado (docker compose)."
  fi

  if [[ "${SKIP_NODE_CHECK:-0}" != "1" ]]; then
    command -v node >/dev/null 2>&1 || die "Node.js não encontrado (>= 20)."
    local node_major
    node_major="$(node -p "process.versions.node.split('.')[0]")"
    [[ "${node_major}" -ge 20 ]] || die "Node.js >= 20 necessário (atual: $(node -v))."
    command -v npm >/dev/null 2>&1 || die "npm não encontrado."
  fi

  command -v openssl >/dev/null 2>&1 || die "openssl não encontrado (necessário para chaves JWT)."

  if [[ "${1:-}" != "prod-only" ]]; then
    command -v curl >/dev/null 2>&1 || log_warn "curl não encontrado — health checks limitados."
  fi

  log_ok "Pré-requisitos OK."
}

validate_dev_config() {
  [[ -f "${DEV_COMPOSE}" ]] || die "Compose dev ausente: ${DEV_COMPOSE}"
  [[ -f "${DEV_ENV_FILE}" ]] || die "Arquivo ${DEV_ENV_FILE} ausente. Rode: install dev"
  compose_dev config >/dev/null
  log_ok "Compose dev válido."
}

validate_prod_config() {
  [[ -f "${PROD_COMPOSE}" ]] || die "Compose prod ausente: ${PROD_COMPOSE}"
  [[ -f "${PROD_ENV_FILE}" ]] || die "Arquivo ${PROD_ENV_FILE} ausente. Rode: install prod"

  grep -q 'CHANGE_ME' "${PROD_ENV_FILE}" && \
    log_warn "Ainda existem placeholders CHANGE_ME em .env.prod — ajuste antes do deploy real."

  local required=(DATABASE_URL REDIS_URL S3_ENDPOINT S3_ACCESS_KEY S3_SECRET_KEY)
  set -a
  # shellcheck disable=SC1090
  source "${PROD_ENV_FILE}"
  set +a
  for var in "${required[@]}"; do
    [[ -n "${!var:-}" ]] || die "Variável obrigatória ausente em .env.prod: ${var}"
  done

  compose_prod config >/dev/null
  log_ok "Compose prod-apps válido."
}
