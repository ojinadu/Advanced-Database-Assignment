-- =====================================================================
-- Portfolio 3, Experiment 3: OVERBOOKING a class.  *** TAB A (Officer A) ***
-- JSS1A has 30 students and capacity 31: ONE seat left. Two admissions
-- officers try to fill it at the same time.
-- Order:  Part 1: A1, B1, A2, B2, A3     Part 2: A4, B4, A5, B5, A6
-- =====================================================================
SET search_path TO harmetage;

-- ===== PART 1: the problem (check, then insert, with no lock) =====

-- A1. Officer A checks: is there room? (30 of 31, so yes)
BEGIN;
SELECT count(*) AS enrolled, (SELECT capacity FROM class_arm WHERE class_arm_id = (SELECT jss1a FROM p3_ids)) AS capacity
FROM enrolment WHERE class_arm_id = (SELECT jss1a FROM p3_ids);

-- (now run B1 in Tab B)

-- A2. Officer A enrols test student 1 and commits.
INSERT INTO enrolment (student_id, class_arm_id, session_id)
VALUES ((SELECT test_student_1 FROM p3_ids), (SELECT jss1a FROM p3_ids), (SELECT session_2526 FROM p3_ids));
COMMIT;

-- (now run B2 in Tab B)

-- A3. Count again: 32 students in a class with capacity 31. OVERBOOKED.
SELECT count(*) AS enrolled, (SELECT capacity FROM class_arm WHERE class_arm_id = (SELECT jss1a FROM p3_ids)) AS capacity
FROM enrolment WHERE class_arm_id = (SELECT jss1a FROM p3_ids);

-- ===== PART 2: the fix (lock the class row first with FOR UPDATE) =====

-- A4. Undo the two test enrolments so one seat is free again, then
--     lock the class row and check. Nobody else can lock it until A finishes.
DELETE FROM enrolment
WHERE student_id IN ((SELECT test_student_1 FROM p3_ids), (SELECT test_student_2 FROM p3_ids));

BEGIN;
SELECT capacity FROM class_arm WHERE class_arm_id = (SELECT jss1a FROM p3_ids) FOR UPDATE;
SELECT count(*) AS enrolled FROM enrolment WHERE class_arm_id = (SELECT jss1a FROM p3_ids);

-- (now run B4 in Tab B: it will FREEZE, waiting for A)

-- A5. Officer A enrols test student 1 and commits. Tab B now unfreezes.
INSERT INTO enrolment (student_id, class_arm_id, session_id)
VALUES ((SELECT test_student_1 FROM p3_ids), (SELECT jss1a FROM p3_ids), (SELECT session_2526 FROM p3_ids));
COMMIT;

-- (now run B5 in Tab B)

-- A6. Final count: 31 of 31. Full, but not overbooked.
SELECT count(*) AS enrolled, (SELECT capacity FROM class_arm WHERE class_arm_id = (SELECT jss1a FROM p3_ids)) AS capacity
FROM enrolment WHERE class_arm_id = (SELECT jss1a FROM p3_ids);
