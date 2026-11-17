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
local MAX_CRAFTER_ROWS = 5

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

local function Tag(key)
    if key == ns.PlayerKey() then return "|cfff2852e" .. L["You"] .. "|r" end
    if IsMine(key) then return "|cff7fb2ff" .. L["Alt"] .. "|r" end
    local r = Rec(key)
    if r and r.friend and (not r.guild or r.guild ~= GetGuildInfo("player")) then
        return "|cff66d9a6" .. L["Friend"] .. "|r"
    end
    return "|cff8f96a8" .. L["Guild"] .. "|r"
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

local function WhisperName(key)
    local realm = key:match("%-([^%-]+)$")
    local mine = ns.PlayerKey():match("%-([^%-]+)$")
    if realm and realm == mine then return ns.ShortName(key) end
    return key
end

local function OpenChat(text)
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(text)
    else
        ns.Print(text)
    end
end

local function Whisper(key, msg)
    OpenChat("/w " .. WhisperName(key) .. " " .. (msg or ""))
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
local counts = { all = 0, mine = 0, help = 0, food = 0 }
local foodGroups = {}

local Rebuild, RenderList, RenderDetail

local function EntryKey(e)
    if e.food then return "food#" .. e.itemID end
    return e.target .. "#" .. e.itemID
end

local function InView(e, v)
    if v == "mine" then return IsMine(e.target) end
    if v == "help" then return AnyMine(e.crafters) end
    return true
end

local function Matches(e)
    if query == "" then return true end
    local d = ns.ItemData(e.itemID)
    if d and d.name:lower():find(query, 1, true) then return true end
    if e.food then
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
    return a < b
end

---------------------------------------------------------------------------
-- Liste aufbauen
---------------------------------------------------------------------------
function Rebuild()
    local results = ns.GetResults() or {}
    ns.S.collapsed = ns.S.collapsed or {}

    counts.all, counts.mine, counts.help = #results, 0, 0
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
    if not selEntry then selKey = nil end

    local groups, order = {}, {}
    for _, e in ipairs(view ~= "food" and results or {}) do
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

    wipe(flat)
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
    for _, k in ipairs(order) do
        local ck = groupBy .. ":" .. k
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
    for _, t in ipairs(sidebar.toggles) do t:Update() end
    sidebar.diffValue:SetText("+" .. ns.S.minDiff)

    -- Gruppieren-Schalter
    list.groupLabel:SetShown(view ~= "food")
    for _, sb in ipairs(list.seg) do
        sb:SetShown(view ~= "food")
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
                if it.food then
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
                if e.food then
                    local more = #e.crafters > 1 and (" +" .. (#e.crafters - 1)) or ""
                    r.meta:SetText(CharName(e.crafters[1]) .. more)
                    r.gain:SetText((e.rank == 1 and "|cffffd140" or "") .. "+" .. e.amount)
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
    if e and selKey == EntryKey(e) then e = nil end
    selKey = e and EntryKey(e) or nil
    selEntry = e
    RenderList()
    RenderDetail()
end

