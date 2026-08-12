#!/usr/bin/env bash
# Espelha código-fonte do monorepo → repos-split/ (GitHub deploy).
# NÃO copia Dockerfiles, package.json raiz nem CI — cada repo split tem estrutura própria.
#
# Uso (monorepo):
#   ./infra/devops/mirror-repos-split.sh [--check]
#   npm run devops:mirror
#
# Uso (aerorf-devops repo, clones irmãos em repos-split/):
#   ./devops/scripts/mirror-repos-split.sh [--check]
#   AERORF_MONOREPO_ROOT=/caminho/monorepo ./devops/scripts/mirror-repos-split.sh
set -euo pipefail

resolve_monorepo_root() {
  if [[ -n "${AERORF_MONOREPO_ROOT:-}" ]]; then
    echo "${AERORF_MONOREPO_ROOT}"
    return 0
  fi
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -d "${script_dir}/../../apps/web" ]]; then
    cd "${script_dir}/../.." && pwd
    return 0
  fi
  if [[ -d "${script_dir}/../../../../apps/web" ]]; then
    cd "${script_dir}/../../../.." && pwd
    return 0
  fi
  return 1
}

ROOT="$(resolve_monorepo_root)" || {
  echo "mirror: defina AERORF_MONOREPO_ROOT ou execute a partir do monorepo." >&2
  exit 1
}

FE="${ROOT}/repos-split/aerorf-frontend"
BE="${ROOT}/repos-split/aerorf-backend"
PK="${ROOT}/repos-split/aerorf-packages"
CHECK=false
[[ "${1:-}" == "--check" ]] && CHECK=true

rsync_() {
  if $CHECK; then
    rsync -avn "$@"
  else
    rsync -av "$@"
  fi
}

die() { echo "mirror: $*" >&2; exit 1; }

[[ -d "$FE" ]] || die "repos-split/aerorf-frontend não encontrado em ${ROOT}"
[[ -d "$BE" ]] || die "repos-split/aerorf-backend não encontrado em ${ROOT}"
[[ -d "$PK" ]] || die "repos-split/aerorf-packages não encontrado em ${ROOT}"

echo "==> Monorepo: ${ROOT}"
echo "==> Frontend: apps/web → aerorf-frontend"
rsync_ --delete \
  --exclude='node_modules' --exclude='.next' --exclude='tsconfig.tsbuildinfo' \
  "${ROOT}/apps/web/app/" "${FE}/app/"
rsync_ --delete --exclude='node_modules' \
  "${ROOT}/apps/web/components/" "${FE}/components/"
rsync_ "${ROOT}/apps/web/lib/" "${FE}/lib/"
rsync_ "${ROOT}/apps/web/public/" "${FE}/public/"

echo "==> Backend: apps/api → aerorf-backend"
rsync_ --delete \
  --exclude='node_modules' --exclude='dist' --exclude='coverage' \
  "${ROOT}/apps/api/src/" "${BE}/src/"
rsync_ "${ROOT}/apps/api/migrations/" "${BE}/migrations/"

echo "==> Packages: packages/* → aerorf-packages"
rsync_ "${ROOT}/packages/business-rules/src/" "${PK}/packages/business-rules/src/"
rsync_ "${ROOT}/packages/shared/src/" "${PK}/packages/shared/src/"
cp "${ROOT}/packages/business-rules/package.json" "${PK}/packages/business-rules/"
cp "${ROOT}/packages/business-rules/tsconfig.json" "${PK}/packages/business-rules/"
cp "${ROOT}/packages/business-rules/vitest.config.ts" "${PK}/packages/business-rules/"

echo "==> Backend vendored packages (file: deps)"
rsync_ "${ROOT}/packages/business-rules/src/" "${BE}/packages/business-rules/src/"
rsync_ "${ROOT}/packages/shared/src/" "${BE}/packages/shared/src/"
cp "${ROOT}/packages/business-rules/package.json" "${BE}/packages/business-rules/"

if $CHECK; then
  echo "==> Dry-run concluído (nenhum arquivo alterado)"
else
  echo "==> Espelhamento concluído. Revise com 'git status' em cada repos-split/* e faça push."
fi
