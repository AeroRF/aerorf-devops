#!/usr/bin/env bash
# Bootstrap único — VPS HostGator (Ubuntu/Debian ou CentOS/Alma/RHEL)
# Uso: export VPS_HOST=SEU_IP && curl -fsSL .../bootstrap-hostgator.sh | bash
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

install_packages() {
  local packages=("$@")
  if command -v apt-get >/dev/null 2>&1; then
    run_root apt-get update -qq
    run_root apt-get install -y "${packages[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y "${packages[@]}"
  elif command -v yum >/dev/null 2>&1; then
    run_root yum install -y "${packages[@]}"
  else
    log "Gerenciador de pacotes não encontrado (apt/dnf/yum)."
    exit 1
  fi
}

detect_vps_host() {
  if [[ -n "${VPS_HOST}" ]]; then
    return 0
  fi
  VPS_HOST="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  if [[ -z "${VPS_HOST}" ]]; then
    VPS_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  log "VPS_HOST detectado: ${VPS_HOST:-não detectado — defina export VPS_HOST=...}"
}

log "Instalando Docker (se necessário)..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | run_root sh
  run_root systemctl enable --now docker 2>/dev/null || run_root service docker start 2>/dev/null || true
  if [[ "$(id -u)" -ne 0 ]] && id -nG "$USER" 2>/dev/null | grep -qv docker; then
    run_root usermod -aG docker "$USER"
    log "Usuário $USER adicionado ao grupo docker — faça logout/login."
  fi
fi

if ! docker compose version >/dev/null 2>&1; then
  log "Docker Compose v2 não encontrado — instalando plugin..."
  install_packages git curl openssl
  if command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y docker-compose-plugin 2>/dev/null || true
  elif command -v yum >/dev/null 2>&1; then
    run_root yum install -y docker-compose-plugin 2>/dev/null || true
  fi
fi

command -v docker >/dev/null 2>&1 || { log "Docker não instalado."; exit 1; }
docker compose version >/dev/null 2>&1 || { log "Docker Compose v2 não encontrado."; exit 1; }

for cmd in git curl openssl; do
  command -v "${cmd}" >/dev/null 2>&1 || install_packages git curl openssl
done

detect_vps_host

mkdir -p "$(dirname "${DEVOPS_DIR}")"
if [[ ! -d "${DEVOPS_DIR}/.git" ]]; then
  log "Clonando aerorf-devops..."
  git clone https://github.com/AeroRF/aerorf-devops.git "${DEVOPS_DIR}"
fi

if [[ ! -d "${BACKEND_DIR}/.git" ]]; then
  log "Clonando aerorf-backend (opcional, migrate/seed)..."
  git clone https://github.com/AeroRF/aerorf-backend.git "${BACKEND_DIR}" \
    || log "Backend privado — seed manual depois."
fi

cd "${DEVOPS_DIR}"
chmod +x devops/aerorf-devops.sh devops/scripts/*.sh 2>/dev/null || true

if [[ ! -f compose/.env.dev ]]; then
  cp compose/.env.dev.example compose/.env.dev
  if [[ -n "${VPS_HOST}" ]]; then
    sed -i "s/SEU_IP_OU_DOMINIO/${VPS_HOST}/g" compose/.env.dev
    log "compose/.env.dev ajustado para VPS_HOST=${VPS_HOST}"
  else
    log "Edite compose/.env.dev — defina CORS_ORIGIN com IP público."
  fi
fi

export SKIP_NODE_CHECK=1

log "Gerando JWT e subindo infra..."
./devops/aerorf-devops.sh install dev --local-apps

log "Migrate (SQL)..."
./devops/aerorf-devops.sh migrate || true

log ""
log "Bootstrap concluído. Próximo passo:"
log "  export GHCR_TOKEN=<PAT read:packages> GHCR_USER=<github-user>"
log "  cd ${DEVOPS_DIR} && ./devops/aerorf-devops.sh install dev"
log "  Firewall: portas 3000, 4000"
log ""
log "Web:  http://${VPS_HOST:-SEU_IP}:3000"
log "API:  http://${VPS_HOST:-SEU_IP}:4000/api/v1/health"
