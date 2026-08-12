-- ============================================
-- WaterOS Database Schema
-- Normalized PostgreSQL with RLS Policies
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- 1. BUSINESSES (Multi-tenant support)
-- ============================================
CREATE TABLE businesses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    pincode TEXT,
    gst_number TEXT,
    pan_number TEXT,
    logo_url TEXT,
    currency TEXT NOT NULL DEFAULT 'INR',
    currency_symbol TEXT NOT NULL DEFAULT '₹',
    invoice_prefix TEXT NOT NULL DEFAULT 'INV',
    invoice_counter INTEGER NOT NULL DEFAULT 0,
    purchase_prefix TEXT NOT NULL DEFAULT 'PUR',
    purchase_counter INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_businesses_phone ON businesses(phone);

-- ============================================
-- 2. USER PROFILES (Extends Supabase Auth)
-- ============================================
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    role TEXT NOT NULL DEFAULT 'employee' CHECK (role IN ('owner', 'admin', 'manager', 'sales', 'accountant', 'delivery', 'employee')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_profiles_business ON user_profiles(business_id);
CREATE INDEX idx_user_profiles_role ON user_profiles(role);

-- ============================================
-- 3. ROLE PERMISSIONS
-- ============================================
CREATE TABLE role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'manager', 'sales', 'accountant', 'delivery', 'employee')),
    module TEXT NOT NULL,
    can_view BOOLEAN NOT NULL DEFAULT false,
    can_create BOOLEAN NOT NULL DEFAULT false,
    can_edit BOOLEAN NOT NULL DEFAULT false,
    can_delete BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(business_id, role, module)
);

CREATE INDEX idx_role_permissions_business ON role_permissions(business_id);

