-- Friendsmith – Leiste am Berufsfenster
-- Zeigt neben dem offenen Beruf: "Upgrades für dich", "Upgrades für <Twink>", "Upgrades für <Gildenmitglied>".
-- Klick oeffnet das Rezept im Berufsfenster, wie bei einer normalen Rezeptzeile.

local ADDON, ns = ...

local P_W, P_H, ROW_H = 260, 420, 20
local panel
local rows, flat = {}, {}
local offset, numRows = 0, 0

local function S() return ns.Style end

local function Host()
    if TradeSkillFrame and TradeSkillFrame:IsShown() then return TradeSkillFrame end
    if ProfessionsFrame and ProfessionsFrame:IsShown() then return ProfessionsFrame end
end

---------------------------------------------------------------------------
-- Rezept im Berufsfenster auswaehlen
---------------------------------------------------------------------------
local function SelectRecipe(itemID)
    local map = ns.CurrentRecipes()
    local info = map and map[itemID]
    if not info then return end
    if info.recipeID then
        local T = C_TradeSkillUI
        if T and T.OpenRecipe then pcall(T.OpenRecipe, info.recipeID) end
        return
    end
    local i = info.index
    if TradeSkillFrame_SetSelection then
        pcall(TradeSkillFrame_SetSelection, i)
    elseif SelectTradeSkill then
        pcall(SelectTradeSkill, i)
    end
    -- Liste so scrollen, dass das Rezept sichtbar ist
    local bar = TradeSkillListScrollFrameScrollBar
    local h = TRADE_SKILL_HEIGHT or 16
    local shown = TRADE_SKILLS_DISPLAYED or 8
    if bar and bar.SetValue then
        local _, max = bar:GetMinMaxValues()
        local want = math.max(0, (i - math.floor(shown / 2)) * h)
        pcall(bar.SetValue, bar, math.min(want, max or want))
    end
    if TradeSkillFrame_Update then pcall(TradeSkillFrame_Update) end
end

---------------------------------------------------------------------------
-- Liste aufbauen
---------------------------------------------------------------------------
local function GroupOrder(a, b)
    local me = ns.PlayerKey()
    if (a == me) ~= (b == me) then return a == me end
    local ma, mb = S().IsMine(a), S().IsMine(b)
    if ma ~= mb then return ma end
    return a < b
end