local function SetView(v)
    view = v
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
        b:SetHeight(30)
        b:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 32)
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
    AddTooltip(sidebar.nav[4], L["Buff food"], L["Who can cook the best \"Well Fed\" food in each category – Stamina, Spirit, Agility and so on."])

    local flbl = SectionLabel(sidebar, L["FILTER"])
    flbl:SetPoint("TOPLEFT", 14, -174)

    sidebar.toggles = {}
    local t1 = MakeToggle(sidebar, L["Only my crafters"],
        function() return ns.S.onlyMine end,
        function(v) ns.S.onlyMine = v; ns.MarkDirty() end)
    t1:SetPoint("TOPLEFT", 14, -190)
    t1:SetPoint("RIGHT", -10, 0)
    AddTooltip(t1, L["Only my crafters"], L["Only shows upgrades you can craft with your own characters."])
    local t2 = MakeToggle(sidebar, L["Lower armor types"],
        function() return ns.S.anyArmor end,
        function(v) ns.S.anyArmor = v; ns.MarkDirty() end)
    t2:SetPoint("TOPLEFT", 14, -238)
    t2:SetPoint("RIGHT", -10, 0)
    AddTooltip(t2, L["Lower armor classes"], L["E.g. also suggests leather to a warrior, not just the best armor type."])
    local t3 = MakeToggle(sidebar, L["Profession window panel"],
        function() return not ns.S.hideProfPanel end,
        function(v) ns.S.hideProfPanel = (not v) or nil; if ns.RefreshProfPanel then ns.RefreshProfPanel() end end)
    t3:SetPoint("TOPLEFT", 14, -294)
    t3:SetPoint("RIGHT", -10, 0)
    AddTooltip(t3, L["Profession window panel"], L["Shows next to the profession window what you can craft with this profession, and for whom."])
    local t4 = MakeToggle(sidebar, L["Rate by spec stats"],
        function() return ns.S.useStats end,
        function(v) ns.S.useStats = v; ns.MarkDirty() end)
    t4:SetPoint("TOPLEFT", 14, -214)
    t4:SetPoint("RIGHT", -10, 0)
    AddTooltip(t4, L["Rating by spec stats"],
        L["Compares strength, agility, spell power etc., weighted by specialization "] ..
        L["(the talent tree with the most points). Without talent points, or when turned off, only item level counts. "] ..
        L["Can be changed per character in the details."])
    local t5 = MakeToggle(sidebar, L["Minimap button"],
        function() return not (ns.S.minimap and ns.S.minimap.hide) end,
        function(v) ns.SetMinimapShown(v) end)
    t5:SetPoint("TOPLEFT", 14, -318)
    t5:SetPoint("RIGHT", -10, 0)
    local t6 = MakeToggle(sidebar, L["Share with friends"],
        function() return ns.S.shareFriends end,
        function(v) ns.S.shareFriends = v; ns.MarkDirty(); if v then ns.Hello(true) end end)
    t6:SetPoint("TOPLEFT", 14, -342)
    t6:SetPoint("RIGHT", -10, 0)
    AddTooltip(t6, L["Share with friends"],
        L["Also exchanges data with people on your friend list who use Friendsmith, even if they aren't in your guild. Data is only accepted from people on your own friend list."])
    sidebar.toggles = { t1, t4, t2, t3, t5, t6 }

    local dl = Text(sidebar, 11, C.text)
    dl:SetPoint("TOPLEFT", 14, -268)
    dl:SetText(L["Min. better"])
    local plus = MakeButton(sidebar, 20, 20, "+")
    plus:SetPoint("TOPRIGHT", -10, -264)
    sidebar.diffValue = Text(sidebar, 11, C.green, "CENTER")
    sidebar.diffValue:SetWidth(30)
    sidebar.diffValue:SetPoint("RIGHT", plus, "LEFT", -2, 0)
    local minus = MakeButton(sidebar, 20, 20, "-")
    minus:SetPoint("RIGHT", sidebar.diffValue, "LEFT", -2, 0)
    plus:SetScript("OnClick", function() ns.S.minDiff = math.min(30, ns.S.minDiff + 1); ns.MarkDirty(); Rebuild() end)
    minus:SetScript("OnClick", function() ns.S.minDiff = math.max(1, ns.S.minDiff - 1); ns.MarkDirty(); Rebuild() end)
    AddTooltip(plus, L["Minimum improvement"], L["Only counts as an upgrade from this many item levels (or percent with spec rating) better."])

    local sync = MakeButton(sidebar, SIDEBAR_W - 20, 28, L["Sync"], true)
    sync:SetPoint("BOTTOMLEFT", 10, 12)
    sync:SetScript("OnClick", function()
        ns.Hello(true)
        ns.Print(L["Sent your data to your guild and friends and requested theirs."])
    end)
    AddTooltip(sync, L["Sync"], L["Sends your data to your guild and online friends using Friendsmith and requests theirs."])
    local rescan = MakeButton(sidebar, SIDEBAR_W - 20, 24, L["Rescan gear"])
    rescan:SetPoint("BOTTOMLEFT", sync, "TOPLEFT", 0, 6)
    rescan:SetScript("OnClick", function()
        ns.UpdateSelf()
        ns.MarkDirty()
    end)
