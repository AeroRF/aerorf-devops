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

## Cloudflare + HTTPS (404 LiteSpeed)

Se **http://IP** funciona mas **https://domínio** mostra:

```text
404 Not Found
The resource requested could not be found on this server!
x-turbo-charged-by: LiteSpeed
```

**Causa:** DNS ainda passa pela **Cloudflare** (proxy laranja). O browser abre **HTTPS**. Com SSL mode **Full**, a Cloudflare liga na origem na porta **443** — onde ainda existe **LiteSpeed** (HostGator), não o Nginx da VPS (só configurado na **80** por enquanto).

| Teste | Resultado típico |
|-------|------------------|
| `http://IP` | ✅ Nginx → app |
| `http://aerorf.com.br` | ✅ Cloudflare → VPS:80 |
| `https://aerorf.com.br` | ❌ Cloudflare → origem:443 LiteSpeed |

### Correção rápida (Cloudflare Dashboard)

1. **SSL/TLS** → modo **Flexible** (visitante HTTPS, origem HTTP porta 80)  
   → `https://aerorf.com.br` passa a funcionar sem certificado na VPS.

2. **DNS** → registros A de `@`, `www`, `app`, `api` com **IP da VPS** (não IP de hospedagem compartilhada antiga).

### Correção definitiva

1. Deploy com **`run_certbot=true`** (Nginx passa a escutar **443** na VPS).  
2. Cloudflare **SSL/TLS** → **Full** (ou Full strict com cert válido na origem).  
3. Secrets: `APP_PUBLIC_URL`, `CORS_ORIGIN`, `COOKIE_SECURE=true` + redeploy.

Para Certbot HTTP-01 com proxy laranja: geralmente funciona na porta 80; se falhar, use **DNS only** (nuvem cinza) só durante o deploy com `run_certbot=true`.

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
