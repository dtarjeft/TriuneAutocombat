-- ============================================================================
-- API Probe: a throwaway plugin for checking the plugin API in game (docs/HOOKS.md).
--
-- It is NOT a shipped plugin: it lives in tools/ so the plugin tests do not pick it up. Copy it to
-- <MacroQuest>/lua/tac/api_probe.lua, click Rescan on the Plugins tab and enable "API Probe". It prints to
-- chat and changes nothing else. Delete the file when you are done.
--
--   /ac probe help               the commands
--   /ac probe version            apiVersion, apiAtLeast and hasCapability
--   /ac probe selftest           the whole spell-record check in one go: no mob, spell or timing needed
--   /ac probe record [spell]     the spell records on your target (or one spell)
--   /ac probe report stale       report an old revision: refused, nothing changes
--   /ac probe report current     report the current revision: core clears the record, the event prints
--   /ac probe fail               make onTick throw: three warnings, then the hook is switched off
--   /ac probe flaky              onTick fails twice, succeeds, ... for 12 ticks: it must never be switched off
--   /ac probe drawfail           make onDrawUI throw: the plugin goes to Error and E: Probe Target disappears
--   /ac probe status             counters
-- ============================================================================
local plugin = {
    id                 = 'api_probe',
    name               = 'API Probe',
    version            = '1.0.0',
    author             = 'TAC',
    description        = 'Throwaway checks for the plugin API: version, spell records, reports and failure handling.',
    defaultEnabled     = false,
    tickInterval       = 1.0,
    runOutOfCombatOnly = false,
    hasThread          = false,
}

local core = nil
local last = nil          -- the last record read by "probe record": { mob, spell, revision }
local mode = nil          -- 'fail' | 'flaky' | 'drawfail' | nil
local ticks, tickCalls, events = 0, 0, 0
local lastEvent = nil   -- the arguments of the last onSpellRecordChanged
local flakyN = 0

local function say(fmt, ...)
    print(string.format('\ay[API Probe]\ax ' .. fmt, ...))
end

local function targetId()
    local id = 0
    pcall(function() id = core.mq.TLO.Target.ID() or 0 end)
    return id
end

local function fmt(v) return v == nil and 'nil' or tostring(v) end

local function printRecord(mob, spell)
    local rec = core.spellRecord(mob, spell)
    if not rec then
        say('%s on #%d: no record', spell, mob)
        return nil
    end
    say('%s on #%d: castAt=%s expiresAt=%s revision=%s', spell, mob, fmt(rec.castAt), fmt(rec.expiresAt), fmt(rec.revision))
    last = { mob = mob, spell = spell, revision = rec.revision }
    return rec
end

local COMMANDS = {}

COMMANDS.help = function()
    say('/ac probe selftest | version | record [spell] | report stale|current | fail | flaky | drawfail | status')
end

COMMANDS.version = function()
    say('apiVersion = "%s" (a %s)', fmt(core.apiVersion), type(core.apiVersion))
    local info = core.apiVersionInfo or {}
    say('apiVersionInfo = { major = %s, minor = %s }', fmt(info.major), fmt(info.minor))
    say('apiAtLeast(1, 0) = %s, apiAtLeast(1, 99) = %s, apiAtLeast(2, 0) = %s',
        fmt(core.apiAtLeast(1, 0)), fmt(core.apiAtLeast(1, 99)), fmt(core.apiAtLeast(2, 0)))
    for _, name in ipairs({ 'spellRecord', 'reportSpellEnded', 'onSpellRecordChanged', 'registerTargetSelector', 'notAThing' }) do
        say('hasCapability("%s") = %s', name, fmt(core.hasCapability(name)))
    end
    local n, stable, experimental = 0, 0, 0
    for _, e in pairs(core.api or {}) do
        n = n + 1
        if e.tier == 'stable' then stable = stable + 1 else experimental = experimental + 1 end
    end
    say('manifest: %d entries (%d stable, %d experimental)', n, stable, experimental)
end

