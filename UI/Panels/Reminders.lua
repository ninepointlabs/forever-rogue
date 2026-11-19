-- Settings › Reminders: live status + what to remind about.
local _, ns = ...
local UI = ns.UI

UI.SettingsSections = UI.SettingsSections or {}

UI.SettingsSections.Reminders = function(L, c)
    local cfg = ns.db.char.reminders
    L:Columns({ 0.5, 0.5 })
    L:Label("Right now")
    local list = ns.Reminders.Evaluate()
    if #list == 0 then L:Text(UI.Hex(UI.C.dim) .. "Nothing to check yet at your level.|r") end
    for _, r in ipairs(list) do
        local chip = r.ok and { text = "OK", kind = "good" } or { text = r.id == "classQuest" and "Open" or "Missing", kind = "warn" }
        L:Row({ chip = chip, title = r.label, sub = r.detail })
    end
    L:Text(UI.Hex(UI.C.dim) .. "Checked out of combat; missing items pop up on screen (also /frogue remind).|r", { size = 12 })
    L:NextColumn()
    L:Label("Remind me about")
    local function check(label, key)
        L:Check(label, cfg[key], function(v) cfg[key] = v ns.Fire("REMINDERS_CHANGED") UI.Refresh() end)
    end
    check("Reminders on", "enabled")
    check("Poisons on both weapons (once you have poisons)", "poisons")
    check("Reagents for spells I know (Flash Powder, Blinding Powder)", "reagents")
    check("Thieves' Tools once I know Pick Lock", "thievesTools")
    check("Class quests (level 10 weapon, lockpicking, poisons at 20 ...)", "classQuests")
    L:Text(UI.Hex(UI.C.dim) .. "Also checked when you leave a capital city.|r", { size = 12 })
    L:Text(UI.Hex(UI.C.dim) .. "Trainer visits show on Home (Do next) and Leveling > Trainer.|r", { size = 12 })
    L:EndColumns()
end
