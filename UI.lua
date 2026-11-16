-- Friendsmith – Fenster, Tooltip und Befehle
-- Aufbau: Kopfzeile (Suche) | Seitenleiste (Ansicht, Filter) | Liste wie im Berufsfenster | Details

local ADDON, ns = ...

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
    [1] = "Kopf", [2] = "Hals", [3] = "Schulter", [5] = "Brust", [6] = "Taille",
    [7] = "Beine", [8] = "Füße", [9] = "Handgelenke", [10] = "Hände",
    [11] = "Finger", [12] = "Finger", [13] = "Schmuck", [14] = "Schmuck",
    [15] = "Rücken", [16] = "Waffenhand", [17] = "Schildhand", [18] = "Distanz",
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
    return string.format("Stufe %s %s", r.level or "?", cls)
end

local function Tag(key)
    if key == ns.PlayerKey() then return "|cfff2852eDu|r" end
    if IsMine(key) then return "|cff7fb2ffTwink|r" end
    return "|cff8f96a8Gilde|r"
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
    if not e.cur then return "neu" end
    if e.pct and e.pct >= 999 then return "++" end
    if e.mode == "stat" then return "+" .. e.pct .. "%" end
    return "+" .. e.diff
end

-- lang fuer Texte: "+5 iLvl", "+12 % besser"
local function GainText(e)
    if not e.cur then return "freier Platz" end
    if e.mode == "stat" then
        if e.pct >= 999 then return "deutlich besser" end
        return "+" .. e.pct .. " % besser"
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
local counts = { all = 0, mine = 0, help = 0 }

local Rebuild, RenderList, RenderDetail

local function EntryKey(e) return e.target .. "#" .. e.itemID end

local function InView(e, v)
    if v == "mine" then return IsMine(e.target) end
    if v == "help" then return AnyMine(e.crafters) end
    return true
end

