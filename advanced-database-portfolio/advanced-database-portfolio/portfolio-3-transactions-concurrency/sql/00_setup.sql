-- =====================================================================
-- Portfolio 3: Transactions and Concurrency
-- File 00: setup. Run the whole file once (F5) before the experiments.
-- Creates a helper view with the IDs the experiments use, two test
-- students who are not yet enrolled, and a backup of the rows we will change.
-- =====================================================================
SET search_path TO harmetage;

DROP VIEW IF EXISTS p3_ids;
DROP TABLE IF EXISTS p3_backup;

-- Two test students, not enrolled anywhere yet.
INSERT INTO student (admission_no, first_name, last_name, date_of_birth, gender, admission_date)
VALUES ('HPS/2025/9001', 'Testa', 'Alpha', DATE '2014-03-01', 'F', DATE '2025-09-08'),
       ('HPS/2025/9002', 'Testo', 'Beta',  DATE '2014-04-01', 'M', DATE '2025-09-08')
ON CONFLICT (admission_no) DO NOTHING;

-- One place to look up every ID the experiments need.
CREATE VIEW p3_ids AS
SELECT
  (SELECT e.enrolment_id FROM enrolment e JOIN student s USING (student_id)
     WHERE s.admission_no = 'HPS/2025/0001')                                  AS enrol_0001,
  (SELECT e.enrolment_id FROM enrolment e JOIN student s USING (student_id)
     WHERE s.admission_no = 'HPS/2025/0002')                                  AS enrol_0002,
  (SELECT t.term_id FROM term t JOIN academic_session a USING (session_id)
     WHERE a.name = '2025/2026' AND t.term_no = 1)                            AS term1,
  (SELECT ca.class_arm_id FROM class_arm ca
     JOIN class_level l USING (level_id) JOIN academic_session a USING (session_id)
     WHERE l.code = 'JSS1' AND ca.arm = 'A' AND a.name = '2025/2026')         AS jss1a,
  (SELECT a.session_id FROM academic_session a WHERE a.name = '2025/2026')   AS session_2526,
  (SELECT sa.allocation_id FROM subject_allocation sa
     JOIN subject sub USING (subject_id)
     JOIN class_arm ca USING (class_arm_id)
     JOIN class_level l USING (level_id) JOIN academic_session a USING (session_id)
     WHERE sub.code = 'MTH' AND l.code = 'JSS1' AND ca.arm = 'A' AND a.name = '2025/2026') AS alloc_math,
  (SELECT sa.allocation_id FROM subject_allocation sa
     JOIN subject sub USING (subject_id)
     JOIN class_arm ca USING (class_arm_id)
     JOIN class_level l USING (level_id) JOIN academic_session a USING (session_id)
     WHERE sub.code = 'ENG' AND l.code = 'JSS1' AND ca.arm = 'A' AND a.name = '2025/2026') AS alloc_eng,
  (SELECT student_id FROM student WHERE admission_no = 'HPS/2025/9001')     AS test_student_1,
  (SELECT student_id FROM student WHERE admission_no = 'HPS/2025/9002')     AS test_student_2,
  (SELECT student_id FROM student WHERE admission_no = 'HPS/2025/0001')     AS student_0001;

-- Backup of the score rows the experiments change, so 06_reset can restore them.
CREATE TABLE p3_backup AS
SELECT sc.enrolment_id, sc.allocation_id, sc.term_id, sc.ca1, sc.ca2, sc.exam
FROM score sc, p3_ids i
WHERE sc.term_id = i.term1
  AND sc.enrolment_id IN (i.enrol_0001, i.enrol_0002)
  AND sc.allocation_id IN (i.alloc_math, i.alloc_eng);

-- Start from a known value: Mathematics CA1 for student 0001 = 18.
UPDATE score SET ca1 = 18
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- JSS1A has 30 students. Set capacity to 31 so exactly ONE seat is left.
UPDATE class_arm SET capacity = 31 WHERE class_arm_id = (SELECT jss1a FROM p3_ids);

-- Show the IDs and the starting state (screenshot this).
SELECT * FROM p3_ids;
SELECT count(*) AS students_in_jss1a,
       (SELECT capacity FROM class_arm WHERE class_arm_id = (SELECT jss1a FROM p3_ids)) AS capacity
FROM enrolment WHERE class_arm_id = (SELECT jss1a FROM p3_ids);
