# Observabilidade AeroRF

Deploy **somente via pipeline** (`aerorf-devops` → `deploy-development.yml`).

## Grafana — acesso

| Campo | Valor |
|-------|-------|
| **URL** | `http://<VPS>:3001` (ex.: http://143.95.222.78:3001) |
| **Usuário padrão** | `admin` |
| **Senha padrão** | `admin` (alterar via secret GitHub) |

### Alterar login/senha (recomendado)

No GitHub → **Settings → Environments → development** → Secrets:

| Secret | Exemplo |
|--------|---------|
| `GRAFANA_ADMIN_USER` | `admin` |
| `GRAFANA_ADMIN_PASSWORD` | senha forte |

O deploy injeta no `.env.dev` do VPS. **Nota:** se o volume Grafana já existir, a senha só muda na primeira instalação ou após reset do volume `grafana_data`.

### Dashboard principal

Após login, abra a pasta **AeroRF** → **AeroRF — Visão Geral do Sistema** (home dashboard automático).

Painéis incluídos:
- API/Web online, erros 4xx/5xx, login, storage
- Latência P95, proxy Next.js, auth failures
- CPU, memória, disco do servidor
- PostgreSQL conexões, Redis memória
- Logs de erro (Loki)
- Alertas Prometheus ativos

## Slack — alertas

### 1. Alertas de sistema (Prometheus → Alertmanager → Slack)

Configure no environment **development**:

```
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T.../B.../xxx
```

Canal sugerido: `#aerorf-alerts`

Dispara em: 5xx, 4xx em pico, falhas de login, erros storage/proxy, CPU/memória/disco, serviços down.

### 2. Deployments CI/CD (GitHub Actions → Slack)

O mesmo `SLACK_WEBHOOK_URL` notifica:

| Evento | Repo |
|--------|------|
| Imagem backend publicada | `aerorf-backend` |
| Imagem frontend publicada | `aerorf-frontend` |
| Deploy VPS concluído/falhou | `aerorf-devops` |

Configure o secret em **cada repositório** ou no nível da org `AeroRF`.

## Separação de ambientes

| Ambiente | Dados | Observabilidade |
|----------|-------|-----------------|
| **development** | Volumes VPS, bucket `aerorf-dev` | Stack no compose |
| **homolog/prod** | Instâncias dedicadas | Externa — sem dados de dev |

## URLs (VPS dev)

- Grafana: `:3001`
- Prometheus: `:9090`
- Alertmanager: `:9093`
