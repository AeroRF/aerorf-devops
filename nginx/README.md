# Mapa de domínios AeroRF (VPS / produção)

Reverse proxy **Nginx** na VPS. Containers Docker escutam em `127.0.0.1` (não expor portas publicamente no firewall).

## HostGator VPS (AlmaLinux + LiteSpeed)

VPS **exclusiva AeroRF**: LiteSpeed vem na porta 80 por padrão. **Pare o LiteSpeed** e use Nginx.

Setup automatizado (na VPS, como root):

```bash
# Com repo já clonado pelo deploy:
bash ~/aerorf/aerorf-devops/nginx/setup-vps-nginx.sh

# SSL após DNS propagado:
bash ~/aerorf/aerorf-devops/nginx/setup-vps-nginx.sh --certbot
```

O script:
1. Para e desabilita **LiteSpeed** (`lsws`)
2. Instala **Nginx** + Certbot (dnf/epel)
3. Copia `aerorf.conf` → `/etc/nginx/conf.d/aerorf.conf`
4. SELinux `httpd_can_network_connect` + firewalld 80/443
5. Sobe Nginx e faz smoke test

Manual (se preferir):

```bash
sudo systemctl stop lsws || sudo /usr/local/lsws/bin/lswsctrl stop
sudo systemctl disable lsws
sudo ss -tlnp | grep ':80 '   # deve estar vazio
sudo systemctl start nginx
```

**Não use `apt`** — HostGator BR usa AlmaLinux/RHEL (`dnf` / `yum`).

Config Nginx: `/etc/nginx/conf.d/aerorf.conf` (não `sites-available`).

---

## DNS (registros A → IP da VPS)

| Host | Uso |
|------|-----|
| `@` / `www` | Landing de vendas (`aerorf.com.br`) |
| `app` | SaaS Next.js |
| `api` | API REST |
| `grafana` | Grafana (restrito) |
| `storage` | MinIO S3 API (restrito) |
| `console.storage` | MinIO Console (restrito) |
| `prometheus` | Prometheus (opcional, restrito) |

---

## Variáveis de ambiente (apps)

Após HTTPS, redeploy com:

```env
CORS_ORIGIN=https://app.aerorf.com.br
APP_PUBLIC_URL=https://app.aerorf.com.br
NEXT_PUBLIC_APP_URL=https://app.aerorf.com.br
COOKIE_SECURE=true
```

Landing em `aerorf.com.br` usa o HTML legado (`aerorf-landing-premium-v8.html`). Middleware Next.js roteia por `Host`:
- `aerorf.com.br` / `www` → rewrite de `/` para o HTML estático
- `app.aerorf.com.br` → `/login` no `/`

---

## Certbot (HTTPS)

```bash
sudo certbot --nginx \
  -d aerorf.com.br \
  -d www.aerorf.com.br \
  -d app.aerorf.com.br \
  -d api.aerorf.com.br
```

Renovação: `sudo certbot renew --dry-run`

---

## Segurança

- Containers expõem portas só em `127.0.0.1` (compose VPS)
- Internet acessa só **80/443** via Nginx
- Proteja `grafana`, `storage`, `prometheus` (IP allowlist ou basic auth no Nginx)

---

## Testes

```bash
curl -s http://127.0.0.1:3000/api/health
curl -s http://127.0.0.1:4000/api/v1/health
curl -I -H 'Host: aerorf.com.br' http://127.0.0.1/
curl -I -H 'Host: app.aerorf.com.br' http://127.0.0.1/login
```
