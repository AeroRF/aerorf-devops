#!/usr/bin/env bash
# Bootstrap — VPS HostGator (CentOS/Alma/RHEL ou Ubuntu/Debian)
# Uso: export VPS_HOST=SEU_IP && curl -fsSL .../bootstrap-hostgator.sh | bash
set -euo pipefail

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
BACKEND_DIR="${BACKEND_DIR:-$HOME/aerorf/aerorf-backend}"
VPS_HOST="${VPS_HOST:-}"

log() { printf '[bootstrap] %s\n' "$*"; }

log "AeroRF bootstrap v3 — CentOS/yum (main $(date +%Y-%m-%d))"

is_rhel_family() {
  [[ -f /etc/redhat-release ]] || grep -qiE 'centos|almalinux|rocky|rhel|fedora' /etc/os-release 2>/dev/null
}

if [[ "$(id -u)" -ne 0 ]] && ! command -v sudo >/dev/null; then
  log "Execute como root ou com sudo disponível."
  exit 1
fi

run_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

install_packages() {
  local packages=("$@")
  if command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y "${packages[@]}"
  elif command -v yum >/dev/null 2>&1; then
    run_root yum install -y "${packages[@]}"
  elif command -v apt-get >/dev/null 2>&1; then
    run_root apt-get update -qq
    run_root apt-get install -y "${packages[@]}"
  else
    log "Gerenciador de pacotes não encontrado (yum/dnf/apt)."
    exit 1
  fi
}

install_docker_engine() {
  command -v docker >/dev/null 2>&1 && return 0

  log "Instalando Docker via gerenciador do SO (sem get.docker.com)..."
  if is_rhel_family; then
    install_packages yum-utils device-mapper-persistent-data lvm2 2>/dev/null \
      || install_packages yum-utils || true
    if command -v dnf >/dev/null 2>&1; then
      run_root dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || true
      run_root dnf install -y docker-ce docker-ce-cli containerd.io 2>/dev/null \
        || run_root dnf install -y docker
    else
      run_root yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || true
      run_root yum install -y docker-ce docker-ce-cli containerd.io 2>/dev/null \
        || run_root yum install -y docker
    fi
  elif command -v apt-get >/dev/null 2>&1; then
    install_packages ca-certificates curl gnupg
    curl -fsSL https://get.docker.com | run_root sh
  else
    log "SO não suportado automaticamente — instale Docker manualmente."
    exit 1
  fi

  run_root systemctl enable docker 2>/dev/null || true
  run_root systemctl start docker 2>/dev/null || run_root service docker start 2>/dev/null || true
}

install_compose_v2() {
  docker compose version >/dev/null 2>&1 && return 0

  log "Instalando Docker Compose v2..."
  if is_rhel_family; then
    run_root dnf install -y docker-compose-plugin 2>/dev/null \
      || run_root yum install -y docker-compose-plugin 2>/dev/null || true
  elif command -v apt-get >/dev/null 2>&1; then
    run_root apt-get install -y docker-compose-plugin 2>/dev/null || true
  fi

  if docker compose version >/dev/null 2>&1; then
    return 0
  fi

  log "Plugin indisponível — baixando binário compose v2..."
  local arch plugin_dir="/usr/local/lib/docker/cli-plugins"
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) arch="x86_64" ;;
    aarch64) arch="aarch64" ;;
  esac
  run_root mkdir -p "${plugin_dir}"
  run_root curl -fsSL \
    "https://github.com/docker/compose/releases/download/v2.24.7/docker-compose-linux-${arch}" \
    -o "${plugin_dir}/docker-compose"
  run_root chmod +x "${plugin_dir}/docker-compose"
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

install_docker_engine
install_compose_v2

command -v docker >/dev/null 2>&1 || { log "Docker não instalado."; exit 1; }
docker info >/dev/null 2>&1 || { log "Docker daemon não está rodando."; exit 1; }
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
  log "Clonando aerorf-backend (opcional)..."
  git clone https://github.com/AeroRF/aerorf-backend.git "${BACKEND_DIR}" \
    || log "Backend privado — seed manual depois."
fi

cd "${DEVOPS_DIR}"
git pull --ff-only origin main 2>/dev/null || true
chmod +x devops/aerorf-devops.sh devops/scripts/*.sh 2>/dev/null || true

if [[ ! -f compose/.env.dev ]]; then
  cp compose/.env.dev.example compose/.env.dev
fi
if [[ -n "${VPS_HOST}" ]]; then
  sed -i "s/SEU_IP_OU_DOMINIO/${VPS_HOST}/g" compose/.env.dev
  log "compose/.env.dev → VPS_HOST=${VPS_HOST}"
fi

export SKIP_NODE_CHECK=1

log "Gerando JWT e subindo infra..."
./devops/aerorf-devops.sh install dev --local-apps

log "Migrate (SQL)..."
./devops/aerorf-devops.sh migrate || true

log ""
log "Bootstrap concluído."
log "  export GHCR_TOKEN=<PAT> GHCR_USER=<github-user>"
log "  cd ${DEVOPS_DIR} && ./devops/aerorf-devops.sh install dev"
log "Web:  http://${VPS_HOST:-SEU_IP}:3000"
log "API:  http://${VPS_HOST:-SEU_IP}:4000/api/v1/health"
