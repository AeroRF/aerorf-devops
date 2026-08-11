-- AeroRF PostgreSQL schema with RLS
-- Run: psql $DATABASE_URL -f migrations/001_initial.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome VARCHAR(255) NOT NULL,
  nome_fantasia VARCHAR(255),
  cnpj VARCHAR(20),
  ativo BOOLEAN DEFAULT true,
  plano JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS unidades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  nome VARCHAR(255) NOT NULL,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  nome VARCHAR(255) DEFAULT '',
  role VARCHAR(50) DEFAULT 'USUARIO',
  empresa_id UUID REFERENCES empresas(id),
  unidade_id UUID REFERENCES unidades(id),
  empresas_permitidas JSONB DEFAULT '[]',
  unidades_permitidas JSONB DEFAULT '[]',
  modulos JSONB DEFAULT '["dashboard"]',
  permissoes JSONB DEFAULT '{"modules":["dashboard"],"actions":["read"]}',
  full_access BOOLEAN DEFAULT false,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS aircraft (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  prefixo VARCHAR(50) NOT NULL,
  modelo VARCHAR(100),
  horas_totais NUMERIC(10, 2) DEFAULT 0,
  status VARCHAR(30) DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workorders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  aircraft_id UUID REFERENCES aircraft(id),
  titulo VARCHAR(255) NOT NULL,
  status VARCHAR(30) DEFAULT 'open',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  storage_key TEXT NOT NULL,
  nome VARCHAR(255) NOT NULL,
  tipo VARCHAR(100) DEFAULT 'general',
  version INT DEFAULT 1,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  titulo VARCHAR(255) NOT NULL,
  mensagem TEXT,
  nivel VARCHAR(20) DEFAULT 'info',
  modulo VARCHAR(50),
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL,
  unidade_id UUID,
  user_id UUID,
  tipo VARCHAR(50) NOT NULL,
  descricao TEXT,
  referencia VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE aircraft ENABLE ROW LEVEL SECURITY;
ALTER TABLE workorders ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation_aircraft ON aircraft;
CREATE POLICY tenant_isolation_aircraft ON aircraft
  FOR ALL
  USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_isolation_workorders ON workorders;
CREATE POLICY tenant_isolation_workorders ON workorders
  FOR ALL
  USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_isolation_documents ON documents;
CREATE POLICY tenant_isolation_documents ON documents
  FOR ALL
  USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_isolation_alerts ON alerts;
CREATE POLICY tenant_isolation_alerts ON alerts
  FOR ALL
  USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_aircraft_empresa ON aircraft(empresa_id);
CREATE INDEX IF NOT EXISTS idx_workorders_empresa ON workorders(empresa_id);
CREATE INDEX IF NOT EXISTS idx_alerts_unidade ON alerts(unidade_id, active);
