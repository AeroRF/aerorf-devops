# aerorf-devops

Infraestrutura AeroRF — Docker Compose, Kubernetes, observabilidade.

Repositório: https://github.com/AeroRF/aerorf-devops

## Deploy dev — VPS HostGator (Compose)

Usa **`compose/docker-compose.dev.yml`** (mesmo stack do monorepo `infra/compose`, adaptado ao split).

### 1. Bootstrap no VPS (uma vez)

SSH na HostGator (painel → VPS → SSH, usuário `root` ou o criado):

```bash
export VPS_HOST=SEU_IP_PUBLICO   # ex: 123.45.67.89
curl -fsSL https://raw.githubusercontent.com/AeroRF/aerorf-devops/main/devops/scripts/bootstrap-hostgator.sh | VPS_HOST=$VPS_HOST bash
```

Ou manualmente:

```bash
git clone https://github.com/AeroRF/aerorf-devops.git ~/aerorf/aerorf-devops
cd ~/aerorf/aerorf-devops
cp compose/.env.dev.example compose/.env.dev
# Edite CORS_ORIGIN=http://SEU_IP:3000
chmod +x devops/aerorf-devops.sh
./devops/aerorf-devops.sh install dev --local-apps
```

### 2. GHCR + apps

```bash
export GHCR_TOKEN=<PAT GitHub com read:packages>
export GHCR_USER=<seu-user-github>
cd ~/aerorf/aerorf-devops
./devops/aerorf-devops.sh install dev
```

### 3. Firewall HostGator

Libere no painel ou `ufw`:

| Porta | Serviço |
|---|---|
| 3000 | Web |
| 4000 | API (opcional se usar proxy `/api/v1` no front) |
| 22 | SSH |

### 4. Deploy — somente GitHub Actions (sem SSH manual)

**Setup único** (environment `development` + secrets SSH/GHCR) — ver seção abaixo se ainda não configurou.

1. Cancele runs antigos/travados em Actions, se houver.
2. https://github.com/AeroRF/aerorf-devops/actions/workflows/deploy-development.yml
3. **Run workflow** → branch `main` → target **compose-ssh** → tags `latest`

O pipeline faz tudo no VPS: git pull, JWT, CORS, PgBouncer (SCRAM), pull GHCR, API/Web, migrate, seed e health check.

**Não é necessário** rodar comandos manualmente no VPS após os secrets configurados.

#### Secrets (environment `development`)

| Secret | Valor |
|---|---|
| `DEV_SSH_HOST` | IP público HostGator |
| `DEV_SSH_PORT` | `22022` (opcional) |
| `DEV_SSH_USER` | `root` |
| `DEV_SSH_KEY` | chave privada deploy |
| `GHCR_TOKEN` | PAT `read:packages` |
| `GHCR_USER` | usuário GitHub |

### URLs

- Web: `http://SEU_IP:3000`
- API health: `http://SEU_IP:4000/api/v1/health`
- Login demo (após seed): `admin@aerorf.com.br` / `admin123`

O front usa `/api/v1` relativo (proxy Next → container `api`) — funciona com IP público sem rebuild.

## CI

- `devops-ci.yml` — valida compose + kubeconform
- `deploy-development.yml` — deploy manual (compose-ssh ou kubernetes)

## CLI

```bash
./devops/aerorf-devops.sh install dev --local-apps
./devops/aerorf-devops.sh install dev
./devops/aerorf-devops.sh logs dev api
```
