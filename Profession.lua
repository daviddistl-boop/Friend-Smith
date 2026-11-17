-- Friendsmith – Leiste am Berufsfenster
-- Zeigt neben dem offenen Beruf: "Upgrades für dich", "Upgrades für <Twink>", "Upgrades für <Gildenmitglied>".
-- Klick oeffnet das Rezept im Berufsfenster, wie bei einer normalen Rezeptzeile.

local ADDON, ns = ...
local L = ns.L

local P_W, P_H, ROW_H = 260, 420, 18
local panel
local rows, flat = {}, {}
local cooking = false -- Kochfenster offen: Buff-Essen statt Upgrades zeigen
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
    local wa, wb = ns.Wishes(a), ns.Wishes(b)
    if wa ~= wb then return wa end
    return a < b
end

-- Kochen: eigenes Buff-Essen nach Kategorie, staerkstes zuerst
local function BuildFood(map)
    local total = 0
    for _, g in ipairs(ns.FoodList()) do
        local items = {}
        for _, e in ipairs(g.items) do
            if map[e.itemID] then items[#items + 1] = e end
        end
        if #items > 0 then
            local ck = "PF:" .. g.cat
            local closed = ns.S.collapsed[ck]
            flat[#flat + 1] = { kind = "h", food = true, label = g.label, ck = ck, n = #items, closed = closed }
            if not closed then
                for _, e in ipairs(items) do flat[#flat + 1] = { kind = "i", e = e } end
            end
            total = total + #items
        end
    end
    return total, false
end

local function Build()
    wipe(flat)
    local map = ns.CurrentRecipes()
    if not map then return 0, true end
    ns.S.collapsed = ns.S.collapsed or {}
    cooking = ns.IsCookingWindow and ns.IsCookingWindow() or false
    if cooking then return BuildFood(map) end
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
            r.exp:SetShown(hdr)
            r.count:SetShown(hdr)
            r.icon:SetShown(not hdr)
            r.gain:SetShown(not hdr)
            if hdr then
                r.exp:SetTexture(it.closed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
                r.text:SetFontObject(GameFontNormal)
                if it.food then
                    r.text:SetText(it.label)
                else
                    local who = (it.key == ns.PlayerKey()) and L["you"] or st.CharName(it.key)
                    r.text:SetText(L["Upgrades for "] .. who .. (ns.Wishes(it.key) and ("  |cffff8fc8" .. L["happy about help"] .. "|r") or ""))
                end
                r.text:SetTextColor(1, 0.82, 0)
                r.text:SetPoint("LEFT", 20, 0)
                r.count:SetText(it.n)
            else
                local e = it.e
                local d = ns.ItemData(e.itemID)
                r.icon:SetTexture(d and d.icon or st.EMPTY_ICON)
                r.text:SetFontObject(GameFontHighlightSmall)
                r.text:SetText(d and d.name or L["Loading …"])
                r.text:SetTextColor(st.QualityColor(d and d.quality))
                r.text:SetPoint("LEFT", 40, 0)
                if e.food then
                    -- gold: niemand kann in dieser Kategorie Besseres kochen
                    r.gain:SetText((e.rank == 1 and "|cffffd100" or "|cffb0b0b0") .. "+" .. e.amount .. "|r")
                else
                    r.gain:SetText(st.DiffText(e))
                end
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
    panel.count:SetText(total > 0 and string.format(cooking and L["%d buff foods"] or L["%d upgrades"], total) or "")
    if linked then
        panel.empty:SetText(L["Someone else's profession – only your own recipes are evaluated here."])
    elseif cooking then
        panel.empty:SetText(L["None of your cooking recipes gives a \"Well Fed\" buff yet.\n\nThe Friendsmith window shows who can cook the best food."])
    else
        panel.empty:SetText(L["With this profession you can't craft anyone an upgrade right now.\n\nThe Friendsmith window shows who can craft something for you."])
    end
    panel.empty:SetShown(#flat == 0)
    panel:Show()
    Render()
end

---------------------------------------------------------------------------
-- Aufbau im Stil des Berufsfensters (Blizzard-Dialograhmen, goldene Ueberschriften)
---------------------------------------------------------------------------
local function Place(host)
    panel:ClearAllPoints()
    local x, y = ns.S.profPanelX or 0, ns.S.profPanelY or -14
    panel:SetPoint("TOPLEFT", host, "TOPRIGHT", x, y)
end

local function BText(parent, fontObject, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject)
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local function Create(host)
    local st = S()
    panel = CreateFrame("Frame", "FriendsmithProfPanel", host, BACKDROP_TEMPLATE)
    panel:SetSize(P_W, P_H)
    panel:SetFrameStrata(host:GetFrameStrata())
    panel:SetFrameLevel(host:GetFrameLevel() + 5)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 26,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        panel:SetBackdropBorderColor(1, 0.86, 0.45)
    else
        st.Fill(panel, { 0.06, 0.05, 0.04, 0.95 })
    end

    -- Titelband wie bei Blizzard-Dialogen
    local ribbon = panel:CreateTexture(nil, "ARTWORK")
    ribbon:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    ribbon:SetSize(230, 56)
    ribbon:SetPoint("TOP", 0, 13)
    local title = BText(panel, "GameFontNormal", "CENTER")
    title:SetPoint("TOP", ribbon, "TOP", 7, -13)
    title:SetText("Friendsmith")
    local logo = panel:CreateTexture(nil, "OVERLAY")
    logo:SetSize(16, 16)
    logo:SetPoint("RIGHT", title, "LEFT", -4, 0)
    logo:SetTexture(ns.LOGO)

    -- oben zum Verschieben ziehen
    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", 0, 0)
    drag:SetHeight(30)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() panel:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        local h = panel:GetParent()
        local s = panel:GetEffectiveScale() / h:GetEffectiveScale()
        ns.S.profPanelX = math.floor(panel:GetLeft() * s - h:GetRight() + 0.5)
        ns.S.profPanelY = math.floor(panel:GetTop() * s - h:GetTop() + 0.5)
        Place(h)
    end)

    -- dunkler Listenbereich mit duennem Rahmen (wie die Rezeptliste)
    local inset = CreateFrame("Frame", nil, panel, BACKDROP_TEMPLATE)
    inset:SetPoint("TOPLEFT", 12, -26)
    inset:SetPoint("BOTTOMRIGHT", -12, 38)
    if inset.SetBackdrop then
        inset:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        inset:SetBackdropColor(0, 0, 0, 0.45)
        inset:SetBackdropBorderColor(0.6, 0.5, 0.3, 0.9)
    end

    local area = CreateFrame("Frame", nil, inset)
    area:SetPoint("TOPLEFT", 5, -5)
    area:SetPoint("BOTTOMRIGHT", -5, 5)
    numRows = math.floor((P_H - 26 - 38 - 10) / ROW_H)
    for i = 1, numRows do
        local r = CreateFrame("Button", nil, area)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("RIGHT")
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
        hl:SetBlendMode("ADD")
        hl:SetVertexColor(1, 0.82, 0, 0.45)
        hl:SetAllPoints()
        r.exp = r:CreateTexture(nil, "ARTWORK")
        r.exp:SetSize(14, 14)
        r.exp:SetPoint("LEFT", 2, 0)
        r.icon = st.Icon(r, 16)
        r.icon:SetPoint("LEFT", 20, 0)
        r.count = BText(r, "GameFontNormalSmall", "RIGHT")
        r.count:SetPoint("RIGHT", -4, 0)
        r.count:SetTextColor(0.75, 0.75, 0.75)
        r.gain = BText(r, "GameFontGreenSmall", "RIGHT")
        r.gain:SetPoint("RIGHT", -4, 0)
        r.gain:SetWidth(40)
        r.text = BText(r, "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 20, 0)
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
                ns.OpenUI(it.e.food and "food" or "help", it.e)
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
                GameTooltip:AddLine(L["Click: open recipe  ·  Shift: link"], 0.6, 0.6, 0.6)
                GameTooltip:AddLine(L["Right-click: show in the Friendsmith window"], 0.6, 0.6, 0.6)
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

    panel.empty = BText(inset, "GameFontDisable", "CENTER")
    panel.empty:SetPoint("TOP", 0, -40)
    panel.empty:SetWidth(P_W - 50)
    if panel.empty.SetWordWrap then panel.empty:SetWordWrap(true) end

    -- unten: Anzahl und Knopf zum grossen Fenster
    panel.count = BText(panel, "GameFontHighlightSmall")
    panel.count:SetPoint("BOTTOMLEFT", 18, 18)

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(96, 22)
    open:SetPoint("BOTTOMRIGHT", -14, 12)
    open:SetText(L["Window"])
    open:SetScript("OnClick", function() ns.OpenUI(cooking and "food" or "mine") end)
    open:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Open Friendsmith"], 1, 1, 1)
        GameTooltip:AddLine(L["It also shows who can craft something for you."], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    open:HookScript("OnLeave", function() GameTooltip:Hide() end)

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
