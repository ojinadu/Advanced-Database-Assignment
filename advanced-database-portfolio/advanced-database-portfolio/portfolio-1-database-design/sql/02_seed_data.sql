-- =====================================================================
-- Harmetage Private School database
-- File 02: seed data (synthetic, fictional people only)
-- One session (2025/2026), 6 levels x 2 arms, 30 students per arm = 360 students
-- Run: psql -v ON_ERROR_STOP=1 -U harmetage -d harmetage -f 02_seed_data.sql
-- =====================================================================

SET search_path TO harmetage;
SELECT setseed(0.42);   -- repeatable random values

-- Name pools used to generate people.
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
-- Academic structure
-- ---------------------------------------------------------------------
INSERT INTO class_level (code, name, stage, sort_order) VALUES
    ('JSS1', 'Junior Secondary 1', 'JUNIOR', 1),
    ('JSS2', 'Junior Secondary 2', 'JUNIOR', 2),
    ('JSS3', 'Junior Secondary 3', 'JUNIOR', 3),
    ('SS1',  'Senior Secondary 1', 'SENIOR', 4),
    ('SS2',  'Senior Secondary 2', 'SENIOR', 5),
    ('SS3',  'Senior Secondary 3', 'SENIOR', 6);

INSERT INTO academic_session (name, start_date, end_date)
VALUES ('2025/2026', DATE '2025-09-08', DATE '2026-07-24');

INSERT INTO term (session_id, term_no, start_date, end_date)
SELECT s.session_id, t.term_no, t.start_date, t.end_date
FROM academic_session s
CROSS JOIN (VALUES (1, DATE '2025-09-08', DATE '2025-12-12'),
                   (2, DATE '2026-01-05', DATE '2026-04-02'),
                   (3, DATE '2026-04-20', DATE '2026-07-24')) AS t (term_no, start_date, end_date)
WHERE s.name = '2025/2026';

INSERT INTO subject (code, name, stage) VALUES
    ('ENG', 'English Language',   'BOTH'),
    ('MTH', 'Mathematics',        'BOTH'),
    ('CIV', 'Civic Education',    'BOTH'),
    ('CMP', 'Computer Studies',   'BOTH'),
    ('BSC', 'Basic Science',      'JUNIOR'),
    ('BTE', 'Basic Technology',   'JUNIOR'),
    ('SOS', 'Social Studies',     'JUNIOR'),
    ('BUS', 'Business Studies',   'JUNIOR'),
    ('FRE', 'French',             'JUNIOR'),
    ('NLG', 'Nigerian Language',  'JUNIOR'),
    ('PHY', 'Physics',            'SENIOR'),
    ('CHE', 'Chemistry',          'SENIOR'),
    ('BIO', 'Biology',            'SENIOR'),
    ('ECO', 'Economics',          'SENIOR'),
    ('GOV', 'Government',         'SENIOR'),
    ('LIT', 'Literature in English', 'SENIOR');

INSERT INTO grade_scale (grade, band, remark) VALUES
    ('A', '[70,100]', 'Excellent'),
    ('B', '[60,70)',  'Very Good'),
    ('C', '[50,60)',  'Good'),
    ('D', '[45,50)',  'Fair'),
    ('E', '[40,45)',  'Pass'),
    ('F', '[0,40)',   'Fail');

-- ---------------------------------------------------------------------
-- Staff: principal, bursar, admissions officer, 30 teachers
-- ---------------------------------------------------------------------
INSERT INTO staff (staff_no, first_name, last_name, role, email, phone, hire_date) VALUES
    ('HPS-ST-001', 'Grace',   'Okafor', 'PRINCIPAL', 'principal@harmetage.example',  '08030000001', DATE '2012-09-01'),
    ('HPS-ST-002', 'Ibrahim', 'Musa',   'BURSAR',    'bursar@harmetage.example',     '08030000002', DATE '2015-01-12'),
    ('HPS-ST-003', 'Ngozi',   'Eze',    'ADMIN',     'admissions@harmetage.example', '08030000003', DATE '2018-03-05');

INSERT INTO staff (staff_no, first_name, last_name, role, email, phone, hire_date)
SELECT format('HPS-ST-%s', lpad((g + 3)::text, 3, '0')),
       CASE WHEN g % 2 = 0 THEN n.female[1 + (g * 7) % array_length(n.female, 1)]
            ELSE n.male[1 + (g * 3) % array_length(n.male, 1)] END,
       n.surname[1 + (g * 5) % array_length(n.surname, 1)],
       'TEACHER',
       format('teacher%s@harmetage.example', g),
       format('0803%s', lpad((1000000 + g)::text, 7, '0')),
       DATE '2014-09-01' + (g * 97) % 3000
FROM generate_series(1, 30) AS g
CROSS JOIN names n;

