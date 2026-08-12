-- Metadados de lançamento de horas (decolagem, pouso, operador, etc.)
ALTER TABLE aviation_hour_logs ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';
