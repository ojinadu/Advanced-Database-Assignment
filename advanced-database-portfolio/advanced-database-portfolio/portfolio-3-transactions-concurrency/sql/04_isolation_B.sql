-- =====================================================================
-- Portfolio 3, Experiment 4: ISOLATION LEVELS.  *** TAB B (Parent paying online) ***
-- Order:  Part 1: A1, B1, A2, A3     Part 2: A4, B4, A5, A6     Part 3: B7, A7, B8
-- =====================================================================
SET search_path TO harmetage;

-- B1. A parent pays 25,000 online. Committed immediately (no BEGIN = auto commit).
INSERT INTO payment (student_id, term_id, amount, method, reference)
VALUES ((SELECT student_0001 FROM p3_ids), (SELECT term1 FROM p3_ids), 25000, 'ONLINE', 'HPS-PAY-TEST-ISO-1');

-- (now run A2 in Tab A)

-- B4. A second online payment of 25,000, during the REPEATABLE READ report.
INSERT INTO payment (student_id, term_id, amount, method, reference)
VALUES ((SELECT student_0001 FROM p3_ids), (SELECT term1 FROM p3_ids), 25000, 'ONLINE', 'HPS-PAY-TEST-ISO-2');

-- (now run A5 in Tab A)

-- B7. Start a payment but do NOT commit it yet.
BEGIN;
INSERT INTO payment (student_id, term_id, amount, method, reference)
VALUES ((SELECT student_0001 FROM p3_ids), (SELECT term1 FROM p3_ids), 99999, 'ONLINE', 'HPS-PAY-TEST-DIRTY');

-- (now run A7 in Tab A: it cannot see this row)

-- B8. Cancel it.
ROLLBACK;
