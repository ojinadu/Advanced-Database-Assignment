-- =====================================================================
-- Harmetage Private School database
-- Portfolio 1: Database Design and Modelling
-- File 01: schema (tables, keys, constraints, trigger)
-- Target: PostgreSQL 16
-- Run: psql -v ON_ERROR_STOP=1 -U harmetage -d harmetage -f 01_schema.sql
-- =====================================================================

DROP SCHEMA IF EXISTS harmetage CASCADE;
CREATE SCHEMA harmetage;
SET search_path TO harmetage;

-- ---------------------------------------------------------------------
-- Academic structure
-- ---------------------------------------------------------------------

-- JSS1 .. SS3. Fixed reference data.
CREATE TABLE class_level (
    level_id    smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        varchar(4)  NOT NULL UNIQUE,
    name        varchar(30) NOT NULL,
    stage       varchar(6)  NOT NULL CHECK (stage IN ('JUNIOR', 'SENIOR')),
    sort_order  smallint    NOT NULL UNIQUE CHECK (sort_order BETWEEN 1 AND 6)
);

-- An academic year, e.g. 2025/2026.
CREATE TABLE academic_session (
    session_id  smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        varchar(9) NOT NULL UNIQUE CHECK (name ~ '^[0-9]{4}/[0-9]{4}$'),
    start_date  date NOT NULL,
    end_date    date NOT NULL,
    CHECK (end_date > start_date)
);

-- Three terms per session.
CREATE TABLE term (
    term_id     smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id  smallint NOT NULL REFERENCES academic_session (session_id),
    term_no     smallint NOT NULL CHECK (term_no BETWEEN 1 AND 3),
    start_date  date NOT NULL,
    end_date    date NOT NULL,
    CHECK (end_date > start_date),
    UNIQUE (session_id, term_no)
);

CREATE TABLE subject (
    subject_id  smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        varchar(8)  NOT NULL UNIQUE,
    name        varchar(60) NOT NULL UNIQUE,
    stage       varchar(6)  NOT NULL CHECK (stage IN ('JUNIOR', 'SENIOR', 'BOTH'))
);

-- Grading bands. The exclusion constraint stops two bands from overlapping,
-- so every total maps to exactly one grade.
CREATE TABLE grade_scale (
    grade   varchar(2)  PRIMARY KEY,
    band    numrange    NOT NULL CHECK (band <@ numrange(0, 100, '[]')),
    remark  varchar(20) NOT NULL,
    EXCLUDE USING gist (band WITH &&)
);

-- ---------------------------------------------------------------------
-- People
-- ---------------------------------------------------------------------

CREATE TABLE staff (
    staff_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    staff_no    varchar(12)  NOT NULL UNIQUE,
    first_name  varchar(50)  NOT NULL,
    last_name   varchar(50)  NOT NULL,
    role        varchar(10)  NOT NULL CHECK (role IN ('TEACHER', 'ADMIN', 'BURSAR', 'PRINCIPAL')),
    email       varchar(120) UNIQUE,
    phone       varchar(20),
    hire_date   date         NOT NULL,
    is_active   boolean      NOT NULL DEFAULT true
);

CREATE TABLE guardian (
    guardian_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  varchar(50)  NOT NULL,
    last_name   varchar(50)  NOT NULL,
    phone       varchar(20)  NOT NULL UNIQUE,
    email       varchar(120) UNIQUE,
    address     text
);

CREATE TABLE student (
    student_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    admission_no   varchar(15) NOT NULL UNIQUE,          -- e.g. HPS/2025/0001
    first_name     varchar(50) NOT NULL,
    last_name      varchar(50) NOT NULL,
    date_of_birth  date        NOT NULL,
    gender         char(1)     NOT NULL CHECK (gender IN ('M', 'F')),
    admission_date date        NOT NULL,
    status         varchar(10) NOT NULL DEFAULT 'ACTIVE'
                   CHECK (status IN ('ACTIVE', 'GRADUATED', 'WITHDRAWN')),
    CHECK (admission_date > date_of_birth)
);