local function Matches(e)
    if query == "" then return true end
    local d = ns.ItemData(e.itemID)
    if d and d.name:lower():find(query, 1, true) then return true end
    if ns.ShortName(e.target):lower():find(query, 1, true) then return true end
    if (SLOT_NAMES[e.slot] or ""):lower():find(query, 1, true) then return true end
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
    if not selEntry then selKey = nil end

    local groups, order = {}, {}
    for _, e in ipairs(results) do
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
            list.empty:SetText("Nichts gefunden für \"" .. query .. "\".")
        elseif view == "help" then
            list.empty:SetText("Gerade kannst du mit keinem deiner Charaktere\njemandem ein Upgrade craften.\n\nÖffne deine Berufsfenster, damit die\nRezepte erfasst werden.")
        elseif view == "mine" then
            list.empty:SetText("Gerade kann dir niemand ein Upgrade craften.\n\nSynce mit der Gilde, damit du ihre\nRezepte siehst.")
        else
            list.empty:SetText("Noch keine Upgrades gefunden.\n\nÖffne bei deinen Handwerkern einmal\ndas Berufsfenster und synce mit der Gilde.")
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
    for _, sb in ipairs(list.seg) do
        local on = (sb.mode == groupBy)
        sb.bg:SetColorTexture(on and C.accentBtn[1] or C.panel2[1], on and C.accentBtn[2] or C.panel2[2],
            on and C.accentBtn[3] or C.panel2[3], 1)
    end

    local st = ns.stats or { targets = 0, crafters = 0 }
    status.left:SetText(string.format("%d Upgrades  ·  %d Charaktere  ·  %d Handwerker%s",
        counts.all, st.targets, st.crafters, ns.pending and "  ·  |cfff2852elade Itemdaten …|r" or ""))

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
                r.title:SetText(CharName(it.key))
                local rec = Rec(it.key)
                r.sub:SetText((rec and rec.level and ("Stufe " .. rec.level) or "") .. "  " .. Tag(it.key))
                r.count:SetText(it.n)
                r.sel:Hide()
                r.bar:Hide()
            else
                local e = it.e
                local d = ns.ItemData(e.itemID)
                r.icon:SetTexture(d and d.icon or EMPTY_ICON)
                r.name:SetText(d and d.name or "Lade …")
                r.name:SetTextColor(QualityColor(d and d.quality))
                if groupBy == "crafter" then
                    r.meta:SetText(CharName(e.target))
                else
                    r.meta:SetText(SLOT_NAMES[e.slot] or "")
                end
                r.gain:SetText(DiffText(e))
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
    sub:SetText("Gilden-Handwerk & Upgrades")

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
    ph:SetText("Suchen: Gegenstand, Name, Platz …")
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
    { view = "mine", label = "Für mich",         icon = "Interface\\Icons\\INV_Chest_Chain_05" },
    { view = "help", label = "Ich kann craften", icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { view = "all",  label = "Ganze Gilde",      icon = "Interface\\Icons\\INV_Misc_Book_09" },
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

    local lbl = SectionLabel(sidebar, "ANSICHT")
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
    AddTooltip(sidebar.nav[1], "Für mich", "Wer kann dir oder deinen Twinks etwas Besseres craften?")
    AddTooltip(sidebar.nav[2], "Ich kann craften", "Für wen kannst du mit deinen Berufen etwas Besseres craften – deine Twinks und die Gilde.")
    AddTooltip(sidebar.nav[3], "Ganze Gilde", "Alles, was irgendwer in der Gilde irgendwem craften kann.")

    local flbl = SectionLabel(sidebar, "FILTER")
    flbl:SetPoint("TOPLEFT", 14, -142)

    sidebar.toggles = {}
    local t1 = MakeToggle(sidebar, "Nur meine Handwerker",
        function() return ns.S.onlyMine end,
        function(v) ns.S.onlyMine = v; ns.MarkDirty() end)
    t1:SetPoint("TOPLEFT", 14, -158)
    t1:SetPoint("RIGHT", -10, 0)
    AddTooltip(t1, "Nur meine Handwerker", "Zeigt nur Upgrades, die du mit deinen eigenen Charakteren craften kannst.")
    local t2 = MakeToggle(sidebar, "Niedrigere Rüstung",
        function() return ns.S.anyArmor end,
        function(v) ns.S.anyArmor = v; ns.MarkDirty() end)
    t2:SetPoint("TOPLEFT", 14, -206)
    t2:SetPoint("RIGHT", -10, 0)
    AddTooltip(t2, "Niedrigere Rüstungsklassen", "Schlägt z. B. einem Krieger auch Leder vor, nicht nur die beste Rüstungsklasse.")
    local t3 = MakeToggle(sidebar, "Leiste am Berufsfenster",
        function() return not ns.S.hideProfPanel end,
        function(v) ns.S.hideProfPanel = (not v) or nil; if ns.RefreshProfPanel then ns.RefreshProfPanel() end end)
    t3:SetPoint("TOPLEFT", 14, -262)
    t3:SetPoint("RIGHT", -10, 0)
    AddTooltip(t3, "Leiste am Berufsfenster", "Zeigt neben dem Berufsfenster, was du mit diesem Beruf für wen craften kannst.")
    local t4 = MakeToggle(sidebar, "Nach Spec-Werten",
        function() return ns.S.useStats end,
        function(v) ns.S.useStats = v; ns.MarkDirty() end)
    t4:SetPoint("TOPLEFT", 14, -182)
    t4:SetPoint("RIGHT", -10, 0)
    AddTooltip(t4, "Nach Spec-Werten bewerten",
        "Vergleicht Stärke, Beweglichkeit, Zaubermacht usw. gewichtet nach der Spezialisierung " ..
        "(Talentbaum mit den meisten Punkten). Ohne Talentpunkte oder ausgeschaltet zählt nur das Itemlevel. " ..
        "Pro Charakter änderbar in den Details.")
    local t5 = MakeToggle(sidebar, "Minimap-Button",
        function() return not (ns.S.minimap and ns.S.minimap.hide) end,
        function(v) ns.SetMinimapShown(v) end)
    t5:SetPoint("TOPLEFT", 14, -286)
    t5:SetPoint("RIGHT", -10, 0)
    sidebar.toggles = { t1, t4, t2, t3, t5 }

    local dl = Text(sidebar, 11, C.text)
    dl:SetPoint("TOPLEFT", 14, -236)
    dl:SetText("Mind. besser")
    local plus = MakeButton(sidebar, 20, 20, "+")
    plus:SetPoint("TOPRIGHT", -10, -232)
    sidebar.diffValue = Text(sidebar, 11, C.green, "CENTER")
    sidebar.diffValue:SetWidth(30)
    sidebar.diffValue:SetPoint("RIGHT", plus, "LEFT", -2, 0)
    local minus = MakeButton(sidebar, 20, 20, "-")
    minus:SetPoint("RIGHT", sidebar.diffValue, "LEFT", -2, 0)
    plus:SetScript("OnClick", function() ns.S.minDiff = math.min(30, ns.S.minDiff + 1); ns.MarkDirty(); Rebuild() end)
    minus:SetScript("OnClick", function() ns.S.minDiff = math.max(1, ns.S.minDiff - 1); ns.MarkDirty(); Rebuild() end)
    AddTooltip(plus, "Mindest-Verbesserung", "Erst ab so vielen Itemleveln mehr (bzw. Prozent bei Spec-Bewertung) gilt etwas als Upgrade.")

    local sync = MakeButton(sidebar, SIDEBAR_W - 20, 28, "Gilde syncen", true)
    sync:SetPoint("BOTTOMLEFT", 10, 12)
    sync:SetScript("OnClick", function()
        ns.Hello()
        ns.Print("Daten an die Gilde gesendet und angefragt.")
    end)
    AddTooltip(sync, "Gilde syncen", "Sendet deine Daten an alle mit Friendsmith und fragt ihre an.")
    local rescan = MakeButton(sidebar, SIDEBAR_W - 20, 24, "Ausrüstung neu einlesen")
    rescan:SetPoint("BOTTOMLEFT", sync, "TOPLEFT", 0, 6)
    rescan:SetScript("OnClick", function()
        ns.UpdateSelf()
        ns.MarkDirty()
    end)
end

---------------------------------------------------------------------------
-- Liste (wie im Berufsfenster: einklappbare Gruppen)
---------------------------------------------------------------------------
local function ShowEntryTooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. e.itemID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Für: " .. CharName(e.target), 1, 1, 1)
    local cd = e.cur and ns.ItemData(e.cur)
    if cd then
        GameTooltip:AddLine("Trägt aktuell: " .. cd.link .. " (iLvl " .. cd.ilvl .. ")", 1, 1, 1)
    else
        GameTooltip:AddLine("Platz ist leer", 1, 1, 1)
    end
    GameTooltip:AddLine("Verbesserung: " .. GainText(e) .. "  (" .. ns.SpecLabel(e.target) .. ")", 0.36, 0.86, 0.42)
    local tr = Rec(e.target)
    local diffs = ns.StatDiffText(ns.ItemStats(e.itemID), e.cur and ns.ItemStats(e.cur, tr and tr.suffix and tr.suffix[e.slot]), ns.WeightsFor(e.target))
    if diffs ~= "" then GameTooltip:AddLine(diffs, 1, 1, 1, true) end
    GameTooltip:AddLine("Herstellbar von: " .. CrafterNames(e.crafters), 1, 1, 1, true)
    GameTooltip:AddLine("Klick: Details · Shift-Klick: verlinken · Strg-Klick: anprobieren", 0.6, 0.6, 0.6)
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
    local gl = SectionLabel(list, "GRUPPIEREN")
    gl:SetPoint("TOPLEFT", 12, -16)
    list.seg = {}
    local modes = { { "target", "Empfänger" }, { "crafter", "Handwerker" } }
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
local ov, it -- Uebersicht / Gegenstand

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
    t:SetText("Übersicht")
    ov.who = Text(ov, 11, C.muted)
    ov.who:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)

    local cw = (W - 2 - SIDEBAR_W - LIST_W - 36 - 10) / 2
    ov.cards = {
        StatCard(ov, "FÜR MICH", "Interface\\Icons\\INV_Chest_Chain_05"),
        StatCard(ov, "ICH KANN CRAFTEN", "Interface\\Icons\\Trade_BlackSmithing"),
        StatCard(ov, "HANDWERKER", "Interface\\Icons\\INV_Misc_Note_01"),
        StatCard(ov, "GILDE GESAMT", "Interface\\Icons\\INV_Misc_Gear_01"),
    }
    for i, c in ipairs(ov.cards) do
        c:SetWidth(cw)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        c:SetPoint("TOPLEFT", 18 + col * (cw + 10), -62 - row * 64)
    end

    local nl = SectionLabel(ov, "NÄCHSTE SCHRITTE")
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
        add("Bestes Upgrade: " .. (d and d.name or "…"),
            string.format("%s · %s · von %s", SLOT_NAMES[best.slot] or "?", GainText(best), CrafterNames(best.crafters)),
            function() Select(best) end)
    end
    if counts.help > 0 then
        add("Du kannst " .. counts.help .. " Upgrades craften", "Für deine Twinks und die Gilde – hier klicken für die Liste.",
            function() SetView("help") end)
    end
    if not IsInGuild() then
        add("Keine Gilde", "Ohne Gilde werden nur deine eigenen Charaktere verglichen.")
    elseif foreign == 0 then
        add("Mit der Gilde syncen", "Noch keine Daten aus der Gilde. Hier klicken zum Austauschen.",
            function() ns.Hello(); ns.Print("Daten an die Gilde gesendet und angefragt.") end)
    end
    if myRecipes == 0 then
        add("Rezepte erfassen", "Öffne einmal jedes Berufsfenster dieses Charakters (Filter aus).")
    else
        add(myRecipes .. " Ausrüstungs-Rezepte erfasst", "Neue Rezepte gelernt? Einfach das Berufsfenster öffnen.")
    end
    if ns.pending then add("Lade Itemdaten …", "Einige Gegenstände sind noch nicht im Cache, gleich vollständig.") end

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
    bt:SetText("< Übersicht")
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
    local vl = SectionLabel(it, "VERGLEICH")
    vl:SetPoint("TOPLEFT", 18, -96)
    local box = Panel(it, C.panel2)
    box:SetPoint("TOPLEFT", 18, -110)
    box:SetPoint("RIGHT", -18, 0)
    box:SetHeight(70)
    local cl = Text(box, 9, C.muted)
    cl:SetPoint("TOPLEFT", 10, -8)
    cl:SetText("TRÄGT AKTUELL")
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
    local fl = SectionLabel(it, "FÜR")
    fl:SetPoint("TOPLEFT", 18, -194)
    it.forName = Text(it, 13)
    it.forName:SetPoint("TOPLEFT", 18, -208)
    it.forSub = Text(it, 11, C.muted)
    it.forSub:SetPoint("LEFT", it.forName, "RIGHT", 8, 0)
    it.spec = Text(it, 10, C.muted)
    it.spec:SetPoint("TOPLEFT", it.forName, "BOTTOMLEFT", 0, -5)
    it.specBtn = MakeButton(it, 64, 18, "ändern")
    it.specBtn.label:SetFont(FONT, 10, "")
    it.specBtn:SetPoint("TOPRIGHT", -18, -206)
    it.specBtn:SetScript("OnClick", function()
        if selEntry then ns.CycleSpec(selEntry.target) end
    end)
    AddTooltip(it.specBtn, "Bewertung ändern",
        "Schaltet für diesen Charakter durch: Automatisch → Talentbaum 1 → 2 → 3 → nur Itemlevel. " ..
        "Gilt nur bei dir.")

    -- Handwerker
    local hl = SectionLabel(it, "HERSTELLBAR VON")
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
        r.btn = MakeButton(r, 70, 18, "Flüstern")
        r.btn:SetPoint("RIGHT", -4, 0)
        r.btn.label:SetFont(FONT, 10, "")
        r.btn:SetScript("OnClick", function(self)
            local e = selEntry
            if not e or not self.key then return end
            local d = ns.ItemData(e.itemID)
            local link = d and d.link or "das Teil"
            local forWhom = (e.target == ns.PlayerKey()) and "mir" or ("meinem Twink " .. ns.ShortName(e.target))
            Whisper(self.key, "Hallo! Könntest du " .. forWhom .. " " .. link .. " herstellen? Mats bringe ich mit.")
        end)
        it.crafters[i] = r
    end
    it.more = Text(it, 10, C.muted)
    it.more:SetPoint("TOPLEFT", 18, -264 - MAX_CRAFTER_ROWS * 28)

    -- Aktionen
    it.link = MakeButton(it, 150, 26, "Im Chat verlinken")
    it.link:SetPoint("BOTTOMLEFT", 18, 14)
    it.link:SetScript("OnClick", function() if selEntry then LinkInChat(selEntry.itemID) end end)
    it.ask = MakeButton(it, 150, 26, "Anfrage flüstern", true)
    it.ask:SetPoint("BOTTOMRIGHT", -18, 14)
    it.ask:SetScript("OnClick", function(self) if self.run then self.run() end end)
