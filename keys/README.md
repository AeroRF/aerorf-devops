# Chaves JWT de desenvolvimento

Geradas automaticamente por `./devops/aerorf-devops.sh install dev`.

```bash
openssl genrsa -out jwt-private.pem 2048
openssl rsa -in jwt-private.pem -pubout -out jwt-public.pem
```

**Nunca commite chaves de produção.**
