# Contrato de variáveis — serviços externos vs embutidos
# Ver .env.dev.example (tudo local) e .env.prod.example (hosts dedicados)

| Variável | Dev (compose) | Prod (externo) |
|---|---|---|
| DATABASE_URL | postgres://...@pgbouncer:5432 | postgres://...@db.aerorf.internal |
| REDIS_URL | redis://redis:6379 | redis://redis.aerorf.internal |
| S3_ENDPOINT | http://minio:9000 | https://storage.aerorf.internal |
| PROMETHEUS | localhost:9090 (compose) | obs.aerorf.internal |
| LOKI | localhost:3100 (compose) | obs.aerorf.internal |
| GRAFANA | localhost:3001 (compose) | obs.aerorf.internal |

Aplicações (api, web) usam **as mesmas env vars** — apenas o valor muda por ambiente.

## Instalação automatizada

Use o CLI DevOps:

```bash
./infra/devops/aerorf-devops.sh install dev
```

Ver [../devops/README.md](../devops/README.md).
