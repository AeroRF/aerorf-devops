-- Telemetria E4 — arquivo bruto MinIO + vínculo cota (documents)

ALTER TABLE telemetry_missions ADD COLUMN IF NOT EXISTS file_name VARCHAR(255);
ALTER TABLE telemetry_missions ADD COLUMN IF NOT EXISTS storage_key TEXT;
ALTER TABLE telemetry_missions ADD COLUMN IF NOT EXISTS size_bytes BIGINT DEFAULT 0;
ALTER TABLE telemetry_missions ADD COLUMN IF NOT EXISTS content_type VARCHAR(100);
ALTER TABLE telemetry_missions ADD COLUMN IF NOT EXISTS raw_file_deleted_at TIMESTAMPTZ;

ALTER TABLE documents ADD COLUMN IF NOT EXISTS telemetry_mission_id UUID REFERENCES telemetry_missions(id);

CREATE INDEX IF NOT EXISTS idx_telemetry_missions_storage ON telemetry_missions(empresa_id)
  WHERE storage_key IS NOT NULL AND raw_file_deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_documents_telemetry ON documents(telemetry_mission_id);
