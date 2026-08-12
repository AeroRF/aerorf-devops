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

### 4. GitHub Actions (deploy automático — recomendado)

**Uma vez:** configure o environment **development** em  
https://github.com/AeroRF/aerorf-devops/settings/environments

#### 4.1 Chave SSH só para Actions (no seu Mac)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/aerorf_deploy -N "" -C "github-actions-aerorf"
cat ~/.ssh/aerorf_deploy.pub
```

No VPS (como root):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "COLE_A_PUBLIC_KEY_aqui" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### 4.2 Secrets no environment `development`

| Secret | Valor |
|---|---|
| `DEV_SSH_HOST` | IP público HostGator |
| `DEV_SSH_USER` | `root` |
| `DEV_SSH_KEY` | conteúdo de `~/.ssh/aerorf_deploy` (privada) |
| `GHCR_TOKEN` | PAT GitHub com `read:packages` |
| `GHCR_USER` | seu usuário GitHub (ex: `dsdouglas`) |

PAT: GitHub → Settings → Developer settings → Personal access tokens → `read:packages`.

#### 4.3 Disparar deploy

1. https://github.com/AeroRF/aerorf-devops/actions/workflows/deploy-development.yml  
2. **Run workflow**  
3. `target`: **compose-ssh**  
4. tags: **latest** (padrão)

O workflow SSH no VPS, faz pull GHCR, sobe API/Web, migrate/seed e health check.

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
