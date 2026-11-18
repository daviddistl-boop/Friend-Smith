-- Friendsmith – Verzauberungen und Entzaubern
--
-- 1) Verzauberer: beim Oeffnen des Verzauberungsfensters merkt sich Friendsmith die Formeln (Zauber-IDs) und fuer
--    welchen Platz sie sind (Armschiene, Brust, Umhang …). Sync: Nachricht "V" (gehoert zu den Charakterdaten).
-- 2) Freie Plaetze: Ausruestung der eigenen Charaktere ohne Verzauberung -> welche Formeln und Ruestungssets
--    (Lederverarbeitung) die Gilde dafuer hat.
-- 3) Entzaubern: Gruene/blaue/lila Ausruestung in den Taschen, die keiner der eigenen Charaktere braucht ->
--    was ein Verzauberer daraus machen koennte und wer diese Mats gerade braucht. Die Ausbeute ist geschaetzt.

local ADDON, ns = ...
local L = ns.L

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

---------------------------------------------------------------------------
-- Plaetze
---------------------------------------------------------------------------
-- Formel-Kategorien und auf welche Ausruestungsplaetze sie passen
local CODES = { "weapon2h", "weapon", "shield", "wrist", "chest", "cloak", "feet", "hands" }
local VALID = {}
for _, c in ipairs(CODES) do VALID[c] = true end

-- Woerter in Formelnamen (englisch und deutsch, Reihenfolge wichtig: 2H vor Waffe)
local WORDS = {
    { "weapon2h", { "2h weapon", "two-handed", "two handed", "zweihandwaffe", "zweihand" } },
    { "shield", { "shield", "schild" } },
    { "wrist", { "bracer", "armschiene" } },
    { "chest", { "chest", "brust" } },
    { "cloak", { "cloak", "umhang" } },
    { "feet", { "boots", "stiefel" } },
    { "hands", { "gloves", "handschuhe" } },
    { "weapon", { "weapon", "waffe" } },
}

local function CodeFromName(name)
    local low = (name or ""):lower()
    for _, w in ipairs(WORDS) do
        for _, word in ipairs(w[2]) do
            if low:find(word, 1, true) then return w[1] end
        end
    end
end

-- Ausruestungsplatz -> passende Formel-Kategorie (nil = nicht verzauberbar)
local function CodeForSlot(slot, itemID)
    if slot == 9 then return "wrist" end
    if slot == 5 then return "chest" end
    if slot == 15 then return "cloak" end
    if slot == 8 then return "feet" end
    if slot == 10 then return "hands" end
    if slot == 16 or slot == 17 then
        local _, _, _, loc = GetItemInfoInstant(itemID)
        if loc == "INVTYPE_2HWEAPON" then return "weapon2h" end
        if loc == "INVTYPE_SHIELD" then return "shield" end
        if loc == "INVTYPE_HOLDABLE" or loc == "INVTYPE_RANGED" or loc == "INVTYPE_RANGEDRIGHT" then return nil end
        return "weapon"
    end
end
ns.CodeForSlot = CodeForSlot

local KIT_SLOTS = { [5] = true, [7] = true, [8] = true, [10] = true } -- Ruestungssets: Brust, Beine, Fuesse, Haende

---------------------------------------------------------------------------
-- Verzauberungsfenster lesen
---------------------------------------------------------------------------
local function EnchantingName()
    return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(7411)) or (GetSpellInfo and GetSpellInfo(7411)) or "Enchanting"
end

local function IsEnchantingWindow()
    local name = EnchantingName()
    local T = C_TradeSkillUI
    if T and T.GetBaseProfessionInfo then
        local ok, info = pcall(T.GetBaseProfessionInfo)
        if ok and type(info) == "table" and (info.professionID == 333 or info.professionName == name) then return true end
    end
    if T and T.GetTradeSkillLine then
        local ok, id, n = pcall(T.GetTradeSkillLine)
        if ok and (id == 333 or n == name) then return true end
    end
    if GetTradeSkillLine then
        local n = GetTradeSkillLine()
        if n == name then return true end
    end
    return false
