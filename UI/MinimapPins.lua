-- Minimap pins for pickpocket spots (Modules/PocketPins.lua decides what and
-- where). Plain textures on the Minimap: no secure frames, nothing clickable
-- that acts; hover shows what the spot is. Updated a few times a second while
-- shown; hidden in instances, when the setting is off, or when your position
-- isn't readable.
local _, ns = ...
local UI = ns.UI

local MP = {}
ns.MinimapPins = MP

MP.UPDATE_EVERY = 0.2
MP.ICON = { research = "Interface\\Icons\\INV_Misc_Bag_11", mine = "Interface\\Icons\\INV_Misc_Coin_02" }

local holder, pins, elapsed = nil, {}, 0
local spots, spotsMap, spotsLevel

local function pin(i)
    if pins[i] then return pins[i] end
    local p = CreateFrame("Frame", nil, holder)
    p:SetSize(14, 14)
    p.tex = p:CreateTexture(nil, "OVERLAY")
    p.tex:SetAllPoints()
    p.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p:EnableMouse(true)
    p:SetScript("OnEnter", function(s)
        if not s.spot then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.spot.title or "Pickpocket spot", 1, 0.96, 0.41)
        if s.spot.sub and s.spot.sub ~= "" then GameTooltip:AddLine(s.spot.sub, 0.9, 0.9, 0.9, true) end
        GameTooltip:AddLine(s.spot.kind == "mine" and "From your Pick Pocket log." or "From the research (fan guide / GoldScout community data; unconfirmed).", 0.6, 0.6, 0.6, true)
        if s.dist then GameTooltip:AddLine(("%d yards away"):format(s.dist), 0.6, 0.6, 0.6) end
        GameTooltip:AddLine(ns.TITLE .. " · /frogue pins to turn off", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pins[i] = p
    return p
end

local function hideFrom(i)
    for j = i, #pins do pins[j]:Hide() end
end

local function zoomAndIndoor()
    local zoom = 0
    if Minimap and Minimap.GetZoom then
        local ok, z = pcall(Minimap.GetZoom, Minimap)
        if ok and type(z) == "number" then zoom = z end
    end
    local indoor = false
    local fn = rawget(_G, "IsIndoors")
    if fn then
        local ok, v = pcall(fn)
        indoor = ok and v and true or false
    end
    return zoom, indoor
end

local function facing()
    local rotates = GetCVarBool and GetCVarBool("rotateMinimap")
    if not rotates then return nil end
    local fn = rawget(_G, "GetPlayerFacing")
    if not fn then return nil end
    local ok, f = pcall(fn)
    if ok and type(f) == "number" and not ns.Auras.IsSecret(f) then return f end
    return nil
end

-- One placement pass. Returns the number of pins shown (tests read it).
function MP.Update()
    local cfg = ns.db and ns.db.char.pocketPins
    if not holder or not cfg or not cfg.enabled then hideFrom(1) return 0 end
    local mapID, px, py = ns.PocketPins.PlayerPosition()
    if not mapID then hideFrom(1) return 0 end
    local size = ns.PocketPins.MapYards(mapID)
    if not size then hideFrom(1) return 0 end
    local level = UnitLevel("player")
    if spotsMap ~= mapID or spotsLevel ~= level or not spots then
        spots, spotsMap, spotsLevel = ns.PocketPins.SpotsFor(mapID, level, px, py, cfg), mapID, level
    end
    local zoom, indoor = zoomAndIndoor()
    local radius = ns.PocketPins.MinimapRadiusYards(zoom, indoor)
    local half = (Minimap:GetWidth() or 140) / 2
    local face = facing()
    local n = 0
    for _, s in ipairs(spots) do
        local ox, oy, dist, inside = ns.PocketPins.Offset(px, py, s.x, s.y, size, radius, half, face)
        n = n + 1
        local p = pin(n)
        p.spot, p.dist = s, math.floor(dist)
        p.tex:SetTexture(MP.ICON[s.kind] or MP.ICON.research)
        p:SetAlpha(inside and 1 or 0.45)
        p:ClearAllPoints()
        p:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
        p:Show()
    end
    hideFrom(n + 1)
    return n
end

-- Spot lists change on zone, level and new log entries.
function MP.Invalidate() spots = nil end

function MP.Refresh()
    if not holder then
        holder = CreateFrame("Frame", "ForeverRoguePinHolder", Minimap)
        holder:SetAllPoints(Minimap)
        holder:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 1) + 5)
        holder:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + (dt or 0)
            if elapsed < MP.UPDATE_EVERY then return end
            elapsed = 0
            pcall(MP.Update)
        end)
    end
    MP.Invalidate()
    local on = ns.db.char.pocketPins.enabled
    holder:SetShown(on)
    return MP.Update()
end

function MP.Toggle(v)
    local cfg = ns.db.char.pocketPins
    if v == nil then v = not cfg.enabled end
    cfg.enabled = v and true or false
    MP.Refresh()
    ns.Print("Pickpocket spots on the minimap " .. (cfg.enabled and "on" or "off") .. ".")
end
