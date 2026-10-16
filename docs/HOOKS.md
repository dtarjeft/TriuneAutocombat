# Plugin API: hooks, events, decisions and registries

**Status: DRAFT for review. Nothing in this document changes any code.**

This draft describes how plugins talk to TAC today and proposes a contract for how they should. It is deliberately
split so it cannot promise something that is not implemented:

| Marker | Meaning |
|---|---|
| **[CURRENT]** | Verified in the source (section 10 lists what was implemented since the first draft). Describes what the code does now, whether or not it was ever written down. |
| **[PROPOSED]** | A contract we would adopt. Not implemented, or implemented but not yet promised. |
| **[DECIDED]** | Agreed in review. Still not implemented unless the same text also says **[CURRENT]**. |
| **[OPEN]** | Undecided. Listed in section 9 under "Still open". |

Function names are given instead of line numbers because the line numbers drift. Everything marked **[CURRENT]** is in
`TAC/lua/triune.lua` (`runtime.initPluginManager`, the `pm` table) unless another file is named.

---

## 1. Why this exists

TAC's core file is large and close to Lua 5.1's limit of 200 active locals in its main chunk. The direction is to grow
TAC through plugins, and to change core mostly by exposing hooks. That only works if plugin authors can build without
asking for a core change each time, and if the core can change without breaking them. This document is the proposed
agreement between the two.

An inventory of the 24 shipped plugins plus the external Enchanter Mez Support plugin (a text scan, not a runtime
trace, so counts are approximate) is summarised in section 7 and the appendices. It is the evidence for the first API
set.

---

## 2. Tiers and versioning

### 2.1 Today **[CURRENT]**

- **Implemented since the first version of this draft:** `core.apiVersion` (the string `"1.0"`), `core.apiVersionInfo`,
  `core.apiAtLeast(major, minor)`, the manifest `core.api` and `core.hasCapability(name)` (section 10). Before that,
  a plugin that needed the registry checked `type(core.registerTargetSelector) == 'function'` by hand (the mez plugin
  still does).
- The manifest so far lists only the entries added with it; the 65 existing keys are not in it yet, so
  `hasCapability` answers `false` for them.
- The plugin core API is the table built in `runtime.initPluginManager` (65 keys). It also contains `runtime`, the
  whole runtime table, which plugins read and call freely.
- Nothing says which of that a plugin may rely on across releases.

### 2.2 Proposed tiers **[PROPOSED]**

| Tier | Promise |
|---|---|
| **Stable** | Documented. Name, arguments, return values, **timing and calling context** and meaning will not change within a major version. Breaking one needs a major bump and a deprecation period. |
| **Experimental** | Documented. May change in a minor release. Every change is called out in the release notes. |
| **Internal** | Reachable (`core.runtime` and anything not listed) but with **no promise at all**. A plugin that uses an internal member owns the breakage. |

Raw `core.runtime` stays available as an unsupported escape hatch. Plugin authors can experiment, and their use shows
what is missing from the supported API. The aim is to move recurring uses into supported accessors, events and
registries, not to remove access.

### 2.3 What `apiVersion` promises **[PROPOSED]**

`core.apiVersion` is a **string**, `"MAJOR.MINOR"`, with structured access
(`core.apiVersionInfo = { major = 1, minor = 10 }`) and a helper `core.apiAtLeast(major, minor)`. Plugins must not
compare versions as Lua numbers: `1.10` and `1.1` are the same number.

- **Minor** bump: additions (a new hook, function, event, registry or optional argument), and changes to
  **experimental** entries, which are called out in the release notes. **The compatibility promise covers stable
  capabilities only:** a plugin that uses only stable entries and was written for `N.x` keeps working on `N.y` for
  `y >= x`. Experimental entries carry no such promise within a major version, and internal ones none at all.
- **Major** bump: anything that changes the arguments, return values, **timing, calling context or meaning** of a
  stable entry, or removes one.
- Behaviour changes are documented in prose release notes even when the signature is unchanged. A signature check is
  not a compatibility check.
- **[DECIDED]** Deprecation window, by example: an entry deprecated in `1.4` is retained throughout `2.x` and may be
  removed in `3.0`. The manifest flags it as deprecated. TAC warns once per session when it can see a deprecated
  function called or a deprecated registration used. The warning is **best-effort**: it does not promise to detect every
  read of a deprecated table or field.
- **[DECIDED]** The version is the string `"MAJOR.MINOR"`, starting at `"1.0"`, with `core.apiVersionInfo` and
  `core.apiAtLeast(major, minor)`. The minor-version promise covers stable entries only.

### 2.4 Capability manifest **[PROPOSED]**

A single table, for example `core.api`, listing every supported entry with its kind (hook, event, decision, registry,
function), tier and the version that introduced it. It is the source for:

