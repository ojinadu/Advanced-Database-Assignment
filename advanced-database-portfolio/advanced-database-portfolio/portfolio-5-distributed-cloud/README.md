# Portfolio 5: Distributed and Cloud Database Exercise

Case study: **Harmetage Private School** (see the [root README](../README.md)).

This activity runs the Harmetage database as a two-node cluster (a primary and a streaming replica), tests that writes reach the replica, simulates the primary failing, demonstrates horizontal partitioning as the basis for sharding, and discusses the consistency trade-offs and a cloud deployment for the school.

## Why a single school needs this

Harmetage has one real moment of heavy load: **results day**. Report cards are released at a fixed time, and several hundred parents open the portal in the same ten minutes. Every one of them reads; almost nobody writes. A single server that handles the bursar comfortably all year can fall over in that window.

There is also a second, quieter risk: a single server is a single point of failure. If its disk dies on the last day of term, scores entered that week are gone.

Replication addresses both. Reads for results day can go to one or more read-only copies, and if the primary fails, a copy already has the data.

## Architecture

```
                     writes (scores, payments, admissions)
   admin / teachers  ───────────────────────────────►  PRIMARY  (port 5433)
                                                          │
                                                          │  WAL stream (asynchronous)
                                                          ▼
   parents / students ◄────── reads (report cards) ────  REPLICA  (port 5434, read-only)
```

Both nodes run PostgreSQL 16 in Docker. The replica is created with `pg_basebackup` (a full copy of the primary) and then kept up to date by **streaming replication**: every change the primary writes to its write-ahead log (WAL) is sent to the replica and replayed there, usually within milliseconds.

| File | Purpose |
|---|---|
| `replication/docker-compose.yml` | Defines the two nodes, their ports and settings |
| `replication/init/01_replication_user.sh` | Runs once on the primary: creates the `replicator` login and allows replication connections |
| `sql/01_check_primary.sql` | Queries that show the primary's replication status |
| `sql/02_check_replica.sql` | Queries that show the replica's lag, and prove it rejects writes |
| `sql/03_replication_test.sql` | Write on the primary, read it on the replica |
| `sql/04_partitioning.sql` | Partition `attendance` by school year and show partition pruning |

## How to run

### Part 1: start the cluster

Docker Desktop must be installed and running. Then, in a terminal, inside the `replication` folder:

```
docker compose up -d
```

The first run downloads PostgreSQL and takes a minute or two. Check both nodes are up:

```
docker compose ps
```

Both should show `running`. If the replica shows `restarting`, wait 30 seconds and check again; it retries until the primary is ready.

### Part 2: register both nodes in pgAdmin

In pgAdmin, right-click **Servers → Register → Server** twice:

| | Name | Host | Port | Username | Password |
|---|---|---|---|---|---|
| Primary | `Harmetage PRIMARY` | `localhost` | `5433` | `harmetage` | `harmetage_dev` |
| Replica | `Harmetage REPLICA` | `localhost` | `5434` | `harmetage` | `harmetage_dev` |

The name goes on the **General** tab, the rest on the **Connection** tab.

### Part 3: load the school onto the primary

Open a Query Tool on the **PRIMARY** server's `harmetage` database. Open and run (F5) the two Portfolio 1 scripts in order: `portfolio-1-database-design/sql/01_schema.sql`, then `02_seed_data.sql`.

Now refresh the **REPLICA** server in pgAdmin and look under its `harmetage` database. All 17 tables are there. You didn't load anything onto the replica; replication did.

### Part 4: check replication

- Run `sql/01_check_primary.sql` on the PRIMARY, one query at a time.
- Run `sql/02_check_replica.sql` on the REPLICA, one query at a time. The last query is **meant to fail**: a replica is read-only.
- Open `sql/03_replication_test.sql` in two tabs, one on each server, and follow the steps P1, R1, P2, R2, P3, R3.

### Part 5: failover

This simulates the primary dying on results day.

