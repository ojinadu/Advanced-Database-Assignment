# Portfolio 2: Query Processing and Optimisation

Case study: **Harmetage Private School** (see the [root README](../README.md)).

This activity measures how fast the school's most common queries run, reads the execution plan PostgreSQL chooses for each, adds indexes, and compares the plans and timings before and after.

## How to run (pgAdmin)

Run the files in `sql/` in this order. Use a Query Tool opened on the `harmetage` database.

1. `01_scale_up_data.sql`: open it and press F5. It takes 1 to 2 minutes. The last result should show the row counts listed below, and `inconsistent scores (must be 0)` must be `0`.
2. `02_vacuum_analyze.sql`: run it on its own. It refreshes the statistics PostgreSQL uses to plan queries.
3. `03_queries.sql`: highlight one query at a time, press F5, and screenshot the result.
4. `04_explain_queries.sql`: highlight the two `SET` lines and run them, then highlight one `EXPLAIN` block at a time. Run each twice and record the second `Execution Time`. These are the **BEFORE** plans.
5. `05_create_indexes.sql`: run the whole file.
6. `04_explain_queries.sql` again: same steps. These are the **AFTER** plans.

To redo the BEFORE measurements, run `06_drop_indexes.sql`.

If step 1 says the bulk data is already loaded, rerun Portfolio 1 scripts `01_schema.sql` and `02_seed_data.sql` first, then start again.

## Why the data was scaled up

Portfolio 1 has 360 students. At that size PostgreSQL reads whole tables in a millisecond or two, so an index can't show any benefit. `01_scale_up_data.sql` adds eight earlier sessions (2017/2018 to 2024/2025), each with 6 levels, 6 arms per level and 32 students per arm.

| Table | Rows after scale-up |
|---|---|
| `academic_session` | 9 |
| `term` | 27 |
| `class_arm` | 300 |
| `subject_allocation` | 3,000 |
| `student` | 9,576 |
| `enrolment` | 9,576 |
| `score` | 287,280 |
| `attendance` | 655,344 |
| `payment` | about 26,000 to 27,000 (random, so it varies slightly) |

The earlier students are synthetic and marked `GRADUATED`. They have no guardian rows, because nothing in this portfolio needs them. Each earlier session uses its own set of students rather than following one cohort through the years. That is a shortcut to get volume quickly, and it doesn't affect the query timings.

## The queries

| ID | Question the school asks | Table that matters |
|---|---|---|
| Q1 | Which students were absent on 14 Oct 2025? | `attendance` (655k rows) |
| Q2 | Which scores did one teacher enter in December 2025? | `score` (287k rows) |
| Q3 | Average score per subject and teacher for first term | `score` |
| Q4 | Payment history for one student | `payment` |
| Q5 | First term class positions for SS2A | `enrolment`, `score` |
| Q6A and Q6B | Absences per class in October 2025, written two ways | `attendance` |

Q6A and Q6B return the same answer. Q6A filters with `EXTRACT(YEAR ...)` and `EXTRACT(MONTH ...)`. Q6B filters with a date range. This pair shows an optimisation that isn't an index at all: rewriting the query so an index can be used.

## How to read an execution plan

Read the plan from the innermost, most indented line outward.

| You see | Meaning |
|---|---|
| `Seq Scan` | PostgreSQL reads every row of the table. Fine for small tables, slow for large ones. |
| `Index Scan` | It uses an index to jump to the matching rows. |
| `Bitmap Index Scan` and `Bitmap Heap Scan` | It uses an index to collect the matching row locations, then reads those pages in order. Common when a medium number of rows match. |
| `Index Only Scan` | The index alone has everything the query needs, so the table isn't touched. |
| `Rows Removed by Filter` | Rows that were read and then thrown away. A big number means wasted work. |
| `Buffers: shared hit / read` | `hit` pages came from memory, `read` pages came from disk. Fewer is better. |
| `Execution Time` | How long the query took, in milliseconds. This is the number to compare. |

## Indexes added

