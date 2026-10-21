# Portfolio 3: Transactions and Concurrency

Case study: **Harmetage Private School** (see the [root README](../README.md)).

This activity shows what happens when several people use the school database at the same time, and how PostgreSQL keeps the data correct. Five experiments: commit and rollback, a lost update, an overbooked class, isolation levels, and a deadlock. Each concurrency experiment shows the problem first, then the fix.

## How to run (pgAdmin)

Experiments 2 to 5 need **two Query Tool tabs open at the same time**, one playing person A and one playing person B. Each tab is its own connection, so PostgreSQL treats them as two separate users.

1. `00_setup.sql`: run the whole file once with F5. Screenshot the two result tables.
2. `01_commit_rollback.sql`: one tab. Highlight one block at a time and press F5.
3. `02_lost_update_A.sql` and `02_lost_update_B.sql`: open A in one tab and B in another. Each step is labelled (A1, B1, A2 ...). Highlight one step, press F5, then switch tabs for the next step. The order is written at the top of each file.
4. `03_overbooking_A.sql` / `03_overbooking_B.sql`: same method.
5. `04_isolation_A.sql` / `04_isolation_B.sql`: same method.
6. `05_deadlock_A.sql` / `05_deadlock_B.sql`: same method.
7. `06_reset.sql`: run the whole file to put the data back as it was.

Important: run the steps in the written order and don't skip any. Some steps deliberately **freeze** (the tab shows the query still running) until you run the next step in the other tab. That freeze is the lock working, and it's worth a screenshot.

If you get confused half way through an experiment, run `ROLLBACK;` in both tabs, then run `06_reset.sql` and `00_setup.sql` and start that experiment again.

## The experiments

### 1. Commit, rollback and savepoint

| Block | What it shows |
|---|---|
| 1A | Admitting a student touches four tables (student, guardian, link, enrolment). Inside one transaction they all succeed together, then `COMMIT`. |
| 1B | The same admission with a duplicate guardian phone number. The second insert fails, and PostgreSQL rolls back the **whole** transaction, so no half-admitted student is left behind. 1C proves it. |
| 1D | The bursar records a payment, sees it inside the transaction, then runs `ROLLBACK`. The payment vanishes. |
| 1E | A teacher saves two scores. The second breaks a `CHECK` constraint. `ROLLBACK TO SAVEPOINT` undoes only the bad one, and the good one is still committed. |

This is atomicity, the A in ACID: a transaction either happens completely or not at all.

### 2. Lost update

Two teachers open the same Mathematics CA1 score (18) at the same time. Teacher A changes it to 20 and saves. Teacher B, still looking at 18, changes it to 15 and saves. Teacher A's work is silently gone.

**Fix:** `REPEATABLE READ`. When B tries to save, PostgreSQL sees the row changed since B read it and refuses with `could not serialize access due to concurrent update`. B must reload and decide again. Nothing is lost silently.

### 3. Overbooking a class

JSS1A has 30 students and a capacity of 31, so one seat is free. Two admissions officers each check ("30 of 31, there's room"), then each insert. Result: 32 students, one more than the class can hold. Checking and then acting is not safe when two people do it at once.

**Fix:** `SELECT ... FOR UPDATE` on the class row before checking. Officer A locks the row. Officer B's lock request freezes until A commits. When B gets the lock and counts, the class is full, so B doesn't insert. Pessimistic locking: lock first, then look.

### 4. Isolation levels

The bursar runs a fee report that totals a student's payments twice. A parent pays online between the two totals.

| Isolation level | What the report saw |
|---|---|
| `READ COMMITTED` (default) | Two different totals in one report. This is a **non-repeatable read**. |
| `REPEATABLE READ` | The same total both times. The report works from a snapshot taken when it began. The new payment appears only after the report ends. |

Part 3 shows that a payment inserted but not yet committed in Tab B is invisible to Tab A. PostgreSQL never allows **dirty reads**, at any isolation level.

### 5. Deadlock

