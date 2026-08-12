#!/usr/bin/env bash
# Bootstrap único — VPS HostGator (Ubuntu/CentOS com root ou sudo)
# Uso: curl -fsSL ... | bash   OU   bash bootstrap-hostgator.sh
set -euo pipefail

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
BACKEND_DIR="${BACKEND_DIR:-$HOME/aerorf/aerorf-backend}"
VPS_HOST="${VPS_HOST:-}"

log() { printf '[bootstrap] %s\n' "$*"; }

if [[ "$(id -u)" -ne 0 ]] && ! command -v sudo >/dev/null; then
  log "Execute como root ou com sudo disponível."
  exit 1
fi

run_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

log "Instalando Docker (se necessário)..."
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | run_root sh
  run_root systemctl enable --now docker
  if [[ "$(id -u)" -ne 0 ]] && groups "$USER" | grep -qv docker; then
    run_root usermod -aG docker "$USER"
    log "Usuário $USER adicionado ao grupo docker — faça logout/login."
  fi
fi

command -v docker compose >/dev/null || { log "Docker Compose v2 não encontrado."; exit 1; }
command -v git >/dev/null || run_root apt-get update -qq && run_root apt-get install -y git curl openssl

mkdir -p "$(dirname "${DEVOPS_DIR}")"
if [[ ! -d "${DEVOPS_DIR}/.git" ]]; then
  log "Clonando aerorf-devops..."
  git clone https://github.com/AeroRF/aerorf-devops.git "${DEVOPS_DIR}"
fi

if [[ ! -d "${BACKEND_DIR}/.git" ]]; then
  log "Clonando aerorf-backend (migrate/seed)..."
  git clone https://github.com/AeroRF/aerorf-backend.git "${BACKEND_DIR}" || log "Backend privado — configure deploy key e clone manual."
fi

cd "${DEVOPS_DIR}"
chmod +x devops/aerorf-devops.sh devops/scripts/*.sh 2>/dev/null || true

if [[ ! -f compose/.env.dev ]]; then
  cp compose/.env.dev.example compose/.env.dev
  if [[ -n "${VPS_HOST}" ]]; then
    sed -i "s/SEU_IP_OU_DOMINIO/${VPS_HOST}/g" compose/.env.dev
    log "compose/.env.dev ajustado para VPS_HOST=${VPS_HOST}"
  else
    log "Edite compose/.env.dev — defina CORS_ORIGIN com IP público da HostGator."
  fi
fi

log "Gerando JWT e subindo infra..."
./devops/aerorf-devops.sh install dev --local-apps

log "Migrate (SQL via devops)..."
./devops/aerorf-devops.sh migrate || true

log ""
log "Bootstrap concluído. Próximo passo:"
log "  1. export GHCR_TOKEN=<PAT read:packages> GHCR_USER=<github-user>"
log "  2. ./devops/aerorf-devops.sh install dev   # infra + apps GHCR"
log "  3. Abra firewall HostGator: portas 3000, 4000 (e 9001 se usar MinIO console)"
log ""
log "URLs: Web http://${VPS_HOST:-SEU_IP}:3000  API http://${VPS_HOST:-SEU_IP}:4000/api/v1/health"