| Index | Columns | Intended for |
|---|---|---|
| `idx_attendance_date_status` | `attendance (attendance_date, status)` | Q1, Q6B |
| `idx_score_recorded_by_at` | `score (recorded_by, recorded_at)` | Q2 |
| `idx_score_term_alloc_total` | `score (term_id, allocation_id) INCLUDE (total)` | Q3 |
| `idx_payment_student_term` | `payment (student_id, term_id)` | Q4 |
| `idx_enrolment_class_arm` | `enrolment (class_arm_id)` | Q5 |

PostgreSQL already builds an index for every primary key and `UNIQUE` constraint, so some lookups were fast from the start. For example, `score` can already be searched by `enrolment_id` because that is the first column of its primary key. The indexes above cover lookups the existing ones can't help with.

In a two-column index the order matters. `(recorded_by, recorded_at)` works well for "this teacher, in this date range". It would not help a query that filters only on `recorded_at`.

`INCLUDE (total)` in the Q3 index stores the score total inside the index, so PostgreSQL can calculate the averages without reading the table at all.

## Results

Fill this in from your own plans. Don't copy numbers from anyone else, because timings depend on your machine.

The **Prediction** column is for you to complete before you run the AFTER plans. Writing a prediction first and then checking it is the quickest way to understand what is going on.

| Query | Plan type BEFORE | Time BEFORE (ms) | Prediction | Plan type AFTER | Time AFTER (ms) | Speed-up |
|---|---|---|---|---|---|---|
| Q1 | Sort | 31.139ms | Bit faster | Sort | 1.880ms | 16.563 |
| Q2 | Sort | 33.022ms | Bit faster | Sort | 1.714ms | 19.266 |
| Q3 | Sort | 26.755ms | Bit faster | Sort | 5.483ms | 4.879 |
| Q4 | Sort | 4.205ms | Bit faster | Sort | 0.163ms |  25.797 |
| Q5 | Limit | 2.255ms | Much faster | Limit | 1.263ms | 1.785 |
| Q6A | Group aggregrate | 96.806ms| Much faster | Group aggregrate | 22.868ms | 4.233 |
| Q6B | Group aggregrate | 79.084ms| Much faster | Sort | 5.693ms | 13.891 |

Speed-up = time before divided by time after.

## Performance analysis

Write this section yourself once the table is filled in, in a few short paragraphs. Cover:

1. **Which queries improved most, and why.** The most improved queries are Q2 and Q4, it shows a massive performance change. In the plan, both queries were replaced by the Bitmap index scan from the sequential scan.
In the before plan, values were high because thousands of heap pages had to be fetched and read into the memory. In the after plan, it dropped significantly because the index filter narrowed down the target tuples before reading the table pages.
2. **Which queries barely changed, and why.** The least improved queries is Q5, which the before time is 2.255ms and the after time is 1.263ms (a quiet low performance). Q5 used a primary key index that returns a large share of the table, where reading the table is cheap.
3. **The cost of indexes.** The cost of the index size is 4608KB which is 4.6MB. The index is lightweight. Paying 4 MB of disk space to trade a 96ms disk scan for a 5ms index lookup is a massive performance win for the database.
4. **Anything that surprised you.** The change effect in the operator of Q6b which transition from *Group aggregate* 79.084ms as the before time to *Sort* (5.693ms) as the after time.

## Limitations

- All timings come from one machine on a synthetic data set. They show the direction and rough size of each improvement, not exact production numbers.
- Earlier sessions have first term attendance only, and no guardian records.
- The score consistency trigger is switched off while the earlier scores are bulk loaded and switched back on straight after. The final check in `01_scale_up_data.sql` proves no inconsistent rows got through.
- `max_parallel_workers_per_gather = 0` and `jit = off` are set while measuring so plans are simple and comparable. A real server would normally leave both on.

## Evidence

Save these in `evidence/`:

- [ ] `01_scale_up_summary.png`: the row counts after the scale-up, with `inconsistent scores` at 0
- [ ] `q1_result.png` to `q6b_result.png`: the result of each query (7 screenshots)
- [ ] `q1_before.png` to `q6b_before.png`: the BEFORE plan for each query (7 screenshots)
- [ ] `indexes_created.png`: script 05 completing successfully
- [ ] `q1_after.png` to `q6b_after.png`: the AFTER plan for each query (7 screenshots)
- [ ] `index_sizes.png`: the index size query from the analysis section

