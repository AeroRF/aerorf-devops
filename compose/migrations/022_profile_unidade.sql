-- Perfis podem ser da empresa inteira (unidade_id NULL) ou só de uma filial.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS unidade_id UUID REFERENCES unidades(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_profiles_unidade ON profiles(unidade_id);

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_empresa_id_nome_key;
DROP INDEX IF EXISTS profiles_empresa_id_nome_key;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_empresa_nome_global
  ON profiles (empresa_id, nome)
  WHERE unidade_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_empresa_unidade_nome
  ON profiles (empresa_id, unidade_id, nome)
  WHERE unidade_id IS NOT NULL;

COMMENT ON COLUMN profiles.unidade_id IS 'Filial dona do perfil. NULL = perfil da empresa (todas as filiais).';
