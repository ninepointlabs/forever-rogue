-- SavedVariables and the dual-spec-ready profile model.
--
-- ForeverRogueDB      (account)        minimap, read "What's changed" ids, global toggles
-- ForeverRogueCharDB  (per character)  two spec profiles A/B + active pointer, reminders,
--                                      teaching progress, the Pick Pocket log and totals,
--                                      boxes opened, gold sessions, lockpicking history
--
-- Every spec-aware feature asks ns.DB.ActiveSpec(); switching profile (manually
-- now, automatically later via Core/DualSpec.lua) re-fires "SPEC_CHANGED".
local _, ns = ...

local DB = {}
ns.DB = DB

DB.SCHEMA = 1
DB.PROFILE_IDS = { "A", "B" }

local function deepDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            deepDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end
DB.deepDefaults = deepDefaults

function DB.NewProfile()
    return {
        spec = nil,               -- "Assassination" | "Combat" | "Subtlety"; nil until picked
        levelingWeights = nil,    -- nil = spec default (see Modules/Stats.lua)
        weights = {},             -- per-stat overrides of the derived weights
        rotationContext = "solo", -- "solo" | "dungeon" | "raid"
    }
end

DB.accountDefaults = {
    schema = DB.SCHEMA,
    minimap = { angle = 215, hide = false },
    changesRead = {},
    tooltip = { enabled = true, showStats = true },
    bags = { highlight = true, toast = true },
    percentScale = 10, -- points per 1% hit/crit: addon assumption, editable, flagged in-game
    debug = false,
}

-- Brief default (Tim may change): keep the last 2,000 pickpockets per character;
-- the per-mob, per-zone and lifetime totals are never trimmed.
DB.POCKET_LOG_CAP = 2000

DB.charDefaults = {
    schema = DB.SCHEMA,
    active = "A",
    profiles = {},
    autoSwitch = true, -- follow the active talent spec (Core/DualSpec.lua): group 1 = A, group 2 = B
    reminders = {
        enabled = true, poisons = true, reagents = true, snd = true, classQuests = true, thievesTools = true,
    },
    rotation = { enabled = true, showInCombatOnly = false, scale = 1, point = nil },
    learn = { hints = true, seenSpells = {}, readLessons = {} },
    summary = { enabled = true },
    -- Pick Pocket log (Modules/Pockets.lua): ring buffer + totals that are never trimmed.
    pockets = {
        log = {}, head = 0, count = 0, cap = DB.POCKET_LOG_CAP,
        totals = {
            session = { n = 0, copper = 0, items = 0, boxes = 0, start = nil },
            day = { n = 0, copper = 0, items = 0, boxes = 0, date = nil },
            life = { n = 0, copper = 0, items = 0, boxes = 0 },
        },
        byMob = {}, byZone = {},
        refillMinutes = 10, -- fan-site figure (kickegg), a setting; measured repeats shown next to it
        lastByGuid = {},
        repeats = {},
    },
    boxes = { opened = {}, openedTotal = 0 },
    lockpick = { history = {} },
    gold = { sessions = {} },
    -- Rogue bar: Pick Lock button and the two poison buttons are secure macros
    -- (casts/uses, out of combat only); reagent cells and the pocket counter are
    -- plain frames. Keys default to none.
    pickLock = { enabled = true, key = nil },
    poisonMH = { enabled = true, key = nil, override = nil }, -- override: poison base name pinned by the player
    poisonOH = { enabled = true, key = nil, override = nil },
    reagentCells = { enabled = true },
    pocketCounter = { enabled = true },
    rogueBar = { point = nil },
    pvp = { rewardGoal = nil },
    window = { tab = "home" },
    lastLevel = nil,
}

-- Wire up (or create) the saved tables. Pure function of its inputs so tests can
-- drive it without a client.
function DB.Init(account, char)
    account = deepDefaults(account or {}, DB.accountDefaults)
    char = deepDefaults(char or {}, DB.charDefaults)
    for _, id in ipairs(DB.PROFILE_IDS) do
        char.profiles[id] = deepDefaults(char.profiles[id] or {}, DB.NewProfile())
    end
    if not char.profiles[char.active] then char.active = "A" end
    if type(char.pockets.cap) ~= "number" or char.pockets.cap < 1 then char.pockets.cap = DB.POCKET_LOG_CAP end
    DB.global, DB.char = account, char
    ns.db = { global = account, char = char }
    return account, char
end

function DB.Profile(id)
    return DB.char.profiles[id or DB.char.active]
end

function DB.ActiveId()
    return DB.char.active
end

function DB.ActiveSpec()
    local p = DB.Profile()
    return p and p.spec
end

function DB.HasChosenSpec()
    return DB.ActiveSpec() ~= nil
end

function DB.SetSpec(spec, id)
    assert(ns.Specs[spec], "unknown spec " .. tostring(spec))
    local p = DB.Profile(id)
    local changed = p.spec ~= spec
    p.spec = spec
    if changed and (id == nil or id == DB.char.active) then ns.Fire("SPEC_CHANGED", spec) end
end

function DB.SwitchProfile(id)
    if not DB.char.profiles[id] or DB.char.active == id then return false end
    DB.char.active = id
    ns.Fire("SPEC_CHANGED", DB.ActiveSpec())
    return true
end

function DB.OtherProfileId()
    return DB.char.active == "A" and "B" or "A"
end
