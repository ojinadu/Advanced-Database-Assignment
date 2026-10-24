-- =====================================================================
-- Portfolio 4: NoSQL and Advanced Data Models
-- File 01: build one JSON document per student per term from the
-- relational tables, and export them for MongoDB.
--
-- Step 1: run everything from SET search_path down to the end of the
--         CREATE VIEW (F5). Then run the SELECT marked "preview" to see a document.
-- Step 2: edit the file path in the COPY command at the bottom, highlight
--         it, and run it on its own. It writes a .json file on your computer.
-- =====================================================================
SET search_path TO harmetage;

DROP VIEW IF EXISTS report_card_document;

CREATE VIEW report_card_document AS
WITH subj AS (
    -- One row per student, term and subject, with grade looked up.
    SELECT sc.enrolment_id, sc.term_id,
           jsonb_build_object(
               'code',    sub.code,
               'name',    sub.name,
               'teacher', st.first_name || ' ' || st.last_name,
               'ca1',     sc.ca1,
               'ca2',     sc.ca2,
               'exam',    sc.exam,
               'total',   sc.total,
               'grade',   g.grade,
               'remark',  g.remark
           ) AS subject_doc,
           sc.total
    FROM score sc
    JOIN subject_allocation sa ON sa.allocation_id = sc.allocation_id
    JOIN subject sub           ON sub.subject_id = sa.subject_id
    JOIN staff st              ON st.staff_id = sa.teacher_id
    JOIN grade_scale g         ON sc.total <@ g.band
),
per_term AS (
    -- Average per student per term, and position within the class arm.
    SELECT s.enrolment_id, s.term_id,
           jsonb_agg(s.subject_doc ORDER BY s.subject_doc->>'name') AS subjects,
           round(avg(s.total), 2) AS average,
           count(*) AS subject_count
    FROM subj s
    GROUP BY s.enrolment_id, s.term_id
),
ranked AS (
    SELECT p.*, e.class_arm_id,
           rank() OVER (PARTITION BY e.class_arm_id, p.term_id ORDER BY p.average DESC) AS position,
           count(*) OVER (PARTITION BY e.class_arm_id, p.term_id) AS class_size
    FROM per_term p
    JOIN enrolment e ON e.enrolment_id = p.enrolment_id
),
att AS (
    SELECT a.enrolment_id, t.term_id,
           count(*) FILTER (WHERE a.status = 'PRESENT') AS present,
           count(*) FILTER (WHERE a.status = 'LATE')    AS late,
           count(*) FILTER (WHERE a.status = 'ABSENT')  AS absent,
           count(*) FILTER (WHERE a.status = 'EXCUSED') AS excused,
           count(*)                                     AS school_days
    FROM attendance a
    JOIN enrolment e ON e.enrolment_id = a.enrolment_id
    JOIN term t      ON t.session_id = e.session_id
                    AND a.attendance_date BETWEEN t.start_date AND t.end_date
    GROUP BY a.enrolment_id, t.term_id
)
SELECT
    stu.admission_no || '|' || ses.name || '|T' || t.term_no AS doc_id,
    jsonb_build_object(
        '_id',     stu.admission_no || '|' || ses.name || '|T' || t.term_no,
        'student', jsonb_build_object(
                       'admission_no', stu.admission_no,
                       'name',         stu.first_name || ' ' || stu.last_name,
                       'gender',       stu.gender,
                       'class',        l.code || ca.arm,
                       'form_teacher', ft.first_name || ' ' || ft.last_name),
        'session', ses.name,
        'term',    t.term_no,
        'term_ends', t.end_date,
        'subjects', r.subjects,
        'summary', jsonb_build_object(
                       'average',       r.average,
                       'position',      r.position,
                       'class_size',    r.class_size,
                       'subject_count', r.subject_count),
        'attendance', CASE WHEN att.enrolment_id IS NULL THEN NULL ELSE
                      jsonb_build_object(
                          'present', att.present, 'late', att.late,
                          'absent',  att.absent,  'excused', att.excused,
                          'school_days', att.school_days) END,
        'comments', '[]'::jsonb,
        'generated_at', now()
    ) AS document
FROM ranked r
JOIN enrolment e        ON e.enrolment_id = r.enrolment_id
JOIN student stu        ON stu.student_id = e.student_id
JOIN class_arm ca       ON ca.class_arm_id = e.class_arm_id
JOIN class_level l      ON l.level_id = ca.level_id
LEFT JOIN staff ft      ON ft.staff_id = ca.form_teacher_id
JOIN term t             ON t.term_id = r.term_id
JOIN academic_session ses ON ses.session_id = t.session_id
LEFT JOIN att           ON att.enrolment_id = r.enrolment_id AND att.term_id = r.term_id
WHERE ses.name = '2025/2026';          -- current session only: 360 students x 3 terms = 1,080 documents

-- Preview: one document, pretty printed. Highlight and run on its own. Screenshot it.
SELECT jsonb_pretty(document) FROM report_card_document
WHERE doc_id = 'HPS/2025/0001|2025/2026|T1';

-- How many documents will be exported? (expect 1080)
SELECT count(*) FROM report_card_document;

-- ---------------------------------------------------------------------
-- EXPORT. Edit the path, then highlight ONLY this COPY command and run it.
-- Windows example:  'C:/Users/YourName/Documents/report_cards.json'
-- Mac example:      '/Users/yourname/Documents/report_cards.json'
-- Use forward slashes even on Windows. The file is written by the
-- PostgreSQL server, so you must be connected as the "postgres" superuser
-- (the default in pgAdmin). One JSON document per line, which is exactly
-- the format MongoDB Compass imports.
-- ---------------------------------------------------------------------
COPY (SELECT document::text FROM report_card_document ORDER BY doc_id)
TO 'C:/Users/YourName/Documents/report_cards.json';
