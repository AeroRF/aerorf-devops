-- Convites externos + política de histórico na transferência

ALTER TABLE aviation_transfers ADD COLUMN IF NOT EXISTS historico_policy JSONB DEFAULT '{}';

CREATE TABLE IF NOT EXISTS aviation_transfer_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id UUID NOT NULL REFERENCES aviation_transfers(id) ON DELETE CASCADE,
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  aircraft_id UUID NOT NULL REFERENCES aircraft(id) ON DELETE CASCADE,
  token VARCHAR(128) UNIQUE NOT NULL,
  destino_externo_nome VARCHAR(255),
  destino_externo_email VARCHAR(255),
  historico_policy JSONB NOT NULL DEFAULT '{}',
  expires_at TIMESTAMPTZ NOT NULL,
  accessed_at TIMESTAMPTZ,
  pdf_generated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aviation_transfer_invites_token ON aviation_transfer_invites(token);
CREATE INDEX IF NOT EXISTS idx_aviation_transfer_invites_transfer ON aviation_transfer_invites(transfer_id);

ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS reentrada_em TIMESTAMPTZ;
ALTER TABLE aircraft ADD COLUMN IF NOT EXISTS reentrada_motivo TEXT;
