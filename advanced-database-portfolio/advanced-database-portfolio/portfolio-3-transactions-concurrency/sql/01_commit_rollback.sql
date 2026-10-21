-- =====================================================================
-- Portfolio 3, Experiment 1: COMMIT, ROLLBACK and SAVEPOINT
-- ONE Query Tool tab. Highlight one BLOCK at a time (between the ----- lines)
-- and press F5. Screenshot the result of each block.
-- =====================================================================
SET search_path TO harmetage;

-- ---------------------------------------------------------------------
-- Block 1A: a successful admission. Four tables change together, then COMMIT.
-- ---------------------------------------------------------------------
BEGIN;

INSERT INTO student (admission_no, first_name, last_name, date_of_birth, gender, admission_date)
VALUES ('HPS/2025/9003', 'Commit', 'Example', DATE '2014-05-05', 'F', DATE '2025-09-08');

INSERT INTO guardian (first_name, last_name, phone, email, address)
VALUES ('Parent', 'Example', '08099990003', 'parent9003@example.com', '3 Test Close, Abuja');

INSERT INTO student_guardian (student_id, guardian_id, relationship, is_primary)
VALUES ((SELECT student_id FROM student WHERE admission_no = 'HPS/2025/9003'),
        (SELECT guardian_id FROM guardian WHERE phone = '08099990003'),
        'MOTHER', true);

INSERT INTO enrolment (student_id, class_arm_id, session_id)
SELECT (SELECT student_id FROM student WHERE admission_no = 'HPS/2025/9003'),
       ca.class_arm_id, ca.session_id
FROM class_arm ca JOIN class_level l USING (level_id) JOIN academic_session a USING (session_id)
WHERE l.code = 'JSS1' AND ca.arm = 'B' AND a.name = '2025/2026';

COMMIT;

-- Proof: all four rows exist.
SELECT s.admission_no, g.first_name || ' ' || g.last_name AS guardian, e.class_arm_id
FROM student s
JOIN student_guardian sg USING (student_id)
JOIN guardian g USING (guardian_id)
JOIN enrolment e USING (student_id)
WHERE s.admission_no = 'HPS/2025/9003';

-- ---------------------------------------------------------------------
-- Block 1B: an admission that FAILS half way. The guardian phone number is
-- already used (duplicate), so the whole transaction is rolled back.
-- Expect an ERROR. Then run Block 1C to prove the student was NOT saved.
-- ---------------------------------------------------------------------
BEGIN;

INSERT INTO student (admission_no, first_name, last_name, date_of_birth, gender, admission_date)
VALUES ('HPS/2025/9004', 'Rollback', 'Example', DATE '2014-06-06', 'M', DATE '2025-09-08');

INSERT INTO guardian (first_name, last_name, phone, email, address)
VALUES ('Duplicate', 'Phone', '08099990003', 'dup@example.com', 'Nowhere');   -- phone already exists

COMMIT;   -- PostgreSQL turns this into a ROLLBACK because the transaction failed

-- ---------------------------------------------------------------------
-- Block 1C: proof the failed admission left nothing behind (expect 0 rows).
-- ---------------------------------------------------------------------
SELECT * FROM student WHERE admission_no = 'HPS/2025/9004';

-- ---------------------------------------------------------------------
-- Block 1D: explicit ROLLBACK. The bursar records a payment, then cancels it.
-- ---------------------------------------------------------------------
BEGIN;

INSERT INTO payment (student_id, term_id, amount, method, reference)
VALUES ((SELECT student_0001 FROM p3_ids), (SELECT term1 FROM p3_ids),
        50000, 'CASH', 'HPS-PAY-TEST-ROLLBACK');

SELECT reference, amount FROM payment WHERE reference = 'HPS-PAY-TEST-ROLLBACK';  -- visible inside

ROLLBACK;

SELECT reference, amount FROM payment WHERE reference = 'HPS-PAY-TEST-ROLLBACK';  -- gone (0 rows)

-- ---------------------------------------------------------------------
-- Block 1E: SAVEPOINT. A teacher enters two scores. The second is invalid
-- (CA1 = 25, limit is 20). With a savepoint, only the bad one is undone and
-- the good one is still committed.
-- Highlight the WHOLE block including the final SELECT; the ERROR in the
-- middle is expected and the block carries on past it.
-- ---------------------------------------------------------------------
BEGIN;

UPDATE score SET ca1 = 17
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id      = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);

SAVEPOINT before_english;

UPDATE score SET ca1 = 25        -- invalid: CHECK (ca1 BETWEEN 0 AND 20)
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id      = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_eng FROM p3_ids);

ROLLBACK TO SAVEPOINT before_english;   -- undo only the English update

COMMIT;

-- Proof: Mathematics CA1 is 17, English CA1 is unchanged.
SELECT sub.code, sc.ca1
FROM score sc JOIN subject_allocation sa USING (allocation_id) JOIN subject sub USING (subject_id)
WHERE sc.enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND sc.term_id = (SELECT term1 FROM p3_ids)
  AND sub.code IN ('MTH', 'ENG');

-- Put Mathematics back to 18 for the next experiment.
UPDATE score SET ca1 = 18
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id      = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);
