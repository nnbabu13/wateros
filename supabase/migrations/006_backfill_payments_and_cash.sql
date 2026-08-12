-- Backfill missing payments, cash_transactions, and bank balances for existing sales
-- Run this ONCE to fix data from sales created before the payment/cash sync was added

-- 1. Insert missing payment records for sales with paid_amount > 0
INSERT INTO payments (id, business_id, customer_id, sale_id, amount, payment_mode, payment_date, created_at)
SELECT
  gen_random_uuid(),
  s.business_id,
  s.customer_id,
  s.id,
  s.paid_amount,
  CASE WHEN s.payment_mode = 'credit' THEN 'cash' ELSE s.payment_mode END,
  s.invoice_date,
  s.created_at
FROM sales s
WHERE s.paid_amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM payments p WHERE p.sale_id = s.id
  );

-- 2. Insert cash_transactions for cash sales
INSERT INTO cash_transactions (id, business_id, transaction_type, amount, reference_type, reference_id, description, transaction_date, created_at)
SELECT
  gen_random_uuid(),
  s.business_id,
  'in',
  s.paid_amount,
  'sale',
  s.id,
  'Sale ' || s.invoice_number,
  s.invoice_date,
  s.created_at
FROM sales s
WHERE s.paid_amount > 0
  AND s.payment_mode = 'cash'
  AND NOT EXISTS (
    SELECT 1 FROM cash_transactions ct WHERE ct.reference_id = s.id AND ct.reference_type = 'sale'
  );

-- 3. Insert bank_transactions and update bank_accounts for UPI/bank_transfer sales
-- First, create bank_transactions
INSERT INTO bank_transactions (id, business_id, bank_account_id, transaction_type, amount, reference_type, reference_id, description, transaction_date, created_at)
SELECT
  gen_random_uuid(),
  s.business_id,
  ba.id,
  'in',
  s.paid_amount,
  'sale',
  s.id,
  'Sale ' || s.invoice_number || ' (' || UPPER(s.payment_mode) || ')',
  s.invoice_date,
  s.created_at
FROM sales s
JOIN bank_accounts ba ON ba.business_id = s.business_id AND ba.is_active = true
WHERE s.paid_amount > 0
  AND s.payment_mode IN ('upi', 'bank_transfer')
  AND NOT EXISTS (
    SELECT 1 FROM bank_transactions bt WHERE bt.reference_id = s.id AND bt.reference_type = 'sale'
  );

-- Then update bank_accounts balances
UPDATE bank_accounts ba
SET balance = balance + (
  SELECT COALESCE(SUM(s.paid_amount), 0)
  FROM sales s
  WHERE s.business_id = ba.business_id
    AND s.paid_amount > 0
    AND s.payment_mode IN ('upi', 'bank_transfer')
    AND EXISTS (
      SELECT 1 FROM bank_transactions bt
      WHERE bt.reference_id = s.id
        AND bt.reference_type = 'sale'
        AND bt.bank_account_id = ba.id
        AND bt.transaction_type = 'in'
    )
),
updated_at = NOW()
WHERE ba.is_active = true;

-- 4. Verify results
SELECT
  (SELECT COUNT(*) FROM sales WHERE paid_amount > 0) AS total_paid_sales,
  (SELECT COUNT(DISTINCT sale_id) FROM payments WHERE sale_id IS NOT NULL) AS payments_created,
  (SELECT COUNT(*) FROM cash_transactions WHERE reference_type = 'sale') AS cash_txns_created,
  (SELECT COUNT(*) FROM bank_transactions WHERE reference_type = 'sale') AS bank_txns_created;
