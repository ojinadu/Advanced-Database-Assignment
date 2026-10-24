// =====================================================================
// Portfolio 4: indexes. Run one line at a time in mongosh.
// =====================================================================

use harmetage

// Before: how does MongoDB answer the "all terms for one student" query?
// Look for "stage": "COLLSCAN" (reads every document).
db.report_cards.find({ "student.admission_no": "HPS/2025/0001" }).explain("executionStats").executionStats

// A parent always looks up by admission number: index it.
db.report_cards.createIndex({ "student.admission_no": 1, term: 1 })

// A form teacher looks up by class and term: index that too.
db.report_cards.createIndex({ "student.class": 1, term: 1, "summary.position": 1 })

// After: look for "stage": "IXSCAN" and compare totalDocsExamined.
db.report_cards.find({ "student.admission_no": "HPS/2025/0001" }).explain("executionStats").executionStats

// List the indexes.
db.report_cards.getIndexes()
