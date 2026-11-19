-- Friendsmith – Buff-Essen
-- Erkennt, welcher "Satt"-Bonus ein gekochtes Essen gibt, und ermittelt pro Kategorie,
-- wer in Gilde, Freundesliste und unter den eigenen Charakteren das beste Essen kochen kann.

local ADDON, ns = ...
local L = ns.L

-- Kategorien in fester Reihenfolge. Die Namen kommen aus dem Spielclient (also schon uebersetzt).
local STATS = {
    { key = "str", name = SPELL_STAT1_NAME or "Strength" },
    { key = "agi", name = SPELL_STAT2_NAME or "Agility" },
    { key = "sta", name = SPELL_STAT3_NAME or "Stamina" },
    { key = "int", name = SPELL_STAT4_NAME or "Intellect" },
    { key = "spi", name = SPELL_STAT5_NAME or "Spirit" },
    { key = "ap",  name = ITEM_MOD_ATTACK_POWER_SHORT or "Attack Power" },
    { key = "sp",  name = ITEM_MOD_SPELL_POWER_SHORT or "Spell Power" },
    { key = "mp5", name = MANA or "Mana", label = L["Mana regeneration"] },
}

local USE_PREFIX = ITEM_SPELL_TRIGGER_ONUSE -- "Benutzen:" / "Use:"

