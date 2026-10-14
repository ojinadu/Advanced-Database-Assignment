-- Run this ALONE, as its own query, right after 01_scale_up_data.sql.
-- VACUUM cannot run together with other statements, so it has its own file.
-- It refreshes PostgreSQL's statistics so the query planner makes good choices.
VACUUM ANALYZE;
