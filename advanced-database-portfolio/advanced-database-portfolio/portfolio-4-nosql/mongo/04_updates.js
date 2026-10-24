// =====================================================================
// Portfolio 4: updates that show why a document model suits report cards.
// =====================================================================

use harmetage

// U1. The form teacher adds a comment. The comments array grows; no new
//     table, no schema change, no migration.
db.report_cards.updateOne(
  { _id: "HPS/2025/0001|2025/2026|T1" },
  { $push: { comments: { by: "Form Teacher", text: "Hard-working and punctual. Keep it up.", at: new Date() } } }
)

// U2. The principal adds a comment too.
db.report_cards.updateOne(
  { _id: "HPS/2025/0001|2025/2026|T1" },
  { $push: { comments: { by: "Principal", text: "An excellent result.", at: new Date() } } }
)

// U3. Mark the report card as released to parents.
db.report_cards.updateOne(
  { _id: "HPS/2025/0001|2025/2026|T1" },
  { $set: { released: true, released_at: new Date() } }
)

// U4. See the result. Note that other documents do NOT have "released"
//     or any comments: documents in one collection can differ in shape.
db.report_cards.findOne({ _id: "HPS/2025/0001|2025/2026|T1" }, { comments: 1, released: 1, released_at: 1 })

// U5. Release every first-term report card in one go.
db.report_cards.updateMany({ term: 1 }, { $set: { released: true } })
db.report_cards.countDocuments({ released: true })
