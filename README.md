# aerorf-devops

Infraestrutura AeroRF — Docker Compose, Kubernetes, observabilidade, CLI DevOps.

Repositório: https://github.com/AeroRF/aerorf-devops

## Repositórios relacionados

| Repo | Função |
|---|---|
| [aerorf-packages](https://github.com/AeroRF/aerorf-packages) | Pacotes npm compartilhados |
| [aerorf-backend](https://github.com/AeroRF/aerorf-backend) | API REST |
| [aerorf-frontend](https://github.com/AeroRF/aerorf-frontend) | Next.js |

## CI

Workflow `devops-ci.yml`: valida compose dev/prod + **kubeconform** nos manifests K8s (sem cluster; ignora schema de CRDs como `ServiceMonitor`).

## Dev local (híbrido)

Clone os 4 repos no mesmo diretório pai (`~/aerorf/`).

```bash
chmod +x devops/aerorf-devops.sh
./devops/aerorf-devops.sh install dev --local-apps
```

Migrate/seed rodam no repo `../aerorf-backend` (variável `AERORF_BACKEND_DIR` em `compose/.env.dev`).

## Dev via GHCR (profile apps)

Após CI publicar imagens backend/frontend:

```bash
./devops/aerorf-devops.sh install dev   # sobe infra + ghcr.io/aerorf/aerorf-*
```

## Imagens

- `ghcr.io/aerorf/aerorf-backend:latest`
- `ghcr.io/aerorf/aerorf-frontend:latest`

## Comandos CLI

| Comando | Descrição |
|---|---|
| `install dev --local-apps` | Infra Docker; apps via npm nos repos |
| `install dev` | Infra + apps GHCR (profile `apps`) |
| `migrate` / `seed` | Delegado ao aerorf-backend |
| `k8s validate` | Dry-run dos manifests |
| `k8s apply` | Deploy em cluster configurado |

## Pipeline → deploy (próximo passo)

1. CI verde nos 4 repos
2. GitHub → Settings → Actions → General → **Workflow permissions: Read and write**
3. GHCR: tornar packages visíveis para repos privados backend/frontend
4. Secret `KUBE_CONFIG` (base64 do kubeconfig) no environment `development`
5. Substituir job de deploy placeholder por `kubectl set image` real