end

-- Liest die gelernten Formeln: { [zauberID] = kategorie }
local function ReadEnchants()
    local out = {}
    local T = C_TradeSkillUI
    if T and T.GetAllRecipeIDs then
        for _, rid in ipairs(T.GetAllRecipeIDs() or {}) do
            local ok, info = pcall(T.GetRecipeInfo, rid)
            if ok and type(info) == "table" and info.learned then
                local code = CodeFromName(info.name)
                if code then out[rid] = code end
            end
        end
    elseif GetNumTradeSkills then
        for i = 1, GetNumTradeSkills() do
            local name, kind = GetTradeSkillInfo(i)
            if kind and kind ~= "header" and kind ~= "subheader" then
                local link = (GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)) or (GetTradeSkillItemLink and GetTradeSkillItemLink(i))
                local id = link and tonumber(link:match("enchant:(%d+)"))
                local code = CodeFromName(name)
                if id and code then out[id] = code end
            end
        end
    end
    return out
end

-- Von ScanRecipes aufgerufen; true = geaendert
function ns.RecordEnchants(rec)
    if not IsEnchantingWindow() then return false end
    local found = ReadEnchants()
    if not next(found) then return false end
    rec.enchants = rec.enchants or {}
    local changed = false
    for id, code in pairs(found) do
        if rec.enchants[id] ~= code then rec.enchants[id] = code; changed = true end
    end
    return changed
end

-- Sync "V": "zauberID:kategorie,..." (sortiert)
function ns.EnchantPayload(rec)
    if not rec.enchants or not next(rec.enchants) then return nil end
    local ids = {}
    for id in pairs(rec.enchants) do ids[#ids + 1] = id end
    table.sort(ids)
    local parts = {}
    for _, id in ipairs(ids) do parts[#parts + 1] = id .. ":" .. rec.enchants[id] end
    return table.concat(parts, ",")
end

function ns.ParseEnchants(rec, f)
    local set, n = {}, 0
    for id, code in (f[4] or ""):gmatch("(%d+):([%w]+)") do
        if VALID[code] and n < 400 then set[tonumber(id)] = code; n = n + 1 end
    end
    rec.enchants = n > 0 and set or nil
end

function ns.EnchantName(id)
    local n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id))
    return n or ("#" .. id)
end

---------------------------------------------------------------------------
-- Freie Verzauberungsplaetze der eigenen Charaktere
---------------------------------------------------------------------------
local function IsKit(itemID)
    local d = ns.ItemData(itemID)
    if not d or not d.name then return false end
    local low = d.name:lower()
    return low:find("armor kit", 1, true) or low:find("rüstungsset", 1, true) or low:find("ruestungsset", 1, true)
end