-- ============================================
-- 4. CUSTOMERS
-- ============================================
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    whatsapp_phone TEXT,
    email TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    pincode TEXT,
    gst_number TEXT,
    opening_balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
    current_balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
    credit_limit NUMERIC(12, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_customers_business ON customers(business_id);
CREATE INDEX idx_customers_phone ON customers(business_id, phone);
CREATE INDEX idx_customers_name ON customers(business_id, name);
CREATE INDEX idx_customers_balance ON customers(business_id, current_balance) WHERE current_balance > 0;

-- ============================================
-- 5. SUPPLIERS
-- ============================================
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    whatsapp_phone TEXT,
    email TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    pincode TEXT,
    gst_number TEXT,
    opening_balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
    current_balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_suppliers_business ON suppliers(business_id);
CREATE INDEX idx_suppliers_phone ON suppliers(business_id, phone);

-- ============================================
-- 6. PRODUCT CATEGORIES
-- ============================================
CREATE TABLE product_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_product_categories_business ON product_categories(business_id);

-- ============================================
-- 7. PRODUCTS
-- ============================================
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    category_id UUID REFERENCES product_categories(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    sku TEXT,
    barcode TEXT,
    description TEXT,
    unit TEXT NOT NULL DEFAULT 'piece',
    purchase_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    selling_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    gst_rate NUMERIC(5, 2) NOT NULL DEFAULT 0,
    current_stock NUMERIC(12, 2) NOT NULL DEFAULT 0,
    minimum_stock NUMERIC(12, 2) NOT NULL DEFAULT 0,
    maximum_stock NUMERIC(12, 2) NOT NULL DEFAULT 0,
    image_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_products_business ON products(business_id);
CREATE INDEX idx_products_sku ON products(business_id, sku) WHERE sku IS NOT NULL;
CREATE INDEX idx_products_barcode ON products(business_id, barcode) WHERE barcode IS NOT NULL;
CREATE INDEX idx_products_low_stock ON products(business_id, current_stock, minimum_stock) WHERE current_stock <= minimum_stock;

-- ============================================
-- 8. INVENTORY MOVEMENTS
-- ============================================
CREATE TABLE inventory_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    movement_type TEXT NOT NULL CHECK (movement_type IN ('in', 'out', 'adjustment', 'transfer', 'return')),
    quantity NUMERIC(12, 2) NOT NULL,
    reference_type TEXT,
    reference_id UUID,
    notes TEXT,
    created_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_inventory_movements_business ON inventory_movements(business_id);
CREATE INDEX idx_inventory_movements_product ON inventory_movements(product_id);
CREATE INDEX idx_inventory_movements_date ON inventory_movements(business_id, created_at);

-- ============================================
-- 9. SALES (Invoices / Bills)
-- ============================================
CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    invoice_number TEXT NOT NULL,
    invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    discount_percent NUMERIC(5, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    balance_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    payment_mode TEXT CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer', 'credit', 'partial')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('paid', 'partially_paid', 'pending', 'cancelled')),
    notes TEXT,
    created_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sales_business ON sales(business_id);
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_date ON sales(business_id, invoice_date);
CREATE INDEX idx_sales_status ON sales(business_id, status);
CREATE INDEX idx_sales_invoice ON sales(business_id, invoice_number);

-- ============================================
-- 10. SALE ITEMS
-- ============================================
CREATE TABLE sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_name TEXT NOT NULL,
    quantity NUMERIC(12, 2) NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    gst_rate NUMERIC(5, 2) NOT NULL DEFAULT 0,
    gst_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product ON sale_items(product_id);

-- ============================================
-- 11. PURCHASES
-- ============================================
CREATE TABLE purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    purchase_number TEXT NOT NULL,
    purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    balance_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    payment_mode TEXT CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer', 'credit', 'partial')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('paid', 'partially_paid', 'pending', 'cancelled')),
    notes TEXT,
    created_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_purchases_business ON purchases(business_id);
CREATE INDEX idx_purchases_supplier ON purchases(supplier_id);
CREATE INDEX idx_purchases_date ON purchases(business_id, purchase_date);
CREATE INDEX idx_purchases_status ON purchases(business_id, status);

-- ============================================
-- 12. PURCHASE ITEMS
-- ============================================
CREATE TABLE purchase_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_name TEXT NOT NULL,
    quantity NUMERIC(12, 2) NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    gst_rate NUMERIC(5, 2) NOT NULL DEFAULT 0,
    gst_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_purchase_items_purchase ON purchase_items(purchase_id);
CREATE INDEX idx_purchase_items_product ON purchase_items(product_id);

-- ============================================
-- 13. EXPENSE CATEGORIES
-- ============================================
CREATE TABLE expense_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT,
    color TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_expense_categories_business ON expense_categories(business_id);

-- ============================================
-- 14. EXPENSES
-- ============================================
CREATE TABLE expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES expense_categories(id) ON DELETE RESTRICT,
    amount NUMERIC(12, 2) NOT NULL,
    description TEXT,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_mode TEXT NOT NULL CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer')),
    receipt_url TEXT,
    is_recurring BOOLEAN NOT NULL DEFAULT false,
    recurring_frequency TEXT CHECK (recurring_frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
    created_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_expenses_business ON expenses(business_id);
CREATE INDEX idx_expenses_category ON expenses(category_id);
CREATE INDEX idx_expenses_date ON expenses(business_id, expense_date);

-- ============================================
-- 15. EMPLOYEES
-- ============================================
CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_profile_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    employee_code TEXT,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    address TEXT,
    city TEXT,
    date_of_birth DATE,
    date_of_joining DATE NOT NULL DEFAULT CURRENT_DATE,
    designation TEXT,
    department TEXT,
    basic_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
    bank_name TEXT,
    bank_account_number TEXT,
    ifsc_code TEXT,
    pan_number TEXT,
    aadhar_number TEXT,
    emergency_contact TEXT,
    emergency_contact_name TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_employees_business ON employees(business_id);
CREATE INDEX idx_employees_active ON employees(business_id, is_active) WHERE is_active = true;

-- ============================================
-- 16. EMPLOYEE DOCUMENTS
-- ============================================
CREATE TABLE employee_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL,
    document_name TEXT NOT NULL,
    document_url TEXT NOT NULL,
    expiry_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_employee_documents_employee ON employee_documents(employee_id);

-- ============================================
-- 17. ATTENDANCE
-- ============================================
CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'half_day', 'leave', 'holiday')),
    check_in_time TIME,
    check_out_time TIME,
    overtime_hours NUMERIC(5, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    marked_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(employee_id, attendance_date)
);

CREATE INDEX idx_attendance_business ON attendance(business_id);
CREATE INDEX idx_attendance_employee ON attendance(employee_id);
CREATE INDEX idx_attendance_date ON attendance(business_id, attendance_date);

-- ============================================
-- 18. SALARY RECORDS
-- ============================================
CREATE TABLE salary_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INTEGER NOT NULL,
    working_days INTEGER NOT NULL DEFAULT 0,
    present_days INTEGER NOT NULL DEFAULT 0,
    absent_days INTEGER NOT NULL DEFAULT 0,
    half_days INTEGER NOT NULL DEFAULT 0,
    leave_days INTEGER NOT NULL DEFAULT 0,
    basic_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
    allowances NUMERIC(12, 2) NOT NULL DEFAULT 0,
    deductions NUMERIC(12, 2) NOT NULL DEFAULT 0,
    advance_deduction NUMERIC(12, 2) NOT NULL DEFAULT 0,
    net_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'partial')),
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    payment_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(employee_id, month, year)
);

