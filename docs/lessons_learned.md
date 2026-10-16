# Lessons Learned (running log)

Kept so nothing depends on either of our memories. **This is not the Development Protocol and does not change it.** At a retrospective, each entry is triaged by the developer into: **Protocol** (general project process), **CLAUDE.md** (working agreement with the AI, or project-specific guidance), or **Noise** (drop it).

How this log works:
- Claude appends an entry whenever a lesson appears during work, with the evidence that produced it (a decision log entry, a commit, an incident).
- **Area** is what kind of lesson it is: Process, Collaboration, Technical or AI-behavior.
- **Suggested** is Claude's provisional guess at where it belongs. It is only a starting point for the retrospective.
- **Triage** stays blank until the retrospective. Do not fill it in earlier.
- Entries are append-only; a lesson found to be wrong is annotated, not deleted.

Entry format: `### LL-NNN — <title> (<date>)`, then **Area**, **What happened**, **Evidence**, **Suggested**, **Triage**.

---

### LL-001 — Per-item counts were stated from a table by eye and were wrong (2026-10-13)

- **Area:** AI-behavior
- **What happened:** after the corrected command scan, Claude reported how many commands three plugins had (33, 15 and 8) by counting words in the printed table instead of computing them. The reviewer found the real values (35, 16 and 7); the total of 98 was right. Nothing in the repository carried the wrong numbers, because the decision log and ledger record only the total.
- **Evidence:** the scan output; the reviewer's correction; a recount by script (35, 16, 7, summing to 98).
- **Suggested:** CLAUDE.md (any number reported from a listing is computed by a command, not counted by eye; "verify, then claim" already says this, so this may belong under Noise).
- **Triage:**
