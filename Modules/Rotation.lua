-- Rotation helper: priority lists per spec/context from content/learn.json and a
-- next-spell suggestion. Advice only: nothing here casts, targets or presses
-- anything (Blizzard forbids automation; we only read state).
local _, ns = ...

local Rotation = {}
ns.Rotation = Rotation

Rotation.CONTEXTS = { "solo", "dungeon", "raid" }
Rotation.CONTEXT_LABELS = { solo = "Solo leveling", dungeon = "Dungeon", raid = "Raid" }
-- Conditions content/learn.json may use (tests/run.lua checks every step).
Rotation.CONDITIONS = { "always", "manual", "buff_missing", "debuff_missing", "ready", "out_of_combat", "in_combat",
    "usable", "in_melee", "stealthed", "not_stealthed", "poison_missing" }
Rotation.CONDITION_PREFIXES = { "cp_at_least", "cp_below", "energy_at_least", "energy_below", "target_hp_below", "proc",
    "buff_missing", "buff_up", "target_debuff_missing" }

local function clean(name)
    return (name:gsub("%s*%(talent%)%s*$", ""))
end
Rotation.Clean = clean

-- name -> spell id / record, built from research (trainer spells, talents,
-- procs, teleports/portals, racials).
local idByName, recByName
local function index()
    if idByName then return end
    idByName, recByName = {}, {}
    for _, s in ipairs(ns.Data.Spells) do
        idByName[s.name] = idByName[s.name] or s.spell_id
        idByName[s.display] = idByName[s.display] or s.spell_id
        recByName[s.name], recByName[s.display] = s, s
    end
    for _, t in ipairs(ns.Data.TalentSpells or {}) do
        local c = clean(t.name)
        if not idByName[c] then idByName[c] = t.spell_id end
    end
    for _, r in ipairs(ns.Data.Racials or {}) do
        if r.spell and not idByName[r.spell] then idByName[r.spell] = r.spell_id end
    end
end

function Rotation.SpellId(name)
    if not name then return nil end
    index()
    return idByName[name] or idByName[clean(name)]
end

function Rotation.SpellRecord(name)
    if not name then return nil end
    index()
    return recByName[name] or recByName[clean(name)]
end

-- Is the name a spell/talent/proc the research knows (even without an ID)?
function Rotation.IsKnownName(name)
    index()
    if idByName[name] or recByName[name] or recByName[clean(name)] then return true end
    for _, t in ipairs(ns.Data.TalentSpells or {}) do
        if clean(t.name) == clean(name) then return true end
    end
    return false
end

function Rotation.Context(spec, context)
    local learn = ns.Data.Learn
    local bySpec = learn and learn.rotation and learn.rotation[spec]
    return bySpec and bySpec[context]
end

-- Any id a source showed for this spell (icons and tooltips only: it may be a
-- high rank, so it's never used to decide what you know).
function Rotation.AnyId(name)
    local id = Rotation.SpellId(name)
    if id then return id end
    local s = Rotation.SpellRecord(name)
    return s and ((s.rank_spell_ids and s.rank_spell_ids[1]) or (s.spell_ids_seen and s.spell_ids_seen[1])) or nil
end

-- Spell icon (texture id/path) or a question mark.
function Rotation.Icon(name)
    local id = Rotation.AnyId(name)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, id or clean(name))
        if ok and tex then return tex end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Is this step's spell usable by the player at all?
function Rotation.Known(name)
    return ns.Progress.Knows(clean(name))
end

-- Can the player use this step at their level?
--   "known"     spell is in the spellbook
--   "trainable" not detected as known, but a trainer rank is available at this level
--   nil         can't be learned yet (talent not taken, level too low, other faction)
function Rotation.Availability(name, level, race, faction)
    if Rotation.Known(name) then return "known" end
    local s = Rotation.SpellRecord(name)
    if s then
        if s.faction and faction and s.faction ~= faction then return nil end
        if not s.talent and s.rank_learn_levels[1] and s.rank_learn_levels[1] <= level then return "trainable" end
        return nil
    end
    return nil -- talents and procs: only once taken
end