-- ---------------------------------------------------------------------
-- Class arms (A and B for each level) and form teachers
-- ---------------------------------------------------------------------
INSERT INTO class_arm (level_id, session_id, arm, capacity)
SELECT l.level_id, s.session_id, a.arm, 35
FROM class_level l
CROSS JOIN academic_session s
CROSS JOIN (VALUES ('A'), ('B')) AS a (arm);

WITH t AS (SELECT staff_id, row_number() OVER (ORDER BY staff_id) AS rn
           FROM staff WHERE role = 'TEACHER'),
     c AS (SELECT ca.class_arm_id, row_number() OVER (ORDER BY l.sort_order, ca.arm) AS rn
           FROM class_arm ca JOIN class_level l USING (level_id))
UPDATE class_arm ca
SET form_teacher_id = t.staff_id
FROM c JOIN t USING (rn)
WHERE ca.class_arm_id = c.class_arm_id;

-- Map of arms in a fixed order (0 = JSS1A, 1 = JSS1B, ... 11 = SS3B).
CREATE TEMP TABLE arm_map AS
SELECT ca.class_arm_id, ca.session_id,
       row_number() OVER (ORDER BY l.sort_order, ca.arm) - 1 AS arm_idx
FROM class_arm ca JOIN class_level l USING (level_id);

-- Each subject gets one junior teacher and one senior teacher.
WITH t AS (SELECT staff_id, row_number() OVER (ORDER BY staff_id) - 1 AS idx
           FROM staff WHERE role = 'TEACHER')
INSERT INTO subject_allocation (class_arm_id, subject_id, teacher_id)
SELECT ca.class_arm_id, s.subject_id, t.staff_id
FROM class_arm ca
JOIN class_level l ON l.level_id = ca.level_id
JOIN subject s     ON s.stage IN (l.stage, 'BOTH')
JOIN t             ON t.idx = ((s.subject_id - 1) * 2
                              + CASE WHEN l.stage = 'SENIOR' THEN 1 ELSE 0 END) % 30;

-- ---------------------------------------------------------------------
-- Students, guardians, enrolments
-- Students are numbered g = 1..360. Students 1-60 are JSS1, 61-120 JSS2, etc.
-- Every 12th student is a sibling of the one before (shares surname and guardian).
-- ---------------------------------------------------------------------
INSERT INTO student (admission_no, first_name, last_name, date_of_birth, gender, admission_date)
SELECT format('HPS/%s/%s', 2025 - (x.lvl - 1), lpad(x.g::text, 4, '0')),
       CASE WHEN x.g % 2 = 0 THEN n.female[1 + (x.g * 7) % array_length(n.female, 1)]
            ELSE n.male[1 + (x.g * 3) % array_length(n.male, 1)] END,
       n.surname[1 + (x.fam * 11) % array_length(n.surname, 1)],
       make_date(2014 - (x.lvl - 1), 1, 1) + (random() * 364)::int,
       CASE WHEN x.g % 2 = 0 THEN 'F' ELSE 'M' END,
       make_date(2025 - (x.lvl - 1), 9, 8)
FROM (SELECT g,
             (g - 1) / 60 + 1 AS lvl,
             CASE WHEN g % 12 = 0 THEN g - 1 ELSE g END AS fam
      FROM generate_series(1, 360) AS g) x
CROSS JOIN names n;

INSERT INTO guardian (first_name, last_name, phone, email, address)
SELECT CASE WHEN f.fam % 2 = 1 THEN n.male[1 + (f.fam * 13) % array_length(n.male, 1)]
            ELSE n.female[1 + (f.fam * 17) % array_length(n.female, 1)] END,
       n.surname[1 + (f.fam * 11) % array_length(n.surname, 1)],
       format('0802%s', lpad(f.fam::text, 7, '0')),
       format('parent%s@example.com', f.fam),
       format('%s Harmetage Close, Abuja', f.fam)
FROM (SELECT g AS fam FROM generate_series(1, 360) AS g WHERE g % 12 <> 0) f
CROSS JOIN names n;

INSERT INTO student_guardian (student_id, guardian_id, relationship, is_primary)
SELECT s.student_id, gd.guardian_id,
       CASE WHEN x.fam % 2 = 1 THEN 'FATHER' ELSE 'MOTHER' END,
       true
FROM student s
CROSS JOIN LATERAL (SELECT right(s.admission_no, 4)::int AS g) g0
CROSS JOIN LATERAL (SELECT CASE WHEN g0.g % 12 = 0 THEN g0.g - 1 ELSE g0.g END AS fam) x
JOIN guardian gd ON gd.phone = format('0802%s', lpad(x.fam::text, 7, '0'));

INSERT INTO enrolment (student_id, class_arm_id, session_id, enrolled_on)
SELECT s.student_id, m.class_arm_id, m.session_id, DATE '2025-09-08'
FROM student s
JOIN arm_map m ON m.arm_idx = (right(s.admission_no, 4)::int - 1) / 30;

