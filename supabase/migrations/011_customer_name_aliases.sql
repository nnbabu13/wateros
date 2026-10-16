-- Remembers OCR/register name variants linked to a real customer.
-- e.g. "Sharath" -> Sarath, "Chikkala" -> Surya bar

CREATE TABLE IF NOT EXISTS customer_name_aliases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  alias TEXT NOT NULL,
  alias_normalized TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_id, alias_normalized)
);

CREATE INDEX IF NOT EXISTS idx_customer_name_aliases_lookup
  ON customer_name_aliases(business_id, alias_normalized);

CREATE INDEX IF NOT EXISTS idx_customer_name_aliases_customer
  ON customer_name_aliases(customer_id);

ALTER TABLE customer_name_aliases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cust_alias_all" ON customer_name_aliases;
CREATE POLICY "cust_alias_all" ON customer_name_aliases
  FOR ALL USING (true) WITH CHECK (true);
