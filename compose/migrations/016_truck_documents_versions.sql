-- Versionamento documental caminhões + vínculo cota storage

ALTER TABLE truck_documents ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE truck_documents ADD COLUMN IF NOT EXISTS root_id UUID;
ALTER TABLE truck_documents ADD COLUMN IF NOT EXISTS version INT DEFAULT 1;
ALTER TABLE truck_documents ADD COLUMN IF NOT EXISTS is_current BOOLEAN DEFAULT true;
ALTER TABLE truck_documents ADD COLUMN IF NOT EXISTS size_bytes BIGINT DEFAULT 0;
ALTER TABLE truck_documents ADD COLUMN IF NOT EXISTS content_type VARCHAR(100);
ALTER TABLE truck_documents ADD COLUMN IF NOT EXISTS retention_type VARCHAR(20) DEFAULT 'periodic';
ALTER TABLE truck_documents ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id);

UPDATE truck_documents SET root_id = id WHERE root_id IS NULL;
UPDATE truck_documents SET version = 1 WHERE version IS NULL;
UPDATE truck_documents SET is_current = true WHERE is_current IS NULL;
UPDATE truck_documents SET is_active = true WHERE is_active IS NULL;

ALTER TABLE documents ADD COLUMN IF NOT EXISTS truck_document_id UUID REFERENCES truck_documents(id);

CREATE INDEX IF NOT EXISTS idx_truck_documents_root ON truck_documents(root_id);
CREATE INDEX IF NOT EXISTS idx_truck_documents_current ON truck_documents(caminhao_placa, is_current)
  WHERE is_current = true AND is_active = true;
CREATE INDEX IF NOT EXISTS idx_documents_truck ON documents(truck_document_id);
