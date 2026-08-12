-- Fila de notificações (e-mail / Resend)

CREATE TABLE IF NOT EXISTS notification_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  unidade_id UUID REFERENCES unidades(id) ON DELETE SET NULL,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  channel VARCHAR(20) NOT NULL DEFAULT 'email',
  recipient_email VARCHAR(255) NOT NULL,
  subject VARCHAR(500) NOT NULL,
  body_html TEXT NOT NULL,
  body_text TEXT,
  dedup_key VARCHAR(255) NOT NULL,
  alert_level VARCHAR(20),
  alert_module VARCHAR(50),
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  attempts INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 5,
  last_error TEXT,
  scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_notification_queue ON notification_queue;
CREATE POLICY tenant_notification_queue ON notification_queue
  FOR ALL USING (empresa_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE INDEX IF NOT EXISTS idx_notification_queue_pending
  ON notification_queue(status, scheduled_at)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_notification_queue_dedup
  ON notification_queue(dedup_key, recipient_email, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_queue_empresa
  ON notification_queue(empresa_id, created_at DESC);
