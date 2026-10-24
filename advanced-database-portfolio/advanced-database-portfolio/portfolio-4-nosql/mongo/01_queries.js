// =====================================================================
// Portfolio 4: MongoDB queries. Run in the mongosh panel at the bottom
// of MongoDB Compass, one command at a time. Screenshot each result.
// =====================================================================

use harmetage

// Q1. How many report cards were imported? (expect 1080)
db.report_cards.countDocuments()

// Q2. One student's first term report card: ONE document, no joins.
//     Compare with Portfolio 1 query 2, which joined 8 tables for the same answer.
db.report_cards.findOne({ _id: "HPS/2025/0001|2025/2026|T1" })

// Q3. All three terms for one student, summary only.
db.report_cards.find(
  { "student.admission_no": "HPS/2025/0001" },
  { term: 1, "summary.average": 1, "summary.position": 1, _id: 0 }
).sort({ term: 1 })

// Q4. Top 5 in JSS1A for first term.
db.report_cards.find(
  { "student.class": "JSS1A", term: 1 },
  { "student.name": 1, "summary.average": 1, "summary.position": 1, _id: 0 }
).sort({ "summary.position": 1 }).limit(5)

// Q5. Students who failed Mathematics in first term (query INSIDE the array).
db.report_cards.find(
  { term: 1, subjects: { $elemMatch: { code: "MTH", grade: "F" } } },
  { "student.name": 1, "student.class": 1, _id: 0 }
)

// Q6. Students absent more than 5 days in first term.
db.report_cards.find(
  { term: 1, "attendance.absent": { $gt: 5 } },
  { "student.name": 1, "student.class": 1, "attendance.absent": 1, _id: 0 }
).sort({ "attendance.absent": -1 })
