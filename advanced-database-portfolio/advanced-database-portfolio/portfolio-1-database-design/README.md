# Portfolio 1: Database Design and Modelling

Case study: **Harmetage Private School**, a private secondary school (JSS1 to SS3) running a three-term academic session. The full case study statement is in the [root README](../README.md).

This folder contains the relational design for the school: the ER diagram, the PostgreSQL schema, seed data, tests that prove the constraints work, and queries that prove the design supports the school's day-to-day operations.

## How to run

From the repository root:

```bash
docker compose up -d

docker exec -i harmetage-pg psql -v ON_ERROR_STOP=1 -U harmetage -d harmetage \
  -f /workspace/portfolio-1-database-design/sql/01_schema.sql

docker exec -i harmetage-pg psql -v ON_ERROR_STOP=1 -U harmetage -d harmetage \
  -f /workspace/portfolio-1-database-design/sql/02_seed_data.sql

docker exec -i harmetage-pg psql -U harmetage -d harmetage \
  -f /workspace/portfolio-1-database-design/sql/03_constraint_tests.sql \
  2>&1 | tee portfolio-1-database-design/evidence/03_constraint_tests_output.txt

docker exec -i harmetage-pg psql -U harmetage -d harmetage \
  -f /workspace/portfolio-1-database-design/sql/04_verification_queries.sql \
  2>&1 | tee portfolio-1-database-design/evidence/04_verification_output.txt
```

Running `01_schema.sql` drops and rebuilds the `harmetage` schema, so the whole sequence can be rerun from scratch.

### Running with pgAdmin instead of Docker

1. Create a database called `harmetage` in pgAdmin.
2. Open the Query Tool on it, open `sql/01_schema.sql`, and press F5. Do the same with `sql/02_seed_data.sql`.
3. Open `sql/03_constraint_tests_pgadmin.sql`. Highlight one test at a time, press F5, and screenshot the error in the Messages tab. Tests 1 to 11 should fail. Test 12 should succeed.
4. Open `sql/04_verification_queries_pgadmin.sql`. Highlight one query at a time, press F5, and screenshot the Data Output tab.

The `_pgadmin` files are the same tests and queries with the psql-only commands (`\echo`, `\set`) removed, because the Query Tool doesn't support them.

| File | Purpose |
|---|---|
| `er-diagram.md` | ER diagram in Mermaid (renders on GitHub) |
| `sql/01_schema.sql` | Tables, keys, constraints and the score consistency trigger |
| `sql/02_seed_data.sql` | Synthetic data for the 2025/2026 session |
| `sql/03_constraint_tests.sql` | Deliberately invalid statements that the database must reject |
| `sql/03_constraint_tests_pgadmin.sql` | Same tests, formatted for the pgAdmin Query Tool |
| `sql/04_verification_queries.sql` | Report card, class positions, fee debtors, attendance, siblings |
| `sql/04_verification_queries_pgadmin.sql` | Same queries, formatted for the pgAdmin Query Tool |
| `evidence/` | Captured outputs and screenshots |

## What the data looks like

The seed script builds one session (2025/2026) with six levels and two arms per level, so 12 class arms in total. Each arm has 30 students, which gives 360 students. Juniors take 10 subjects and seniors take 10, with one teacher per subject per stage. Scores exist for all three terms (10,800 rows). Attendance covers the 70 school days of first term (25,200 rows). Fee payments follow a realistic mix: most parents pay in full, some pay in two instalments, and some still owe, with more debtors in third term. Every 12th student is a sibling of the student before and shares their guardian.

All names, phone numbers and emails are synthetic. No real student or staff data is used.

## Entities