CREATE INDEX idx_salary_records_business ON salary_records(business_id);
CREATE INDEX idx_salary_records_employee ON salary_records(employee_id);
CREATE INDEX idx_salary_records_period ON salary_records(business_id, year, month);

-- ============================================
-- 19. EMPLOYEE ADVANCES
-- ============================================
CREATE TABLE employee_advances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    amount NUMERIC(12, 2) NOT NULL,
    advance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    reason TEXT,
    is_deducted BOOLEAN NOT NULL DEFAULT false,
    deduction_salary_id UUID REFERENCES salary_records(id),
    created_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_employee_advances_business ON employee_advances(business_id);
CREATE INDEX idx_employee_advances_employee ON employee_advances(employee_id);

-- ============================================
-- 20. CASH TRANSACTIONS
-- ============================================
CREATE TABLE cash_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('in', 'out')),
    amount NUMERIC(12, 2) NOT NULL,
    reference_type TEXT,
    reference_id UUID,
    description TEXT NOT NULL,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cash_transactions_business ON cash_transactions(business_id);
CREATE INDEX idx_cash_transactions_date ON cash_transactions(business_id, transaction_date);
CREATE INDEX idx_cash_transactions_type ON cash_transactions(business_id, transaction_type);

-- ============================================
-- 21. BANK ACCOUNTS
-- ============================================
CREATE TABLE bank_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    account_name TEXT NOT NULL,
    bank_name TEXT,
    account_number TEXT,
    ifsc_code TEXT,
    account_type TEXT NOT NULL DEFAULT 'bank' CHECK (account_type IN ('bank', 'upi', 'cash')),
    balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bank_accounts_business ON bank_accounts(business_id);

-- ============================================
-- 22. BANK TRANSACTIONS
-- ============================================
CREATE TABLE bank_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    bank_account_id UUID NOT NULL REFERENCES bank_accounts(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('in', 'out', 'transfer')),
    amount NUMERIC(12, 2) NOT NULL,
    reference_type TEXT,
    reference_id UUID,
    description TEXT NOT NULL,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bank_transactions_business ON bank_transactions(business_id);
CREATE INDEX idx_bank_transactions_account ON bank_transactions(bank_account_id);
CREATE INDEX idx_bank_transactions_date ON bank_transactions(business_id, transaction_date);

-- ============================================
-- 23. PAYMENTS (Customer Payments)
-- ============================================
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    sale_id UUID REFERENCES sales(id) ON DELETE SET NULL,
    amount NUMERIC(12, 2) NOT NULL,
    payment_mode TEXT NOT NULL CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer')),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    reference_number TEXT,
    notes TEXT,
    created_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payments_business ON payments(business_id);
CREATE INDEX idx_payments_customer ON payments(customer_id);
CREATE INDEX idx_payments_sale ON payments(sale_id);
CREATE INDEX idx_payments_date ON payments(business_id, payment_date);

