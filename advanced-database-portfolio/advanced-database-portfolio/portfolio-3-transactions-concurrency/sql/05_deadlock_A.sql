-- =====================================================================
-- Portfolio 3, Experiment 5: DEADLOCK.  *** TAB A (Teacher A) ***
-- Two teachers update the same two rows in opposite order.
-- Order: A1, B1, A2 (freezes), B2 (ERROR), A2 then finishes on its own, A3, B3
-- =====================================================================
SET search_path TO harmetage;

-- A1. Teacher A updates student 0001's Mathematics CA2.
BEGIN;
UPDATE score SET ca2 = 15
WHERE enrolment_id = (SELECT enrol_0001 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids) AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- (now run B1 in Tab B)

-- A2. Teacher A now updates student 0002's Mathematics CA2. This FREEZES,
--     because Tab B holds that row. Leave it and go and run B2.
UPDATE score SET ca2 = 15
WHERE enrolment_id = (SELECT enrol_0002 FROM p3_ids)
  AND term_id = (SELECT term1 FROM p3_ids) AND allocation_id = (SELECT alloc_math FROM p3_ids);

-- After B2 fails, A2 completes by itself. Then:
-- A3. Commit. Teacher A's work survives.
COMMIT;
