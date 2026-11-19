-- Gold: Session · History · Farms · Tips. v0.1 keeps it simple: this session's
-- money by source (no combat log, no chat parsing: see Modules/Gold.lua), the
-- last sessions, and the researched farm spots for your level.
local _, ns = ...
local UI = ns.UI

local TABS = { "Session", "History", "Farms", "Tips" }
local tab = "Session"
local S = {}

local function gold(t) return UI.Hex(ns.PocketAccent) .. t .. "|r" end
local function money(c) return ns.Gold.Format(c or 0) end

S.Session = function(L, c)
    local s = ns.Gold.Session()
    L:Columns({ 0.5, 0.5 })
    L:Label(gold("This session"))
    if not s then L:Text("Starts at login.") L:EndColumns() return end
    local ph = ns.Gold.PerHour()
    L:Row({ title = "Net: " .. money(s.gained - s.spent), right = ph and (money(ph) .. "/h") or nil,
        sub = "Gained " .. money(s.gained) .. " · spent " .. money(s.spent) })
    for _, k in ipairs(ns.Gold.SOURCES) do
        local v = s.by[k] or 0
        if v ~= 0 then L:Row({ title = ns.Gold.SOURCE_LABELS[k], right = (v > 0 and UI.Hex(UI.C.good) or UI.Hex(UI.C.bad)) .. money(v) .. "|r" }) end
    end
    L:Text(UI.Hex(UI.C.dim) .. "Money is labelled by what was open when it changed: a Pick Pocket loot window, another loot window, a merchant, the mailbox (AH), or a quest turn-in. Everything else is \"Other\".|r", { size = 11 })
    L:NextColumn()
    L:Label(gold("Pick Pocket"))
    local T = ns.Pockets.Totals()
    L:Row({ title = T.session.n .. " pickpockets", right = money(T.session.copper), sub = "Lifetime: " .. T.life.n .. " · " .. money(T.life.copper) })
    L:Buttons({ { label = "Pockets & Locks", onClick = function() UI.Select("pockets") end } })
    L:Label(gold("Boxes in your bags"))
    local any = false
    for name, t in pairs(ns.Locks.Counts()) do
        any = true
        local price, label = ns.Locks.Value(t.box or {}, nil)
        L:Row({ title = name .. " x" .. (t.bags + t.bank), right = price and (money(price * (t.bags + t.bank)) .. " " .. UI.Hex(UI.C.dim) .. label .. "|r") or "?" })
    end
    if not any then L:Text(UI.Hex(UI.C.dim) .. "None.|r") end
    L:EndColumns()
end

S.History = function(L, c)
    local list = ns.db.char.gold.sessions
    if #list == 0 then L:Text("No sessions yet.") return end
    for i = #list, math.max(1, #list - 14), -1 do
        local s = list[i]
        local parts = {}
        for _, k in ipairs(ns.Gold.SOURCES) do
            if (s.by[k] or 0) ~= 0 then parts[#parts + 1] = ns.Gold.SOURCE_LABELS[k] .. " " .. money(s.by[k]) end
        end
        L:Row({ title = (rawget(_G, "date") and date("%b %d %H:%M", s.start) or "?"), right = money((s.gained or 0) - (s.spent or 0)),
            sub = #parts > 0 and table.concat(parts, " · ") or "no money change" })
    end
end

S.Farms = function(L, c)
    L:Text(UI.Hex(UI.C.dim) .. "Researched spots near your level (±5), your faction first. Fan-site spots are hints: unconfirmed unless marked otherwise.|r", { size = 12 })
    local list = ns.Gold.Farms(c.level, c.faction)
    if #list == 0 then L:Text("Nothing near your level in the research. Pickpocket every humanoid as you quest.") end
    for _, f in ipairs(list) do
        L:Row({ chip = { text = (f.level_min or "?") .. "-" .. (f.level_max or "?"), kind = "neutral" }, title = (f.spot or "?") .. ", " .. (f.zone or "?"),
            right = f.method, sub = (f.what_sells or "") .. (f.notes and ("\n" .. f.notes) or "") .. UI.FlagText(f),
            button = f.zone and { label = "Map", onClick = function() ns.Map.Mark(f.zone, f.coords, f.spot) end } or nil })
        L:Source(f)
    end
end

S.Tips = function(L, c)
    for _, t in ipairs(ns.Data.GoldTips or {}) do
        L:Row({ title = t.title or "", sub = (t.body or "") .. UI.FlagText(t) })
        L:Source(t)
    end
    if not (ns.Data.GoldTips and ns.Data.GoldTips[1]) then L:Text("No gold tips in the research yet.") end
end

UI.RegisterPanel({
    key = "gold", label = "Gold",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L, c)
        L:Title("Gold", "Money this session by source, past sessions, and where rogues make gold")
        local items = {}
        for _, t in ipairs(TABS) do table.insert(items, { label = t, active = tab == t, onClick = function() tab = t UI.Refresh() end }) end
        L:Tabs(items)
        ;(S[tab] or S.Session)(L, c)
    end,
})
