-- ============================================
-- WaterOS Inventory V1
-- Raw Materials, Recipes, Production
-- ============================================

-- 1. Extend products table
ALTER TABLE products ADD COLUMN IF NOT EXISTS product_type TEXT NOT NULL DEFAULT 'finished_product'
    CHECK (product_type IN ('raw_material', 'packaging', 'finished_product', 'reusable_asset'));
ALTER TABLE products ADD COLUMN IF NOT EXISTS packaging_unit TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS conversion_quantity NUMERIC(12,2) NOT NULL DEFAULT 1;
ALTER TABLE products ADD COLUMN IF NOT EXISTS average_cost NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS notes TEXT;

CREATE INDEX IF NOT EXISTS idx_products_type ON products(business_id, product_type) WHERE is_active = true;

-- 2. Drop duplicate tables from 004 (never used)
DROP TABLE IF EXISTS stock_movements;
DROP TABLE IF EXISTS inventory_products;

-- 3. Extend inventory_movements CHECK constraint
ALTER TABLE inventory_movements DROP CONSTRAINT IF EXISTS inventory_movements_movement_type_check;
ALTER TABLE inventory_movements ADD CONSTRAINT inventory_movements_movement_type_check
    CHECK (movement_type IN ('in', 'out', 'adjustment', 'transfer', 'return', 'production_consumption', 'production_output'));

-- 4. Product Recipes
CREATE TABLE IF NOT EXISTS product_recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    name TEXT NOT NULL DEFAULT 'Default Recipe',
    description TEXT,
    yield_quantity NUMERIC(12,2) NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_recipes_business ON product_recipes(business_id);
CREATE INDEX IF NOT EXISTS idx_recipes_product ON product_recipes(product_id);

-- 5. Recipe Items (materials per recipe)
CREATE TABLE IF NOT EXISTS recipe_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id UUID NOT NULL REFERENCES product_recipes(id) ON DELETE CASCADE,
    material_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity_per_unit NUMERIC(12,4) NOT NULL,
    unit TEXT NOT NULL DEFAULT 'piece',
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe ON recipe_items(recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_material ON recipe_items(material_id);

-- 6. Production Batches
CREATE TABLE IF NOT EXISTS production_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    recipe_id UUID REFERENCES product_recipes(id) ON DELETE SET NULL,
    planned_quantity NUMERIC(12,2) NOT NULL DEFAULT 0,
    actual_quantity NUMERIC(12,2) NOT NULL DEFAULT 0,
    production_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prod_batches_business ON production_batches(business_id);
CREATE INDEX IF NOT EXISTS idx_prod_batches_product ON production_batches(product_id);
CREATE INDEX IF NOT EXISTS idx_prod_batches_date ON production_batches(business_id, production_date);

-- 7. Production Consumptions
CREATE TABLE IF NOT EXISTS production_consumptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES production_batches(id) ON DELETE CASCADE,
    material_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    planned_quantity NUMERIC(12,4) NOT NULL DEFAULT 0,
    actual_quantity NUMERIC(12,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prod_consumptions_batch ON production_consumptions(batch_id);

-- 8. Production Outputs
CREATE TABLE IF NOT EXISTS production_outputs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES production_batches(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prod_outputs_batch ON production_outputs(batch_id);

-- 9. Fix stock triggers
-- Drop old triggers if they exist
DROP TRIGGER IF EXISTS trigger_update_stock_on_sale ON sale_items;
DROP TRIGGER IF EXISTS trigger_update_stock_on_purchase ON purchase_items;

-- Update sale trigger: only deduct finished products
CREATE OR REPLACE FUNCTION update_stock_on_sale()
RETURNS TRIGGER AS $$
DECLARE
    v_product_type TEXT;
    v_conversion NUMERIC;
BEGIN
    SELECT product_type, conversion_quantity INTO v_product_type, v_conversion
    FROM products WHERE id = NEW.product_id;

    IF v_product_type = 'finished_product' THEN
        UPDATE products SET current_stock = current_stock - NEW.quantity WHERE id = NEW.product_id;
        INSERT INTO inventory_movements (business_id, product_id, movement_type, quantity, reference_type, reference_id)
        SELECT s.business_id, NEW.product_id, 'out', NEW.quantity, 'sale', NEW.sale_id
        FROM sales s WHERE id = NEW.sale_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update purchase trigger: only add raw materials and packaging
CREATE OR REPLACE FUNCTION update_stock_on_purchase()
RETURNS TRIGGER AS $$
DECLARE
    v_product_type TEXT;
    v_old_avg NUMERIC;
    v_old_stock NUMERIC;
    v_new_avg NUMERIC;
BEGIN
    SELECT product_type, average_cost, current_stock INTO v_product_type, v_old_avg, v_old_stock
    FROM products WHERE id = NEW.product_id;

    IF v_product_type IN ('raw_material', 'packaging') THEN
        -- Weighted average cost
        IF (v_old_stock + NEW.quantity) > 0 THEN
            v_new_avg := ((v_old_avg * v_old_stock) + (NEW.unit_price * NEW.quantity)) / (v_old_stock + NEW.quantity);
        ELSE
            v_new_avg := NEW.unit_price;
        END IF;

        UPDATE products
        SET current_stock = current_stock + NEW.quantity,
            average_cost = v_new_avg
        WHERE id = NEW.product_id;

        INSERT INTO inventory_movements (business_id, product_id, movement_type, quantity, reference_type, reference_id)
        SELECT p.business_id, NEW.product_id, 'in', NEW.quantity, 'purchase', NEW.purchase_id
        FROM purchases p WHERE id = NEW.purchase_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach triggers
CREATE TRIGGER trigger_update_stock_on_sale
    AFTER INSERT ON sale_items
    FOR EACH ROW EXECUTE FUNCTION update_stock_on_sale();

CREATE TRIGGER trigger_update_stock_on_purchase
    AFTER INSERT ON purchase_items
    FOR EACH ROW EXECUTE FUNCTION update_stock_on_purchase();

-- 10. RLS policies for new tables
ALTER TABLE product_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_consumptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_outputs ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE
    pol RECORD;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'product_recipes' AND schemaname = 'public' LOOP
        EXECUTE format('DROP POLICY IF EXISTS "%s" ON product_recipes', pol.policyname);
    END LOOP;
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'recipe_items' AND schemaname = 'public' LOOP
        EXECUTE format('DROP POLICY IF EXISTS "%s" ON recipe_items', pol.policyname);
    END LOOP;
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'production_batches' AND schemaname = 'public' LOOP
        EXECUTE format('DROP POLICY IF EXISTS "%s" ON production_batches', pol.policyname);
    END LOOP;
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'production_consumptions' AND schemaname = 'public' LOOP
        EXECUTE format('DROP POLICY IF EXISTS "%s" ON production_consumptions', pol.policyname);
    END LOOP;
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'production_outputs' AND schemaname = 'public' LOOP
        EXECUTE format('DROP POLICY IF EXISTS "%s" ON production_outputs', pol.policyname);
    END LOOP;
END $$;

CREATE POLICY "product_recipes_open" ON product_recipes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "recipe_items_open" ON recipe_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "production_batches_open" ON production_batches FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "production_consumptions_open" ON production_consumptions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "production_outputs_open" ON production_outputs FOR ALL USING (true) WITH CHECK (true);

-- 11. Updated at triggers for new tables
CREATE TRIGGER trigger_product_recipes_updated_at BEFORE UPDATE ON product_recipes FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_production_batches_updated_at BEFORE UPDATE ON production_batches FOR EACH ROW EXECUTE FUNCTION update_updated_at();