-- Many-to-many: a student can have several guardians, and siblings share one.
CREATE TABLE student_guardian (
    student_id   integer NOT NULL REFERENCES student (student_id) ON DELETE CASCADE,
    guardian_id  integer NOT NULL REFERENCES guardian (guardian_id),
    relationship varchar(10) NOT NULL
                 CHECK (relationship IN ('FATHER', 'MOTHER', 'GUARDIAN', 'SIBLING', 'OTHER')),
    is_primary   boolean NOT NULL DEFAULT false,
    PRIMARY KEY (student_id, guardian_id)
);

-- At most one primary contact per student (partial unique index).
CREATE UNIQUE INDEX uq_student_one_primary_guardian
    ON student_guardian (student_id) WHERE is_primary;

-- ---------------------------------------------------------------------
-- Classes, teaching and enrolment
-- ---------------------------------------------------------------------

-- A class arm is one stream of a level in one session, e.g. JSS1A in 2025/2026.
CREATE TABLE class_arm (
    class_arm_id    integer  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    level_id        smallint NOT NULL REFERENCES class_level (level_id),
    session_id      smallint NOT NULL REFERENCES academic_session (session_id),
    arm             char(1)  NOT NULL CHECK (arm BETWEEN 'A' AND 'F'),
    form_teacher_id integer  REFERENCES staff (staff_id),
    capacity        smallint NOT NULL DEFAULT 35 CHECK (capacity BETWEEN 1 AND 60),
    UNIQUE (level_id, session_id, arm),
    UNIQUE (session_id, form_teacher_id),     -- one form class per teacher per session
    UNIQUE (class_arm_id, session_id)         -- target for the composite FK in enrolment
);

-- Which teacher takes which subject in which class arm.
CREATE TABLE subject_allocation (
    allocation_id integer  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    class_arm_id  integer  NOT NULL REFERENCES class_arm (class_arm_id),
    subject_id    smallint NOT NULL REFERENCES subject (subject_id),
    teacher_id    integer  NOT NULL REFERENCES staff (staff_id),
    UNIQUE (class_arm_id, subject_id)
);

-- A student's placement in a class arm for a session.
-- session_id is repeated here on purpose. The composite FK forces it to match
-- the class arm's session, and UNIQUE (student_id, session_id) then stops a
-- student from sitting in two classes in the same session.
CREATE TABLE enrolment (
    enrolment_id integer  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id   integer  NOT NULL REFERENCES student (student_id),
    class_arm_id integer  NOT NULL,
    session_id   smallint NOT NULL,
    enrolled_on  date     NOT NULL DEFAULT CURRENT_DATE,
    FOREIGN KEY (class_arm_id, session_id) REFERENCES class_arm (class_arm_id, session_id),
    UNIQUE (student_id, session_id)
);

-- ---------------------------------------------------------------------
-- Results and attendance
-- ---------------------------------------------------------------------

-- CA1 (20) + CA2 (20) + Exam (60) = 100.
CREATE TABLE score (
    enrolment_id  integer  NOT NULL REFERENCES enrolment (enrolment_id),
    allocation_id integer  NOT NULL REFERENCES subject_allocation (allocation_id),
    term_id       smallint NOT NULL REFERENCES term (term_id),
    ca1   numeric(4,1) CHECK (ca1  BETWEEN 0 AND 20),
    ca2   numeric(4,1) CHECK (ca2  BETWEEN 0 AND 20),
    exam  numeric(4,1) CHECK (exam BETWEEN 0 AND 60),
    total numeric(5,1) GENERATED ALWAYS AS
          (COALESCE(ca1, 0) + COALESCE(ca2, 0) + COALESCE(exam, 0)) STORED,
    recorded_by integer REFERENCES staff (staff_id),
    recorded_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (enrolment_id, term_id, allocation_id)
);

