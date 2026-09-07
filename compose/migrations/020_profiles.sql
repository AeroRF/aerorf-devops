-- Perfis customizáveis por empresa
-- Cada empresa pode criar seus próprios perfis com módulos específicos

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID REFERENCES empresas(id) ON DELETE CASCADE,
  nome VARCHAR(100) NOT NULL,
  descricao TEXT,
  modules JSONB NOT NULL DEFAULT '["dashboard"]'::jsonb,
  actions JSONB NOT NULL DEFAULT '["read"]'::jsonb,
  is_system BOOLEAN NOT NULL DEFAULT false,
  ativo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(empresa_id, nome)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_profiles_empresa ON profiles(empresa_id);
CREATE INDEX IF NOT EXISTS idx_profiles_ativo ON profiles(ativo) WHERE ativo = true;

-- Perfis padrão do sistema (empresa_id = NULL significa global)
INSERT INTO profiles (id, empresa_id, nome, descricao, modules, actions, is_system) VALUES
  ('00000000-0000-0000-0000-000000000001', NULL, 'Administrador Master', 
   'Acesso total ao sistema, todas as empresas e módulos',
   '["dashboard", "aviacao", "caminhoes", "combustiveis", "estoque", "telemetria", "manutencao", "documentos", "relatorios", "empresas", "usuarios"]'::jsonb,
   '["read", "create", "update", "delete", "admin"]'::jsonb,
   true),
  ('00000000-0000-0000-0000-000000000002', NULL, 'Administrador Empresa',
   'Gerencia usuários e operações da empresa',
   '["dashboard", "aviacao", "caminhoes", "combustiveis", "estoque", "telemetria", "manutencao", "documentos", "relatorios", "usuarios"]'::jsonb,
   '["read", "create", "update", "delete"]'::jsonb,
   true),
  ('00000000-0000-0000-0000-000000000003', NULL, 'Gestor Operacional',
   'Acesso a todos os módulos operacionais e relatórios',
   '["dashboard", "aviacao", "caminhoes", "combustiveis", "estoque", "telemetria", "manutencao", "documentos", "relatorios"]'::jsonb,
   '["read", "create", "update", "delete"]'::jsonb,
   true),
  ('00000000-0000-0000-0000-000000000004', NULL, 'Operador',
   'Acesso operacional padrão',
   '["dashboard", "aviacao", "caminhoes", "combustiveis", "estoque", "telemetria", "manutencao", "documentos"]'::jsonb,
   '["read", "create", "update"]'::jsonb,
   true),
  ('00000000-0000-0000-0000-000000000005', NULL, 'Mecânico',
   'Acesso a aviação, manutenção e estoque',
   '["dashboard", "aviacao", "manutencao", "estoque", "documentos"]'::jsonb,
   '["read", "create", "update"]'::jsonb,
   true),
  ('00000000-0000-0000-0000-000000000006', NULL, 'Somente Consulta',
   'Visualização de dashboard e relatórios',
   '["dashboard", "relatorios"]'::jsonb,
   '["read"]'::jsonb,
   true)
ON CONFLICT DO NOTHING;

-- Adicionar coluna profile_id na tabela users
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_id UUID REFERENCES profiles(id);
CREATE INDEX IF NOT EXISTS idx_users_profile ON users(profile_id);

-- Comentários
COMMENT ON TABLE profiles IS 'Perfis de acesso customizáveis por empresa';
COMMENT ON COLUMN profiles.empresa_id IS 'NULL = perfil global do sistema';
COMMENT ON COLUMN profiles.modules IS 'Array de módulos permitidos';
COMMENT ON COLUMN profiles.actions IS 'Array de ações permitidas (read, create, update, delete, admin)';
COMMENT ON COLUMN profiles.is_system IS 'Perfil do sistema (não pode ser editado/excluído)';