- `core.hasCapability(name)` (covers hooks, events, registries and functions; there is no separate `hasHook`),
- the generated API reference, and
- the generated "what changed" summary (additions and tier changes only).

**[DECIDED]** There is one check, `core.hasCapability(name)`; `hasHook` is not added.

A plugin that uses an optional capability checks for it at `onInit` and degrades gracefully, as the mez plugin does when
the target selector registry is missing.

---

## 3. The three mechanisms

The plugin manager already mixes three different kinds of call under one dispatcher. They need different rules.

### 3.1 Events: "this happened" **[CURRENT]**

Dispatch (`dispatch(hookName, firstTrue=false, ...)` in `initPluginManager`):

- Iterates `pm.pluginOrder` (load order). A plugin receives the call only if it is `enabled` and its status is not
  `Error`. A plugin in the `Sleeping (Combat)` state (see `runOutOfCombatOnly`) still receives events.
- Each handler runs under `xpcall`. The return value is ignored. An error is reported once
  (`pm.reportError`) and sets the plugin's status to `Error`.

Events dispatched this way: `onCombatTick(targetId)`, `onZoned(zoneName)`, `onLoadoutSaved()`.

Timing worth knowing **[CURRENT]**: `onCombatTick` runs from the main loop immediately after `combatTick`, once per
pass that ran `combatTick` (throttled to roughly 0.4 s). The Enchanter plugin relies on that ordering: the combat engine
has already restored the previous target by the time the hook runs.

`onLoadoutSaved` is dispatched but no shipped plugin implements it.

**[PROPOSED]** contract: handlers must not assume order relative to other plugins, must not block, and must tolerate
being called during zoning or while combat is paused.
**[DECIDED]** load order is not promised for events (section 3.2).

### 3.2 Decisions: "what should happen" **[CURRENT]**

Three hooks are dispatched with `firstTrue = true`:

| Hook | Combine rule today | What a `true` means |
|---|---|---|
| `wantsCombatHold()` | first truthy wins | the combat loop should stand still (`runtime.combatHold()`) |
| `onBetweenPulls()` | first truthy wins, in `priority` order | the plugin started something; the puller should yield this tick |
| `onCommand(cmd, args)` | first truthy wins, in `priority` order | the plugin handled the `/ac <cmd>` fallthrough |

The target selector registry (section 3.3) is a fourth kind: exactly one resolver per name.

Three different combine rules are in use and none has a name. **[PROPOSED]** names:

- **any-true** (an OR / veto): `wantsCombatHold`.
- **first-handled** (a claim): `onCommand`, `onBetweenPulls`.
- **single-resolver**: a registry entry with one owner.

**[PROPOSED]** every decision mechanism must state: its combine rule, whether order matters, what an error means (fail
closed or fail open), how often it may be called, and what it may cost. Decisions that run in a hot path (a target
selector runs for every gem evaluation) must be cheap or cache per `tickSerial`.
**[PROPOSED]** decisions must not depend on load order. Where two plugins could conflict, the mechanism either refuses
the second (as the registry refuses a name collision) or takes an explicit priority.

**[DECIDED]** Order and priority:

- Events carry no ordering promise.
- The **first-handled** mechanisms (`onCommand`, `onBetweenPulls`) are ordered by an explicit `priority` field in the
  plugin manifest (a number, higher first, default 0). **Tie rule:** equal priorities are ordered by plugin id,
  alphabetically, so the result is stable and documented. Load order is not used. Distinctive command names still help,
  but they do not resolve two plugins that both claim a command or both answer `onBetweenPulls`; priority does.
  **[CURRENT]** Implemented (docs/decision_log.md DL-003). Details:
  - A plugin declares `priority = <number>` on the table its file returns. It must be a **finite Lua number**: negatives
    and fractions are fine, there is no range limit, and integers are recommended. A missing `priority` is 0. Anything
    else (a string, **including `'10'`**, a table, a boolean, NaN, infinity) counts as 0, the plugin still loads, and core
    writes one warning to the TAC log for that plugin each time it loads.
  - Core builds the order each time one of the two hooks runs: the enabled plugins that have the hook, sorted by
    `priority` (highest first), then by plugin id (plain string comparison). Every other hook, `wantsCombatHold`
    included, still runs in load order.
  - `priority` is read when the plugin's file is loaded. Editing the file changes nothing until the plugin is reloaded
    (the Reload button, or reload all). `restartAll` does not re-read files.
  - `core.hasCapability('hookPriority')` is true when core honours it. Check it in `onInit` (and that `core.hasCapability`
    exists at all: V3.2 has neither). An older core runs both hooks in load order and ignores the field.
  - Do not confuse this with the per-action `priority` (1 to 99) on spell gems, discs and clickies. That one runs
    **lowest first**. The plugin field runs **highest first**.

  Example. Two plugins both implement `onCommand` and both can handle `/ac mez`:

  ```lua
  -- tac/mez.lua
  return { id = 'mez', name = 'Mez', priority = 10, onCommand = function(cmd) return cmd == 'mez' end }
  -- tac/mezlite.lua
  return { id = 'mezlite', name = 'Mez Lite', priority = 5, onCommand = function(cmd) return cmd == 'mez' end }
  ```

  `mez` (10) is asked first and handles the command, so `mezlite` (5) is never called for it. With both at 5, the ids
  decide: `mez` before `mezlite`. If `mez` returns false, the next plugin is asked.
