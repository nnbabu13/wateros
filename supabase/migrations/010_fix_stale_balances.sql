-- Fix stale sale balance_amount and paid_amount
-- Recalculate from actual payments data

UPDATE sales s
SET
    paid_amount = COALESCE((
        SELECT SUM(p.amount)
        FROM payments p
        WHERE p.sale_id = s.id
    ), 0),
    balance_amount = GREATEST(
        s.total_amount - COALESCE((
            SELECT SUM(p.amount)
            FROM payments p
            WHERE p.sale_id = s.id
        ), 0),
        0
    ),
    status = CASE
        WHEN COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.sale_id = s.id), 0) >= s.total_amount THEN 'paid'
        WHEN COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.sale_id = s.id), 0) > 0 THEN 'partially_paid'
        ELSE 'pending'
    END
WHERE s.status != 'cancelled';

-- Fix stale customer current_balance
-- Formula: opening_balance + SUM(sales.total_amount) - SUM(payments.amount)

UPDATE customers c
SET current_balance = (
    COALESCE(c.opening_balance, 0)
    + COALESCE(
        (SELECT SUM(s.total_amount)
         FROM sales s
         WHERE s.customer_id = c.id
           AND s.status != 'cancelled'), 0)
    - COALESCE(
        (SELECT SUM(p.amount)
         FROM payments p
         WHERE p.customer_id = c.id), 0)
);
