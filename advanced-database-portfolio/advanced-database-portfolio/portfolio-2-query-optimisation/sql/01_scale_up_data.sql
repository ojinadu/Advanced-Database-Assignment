-- =====================================================================
-- Harmetage Private School database
-- Portfolio 2: Query Processing and Optimisation
-- File 01: scale-up data (history for 8 earlier sessions)
--
-- Why: with 360 students every query is instant, so indexes show no
-- benefit. This script adds eight earlier sessions (2017/2018 to 2024/2025)
-- so the tables are big enough for execution plans to differ.
--
-- Each earlier session has 6 level x 6 arms x 32 students = 1,152 students.
-- These students are synthetic and are marked GRADUATED. They have no
-- guardian records, which Portfolio 2 does not need.
--
-- Run ONCE, after Portfolio 1 scripts 01 and 02. Takes about 1 to 2 minutes.
-- To reload, rerun Portfolio 1 scripts 01 and 02 first.
-- =====================================================================

SET search_path TO harmetage;
SELECT setseed(0.17);

-- Stop if the bulk data is already there.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM academic_session WHERE name = '2025/2026') THEN
        RAISE EXCEPTION 'Run Portfolio 1 scripts 01 and 02 first.';
    END IF;
    IF EXISTS (SELECT 1 FROM academic_session WHERE name = '2017/2018') THEN
        RAISE EXCEPTION 'Bulk data is already loaded. To reload, rerun Portfolio 1 scripts 01 and 02 first.';
    END IF;
END;
$$;

CREATE TEMP TABLE names AS
SELECT
    ARRAY['Adebayo','Chinedu','Emeka','Tunde','Yusuf','Olumide','Ifeanyi','Segun','Bello','Obinna',
          'Kelechi','Ibrahim','Femi','Chukwudi','Musa','Babatunde','Uchenna','Sani','Tobi','Nnamdi'] AS male,
    ARRAY['Fatima','Aisha','Blessing','Chioma','Hauwa','Zainab','Amaka','Kemi','Halima','Ngozi',
          'Funmilayo','Adaeze','Maryam','Bisola','Ifeoma','Hadiza','Temitope','Chiamaka','Rukayat','Ebere'] AS female,
    ARRAY['Adeyemi','Okonkwo','Abubakar','Nwosu','Ogunleye','Eze','Danjuma','Okoro','Lawal','Ibe',
          'Suleiman','Afolabi','Nnaji','Yakubu','Olaniyan','Obi','Balogun','Umar','Chukwu','Aliyu',
          'Oyelaran','Mohammed','Anozie','Bakare'] AS surname;

-- ---------------------------------------------------------------------
-- Sessions and terms
-- ---------------------------------------------------------------------
INSERT INTO academic_session (name, start_date, end_date)
SELECT format('%s/%s', y, y + 1), make_date(y, 9, 8), make_date(y + 1, 7, 24)
FROM generate_series(2017, 2024) AS y;

INSERT INTO term (session_id, term_no, start_date, end_date)
SELECT s.session_id, t.term_no,
       make_date(EXTRACT(YEAR FROM s.start_date)::int + t.y_off, t.sm, t.sd),
       make_date(EXTRACT(YEAR FROM s.start_date)::int + t.y_off, t.em, t.ed)
FROM academic_session s
CROSS JOIN (VALUES (1, 0, 9, 8, 12, 12),
                   (2, 1, 1, 5,  4,  2),
                   (3, 1, 4, 20, 7, 24)) AS t (term_no, y_off, sm, sd, em, ed)
WHERE s.name <> '2025/2026';

-- Fees were lower in earlier years (8 percent cheaper for each year back).
INSERT INTO fee_schedule (level_id, term_id, fee_item_id, amount)
SELECT l.level_id, t.term_id, fi.fee_item_id,
       round(
         CASE fi.name
              WHEN 'Tuition'          THEN CASE l.stage WHEN 'JUNIOR' THEN 185000 ELSE 210000 END
              WHEN 'Development Levy' THEN 15000
              WHEN 'ICT'              THEN 10000
              WHEN 'Laboratory'       THEN 12000
         END * power(0.92::numeric, 2025 - EXTRACT(YEAR FROM s.start_date)::int),
         -2)
