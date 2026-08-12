-- Fix: The trigger was double-counting paid_amount because the app already sets it.
-- Change trigger to ONLY update customer balance (not sales paid_amount).

-- 1. Drop the old trigger
DROP TRIGGER IF EXISTS trigger_update_customer_balance ON payments;

-- 2. Recreate the function to only update customer balance (no sales update)
CREATE OR REPLACE FUNCTION update_customer_balance_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update customer balance: reduce by payment amount (customer owes less)
    UPDATE customers
    SET current_balance = current_balance - NEW.amount
    WHERE id = NEW.customer_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Recreate the trigger
CREATE TRIGGER trigger_update_customer_balance
AFTER INSERT ON payments
FOR EACH ROW EXECUTE FUNCTION update_customer_balance_on_payment();

-- 4. Repair corrupted data: Fix sales paid_amount and balance_amount
-- INV-000005: was paid=2600, trigger added 2600 again → paid=5200 (wrong)
UPDATE sales SET paid_amount = 2600, balance_amount = 0, status = 'paid'
WHERE invoice_number = 'INV-000005';

-- INV-000008: was paid=10, trigger added 10 again → paid=20 (wrong)
UPDATE sales SET paid_amount = 10, balance_amount = 30, status = 'partially_paid'
WHERE invoice_number = 'INV-000008';

-- 5. Repair customer balances
-- Sarat: should be 0 (paid in full for INV-000005), was -2600 due to double trigger
UPDATE customers SET current_balance = 0
WHERE id = 'c98d1922-9e84-48da-bfa1-50557c9e0b71' AND business_id = '023250c0-18b3-4536-a080-5b1330db3394';

-- Dommeti Sai: should owe 30 (INV-000008 total=40, paid=10, balance=30), was -10
UPDATE customers SET current_balance = 30
WHERE id = '85b7f054-89b5-4510-bbf7-1e745536efbd' AND business_id = '023250c0-18b3-4536-a080-5b1330db3394';

-- 6. Create cash_transactions for today's cash payments
INSERT INTO cash_transactions (business_id, transaction_type, amount, reference_type, reference_id, description, transaction_date)
SELECT
    p.business_id,
    'in',
    p.amount,
    'sale',
    p.sale_id,
    'Sale payment',
    p.payment_date
FROM payments p
WHERE p.payment_date = '2026-08-11'
  AND p.payment_mode = 'cash'
  AND NOT EXISTS (
      SELECT 1 FROM cash_transactions ct
      WHERE ct.reference_id = p.sale_id AND ct.transaction_date = p.payment_date
  );