-- { { key, slot, code, itemID, enchants = { {id, keys} }, kits = { {itemID, keys} } }, ... }
function ns.FreeEnchantSlots()
    local DB = FriendsmithDB
    local myGuild = GetGuildInfo("player")
    local now = time()
    -- was kann die Gilde?
    local byCode = {}
    for key, rec in pairs(DB.chars) do
        if rec.enchants and ns.IsRelevant(rec, myGuild, now) then
            for id, code in pairs(rec.enchants) do
                byCode[code] = byCode[code] or {}
                byCode[code][id] = byCode[code][id] or {}
                table.insert(byCode[code][id], key)
            end
        end
    end
    local kits = {}
    for itemID, who in pairs(ns.craftable or {}) do
        if IsKit(itemID) then kits[#kits + 1] = { itemID, who } end
    end
    table.sort(kits, function(a, b) return a[1] < b[1] end)

    local out = {}
    for key, rec in pairs(DB.chars) do
        if rec.mine and rec.gear and rec.ench then
            for slot, itemID in pairs(rec.gear) do
                if (rec.ench[slot] or 0) == 0 then
                    local code = CodeForSlot(slot, itemID)
                    local e = { enchSlot = true, key = key, slot = slot, code = code, itemID = itemID, enchants = {}, kits = {} }
                    for id, keys in pairs(code and byCode[code] or {}) do
                        table.sort(keys)
                        e.enchants[#e.enchants + 1] = { id = id, keys = keys }
                    end
                    table.sort(e.enchants, function(a, b) return a.id > b.id end) -- hoehere ID ~ neuere/bessere Formel
                    if KIT_SLOTS[slot] then
                        for _, k in ipairs(kits) do e.kits[#e.kits + 1] = { itemID = k[1], keys = k[2] } end
                    end
                    if #e.enchants > 0 or #e.kits > 0 then out[#out + 1] = e end
                end
            end
        end
    end
    local me = ns.PlayerKey()
    table.sort(out, function(a, b)
        if (a.key == me) ~= (b.key == me) then return a.key == me end
        if a.key ~= b.key then return a.key < b.key end
        return a.slot < b.slot
    end)
    return out
end

---------------------------------------------------------------------------
-- Entzaubern: geschaetzte Ausbeute (klassische Tabelle)
---------------------------------------------------------------------------
local DUST = { { 25, 10940 }, { 35, 11083 }, { 45, 11137 }, { 55, 11176 }, { 999, 16204 } }
local ESSENCE = { { 15, 10938 }, { 20, 10939 }, { 25, 10998 }, { 30, 11082 }, { 35, 11134 }, { 40, 11135 },
                  { 45, 11174 }, { 50, 11175 }, { 55, 16202 }, { 999, 16203 } }
local SHARD = { { 20, 10978 }, { 25, 11084 }, { 30, 11138 }, { 35, 11139 }, { 40, 11177 }, { 45, 11178 },
                { 50, 14343 }, { 999, 14344 } }
local NEXUS = 20725
local SKILL = { { 20, 1 }, { 25, 25 }, { 30, 50 }, { 35, 75 }, { 40, 100 }, { 45, 125 }, { 50, 150 }, { 55, 175 }, { 60, 200 }, { 999, 225 } }

local function Pick(t, ilvl)
    for _, x in ipairs(t) do if ilvl <= x[1] then return x[2] end end
end

-- { mats = {itemID, ...}, skill = noetige Verzauberkunst }
function ns.DisenchantYield(itemID)
    local d = ns.ItemData(itemID)
    if not d or not d.quality or d.quality < 2 or d.quality > 4 then return nil end
    if d.class ~= 2 and d.class ~= 4 then return nil end
    local ilvl = d.ilvl or 0
    local mats
    if d.quality == 2 then
        mats = { Pick(DUST, ilvl), Pick(ESSENCE, ilvl) }
    elseif d.quality == 3 then
        mats = { Pick(SHARD, ilvl) }
    else
        mats = { ilvl >= 56 and NEXUS or Pick(SHARD, ilvl) }
    end
    return { mats = mats, skill = Pick(SKILL, ilvl) or 1 }
end

-- Wer braucht welche Mats gerade? matID -> { {who, n, why}, ... }
function ns.MatNeeds()
    local needs = {}
    local function add(id, who, n, why)
        needs[id] = needs[id] or {}
        table.insert(needs[id], { who = who, n = n, why = why })
    end
    for _, r in ipairs(ns.OpenRequests and ns.OpenRequests() or {}) do
        for _, m in ipairs(r.mats) do add(m[1], r.from, m[2], "request") end
    end
    for _, e in ipairs(ns.StockList and ns.StockList() or {}) do
        if e.missing > 0 then
            for _, m in ipairs(ns.Reagents(e.itemID) or {}) do add(m[1], "stock", m[2] * e.missing, "stock") end
        end
    end
    for _, e in ipairs(ns.ProfHelpList and ns.ProfHelpList() or {}) do
        local o = e.plan and not e.plan.trainer and e.plan.options[1]
        for _, m in ipairs(o and o.mats or {}) do add(m[1], e.key, m[2], "prof") end
    end
    return needs
end

-- Verzauberer der Gilde mit Fertigkeit: { {key, rank}, ... }
function ns.Enchanters()
    local DB = FriendsmithDB
    local myGuild = GetGuildInfo("player")
    local now = time()
    local names = { [EnchantingName():lower()] = true, enchanting = true, verzauberkunst = true }
    local out = {}
    for key, rec in pairs(DB.chars) do
        if ns.IsRelevant(rec, myGuild, now) then
            local rank
            for name, p in pairs(rec.profs or {}) do
                if names[name:lower()] then rank = p.rank end
            end
            if not rank and rec.enchants and next(rec.enchants) then rank = 0 end -- Formeln bekannt, Stufe unbekannt
            if rank then out[#out + 1] = { key = key, rank = rank } end
        end
    end
    table.sort(out, function(a, b) return a.rank > b.rank end)
    return out
end

---------------------------------------------------------------------------
-- Taschen des eingeloggten Charakters durchsuchen
---------------------------------------------------------------------------
local function BagItems()
    local out = {}
    local CC = C_Container
    local numSlots = (CC and CC.GetContainerNumSlots) or GetContainerNumSlots
    local itemInfo = (CC and CC.GetContainerItemInfo) or GetContainerItemInfo
    if not numSlots or not itemInfo then return out end
    for bag = 0, 4 do
        for slot = 1, numSlots(bag) or 0 do
            local a, _, _, _, _, _, link, _, _, id, bound = itemInfo(bag, slot)
            if type(a) == "table" then
                link, id, bound = a.hyperlink, a.itemID, a.isBound
            end
            id = id or (link and tonumber(link:match("item:(%d+)")))
            if id then out[#out + 1] = { itemID = id, link = link, bound = bound and true or false } end
        end
    end
    return out
end

local cache = { t = 0, list = {} }

-- { { itemID, link, bound, yield, needs = { {who, n, why} }, wearer = {key, r} }, ... }
function ns.DisenchantCandidates(force)
    if not force and GetTime() - cache.t < 5 then return cache.list end
    local DB = FriendsmithDB
    local myGuild = GetGuildInfo("player")
    local now = time()
    local amEnchanter = false
    for _, en in ipairs(ns.Enchanters()) do
        if DB.chars[en.key] and DB.chars[en.key].mine then amEnchanter = true end
    end
    local needs = ns.MatNeeds()
    local out, seen = {}, {}
    for _, it in ipairs(BagItems()) do
        local d = ns.ItemData(it.itemID)
        local y = d and ns.INVTYPE_SLOTS[d.loc] and ns.DisenchantYield(it.itemID)
        if y and not seen[it.itemID] and (not it.bound or amEnchanter) then
            -- braucht es einer der eigenen Charaktere? dann nicht vorschlagen
            local useful = false
            for key, rec in pairs(DB.chars) do
                if rec.mine and ns.EvaluateFor(key, it.itemID) then useful = true break end
            end
            if not useful then
                seen[it.itemID] = true
                local c = { deItem = true, itemID = it.itemID, link = it.link, bound = it.bound, yield = y, needs = {}, crafters = {} }
                for _, m in ipairs(y.mats) do
                    for _, n in ipairs(needs[m] or {}) do c.needs[#c.needs + 1] = { mat = m, who = n.who, n = n.n, why = n.why } end
                end
                -- koennte jemand aus der Gilde das Teil tragen? (nur handelbare Teile)
                if not it.bound then
                    for key, rec in pairs(DB.chars) do
                        if not rec.mine and ns.IsRelevant(rec, myGuild, now) then
                            local r = ns.EvaluateFor(key, it.itemID)
                            if r and (not c.wearer or r.rank > c.wearer.r.rank) then c.wearer = { key = key, r = r } end
                        end
                    end
                end
                out[#out + 1] = c
            end
        end
    end
    table.sort(out, function(a, b)
        if (#a.needs > 0) ~= (#b.needs > 0) then return #a.needs > 0 end
        return a.itemID < b.itemID
    end)
    cache = { t = GetTime(), list = out }
    return out
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", function()
    cache.t = 0
    ns.Debounce("matsui", 1, function() if ns.RefreshUI then ns.RefreshUI() end end)
end)
