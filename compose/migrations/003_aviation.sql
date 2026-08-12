-- Aviação — tabelas complementares (idempotente)
-- Run: psql $DATABASE_URL -f migrations/003_aviation.sql

ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS fabricante VARCHAR(100);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS operador_id UUID;
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS observacoes TEXT;
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

ALTER TABLE workorders ADD COLUMN IF NOT EXISTS numero_interno VARCHAR(50);
ALTER TABLE workorders ADD COLUMN IF NOT EXISTS tipo_execucao VARCHAR(50);
ALTER TABLE workorders ADD COLUMN IF NOT EXISTS mecanico VARCHAR(100);
ALTER TABLE workorders ADD COLUMN IF NOT EXISTS inspetor VARCHAR(100);
ALTER TABLE workorders ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

CREATE TABLE IF NOT EXISTS aviation_operators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  nome VARCHAR(255) NOT NULL,
  codigo VARCHAR(50),
  tipo VARCHAR(30) DEFAULT 'empresa',
  documento VARCHAR(30),
  status VARCHAR(30) DEFAULT 'ativo',
  observacao TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS aviation_pilots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  nome VARCHAR(255) NOT NULL,
  codigo VARCHAR(50),
  documento VARCHAR(30),
  licenca VARCHAR(50),
  validade_licenca DATE,
  status VARCHAR(30) DEFAULT 'ativo',
  observacao TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS aviation_components (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  aircraft_id UUID REFERENCES aircraft(id) ON DELETE SET NULL,
  pn VARCHAR(100),
  descricao TEXT,
  controle_por VARCHAR(20) DEFAULT 'HORAS',
  limite_horas NUMERIC(10, 2),
  usados_horas NUMERIC(10, 2) DEFAULT 0,
  limite_ciclos NUMERIC(10, 2),
  usados_ciclos NUMERIC(10, 2) DEFAULT 0,
  data_validade DATE,
  status VARCHAR(30) DEFAULT 'INSTALADO',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS aviation_hour_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  aircraft_id UUID NOT NULL REFERENCES aircraft(id) ON DELETE CASCADE,
  pilot_id UUID REFERENCES aviation_pilots(id) ON DELETE SET NULL,
  horas NUMERIC(10, 2) NOT NULL,
  ciclos NUMERIC(10, 2) DEFAULT 0,
  data_voo DATE,
  observacoes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS aviation_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  aircraft_id UUID NOT NULL REFERENCES aircraft(id) ON DELETE CASCADE,
  from_unidade_id UUID,
  to_empresa_id UUID NOT NULL REFERENCES empresas(id),
  to_unidade_id UUID NOT NULL REFERENCES unidades(id),
  motivo TEXT,
  data_transferencia DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE aviation_operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE aviation_pilots ENABLE ROW LEVEL SECURITY;
ALTER TABLE aviation_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE aviation_hour_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE aviation_transfers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_aviation_operators ON aviation_operators;
CREATE POLICY tenant_aviation_operators ON aviation_operators
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_aviation_pilots ON aviation_pilots;
CREATE POLICY tenant_aviation_pilots ON aviation_pilots
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_aviation_components ON aviation_components;
CREATE POLICY tenant_aviation_components ON aviation_components
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_aviation_hour_logs ON aviation_hour_logs;
CREATE POLICY tenant_aviation_hour_logs ON aviation_hour_logs
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_aviation_transfers ON aviation_transfers;
CREATE POLICY tenant_aviation_transfers ON aviation_transfers
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_aviation_operators_tenant ON aviation_operators(empresa_id, unidade_id);
CREATE INDEX IF NOT EXISTS idx_aviation_pilots_tenant ON aviation_pilots(empresa_id, unidade_id);
CREATE INDEX IF NOT EXISTS idx_aviation_components_aircraft ON aviation_components(aircraft_id);
CREATE INDEX IF NOT EXISTS idx_aviation_hour_logs_aircraft ON aviation_hour_logs(aircraft_id);
CREATE INDEX IF NOT EXISTS idx_aviation_transfers_aircraft ON aviation_transfers(aircraft_id);
