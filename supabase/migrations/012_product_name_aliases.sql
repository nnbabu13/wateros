-- Remembers register text variants linked to a real product.
-- e.g. "Bags" -> Water Bag, "500" -> 500ml Water Bottle

CREATE TABLE IF NOT EXISTS product_name_aliases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  alias TEXT NOT NULL,
  alias_normalized TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_id, alias_normalized)
);

CREATE INDEX IF NOT EXISTS idx_product_name_aliases_lookup
  ON product_name_aliases(business_id, alias_normalized);

ALTER TABLE product_name_aliases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "prod_alias_all" ON product_name_aliases;
CREATE POLICY "prod_alias_all" ON product_name_aliases
  FOR ALL USING (true) WITH CHECK (true);
