-- =====================================================================
-- Portfolio 5: run on the PRIMARY (port 5433). Highlight one query at a time.
-- =====================================================================

-- 1. Am I the primary? Expect "false" (false = not in recovery = primary).
SELECT pg_is_in_recovery() AS is_replica;

-- 2. Who is replicating from me? Expect one row: the replica, state "streaming".
SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn,
       write_lag, flush_lag, replay_lag, sync_state
FROM pg_stat_replication;

-- 3. The replication slot the replica uses (keeps WAL until the replica has it).
SELECT slot_name, slot_type, active, restart_lsn FROM pg_replication_slots;

-- 4. Current write position on the primary.
SELECT pg_current_wal_lsn() AS primary_lsn;
