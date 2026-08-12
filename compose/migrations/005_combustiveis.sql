-- Combustíveis — tanques, movimentos e terceiros (idempotente)

CREATE TABLE IF NOT EXISTS fuel_settings (
  empresa_id UUID PRIMARY KEY REFERENCES empresas(id) ON DELETE CASCADE,
  tipos JSONB DEFAULT '["JET A-1","AVGAS","DIESEL S10","ETANOL","GASOLINA"]',
  lot_config JSONB DEFAULT '{"seq":{},"pattern":"{EMP}-{UNI}-{PROD}-{YYYYMMDD}-{SEQ4}"}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fuel_tanks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  external_id VARCHAR(50) NOT NULL,
  nome VARCHAR(255) NOT NULL,
  tipo_combustivel VARCHAR(50) NOT NULL,
  capacidade_litros NUMERIC(14, 2) DEFAULT 0,
  alerta_minimo_litros NUMERIC(14, 2) DEFAULT 0,
  saldo_inicial NUMERIC(14, 2) DEFAULT 0,
  saldo_atual NUMERIC(14, 2) DEFAULT 0,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (empresa_id, unidade_id, external_id)
);

CREATE TABLE IF NOT EXISTS fuel_third_parties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  external_id VARCHAR(50),
  nome VARCHAR(255) NOT NULL,
  doc_numero VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fuel_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  produto VARCHAR(50) NOT NULL,
  tipo_mov VARCHAR(30) NOT NULL,
  quantidade_litros NUMERIC(14, 2) NOT NULL,
  origem JSONB DEFAULT '{}',
  destino JSONB DEFAULT '{}',
  custos JSONB,
  lote JSONB,
  rastreabilidade JSONB,
  km_obrigatorio JSONB,
  operador JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE fuel_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE fuel_tanks ENABLE ROW LEVEL SECURITY;
ALTER TABLE fuel_third_parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE fuel_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_fuel_settings ON fuel_settings;
CREATE POLICY tenant_fuel_settings ON fuel_settings
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_fuel_tanks ON fuel_tanks;
CREATE POLICY tenant_fuel_tanks ON fuel_tanks
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_fuel_third_parties ON fuel_third_parties;
CREATE POLICY tenant_fuel_third_parties ON fuel_third_parties
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_fuel_movements ON fuel_movements;
CREATE POLICY tenant_fuel_movements ON fuel_movements
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_fuel_tanks_tenant ON fuel_tanks(empresa_id, unidade_id);
CREATE INDEX IF NOT EXISTS idx_fuel_movements_ts ON fuel_movements(empresa_id, ts DESC);
