local _, ns = ...
local UI = ns.UI

local WHEN_TEXT = {
    always = "", buff_missing = "if the buff is missing", debuff_missing = "if it isn't on the target",
    ready = "when off cooldown", out_of_combat = "out of combat", in_combat = "in combat",
    manual = "when the situation calls for it", usable = "when it lights up",
    in_melee = "in melee range", stealthed = "from Stealth", not_stealthed = "out of Stealth",
    poison_missing = "if a weapon has no poison (or it's running out)",
}
local function whenText(w)
    if not w then return "" end
    if WHEN_TEXT[w] then return WHEN_TEXT[w] end
    local k, v = w:match("^([%w_]+):(.+)$")
    if k == "cp_at_least" then return "at " .. v .. "+ combo points" end
    if k == "cp_below" then return "under " .. v .. " combo points" end
    if k == "energy_at_least" then return "with " .. v .. "+ Energy" end
    if k == "energy_below" then return "under " .. v .. " Energy" end
    if k == "target_hp_below" then return "when the target is below " .. v .. "% health" end
    if k == "proc" then return "when " .. v .. " procs" end
    if k == "buff_missing" then return "if " .. v .. " is missing" end
    if k == "buff_up" then return "while " .. v .. " is up" end
    if k == "target_debuff_missing" then return "if " .. v .. " isn't on the target" end
    return w
end
ns.Rotation.WhenText = whenText

local view -- nil = the profile's context; "cooldowns" | "energy"

local function stateText(v)
    if v == nil then return UI.Hex(UI.C.dim) .. "hidden|r" end
    return v and (UI.Hex(UI.C.good) .. v .. "|r") or (UI.Hex(UI.C.warn) .. "none|r")
end

-- Content entries for one topic (mechanics with that topic, or a whole section
-- such as content.rogue), with flags and sources.
local function topicEntries(L, topic, asRows)
    local content = ns.Learn.Content()
    local any = false
    local list = {}
    for _, e in ipairs(content and content.mechanics or {}) do if e.topic == topic then table.insert(list, e) end end
    for _, e in ipairs(content and content[topic] or {}) do table.insert(list, e) end
    for _, e in ipairs(list) do
        do
            any = true
            local flag = e.unconfirmed and ("\n" .. UI.FLAG_ICON .. " " .. UI.Hex(UI.C.warn) .. ((e.flag and e.flag ~= "") and e.flag or "Unconfirmed") .. "|r") or ""
            if asRows then
                L:Row({ title = e.title or "", sub = (e.body or "") .. flag })
            else
                L:Text((e.title and (UI.Hex(UI.Accent()) .. e.title .. "|r\n") or "") .. (e.body or "") .. flag, { size = 12 })
            end
            for _, src in ipairs(e.sources or {}) do L:Source({ source_url = src }) end
        end
    end
    return any
end

local function renderCooldowns(L, c)
    L:Text(UI.Hex(UI.C.dim) .. "Your own buffs and cooldowns, read from the game when Forever allows it. Anything unreadable shows 'hidden'. Blizzard's Cooldown Manager (/cdm, Options > Gameplay Enhancement) can track these too.|r", { size = 12 })
    L:Row({ title = ns.Rogue.HudLine(), sub = "Your Energy and combo points (combo points survive a target switch in Forever)." })
    L:Columns({ 0.5, 0.5 })
    L:Label("Buffs")
    local procs = ns.Cooldowns.Procs()
    for _, p in ipairs(procs) do
        local status
        if p.up == nil then status = UI.Hex(UI.C.dim) .. "hidden|r"
        elseif p.up then status = UI.Hex(UI.C.good) .. (p.max and ((p.stacks or 0) .. "/" .. p.max) or "up") .. "|r"
        else status = UI.Hex(UI.C.dim) .. (p.max and ("0/" .. p.max) or "down") .. "|r" end
        L:Row({ icon = ns.Rotation.Icon(p.aura), title = p.aura, right = status })
    end
    if #procs == 0 then L:Text(UI.Hex(UI.C.dim) .. "None yet: Slice and Dice comes at 10.|r", { size = 12 }) end
    L:NextColumn()
    L:Label("Cooldowns")
    local list = ns.Cooldowns.List()
    for _, e in ipairs(list) do
        local right
        if e.left == nil then right = UI.Hex(UI.C.dim) .. "hidden|r"
        elseif e.left <= 0.1 then right = UI.Hex(UI.C.good) .. "ready|r"
        else right = UI.Hex(UI.C.warn) .. ns.Poisons.FormatLeft(math.ceil(e.left)) .. "|r" end
        L:Row({ icon = ns.Rotation.Icon(e.spell), title = e.spell, right = right })
    end
    if #list == 0 then L:Text(UI.Hex(UI.C.dim) .. "No tracked cooldowns known yet.|r", { size = 12 }) end
    L:EndColumns()
end

