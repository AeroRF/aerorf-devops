# AeroRF DevOps

Scripts para instalar e operar a infraestrutura conforme a arquitetura:

| Ambiente | O que instala | Dados persistentes |
|---|---|---|
| **dev** | Stack completa no Docker Compose | Postgres, MinIO, Redis, Loki (volumes locais) |
| **prod** | Somente API + Web (stateless) | **Externos** — DB, MinIO, observabilidade |

## Início rápido

```bash
chmod +x infra/devops/aerorf-devops.sh

# Instalação completa DEV (recomendado na primeira vez)
./infra/devops/aerorf-devops.sh install dev

# DEV com apps locais (só infra no Docker)
./infra/devops/aerorf-devops.sh install dev --local-apps

# Scaffold PROD (gera .env.prod, build, valida)
./infra/devops/aerorf-devops.sh install prod
```

Via npm (raiz do monorepo):

```bash
npm run devops:install:dev
npm run devops:up:dev
npm run devops:status
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
| `k8s validate\|apply` | Manifests em `infra/k8s/` |

## Estrutura

```text
infra/devops/
├── aerorf-devops.sh      # CLI principal
└── lib/
    ├── common.sh         # Paths, logs, helpers
    ├── check.sh          # Pré-requisitos e validação
    ├── init.sh           # .env, JWT, npm build
    ├── dev.sh            # Ambiente desenvolvimento
    ├── prod.sh           # Ambiente produção (apps only)
    └── k8s.sh            # Kubernetes
```

## Arquivos de ambiente

- `infra/compose/.env.dev` — gerado de `.env.dev.example` (serviços locais)
- `infra/compose/.env.prod` — gerado de `.env.prod.example` (hosts externos)

Nunca commite secrets de produção. JWT dev fica em `infra/keys/` (gitignored em prod real).