-- ============================================
-- 24. SUPPLIER PAYMENTS
-- ============================================
CREATE TABLE supplier_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    purchase_id UUID REFERENCES purchases(id) ON DELETE SET NULL,
    amount NUMERIC(12, 2) NOT NULL,
    payment_mode TEXT NOT NULL CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer')),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    reference_number TEXT,
    notes TEXT,
    created_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_supplier_payments_business ON supplier_payments(business_id);
CREATE INDEX idx_supplier_payments_supplier ON supplier_payments(supplier_id);
CREATE INDEX idx_supplier_payments_date ON supplier_payments(business_id, payment_date);

-- ============================================
-- 25. NOTIFICATIONS
-- ============================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    notification_type TEXT NOT NULL CHECK (notification_type IN ('payment_due', 'low_stock', 'expense_due', 'salary_due', 'follow_up', 'info')),
    reference_type TEXT,
    reference_id UUID,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_business ON notifications(business_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;

-- ============================================
-- 26. WHATSAPP TEMPLATES
-- ============================================
CREATE TABLE whatsapp_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    template_type TEXT NOT NULL CHECK (template_type IN ('friendly', 'second', 'final', 'custom')),
    message_template TEXT NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_whatsapp_templates_business ON whatsapp_templates(business_id);

-- ============================================
-- 27. ACTIVITY LOG
-- ============================================
CREATE TABLE activity_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID REFERENCES user_profiles(id),
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    entity_name TEXT,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_activity_log_business ON activity_log(business_id);
CREATE INDEX idx_activity_log_date ON activity_log(business_id, created_at);
CREATE INDEX idx_activity_log_entity ON activity_log(entity_type, entity_id);

-- ============================================
-- 28. APP SETTINGS
-- ============================================
CREATE TABLE app_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    setting_key TEXT NOT NULL,
    setting_value JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(business_id, setting_key)
);

CREATE INDEX idx_app_settings_business ON app_settings(business_id);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER trigger_businesses_updated_at BEFORE UPDATE ON businesses FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_suppliers_updated_at BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_sales_updated_at BEFORE UPDATE ON sales FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_purchases_updated_at BEFORE UPDATE ON purchases FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_expenses_updated_at BEFORE UPDATE ON expenses FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_employees_updated_at BEFORE UPDATE ON employees FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_salary_records_updated_at BEFORE UPDATE ON salary_records FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_bank_accounts_updated_at BEFORE UPDATE ON bank_accounts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_whatsapp_templates_updated_at BEFORE UPDATE ON whatsapp_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_app_settings_updated_at BEFORE UPDATE ON app_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-generate invoice number
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS TRIGGER AS $$
DECLARE
    prefix TEXT;
    counter INTEGER;
BEGIN
    SELECT invoice_prefix, invoice_counter + 1
    INTO prefix, counter
    FROM businesses WHERE id = NEW.business_id;

    NEW.invoice_number = prefix || '-' || LPAD(counter::TEXT, 6, '0');

    UPDATE businesses SET invoice_counter = counter WHERE id = NEW.business_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_invoice_number
BEFORE INSERT ON sales
FOR EACH ROW EXECUTE FUNCTION generate_invoice_number();

-- Auto-generate purchase number
CREATE OR REPLACE FUNCTION generate_purchase_number()
RETURNS TRIGGER AS $$
DECLARE
    prefix TEXT;
    counter INTEGER;
BEGIN
    SELECT purchase_prefix, purchase_counter + 1
    INTO prefix, counter
    FROM businesses WHERE id = NEW.business_id;

    NEW.purchase_number = prefix || '-' || LPAD(counter::TEXT, 6, '0');

    UPDATE businesses SET purchase_counter = counter WHERE id = NEW.business_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_purchase_number
BEFORE INSERT ON purchases
FOR EACH ROW EXECUTE FUNCTION generate_purchase_number();

