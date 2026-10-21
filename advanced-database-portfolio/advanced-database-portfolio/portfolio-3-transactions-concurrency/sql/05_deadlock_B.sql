-- =====================================================================
-- Portfolio 3, Experiment 5: DEADLOCK.  *** TAB B (Teacher B) ***
-- Order: A1, B1, A2 (freezes), B2 (ERROR), A2 then finishes on its own, A3, B3
-- =====================================================================
SET search_path TO harmetage;

-- B1. Teacher B updates student 0002's Mathematics CA2 first.
BEGIN;
UPDATE score SET ca2 = 12
WHERE enrolment_id = (SELECT enrol_0002 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids) AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- (now run A2 in Tab A: it freezes)

-- B2. Teacher B now wants student 0001's row, which Tab A holds.
--     A waits for B, B waits for A. Within about a second PostgreSQL
--     detects the deadlock and cancels THIS transaction. Expect:
--     ERROR: deadlock detected
UPDATE score SET ca2 = 12
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids) AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- B3. Clean up. The fix is a rule, not code: always update rows in the
--     same order (for example by enrolment_id), so two transactions can
--     never each wait for the other.
ROLLBACK;
