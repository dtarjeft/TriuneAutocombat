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

### DL-001 — Retrofit: adopting the Development Protocol and the working agreements made on 2026-10-13

- **Status:** Retrofit entry, 2026-10-13 (Protocol §19). The decisions below were made in conversation on 2026-10-13 before this log existed. Confirmed means the developer said it in chat; nothing here has been exercised in practice yet.
- **Story:** the project (a fork of the archived `gennro/TriuneAutocombat`, based on v3.2.0) had working rules only in `CLAUDE.md` and `.agents/AGENTS.md`. The developer supplied a general development protocol, `docs/Development_Protocol.txt`, written for another project, and asked for it to govern this one. Applying it needs a decision log, a project ledger and a lessons log, none of which existed. The developer supplied copies of those three documents from the other project as structural references; they were read first and then cleared for TAC.
- **Requirement (developer's own words, confirmed):**
  1. `docs/Development_Protocol.txt` governs development. `CLAUDE.md` points to it as mandatory reading.
  2. Test builds are named `v3.2.0-<feature>-<N>`: the base version, the feature, then a counter that rises with each build of that feature.
  3. The decision log and project ledger must exist and be maintained. They were created on this date, along with a lessons log.
  4. The developer maintains `docs/sibling-project.txt`, the list of the developer's other projects on this platform and what they cover (Protocol §21).
  5. The developer decides when a session ends (Protocol §22). The ledger and decision log must be current before that point.
  6. MacroQuest behavior is read from the MacroQuest documentation (https://github.com/macroquest/docs), not guessed.
  7. Docs-only changes may be committed and pushed directly to `dev` without a feature branch and without asking, except docs about a feature still on a feature branch, which stay on that branch until the feature merges.
  8. TAC's logs move out of `config` and into the MacroQuest `Logs` folder. This is the first piece of work. Only the direction is agreed.
- **Design choices:** none agreed yet. How the log move is done, which files move, and the folder layout are not decided.
- **Implementation choices:** Claude chose the three documents' structure (taken from the reference copies, with the other project's content removed), put the version-naming and other agreements in `CLAUDE.md`, and made the ledger's cold-start block short.
- **Open:**
  - How the Protocol §8 file schema (logs in `macroquest\logs\<luaname>\`, configs in `macroquest\config\<luaname>\`) applies to existing TAC files beyond logs.
  - How pre-release test build names fit the rule that `triune.lua` and `README.md` versions must match.
  - Earlier decisions recorded only in `docs/HOOKS.md` section 9 are not retrofitted here. Whether to do so is not decided.
  - Not yet verified: that the Protocol's process (one change at a time, mutation-checked tests, handoff review) works in practice on this project.
- **Shares a seam with:** none yet. The log move (item 8) will touch the per-server file naming already described in `CLAUDE.md`.
- **Supersedes:** nothing in a specification. It adds to `CLAUDE.md`'s rules; where `CLAUDE.md` says "do not push anything unless asked", the docs-only exception in item 7 applies.
- **Source:** developer statements in chat, 2026-10-13; `docs/Development_Protocol.txt`; commits `0b9c0cb`, `d7a572f`, `0394b30` and `203cbca`.

**Addendum to DL-001, 2026-10-13 — decisions made after reviewing `docs/New_Project_Kit.md`** (the kit was written for another project; it is reference material, not adopted wholesale). Developer's own words, confirmed:

- **User stories are a conversation, on a trial basis this session.** A story is not written as a formal document. The developer talks it through with Claude. Claude's restatement and the labelled items (Requirement, Assumption, Open) from the Protocol still apply to what comes out of that conversation. The trial's result is not yet judged. `User_Story_Template.md` is not being used.
- **There is no `SPEC.md`.** TAC is an existing project, not a new one, so nothing is created from scratch. This resolves the "SPEC.md" question the kit raised. `docs/HOOKS.md` stays the plugin API contract and is not a project spec.
- **Helper scripts are made per project, when needed.** Scripts from another project (such as its mutation runner or review-folder scripts) are not reused unless the developer says so, because they may not suit this project.

Not yet decided from the kit review: whether the ledger gets a Dependencies section, and whether TAC needs a single check command. Not verified: that conversational stories carry enough evidence for the decision log; revisit after the first one is done.

---
