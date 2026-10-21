-- =====================================================================
-- Portfolio 3, Experiment 2: LOST UPDATE.  *** TAB A (Teacher A) ***
-- Open this file in one Query Tool tab and 02_lost_update_B.sql in another.
-- Run the steps in this order, switching tabs:
--   Part 1:  A1, B1, A2, B2, A3
--   Part 2:  A4, B4, A5, B5, A6
-- Highlight one step at a time and press F5.
-- =====================================================================
SET search_path TO harmetage;

-- ===== PART 1: the problem (READ COMMITTED, the default) =====

-- A1. Teacher A opens the Mathematics score for student 0001 and reads CA1 (18).
BEGIN;
SELECT ca1 FROM score
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- (now run B1 in Tab B)

-- A2. Teacher A adds 2 marks to the 18 they saw, and saves.
UPDATE score SET ca1 = 20
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);
COMMIT;

-- (now run B2 in Tab B)

-- A3. Check the final value. It is 15. Teacher A's change (20) has been LOST.
SELECT ca1 FROM score
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- ===== PART 2: the fix with REPEATABLE READ =====

-- A4. Put the value back to 18, then start again at REPEATABLE READ.
UPDATE score SET ca1 = 18
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);

BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT ca1 FROM score
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- (now run B4 in Tab B)

-- A5. Teacher A saves.
UPDATE score SET ca1 = 20
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);
COMMIT;

-- (now run B5 in Tab B: it gets an ERROR instead of silently overwriting)

-- A6. Final value is 20. Nothing was lost.
SELECT ca1 FROM score
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);