Teacher A locks student 0001's score then asks for student 0002's. Teacher B locks student 0002's then asks for student 0001's. Each is waiting for the other, forever. PostgreSQL notices within about a second and cancels one of them with `ERROR: deadlock detected`. The other finishes normally.

**Fix:** a rule rather than code. Always update rows in the same order (for example lowest `enrolment_id` first). Then two transactions can never each hold what the other wants.

## Summary of mechanisms

| Problem | Mechanism that solves it | Type |
|---|---|---|
| Half-finished admission | Transaction with `COMMIT` / `ROLLBACK` | Atomicity |
| One bad entry in a batch | `SAVEPOINT` | Partial rollback |
| Lost update | `REPEATABLE READ` isolation | Optimistic: detect the conflict, reject the loser |
| Overbooking | `SELECT ... FOR UPDATE` | Pessimistic: lock first |
| Non-repeatable read | `REPEATABLE READ` isolation | Snapshot |
| Deadlock | Consistent lock ordering | Prevention |

## Which approach for Harmetage?

Write this yourself after running the experiments. Questions to cover:

1. For score entry, would you choose the `REPEATABLE READ` approach (let both teachers try, reject the second) or the `FOR UPDATE` approach (first teacher locks the row)? Teachers enter scores in bursts at the end of term, and conflicts on the same score are rare. Which costs less?
During the end of the term score entry, conflicts are rare and teacher works in an unexpected speed. ‘REPETABLE READ’ is better.
Under REPEATABLE READ, the database does not hold locks while teachers are actively typing or thinking. Because conflicts happen rarely, almost all transactions succeed on the first try without waiting. 
FOR UPDATE, on the other hand, aggressively locks database rows as soon as the first teacher touches them. This forces concurrent teachers to block and wait, increasing contention and overhead during peak end-of-term reporting periods when database resources are already stretched thin.
2. For class enrolment on admission day, why is locking the better choice?
Because more than one staff members can attempt to register a student in a class at the same time which can exceed the physical maximum capacity of a class.
Locking is necessary so as to eliminate over-enrolment bug (31 students in class meant for 30), which will force the second transaction to wait until the first transaction is updated
3. Should the fee report use `REPEATABLE READ` always? What would a parent think if a receipt and a report disagreed?
No.
If a parent think a receipt and report disagree, it will lead to lack of trust, inconsistency and disputes between the parent and the school
4. What did PostgreSQL do about the deadlock, and what should the school's application do when it receives that error?
When PostgreSQL detects a deadlock, it automatically steps in as an impartial referee. It aborts and rolls back one of the transactions (throwing a red error, such as a serialization or deadlock failure) to allow the other transaction to proceed and finish its work.
The school's application code should catch this specific deadlock error, wait for a brief, randomized backoff period (milliseconds), and automatically retry the transaction. Because deadlocks are usually temporary timing collisions under high concurrency, a clean retry will almost always succeed on the second attempt without requiring human intervention

## Evidence

Save these in `evidence/`:

- [ ] `00_setup_ids.png`: the two tables from the setup script
- [ ] `01a_commit_proof.png`, `01b_rollback_error.png`, `01c_no_student.png`, `01d_rollback_payment.png`, `01e_savepoint_proof.png`
- [ ] `02_lost_update_problem.png`: A3 showing 15 instead of 20
- [ ] `02_lost_update_fix.png`: B5 showing the serialization error
- [ ] `03_overbooking_problem.png`: A3 showing 32 of 31
- [ ] `03_overbooking_waiting.png`: Tab B frozen on B4 (the lock)
- [ ] `03_overbooking_fix.png`: A6 showing 31 of 31
- [ ] `04_nonrepeatable_read.png`: A1 and A2 with different totals
- [ ] `04_repeatable_read.png`: A4 and A5 with the same total
- [ ] `04_no_dirty_read.png`: A7 showing 0 rows
- [ ] `05_deadlock_error.png`: B2 showing `deadlock detected`
- [ ] `06_reset.png`: the reset completing
