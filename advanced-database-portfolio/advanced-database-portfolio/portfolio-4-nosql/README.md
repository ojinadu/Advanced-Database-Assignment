# Portfolio 4: NoSQL and Advanced Data Models

Case study: **Harmetage Private School** (see the [root README](../README.md)).

This activity takes one part of the school's data, the term report card, and models it in MongoDB as a document instead of across relational tables. It exports the real data from PostgreSQL, imports it into MongoDB, runs queries, aggregations and updates, and then argues where the document model fits and where it doesn't.

## How to run

### Part 1: export from PostgreSQL (pgAdmin)

1. Open `sql/01_export_report_cards.sql` in a Query Tool on `harmetage`.
2. Highlight from `SET search_path` down to the end of the `CREATE VIEW` statement and press F5.
3. Highlight the preview `SELECT jsonb_pretty(...)` and run it. Screenshot the document.
4. Highlight the `count(*)` query and run it. Expect 1,080.
5. Edit the file path in the `COPY ... TO` command at the bottom to a folder on your computer, highlight only that command, and run it. A file `report_cards.json` appears there, one document per line.

### Part 2: import into MongoDB (Compass)

1. Install MongoDB Community Server and MongoDB Compass (see the walkthrough in the conversation, or mongodb.com/try/download/community).
2. Open Compass and connect to `mongodb://localhost:27017`.
3. Create a database `harmetage` with a collection `report_cards`.
4. Open the collection, click **Add Data → Import JSON or CSV file**, choose `report_cards.json`, and import. Expect 1,080 documents.

### Part 3: queries (Compass mongosh panel)

Open the `>_MONGOSH` panel at the bottom of Compass and run the files in `mongo/` one command at a time:

| File | What it does |
|---|---|
| `01_queries.js` | Find queries, including searching inside the subjects array |
| `02_indexes.js` | Explain plan before and after creating indexes |
| `03_aggregations.js` | Group, unwind and compare across terms |
| `04_updates.js` | Add comments and a release flag without changing any schema |

## The document

Each document is one student's report card for one term. Everything a parent sees on the printed report card is inside it.

```json
{
  "_id": "HPS/2025/0001|2025/2026|T1",
  "student": { "admission_no": "HPS/2025/0001", "name": "...", "gender": "M",
               "class": "JSS1A", "form_teacher": "..." },
  "session": "2025/2026",
  "term": 1,
  "term_ends": "2025-12-12",
  "subjects": [
    { "code": "MTH", "name": "Mathematics", "teacher": "...",
      "ca1": 18, "ca2": 15, "exam": 44, "total": 77, "grade": "A", "remark": "Excellent" },
    ...
  ],
  "summary": { "average": 64.3, "position": 7, "class_size": 30, "subject_count": 10 },
  "attendance": { "present": 63, "late": 4, "absent": 2, "excused": 1, "school_days": 70 },
  "comments": [],
  "generated_at": "..."
}
```

The `_id` is built from the admission number, session and term, so the same report card can never be imported twice.

## Relational versus document: the same report card

In PostgreSQL, printing one report card joins eight tables: `student`, `enrolment`, `score`, `subject_allocation`, `subject`, `staff`, `term` and `grade_scale`, plus `attendance` for the summary and a window function for the class position. The query in Portfolio 1 (`04_verification_queries.sql`, query 2) does exactly this.

In MongoDB it is `findOne({ _id: ... })`. One read, no joins, no computation.

That is not because MongoDB is cleverer. It's because the work was done once, at export time, and the result stored. The relational database computes the report card every time it's asked; the document database stores the answer.

## Why the document model suits report cards

**Written once, read many times.** A report card is finalised at the end of term. After that it is never recalculated, but it is read thousands of times: by parents on results day, by the student, by the school when printing transcripts years later. Precomputing it and storing it whole fits that pattern.

