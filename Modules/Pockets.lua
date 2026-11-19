-- Pick Pocket log and earnings (the headline feature).
--
-- How a pickpocket is recognised without a combat log (BRIEF §3):
--   1. UNIT_SPELLCAST_SUCCEEDED("player", Pick Pocket) -> an attempt starts: we
--      remember the target (name, level, GUID when readable), the zone and your
--      money at that moment.
--   2. LOOT_OPENED / LOOT_READY within a few seconds -> the loot window is the
--      victim's pockets: item links are read from the loot slots.
--   3. LOOT_CLOSED -> coin = money now - money at the cast (Blizzard's own
--      money, not chat text, so it works in every language and with auto loot).
-- Inside instances creature names and GUIDs are secret: the entry is still
-- recorded as "unknown mob, <zone>" with whatever coin and items we saw.
--
-- Storage (ForeverRogueCharDB.pockets): a ring buffer of the last N entries
-- (default 2,000; brief default) plus session/day/lifetime totals and per-mob
-- and per-zone totals that are never trimmed.
local _, ns = ...

local Pockets = {}
ns.Pockets = Pockets

Pockets.ATTEMPT_WINDOW = 4 -- seconds between the cast and the loot window
Pockets.MAX_REPEATS = 50

local pending -- current attempt
local function db() return ns.db.char.pockets end
local function secret(v) return ns.Auras.IsSecret(v) end

local function now() return (rawget(_G, "time") and time()) or 0 end
local function today()
    local d = rawget(_G, "date")
    return d and d("%Y-%m-%d") or "?"
end

local function emptyTotals() return { n = 0, copper = 0, items = 0, boxes = 0 } end

-- Junkbox item ids from research -> tier name.
local junkById
local function junkboxTier(id)
    if not junkById then
        junkById = {}
        for _, j in ipairs(ns.Data.Junkboxes or {}) do
            if j.item_id then junkById[j.item_id] = (j.name or ""):match("^(%S+)") or j.name end
        end
    end
    return id and junkById[id] or nil
end
Pockets.JunkboxTier = junkboxTier

function Pockets.IsPickPocket(spellID)
    if spellID == nil or secret(spellID) then return false end
    local id = ns.Rotation.SpellId("Pick Pocket")
    if id and spellID == id then return true end
    return ns.Auras.SpellName(spellID) == "Pick Pocket"
end