- `wantsCombatHold` is **advisory**. A plugin can ask the combat loop to stand still, but it is not a guaranteed safety
  interlock, and plugins must not rely on it as one.

**[DECIDED]** Safe defaults. A failing decision falls back to the state in which TAC does nothing new and is not
blocked:

| Mechanism | On error |
|---|---|
| target selector | no target |
| `wantsCombatHold` | do not hold |
| `onBetweenPulls` | do not yield |
| `onCommand` | not handled |
| events | nothing |

Section 4.4 separates a failing hook from a failing plugin.

### 3.3 Registries: "I provide this" **[CURRENT]**

The only registry today is the target selector registry (`core.registerTargetSelector` and
`core.unregisterTargetSelector`), described in the Enchanter plugin repository's `docs/TAC-INTEGRATION.md`:

- Registration names an `owner` (the plugin id), a `label`, a `side` (`E` or `F`), help text and a `resolve(ctx)`
  function returning a spawn id or nil. A non-table spec, an empty label, a label with a side prefix, a non-function
  resolver, a bad side, a collision with a built-in label and a label already owned by another plugin are all refused.
- A resolver error counts as "no target" and is reported once per 30 seconds.
- `pm.disablePlugin` calls `runtime.unregisterTargetSelectorsByOwner(id)` after `onDestroy`, so the plugin's selectors
  go away. `pm.reloadPlugin` goes through `disablePlugin`.
- A saved token that is no longer registered shows as `<token> (unavailable)` in the Target dropdown and resolves to no
  target. It never falls back to the current target.

**[PROPOSED]** rules for every registry, existing or new:

1. `owner` is mandatory.
2. A name collision is refused, not resolved by load order.
3. Disabling or reloading a plugin removes everything it registered. This is done by **one sweep over a list of
   registries** in `disablePlugin`, so a new registry joins the list instead of editing `disablePlugin` each time.
4. A saved reference to something that is no longer registered degrades to "unavailable" and **fails closed** (a
   missing condition does not fire, a missing selector targets nothing, a missing tab or command simply is not there).
5. Registrations take effect and are removed without a restart.
6. **[PROPOSED]** A plugin that enters `Error` is treated like a disabled plugin for registrations: its registrations
   are swept by owner. A registration made during an `onInit` that then fails is rolled back the same way. Reloading
   the plugin registers again through `onInit`.

**[DECIDED]** Registry resolvers have their own policy, separate from hooks. A resolver error returns the safe default
for that call and is reported at most once per 30 seconds (as today). It never counts toward disabling a hook and never
removes the registration by itself. Only a fatal plugin failure (section 4.4) removes a plugin's registrations.

**[CURRENT]** (implemented): `pm.reportError` now sweeps the plugin's registrations by owner
(`runtime.unregisterTargetSelectorsByOwner`). Before this, nothing was swept when a plugin entered `Error`:
`runtime.runTargetSelector` looks the label up and calls the resolver without checking the owner's status, so an
erroring plugin's selector stayed callable, and a plugin whose `onInit` failed partway kept whatever it had registered.
`runTargetSelector` itself still does not check the owner's status; it relies on the sweep.
**[DECIDED]** Remove, and roll back a failed `onInit`: a saved reference then shows as "unavailable" and fails closed,
exactly as for a disabled plugin, with one code path.

---

## 4. Lifecycle and calling context

### 4.1 Lifecycle **[CURRENT]**

1. `pm.discover` finds `*.lua` files in the plugin folder. `pm.loadPlugin` loads the file and reads the manifest.
2. Whether a plugin is enabled follows the saved choice, else its `defaultEnabled` (default true).
3. Enabling calls `onInit(core)` under `xpcall`, then `onLoadSettings(settings)` under `pcall`.
4. While enabled: `onTick` (see below), `onDrawUI`, `onDrawSettings`, `onCommand`, the events in 3.1, and the decisions
   in 3.2.
5. Disabling calls `onDestroy()` under `pcall` (an error there is swallowed), then removes the plugin's target
   selectors.
