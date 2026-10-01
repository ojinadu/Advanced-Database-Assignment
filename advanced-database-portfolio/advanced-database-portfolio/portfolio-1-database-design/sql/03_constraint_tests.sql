-- =====================================================================
-- Harmetage Private School database
-- File 03: constraint tests
-- Every statement below except the last block SHOULD FAIL.
-- The error messages are the evidence that the constraints work.
-- Run: psql -U harmetage -d harmetage -f 03_constraint_tests.sql 2>&1 | tee ../evidence/03_constraint_tests_output.txt
-- =====================================================================

\set ON_ERROR_STOP off
SET search_path TO harmetage;

\echo ''
\echo '=== Test 1: CA1 above its 20-mark limit (CHECK constraint) ==='
UPDATE score SET ca1 = 25
WHERE (enrolment_id, term_id, allocation_id) =
      (SELECT enrolment_id, term_id, allocation_id FROM score LIMIT 1);

\echo ''
\echo '=== Test 2: writing to the generated total column directly ==='
UPDATE score SET total = 100
WHERE (enrolment_id, term_id, allocation_id) =
      (SELECT enrolment_id, term_id, allocation_id FROM score LIMIT 1);

\echo ''
\echo '=== Test 3: same student in a second class in the same session (UNIQUE student_id, session_id) ==='
INSERT INTO enrolment (student_id, class_arm_id, session_id)
SELECT e.student_id, ca.class_arm_id, ca.session_id
FROM enrolment e
JOIN class_arm ca ON ca.class_arm_id <> e.class_arm_id
LIMIT 1;

\echo ''
\echo '=== Test 4: enrolment whose session does not match its class arm (composite FK) ==='
INSERT INTO enrolment (student_id, class_arm_id, session_id)
SELECT (SELECT min(student_id) FROM student),
       (SELECT min(class_arm_id) FROM class_arm),
       (SELECT max(session_id) + 1 FROM academic_session);

\echo ''
\echo '=== Test 5: score using another class arm''s subject allocation (trigger) ==='
INSERT INTO score (enrolment_id, allocation_id, term_id, ca1, ca2, exam)
SELECT e.enrolment_id, sa.allocation_id, t.term_id, 10, 10, 40
FROM enrolment e
JOIN subject_allocation sa ON sa.class_arm_id <> e.class_arm_id
JOIN term t ON t.session_id = e.session_id AND t.term_no = 1
LIMIT 1;

\echo ''
\echo '=== Test 6: second primary guardian for one student (partial unique index) ==='
INSERT INTO student_guardian (student_id, guardian_id, relationship, is_primary)
SELECT s.student_id, g.guardian_id, 'GUARDIAN', true
FROM student s
CROSS JOIN guardian g
WHERE NOT EXISTS (SELECT 1 FROM student_guardian x
                  WHERE x.student_id = s.student_id AND x.guardian_id = g.guardian_id)
LIMIT 1;

\echo ''
\echo '=== Test 7: overlapping grade band (exclusion constraint) ==='
INSERT INTO grade_scale (grade, band, remark) VALUES ('A1', '[75,100]', 'Distinction');

\echo ''
\echo '=== Test 8: attendance on a Saturday (CHECK constraint) ==='
INSERT INTO attendance (enrolment_id, attendance_date, status)
VALUES ((SELECT min(enrolment_id) FROM enrolment), DATE '2025-09-13', 'PRESENT');

\echo ''
\echo '=== Test 9: negative payment amount (CHECK constraint) ==='
INSERT INTO payment (student_id, term_id, amount, method, reference)
VALUES ((SELECT min(student_id) FROM student), (SELECT min(term_id) FROM term),
        -5000, 'CASH', 'TEST-NEG-001');

\echo ''
\echo '=== Test 10: reused payment reference (UNIQUE constraint) ==='
INSERT INTO payment (student_id, term_id, amount, method, reference)
SELECT student_id, term_id, 1000, 'CASH', reference
FROM payment LIMIT 1;

\echo ''
\echo '=== Test 11: deleting a student who has enrolment records (FK restrict) ==='
DELETE FROM student WHERE student_id = (SELECT min(student_id) FROM student);

\echo ''
\echo '=== Test 12 (should SUCCEED): valid admission of a new JSS1 student, then rolled back ==='
BEGIN;
WITH s AS (
    INSERT INTO student (admission_no, first_name, last_name, date_of_birth, gender, admission_date)
    VALUES ('HPS/2025/9999', 'Test', 'Student', DATE '2014-05-01', 'F', DATE '2025-09-08')
    RETURNING student_id
)
INSERT INTO enrolment (student_id, class_arm_id, session_id)
SELECT s.student_id, ca.class_arm_id, ca.session_id
FROM s
JOIN class_arm ca ON ca.arm = 'A'
JOIN class_level l ON l.level_id = ca.level_id AND l.code = 'JSS1'
RETURNING enrolment_id, student_id, class_arm_id, session_id;
ROLLBACK;

\echo ''
\echo '=== Done ==='
