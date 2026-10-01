-- =====================================================================
-- Harmetage Private School database
-- File 04 (pgAdmin version): verification queries
-- Shows the schema supports the school's key operations.
-- Run in pgAdmin Query Tool: highlight ONE block at a time and press F5.
-- =====================================================================

SET search_path TO harmetage;


-- === 1. Row counts per table ===
SELECT 'class_level' AS table_name, count(*) AS row_count FROM class_level
UNION ALL SELECT 'academic_session',   count(*) FROM academic_session
UNION ALL SELECT 'term',               count(*) FROM term
UNION ALL SELECT 'subject',            count(*) FROM subject
UNION ALL SELECT 'grade_scale',        count(*) FROM grade_scale
UNION ALL SELECT 'staff',              count(*) FROM staff
UNION ALL SELECT 'guardian',           count(*) FROM guardian
UNION ALL SELECT 'student',            count(*) FROM student
UNION ALL SELECT 'student_guardian',   count(*) FROM student_guardian
UNION ALL SELECT 'class_arm',          count(*) FROM class_arm
UNION ALL SELECT 'subject_allocation', count(*) FROM subject_allocation
UNION ALL SELECT 'enrolment',          count(*) FROM enrolment
UNION ALL SELECT 'score',              count(*) FROM score
UNION ALL SELECT 'attendance',         count(*) FROM attendance
UNION ALL SELECT 'fee_item',           count(*) FROM fee_item
UNION ALL SELECT 'fee_schedule',       count(*) FROM fee_schedule
UNION ALL SELECT 'payment',            count(*) FROM payment;


-- === 2. First term report card for student HPS/2025/0001 ===
SELECT sub.name                              AS subject,
       sc.ca1, sc.ca2, sc.exam, sc.total,
       g.grade, g.remark,
       st.first_name || ' ' || st.last_name  AS subject_teacher
FROM student s
JOIN enrolment e           ON e.student_id = s.student_id
JOIN score sc              ON sc.enrolment_id = e.enrolment_id
JOIN term t                ON t.term_id = sc.term_id AND t.term_no = 1
JOIN subject_allocation sa ON sa.allocation_id = sc.allocation_id
JOIN subject sub           ON sub.subject_id = sa.subject_id
JOIN staff st              ON st.staff_id = sa.teacher_id
JOIN grade_scale g         ON sc.total <@ g.band
WHERE s.admission_no = 'HPS/2025/0001'
ORDER BY sub.name;


-- === 3. First term class positions in JSS1A (top 10) ===
SELECT s.admission_no,
       s.first_name || ' ' || s.last_name  AS student,
       round(avg(sc.total), 2)             AS average,
       rank() OVER (ORDER BY avg(sc.total) DESC) AS position
FROM score sc
JOIN term t        ON t.term_id = sc.term_id AND t.term_no = 1
JOIN enrolment e   ON e.enrolment_id = sc.enrolment_id
JOIN student s     ON s.student_id = e.student_id
JOIN class_arm ca  ON ca.class_arm_id = e.class_arm_id AND ca.arm = 'A'
JOIN class_level l ON l.level_id = ca.level_id AND l.code = 'JSS1'
GROUP BY s.admission_no, s.first_name, s.last_name
ORDER BY position
LIMIT 10;


-- === 4. Third term fee debtors (balance = fees due - payments) ===
WITH due AS (
    SELECT e.student_id, t.term_id, SUM(fs.amount) AS amount_due
    FROM enrolment e
    JOIN class_arm ca    ON ca.class_arm_id = e.class_arm_id
    JOIN term t          ON t.session_id = e.session_id AND t.term_no = 3
    JOIN fee_schedule fs ON fs.level_id = ca.level_id AND fs.term_id = t.term_id
    GROUP BY e.student_id, t.term_id
),
paid AS (
    SELECT student_id, term_id, SUM(amount) AS amount_paid
    FROM payment GROUP BY student_id, term_id
)
SELECT s.admission_no,
       s.first_name || ' ' || s.last_name        AS student,
       d.amount_due,
       COALESCE(p.amount_paid, 0)                AS amount_paid,
       d.amount_due - COALESCE(p.amount_paid, 0) AS balance
FROM due d
JOIN student s    ON s.student_id = d.student_id
LEFT JOIN paid p  ON p.student_id = d.student_id AND p.term_id = d.term_id
WHERE d.amount_due - COALESCE(p.amount_paid, 0) > 0
ORDER BY balance DESC, s.admission_no
LIMIT 15;


-- === 5. First term attendance rate by class arm ===
SELECT l.code || ca.arm AS class,
       round(100.0 * count(*) FILTER (WHERE a.status IN ('PRESENT', 'LATE')) / count(*), 1) AS attendance_pct
FROM attendance a
JOIN enrolment e   ON e.enrolment_id = a.enrolment_id
JOIN class_arm ca  ON ca.class_arm_id = e.class_arm_id
JOIN class_level l ON l.level_id = ca.level_id
GROUP BY l.sort_order, l.code, ca.arm
ORDER BY l.sort_order, ca.arm;


-- === 6. Siblings sharing a guardian ===
SELECT g.first_name || ' ' || g.last_name AS guardian,
       string_agg(s.first_name || ' (' || s.admission_no || ')', ', ' ORDER BY s.admission_no) AS children
FROM guardian g
JOIN student_guardian sg ON sg.guardian_id = g.guardian_id
JOIN student s           ON s.student_id = sg.student_id
GROUP BY g.guardian_id, g.first_name, g.last_name
HAVING count(*) > 1
ORDER BY guardian
LIMIT 10;
