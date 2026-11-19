-- Pickpocket spots on the minimap: which spots to show and where they go.
--
-- Spots come from two places, and nothing is guessed:
--   * research: pickpocket targets and GoldScout junkbox hotspots that carry
--     sourced coordinates (zone + x/y in 0-100 map units, as the guides print
--     them), filtered to your level range;
--   * your own log: where you stood when a pickpocket gave loot (open world
--     only; inside instances the game doesn't give addons your position).
--
-- Placement uses only Blizzard map APIs: C_Map.GetBestMapForUnit and
-- GetPlayerMapPosition for you, C_Map.GetWorldPosFromMapPos to turn the zone's
-- 0-1 map units into yards, and the minimap's zoom level. The yards-per-zoom
-- table is the client's fixed minimap scale (the same constants
-- HereBeDragons-Pins uses); verify on Forever.
local _, ns = ...

local Pins = {}
ns.PocketPins = Pins

Pins.MAX_PINS = 25
Pins.LEVEL_BELOW, Pins.LEVEL_ABOVE = 10, 5 -- research spots within this range of your level
Pins.OWN_SPOTS_PER_MOB = 8

-- Minimap diameter in yards per zoom level (0 = most zoomed out).
Pins.MINIMAP_YARDS = {
    outdoor = { [0] = 466 + 2 / 3, [1] = 400, [2] = 333 + 1 / 3, [3] = 266 + 2 / 3, [4] = 200, [5] = 133 + 1 / 3 },
    indoor = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
}

local function secret(v) return ns.Auras.IsSecret(v) end

----------------------------------------------------------------------------
-- Positions
----------------------------------------------------------------------------
-- Your map and 0-1 position, or nil (instances, secret values, missing API).
function Pins.PlayerPosition()
    if ns.Rogue.InInstance() then return nil end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not mapID or secret(mapID) then return nil end
    local ok2, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok2 or not pos or secret(pos) then return nil end
    local x, y = pos:GetXY()
    if not x or not y or secret(x) or secret(y) or (x == 0 and y == 0) then return nil end
    return mapID, x, y
end

-- Size of a map in yards: { w, h } from two corners (axis-agnostic distances).
local sizeCache = {}
function Pins.MapYards(mapID)
    if sizeCache[mapID] ~= nil then return sizeCache[mapID] or nil end
    local result = false
    if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local function world(x, y)
            local ok, _, wp = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
            if ok and wp then return wp:GetXY() end
        end
        local ax, ay = world(0, 0)
        local bx, by = world(1, 0)
        local cx, cy = world(0, 1)
        if ax and bx and cx then
            local w = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
            local h = math.sqrt((cx - ax) ^ 2 + (cy - ay) ^ 2)
            if w > 0 and h > 0 then result = { w = w, h = h } end
        end
    end
    sizeCache[mapID] = result
    return result or nil
end

function Pins.MinimapRadiusYards(zoom, indoor)
    local t = Pins.MINIMAP_YARDS[indoor and "indoor" or "outdoor"]
    return (t[zoom or 0] or t[0]) / 2
end

-- Pure placement: player and spot in 0-1 map units on the same map; returns the
-- pixel offset from the minimap centre, the distance in yards and whether the
-- spot is inside the minimap circle. facing = radians when the minimap rotates.
function Pins.Offset(px, py, sx, sy, size, radiusYards, halfPixels, facing)
    local dx = (sx - px) * size.w
    local dy = (sy - py) * size.h -- map y grows downward
    if facing then
        local c, s = math.cos(facing), math.sin(facing)
        dx, dy = dx * c - dy * s, dx * s + dy * c
    end
    local dist = math.sqrt(dx * dx + dy * dy)
    local scale = halfPixels / radiusYards
    local ox, oy = dx * scale, -dy * scale
    local inside = dist <= radiusYards
    if not inside and dist > 0 then
        -- clamp to the edge so far-off spots still point the way
        local k = radiusYards / dist
        ox, oy = ox * k, oy * k
    end
    return ox, oy, dist, inside
end

