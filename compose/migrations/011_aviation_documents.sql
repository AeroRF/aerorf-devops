-- Documentos de aviação — conformidade por aeronave

CREATE TABLE IF NOT EXISTS aviation_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  aircraft_id UUID NOT NULL REFERENCES aircraft(id) ON DELETE CASCADE,
  categoria VARCHAR(100) NOT NULL,
  nome VARCHAR(255) NOT NULL,
  validade DATE,
  alerta_dias INTEGER DEFAULT 30,
  obs TEXT,
  file_name VARCHAR(255),
  storage_key TEXT,
  is_active BOOLEAN DEFAULT true,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE aviation_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_aviation_documents ON aviation_documents;
CREATE POLICY tenant_aviation_documents ON aviation_documents
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_aviation_documents_aircraft ON aviation_documents(aircraft_id);
CREATE INDEX IF NOT EXISTS idx_aviation_documents_unidade ON aviation_documents(unidade_id);
