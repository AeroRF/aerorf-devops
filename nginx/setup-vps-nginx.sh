#!/usr/bin/env bash
# AeroRF — Nginx na VPS HostGator (AlmaLinux + LiteSpeed na porta 80)
# Invocado pelo pipeline (remote-compose-deploy.sh) — NÃO rode git manualmente na VPS.
#
# Requer DEVOPS_DIR já atualizado pelo deploy (ensure_devops_repo).
# SSL opcional: AERORF_CERTBOT=1
set -euo pipefail

DEVOPS_DIR="${DEVOPS_DIR:-$HOME/aerorf/aerorf-devops}"
CONF_SRC="${DEVOPS_DIR}/nginx/aerorf.conf"
CONF_DEST="/etc/nginx/conf.d/aerorf.conf"

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
      log "ERRO: LiteSpeed ainda na porta 80."
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
  [[ -f "${CONF_SRC}" ]] || { log "Config não encontrada: ${CONF_SRC} (deploy deveria ter atualizado aerorf-devops)"; exit 1; }
  log "Instalando ${CONF_DEST}..."
  run_root cp "${CONF_SRC}" "${CONF_DEST}"
  if is_rhel_family; then
    run_root rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true
  fi
  run_root nginx -t
}

start_nginx() {
  run_root systemctl start nginx 2>/dev/null || true
  run_root systemctl reload nginx
  if run_root systemctl is-active nginx >/dev/null 2>&1; then
    log "Nginx active."
  else
    log "ERRO: Nginx não subiu."
    exit 1
  fi
}

run_certbot() {
  log "Emitindo certificados Let's Encrypt..."
  run_root certbot --nginx --non-interactive --agree-tos --register-unsafely-without-email \
    -d aerorf.com.br \
    -d www.aerorf.com.br \
    -d app.aerorf.com.br \
    -d api.aerorf.com.br \
    && log "HTTPS configurado." \
    || log "Certbot falhou (DNS ainda propagando?) — próximo deploy com run_certbot=true"
}

smoke_test() {
  log "Smoke test Nginx..."
  curl -sf http://127.0.0.1:3000/api/health >/dev/null \
    && log "  web :3000 OK" || log "  web :3000 — aguardando container"
  curl -sf http://127.0.0.1:4000/api/v1/health >/dev/null \
    && log "  api :4000 OK" || log "  api :4000 — aguardando container"
  curl -sf -o /dev/null -w '' -H 'Host: aerorf.com.br' http://127.0.0.1/ \
    && log "  nginx → landing (Host: aerorf.com.br) OK" \
    || log "  nginx proxy landing — verifique aerorf.conf"
  curl -sf -o /dev/null -w '' -H 'Host: app.aerorf.com.br' http://127.0.0.1/login \
    && log "  nginx → app (Host: app.aerorf.com.br) OK" \
    || log "  nginx proxy app — verifique aerorf.conf"
}

# --- main (sourceable ou standalone) ---
setup_vps_nginx() {
  [[ "$(id -u)" -eq 0 ]] || command -v sudo >/dev/null || { log "Execute como root ou com sudo."; exit 1; }

  stop_litespeed
  install_nginx
  install_certbot
  configure_selinux
  configure_firewall
  install_aerorf_conf
  start_nginx
  smoke_test

  if [[ "${AERORF_CERTBOT:-}" == "1" ]]; then
    run_certbot
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  setup_vps_nginx
fi
