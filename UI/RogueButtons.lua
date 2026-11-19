-- The Rogue bar's buttons and cells.
--
-- Secure buttons (they act, one press = one action, out of combat only):
--   * Pick Lock: "/cast Pick Lock" + "/use <bag> <slot>" of the next junkbox or
--     lockbox you have the skill for (the macro pattern players use; verify on
--     Forever). Disarmed when there's no box you can open.
--   * Poison MH / OH: "/use <poison>" + "/use 16" (main hand) or "/use 17" (off
--     hand), the best rank of the poison you carry. Disarmed while the right
--     poison is on with 5+ minutes left. Shown only once poisons are unlocked.
-- Plain cells (never act): reagents & tools, and the session pocket counter.
--
-- Blizzard rules this follows: every action needs your click or key press;
-- attributes only change out of combat (in combat a button keeps what it had);
-- the button's own macrotext, no player macros, no /click, no Bindings.xml;
-- keys are optional override bindings, none by default, never Super/Meta.
local _, ns = ...
local UI = ns.UI
local Bar = ns.RogueBar

local Buttons = {}
ns.RogueButtons = Buttons
Buttons.defs = {}
Buttons.byKey = {}

local function knows(n) return ns.Progress.Knows(n) end

----------------------------------------------------------------------------
-- View models (pure functions of state; tests call them)
----------------------------------------------------------------------------

-- Pick Lock. skill = { rank, max } or nil/false; nextBox = Locks.NextBox entry; total = boxes in bags.
function Buttons.PickLockView(skill, nextBox, total, hasTools)
    local v = { lines = {}, icon = "Interface\\Icons\\Spell_Nature_MoonKey" }
    local rank = type(skill) == "table" and skill.rank or nil
    v.stock = UI.Hex(UI.C.dim) .. (rank and (rank .. "/" .. (skill.max or "?")) or "skill ?") .. "|r"
    if hasTools == false then
        table.insert(v.lines, "No Thieves' Tools in your bags: Pick Lock needs them.")
    end
    if not nextBox then
        v.status, v.active = UI.Hex(UI.C.dim) .. ((total or 0) > 0 and "too hard" or "no box") .. "|r", false
        if (total or 0) > 0 then table.insert(v.lines, "You carry boxes, but none you have the Lockpicking skill for yet.") end
        return v
    end
    local name = nextBox.box.name
    v.macro = ("/cast Pick Lock\n/use %d %d"):format(nextBox.bag, nextBox.slot)
    v.status, v.active = UI.Hex(UI.C.good) .. (total or 1) .. (total == 1 and " box" or " boxes") .. "|r", true
    v.title = "Pick Lock: " .. name
    table.insert(v.lines, "Next: " .. name .. " (needs " .. tostring(nextBox.box.skill or "?") .. ", Classic value).")
    table.insert(v.lines, "Press once to pick the lock, then right-click the box to open it.")
    return v
end

-- Poison button for a hand. want = item name to apply; on = OnWeapons()[hand]; stockN = count in bags.
function Buttons.PoisonView(hand, want, base, on, stockN)
    local v = { lines = {}, icon = "Interface\\Icons\\Ability_Poisons", hand = hand }
    local label = hand == "mh" and "MH" or "OH"
    if not want then
        v.status, v.active = UI.Hex(UI.C.dim) .. label .. " none|r", false
        table.insert(v.lines, "No poison in your bags.")
        return v
    end
    v.stock = UI.Hex(UI.C.dim) .. (base or want):gsub(" Poison", "") .. " x" .. (stockN or 0) .. "|r"
    v.title = ns.Poisons.HAND_LABEL[hand] .. " poison: " .. want
    if on == "noweapon" then
        v.status, v.active = UI.Hex(UI.C.dim) .. label .. " no weapon|r", false
        return v
    end
    if on == nil then
        v.status, v.active, v.macro = UI.Hex(UI.C.dim) .. label .. " hidden|r", true, ns.Poisons.Macro(want, hand)
        table.insert(v.lines, "Can't read your weapon right now; the button still applies " .. want .. ".")
        return v
    end
    local ok = ns.Poisons.HandOk(on, base)
    if ok then
        v.status, v.active, v.applied = UI.Hex(UI.C.good) .. label .. " " .. ns.Poisons.FormatLeft(on.left) .. "|r", false, true
        table.insert(v.lines, (on.name or want) .. " is on" .. (on.charges and (" (" .. on.charges .. " charges)") or "") .. ", so the button won't use another. It lights up again under 5 minutes.")
        if on.stone then table.insert(v.lines, "Also on this weapon: " .. on.stone .. " (Forever lets a stone and a poison share a weapon).") end
        return v
    end
    v.macro = ns.Poisons.Macro(want, hand)
    v.active = true
    if on == false then
        v.status = UI.Hex(UI.C.warn) .. label .. " none|r"
    elseif on.base and base and on.base ~= base then
        v.status = UI.Hex(UI.C.warn) .. label .. " " .. on.base:gsub(" Poison", "") .. "|r"
        table.insert(v.lines, "On your weapon: " .. (on.name or on.base) .. ". Suggested: " .. want .. ".")
    elseif not on.base then
        v.status = UI.Hex(UI.C.warn) .. label .. " stone|r"
        table.insert(v.lines, "Only a stone/oil on this weapon (" .. tostring(on.stone or "temporary enchant") .. "). Forever lets a poison sit next to it.")
    else
        v.status = UI.Hex(UI.C.warn) .. label .. " " .. ns.Poisons.FormatLeft(on.left) .. "|r"
        table.insert(v.lines, "Running out: press to refresh.")
    end
    return v
