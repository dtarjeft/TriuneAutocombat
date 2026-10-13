# TAC Project Ledger

Maintained per [Development_Protocol.txt](Development_Protocol.txt) Section 11. This ledger tracks the project's *current state*. Read it first to orient; consult [decision_log.md](decision_log.md) for rationale, history and active overrides only as needed. Do not rebuild the current state by reading the whole decision log.

When new evidence resolves an open question, update the ledger before building on that conclusion. Update entries in place so the ledger describes the present, but keep every correction visible (a struck-through line with a note, or "resolved, see below"); never rewrite silently. If a correction is material, add a decision log entry for it. Do not record the hash of HEAD here: it is always one commit stale.

## Up next

Cold start (replace this block as the state changes; read it first):

- The development protocol was adopted on 2026-10-13. This ledger, the decision log and the lessons log were created that day. The decision log holds one retrofit entry, DL-001, covering the agreements of that day; the ledger and lessons log hold no further entries.
- First planned piece of work: move TAC's logs out of `config` and into the MacroQuest `Logs` folder. Nothing investigated or built yet.
- Paused: priority ordering for `onCommand` and `onBetweenPulls` (see `docs/HOOKS.md` sections 3.2, 9 and 10). A design was proposed but nothing was agreed or built.

## Pending live verification

Implemented but not yet confirmed in the live game. Nothing yet.

## Resolved behavior

Only behavior we have actually agreed upon.

- Test builds are named `v3.2.0-<feature>-<N>`: the base version, the feature, then a counter that rises with each build of that feature (developer, 2026-10-13).

## Confirmed live/system facts

Facts established through testing, source inspection, logs, or documentation. Nothing recorded yet.

## Open implementation details

Questions intentionally unresolved; surface them for discussion when they become relevant.

- How the Protocol's file schema (logs in `macroquest\logs\<luaname>\`, config in `macroquest\config\<luaname>\`) applies to existing TAC files: the developer has said logs move out of `config` first; what happens to the per-server loadout, chat and DPS files, and the exact folder names, are not decided.
- How pre-release test build names fit with the version-must-match check between `triune.lua` and `README.md`.

## Out of scope

Things we have explicitly decided not to build or investigate. Nothing yet.