6. Reloading (`pm.reloadPlugin`) disables the plugin if it was enabled (so step 5 runs, including the selector sweep), then loads the file again, which re-enables it if it was running before.

Manifest fields read today: `id`, `name`, `version`, `author`, `description`, `defaultEnabled`, `tickInterval`,
`runOutOfCombatOnly`, `hasThread`, `uses`, `window`/`windows`, `help`.

### 4.2 `onTick` **[CURRENT]**

Called from `pm.tick` for each enabled plugin whose `tickInterval` has elapsed. A plugin with `runOutOfCombatOnly` does
not tick during combat (status `Sleeping (Combat)`). A plugin with `hasThread = true` is resumed as a coroutine fiber
(`pm.createFiber`) instead of having `onTick` called.

### 4.3 Drawing and calling context **[CURRENT]**

- `onDrawUI` and `onDrawSettings` run inside ImGui render callbacks (`pm.inDraw` is true).
- `mq.delay` is refused there, because it is a hard crash that also corrupts the ImGui stack. A plugin that needs to wait
  from a button must use `core.defer(...)`, which `pm.tick` runs later.
- An error during draw is **fatal for that plugin**: it is set to `Error` and no longer drawn, because retrying would
  leave the ImGui Begin/End stack unbalanced.

**[PROPOSED]** each documented hook states its calling context (main loop, draw callback, fiber, event callback) and what
is forbidden there. The draw restriction above is the template.

### 4.4 Errors **[CURRENT]**

An error in any dispatched hook calls `pm.reportError`: the status becomes `Error`, one line is printed, and the
traceback goes to the TAC log. A plugin in `Error` receives **no further hooks of any kind** until it is reloaded. The Plugins page shows
`Error: <message>`, and the plugin's settings panel shows the message with a **Reload Plugin** button.
Registrations are swept when a plugin enters `Error` (section 3.3).

**[DECIDED]** A **hook failure** is not a **plugin failure**:

- *Hook failure.* An error in a non-fatal hook (events, decisions, `onTick`, `onCommand`, `onSaveSettings`,
  `onLoadSettings`) is counted per plugin and hook. After **three consecutive failures** that hook is disabled for that
  plugin and reported once, with its traceback. A **successful invocation resets** that hook's counter, and a **reload
  resets** disabled hooks. Disabling a hook does not touch the plugin's other hooks or its registrations.
- *Fatal plugin failure.* A draw error (`onDrawUI`, `onDrawSettings`), a failed `onInit`, or an uncaught error in a
  plugin's fiber puts the plugin in `Error`, as today. Its registrations are swept by owner, and a failed `onInit` rolls
  back what it registered **immediately**.
- *Cleanup.* An error in `onDestroy` is swallowed (as today) and **can never prevent the owner sweep**.

**[CURRENT]** (implemented, section 10): `pm.hookFailed`, `pm.hookSucceeded` and `pm.hookEnabled` count failures
per plugin and hook; `dispatch`, `onTick` and `onSpellRecordChanged` use them, and `pm.loadPlugin` clears the counters on
a reload. Draw errors, a failed `onInit` and fiber errors still go through `pm.reportError`. `onSaveSettings` and
`onLoadSettings` are called under a plain `pcall` and have never flagged a plugin, so they are not counted. Before this
change every error in any hook put the plugin in `Error`.

---

## 5. Shared state and who may change it

### 5.1 Today **[CURRENT]**

Plugins get `core.runtime`, the whole runtime table. The inventory (section 7) found that reads and calls dominate. The
few writes into runtime state are:

- `auto_aa` sets `runtime.pendingCursorClearAt` and edits entries of `runtime.cachedAAData`.
- `boxnet` assigns the `runtime.onBoxBuffRequestDone` callback.
- The external mez plugin clears entries of `runtime.npcSpellApplied[mobId][spell]` when a mez cast failed or the mob
  woke. That table is shared knowledge that TAC's own cast code writes when a cast is issued and clears on a resist,
  fizzle or interrupt.

The first inventory pass counted only top-level assignments and missed the nested writes; see appendix C.

### 5.2 Proposed policy **[PROPOSED]**

- **Reading** runtime state is allowed but is internal-tier unless the member is in the supported set.
- **Mutating** shared state (targeting, casting, cooldown and cast records) is not safe for plugins to do directly,
  because it can undermine coordination between plugins. It is not blocked, and it is not documented as supported.
- **Plugins report observations; core owns shared record changes.** A plugin that learns something calls a supported
  function, `core.reportSpellEnded(mobId, spell, reason, revision, detail)`, with reasons such as `failed`, `woke`,
  `faded`. `revision` is the opaque revision the reporter read from `core.spellRecord`; `detail` is an **optional
  last argument**, a short string for logs. Core decides what to clear and tells other plugins. This is the supported
  route for what the mez plugin does by hand. The argument order is **[PROPOSED]** and not final (section 9, "Still open").
