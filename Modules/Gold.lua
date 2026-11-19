-- Gold: money formatting, item prices (Auctionator when loaded, else vendor),
-- and v0.1 session tracking with a simple source split.
--
-- Money attribution (no combat log, no chat parsing): every PLAYER_MONEY change
-- is compared with the last known balance and labelled by what is open at that
-- moment:
--   pickpocket  a Pick Pocket loot window (Modules/Pockets.lua)
--   loot        any other loot window
--   merchant    a merchant window (selling, or buying = negative)
--   mail        the mailbox (AH sales/returns arrive by mail)
--   quest       within 3 s of a quest turn-in
--   other       anything else (trade, repair, training ...)
local _, ns = ...

local Gold = {}
ns.Gold = Gold

Gold.SOURCES = { "pickpocket", "loot", "merchant", "mail", "quest", "other" }
Gold.SOURCE_LABELS = { pickpocket = "Pick Pocket coin", loot = "Loot coin", merchant = "Merchant", mail = "Mail (AH)",
    quest = "Quest rewards", other = "Other" }
Gold.MAX_SESSIONS = 30

local function secret(v) return ns.Auras.IsSecret(v) end
local open = { loot = false, merchant = false, mail = false }
local lastQuest = -100
local lastMoney
local session

function Gold.Format(copper, short)
    copper = math.floor(copper or 0)
    local neg = copper < 0
    copper = math.abs(copper)
    local g, s, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
    local out
    if g > 0 then out = short and ("%dg %ds"):format(g, s) or ("%dg %ds %dc"):format(g, s, c)
    elseif s > 0 then out = ("%ds %dc"):format(s, c)
    else out = ("%dc"):format(c) end
    return (neg and "-" or "") .. out
end

----------------------------------------------------------------------------
-- Prices. Tim's decision (2026-11-19): Auctionator's price when Auctionator is
-- installed and loaded (its public API, pcall-guarded), otherwise the vendor
-- sell price from GetItemInfo. Returns copper, label ("AH (Auctionator)" or
-- "Vendor") or nil when neither is known yet.
----------------------------------------------------------------------------
Gold.CALLER_ID = "Forever Rogue"

function Gold.AuctionatorLoaded()
    if not (C_AddOns and C_AddOns.IsAddOnLoaded) then return false end
    local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "Auctionator")
    if not ok or not loaded then return false end
    local A = rawget(_G, "Auctionator")
    return type(A) == "table" and type(A.API) == "table" and type(A.API.v1) == "table"
end

local function itemLinkFor(item)
    if type(item) == "string" and item:find("item:", 1, true) then return item end
    local id = tonumber(item)
    if id and C_Item and C_Item.GetItemInfo then
        local ok, _, link = pcall(C_Item.GetItemInfo, id)
        if ok and link and not secret(link) then return link end
    end
    return id and ("item:" .. id) or nil
end

function Gold.AuctionPrice(item)
    if not Gold.AuctionatorLoaded() then return nil end
    local api = rawget(_G, "Auctionator").API.v1
    local link = itemLinkFor(item)
    if api.GetAuctionPriceByItemLink and link then
        local ok, price = pcall(api.GetAuctionPriceByItemLink, Gold.CALLER_ID, link)
        if ok and type(price) == "number" and price > 0 then return price end
    end
    local id = tonumber(item) or (link and tonumber(tostring(link):match("item:(%d+)")))
    if api.GetAuctionPriceByItemID and id then
        local ok, price = pcall(api.GetAuctionPriceByItemID, Gold.CALLER_ID, id)
        if ok and type(price) == "number" and price > 0 then return price end
    end
    return nil
end

function Gold.VendorPrice(item)
    if not (C_Item and C_Item.GetItemInfo) then return nil end
    local ok, r = pcall(function() return { C_Item.GetItemInfo(item) } end)
    if not ok or not r then return nil end
    local price = r[11]
    if type(price) == "number" and not secret(price) then return price end
    return nil
end

function Gold.Price(item)
    local ah = Gold.AuctionPrice(item)
    if ah then return ah, "AH (Auctionator)" end
    local v = Gold.VendorPrice(item)
    if v then return v, "Vendor" end
    return nil, nil
end

----------------------------------------------------------------------------
-- Session tracking
----------------------------------------------------------------------------
local function money()
    local ok, m = pcall(GetMoney)
    if ok and type(m) == "number" and not secret(m) then return m end
    return nil
end

function Gold.NewSession(t)
    session = { start = t or ((rawget(_G, "time") and time()) or 0), by = {}, gained = 0, spent = 0 }
    for _, k in ipairs(Gold.SOURCES) do session.by[k] = 0 end
    local list = ns.db.char.gold.sessions
    table.insert(list, session)
    while #list > Gold.MAX_SESSIONS do table.remove(list, 1) end
    lastMoney = money()
    return session
end

function Gold.Session() return session end

function Gold.Classify()
    if ns.Pockets.InWindow() then return "pickpocket" end
    if open.loot then return "loot" end
    if open.merchant then return "merchant" end
    if open.mail then return "mail" end
    if GetTime() - lastQuest < 3 then return "quest" end
    return "other"
end

-- Apply one money change (pure enough for tests: pass the new balance).
function Gold.OnMoney(newMoney, source)
    newMoney = newMoney or money()
    if not session then Gold.NewSession() end
    if newMoney == nil or lastMoney == nil then lastMoney = newMoney return nil end
    local delta = newMoney - lastMoney
    lastMoney = newMoney
    if delta == 0 then return nil end
    source = source or Gold.Classify()
    session.by[source] = (session.by[source] or 0) + delta
    if delta > 0 then session.gained = session.gained + delta else session.spent = session.spent - delta end
    return source, delta
end

function Gold.SetOpen(kind, v) open[kind] = v and true or false end
function Gold.QuestTurnedIn() lastQuest = GetTime() end

-- Copper per hour this session (net gained), or nil before a minute has passed.
function Gold.PerHour(t)
    if not session then return nil end
    local secs = (t or ((rawget(_G, "time") and time()) or 0)) - session.start
    if secs < 60 then return nil end
    return (session.gained - session.spent) / (secs / 3600)
end

-- Farm spots for a level and faction from research (§7.8).
function Gold.Farms(level, faction)
    local out = {}
    for _, f in ipairs(ns.Data.GoldFarms or {}) do
        local okFaction = not f.faction or f.faction == "Both" or not faction or f.faction == faction
        if okFaction and (not level or ((f.level_min or 1) <= level + 5 and (f.level_max or 60) >= level - 5)) then
            out[#out + 1] = f
        end
    end
    table.sort(out, function(a, b) return (a.level_min or 0) < (b.level_min or 0) end)
    return out
end

function Gold.Register()
    local f = ns.EventFrame
    for _, ev in ipairs({ "PLAYER_MONEY", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "QUEST_TURNED_IN" }) do
        pcall(f.RegisterEvent, f, ev)
    end
    Gold.NewSession()
end