end

----------------------------------------------------------------------------
-- Generic secure button cell
----------------------------------------------------------------------------
local function makeButton(def)
    local cell = Bar.Cell(def.key, def.order)
    local btn = CreateFrame("Button", def.name, cell, "SecureActionButtonTemplate, BackdropTemplate")
    Bar.Decorate(btn, cell, def.icon)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("useOnKeyDown", false)
    btn.def, btn.cell = def, cell
    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText((s.view and s.view.title) or def.label, 1, 0.82, 0)
        for _, l in ipairs(s.view and s.view.lines or {}) do GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true) end
        if s:GetAttribute("type") then
            local key = ns.db.char[def.cfg].key
            GameTooltip:AddLine("Click or press " .. (key or "your key (Settings > Rogue bar)") .. ": one action per press, out of combat.", 0.6, 0.6, 0.6, true)
        end
        if InCombatLockdown() then GameTooltip:AddLine("In combat the button keeps what it had until combat ends.", 1, 0.5, 0.3, true) end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:HookScript("PostClick", function(_, _, down)
        if down then return end
        C_Timer.After(0.5, function() pcall(Buttons.Update) end)
    end)
    def.btn = btn
    return btn
end

local function apply(def)
    local btn = def.btn
    if not btn then return end
    local v = def.view()
    btn.view = v
    btn.status:SetText(v.status or "")
    btn.stock:SetText(v.stock or "")
    if InCombatLockdown() then
        Bar.SetLook(btn, v.active)
        return
    end
    if v.macro and not v.applied then
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", v.macro)
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
    end
    if v.icon then btn.icon:SetTexture(v.icon) end
    Bar.SetLook(btn, v.active)
end

local function addDef(def)
    table.insert(Buttons.defs, def)
    Buttons.byKey[def.key] = def
end

addDef({
    key = "picklock", order = 1, name = "ForeverRoguePickLockButton", cfg = "pickLock", label = "Pick Lock",
    icon = "Interface\\Icons\\Spell_Nature_MoonKey",
    shouldShow = function() return ns.db.char.pickLock.enabled and knows("Pick Lock") end,
    view = function()
        local skill = ns.Rogue.Lockpicking()
        local boxes = ns.Locks.InBags()
        local total = 0
        for _, e in ipairs(boxes) do total = total + e.count end
        return Buttons.PickLockView(skill, ns.Locks.NextBox(type(skill) == "table" and skill.rank or nil), total, ns.Rogue.HasThievesTools())
    end,
})

local function poisonDef(hand, order)
    local cfgKey = hand == "mh" and "poisonMH" or "poisonOH"
    addDef({
        key = "poison" .. hand, order = order, name = hand == "mh" and "ForeverRoguePoisonMHButton" or "ForeverRoguePoisonOHButton",
        cfg = cfgKey, label = ns.Poisons.HAND_LABEL[hand] .. " poison", icon = "Interface\\Icons\\Ability_Poisons",
        shouldShow = function()
            if not ns.db.char[cfgKey].enabled then return false end
            if hand == "oh" and (UnitLevel("player") or 1) < ns.Stats.DUAL_WIELD_LEVEL then return false end
            return ns.Poisons.Unlocked() == true
        end,
        view = function()
            local stock = ns.Poisons.Stock()
            local want, base = ns.Poisons.ForHand(hand, ns.DB.ActiveSpec(), stock)
            local on = ns.Poisons.OnWeapons()
            return Buttons.PoisonView(hand, want, base, on and on[hand], base and stock[base] and stock[base].total or 0)
        end,
    })
