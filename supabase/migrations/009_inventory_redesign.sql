-- Inventory Redesign: Period-based stock tracking + remove production

-- 0. Create updated_at trigger function if not exists
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. Create stock_entries table
CREATE TABLE stock_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    month DATE NOT NULL,
    entry_type TEXT NOT NULL CHECK (entry_type IN ('opening', 'closing')),
    quantity NUMERIC(12, 2) NOT NULL DEFAULT 0,
    unit_cost NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_value NUMERIC(14, 2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(business_id, product_id, month, entry_type)
);

CREATE INDEX idx_stock_entries_business_month ON stock_entries(business_id, month);
CREATE INDEX idx_stock_entries_product ON stock_entries(product_id);

ALTER TABLE stock_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY stock_entries_all ON stock_entries FOR ALL USING (true) WITH CHECK (true);

CREATE TRIGGER trigger_stock_entries_updated_at
    BEFORE UPDATE ON stock_entries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 2. Drop production tables
DROP TABLE IF EXISTS production_consumptions CASCADE;
DROP TABLE IF EXISTS production_outputs CASCADE;
DROP TABLE IF EXISTS production_batches CASCADE;

-- 3. Update inventory_movements CHECK constraint (remove production types)
ALTER TABLE inventory_movements DROP CONSTRAINT IF EXISTS inventory_movements_movement_type_check;
ALTER TABLE inventory_movements ADD CONSTRAINT inventory_movements_movement_type_check
    CHECK (movement_type IN ('in', 'out', 'adjustment', 'transfer', 'return'));
