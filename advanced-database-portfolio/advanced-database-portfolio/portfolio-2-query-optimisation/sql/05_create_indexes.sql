-- =====================================================================
-- Harmetage Private School database
-- Portfolio 2: indexes
-- Run after capturing the BEFORE plans. Run the whole file with F5.
-- =====================================================================

SET search_path TO harmetage;

-- Q1 and Q6B: find attendance by date (and status).
CREATE INDEX idx_attendance_date_status
    ON attendance (attendance_date, status);

-- Q2: find scores by who recorded them and when.
CREATE INDEX idx_score_recorded_by_at
    ON score (recorded_by, recorded_at);

-- Q3: scores for one term, with the allocation and total stored inside the
-- index itself, so PostgreSQL can answer without visiting the table.
CREATE INDEX idx_score_term_alloc_total
    ON score (term_id, allocation_id) INCLUDE (total);

-- Q4: payments for one student.
CREATE INDEX idx_payment_student_term
    ON payment (student_id, term_id);

-- Q5: students in one class arm.
CREATE INDEX idx_enrolment_class_arm
    ON enrolment (class_arm_id);

ANALYZE;