-- ---------------------------------------------------------------------
-- Scores for all three terms (goes through the consistency trigger)
-- ---------------------------------------------------------------------
INSERT INTO score (enrolment_id, allocation_id, term_id, ca1, ca2, exam, recorded_by, recorded_at)
SELECT e.enrolment_id, sa.allocation_id, t.term_id,
       round((6  + random() * 14)::numeric, 0),
       round((6  + random() * 14)::numeric, 0),
       round((15 + random() * 45)::numeric, 0),
       sa.teacher_id,
       (t.end_date - 5) + TIME '14:00'
FROM enrolment e
JOIN subject_allocation sa ON sa.class_arm_id = e.class_arm_id
JOIN term t                ON t.session_id   = e.session_id;

-- ---------------------------------------------------------------------
-- Attendance for first term school days
-- ---------------------------------------------------------------------
INSERT INTO attendance (enrolment_id, attendance_date, status, recorded_by)
SELECT enrolment_id, day,
       CASE WHEN x < 0.90 THEN 'PRESENT'
            WHEN x < 0.95 THEN 'LATE'
            WHEN x < 0.99 THEN 'ABSENT'
            ELSE 'EXCUSED' END,
       form_teacher_id
FROM (
    SELECT e.enrolment_id, d::date AS day, ca.form_teacher_id, random() AS x
    FROM enrolment e
    JOIN class_arm ca ON ca.class_arm_id = e.class_arm_id
    JOIN term t       ON t.session_id = e.session_id AND t.term_no = 1
    CROSS JOIN LATERAL generate_series(t.start_date, t.end_date, INTERVAL '1 day') AS d
    WHERE EXTRACT(ISODOW FROM d) BETWEEN 1 AND 5
) days;

-- ---------------------------------------------------------------------
-- Fees and payments
-- ---------------------------------------------------------------------
INSERT INTO fee_item (name) VALUES ('Tuition'), ('Development Levy'), ('ICT'), ('Laboratory');

INSERT INTO fee_schedule (level_id, term_id, fee_item_id, amount)
SELECT l.level_id, t.term_id, fi.fee_item_id,
       CASE fi.name
            WHEN 'Tuition'          THEN CASE l.stage WHEN 'JUNIOR' THEN 185000 ELSE 210000 END
            WHEN 'Development Levy' THEN 15000
            WHEN 'ICT'              THEN 10000
            WHEN 'Laboratory'       THEN 12000
       END
FROM class_level l
CROSS JOIN term t
CROSS JOIN fee_item fi
WHERE (fi.name <> 'Development Levy' OR t.term_no = 1)   -- levy charged once a session
  AND (fi.name <> 'Laboratory' OR l.stage = 'SENIOR');    -- lab fee for seniors only

-- Payment patterns: most pay in full, some pay in two instalments,
-- some pay half and still owe. Third term has more debtors.
WITH bill AS MATERIALIZED (
    SELECT e.student_id, t.term_id, t.term_no, t.start_date,
           SUM(fs.amount) AS amount, random() AS r
    FROM enrolment e
    JOIN class_arm ca    ON ca.class_arm_id = e.class_arm_id
    JOIN term t          ON t.session_id = e.session_id
    JOIN fee_schedule fs ON fs.level_id = ca.level_id AND fs.term_id = t.term_id
    GROUP BY e.student_id, t.term_id, t.term_no, t.start_date
),
pay AS (
    SELECT student_id, term_id, amount, start_date + 7 AS pay_date
    FROM bill WHERE (term_no < 3 AND r < 0.85) OR (term_no = 3 AND r < 0.70)
    UNION ALL
    SELECT student_id, term_id, round(amount * 0.6, 2), start_date + 5
    FROM bill WHERE term_no < 3 AND r >= 0.85 AND r < 0.95
    UNION ALL
    SELECT student_id, term_id, amount - round(amount * 0.6, 2), start_date + 40
    FROM bill WHERE term_no < 3 AND r >= 0.85 AND r < 0.95
    UNION ALL
    SELECT student_id, term_id, round(amount * 0.5, 2), start_date + 10
    FROM bill WHERE (term_no < 3 AND r >= 0.95) OR (term_no = 3 AND r >= 0.70 AND r < 0.90)
)
INSERT INTO payment (student_id, term_id, amount, method, reference, paid_at, received_by)
SELECT p.student_id, p.term_id, p.amount,
       (ARRAY['TRANSFER', 'TRANSFER', 'POS', 'ONLINE', 'CASH'])[1 + (row_number() OVER ())::int % 5],
       format('HPS-PAY-%s', lpad((row_number() OVER (ORDER BY p.pay_date, p.student_id))::text, 6, '0')),
       p.pay_date + TIME '10:00',
       (SELECT staff_id FROM staff WHERE role = 'BURSAR' LIMIT 1)
FROM pay p;

ANALYZE;
