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

## Slack — alertas e deploys

### Secret obrigatório

No GitHub → **Settings → Environments → development** → Secret:

```
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T.../B.../xxx
```

Crie o webhook em [Slack API → Incoming Webhooks](https://api.slack.com/messaging/webhooks) apontando para o canal desejado (ex.: `#aerorf-alerts` ou `#deploys`).

> **Importante:** o canal é definido na criação do webhook — não é necessário (e pode falhar) configurar `channel` no Alertmanager.

### 1. Alertas de sistema (Prometheus → Alertmanager → Slack)

Após cada deploy VPS, o script `observability-slack-verify.sh`:
- recria o Alertmanager com o webhook atualizado
- envia um ping de confirmação no Slack
- valida Prometheus e targets

Dispara alertas em: 5xx, 4xx em pico, falhas de login, erros storage/proxy, CPU/memória/disco, serviços down.

### 2. Deployments CI/CD (GitHub Actions → Slack)

| Evento | Repo | Quando |
|--------|------|--------|
| Imagem backend publicada | `aerorf-backend` | push main |
| Imagem frontend publicada | `aerorf-frontend` | push main |
| Deploy VPS iniciado/concluído | `aerorf-devops` | Deploy Development |
| Reset credenciais | `aerorf-devops` | Reset Dev Credentials |

O secret `SLACK_WEBHOOK_URL` deve estar no environment **development** (usado pelos jobs de publish e deploy).

## Separação de ambientes

| Ambiente | Dados | Observabilidade |
|----------|-------|-----------------|
| **development** | Volumes VPS, bucket `aerorf-dev` | Stack no compose |
| **homolog/prod** | Instâncias dedicadas | Externa — sem dados de dev |

## URLs (VPS dev)

- Grafana: `:3001`
- Prometheus: `:9090`
- Alertmanager: `:9093`