FROM class_level l
CROSS JOIN term t
JOIN academic_session s ON s.session_id = t.session_id
CROSS JOIN fee_item fi
WHERE s.name <> '2025/2026'
  AND (fi.name <> 'Development Levy' OR t.term_no = 1)
  AND (fi.name <> 'Laboratory' OR l.stage = 'SENIOR');

-- ---------------------------------------------------------------------
-- Class arms (A to F for every level) and subject allocations
-- Form teachers are left empty: there are only 30 teachers for 36 arms.
-- ---------------------------------------------------------------------
INSERT INTO class_arm (level_id, session_id, arm, capacity)
SELECT l.level_id, s.session_id, a.arm, 35
FROM class_level l
CROSS JOIN academic_session s
CROSS JOIN (VALUES ('A'), ('B'), ('C'), ('D'), ('E'), ('F')) AS a (arm)
WHERE s.name <> '2025/2026';

WITH t AS (SELECT staff_id, row_number() OVER (ORDER BY staff_id) - 1 AS idx
           FROM staff WHERE role = 'TEACHER')
INSERT INTO subject_allocation (class_arm_id, subject_id, teacher_id)
SELECT ca.class_arm_id, s.subject_id, t.staff_id
FROM class_arm ca
JOIN academic_session ses ON ses.session_id = ca.session_id AND ses.name <> '2025/2026'
JOIN class_level l        ON l.level_id = ca.level_id
JOIN subject s            ON s.stage IN (l.stage, 'BOTH')
JOIN t                    ON t.idx = ((s.subject_id - 1) * 2
                                      + CASE WHEN l.stage = 'SENIOR' THEN 1 ELSE 0 END) % 30;

-- ---------------------------------------------------------------------
-- Students and enrolments
-- ---------------------------------------------------------------------
CREATE TEMP TABLE bulk_plan AS
SELECT (row_number() OVER (ORDER BY ca.session_id, l.sort_order, ca.arm, k))::int + 1000 AS n,
       ca.class_arm_id, ca.session_id, l.sort_order AS lvl, ses.start_date
FROM class_arm ca
JOIN academic_session ses ON ses.session_id = ca.session_id AND ses.name <> '2025/2026'
JOIN class_level l        ON l.level_id = ca.level_id
CROSS JOIN generate_series(1, 32) AS k;

ALTER TABLE bulk_plan ADD COLUMN adm varchar(15);
UPDATE bulk_plan
SET adm = format('HPS/%s/%s', EXTRACT(YEAR FROM start_date)::int - (lvl - 1), lpad(n::text, 5, '0'));

INSERT INTO student (admission_no, first_name, last_name, date_of_birth, gender, admission_date, status)
SELECT p.adm,
       CASE WHEN p.n % 2 = 0 THEN nm.female[1 + (p.n * 7)  % array_length(nm.female, 1)]
            ELSE                  nm.male[1 + (p.n * 3)  % array_length(nm.male, 1)] END,
       nm.surname[1 + (p.n * 11) % array_length(nm.surname, 1)],
       p.start_date - ((10 + p.lvl) * 365 + (random() * 364)::int),
       CASE WHEN p.n % 2 = 0 THEN 'F' ELSE 'M' END,
       p.start_date,
       'GRADUATED'
FROM bulk_plan p
CROSS JOIN names nm
ORDER BY p.n;

INSERT INTO enrolment (student_id, class_arm_id, session_id, enrolled_on)
SELECT s.student_id, p.class_arm_id, p.session_id, p.start_date
FROM bulk_plan p
JOIN student s ON s.admission_no = p.adm;

-- ---------------------------------------------------------------------
-- Scores for all three terms of every earlier session.
-- The consistency trigger is switched off during the bulk load only,
-- because the data is generated to be consistent. It is switched back on
-- straight after, and a check at the end proves nothing slipped through.
-- ---------------------------------------------------------------------
ALTER TABLE score DISABLE TRIGGER trg_score_consistency;

INSERT INTO score (enrolment_id, allocation_id, term_id, ca1, ca2, exam, recorded_by, recorded_at)
SELECT e.enrolment_id, sa.allocation_id, t.term_id,
       round((6  + random() * 14)::numeric, 0),
       round((6  + random() * 14)::numeric, 0),
       round((15 + random() * 45)::numeric, 0),
       sa.teacher_id,
       (t.end_date - 5) + TIME '14:00'
