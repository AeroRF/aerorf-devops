#!/usr/bin/env bash

init_env_dev() {
  if [[ ! -f "${DEV_ENV_FILE}" ]]; then
    cp "${COMPOSE_DIR}/.env.dev.example" "${DEV_ENV_FILE}"
    log_ok "Criado ${DEV_ENV_FILE}"
  else
    log "Usando ${DEV_ENV_FILE} existente."
  fi
}

init_env_prod() {
  if [[ ! -f "${PROD_ENV_FILE}" ]]; then
    cp "${COMPOSE_DIR}/.env.prod.example" "${PROD_ENV_FILE}"
    log_ok "Criado ${PROD_ENV_FILE} — edite hosts externos antes do deploy real."
  else
    log "Usando ${PROD_ENV_FILE} existente."
  fi
}

init_jwt_keys() {
  mkdir -p "${KEYS_DIR}"
  local priv="${KEYS_DIR}/jwt-private.pem"
  local pub="${KEYS_DIR}/jwt-public.pem"

  if [[ -f "${priv}" && -f "${pub}" ]]; then
    log "Chaves JWT já existem em ${KEYS_DIR}"
    return 0
  fi

  log "Gerando par de chaves JWT RS256..."
  openssl genrsa -out "${priv}" 2048 2>/dev/null
  openssl rsa -in "${priv}" -pubout -out "${pub}" 2>/dev/null
  chmod 600 "${priv}"
  chmod 644 "${pub}"
  log_ok "Chaves JWT criadas."
}

init_directories() {
  mkdir -p "${KEYS_DIR}"
  mkdir -p "${ROOT_DIR}/observability/prometheus"
  mkdir -p "${ROOT_DIR}/observability/grafana/provisioning/datasources"
  mkdir -p "${ROOT_DIR}/observability/loki"
  mkdir -p "${ROOT_DIR}/observability/promtail"
  mkdir -p "${K8S_DIR}"
  mkdir -p "${COMPOSE_DIR}/migrations"
  log_ok "Diretórios de infraestrutura verificados."
}