end
poisonDef("mh", 2)
poisonDef("oh", 3)

----------------------------------------------------------------------------
-- Plain cells: reagents & tools, pocket counter
----------------------------------------------------------------------------
local reagentCell, counterCell

function Buttons.ReagentLines()
    local out = {}
    for _, s in ipairs(ns.Rogue.Supplies()) do
        if s.needed then
            local short = s.name:gsub(" Powder", ""):gsub("Thieves' Tools", "Tools")
            out[#out + 1] = (s.count > 0 and UI.Hex(UI.C.good) or UI.Hex(UI.C.warn)) .. short .. " " .. s.count .. "|r"
        end
    end
    return out
end

local function buildPlainCells()
    if reagentCell then return end
    reagentCell = Bar.Cell("reagents", 4)
    reagentCell.text = UI.Text(reagentCell, 10)
    reagentCell.text:SetPoint("TOP", 0, -2)
    reagentCell.text:SetWidth(Bar.CELL_W - 4)
    reagentCell.text:SetJustifyH("CENTER")
    counterCell = Bar.Cell("pockets", 5)
    counterCell.text = UI.Text(counterCell, 10)
    counterCell.text:SetPoint("TOP", 0, -2)
    counterCell.text:SetWidth(Bar.CELL_W - 4)
    counterCell.text:SetJustifyH("CENTER")
end

function Buttons.UpdatePlain()
    buildPlainCells()
    local lines = Buttons.ReagentLines()
    reagentCell.text:SetText(#lines > 0 and table.concat(lines, "\n") or "")
    local s = ns.db.char.pockets.totals.session
    counterCell.text:SetText(UI.Hex(ns.PocketAccent) .. "Pockets|r\n" .. s.n .. "\n" .. ns.Gold.Format(s.copper, true))
    return lines
end

----------------------------------------------------------------------------
-- Refresh / update / keys
----------------------------------------------------------------------------
function Buttons.Build()
    for _, def in ipairs(Buttons.defs) do
        if not def.btn then makeButton(def) end
    end
    buildPlainCells()
end

function Buttons.Update()
    for _, def in ipairs(Buttons.defs) do
        if def.btn and def.btn.cell.want then pcall(apply, def) end
    end
    pcall(Buttons.UpdatePlain)
end

local ticker
-- Show/hide cells and re-aim the buttons (out of combat only).
function Buttons.Refresh()
    if InCombatLockdown() then return end
    Buttons.Build()
    local any = false
    for _, def in ipairs(Buttons.defs) do
        local ok, show = pcall(def.shouldShow)
        def.btn.cell.want = ok and show and true or false
        any = any or def.btn.cell.want
        Buttons.ApplyKey(def.key)
    end
    local lines = Buttons.UpdatePlain()
    reagentCell.want = ns.db.char.reagentCells.enabled and #lines > 0
    counterCell.want = ns.db.char.pocketCounter.enabled and knows("Pick Pocket")
    Bar.Layout()
    any = any or reagentCell.want or counterCell.want
    if any and not ticker then
        ticker = C_Timer.NewTicker(1, function() pcall(Buttons.Update) end)
    elseif not any and ticker then
        ticker:Cancel()
        ticker = nil
    end
    Buttons.Update()
end

function Buttons.ApplyKey(key)
    local def = Buttons.byKey[key]
    if not def or not def.btn then return end
    Bar.ApplyKey(def.btn, def.name, ns.db.char[def.cfg].key)
end

function Buttons.SetKey(key, bind)
    if InCombatLockdown() then ns.Print("Can't change key bindings in combat.") return end
    local def = Buttons.byKey[key]
    if not def then return end
    Buttons.Build()
    ns.db.char[def.cfg].key = bind
    Buttons.ApplyKey(key)
    ns.Print(bind and (def.label .. " button bound to " .. bind .. ".") or (def.label .. " button key cleared."))
    ns.Fire("KEY_CHANGED")
end

function Buttons.StartKeyCapture(key)
    local def = Buttons.byKey[key]
    if not def then return end
    Bar.CaptureKey(def.label:lower() .. " button", function(k) Buttons.SetKey(key, k) end)
end

-- /frogue bar debug
function Buttons.Debug()
    Buttons.Build()
    ns.Print("Rogue bar debug:")
    for _, def in ipairs(Buttons.defs) do
        local b = def.btn
        print(("  %s shown=%s type=%s macrotext=%s key=%s"):format(def.key, tostring(b.cell:IsShown()), tostring(b:GetAttribute("type")),
            tostring(b:GetAttribute("macrotext")):gsub("\n", " | "), tostring(ns.db.char[def.cfg].key)))
    end
end
