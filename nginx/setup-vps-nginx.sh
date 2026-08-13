#!/usr/bin/env bash
# AeroRF — Nginx na VPS HostGator (AlmaLinux + LiteSpeed na porta 80)
# VPS exclusiva AeroRF: para LiteSpeed e usa Nginx como reverse proxy.
#
# Uso (na VPS, como root):
#   curl -fsSL https://raw.githubusercontent.com/AeroRF/aerorf-devops/main/nginx/setup-vps-nginx.sh | bash
#   # ou, com repo já clonado:
#   bash ~/aerorf/aerorf-devops/nginx/setup-vps-nginx.sh
#
# SSL (após DNS propagado):
#   bash ~/aerorf/aerorf-devops/nginx/setup-vps-nginx.sh --certbot
set -euo pipefail

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
CONF_SRC="${DEVOPS_DIR}/nginx/aerorf.conf"
CONF_DEST="/etc/nginx/conf.d/aerorf.conf"
RUN_CERTBOT=false
[[ "${1:-}" == "--certbot" ]] && RUN_CERTBOT=true

log() { printf '[nginx-setup] %s\n' "$*"; }

run_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

is_rhel_family() {
  [[ -f /etc/redhat-release ]] || grep -qiE 'centos|almalinux|rocky|rhel' /etc/os-release 2>/dev/null
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
    log "Gerenciador de pacotes não suportado."
    exit 1
  fi
}

ensure_devops_repo() {
  if [[ ! -f "${CONF_SRC}" ]]; then
    log "Clonando aerorf-devops..."
    mkdir -p "$(dirname "${DEVOPS_DIR}")"
    git clone https://github.com/AeroRF/aerorf-devops.git "${DEVOPS_DIR}"
    git -C "${DEVOPS_DIR}" pull --ff-only origin main 2>/dev/null || true
  fi
  [[ -f "${CONF_SRC}" ]] || { log "Arquivo não encontrado: ${CONF_SRC}"; exit 1; }
}

stop_litespeed() {
  if ss -tlnp 2>/dev/null | grep -qE ':80 .*litespeed'; then
    log "LiteSpeed ocupa a porta 80 — parando (VPS exclusiva AeroRF)..."
    run_root systemctl stop lsws 2>/dev/null || true
    if [[ -x /usr/local/lsws/bin/lswsctrl ]]; then
      run_root /usr/local/lsws/bin/lswsctrl stop 2>/dev/null || true
    fi
    run_root systemctl disable lsws 2>/dev/null || true
    sleep 2
    if ss -tlnp 2>/dev/null | grep -qE ':80 .*litespeed'; then
      log "ERRO: LiteSpeed ainda na porta 80. Verifique: ss -tlnp | grep ':80 '"
      exit 1
    fi
    log "LiteSpeed parado."
  else
    log "Porta 80 livre (LiteSpeed não detectado)."
  fi
}

install_nginx() {
  if command -v nginx >/dev/null 2>&1; then
    log "Nginx já instalado."
    return 0
  fi
  log "Instalando Nginx..."
  if is_rhel_family; then
    install_packages epel-release 2>/dev/null || true
    install_packages nginx
  else
    install_packages nginx
  fi
  run_root systemctl enable nginx
}

install_certbot() {
  if command -v certbot >/dev/null 2>&1; then
    return 0
  fi
  log "Instalando Certbot..."
  if is_rhel_family; then
    install_packages certbot python3-certbot-nginx 2>/dev/null || install_packages certbot
  else
    install_packages certbot python3-certbot-nginx
  fi
}

configure_selinux() {
  if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce 2>/dev/null)" != "Disabled" ]]; then
    log "SELinux: permitindo proxy Nginx → containers..."
    run_root setsebool -P httpd_can_network_connect 1
  fi
}

configure_firewall() {
  if command -v firewall-cmd >/dev/null 2>&1 && run_root systemctl is-active firewalld >/dev/null 2>&1; then
    log "Firewalld: liberando HTTP/HTTPS..."
    run_root firewall-cmd --permanent --add-service=http
    run_root firewall-cmd --permanent --add-service=https
    run_root firewall-cmd --reload
  fi
}

install_aerorf_conf() {
  log "Instalando ${CONF_DEST}..."
  run_root cp "${CONF_SRC}" "${CONF_DEST}"
  if is_rhel_family; then
    run_root rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true
  fi
  run_root nginx -t
}

start_nginx() {
  run_root systemctl start nginx
  run_root systemctl reload nginx 2>/dev/null || true
  if run_root systemctl is-active nginx >/dev/null 2>&1; then
    log "Nginx active."
  else
    log "ERRO: Nginx não subiu. Verifique: systemctl status nginx"
    exit 1
  fi
}

run_certbot() {
  log "Emitindo certificados Let's Encrypt (DNS deve apontar para esta VPS)..."
  run_root certbot --nginx --non-interactive --agree-tos --register-unsafely-without-email \
    -d aerorf.com.br \
    -d www.aerorf.com.br \
    -d app.aerorf.com.br \
    -d api.aerorf.com.br \
    || {
      log "Certbot falhou — confira DNS e rode depois:"
      log "  certbot --nginx -d aerorf.com.br -d www.aerorf.com.br -d app.aerorf.com.br -d api.aerorf.com.br"
      return 0
    }
  log "HTTPS configurado."
}

smoke_test() {
  log "Smoke test local..."
  curl -sf http://127.0.0.1:3000/api/health >/dev/null \
    && log "  web :3000 OK" || log "  web :3000 — container aerorf_web rodando?"
  curl -sf http://127.0.0.1:4000/api/v1/health >/dev/null \
    && log "  api :4000 OK" || log "  api :4000 — container aerorf_api rodando?"
  curl -sf -o /dev/null -w '' -H 'Host: aerorf.com.br' http://127.0.0.1/ \
    && log "  nginx proxy (Host: aerorf.com.br) OK" || log "  nginx proxy — verifique aerorf.conf"
}

# --- main ---
[[ "$(id -u)" -eq 0 ]] || command -v sudo >/dev/null || { log "Execute como root ou com sudo."; exit 1; }

ensure_devops_repo
stop_litespeed
install_nginx
install_certbot
configure_selinux
configure_firewall
install_aerorf_conf
start_nginx
smoke_test

if $RUN_CERTBOT; then
  run_certbot
fi

log ""
log "Concluído. Próximos passos:"
log "  1. DNS A → IP desta VPS (@, www, app, api, ...)"
log "  2. Certbot: bash ${DEVOPS_DIR}/nginx/setup-vps-nginx.sh --certbot"
log "  3. Deploy GitHub: CORS_ORIGIN / APP_PUBLIC_URL = https://app.aerorf.com.br"
log "  4. Teste: https://aerorf.com.br  |  https://app.aerorf.com.br/login"
