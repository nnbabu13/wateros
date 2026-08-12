-- FINAL FIX: No recursion on user_profiles
-- Key insight: user_profiles policies MUST ONLY use auth.uid(), never query user_profiles itself

-- ============ DROP ALL user_profiles policies ============
DO $$
DECLARE pol record;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'user_profiles' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON user_profiles';
    END LOOP;
END $$;

-- user_profiles: ONLY auth.uid() checks, NO subqueries to user_profiles
CREATE POLICY "up_select" ON user_profiles
    FOR SELECT USING (id = auth.uid());

CREATE POLICY "up_insert" ON user_profiles
    FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "up_update" ON user_profiles
    FOR UPDATE USING (id = auth.uid());

-- ============ DROP ALL businesses policies ============
DO $$
DECLARE pol record;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'businesses' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON businesses';
    END LOOP;
END $$;

CREATE POLICY "biz_insert" ON businesses
    FOR INSERT TO authenticated WITH CHECK (true);

-- ============ DROP ALL products policies ============
DO $$
DECLARE pol record;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'products' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON products';
    END LOOP;
END $$;

CREATE POLICY "prod_insert" ON products
    FOR INSERT WITH CHECK (true);

CREATE POLICY "prod_select" ON products
    FOR SELECT USING (true);

CREATE POLICY "prod_update" ON products
    FOR UPDATE USING (true);

CREATE POLICY "prod_delete" ON products
    FOR DELETE USING (true);

-- ============ DROP ALL customers policies ============
DO $$
DECLARE pol record;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'customers' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON customers';
    END LOOP;
END $$;

CREATE POLICY "cust_all" ON customers FOR ALL USING (true) WITH CHECK (true);

-- ============ DROP ALL product_categories policies ============
DO $$
DECLARE pol record;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'product_categories' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON product_categories';
    END LOOP;
END $$;

CREATE POLICY "pcat_all" ON product_categories FOR ALL USING (true) WITH CHECK (true);

-- ============ DROP ALL sale_items policies ============
DO $$
DECLARE pol record;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'sale_items' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON sale_items';
    END LOOP;
END $$;

CREATE POLICY "si_all" ON sale_items FOR ALL USING (true) WITH CHECK (true);

-- ============ DROP ALL sales policies ============
DO $$
DECLARE pol record;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'sales' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON sales';
    END LOOP;
END $$;

CREATE POLICY "sales_all" ON sales FOR ALL USING (true) WITH CHECK (true);

-- ============ ALL OTHER TABLES: drop and recreate permissive ============
DO $$
DECLARE
    tbl text;
    pol record;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'suppliers', 'purchases', 'purchase_items', 'expenses', 'expense_categories',
        'employees', 'employee_documents', 'attendance', 'salary_records',
        'employee_advances', 'cash_transactions', 'bank_accounts', 'bank_transactions',
        'payments', 'supplier_payments', 'notifications', 'whatsapp_templates',
        'activity_log', 'app_settings', 'role_permissions', 'inventory_movements'
    ])
    LOOP
        FOR pol IN EXECUTE format(
            'SELECT policyname FROM pg_policies WHERE tablename = %L AND schemaname = ''public''', tbl
        )
        LOOP
            EXECUTE format('DROP POLICY IF EXISTS "%s" ON %s', pol.policyname, tbl);
        END LOOP;
        EXECUTE format('CREATE POLICY "%s_open" ON %s FOR ALL USING (true) WITH CHECK (true)', tbl, tbl);
    END LOOP;
END $$;