-- Update product stock on sale
CREATE OR REPLACE FUNCTION update_stock_on_sale()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products
    SET current_stock = current_stock - NEW.quantity
    WHERE id = NEW.product_id;

    INSERT INTO inventory_movements (business_id, product_id, movement_type, quantity, reference_type, reference_id)
    SELECT NEW.sale_id, NEW.product_id, 'out', NEW.quantity, 'sale', NEW.sale_id
    FROM sales WHERE id = NEW.sale_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update product stock on purchase
CREATE OR REPLACE FUNCTION update_stock_on_purchase()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products
    SET current_stock = current_stock + NEW.quantity
    WHERE id = NEW.product_id;

    INSERT INTO inventory_movements (business_id, product_id, movement_type, quantity, reference_type, reference_id)
    SELECT NEW.purchase_id, NEW.product_id, 'in', NEW.quantity, 'purchase', NEW.purchase_id
    FROM purchases WHERE id = NEW.purchase_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update customer balance on payment
CREATE OR REPLACE FUNCTION update_customer_balance_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE customers
    SET current_balance = current_balance - NEW.amount
    WHERE id = NEW.customer_id;

    IF NEW.sale_id IS NOT NULL THEN
        UPDATE sales
        SET paid_amount = paid_amount + NEW.amount,
            balance_amount = total_amount - paid_amount - NEW.amount,
            status = CASE
                WHEN paid_amount + NEW.amount >= total_amount THEN 'paid'
                WHEN paid_amount + NEW.amount > 0 THEN 'partially_paid'
                ELSE status
            END
        WHERE id = NEW.sale_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_customer_balance
AFTER INSERT ON payments
FOR EACH ROW EXECUTE FUNCTION update_customer_balance_on_payment();

-- Update supplier balance on payment
CREATE OR REPLACE FUNCTION update_supplier_balance_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE suppliers
    SET current_balance = current_balance - NEW.amount
    WHERE id = NEW.supplier_id;

    IF NEW.purchase_id IS NOT NULL THEN
        UPDATE purchases
        SET paid_amount = paid_amount + NEW.amount,
            balance_amount = total_amount - paid_amount - NEW.amount,
            status = CASE
                WHEN paid_amount + NEW.amount >= total_amount THEN 'paid'
                WHEN paid_amount + NEW.amount > 0 THEN 'partially_paid'
                ELSE status
            END
        WHERE id = NEW.purchase_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_supplier_balance
AFTER INSERT ON supplier_payments
FOR EACH ROW EXECUTE FUNCTION update_supplier_balance_on_payment();

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================

ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE salary_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Helper function to get user's business_id
CREATE OR REPLACE FUNCTION get_user_business_id()
RETURNS UUID AS $$
    SELECT business_id FROM user_profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- RLS Policies: Users can only access their own business data
CREATE POLICY "Users can view own business" ON businesses
    FOR SELECT USING (id = get_user_business_id());

CREATE POLICY "Users can update own business" ON businesses
    FOR UPDATE USING (id = get_user_business_id());

CREATE POLICY "Users can view business profiles" ON user_profiles
    FOR SELECT USING (business_id = get_user_business_id());

CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (id = auth.uid());

CREATE POLICY "Admins can manage profiles" ON user_profiles
    FOR ALL USING (
        business_id = get_user_business_id() AND
        EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('owner', 'admin'))
    );

-- Apply business_id isolation to all main tables
CREATE POLICY "Business isolation" ON customers FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON suppliers FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON product_categories FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON products FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON inventory_movements FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON sales FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON sale_items FOR ALL USING (
    EXISTS (SELECT 1 FROM sales WHERE sales.id = sale_items.sale_id AND sales.business_id = get_user_business_id())
);
CREATE POLICY "Business isolation" ON purchases FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON purchase_items FOR ALL USING (
    EXISTS (SELECT 1 FROM purchases WHERE purchases.id = purchase_items.purchase_id AND purchases.business_id = get_user_business_id())
);
CREATE POLICY "Business isolation" ON expense_categories FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON expenses FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON employees FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON employee_documents FOR ALL USING (
    EXISTS (SELECT 1 FROM employees WHERE employees.id = employee_documents.employee_id AND employees.business_id = get_user_business_id())
);
CREATE POLICY "Business isolation" ON attendance FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON salary_records FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON employee_advances FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON cash_transactions FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON bank_accounts FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON bank_transactions FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON payments FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON supplier_payments FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON notifications FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON whatsapp_templates FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON activity_log FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON app_settings FOR ALL USING (business_id = get_user_business_id());
CREATE POLICY "Business isolation" ON role_permissions FOR ALL USING (business_id = get_user_business_id());

