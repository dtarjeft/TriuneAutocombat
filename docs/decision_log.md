# TAC Decision Log

Maintained per [Development_Protocol.txt](Development_Protocol.txt) Section 2. This log records *why* material decisions were made and how they evolved. It describes history, not current state: current state lives in [project_ledger.md](project_ledger.md). Append to it as decisions are made; do not reconstruct it from memory.

## How an entry works

- Entry IDs are `DL-NNN`, numbered in order and never reused. Each entry starts from a story: the observed behavior or problem and what is actually known, before any solution.
- Each entry has these labeled blocks. Approving a name or a number is not approving a requirement; do not let approval of one block imply approval of another.
  - **Status:** confirmed, provisional, or dependent on an open question, with the date.
  - **Requirement:** behavior explicitly stated or approved by the developer.
  - **Design choices:** the shape of the solution, agreed with the developer.
  - **Implementation choices:** details left to Claude.
  - **Open:** unresolved questions, and a list of what is **not yet verified** and must not be described as confirmed. Update that list as items are resolved.
  - **Shares a seam with:** other entries touching the same hook point, data or ordering constraint, written when the entry is made.
  - **Supersedes:** the earlier decision or spec item this changes, if any.
  - **Source:** the evidence, requirement or constraint that drove it.
- The log is append-only. Never rewrite an entry; add a dated **Addendum** under it so the correction and the original reasoning are both visible.
- Work done outside the main repository or session still gets an entry (a retrofit entry if found later, Protocol §19).

## Active overrides index

Entries that supersede a specification item are listed here, so the supersession is visible without cross-referencing the whole log. Format: `DL-NNN SUPERSEDES <document> <section>: <one line>`.

(none yet)

---
