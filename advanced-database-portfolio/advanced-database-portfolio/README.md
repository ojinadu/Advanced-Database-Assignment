# Advanced Database Systems Portfolio

MIT 8103 Advanced Database Systems, First Semester Continuous Assessment, 2026/2027 session
Miva Open University, Master of Information Technology

Student: [Oluwatosin Jinadu] ([2026/A/MIT/0352])

## Case study: Harmetage Private School

Harmetage Private School is a private secondary school running JSS1 to SS3 on a three-term academic session. The school needs a database to manage student records, academic results, attendance and fee payments across its academic calendar. The school, its staff and its students in this portfolio are simulated, and all data is synthetic.

**Users of the database.** Administrators handle admissions and records. Teachers and form teachers record scores and attendance. The bursar records fee payments. The principal approves and reviews results. Students and parents view results and fee status.

**Major data stored.** Students and their guardians, staff, class levels and arms, subjects, sessions and terms, subject allocations to teachers, enrolments, continuous assessment and exam scores, attendance, fee schedules and payments.

**Key operations.** Admit and enrol students into class arms, allocate subjects to teachers, record CA and exam scores, compute term results and class positions, generate report cards, track attendance, record fee payments and identify outstanding balances.

## Repository structure

| Folder | Activity | Status |
|---|---|---|
| [`portfolio-1-database-design`](portfolio-1-database-design/) | ER diagram, relational schema, keys, constraints, normalisation | Done |
| [`portfolio-2-query-optimisation`](portfolio-2-query-optimisation/) | SQL queries, execution plans, indexing, performance analysis | Done |
| [`portfolio-3-transactions-concurrency`](portfolio-3-transactions-concurrency/) | Commit, rollback, isolation levels, concurrency control | Done |
| [`portfolio-4-nosql`](portfolio-4-nosql/) | NoSQL model for the same school | Done |
| [`portfolio-5-distributed-cloud`](portfolio-5-distributed-cloud/) | Replication, availability, consistency, deployment | Not started |

## Tools

- PostgreSQL 16, run locally with Docker (`docker-compose.yml`)
- psql for running scripts and capturing output
- Mermaid for the ER diagram

## Getting started

```bash
docker compose up -d
docker exec -it harmetage-pg psql -U harmetage -d harmetage
```

Each portfolio folder has its own README with the exact commands to run and the evidence produced.

## AI use declaration

1. **AI tool used:** Claude (Anthropic).
2. **What it was used for:** [Describe honestly, e.g. drafting the initial schema, seed data scripts and README text for Portfolio 1.]
3. **How I reviewed and verified the output:** [Describe what you actually did, e.g. ran every script against PostgreSQL 16, checked row counts and constraint test outputs, corrected X, and rewrote the design explanations in my own words.]

## References

- PostgreSQL Global Development Group (2024). *PostgreSQL 16 Documentation*. https://www.postgresql.org/docs/16/
- Elmasri, R. and Navathe, S. B. (2016). *Fundamentals of Database Systems* (7th ed.). Pearson.
