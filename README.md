# aerorf-devops

Infraestrutura AeroRF SaaS — Docker Compose (dev/prod), Kubernetes, observabilidade e CLI DevOps.

Organização: [AeroRF](https://github.com/AeroRF)

## Repositórios relacionados

| Repo | Função |
|---|---|
| [aerorf-packages](https://github.com/AeroRF/aerorf-packages) | `@aerorf/shared`, `@aerorf/business-rules` |
| [aerorf-backend](https://github.com/AeroRF/aerorf-backend) | API REST |
| [aerorf-frontend](https://github.com/AeroRF/aerorf-frontend) | Next.js |

## Estrutura

```text
compose/           Docker Compose dev + prod-apps + migrations SQL
k8s/               Manifests Kubernetes
observability/     Prometheus, Grafana, Loki, Promtail
devops/            CLI aerorf-devops.sh
keys/              JWT dev (gitignored)
```

## Dev — instalação rápida

Clone os 4 repos no mesmo diretório pai:

```text
~/aerorf/
  aerorf-packages/
  aerorf-devops/
  aerorf-backend/
  aerorf-frontend/
```

```bash
cd aerorf-devops
chmod +x devops/aerorf-devops.sh

# Infra no Docker + apps locais (recomendado)
./devops/aerorf-devops.sh install dev --local-apps

# Backend e frontend (outros terminais)
cd ../aerorf-backend && cp .env.example .env && npm install ../aerorf-packages/packages/* && npm install
npm run migrate && npm run seed && npm run dev

cd ../aerorf-frontend && cp .env.example .env.local && npm install ../aerorf-packages/packages/* && npm install
npm run dev
```

## Dev — stack completa via GHCR

Após CI publicar imagens:

```bash
./devops/aerorf-devops.sh install dev   # profile apps — puxa ghcr.io/aerorf/*
```

## Comandos

| Comando | Descrição |
|---|---|
| `install dev` | Infra + apps GHCR (profile apps) + migrate + seed |
| `install dev --local-apps` | Só infra; apps via npm nos repos backend/frontend |
| `up dev [--apps]` | Sobe stack |
| `down dev` | Para containers |
| `migrate` / `seed` | Via repo `../aerorf-backend` |
| `k8s validate\|apply` | Manifests em `k8s/` |

## Imagens Docker (GHCR)

- `ghcr.io/aerorf/aerorf-backend:latest`
- `ghcr.io/aerorf/aerorf-frontend:latest`

## Produção

Apps stateless — Postgres, MinIO e observabilidade **externos** (`compose/.env.prod.example`).
