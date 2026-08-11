# Variáveis de ambiente — compose

| Variável | Dev (compose) | Prod (externo) |
|---|---|---|
| DATABASE_URL | postgres local / pgbouncer | servidor PostgreSQL dedicado |
| REDIS_URL | redis://redis:6379 | Redis managed/VM |
| S3_ENDPOINT | http://minio:9000 | MinIO/S3 dedicado |

Exemplos: `.env.dev.example`, `.env.prod.example`

CLI: `../devops/aerorf-devops.sh install dev`
