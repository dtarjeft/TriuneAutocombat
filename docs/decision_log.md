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

**Addendum to DL-001, 2026-10-13 — an independent reviewer (ChatGPT) is adopted.** The developer pasted a description of a review process and, asked whether to adopt it, answered "I want you to use this process." It is recorded in `CLAUDE.md` ("Review process"). In short: ChatGPT reviews design decisions and has no write permissions; Claude brings each new decision to review before implementing it, with `HANDOFF` and `REVIEW OF` labels; ChatGPT answers Approve or Request changes, with a *For Claude* and a *For Shane* section; Claude weighs the review on its merits; technical consensus is not the developer's approval, and only the developer's own words approve. It adds to Protocol section 17 (one decision per handoff). Not yet verified: how well the relay works in practice; no review folder exists, so material is supplied inline or as files the developer provides. Applies from DL-003 onward; DL-001 and DL-002 were not reviewed this way.

**Second addendum to DL-001, 2026-10-13 — ChatGPT also reviews code from a review copy.** The developer created `C:\Users\legal\source\repos\TriuneAutocombat-Review` and said that whenever something is coded it must contain a copy of the repository so ChatGPT can review from it. Asked what the copy holds, the developer chose "A": everything except `TAC/resources` (about 1.1 GB of navmeshes and data; the rest of the tracked tree is 5.3 MB). Implementation choices (Claude's): the copy is made from the committed state of the checked-out branch (a temporary index, no `.git`; not `git archive`, because the repository marks `.github`, `.agents` and `.gitignore` export-ignore for release zips and the reviewer should see them); every copied file is verified against git; a `MANIFEST.txt` records branch, commit, date and the exclusion; the script removes only files a previous run listed and reports anything else. The helper is `C:\Users\legal\TAC-review-tools\refresh_review.sh`, outside the repository, as the developer's earlier decision on per-project helper scripts allows. The rule is in `CLAUDE.md` ("Review copy of the code"). First run: 52 files copied and verified (branch `feat/hook-priority`, commit `5442c8f`). Not verified: that ChatGPT can read the folder, and that the copy is enough for what it reviews (resource files are absent by design).

---

### DL-002 — TAC logs move to `Logs\TAC\`

- **Status:** In progress, 2026-10-13. Requirement agreed in conversation; design not yet agreed; nothing built. This entry lives on branch `feat/log-folder` until the feature merges.
- **Story:** the Protocol (§8) puts a script's logs in a folder named for the script under the MacroQuest `Logs` folder. TAC writes its logs flat into `Logs` (or into `config` when `Logs` cannot be used). Reading the code (2026-10-13): the main log (`tac/triune_log.lua`, `resolveDir`) builds `config/../Logs` and falls back through `config/../logs`, `config`, then the working folder, testing each by writing a probe file. The chat logs (`tac/chat.lua`) use `MacroQuest.Path('logs')` without probing. Nothing in TAC creates a folder. MacroQuest's documentation (`reference/data-types/datatype-macroquest.md`, docs commit `a85c4a6`) says the logs location is configurable and must be read from `${MacroQuest.Path[logs]}`, not hard coded. `lfs` is not bundled; the docs describe it as a LuaRocks module installed through PackageMan, which can be declined. The installed LuaFileSystem 1.9.0 manual documents `lfs.mkdir(dirname)`, returning `true`, or `nil` plus an error message and a system error code.
- **Requirement (developer's own words, confirmed 2026-10-13):**
  1. The folder is `Logs\TAC\`.
  2. Five kinds of file move into it: the main log and its `.old` rotation, the dump files, the chat tab logs, the chat trace file and the chat capture file.
  3. Chat history (`triune_chat_history_<server>_<Name>.txt`) stays in `config`, because TAC reads it back at the next start.
  4. Existing log files stay where they are; nothing is moved or copied.
  5. If the folder cannot be used, TAC behaves as it does today when a log location fails: it falls back and retries a failed open later, without a warning.
  6. TAC must ensure the folder exists, in two ways: the release ships the folder, and TAC creates it when it is missing.
  7. The main log asks MacroQuest where `Logs` is (`MacroQuest.Path('logs')`) instead of guessing `config/../Logs`.
  8. The README is updated to say the logs are in `Logs/TAC/`.
- **Design choices:** none agreed yet.
- **Implementation choices:** none.
- **Open:**
  - Whether the main log and the chat files share one function for the folder, and where it lives.
  - How a test build of this feature is named and versioned, given the version-must-match check (see DL-001).
  - What happens to the other, lower-priority fallback candidates the main log tries today.
  - Not yet verified: that `lfs.mkdir` succeeds against `Logs` in the running game; that it does not stall the client; that `MacroQuest.Path('logs')` returns a usable path at the point TAC first opens the log.
- **Shares a seam with:** DL-001 (version naming; the log move was named there as the first piece of work). The hook-priority work is unrelated.
- **Supersedes:** nothing.
- **Source:** developer statements in chat, 2026-10-13; `TAC/lua/tac/triune_log.lua`; `TAC/lua/tac/chat.lua`; the MacroQuest docs and the installed LuaFileSystem 1.9.0 manual cited above.

---

**Addendum to DL-002, 2026-10-13 — design choice 1 approved.** The developer chose Option A in their own words ("A"): one shared function decides the log folder. It lives in `tac/triune_log.lua`, which already manages log folders, and the chat plugin reads it through the core plugin API (a new manifest entry, with the chat plugin keeping its current behavior when the entry is absent). The function asks MacroQuest for the logs location, adds `TAC`, creates the folder when it is missing and `lfs` is available (under `pcall`), checks that it can be written, remembers the answer, and on failure falls back as today. Worst case stated to the developer: chat and core get out of step and chat logs fall back to flat `Logs`; no log is lost. The API entry's name and the function's exact shape are implementation choices, still to be made and shown. Still open: the version and name of a test build of this feature.

**Addendum to DL-002, 2026-10-13 — built locally on `feat/log-folder`; not installed, not live-tested.**
- **What was built (implementation choices, made by Claude):**
  - `triune_log.lua`: `resolveDir()` tries `<MacroQuest logs>/TAC` (creating it once with `lfs.mkdir` under `pcall` when it is missing), then the logs folder itself, then the old guess chain (`config/../Logs`, `config/../logs`, `config`, `.`). The answer is remembered. New `logDir()`; `M.SUBDIR = 'TAC'`. The logger takes a `logsPath` function and, for tests only, an `fs` table (`canWrite`, `mkdir`).
  - `triune.lua`: `runtime.mqLogsPath()` asks `MacroQuest.Path('logs')` (empty, `NULL`, nil and errors count as no answer); new core API entry `logDir` (experimental, since 1.0).
  - `chat.lua`: one `logsDir()` shared by the tab logs, the trace and the capture file; it uses `core.logDir()` when `core.hasCapability('logDir')`, else the old behaviour. The two help strings name `Logs/TAC/`. Chat history is untouched.
  - `TAC/Logs/TAC/README.txt` ships the folder in the release zips (`git archive` of `TAC/`). `README.md` and `CHANGELOG.md` updated.
- **Evidence (local tier only):** `tests/test_pure_logic.lua` Suite 119, 45 new assertions, each citing a DL-002 requirement; suite result 8473 passed and 2 failed (Suite 86 and Suite 103, the known failures; baseline before the change was 8428 passed and the same 2). Mutation check of 17 deliberate defects (scratch script, not in the repo): all 17 caught, 2 of them by crashing the run. Two mutations first survived (chat history moved into the log folder; one README line reverted); the tests were tightened and both are now caught. LuaJIT parse of the four Lua files, the version check (3.2 = 3.2) and the theme check pass. `luac5.1` and `luacheck` are not installed, so the CI lint has not been run on this change.
- **Not verified, and not to be described as confirmed:**
  - that `lfs.mkdir` creates `Logs\TAC` in the running game, including with the mixed separator in `C:\...\Logs/TAC`;
  - that creating the folder does not stall the client;
  - that `MacroQuest.Path('logs')` returns a usable path when TAC first opens a log;
  - that the Chat plugin picks up `core.logDir` in the running game (the tests use a fake core);
  - that the placeholder file extracts into `Logs\TAC\` from a real release zip;
  - that `luacheck` and `luac5.1` accept the change.
- **Open:** the name and version of a test build (DL-001). The method for the live check: install, run TAC with Log To File on, and look for the files in `Logs\TAC\`; no staged scenario is needed.

**Addendum to DL-002, 2026-10-13 — installed as test build `v3.2.0-log-folder-1` for the live check (developer's go-ahead, in their own words: "Yes, install it for the live check. You pick the build name and version.").**
- **Build identity (implementation choice, Claude's):** `v3.2.0-log-folder-1`. It is stamped only into the installed `triune.lua`, on the `VERSION` line, so the window title and the log header show it. The repository's `VERSION` stays `3.2` because several test suites assert `3.2` and CI requires it to match the README. The installed `triune.lua` is therefore the branch file with that one line changed; the other two files are byte-for-byte the branch files (compared after removing carriage returns; the line endings differ from the repository's working copy).
- **Installed:** `lua/triune.lua`, `lua/tac/triune_log.lua`, `lua/tac/chat.lua` in `C:\Users\Public\MacroQuest\`. Before the install these three matched `dev` exactly, so the baseline is `dev`. Backup of the replaced files: `C:\Users\legal\TAC-backup-20261013-140007\`.
- **Deliberately not installed:** `TAC/Logs/TAC/README.txt`, so that TAC has to create `Logs\TAC\` itself; the shipped-folder path is a plain file extraction and is checked separately.
- **How the live check works (no staged scenario):** restart TAC, turn on Log To File (`/ac log on`), then read `Logs\` and `Logs\TAC\`. If `triune_<server>_<character>.log` is in `Logs\TAC\`, `lfs.mkdir` worked. If it is in `Logs\` instead, the folder could not be created and TAC fell back silently as designed; that outcome would not say why, and would be a reason to add a diagnostic. Chat tab logging, if switched on for a tab, should write to the same folder.

**Addendum to DL-002, 2026-10-13 — first live observation of `v3.2.0-log-folder-1` (read from disk by Claude at 16:33–16:34).**
- **Observed:** `C:\Users\Public\MacroQuest\Logs\TAC\` exists, created at 16:33, the same minute TAC started and logging was switched on; the placeholder `README.txt` was not installed, so TAC created the folder. It holds `triune_multiclass_Kylaeris.log`, whose header reads `Triune v3.2.0-log-folder-1` and whose line `File logging ENABLED -> C:\Users\Public\MacroQuest\Logs/TAC/triune_multiclass_Kylaeris.log` names the new path. No error or warning about logging appears in the first 29 lines read. The flat `Logs\` copy of the same log (`triune_multiclass_Kylaeris.log`, 16:33, 4.4 MB) is the old file that was already there; its modified time of 16:33 was not examined further and should not be read as proof that nothing new went to it.
- **Now supported by observation:** `lfs.mkdir` created `Logs\TAC` in the running game with the mixed separator; the main log opens and writes there; the build identity shows in the log header.
- **Still not verified:** that the folder creation did not stall the client (nothing was measured; the developer has not reported a stall); `/ac dump` files; the chat tab logs, trace and capture (nothing was written, because chat tab logging is off) and therefore that the Chat plugin uses `core.logDir` in the game; log rotation to `.old` inside `Logs\TAC`; that a release zip extracts the placeholder into `Logs\TAC\`.

**Addendum to DL-002, 2026-10-13 — second live observation (16:35).** `/ac dump` was run by the developer; `Logs\TAC\triune_dump_multiclass_Kylaeris_20261013_163419.log` (98 KB) exists, and its header names `v3.2.0-log-folder-1`. So the dump files go to `Logs\TAC\` in the running game (requirement 2, dump files: observed). The main log in the same folder was still growing (29 KB at 16:35). No chat tab log, trace or capture file has been written anywhere yet, so the Chat plugin's use of `core.logDir` remains unverified in the game, as do the stall question, rotation to `.old` inside `Logs\TAC`, and extraction of the placeholder from a release zip.

**Addendum to DL-002, 2026-10-13 — third live observation (16:37).** The developer switched on "Log to file" for a chat tab. `Logs\TAC\tac_chat_Kylaeris_All_20261013.txt` exists (5.7 KB and growing) and no `tac_chat_*` file exists anywhere else under the MacroQuest folder (searched to depth 3). So the Chat plugin's tab logs go to `Logs\TAC\` in the running game, which also shows the plugin took the folder from `core.logDir` rather than falling back to `MacroQuest.Path('logs')` (the fallback would have written to flat `Logs\`). Observed for the main log, dump files and chat tab logs. Not observed: the chat draw trace and capture files (they need `/tacchat trace on` plus a draw error, and the capture command). Still unverified: that folder creation did not stall the client, rotation to `.old` inside `Logs\TAC`, and extraction of the placeholder from a release zip.

**Addendum to DL-002, 2026-10-13 — closed; merged into `dev`.** The developer said the live check is done and told Claude to merge ("The live check is done, merge it into dev"). Merged into local `dev` with a merge commit; the branch `feat/log-folder` is deleted. Not pushed (code needs a push request). What the developer accepted as not observed live: the chat draw trace and capture files, a stall measurement, rotation to `.old` inside `Logs\TAC`, and extraction of the placeholder from a release zip. The installed test build `v3.2.0-log-folder-1` stays in MacroQuest for now.
