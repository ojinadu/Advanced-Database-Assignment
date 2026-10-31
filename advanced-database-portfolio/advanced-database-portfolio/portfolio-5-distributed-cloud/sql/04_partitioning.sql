-- =====================================================================
-- Portfolio 5: horizontal partitioning of the attendance table.
-- Sharding means splitting one big table across machines by a key.
-- Partitioning is the same split inside one machine, and it is how a
-- single PostgreSQL server prepares a table for sharding later.
--
-- Run this on your ORIGINAL local PostgreSQL (port 5432), where
-- Portfolio 2's 655,344 attendance rows live. Highlight one block at a time.
-- =====================================================================
SET search_path TO harmetage;

-- Block 1: the partitioned table, split by school year (the "shard key").
DROP TABLE IF EXISTS attendance_part CASCADE;

CREATE TABLE attendance_part (
    enrolment_id    integer    NOT NULL,
    attendance_date date       NOT NULL,
    status          varchar(7) NOT NULL,
    recorded_by     integer,
    PRIMARY KEY (enrolment_id, attendance_date)
) PARTITION BY RANGE (attendance_date);

-- One partition per academic session, 2017/2018 to 2025/2026.
CREATE TABLE attendance_2017 PARTITION OF attendance_part FOR VALUES FROM ('2017-09-01') TO ('2018-09-01');
CREATE TABLE attendance_2018 PARTITION OF attendance_part FOR VALUES FROM ('2018-09-01') TO ('2019-09-01');
CREATE TABLE attendance_2019 PARTITION OF attendance_part FOR VALUES FROM ('2019-09-01') TO ('2020-09-01');
CREATE TABLE attendance_2020 PARTITION OF attendance_part FOR VALUES FROM ('2020-09-01') TO ('2021-09-01');
CREATE TABLE attendance_2021 PARTITION OF attendance_part FOR VALUES FROM ('2021-09-01') TO ('2022-09-01');
CREATE TABLE attendance_2022 PARTITION OF attendance_part FOR VALUES FROM ('2022-09-01') TO ('2023-09-01');
CREATE TABLE attendance_2023 PARTITION OF attendance_part FOR VALUES FROM ('2023-09-01') TO ('2024-09-01');
CREATE TABLE attendance_2024 PARTITION OF attendance_part FOR VALUES FROM ('2024-09-01') TO ('2025-09-01');
CREATE TABLE attendance_2025 PARTITION OF attendance_part FOR VALUES FROM ('2025-09-01') TO ('2026-09-01');

-- Block 2: copy the data in. PostgreSQL routes each row to the right partition.
INSERT INTO attendance_part SELECT enrolment_id, attendance_date, status, recorded_by FROM attendance;

-- Block 3: how many rows landed in each partition?
SELECT c.relname AS partition, pg_size_pretty(pg_relation_size(c.oid)) AS size,
       (xpath('/row/cnt/text()', query_to_xml('SELECT count(*) AS cnt FROM harmetage.' || c.relname, false, true, '')))[1]::text::int AS rows
FROM pg_inherits i
JOIN pg_class c ON c.oid = i.inhrelid
JOIN pg_class p ON p.oid = i.inhparent
WHERE p.relname = 'attendance_part'
ORDER BY c.relname;

-- Block 4: PARTITION PRUNING. A query for one month touches ONE partition.
-- In the plan, only attendance_2025 is scanned; the other eight never appear.
EXPLAIN (ANALYZE, BUFFERS)
SELECT status, count(*) FROM attendance_part
WHERE attendance_date >= DATE '2025-10-01' AND attendance_date < DATE '2025-11-01'
GROUP BY status;

-- Block 5: the same query on the original unpartitioned table, for comparison.
EXPLAIN (ANALYZE, BUFFERS)
SELECT status, count(*) FROM attendance
WHERE attendance_date >= DATE '2025-10-01' AND attendance_date < DATE '2025-11-01'
GROUP BY status;

-- Block 6: archiving an old year is instant: detach the partition instead of
-- deleting 78,336 rows one by one.
ALTER TABLE attendance_part DETACH PARTITION attendance_2017;
SELECT count(*) FROM attendance_part;      -- 2017/2018 rows are gone from the main table
SELECT count(*) FROM attendance_2017;      -- but still exist on their own, ready to archive

-- Block 7: clean up.
DROP TABLE attendance_2017;
DROP TABLE attendance_part CASCADE;