- **Reports must not clear a newer record.** A delayed `failed` or `faded` report for an older cast could otherwise erase
  the record that replaced it. Core ignores a report whose `revision` does not match the current record (see the
  revision guarantee below). Today the mez plugin approximates this by matching the failed cast's time to a record within
  3 seconds, which is a heuristic that this contract replaces.

**[DECIDED]** The revision check. `core.spellRecord(mobId, spell)` returns a copy that includes a `revision` field, and
**`revision` is an opaque token**. Reports must include the revision the reporter observed, and core ignores a report
whose revision no longer matches the current record, without emitting any event.

**The guarantee a revision must give.** An opaque token is the right interface, but it does not make the value
underneath unique. The contract is therefore stated on the *behaviour*, whatever the implementation: **a revision must
distinguish every record from every record that replaced it or could be mistaken for it.** In particular, a revision
observed for one record must never match:

- a later record for the same mob and spell, including one created after the first was cleared or expired;
- a record created after the tables were **replaced wholesale** on a zone change or reset (`runtime.npcSpellApplied = {}`);
- a record for a **different mob that reuses the same spawn id**. EverQuest reuses spawn ids, so a stale report for a dead
  mob must not be able to hit a new mob that happens to have the same id.

So uniqueness is **process-wide, not per mob-and-spell key.** An implementation may use timestamps only if it can
guarantee all of the above, for example by forcing each new value to be strictly greater than the last one issued.
Otherwise it must use a generation counter. **[DECIDED]** the target implementation is a process-wide, strictly
increasing generation counter assigned whenever core writes or replaces a spell record, because it provides the
guarantee by construction. The cast time stays available as the separate, informational `castAt` field.

**The generation counter is never reset** by zoning, by a wholesale reset of the spell tables, or by a plugin reload
or reload of all plugins. It starts at its initial value only when the TAC process starts, which is also when every
record disappears, so no revision can outlive the counter that issued it.

**[CURRENT]** (implemented): `runtime.touchSpellRecord(mobId, spell)` stamps a revision from the process-wide counter
`runtime.spellRecordGen` at the two places core writes a record, and `runtime.npcSpellRevision` is replaced at the two
wholesale resets while the counter is left alone. The counter is initialised once, in the runtime table.

What was verified about using the cast time as the revision (`runtime.npcSpellLastCast[mob][spell]`):

- It is written with `os.clock()` at the moment a cast is issued, at two sites (the gem cast path and the
  AA/ability path), together with the expiry in `npcSpellApplied`.
- `os.clock()` is monotonic within the TAC process with roughly 1 ms resolution. Successive casts of the same spell on the
  same mob are at least a cast time apart, so in practice they cannot share a value. Reloading a plugin does not reset
  it, since the process is the same. Records are not persisted, so none survives a TAC restart.
- **It cannot be proven unique** for instant effects or if two sites ever wrote in the same millisecond, and it is
  keyed by mob id, so it says nothing about a reused spawn id. A timestamp does not meet the guarantee above without
  extra work, so the contract promises only an opaque `revision` and the target implementation is a generation counter.
- Two further facts the design must respect: `npcSpellLastCast` is **not cleared** when a resist or fizzle clears the
  applied entry, so a report that matches the revision after the entry was already cleared is a no-op; and both tables
  are **replaced wholesale** on a zone or reset (`runtime.npcSpellApplied = {}`), so a report about a record that no
  longer exists is a no-op.

**[DECIDED]** `onSpellRecordChanged(mobId, spell, reason, old, new, detail)` is an experimental event that fires
**after core commits an actual change**, with **copies** of the old and new records (each including its `revision`), the
reason, and the optional `detail` string as the **last argument**, passed through from the report (nil when the
report had none). Rejected, stale and no-op reports do not emit it. Reasons: `failed`, `woke`, `faded`. The argument
order is **[PROPOSED]** and not final (section 9, "Still open").
- **A plugin's own tracking stays private.** The mez plugin's landing-confirmation table is its own and needs no API.

**[CURRENT]** (implemented, experimental): `core.spellRecord`, `core.reportSpellEnded` and the `onSpellRecordChanged`
event. The mez plugin has not been moved onto them yet.

---

## 6. Per-server configuration **[CURRENT]**

Added with the per-server config work (`dev`):

- `core.serverTag()` returns the sanitized server name from `MacroQuest.Server()` (falling back to
  `EverQuest.ServerName()` and `Zone.Server()`), or `''` when unknown.