end

---------------------------------------------------------------------------
-- Liste (wie im Berufsfenster: einklappbare Gruppen)
---------------------------------------------------------------------------
local function ShowFoodTooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. e.itemID)
    GameTooltip:AddLine(" ")
    if e.rank == 1 then
        GameTooltip:AddLine(string.format(L["Best %s food you can get (+%d)"], e.label, e.amount), 1, 0.82, 0.25, true)
    else
        local bd = ns.ItemData(e.best.itemID)
        GameTooltip:AddLine(string.format(L["Better: %s (+%d) by %s"], bd and bd.name or "?", e.best.amount, CrafterNames(e.best.crafters)), 1, 1, 1, true)
    end
    GameTooltip:AddLine(L["Cooked by: "] .. CrafterNames(e.crafters), 1, 1, 1, true)
    GameTooltip:AddLine(L["Click: details · Shift-click: link"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function ShowEntryTooltip(owner, e)
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
local ov, it, fd -- Uebersicht / Gegenstand / Essen

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
        StatCard(ov, L["CRAFTERS"], "Interface\\Icons\\INV_Misc_Note_01"),
        StatCard(ov, L["GUILD & FRIENDS"], "Interface\\Icons\\INV_Misc_Gear_01"),
    }
    for i, c in ipairs(ov.cards) do
        c:SetWidth(cw)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        c:SetPoint("TOPLEFT", 18 + col * (cw + 10), -62 - row * 64)
    end

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
    ov.cards[3].value:SetText(st.crafters)
    ov.cards[4].value:SetText(counts.all)

    local hints = {}
    local function add(title, body, action) hints[#hints + 1] = { title, body, action } end

    local myRecipes = 0
    local rec = DB.chars[me]
    if rec and rec.recipes then for _ in pairs(rec.recipes) do myRecipes = myRecipes + 1 end end
    local foreign = 0
    for _, r in pairs(DB.chars) do if not r.mine then foreign = foreign + 1 end end

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
        it.crafters[i] = r
    end
    it.more = Text(it, 10, C.muted)
    it.more:SetPoint("TOPLEFT", 18, -264 - MAX_CRAFTER_ROWS * 28)

    -- Aktionen
    it.link = MakeButton(it, 150, 26, L["Link in chat"])
    it.link:SetPoint("BOTTOMLEFT", 18, 14)
    it.link:SetScript("OnClick", function() if selEntry then LinkInChat(selEntry.itemID) end end)
    it.ask = MakeButton(it, 150, 26, L["Whisper request"], true)
    it.ask:SetPoint("BOTTOMRIGHT", -18, 14)
    it.ask:SetScript("OnClick", function(self) if self.run then self.run() end end)
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
            r.name:SetText(CharName(k))
            r.sub:SetText(Tag(k))
            r.btn:SetShown(not IsMine(k))
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
    fd.amount:SetText("+" .. e.amount)
    fd.rank:SetText(e.rank == 1 and L["BEST"] or string.format(L["RANK %d"], e.rank))
    if e.rank == 1 then
        fd.best:SetText("|cffffd140" .. L["This is the best food in this category."] .. "|r")
    else
        local bd = ns.ItemData(e.best.itemID)
        fd.best:SetText((bd and bd.name or "?") .. "  |cff5cdb6b+" .. e.best.amount .. "|r  ·  " .. CrafterNames(e.best.crafters))
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

function RenderDetail()
    if not detail then return end
    ov:Hide(); it:Hide(); fd:Hide()
    if selEntry and selEntry.food then
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
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local function CreateUI()
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
        ns.Print(L["/fsmith reset – delete other guild members' data"])
    else
        ns.ToggleUI()
    end
end