local function Build()
    wipe(flat)
    local map = ns.CurrentRecipes()
    if not map then return 0, true end
    local me = ns.PlayerKey()
    local groups, order, total = {}, {}, 0
    for _, e in ipairs(ns.GetResults() or {}) do
        if map[e.itemID] then
            local mine = false
            for _, k in ipairs(e.crafters) do if k == me then mine = true end end
            if mine then
                local g = groups[e.target]
                if not g then
                    g = {}
                    groups[e.target] = g
                    order[#order + 1] = e.target
                end
                g[#g + 1] = e
                total = total + 1
            end
        end
    end
    table.sort(order, GroupOrder)
    ns.S.collapsed = ns.S.collapsed or {}
    for _, k in ipairs(order) do
        local ck = "P:" .. k
        local closed = ns.S.collapsed[ck]
        flat[#flat + 1] = { kind = "h", key = k, ck = ck, n = #groups[k], closed = closed }
        if not closed then
            for _, e in ipairs(groups[k]) do flat[#flat + 1] = { kind = "i", e = e } end
        end
    end
    return total, false
end

local function Render()
    local st = S()
    for i = 1, numRows do
        local r = rows[i]
        local it = flat[offset + i]
        r.item = it
        if not it then
            r:Hide()
        else
            r:Show()
            local hdr = it.kind == "h"
            r.hbg:SetShown(hdr)
            r.exp:SetShown(hdr)
            r.count:SetShown(hdr)
            r.icon:SetShown(not hdr)
            r.gain:SetShown(not hdr)
            if hdr then
                r.exp:SetTexture(it.closed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
                local who = (it.key == ns.PlayerKey()) and "dich" or st.CharName(it.key)
                r.text:SetText("Upgrades für " .. who)
                r.text:SetTextColor(st.C.gold[1], st.C.gold[2], st.C.gold[3])
                r.text:SetPoint("LEFT", 22, 0)
                r.count:SetText(it.n)
            else
                local e = it.e
                local d = ns.ItemData(e.itemID)
                r.icon:SetTexture(d and d.icon or st.EMPTY_ICON)
                r.text:SetText(d and d.name or "Lade …")
                r.text:SetTextColor(st.QualityColor(d and d.quality))
                r.text:SetPoint("LEFT", 42, 0)
                r.gain:SetText(st.DiffText(e))
            end
        end
    end
end

function ns.RefreshProfPanel()
    if not panel then return end
    local host = Host()
    if not host or ns.S.hideProfPanel or InCombatLockdown() then
        panel:Hide()
        return
    end
    local total, linked = Build()
    local maxOff = math.max(0, #flat - numRows)
    offset = math.min(offset, maxOff)
    panel.count:SetText(total > 0 and total or "")
    if linked then
        panel.empty:SetText("Fremder Beruf – hier werden nur deine eigenen Rezepte ausgewertet.")
    else
        panel.empty:SetText("Mit diesem Beruf kannst du gerade niemandem etwas Besseres craften.\n\nIm Friendsmith-Fenster siehst du, wer dir etwas craften kann.")
    end
    panel.empty:SetShown(#flat == 0)
    panel:Show()
    Render()
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
local function Place(host)
    panel:ClearAllPoints()
    local x, y = ns.S.profPanelX or 2, ns.S.profPanelY or -12
    panel:SetPoint("TOPLEFT", host, "TOPRIGHT", x, y)
end

local function Create(host)
    local st = S()
    local C = st.C
    panel = CreateFrame("Frame", "FriendsmithProfPanel", host)
    panel:SetSize(P_W, P_H)
    panel:SetFrameStrata(host:GetFrameStrata())
    panel:SetFrameLevel(host:GetFrameLevel() + 5)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    st.Fill(panel, C.bg)
    st.Border(panel, { 0, 0, 0, 1 })

    -- Kopf (zum Verschieben ziehen)
    local head = CreateFrame("Frame", nil, panel)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(34)
    st.Fill(head, C.header)
    local line = head:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.55)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() panel:StartMoving() end)
    head:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        local h = panel:GetParent()
        local s = panel:GetEffectiveScale() / h:GetEffectiveScale()
        ns.S.profPanelX = math.floor(panel:GetLeft() * s - h:GetRight() + 0.5)
        ns.S.profPanelY = math.floor(panel:GetTop() * s - h:GetTop() + 0.5)
        Place(h)
    end)

    local logo = st.Icon(head, 20)
    logo:SetPoint("LEFT", 8, 0)
    logo:SetTexture(ns.LOGO)
    logo:SetTexCoord(0, 1, 0, 1)
    local title = st.Text(head, 12)
    title:SetPoint("LEFT", logo, "RIGHT", 7, 0)
    title:SetText("Friendsmith")
    panel.count = st.Text(head, 11, C.green)
    panel.count:SetPoint("LEFT", title, "RIGHT", 6, 0)

    local open = st.MakeButton(head, 56, 20, "Fenster")
    open:SetPoint("RIGHT", -6, 0)
    open.label:SetFont(st.FONT, 10, "")
    open:SetScript("OnClick", function() ns.OpenUI("mine") end)
    open:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Friendsmith öffnen", 1, 1, 1)
        GameTooltip:AddLine("Dort siehst du auch, wer dir etwas craften kann.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    open:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- Zeilen
    local area = CreateFrame("Frame", nil, panel)
    area:SetPoint("TOPLEFT", 4, -40)
    area:SetPoint("BOTTOMRIGHT", -4, 24)
    numRows = math.floor((P_H - 40 - 24) / ROW_H)
    for i = 1, numRows do
        local r = CreateFrame("Button", nil, area)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("RIGHT")
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.hbg = st.Fill(r, C.panel2)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.07)
        r.exp = r:CreateTexture(nil, "ARTWORK")
        r.exp:SetSize(14, 14)
        r.exp:SetPoint("LEFT", 4, 0)
        r.icon = st.Icon(r, 16)
        r.icon:SetPoint("LEFT", 20, 0)
        r.count = st.Text(r, 10, C.muted, "RIGHT")
        r.count:SetPoint("RIGHT", -6, 0)
        r.gain = st.Text(r, 11, C.green, "RIGHT")
        r.gain:SetPoint("RIGHT", -6, 0)
        r.gain:SetWidth(40)
        r.text = st.Text(r, 11)
        r.text:SetPoint("LEFT", 22, 0)
        r.text:SetPoint("RIGHT", r.gain, "LEFT", -4, 0)

        r:SetScript("OnClick", function(self, btn)
            local it = self.item
            if not it then return end
            if it.kind == "h" then
                ns.S.collapsed[it.ck] = not it.closed or nil
                ns.RefreshProfPanel()
                return
            end
            local d = ns.ItemData(it.e.itemID)
            if btn == "RightButton" then
                ns.OpenUI("help", it.e)
            elseif d and IsModifiedClick and HandleModifiedItemClick
                and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP")) then
                HandleModifiedItemClick(d.link)
            else
                SelectRecipe(it.e.itemID)
            end
        end)
        r:SetScript("OnEnter", function(self)
            local it = self.item
            if it and it.kind == "i" and ns.ShowEntryTooltip then
                ns.ShowEntryTooltip(self, it.e)
                GameTooltip:AddLine("Rechtsklick: im Friendsmith-Fenster zeigen", 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
    end
    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(_, delta)
        local maxOff = math.max(0, #flat - numRows)
        offset = math.max(0, math.min(maxOff, offset - delta * 3))
        Render()
    end)

    panel.empty = st.Text(panel, 11, C.muted, "CENTER")
    panel.empty:SetPoint("TOP", 0, -70)
    panel.empty:SetWidth(P_W - 30)
    if panel.empty.SetWordWrap then panel.empty:SetWordWrap(true) end

    local foot = st.Text(panel, 9, C.muted, "CENTER")
    foot:SetPoint("BOTTOM", 0, 8)
    foot:SetText("Klick: Rezept öffnen  ·  Shift: verlinken")

    Place(host)
end

function ns.OnTradeSkillShow()
    local host = Host()
    if not host or not ns.Style then return end
    if not panel then
        Create(host)
    elseif panel:GetParent() ~= host then
        panel:SetParent(host)
        Place(host)
    end
    offset = 0
    C_Timer.After(0.3, ns.RefreshProfPanel)
end
