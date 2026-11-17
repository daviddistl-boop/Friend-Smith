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
    for i = 1, scanTip:NumLines() do
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

function ns.FoodBuff(itemID)
    local c = cache[itemID]
    if c ~= nil then return c or nil end
    local d = ns.ItemData(itemID)
    if not d then return nil end -- noch nicht geladen
    if d.class ~= 0 or (d.loc and d.loc ~= "") then cache[itemID] = false; return nil end

    -- nur die "Benutzen:"-Zeile(n) auswerten
    local text
    for _, line in ipairs(TooltipLines(itemID)) do
        if not USE_PREFIX or line:find(USE_PREFIX, 1, true) == 1 then
            text = (text and (text .. " ") or "") .. line
        end
    end
    if not text then return nil end -- Tooltip noch leer: spaeter nochmal versuchen

    local low = text:lower()
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
    if #keys == 0 then cache[itemID] = false; return nil end

    c = {
        cat = table.concat(keys, "+"),
        label = table.concat(labels, " & "),
        amount = amount,
        text = (text:gsub("^" .. (USE_PREFIX and USE_PREFIX:gsub("%p", "%%%0") or "") .. "%s*", "")),
    }
    cache[itemID] = c
    return c
end

---------------------------------------------------------------------------
-- Liste: alle bekannten Buff-Essen, nach Kategorie, bestes zuerst
---------------------------------------------------------------------------
local function CatOrder(cat)
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
    for _, key in ipairs(keys) do
        for itemID in pairs(DB.chars[key].recipes) do
            local buff = ns.FoodBuff(itemID)
            if buff then
                local e = foods[itemID]
                if not e then
                    local d = ns.ItemData(itemID)
                    e = { food = true, itemID = itemID, cat = buff.cat, label = buff.label,
                          amount = buff.amount, text = buff.text, req = d and d.req or 0, crafters = {} }
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
