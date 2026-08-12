-- Estoque — produtos, depósitos, movimentos e NF (idempotente)

CREATE TABLE IF NOT EXISTS stock_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  sku VARCHAR(100) NOT NULL,
  nome VARCHAR(255) NOT NULL,
  un VARCHAR(20) DEFAULT 'UN',
  controle VARCHAR(30) DEFAULT 'SIMPLES',
  custo VARCHAR(30) DEFAULT 'FIFO',
  preco_tabela NUMERIC(14, 4) DEFAULT 0,
  preco_min NUMERIC(14, 4) DEFAULT 0,
  preco_max NUMERIC(14, 4) DEFAULT 0,
  ncm VARCHAR(20),
  categoria VARCHAR(100),
  critico BOOLEAN DEFAULT false,
  minimo NUMERIC(14, 2) DEFAULT 0,
  limites JSONB DEFAULT '{}',
  alertas JSONB DEFAULT '{"horas":10,"ciclos":10,"dias":15}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (empresa_id, unidade_id, sku)
);

CREATE TABLE IF NOT EXISTS stock_deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  external_id VARCHAR(50) NOT NULL,
  nome VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (empresa_id, unidade_id, external_id)
);

CREATE TABLE IF NOT EXISTS stock_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  fornecedor VARCHAR(255),
  doc_numero VARCHAR(50),
  numero VARCHAR(50) NOT NULL,
  serie VARCHAR(20),
  chave VARCHAR(80),
  emissao DATE,
  obs TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tipo_mov VARCHAR(30) NOT NULL,
  produto_id UUID NOT NULL REFERENCES stock_products(id) ON DELETE RESTRICT,
  qtd NUMERIC(14, 4) NOT NULL,
  lote VARCHAR(100),
  origem JSONB DEFAULT '{}',
  destino JSONB DEFAULT '{}',
  custos JSONB,
  operador JSONB,
  os_id VARCHAR(50),
  aeronave_id VARCHAR(50),
  consumer_type VARCHAR(30),
  consumer_id VARCHAR(50),
  pair_id VARCHAR(50),
  nota_id UUID REFERENCES stock_invoices(id) ON DELETE SET NULL,
  maintenance_auto BOOLEAN DEFAULT false,
  estornado BOOLEAN DEFAULT false,
  estornado_em TIMESTAMPTZ,
  observacao TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE stock_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_stock_products ON stock_products;
CREATE POLICY tenant_stock_products ON stock_products
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_stock_deposits ON stock_deposits;
CREATE POLICY tenant_stock_deposits ON stock_deposits
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_stock_invoices ON stock_invoices;
CREATE POLICY tenant_stock_invoices ON stock_invoices
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

DROP POLICY IF EXISTS tenant_stock_movements ON stock_movements;
CREATE POLICY tenant_stock_movements ON stock_movements
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_stock_products_tenant ON stock_products(empresa_id, unidade_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_ts ON stock_movements(empresa_id, ts DESC);
