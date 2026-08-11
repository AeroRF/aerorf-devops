#!/usr/bin/env bash
# AeroRF DevOps — CLI principal
# Uso: ./devops/aerorf-devops.sh <comando> [ambiente] [opções]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/check.sh
source "${SCRIPT_DIR}/lib/check.sh"
# shellcheck source=lib/init.sh
source "${SCRIPT_DIR}/lib/init.sh"
# shellcheck source=lib/dev.sh
source "${SCRIPT_DIR}/lib/dev.sh"
# shellcheck source=lib/prod.sh
source "${SCRIPT_DIR}/lib/prod.sh"
# shellcheck source=lib/k8s.sh
source "${SCRIPT_DIR}/lib/k8s.sh"

usage() {
  cat <<'EOF'
AeroRF DevOps — estrutura de instalação e operação

Uso:
  aerorf-devops.sh install <dev|prod> [--local-apps]   Instala ambiente completo
  up dev [--apps] [--build]     Sobe stack ( --apps inclui containers GHCR )
  aerorf-devops.sh down <dev|prod>                      Para containers
  aerorf-devops.sh restart <dev|prod>                   Reinicia stack
  aerorf-devops.sh status [dev|prod]                    Status dos serviços
  aerorf-devops.sh logs <dev|prod> [servico]            Logs (ex: api, postgres)
  aerorf-devops.sh seed                                 Executa seed do banco (dev)
  aerorf-devops.sh migrate                              Executa migrations (dev)
  aerorf-devops.sh validate <dev|prod>                  Valida pré-requisitos e config
  aerorf-devops.sh k8s <validate|apply>                 Kubernetes (prod)
  aerorf-devops.sh help

Ambientes:
  dev   Stack completa (Postgres, Redis, MinIO, observabilidade + apps)
  prod  Somente apps stateless — DB/MinIO/obs externos (.env.prod)

Exemplos:
  ./devops/aerorf-devops.sh install dev
  ./devops/aerorf-devops.sh install dev --local-apps
  ./devops/aerorf-devops.sh up dev --apps
  ./infra/devops/aerorf-devops.sh validate prod
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true

  case "${cmd}" in
    install)
      local env="${1:-dev}"
      shift || true
      case "${env}" in
        dev)  cmd_install_dev "$@" ;;
        prod) cmd_install_prod "$@" ;;
        *)    die "Ambiente inválido: ${env}. Use dev ou prod." ;;
      esac
      ;;
    up)
      local env="${1:-dev}"
      shift || true
      case "${env}" in
        dev)  cmd_up_dev "$@" ;;
        prod) cmd_up_prod "$@" ;;
        *)    die "Ambiente inválido: ${env}" ;;
      esac
      ;;
    down)
      local env="${1:-dev}"
      case "${env}" in
        dev)  cmd_down_dev ;;
        prod) cmd_down_prod ;;
        *)    die "Ambiente inválido: ${env}" ;;
      esac
      ;;
    restart)
      local env="${1:-dev}"
      cmd_down "${env}"
      cmd_up "${env}" --build
      ;;
    status) cmd_status "${1:-dev}" ;;
    logs)   cmd_logs "${1:-dev}" "${2:-}" ;;
    seed)   cmd_seed ;;
    migrate) cmd_migrate ;;
    validate)
      local env="${1:-dev}"
      validate_prerequisites
      case "${env}" in
        dev)  validate_dev_config ;;
        prod) validate_prod_config ;;
        *)    die "Ambiente inválido: ${env}" ;;
      esac
      log_ok "Validação ${env} concluída."
      ;;
    k8s)
      local sub="${1:-validate}"
      case "${sub}" in
        validate) k8s_validate ;;
        apply)    k8s_apply ;;
        *)        die "Subcomando k8s inválido: ${sub}" ;;
      esac
      ;;
    help|-h|--help) usage ;;
    *)
      die "Comando desconhecido: ${cmd}. Use 'help'."
      ;;
  esac
}

cmd_down() {
  local env="$1"
  case "${env}" in
    dev)  cmd_down_dev ;;
    prod) cmd_down_prod ;;
  esac
}

cmd_up() {
  local env="$1"
  shift || true
  case "${env}" in
    dev)  cmd_up_dev "$@" ;;
    prod) cmd_up_prod "$@" ;;
  esac
}

main "$@"
