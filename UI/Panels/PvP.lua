-- PvP (pattern from Tristan's Addon's Battle screen, kept small): Honor & Rank ·
-- Battlegrounds · Rogue PvP · Gear. No combat log, no chat sending; anything
-- the client won't tell addons shows as "hidden".
local _, ns = ...
local UI = ns.UI

local TABS = { "Honor & Rank", "Battlegrounds", "Rogue PvP", "Gear" }
local tab = "Honor & Rank"
local S = {}

local function red(t) return UI.Hex(ns.BattleAccent) .. t .. "|r" end
local function P() return ns.Data.PvP or {} end
local flag = function(e) return UI.FlagText(e) end

S["Honor & Rank"] = function(L, c)
    local rank, honor, session = ns.PvP.Rank(), ns.PvP.Honor(), ns.PvP.Session()
    L:Columns({ 0.55, 0.45 })
    L:Label(red("You"))
    if rank then
        L:Row({ chip = { text = "R" .. rank.rank, kind = "info" }, title = rank.rank > 0 and (rank.name or ("Rank " .. rank.rank)) or "No rank yet" })
        if rank.progress then L:Progress("Progress to the next rank", math.floor(rank.progress * 100), 100, math.floor(rank.progress * 100) .. "%") end
    else
        L:Row({ chip = { text = "hidden", kind = "neutral" }, title = "Rank and Rank Points", sub = "Not readable by addons here. Press C, then the Player vs. Player tab." })
    end
    if honor then
        L:Row({ icon = honor.icon, title = "Honor: " .. honor.amount .. (honor.max and honor.max > 0 and (" / " .. honor.max) or "") })
    else
        L:Row({ chip = { text = "hidden", kind = "neutral" }, title = "Honor", sub = "Not readable here; see Character > Player vs. Player." })
    end
    if session then L:Row({ title = ("This session: %s honorable kills"):format(tostring(session.hk)) }) end
    local nextR = ns.PvP.NextReward(rank and rank.rank or 0)
    if nextR then L:Label(red("Next rank reward")) L:Row({ chip = { text = "R" .. nextR.rank, kind = "warn" }, title = nextR.reward }) L:Source(nextR) end
    local gp = P().gear_path
    if gp then L:Label(red("Gear path")) L:Text((gp.text or "") .. flag(gp), { size = 12 }) L:Source(gp) end
    L:NextColumn()
    L:Label(red("Rank rewards (Blizzard)"))
    for _, r in ipairs(ns.PvP.Ranks()) do
        L:Row({ chip = { text = "R" .. r.rank, kind = (rank and rank.rank >= r.rank) and "good" or "neutral" }, title = r.reward })
    end
    if ns.PvP.Ranks()[1] then L:Source(ns.PvP.Ranks()[1]) end
    L:EndColumns()
    L:Label(red("What this client lets addons read"))
    local probes = ns.PvP.RunProbes()
    for _, name in ipairs(ns.PvP.PROBE_ORDER) do
        local p = probes[name] or { status = "missing" }
        L:Row({ chip = { text = p.status, kind = p.status == "ok" and "good" or (p.status == "secret" and "warn" or "neutral") }, title = name, sub = p.note })
    end
    local s = P().summary
    if s then L:Note(s.text) L:Source(s) end
end

S.Battlegrounds = function(L, c)
    local list = ns.PvP.Battlegrounds()
    if #list == 0 then L:Flag("No battleground data in the research.") return end
    local q = P().queue
    if q and q.text then L:Text(UI.Hex(UI.C.dim) .. q.text .. "|r", { size = 12 }) L:Source(q) end
    for _, bg in ipairs(list) do
        local open = ns.PvP.BGOpen(bg, c.level)
        local sub = {}
        if bg.objective then sub[#sub + 1] = bg.objective end
        if bg.size then sub[#sub + 1] = bg.size end
        L:Row({ chip = open and { text = "Open to you", kind = "good" } or { text = bg.min_level and ("from " .. bg.min_level) or "?", kind = "neutral" },
            title = bg.name, right = (bg.min_level or "?") .. "-" .. (bg.max_level or "?"), sub = table.concat(sub, "\n") .. flag(bg) })
        L:Source(bg)
    end
    L:Note("Weapon skills count as maxed in battlegrounds (Wowhead weapon-trainer guide).")
end

S["Rogue PvP"] = function(L, c)
    local z = ns.PvP.Zone()
    L:Columns({ 0.5, 0.5 })
    L:Label(red("Where you are"))
    if z then
        L:Row({ chip = { text = z.kind, kind = ns.PvP.ZONE_KIND[z.kind] or "neutral" }, title = z.text,
            sub = z.flagged == nil and "Flag state hidden." or (z.flagged and "You're flagged for PvP." or "You're not flagged.") })
    else
        L:Row({ chip = { text = "hidden", kind = "neutral" }, title = "Zone PvP status isn't readable here" })
    end
    local tip = ns.PvP.DangerTip()
    if tip then L:Row({ chip = { text = "Ready", kind = "good" }, title = tip }) end
    L:Label(red("Poison choices"))
    for _, p in ipairs(P().poison_choices or {}) do
        L:Row({ title = p.poison, sub = p.when })
        L:Source(p)
    end
    L:NextColumn()
    L:Label(red("Rogue notes"))
    for _, n in ipairs(P().rogue_notes or {}) do
        L:Row({ title = n.title or "", sub = (n.body or "") .. flag(n) })
        L:Source(n)
    end
    if not (P().rogue_notes and P().rogue_notes[1]) then L:Text("No rogue PvP notes in the research yet.") end
    L:EndColumns()
end

S.Gear = function(L, c)
    local list = P().gear or {}
    if #list == 0 then
        L:Flag("No rogue PvP gear list in the research yet (see About the data > gaps). The blue/epic Honor sets are on Character > Player vs. Player.")
        return
    end
    for _, g in ipairs(list) do
        L:Item(g.item_id, g.name, (g.slot or "") .. " · " .. (g.source or "") .. flag(g), g.bracket)
        L:Source(g)
    end
end

UI.RegisterPanel({
    key = "pvp", label = "PvP",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L, c)
        L:Title("PvP", "Honor & Rank, battlegrounds and rogue PvP notes")
        local items = {}
        for _, t in ipairs(TABS) do table.insert(items, { label = t, active = tab == t, onClick = function() tab = t UI.Refresh() end }) end
        L:Tabs(items)
        ;(S[tab] or S["Honor & Rank"])(L, c)
    end,
})
