# Mapa de domínios AeroRF (VPS / produção)

Reverse proxy **Nginx** na VPS. Containers Docker escutam em `127.0.0.1` (não expor portas publicamente no firewall).

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

## Variáveis de ambiente (apps)

```env
NEXT_PUBLIC_APP_URL=https://app.aerorf.com.br
NEXT_PUBLIC_API_URL=https://api.aerorf.com.br/api/v1
CORS_ORIGIN=https://app.aerorf.com.br
APP_PUBLIC_URL=https://app.aerorf.com.br
```

Landing em `aerorf.com.br` usa o HTML legado (`public/aerorf-landing-premium-v8.html`), sem backend. O middleware Next.js roteia por `Host`:
- `aerorf.com.br` / `www` → rewrite de `/` para o HTML estático
- `app.aerorf.com.br` → `/login` no `/`

## Instalação na VPS

1. Copie `aerorf.conf` para `/etc/nginx/sites-available/aerorf`
2. Ajuste `server_name` e caminhos de certificado Let's Encrypt
3. `sudo ln -s /etc/nginx/sites-available/aerorf /etc/nginx/sites-enabled/`
4. `sudo certbot --nginx -d aerorf.com.br -d www.aerorf.com.br -d app.aerorf.com.br -d api.aerorf.com.br ...`
5. `sudo nginx -t && sudo systemctl reload nginx`
6. Feche no firewall as portas `3000`, `4000`, `3001`, etc. (só 80/443 públicos)

## Teste local da landing

```bash
# Acesse o HTML legado diretamente:
# http://localhost:3000/aerorf-landing-premium-v8.html

# Simular domínio de marketing (rewrite / → HTML):
NEXT_PUBLIC_SITE_MODE=marketing npm run dev --workspace=@aerorf/web
```

## Orçamento (formulário landing)

Sem backend: solicitações ficam em `localStorage` (`aerorf_orcamentos_landing`) no navegador do visitante, igual ao HTML legado. Integração com e-mail/CRM pode ser Fase 2.
