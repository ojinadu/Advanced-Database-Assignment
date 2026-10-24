// =====================================================================
// Portfolio 4: aggregation pipeline. Run one pipeline at a time.
// =====================================================================

use harmetage

// A1. Average score per class for first term (like SQL GROUP BY).
db.report_cards.aggregate([
  { $match: { term: 1 } },
  { $group: { _id: "$student.class", class_average: { $avg: "$summary.average" }, students: { $sum: 1 } } },
  { $sort: { _id: 1 } }
])

// A2. Average per SUBJECT across the whole school, first term.
//     $unwind turns each subject in the array into its own row, then we group.
db.report_cards.aggregate([
  { $match: { term: 1 } },
  { $unwind: "$subjects" },
  { $group: { _id: "$subjects.name", average: { $avg: "$subjects.total" }, fails: { $sum: { $cond: [ { $eq: ["$subjects.grade", "F"] }, 1, 0 ] } } } },
  { $sort: { average: -1 } }
])

// A3. Grade distribution across the school, first term.
db.report_cards.aggregate([
  { $match: { term: 1 } },
  { $unwind: "$subjects" },
  { $group: { _id: "$subjects.grade", count: { $sum: 1 } } },
  { $sort: { _id: 1 } }
])

// A4. Students who improved their position from term 1 to term 2.
db.report_cards.aggregate([
  { $match: { term: { $in: [1, 2] } } },
  { $group: { _id: "$student.admission_no", name: { $first: "$student.name" },
              positions: { $push: { term: "$term", position: "$summary.position" } } } },
  { $project: { name: 1,
      t1: { $arrayElemAt: [ { $filter: { input: "$positions", cond: { $eq: ["$$this.term", 1] } } }, 0 ] },
      t2: { $arrayElemAt: [ { $filter: { input: "$positions", cond: { $eq: ["$$this.term", 2] } } }, 0 ] } } },
  { $project: { name: 1, t1: "$t1.position", t2: "$t2.position", improved_by: { $subtract: ["$t1.position", "$t2.position"] } } },
  { $match: { improved_by: { $gt: 5 } } },
  { $sort: { improved_by: -1 } },
  { $limit: 10 }
])
