-- =====================================================================
-- Portfolio 5: run on the REPLICA (port 5434). Highlight one query at a time.
-- =====================================================================

-- 1. Am I a replica? Expect "true".
SELECT pg_is_in_recovery() AS is_replica;

-- 2. How far behind am I? Usually 0 bytes and well under a second.
SELECT pg_last_wal_receive_lsn() AS received,
       pg_last_wal_replay_lsn()  AS replayed,
       pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()) AS bytes_behind,
       now() - pg_last_xact_replay_timestamp() AS time_behind;

-- 3. Where am I connected? Expect primary host and state "streaming".
SELECT status, sender_host, sender_port, slot_name FROM pg_stat_wal_receiver;

-- 4. Try to write. Expect:
--    ERROR: cannot execute INSERT in a read-only transaction
INSERT INTO harmetage.fee_item (name) VALUES ('Should fail on replica');
