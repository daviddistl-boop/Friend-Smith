-- Friendsmith – Fenster, Tooltip und Befehle
-- Aufbau: Kopfzeile (Suche) | Seitenleiste (Ansicht, Filter) | Liste wie im Berufsfenster | Details

local ADDON, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Stil
---------------------------------------------------------------------------
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local EMPTY_ICON = 134400

local C = {
    bg        = { 0.055, 0.062, 0.078, 0.97 },
    header    = { 0.085, 0.092, 0.115, 1 },
    panel     = { 0.075, 0.082, 0.102, 1 },
    panel2    = { 0.115, 0.125, 0.155, 1 },
    border    = { 0.20, 0.22, 0.27, 1 },
    accent    = { 0.95, 0.52, 0.18, 1 },
    accentBg  = { 0.95, 0.52, 0.18, 0.15 },
    accentBtn = { 0.55, 0.26, 0.07, 1 },
    text      = { 0.93, 0.93, 0.95, 1 },
    muted     = { 0.56, 0.59, 0.66, 1 },
    green     = { 0.36, 0.86, 0.42, 1 },
    gold      = { 1.00, 0.82, 0.25, 1 },
}

local W, H = 880, 560
local HEADER_H, STATUS_H, SIDEBAR_W, LIST_W = 48, 22, 184, 330
local ROW_H = 22
local MAX_CRAFTER_ROWS = 3
local MAX_MAT_ROWS = 5

local SLOT_NAMES = {
    [1] = L["Head"], [2] = L["Neck"], [3] = L["Shoulder"], [5] = L["Chest"], [6] = L["Waist"],
    [7] = L["Legs"], [8] = L["Feet"], [9] = L["Wrist"], [10] = L["Hands"],
    [11] = "Finger", [12] = "Finger", [13] = L["Trinket"], [14] = L["Trinket"],
    [15] = L["Back"], [16] = L["Main Hand"], [17] = L["Off Hand"], [18] = L["Ranged"],
}

---------------------------------------------------------------------------
-- Kleine Bausteine
---------------------------------------------------------------------------
local function Fill(frame, c, layer, sub)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    t:SetAllPoints()
    return t
end

local function Border(frame, c)
    local edges = {}
    local function edge()
        local t = frame:CreateTexture(nil, "BORDER")
        edges[#edges + 1] = t
        return t
    end
    local t = edge(); t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
    t = edge(); t:SetPoint("BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT"); t:SetHeight(1)
    t = edge(); t:SetPoint("TOPLEFT"); t:SetPoint("BOTTOMLEFT"); t:SetWidth(1)
    t = edge(); t:SetPoint("TOPRIGHT"); t:SetPoint("BOTTOMRIGHT"); t:SetWidth(1)
    for _, e in ipairs(edges) do e:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    return edges
end

local function SetBorderColor(edges, r, g, b, a)
    for _, e in ipairs(edges) do e:SetColorTexture(r, g, b, a or 1) end
end

local function Panel(parent, bg, border)
    local p = CreateFrame("Frame", nil, parent)
    p.bg = Fill(p, bg or C.panel)
    if border ~= false then p.border = Border(p, border or C.border) end
    return p
end

local function Text(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.75)
    local c = color or C.text
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

local function SectionLabel(parent, text)
    local fs = Text(parent, 9, C.muted)
    fs:SetText(text)
    return fs
end

local function Icon(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return t
end

local function AddTooltip(frame, title, body)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 1, 1)
        if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function MakeButton(parent, w, h, label, accent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.bg = Fill(b, accent and C.accentBtn or C.panel2)
    b.border = Border(b, accent and C.accent or C.border)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.07)
    b.label = Text(b, 11, C.text, "CENTER")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(label)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.label:SetPoint("CENTER", 1, -1) end end)
    b:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
    function b:SetActive(on)
        if on then self:Enable() else self:Disable() end
        self:SetAlpha(on and 1 or 0.45)
    end
    return b
end

local function MakeToggle(parent, label, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    local box = CreateFrame("Frame", nil, b)
    box:SetSize(14, 14)
    box:SetPoint("LEFT")
    Fill(box, C.panel2)
    Border(box, C.border)
    local mark = box:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    mark:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    local fs = Text(b, 11, C.text)
    fs:SetPoint("LEFT", box, "RIGHT", 7, 0)
    fs:SetPoint("RIGHT")
    fs:SetText(label)
    function b:Update() mark:SetShown(get() and true or false) end
    b:SetScript("OnClick", function(self)
        set(not get())
        self:Update()
    end)
    b:Update()
    return b
end

---------------------------------------------------------------------------
-- Daten-Hilfen
---------------------------------------------------------------------------
local function Rec(key) return FriendsmithDB.chars[key] end
local function IsMine(key) local r = Rec(key); return r and r.mine or false end

local function ClassColored(text, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return text end
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5), text)
end

local function CharName(key)
    local r = Rec(key)
    return ClassColored(ns.ShortName(key), r and r.class)
end

