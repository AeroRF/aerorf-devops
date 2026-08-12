-- Caminhões — frota terrestre (idempotente)

CREATE TABLE IF NOT EXISTS trucks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  placa VARCHAR(20) NOT NULL,
  modelo VARCHAR(100),
  odometro INTEGER DEFAULT 0,
  capacidade_tanque_litros NUMERIC(12, 2),
  combustivel_permitido JSONB DEFAULT '["DIESEL"]',
  tanque_operacional JSONB DEFAULT '{}',
  obs TEXT,
  situacao VARCHAR(30) DEFAULT 'ATIVO',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (empresa_id, unidade_id, placa)
);

CREATE TABLE IF NOT EXISTS truck_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  caminhao_placa VARCHAR(20) NOT NULL,
  tipo VARCHAR(50) NOT NULL,
  nome VARCHAR(255) NOT NULL,
  validade DATE,
  alerta_dias INTEGER DEFAULT 30,
  obs TEXT,
  file_name VARCHAR(255),
  storage_key TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS truck_maintenance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  placa VARCHAR(20) NOT NULL,
  data DATE,
  odometro INTEGER DEFAULT 0,
  servico VARCHAR(255),
  valor_servico NUMERIC(12, 2) DEFAULT 0,
  valor_pecas NUMERIC(12, 2) DEFAULT 0,
  descricao TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE trucks ENABLE ROW LEVEL SECURITY;
ALTER TABLE truck_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE truck_maintenance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_trucks ON trucks;
CREATE POLICY tenant_trucks ON trucks
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_truck_documents ON truck_documents;
CREATE POLICY tenant_truck_documents ON truck_documents
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_truck_maintenance ON truck_maintenance;
CREATE POLICY tenant_truck_maintenance ON truck_maintenance
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_trucks_tenant ON trucks(empresa_id, unidade_id);
CREATE INDEX IF NOT EXISTS idx_truck_documents_placa ON truck_documents(caminhao_placa);
CREATE INDEX IF NOT EXISTS idx_truck_maintenance_placa ON truck_maintenance(placa);
