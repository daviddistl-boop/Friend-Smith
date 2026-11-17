-- Friendsmith – Core
-- Speichert Ausruestung und Rezepte und berechnet, wer wem ein Upgrade craften kann.

local ADDON, ns = ...
local L = ns.L
-- Version kommt aus der .toc, damit sie nur an einer Stelle gepflegt wird
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = (GetMeta and GetMeta(ADDON, "Version")) or "?"

---------------------------------------------------------------------------
-- API-Kompatibilitaet (Forever basiert auf einem modernen Client)
---------------------------------------------------------------------------
local GetItemInfo        = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local RequestLoad        = C_Item and C_Item.RequestLoadItemDataByID

local DEFAULTS = {
    minDiff    = 1,     -- mindestens so viele Itemlevel (bzw. Prozent bei Spec-Bewertung) besser
    useStats   = true,  -- nach Werten der Spezialisierung bewerten, sobald Talente verteilt sind
    levelAhead = 2,     -- auch Teile zeigen, die erst in X Leveln tragbar sind
    onlyMine   = false, -- nur eigene Charaktere als Handwerker
    maxAgeDays = 30,    -- Gildendaten aelter als X Tage ignorieren
    anyArmor   = false, -- auch niedrigere Ruestungsklassen vorschlagen
    shareFriends = true, -- auch mit Freunden (Freundesliste) austauschen, die Friendsmith nutzen
    wishes     = false, -- "Ich freue mich ueber Hilfe": andere sehen von selbst, womit sie helfen koennten
    nudges     = true,  -- beim Login kurz zeigen, wem ich helfen koennte
}

function ns.Print(msg)
    print("|cff66ccffFriendsmith|r: " .. tostring(msg))
end

function ns.ShortName(key)
    return ((key or "?"):gsub("%-[^%-]*$", ""))
end

function ns.PlayerKey()
    local name = UnitName("player") or "?"
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not realm or realm == "" then
        realm = ((GetRealmName() or ""):gsub("%s", ""))
    end
    return name .. "-" .. realm
end

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
local timers = {}
function ns.Debounce(name, delay, fn)
    if timers[name] then timers[name]:Cancel() end
    timers[name] = C_Timer.NewTimer(delay, function()
        timers[name] = nil
        fn()
    end)
end

function ns.MarkDirty()
    ns.dirty = true
    ns.Debounce("ui", 0.5, function()
        if ns.RefreshUI then ns.RefreshUI() end
        if ns.RefreshProfPanel then ns.RefreshProfPanel() end
        if ns.RefreshBroker then ns.RefreshBroker() end
    end)
end

local infoCache = {}
function ns.ItemData(itemID)
    if not itemID then return nil end
    local c = infoCache[itemID]
    if c then return c end
    local name, link, quality, ilvl, reqLevel, typeName, subName, _, equipLoc, icon, _, classID, subclassID, bindType = GetItemInfo(itemID)
    if not name then
        if RequestLoad then RequestLoad(itemID) end
        ns.pending = true
        return nil
    end
    c = {
        name = name, link = link, quality = quality, icon = icon,
        ilvl = ilvl or 0, req = reqLevel or 0, loc = equipLoc,
        class = classID, sub = subclassID,
        typeName = typeName, subName = subName,
        bop = (bindType == 1), -- beim Aufheben gebunden: nur fuer den Handwerker selbst
    }
    infoCache[itemID] = c
    return c
end

---------------------------------------------------------------------------
-- Ausruestungsregeln (an Classic angelehnt, ggf. anpassen)
---------------------------------------------------------------------------
local INVTYPE_SLOTS = {
    INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3},
    INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5}, INVTYPE_WAIST = {6},
    INVTYPE_LEGS = {7}, INVTYPE_FEET = {8}, INVTYPE_WRIST = {9},
    INVTYPE_HAND = {10}, INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14},
    INVTYPE_CLOAK = {15}, INVTYPE_WEAPON = {16, 17}, INVTYPE_2HWEAPON = {16},
    INVTYPE_WEAPONMAINHAND = {16}, INVTYPE_WEAPONOFFHAND = {17},
    INVTYPE_SHIELD = {17}, INVTYPE_HOLDABLE = {17},
    INVTYPE_RANGED = {18}, INVTYPE_RANGEDRIGHT = {18}, INVTYPE_THROWN = {18},
    INVTYPE_RELIC = {18},
}
ns.INVTYPE_SLOTS = INVTYPE_SLOTS
local MAINHAND_ONLY = {16}

ns.GEAR_SLOTS = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18}

