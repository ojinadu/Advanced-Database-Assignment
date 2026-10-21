-- =====================================================================
-- Portfolio 3: reset. Run the whole file (F5) to undo the experiments.
-- Safe to run at any time. Run 00_setup.sql again before redoing them.
-- =====================================================================
SET search_path TO harmetage;

-- Restore the changed score rows.
UPDATE score sc SET ca1 = b.ca1, ca2 = b.ca2, exam = b.exam
FROM p3_backup b
WHERE sc.enrolment_id = b.enrolment_id AND sc.term_id = b.term_id AND sc.allocation_id = b.allocation_id;

-- Remove test payments, enrolments, guardians and students.
DELETE FROM payment WHERE reference LIKE 'HPS-PAY-TEST-%';
DELETE FROM enrolment WHERE student_id IN (SELECT student_id FROM student WHERE admission_no LIKE 'HPS/2025/900%');
DELETE FROM student_guardian WHERE student_id IN (SELECT student_id FROM student WHERE admission_no LIKE 'HPS/2025/900%');
DELETE FROM student WHERE admission_no LIKE 'HPS/2025/900%';
DELETE FROM guardian WHERE phone = '08099990003';

-- Restore class capacity.
UPDATE class_arm SET capacity = 35 WHERE class_arm_id = (SELECT jss1a FROM p3_ids);

DROP TABLE IF EXISTS p3_backup;
DROP VIEW IF EXISTS p3_ids;

SELECT 'reset complete' AS status;
