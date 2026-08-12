-- Versionamento documental + bytes reais para cota de storage

ALTER TABLE aviation_documents ADD COLUMN IF NOT EXISTS root_id UUID;
ALTER TABLE aviation_documents ADD COLUMN IF NOT EXISTS version INT DEFAULT 1;
ALTER TABLE aviation_documents ADD COLUMN IF NOT EXISTS is_current BOOLEAN DEFAULT true;
ALTER TABLE aviation_documents ADD COLUMN IF NOT EXISTS size_bytes BIGINT DEFAULT 0;
ALTER TABLE aviation_documents ADD COLUMN IF NOT EXISTS content_type VARCHAR(100);
ALTER TABLE aviation_documents ADD COLUMN IF NOT EXISTS retention_type VARCHAR(20) DEFAULT 'periodic';
ALTER TABLE aviation_documents ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id);

UPDATE aviation_documents SET root_id = id WHERE root_id IS NULL;
UPDATE aviation_documents SET version = 1 WHERE version IS NULL;
UPDATE aviation_documents SET is_current = true WHERE is_current IS NULL;

ALTER TABLE documents ADD COLUMN IF NOT EXISTS size_bytes BIGINT DEFAULT 0;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS content_type VARCHAR(100);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES documents(id);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS aviation_document_id UUID REFERENCES aviation_documents(id);

CREATE INDEX IF NOT EXISTS idx_aviation_documents_root ON aviation_documents(root_id);
CREATE INDEX IF NOT EXISTS idx_aviation_documents_current ON aviation_documents(aircraft_id, is_current)
  WHERE is_current = true AND is_active = true;
CREATE INDEX IF NOT EXISTS idx_documents_aviation ON documents(aviation_document_id);
