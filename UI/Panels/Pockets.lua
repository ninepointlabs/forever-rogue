-- Pockets & Locks: Log · Best targets · Boxes · Lockpicking · Doors.
-- The Pick Pocket log is the player's own; "Best targets" shows GoldScout's
-- crowdsourced numbers (Tim's decision, 2026-11-19), labelled "Community data
-- (GoldScout)" with sample size and an "unconfirmed" badge, side by side with
-- the player's own best mobs.
local _, ns = ...
local UI = ns.UI

local TABS = { "Log", "Best targets", "Boxes", "Lockpicking", "Doors" }
local tab = "Log"
local S = {}
UI.PocketSections = S

local function gold(t) return UI.Hex(ns.PocketAccent) .. t .. "|r" end
local function flag(e) return UI.FlagText(e) end
local function money(c) return ns.Gold.Format(c or 0) end

local function totalsRow(L, label, t, extra)
    local per = ns.Pockets.CopperPer(t)
    L:Row({ title = label .. ": " .. (t.n or 0) .. " pickpocket" .. ((t.n or 0) == 1 and "" or "s"),
        right = UI.Hex(ns.PocketAccent) .. money(t.copper) .. "|r",
        sub = ("%s per pickpocket · %d item(s) · %d junkbox(es)%s"):format(per and money(per) or "-", t.items or 0, t.boxes or 0, extra or "") })
end

S.Log = function(L, c)
    if not ns.Progress.Knows("Pick Pocket") then
        L:Row({ chip = { text = "Level 4", kind = "info" }, title = "Pick Pocket is learned at level 4",
            sub = "Once you have it, every pickpocket is logged here: coin, items, junkboxes, the mob and the zone." })
    end
    local T = ns.Pockets.Totals()
    L:Columns({ 0.5, 0.5 })
    L:Label(gold("Totals"))
    local ph = ns.Pockets.PerHour()
    totalsRow(L, "This session", T.session, ph and (" · %.0f per hour"):format(ph) or nil)
    totalsRow(L, "Today", T.day)
    totalsRow(L, "Lifetime", T.life, (T.life.empty and T.life.empty > 0) and (" · " .. T.life.empty .. " with nothing to take") or nil)
    L:Text(UI.Hex(UI.C.dim) .. ("The log keeps your last %d pickpockets (%d now). Totals, per-mob and per-zone numbers are never trimmed.|r"):format(ns.db.char.pockets.cap, ns.Pockets.Count()), { size = 11 })
    L:NextColumn()
    L:Label(gold("Pocket refill"))
    local measured, n = ns.Pockets.MeasuredRefill()
    L:Row({ title = ("Timer: %d minutes"):format(ns.db.char.pockets.refillMinutes),
        sub = "Fan sites say pockets refill after about 10 minutes (kickegg; unverified). " ..
            (measured and ("Your own repeats on the same mob: median %.1f min over %d."):format(measured, n) or "No repeats on the same mob measured yet.") })
    local items = {}
    for _, m in ipairs({ 5, 10, 15, 20 }) do
        table.insert(items, { label = m .. " min", active = ns.db.char.pockets.refillMinutes == m, onClick = function() ns.db.char.pockets.refillMinutes = m UI.Refresh() end })
    end
    L:Buttons(items, 70)
    local ti = ns.Rogue.TargetInfo()
    if ti and ti.guid then
        local left = ns.Pockets.RefillLeft(ti.guid)
        if left then
            L:Row({ chip = { text = left > 0 and "wait" or "ready", kind = left > 0 and "warn" or "good" }, title = (ti.name or "Target") .. ": " .. (left > 0 and (math.ceil(left / 60) .. " min until refill") or "pockets should be full again") })
        end
    end
    L:EndColumns()
    L:Label(gold("Latest pickpockets"))
    local log = ns.Pockets.Log(25)
    if #log == 0 then
        L:Row({ chip = { text = "Empty", kind = "neutral" }, title = "No pickpockets logged yet",
            sub = "Sneak up on a humanoid (Stealth), Pick Pocket it, and the loot shows up here. Inside dungeons the game hides mob names from addons, so those entries say \"unknown mob\"." })
    end
    for _, e in ipairs(log) do
        local items = {}
        for _, it in ipairs(e.items or {}) do items[#items + 1] = (it.link or "?") .. ((it.q and it.q > 1) and (" x" .. it.q) or "") end
        L:Row({ chip = e.junkbox and { text = e.junkbox, kind = "good" } or nil, title = ns.Pockets.EntryLabel(e),
            right = UI.Hex(ns.PocketAccent) .. (e.coinUnknown and "?" or money(e.copper)) .. "|r",
            sub = ((e.zone and e.mob) and (e.zone .. " · ") or "") .. (rawget(_G, "date") and date("%b %d %H:%M", e.t) or "") .. (#items > 0 and ("\n" .. table.concat(items, ", ")) or "") })
    end
end

local function pinChecks(L)
    local cfg = ns.db.char.pocketPins
    L:Check("Show pickpocket spots on the minimap", cfg.enabled, function(v) ns.MinimapPins.Toggle(v) UI.Refresh() end,
        "Researched spots that have coordinates (near your level) and the spots where you picked pockets. Open world only. /frogue pins")
    if cfg.enabled then
        L:Check("  Researched spots (fan guides, GoldScout hotspots)", cfg.research, function(v) cfg.research = v ns.MinimapPins.Refresh() UI.Refresh() end)
        L:Check("  My own spots (from the log)", cfg.mine, function(v) cfg.mine = v ns.MinimapPins.Refresh() UI.Refresh() end)
    end
end
UI.PocketPinChecks = pinChecks

S["Best targets"] = function(L, c)
    pinChecks(L)
    L:Columns({ 0.5, 0.5 })
    L:Label(gold("From your own log"))
    local mine = ns.Pockets.BestMobs(3, 10)
    if #mine == 0 then
        L:Text(UI.Hex(UI.C.dim) .. "Pick at least 3 pockets of the same kind of mob and your best ones rank here (coin per pickpocket, junkbox rate).|r", { size = 12 })
    end
    for i, m in ipairs(mine) do
        L:Row({ chip = { text = "#" .. i, kind = "good" }, title = m.mob .. (m.minLevel and (" (" .. m.minLevel .. (m.maxLevel ~= m.minLevel and ("-" .. m.maxLevel) or "") .. ")") or ""),
            right = money(m.per), sub = ("%d pickpockets · %d junkbox(es) (%.0f%%) · %s"):format(m.n, m.boxes, m.boxRate * 100, m.zone or "?") })
    end
    L:NextColumn()
    L:Label(gold("Community data (GoldScout)"))
    L:Text(UI.Hex(UI.C.dim) .. "Crowdsourced by the GoldScout addon's players (wowgoldscout.com): junkbox chance per pickpocket, with how many pickpockets were recorded (n). Small samples: treat as hints.|r", { size = 11 })
    local list = {}
    for _, t in ipairs(ns.Data.PickpocketTargets or {}) do
        local f = t.faction_note
        list[#list + 1] = t
    end
    table.sort(list, function(a, b)
        local la, lb = math.abs((a.level_min or 0) - c.level), math.abs((b.level_min or 0) - c.level)
        if la ~= lb then return la < lb end
        return (a.chance_pct or 0) > (b.chance_pct or 0)
    end)
    local shown = 0
    for _, t in ipairs(list) do
        if shown >= 14 then break end
        shown = shown + 1
        local community = t.community == "GoldScout"
        local chips = community and { text = "Community", kind = "info" } or { text = "Fan guide", kind = "neutral" }
        local right = t.chance_pct and (t.chance_pct .. "%" .. (t.sample_n and (" (n=" .. t.sample_n .. ")") or "")) or ""
        L:Row({ chip = chips, title = t.mob .. (t.level_min and (" (" .. t.level_min .. (t.level_max and t.level_max ~= t.level_min and ("-" .. t.level_max) or "") .. ")") or ""),
            right = right,
            sub = (t.zone or "?") .. (t.junkbox and (" · " .. t.junkbox .. " Junkbox") or "") .. (t.notes and ("\n" .. t.notes) or "") .. flag(t),
            button = t.zone and { label = "Map", onClick = function() ns.Map.Mark(t.zone, t.coords, t.mob) end } or nil })
        L:Source(t)
    end
    if shown == 0 then L:Flag("No pickpocket targets in the research.") end
    L:EndColumns()
end

S.Boxes = function(L, c)
    local lp = ns.Rogue.Lockpicking()
    local skill = type(lp) == "table" and lp.rank or nil
    L:Text(UI.Hex(UI.C.dim) .. "Lock values are the Classic ones (Forever's database shows placeholders); colours follow Classic skill-up colours (an addon assumption). Value: " ..
        (ns.Gold.AuctionatorLoaded() and "Auctionator prices (AH)." or "vendor prices (install Auctionator for AH prices).") .. "|r", { size = 11 })
    local counts = ns.Locks.Counts()
    L:Label(gold("In your bags" .. (next(counts) and "" or ": none")))
    for name, t in pairs(counts) do
        local need = t.box and t.box.skill
        local col = ns.Locks.Color(skill, need)
        local price, label = ns.Locks.Value(t.box or {}, nil)
        L:Row({ chip = { text = col, kind = (col == "red") and "warn" or ((col == "grey" or col == "unknown") and "neutral" or "good") }, title = name .. "  x" .. (t.bags + t.bank),
            right = price and (money(price) .. " " .. UI.Hex(UI.C.dim) .. "(" .. label .. ")|r") or nil,
            sub = ("bags %d · bank %s · needs %s · %s"):format(t.bags, t.bank > 0 and t.bank or "open the bank to count", tostring(need or "?"), ns.Locks.COLOR_TEXT[col]) })
    end
    L:Label(gold("Junkboxes (Pick Pocket only)"))
    for _, j in ipairs(ns.Data.Junkboxes or {}) do
        local col = ns.Locks.Color(skill, j.lock_skill)
        local price, label = ns.Locks.Value(j, nil)
        L:Item(j.item_id, j.name, ("needs %s · mobs %s · %s"):format(tostring(j.lock_skill), tostring(j.mob_level_range or "?"), ns.Locks.COLOR_TEXT[col]) .. flag(j),
            price and (money(price) .. " " .. UI.Hex(UI.C.dim) .. label .. "|r") or nil)
        L:Source(j)
    end
    L:Label(gold("Lockboxes (drops)"))
    for _, b in ipairs(ns.Data.Lockboxes or {}) do
        local col = ns.Locks.Color(skill, b.lock_skill)
        L:Row({ title = b.name, right = tostring(b.lock_skill or "?"), sub = ("mobs %s · %s"):format(tostring(b.mob_level_range or "?"), ns.Locks.COLOR_TEXT[col]) .. flag(b) })
        L:Source(b)
    end
    L:Note("Open other players' boxes in a city: they put the box in the bottom trade slot (\"will not be traded\"); tips are up to them.")
end

S.Lockpicking = function(L, c)
    local lp = ns.Rogue.Lockpicking()
    local cap = ns.Rogue.LockpickCap(c.level)
    L:Columns({ 0.5, 0.5 })
    L:Label(gold("Your skill"))
    if lp then
        L:Progress("Lockpicking", lp.base, cap, lp.base .. " / " .. cap .. " (cap at your level)")
    elseif lp == false then
        L:Row({ chip = { text = "Not yet", kind = "info" }, title = "No Lockpicking skill yet",
            sub = "Pick Lock's level is disputed (client 1, Icy Veins 15, fan sites 16): see About the data. Rogues usually get it with the lockpicking class quest." })
    else
        L:Row({ chip = { text = "hidden", kind = "neutral" }, title = "Skill not readable here", sub = "Check your Skills / profession window." })
    end
    local tools = ns.Rogue.HasThievesTools()
    L:Row({ chip = { text = tools and "Yes" or (tools == false and "No" or "?"), kind = tools and "good" or "warn" }, title = "Thieves' Tools in your bags",
        sub = "Pick Lock needs them (item 5060 per wowfdb). The lockpicking class quest gives a set." })
    local r = ns.db.char.lockpick.history
    if #r > 1 then L:Text(UI.Hex(UI.C.dim) .. ("Skill-ups seen by the addon: %d (last at %s).|r"):format(#r - 1, tostring(r[#r].zone or "?")), { size = 11 }) end
    L:NextColumn()
    L:Label(gold("Next step on the route"))
    local step = ns.Locks.RouteStep(lp and lp.base or 1, c.faction)
    if step then
        L:Row({ title = ("%d-%d: %s"):format(step.skill_from or 0, step.skill_to or 0, step.spot or step.zone or "?"), sub = (step.zone or "") .. " · " .. (step.object or "") .. (step.notes and ("\n" .. step.notes) or "") .. flag(step),
            button = { label = "Map", onClick = function() ns.Map.Mark(step.zone, step.coords, step.spot) end } })
        L:Source(step)
    else
        L:Text("No route step for your skill and faction in the research.")
    end
    L:EndColumns()
    L:Label(gold("The whole route"))
    for _, s in ipairs(ns.Data.LockpickRoute or {}) do
        if not s.faction or s.faction == "Both" or s.faction == c.faction then
            L:Row({ chip = { text = (s.skill_from or 0) .. "-" .. (s.skill_to or 0), kind = "neutral" }, title = (s.spot or "?") .. ", " .. (s.zone or "?"),
                sub = (s.object or "") .. (s.coords and (" · " .. s.coords[1] .. ", " .. s.coords[2]) or "") .. (s.notes and ("\n" .. s.notes) or "") .. flag(s),
                button = { label = "Map", onClick = function() ns.Map.Mark(s.zone, s.coords, s.spot) end } })
            L:Source(s)
        end
    end
    local rules = ns.Data.LockpickRules
    if rules then L:Note(rules.notes or "Cap = level x 5.") L:Source(rules) end
end

S.Doors = function(L, c)
    local lp = ns.Rogue.Lockpicking()
    L:Text(UI.Hex(UI.C.dim) .. "Locked doors and chests in dungeons you can open with Pick Lock (Classic values; verify in Forever).|r", { size = 12 })
    for _, d in ipairs(ns.Data.LockDoors or {}) do
        local col = ns.Locks.Color(lp and lp.rank or nil, d.skill)
        L:Row({ chip = { text = tostring(d.skill or "?"), kind = (col == "red" or col == "unknown") and "neutral" or "good" }, title = d.dungeon .. ": " .. (d.what or ""), sub = ns.Locks.COLOR_TEXT[col] .. flag(d) })
        L:Source(d)
    end
    if not (ns.Data.LockDoors and ns.Data.LockDoors[1]) then L:Flag("No door data in the research.") end
end

UI.RegisterPanel({
    key = "pockets", label = "Pockets & Locks",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L, c)
        L:Title("Pockets & Locks", "Your Pick Pocket log, the best targets, boxes and Lockpicking")
        local items = {}
        for _, t in ipairs(TABS) do table.insert(items, { label = t, active = tab == t, onClick = function() tab = t UI.Refresh() end }) end
        L:Tabs(items)
        ;(S[tab] or S.Log)(L, c)
    end,
})
