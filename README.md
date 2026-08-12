# aerorf-devops

Infraestrutura AeroRF — Docker Compose, Kubernetes, observabilidade e CLI DevOps.

Repositório: https://github.com/AeroRF/aerorf-devops

## Repositórios

| Repo | Função |
|---|---|
| [aerorf-packages](https://github.com/AeroRF/aerorf-packages) | Pacotes npm |
| [aerorf-backend](https://github.com/AeroRF/aerorf-backend) | API → `ghcr.io/aerorf/aerorf-backend` |
| [aerorf-frontend](https://github.com/AeroRF/aerorf-frontend) | Web → `ghcr.io/aerorf/aerorf-frontend` |

## Deploy development

Workflow **Deploy Development** (manual): Actions → Deploy Development → Run workflow.

### Opção A — VPS + Docker Compose (recomendado para dev)

1. No servidor: clone `aerorf-devops`, instale Docker, gere JWT em `keys/`
2. GitHub → **aerorf-devops** → Settings → Environments → `development` → secrets:

| Secret | Conteúdo |
|---|---|
| `DEV_SSH_HOST` | IP/hostname do servidor |
| `DEV_SSH_USER` | usuário SSH (ex: `deploy`) |
| `DEV_SSH_KEY` | chave privada SSH |
| `GHCR_TOKEN` | PAT com `read:packages` (se imagens privadas) |

3. Run workflow → target **compose-ssh** → tags `latest`

No servidor, antes do primeiro deploy:

```bash
git clone git@github.com:AeroRF/aerorf-devops.git ~/aerorf/aerorf-devops
cd ~/aerorf/aerorf-devops && ./devops/aerorf-devops.sh install dev --local-apps
# clone backend ao lado para migrate/seed
```

### Opção B — Kubernetes (namespace `aerorf-dev`)

Secrets no environment `development`:

| Secret | Conteúdo |
|---|---|
| `KUBE_CONFIG` | `cat ~/.kube/config \| base64` |

Antes do deploy, edite `k8s/aerorf-dev.yaml` (JWT e DATABASE_URL reais) ou aplique secret via kubectl.

Run workflow → target **kubernetes**.

NodePorts padrão: API **30040**, Web **30080**.

### Deploy local com imagens GHCR

```bash
export GHCR_TOKEN=<PAT read:packages>
export GHCR_USER=<seu-user-github>
./devops/aerorf-devops.sh install dev
```

## CI

- `devops-ci.yml` — valida compose + kubeconform
- `deploy-development.yml` — deploy manual (compose-ssh ou kubernetes)

## CLI

```bash
./devops/aerorf-devops.sh install dev --local-apps  # infra only
./devops/aerorf-devops.sh install dev              # infra + GHCR apps
./devops/aerorf-devops.sh k8s validate
```