- `core.configFilePath(prefix, name, ext)` returns `<configDir>/<prefix>_<server>_<name>.<ext>`, copying the old
  `<prefix>_<name>.<ext>` across the first time, and the old name when the server is unknown.

Proposed tier **[PROPOSED]**: stable.

---

## 7. Proposed first API set

Evidence is the inventory: how many of the 25 plugins use each entry. "Today" means it exists now but is not
documented as a promise. Tier is a proposal.

### 7.1 Window and settings framework (today, heavily used)

`ImGui` and `mq` (25 of 25), `saveLoadout` (25), `ctrl` (22; added to the API table after construction, not in the
table), `px` (24), `accent` (22), `pushTheme`, `popTheme`, `preBeginWindow`, `postBeginWindow`, `preEndWindow` (22 each),
`windowFlags` (21), `colors` (20), `setTooltip` (17), `VERSION` (11), `applyWindowScale`, `drawWindowMenuItems` (9),
`windowBgAlpha` (8), `drawWindowScaleControl` (7), `drawStatusProgressBar` (6), `defer`, `delay`, `inspectSpell`,
`log`. **Proposed tier: stable.** Needs only documentation (arguments, calling context).

### 7.2 Lifecycle events and decisions (today)

`onInit`, `onDestroy`, `onTick`, `onDrawUI`, `onDrawSettings`, `onCommand`, `onSaveSettings`, `onLoadSettings`, `onZoned`,
`onCombatTick`, `onBetweenPulls`, `wantsCombatHold`, `onLoadoutSaved`. **Proposed tier: stable** for the first eight,
**experimental** for the combat-time hooks (barely used so far: `onCombatTick` by one plugin, `wantsCombatHold` by two,
`onBetweenPulls` by one).

### 7.3 Combat and target state (read-only accessors; today reached through `core.runtime`)

`isCasting`, `isCombat`, `anyXtarAlive`, `countNPCXtarget`, `isMoveActive`, `isHostileTarget`, `isIgnored`,
`isUnreachable`, `isTargetInRange`, `maPcId`, `maTargetId`, `tickSerial`, `boxnetApi`, `boxnetMaTarget`,
`BOXNET_FRESH_SEC`. Used mainly by the mez plugin. **Proposed: promote to a documented read-only set, experimental
first.**

### 7.4 Cooldown and cast records (read accessors; today raw tables)

`lastCast`, `lastAAFiredAt`, `lastDiscFiredAt`, `lastSkillFiredAt`, `discExpires`, `discCooldown`, `aaCooldownTotal`,
`timerGroupCooldown`, `npcSpellApplied`, `npcSpellLastCast`, `cachedAAData`, `getClientAbilities`. Used by
`hud_cooldowns`, `auto_aa` and the mez plugin. **Proposed: read accessors, experimental; shared-record changes only
through `reportSpellEnded` (section 5.2), which is new.**

**Accessors return values, not live tables [PROPOSED].** Returning a raw table would keep the nested-write problem
(a plugin could write into it). Point queries return a copy, for example `core.spellRecord(mobId, spell)` giving
`{ castAt, expiresAt, revision }`; any list-returning accessor returns a snapshot. The raw tables stay internal-tier.
**[DECIDED]** Hot paths use point queries or small result sets. A snapshot of a whole table every tick is too
expensive to be a supported accessor.

### 7.5 Actions and presets (today `core.runtime` calls)

`castGem`, `fireAA`, `fireDisc`, `fireSkill`, `useClickie`, `tryMem`, `isDiscReady`, `getSpellBookSlot`,
`importCurrentGems`, `savePreset`, `loadPreset`, `deletePreset`. Used by the buttons plugin. **[DECIDED]** these are
not promised: they drive the combat engine and are the riskiest to commit to. Revisit when a second plugin needs them.

### 7.6 Plugin discovery (today `pluginManager` reads)

Seven plugins read `runtime.pluginManager` (`uses`, `usedBy`, window lists). **A small read-only view**
(`core.plugins.list()`, `core.plugins.usedBy(id)`, `core.plugins.state(id)`), **[DECIDED]** experimental; the exact
return shapes are still open (section 9).

### 7.7 Registries

- Target selectors: today, experimental until the registry rules in 3.3 are met.
- Additional registries (for example conditions, tabs, commands) are **deferred**: each would follow the 3.3 rules and
  be added only when a plugin needs it. Conditions are the likeliest first.

### 7.8 Requests and callbacks (replacing the two writes)

A supported way to request a cursor clear and to receive the Box Network buff-request completion, instead of assigning
into runtime. **Deferred**: both writes are in shipped plugins and can move when those plugins are next touched.

### 7.9 Configuration

`core.serverTag`, `core.configFilePath` (section 6).

---

## 8. Compatibility process and checks

All **[PROPOSED]**; none exists yet.

