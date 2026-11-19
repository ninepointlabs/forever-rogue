-- Poisons: what is on each weapon, stock in bags, which poison each hand
-- should carry, and the macro text for the two poison buttons.
--
-- Forever lets a poison and a sharpening stone / weightstone sit on the same
-- weapon (Blizzard deep dive; not yet in client data per wowfdb), so a weapon
-- can carry two temporary effects. GetWeaponEnchantInfo reports one expiry and
-- one charge count per hand; the weapon tooltip is read line by line to name
-- every effect it shows. Anything unreadable is "hidden", never guessed.
local _, ns = ...

local Poisons = {}
ns.Poisons = Poisons

Poisons.SLOTS = { mh = 16, oh = 17 }
Poisons.HAND_LABEL = { mh = "Main hand", oh = "Off hand" }
-- Temp-enchant words on weapon tooltips (sharpening stones / weightstones / oils).
Poisons.STONE_WORDS = { "Sharpened", "Weighted", "Sharpening", "Weightstone", "Oil" }
Poisons.LOW_SECONDS = 300 -- buttons re-arm and reminders fire under 5 minutes left

local function secret(v) return ns.Auras.IsSecret(v) end

-- Base poison names from research (Instant Poison, Deadly Poison, ...).
local bases
function Poisons.Bases()
    if bases then return bases end
    bases = {}
    local seen = {}
    for _, p in ipairs(ns.Data.Poisons or {}) do
        local b = p.base or (p.name or ""):gsub("%s+[IVX]+$", "")
        if b ~= "" and not seen[b] then
            seen[b] = true
            bases[#bases + 1] = b
        end
    end
    return bases
end

-- "Instant Poison III" -> "Instant Poison", 3; nil for anything else.
local ROMAN = { I = 1, II = 2, III = 3, IV = 4, V = 5, VI = 6, VII = 7 }
function Poisons.Parse(name)
    if not name then return nil end
    for _, b in ipairs(Poisons.Bases()) do
        if name == b then return b, 1 end
        local r = name:match("^" .. b:gsub("%-", "%%-") .. " ([IVX]+)$")
        if r and ROMAN[r] then return b, ROMAN[r] end
    end
    return nil
end

-- Name the effects in a weapon tooltip: poison (first match) and stone.
function Poisons.FromLines(lines)
    local poison, stone
    for _, l in ipairs(lines or {}) do
        if type(l) == "string" then
            if not poison then
                for _, b in ipairs(Poisons.Bases()) do
                    local s = l:find(b, 1, true)
                    if s then
                        poison = l:match("(" .. b:gsub("%-", "%%-") .. "%s*[IVX]*)") or b
                        poison = poison:gsub("%s+$", "")
                        break
                    end
                end
            end
            if not stone then
                for _, w in ipairs(Poisons.STONE_WORDS) do
                    if l:find(w, 1, true) and not l:find("Poison", 1, true) then stone = l break end
                end
            end
        end
    end
    return poison, stone
end

local function tooltipLines(slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
    if not ok or secret(data) then return nil end
    if not data or not data.lines then return {} end
    local out = {}
    for i, line in ipairs(data.lines) do
        local t = line.leftText
        if t and not secret(t) then out[i] = t end
    end
    return out
end
Poisons.TooltipLines = tooltipLines

local function hasWeapon(slot)
    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    if not ok or secret(link) then return nil end
    return link ~= nil
end

-- { mh = false | { name?, base?, rank?, left?, charges?, stone? } | "noweapon", oh = ... }
-- or nil when the client hides your weapon state.
function Poisons.OnWeapons()
    if not GetWeaponEnchantInfo then return nil end
    local ok, r = pcall(function() return { GetWeaponEnchantInfo() } end)
    if not ok or not r or secret(r[1]) then return nil end
    local out = {}
    for hand, slot in pairs(Poisons.SLOTS) do
        local i = hand == "mh" and 1 or 5
        local has, ms, charges = r[i], r[i + 1], r[i + 2]
        local weapon = hasWeapon(slot)
        local lines = tooltipLines(slot)
        if lines == nil then return nil end
        local pname, stone = Poisons.FromLines(lines)
        if weapon == false then
            out[hand] = "noweapon"
        elseif not has and not pname and not stone then
            out[hand] = false
        else
            local base, rank = Poisons.Parse(pname)
            local e = { name = pname, base = base, rank = rank, stone = stone }
            if has and type(ms) == "number" and not secret(ms) then e.left = math.floor(ms / 1000) end
            if has and type(charges) == "number" and not secret(charges) and charges > 0 then e.charges = charges end
            out[hand] = e
        end
    end
    return out
end

-- Poison items in bags: { [base] = { total = n, best = "Instant Poison III", bestRank = 3, ranks = { [name] = n } } }
function Poisons.Stock()
    local out = {}
    ns.Rogue.EachBagItem(function(_, _, _, name, count)
        local base, rank = Poisons.Parse(name)
        if base then
            local s = out[base] or { total = 0, ranks = {} }
            s.total = s.total + count
            s.ranks[name] = (s.ranks[name] or 0) + count
            if not s.bestRank or rank > s.bestRank then s.best, s.bestRank = name, rank end
            out[base] = s
        end
    end)
    return out
end

-- Has the character unlocked poisons? Poisons skill line, else any poison in
-- bags; nil when unknown.
function Poisons.Unlocked()
    local sk = ns.Rogue.PoisonsSkill()
    if sk then return true end
    for _ in pairs(Poisons.Stock()) do return true end
    if sk == false then return false end
    return nil
end

-- Sourced suggestion for a spec and hand (poison_rules.suggested).
function Poisons.Suggested(spec, hand)
    local rules = ns.Data.PoisonRules
    for _, s in ipairs(rules and rules.suggested or {}) do
        if s.spec == spec or s.spec == "Any" or s.spec == "All" then
            local v = hand == "mh" and s.main_hand or s.off_hand
            if v then
                v = v:gsub("%s*%b()", "")
                return v, s
            end
        end
    end
    return nil
end

-- What the button for a hand should apply: the pinned poison, the suggested
-- one if you have it, else whatever poison you carry (most stock first).
-- Returns item name (best rank in bags) and base, or nil.
function Poisons.ForHand(hand, spec, stock)
    stock = stock or Poisons.Stock()
    local cfg = ns.db.char[hand == "mh" and "poisonMH" or "poisonOH"]
    local want = cfg and cfg.override or Poisons.Suggested(spec, hand)
    if want then
        local base = Poisons.Parse(want) or want
        if stock[base] then return stock[base].best, base end
    end
    local bestBase, bestN
    for base, s in pairs(stock) do
        if not bestN or s.total > bestN or (s.total == bestN and base < bestBase) then bestBase, bestN = base, s.total end
    end
    if bestBase then return stock[bestBase].best, bestBase end
    return nil
end

function Poisons.Macro(itemName, hand)
    if not itemName then return nil end
    return ("/use %s\n/use %d"):format(itemName, Poisons.SLOTS[hand])
end

-- Is this hand's poison fine (on, right base, enough time)? true/false/nil.
function Poisons.HandOk(on, base)
    if on == nil then return nil end
    if on == "noweapon" then return true end
    if on == false then return false end
    if base and on.base and on.base ~= base then return false end
    if on.left and on.left < Poisons.LOW_SECONDS then return false end
    if not on.base then return false end -- only a stone/oil (or an effect we can't name): a poison still fits
    return true
end

function Poisons.FormatLeft(sec)
    if not sec then return "" end
    if sec >= 60 then return math.floor(sec / 60) .. "m" end
    return sec .. "s"
end
