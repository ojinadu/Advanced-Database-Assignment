-- Removes the Portfolio 2 indexes so you can redo the BEFORE measurements.
SET search_path TO harmetage;

DROP INDEX IF EXISTS idx_attendance_date_status;
DROP INDEX IF EXISTS idx_score_recorded_by_at;
DROP INDEX IF EXISTS idx_score_term_alloc_total;
DROP INDEX IF EXISTS idx_payment_student_term;
DROP INDEX IF EXISTS idx_enrolment_class_arm;
