-- =====================================================================
-- Portfolio 3, Experiment 2: LOST UPDATE.  *** TAB B (Teacher B) ***
-- Order:  Part 1: A1, B1, A2, B2, A3     Part 2: A4, B4, A5, B5, A6
-- =====================================================================
SET search_path TO harmetage;

-- ===== PART 1: the problem =====

-- B1. Teacher B opens the same score at the same time and also sees 18.
BEGIN;
SELECT ca1 FROM score
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- (now run A2 in Tab A)

-- B2. Teacher B subtracts 3 marks from the 18 they saw, saves and commits.
--     Nothing warns B that the row changed. A's 20 is overwritten by 15.
UPDATE score SET ca1 = 15
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);
COMMIT;

-- (now run A3 in Tab A)

-- ===== PART 2: the fix =====

-- B4. Teacher B starts at REPEATABLE READ and reads 18.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT ca1 FROM score
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- (now run A5 in Tab A)

-- B5. Teacher B tries to save. Expect:
--     ERROR: could not serialize access due to concurrent update
--     PostgreSQL refuses, because the row changed since B read it.
UPDATE score SET ca1 = 15
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids)
  AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- B6. B must roll back, reload the row (now 20) and decide again.
ROLLBACK;

-- (now run A6 in Tab A)
