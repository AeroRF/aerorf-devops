# MinIO — políticas e estrutura de buckets (complemento arquitetura §7)

## Estrutura de objetos

```text
aerorf-prod/
  tenants/
    {empresaId}/
      unit_{unidadeId}/
        documents/
        aircraft/
        stock/
        fuel/
        telemetry/
```

## Dev

- Bucket `aerorf-dev` criado por `minio-init` no compose
- Versionamento habilitado via `mc version enable`

## Prod

- Servidor MinIO dedicado (fora do cluster de apps)
- IAM policies por prefixo `tenants/{empresaId}/`
- API valida tenant antes de presigned URL (`packages/business-rules`)

## Init script (dev)

Ver `docker-compose.dev.yml` serviço `minio-init`.