end

local function RenderItem(e)
    local d = ns.ItemData(e.itemID)
    local qr, qg, qb = QualityColor(d and d.quality)
    it.icon:SetTexture(d and d.icon or EMPTY_ICON)
    SetBorderColor(it.iconBorder, qr, qg, qb, 1)
    it.name:SetText(d and d.name or "Lade Itemdaten …")
    it.name:SetTextColor(qr, qg, qb)
    local meta = { SLOT_NAMES[e.slot] or "?" }
    if d then
        if d.subName and d.subName ~= "" and d.subName ~= "Verschiedenes" then meta[#meta + 1] = d.subName end
        meta[#meta + 1] = "iLvl " .. d.ilvl
        if d.req and d.req > 1 then meta[#meta + 1] = "ab Stufe " .. d.req end
    end
    it.meta:SetText(table.concat(meta, "  ·  "))

    if e.cur then
        local cd = ns.ItemData(e.cur)
        it.curIcon:SetTexture(cd and cd.icon or EMPTY_ICON)
        it.curName:SetText((cd and cd.name or "…") .. (cd and ("  |cff8f96a8iLvl " .. cd.ilvl .. "|r") or ""))
        it.curName:SetTextColor(QualityColor(cd and cd.quality))
        if e.mode == "stat" then
            it.gain:SetText(DiffText(e))
            it.gainLabel:SetText("FÜR DIE SPEC")
        else
            it.gain:SetText("+" .. e.diff)
            it.gainLabel:SetText("ITEMLEVEL")
        end
    else
        it.curIcon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        it.curName:SetText("Platz ist leer")
        it.curName:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        it.gain:SetText("NEU")
        it.gainLabel:SetText("FREIER PLATZ")
    end

    it.forName:SetText(CharName(e.target))
    it.forSub:SetText(LevelClass(e.target) .. "   " .. Tag(e.target))
    it.spec:SetText("Bewertet nach: |cffe6e6eb" .. ns.SpecLabel(e.target) .. "|r")
    local w = ns.WeightsFor(e.target)
    local tr = Rec(e.target)
    local diffs = ns.StatDiffText(ns.ItemStats(e.itemID), e.cur and ns.ItemStats(e.cur, tr and tr.suffix and tr.suffix[e.slot]), w)
    it.statLine:SetText(diffs ~= "" and diffs or "Keine Wertunterschiede bekannt")

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
    it.more:SetText(extra > 0 and ("+" .. extra .. " weitere") or "")

    -- Hauptaktion
    local link = d and d.link or "das Teil"
    local foreignCrafter = FirstForeign(e.crafters)
    if not IsMine(e.target) and AnyMine(e.crafters) then
        it.ask.label:SetText("Angebot flüstern")
        it.ask.run = function()
            local diff = e.cur and (" (" .. GainText(e) .. " für dich)") or " (dein Platz ist noch leer)"
            Whisper(e.target, "Hallo! Ich kann dir " .. link .. " herstellen" .. diff .. ". Interesse? Mats bringst du mit.")
        end
        it.ask:SetActive(true)
    elseif foreignCrafter then
        it.ask.label:SetText("Anfrage flüstern")
        it.ask.run = function()
            local forWhom = (e.target == ns.PlayerKey()) and "mir" or ("meinem Twink " .. ns.ShortName(e.target))
            Whisper(foreignCrafter, "Hallo! Könntest du " .. forWhom .. " " .. link .. " herstellen? Mats bringe ich mit.")
        end
        it.ask:SetActive(true)
    else
        it.ask.label:SetText("Selbst herstellen")
        it.ask.run = nil
        it.ask:SetActive(false)
    end
end

function RenderDetail()
    if not detail then return end
    if selEntry then
        ov:Hide()
        it:Show()
        RenderItem(selEntry)
    else
        it:Hide()
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
    right:SetText("v" .. ns.VERSION .. "  ·  /fsmith hilfe")

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
    tt:AddLine("Friendsmith – craftbar von: " .. CrafterNames(who), 0.95, 0.6, 0.3, true)
    local ups = ns.byItem and ns.byItem[itemID]
    if ups then
        local t = {}
        for _, e in ipairs(ups) do
            t[#t + 1] = CharName(e.target) .. " " .. DiffText(e)
        end
        tt:AddLine("Upgrade für: " .. table.concat(t, ", "), 0.3, 1, 0.3, true)
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
        ns.Hello()
        ns.Print("Daten an die Gilde gesendet und angefragt.")
    elseif msg == "scan" then
        ns.UpdateSelf()
        ns.ScanRecipes(true)
    elseif msg:match("^diff") then
        local n = tonumber(msg:match("%d+"))
        if n then ns.S.minDiff = math.max(1, n); ns.MarkDirty() end
        ns.Print("Mindest-Verbesserung: " .. ns.S.minDiff .. " Itemlevel.")
    elseif msg == "ruestung" or msg == "rüstung" then
        ns.S.anyArmor = not ns.S.anyArmor
        ns.MarkDirty()
        ns.Print(ns.S.anyArmor and "Auch niedrigere Rüstungsklassen werden vorgeschlagen."
            or "Nur die beste Rüstungsklasse jeder Klasse wird vorgeschlagen.")
    elseif msg == "minimap" then
        local show = ns.S.minimap and ns.S.minimap.hide
        ns.SetMinimapShown(show and true or false)
        ns.Print(show and "Minimap-Button eingeblendet." or "Minimap-Button ausgeblendet.")
    elseif msg == "reset" then
        for k, rec in pairs(FriendsmithDB.chars) do
            if not rec.mine then FriendsmithDB.chars[k] = nil end
        end
        ns.MarkDirty()
        ns.Print("Gespeicherte Gildendaten gelöscht (deine eigenen Charaktere bleiben).")
    elseif msg == "help" or msg == "hilfe" then
        ns.Print("/fsmith – Fenster öffnen/schließen")
        ns.Print("/fsmith sync – Daten mit der Gilde austauschen")
        ns.Print("/fsmith scan – Berufsfenster neu einlesen (Fenster muss offen sein)")
        ns.Print("/fsmith diff 3 – erst ab +3 Itemlevel als Upgrade zählen")
        ns.Print("/fsmith ruestung – auch niedrigere Rüstungsklassen erlauben (an/aus)")
        ns.Print("/fsmith minimap – Minimap-Button ein/aus")
        ns.Print("/fsmith reset – Daten anderer Gildenmitglieder löschen")
    else
        ns.ToggleUI()
    end
end
