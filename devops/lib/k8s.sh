#!/usr/bin/env bash

k8s_validate() {
  command -v kubectl >/dev/null 2>&1 || die "kubectl não encontrado."

  log "Validando manifests K8s (dry-run)..."
  kubectl apply --dry-run=client --validate=false -f "${K8S_DIR}/"
  log_ok "Manifests K8s válidos."
}

k8s_apply() {
  command -v kubectl >/dev/null 2>&1 || die "kubectl não encontrado."

  validate_prod_config
  log_warn "Apply em cluster real — confirme contexto kubectl: $(kubectl config current-context 2>/dev/null || echo '?')"

  kubectl apply -f "${K8S_DIR}/"
  log_ok "Manifests aplicados. Verifique: kubectl get pods -n aerorf-prod"
}