CREATE TABLE attendance (
    enrolment_id    integer    NOT NULL REFERENCES enrolment (enrolment_id),
    attendance_date date       NOT NULL,
    status          varchar(7) NOT NULL CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'EXCUSED')),
    recorded_by     integer    REFERENCES staff (staff_id),
    PRIMARY KEY (enrolment_id, attendance_date),
    CHECK (EXTRACT(ISODOW FROM attendance_date) BETWEEN 1 AND 5)   -- school days only
);

-- ---------------------------------------------------------------------
-- Fees
-- ---------------------------------------------------------------------

CREATE TABLE fee_item (
    fee_item_id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        varchar(40) NOT NULL UNIQUE
);

-- What each level pays per term for each fee item.
CREATE TABLE fee_schedule (
    level_id    smallint      NOT NULL REFERENCES class_level (level_id),
    term_id     smallint      NOT NULL REFERENCES term (term_id),
    fee_item_id smallint      NOT NULL REFERENCES fee_item (fee_item_id),
    amount      numeric(12,2) NOT NULL CHECK (amount > 0),
    PRIMARY KEY (level_id, term_id, fee_item_id)
);

-- Balances are not stored. They are computed as fees due minus payments,
-- so they can never drift out of sync with the payment records.
CREATE TABLE payment (
    payment_id  bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id  integer       NOT NULL REFERENCES student (student_id),
    term_id     smallint      NOT NULL REFERENCES term (term_id),
    amount      numeric(12,2) NOT NULL CHECK (amount > 0),
    method      varchar(8)    NOT NULL CHECK (method IN ('CASH', 'TRANSFER', 'POS', 'ONLINE')),
    reference   varchar(40)   NOT NULL UNIQUE,
    paid_at     timestamptz   NOT NULL DEFAULT now(),
    received_by integer       REFERENCES staff (staff_id)
);

-- ---------------------------------------------------------------------
-- Cross-table rule that a plain FK cannot express:
-- a score must use a subject allocation from the student's own class arm,
-- and a term from the student's own session.
-- ---------------------------------------------------------------------
CREATE FUNCTION check_score_consistency() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_enrol_arm   integer;
    v_enrol_sess  smallint;
    v_alloc_arm   integer;
    v_term_sess   smallint;
BEGIN
    SELECT class_arm_id, session_id INTO v_enrol_arm, v_enrol_sess
      FROM enrolment WHERE enrolment_id = NEW.enrolment_id;

    SELECT class_arm_id INTO v_alloc_arm
      FROM subject_allocation WHERE allocation_id = NEW.allocation_id;

    SELECT session_id INTO v_term_sess
      FROM term WHERE term_id = NEW.term_id;

    -- Missing parent rows: let the foreign keys report the error.
    IF v_enrol_arm IS NULL OR v_alloc_arm IS NULL OR v_term_sess IS NULL THEN
        RETURN NEW;
    END IF;

    IF v_alloc_arm <> v_enrol_arm THEN
        RAISE EXCEPTION 'Score rejected: allocation % belongs to class arm %, but enrolment % is in class arm %',
            NEW.allocation_id, v_alloc_arm, NEW.enrolment_id, v_enrol_arm;
    END IF;

    IF v_term_sess <> v_enrol_sess THEN
        RAISE EXCEPTION 'Score rejected: term % belongs to session %, but enrolment % is for session %',
            NEW.term_id, v_term_sess, NEW.enrolment_id, v_enrol_sess;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_score_consistency
    BEFORE INSERT OR UPDATE OF enrolment_id, allocation_id, term_id ON score
    FOR EACH ROW EXECUTE FUNCTION check_score_consistency();

-- Note: foreign key columns are deliberately NOT indexed yet (PostgreSQL does
-- not index them automatically). Indexing is handled in Portfolio 2 so the
-- before/after effect can be measured.

-- Make "harmetage" the default schema for every new connection to this
-- database, so tools like pgAdmin find the tables without SET search_path.
DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I SET search_path TO harmetage, public', current_database());
END;
$$;