-- Woerter fuer den "Satt"-Bonus. Der Buffname kommt aus dem Client (erst bei Bedarf abfragen –
-- beim Laden des Addons sind Zauberdaten oft noch nicht da), dazu feste Rueckfaelle.
local wellFedWords
local function WellFedWords()
    if wellFedWords then return wellFedWords end
    local w = { "well fed", "gesättigt", "wohlgenährt" }
    local n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(19705)) or (GetSpellInfo and GetSpellInfo(19705))
    if n and n ~= "" then
        w[#w + 1] = n:lower()
        wellFedWords = w -- nur merken, wenn der Client den Namen geliefert hat
    end
    return w
end

local function IsWellFed(low)
    for _, word in ipairs(WellFedWords()) do
        if low:find(word, 1, true) then return true end
    end
    -- "satt" als ganzes Wort (nicht "statt", "Sattel" …)
    return low:find("%f[%a]satt%f[%A]") ~= nil
end

local function Plain(t)
    -- Farbcodes entfernen: klassisch |cffRRGGBB und modern |cnIQ1: / |cnNAME:
    return (t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
end

---------------------------------------------------------------------------
-- Tooltip-Text eines Gegenstands lesen
---------------------------------------------------------------------------
local scanTip
local function TooltipLines(itemID)
    local out = {}
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
        if ok and data and data.lines then
            for _, line in ipairs(data.lines) do
                if line.leftText then out[#out + 1] = line.leftText end
            end
            if #out > 0 then return out end
        end
    end
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "FriendsmithScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetHyperlink("item:" .. itemID)
    for i = 1, scanTip:NumLines() or 0 do
        local fs = _G["FriendsmithScanTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t then out[#out + 1] = t end
    end
    scanTip:Hide()
    return out
end

-- Zahl direkt vor dem Wert ("gain 12 Stamina", "erhaltet 12 Ausdauer"), sonst die naechste danach
local function AmountNear(text, pos)
    local before = text:sub(1, pos - 1):match("(%d+)%s*$")
    if before then return tonumber(before) end
    local after = text:match("(%d+)", pos)
    return after and tonumber(after) or 0
end

---------------------------------------------------------------------------
-- Buff eines Essens: { cat = "sta+spi", label = "Ausdauer & Willenskraft", amount = 12, text = "..." }
---------------------------------------------------------------------------
local cache = {}

-- Auswertung mit Grund (fuer /fsmith foodcheck): buff oder nil, Grund, Text
local function Analyze(itemID)
    local d = ns.ItemData(itemID)
    if not d then return nil, "loading" end
    if d.class ~= 0 or (d.loc and d.loc ~= "") then return nil, "noconsumable" end

    local lines = TooltipLines(itemID)
    local text
    for i, line in ipairs(lines) do
        line = Plain(line)
        if i > 1 and (not USE_PREFIX or line:find(USE_PREFIX, 1, true)) then
            text = (text and (text .. " ") or "") .. line
        end
    end
    if not text then
        -- kein "Benutzen:" gefunden: alle Zeilen ausser dem Namen nehmen, falls dort "satt" steht
        local all = {}
        for i, line in ipairs(lines) do if i > 1 then all[#all + 1] = Plain(line) end end
        local joined = table.concat(all, " ")
        if joined ~= "" and IsWellFed(joined:lower()) then text = joined end
    end
    if not text then return nil, (#lines <= 1) and "notooltip" or "nouse" end

    local low = text:lower()
    if not IsWellFed(low) then return nil, "nowellfed", text end
    local keys, labels, amount, firstPos = {}, {}, 0, nil
    for _, s in ipairs(STATS) do
        local pos = low:find(s.name:lower(), 1, true)
        if pos then
            keys[#keys + 1] = s.key
            labels[#labels + 1] = s.label or s.name
            if not firstPos or pos < firstPos then
                firstPos = pos
                amount = AmountNear(text, pos)
            end
        end
    end
    if #keys == 0 then return nil, "nostat", text end
    local clean = USE_PREFIX and text:gsub("^%s*" .. USE_PREFIX:gsub("%p", "%%%0") .. "%s*", "") or text
    return {
        cat = table.concat(keys, "+"),
        label = table.concat(labels, " & "),
        amount = amount,
        text = clean,
    }, "ok", text
end

function ns.FoodBuff(itemID)
    local c = cache[itemID]
    if c ~= nil then return c or nil end
    local buff, why = Analyze(itemID)
    if buff then
        cache[itemID] = buff
    elseif why == "noconsumable" or why == "nowellfed" or why == "nostat" then
        cache[itemID] = false -- endgueltig kein Buff-Essen
    end
    -- "loading"/"notooltip"/"nouse": spaeter noch einmal versuchen
    return buff
end

-- /fsmith foodcheck: zeigt, wie Friendsmith die eigenen Koch-Rezepte bewertet
function ns.FoodCheck()
    wipe(cache)
    local rec = FriendsmithDB.chars[ns.PlayerKey()]
    local counts, samples = {}, {}
    for itemID in pairs(rec and rec.recipes or {}) do
        local d = ns.ItemData(itemID)
        if d and d.class == 0 then
            local buff, why, text = Analyze(itemID)
            counts[why] = (counts[why] or 0) + 1
            if #samples < 8 and why ~= "noconsumable" then
                samples[#samples + 1] = string.format("%s: %s%s", d.name, buff and ("|cff5cdb6b" .. buff.label .. " +" .. buff.amount .. "|r") or ("|cffff6060" .. why .. "|r"),
                    (not buff and text) and ("  |cff8f96a8" .. text:sub(1, 90) .. "|r") or "")
            end
        end
    end
    ns.Print(string.format(L["Food check: %d buff food, %d without \"Well Fed\", %d without a Use line, %d not loaded yet."],
        counts.ok or 0, (counts.nowellfed or 0) + (counts.nostat or 0), (counts.nouse or 0) + (counts.notooltip or 0), counts.loading or 0))
    local nc = 0
    for _, h in pairs(rec and rec.foodCat or {}) do if ns.IsBuffCategory(h) then nc = nc + 1 end end
    ns.Print(string.format(L["From the cooking window: %d recipes in buff food categories."], nc))
    for _, line in ipairs(samples) do ns.Print("  " .. line) end
    ns.MarkDirty()
end

---------------------------------------------------------------------------
-- Kategorien aus dem Kochfenster ("Ausdauernahrung", "Stärkungsnahrung" …).
-- WoW Forever sortiert die Rezepte schon nach Buff – das ist verlaesslicher als jeder Tooltip-Text.
---------------------------------------------------------------------------
local function CleanHeader(h) return ((h or ""):gsub("[;,=|]", ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Ist das eine Kategorie mit Buff-Essen? ("…nahrung" / "… Food", aber nicht Alltagsessen oder Lager)
function ns.IsBuffCategory(h)
    local low = (h or ""):lower()
    if low == "" then return false end
    if low:find("alltäglich", 1, true) or low:find("everyday", 1, true) or low:find("daily", 1, true)
        or low:find("lager", 1, true) or low:find("camp", 1, true) then return false end
    return low:find("nahrung", 1, true) ~= nil or low:find("food", 1, true) ~= nil
end

local function ReadCategories()
    local out = {}
    local T = C_TradeSkillUI
    if T and T.GetAllRecipeIDs and not ns.ClassicList() then
        for _, rid in ipairs(T.GetAllRecipeIDs() or {}) do
            local ok, info = pcall(T.GetRecipeInfo, rid)
            if ok and type(info) == "table" and info.learned and info.categoryID and T.GetCategoryInfo then
                local okc, cat = pcall(T.GetCategoryInfo, info.categoryID)
                local itemID
                if T.GetRecipeOutputItemData then
                    local oko, o = pcall(T.GetRecipeOutputItemData, rid)
                    itemID = oko and type(o) == "table" and o.itemID or nil
                end
                if okc and type(cat) == "table" and cat.name and itemID then out[itemID] = CleanHeader(cat.name) end
            end
        end
    elseif GetNumTradeSkills then
        local header
        for i = 1, GetNumTradeSkills() do
            local name, kind = GetTradeSkillInfo(i)
            if kind == "header" or kind == "subheader" then
                header = name
            elseif kind then
                local link = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
                local itemID = link and tonumber(link:match("item:(%d+)"))
                if itemID and header then out[itemID] = CleanHeader(header) end
            end
        end
    end
    return out
end

-- Von ScanRecipes aufgerufen (nur im Kochfenster); true = geaendert
function ns.RecordFoodCategories(rec)
    if not (ns.IsCookingWindow and ns.IsCookingWindow()) then return false end
    local found = ReadCategories()
    rec.foodCat = rec.foodCat or {}
    local changed = false
    for itemID, h in pairs(found) do
        if h ~= "" and rec.foodCat[itemID] ~= h then rec.foodCat[itemID] = h; changed = true end
    end
    return changed
end

-- Sync "C": "itemID=Kategorie,..." (nur Buff-Kategorien, sortiert)
function ns.FoodCatPayload(rec)
    local ids = {}
    for id, h in pairs(rec.foodCat or {}) do if ns.IsBuffCategory(h) then ids[#ids + 1] = id end end
    if #ids == 0 then return nil end
    table.sort(ids)
    local parts = {}
    for _, id in ipairs(ids) do parts[#parts + 1] = id .. "=" .. rec.foodCat[id] end
    return table.concat(parts, ",")
end

function ns.ParseFoodCats(rec, f)
    local set, n = {}, 0
    for id, h in (f[4] or ""):gmatch("(%d+)=([^,]+)") do
        if n < 300 and #h <= 40 then set[tonumber(id)] = h; n = n + 1 end
    end
    rec.foodCat = n > 0 and set or nil
end

-- "+12" oder, wenn nur die Kategorie bekannt ist, die benoetigte Stufe
function ns.FoodValueText(e)
    if e.levelOnly then return L["lvl"] .. " " .. (e.req or "?") end
    return "+" .. (e.amount or 0)
end

---------------------------------------------------------------------------
-- Liste: alle bekannten Buff-Essen, nach Kategorie, bestes zuerst
---------------------------------------------------------------------------
local function CatOrder(cat)
    if cat:sub(1, 2) == "h:" then return 50 end
    local first = cat:match("^[^+]+")
    for i, s in ipairs(STATS) do
        if s.key == first then return i end
    end
    return 99
end

function ns.FoodList()
    local DB = FriendsmithDB
    local myGuild = GetGuildInfo("player")
    local now = time()

    local foods = {}
    local keys = {}
    for key, rec in pairs(DB.chars) do
        if rec.recipes and ns.IsRelevant(rec, myGuild, now) and (not ns.S.onlyMine or rec.mine) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    -- Kategorien aus den Kochfenstern aller (Gilde, Freunde, eigene)
    local catOf = {}
    for _, rec in pairs(DB.chars) do
        for id, h in pairs(rec.foodCat or {}) do catOf[id] = catOf[id] or h end
    end
    for _, key in ipairs(keys) do
        for itemID in pairs(DB.chars[key].recipes) do
            local header = catOf[itemID]
            local byCat = header and ns.IsBuffCategory(header)
            local buff = ns.FoodBuff(itemID)
            if byCat or buff then
                local e = foods[itemID]
                if not e then
                    local d = ns.ItemData(itemID)
                    e = { food = true, itemID = itemID, req = d and d.req or 0, crafters = {},
                          amount = buff and buff.amount or 0, text = buff and buff.text or nil }
                    if byCat then
                        -- Gruppe wie im Kochfenster; Rangfolge nach Buff-Wert, sonst nach Stufe
                        e.cat, e.label = "h:" .. header:lower(), header
                        e.levelOnly = not buff
                    else
                        e.cat, e.label = buff.cat, buff.label
                    end
                    foods[itemID] = e
                end
                e.crafters[#e.crafters + 1] = key
            elseif ns.ItemData(itemID) == nil then
                ns.pending = true
            end
        end
    end

    local cats, order = {}, {}
    for _, e in pairs(foods) do
        local g = cats[e.cat]
        if not g then
            g = { cat = e.cat, label = e.label, items = {} }
            cats[e.cat] = g
            order[#order + 1] = g
        end
        g.items[#g.items + 1] = e
    end
    for _, g in ipairs(order) do
        table.sort(g.items, function(a, b)
            if a.amount ~= b.amount then return a.amount > b.amount end
            if a.req ~= b.req then return a.req > b.req end
            return a.itemID < b.itemID
        end)
        for i, e in ipairs(g.items) do
            e.rank = i
            e.best = g.items[1]
        end
    end
    table.sort(order, function(a, b)
        local oa, ob = CatOrder(a.cat), CatOrder(b.cat)
        if oa ~= ob then return oa < ob end
        if #a.cat ~= #b.cat then return #a.cat < #b.cat end
        return a.cat < b.cat
    end)
    return order
end