-- Plants a made-up record (mob id 999999, "Probe Spell") through core's own functions, then exercises the
-- report API on it and prints PASS or FAIL for each check. It needs no target and no timing, and it removes
-- what it planted. It writes to runtime tables, which is fine for a test tool and nothing a plugin should do.
COMMANDS.selftest = function()
    local rt = core.runtime
    if not (rt and rt.touchSpellRecord and rt.npcSpellApplied and rt.npcSpellLastCast) then
        say('this build has no spell record support (touchSpellRecord is missing)')
        return
    end
    local mob, spell = 999999, 'Probe Spell'
    local passed, failed = 0, 0
    local function check(label, ok)
        if ok then passed = passed + 1 else failed = failed + 1 end
        say('%s: %s', ok and 'PASS' or 'FAIL', label)
    end
    local function plant()
        rt.npcSpellLastCast[mob] = rt.npcSpellLastCast[mob] or {}
        rt.npcSpellLastCast[mob][spell] = os.clock()
        rt.npcSpellApplied[mob] = rt.npcSpellApplied[mob] or {}
        rt.npcSpellApplied[mob][spell] = os.clock() + 60
        rt.touchSpellRecord(mob, spell)
        return core.spellRecord(mob, spell)
    end
    local eventsBefore = events

    local r1 = plant()
    check('a planted record can be read (revision ' .. fmt(r1 and r1.revision) .. ')', r1 ~= nil and r1.revision ~= nil)
    local ok, why = core.reportSpellEnded(mob, spell, 'woke', -1, 'selftest stale')
    check('a report with a revision that cannot match is refused as stale', ok == false and why == 'stale')
    check('...and the record is still there', core.spellRecord(mob, spell) ~= nil)

    local r2 = plant() -- the same spell cast again on the same mob
    check('a recast gets a different revision (' .. fmt(r1 and r1.revision) .. ' then ' .. fmt(r2 and r2.revision) .. ')',
        r1 ~= nil and r2 ~= nil and r1.revision ~= r2.revision)
    ok, why = core.reportSpellEnded(mob, spell, 'faded', r1.revision, 'selftest late report')
    check('a late report for the OLDER cast is refused as stale', ok == false and why == 'stale')
    check('...and the NEWER record survives', core.spellRecord(mob, spell) ~= nil)
    check('...and no event was emitted for the refused reports', events == eventsBefore)

    ok, why = core.reportSpellEnded(mob, spell, 'woke', r2.revision, 'selftest current')
    check('a report with the current revision is accepted', ok == true)
    check('...and core cleared the record', core.spellRecord(mob, spell) == nil)
    check('...and exactly one onSpellRecordChanged event arrived', events == eventsBefore + 1)
    check('...carrying the old record (with its revision), no new record, the reason and the detail',
        lastEvent ~= nil and lastEvent.mob == mob and lastEvent.reason == 'woke' and lastEvent.old ~= nil
        and lastEvent.old.revision == r2.revision and lastEvent.new == nil and lastEvent.detail == 'selftest current')
    ok, why = core.reportSpellEnded(mob, spell, 'woke', r2.revision)
    check('reporting the same thing again does nothing (' .. fmt(why) .. ')', ok == false and why == 'no record')
    ok, why = core.reportSpellEnded(mob, spell, 'exploded', r2.revision)
    check('an unknown reason is refused (' .. fmt(why) .. ')', ok == false and why == 'bad reason')

    rt.npcSpellApplied[mob], rt.npcSpellLastCast[mob] = nil, nil
    if rt.npcSpellRevision then rt.npcSpellRevision[mob] = nil end
    say('selftest: %d passed, %d failed', passed, failed)
end

COMMANDS.record = function(args)
    local mob = targetId()
    if mob == 0 then say('target a mob first'); return end
    local spell = table.concat(args, ' ')
    if spell ~= '' then printRecord(mob, spell); return end
    -- no spell given: list the spells recorded for the target (reads an internal table, for this probe only)
    local applied = core.runtime and core.runtime.npcSpellApplied and core.runtime.npcSpellApplied[mob]
    local found = 0
    for name in pairs(applied or {}) do
        printRecord(mob, name)
        found = found + 1
    end
    if found == 0 then say('no spell records on #%d (cast a duration spell on it with TAC first)', mob) end
end