- **Contract test.** A file listing every stable entry with its documented signature and calling context. A change that
  breaks it needs a major bump.
- **Leak test.** For every registry, capture a snapshot before a plugin is enabled: not only the count and keys but
  each entry's **identity** (the function or table itself), **owner** and **metadata** (label, side, help text and so
  on). Enable and disable the plugin and assert the snapshot is identical to the baseline (not "empty", so built-in
  entries may remain). Comparing counts and keys alone would miss a plugin that replaced an existing entry while
  keeping both. Repeat with two enable/disable cycles. Also exercise the real `pm.reloadPlugin` path, which may retain
  references or clean up differently, and after a reload assert that only the **new** plugin instance's registrations
  remain, by checking that no registered function is one the old instance created. Add a case where `onInit` raises
  after registering, and one where the plugin enters `Error` (section 3.3).
- **Write ratchet.** A review guard that lists plugin writes into runtime state and fails when a plugin adds one that is
  not on the list, prompting the question "should this be a supported function?". It is a guard, not a proof. It must
  cover nested writes (`rt.x[a] = ...`), aliases (`local t = rt.x`) and table mutations (`table.insert`,
  `table.remove`), which a plain search for `rt.x =` misses. It accepts some false negatives. A bytecode listing
  (`luajit -bl`) could be more reliable than text search; start with text.
- **Deprecation.** **[DECIDED]** A stable entry deprecated in `1.4` is retained throughout `2.x` and may be removed in
  `3.0`; warnings are best-effort (section 2.3).
- **Release notes.** API additions and tier changes can be generated from the manifest; behaviour changes need prose.

---

## 9. Decisions

Status of the fourteen items raised by the first draft, after review. **Decided** items are agreed but not
implemented. **Deferred** items are intentionally left until a plugin needs them.

1. **Raw runtime access.** **Decided:** `core.runtime` stays available as the unsupported escape hatch. No write-warning
   proxy (it would miss nested writes); the write ratchet in section 8 covers it.
2. **Dispatch order.** **Decided:** no ordering promise for events. First-handled mechanisms use an explicit `priority`
   with an alphabetical-by-id tie rule (section 3.2).
3. **Failure policy.** **Decided:** a safe default per mechanism, three-strikes per hook, draw errors and failed
   `onInit` are fatal, and resolvers have their own policy (sections 3.2, 3.3, 4.4).
4. **`apiVersion` semantics.** **Decided:** `"MAJOR.MINOR"`; minor-version promise for stable entries only;
   deprecation example in section 2.3.
5. **Manifest shape.** **Decided:** `core.api` plus `core.hasCapability(name)`; no `hasHook`.
6. **Action functions.** **Decided:** not promised. Revisit when a second plugin needs them.
7. **Plugin discovery view.** **Decided:** a small read-only `core.plugins` view (`list`, `usedBy`, `state`), experimental.
8. **`reportSpellEnded`.** **Decided:** reasons `failed`, `woke`, `faded` with an optional detail; core notifies through
   `onSpellRecordChanged` after an actual change; the mez plugin migrates when the function exists (section 5.2).
9. **Request/callback pair** replacing `pendingCursorClearAt` and `onBoxBuffRequestDone`. **Deferred.**
10. **Extra registries.** **Deferred** until a plugin needs one. Conditions are the likeliest first.
11. **Registrations and `Error`.** **Decided:** remove, and roll back a failed `onInit` (section 3.3).
12. **Version format.** **Decided:** the string `"MAJOR.MINOR"` with `apiVersionInfo` and `apiAtLeast` (section 2.3).
13. **Snapshot or live.** **Decided:** supported accessors return copies; point queries for hot paths (section 7.4).
14. **Report revisions.** **Decided:** an opaque `revision` token with a uniqueness guarantee: it must distinguish every
    replacement record, across zone and reset boundaries and across reused spawn ids, process-wide. The target
    implementation is a generation counter; timestamps only if they meet the guarantee (section 5.2).

### Still open

- ~~The `priority` field: its name and range, and how it is documented for plugin authors.~~ Resolved and implemented, see section 3.2
  and docs/decision_log.md DL-003 (the field is `priority`, a finite number, no range limit; documented in 3.2).
- The exact `core.plugins` and `core.spellRecord` return shapes.
- Which hooks count as non-fatal for the three-strikes rule beyond the list in section 4.4.
- The final argument order of `core.reportSpellEnded` and `onSpellRecordChanged` (including a single table argument
  instead of positional ones, which would make later additions easier).

---

## 10. Implementation status

What exists in the source, and what does not, as of the branch that merged this section.

**Implemented (tests in Suites 116 and 117, and in 88 and 92):**

