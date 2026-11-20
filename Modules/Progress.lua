-- Class quests, riding/gold goals and milestones.
local _, ns = ...

local Progress = {}
ns.Progress = Progress

Progress.RACE_NAMES = {
    Human = "Human", Dwarf = "Dwarf", Gnome = "Gnome", NightElf = "Night Elf",
    Scourge = "Undead", Undead = "Undead", Troll = "Troll", Orc = "Orc", Tauren = "Tauren",
}

function Progress.PlayerRace()
    local name, english = UnitRace("player")
    if english and Progress.RACE_NAMES[english] then return Progress.RACE_NAMES[english] end
    -- Forever's new race (Alliance Skyborne / Horde Windshaper Skyborne): quest data says "Skyborne".
    if tostring(english or name or ""):find("Skyborne", 1, true) then return "Skyborne" end
    return english or name
end

local function raceMatches(field, race)
    if not field or not race then return false end
    if field == "All" then return true end
    for part in field:gmatch("[^/]+") do
        part = part:match("^%s*(.-)%s*$")
        if part == race or (race == "Undead" and part == "Scourge") then return true end
    end
    return false
end
Progress.RaceMatches = raceMatches

function Progress.IsQuestDone(id)
    if not id then return nil end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
        if ok then return done end
    end
    return nil
end

-- Class quests whose ID isn't in the research can still be finished: the addon
-- notices the turn-in (QUEST_TURNED_IN + the quest's title), finds it among
-- quests you already completed at login (by title, where the client knows it),
-- or you mark it done on Leveling > Class quests. Stored per character.
local function questLog()
    local c = ns.db and ns.db.char
    if not c then return nil end
    c.questLog = c.questLog or { done = {}, ids = {} }
    c.questLog.done = c.questLog.done or {}
    c.questLog.ids = c.questLog.ids or {}
    return c.questLog
end

local function norm(t) return tostring(t or ""):lower():gsub("^%s+", ""):gsub("%s+$", "") end

-- Done? true / false, or nil when it can't be known.
function Progress.IsClassQuestDone(q)
    if q.quest_id then return Progress.IsQuestDone(q.quest_id) end
    local log = questLog()
    if not log then return nil end
    if log.done[q.name] then return true end
    local id = log.ids[q.name]
    if id and Progress.IsQuestDone(id) then return true end
    return false
end

function Progress.SetClassQuestDone(name, done)
    local log = questLog()
    if not log then return end
    log.done[name] = done and true or nil
end

local function byTitle(title)
    local t = norm(title)
    if t == "" then return nil end
    for _, q in ipairs(ns.Data.Quests or {}) do
        if not q.quest_id and norm(q.name) == t then return q end
    end
    return nil
end

local function titleFor(id)
    local fn = C_QuestLog and C_QuestLog.GetTitleForQuestID
    if not fn then return nil end
    local ok, t = pcall(fn, id)
    if ok and type(t) == "string" then return t end
    return nil
end

-- A quest was turned in (QUEST_TURNED_IN questID; title from the quest frame
-- when the client doesn't return it by ID). Returns the matched quest or nil.
function Progress.NoteTurnIn(questID, title)
    local q = byTitle(titleFor(questID) or title)
    local log = questLog()
    if not q or not log then return nil end
    log.done[q.name] = true
    if questID then log.ids[q.name] = questID end
    return q
end

-- At login: completed quest IDs whose titles match an ID-less class quest.
function Progress.ScanCompleted()
    local fn = C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs
    local log = questLog()
    if not fn or not log then return 0 end
    local ok, ids = pcall(fn)
    if not ok or type(ids) ~= "table" then return 0 end
    local n = 0
    for _, id in ipairs(ids) do
        local q = byTitle(titleFor(id))
        if q and not log.done[q.name] then
            log.done[q.name], log.ids[q.name] = true, id
            n = n + 1
        end
    end
    return n
end

-- Class quests for a race + faction (nil = show all). Quests without a
-- researched ID are kept and flagged (`missing`), never given an invented ID.
function Progress.ClassQuests(race, faction)
    local out = {}
    for _, q in ipairs(ns.Data.Quests) do
        local ok = (race == nil) or q.races == nil or raceMatches(q.races, race)
        if ok and faction and q.faction and q.faction ~= "Both" and q.faction ~= faction then ok = false end
        if ok then
            if q.quest_id == nil then q.missing = true end
            table.insert(out, q)
        end
    end
    table.sort(out, function(a, b)
        local la, lb = a.level or 99, b.level or 99
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    return out
end

-- The next class quest at or above level-ish that isn't completed.
function Progress.NextClassQuest(race, faction, level)
    for _, q in ipairs(Progress.ClassQuests(race, faction)) do
        if not Progress.IsClassQuestDone(q) then
            if q.level and q.type ~= "repeatable" and q.level >= (level or 1) - 10 then return q end
        end
    end
    return nil
end

-- Gold goals. Values come from research riding data (training cost text "100g").
local function goldFromText(text)
    local g = text and tonumber(tostring(text):match("(%d+)g"))
    return g
end

function Progress.GoldGoals()
    local goals = {}
    for _, r in ipairs(ns.Data.Riding) do
        local cost = goldFromText(r.training)
        if cost and r.level then
            table.insert(goals, {
                name = r.skill, level = r.level, gold = cost, speed = r.speed,
                mount = r.mount_cost, spell_id = r.spell_id, source_url = r.source_url, checked = r.checked,
            })
        end
    end
    table.sort(goals, function(a, b) return a.level < b.level end)
    return goals
end

function Progress.RidingNotes()
    for _, r in ipairs(ns.Data.Riding) do
        if r.notes then return r end
    end
end

function Progress.MountForRace(race)
    for _, m in ipairs(ns.Data.Mounts) do
        if m.race == race then return m end
    end
end

function Progress.KnowsSpell(id)
    if not id then return false end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, id)
        if ok and known then return true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, id)
        if ok and known then return true end
    end
    return false
end

-- Next unmet gold goal (skipping skills already learned).
function Progress.NextGoldGoal(level)
    for _, g in ipairs(Progress.GoldGoals()) do
        if not Progress.KnowsSpell(g.spell_id) then return g end
    end
end

function Progress.NextMilestone(level)
    for _, m in ipairs(ns.Data.Milestones.items) do
        if m.level > level then return m end
    end
end

-- Spell known by name: research IDs first (base id, per-rank ids, any id a
-- source showed for it), then the spellbook by name. Several ranked Rogue
-- spells have no confirmed rank-1 id in the research, so the name lookup always
-- runs when no id matched.
function Progress.Knows(name)
    local id = ns.Rotation and ns.Rotation.SpellId(name)
    if id and Progress.KnowsSpell(id) then return true end
    local s = ns.Rotation and ns.Rotation.SpellRecord(name)
    for _, rid in ipairs(s and s.rank_spell_ids or {}) do
        if Progress.KnowsSpell(rid) then return true end
    end
    for _, rid in ipairs(s and s.spell_ids_seen or {}) do
        if Progress.KnowsSpell(rid) then return true end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local clean = ns.Rotation and ns.Rotation.Clean(name) or name
        local ok, info = pcall(C_Spell.GetSpellInfo, clean)
        if ok and info and not ns.Auras.IsSecret(info) then return true end
    end
    return false
end

function Progress.MoneyText(copper)
    copper = copper or 0
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    return ("%dg %ds"):format(g, s)
end
