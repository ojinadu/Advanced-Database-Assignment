-- =====================================================================
-- Portfolio 3, Experiment 4: ISOLATION LEVELS.  *** TAB A (Bursar) ***
-- The bursar totals a student's payments twice inside one report
-- while a parent pays online in between.
-- Order:  Part 1: A1, B1, A2, A3     Part 2: A4, B4, A5, A6     Part 3: B7, A7, B8
-- =====================================================================
SET search_path TO harmetage;

-- ===== PART 1: READ COMMITTED (the default) allows a NON-REPEATABLE READ =====

-- A1. Start a report and total the payments for student 0001, term 1.
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT coalesce(sum(amount), 0) AS total_paid FROM payment
WHERE student_id = (SELECT student_0001 FROM p3_ids) AND term_id = (SELECT term1 FROM p3_ids);

-- (now run B1 in Tab B: a payment of 25,000 arrives and is committed)

-- A2. Same query, same transaction: the total is now 25,000 HIGHER.
--     The same read gave two different answers = non-repeatable read.
SELECT coalesce(sum(amount), 0) AS total_paid FROM payment
WHERE student_id = (SELECT student_0001 FROM p3_ids) AND term_id = (SELECT term1 FROM p3_ids);

-- A3. End the report.
COMMIT;

-- ===== PART 2: REPEATABLE READ gives a stable snapshot =====

-- A4. Same report, but at REPEATABLE READ.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT coalesce(sum(amount), 0) AS total_paid FROM payment
WHERE student_id = (SELECT student_0001 FROM p3_ids) AND term_id = (SELECT term1 FROM p3_ids);

-- (now run B4 in Tab B: another 25,000 payment is committed)

-- A5. Same query again: the total has NOT changed. The report sees a
--     consistent snapshot taken when the transaction began.
SELECT coalesce(sum(amount), 0) AS total_paid FROM payment
WHERE student_id = (SELECT student_0001 FROM p3_ids) AND term_id = (SELECT term1 FROM p3_ids);

COMMIT;

-- A6. Outside the transaction, the new payment is visible straight away.
SELECT coalesce(sum(amount), 0) AS total_paid FROM payment
WHERE student_id = (SELECT student_0001 FROM p3_ids) AND term_id = (SELECT term1 FROM p3_ids);

-- ===== PART 3: DIRTY READS never happen in PostgreSQL =====

-- (first run B7 in Tab B: it inserts a payment but does NOT commit)

-- A7. Look for the uncommitted payment. 0 rows: it is invisible to us.
--     PostgreSQL treats READ UNCOMMITTED as READ COMMITTED, so dirty reads
--     are impossible at every isolation level.
SELECT reference, amount FROM payment WHERE reference = 'HPS-PAY-TEST-DIRTY';

-- (now run B8 in Tab B to roll it back)