| Table | What it holds | Primary key |
|---|---|---|
| `academic_session` | A school year such as 2025/2026 | `session_id` |
| `term` | The three terms inside a session | `term_id` |
| `class_level` | JSS1 to SS3 | `level_id` |
| `class_arm` | One stream of a level in a session, e.g. JSS1A | `class_arm_id` |
| `subject` | Subjects, tagged junior, senior or both | `subject_id` |
| `subject_allocation` | Which teacher takes which subject in which arm | `allocation_id` |
| `staff` | Teachers, principal, bursar, admin staff | `staff_id` |
| `student` | Student bio data and status | `student_id` |
| `guardian` | Parents and guardians | `guardian_id` |
| `student_guardian` | Links students to guardians (many to many) | (`student_id`, `guardian_id`) |
| `enrolment` | A student's class arm for a session | `enrolment_id` |
| `score` | CA1, CA2 and exam per student, subject and term | (`enrolment_id`, `term_id`, `allocation_id`) |
| `attendance` | Daily attendance | (`enrolment_id`, `attendance_date`) |
| `fee_item` | Tuition, development levy, ICT, laboratory | `fee_item_id` |
| `fee_schedule` | Amount each level pays per item per term | (`level_id`, `term_id`, `fee_item_id`) |
| `payment` | Money received from parents | `payment_id` |
| `grade_scale` | Score bands for grades A to F | `grade` |

Where a table represents a thing (student, staff, class arm), I used a surrogate identity key and kept the real-world identifier (admission number, staff number) as a `UNIQUE` column. Admission numbers are visible to people and occasionally get corrected. A surrogate key means a correction touches one row instead of every table that references the student.

Where a table only records a fact about other things (a score, an attendance mark, a fee amount), I used the natural composite key. The composite key already guarantees one score per student per subject per term, and adding a surrogate would mean maintaining a second unique index to enforce the same rule.

## Keys and constraints

| Constraint | Where | Rule it enforces |
|---|---|---|
| `CHECK (ca1 BETWEEN 0 AND 20)` and similar | `score` | CA1 and CA2 are out of 20, exam out of 60 |
| Generated column `total` | `score` | Total is always CA1 + CA2 + exam and cannot be edited by hand |
| `UNIQUE (student_id, session_id)` | `enrolment` | A student sits in only one class per session |
| Composite FK `(class_arm_id, session_id)` | `enrolment` | The enrolment's session matches the class arm's session |
| Trigger `trg_score_consistency` | `score` | A score must use a subject taught in the student's own arm, in a term of the student's own session |
| Partial unique index on `is_primary` | `student_guardian` | At most one primary contact per student |
| `EXCLUDE USING gist (band WITH &&)` | `grade_scale` | Grade bands never overlap, so each total maps to one grade |
| `CHECK (ISODOW BETWEEN 1 AND 5)` | `attendance` | Attendance only on weekdays |
| `UNIQUE (session_id, form_teacher_id)` | `class_arm` | A teacher is form teacher of one arm per session at most |
| `UNIQUE (level_id, session_id, arm)` | `class_arm` | No duplicate JSS1A in the same session |
| `CHECK (amount > 0)`, `UNIQUE (reference)` | `payment` | No negative payments and no reused payment references |
| FK without `ON DELETE CASCADE` | `enrolment`, `score`, `payment` | A student with academic or financial history can't be deleted, only marked `WITHDRAWN` or `GRADUATED` |

`sql/03_constraint_tests.sql` tries to break each of these rules and records the error PostgreSQL returns.

The score trigger exists because a foreign key can only point at one table. The rule "the subject allocation must belong to the same class arm as the enrolment" compares two different parent rows. I could have copied `class_arm_id` into `score` and used two composite foreign keys, but that column would depend on `enrolment_id` alone, which is part of the key. That's a partial dependency and breaks 2NF, so I enforced the rule in a trigger instead.

## Normalisation

The starting point is how many schools actually keep results: one spreadsheet per class per term, a row per student, and a column group per subject.

**Unnormalised form (UNF).** One record per student per term:

```
ResultSheet(AdmissionNo, StudentName, DOB, Class, FormTeacher, Session, Term,
            GuardianName, GuardianPhone,
            { Subject, SubjectTeacher, CA1, CA2, Exam, Total, Grade },   <- repeating group
            AmountDue, AmountPaid, Balance)
```

The subject group repeats 10 times per row. Adding an eleventh subject means changing the sheet's structure, and you can't ask a simple question like "average Mathematics score" without scanning ten different columns.

**First normal form (1NF).** I removed the repeating group so every row holds one subject for one student in one term, with atomic values only:

