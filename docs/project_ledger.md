# TAC Project Ledger

Maintained per [Development_Protocol.txt](Development_Protocol.txt) Section 11. This ledger tracks the project's *current state*. Read it first to orient; consult [decision_log.md](decision_log.md) for rationale, history and active overrides only as needed. Do not rebuild the current state by reading the whole decision log.

When new evidence resolves an open question, update the ledger before building on that conclusion. Update entries in place so the ledger describes the present, but keep every correction visible (a struck-through line with a note, or "resolved, see below"); never rewrite silently. If a correction is material, add a decision log entry for it. Do not record the hash of HEAD here: it is always one commit stale.

## Up next

Cold start (replace this block as the state changes; read it first):

- The development protocol was adopted on 2026-10-13. This ledger, the decision log and the lessons log were created that day. The decision log holds one retrofit entry, DL-001, covering the agreements of that day; the ledger and lessons log hold no further entries.
- In progress: moving TAC's logs into `Logs\TAC\` (DL-002), on branch `feat/log-folder`, not merged and not pushed. Built, with passing local tests and a 17-point mutation check. **Installed 2026-10-13 as test build `v3.2.0-log-folder-1`** (see DL-002 install addendum); **nothing is verified live yet.** Waiting on the developer to restart TAC and turn on Log To File; I then read `Logs\` and `Logs\TAC\` to see where the files went. The previous files are backed up in `C:\Users\legal\TAC-backup-20261013-140007\`.
- Paused: priority ordering for `onCommand` and `onBetweenPulls` (see `docs/HOOKS.md` sections 3.2, 9 and 10). A design was proposed but nothing was agreed or built.

## Pending live verification

Implemented but not yet confirmed in the live game.

- `Logs\TAC\` for the main log, dump files, chat tab logs, chat trace and chat capture (DL-002, `feat/log-folder`). Local tests only. Unverified: that `lfs.mkdir` creates the folder in the running game and does not stall the client; that `MacroQuest.Path('logs')` is usable when the log first opens; that the Chat plugin uses `core.logDir` in the game; that a release zip extracts the placeholder into `Logs\TAC\`.

## Resolved behavior

Only behavior we have actually agreed upon.

- TAC's logs go to `Logs\TAC\` (requirements in DL-002: agreed, built locally, not yet verified live). Chat history stays in `config`; old log files stay where they are.
- Test builds are named `v3.2.0-<feature>-<N>`: the base version, the feature, then a counter that rises with each build of that feature (developer, 2026-10-13).

## Confirmed live/system facts

Facts established through testing, source inspection, logs, or documentation.

- MacroQuest's docs say the logs folder is configurable and must be read from `${MacroQuest.Path[logs]}` (`reference/data-types/datatype-macroquest.md`, docs commit `a85c4a6`, read 2026-10-13).
- `lfs` is not bundled with MacroQuest; its docs describe it as a LuaRocks module installed through PackageMan (`lua/luarocks-modules.md`). LuaFileSystem 1.9.0 is installed on the developer's machine and its manual documents `lfs.mkdir` (read 2026-10-13).
- Before DL-002, TAC wrote the main log to `config/../Logs` (a guess) and the chat logs to `MacroQuest.Path('logs')`, and nothing in TAC created folders (code reading, 2026-10-13).

## Open implementation details

Questions intentionally unresolved; surface them for discussion when they become relevant.

- How the Protocol's file schema (logs in `macroquest\logs\<luaname>\`, config in `macroquest\config\<luaname>\`) applies to existing TAC files: the developer has said logs move out of `config` first; what happens to the per-server loadout, chat and DPS files, and the exact folder names, are not decided.
- How pre-release test build names fit with the version-must-match check between `triune.lua` and `README.md`.

## Out of scope

Things we have explicitly decided not to build or investigate. Nothing yet.
