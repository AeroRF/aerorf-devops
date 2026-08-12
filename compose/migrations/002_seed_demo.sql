-- Seed demo (idempotente) — admin@aerorf.com.br / admin123
-- Uso: docker exec -i aerorf_postgres psql -U aerorf -d aerorf < compose/migrations/002_seed_demo.sql

DO $$
DECLARE
  v_empresa UUID := '11111111-1111-4111-8111-111111111111';
  v_unidade UUID := '22222222-2222-4222-8222-222222222222';
  v_user UUID := '33333333-3333-4333-8333-333333333333';
BEGIN
  INSERT INTO empresas (id, nome, nome_fantasia, cnpj, ativo)
  VALUES (v_empresa, 'AeroRF Demo', 'AeroRF Demo', '00.000.000/0001-00', true)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO unidades (id, empresa_id, nome, ativo)
  VALUES (v_unidade, v_empresa, 'Base Principal', true)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO users (
    id, email, password_hash, nome, role, empresa_id, unidade_id,
    empresas_permitidas, unidades_permitidas, modulos, permissoes, full_access, ativo
  ) VALUES (
    v_user,
    'admin@aerorf.com.br',
    '$2a$10$AVcGreztGHf/7vxXV9WobeWSRT7m.0xkP6IuAs2t2uB4euwv.ffV2',
    'Administrador',
    'ADMIN_MASTER',
    v_empresa,
    v_unidade,
    jsonb_build_array(v_empresa::text),
    jsonb_build_array(v_unidade::text),
    '["dashboard","empresas","usuarios","aviacao","combustiveis","estoque","telemetria","caminhoes"]'::jsonb,
    '{"modules":["dashboard","aviacao"],"actions":["read","create","update","delete","admin"]}'::jsonb,
    true,
    true
  ) ON CONFLICT (email) DO NOTHING;

  PERFORM set_config('app.current_tenant_id', v_empresa::text, true);

  INSERT INTO aircraft (empresa_id, unidade_id, prefixo, modelo, horas_totais, status)
  SELECT v_empresa, v_unidade, 'PT-ARF', 'Air Tractor AT-502', 1250.5, 'active'
  WHERE NOT EXISTS (
    SELECT 1 FROM aircraft WHERE prefixo = 'PT-ARF' AND empresa_id = v_empresa
  );
END $$;
