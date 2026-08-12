# Observabilidade AeroRF

Deploy **somente via pipeline** (`aerorf-devops` → `deploy-development.yml`). Não use comandos locais para subir stack em VPS.

## Separação de ambientes (dados)

| Ambiente | Project Compose | Bucket S3 | DB / volumes | Observabilidade |
|----------|-----------------|-----------|--------------|-----------------|
| **development** (VPS) | `aerorf-dev` | `aerorf-dev` | Volumes Docker no VPS dev | Stack embutida no compose |
| **homolog** | `aerorf-hml` (futuro) | `aerorf-hml` | Instância dedicada | Stack dedicada, label `environment=homolog` |
| **production** | K8s `aerorf-prod` | `aerorf-prod` | PostgreSQL/Redis/MinIO externos | Prometheus/Loki externos (`obs.aerorf.internal`) |

**Regra:** seed, dados demo e volumes de dev **nunca** são copiados para homolog/prod. Cada ambiente tem secrets e instâncias próprias no GitHub Environments.

## O que é monitorado

### Aplicação (API + Web)
- HTTP 4xx/5xx — counter + log estruturado (`event: http_error`)
- Falhas de login e refresh token (`auth_login_failures_total`, `auth_refresh_failures_total`)
- Erros de storage/presign/upload (`storage_operation_errors_total`)
- Erros do proxy Next.js → API (`proxy_errors_total`)
- Latência por rota (`http_request_duration_seconds`)

### Infraestrutura (servidor)
- CPU, memória, disco (`node-exporter`)
- Conexões PostgreSQL (`postgres-exporter`)
- Redis (`redis-exporter`)
- Targets up/down (API, Web, exporters)

### Logs (Loki + Promtail)
- Logs JSON do Pino (API) com labels `level`, `event`
- Erros HTTP e storage marcados como `alert_candidate`

## Alertas (threshold baixo)

Regras em `prometheus/alerts.yml`:

| Alerta | Condição |
|--------|----------|
| `AeroRFHttp5xx` | Qualquer 5xx em 5 min |
| `AeroRFHttp4xxSpike` | > 5 erros 4xx em 5 min |
| `AeroRFLoginFailures` | > 2 falhas de login em 5 min |
| `AeroRFStorageErrors` | Qualquer erro de storage |
| `AeroRFProxyErrors` | Proxy Next indisponível |
| `AeroRFHighCpu` | CPU > 70% por 3 min |
| `AeroRFHighMemory` | Memória > 75% |
| `AeroRFLowDisk` | Disco < 15% livre |

Alertmanager (`:9093`) encaminha para webhook configurado em `ALERT_WEBHOOK_URL` (GitHub secret no environment `development`).

## Pipeline

1. Push em `aerorf-backend` / `aerorf-frontend` → CI build + GHCR
2. Push em `aerorf-devops` (`compose/**`, `observability/**`) → `deploy-development.yml`
3. Script `remote-compose-deploy.sh` sobe: Postgres, Redis, MinIO, **Prometheus, Alertmanager, Grafana, Loki, Promtail, exporters**, depois apps

## URLs (VPS dev)

- Grafana: `http://<VPS>:3001` (admin/admin)
- Prometheus: `http://<VPS>:9090`
- Alertmanager: `http://<VPS>:9093`

## Configurar notificações

No GitHub → Settings → Environments → **development** → secret:

```
ALERT_WEBHOOK_URL=https://hooks.slack.com/services/...
```

O deploy injeta no `.env.dev` do VPS via `ensure_env_dev` (se configurado no script).
