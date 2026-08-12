# AeroRF DevOps

Scripts para instalar e operar a infraestrutura conforme a arquitetura:

| Ambiente | O que instala | Dados persistentes |
|---|---|---|
| **dev** | Stack completa no Docker Compose | Postgres, MinIO, Redis, Loki (volumes locais) |
| **prod** | Somente API + Web (stateless) | **Externos** — DB, MinIO, observabilidade |

## Início rápido

```bash
chmod +x devops/aerorf-devops.sh

# Instalação completa DEV (recomendado na primeira vez)
./devops/aerorf-devops.sh install dev

# DEV com apps locais (só infra no Docker)
./devops/aerorf-devops.sh install dev --local-apps

# Scaffold PROD (gera .env.prod, build, valida)
./devops/aerorf-devops.sh install prod
```

Via npm (raiz do monorepo local):

```bash
npm run devops:install:dev
npm run devops:up:dev
npm run devops:mirror
```

## Comandos

| Comando | Descrição |
|---|---|
| `install dev` | Pré-reqs, env, JWT, npm build, compose up, migrate, seed |
| `install dev --local-apps` | Infra no Docker; API/Web via `npm run dev:*` |
| `install prod` | Scaffold prod + build + validação |
| `up dev [--build]` | Sobe stack dev |
| `up prod [--build]` | Sobe apps prod (serviços externos via `.env.prod`) |
| `down dev\|prod` | Para containers |
| `status` | `docker compose ps` |
| `logs dev api` | Logs de um serviço |
| `seed` / `migrate` | Banco dev |
| `validate dev\|prod` | Checagens |
| `k8s validate\|apply` | Manifests em `k8s/` |
| `mirror [--check]` | Espelha monorepo → `repos-split/` (requer clones irmãos) |

## Espelhamento monorepo → GitHub

Antes de push/deploy, sincronize o código dos repos split:

```bash
# No monorepo (recomendado)
npm run devops:mirror
# ou dry-run
npm run devops:mirror:check

# A partir deste repo (monorepo em ../..)
AERORF_MONOREPO_ROOT=/caminho/AeroRF_MONOREPO ./devops/scripts/mirror-repos-split.sh
```

O script **não** copia Dockerfiles nem CI — cada repo split tem estrutura própria.

## Estrutura

```text
devops/
├── aerorf-devops.sh      # CLI principal
├── scripts/
│   ├── mirror-repos-split.sh
│   └── remote-compose-deploy.sh
└── lib/
    ├── common.sh
    ├── check.sh
    ├── init.sh
    ├── dev.sh
    ├── prod.sh
    └── k8s.sh
```

## Arquivos de ambiente

- `compose/.env.dev` — gerado de `.env.dev.example` (serviços locais)
- `compose/.env.prod` — gerado de `.env.prod.example` (hosts externos)

Nunca commite secrets de produção. JWT dev fica em `keys/` (gitignored em prod real).
