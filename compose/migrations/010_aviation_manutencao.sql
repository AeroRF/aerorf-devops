-- Manutenção aviação — histórico R&R e histórico técnico

CREATE TABLE IF NOT EXISTS aviation_rr_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  aircraft_id UUID REFERENCES aircraft(id) ON DELETE SET NULL,
  component_id UUID,
  acao VARCHAR(30) NOT NULL,
  origem VARCHAR(30),
  responsavel VARCHAR(255),
  pn VARCHAR(100),
  sn VARCHAR(100),
  descricao TEXT,
  tsn NUMERIC(10, 2),
  tso NUMERIC(10, 2),
  data_validade DATE,
  observacao TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS aviation_maintenance_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  aircraft_id UUID REFERENCES aircraft(id) ON DELETE SET NULL,
  workorder_id UUID REFERENCES workorders(id) ON DELETE SET NULL,
  mensagem TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE aviation_rr_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE aviation_maintenance_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_aviation_rr_history ON aviation_rr_history;
CREATE POLICY tenant_aviation_rr_history ON aviation_rr_history
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_aviation_maintenance_history ON aviation_maintenance_history;
CREATE POLICY tenant_aviation_maintenance_history ON aviation_maintenance_history
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_aviation_rr_history_aircraft ON aviation_rr_history(aircraft_id);
CREATE INDEX IF NOT EXISTS idx_aviation_maintenance_history_aircraft ON aviation_maintenance_history(aircraft_id);
