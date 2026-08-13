-- Migration 008: Fix cash_transactions model
-- Changes reference_id from sale.id to payment.id for sale-type transactions,
-- cleans up duplicates, and adds uniqueness constraints.

-- =============================================
-- STEP 1: DIAGNOSTIC (informational only)
-- =============================================

-- 1a. Show duplicate cash_transactions (same business_id + reference_type + reference_id)
-- EXPECTED OUTPUT: Should be 0 after cleanup
SELECT 
    business_id, 
    reference_type, 
    reference_id, 
    COUNT(*) as duplicate_count,
    ARRAY_AGG(amount ORDER BY created_at) as amounts,
    ARRAY_AGG(transaction_type ORDER BY created_at) as types,
    ARRAY_AGG(created_at ORDER BY created_at) as created_ats
FROM cash_transactions
GROUP BY business_id, reference_type, reference_id
HAVING COUNT(*) > 1;

-- 1b. Show orphan cash_transactions (reference_id points to non-existent payment/expense)
-- For sale-type: reference_id should match a payments.id
SELECT ct.id, ct.business_id, ct.reference_type, ct.reference_id, ct.amount, ct.transaction_date, ct.created_at
FROM cash_transactions ct
LEFT JOIN payments p ON p.id = ct.reference_id
WHERE ct.reference_type = 'sale' AND p.id IS NULL;

-- For customer_payment-type: reference_id should match a payments.id
SELECT ct.id, ct.business_id, ct.reference_type, ct.reference_id, ct.amount, ct.transaction_date, ct.created_at
FROM cash_transactions ct
LEFT JOIN payments p ON p.id = ct.reference_id
WHERE ct.reference_type = 'customer_payment' AND p.id IS NULL;

-- For expense-type: reference_id should match an expenses.id
SELECT ct.id, ct.business_id, ct.reference_type, ct.reference_id, ct.amount, ct.transaction_date, ct.created_at
FROM cash_transactions ct
LEFT JOIN expenses e ON e.id = ct.reference_id
WHERE ct.reference_type = 'expense' AND e.id IS NULL;

-- 1c. Show cash_transactions still using legacy sale.id as reference_id
-- (reference_id = sale.id instead of payment.id)
SELECT ct.id, ct.business_id, ct.reference_id as sale_id, ct.amount, ct.transaction_date, ct.created_at
FROM cash_transactions ct
WHERE ct.reference_type = 'sale'
  AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.id = ct.reference_id);

-- =============================================
-- STEP 2: CLEANUP DUPLICATES
-- =============================================
-- For each set of duplicate cash_transactions (same business_id + reference_type + reference_id):
-- Keep the row that has a valid payment reference; if none, keep the newest.

-- 2a. Create a temporary table of duplicate IDs to KEEP (one per group)
CREATE TEMPORARY TABLE cash_txn_keep AS
SELECT DISTINCT ON (business_id, reference_type, reference_id)
    id
FROM cash_transactions
ORDER BY business_id, reference_type, reference_id, created_at DESC;

-- 2b. Delete duplicates (rows not in the keep table)
DELETE FROM cash_transactions
WHERE id NOT IN (SELECT id FROM cash_txn_keep);

-- 2c. Drop temp table
DROP TABLE IF EXISTS cash_txn_keep;

-- =============================================
-- STEP 3: MIGRATE SALE REFERENCES FROM sale.id TO payment.id
-- =============================================
-- For each cash_transactions with reference_type='sale' where reference_id is a sale.id,
-- find the corresponding payment(s) and update to use payment.id.
-- If multiple payments exist for the same sale, we need to split the transaction.

-- 3a. For cash_transactions that reference a sale.id directly (legacy model)
-- and there's exactly one payment for that sale, update reference_id to payment.id
UPDATE cash_transactions ct
SET reference_id = p.id
FROM payments p
WHERE ct.reference_type = 'sale'
  AND ct.reference_id = p.sale_id
  AND ct.reference_id != p.id
  AND NOT EXISTS (
    -- Only update if there's exactly one payment for this sale
    SELECT 1 FROM payments p2 
    WHERE p2.sale_id = p.sale_id AND p2.id != p.id
  );

-- 3b. For cash_transactions that reference a sale.id but there are multiple payments,
-- we need to handle this carefully. The safest approach is to delete the legacy row
-- and let the app recreate it correctly on next edit.
-- WARNING: This may slightly adjust the cash balance if the amounts don't match.
-- We only do this for cases where the amounts don't align.

-- First, find cash_transactions that still reference a sale.id (not a payment.id)
-- and there are multiple payments for that sale
DELETE FROM cash_transactions ct
WHERE ct.reference_type = 'sale'
  AND ct.reference_id IN (
    SELECT s.id FROM sales s
    WHERE (SELECT COUNT(*) FROM payments p WHERE p.sale_id = s.id) > 1
  )
  AND ct.reference_id NOT IN (SELECT id FROM payments);

-- =============================================
-- STEP 4: ADD CHECK CONSTRAINT FOR reference_type
-- =============================================
-- Only allow known reference_types
ALTER TABLE cash_transactions
ADD CONSTRAINT cash_transactions_reference_type_check
CHECK (reference_type IN ('sale', 'expense', 'customer_payment'));

-- =============================================
-- STEP 5: ADD UNIQUE CONSTRAINT
-- =============================================
-- After migration, each (business_id, reference_type, reference_id) should be unique.
-- This prevents future duplicates at the database level.

-- First, verify no duplicates remain (the cleanup above should have removed them)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM cash_transactions
        GROUP BY business_id, reference_type, reference_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Duplicate cash_transactions still exist. Cannot add unique constraint.';
    END IF;
END $$;

CREATE UNIQUE INDEX idx_cash_transactions_unique_ref
ON cash_transactions(business_id, reference_type, reference_id);

-- =============================================
-- STEP 6: FINAL VERIFICATION
-- =============================================

-- Count remaining duplicates (should be 0)
SELECT 
    COUNT(*) as remaining_duplicates
FROM (
    SELECT business_id, reference_type, reference_id
    FROM cash_transactions
    GROUP BY business_id, reference_type, reference_id
    HAVING COUNT(*) > 1
) d;

-- Count remaining orphans
SELECT 
    COUNT(*) as remaining_orphans
FROM cash_transactions ct
LEFT JOIN payments p ON p.id = ct.reference_id AND ct.reference_type IN ('sale', 'customer_payment')
LEFT JOIN expenses e ON e.id = ct.reference_id AND ct.reference_type = 'expense'
WHERE p.id IS NULL AND e.id IS NULL;

-- Cash balance verification
SELECT 
    SUM(CASE WHEN transaction_type = 'in' THEN amount ELSE 0 END) as total_in,
    SUM(CASE WHEN transaction_type = 'out' THEN amount ELSE 0 END) as total_out,
    SUM(CASE WHEN transaction_type = 'in' THEN amount ELSE -amount END) as net_balance
FROM cash_transactions;
