# Mapa de domínios AeroRF (VPS / produção)

Reverse proxy **Nginx** na VPS. Configurado **automaticamente pelo pipeline** — não execute git nem scripts manualmente na VPS.

## Pipeline (único caminho operacional)

**Actions → aerorf-devops → Deploy Development**

| Input | Default | Descrição |
|-------|---------|-----------|
| `backend_tag` | `latest` | Imagem API |
| `frontend_tag` | `latest` | Imagem Web |
| `setup_nginx` | `true` | Para LiteSpeed, instala Nginx + `aerorf.conf` |
| `run_certbot` | `false` | HTTPS Let's Encrypt (ligue quando DNS estiver OK) |

O deploy (`remote-compose-deploy.sh`) após subir containers:
1. Atualiza `aerorf-devops` via git **no script** (automático)
2. Executa `nginx/setup-vps-nginx.sh` (LiteSpeed off → Nginx proxy)

### Secrets GitHub (environment `development`)

| Secret | Exemplo | Quando |
|--------|---------|--------|
| `APP_PUBLIC_URL` | `https://app.aerorf.com.br` | Após DNS + certbot |
| `CORS_ORIGIN` | `https://app.aerorf.com.br` | Idem |
| `COOKIE_SECURE` | `true` | Com HTTPS |

---

## DNS (registros A → IP da VPS)

| Host | Uso |
|------|-----|
| `@` / `www` | Landing (`aerorf.com.br`) |
| `app` | SaaS Next.js |
| `api` | API REST |
| `grafana` | Grafana (restrito) |
| `storage` | MinIO API (restrito) |

---

## Fluxo recomendado

1. **Deploy** com `setup_nginx=true`, `run_certbot=false` → Nginx HTTP nos domínios
2. Configure **DNS** apontando para a VPS
3. **Deploy** de novo com `run_certbot=true` → HTTPS
4. Configure secrets `APP_PUBLIC_URL`, `CORS_ORIGIN`, `COOKIE_SECURE=true`
5. **Deploy** final → apps com URLs de produção

---

## Domínios e roteamento

| Domínio | Backend local |
|---------|---------------|
| `aerorf.com.br` / `www` | `127.0.0.1:3000` (landing HTML legado) |
| `app.aerorf.com.br` | `127.0.0.1:3000` (SaaS) |
| `api.aerorf.com.br` | `127.0.0.1:4000` |

Middleware Next.js usa header `Host` — Nginx repassa via `proxy_set_header Host $host`.

Arquivos: `nginx/aerorf.conf`, `nginx/setup-vps-nginx.sh`
