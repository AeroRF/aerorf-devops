-- Metadados de unidade (externalId legado)
ALTER TABLE unidades ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';