ns.CLASSES = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
    SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true,
}

local DUAL    = { WARRIOR = true, ROGUE = true, HUNTER = true }
local SHIELD  = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local HOLDABLE = { PRIEST = true, MAGE = true, WARLOCK = true, DRUID = true, SHAMAN = true, PALADIN = true }
local RELIC   = { PALADIN = 7, DRUID = 8, SHAMAN = 9 } -- Buchband, Goetze, Totem

-- Waffen-Unterklassen: 0 Axt1H, 1 Axt2H, 2 Bogen, 3 Gewehr, 4 Streitkolben1H, 5 Streitkolben2H,
-- 6 Stangenwaffe, 7 Schwert1H, 8 Schwert2H, 10 Stab, 13 Faust, 15 Dolch, 16 Wurfwaffe, 18 Armbrust, 19 Zauberstab
local function set(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end
local WEAPONS = {
    WARRIOR = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = set(0, 1, 4, 5, 6, 7, 8),
    HUNTER  = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE   = set(0, 2, 3, 4, 7, 13, 15, 16, 18), -- in Forever auch 1H-Aexte
    PRIEST  = set(4, 10, 15, 19),
    SHAMAN  = set(0, 1, 4, 5, 10, 13, 15),
    MAGE    = set(7, 10, 15, 19),
    WARLOCK = set(7, 10, 15, 19),
    DRUID   = set(4, 5, 10, 13, 15),
}

local function BestArmor(class, level)
    if class == "WARRIOR" or class == "PALADIN" then return (level >= 40) and 4 or 3 end
    if class == "HUNTER" or class == "SHAMAN" then return (level >= 40) and 3 or 2 end
    if class == "ROGUE" or class == "DRUID" then return 2 end
    return 1
end

local function CanUse(class, level, d)
    if not class or not d.class then return false end
    if d.class == 4 then -- Ruestung
        local loc = d.loc
        if loc == "INVTYPE_CLOAK" or loc == "INVTYPE_NECK" or loc == "INVTYPE_FINGER" or loc == "INVTYPE_TRINKET" then
            return true
        end
        if loc == "INVTYPE_HOLDABLE" then return HOLDABLE[class] or false end
        if loc == "INVTYPE_RELIC" then return RELIC[class] == d.sub end
        if d.sub == 6 then return SHIELD[class] or false end
        if d.sub and d.sub >= 1 and d.sub <= 4 then
            local best = BestArmor(class, level)
            if ns.S.anyArmor then return d.sub <= best end
            return d.sub == best
        end
        return false
    elseif d.class == 2 then -- Waffe
        local t = WEAPONS[class]
        return (t and t[d.sub]) or false
    end
    return false
end

-- Liefert {slot, cur, diff, pct, mode, rank} wenn itemID fuer den Charakter key ein Upgrade ist.
-- mode "stat": nach Werten der Spezialisierung (pct = Prozent besser), sonst nach Itemlevel (diff).
local function Evaluate(key, rec, itemID)
    local d = ns.ItemData(itemID)
    if not d then return nil end
    local slots = INVTYPE_SLOTS[d.loc]
    if not slots then return nil end
    local level = rec.level or 1
    if d.req > level + ns.S.levelAhead then return nil end
    if not CanUse(rec.class, level, d) then return nil end
    if d.loc == "INVTYPE_WEAPON" and not DUAL[rec.class] then slots = MAINHAND_ONLY end

    local w = ns.WeightsFor and ns.WeightsFor(key)
    local newScore
    if w then
        local st = ns.ItemStats(itemID)
        if not st then return nil end
        if ns.Irrelevant(w, st) then return nil end
        newScore = ns.Score(w, st)
        if newScore <= 0 then return nil end
    end

    local gear = rec.gear or {}
    local suffix = rec.suffix or {}
    local mh
    if gear[16] then
        mh = ns.ItemData(gear[16])
        if not mh then return nil end
    end

    local best
    for _, slot in ipairs(slots) do
        local blocked = (slot == 17 and mh and mh.loc == "INVTYPE_2HWEAPON")
        local cur = gear[slot]
        if not blocked and cur ~= itemID then
            local curIlvl, curScore = 0, 0
            if cur then
                local cd = ns.ItemData(cur)
                if not cd then return nil end
                curIlvl = cd.ilvl
                if w then
                    local cs = ns.ItemStats(cur, suffix[slot])
                    if not cs then return nil end
                    curScore = ns.Score(w, cs)
                end
            end
            local diff = d.ilvl - curIlvl
            local r = { slot = slot, cur = cur, diff = diff }
            if w then
                r.mode = "stat"
                if cur and curScore > 0 then
                    r.pct = math.min(500, math.floor((newScore - curScore) / curScore * 100 + 0.5))
                else
                    r.pct = cur and 999 or 1000 -- leerer Platz bzw. Teil ohne nuetzliche Werte
                end
                r.rank = r.pct
            else
                r.rank = diff
            end
            if not best or r.rank > best.rank then best = r end
        end
    end
    if best and best.rank >= ns.S.minDiff then return best end
    return nil
end

---------------------------------------------------------------------------
-- Berechnung
---------------------------------------------------------------------------
local MAX_PER_SLOT = 3

-- Zaehlt ein Charakter mit? Eigene immer, sonst Gilde oder (wenn erlaubt) Freunde mit frischen Daten.
function ns.IsRelevant(rec, myGuild, now)
    if rec.mine then return true end
    if (now - (rec.updated or 0)) >= ns.S.maxAgeDays * 86400 then return false end
    if myGuild ~= nil and rec.guild == myGuild then return true end
    return rec.friend and ns.S.shareFriends or false
end

function ns.Compute()
    ns.pending = false
    local DB = FriendsmithDB
    local myGuild = GetGuildInfo("player")
    local now = time()
    local function relevant(rec) return ns.IsRelevant(rec, myGuild, now) end

    local targets, crafters = {}, {}
    for key, rec in pairs(DB.chars) do
        if relevant(rec) then
            if rec.gear and rec.class then targets[#targets + 1] = key end
            -- (Kochrezepte stecken mit in rec.recipes; Evaluate ignoriert alles, was nicht anlegbar ist)
            if rec.recipes and next(rec.recipes) and (not ns.S.onlyMine or rec.mine) then
                crafters[#crafters + 1] = key
            end
        end
    end
    table.sort(crafters)

    local craftable = {}
    for _, ck in ipairs(crafters) do
        for itemID in pairs(DB.chars[ck].recipes) do
            local t = craftable[itemID]
            if not t then t = {}; craftable[itemID] = t end
            t[#t + 1] = ck
        end
    end

    local all = {}
    for itemID, who in pairs(craftable) do
        local d = ns.ItemData(itemID)
        for _, tk in ipairs(targets) do
            local crafters = who
            if d and d.bop then
                -- gebundene Teile kann nur der Handwerker fuer sich selbst herstellen
                crafters = nil
                for _, ck in ipairs(who) do
                    if ck == tk then crafters = { ck } end
                end
            end
            local r = crafters and Evaluate(tk, DB.chars[tk], itemID)
            if r then
                local mine = false
                for _, ck in ipairs(crafters) do
                    if DB.chars[ck].mine then mine = true end
                end
                all[#all + 1] = {
                    target = tk, itemID = itemID, slot = r.slot,
                    cur = r.cur, diff = r.diff, pct = r.pct, mode = r.mode, rank = r.rank,
                    crafters = crafters, mineCraft = mine,
                }
            end
        end
    end

    table.sort(all, function(a, b)
        if a.target ~= b.target then return a.target < b.target end
        if a.slot ~= b.slot then return a.slot < b.slot end
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.itemID < b.itemID
    end)

    -- pro Ziel und Platz nur die besten Vorschlaege behalten.
    -- Was du selbst craften kannst, wird extra gezaehlt, damit es nicht von
    -- besseren Gilden-Vorschlaegen verdraengt wird.
    local results, byItem, count, countMine = {}, {}, {}, {}
    for _, e in ipairs(all) do
        local ck = e.target .. "#" .. e.slot
        count[ck] = (count[ck] or 0) + 1
        local keep = count[ck] <= MAX_PER_SLOT
        if e.mineCraft then
            countMine[ck] = (countMine[ck] or 0) + 1
            keep = keep or countMine[ck] <= MAX_PER_SLOT
        end
        if keep then
            results[#results + 1] = e
            byItem[e.itemID] = byItem[e.itemID] or {}
            table.insert(byItem[e.itemID], e)
        end
    end

    ns.results, ns.byItem, ns.craftable = results, byItem, craftable
    ns.stats = { targets = #targets, crafters = #crafters }
    ns.dirty = false

    if ns.pending then
        ns.retries = (ns.retries or 0) + 1
        if ns.retries <= 10 then
            C_Timer.After(2, ns.MarkDirty)
        end
    else
        ns.retries = 0
    end
    return results
end

function ns.GetResults()
    if ns.dirty or not ns.results then
        if InCombatLockdown() and ns.results then return ns.results end
        return ns.Compute()
    end
    return ns.results
end

---------------------------------------------------------------------------
-- Eigene Daten erfassen
---------------------------------------------------------------------------
function ns.UpdateSelf(levelOverride)
    if InCombatLockdown() then return end
    local DB = FriendsmithDB
    local key = ns.PlayerKey()
    local rec = DB.chars[key] or {}
    DB.chars[key] = rec
    rec.mine = true
    rec.class = select(2, UnitClass("player"))
    rec.level = levelOverride or UnitLevel("player")
    rec.guild = GetGuildInfo("player")
    rec.updated = time()
    local gear, suffix = {}, {}
    for _, slot in ipairs(ns.GEAR_SLOTS) do
        local id = GetInventoryItemID("player", slot)
        if id then
            gear[slot] = id
            local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
            -- item:ID:Verzauberung:Sockel1-4:Zufallseigenschaft
            local sfx = link and tonumber(link:match("item:%d+:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:(%-?%d+)"))
            if sfx and sfx ~= 0 then suffix[slot] = sfx end
        end
    end
    rec.gear = gear
    rec.suffix = suffix
    if ns.DetectSpec then rec.spec = ns.DetectSpec() end
    rec.wish = ns.S.wishes or nil
    rec.recipes = rec.recipes or {}
    ns.MarkDirty()
end

local function IsGear(itemID)
    local _, _, _, equipLoc = GetItemInfoInstant(itemID)
    return equipLoc and INVTYPE_SLOTS[equipLoc] ~= nil
end

-- Ist gerade das Kochen-Fenster offen? (Fertigkeitslinie 185 bzw. Name des Zaubers "Kochkunst")
local function IsCookingWindow()
    local cook = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(2550)) or (GetSpellInfo and GetSpellInfo(2550))
    local T = C_TradeSkillUI
    if T and T.GetBaseProfessionInfo then
        local ok, info = pcall(T.GetBaseProfessionInfo)
        if ok and type(info) == "table" and (info.professionID == 185 or (cook and info.professionName == cook)) then return true end
    end
    if T and T.GetTradeSkillLine then
        local ok, id, name = pcall(T.GetTradeSkillLine)
        if ok and (id == 185 or (cook and (name == cook or id == cook))) then return true end
    end
    if GetTradeSkillLine then
        local name = GetTradeSkillLine()
        if cook and name == cook then return true end
    end
    return false
end
ns.IsCookingWindow = IsCookingWindow

-- Verbrauchsgueter (Essen, Traenke, Verbaende …) und Handwerkswaren (Barren, Stoffballen …)
-- merken wir uns fuer Buff-Essen und Gildenlager
local function IsSupply(itemID)
    local _, _, _, equipLoc, _, classID = GetItemInfoInstant(itemID)
    return (classID == 0 or classID == 7) and (not equipLoc or equipLoc == "")
end

local function AddRecipe(rec, itemID)
    if itemID and (IsGear(itemID) or IsSupply(itemID)) and not rec.recipes[itemID] then
        rec.recipes[itemID] = true
        return 1
    end
    return 0
end

-- Gelernte Rezepte des offenen Berufsfensters: itemID -> { recipeID = .. } oder { index = .. }.
-- Gibt nil zurueck, wenn das Fenster einen fremden (verlinkten) Beruf zeigt.
function ns.CurrentRecipes()
    local map = {}
    local T = C_TradeSkillUI
    if T and T.GetAllRecipeIDs then
        -- moderner Berufsfenster-Weg
        if (T.IsTradeSkillLinked and T.IsTradeSkillLinked()) or (T.IsTradeSkillGuild and T.IsTradeSkillGuild()) then
            return nil
        end
        for _, rid in ipairs(T.GetAllRecipeIDs() or {}) do
            local info = T.GetRecipeInfo and T.GetRecipeInfo(rid)
            if info and info.learned then
                local itemID
                if T.GetRecipeOutputItemData then
                    local ok, out = pcall(T.GetRecipeOutputItemData, rid)
                    if ok and type(out) == "table" then
                        itemID = out.itemID
                        if not itemID and out.hyperlink then itemID = GetItemInfoInstant(out.hyperlink) end
                    end
                end
                if not itemID and T.GetRecipeItemLink then
                    local ok, link = pcall(T.GetRecipeItemLink, rid)
                    if ok and link then itemID = tonumber(link:match("item:(%d+)")) end
                end
                if itemID then map[itemID] = { recipeID = rid } end
            end
        end
    elseif GetNumTradeSkills then
        -- klassischer Weg (eingeklappte Kategorien sind hier nicht sichtbar)
        if IsTradeSkillLinked and IsTradeSkillLinked() then return nil end
        for i = 1, GetNumTradeSkills() do
            local _, kind = GetTradeSkillInfo(i)
            if kind and kind ~= "header" and kind ~= "subheader" then
                local link = GetTradeSkillItemLink(i)
                local itemID = link and tonumber(link:match("item:(%d+)"))
                if itemID then map[itemID] = { index = i } end
            end
        end
    end
    return map
end

-- Liest die bekannten Rezepte aus dem offenen Berufsfenster.
function ns.ScanRecipes(verbose)
    if InCombatLockdown() then return end
    local DB = FriendsmithDB
    local rec = DB.chars[ns.PlayerKey()]
    if not rec then ns.UpdateSelf(); rec = DB.chars[ns.PlayerKey()] end
    rec.recipes = rec.recipes or {}
    local added = 0

    local map = ns.CurrentRecipes()
    if not map then return end
    for itemID in pairs(map) do
        added = added + AddRecipe(rec, itemID)
    end
    local newMats = ns.RecordReagents and ns.RecordReagents(map, rec) or 0
    local profChanged = ns.RecordProfession and ns.RecordProfession(map, rec) or false

    if added > 0 or newMats > 0 or profChanged then
        ns.MarkDirty()
        ns.Debounce("sendrecipes", 20, function()
            if ns.SendChar then ns.SendChar(ns.PlayerKey(), "R") end
        end)
    end
    if verbose or added > 0 then
        local total = 0
        for _ in pairs(rec.recipes) do total = total + 1 end
        ns.Print(string.format(L["%d new recipes recorded (total %d)."], added, total))
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ns.eventFrame = ev

local function SafeRegister(event)
    pcall(ev.RegisterEvent, ev, event)
end

SafeRegister("ADDON_LOADED")
SafeRegister("PLAYER_LOGIN")
SafeRegister("PLAYER_ENTERING_WORLD")
SafeRegister("PLAYER_EQUIPMENT_CHANGED")
SafeRegister("PLAYER_LEVEL_UP")
SafeRegister("CHARACTER_POINTS_CHANGED")
SafeRegister("PLAYER_TALENT_UPDATE")
SafeRegister("PLAYER_GUILD_UPDATE")
SafeRegister("GET_ITEM_INFO_RECEIVED")
SafeRegister("TRADE_SKILL_SHOW")
SafeRegister("TRADE_SKILL_UPDATE")
SafeRegister("TRADE_SKILL_LIST_UPDATE")
SafeRegister("TRADE_SKILL_DATA_SOURCE_CHANGED")

local helloDone = false

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        FriendsmithDB = FriendsmithDB or {}
        local DB = FriendsmithDB
        DB.chars = DB.chars or {}
        DB.settings = DB.settings or {}
        for k, v in pairs(DEFAULTS) do
            if DB.settings[k] == nil then DB.settings[k] = v end
        end
        ns.S = DB.settings
        ns.dirty = true

    elseif event == "PLAYER_LOGIN" then
        ns.UpdateSelf()
        if ns.InitComm then ns.InitComm() end
        if ns.InitBroker then ns.InitBroker() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.Debounce("self", 3, function() ns.UpdateSelf() end)
        if not helloDone then
            helloDone = true
            ns.Debounce("hello", 15, function() if ns.Hello then ns.Hello() end end)
        end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
        local lvl = (event == "PLAYER_LEVEL_UP") and arg1 or nil
        ns.Debounce("self", 2, function()
            ns.UpdateSelf(lvl)
            ns.Debounce("sendgear", 30, function()
                if ns.SendChar then ns.SendChar(ns.PlayerKey(), "G") end
            end)
        end)

    elseif event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        ns.Debounce("self", 2, function()
            ns.UpdateSelf()
            ns.Debounce("sendgear", 30, function()
                if ns.SendChar then ns.SendChar(ns.PlayerKey(), "G") end
            end)
        end)

    elseif event == "PLAYER_GUILD_UPDATE" then
        ns.Debounce("self", 3, function() ns.UpdateSelf() end)

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if ns.pending then ns.Debounce("iteminfo", 1, ns.MarkDirty) end

    else -- Berufsfenster
        if event == "TRADE_SKILL_SHOW" and ns.OnTradeSkillShow then ns.OnTradeSkillShow() end
        ns.Debounce("scan", 1, function()
            ns.ScanRecipes(false)
            if ns.RefreshProfPanel then ns.RefreshProfPanel() end
        end)
    end
end)
