-- Telemetria — missões e preços aprendidos (idempotente)

CREATE TABLE IF NOT EXISTS telemetry_missions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  external_id VARCHAR(50) NOT NULL,
  aircraft VARCHAR(50) NOT NULL,
  operacao VARCHAR(255),
  preco_ha NUMERIC(14, 4) DEFAULT 0,
  start_ts TIMESTAMPTZ NOT NULL,
  end_ts TIMESTAMPTZ NOT NULL,
  mission_date DATE,
  area_ha NUMERIC(14, 4) DEFAULT 0,
  litros_aplicados NUMERIC(14, 4) DEFAULT 0,
  l_ha NUMERIC(14, 4) DEFAULT 0,
  ha_h NUMERIC(14, 4) DEFAULT 0,
  dur_h NUMERIC(14, 4) DEFAULT 0,
  app_h NUMERIC(14, 4) DEFAULT 0,
  comb_l NUMERIC(14, 4) DEFAULT 0,
  cm NUMERIC(14, 6) DEFAULT 0,
  l_h NUMERIC(14, 4) DEFAULT 0,
  r_ha NUMERIC(14, 4) DEFAULT 0,
  custo_combustivel_total NUMERIC(14, 2) DEFAULT 0,
  receita_total NUMERIC(14, 2) DEFAULT 0,
  margem_total NUMERIC(14, 2) DEFAULT 0,
  margem_por_ha NUMERIC(14, 2) DEFAULT 0,
  piloto VARCHAR(255),
  payload JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS telemetry_learned_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  operacao VARCHAR(255) NOT NULL,
  preco_ha NUMERIC(14, 4) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (empresa_id, operacao)
);

ALTER TABLE telemetry_missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_learned_prices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_telemetry_missions ON telemetry_missions;
CREATE POLICY tenant_telemetry_missions ON telemetry_missions
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_telemetry_learned_prices ON telemetry_learned_prices;
CREATE POLICY tenant_telemetry_learned_prices ON telemetry_learned_prices
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_telemetry_missions_ts ON telemetry_missions(empresa_id, start_ts DESC);
