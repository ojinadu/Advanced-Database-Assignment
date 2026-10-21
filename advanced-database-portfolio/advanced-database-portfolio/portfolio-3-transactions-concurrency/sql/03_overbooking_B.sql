-- =====================================================================
-- Portfolio 3, Experiment 3: OVERBOOKING a class.  *** TAB B (Officer B) ***
-- Order:  Part 1: A1, B1, A2, B2, A3     Part 2: A4, B4, A5, B5, A6
-- =====================================================================
SET search_path TO harmetage;

-- ===== PART 1: the problem =====

-- B1. Officer B checks at the same moment and ALSO sees 30 of 31.
BEGIN;
SELECT count(*) AS enrolled, (SELECT capacity FROM class_arm WHERE class_arm_id = (SELECT jss1a FROM p3_ids)) AS capacity
FROM enrolment WHERE class_arm_id = (SELECT jss1a FROM p3_ids);

-- (now run A2 in Tab A)

-- B2. Officer B enrols test student 2 and commits. Nothing stops it.
INSERT INTO enrolment (student_id, class_arm_id, session_id)
VALUES ((SELECT test_student_2 FROM p3_ids), (SELECT jss1a FROM p3_ids), (SELECT session_2526 FROM p3_ids));
COMMIT;

-- (now run A3 in Tab A)

-- ===== PART 2: the fix =====

-- B4. Officer B tries to lock the class row. This FREEZES until A commits.
--     (pgAdmin shows the query still running. That is correct. Go and run A5.)
BEGIN;
SELECT capacity FROM class_arm WHERE class_arm_id = (SELECT jss1a FROM p3_ids) FOR UPDATE;

-- B5. Now B has the lock. Count again: 31 of 31. The seat is gone.
SELECT count(*) AS enrolled FROM enrolment WHERE class_arm_id = (SELECT jss1a FROM p3_ids);

-- Officer B sees the class is full and does NOT insert.
ROLLBACK;

-- (now run A6 in Tab A)