FROM enrolment e
JOIN academic_session ses  ON ses.session_id = e.session_id AND ses.name <> '2025/2026'
JOIN subject_allocation sa ON sa.class_arm_id = e.class_arm_id
JOIN term t                ON t.session_id = e.session_id;

ALTER TABLE score ENABLE TRIGGER trg_score_consistency;

-- ---------------------------------------------------------------------
-- First term attendance for every earlier session
-- ---------------------------------------------------------------------
INSERT INTO attendance (enrolment_id, attendance_date, status, recorded_by)
SELECT enrolment_id, day,
       CASE WHEN x < 0.90 THEN 'PRESENT'
            WHEN x < 0.95 THEN 'LATE'
            WHEN x < 0.99 THEN 'ABSENT'
            ELSE 'EXCUSED' END,
       NULL
FROM (
    SELECT e.enrolment_id, d::date AS day, random() AS x
    FROM enrolment e
    JOIN academic_session ses ON ses.session_id = e.session_id AND ses.name <> '2025/2026'
    JOIN term t               ON t.session_id = e.session_id AND t.term_no = 1
    CROSS JOIN LATERAL generate_series(t.start_date, t.end_date, INTERVAL '1 day') AS d
    WHERE EXTRACT(ISODOW FROM d) BETWEEN 1 AND 5
) days;

-- ---------------------------------------------------------------------
-- Fee payments: 85 percent pay in full, 10 percent pay 60 percent,
-- 5 percent pay nothing.
-- ---------------------------------------------------------------------
WITH bill AS MATERIALIZED (
    SELECT e.student_id, t.term_id, t.start_date,
           SUM(fs.amount) AS amount, random() AS r
    FROM enrolment e
    JOIN academic_session ses ON ses.session_id = e.session_id AND ses.name <> '2025/2026'
    JOIN class_arm ca         ON ca.class_arm_id = e.class_arm_id
    JOIN term t               ON t.session_id = e.session_id
    JOIN fee_schedule fs      ON fs.level_id = ca.level_id AND fs.term_id = t.term_id
    GROUP BY e.student_id, t.term_id, t.start_date
)
INSERT INTO payment (student_id, term_id, amount, method, reference, paid_at, received_by)
SELECT p.student_id, p.term_id, p.pay_amount,
       (ARRAY['TRANSFER', 'TRANSFER', 'POS', 'ONLINE', 'CASH'])[1 + p.rn % 5],
       'HPS-PAY-B' || lpad(p.rn::text, 7, '0'),
       p.start_date + 7 + TIME '10:00',
       (SELECT staff_id FROM staff WHERE role = 'BURSAR' LIMIT 1)
FROM (
    SELECT b.student_id, b.term_id, b.start_date,
           CASE WHEN b.r < 0.85 THEN b.amount ELSE round(b.amount * 0.6, 2) END AS pay_amount,
           (row_number() OVER (ORDER BY b.term_id, b.student_id))::int AS rn
    FROM bill b
    WHERE b.r < 0.95
) p;

ANALYZE;

-- ---------------------------------------------------------------------
-- Summary (this is the result pgAdmin shows after the script finishes)
-- ---------------------------------------------------------------------
SELECT 'academic_session' AS item, count(*) AS rows FROM academic_session
UNION ALL SELECT 'term',               count(*) FROM term
UNION ALL SELECT 'class_arm',          count(*) FROM class_arm
UNION ALL SELECT 'subject_allocation', count(*) FROM subject_allocation
UNION ALL SELECT 'student',            count(*) FROM student
UNION ALL SELECT 'enrolment',          count(*) FROM enrolment
UNION ALL SELECT 'score',              count(*) FROM score
UNION ALL SELECT 'attendance',         count(*) FROM attendance
UNION ALL SELECT 'payment',            count(*) FROM payment
UNION ALL SELECT 'inconsistent scores (must be 0)', count(*)
FROM score sc
JOIN enrolment e           ON e.enrolment_id = sc.enrolment_id
JOIN subject_allocation sa ON sa.allocation_id = sc.allocation_id
JOIN term t                ON t.term_id = sc.term_id
WHERE sa.class_arm_id <> e.class_arm_id OR t.session_id <> e.session_id;
