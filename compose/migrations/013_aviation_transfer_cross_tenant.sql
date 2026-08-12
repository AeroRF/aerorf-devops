-- Transferência cross-tenant: status, auditoria, acesso multi-empresa e RLS bidirecional

ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS status VARCHAR(40) DEFAULT 'concluida';
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS tipo VARCHAR(40) DEFAULT 'transferencia';
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS comprador_usa_aerorf BOOLEAN DEFAULT true;
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS from_empresa_id UUID REFERENCES empresas(id);
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS destino_externo_nome VARCHAR(255);
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS etapa_erp VARCHAR(80);
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS observacao TEXT;
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS criado_por UUID;
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS criado_por_email VARCHAR(255);
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS aceito_por UUID;
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS aceito_por_email VARCHAR(255);
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS recusado_por UUID;
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS recusado_por_email VARCHAR(255);
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS data_aceite TIMESTAMPTZ;
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS data_recusa TIMESTAMPTZ;
ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS motivo_recusa TEXT;

UPDATE aviation_transfers SET from_empresa_id = empresa_id WHERE from_empresa_id IS NULL;
UPDATE aviation_transfers SET status = 'concluida' WHERE status IS NULL OR status = '';

ALTER TABLE aviation_transfers ALTER COLUMN to_empresa_id DROP NOT NULL;
ALTER TABLE aviation_transfers ALTER COLUMN to_unidade_id DROP NOT NULL;

ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS status_transferencia VARCHAR(40);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS transferencia_pendente_to_empresa_id UUID REFERENCES empresas(id);
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS ultima_transferencia_id UUID;

CREATE TABLE IF NOT EXISTS aircraft_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aircraft_id UUID NOT NULL REFERENCES aircraft(id) ON DELETE CASCADE,
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  tipo_acesso VARCHAR(30) DEFAULT 'operador',
  ativo BOOLEAN DEFAULT true,
  origem VARCHAR(80),
  transferencia_id UUID REFERENCES aviation_transfers(id) ON DELETE SET NULL,
  criado_em TIMESTAMPTZ DEFAULT NOW(),
  desativado_em TIMESTAMPTZ,
  motivo_desativacao TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_aircraft_access_unique_active
  ON aircraft_access(aircraft_id, empresa_id, tipo_acesso)
  WHERE ativo = true;

ALTER TABLE aircraft_access ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_aircraft_access ON aircraft_access;
CREATE POLICY tenant_aircraft_access ON aircraft_access
  FOR ALL USING (
    empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID
    OR aircraft_id IN (
      SELECT id FROM aircraft
      WHERE empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID
    )
  );

DROP POLICY IF EXISTS tenant_aviation_transfers ON aviation_transfers;
CREATE POLICY tenant_aviation_transfers_select ON aviation_transfers
  FOR SELECT USING (
    empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID
    OR to_empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID
  );
CREATE POLICY tenant_aviation_transfers_insert ON aviation_transfers
  FOR INSERT WITH CHECK (
    empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID
  );
CREATE POLICY tenant_aviation_transfers_update ON aviation_transfers
  FOR UPDATE USING (
    empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID
    OR to_empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID
  );

CREATE INDEX IF NOT EXISTS idx_aviation_transfers_status ON aviation_transfers(status);
CREATE INDEX IF NOT EXISTS idx_aviation_transfers_to_empresa ON aviation_transfers(to_empresa_id, status);
CREATE INDEX IF NOT EXISTS idx_aircraft_access_aircraft ON aircraft_access(aircraft_id);
CREATE INDEX IF NOT EXISTS idx_aircraft_transfer_pending ON aircraft(transferencia_pendente_to_empresa_id)
  WHERE status_transferencia = 'pendente_aceite';

-- Acesso inicial para aeronaves existentes (empresa titular)
INSERT INTO aircraft_access (aircraft_id, empresa_id, tipo_acesso, ativo, origem)
SELECT a.id, a.empresa_id, 'operador', true, 'migracao_inicial'
FROM aircraft a
WHERE NOT EXISTS (
  SELECT 1 FROM aircraft_access aa
  WHERE aa.aircraft_id = a.id AND aa.empresa_id = a.empresa_id AND aa.ativo = true
);
