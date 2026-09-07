-- Perfis customizáveis por empresa
-- Cada empresa cria seus próprios perfis com módulos específicos
-- Não há perfis default - o administrador deve criar os perfis da empresa

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  nome VARCHAR(100) NOT NULL,
  descricao TEXT,
  modules JSONB NOT NULL DEFAULT '["dashboard"]'::jsonb,
  actions JSONB NOT NULL DEFAULT '["read"]'::jsonb,
  ativo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(empresa_id, nome)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_profiles_empresa ON profiles(empresa_id);
CREATE INDEX IF NOT EXISTS idx_profiles_ativo ON profiles(ativo) WHERE ativo = true;

-- Adicionar coluna profile_id na tabela users
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_id UUID REFERENCES profiles(id);
CREATE INDEX IF NOT EXISTS idx_users_profile ON users(profile_id);

-- Comentários
COMMENT ON TABLE profiles IS 'Perfis de acesso customizáveis por empresa';
COMMENT ON COLUMN profiles.empresa_id IS 'Empresa dona do perfil (obrigatório)';
COMMENT ON COLUMN profiles.modules IS 'Array de módulos permitidos';
COMMENT ON COLUMN profiles.actions IS 'Array de ações permitidas (read, create, update, delete, admin)';