1. In the terminal: `docker compose stop primary`
2. In pgAdmin, try to run any query on the PRIMARY server. It fails: the server is gone.
3. Run `SELECT * FROM harmetage.student LIMIT 5;` on the REPLICA. Parents can still read their results.
4. Promote the replica so it accepts writes: `docker exec harmetage-replica pg_ctl promote -D /var/lib/postgresql/data`
5. On the REPLICA, run `SELECT pg_is_in_recovery();` Expect `false`. It is now a primary.
6. Insert something: `INSERT INTO harmetage.fee_item (name) VALUES ('After failover');` It works.

The school is back in business on the surviving node. To rebuild the cluster afterwards: `docker compose down -v` then `docker compose up -d` and reload the Portfolio 1 scripts (the old primary cannot simply rejoin as a replica without being re-cloned, which is the normal behaviour in PostgreSQL).

### Part 6: partitioning

Run `sql/04_partitioning.sql` on your **original** local PostgreSQL (port 5432, from Portfolios 1 to 4), because that is where the 655,344 attendance rows from Portfolio 2 live. One block at a time.

## Replication: what the evidence shows

`pg_stat_replication` on the primary lists the replica with `state = streaming` and lag columns of a few milliseconds. `pg_stat_wal_receiver` on the replica shows it connected to the primary. The insert in `03_replication_test.sql` is visible on the replica immediately after it commits on the primary.

The replication here is **asynchronous**: the primary commits as soon as its own disk has the change, then sends it on. The replica is normally a few milliseconds behind. For Harmetage this is acceptable, as discussed under consistency below. Synchronous replication (`synchronous_commit = on` with a `synchronous_standby_names` entry) would make the primary wait for the replica's acknowledgement on every commit, which removes the lag but makes every write slower and means a replica outage stalls the primary.

## Sharding: the partitioning demo and the design

Sharding splits one table across several servers by a key. Partitioning is the same split inside one server, and it is the first step: once a table is partitioned, each partition can later be moved to its own machine (with the `postgres_fdw` extension or a tool like Citus).

`04_partitioning.sql` partitions `attendance` by school year. The important result is **partition pruning**: a query for October 2025 scans only `attendance_2025`, and the plan never mentions the other eight partitions. Archiving an old year is a `DETACH PARTITION`, which takes milliseconds, instead of deleting 78,336 rows.

**Choosing a shard key for Harmetage.** Two candidates:

| Shard key | Good | Bad |
|---|---|---|
| Academic session (year) | Old years are read rarely and can go to cheap storage; archiving is a detach | Almost all live traffic is on the current year, so one shard does all the work |
| Campus (if the school opens more sites) | Each campus's load lands on its own shard; a campus's data stays local | Cross-campus reports (school-wide averages) must query every shard and combine |

For a single-campus school, the honest answer is that sharding is not yet needed: 9,576 students and 655,344 attendance rows fit comfortably on one server. Partitioning by session gives most of the operational benefit (pruning, cheap archiving) with none of the cross-server complexity. Sharding by campus becomes worth it only if Harmetage grows into a group of schools.

## Consistency: what parents and the bursar can tolerate

The CAP theorem says a distributed system under a network partition must choose between consistency (every read sees the latest write) and availability (every request gets an answer). In practice, with asynchronous replication, the question is: **which reads may be slightly stale?**

| Operation | Stale read acceptable? | Route to |
|---|---|---|
| Parent views a released report card | Yes. It was finalised days ago; a few milliseconds of lag change nothing. | Replica |
| Teacher enters a score, then views the class list | No. Seeing their own write missing would look like data loss. | Primary |
| Bursar records a payment, then prints the receipt | No. The receipt must show the payment. | Primary |
| Parent checks fee balance | Mostly yes, but a parent who has just paid online expects to see it. | Primary for the paying session, replica otherwise |
| School-wide statistics for the principal | Yes. | Replica |
| Admission officer checks class capacity (Portfolio 3) | No. The `FOR UPDATE` lock only works on the primary. | Primary |

