# TAC Project Ledger

Maintained per [Development_Protocol.txt](Development_Protocol.txt) Section 11. This ledger tracks the project's *current state*. Read it first to orient; consult [decision_log.md](decision_log.md) for rationale, history and active overrides only as needed. Do not rebuild the current state by reading the whole decision log.

When new evidence resolves an open question, update the ledger before building on that conclusion. Update entries in place so the ledger describes the present, but keep every correction visible (a struck-through line with a note, or "resolved, see below"); never rewrite silently. If a correction is material, add a decision log entry for it. Do not record the hash of HEAD here: it is always one commit stale.

## Up next

Cold start (replace this block as the state changes; read it first):

- The development protocol was adopted on 2026-10-13. This ledger, the decision log and the lessons log were created that day. The decision log holds one retrofit entry, DL-001, covering the agreements of that day; the ledger and lessons log hold no further entries.
- Done and merged into local `dev` (not pushed): TAC's logs move to `Logs\TAC\` (DL-002). The developer called the live check done on 2026-10-13 after the main log, `/ac dump` files and chat tab logs were seen landing in `Logs\TAC\`. **Still installed in MacroQuest: test build `v3.2.0-log-folder-1`**, that is the merged `dev` files with `VERSION` stamped in the installed `triune.lua` only; what to do with it is not decided. The files it replaced are backed up in `C:\Users\legal\TAC-backup-20261013-140007\` (the earlier `TAC-backup-20261013-075343` also remains).
- Done and merged into local `dev` (not pushed): priority ordering for `onCommand` and `onBetweenPulls` (DL-003). All four design decisions were reviewed by ChatGPT and approved by the developer; the implementation was reviewed by ChatGPT (snapshot `70245f7`, recommended for merge) and the developer said "Merge it." Built and passing local tests and a 15-point mutation check. **Not installed in MacroQuest, nothing verified live; the developer skipped the live check.** Known gap: it is not verified that no two shipped plugins claim the same command, so the new id order could change which plugin answers one (the static scan was inconclusive for 15 plugins). Before a release: run `luacheck` and `luac5.1` (CI), neither of which has run on this change.
- The test build `v3.2.0-log-folder-1` (from DL-002) is still what is installed in MacroQuest; it does not include the hook-priority code.

## Pending live verification

Implemented but not yet confirmed in the live game.

- `Logs\TAC\` (DL-002), the parts never observed live: the chat draw trace and chat capture files (local tests only); that creating the folder does not stall the client (not measured); rotation of the main log to `.old` inside `Logs\TAC\`; that a release zip extracts the shipped `TAC/Logs/TAC/README.txt` into `Logs\TAC\`. The developer accepted the live check as done without these.

## Resolved behavior

Only behavior we have actually agreed upon.

- TAC's logs go to `Logs\TAC\` (requirements in DL-002; built, merged into local `dev`, live-checked for the main log, dump files and chat tab logs). Chat history stays in `config`; old log files stay where they are.
- Test builds are named `v3.2.0-<feature>-<N>`: the base version, the feature, then a counter that rises with each build of that feature (developer, 2026-10-13).

## Confirmed live/system facts

Facts established through testing, source inspection, logs, or documentation.

- MacroQuest's docs say the logs folder is configurable and must be read from `${MacroQuest.Path[logs]}` (`reference/data-types/datatype-macroquest.md`, docs commit `a85c4a6`, read 2026-10-13).
- `lfs` is not bundled with MacroQuest; its docs describe it as a LuaRocks module installed through PackageMan (`lua/luarocks-modules.md`). LuaFileSystem 1.9.0 is installed on the developer's machine and its manual documents `lfs.mkdir` (read 2026-10-13).
- Before DL-002, TAC wrote the main log to `config/../Logs` (a guess) and the chat logs to `MacroQuest.Path('logs')`, and nothing in TAC created folders (code reading, 2026-10-13).
- Live, 2026-10-13, test build `v3.2.0-log-folder-1` (read from disk): TAC created `Logs\TAC\` itself with `lfs.mkdir` using the mixed-separator path `C:\Users\Public\MacroQuest\Logs/TAC`; the main log, a `/ac dump` file and a chat tab log (`tac_chat_Kylaeris_All_20261013.txt`) were written there, and no chat file was written anywhere else (DL-002 addenda).

## Open implementation details

Questions intentionally unresolved; surface them for discussion when they become relevant.

- How the Protocol's file schema (logs in `macroquest\logs\<luaname>\`, config in `macroquest\config\<luaname>\`) applies to existing TAC files: the developer has said logs move out of `config` first; what happens to the per-server loadout, chat and DPS files, and the exact folder names, are not decided.
- How pre-release test build names fit with the version-must-match check between `triune.lua` and `README.md`. For `v3.2.0-log-folder-1` the name was stamped into the installed `triune.lua` only and not committed; whether that is the standing method is not decided.

## Out of scope

Things we have explicitly decided not to build or investigate. Nothing yet.