-- Evaluate one condition. state: table of readers (injectable for tests).
-- Returns true/false, or nil when the client won't tell us (secret/unknown).
function Rotation.Check(step, state)
    local when = step.when or "always"
    local name = clean(step.spell)
    if when == "always" then return true end
    if when == "manual" then return false end -- listed for reading; the HUD never suggests it
    if when == "out_of_combat" then return not state.inCombat() end
    if when == "in_combat" then return state.inCombat() and true or false end
    if when == "buff_missing" then
        local has = state.playerBuff(state.spellName(name))
        if has == nil then return nil end
        return has == false
    end
    if when == "debuff_missing" then
        if not state.hasTarget() then return false end
        local has = state.targetDebuff(state.spellName(name))
        if has == nil then return nil end
        return has == false
    end
    if when == "ready" then
        local left = state.cooldown(name)
        if left == nil then return nil end
        return left <= 0.1
    end
    -- Stealth (or Vanish) is up: openers like Cheap Shot, Garrote, Ambush.
    if when == "stealthed" or when == "not_stealthed" then
        local st = state.stealthed()
        if st == nil then return nil end
        if when == "stealthed" then return st end
        return not st
    end
    -- A weapon has no poison / temporary enchant (or it runs out within 60 s).
    if when == "poison_missing" then
        local p = state.poisons()
        if p == nil then return nil end
        for _, hand in ipairs({ "mh", "oh" }) do
            local h = p[hand]
            if h == false then return true end
            if type(h) == "table" and h.left and h.left < 60 then return true end
        end
        return false
    end
    if when == "usable" then
        if not state.hasTarget() then return false end
        return state.usable(name)
    end
    if when == "in_melee" then
        if not state.hasTarget() then return false end
        return state.inMelee()
    end
    local kind, arg = when:match("^([%w_]+):(.+)$")
    local num = tonumber(arg)
    -- Combo points on your target (Forever keeps them across a target switch).
    if kind == "cp_at_least" or kind == "cp_below" then
        local cp = state.comboPoints()
        if cp == nil then return nil end
        if kind == "cp_at_least" then return cp >= num else return cp < num end
    end
    if kind == "energy_at_least" or kind == "energy_below" then
        local e = state.energy()
        if e == nil then return nil end
        if kind == "energy_at_least" then return e >= num else return e < num end
    end
    if kind == "target_hp_below" then
        local pct = state.targetHpPct()
        if pct == nil then return nil end
        return pct < num
    end
    if kind == "proc" then
        local has = state.playerBuff(arg)
        if has == nil then return nil end
        return has ~= false
    end
    if kind == "buff_missing" or kind == "buff_up" then
        local has = state.playerBuff(state.spellName(arg))
        if has == nil then return nil end
        if kind == "buff_up" then return has ~= false end
        return has == false
    end
    if kind == "target_debuff_missing" then
        if not state.hasTarget() then return false end
        local has = state.targetDebuff(state.spellName(arg))
        if has == nil then return nil end
        return has == false
    end
    return nil
end

-- Live readers backed by Modules/Auras.lua.
Rotation.LiveState = {
    inCombat = function() return UnitAffectingCombat("player") end,
    hasTarget = function() return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") end,
    spellName = function(name)
        local id = Rotation.SpellId(name)
        return (id and ns.Auras.SpellName(id)) or name
    end,
    playerBuff = function(n) return ns.Auras.Find("player", n, "HELPFUL") end,
    playerDebuff = function(n) return ns.Auras.Find("player", n, "HARMFUL") end,
    playerStacks = function(n)
        local data = ns.Auras.Find("player", n, "HELPFUL")
        if data == false then data = ns.Auras.Find("player", n, "HARMFUL") end
        if data == nil then return nil end
        if data == false then return 0 end
        local c = data.applications or data.charges or data.count
        if c == nil or ns.Auras.IsSecret(c) then return nil end
        return math.max(1, c)
    end,
    targetDebuff = function(n) return ns.Auras.TargetHasMine(n) end,
    stealthed = function() return ns.Rogue.Stealthed() end,
    poisons = function() return ns.Poisons.OnWeapons() end,
    comboPoints = function() return ns.Rogue.ComboPoints() end,
    energy = function() return ns.Rogue.Energy() end,
    inMelee = function() return ns.Rogue.InMelee() end,
    usable = function(name) return ns.Auras.Usable(Rotation.SpellId(name) or name) end,
    cooldown = function(name)
        local id = Rotation.SpellId(name)
        return ns.Auras.CooldownLeft(id or name)
    end,
    targetHpPct = function() return ns.Auras.HealthPct("target") end,
    known = function(name) return Rotation.Known(name) end,
}

-- Steps that are "ready" conditions on any step also feed the cooldown bar.
function Rotation.Cooldowns(ctx)
    local seen, out = {}, {}
    for _, step in ipairs(ctx and ctx.priority or {}) do
        if step.when == "ready" and not seen[step.spell] then
            seen[step.spell] = true
            table.insert(out, step.spell)
        end
    end
    return out
end

-- Returns suggestion list (up to `max` steps whose conditions currently pass),
-- plus a flag when some conditions could not be read.
function Rotation.Suggest(spec, context, state, max)
    state = state or Rotation.LiveState
    local ctx = Rotation.Context(spec, context)
    if not ctx then return {}, false, nil end
    local out, blocked = {}, false
    for _, step in ipairs(ctx.priority or {}) do
        if state.known(step.spell) then
            local ok = Rotation.Check(step, state)
            if ok == nil then blocked = true end
            if ok then
                table.insert(out, step)
                if #out >= (max or 3) then break end
            end
        end
    end
    return out, blocked, ctx
end