The rule that falls out: **writes and read-after-write go to the primary; everything else can go to the replica.** This is the "read your own writes" pattern, and it lets results-day traffic, which is almost entirely parents reading finalised report cards, be served by replicas without any parent seeing an inconsistency.

This also connects to Portfolio 4: the MongoDB report cards are a deliberately stale copy, generated once and never updated. That is the same trade-off, taken further.

## Cloud deployment

The Docker setup proves the mechanism. For a real school, nobody should run their own replication. A managed PostgreSQL service does all of it:

| Need | Managed service feature |
|---|---|
| Replica for results day | Read replicas added with a click, removed after the week |
| Failover | Automatic: the service promotes a standby and repoints the connection string, typically in under a minute |
| Backups | Daily snapshots plus continuous WAL archiving, so the database can be restored to any point in time (point-in-time recovery) |
| Security | Encrypted at rest and in transit; private network access from the school's application only |

Any of Google Cloud SQL, Amazon RDS, Azure Database for PostgreSQL, or a serverless provider such as Neon would do. For a single school the smallest instance tier is enough for ten months of the year, with a read replica switched on for results weeks. The cost of running a replica permanently is hard to justify; the cost of running one for three weeks a year is small.

What the school gives up: direct control over the server, some PostgreSQL extensions, and it must trust the provider's uptime. For a school with no database administrator, that trade is clearly worth it.

## Alternative if Docker is not available

Create a free PostgreSQL project on Neon (neon.tech), which offers read replicas on its free tier. Load the Portfolio 1 scripts through its SQL editor or by registering the connection in pgAdmin, enable a read replica in the project settings, and run `01_check_primary.sql`, `02_check_replica.sql` and `03_replication_test.sql` against the two connection strings. The queries are the same; only the host changes. Screenshot the Neon dashboard showing the replica as deployment evidence.

## Reflection prompts

Write a few paragraphs in your own words:

1. How long was the replica behind the primary in your test? Would that lag ever be visible to a parent?
It was behind for about few seconds, typically measured in low millisecond
The lag would never be visible to parent because parent interact with read-only views (i.e parent will only see up-to-date information.
2. During failover, what did parents experience and what did teachers experience?
Since most parents perform read operations (viewing information), they may experience uninterruptable read access during primary failure but may encounter temporary error or timeout when performing write operations.
Teachers are heavy users of write operations (inputting grades and so on). During primary downtime, teachers would experience errors while trying to save or update records.
3. Why is partitioning by session more useful than sharding for Harmetage today?
Partitioning by session (such as dividing data by academic terms, years, or enrollment sessions) is far more practical for Harmetage today than sharding for several reasons: Data alignment with school operations and avoiding unnecessary complexity 
4. If you were advising the school, would you recommend managed cloud PostgreSQL or a server in the school office? What are the two strongest reasons?
My recommendation would be managed cloud PostgreSQL because of his reliability, security overhead and automated backups.

## Evidence

Save these in `evidence/`:

- [ ] `01_compose_ps.png`: both containers running
- [ ] `02_pgadmin_two_servers.png`: PRIMARY and REPLICA registered in pgAdmin, both showing the 17 tables
- [ ] `03_primary_stat_replication.png`: `pg_stat_replication` showing `streaming`
- [ ] `04_replica_lag.png`: lag query on the replica
- [ ] `05_replica_readonly_error.png`: the failed insert on the replica
- [ ] `06_replication_test.png`: P2 on the primary and R2 on the replica side by side
- [ ] `07_failover_primary_down.png`: pgAdmin unable to reach the primary
- [ ] `08_failover_promoted.png`: `pg_is_in_recovery()` returning false on the replica, and the insert succeeding
- [ ] `09_partition_rows.png`: rows per partition
- [ ] `10_partition_pruning.png`: the EXPLAIN plan touching only `attendance_2025`
- [ ] `11_partition_detach.png`: counts before and after detaching 2017
