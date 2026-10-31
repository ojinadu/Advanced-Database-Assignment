-- =====================================================================
-- Portfolio 5: prove that a write on the primary appears on the replica.
-- Open this file in TWO pgAdmin tabs: one on the PRIMARY server and one on
-- the REPLICA server. Run the steps in order P1, R1, P2, R2, P3, R3.
-- =====================================================================
SET search_path TO harmetage;

-- P1 (PRIMARY). Note the current count of fee items.
SELECT count(*) AS fee_items FROM fee_item;

-- R1 (REPLICA). Same count. Both nodes agree.
SELECT count(*) AS fee_items FROM fee_item;

-- P2 (PRIMARY). Add a new fee item on the primary.
INSERT INTO fee_item (name) VALUES ('Excursion Levy') RETURNING fee_item_id, name;

-- R2 (REPLICA). It is already here. Run this within a second of P2 if you can.
SELECT fee_item_id, name FROM fee_item WHERE name = 'Excursion Levy';

-- P3 (PRIMARY). A bigger write: a payment, then check the replica.
INSERT INTO payment (student_id, term_id, amount, method, reference)
SELECT s.student_id, t.term_id, 10000, 'ONLINE', 'HPS-PAY-REPL-TEST'
FROM student s, term t JOIN academic_session a USING (session_id)
WHERE s.admission_no = 'HPS/2025/0001' AND a.name = '2025/2026' AND t.term_no = 1
RETURNING payment_id, reference, paid_at;

-- R3 (REPLICA). The payment is visible on the read-only node.
SELECT payment_id, reference, amount, paid_at FROM payment WHERE reference = 'HPS-PAY-REPL-TEST';

-- Clean up (PRIMARY only).
DELETE FROM payment WHERE reference = 'HPS-PAY-REPL-TEST';
DELETE FROM fee_item WHERE name = 'Excursion Levy';
