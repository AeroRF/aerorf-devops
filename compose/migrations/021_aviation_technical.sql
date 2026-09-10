-- Proposta adicional v2.1 — perfil técnico, multi-controle, versão de voo, fechamento
-- Idempotente. Estende tabelas existentes (não cria célula como componente).

-- ——— Aeronave = célula ———
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS numero_serie VARCHAR(100);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS ciclos_totais NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS baseline_horas NUMERIC(10, 2);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS baseline_ciclos NUMERIC(10, 2);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS baseline_data DATE;
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS manual_referencia VARCHAR(255);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS manual_revisao VARCHAR(100);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS categoria VARCHAR(50);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS propulsao VARCHAR(50);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS perfil_operacao VARCHAR(30);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS perfil_tecnico VARCHAR(50);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS pousos_totais NUMERIC(10, 2) DEFAULT 0;

-- ——— Componentes: condição + contadores simultâneos (modelo v3) ———
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tipo VARCHAR(30) DEFAULT 'OUTRO';
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS grupo VARCHAR(80);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS fabricante VARCHAR(120);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS modelo VARCHAR(120);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS posicao VARCHAR(120);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS condicao VARCHAR(20) DEFAULT 'USADO';
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tsn NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tso NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tso_novo BOOLEAN DEFAULT false;
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS csn NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS cso NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS pousos NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS limite_pousos NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tlv_horas NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tlv_ciclos NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tlv_pousos NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tlv_calendario DATE;
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tbo_horas NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tbo_ciclos NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tbo_pousos NUMERIC(10, 2);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tbo_calendario DATE;
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS fator_vida VARCHAR(80);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS fator_unidade VARCHAR(40);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS referencia_tecnica VARCHAR(255);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS controles JSONB DEFAULT '{}';
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS overhaul_em TIMESTAMPTZ;

UPDATE aviation_components
SET tsn = COALESCE(tsn, usados_horas, 0),
    tso = COALESCE(tso, usados_horas, 0),
    csn = COALESCE(csn, usados_ciclos, 0),
    cso = COALESCE(cso, usados_ciclos, 0),
    tso_novo = COALESCE(tso_novo, false),
    condicao = COALESCE(NULLIF(condicao, ''), 'USADO'),
    tipo = COALESCE(NULLIF(tipo, ''), 'OUTRO'),
    controles = CASE
      WHEN controles IS NULL OR controles = '{}'::jsonb THEN
        jsonb_build_object(
          'horas', UPPER(COALESCE(controle_por, '')) = 'HORAS',
          'ciclos', UPPER(COALESCE(controle_por, '')) = 'CICLOS',
          'calendario', UPPER(COALESCE(controle_por, '')) = 'DATA',
          'onCondition', UPPER(COALESCE(controle_por, '')) IN ('ON_CONDITION', 'OC', 'O/C'),
          'pousos', false
        )
      ELSE controles
    END
WHERE tsn IS NULL OR controles IS NULL OR controles = '{}'::jsonb;

-- ——— Registro de voo: campos + versionamento ———
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS horas_delta NUMERIC(10, 2);
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS origem VARCHAR(120);
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS destino VARCHAR(120);
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS partida VARCHAR(10);
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS corte VARCHAR(10);
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS pousos NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS partidas_motor NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS tipo_operacao VARCHAR(20);
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS forma_registro VARCHAR(20);
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS natureza VARCHAR(120);
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS root_id UUID;
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS version INT DEFAULT 1;
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS is_current BOOLEAN DEFAULT true;
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS retificado_por UUID REFERENCES users(id);
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS retificado_em TIMESTAMPTZ;
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS motivo_retificacao TEXT;

UPDATE aviation_hour_logs
SET root_id = COALESCE(root_id, id),
    version = COALESCE(version, 1),
    is_current = COALESCE(is_current, true),
    horas_delta = COALESCE(
      horas_delta,
      NULLIF(metadata->>'horasVoo', '')::NUMERIC,
      0
    ),
    partida = COALESCE(partida, NULLIF(metadata->>'partida', ''), NULLIF(metadata->>'decolagem', '')),
    corte = COALESCE(corte, NULLIF(metadata->>'corte', ''), NULLIF(metadata->>'pouso', '')),
    origem = COALESCE(origem, NULLIF(metadata->>'origem', ''), NULLIF(metadata->>'base', '')),
    destino = COALESCE(destino, NULLIF(metadata->>'destino', '')),
    natureza = COALESCE(natureza, NULLIF(metadata->>'natureza', ''))
WHERE root_id IS NULL OR horas_delta IS NULL;

CREATE INDEX IF NOT EXISTS idx_hour_logs_current ON aviation_hour_logs(aircraft_id, data_voo DESC)
  WHERE COALESCE(is_current, true) = true;
CREATE INDEX IF NOT EXISTS idx_hour_logs_root ON aviation_hour_logs(root_id, version);

-- ——— Fechamento mensal (competência) ———
CREATE TABLE IF NOT EXISTS aviation_period_closings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  aircraft_id UUID NOT NULL REFERENCES aircraft(id) ON DELETE CASCADE,
  competencia DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'FECHADO',
  saldo_inicial_horas NUMERIC(10, 2) DEFAULT 0,
  movimentos_horas NUMERIC(10, 2) DEFAULT 0,
  saldo_final_horas NUMERIC(10, 2) DEFAULT 0,
  saldo_inicial_ciclos NUMERIC(10, 2) DEFAULT 0,
  movimentos_ciclos NUMERIC(10, 2) DEFAULT 0,
  saldo_final_ciclos NUMERIC(10, 2) DEFAULT 0,
  snapshot JSONB DEFAULT '{}',
  fechado_por UUID REFERENCES users(id),
  fechado_em TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (empresa_id, aircraft_id, competencia)
);

CREATE TABLE IF NOT EXISTS aviation_period_exceptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  closing_id UUID NOT NULL REFERENCES aviation_period_closings(id) ON DELETE CASCADE,
  hour_log_id UUID REFERENCES aviation_hour_logs(id) ON DELETE SET NULL,
  user_id UUID REFERENCES users(id),
  motivo TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE aviation_period_closings ENABLE ROW LEVEL SECURITY;
ALTER TABLE aviation_period_exceptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_aviation_period_closings ON aviation_period_closings;
CREATE POLICY tenant_aviation_period_closings ON aviation_period_closings
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_aviation_period_exceptions ON aviation_period_exceptions;
CREATE POLICY tenant_aviation_period_exceptions ON aviation_period_exceptions
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_period_closings_aircraft ON aviation_period_closings(aircraft_id, competencia DESC);
CREATE INDEX IF NOT EXISTS idx_period_exceptions_closing ON aviation_period_exceptions(closing_id);
