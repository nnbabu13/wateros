-- Inventory Products
CREATE TABLE IF NOT EXISTS inventory_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category_id UUID REFERENCES expense_categories(id),
    unit TEXT NOT NULL DEFAULT 'piece',
    current_stock NUMERIC NOT NULL DEFAULT 0,
    min_stock NUMERIC NOT NULL DEFAULT 0,
    cost_price NUMERIC NOT NULL DEFAULT 0,
    sell_price NUMERIC NOT NULL DEFAULT 0,
    hsn_code TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Stock Movements
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES inventory_products(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('in', 'out', 'adjustment')),
    quantity NUMERIC NOT NULL,
    reference_type TEXT,
    reference_id UUID,
    reason TEXT,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_products_business ON inventory_products(business_id);
CREATE INDEX IF NOT EXISTS idx_stock_mov_business ON stock_movements(business_id);
CREATE INDEX IF NOT EXISTS idx_stock_mov_product ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_mov_date ON stock_movements(business_id, date);

-- RLS
ALTER TABLE inventory_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DO $$ BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'inventory_products' AND schemaname = 'public' LOOP
        EXECUTE format('DROP POLICY IF EXISTS "%s" ON inventory_products', pol.policyname);
    END LOOP;
END $$;
DO $$ BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'stock_movements' AND schemaname = 'public' LOOP
        EXECUTE format('DROP POLICY IF EXISTS "%s" ON stock_movements', pol.policyname);
    END LOOP;
END $$;

CREATE POLICY "inventory_products_open" ON inventory_products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "stock_movements_open" ON stock_movements FOR ALL USING (true) WITH CHECK (true);