local function renderEnergy(L, c)
    L:Text(UI.Hex(UI.C.dim) .. "Energy, combo points and openers. Facts from the research; anything unconfirmed is marked.|r", { size = 12 })
    local any = topicEntries(L, "energy", true)
    local rot = ns.Data.Rotations or {}
    if rot.energy then
        L:Label("Energy")
        L:Text(rot.energy, { size = 12 })
        L:Source(ns.Data.Rotations)
    end
    if not any and not rot.energy then L:Text("No energy content in the research yet.") end
end

UI.RegisterPanel({
    key = "rotation", label = "Rotation",
    setSub = function(sub)
        local key = sub and sub:lower()
        if key == "cooldowns" then view = "cooldowns"
        elseif key == "energy" then view = "energy"
        elseif key and ns.Rotation.CONTEXT_LABELS[key] then ns.DB.Profile().rotationContext = key view = nil end
    end,
    render = function(L, c)
        L:Title("Rotation", c.spec and (c.spec .. " · only spells you can use at level " .. c.level) or nil)
        if not c.spec then L:Text("Pick a spec first (spec pill at the top).") return end
        local p = c.profile
        local current = p.rotationContext or "solo"
        local tabs = {}
        for _, key in ipairs(ns.Rotation.CONTEXTS) do
            table.insert(tabs, { label = ns.Rotation.CONTEXT_LABELS[key], active = view == nil and key == current, onClick = function()
                p.rotationContext = key
                view = nil
                ns.Fire("ROTATION_CONTEXT", key)
                UI.Refresh()
            end })
        end
        table.insert(tabs, { label = "Cooldowns", active = view == "cooldowns", onClick = function() view = "cooldowns" UI.Refresh() end })
        table.insert(tabs, { label = "Energy", active = view == "energy", onClick = function() view = "energy" UI.Refresh() end })
        L:Tabs(tabs)
        if view == "cooldowns" then renderCooldowns(L, c) return end
        if view == "energy" then renderEnergy(L, c) return end

        local ctxData = ns.Rotation.Context(c.spec, current)
        if not ctxData then
            L:Flag("No rotation content for this spec and situation yet.")
            return
        end
        if ctxData.unconfirmed then L:Note(c.spec .. " " .. current .. ": " .. ((ctxData.flag ~= "" and ctxData.flag) or "unconfirmed")) end
        for _, s in ipairs(ctxData.sources or {}) do L:Source({ source_url = s }) end

        L:Columns({ 0.6, 0.4 })
        L:Text(UI.Hex(UI.C.dim) .. "Top of the list wins. The on-screen helper lights up the next one. Advice only: you press the buttons.|r", { size = 12 })
        local n, hidden = 0, 0
        for _, step in ipairs(ctxData.priority or {}) do
            local avail = ns.Rotation.Availability(step.spell, c.level, c.race, c.faction)
            if avail then
                n = n + 1
                local sub = whenText(step.when)
                if step.note and step.note ~= "" then sub = (sub ~= "" and (sub .. " - ") or "") .. step.note end
                local chip
                if avail == "trainable" then chip = { text = "Train it", kind = "warn" } end
                L:Spell(ns.Rotation.SpellId(step.spell), ("%d. %s"):format(n, (step.spell:gsub(" %(talent%)", ""))), sub, nil,
                    ns.Rotation.Icon(step.spell), chip and { chip = chip } or nil)
            else
                hidden = hidden + 1
            end
        end
        if n == 0 then L:Text(UI.Hex(UI.C.dim) .. "Nothing in this list is available at your level yet.|r") end
        if hidden > 0 then
            L:Text(UI.Hex(UI.C.dim) .. hidden .. " more step" .. (hidden == 1 and "" or "s") .. " unlock with levels or talents; they'll appear here when you can use them.|r", { size = 12 })
        end

        L:NextColumn()
        local hud = ns.db.char.rotation
        L:Row({ title = "On-screen helper", sub = hud.showInCombatOnly and "Shows in combat only" or "Next-spell icon near your character",
            button = { label = hud.enabled and "On" or "Off", onClick = function()
                hud.enabled = not hud.enabled
                ns.Fire("HUD_TOGGLE")
                UI.Refresh()
            end } })
        if ctxData.summary then
            L:Label("The plan")
            L:Text(ctxData.summary, { size = 12 })
        end
        if ctxData.tips and #ctxData.tips > 0 then
            L:Label("Tips")
            for _, t in ipairs(ctxData.tips) do L:Text("- " .. t, { size = 12 }) end
        end
        L:Label("Last fight")
        local last = ns.Summary.last
        if last then
            L:Text(("%ds · Energy at the end: %s"):format(last.duration, last.energyEnd and tostring(last.energyEnd) or "?"), { size = 12 })
            L:Text(UI.Hex(UI.C.dim) .. ns.Summary.Text(last) .. "|r", { size = 12 })
            for _, t in ipairs(last.tips or {}) do L:Text("- " .. t, { size = 12 }) end
        else
            L:Text(UI.Hex(UI.C.dim) .. "After each fight: casts used and a tip.|r", { size = 12 })
        end
        L:Buttons({ { label = "Energy & combo points", onClick = function() view = "energy" UI.Refresh() end },
            { label = "Poisons", onClick = function() UI.Select("poisons") end } })
        L:EndColumns()
    end,
})
