#!/usr/bin/env bash

cmd_install_prod() {
  log "=== Instalação PROD (scaffold apps stateless) ==="
  validate_prerequisites prod-only
  init_directories
  init_env_prod
  init_jwt_keys

  log "Validando compose prod-apps..."
  validate_prod_config

  cat <<EOF

Próximos passos PROD:
  1. Edite compose/.env.prod com hosts EXTERNOS:
     - DATABASE_URL → servidor PostgreSQL dedicado
     - S3_ENDPOINT  → MinIO/S3 dedicado
     - REDIS_URL    → Redis managed/VM

  2. Imagens GHCR (CI dos repos backend/frontend):
     - ghcr.io/aerorf/aerorf-backend:latest
     - ghcr.io/aerorf/aerorf-frontend:latest

  3. Docker Compose (somente apps):
     ./devops/aerorf-devops.sh up prod

  4. Kubernetes:
     ./devops/aerorf-devops.sh k8s validate
     ./devops/aerorf-devops.sh k8s apply

EOF

  print_endpoints_prod
  log_ok "Scaffold PROD concluído."
}

cmd_up_prod() {
  compose_prod up -d
  print_endpoints_prod
  log_ok "Apps PROD (stateless) iniciados. Serviços de dados são EXTERNOS."
}

cmd_down_prod() {
  log "Parando apps PROD..."
  compose_prod down
  log_ok "Apps PROD parados."
}