----------------------------------------------------------------------------
-- Session / day bookkeeping
----------------------------------------------------------------------------
function Pockets.StartSession(t)
    local p = db()
    p.totals.session = emptyTotals()
    p.totals.session.start = t or now()
    -- Forget refill stamps older than two hours (they're only for the timer).
    local cutoff = (t or now()) - 7200
    for guid, ts in pairs(p.lastByGuid) do
        if ts < cutoff then p.lastByGuid[guid] = nil end
    end
end

local function rollDay()
    local p = db()
    local d = today()
    if p.totals.day.date ~= d then
        p.totals.day = emptyTotals()
        p.totals.day.date = d
    end
end

local function add(t, e)
    t.n = (t.n or 0) + 1
    t.copper = (t.copper or 0) + (e.copper or 0)
    t.items = (t.items or 0) + #(e.items or {})
    t.boxes = (t.boxes or 0) + (e.junkbox and 1 or 0)
end

----------------------------------------------------------------------------
-- Ring buffer
----------------------------------------------------------------------------
function Pockets.Record(e)
    local p = db()
    rollDay()
    e.t = e.t or now()
    p.head = (p.head % p.cap) + 1
    p.log[p.head] = e
    p.count = math.min(p.count + 1, p.cap)
    for _, t in ipairs({ p.totals.session, p.totals.day, p.totals.life }) do add(t, e) end
    local key = e.mob or "unknown mob"
    local m = p.byMob[key]
    if not m then
        m = emptyTotals()
        p.byMob[key] = m
    end
    add(m, e)
    if e.level then
        m.minLevel = math.min(m.minLevel or e.level, e.level)
        m.maxLevel = math.max(m.maxLevel or e.level, e.level)
    end
    m.zone = e.zone or m.zone
    local z = p.byZone[e.zone or "Unknown zone"]
    if not z then
        z = emptyTotals()
        p.byZone[e.zone or "Unknown zone"] = z
    end
    add(z, e)
    -- Refill timer: open world only (GUIDs readable). A repeat on the same GUID
    -- that gave loot measures the real refill time.
    if e.guid then
        local last = p.lastByGuid[e.guid]
        if last and e.t > last then
            table.insert(p.repeats, math.floor((e.t - last) / 60 * 10 + 0.5) / 10)
            while #p.repeats > Pockets.MAX_REPEATS do table.remove(p.repeats, 1) end
        end
        p.lastByGuid[e.guid] = e.t
    end
    ns.Fire("POCKETS_CHANGED", e)
    return e
end

-- Newest first, up to n entries.
function Pockets.Log(n)
    local p = db()
    local out = {}
    for i = 0, math.min(n or p.count, p.count) - 1 do
        local idx = ((p.head - 1 - i) % p.cap) + 1
        out[#out + 1] = p.log[idx]
    end
    return out
end

function Pockets.Count() return db().count end
function Pockets.Totals() return db().totals end

-- Pickpockets per hour this session.
function Pockets.PerHour(t)
    local s = db().totals.session
    if not s.start or s.n == 0 then return nil end
    local hours = math.max(((t or now()) - s.start) / 3600, 1 / 60)
    return s.n / hours
end

function Pockets.CopperPer(totals)
    if not totals or (totals.n or 0) == 0 then return nil end
    return totals.copper / totals.n
end

-- Best mobs from your own log: copper per pickpocket (junkboxes break ties),
-- only mobs with at least minN pickpockets.
function Pockets.BestMobs(minN, limit)
    local out = {}
    for name, m in pairs(db().byMob) do
        if name ~= "unknown mob" and m.n >= (minN or 3) then
            out[#out + 1] = { mob = name, n = m.n, copper = m.copper, per = m.copper / m.n, boxes = m.boxes,
                boxRate = m.boxes / m.n, zone = m.zone, minLevel = m.minLevel, maxLevel = m.maxLevel }
        end
    end
    table.sort(out, function(a, b)
        if a.per ~= b.per then return a.per > b.per end
        return a.boxRate > b.boxRate
    end)
    if limit then for i = #out, limit + 1, -1 do out[i] = nil end end
    return out
end

-- Pocket refill: minutes left on this GUID (setting, default 10 = fan-site figure).
function Pockets.RefillLeft(guid, t)
    if not guid then return nil end
    local last = db().lastByGuid[guid]
    if not last then return nil end
    local left = db().refillMinutes * 60 - ((t or now()) - last)
    return left > 0 and left or 0
end

-- Median of your measured repeats (minutes), or nil.
function Pockets.MeasuredRefill()
    local r = {}
    for i, v in ipairs(db().repeats) do r[i] = v end
    if #r == 0 then return nil, 0 end
    table.sort(r)
    local mid = math.floor((#r + 1) / 2)
    return r[mid], #r
end

function Pockets.EntryLabel(e)
    if e.mob then return e.mob .. (e.level and (" (" .. e.level .. ")") or "") end
    return "unknown mob, " .. (e.zone or "unknown zone")
end

----------------------------------------------------------------------------
-- Live event flow
----------------------------------------------------------------------------
local function money()
    local ok, m = pcall(GetMoney)
    if ok and type(m) == "number" and not secret(m) then return m end
    return nil
end

function Pockets.BeginAttempt(t)
    local info = ns.Rogue.TargetInfo() or {}
    local inside = ns.Rogue.InInstance()
    pending = {
        t = t or now(), started = GetTime(), money = money(), zone = ns.Rogue.ZoneName(),
        mob = info.name, level = info.level, guid = (not inside) and info.guid or nil, instance = inside or nil,
    }
    if C_Timer and C_Timer.After then
        local mine = pending
        C_Timer.After(Pockets.ATTEMPT_WINDOW, function()
            if pending == mine and not mine.opened then
                pending = nil
                local life = db().totals.life
                life.empty = (life.empty or 0) + 1
            end
        end)
    end
    return pending
end

function Pockets.Pending() return pending end

-- Loot slots -> { {link, id, name, quantity}, ... }; money slots are skipped
-- (coin comes from the money delta).
function Pockets.ReadLootSlots()
    local items = {}
    local n = rawget(_G, "GetNumLootItems")
    if not n then return items end
    local ok, count = pcall(n)
    if not ok or type(count) ~= "number" or secret(count) then return items, true end
    for i = 1, count do
        local isMoney = false
        local slotType = rawget(_G, "GetLootSlotType")
        if slotType then
            local okT, ty = pcall(slotType, i)
            if okT and ty == 2 then isMoney = true end
        end
        if not isMoney then
            local okL, link = pcall(GetLootSlotLink, i)
            local okI, _, name, qty = pcall(GetLootSlotInfo, i)
            if okL and link and not secret(link) then
                items[#items + 1] = { link = link, id = tonumber(tostring(link):match("item:(%d+)")),
                    name = (okI and name and not secret(name)) and name or tostring(link):match("%[(.-)%]"),
                    quantity = (okI and type(qty) == "number" and not secret(qty)) and qty or 1 }
            end
        end
    end
    return items
end

function Pockets.OnLootOpened(items)
    if not pending or pending.opened then return nil end
    if GetTime() - pending.started > Pockets.ATTEMPT_WINDOW then
        pending = nil
        return nil
    end
    pending.opened = true
    pending.items = items or Pockets.ReadLootSlots()
    return pending
end

function Pockets.OnLootClosed()
    local p = pending
    if not p or not p.opened then return nil end
    pending = nil
    local after = money()
    local e = {
        t = p.t, mob = p.mob, level = p.level, zone = p.zone, guid = p.guid, instance = p.instance,
        copper = (after and p.money) and math.max(0, after - p.money) or 0,
        coinUnknown = (after == nil or p.money == nil) or nil,
        items = {},
    }
    for _, it in ipairs(p.items or {}) do
        e.items[#e.items + 1] = { link = it.link, id = it.id, q = it.quantity }
        local tier = junkboxTier(it.id)
        if tier then e.junkbox = tier end
    end
    return Pockets.Record(e)
end

-- Is the current money change part of a pickpocket? (Gold attribution.)
function Pockets.InWindow()
    return pending ~= nil and pending.opened == true
end

function Pockets.Register()
    pcall(ns.EventFrame.RegisterEvent, ns.EventFrame, "LOOT_READY") -- before auto loot empties the slots
    pcall(ns.EventFrame.RegisterEvent, ns.EventFrame, "LOOT_OPENED")
    pcall(ns.EventFrame.RegisterEvent, ns.EventFrame, "LOOT_CLOSED")
    Pockets.StartSession()
    rollDay()
end

-- One-line counter for the Rogue bar / HUD.
function Pockets.CounterText()
    local s = db().totals.session
    return ("Pockets: %d · %s"):format(s.n, ns.Gold.Format(s.copper, true))
end
