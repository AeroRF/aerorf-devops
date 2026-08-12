-- Convites de usuário — ativação de conta (senha) em 24h

ALTER TABLE users ADD COLUMN IF NOT EXISTS pending_activation BOOLEAN DEFAULT false;

UPDATE users SET pending_activation = false WHERE pending_activation IS NULL;

CREATE TABLE IF NOT EXISTS user_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR(64) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  invited_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_invites_token ON user_invites(token);
CREATE INDEX IF NOT EXISTS idx_user_invites_user ON user_invites(user_id, created_at DESC);
