-- =====================================================================
-- Harmetage Private School database
-- Portfolio 2: execution plans (EXPLAIN ANALYZE)
--
-- 1. Highlight the two SET lines below and press F5 (once per Query Tool tab).
-- 2. Highlight ONE EXPLAIN block at a time, press F5, screenshot the plan.
-- 3. Run each block TWICE and record the second "Execution Time"
--    (the first run may be slower while data is loaded into memory).
-- 4. Run this whole file BEFORE creating the indexes, then again AFTER.
-- =====================================================================

SET search_path TO harmetage;
SET max_parallel_workers_per_gather = 0;  -- simpler plans, easier to compare
SET jit = off;                            -- stops compile time distorting small queries

-- ---- Q1: Students absent on one day (attendance register lookup) ----
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.admission_no, s.first_name, s.last_name, l.code || ca.arm AS class
FROM attendance a
JOIN enrolment e   ON e.enrolment_id = a.enrolment_id
JOIN student s     ON s.student_id = e.student_id
JOIN class_arm ca  ON ca.class_arm_id = e.class_arm_id
JOIN class_level l ON l.level_id = ca.level_id
WHERE a.attendance_date = DATE '2025-10-14'
  AND a.status = 'ABSENT'
ORDER BY class, s.last_name;

-- ---- Q2: Scores entered by one teacher in December 2025 (audit by the principal) ----
EXPLAIN (ANALYZE, BUFFERS)
SELECT sc.enrolment_id, sub.name AS subject, sc.term_id, sc.total, sc.recorded_at
FROM score sc
JOIN subject_allocation sa ON sa.allocation_id = sc.allocation_id
JOIN subject sub           ON sub.subject_id = sa.subject_id
WHERE sc.recorded_by = (SELECT staff_id FROM staff WHERE staff_no = 'HPS-ST-004')
  AND sc.recorded_at >= TIMESTAMPTZ '2025-12-01'
  AND sc.recorded_at <  TIMESTAMPTZ '2026-01-01'
ORDER BY sc.recorded_at, sub.name;

-- ---- Q3: Average score per subject and teacher for first term 2025/2026 ----
EXPLAIN (ANALYZE, BUFFERS)
SELECT sub.name AS subject,
       st.first_name || ' ' || st.last_name AS teacher,
       count(*) AS scores,
       round(avg(sc.total), 2) AS average_total
FROM score sc
JOIN subject_allocation sa ON sa.allocation_id = sc.allocation_id
JOIN subject sub           ON sub.subject_id = sa.subject_id
JOIN staff st              ON st.staff_id = sa.teacher_id
WHERE sc.term_id = (SELECT t.term_id
                    FROM term t
                    JOIN academic_session s ON s.session_id = t.session_id
                    WHERE s.name = '2025/2026' AND t.term_no = 1)
GROUP BY sub.name, st.first_name, st.last_name
ORDER BY average_total DESC;

-- ---- Q4: Payment history for one student (bursar receipt lookup) ----
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.paid_at::date AS paid_on, t.term_no, p.amount, p.method, p.reference
FROM student s
JOIN payment p ON p.student_id = s.student_id
JOIN term t    ON t.term_id = p.term_id
WHERE s.admission_no = 'HPS/2025/0001'
ORDER BY p.paid_at;

-- ---- Q5: First term class positions for SS2A, 2025/2026 (top 10) ----
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.admission_no,
       s.first_name || ' ' || s.last_name AS student,
       round(avg(sc.total), 2) AS average,
       rank() OVER (ORDER BY avg(sc.total) DESC) AS position
FROM academic_session ses
JOIN class_arm ca  ON ca.session_id = ses.session_id
JOIN class_level l ON l.level_id = ca.level_id
JOIN enrolment e   ON e.class_arm_id = ca.class_arm_id
JOIN student s     ON s.student_id = e.student_id
JOIN term t        ON t.session_id = ses.session_id AND t.term_no = 1
JOIN score sc      ON sc.enrolment_id = e.enrolment_id AND sc.term_id = t.term_id
WHERE ses.name = '2025/2026' AND l.code = 'SS2' AND ca.arm = 'A'
GROUP BY s.student_id, s.admission_no, s.first_name, s.last_name
ORDER BY position
LIMIT 10;

-- ---- Q6A: Absences per class in October 2025 - SLOW version (function on the date column) ----
EXPLAIN (ANALYZE, BUFFERS)
SELECT l.code || ca.arm AS class, count(*) AS absences
FROM attendance a
JOIN enrolment e   ON e.enrolment_id = a.enrolment_id
JOIN class_arm ca  ON ca.class_arm_id = e.class_arm_id
JOIN class_level l ON l.level_id = ca.level_id
WHERE a.status = 'ABSENT'
  AND EXTRACT(YEAR  FROM a.attendance_date) = 2025
  AND EXTRACT(MONTH FROM a.attendance_date) = 10
GROUP BY l.sort_order, l.code, ca.arm
ORDER BY l.sort_order, ca.arm;

-- ---- Q6B: Absences per class in October 2025 - REWRITTEN version (date range) ----
EXPLAIN (ANALYZE, BUFFERS)
SELECT l.code || ca.arm AS class, count(*) AS absences
FROM attendance a
JOIN enrolment e   ON e.enrolment_id = a.enrolment_id
JOIN class_arm ca  ON ca.class_arm_id = e.class_arm_id
JOIN class_level l ON l.level_id = ca.level_id
WHERE a.status = 'ABSENT'
  AND a.attendance_date >= DATE '2025-10-01'
  AND a.attendance_date <  DATE '2025-11-01'
GROUP BY l.sort_order, l.code, ca.arm
ORDER BY l.sort_order, ca.arm;
