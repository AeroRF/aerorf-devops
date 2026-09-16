-- T.L.V. / T.B.O. calendário como período (quantidade + unidade), além da data de vencimento.

ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tlv_cal_quantidade INTEGER;
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tlv_cal_unidade VARCHAR(10);
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tbo_cal_quantidade INTEGER;
ALTER TABLE aviation_components ADD COLUMN IF NOT EXISTS tbo_cal_unidade VARCHAR(10);