- `core.apiVersion` (string), `core.apiVersionInfo`, `core.apiAtLeast`, the manifest `core.api` and
  `core.hasCapability`. Manifest entries so far: the version helpers, the target selector registry, `serverTag`,
  `configFilePath`, `spellRecord`, `reportSpellEnded` and the `onSpellRecordChanged` event. Tiers are provisional.
- Spell record revisions from a never-reset, process-wide counter; `core.spellRecord` (returns copies);
  `core.reportSpellEnded(mobId, spell, reason, revision, detail)`; the `onSpellRecordChanged(mobId, spell, reason, old,
  new, detail)` event with copies for each plugin, fired only after core commits a change.
- Hook failures counted per plugin and hook (three strikes, reset by a success and by a reload); fatal failures sweep the
  plugin's registrations, including the rollback of a failed `onInit`.
- `priority` ordering for `onCommand` and `onBetweenPulls` (section 3.2, DL-003): the field, its validation and warning,
  the order built on each call, the reload behaviour and the `hookPriority` capability. Tests in Suite 120.

**Not implemented yet:**

- `core.plugins` (`list`, `usedBy`, `state`), and the rest of the manifest (the existing 65 keys, with tiers).
- Deprecation flags and warnings (section 2.3).
- The contract test, the write ratchet, and the registry leak test including the real reload path (section 8).
- Moving the mez plugin onto `reportSpellEnded`.
- The three open details in section 9.

---

## Appendix A. Core API table today (65 keys, `runtime.initPluginManager`)

Used by at least one plugin, with the number of plugins using it:
`ImGui` 25, `mq` 25, `saveLoadout` 25, `px` 24, `accent` 22, `popTheme` 22, `postBeginWindow` 22, `preBeginWindow` 22,
`preEndWindow` 22, `pushTheme` 22, `windowFlags` 21, `colors` 20, `setTooltip` 17, `VERSION` 11, `applyWindowScale` 9,
`drawWindowMenuItems` 9, `windowBgAlpha` 8, `drawWindowScaleControl` 7, `drawStatusProgressBar` 6, `delay` 4,
`inspectSpell` 4, `col32` 3, `getMultiPetList` 3, `getSpellIconAnimation` 3, `log` 3, `toVec` 3, `DATA` 2,
`cleanSpellName` 2, `configFilePath` 2, `fmtSec` 2, `getConColorRgb` 2, `getNumGems` 2, `idxOf` 2, `parseDurationSec` 2,
`parseSpellRecastTime` 2, and one plugin each for `addIgnore`, `addZoneIgnore`, `classColor`, `currentWindowScale`,
`defer`, `drawSpellIcon`, `drawSpellbookIcon`, `getAbilityBaseCooldown`, `getDiscCooldownAndDuration`,
`getGemCooldownSec`, `getPetSpawnInfo`, `getXtForceId`, `isSpawnAlive`, `isXtIgnoredId`, `normalizeSpellName`,
`parseCombatAbilityTimer`, `postEndWindow`, `pushWindowScale`, `registerTargetSelector`, `requestClassRedetect`,
`resolveTargetOfTarget`, `setXtForce`, `setXtIgnore`, `unregisterTargetSelector`.

Not used by any plugin: `windowOpts`, `setWindowOpt`, `windowScale`, `toggleTool`, and `serverTag` (new). `runtime` is
used as the back door described in section 5.

Used but not in the table when it is built (added to the core table later): `ctrl`, `loadout`, `myClasses`,
`castTracker`, `boxnet`, `zoneclaim`, `nms_looter_handoff`. These are undocumented and need a decision.

## Appendix B. Plugin lifecycle hooks implemented

`onInit` and `onDestroy` 25, `onDrawSettings` 24, `onTick` 24, `onDrawUI` 23, `onCommand` 18, `onLoadSettings` and
`onSaveSettings` 12, `onZoned` 10, `wantsCombatHold` 2, `onCombatTick` 1 (the mez plugin), `onBetweenPulls` 1.
`onBadgeClick` is called by `hud_unitframes` on another plugin directly; it is a plugin-to-plugin convention, not a core
hook.

## Appendix C. Method and limits of the inventory

A script read the plugin files and the core API table, counted `core.<key>`, `core.runtime.<member>` and `rt.<member>`
(where `rt = core.runtime`) uses, and classified each as a call, a read or a direct assignment. It is a text scan, not a
trace, so:

- Dynamic access (`core[name]`) and aliases other than `rt` are missed.
- The first pass counted only direct assignments. A second check found nested writes: `auto_aa` into
  `runtime.cachedAAData`, and the mez plugin into `runtime.npcSpellApplied`. Plugins such as `chat` and `buffbot` also
  have a local table named `rt`; those are the plugin's own state and not runtime writes.
- Counts are approximate to within a few uses.