----------------------------------------------------------------------------
-- Spots
----------------------------------------------------------------------------
local function coords(c)
    if type(c) == "table" and tonumber(c[1]) and tonumber(c[2]) then return tonumber(c[1]) / 100, tonumber(c[2]) / 100 end
    return nil
end

-- Research spots with coordinates: { zone, x, y, title, sub, kind = "research", rec, level_min, level_max }.
function Pins.ResearchSpots()
    local out = {}
    for _, t in ipairs(ns.Data.PickpocketTargets or {}) do
        local x, y = coords(t.coords)
        if x and t.zone then
            out[#out + 1] = { zone = t.zone, x = x, y = y, title = t.mob, kind = "research", rec = t,
                level_min = t.level_min, level_max = t.level_max,
                sub = (t.junkbox and (t.junkbox .. " Junkbox · ") or "") .. (t.level_min and ("levels " .. t.level_min .. "-" .. (t.level_max or t.level_min)) or "") }
        end
    end
    for _, j in ipairs(ns.Data.Junkboxes or {}) do
        for _, h in ipairs(j.goldscout_map_hotspots or {}) do
            local x, y = coords(h.coords)
            if x and h.zone then
                local lo, hi = tostring(j.mob_level_range or ""):match("(%d+)%D+(%d+)")
                out[#out + 1] = { zone = h.zone, x = x, y = y, title = j.name .. " hotspot (GoldScout)", kind = "research", rec = h,
                    level_min = tonumber(lo), level_max = tonumber(hi),
                    sub = "Most " .. j.name .. "es reported around here (kills and pickpockets, community data)" }
            end
        end
    end
    return out
end

function Pins.LevelOk(s, level)
    if not level or not s.level_min then return true end
    return s.level_min <= level + Pins.LEVEL_ABOVE and (s.level_max or s.level_min) >= level - Pins.LEVEL_BELOW
end

-- Your own spots on a map: { x, y, title, sub, kind = "mine" } from the per-mob spot lists.
function Pins.OwnSpots(mapID)
    local out = {}
    for mob, m in pairs(ns.db.char.pockets.byMob) do
        for _, s in ipairs(m.spots or {}) do
            if s.map == mapID then
                out[#out + 1] = { x = s.x, y = s.y, title = mob, kind = "mine",
                    sub = ("You: %d pickpockets, %s each"):format(m.n, ns.Gold.Format(ns.Pockets.CopperPer(m) or 0, true)) }
            end
        end
    end
    return out
end

-- Everything to pin on mapID for this level, nearest first, capped.
function Pins.SpotsFor(mapID, level, px, py, cfg)
    cfg = cfg or ns.db.char.pocketPins
    local out = {}
    if cfg.research then
        for _, s in ipairs(Pins.ResearchSpots()) do
            if Pins.LevelOk(s, level) and ns.Map.FindZone(s.zone) == mapID then out[#out + 1] = s end
        end
    end
    if cfg.mine then
        for _, s in ipairs(Pins.OwnSpots(mapID)) do out[#out + 1] = s end
    end
    if px and py then
        table.sort(out, function(a, b)
            return (a.x - px) ^ 2 + (a.y - py) ^ 2 < (b.x - px) ^ 2 + (b.y - py) ^ 2
        end)
    end
    for i = #out, Pins.MAX_PINS + 1, -1 do out[i] = nil end
    return out
end

-- Remember where a pickpocket happened (called by Pockets with the entry).
function Pins.RememberSpot(e)
    if not (e.map and e.x and e.y and e.mob) then return end
    local m = ns.db.char.pockets.byMob[e.mob]
    if not m then return end
    m.spots = m.spots or {}
    for _, s in ipairs(m.spots) do
        -- one spot per ~2% of the map is enough
        if s.map == e.map and math.abs(s.x - e.x) < 0.02 and math.abs(s.y - e.y) < 0.02 then return end
    end
    table.insert(m.spots, { map = e.map, x = e.x, y = e.y })
    while #m.spots > Pins.OWN_SPOTS_PER_MOB do table.remove(m.spots, 1) end
end