local function CrafterNames(list)
    local t = {}
    for _, k in ipairs(list) do t[#t + 1] = CharName(k) end
    return table.concat(t, ", ")
end

local function LevelClass(key)
    local r = Rec(key)
    if not r then return "" end
    local cls = r.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[r.class] or r.class or ""
    return string.format(L["Level %s %s"], r.level or "?", cls)
end

local WISH_TAG = "|cffff8fc8" .. L["happy about help"] .. "|r"

local function Tag(key)
    if key == ns.PlayerKey() then return "|cfff2852e" .. L["You"] .. "|r" end
    if IsMine(key) then return "|cff7fb2ff" .. L["Alt"] .. "|r" end
    local r = Rec(key)
    local wish = (r and r.wish) and ("  " .. WISH_TAG) or ""
    if r and r.friend and (not r.guild or r.guild ~= GetGuildInfo("player")) then
        return "|cff66d9a6" .. L["Friend"] .. "|r" .. wish
    end
    return "|cff8f96a8" .. L["Guild"] .. "|r" .. wish
end

local function QualityColor(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function AnyMine(list)
    for _, k in ipairs(list) do if IsMine(k) then return true end end
    return false
end

local function FirstForeign(list)
    for _, k in ipairs(list) do if not IsMine(k) then return k end end
end

local function OpenChat(text)
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(text)
    else
        ns.Print(text)
    end
end

-- Ziel zum Fluestern: am besten der Absendername, wie ihn der Server bei der letzten Addon-Nachricht
-- gemeldet hat. Den Realm haengen wir selbst nie an – WoW Forever kennt die API-Realmnamen nicht.
local function WhisperTarget(key, sender)
    local r = Rec(key)
    local s = sender or (r and r.sender)
    if s and s ~= "" then
        return (s:gsub("%-[^%-]*$", ""))
    end
    return ns.ShortName(key)
end

local function Whisper(key, msg, sender)
    local target = WhisperTarget(key, sender)
    msg = msg or ""
    -- Fluesterfenster direkt oeffnen (klappt auch mit Leerzeichen im Namen)
    if ChatFrame_SendTell and ChatEdit_GetActiveWindow then
        ChatFrame_SendTell(target)
        local eb = ChatEdit_GetActiveWindow()
        if eb then
            eb:Insert(msg)
            return
        end
    end
    OpenChat("/w " .. target .. " " .. msg)
end

local function AgeText(t)
    local s = math.max(0, ns.Now() - (t or 0))
    if s < 3600 then return string.format(L["%d min"], math.max(1, math.floor(s / 60))) end
    if s < 86400 then return string.format(L["%d h"], math.floor(s / 3600)) end
    return string.format(L["%d d"], math.floor(s / 86400))
end

local function ItemLinkOrName(id)
    local d = ns.ItemData(id)
    return d and d.link or (d and d.name) or ("item " .. id)
end

local function LinkInChat(itemID)
    local d = ns.ItemData(itemID)
    if not d then return end
    if not (ChatEdit_InsertLink and ChatEdit_InsertLink(d.link)) then OpenChat(d.link) end
end

-- kurz fuer Listen: "+5", "+12%", "neu"
local function DiffText(e)
    if not e.cur then return L["new"] end
    if e.pct and e.pct >= 999 then return "++" end
    if e.mode == "stat" then return "+" .. e.pct .. "%" end
    return "+" .. e.diff
end

-- lang fuer Texte: "+5 iLvl", "+12 % besser"
local function GainText(e)
    if not e.cur then return L["empty slot"] end
    if e.mode == "stat" then
        if e.pct >= 999 then return L["much better"] end
        return string.format(L["+%d%% better"], e.pct)
    end
    return "+" .. e.diff .. " iLvl"
end

ns.Style = {
    C = C, FONT = FONT, EMPTY_ICON = EMPTY_ICON, SLOT_NAMES = SLOT_NAMES,
    Fill = Fill, Border = Border, Text = Text, Icon = Icon, SectionLabel = SectionLabel,
    MakeButton = MakeButton, CharName = CharName, CrafterNames = CrafterNames,
    QualityColor = QualityColor, DiffText = DiffText, GainText = GainText, IsMine = IsMine,
}

---------------------------------------------------------------------------
-- Zustand
---------------------------------------------------------------------------
local f, list, detail, sidebar, status
local rows, flat = {}, {}
local offset, numRows = 0, 0
local view, groupBy, query = "mine", "target", ""
local selKey, selEntry
local showSettings = false
local lastRecipeHint
local counts = { all = 0, mine = 0, help = 0, food = 0, requests = 0, stock = 0, profs = 0, feed = 0 }
local feedEntries = {}
local helperGroups = {}
local enchSlots, deItems = {}, {}
local rosterCache = {}
local profEntries = {}
local stockEntries = {}
local reqEntries = {}
local foodGroups = {}

local Rebuild, RenderList, RenderDetail, CreateUI

local function EntryKey(e)
    if e.food then return "food#" .. e.itemID end
    if e.request then return "req#" .. e.r.id end
    if e.stock then return "stock#" .. e.itemID end
    if e.prof then return "prof#" .. e.key .. ":" .. e.name end
    if e.feedEntry then return "feed#" .. e.f.id end
    if e.helper then return "helper#" .. (e.topic or "new") .. ":" .. e.key end
    if e.enchSlot then return "ench#" .. e.key .. ":" .. e.slot end
    if e.deItem then return "de#" .. e.itemID end
    return e.target .. "#" .. e.itemID
end

local bestHelp = {} -- "Ich kann craften": nur das beste Teil je Spieler und Platz

local function InView(e, v)
    if v == "mine" then return IsMine(e.target) end
    if v == "help" then return bestHelp[e] == true end
    return true
end

local function Matches(e)
    if query == "" then return true end
    local d = ns.ItemData(e.itemID)
    if d and d.name:lower():find(query, 1, true) then return true end
    if e.enchSlot or e.deItem then
        return (e.key and ns.ShortName(e.key):lower():find(query, 1, true) ~= nil)
            or (e.slot and (SLOT_NAMES[e.slot] or ""):lower():find(query, 1, true) ~= nil) or false
    elseif e.helper then
        return ns.ShortName(e.key):lower():find(query, 1, true) ~= nil
            or (e.topic and ns.TopicLabel(e.topic):lower():find(query, 1, true) ~= nil) or false
    elseif e.feedEntry then
        return ns.FeedText(e.f, true):lower():find(query, 1, true) ~= nil
    elseif e.prof then
        if e.name:lower():find(query, 1, true) then return true end
    elseif e.stock then
        -- nur Name und Handwerker (unten)
    elseif e.request then
        if ns.ShortName(e.r.from):lower():find(query, 1, true) then return true end
        for _, m in ipairs(e.r.mats) do
            local md = ns.ItemData(m[1])
            if md and md.name:lower():find(query, 1, true) then return true end
        end
    elseif e.food then
        if e.label:lower():find(query, 1, true) then return true end
    else
        if ns.ShortName(e.target):lower():find(query, 1, true) then return true end
        if (SLOT_NAMES[e.slot] or ""):lower():find(query, 1, true) then return true end
    end
    for _, k in ipairs(e.crafters) do
        if ns.ShortName(k):lower():find(query, 1, true) then return true end
    end
    return false
end

local function GroupOrder(a, b)
    local me = ns.PlayerKey()
    if (a == me) ~= (b == me) then return a == me end
    local ma, mb = IsMine(a), IsMine(b)
    if ma ~= mb then return ma end
    local wa, wb = ns.Wishes(a), ns.Wishes(b)
    if wa ~= wb then return wa end
    return a < b
end

---------------------------------------------------------------------------
-- Liste aufbauen
---------------------------------------------------------------------------
function Rebuild()
    local results = ns.GetResults() or {}
    ns.S.collapsed = ns.S.collapsed or {}

    counts.all, counts.mine, counts.help = #results, 0, 0
    bestHelp = ns.BestCraftable(results)
    selEntry = nil
    for _, e in ipairs(results) do
        if InView(e, "mine") then counts.mine = counts.mine + 1 end
        if InView(e, "help") then counts.help = counts.help + 1 end
        if selKey and EntryKey(e) == selKey then selEntry = e end
    end
    foodGroups = ns.FoodList()
    counts.food = 0
    for _, g in ipairs(foodGroups) do
        counts.food = counts.food + #g.items
        for _, e in ipairs(g.items) do
            if selKey and EntryKey(e) == selKey then selEntry = e end
        end
    end
    wipe(reqEntries)
    for _, r in ipairs(ns.OpenRequests()) do
        local e = { request = true, r = r, itemID = r.item, crafters = {} }
        reqEntries[#reqEntries + 1] = e
        if selKey and EntryKey(e) == selKey then selEntry = e end
    end
    counts.requests = #reqEntries
    -- Verzauberungen: freie Plaetze und Teile zum Entzaubern
    enchSlots = ns.FreeEnchantSlots and ns.FreeEnchantSlots() or {}
    deItems = ns.DisenchantCandidates and ns.DisenchantCandidates() or {}
    counts.ench = #enchSlots + #deItems
    for _, list in ipairs({ enchSlots, deItems }) do
        for _, e in ipairs(list) do
            e.crafters = e.crafters or {}
            if selKey and EntryKey(e) == selKey then selEntry = e end
        end
    end

    -- Helfer und neue Mitglieder
    helperGroups = {}
    counts.helpers = 0
    local byTopic, roster = ns.HelperList()
    rosterCache = roster or {}
    local newbies = ns.NewcomerList(rosterCache)
    if #newbies > 0 then
        local items = {}
        for _, n in ipairs(newbies) do
            items[#items + 1] = { helper = true, newcomer = true, key = n.key, name = n.name, online = n.online, level = n.level, t = n.t, crafters = {} }
        end
        helperGroups[#helperGroups + 1] = { ck = "helpers:new", label = L["New in the guild"], items = items }
    end
    local seen = {}
    for _, t in ipairs(ns.HELP_TOPICS) do
        local list = byTopic[t]
        if list and #list > 0 then
            local items = {}
            for _, h in ipairs(list) do
                items[#items + 1] = { helper = true, topic = t, key = h.key, online = h.online, level = h.level, crafters = {} }
                if not seen[h.key] then seen[h.key] = true; counts.helpers = counts.helpers + 1 end
            end
            helperGroups[#helperGroups + 1] = { ck = "helpers:" .. t, label = ns.TopicLabel(t), items = items }
        end
    end
    for _, g in ipairs(helperGroups) do
        for _, e in ipairs(g.items) do
            if selKey and EntryKey(e) == selKey then selEntry = e end
        end
    end

    feedEntries = {}
    counts.feed = 0
    for _, f in ipairs(ns.FeedEntries()) do
        local e = { feedEntry = true, f = f, itemID = type(f.a) == "number" and f.a or nil, crafters = {} }
        feedEntries[#feedEntries + 1] = e
        if ns.Now() - f.t < 86400 then counts.feed = counts.feed + 1 end
        if selKey and EntryKey(e) == selKey then selEntry = e end
    end
    profEntries = ns.ProfHelpList()
    counts.profs = #profEntries
    for _, e in ipairs(profEntries) do
        if selKey and EntryKey(e) == selKey then selEntry = e end
    end
    stockEntries = ns.StockList()
    counts.stock = 0
    for _, e in ipairs(stockEntries) do
        if e.missing > 0 then counts.stock = counts.stock + 1 end
        if selKey and EntryKey(e) == selKey then selEntry = e end
    end
    if not selEntry then selKey = nil end

    local groups, order = {}, {}
    local grouped = view ~= "food" and view ~= "requests" and view ~= "stock" and view ~= "profs" and view ~= "feed" and view ~= "helpers" and view ~= "ench"
    for _, e in ipairs(grouped and results or {}) do
        if InView(e, view) and Matches(e) then
            local keys
            if groupBy == "crafter" then
                keys = {}
                for _, k in ipairs(e.crafters) do
                    if view ~= "help" or IsMine(k) then keys[#keys + 1] = k end
                end
            else
                keys = { e.target }
            end
            for _, k in ipairs(keys) do
                local g = groups[k]
                if not g then
                    g = {}
                    groups[k] = g
                    order[#order + 1] = k
                end
                g[#g + 1] = e
            end
        end
    end
    table.sort(order, GroupOrder)

    if view == "requests" or view == "profs" then
        for _, e in ipairs(view == "profs" and profEntries or reqEntries) do
            if Matches(e) then
                local k = e.prof and e.key or e.r.from
                if not groups[k] then groups[k] = {}; order[#order + 1] = k end
                table.insert(groups[k], e)
            end
        end
        table.sort(order, GroupOrder)
    end

    wipe(flat)
    if view == "ench" then
        for _, g in ipairs({ { "ench:slots", L["Free enchant slots"], enchSlots }, { "ench:de", L["Spare gear to disenchant"], deItems } }) do
            local items = {}
            for _, e in ipairs(g[3]) do if Matches(e) then items[#items + 1] = e end end
            if #items > 0 then
                local closed = ns.S.collapsed[g[1]]
                flat[#flat + 1] = { kind = "h", label = g[2], ck = g[1], n = #items, closed = closed }
                if not closed then
                    for _, e in ipairs(items) do flat[#flat + 1] = { kind = "i", e = e } end
                end
            end
        end
    end
    if view == "helpers" then
        for _, g in ipairs(helperGroups) do
            local items = {}
            for _, e in ipairs(g.items) do if Matches(e) then items[#items + 1] = e end end
            if #items > 0 then
                local closed = ns.S.collapsed[g.ck]
                flat[#flat + 1] = { kind = "h", label = g.label, ck = g.ck, n = #items, closed = closed }
                if not closed then
                    for _, e in ipairs(items) do flat[#flat + 1] = { kind = "i", e = e } end
                end
            end
        end
    end
    if view == "feed" then
        -- nach Tagen gruppiert, neueste zuerst
        local today = date("%Y%m%d", time())
        local yesterday = date("%Y%m%d", time() - 86400)
        local lastDay, h
        for _, e in ipairs(feedEntries) do
            if Matches(e) then
                local d = date("%Y%m%d", e.f.t)
                if d ~= lastDay then
                    lastDay = d
                    local label = (d == today and L["Today"]) or (d == yesterday and L["Yesterday"]) or date("%d.%m.", e.f.t)
                    local ck = "feed:" .. d
                    h = { kind = "h", label = label, ck = ck, n = 0, closed = ns.S.collapsed[ck] }
                    flat[#flat + 1] = h
                end
                h.n = h.n + 1
                if not h.closed then flat[#flat + 1] = { kind = "i", e = e } end
            end
        end
    end
    if view == "food" then
        for _, g in ipairs(foodGroups) do
            local items = {}
            for _, e in ipairs(g.items) do
                if Matches(e) then items[#items + 1] = e end
            end
            if #items > 0 then
                local ck = "food:" .. g.cat
                local closed = ns.S.collapsed[ck]
                flat[#flat + 1] = { kind = "h", food = true, label = g.label, ck = ck, n = #items, closed = closed }
                if not closed then
                    for _, e in ipairs(items) do flat[#flat + 1] = { kind = "i", e = e } end
                end
            end
        end
    end
    if view == "stock" then
        local low, ok = {}, {}
        for _, e in ipairs(stockEntries) do
            if Matches(e) then table.insert(e.missing > 0 and low or ok, e) end
        end
        for _, g in ipairs({ { "stock:low", L["Below target"], low }, { "stock:ok", L["Stocked"], ok } }) do
            if #g[3] > 0 then
                local closed = ns.S.collapsed[g[1]]
                flat[#flat + 1] = { kind = "h", label = g[2], ck = g[1], n = #g[3], closed = closed }
                if not closed then
                    for _, e in ipairs(g[3]) do flat[#flat + 1] = { kind = "i", e = e } end
                end
            end
        end
    end
    for _, k in ipairs(order) do
        local ck = ((view == "requests" or view == "profs") and view or groupBy) .. ":" .. k
        local closed = ns.S.collapsed[ck]
        flat[#flat + 1] = { kind = "h", key = k, ck = ck, n = #groups[k], closed = closed }
        if not closed then
            for _, e in ipairs(groups[k]) do flat[#flat + 1] = { kind = "i", e = e } end
        end
    end

    local maxOff = math.max(0, #flat - numRows)
    offset = math.max(0, math.min(offset, maxOff))
    list.scroll:SetMinMaxValues(0, maxOff)
    list.scroll:SetShown(maxOff > 0)
    list.scroll:SetValue(offset)
    list.empty:SetShown(#flat == 0)
    if #flat == 0 then
        if query ~= "" then
            list.empty:SetText(string.format(L["Nothing found for \"%s\"."], query))
        elseif view == "ench" then
            list.empty:SetText(L["Nothing to enchant or disenchant right now.\n\nEnchanters: open your enchanting window once\nso your guild sees your formulas."])
        elseif view == "helpers" then
            list.empty:SetText(L["Nobody has set up a helper profile yet.\n\nTell your guild what you're happy to help with:\nSettings → Helper profile."])
        elseif view == "feed" then
            list.empty:SetText(L["Nothing in the guild feed yet.\n\nProfession steps, level milestones, finished\nmat requests and thank-yous show up here."])
        elseif view == "profs" then
            list.empty:SetText(L["No profession data yet.\n\nEveryone with Friendsmith 0.9 shares their skill\nwhen they open their profession window."])
        elseif view == "stock" then
            list.empty:SetText(ns.CanSetTargets() and L["No stock targets yet.\n\nAdd items above: shift-click an item\n(or type its name) and enter an amount."]
                or L["Your guild hasn't set any stock targets yet.\n\nThe guild master and officers can set\nminimum amounts for the guild bank here."])
        elseif view == "requests" then
            list.empty:SetText(L["No open mat requests in your guild.\n\nIn the details of an upgrade you can\nask your guild for missing mats."])
        elseif view == "food" then
            list.empty:SetText(L["No buff food known yet.\n\nOpen the cooking window once on each\nof your cooks and sync with your guild."])
        elseif view == "help" then
            list.empty:SetText(L["None of your characters can craft\nanyone an upgrade right now.\n\nOpen your profession windows so your\nrecipes get recorded."])
        elseif view == "mine" then
            list.empty:SetText(L["Nobody can craft you an upgrade right now.\n\nSync with your guild to see\ntheir recipes."])
        else
            list.empty:SetText(L["No upgrades found yet.\n\nOpen the profession window once on each\nof your crafters and sync with your guild."])
        end
    end

    -- Seitenleiste
    for _, nb in ipairs(sidebar.nav) do
        nb.count:SetText(counts[nb.view] or 0)
        local on = (nb.view == view)
        nb.sel:SetShown(on)
        nb.bar:SetShown(on)
        nb.label:SetTextColor(on and 1 or C.text[1], on and 1 or C.text[2], on and 1 or C.text[3])
    end
    if stv then
        for _, t in ipairs(stv.toggles) do t:Update() end
        stv.diffValue:SetText("+" .. ns.S.minDiff)
    end
    sidebar.gear:SetActive(not showSettings)

    -- Gruppieren-Schalter
    list.groupLabel:SetShown(grouped)
    list.addBar:SetShown(view == "stock" and ns.CanSetTargets())
    list.thankBar:SetShown(view == "feed")
    if view == "feed" then
        local tl = ns.HelpTally and ns.HelpTally(7) or { people = 0 }
        list.thankBar.count:SetText(string.format(L["Thanks received: %d"], ns.S.thanksReceived or 0) .. "  ·  " .. string.format(L["Helped this week: %d"], tl.people))
    end
    for _, sb in ipairs(list.seg) do
        sb:SetShown(grouped)
        local on = (sb.mode == groupBy)
        sb.bg:SetColorTexture(on and C.accentBtn[1] or C.panel2[1], on and C.accentBtn[2] or C.panel2[2],
            on and C.accentBtn[3] or C.panel2[3], 1)
    end

    local st = ns.stats or { targets = 0, crafters = 0 }
    status.left:SetText(string.format(L["%d upgrades  ·  %d characters  ·  %d crafters%s"],
        counts.all, st.targets, st.crafters, ns.pending and "  ·  |cfff2852e" .. L["loading item data …"] .. "|r" or ""))

    RenderList()
    RenderDetail()
end

function RenderList()
    for i = 1, numRows do
        local r = rows[i]
        local it = flat[offset + i]
        r.item = it
        if not it then
            r:Hide()
        else
            r:Show()
            local isHeader = it.kind == "h"
            r.hbg:SetShown(isHeader)
            r.exp:SetShown(isHeader)
            r.title:SetShown(isHeader)
            r.sub:SetShown(isHeader)
            r.count:SetShown(isHeader)
            r.icon:SetShown(not isHeader)
            r.name:SetShown(not isHeader)
            r.meta:SetShown(not isHeader)
            r.gain:SetShown(not isHeader)

            if isHeader then
                r.exp:SetTexture(it.closed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
                if it.label then
                    r.title:SetText("|cffffd140" .. it.label .. "|r")
                    r.sub:SetText("")
                else
                    r.title:SetText(CharName(it.key))
                    local rec = Rec(it.key)
                    r.sub:SetText((rec and rec.level and (L["Level "] .. rec.level) or "") .. "  " .. Tag(it.key))
                end
                r.count:SetText(it.n)
                r.sel:Hide()
                r.bar:Hide()
            else
                local e = it.e
                local d = ns.ItemData(e.itemID)
                r.icon:SetTexture(d and d.icon or EMPTY_ICON)
                r.name:SetText(d and d.name or L["Loading …"])
                r.name:SetTextColor(QualityColor(d and d.quality))
                if e.enchSlot then
                    r.meta:SetText(CharName(e.key))
                    local n = #e.enchants + #e.kits
                    r.gain:SetText("|cffffd140" .. n .. "|r")
                elseif e.deItem then
                    r.meta:SetText(#e.needs > 0 and ("|cff5cdb6b" .. L["needed"] .. "|r") or (e.wearer and ("|cffff8fc8" .. L["wearable"] .. "|r") or ""))
                    r.gain:SetText(e.bound and ("|cff8f96a8" .. L["bound"] .. "|r") or "")
                elseif e.helper then
                    r.icon:SetTexture(e.newcomer and "Interface\\Icons\\INV_Misc_Gift_01" or "Interface\\Icons\\Spell_Holy_Heal")
                    r.name:SetText(Rec(e.key) and CharName(e.key) or ns.ShortName(e.name or e.key))
                    r.name:SetTextColor(1, 1, 1)
                    if e.online then
                        r.meta:SetText("|cff5cdb6b" .. L["online"] .. "|r")
                    else
                        r.meta:SetText(e.level and (L["Level "] .. e.level) or "")
                    end
                    r.gain:SetText(e.newcomer and ("|cff8f96a8" .. AgeText(e.t) .. "|r") or "")
                elseif e.feedEntry then
                    local icons = { prof = "Interface\\Icons\\INV_Misc_Note_02", lvl = "Interface\\Icons\\Spell_Holy_Heal",
                                    req = "Interface\\Icons\\INV_Misc_Bag_10", join = "Interface\\Icons\\INV_Misc_Gift_01", thanks = "Interface\\Icons\\INV_ValentinesCard02" }
                    if not (d and (e.f.kind == "req")) then r.icon:SetTexture(icons[e.f.kind] or EMPTY_ICON) end
                    r.name:SetText(ns.FeedText(e.f))
                    r.name:SetTextColor(1, 1, 1)
                    r.meta:SetText("")
                    r.gain:SetText("|cff8f96a8" .. AgeText(e.f.t) .. "|r")
                elseif e.prof then
                    r.name:SetText(e.name .. "  |cff8f96a8" .. e.p.rank .. "/" .. e.p.max .. "|r")
                    r.name:SetTextColor(1, 1, 1)
                    if e.plan.trainer then
                        r.meta:SetText("|cffffd140" .. L["trainer"] .. "|r")
                        r.gain:SetText("")
                    else
                        r.meta:SetText(string.format(L["to %d"], e.plan.target))
                        r.gain:SetText("+" .. e.plan.points)
                    end
                elseif e.stock then
                    local col = e.missing > 0 and "|cffff6060" or "|cff5cdb6b"
                    r.meta:SetText(col .. e.have .. "|r / " .. e.target)
                    r.gain:SetText(e.missing > 0 and ("|cffff6060-" .. e.missing .. "|r") or "|cff5cdb6bOK|r")
                elseif e.request then
                    local help = false
                    if not IsMine(e.r.from) then
                        for _, m in ipairs(e.r.mats) do if ns.OwnCount(m[1]) > 0 then help = true end end
                    end
                    r.meta:SetText(help and ("|cff5cdb6b" .. L["you have some"] .. "|r") or string.format(L["%d mats"], #e.r.mats))
                    r.gain:SetText("|cff8f96a8" .. AgeText(e.r.t) .. "|r")
                elseif e.food then
                    local more = #e.crafters > 1 and (" +" .. (#e.crafters - 1)) or ""
                    r.meta:SetText(CharName(e.crafters[1]) .. more)
                    r.gain:SetText((e.rank == 1 and "|cffffd140" or "") .. ns.FoodValueText(e))
                elseif groupBy == "crafter" then
                    r.meta:SetText(CharName(e.target))
                    r.gain:SetText(DiffText(e))
                else
                    r.meta:SetText(SLOT_NAMES[e.slot] or "")
                    r.gain:SetText(DiffText(e))
                end
                local on = selKey ~= nil and EntryKey(e) == selKey
                r.sel:SetShown(on)
                r.bar:SetShown(on)
            end
        end
    end
end

local function SetOffset(v)
    local _, maxOff = list.scroll:GetMinMaxValues()
    v = math.max(0, math.min(math.floor(v + 0.5), maxOff))
    if v ~= offset then
        offset = v
        list.scroll:SetValue(v)
        RenderList()
    end
end

local function Select(e)
    showSettings = false
    if e and selKey == EntryKey(e) then e = nil end
    selKey = e and EntryKey(e) or nil
    selEntry = e
    RenderList()
    RenderDetail()
end

local function SetView(v)
    view = v
    showSettings = false
    offset = 0
    Rebuild()
end

---------------------------------------------------------------------------
-- Kopfzeile
---------------------------------------------------------------------------
local function CreateHeader()
    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT", 1, -1)
    h:SetPoint("TOPRIGHT", -1, -1)
    h:SetHeight(HEADER_H)
    Fill(h, C.header)
    local line = h:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.55)

    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() f:StartMoving() end)
    h:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local logo = Icon(h, 30)
    logo:SetPoint("LEFT", 12, 0)
    logo:SetTexture(ns.LOGO)
    logo:SetTexCoord(0, 1, 0, 1)
    local title = Text(h, 16, C.text)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, 1)
    title:SetText("Friendsmith")
    local sub = Text(h, 10, C.muted)
    sub:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 10, 0)
    sub:SetText(L["Guild crafting & upgrades"])

    local close = CreateFrame("Button", nil, h)
    close:SetSize(28, 28)
    close:SetPoint("RIGHT", -10, 0)
    local cx = Text(close, 14, C.muted, "CENTER")
    cx:SetPoint("CENTER")
    cx:SetText("X")
    close:SetScript("OnEnter", function() cx:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() cx:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    close:SetScript("OnClick", function() f:Hide() end)

    local sb = CreateFrame("EditBox", nil, h)
    sb:SetSize(230, 26)
    sb:SetPoint("RIGHT", close, "LEFT", -10, 0)
    sb:SetAutoFocus(false)
    sb:SetFont(FONT, 11, "")
    sb:SetTextColor(C.text[1], C.text[2], C.text[3])
    sb:SetTextInsets(26, 8, 0, 0)
    Fill(sb, C.bg)
    local sbBorder = Border(sb, C.border)
    local mag = sb:CreateTexture(nil, "OVERLAY")
    mag:SetSize(14, 14)
    mag:SetPoint("LEFT", 8, -1)
    mag:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    mag:SetVertexColor(0.7, 0.7, 0.75)
    local ph = Text(sb, 11, C.muted)
    ph:SetPoint("LEFT", 26, 0)
    ph:SetText(L["Search: item, name, slot …"])
    sb:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        ph:SetShown(txt == "")
        local q = txt:lower():match("^%s*(.-)%s*$") or ""
        if q ~= query then
            query = q
            offset = 0
            Rebuild()
        end
    end)
    sb:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
    end)
    sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    sb:SetScript("OnEditFocusGained", function() SetBorderColor(sbBorder, C.accent[1], C.accent[2], C.accent[3], 0.9) end)
    sb:SetScript("OnEditFocusLost", function() SetBorderColor(sbBorder, C.border[1], C.border[2], C.border[3], 1) end)
end

---------------------------------------------------------------------------
-- Seitenleiste
---------------------------------------------------------------------------
local NAV = {
    { view = "mine", label = L["For me"],         icon = "Interface\\Icons\\INV_Chest_Chain_05" },
    { view = "help", label = L["I can craft"], icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { view = "all",  label = L["Guild & friends"],      icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { view = "food", label = L["Buff food"],      icon = "Interface\\Icons\\Spell_Misc_Food" },
    { view = "requests", label = L["Mat requests"], icon = "Interface\\Icons\\INV_Misc_Bag_10" },
    { view = "stock", label = L["Guild stock"], icon = "Interface\\Icons\\INV_Box_01" },
    { view = "profs", label = L["Profession help"], icon = "Interface\\Icons\\INV_Misc_Note_02" },
    { view = "feed", label = L["Guild feed"], icon = "Interface\\Icons\\INV_Scroll_03" },
    { view = "helpers", label = L["Helpers"], icon = "Interface\\Icons\\Spell_Holy_Heal" },
    { view = "ench", label = L["Enchanting"], icon = "Interface\\Icons\\Trade_Engraving" },
}

local function CreateSidebar()
    sidebar = Panel(f, C.panel, false)
    sidebar:SetPoint("TOPLEFT", 1, -1 - HEADER_H)
    sidebar:SetPoint("BOTTOMLEFT", 1, 1 + STATUS_H)
    sidebar:SetWidth(SIDEBAR_W)
    local edge = sidebar:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetWidth(1)
    edge:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    local lbl = SectionLabel(sidebar, L["VIEW"])
    lbl:SetPoint("TOPLEFT", 14, -14)

    sidebar.nav = {}
    for i, n in ipairs(NAV) do
        local b = CreateFrame("Button", nil, sidebar)
        b:SetHeight(24)
        b:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 26)
        b:SetPoint("RIGHT", -8, 0)
        b.view = n.view
        b.sel = Fill(b, C.accentBg)
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetPoint("TOPLEFT")
        b.bar:SetPoint("BOTTOMLEFT")
        b.bar:SetWidth(2)
        b.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.05)
        local ic = Icon(b, 18)
        ic:SetPoint("LEFT", 10, 0)
        ic:SetTexture(n.icon)
        b.label = Text(b, 12, C.text)
        b.label:SetPoint("LEFT", ic, "RIGHT", 8, 0)
        b.label:SetText(n.label)
        b.count = Text(b, 10, C.muted, "RIGHT")
        b.count:SetPoint("RIGHT", -8, 0)
        b:SetScript("OnClick", function(self) SetView(self.view) end)
        sidebar.nav[i] = b
    end
    AddTooltip(sidebar.nav[1], L["For me"], L["Who can craft something better for you or your alts?"])
    AddTooltip(sidebar.nav[2], L["I can craft"], L["Who you can craft something better for with your professions – your alts and your guild."])
    AddTooltip(sidebar.nav[3], L["Guild & friends"], L["Everything anyone in your guild or among your friends can craft for anyone."])
    AddTooltip(sidebar.nav[10], L["Enchanting"], L["Unenchanted gear and which enchants or armor kits your guild can make for it – plus spare gear an enchanter could turn into mats others need."])
    AddTooltip(sidebar.nav[9], L["Helpers"], L["Who is happy to help with what – and who is new in the guild."])
    AddTooltip(sidebar.nav[8], L["Guild feed"], L["Nice moments in your guild: profession steps, level milestones, finished mat requests and thank-yous."])
    AddTooltip(sidebar.nav[7], L["Profession help"], L["Who is leveling a profession and which mats they need for the next big step."])
    AddTooltip(sidebar.nav[6], L["Guild stock"], L["Minimum amounts for the guild bank – what's missing, who can craft it and which mats are needed."])
    AddTooltip(sidebar.nav[5], L["Mat requests"], L["Mats your guild is looking for right now – and whether you have some."])
    AddTooltip(sidebar.nav[4], L["Buff food"], L["Who can cook the best \"Well Fed\" food in each category – Stamina, Spirit, Agility and so on."])

    local sync = MakeButton(sidebar, SIDEBAR_W - 20, 28, L["Sync"], true)
    sync:SetPoint("BOTTOMLEFT", 10, 12)
    sync:SetScript("OnClick", function()
        ns.Hello(true)
        ns.Print(L["Sent your data to your guild and friends and requested theirs."])
    end)
    AddTooltip(sync, L["Sync"], L["Sends your data to your guild and online friends using Friendsmith and requests theirs."])
    local gear = MakeButton(sidebar, SIDEBAR_W - 20, 24, L["Settings"])
    gear:SetPoint("BOTTOMLEFT", sync, "TOPLEFT", 0, 6)
    gear:SetScript("OnClick", function() ns.OpenSettings(true) end)
    sidebar.gear = gear
end

---------------------------------------------------------------------------
-- Liste (wie im Berufsfenster: einklappbare Gruppen)
---------------------------------------------------------------------------
local function ShowFoodTooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. e.itemID)
    GameTooltip:AddLine(" ")
    if e.rank == 1 then
        GameTooltip:AddLine(string.format(L["Best %s food you can get (%s)"], e.label, ns.FoodValueText(e)), 1, 0.82, 0.25, true)
    else
        local bd = ns.ItemData(e.best.itemID)
        GameTooltip:AddLine(string.format(L["Better: %s (%s) by %s"], bd and bd.name or "?", ns.FoodValueText(e.best), CrafterNames(e.best.crafters)), 1, 1, 1, true)
    end
    GameTooltip:AddLine(L["Cooked by: "] .. CrafterNames(e.crafters), 1, 1, 1, true)
    GameTooltip:AddLine(L["Click: details · Shift-click: link"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function ShowRequestTooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. e.itemID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format(L["%s is looking for mats (%s ago):"], CharName(e.r.from), AgeText(e.r.t)), 1, 0.82, 0.25, true)
    for _, m in ipairs(e.r.mats) do
        local md = ns.ItemData(m[1])
        local own = ns.OwnCount(m[1])
        GameTooltip:AddLine(m[2] .. "x " .. (md and md.name or "…") .. (own > 0 and ("  |cff5cdb6b" .. string.format(L["(you have %d)"], own) .. "|r") or ""), 1, 1, 1)
    end
    GameTooltip:AddLine(L["Click: details · Shift-click: link"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function ShowStockTooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. e.itemID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format(L["Guild bank: %d of %d"], e.have, e.target), 1, 0.82, 0.25)
    if e.missing > 0 then GameTooltip:AddLine(string.format(L["Missing: %d"], e.missing), 1, 0.4, 0.4) end
    GameTooltip:AddLine(L["Craftable by: "] .. (#e.crafters > 0 and CrafterNames(e.crafters) or L["nobody known"]), 1, 1, 1, true)
    GameTooltip:AddLine(L["Click: details · Shift-click: link"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function ShowEntryTooltip(owner, e)
    if e.enchSlot then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. e.itemID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(L["%s: no enchant yet"], SLOT_NAMES[e.slot] or "?"), 1, 0.82, 0.25)
        for i = 1, math.min(4, #e.enchants) do
            local x = e.enchants[i]
            GameTooltip:AddLine(ns.EnchantName(x.id) .. " – " .. CrafterNames(x.keys), 1, 1, 1, true)
        end
        if #e.kits > 0 then GameTooltip:AddLine(string.format(L["Armor kits: %d"], #e.kits), 0.9, 0.9, 0.9) end
        GameTooltip:Show()
        return
    end
    if e.deItem then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. e.itemID)
        GameTooltip:AddLine(" ")
        local m = {}
        for _, id in ipairs(e.yield.mats) do local d = ns.ItemData(id); m[#m + 1] = d and d.name or "?" end
        GameTooltip:AddLine(L["Disenchants into (estimate): "] .. table.concat(m, ", "), 1, 0.82, 0.25, true)
        if #e.needs > 0 then GameTooltip:AddLine(string.format(L["Needed by %d"], #e.needs), 0.36, 0.86, 0.42) end
        if e.wearer then GameTooltip:AddLine(string.format(L["%s could wear this!"], ns.ShortName(e.wearer.key)), 1, 0.56, 0.78) end
        GameTooltip:Show()
        return
    end
    if e.helper then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(Rec(e.key) and CharName(e.key) or ns.ShortName(e.name or e.key), 1, 1, 1)
        if e.newcomer then GameTooltip:AddLine(string.format(L["New in the guild (%s ago)"], AgeText(e.t)), 1, 0.82, 0.25) end
        local r = Rec(e.key)
        if r and r.help then
            local t = {}
            for _, k in ipairs(ns.HELP_TOPICS) do if r.help[k] then t[#t + 1] = ns.TopicLabel(k) end end
            GameTooltip:AddLine(L["Happy to help with: "] .. table.concat(t, ", "), 1, 0.56, 0.78, true)
        end
        GameTooltip:Show()
        return
    end
    if e.feedEntry then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.FeedText(e.f), 1, 1, 1, true)
        GameTooltip:AddLine(string.format(L["%s ago"], AgeText(e.f.t)), 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    if e.prof then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(CharName(e.key) .. " – " .. e.name .. " " .. e.p.rank .. "/" .. e.p.max, 1, 1, 1)
        if e.plan.trainer then
            GameTooltip:AddLine(string.format(L["Needs a trainer to go beyond %d."], e.p.max), 1, 0.82, 0.25, true)
        else
            GameTooltip:AddLine(string.format(L["%d points to %d"], e.plan.points, e.plan.target), 1, 0.82, 0.25)
            local o = e.plan.options[1]
            if o then GameTooltip:AddLine(string.format(L["Suggestion: ~%dx %s"], o.crafts, ItemLinkOrName(o.itemID)), 1, 1, 1, true) end
        end
        GameTooltip:AddLine(string.format(L["Updated %s ago"], AgeText(e.p.t)), 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    if e.stock then return ShowStockTooltip(owner, e) end
    if e.request then return ShowRequestTooltip(owner, e) end
    if e.food then return ShowFoodTooltip(owner, e) end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. e.itemID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["For: "] .. CharName(e.target), 1, 1, 1)
    local cd = e.cur and ns.ItemData(e.cur)
    if cd then
        GameTooltip:AddLine(L["Wearing: "] .. cd.link .. " (iLvl " .. cd.ilvl .. ")", 1, 1, 1)
    else
        GameTooltip:AddLine(L["Slot is empty"], 1, 1, 1)
    end
    GameTooltip:AddLine(L["Improvement: "] .. GainText(e) .. "  (" .. ns.SpecLabel(e.target) .. ")", 0.36, 0.86, 0.42)
    local tr = Rec(e.target)
    local diffs = ns.StatDiffText(ns.ItemStats(e.itemID), e.cur and ns.ItemStats(e.cur, tr and tr.suffix and tr.suffix[e.slot]), ns.WeightsFor(e.target))
    if diffs ~= "" then GameTooltip:AddLine(diffs, 1, 1, 1, true) end
    GameTooltip:AddLine(L["Craftable by: "] .. CrafterNames(e.crafters), 1, 1, 1, true)
    GameTooltip:AddLine(L["Click: details · Shift-click: link · Ctrl-click: try on"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

ns.ShowEntryTooltip = ShowEntryTooltip

local function MakeEdit(parent, w, placeholder, numeric)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(w, 22)
    e:SetAutoFocus(false)
    e:SetFont(FONT, 11, "")
    e:SetTextColor(C.text[1], C.text[2], C.text[3])
    e:SetTextInsets(6, 6, 0, 0)
    if numeric and e.SetNumeric then e:SetNumeric(true) end
    if numeric then e:SetMaxLetters(4) end
    Fill(e, C.bg)
    e.border = Border(e, C.border)
    local ph = Text(e, 10, C.muted)
    ph:SetPoint("LEFT", 6, 0)
    ph:SetText(placeholder or "")
    e:SetScript("OnTextChanged", function(self) ph:SetShown((self:GetText() or "") == "") end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function(self) SetBorderColor(self.border, C.accent[1], C.accent[2], C.accent[3], 0.9) end)
    e:SetScript("OnEditFocusLost", function(self) SetBorderColor(self.border, C.border[1], C.border[2], C.border[3], 1) end)
    return e
end

-- Gegenstand aus Link, ID oder (zwischengespeichertem) Namen
local function ParseItem(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return nil end
    local id = tonumber(text:match("item:(%d+)")) or tonumber(text)
    if id then return id end
    local GII = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local _, link = GII(text)
    return link and tonumber(link:match("item:(%d+)"))
end
ns.ParseItem = ParseItem

local activeItemBox -- bekommt Shift-Klick-Links, solange es den Fokus hat
if hooksecurefunc and ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if activeItemBox and activeItemBox:IsVisible() and activeItemBox:HasFocus() and link then
            activeItemBox:SetText(link)
        end
    end)
end

local function CreateList()
    list = Panel(f, C.bg, false)
    list:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    list:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
    list:SetWidth(LIST_W)
    local edge = list:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetWidth(1)
    edge:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    -- Gruppieren
    local gl = SectionLabel(list, L["GROUP BY"])
    gl:SetPoint("TOPLEFT", 12, -16)
    list.groupLabel = gl

    -- Gildenlager: Ziel hinzufuegen (nur Offiziere)
    local bar = CreateFrame("Frame", nil, list)
    bar:SetPoint("TOPLEFT", 10, -10)
    bar:SetPoint("TOPRIGHT", -10, -10)
    bar:SetHeight(22)
    local itemBox = MakeEdit(bar, 186, L["Shift-click an item or type its name"])
    itemBox:SetPoint("LEFT")
    itemBox:HookScript("OnEditFocusGained", function(self) activeItemBox = self end)
    local amountBox = MakeEdit(bar, 50, L["Amount"], true)
    amountBox:SetPoint("LEFT", itemBox, "RIGHT", 6, 0)
    local add = MakeButton(bar, 62, 22, L["Add"], true)
    add:SetPoint("LEFT", amountBox, "RIGHT", 6, 0)
    local function submit()
        local id = ParseItem(itemBox:GetText())
        local n = tonumber(amountBox:GetText())
        if not id then ns.Print(L["Item not found – shift-click it from your bags or a link."]); return end
        if not n or n < 1 then ns.Print(L["Enter an amount."]); return end
        if ns.SetTarget(id, n) then
            itemBox:SetText(""); amountBox:SetText("")
            itemBox:ClearFocus(); amountBox:ClearFocus()
        end
    end
    add:SetScript("OnClick", submit)
    itemBox:SetScript("OnEnterPressed", function() amountBox:SetFocus() end)
    amountBox:SetScript("OnEnterPressed", submit)
    AddTooltip(add, L["Add stock target"], L["Sets how many of this item should be in the guild bank. Only the guild master and officers can do this."])
    bar:Hide()
    list.addBar = bar

    -- Gilden-Feed: Danke sagen
    local tb = CreateFrame("Frame", nil, list)
    tb:SetPoint("TOPLEFT", 10, -10)
    tb:SetPoint("TOPRIGHT", -10, -10)
    tb:SetHeight(22)
    local nameBox = MakeEdit(tb, 140, L["Name (or your target)"])
    nameBox:SetPoint("LEFT")
    local thx = MakeButton(tb, 70, 22, L["Thanks!"], true)
    thx:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
    local function thank()
        local name = (nameBox:GetText() or ""):match("^%s*(.-)%s*$")
        if name == "" then name = UnitName and UnitName("target") or "" end
        if not name or name == "" then ns.Print(L["Enter a name or target the player."]); return end
        if ns.Thank(name) then nameBox:SetText(""); nameBox:ClearFocus() end
    end
    thx:SetScript("OnClick", thank)
    nameBox:SetScript("OnEnterPressed", thank)
    AddTooltip(thx, L["Say thanks"], L["Thanks someone for their help. It shows up in the guild feed and they get a short note."])
    tb.count = Text(tb, 10, C.muted, "RIGHT")
    tb.count:SetPoint("RIGHT")
    tb:Hide()
    list.thankBar = tb
    list.seg = {}
    local modes = { { "target", L["Recipient"] }, { "crafter", L["Crafter"] } }
    for i, m in ipairs(modes) do
        local b = MakeButton(list, 90, 22, m[2])
        b.mode = m[1]
        if i == 1 then
            b:SetPoint("TOPRIGHT", list, "TOPRIGHT", -102, -10)
        else
            b:SetPoint("LEFT", list.seg[1], "RIGHT", -1, 0)
        end
        b:SetScript("OnClick", function(self)
            groupBy = self.mode
            offset = 0
            Rebuild()
        end)
        list.seg[i] = b
    end

    local area = CreateFrame("Frame", nil, list)
    area:SetPoint("TOPLEFT", 6, -42)
    area:SetPoint("BOTTOMRIGHT", -6, 6)
    list.area = area

    local areaH = H - 2 - HEADER_H - STATUS_H - 42 - 6
    numRows = math.floor(areaH / ROW_H)

    for i = 1, numRows do
        local r = CreateFrame("Button", nil, area)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("RIGHT", area, "RIGHT", -10, 0)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        r.hbg = Fill(r, C.panel2)
        r.sel = Fill(r, C.accentBg, "BACKGROUND", 1)
        r.bar = r:CreateTexture(nil, "ARTWORK")
        r.bar:SetPoint("TOPLEFT")
        r.bar:SetPoint("BOTTOMLEFT")
        r.bar:SetWidth(2)
        r.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.06)

        -- Gruppenkopf
        r.exp = r:CreateTexture(nil, "ARTWORK")
        r.exp:SetSize(14, 14)
        r.exp:SetPoint("LEFT", 4, 0)
        r.title = Text(r, 12)
        r.title:SetPoint("LEFT", 22, 0)
        r.sub = Text(r, 10, C.muted)
        r.sub:SetPoint("LEFT", r.title, "RIGHT", 8, 0)
        r.count = Text(r, 10, C.muted, "RIGHT")
        r.count:SetPoint("RIGHT", -8, 0)

        -- Eintrag
        r.icon = Icon(r, 16)
        r.icon:SetPoint("LEFT", 22, 0)
        r.gain = Text(r, 11, C.green, "RIGHT")
        r.gain:SetPoint("RIGHT", -6, 0)
        r.gain:SetWidth(40)
        r.meta = Text(r, 10, C.muted, "RIGHT")
        r.meta:SetPoint("RIGHT", r.gain, "LEFT", -6, 0)
        r.meta:SetWidth(76)
        r.name = Text(r, 11)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetPoint("RIGHT", r.meta, "LEFT", -6, 0)

        r:SetScript("OnClick", function(self, btn)
            local it = self.item
            if not it then return end
            if it.kind == "h" then
                ns.S.collapsed[it.ck] = not it.closed or nil
                Rebuild()
                return
            end
            local d = ns.ItemData(it.e.itemID)
            if d and IsModifiedClick and HandleModifiedItemClick
                and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP")) then
                HandleModifiedItemClick(d.link)
                return
            end
            if d and IsShiftKeyDown() then LinkInChat(it.e.itemID); return end
            Select(it.e)
            -- kannst du es selbst herstellen? Dann zum Rezept im Berufsfenster springen
            local me = ns.PlayerKey()
            local canCraft = false
            for _, k in ipairs(it.e.crafters or {}) do if k == me then canCraft = true end end
            if canCraft and it.e.itemID and ns.OpenRecipe and not ns.OpenRecipe(it.e.itemID) then
                if not lastRecipeHint or GetTime() - lastRecipeHint > 10 then
                    lastRecipeHint = GetTime()
                    ns.Print(L["Open the matching profession window – Friendsmith will jump straight to the recipe."])
                end
            end
        end)
        r:SetScript("OnEnter", function(self)
            local it = self.item
            if it and it.kind == "i" then ShowEntryTooltip(self, it.e) end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
    end

    -- Scrollleiste
    local s = CreateFrame("Slider", nil, area)
    s:SetOrientation("VERTICAL")
    s:SetWidth(5)
    s:SetPoint("TOPRIGHT", 0, 0)
    s:SetPoint("BOTTOMRIGHT", 0, 0)
    Fill(s, C.panel2)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.8)
    thumb:SetSize(5, 40)
    s:SetThumbTexture(thumb)
    s:SetValueStep(1)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:SetMinMaxValues(0, 0)
    s:SetValue(0)
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        if v ~= offset then
            offset = v
            RenderList()
        end
    end)
    list.scroll = s

    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(_, delta) SetOffset(offset - delta * 3) end)

    list.empty = Text(list, 12, C.muted, "CENTER")
    list.empty:SetPoint("CENTER", 0, 20)
    list.empty:SetWidth(LIST_W - 30)
    if list.empty.SetWordWrap then list.empty:SetWordWrap(true) end
end

---------------------------------------------------------------------------
-- Detailbereich
---------------------------------------------------------------------------
local ov, it, fd, rq, sk, ph, fv, stv, hp, en -- ... / Einstellungen / Helfer / Verzauberung

-- Zutatenliste: "4x Dunkles Leder   du 3 · Bank 6  fehlt 1"
local function CreateMatsBlock(parent, top, title)
    local b = { rows = {} }
    b.label = SectionLabel(parent, title)
    b.label:SetPoint("TOPLEFT", 18, top)
    b.note = Text(parent, 9, C.muted, "RIGHT")
    b.note:SetPoint("TOPRIGHT", -18, top)
    for i = 1, MAX_MAT_ROWS do
        local r = CreateFrame("Button", nil, parent)
        r:SetHeight(14)
        r:SetPoint("TOPLEFT", 18, top - 14 - (i - 1) * 14)
        r:SetPoint("RIGHT", -18, 0)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.05)
        r.icon = Icon(r, 12)
        r.icon:SetPoint("LEFT", 2, 0)
        r.state = r:CreateTexture(nil, "ARTWORK")
        r.state:SetSize(12, 12)
        r.state:SetPoint("RIGHT", -2, 0)
        r.info = Text(r, 10, C.muted, "RIGHT")
        r.info:SetPoint("RIGHT", r.state, "LEFT", -4, 0)
        r.name = Text(r, 10)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
        r.name:SetPoint("RIGHT", r.info, "LEFT", -6, 0)
        r:SetScript("OnEnter", function(self)
            if not self.id then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.id)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function(self) if self.id and IsShiftKeyDown() then LinkInChat(self.id) end end)
        b.rows[i] = r
    end
    b.empty = Text(parent, 10, C.muted)
    b.empty:SetPoint("TOPLEFT", 18, top - 16)
    b.empty:SetPoint("RIGHT", -18, 0)
    if b.empty.SetWordWrap then b.empty:SetWordWrap(true) end
    return b
end

-- Zeigt die Zutaten und gibt zurueck, was fehlt ({ {id, anzahl}, ... }); nil = Zutaten unbekannt
local function RenderMats(b, mats)
    local bt = ns.GuildBankTime()
    if bt then
        b.note:SetText(string.format(L["guild bank: %s ago"], AgeText(bt)))
    else
        b.note:SetText(IsInGuild() and L["guild bank not seen yet"] or "")
    end
    if not mats then
        for _, r in ipairs(b.rows) do r:Hide() end
        b.empty:SetText(L["Mats unknown – the crafter needs Friendsmith 0.7 or newer and has to open the profession window once."])
        b.empty:Show()
        return nil
    end
    b.empty:Hide()
    local missing = {}
    for i, m in ipairs(mats) do
        local id, need = m[1], m[2]
        local own, bank = ns.OwnCount(id), ns.GuildBankCount(id)
        local miss = math.max(0, need - own - bank)
        if miss > 0 then missing[#missing + 1] = { id, miss } end
        local r = b.rows[i]
        if r then
            local d = ns.ItemData(id)
            r.id = id
            r.icon:SetTexture(d and d.icon or EMPTY_ICON)
            r.name:SetText(need .. "x " .. (d and d.name or "…"))
            r.name:SetTextColor(QualityColor(d and d.quality))
            local info = string.format(L["you %d · bank %d"], own, bank)
            if miss > 0 then info = info .. "  |cffff6060" .. string.format(L["missing %d"], miss) .. "|r" end
            r.info:SetText(info)
            r.state:SetTexture(miss > 0 and "Interface\\RaidFrame\\ReadyCheck-NotReady" or "Interface\\RaidFrame\\ReadyCheck-Ready")
            r:Show()
        end
    end
    for i = #mats + 1, #b.rows do b.rows[i]:Hide() end
    return missing
end

-- Gesuch anlegen (fuer alle mit Friendsmith sichtbar) und Text fuer den Gildenchat vorbereiten
local function AskGuildForMats(itemID, missing)
    ns.CreateRequest(itemID, missing)
    local function build(withLinks)
        local parts = {}
        for _, m in ipairs(missing) do
            local d = ns.ItemData(m[1])
            parts[#parts + 1] = m[2] .. "x " .. ((withLinks and d and d.link) or (d and d.name) or "?")
        end
        return ns.Subst(L["Looking for mats for {item}: {mats} – can anyone help?"],
            { item = ItemLinkOrName(itemID), mats = table.concat(parts, ", ") })
    end
    local msg = build(true)
    if #msg > 250 then msg = build(false) end
    OpenChat("/g " .. msg)
    ns.Print(L["Mat request saved – your guild sees it in Friendsmith under \"Mat requests\". Press Enter to also post it in guild chat."])
end

local function StatCard(parent, label, icon)
    local p = Panel(parent, C.panel2)
    p:SetHeight(54)
    local ic = Icon(p, 30)
    ic:SetPoint("LEFT", 10, 0)
    ic:SetTexture(icon)
    local l = SectionLabel(p, label)
    l:SetPoint("TOPLEFT", ic, "TOPRIGHT", 10, -1)
    p.value = Text(p, 17, C.text)
    p.value:SetPoint("BOTTOMLEFT", ic, "BOTTOMRIGHT", 10, -1)
    return p
end

local function CreateOverview(parent)
    ov = CreateFrame("Frame", nil, parent)
    ov:SetAllPoints()

    local t = Text(ov, 16, C.text)
    t:SetPoint("TOPLEFT", 18, -16)
    t:SetText(L["Overview"])
    ov.who = Text(ov, 11, C.muted)
    ov.who:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)

    local cw = (W - 2 - SIDEBAR_W - LIST_W - 36 - 10) / 2
    ov.cards = {
        StatCard(ov, L["FOR ME"], "Interface\\Icons\\INV_Chest_Chain_05"),
        StatCard(ov, L["I CAN CRAFT"], "Interface\\Icons\\Trade_BlackSmithing"),
        StatCard(ov, L["HELPED THIS WEEK"], "Interface\\Icons\\Spell_Holy_Heal"),
        StatCard(ov, L["GUILD & FRIENDS"], "Interface\\Icons\\INV_Misc_Gear_01"),
    }
    for i, c in ipairs(ov.cards) do
        c:SetWidth(cw)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        c:SetPoint("TOPLEFT", 18 + col * (cw + 10), -62 - row * 64)
    end

    local hc = ov.cards[3]
    hc:EnableMouse(true)
    hc:SetScript("OnEnter", function(self)
        local t = self.tally or {}
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Your help this week"], 1, 1, 1)
        GameTooltip:AddLine(string.format(L["People you helped: %d"], t.people or 0), 1, 0.82, 0.25)
        GameTooltip:AddLine(string.format(L["Given in trades: %d · Thank-yous: %d"], t.trade or 0, t.thanks or 0), 0.9, 0.9, 0.9)
        GameTooltip:AddLine(string.format(L["Help offered: %d · Welcomes: %d"], t.offer or 0, t.welcome or 0), 0.9, 0.9, 0.9)
        GameTooltip:AddLine(L["Only you can see this."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    hc:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local nl = SectionLabel(ov, L["NEXT STEPS"])
    nl:SetPoint("TOPLEFT", 18, -200)

    ov.hints = {}
    for i = 1, 5 do
        local b = CreateFrame("Button", nil, ov)
        b:SetHeight(40)
        b:SetPoint("TOPLEFT", 18, -216 - (i - 1) * 44)
        b:SetPoint("RIGHT", -18, 0)
        Fill(b, C.panel)
        Border(b, C.border)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(1, 1, 1, 0.05)
        b.dot = b:CreateTexture(nil, "ARTWORK")
        b.dot:SetSize(3, 24)
        b.dot:SetPoint("LEFT", 8, 0)
        b.dot:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        b.title = Text(b, 12, C.gold)
        b.title:SetPoint("TOPLEFT", 20, -7)
        b.title:SetPoint("RIGHT", -10, 0)
        b.body = Text(b, 10, C.muted)
        b.body:SetPoint("BOTTOMLEFT", 20, 7)
        b.body:SetPoint("RIGHT", -10, 0)
        b:SetScript("OnClick", function(self) if self.action then self.action() end end)
        ov.hints[i] = b
    end
end

local function RenderOverview()
    local DB = FriendsmithDB
    local me = ns.PlayerKey()
    ov.who:SetText(CharName(me) .. "  ·  " .. LevelClass(me) .. (GetGuildInfo("player") and ("  ·  <" .. GetGuildInfo("player") .. ">") or ""))

    local st = ns.stats or { crafters = 0 }
    ov.cards[1].value:SetText(counts.mine)
    ov.cards[2].value:SetText(counts.help)
    local tally = ns.HelpTally and ns.HelpTally(7) or { people = 0 }
    ov.cards[3].value:SetText(tally.people)
    ov.cards[3].tally = tally
    ov.cards[4].value:SetText(counts.all)

    local hints = {}
    local function add(title, body, action) hints[#hints + 1] = { title, body, action } end

    local myRecipes = 0
    local rec = DB.chars[me]
    if rec and rec.recipes then for _ in pairs(rec.recipes) do myRecipes = myRecipes + 1 end end
    local foreign = 0
    for _, r in pairs(DB.chars) do if not r.mine then foreign = foreign + 1 end end

    -- Stille Wuensche: wem koennte ich helfen?
    local wishHints = ns.WishHints and ns.WishHints() or {}
    if #wishHints > 0 then
        local people = ns.WishPeople(wishHints)
        local text = ns.WishHintText(wishHints[1]):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
        add("|cffff8fc8" .. string.format(people == 1 and L["%d guild member would be happy about help"] or L["%d guild members would be happy about help"], people) .. "|r",
            text, function() ns.Nudge(true) end)
    end

    -- bestes Upgrade fuer den aktuellen Charakter
    local best
    for _, e in ipairs(ns.results or {}) do
        if e.target == me and (not best or e.rank > best.rank) then best = e end
    end
    if best then
        local d = ns.ItemData(best.itemID)
        add(L["Best upgrade: "] .. (d and d.name or "…"),
            string.format(L["%s · %s · by %s"], SLOT_NAMES[best.slot] or "?", GainText(best), CrafterNames(best.crafters)),
            function() Select(best) end)
    end
    if counts.help > 0 then
        add(string.format(L["You can craft %d upgrades"], counts.help), L["For your alts and your guild – click here for the list."],
            function() SetView("help") end)
    end
    if ns.IsWelcomePeriod() then
        add("|cffffd140" .. string.format(L["Welcome to <%s>!"], GetGuildInfo("player") or "?") .. "|r",
            string.format(counts.helpers == 1 and L["%d member is happy to help – see who helps with what."]
                or L["%d members are happy to help – see who helps with what."], counts.helpers), function() SetView("helpers") end)
    end
    local newbies = helperGroups[1] and helperGroups[1].ck == "helpers:new" and helperGroups[1].items or {}
    if #newbies > 0 then
        local n = newbies[1]
        add("|cffffd140" .. string.format(L["New in the guild: %s"], ns.ShortName(n.name or n.key)) .. "|r" .. (#newbies > 1 and ("  +" .. (#newbies - 1)) or ""),
            L["Say hello – a short welcome helps a lot."], function() SetView("helpers") end)
    end
    local latest = feedEntries[1]
    if latest and ns.Now() - latest.f.t < 2 * 86400 then
        add(L["Guild feed"], ns.FeedText(latest.f, true), function() SetView("feed") end)
    end
    local leveling = 0
    for _, e in ipairs(profEntries) do if not IsMine(e.key) and not e.plan.trainer then leveling = leveling + 1 end end
    if leveling > 0 then
        add(string.format(L["%d professions being leveled"], leveling), L["See who needs mats for the next step – click here."],
            function() SetView("profs") end)
    end
    if counts.stock > 0 then
        add(string.format(L["Guild stock: %d items below target"], counts.stock),
            L["The guild bank is running low – see what's missing and who can craft it."], function() SetView("stock") end)
    end
    if counts.requests > 0 then
        add(string.format(L["%d open mat requests"], counts.requests), L["Your guild is looking for mats – maybe you have some. Click here."],
            function() SetView("requests") end)
    end
    if not IsInGuild() then
        add(L["No guild"], L["Without a guild, only your own characters and friends using Friendsmith are compared."])
    elseif foreign == 0 then
        add(L["Sync with your guild"], L["No data from your guild yet. Click here to sync."],
            function() ns.Hello(true); ns.Print(L["Sent your data to your guild and friends and requested theirs."]) end)
    end
    if myRecipes == 0 then
        add(L["Record recipes"], L["Open each profession window of this character once (filters off)."])
    else
        add(string.format(L["%d recipes recorded"], myRecipes), L["Learned new recipes? Just open the profession window."])
    end
    if not ns.MyHelpTopics() and IsInGuild() then
        add(L["Happy to help others?"], L["Set up your helper profile – it shows your guild what you can help with."],
            function() ns.OpenSettings(true, "profile") end)
    end
    if ns.pending then add(L["Loading item data …"], L["Some items aren't cached yet, almost done."]) end

    for i, b in ipairs(ov.hints) do
        local h = hints[i]
        if h then
            b.title:SetText(h[1])
            b.body:SetText(h[2])
            b.action = h[3]
            b.hl:SetShown(h[3] ~= nil)
            b:Show()
        else
            b:Hide()
        end
    end
end

local function CreateItemView(parent)
    it = CreateFrame("Frame", nil, parent)
    it:SetAllPoints()

    local back = CreateFrame("Button", nil, it)
    back:SetSize(90, 18)
    back:SetPoint("TOPRIGHT", -14, -12)
    local bt = Text(back, 10, C.muted, "RIGHT")
    bt:SetPoint("RIGHT")
    bt:SetText(L["< Overview"])
    back:SetScript("OnEnter", function() bt:SetTextColor(1, 1, 1) end)
    back:SetScript("OnLeave", function() bt:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    back:SetScript("OnClick", function() Select(nil) end)

    -- Kopf: Icon + Name
    local ib = CreateFrame("Button", nil, it)
    ib:SetSize(46, 46)
    ib:SetPoint("TOPLEFT", 18, -34)
    it.icon = Icon(ib, 44)
    it.icon:SetPoint("CENTER")
    it.iconBorder = Border(ib, C.border)
    ib:SetScript("OnEnter", function(self)
        if selEntry then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. selEntry.itemID)
            GameTooltip:Show()
        end
    end)
    ib:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ib:SetScript("OnClick", function()
        local d = selEntry and ns.ItemData(selEntry.itemID)
        if d and HandleModifiedItemClick then HandleModifiedItemClick(d.link) end
    end)

    it.name = Text(it, 15)
    it.name:SetPoint("TOPLEFT", ib, "TOPRIGHT", 12, -3)
    it.name:SetPoint("RIGHT", -18, 0)
    it.meta = Text(it, 11, C.muted)
    it.meta:SetPoint("BOTTOMLEFT", ib, "BOTTOMRIGHT", 12, 4)
    it.meta:SetPoint("RIGHT", -18, 0)

    -- Vergleich
    local vl = SectionLabel(it, L["COMPARISON"])
    vl:SetPoint("TOPLEFT", 18, -96)
    local box = Panel(it, C.panel2)
    box:SetPoint("TOPLEFT", 18, -110)
    box:SetPoint("RIGHT", -18, 0)
    box:SetHeight(70)
    local cl = Text(box, 9, C.muted)
    cl:SetPoint("TOPLEFT", 10, -8)
    cl:SetText(L["CURRENTLY WEARING"])
    it.curIcon = Icon(box, 20)
    it.curIcon:SetPoint("TOPLEFT", 10, -22)
    it.gain = Text(box, 20, C.green, "RIGHT")
    it.gain:SetPoint("TOPRIGHT", -12, -8)
    it.gainLabel = Text(box, 9, C.muted, "RIGHT")
    it.gainLabel:SetPoint("TOPRIGHT", it.gain, "BOTTOMRIGHT", 0, -3)
    it.curName = Text(box, 11)
    it.curName:SetPoint("LEFT", it.curIcon, "RIGHT", 7, 0)
    it.curName:SetPoint("RIGHT", box, "RIGHT", -96, 0)
    it.statLine = Text(box, 10, C.muted)
    it.statLine:SetPoint("BOTTOMLEFT", 10, 8)
    it.statLine:SetPoint("RIGHT", box, "RIGHT", -10, 0)

    -- Fuer
    local fl = SectionLabel(it, L["FOR"])
    fl:SetPoint("TOPLEFT", 18, -194)
    it.forName = Text(it, 13)
    it.forName:SetPoint("TOPLEFT", 18, -208)
    it.forSub = Text(it, 11, C.muted)
    it.forSub:SetPoint("LEFT", it.forName, "RIGHT", 8, 0)
    it.spec = Text(it, 10, C.muted)
    it.spec:SetPoint("TOPLEFT", it.forName, "BOTTOMLEFT", 0, -5)
    it.specBtn = MakeButton(it, 64, 18, L["change"])
    it.specBtn.label:SetFont(FONT, 10, "")
    it.specBtn:SetPoint("TOPRIGHT", -18, -206)
    it.specBtn:SetScript("OnClick", function()
        if selEntry then ns.CycleSpec(selEntry.target) end
    end)
    AddTooltip(it.specBtn, L["Change rating"],
        L["Cycles for this character: automatic → talent tree 1 → 2 → 3 → item level only. "] ..
        L["Only affects you."])

    -- Handwerker
    local hl = SectionLabel(it, L["CRAFTABLE BY"])
    hl:SetPoint("TOPLEFT", 18, -250)
    it.crafters = {}
    for i = 1, MAX_CRAFTER_ROWS do
        local r = CreateFrame("Frame", nil, it)
        r:SetHeight(26)
        r:SetPoint("TOPLEFT", 18, -264 - (i - 1) * 28)
        r:SetPoint("RIGHT", -18, 0)
        Fill(r, C.panel)
        r.name = Text(r, 12)
        r.name:SetPoint("LEFT", 10, 0)
        r.sub = Text(r, 10, C.muted)
        r.sub:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.btn = MakeButton(r, 70, 18, L["Whisper"])
        r.btn:SetPoint("RIGHT", -4, 0)
        r.btn.label:SetFont(FONT, 10, "")
        r.btn:SetScript("OnClick", function(self)
            local e = selEntry
            if not e or not self.key then return end
            local d = ns.ItemData(e.itemID)
            local link = d and d.link or L["the item"]
            local forWhom = (e.target == ns.PlayerKey()) and L["me"] or string.format(L["my alt %s"], ns.ShortName(e.target))
            Whisper(self.key, ns.Subst(L["Hi! Could you craft {item} for {who}? I\'ll bring the mats."], { item = link, who = forWhom }))
        end)
        r.thx = MakeButton(r, 56, 18, L["Thanks!"])
        r.thx:SetPoint("RIGHT", r.btn, "LEFT", -4, 0)
        r.thx.label:SetFont(FONT, 10, "")
        r.thx:SetScript("OnClick", function(self)
            if selEntry and self.key then ns.Thank(self.key, selEntry.itemID) end
        end)
        AddTooltip(r.thx, L["Say thanks"], L["Crafted it for you? Say thanks – it shows up in the guild feed."])
        it.crafters[i] = r
    end
    it.more = Text(it, 10, C.muted)
    it.more:SetPoint("TOPLEFT", 18, -264 - MAX_CRAFTER_ROWS * 28)

    -- Zutaten
    it.mats = CreateMatsBlock(it, -362, L["MATS"])

    -- Aktionen
    it.link = MakeButton(it, 100, 26, L["Link in chat"])
    it.link:SetPoint("BOTTOMLEFT", 18, 14)
    it.link:SetScript("OnClick", function() if selEntry then LinkInChat(selEntry.itemID) end end)
    it.ask = MakeButton(it, 108, 26, L["Whisper request"], true)
    it.ask:SetPoint("BOTTOMRIGHT", -18, 14)
    it.ask:SetScript("OnClick", function(self) if self.run then self.run() end end)
    it.req = MakeButton(it, 108, 26, L["Ask for mats"])
    it.req:SetPoint("RIGHT", it.ask, "LEFT", -6, 0)
    it.req:SetScript("OnClick", function(self) if self.run then self.run() end end)
    AddTooltip(it.req, L["Ask for mats"],
        L["Saves a mat request that everyone in your guild with Friendsmith sees, and prepares a guild chat message with the missing mats."])
end

local function RenderItem(e)
    local d = ns.ItemData(e.itemID)
    local qr, qg, qb = QualityColor(d and d.quality)
    it.icon:SetTexture(d and d.icon or EMPTY_ICON)
    SetBorderColor(it.iconBorder, qr, qg, qb, 1)
    it.name:SetText(d and d.name or L["Loading item data …"])
    it.name:SetTextColor(qr, qg, qb)
    local meta = { SLOT_NAMES[e.slot] or "?" }
    if d then
        if d.subName and d.subName ~= "" and d.subName ~= "Verschiedenes" and d.subName ~= "Miscellaneous" then meta[#meta + 1] = d.subName end
        meta[#meta + 1] = "iLvl " .. d.ilvl
        if d.req and d.req > 1 then meta[#meta + 1] = L["requires level "] .. d.req end
    end
    it.meta:SetText(table.concat(meta, "  ·  "))

    if e.cur then
        local cd = ns.ItemData(e.cur)
        it.curIcon:SetTexture(cd and cd.icon or EMPTY_ICON)
        it.curName:SetText((cd and cd.name or "…") .. (cd and ("  |cff8f96a8iLvl " .. cd.ilvl .. "|r") or ""))
        it.curName:SetTextColor(QualityColor(cd and cd.quality))
        if e.mode == "stat" then
            it.gain:SetText(DiffText(e))
            it.gainLabel:SetText(L["FOR THE SPEC"])
        else
            it.gain:SetText("+" .. e.diff)
            it.gainLabel:SetText(L["ITEM LEVEL"])
        end
    else
        it.curIcon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        it.curName:SetText(L["Slot is empty"])
        it.curName:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        it.gain:SetText(L["NEW"])
        it.gainLabel:SetText(L["EMPTY SLOT"])
    end

    it.forName:SetText(CharName(e.target))
    it.forSub:SetText(LevelClass(e.target) .. "   " .. Tag(e.target))
    it.spec:SetText(L["Rated by: "] .. "|cffe6e6eb" .. ns.SpecLabel(e.target) .. "|r")
    local w = ns.WeightsFor(e.target)
    local tr = Rec(e.target)
    local diffs = ns.StatDiffText(ns.ItemStats(e.itemID), e.cur and ns.ItemStats(e.cur, tr and tr.suffix and tr.suffix[e.slot]), w)
    it.statLine:SetText(diffs ~= "" and diffs or L["No known stat differences"])

    for i, r in ipairs(it.crafters) do
        local k = e.crafters[i]
        if k then
            r.key = k
            r.btn.key = k
            r.thx.key = k
            r.name:SetText(CharName(k))
            r.sub:SetText(Tag(k))
            r.btn:SetShown(not IsMine(k))
            r.thx:SetShown(not IsMine(k) and IsMine(e.target))
            r:Show()
        else
            r:Hide()
        end
    end
    local extra = #e.crafters - MAX_CRAFTER_ROWS
    it.more:SetText(extra > 0 and string.format(L["+%d more"], extra) or "")

    -- Hauptaktion
    local link = d and d.link or L["the item"]
    local foreignCrafter = FirstForeign(e.crafters)
    if not IsMine(e.target) and AnyMine(e.crafters) then
        it.ask.label:SetText(L["Whisper offer"])
        it.ask.run = function()
            local diff = e.cur and ns.Subst(L[" ({gain} for you)"], { gain = GainText(e) }) or L[" (your slot is still empty)"]
            Whisper(e.target, ns.Subst(L["Hi! I can craft you {item}{gain}. Interested? Just bring the mats."], { item = link, gain = diff }))
            ns.LogHelp("offer", e.target, e.itemID)
        end
        it.ask:SetActive(true)
    elseif foreignCrafter then
        it.ask.label:SetText(L["Whisper request"])
        it.ask.run = function()
            local forWhom = (e.target == ns.PlayerKey()) and L["me"] or string.format(L["my alt %s"], ns.ShortName(e.target))
            Whisper(foreignCrafter, ns.Subst(L["Hi! Could you craft {item} for {who}? I\'ll bring the mats."], { item = link, who = forWhom }))
        end
        it.ask:SetActive(true)
    else
        it.ask.label:SetText(L["Craft it yourself"])
        it.ask.run = nil
        it.ask:SetActive(false)
    end

    -- Zutaten und Mats-Anfrage
    local missing = RenderMats(it.mats, ns.Reagents(e.itemID))
    it.req.run = nil
    if not missing then
        it.req.label:SetText(L["Mats unknown"])
    elseif #missing == 0 then
        it.req.label:SetText(L["Mats complete"])
    else
        it.req.label:SetText(L["Ask for mats"])
        if IsInGuild() then it.req.run = function() AskGuildForMats(e.itemID, missing) end end
    end
    it.req:SetActive(it.req.run ~= nil)
end

local function CreateFoodView(parent)
    fd = CreateFrame("Frame", nil, parent)
    fd:SetAllPoints()

    local back = CreateFrame("Button", nil, fd)
    back:SetSize(90, 18)
    back:SetPoint("TOPRIGHT", -14, -12)
    local bt = Text(back, 10, C.muted, "RIGHT")
    bt:SetPoint("RIGHT")
    bt:SetText(L["< Overview"])
    back:SetScript("OnEnter", function() bt:SetTextColor(1, 1, 1) end)
    back:SetScript("OnLeave", function() bt:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    back:SetScript("OnClick", function() Select(nil) end)

    local ib = CreateFrame("Button", nil, fd)
    ib:SetSize(46, 46)
    ib:SetPoint("TOPLEFT", 18, -34)
    fd.icon = Icon(ib, 44)
    fd.icon:SetPoint("CENTER")
    fd.iconBorder = Border(ib, C.border)
    ib:SetScript("OnEnter", function(self)
        if selEntry then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. selEntry.itemID)
            GameTooltip:Show()
        end
    end)
    ib:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ib:SetScript("OnClick", function()
        local d = selEntry and ns.ItemData(selEntry.itemID)
        if d and HandleModifiedItemClick then HandleModifiedItemClick(d.link) end
    end)

    fd.name = Text(fd, 15)
    fd.name:SetPoint("TOPLEFT", ib, "TOPRIGHT", 12, -3)
    fd.name:SetPoint("RIGHT", -18, 0)
    fd.meta = Text(fd, 11, C.muted)
    fd.meta:SetPoint("BOTTOMLEFT", ib, "BOTTOMRIGHT", 12, 4)
    fd.meta:SetPoint("RIGHT", -18, 0)

    local bl = SectionLabel(fd, L["WELL FED"])
    bl:SetPoint("TOPLEFT", 18, -96)
    local box = Panel(fd, C.panel2)
    box:SetPoint("TOPLEFT", 18, -110)
    box:SetPoint("RIGHT", -18, 0)
    box:SetHeight(70)
    fd.amount = Text(box, 20, C.green, "RIGHT")
    fd.amount:SetPoint("TOPRIGHT", -12, -8)
    fd.rank = Text(box, 9, C.muted, "RIGHT")
    fd.rank:SetPoint("TOPRIGHT", fd.amount, "BOTTOMRIGHT", 0, -3)
    fd.text = Text(box, 10, C.text)
    fd.text:SetPoint("TOPLEFT", 10, -8)
    fd.text:SetPoint("RIGHT", box, "RIGHT", -70, 0)
    if fd.text.SetWordWrap then fd.text:SetWordWrap(true) end
    if fd.text.SetMaxLines then fd.text:SetMaxLines(4) end

    local cl = SectionLabel(fd, L["BEST IN CATEGORY"])
    cl:SetPoint("TOPLEFT", 18, -194)
    fd.best = Text(fd, 12)
    fd.best:SetPoint("TOPLEFT", 18, -210)
    fd.best:SetPoint("RIGHT", -18, 0)

    local hl = SectionLabel(fd, L["COOKED BY"])
    hl:SetPoint("TOPLEFT", 18, -250)
    fd.crafters = {}
    for i = 1, MAX_CRAFTER_ROWS do
        local r = CreateFrame("Frame", nil, fd)
        r:SetHeight(26)
        r:SetPoint("TOPLEFT", 18, -264 - (i - 1) * 28)
        r:SetPoint("RIGHT", -18, 0)
        Fill(r, C.panel)
        r.name = Text(r, 12)
        r.name:SetPoint("LEFT", 10, 0)
        r.sub = Text(r, 10, C.muted)
        r.sub:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.btn = MakeButton(r, 70, 18, L["Whisper"])
        r.btn:SetPoint("RIGHT", -4, 0)
        r.btn.label:SetFont(FONT, 10, "")
        r.btn:SetScript("OnClick", function(self)
            local e = selEntry
            if not e or not self.key then return end
            local d = ns.ItemData(e.itemID)
            Whisper(self.key, ns.Subst(L["Hi! Could you cook me some {item}? I'll bring the mats."], { item = d and d.link or L["the item"] }))
        end)
        fd.crafters[i] = r
    end
    fd.more = Text(fd, 10, C.muted)
    fd.more:SetPoint("TOPLEFT", 18, -264 - MAX_CRAFTER_ROWS * 28)

    fd.link = MakeButton(fd, 150, 26, L["Link in chat"])
    fd.link:SetPoint("BOTTOMLEFT", 18, 14)
    fd.link:SetScript("OnClick", function() if selEntry then LinkInChat(selEntry.itemID) end end)
end

local function RenderFood(e)
    local d = ns.ItemData(e.itemID)
    local qr, qg, qb = QualityColor(d and d.quality)
    fd.icon:SetTexture(d and d.icon or EMPTY_ICON)
    SetBorderColor(fd.iconBorder, qr, qg, qb, 1)
    fd.name:SetText(d and d.name or L["Loading item data …"])
    fd.name:SetTextColor(qr, qg, qb)
    local meta = { e.label }
    if e.req and e.req > 1 then meta[#meta + 1] = L["requires level "] .. e.req end
    fd.meta:SetText(table.concat(meta, "  ·  "))
    fd.text:SetText(e.text or "")
    fd.amount:SetText(ns.FoodValueText(e))
    fd.rank:SetText(e.rank == 1 and L["BEST"] or string.format(L["RANK %d"], e.rank))
    if e.rank == 1 then
        fd.best:SetText("|cffffd140" .. L["This is the best food in this category."] .. "|r")
    else
        local bd = ns.ItemData(e.best.itemID)
        fd.best:SetText((bd and bd.name or "?") .. "  |cff5cdb6b" .. ns.FoodValueText(e.best) .. "|r  ·  " .. CrafterNames(e.best.crafters))
    end
    for i, r in ipairs(fd.crafters) do
        local k = e.crafters[i]
        if k then
            r.btn.key = k
            r.name:SetText(CharName(k))
            r.sub:SetText(Tag(k))
            r.btn:SetShown(not IsMine(k))
            r:Show()
        else
            r:Hide()
        end
    end
    local extra = #e.crafters - MAX_CRAFTER_ROWS
    fd.more:SetText(extra > 0 and string.format(L["+%d more"], extra) or "")
end

local function CreateStockView(parent)
    sk = CreateFrame("Frame", nil, parent)
    sk:SetAllPoints()

    local back = CreateFrame("Button", nil, sk)
    back:SetSize(90, 18)
    back:SetPoint("TOPRIGHT", -14, -12)
    local bt = Text(back, 10, C.muted, "RIGHT")
    bt:SetPoint("RIGHT")
    bt:SetText(L["< Overview"])
    back:SetScript("OnEnter", function() bt:SetTextColor(1, 1, 1) end)
    back:SetScript("OnLeave", function() bt:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    back:SetScript("OnClick", function() Select(nil) end)

    local ib = CreateFrame("Button", nil, sk)
    ib:SetSize(46, 46)
    ib:SetPoint("TOPLEFT", 18, -34)
    sk.icon = Icon(ib, 44)
    sk.icon:SetPoint("CENTER")
    sk.iconBorder = Border(ib, C.border)
    ib:SetScript("OnEnter", function(self)
        if selEntry then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. selEntry.itemID)
            GameTooltip:Show()
        end
    end)
    ib:SetScript("OnLeave", function() GameTooltip:Hide() end)
    sk.name = Text(sk, 15)
    sk.name:SetPoint("TOPLEFT", ib, "TOPRIGHT", 12, -3)
    sk.name:SetPoint("RIGHT", -18, 0)
    sk.meta = Text(sk, 11, C.muted)
    sk.meta:SetPoint("BOTTOMLEFT", ib, "BOTTOMRIGHT", 12, 4)
    sk.meta:SetPoint("RIGHT", -18, 0)

    -- Bestand
    local bl = SectionLabel(sk, L["GUILD BANK"])
    bl:SetPoint("TOPLEFT", 18, -94)
    sk.count = Text(sk, 20, C.text)
    sk.count:SetPoint("TOPLEFT", 18, -108)
    sk.missing = Text(sk, 12, C.green)
    sk.missing:SetPoint("LEFT", sk.count, "RIGHT", 12, -1)

    -- Handwerker
    local hl = SectionLabel(sk, L["CRAFTABLE BY"])
    hl:SetPoint("TOPLEFT", 18, -146)
    sk.crafters = {}
    for i = 1, MAX_CRAFTER_ROWS do
        local r = CreateFrame("Frame", nil, sk)
        r:SetHeight(24)
        r:SetPoint("TOPLEFT", 18, -160 - (i - 1) * 26)
        r:SetPoint("RIGHT", -18, 0)
        Fill(r, C.panel)
        r.name = Text(r, 12)
        r.name:SetPoint("LEFT", 10, 0)
        r.sub = Text(r, 10, C.muted)
        r.sub:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.btn = MakeButton(r, 70, 18, L["Whisper"])
        r.btn:SetPoint("RIGHT", -3, 0)
        r.btn.label:SetFont(FONT, 10, "")
        r.btn:SetScript("OnClick", function(self)
            local e = selEntry
            if not e or not self.key then return end
            Whisper(self.key, ns.Subst(L["Hi! Our guild bank is short {n}x {item}. Could you craft some?"],
                { n = e.missing, item = ItemLinkOrName(e.itemID) }))
        end)
        sk.crafters[i] = r
    end
    sk.nobody = Text(sk, 11, C.muted)
    sk.nobody:SetPoint("TOPLEFT", 18, -164)
    sk.nobody:SetText(L["Nobody known can craft this yet."])

    -- Mats fuer die fehlende Menge
    sk.mats = CreateMatsBlock(sk, -246, L["MATS FOR THE MISSING AMOUNT"])

    -- Offiziere: Ziel aendern
    sk.edit = CreateFrame("Frame", nil, sk)
    sk.edit:SetPoint("TOPLEFT", 18, -336)
    sk.edit:SetPoint("RIGHT", -18, 0)
    sk.edit:SetHeight(40)
    local el = SectionLabel(sk.edit, L["TARGET (OFFICERS)"])
    el:SetPoint("TOPLEFT", 0, 0)
    sk.amount = MakeEdit(sk.edit, 60, "", true)
    sk.amount:SetPoint("TOPLEFT", 0, -14)
    sk.save = MakeButton(sk.edit, 80, 22, L["Save"], true)
    sk.save:SetPoint("LEFT", sk.amount, "RIGHT", 6, 0)
    sk.remove = MakeButton(sk.edit, 80, 22, L["Remove"])
    sk.remove:SetPoint("LEFT", sk.save, "RIGHT", 6, 0)
    local function save()
        local n = tonumber(sk.amount:GetText())
        if selEntry and n and n > 0 then ns.SetTarget(selEntry.itemID, n); sk.amount:ClearFocus() end
    end
    sk.save:SetScript("OnClick", save)
    sk.amount:SetScript("OnEnterPressed", save)
    sk.remove:SetScript("OnClick", function()
        if selEntry and ns.SetTarget(selEntry.itemID, 0) then Select(nil) end
    end)

    sk.link = MakeButton(sk, 100, 26, L["Link in chat"])
    sk.link:SetPoint("BOTTOMLEFT", 18, 14)
    sk.link:SetScript("OnClick", function() if selEntry then LinkInChat(selEntry.itemID) end end)
    sk.req = MakeButton(sk, 140, 26, L["Ask for mats"], true)
    sk.req:SetPoint("BOTTOMRIGHT", -18, 14)
    sk.req:SetScript("OnClick", function(self) if self.run then self.run() end end)
    AddTooltip(sk.req, L["Ask for mats"], L["Creates a mat request for what's needed to craft the missing amount."])
end

local function RenderStock(e)
    local d = ns.ItemData(e.itemID)
    local qr, qg, qb = QualityColor(d and d.quality)
    sk.icon:SetTexture(d and d.icon or EMPTY_ICON)
    SetBorderColor(sk.iconBorder, qr, qg, qb, 1)
    sk.name:SetText(d and d.name or L["Loading item data …"])
    sk.name:SetTextColor(qr, qg, qb)
    local _, info = ns.StockTargets()
    local by = info and info.by and ns.ShortName(info.by)
    sk.meta:SetText(string.format(L["Target: %d"], e.target) .. (by and ("  ·  " .. string.format(L["set by %s"], by)) or ""))
    sk.count:SetText(e.have .. " / " .. e.target)
    if e.missing > 0 then
        sk.missing:SetText("|cffff6060" .. string.format(L["%d missing"], e.missing) .. "|r")
    else
        sk.missing:SetText("|cff5cdb6b" .. L["target reached"] .. "|r")
    end

    for i, r in ipairs(sk.crafters) do
        local k = e.crafters[i]
        if k then
            r.btn.key = k
            r.name:SetText(CharName(k))
            r.sub:SetText(Tag(k))
            r.btn:SetShown(not IsMine(k) and e.missing > 0)
            r:Show()
        else
            r:Hide()
        end
    end
    sk.nobody:SetShown(#e.crafters == 0)

    -- Mats fuer die fehlende Menge (1 Stueck pro Herstellung angenommen)
    local base = ns.Reagents(e.itemID)
    local scaled
    if base and e.missing > 0 then
        scaled = {}
        for i, m in ipairs(base) do scaled[i] = { m[1], m[2] * e.missing } end
    end
    local missing
    if e.missing == 0 then
        for _, row in ipairs(sk.mats.rows) do row:Hide() end
        sk.mats.empty:SetText(L["Nothing missing."])
        sk.mats.empty:Show()
        sk.mats.note:SetText("")
    else
        missing = RenderMats(sk.mats, scaled)
    end

    sk.edit:SetShown(ns.CanSetTargets())
    if not sk.amount:HasFocus() then sk.amount:SetText(tostring(e.target)) end

    sk.req.run = nil
    if e.missing == 0 then
        sk.req.label:SetText(L["Target reached"])
    elseif not missing then
        sk.req.label:SetText(L["Mats unknown"])
    elseif #missing == 0 then
        sk.req.label:SetText(L["Mats complete"])
    else
        sk.req.label:SetText(L["Ask for mats"])
        sk.req.run = function() AskGuildForMats(e.itemID, missing) end
    end
    sk.req:SetActive(sk.req.run ~= nil)
end

local function CreateProfView(parent)
    ph = CreateFrame("Frame", nil, parent)
    ph:SetAllPoints()
    ph.opt = 1

    local back = CreateFrame("Button", nil, ph)
    back:SetSize(90, 18)
    back:SetPoint("TOPRIGHT", -14, -12)
    local bt = Text(back, 10, C.muted, "RIGHT")
    bt:SetPoint("RIGHT")
    bt:SetText(L["< Overview"])
    back:SetScript("OnEnter", function() bt:SetTextColor(1, 1, 1) end)
    back:SetScript("OnLeave", function() bt:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    back:SetScript("OnClick", function() Select(nil) end)

    ph.title = Text(ph, 15)
    ph.title:SetPoint("TOPLEFT", 18, -36)
    ph.title:SetPoint("RIGHT", -110, 0)
    ph.who = Text(ph, 11, C.muted)
    ph.who:SetPoint("TOPLEFT", ph.title, "BOTTOMLEFT", 0, -6)

    local sl = SectionLabel(ph, L["SKILL"])
    sl:SetPoint("TOPLEFT", 18, -86)
    ph.skill = Text(ph, 20, C.text)
    ph.skill:SetPoint("TOPLEFT", 18, -100)
    ph.step = Text(ph, 11, C.green)
    ph.step:SetPoint("LEFT", ph.skill, "RIGHT", 12, -1)
    ph.step:SetPoint("RIGHT", -18, 0)

    ph.sugLabel = SectionLabel(ph, L["SUGGESTION"])
    ph.sugLabel:SetPoint("TOPLEFT", 18, -136)
    ph.opts = {}
    for i = 1, 5 do
        local b = CreateFrame("Button", nil, ph)
        b:SetHeight(18)
        b:SetPoint("TOPLEFT", 18, -150 - (i - 1) * 19)
        b:SetPoint("RIGHT", -18, 0)
        b.sel = Fill(b, C.accentBg)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.05)
        b.icon = Icon(b, 14)
        b.icon:SetPoint("LEFT", 4, 0)
        b.text = Text(b, 11)
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b:SetScript("OnClick", function(self)
            if self.itemID and IsShiftKeyDown() then LinkInChat(self.itemID); return end
            local e = selEntry
            local o = e and e.plan and e.plan.options[self.index]
            if o and o.train then return end
            ph.opt = self.index
            RenderDetail()
        end)
        b:SetScript("OnEnter", function(self)
            if not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.itemID)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b.index = i
        ph.opts[i] = b
    end
    ph.note = Text(ph, 10, C.muted)
    ph.note:SetPoint("TOPLEFT", 18, -150)
    ph.note:SetPoint("RIGHT", -18, 0)
    if ph.note.SetWordWrap then ph.note:SetWordWrap(true) end

    ph.mats = CreateMatsBlock(ph, -252, L["MATS"])

    ph.link = MakeButton(ph, 100, 26, L["Link in chat"])
    ph.link:SetPoint("BOTTOMLEFT", 18, 14)
    ph.link:SetScript("OnClick", function(self) if self.itemID then LinkInChat(self.itemID) end end)
    ph.act = MakeButton(ph, 150, 26, L["Whisper: I can help"], true)
    ph.act:SetPoint("BOTTOMRIGHT", -18, 14)
    ph.act:SetScript("OnClick", function(self) if self.run then self.run() end end)
end

local function RenderProf(e)
    if ph.lastKey ~= EntryKey(e) then ph.opt = 1; ph.lastKey = EntryKey(e) end
    local p, plan = e.p, e.plan
    ph.title:SetText(e.name)
    ph.who:SetText(CharName(e.key) .. "  " .. Tag(e.key) .. "  ·  " .. string.format(L["updated %s ago"], AgeText(p.t)))
    ph.skill:SetText(p.rank .. " / " .. p.max)

    local opt = plan.options[ph.opt] or plan.options[1]
    if opt and opt.train then opt = plan.options[1] end
    if plan.trainer then
        ph.step:SetText("|cffffd140" .. string.format(L["Needs a trainer to go beyond %d."], p.max) .. "|r")
    else
        ph.step:SetText(string.format(L["%d points to %d"], plan.points, plan.target))
    end

    ph.sugLabel:SetText(plan.guide and L["ROUTE (ONEFORALL)"] or L["SUGGESTION"])
    for i, b in ipairs(ph.opts) do
        local o = plan.options[i]
        if o and not plan.trainer then
            b.itemID = o.itemID
            if o.train then
                b.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
                b.text:SetText("|cffffd140" .. string.format(L["at %d: visit the trainer (up to %d)"], o.at, o.cap) .. "|r")
            elseif o.total then
                b.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
                b.text:SetText(string.format(L["Whole route: ~%d crafts to %d"], o.crafts, plan.target))
            else
                local d = ns.ItemData(o.itemID)
                b.icon:SetTexture(d and d.icon or EMPTY_ICON)
                if o.color == "g" then
                    b.text:SetText(string.format("%d–%d  ~%dx %s", o.from, o.to, o.crafts, d and d.name or "…")
                        .. (o.learn and ("  |cffffd140(" .. L["learn first"] .. ")|r") or ""))
                else
                    local col = o.color == "o" and "|cffff8040" or "|cffffff00"
                    b.text:SetText(string.format("~%dx %s  %s(%s)|r", o.crafts, d and d.name or "…", col,
                        o.color == "o" and L["orange"] or L["yellow"]))
                end
            end
            b.sel:SetShown(o == opt)
            b:Show()
        else
            b:Hide()
        end
    end
    if plan.trainer then
        ph.note:SetText(L["Visit a trainer to learn the next rank – after that new recipes become orange again."])
    elseif #plan.options == 0 then
        ph.note:SetText(L["No orange or yellow recipes with known mats. The player may need new recipes from a trainer or vendor."])
    else
        ph.note:SetText("")
    end
    ph.note:SetShown(ph.note:GetText() ~= "")

    local missing
    if opt and not plan.trainer then
        missing = RenderMats(ph.mats, opt.mats)
        ph.mats.label:Show()
        ph.mats.note:Show()
    else
        for _, row in ipairs(ph.mats.rows) do row:Hide() end
        ph.mats.empty:Hide()
        ph.mats.label:Hide()
        ph.mats.note:Hide()
    end

    ph.link.itemID = opt and opt.itemID
    ph.link:SetActive(opt ~= nil and not plan.trainer)
    ph.act.run = nil
    if IsMine(e.key) then
        ph.act.label:SetText(L["Ask for mats"])
        if opt and missing and #missing > 0 and IsInGuild() then
            ph.act.run = function() AskGuildForMats(opt.itemID, missing) end
        elseif missing and #missing == 0 then
            ph.act.label:SetText(L["Mats complete"])
        end
    elseif opt and not plan.trainer then
        ph.act.label:SetText(L["Whisper: I can help"])
        ph.act.run = function()
            local have = {}
            for _, m in ipairs(opt.mats or {}) do
                local own = ns.OwnCount(m[1])
                if own > 0 then have[#have + 1] = math.min(own, m[2]) .. "x " .. ItemLinkOrName(m[1]) end
            end
            ns.LogHelp("offer", e.key, opt.itemID)
            Whisper(e.key, ns.Subst(L["Hi! I saw you're leveling {prof} ({rank}/{max}). I can help with mats for {item}: {mats}"],
                { prof = e.name, rank = p.rank, max = p.max, item = ItemLinkOrName(opt.itemID),
                  mats = #have > 0 and table.concat(have, ", ") or L["some of it"] }))
        end
    else
        ph.act.label:SetText(L["Whisper: I can help"])
    end
    ph.act:SetActive(ph.act.run ~= nil)
end

local function CreateFeedView(parent)
    fv = CreateFrame("Frame", nil, parent)
    fv:SetAllPoints()
    local back = CreateFrame("Button", nil, fv)
    back:SetSize(90, 18)
    back:SetPoint("TOPRIGHT", -14, -12)
    local bt = Text(back, 10, C.muted, "RIGHT")
    bt:SetPoint("RIGHT")
    bt:SetText(L["< Overview"])
    back:SetScript("OnEnter", function() bt:SetTextColor(1, 1, 1) end)
    back:SetScript("OnLeave", function() bt:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    back:SetScript("OnClick", function() Select(nil) end)
    local l = SectionLabel(fv, L["GUILD FEED"])
    l:SetPoint("TOPLEFT", 18, -36)
    fv.text = Text(fv, 14, C.text)
    fv.text:SetPoint("TOPLEFT", 18, -54)
    fv.text:SetPoint("RIGHT", -18, 0)
    if fv.text.SetWordWrap then fv.text:SetWordWrap(true) end
    fv.age = Text(fv, 11, C.muted)
    fv.age:SetPoint("TOPLEFT", fv.text, "BOTTOMLEFT", 0, -8)
    fv.act = MakeButton(fv, 170, 26, L["Whisper congratulations"], true)
    fv.act:SetPoint("BOTTOMRIGHT", -18, 14)
    fv.act:SetScript("OnClick", function(self) if self.run then self.run() end end)
    fv.thx = MakeButton(fv, 120, 26, L["Thanks!"])
    fv.thx:SetPoint("BOTTOMLEFT", 18, 14)
    fv.thx:SetScript("OnClick", function(self) if self.run then self.run() end end)
end

local function RenderFeed(e)
    local f = e.f
    fv.text:SetText(ns.FeedText(f))
    fv.age:SetText(string.format(L["%s ago"], AgeText(f.t)))
    local mine = IsMine(f.key)
    fv.act.run, fv.thx.run = nil, nil
    if f.kind == "join" then
        fv.act.label:SetText(L["Whisper welcome"])
        fv.act.run = function() Whisper(f.a, L["Welcome to the guild! If you need anything, just ask – we're happy to help."]); ns.LogHelp("welcome", f.a) end
    elseif not mine and (f.kind == "prof" or f.kind == "lvl" or f.kind == "req") then
        fv.act.label:SetText(L["Whisper congratulations"])
        fv.act.run = function()
            Whisper(f.key, ns.Subst(L["Congratulations: {what}"], { what = ns.FeedText(f, true) }))
        end
    elseif f.kind == "thanks" and ns.SameName(f.to, ns.PlayerKey()) then
        fv.act.label:SetText(L["You're welcome!"])
        fv.act.run = function() Whisper(f.key, L["You're welcome – happy to help!"]) end
    else
        fv.act.label:SetText(L["Whisper congratulations"])
    end
    fv.act:SetActive(fv.act.run ~= nil)
    -- jemandem aus dem Eintrag danken (z. B. dem, der Mats geschickt hat)
    if not mine and f.kind ~= "thanks" and f.kind ~= "join" then
        fv.thx.label:SetText(string.format(L["Thank %s"], ns.ShortName(f.key)))
        fv.thx.run = function() ns.Thank(f.key) end
    else
        fv.thx.label:SetText(L["Thanks!"])
    end
    fv.thx:SetActive(fv.thx.run ~= nil)
end

local WHISPER_FOR = {
    crafting = "Hi! Friendsmith says you're happy to craft for others. Could you help me with something?",
    mats = "Hi! Friendsmith says you're happy to share mats. Could you spare some?",
    dungeons = "Hi! Friendsmith says you're happy to run dungeons. Would you have time to join me sometime?",
    quests = "Hi! Friendsmith says you're happy to help with quests. Could you help me with one?",
    gathering = "Hi! Friendsmith says you're happy to gather. Could you help me find some materials?",
    questions = "Hi! Friendsmith says you're happy to answer questions. May I ask you something?",
    leveling = "Hi! Friendsmith says you'd like to level together. Want to team up sometime?",
}

local function CreateHelperView(parent)
    hp = CreateFrame("Frame", nil, parent)
    hp:SetAllPoints()
    local back = CreateFrame("Button", nil, hp)
    back:SetSize(90, 18)
    back:SetPoint("TOPRIGHT", -14, -12)
    local bt = Text(back, 10, C.muted, "RIGHT")
    bt:SetPoint("RIGHT")
    bt:SetText(L["< Overview"])
    back:SetScript("OnEnter", function() bt:SetTextColor(1, 1, 1) end)
    back:SetScript("OnLeave", function() bt:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    back:SetScript("OnClick", function() Select(nil) end)
    hp.title = Text(hp, 16, C.text)
    hp.title:SetPoint("TOPLEFT", 18, -36)
    hp.sub = Text(hp, 11, C.muted)
    hp.sub:SetPoint("TOPLEFT", hp.title, "BOTTOMLEFT", 0, -6)
    hp.sub:SetPoint("RIGHT", -18, 0)
    local l1 = SectionLabel(hp, L["HAPPY TO HELP WITH"])
    l1:SetPoint("TOPLEFT", 18, -92)
    hp.topics = Text(hp, 12, C.text)
    hp.topics:SetPoint("TOPLEFT", 18, -108)
    hp.topics:SetPoint("RIGHT", -18, 0)
    if hp.topics.SetWordWrap then hp.topics:SetWordWrap(true) end
    local l2 = SectionLabel(hp, L["PROFESSIONS"])
    l2:SetPoint("TOPLEFT", 18, -190)
    hp.profs = Text(hp, 12, C.text)
    hp.profs:SetPoint("TOPLEFT", 18, -206)
    hp.profs:SetPoint("RIGHT", -18, 0)
    if hp.profs.SetWordWrap then hp.profs:SetWordWrap(true) end
    hp.hint = Text(hp, 11, C.muted)
    hp.hint:SetPoint("TOPLEFT", 18, -300)
    hp.hint:SetPoint("RIGHT", -18, 0)
    if hp.hint.SetWordWrap then hp.hint:SetWordWrap(true) end
    hp.thx = MakeButton(hp, 100, 26, L["Thanks!"])
    hp.thx:SetPoint("BOTTOMLEFT", 18, 14)
    hp.thx:SetScript("OnClick", function(self) if self.key then ns.Thank(self.key) end end)
    hp.act = MakeButton(hp, 170, 26, L["Whisper"], true)
    hp.act:SetPoint("BOTTOMRIGHT", -18, 14)
    hp.act:SetScript("OnClick", function(self) if self.run then self.run() end end)
end

local function RenderHelper(e)
    local r = Rec(e.key)
    hp.title:SetText(r and CharName(e.key) or ns.ShortName(e.name or e.key))
    local info = ns.RosterInfo(rosterCache, e.key)
    local parts = {}
    local lvl = (info and info.level) or (r and r.level)
    if lvl then parts[#parts + 1] = L["Level "] .. lvl end
    parts[#parts + 1] = (info and info.online) and ("|cff5cdb6b" .. L["online"] .. "|r") or L["offline"]
    if r then parts[#parts + 1] = Tag(e.key) end
    if e.newcomer then parts[#parts + 1] = "|cffffd140" .. string.format(L["new since %s"], AgeText(e.t)) .. "|r" end
    hp.sub:SetText(table.concat(parts, "  ·  "))

    local t = {}
    for _, k in ipairs(ns.HELP_TOPICS) do
        if r and r.help and r.help[k] then t[#t + 1] = "|cffff8fc8•|r " .. ns.TopicLabel(k) end
    end
    hp.topics:SetText(#t > 0 and table.concat(t, "\n") or ("|cff8f96a8" .. L["No helper profile."] .. "|r"))
    local pr = {}
    for name, p in pairs(r and r.profs or {}) do pr[#pr + 1] = name .. "  |cff8f96a8" .. p.rank .. "/" .. p.max .. "|r" end
    table.sort(pr)
    hp.profs:SetText(#pr > 0 and table.concat(pr, "\n") or ("|cff8f96a8" .. L["Unknown (no Friendsmith or profession window not opened yet)."] .. "|r"))

    hp.thx.key = e.key
    hp.thx:SetShown(not e.newcomer and not IsMine(e.key))
    hp.act.run = nil
    if e.newcomer then
        hp.hint:SetText(L["Say hello! New members often don't dare to ask – a short welcome helps a lot."])
        hp.act.label:SetText(L["Whisper welcome"])
        hp.act.run = function() Whisper(e.key, L["Welcome to the guild! If you need anything, just ask – we're happy to help."], e.name); ns.LogHelp("welcome", e.name or e.key) end
    else
        hp.hint:SetText(e.topic and string.format(L["%s is happy to help with: %s. Don't be shy – just ask!"], ns.ShortName(e.key), ns.TopicLabel(e.topic)) or "")
        hp.act.label:SetText(L["Whisper"])
        if not IsMine(e.key) then
            hp.act.run = function() Whisper(e.key, L[WHISPER_FOR[e.topic] or WHISPER_FOR.questions]) end
        end
    end
    hp.act:SetActive(hp.act.run ~= nil)
end

local function CreateEnchView(parent)
    en = CreateFrame("Frame", nil, parent)
    en:SetAllPoints()
    en.opt = 1
    local back = CreateFrame("Button", nil, en)
    back:SetSize(90, 18)
    back:SetPoint("TOPRIGHT", -14, -12)
    local bt = Text(back, 10, C.muted, "RIGHT")
    bt:SetPoint("RIGHT")
    bt:SetText(L["< Overview"])
    back:SetScript("OnEnter", function() bt:SetTextColor(1, 1, 1) end)
    back:SetScript("OnLeave", function() bt:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    back:SetScript("OnClick", function() Select(nil) end)

    local ib = CreateFrame("Button", nil, en)
    ib:SetSize(46, 46)
    ib:SetPoint("TOPLEFT", 18, -34)
    en.icon = Icon(ib, 44)
    en.icon:SetPoint("CENTER")
    en.iconBorder = Border(ib, C.border)
    ib:SetScript("OnEnter", function(self)
        if selEntry then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. selEntry.itemID); GameTooltip:Show() end
    end)
    ib:SetScript("OnLeave", function() GameTooltip:Hide() end)
    en.name = Text(en, 15)
    en.name:SetPoint("TOPLEFT", ib, "TOPRIGHT", 12, -3)
    en.name:SetPoint("RIGHT", -18, 0)
    en.meta = Text(en, 11, C.muted)
    en.meta:SetPoint("BOTTOMLEFT", ib, "BOTTOMRIGHT", 12, 4)
    en.meta:SetPoint("RIGHT", -18, 0)

    en.label1 = SectionLabel(en, "")
    en.label1:SetPoint("TOPLEFT", 18, -96)
    en.rows = {}
    for i = 1, 7 do
        local b = CreateFrame("Button", nil, en)
        b:SetHeight(18)
        b:SetPoint("TOPLEFT", 18, -110 - (i - 1) * 19)
        b:SetPoint("RIGHT", -18, 0)
        b.sel = Fill(b, C.accentBg)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.05)
        b.text = Text(b, 11)
        b.text:SetPoint("LEFT", 4, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b.index = i
        b:SetScript("OnClick", function(self) en.opt = self.index; RenderDetail() end)
        b:SetScript("OnEnter", function(self)
            if self.link then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.link); GameTooltip:Show() end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        en.rows[i] = b
    end
    en.label2 = SectionLabel(en, "")
    en.label2:SetPoint("TOPLEFT", 18, -252)
    en.text2 = Text(en, 11, C.text)
    en.text2:SetPoint("TOPLEFT", 18, -268)
    en.text2:SetPoint("RIGHT", -18, 0)
    if en.text2.SetWordWrap then en.text2:SetWordWrap(true) end
    en.hint = Text(en, 11, C.green)
    en.hint:SetPoint("TOPLEFT", 18, -380)
    en.hint:SetPoint("RIGHT", -18, 0)
    if en.hint.SetWordWrap then en.hint:SetWordWrap(true) end

    en.b1 = MakeButton(en, 150, 26, L["Whisper"])
    en.b1:SetPoint("BOTTOMLEFT", 18, 14)
    en.b1:SetScript("OnClick", function(self) if self.run then self.run() end end)
    en.b2 = MakeButton(en, 170, 26, L["Whisper"], true)
    en.b2:SetPoint("BOTTOMRIGHT", -18, 14)
    en.b2:SetScript("OnClick", function(self) if self.run then self.run() end end)
end

local function RenderEnch(e)
    if en.lastKey ~= EntryKey(e) then en.opt = 1; en.lastKey = EntryKey(e) end
    local d = ns.ItemData(e.itemID)
    local qr, qg, qb = QualityColor(d and d.quality)
    en.icon:SetTexture(d and d.icon or EMPTY_ICON)
    SetBorderColor(en.iconBorder, qr, qg, qb, 1)
    en.name:SetText(d and d.name or L["Loading item data …"])
    en.name:SetTextColor(qr, qg, qb)
    en.b1.run, en.b2.run = nil, nil
    for _, r in ipairs(en.rows) do r:Hide() end

    if e.enchSlot then
        en.meta:SetText((SLOT_NAMES[e.slot] or "?") .. "  ·  " .. CharName(e.key) .. "  ·  |cffffd140" .. L["no enchant yet"] .. "|r")
        en.label1:SetText(L["YOUR GUILD CAN DO"])
        local opts = {}
        for _, x in ipairs(e.enchants) do opts[#opts + 1] = { enchant = x.id, keys = x.keys } end
        for _, k in ipairs(e.kits) do opts[#opts + 1] = { kit = k.itemID, keys = k.keys } end
        for i, r in ipairs(en.rows) do
            local o = opts[i]
            if o then
                local label = o.enchant and ns.EnchantName(o.enchant)
                    or ("|cffffd140" .. L["Armor kit"] .. ":|r " .. ((ns.ItemData(o.kit) or {}).name or "…"))
                r.text:SetText(label .. "  |cff8f96a8– " .. ns.ShortName(o.keys[1]) .. (#o.keys > 1 and (" +" .. (#o.keys - 1)) or "") .. "|r")
                r.link = o.kit and ("item:" .. o.kit) or (o.enchant and ("enchant:" .. o.enchant)) or nil
                r.sel:SetShown(i == en.opt)
                r:Show()
            end
        end
        local o = opts[en.opt] or opts[1]
        en.label2:SetText(o and L["WHO CAN DO IT"] or "")
        en.text2:SetText(o and CrafterNames(o.keys) or "")
        en.hint:SetText(#opts > #en.rows and string.format(L["+%d more"], #opts - #en.rows) or "")
        local first = o and o.keys and o.keys[1]
        if first and not IsMine(first) then
            en.b2.label:SetText(string.format(L["Whisper %s"], ns.ShortName(first)))
            en.b2.run = function()
                local what = o.enchant and ns.EnchantName(o.enchant) or ItemLinkOrName(o.kit)
                Whisper(first, ns.Subst(o.enchant and L["Hi! Could you enchant my {slot} with {what}? I'll bring the mats."]
                    or L["Hi! Could you make me {what}? I'll bring the mats."], { slot = SLOT_NAMES[e.slot] or "", what = what }))
            end
        else
            en.b2.label:SetText(first and L["You can do it yourself"] or L["Whisper"])
        end
        en.b1.label:SetText(L["Link in chat"])
        en.b1.run = function() LinkInChat(e.itemID) end
    else
        local m = {}
        for _, id in ipairs(e.yield.mats) do m[#m + 1] = ItemLinkOrName(id) end
        en.meta:SetText(string.format(L["Disenchants into (estimate): %s"], table.concat(m, ", ")))
        en.label1:SetText(L["ENCHANTERS IN YOUR GUILD"])
        local list = ns.Enchanters()
        local best
        for i, r in ipairs(en.rows) do
            local x = list[i]
            if x then
                local ok = x.rank == 0 or x.rank >= e.yield.skill
                r.text:SetText(CharName(x.key) .. "  " .. (x.rank > 0 and (ok and "|cff5cdb6b" or "|cffff6060") .. x.rank .. "|r" or "|cff8f96a8?|r"))
                r.link = nil
                r.sel:SetShown(false)
                r:Show()
                if ok and not best and not IsMine(x.key) then best = x.key end
            end
        end
        if #list == 0 then
            en.rows[1].text:SetText("|cff8f96a8" .. L["No enchanter known yet."] .. "|r")
            en.rows[1].sel:SetShown(false)
            en.rows[1]:Show()
        end
        en.label2:SetText(L["WHO NEEDS THESE MATS"])
        local t = {}
        for i, n in ipairs(e.needs) do
            if i > 6 then break end
            local who = n.who == "stock" and L["Guild stock"] or ns.ShortName(n.who)
            local md = ns.ItemData(n.mat)
            t[#t + 1] = string.format("%s: %dx %s", who, n.n, md and md.name or "?")
        end
        en.text2:SetText(#t > 0 and table.concat(t, "\n") or ("|cff8f96a8" .. L["Nobody right now – the mats can still go to the guild bank."] .. "|r"))
        if e.wearer then
            en.hint:SetText("|cffff8fc8" .. string.format(L["%s could wear this – maybe give it to them instead!"], ns.ShortName(e.wearer.key)) .. "|r")
            en.b1.label:SetText(string.format(L["Offer to %s"], ns.ShortName(e.wearer.key)))
            en.b1.run = function()
                Whisper(e.wearer.key, ns.Subst(L["Hi! I have {item} – it would be an upgrade for you. Want it?"], { item = e.link or ItemLinkOrName(e.itemID) }))
                ns.LogHelp("offer", e.wearer.key, e.itemID)
            end
        else
            en.hint:SetText(e.bound and L["Soulbound – only you can disenchant it."] or "")
            en.b1.label:SetText(L["Link in chat"])
            en.b1.run = function() LinkInChat(e.itemID) end
        end
        if best then
            en.b2.label:SetText(string.format(L["Offer to %s"], ns.ShortName(best)))
            en.b2.run = function()
                local who = e.needs[1] and (e.needs[1].who == "stock" and L["the guild stock"] or ns.ShortName(e.needs[1].who)) or L["the guild"]
                Whisper(best, ns.Subst(L["Hi! I have {item} I don't need. Want to disenchant it? The mats could go to {who}."],
                    { item = e.link or ItemLinkOrName(e.itemID), who = who }))
                ns.LogHelp("offer", best, e.itemID)
            end
        else
            en.b2.label:SetText(L["Whisper"])
        end
    end
    en.b1:SetActive(en.b1.run ~= nil)
    en.b2:SetActive(en.b2.run ~= nil)
end

local function CreateSettingsView(parent)
    stv = CreateFrame("Frame", nil, parent)
    stv:SetAllPoints()
    local title = Text(stv, 16, C.text)
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText(L["Settings"])
    local back = CreateFrame("Button", nil, stv)
    back:SetSize(90, 18)
    back:SetPoint("TOPRIGHT", -14, -12)
    local bt = Text(back, 10, C.muted, "RIGHT")
    bt:SetPoint("RIGHT")
    bt:SetText(L["< Overview"])
    back:SetScript("OnEnter", function() bt:SetTextColor(1, 1, 1) end)
    back:SetScript("OnLeave", function() bt:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    back:SetScript("OnClick", function() ns.OpenSettings(false) end)

    stv.toggles = {}
    local page = CreateFrame("Frame", nil, stv)
    page:SetAllPoints()
    stv.general = page
    local function section(text, y)
        local l = SectionLabel(page, text)
        l:SetPoint("TOPLEFT", 18, y)
    end
    local function toggle(label, y, get, set, tipTitle, tip)
        local t = MakeToggle(page, label, get, set)
        t:SetPoint("TOPLEFT", 18, y)
        t:SetPoint("RIGHT", -18, 0)
        if tip then AddTooltip(t, tipTitle or label, tip) end
        stv.toggles[#stv.toggles + 1] = t
        return t
    end

    section(L["UPGRADES"], -48)
    toggle(L["Only my crafters"], -64, function() return ns.S.onlyMine end,
        function(v) ns.S.onlyMine = v; ns.MarkDirty() end,
        nil, L["Only shows upgrades you can craft with your own characters."])
    toggle(L["Rate by spec stats"], -86, function() return ns.S.useStats end,
        function(v) ns.S.useStats = v; ns.MarkDirty() end, L["Rating by spec stats"],
        L["Compares strength, agility, spell power etc., weighted by specialization "] ..
        L["(the talent tree with the most points). Without talent points, or when turned off, only item level counts. "] ..
        L["Can be changed per character in the details."])
    toggle(L["Lower armor types"], -108, function() return ns.S.anyArmor end,
        function(v) ns.S.anyArmor = v; ns.MarkDirty() end, L["Lower armor classes"],
        L["E.g. also suggests leather to a warrior, not just the best armor type."])
    local dl = Text(page, 11, C.text)
    dl:SetPoint("TOPLEFT", 18, -134)
    dl:SetText(L["Min. better"])
    local plus = MakeButton(page, 20, 20, "+")
    plus:SetPoint("TOPLEFT", 200, -130)
    stv.diffValue = Text(page, 11, C.green, "CENTER")
    stv.diffValue:SetWidth(30)
    stv.diffValue:SetPoint("RIGHT", plus, "LEFT", -2, 0)
    local minus = MakeButton(page, 20, 20, "-")
    minus:SetPoint("RIGHT", stv.diffValue, "LEFT", -2, 0)
    plus:SetScript("OnClick", function() ns.S.minDiff = math.min(30, ns.S.minDiff + 1); ns.MarkDirty(); Rebuild() end)
    minus:SetScript("OnClick", function() ns.S.minDiff = math.max(1, ns.S.minDiff - 1); ns.MarkDirty(); Rebuild() end)
    AddTooltip(plus, L["Minimum improvement"], L["Only counts as an upgrade from this many item levels (or percent with spec rating) better."])

    section(L["WINDOW"], -166)
    toggle(L["Profession window panel"], -182, function() return not ns.S.hideProfPanel end,
        function(v) ns.S.hideProfPanel = (not v) or nil; if ns.RefreshProfPanel then ns.RefreshProfPanel() end end,
        nil, L["Shows next to the profession window what you can craft with this profession, and for whom."])
    toggle(L["Minimap button"], -204, function() return not (ns.S.minimap and ns.S.minimap.hide) end,
        function(v) ns.SetMinimapShown(v) end)

    section(L["SHARING"], -236)
    toggle(L["Share with friends"], -252, function() return ns.S.shareFriends end,
        function(v) ns.S.shareFriends = v; ns.MarkDirty(); if v then ns.Hello(true) end end, nil,
        L["Also exchanges data with people on your friend list who use Friendsmith, even if they aren't in your guild. Data is only accepted from people on your own friend list."])
    toggle(L["Happy about help"], -274, function() return ns.S.wishes end,
        function(v) ns.SetWishes(v) end, nil,
        L["Friendsmith asks for you: guild members and friends see by themselves what they could craft for you or which mats you need for your profession. Nobody gets a message – they only see it in Friendsmith."])
    toggle(L["Share my milestones in the guild feed"], -296, function() return ns.S.feedEvents ~= false end,
        function(v) ns.S.feedEvents = v end, nil,
        L["Profession steps, level milestones and finished mat requests show up in the guild feed."])

    section(L["HINTS"], -328)
    toggle(L["Hints after login: who I could help"], -344, function() return ns.S.nudges ~= false end,
        function(v) ns.S.nudges = v end, nil,
        L["A few lines in your own chat after login – an upgrade you could craft or mats someone needs."])
    toggle(L["Ask to say thanks after trades"], -366, function() return ns.S.tradeThanks ~= false end,
        function(v) ns.S.tradeThanks = v end)

    section(L["DATA"], -398)
    local clean = MakeButton(page, 150, 24, L["Clean up now"])
    clean:SetPoint("TOPLEFT", 18, -414)
    clean:SetScript("OnClick", function() if ns.Cleanup then ns.Cleanup(true) end end)
    AddTooltip(clean, L["Clean up now"], L["Removes old data: characters who left the guild or haven't been seen for a long time, old feed entries, expired requests and unused mats lists. Happens automatically after login, too."])
    local reset = MakeButton(page, 150, 24, L["Delete others' data"])
    reset:SetPoint("LEFT", clean, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function() SlashCmdList.FRIENDSMITH("reset") end)
    AddTooltip(reset, L["Delete others' data"], L["Deletes everything Friendsmith knows about other players. Your own characters are kept. It comes back with the next sync."])

    -- Reiter 2: Helfer-Profil
    local prof = CreateFrame("Frame", nil, stv)
    prof:SetAllPoints()
    stv.profile = prof
    local pl = SectionLabel(prof, L["I'M HAPPY TO HELP WITH"])
    pl:SetPoint("TOPLEFT", 18, -48)
    local intro = Text(prof, 10, C.muted)
    intro:SetPoint("TOPLEFT", 18, -62)
    intro:SetPoint("RIGHT", -18, 0)
    if intro.SetWordWrap then intro:SetWordWrap(true) end
    intro:SetText(L["Your guild and friends see this in the Helpers view – so people who don't like to ask know whom they can turn to. Nobody gets a message."])
    for i, t in ipairs(ns.HELP_TOPICS) do
        local tg = MakeToggle(prof, ns.TopicLabel(t),
            function() return ns.S.helpTopics and ns.S.helpTopics[t] or false end,
            function(v) ns.SetHelpTopic(t, v) end)
        tg:SetPoint("TOPLEFT", 18, -104 - (i - 1) * 24)
        tg:SetPoint("RIGHT", -18, 0)
        stv.toggles[#stv.toggles + 1] = tg
    end
    prof:Hide()

    -- Reiterknoepfe
    local function tab(label, x, w, show)
        local b = MakeButton(stv, w, 20, label)
        b:SetPoint("TOPLEFT", x, -14)
        b.label:SetFont(FONT, 10, "")
        b:SetScript("OnClick", function() stv.tab = show; ns.OpenSettings(true) end)
        return b
    end
    stv.tabs = { tab(L["General"], 120, 70, "general"), tab(L["Helper profile"], 194, 96, "profile") }
    stv.tab = "general"
    stv:Hide()
end

-- Einstellungen im Fenster zeigen/verstecken
function ns.OpenSettings(on, tab)
    if not f then CreateUI() end
    if tab and stv then stv.tab = tab end
    showSettings = on and true or false
    if showSettings then selKey, selEntry = nil, nil end
    if not f:IsShown() then f:Show() else Rebuild() end
end

local function CreateRequestView(parent)
    rq = CreateFrame("Frame", nil, parent)
    rq:SetAllPoints()

    local back = CreateFrame("Button", nil, rq)
    back:SetSize(90, 18)
    back:SetPoint("TOPRIGHT", -14, -12)
    local bt = Text(back, 10, C.muted, "RIGHT")
    bt:SetPoint("RIGHT")
    bt:SetText(L["< Overview"])
    back:SetScript("OnEnter", function() bt:SetTextColor(1, 1, 1) end)
    back:SetScript("OnLeave", function() bt:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    back:SetScript("OnClick", function() Select(nil) end)

    local ib = CreateFrame("Button", nil, rq)
    ib:SetSize(46, 46)
    ib:SetPoint("TOPLEFT", 18, -34)
    rq.icon = Icon(ib, 44)
    rq.icon:SetPoint("CENTER")
    rq.iconBorder = Border(ib, C.border)
    ib:SetScript("OnEnter", function(self)
        if selEntry then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. selEntry.itemID)
            GameTooltip:Show()
        end
    end)
    ib:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rq.name = Text(rq, 15)
    rq.name:SetPoint("TOPLEFT", ib, "TOPRIGHT", 12, -3)
    rq.name:SetPoint("RIGHT", -18, 0)
    rq.meta = Text(rq, 11, C.muted)
    rq.meta:SetPoint("BOTTOMLEFT", ib, "BOTTOMRIGHT", 12, 4)
    rq.meta:SetPoint("RIGHT", -18, 0)

    rq.mats = CreateMatsBlock(rq, -96, L["MATS NEEDED"])
    rq.hint = Text(rq, 11, C.text)
    rq.hint:SetPoint("TOPLEFT", 18, -200)
    rq.hint:SetPoint("RIGHT", -18, 0)
    if rq.hint.SetWordWrap then rq.hint:SetWordWrap(true) end

    rq.link = MakeButton(rq, 100, 26, L["Link in chat"])
    rq.link:SetPoint("BOTTOMLEFT", 18, 14)
    rq.link:SetScript("OnClick", function() if selEntry then LinkInChat(selEntry.itemID) end end)
    rq.act = MakeButton(rq, 150, 26, L["Whisper: I can help"], true)
    rq.act:SetPoint("BOTTOMRIGHT", -18, 14)
    rq.act:SetScript("OnClick", function(self) if self.run then self.run() end end)
end

local function RenderRequest(e)
    local r = e.r
    local d = ns.ItemData(r.item)
    local qr, qg, qb = QualityColor(d and d.quality)
    rq.icon:SetTexture(d and d.icon or EMPTY_ICON)
    SetBorderColor(rq.iconBorder, qr, qg, qb, 1)
    rq.name:SetText(d and d.name or L["Loading item data …"])
    rq.name:SetTextColor(qr, qg, qb)
    rq.meta:SetText(string.format(L["Requested by %s · %s ago"], CharName(r.from), AgeText(r.t)))
    RenderMats(rq.mats, r.mats)

    local mine = r.from == ns.PlayerKey() or IsMine(r.from)
    local have = {}
    for _, m in ipairs(r.mats) do
        local own = ns.OwnCount(m[1])
        if own > 0 then have[#have + 1] = math.min(own, m[2]) .. "x " .. ItemLinkOrName(m[1]) end
    end
    if mine then
        rq.hint:SetText(L["This is your request. Close it once you have everything."])
        rq.act.label:SetText(L["Close request"])
        rq.act.run = r.from == ns.PlayerKey() and function() ns.CloseRequest(r); Select(nil) end or nil
    else
        rq.hint:SetText(#have > 0 and ("|cff5cdb6b" .. L["You have some of these mats – offer them with a whisper."] .. "|r")
            or L["You don't have any of these mats. Maybe someone else in your guild can help."])
        rq.act.label:SetText(L["Whisper: I can help"])
        rq.act.run = function()
            ns.LogHelp("offer", r.from, r.item)
            Whisper(r.from, ns.Subst(L["Hi! I saw your Friendsmith request for {item}. I can help with: {mats}"],
                { item = ItemLinkOrName(r.item), mats = #have > 0 and table.concat(have, ", ") or L["some of it"] }), r.sender)
        end
    end
    rq.act:SetActive(rq.act.run ~= nil)
end

function RenderDetail()
    if not detail then return end
    ov:Hide(); it:Hide(); fd:Hide(); rq:Hide(); sk:Hide(); ph:Hide(); fv:Hide(); stv:Hide(); hp:Hide(); en:Hide()
    if showSettings then
        stv:Show()
        local prof = stv.tab == "profile"
        stv.general:SetShown(not prof)
        stv.profile:SetShown(prof)
        for i, b in ipairs(stv.tabs) do
            local on = (i == 2) == prof
            b.bg:SetColorTexture(on and C.accentBtn[1] or C.panel2[1], on and C.accentBtn[2] or C.panel2[2], on and C.accentBtn[3] or C.panel2[3], 1)
        end
        return
    end
    if selEntry and (selEntry.enchSlot or selEntry.deItem) then
        en:Show()
        RenderEnch(selEntry)
        return
    end
    if selEntry and selEntry.helper then
        hp:Show()
        RenderHelper(selEntry)
        return
    end
    if selEntry and selEntry.feedEntry then
        fv:Show()
        RenderFeed(selEntry)
        return
    end
    if selEntry and selEntry.prof then
        ph:Show()
        RenderProf(selEntry)
    elseif selEntry and selEntry.stock then
        sk:Show()
        RenderStock(selEntry)
    elseif selEntry and selEntry.request then
        rq:Show()
        RenderRequest(selEntry)
    elseif selEntry and selEntry.food then
        fd:Show()
        RenderFood(selEntry)
    elseif selEntry then
        it:Show()
        RenderItem(selEntry)
    else
        ov:Show()
        RenderOverview()
    end
end

local function CreateDetail()
    detail = CreateFrame("Frame", nil, f)
    detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 0, 0)
    detail:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1 + STATUS_H)
    Fill(detail, C.panel)
    CreateOverview(detail)
    CreateItemView(detail)
    CreateFoodView(detail)
    CreateRequestView(detail)
    CreateStockView(detail)
    CreateProfView(detail)
    CreateFeedView(detail)
    CreateSettingsView(detail)
    CreateHelperView(detail)
    CreateEnchView(detail)
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
function CreateUI()
    f = CreateFrame("Frame", "FriendsmithFrame", UIParent)
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    tinsert(UISpecialFrames, "FriendsmithFrame")
    Fill(f, C.bg)
    Border(f, { 0, 0, 0, 1 })

    CreateHeader()
    CreateSidebar()
    CreateList()
    CreateDetail()

    status = CreateFrame("Frame", nil, f)
    status:SetPoint("BOTTOMLEFT", 1, 1)
    status:SetPoint("BOTTOMRIGHT", -1, 1)
    status:SetHeight(STATUS_H)
    Fill(status, C.header)
    local sl = status:CreateTexture(nil, "BORDER")
    sl:SetPoint("TOPLEFT")
    sl:SetPoint("TOPRIGHT")
    sl:SetHeight(1)
    sl:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    status.left = Text(status, 10, C.muted)
    status.left:SetPoint("LEFT", 12, 0)
    local right = Text(status, 10, C.muted, "RIGHT")
    right:SetPoint("RIGHT", -12, 0)
    right:SetText("v" .. ns.VERSION .. "  ·  " .. L["/fsmith help"])

    f:SetScript("OnShow", function() Rebuild() end)
end

function ns.RefreshUI()
    if not f or not f:IsShown() then return end
    Rebuild()
end

function ns.ToggleUI()
    if not f then CreateUI() end
    f:SetShown(not f:IsShown())
end

-- Fenster oeffnen und direkt eine Ansicht/einen Eintrag zeigen (z. B. aus der Berufsfenster-Leiste)
function ns.OpenUI(v, e)
    if not f then CreateUI() end
    if v then view = v; offset = 0 end
    if e then selKey = EntryKey(e) end
    if f:IsShown() then Rebuild() else f:Show() end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function AddTooltipLines(tt, itemID)
    if not itemID or InCombatLockdown() or not FriendsmithDB then return end
    ns.GetResults()
    local who = ns.craftable and ns.craftable[itemID]
    if not who then return end
    tt:AddLine(L["Friendsmith – craftable by: "] .. CrafterNames(who), 0.95, 0.6, 0.3, true)
    local ups = ns.byItem and ns.byItem[itemID]
    if ups then
        local t = {}
        for _, e in ipairs(ups) do
            t[#t + 1] = CharName(e.target) .. " " .. DiffText(e)
        end
        tt:AddLine(L["Upgrade for: "] .. table.concat(t, ", "), 0.3, 1, 0.3, true)
    end
    tt:Show()
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
        local ok, id = pcall(function() return data and data.id end)
        if ok and type(id) == "number" then AddTooltipLines(tt, id) end
    end)
else
    local function OnSetItem(tt)
        local _, link = tt:GetItem()
        if link then AddTooltipLines(tt, tonumber(link:match("item:(%d+)"))) end
    end
    GameTooltip:HookScript("OnTooltipSetItem", OnSetItem)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", OnSetItem) end
end

---------------------------------------------------------------------------
-- Befehle
---------------------------------------------------------------------------
SLASH_FRIENDSMITH1 = "/friendsmith"
SLASH_FRIENDSMITH2 = "/fsmith"
SlashCmdList.FRIENDSMITH = function(msg)
    local rawMsg = msg
    msg = ((msg or ""):lower():match("^%s*(.-)%s*$")) or ""
    if msg == "sync" then
        ns.Hello(true)
        ns.Print(L["Sent your data to your guild and friends and requested theirs."])
    elseif msg == "scan" then
        ns.UpdateSelf()
        ns.ScanRecipes(true)
    elseif msg:match("^diff") then
        local n = tonumber(msg:match("%d+"))
        if n then ns.S.minDiff = math.max(1, n); ns.MarkDirty() end
        ns.Print(string.format(L["Minimum improvement: %d (item levels, or percent with spec rating)."], ns.S.minDiff))
    elseif msg == "armor" or msg == "ruestung" or msg == "rüstung" then
        ns.S.anyArmor = not ns.S.anyArmor
        ns.MarkDirty()
        ns.Print(ns.S.anyArmor and L["Lower armor types will be suggested too."]
            or L["Only each class's best armor type will be suggested."])
    elseif msg == "minimap" then
        local show = ns.S.minimap and ns.S.minimap.hide
        ns.SetMinimapShown(show and true or false)
        ns.Print(show and L["Minimap button shown."] or L["Minimap button hidden."])
    elseif msg == "stock" or msg == "lager" then
        ns.OpenUI("stock")
    elseif msg:match("^target") or msg:match("^ziel") then
        -- /fsmith target [Item] 40   (0 = entfernen); Links behalten wir aus dem Originaltext
        local raw = (rawMsg or ""):gsub("^%s*%S+%s*", "")
        local amount = tonumber(raw:match("(%d+)%s*$"))
        local id = ns.ParseItem((raw:gsub("%s*%d+%s*$", "")))
        if id and amount then
            if ns.SetTarget(id, amount) then
                ns.Print(string.format(L["Stock target for %s: %d"], ItemLinkOrName(id), amount))
            end
        else
            ns.Print(L["/fsmith target [item] 40 – set a stock target (0 removes it)"])
        end
    elseif msg:match("^thanks") or msg:match("^danke") then
        local raw = (rawMsg or ""):gsub("^%s*%S+%s*", "")
        local name = raw:match("^(%S+)")
        if not name and UnitName then name = UnitName("target") end
        local item = ns.ParseItem and ns.ParseItem(raw:gsub("^%S+%s*", ""))
        if name then ns.Thank(name, item) else ns.Print(L["/fsmith thanks Name [item] – say thanks (or target the player)"]) end
    elseif msg == "settings" or msg == "options" or msg == "einstellungen" then
        ns.OpenSettings(true)
    elseif msg == "cleanup" or msg == "aufraeumen" or msg == "aufräumen" then
        if ns.Cleanup then ns.Cleanup(true) end
    elseif msg == "helpers" or msg == "helfer" then
        ns.OpenUI("helpers")
    elseif msg == "profile" or msg == "profil" then
        ns.OpenSettings(true, "profile")
    elseif msg == "enchanting" or msg == "ench" or msg == "verzaubern" then
        ns.OpenUI("ench")
    elseif msg == "feed" then
        ns.OpenUI("feed")
    elseif msg == "milestones" or msg == "meilensteine" then
        ns.S.feedEvents = not (ns.S.feedEvents ~= false)
        ns.Print(ns.S.feedEvents and L["Your milestones are shared in the guild feed."] or L["Your milestones are no longer shared."])
    elseif msg == "tradethanks" then
        ns.S.tradeThanks = not (ns.S.tradeThanks ~= false)
        ns.Print(ns.S.tradeThanks and L["After trades you'll be asked whether to say thanks."] or L["No more thank-you prompts after trades."])
    elseif msg == "wishes" or msg == "wuensche" or msg == "wünsche" then
        ns.SetWishes(not ns.S.wishes)
        ns.Print(ns.S.wishes and L["Silent wishes on: your guild sees where it could help you – you don't have to ask."] or L["Silent wishes off."])
    elseif msg == "nudges" or msg == "hinweise" then
        ns.S.nudges = not ns.S.nudges
        ns.Print(ns.S.nudges and L["Login hints on."] or L["Login hints off."])
    elseif msg == "help me" or msg == "helfen" then
        if (ns.Nudge(true) or 0) == 0 then ns.Print(L["Right now nobody needs anything you have."]) end
    elseif msg == "foodcheck" or msg == "essen" then
        ns.FoodCheck()
    elseif msg == "debug" then
        ns.S.debug = not ns.S.debug or nil
        ns.Print(ns.S.debug and L["Debug on: incoming Friendsmith messages are shown in chat."] or L["Debug off."])
    elseif msg == "reset" then
        for k, rec in pairs(FriendsmithDB.chars) do
            if not rec.mine then FriendsmithDB.chars[k] = nil end
        end
        ns.MarkDirty()
        ns.Print(L["Stored guild data deleted (your own characters are kept)."])
    elseif msg == "help" or msg == "hilfe" then
        ns.Print(L["/fsmith – open/close the window"])
        ns.Print(L["/fsmith sync – exchange data with your guild and friends"])
        ns.Print(L["/fsmith scan – rescan the profession window (must be open)"])
        ns.Print(L["/fsmith diff 3 – only count +3 or more as an upgrade"])
        ns.Print(L["/fsmith armor – allow lower armor types (on/off)"])
        ns.Print(L["/fsmith minimap – minimap button on/off"])
        ns.Print(L["/fsmith wishes – \"happy about help\" on/off"])
        ns.Print(L["/fsmith nudges – login hints on/off"])
        ns.Print(L["/fsmith thanks Name [item] – say thanks (or target the player)"])
        ns.Print(L["/fsmith feed – open the guild feed"])
        ns.Print(L["/fsmith milestones – share your milestones on/off"])
        ns.Print(L["/fsmith tradethanks – thank-you prompt after trades on/off"])
        ns.Print(L["/fsmith settings – open the settings"])
        ns.Print(L["/fsmith helpers – who is happy to help with what"])
        ns.Print(L["/fsmith ench – enchants for your gear and spare gear to disenchant"])
        ns.Print(L["/fsmith profile – set up your helper profile"])
        ns.Print(L["/fsmith cleanup – remove old data now"])
        ns.Print(L["/fsmith stock – open the guild stock"])
        ns.Print(L["/fsmith target [item] 40 – set a stock target (0 removes it)"])
        ns.Print(L["/fsmith reset – delete other guild members' data"])
    else
        ns.ToggleUI()
    end
end

---------------------------------------------------------------------------
-- Eintrag im Blizzard-Menue (Optionen -> AddOns)
---------------------------------------------------------------------------
do
    local panel = CreateFrame("Frame")
    panel.name = "Friendsmith"
    local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("Friendsmith")
    local d = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    d:SetPoint("RIGHT", -16, 0)
    d:SetJustifyH("LEFT")
    d:SetText(L["All settings are in the Friendsmith window."])
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(200, 26)
    b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
    b:SetText(L["Open Friendsmith settings"])
    b:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() and HideUIPanel then HideUIPanel(InterfaceOptionsFrame) end
        ns.OpenSettings(true)
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        pcall(function()
            local cat = Settings.RegisterCanvasLayoutCategory(panel, "Friendsmith")
            Settings.RegisterAddOnCategory(cat)
        end)
    elseif InterfaceOptions_AddCategory then
        pcall(InterfaceOptions_AddCategory, panel)
    end
end
