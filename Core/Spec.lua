-- Spec definitions: names, roles, palette, icons.
local _, ns = ...

ns.SPEC_ORDER = { "Assassination", "Combat", "Subtlety" }

-- Palette: rogue yellow (#FFF569) as the neutral accent; poison green for
-- Assassination, steel/blood red for Combat, shadow violet for Subtlety.
-- Icons are the standard Rogue spec icons (ability icons Blizzard has shipped
-- since Classic); verify they exist in the Forever client.
ns.Specs = {
    Assassination = {
        key = "Assassination", role = "Damage",
        icon = "Interface\\Icons\\Ability_Rogue_Eviscerate",
        accent = { 0.400, 0.780, 0.290 }, accent2 = { 0.600, 0.870, 0.360 },
        tree = "Assassination", weights = "Assassination",
        blurb = "Poisons, Slice and Dice and Rupture, Shank for Venom, and Mutilate with two daggers once the tree reaches row 7. Strong for groups and raids.",
    },
    Combat = {
        key = "Combat", role = "Damage",
        icon = "Interface\\Icons\\Ability_BackStab",
        accent = { 0.850, 0.330, 0.270 }, accent2 = { 0.930, 0.560, 0.300 },
        tree = "Combat", weights = "Combat",
        blurb = "Sinister Strike and Eviscerate with a slow main hand, Riposte at 20, Blade Flurry at 30, Adrenaline Rush at 40. The recommended leveling spec.",
    },
    Subtlety = {
        key = "Subtlety", role = "Damage",
        icon = "Interface\\Icons\\Ability_Stealth",
        accent = { 0.560, 0.450, 0.860 }, accent2 = { 0.420, 0.360, 0.700 },
        tree = "Subtlety", weights = "Subtlety",
        blurb = "Stealth openers, Hemorrhage at 30 and Death Mark at 40, Shank with Boot Knife, Premeditation and Preparation. The solo and PvP alternative.",
    },
}

-- Brief default (Tim may change): level as Combat; at 40 make dual spec
-- Combat (A) + Subtlety (B).
ns.RECOMMENDED_LEVELING_SPEC = "Combat"
ns.RECOMMENDED_DUAL_SPEC = { A = "Combat", B = "Subtlety" }

-- Neutral palette used before a spec is picked (rogue yellow #FFF569).
ns.NeutralAccent = { 1.0, 0.961, 0.412 }
ns.NEUTRAL_ICON = "Interface\\Icons\\Ability_Stealth"

-- Muted gold accent for the Pockets & Locks and Gold screens; poison green for Poisons.
ns.PocketAccent = { 0.855, 0.698, 0.310 }
ns.PoisonAccent = { 0.443, 0.800, 0.333 }
ns.BattleAccent = { 0.780, 0.290, 0.290 }

function ns.SpecAccent(spec)
    local s = ns.Specs[spec or (ns.DB and ns.DB.char and ns.DB.ActiveSpec())]
    return s and s.accent or ns.NeutralAccent
end