**It's a natural unit.** Nobody wants half a report card. The subjects, the summary, the attendance and the comments are always read together, so storing them together means one disk read instead of nine.

**It's a historical record.** A report card from 2019 should say what it said in 2019, even if the student later changed class, the teacher left, or the grading bands changed. In the relational model, the grade is looked up live from `grade_scale`, so changing the bands rewrites history. The document freezes it.

**The shape varies.** Juniors and seniors take different subjects. Some report cards get a principal's comment and some don't. Term 1 has attendance and terms 2 and 3 don't yet. A document holds whatever that report card has; a table would need nullable columns or extra tables for each variation. `04_updates.js` shows a comment being added to one document with `$push` and no schema change anywhere.

## Why the relational model still owns the source data

The document is a copy. PostgreSQL remains the system of record, for these reasons:

**Scores change before release.** A teacher corrects a CA score. In the document model that means regenerating the report card and every statistic in it (average, position, class ranking for all 30 classmates). In the relational model it's one `UPDATE` and the next query is correct.

**The same data serves many views.** A subject teacher's mark sheet, a class ranking, a subject average across the school and a report card are all different arrangements of the same scores. Storing them normalised once and joining as needed avoids keeping four copies in sync.

**Constraints.** PostgreSQL rejects a CA1 of 25, a score for a subject the student doesn't take, or a student enrolled in two classes (Portfolio 1 tests all of these). MongoDB would accept any of them unless validation is added at the application layer or with schema validation rules.

**Transactions.** Enrolling a student touches four tables atomically (Portfolio 3). MongoDB supports multi-document transactions, but it is not the natural grain of the system.

## Where each fits at Harmetage

| Data | Store | Reason |
|---|---|---|
| Students, staff, enrolments, raw scores, payments | PostgreSQL | Changes often, needs constraints and joins, is the source of truth |
| Finalised report cards | MongoDB | Written once, read many times, varies in shape, must freeze history |
| Live class ranking during results entry (optional) | Redis sorted set | Key-value store keyed by `class:term`, `ZADD` on each score, `ZREVRANK` for position in constant time |

The Redis row is a discussion point, not implemented here. It would suit a live leaderboard-style view while teachers are still entering scores, before the report cards are generated.

## Indexes in MongoDB

`02_indexes.js` runs the "all terms for one student" query with `explain("executionStats")` before and after creating an index on `student.admission_no`. Before, the plan stage is `COLLSCAN` and `totalDocsExamined` is 1,080. After, it is `IXSCAN` and `totalDocsExamined` is 3. Same idea as Portfolio 2, different database.

MongoDB's `_id` is always indexed, which is why `findOne({ _id })` is fast from the start.

## Reflection prompts

Write a few paragraphs in your own words after running everything:

1. Query 2 in `01_queries.js` and query 2 in Portfolio 1 return the same report card. Which was easier to write? Which would you rather maintain if the school changed its grading bands?
2. What happens to the MongoDB copy when a score is corrected in PostgreSQL after export? How would you keep them in sync?
3. Did the aggregation pipeline feel harder or easier than SQL `GROUP BY`? Why?
4. Would you store fee payments as documents? Why or why not?

## Evidence

Save these in `evidence/`:

- [ ] `01_view_created.png`: the view being created in pgAdmin
- [ ] `02_document_preview.png`: the pretty-printed JSON for student 0001
- [ ] `03_export_count.png`: the count of 1,080 and the COPY command succeeding
- [ ] `04_compass_import.png`: Compass showing 1,080 documents in `report_cards`
- [ ] `05_compass_document.png`: one document expanded in Compass
- [ ] `q1_count.png` to `q6_absences.png`: the six find queries
- [ ] `idx_before_collscan.png`, `idx_after_ixscan.png`, `idx_list.png`
- [ ] `agg1_class_average.png` to `agg4_improved.png`
- [ ] `upd_comments_added.png`, `upd_released_count.png`
