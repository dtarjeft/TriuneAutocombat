# Plugin API: hooks, events, decisions and registries

**Status: DRAFT for review. Nothing in this document changes any code.**

This draft describes how plugins talk to TAC today and proposes a contract for how they should. It is deliberately
split so it cannot promise something that is not implemented:

| Marker | Meaning |
|---|---|
| **[CURRENT]** | Verified in the source at `dev` (`808ce32`). Describes what the code does now, whether or not it was ever written down. |
| **[PROPOSED]** | A contract we would adopt. Not implemented, or implemented but not yet promised. |
| **[OPEN]** | Undecided. Listed again in section 9. |

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

- There is no API version and no way for a plugin to ask what the core offers. `core.registerTargetSelector` exists,
  and a plugin that needs it checks `type(core.registerTargetSelector) == 'function'` by hand (the mez plugin does).
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

`core.apiVersion = MAJOR.MINOR`.

- **Minor** bump: additions only (a new hook, function, event, registry or optional argument). A plugin written for
  `N.x` keeps working on `N.y` for `y >= x`.
- **Major** bump: anything that changes the arguments, return values, **timing, calling context or meaning** of a
  stable entry, or removes one.
- Behaviour changes are documented in prose release notes even when the signature is unchanged. A signature check is
  not a compatibility check.

### 2.4 Capability manifest **[PROPOSED]**

A single table, for example `core.api`, listing every supported entry with its kind (hook, event, decision, registry,
function), tier and the version that introduced it. It is the source for:

- `core.hasCapability(name)` (covers hooks and functions; `hasHook` stays as the narrower form),
- the generated API reference, and
- the generated "what changed" summary (additions and tier changes only).

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
**[OPEN]** whether load order is a promise (section 9, item 2).

### 3.2 Decisions: "what should happen" **[CURRENT]**

Three hooks are dispatched with `firstTrue = true`:

| Hook | Combine rule today | What a `true` means |
|---|---|---|
| `wantsCombatHold()` | first truthy wins | the combat loop should stand still (`runtime.combatHold()`) |
| `onBetweenPulls()` | first truthy wins | the plugin started something; the puller should yield this tick |
| `onCommand(cmd, args)` | first truthy wins | the plugin handled the `/ac <cmd>` fallthrough |

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
**[OPEN]** failure policy per mechanism (section 9, item 3).

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
**[OPEN]** whether one failure should silence a plugin completely, or only the hook that failed (section 9, item 3).

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
  function (for example `core.reportSpellEnded(mobId, spell, reason)`, with reasons such as `failed`, `woke`, `faded`).
  Core decides what to clear and tells other plugins. This is the supported route for what the mez plugin does by hand.
- **A plugin's own tracking stays private.** The mez plugin's landing-confirmation table is its own and needs no API.

Nothing here is implemented. `reportSpellEnded` does not exist yet.

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

### 7.5 Actions and presets (today `core.runtime` calls)

`castGem`, `fireAA`, `fireDisc`, `fireSkill`, `useClickie`, `tryMem`, `isDiscReady`, `getSpellBookSlot`,
`importCurrentGems`, `savePreset`, `loadPreset`, `deletePreset`. Used by the buttons plugin. **[OPEN]** whether these are
promised or stay internal (section 9, item 6): they drive the combat engine and are the riskiest to promise.

### 7.6 Plugin discovery (today `pluginManager` reads)

Seven plugins read `runtime.pluginManager` (`uses`, `usedBy`, window lists). **Proposed: a small stable read-only view**
(`core.plugins.list()`, `core.plugins.usedBy(id)`, `core.plugins.state(id)`); **[OPEN]** exact shape.

### 7.7 Registries

- Target selectors: today, experimental until the registry rules in 3.3 are met.
- Additional registries (for example conditions, tabs, commands) are **[OPEN]**: each would follow the 3.3 rules and
  be added only when a plugin needs it.

### 7.8 Requests and callbacks (replacing the two writes)

A supported way to request a cursor clear and to receive the Box Network buff-request completion, instead of assigning
into runtime. **[OPEN]** shape; both are new.

### 7.9 Configuration

`core.serverTag`, `core.configFilePath` (section 6).

---

## 8. Compatibility process and checks

All **[PROPOSED]**; none exists yet.

- **Contract test.** A file listing every stable entry with its documented signature and calling context. A change that
  breaks it needs a major bump.
- **Leak test.** For every registry, capture its contents (count and keys) before a plugin is enabled, enable and disable
  it, and assert the contents equal that baseline (not "empty", so built-in entries may remain). Repeat with two
  enable/disable cycles and also exercise the real `pm.reloadPlugin` path, which may retain references or clean up
  differently.
- **Write ratchet.** A review guard that lists plugin writes into runtime state and fails when a plugin adds one that is
  not on the list, prompting the question "should this be a supported function?". It is a guard, not a proof. It must
  cover nested writes (`rt.x[a] = ...`), aliases (`local t = rt.x`) and table mutations (`table.insert`,
  `table.remove`), which a plain search for `rt.x =` misses. It accepts some false negatives. A bytecode listing
  (`luajit -bl`) could be more reliable than text search; start with text.
- **Deprecation.** A stable entry is deprecated for at least one major version before removal. **[OPEN]** length.
- **Release notes.** API additions and tier changes can be generated from the manifest; behaviour changes need prose.

---

## 9. Open decisions

1. **Raw runtime access.** Keep `core.runtime` available as the unsupported escape hatch (current lean: yes), and
   whether to log or flag writes to it in debug mode.
2. **Dispatch order.** Whether load order (`pm.pluginOrder`) is promised for events. Decisions should not depend on it.
3. **Failure policy.** Per mechanism: fail closed or open. And whether an error silences a plugin entirely (today) or
   only the failing hook.
4. **`apiVersion` semantics.** Confirm MAJOR.MINOR and the deprecation window.
5. **Manifest shape.** `core.api` fields and whether `hasHook` stays.
6. **Action functions.** Whether `castGem`, `fireAA` and the like are ever promised.
7. **Plugin discovery view.** Exact shape of `core.plugins`.
8. **`reportSpellEnded`.** Reasons list, whether core notifies other plugins, and the migration of the mez plugin.
9. **Request/callback pair** replacing `pendingCursorClearAt` and `onBoxBuffRequestDone`.
10. **Extra registries.** Which of conditions, tabs and commands, and when.

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