-- ============================================
-- SEED DATA: Default expense categories
-- ============================================
-- These will be inserted via app on business creation

-- ============================================
-- VIEWS: Dashboard aggregations
-- ============================================

CREATE OR REPLACE VIEW daily_sales_view AS
SELECT
    business_id,
    invoice_date,
    COUNT(*) as total_invoices,
    SUM(total_amount) as total_sales,
    SUM(paid_amount) as total_collected,
    SUM(balance_amount) as total_pending
FROM sales
WHERE status != 'cancelled'
GROUP BY business_id, invoice_date;

CREATE OR REPLACE VIEW customer_outstanding_view AS
SELECT
    c.business_id,
    c.id as customer_id,
    c.name as customer_name,
    c.phone as customer_phone,
    c.current_balance as outstanding_amount,
    COUNT(s.id) as pending_invoices
FROM customers c
LEFT JOIN sales s ON s.customer_id = c.id AND s.status IN ('pending', 'partially_paid')
WHERE c.current_balance > 0
GROUP BY c.id, c.business_id, c.name, c.phone, c.current_balance;

CREATE OR REPLACE VIEW supplier_outstanding_view AS
SELECT
    s.business_id,
    s.id as supplier_id,
    s.name as supplier_name,
    s.phone as supplier_phone,
    s.current_balance as outstanding_amount,
    COUNT(p.id) as pending_purchases
FROM suppliers s
LEFT JOIN purchases p ON p.supplier_id = s.id AND p.status IN ('pending', 'partially_paid')
WHERE s.current_balance > 0
GROUP BY s.id, s.business_id, s.name, s.phone, s.current_balance;

CREATE OR REPLACE VIEW low_stock_products_view AS
SELECT
    business_id,
    id as product_id,
    name as product_name,
    sku,
    current_stock,
    minimum_stock,
    (minimum_stock - current_stock) as shortage
FROM products
WHERE current_stock <= minimum_stock AND is_active = true;

CREATE OR REPLACE VIEW today_summary_view AS
SELECT
    s.business_id,
    COALESCE(SUM(s.total_amount), 0) as today_sales,
    COALESCE(SUM(s.paid_amount), 0) as today_collection,
    COALESCE((SELECT SUM(balance_amount) FROM sales WHERE status IN ('pending', 'partially_paid')), 0) as pending_payments,
    COALESCE((SELECT SUM(amount) FROM expenses WHERE expense_date = CURRENT_DATE), 0) as today_expenses,
    COALESCE((SELECT SUM(amount) FROM cash_transactions WHERE transaction_type = 'in' AND transaction_date = CURRENT_DATE), 0) -
    COALESCE((SELECT SUM(amount) FROM cash_transactions WHERE transaction_type = 'out' AND transaction_date = CURRENT_DATE), 0) as cash_balance,
    COALESCE((SELECT SUM(balance) FROM bank_accounts WHERE account_type = 'bank'), 0) as bank_balance,
    COALESCE(SUM(s.total_amount), 0) - COALESCE((SELECT SUM(amount) FROM expenses WHERE expense_date = CURRENT_DATE), 0) as today_profit,
    COALESCE((SELECT SUM(current_balance) FROM customers WHERE current_balance > 0), 0) as outstanding_receivables,
    COALESCE((SELECT SUM(current_balance) FROM suppliers WHERE current_balance > 0), 0) as outstanding_payables
FROM sales s
WHERE s.invoice_date = CURRENT_DATE AND s.status != 'cancelled'
GROUP BY s.business_id;
