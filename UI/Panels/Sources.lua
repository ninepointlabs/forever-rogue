-- Settings › About the data: client info, research gaps, conflicts, assumptions, sources.
local _, ns = ...
local UI = ns.UI

UI.SettingsSections = UI.SettingsSections or {}

UI.SettingsSections["About the data"] = function(L, c)
    local meta = ns.Data.Meta
    L:Label("Client")
    L:Row({ title = ("Built for %s · Interface %s · project %s"):format(meta.game, tostring(meta.toc_interface), meta.wow_project_id),
        sub = ("Research build %s\nYour client %s (WOW_PROJECT_ID %s)"):format(meta.latest_build_seen,
            table.concat({ GetBuildInfo() }, " / "), tostring(WOW_PROJECT_ID)) })
    L:Note(meta.api_note)

    L:Label("Research gaps (the addon doesn't guess these)")
    for _, g in ipairs(ns.Data.Gaps) do
        L:Row({ chip = { text = "Gap", kind = "warn" }, title = g.gap })
        L:Source(g)
    end
    L:Label("Conflicts between sources")
    for _, cf in ipairs(ns.Data.Conflicts or {}) do
        L:Row({ chip = { text = "Conflict", kind = "info" }, title = cf.topic or "?", sub = cf.detail })
        L:Source(cf)
    end
    L:Label("Addon assumptions")
    L:Row({ title = "Gear scores use rank-derived weights from each spec's stat priority, not simulations." })
    L:Row({ title = "Hit/crit/dodge/parry/block % and weapon DPS are scaled by " .. ns.db.global.percentScale .. " points per 1% or per 1 DPS (Tooltips & bags tab)." })
    L:Row({ title = "Rogues: cloth and leather; daggers, one-handed swords, maces, fist weapons and (conflict) one-handed axes; bows, crossbows, guns, thrown. Off-hand weapons from level " .. ns.Stats.DUAL_WIELD_LEVEL .. " (Dual Wield)." })
    L:Row({ title = "Weapon notes call a main hand 'slow' from " .. ns.Stats.SLOW_SPEED .. " speed (addon threshold; Icy Veins only says 'slow')." })
    L:Row({ title = "Pick Pocket log: an attempt is a Pick Pocket cast followed by a loot window within " .. ns.Pockets.ATTEMPT_WINDOW .. " s; coin = your money after the window closes minus your money at the cast." })
    L:Row({ title = "Pocket refill timer defaults to 10 minutes (a fan-site figure, kickegg); your own repeats on the same mob are measured next to it." })
    L:Row({ title = "Lock colours use Classic skill-up colours (orange < +25, yellow < +50, green < +100, grey beyond); lock values are Classic values." })
    L:Row({ title = "Box values: Auctionator's price when Auctionator is loaded, else the vendor sell price (labelled)." })
    L:Row({ title = "Money is attributed to a source by what window is open when it changes (no combat log, no chat parsing)." })
    L:Row({ title = "Poison detection reads your weapon tooltips for poison names; a stone or oil shows as a separate effect." })
    L:Row({ title = "Tooltip stat parsing reads English item text." })

    L:Label("Sources")
    local keys = {}
    for k in pairs(ns.Data.Sources) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do L:Link(k, ns.Data.Sources[k]) end
end