COMMANDS.report = function(args)
    local which = args[1]
    if not last then say('run "probe record" on a target with a record first'); return end
    if which ~= 'stale' and which ~= 'current' then say('use: probe report stale | current'); return end
    local revision = last.revision
    if which == 'stale' then
        revision = -1 -- cannot be a real revision
    else
        local rec = core.spellRecord(last.mob, last.spell)
        if not rec then say('no record any more for %s on #%d', last.spell, last.mob); return end
        revision = rec.revision
    end
    local ok, why = core.reportSpellEnded(last.mob, last.spell, 'woke', revision, 'api_probe ' .. which)
    say('reportSpellEnded(%d, %s, woke, %s) -> %s%s', last.mob, last.spell, fmt(revision), fmt(ok), why and (' (' .. why .. ')') or '')
    printRecord(last.mob, last.spell)
end

COMMANDS.fail = function()
    mode, tickCalls = 'fail', 0
    say('onTick will throw on every call. Expect "failed (1 of 3)", "(2 of 3)", then "switched off". The plugin must stay Active.')
end

COMMANDS.flaky = function()
    mode, flakyN, tickCalls = 'flaky', 0, 0
    say('onTick will fail twice, then succeed, for 12 ticks. It must not be switched off: expect 12 calls at the end.')
end

COMMANDS.drawfail = function()
    mode = 'drawfail'
    say('onDrawUI will throw on the next frame. Expect the plugin to show Error and "E: Probe Target" to leave the Target dropdown.')
end

COMMANDS.status = function()
    say('ticks=%d tickCalls=%d events=%d mode=%s', ticks, tickCalls, events, fmt(mode))
end

function plugin.onInit(coreApi)
    core = coreApi
    mode, last, lastEvent = nil, nil, nil
    ticks, tickCalls, events, flakyN = 0, 0, 0, 0
    if core.hasCapability('registerTargetSelector') then
        local ok, why = core.registerTargetSelector({
            owner = plugin.id, label = 'Probe Target', side = 'E',
            help = 'API Probe: never selects a target. Exists to check that registrations are swept.',
            resolve = function() return nil end,
        })
        say('loaded; registered E: Probe Target -> %s%s', fmt(ok), why and (' (' .. why .. ')') or '')
    else
        say('loaded; this build has no target selector registry')
    end
    say('type /ac probe help')
end

function plugin.onDestroy()
    say('unloaded')
end

function plugin.onCommand(cmd, args)
    if cmd ~= 'probe' then return false end
    local rest = {}
    for i = 2, #(args or {}) do rest[#rest + 1] = args[i] end
    local sub = (rest[1] or 'help'):lower()
    table.remove(rest, 1)
    local fn = COMMANDS[sub]
    if not fn then COMMANDS.help(); return true end
    local ok, err = pcall(fn, rest)
    if not ok then say('command failed: %s', tostring(err)) end
    return true
end

function plugin.onTick()
    ticks = ticks + 1
    if mode == 'fail' then
        tickCalls = tickCalls + 1
        error('probe: onTick throws on purpose (call ' .. tickCalls .. ')')
    elseif mode == 'flaky' then
        tickCalls = tickCalls + 1
        flakyN = flakyN + 1
        if flakyN % 3 ~= 0 then error('probe: flaky onTick fails (call ' .. flakyN .. ')') end
        if flakyN >= 12 then
            mode = nil
            say('flaky run over: onTick ran %d times (12 means it was never switched off)', tickCalls)
        end
    end
end

function plugin.onDrawUI()
    if mode == 'drawfail' then
        mode = nil
        error('probe: onDrawUI throws on purpose')
    end
end

function plugin.onSpellRecordChanged(mobId, spell, reason, old, new, detail)
    events = events + 1
    lastEvent = { mob = mobId, spell = spell, reason = reason, old = old, new = new, detail = detail }
    say('onSpellRecordChanged(#%s, %s, %s) old.revision=%s old.expiresAt=%s new=%s detail=%s',
        fmt(mobId), fmt(spell), fmt(reason), fmt(old and old.revision), fmt(old and old.expiresAt), fmt(new), fmt(detail))
end

function plugin.onDrawSettings()
    local ImGui = core.ImGui
    ImGui.TextWrapped('API Probe: type /ac probe help in chat. It prints to chat and changes nothing else.')
end

plugin.help = { '/ac probe help - API probe commands (throwaway test plugin)' }

return plugin
