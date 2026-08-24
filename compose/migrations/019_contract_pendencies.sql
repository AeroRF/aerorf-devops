-- Contrato 115h — docs piloto/mecânico, movimentação componentes, locale

ALTER TABLE users ADD COLUMN IF NOT EXISTS locale VARCHAR(5) DEFAULT 'pt';
ALTER TABLE empresas ADD COLUMN IF NOT EXISTS default_locale VARCHAR(5) DEFAULT 'pt';

CREATE TABLE IF NOT EXISTS aviation_mechanics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  nome VARCHAR(255) NOT NULL,
  codigo VARCHAR(50),
  documento VARCHAR(30),
  registro VARCHAR(50),
  status VARCHAR(30) DEFAULT 'ativo',
  observacao TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS aviation_pilot_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  pilot_id UUID NOT NULL REFERENCES aviation_pilots(id) ON DELETE CASCADE,
  tipo VARCHAR(100) NOT NULL,
  nome VARCHAR(255) NOT NULL,
  validade DATE,
  alerta_dias INTEGER DEFAULT 30,
  obs TEXT,
  file_name VARCHAR(255),
  storage_key TEXT,
  root_id UUID,
  version INT DEFAULT 1,
  is_current BOOLEAN DEFAULT true,
  size_bytes BIGINT DEFAULT 0,
  content_type VARCHAR(100),
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS aviation_mechanic_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  mechanic_id UUID NOT NULL REFERENCES aviation_mechanics(id) ON DELETE CASCADE,
  tipo VARCHAR(100) NOT NULL,
  nome VARCHAR(255) NOT NULL,
  validade DATE,
  alerta_dias INTEGER DEFAULT 30,
  obs TEXT,
  file_name VARCHAR(255),
  storage_key TEXT,
  root_id UUID,
  version INT DEFAULT 1,
  is_current BOOLEAN DEFAULT true,
  size_bytes BIGINT DEFAULT 0,
  content_type VARCHAR(100),
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS aviation_component_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  component_id UUID NOT NULL REFERENCES aviation_components(id) ON DELETE CASCADE,
  from_aircraft_id UUID REFERENCES aircraft(id) ON DELETE SET NULL,
  to_aircraft_id UUID REFERENCES aircraft(id) ON DELETE SET NULL,
  retirada_workorder_id UUID REFERENCES workorders(id) ON DELETE SET NULL,
  instalacao_workorder_id UUID REFERENCES workorders(id) ON DELETE SET NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'EM_TRANSITO',
  horas_retirada NUMERIC(10, 2),
  ciclos_retirada NUMERIC(10, 2),
  horas_instalacao NUMERIC(10, 2),
  ciclos_instalacao NUMERIC(10, 2),
  motivo TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE documents ADD COLUMN IF NOT EXISTS pilot_document_id UUID REFERENCES aviation_pilot_documents(id);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS mechanic_document_id UUID REFERENCES aviation_mechanic_documents(id);

UPDATE aviation_pilot_documents SET root_id = id WHERE root_id IS NULL;
UPDATE aviation_mechanic_documents SET root_id = id WHERE root_id IS NULL;

ALTER TABLE aviation_mechanics ENABLE ROW LEVEL SECURITY;
ALTER TABLE aviation_pilot_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE aviation_mechanic_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE aviation_component_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_aviation_mechanics ON aviation_mechanics;
CREATE POLICY tenant_aviation_mechanics ON aviation_mechanics
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_aviation_pilot_documents ON aviation_pilot_documents;
CREATE POLICY tenant_aviation_pilot_documents ON aviation_pilot_documents
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_aviation_mechanic_documents ON aviation_mechanic_documents;
CREATE POLICY tenant_aviation_mechanic_documents ON aviation_mechanic_documents
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_aviation_component_movements ON aviation_component_movements;
CREATE POLICY tenant_aviation_component_movements ON aviation_component_movements
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_aviation_mechanics_tenant ON aviation_mechanics(empresa_id, unidade_id);
CREATE INDEX IF NOT EXISTS idx_pilot_documents_pilot ON aviation_pilot_documents(pilot_id, is_current)
  WHERE is_current = true AND is_active = true;
CREATE INDEX IF NOT EXISTS idx_mechanic_documents_mechanic ON aviation_mechanic_documents(mechanic_id, is_current)
  WHERE is_current = true AND is_active = true;
CREATE INDEX IF NOT EXISTS idx_component_movements_status ON aviation_component_movements(unidade_id, status);
