-- Junkboxes, lockboxes and Lockpicking.
--
-- Boxes are matched by item id from research (junkboxes 16882-16885 and the
-- lockboxes with sourced ids) and, for lockboxes without an id, by name.
-- Lock skill values are Classic values (Forever's DB shows placeholders), so
-- every "can I open it?" answer is labelled as such in the UI.
local _, ns = ...

local Locks = {}
ns.Locks = Locks

local function secret(v) return ns.Auras.IsSecret(v) end

-- Bank: -1 (main bank) and the bank bag slots 6-12 (feature-tested; Classic-style
-- ids). Only scanned while the bank is open.
Locks.BANK_BAGS = { -1, 6, 7, 8, 9, 10, 11, 12 }
local bankOpen = false
local bankCounts = {}

local byId, byName
local function index()
    if byId then return end
    byId, byName = {}, {}
    for _, j in ipairs(ns.Data.Junkboxes or {}) do
        local r = { rec = j, kind = "junkbox", name = j.name, item_id = j.item_id, skill = j.lock_skill }
        if j.item_id then byId[j.item_id] = r end
        byName[j.name] = r
    end
    for _, l in ipairs(ns.Data.Lockboxes or {}) do
        local r = { rec = l, kind = "lockbox", name = l.name, item_id = l.item_id, skill = l.lock_skill }
        if l.item_id then byId[l.item_id] = r end
        byName[l.name] = r
    end
end

function Locks.BoxFor(id, name)
    index()
    return (id and byId[id]) or (name and byName[name]) or nil
end

-- Classic skill-up colours for a lock (addon assumption, shown as such):
-- red = can't open, orange < +25, yellow < +50, green < +100, grey beyond.
function Locks.Color(skill, need)
    if skill == nil or need == nil then return "unknown" end
    if skill < need then return "red" end
    local d = skill - need
    if d < 25 then return "orange" end
    if d < 50 then return "yellow" end
    if d < 100 then return "green" end
    return "grey"
end
Locks.COLOR_RGB = {
    red = { 0.95, 0.25, 0.25 }, orange = { 1.0, 0.5, 0.25 }, yellow = { 1.0, 0.85, 0.2 },
    green = { 0.25, 0.85, 0.35 }, grey = { 0.6, 0.6, 0.6 }, unknown = { 0.7, 0.7, 0.75 },
}
Locks.COLOR_TEXT = { red = "can't open yet", orange = "opens, skill-up likely", yellow = "opens, skill-up possible",
    green = "opens, skill-up unlikely", grey = "opens, no skill-up", unknown = "skill unknown" }

function Locks.CanOpen(skill, need)
    if skill == nil or need == nil then return nil end
    return skill >= need
end

-- Boxes in your bags: list of { box, bag, slot, count, link }.
function Locks.InBags()
    local out = {}
    ns.Rogue.EachBagItem(function(bag, slot, id, name, count, link)
        local b = Locks.BoxFor(id, name)
        if b then out[#out + 1] = { box = b, bag = bag, slot = slot, count = count, link = link, id = id } end
    end)
    return out
end

-- Totals by box name: { name = { bags = n, bank = n, box = b } }.
function Locks.Counts()
    local out = {}
    for _, e in ipairs(Locks.InBags()) do
        local t = out[e.box.name] or { bags = 0, bank = 0, box = e.box }
        t.bags = t.bags + e.count
        out[e.box.name] = t
    end
    for name, n in pairs(bankCounts) do
        local t = out[name] or { bags = 0, bank = 0, box = Locks.BoxFor(nil, name) }
        t.bank = n
        out[name] = t
    end
    return out
end

function Locks.ScanBank()
    if not bankOpen then return end
    bankCounts = {}
    ns.Rogue.EachBagItem(function(_, _, id, name, count)
        local b = Locks.BoxFor(id, name)
        if b then bankCounts[b.name] = (bankCounts[b.name] or 0) + count end
    end, Locks.BANK_BAGS)
end

function Locks.SetBankOpen(v)
    bankOpen = v and true or false
    if bankOpen then Locks.ScanBank() end
end

-- The next box the Pick Lock button should open: one you have the skill for
-- (lowest requirement first, junkboxes before lockboxes at the same skill).
function Locks.NextBox(skill)
    local best
    for _, e in ipairs(Locks.InBags()) do
        local need = e.box.skill or 1
        if skill == nil or skill >= need then
            if not best or need < (best.box.skill or 1) or (need == (best.box.skill or 1) and e.box.kind == "junkbox" and best.box.kind ~= "junkbox") then
                best = e
            end
        end
    end
    return best
end

-- Value of one box: research has no contents table for Forever, so the box's
-- own price (Auctionator or vendor) is what we can show.
function Locks.Value(box, link)
    local item = link or box.item_id
    if not item then return nil, nil end
    return ns.Gold.Price(item)
end

-- Next lockpicking route step for a skill and faction.
function Locks.RouteStep(skill, faction)
    local best
    for _, r in ipairs(ns.Data.LockpickRoute or {}) do
        local okF = not r.faction or r.faction == "Both" or not faction or r.faction == faction
        if okF and skill and skill >= (r.skill_from or 0) and skill < (r.skill_to or 300) then
            best = best or r
        end
    end
    return best
end

-- Count an opened box (Pick Lock + open): BAG_UPDATE after a Pick Lock cast.
function Locks.NoteOpened(name)
    local b = ns.db.char.boxes
    b.opened[name] = (b.opened[name] or 0) + 1
    b.openedTotal = (b.openedTotal or 0) + 1
end

-- Lockpicking skill-ups: remember the last value we saw so the screen can list them.
function Locks.TrackSkill()
    local lp = ns.Rogue.Lockpicking()
    if not lp then return nil end
    local h = ns.db.char.lockpick.history
    local last = h[#h]
    if not last or last.rank ~= lp.base then
        h[#h + 1] = { rank = lp.base, t = (rawget(_G, "time") and time()) or 0, zone = ns.Rogue.ZoneName() }
        while #h > 200 do table.remove(h, 1) end
    end
    return lp
end

function Locks.Register()
    local f = ns.EventFrame
    for _, ev in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "SKILL_LINES_CHANGED" }) do
        pcall(f.RegisterEvent, f, ev)
    end
end
