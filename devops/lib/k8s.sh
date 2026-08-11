#!/usr/bin/env bash

k8s_validate() {
  if command -v kubeconform >/dev/null 2>&1; then
    log "Validando manifests K8s (kubeconform, offline)..."
    kubeconform -summary -ignore-missing-schemas "${K8S_DIR}/"
    log_ok "Manifests K8s válidos."
    return 0
  fi

  command -v kubectl >/dev/null 2>&1 || die "Instale kubeconform (recomendado) ou kubectl."

  log_warn "kubeconform não encontrado — kubectl exige cluster para CRDs (ex: ServiceMonitor)."
  log "Validando manifests K8s (kubectl dry-run)..."
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