```
Result(AdmissionNo, Session, Term, Subject, StudentName, DOB, Class, FormTeacher,
       GuardianName, GuardianPhone, SubjectTeacher, CA1, CA2, Exam, Total, Grade)
Key: (AdmissionNo, Session, Term, Subject)
```

Fee columns come out here too. They describe a student's term, not a subject, and repeating the balance on all ten subject rows would guarantee inconsistencies.

**Second normal form (2NF).** Several attributes depend on only part of the key:

| Dependency | Problem | Resolved into |
|---|---|---|
| AdmissionNo → StudentName, DOB | Name repeated on every score row | `student` |
| (AdmissionNo, Session) → Class | Class repeated for every subject and term | `enrolment` |
| (Session, Term) → term dates | Dates repeated for every student | `term` |

After this step, `score` holds only CA1, CA2 and exam, fully dependent on (student's enrolment, term, subject).

**Third normal form (3NF).** Transitive dependencies remain, where a non-key attribute determines another non-key attribute:

| Dependency | Problem | Resolved into |
|---|---|---|
| Class → FormTeacher | Changing a form teacher meant editing 30 student rows | `class_arm.form_teacher_id` |
| (Class, Subject) → SubjectTeacher | Teacher repeated for every student in the arm | `subject_allocation` |
| GuardianPhone → GuardianName | Siblings stored the same guardian twice, with drift risk | `guardian` + `student_guardian` |
| Total → Grade | Changing the grading policy meant rewriting every result | `grade_scale`, looked up by range |
| CA1, CA2, Exam → Total | Total could disagree with its parts | Generated column |
| Fees due, paid → Balance | Stored balance goes stale on every payment | Computed in queries, never stored |

The generated `total` column is technically a derived value stored in the table. I kept it because PostgreSQL computes it on every write, so it can't disagree with CA1, CA2 and exam, and the result queries in Portfolio 2 can filter and sort on it directly.

**Boyce-Codd normal form (BCNF).** Leaving aside the generated `total` covered above, every table is in BCNF except `enrolment`, and that exception is deliberate. `enrolment` has the dependency `class_arm_id → session_id`, and `class_arm_id` alone isn't a key of the table. That breaks BCNF. It still satisfies 3NF, because `session_id` is part of the candidate key (`student_id`, `session_id`), and 3NF allows a dependency whose right-hand side is a prime attribute.

I accepted this because it lets the database enforce "one class per student per session" with a plain `UNIQUE` constraint. The redundancy can't cause an update anomaly because the composite foreign key to `class_arm (class_arm_id, session_id)` rejects any `session_id` that disagrees with the class arm. The only alternative was another trigger, and I'd rather have a declarative constraint the query planner and other developers can see.

## Known limitations

- Subject stage is not enforced against class level. Nothing stops an allocation of Physics (senior) to JSS1A. The seed data respects it, and a trigger similar to the score check could close this gap.
- `subject_allocation.teacher_id` accepts any staff member, not only teachers. A principal who also teaches is realistic, so I left this open on purpose.
- Class arm `capacity` is stored but not enforced on enrolment. Enforcing it correctly under concurrent registrations is the concurrency problem I'll demonstrate in Portfolio 3.
- Foreign key columns have no indexes yet. PostgreSQL doesn't create them automatically, and I left them out so Portfolio 2 can measure the difference they make.
- Senior students all take the same 10 subjects. A real school would split science, commercial and arts streams. The design supports this already, since allocations are per arm, but the seed data doesn't model it.

## Evidence

Evidence to be captured in `evidence/`:

- [ ] `03_constraint_tests_output.txt` (psql) or one screenshot per test (pgAdmin): every rejected statement with its error
- [ ] `04_verification_output.txt` (psql) or one screenshot per query (pgAdmin): report card, positions, debtors, attendance, siblings
- [ ] Screenshot of `\dt harmetage.*` listing all 17 tables
- [ ] Screenshot of `\d harmetage.score` showing the keys, checks, generated column and trigger
- [ ] ER diagram exported as PNG from mermaid.live, or from pgAdmin's ERD tool
