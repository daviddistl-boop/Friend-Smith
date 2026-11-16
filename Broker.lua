-- Friendsmith – Addon-Button
-- 1. LibDataBroker: erscheint in Broker-Leisten (Titan Panel, ChocolateBar, Bazooka, ...) mit Upgrade-Zahl
-- 2. Minimap-Button: ueber LibDBIcon, falls vorhanden, sonst ein eigener verschiebbarer Button
-- 3. Addon-Menue (Addon Compartment) ueber die Eintraege in der .toc

local ADDON, ns = ...
local L = ns.L

ns.LOGO = "Interface\\AddOns\\Friendsmith\\Media\\logo"

local ldbObject, ownButton

---------------------------------------------------------------------------
-- Zahlen und Tooltip
---------------------------------------------------------------------------
local function IsMine(key)
    local r = FriendsmithDB.chars[key]
    return r and r.mine
end

function ns.Counts()
    local mine, help = 0, 0
    if InCombatLockdown() and not ns.results then return 0, 0 end
    for _, e in ipairs(ns.GetResults() or {}) do
        if IsMine(e.target) then mine = mine + 1 end
        for _, k in ipairs(e.crafters) do
            if IsMine(k) then help = help + 1; break end
        end
    end
    return mine, help
end

local function FillTooltip(tt)
    local mine, help = ns.Counts()
    tt:AddLine("Friendsmith", 0.95, 0.52, 0.18)
    tt:AddDoubleLine(L["For me"], mine, 1, 1, 1, 0.36, 0.86, 0.42)
    tt:AddDoubleLine(L["I can craft"], help, 1, 1, 1, 0.36, 0.86, 0.42)
    tt:AddLine(" ")
    tt:AddLine(L["Left-click: open/close the window"], 0.6, 0.6, 0.6)
    tt:AddLine(L["Right-click: \"I can craft\""], 0.6, 0.6, 0.6)
    if ownButton then tt:AddLine(L["Drag: move around the minimap"], 0.6, 0.6, 0.6) end
end

local function OnClick(button)
    if button == "RightButton" then
        ns.OpenUI("help")
    else
        ns.ToggleUI()
    end
end

function ns.RefreshBroker()
    if not ldbObject then return end
    local mine, help = ns.Counts()
    ldbObject.text = string.format(L["|cff5cdb6b%d|r for me · |cff5cdb6b%d|r craftable"], mine, help)
end

---------------------------------------------------------------------------
-- Eigener Minimap-Button (nur ohne LibDBIcon)
---------------------------------------------------------------------------
local function PlaceOwn()
    local a = math.rad(ns.S.minimapAngle or 215)
    local r = (Minimap:GetWidth() / 2) + 5
    ownButton:ClearAllPoints()
    ownButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function CreateOwnButton()
    if not Minimap then return end
    local b = CreateFrame("Button", "FriendsmithMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(22, 22)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(ns.LOGO)
    if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b:SetScript("OnClick", function(_, btn) OnClick(btn) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        FillTooltip(GameTooltip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            ns.S.minimapAngle = math.deg((math.atan2 or math.atan)(cy / s - my, cx / s - mx))
            PlaceOwn()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    ownButton = b
    PlaceOwn()
end

---------------------------------------------------------------------------
-- Einrichtung
---------------------------------------------------------------------------
function ns.SetMinimapShown(show)
    ns.S.minimap = ns.S.minimap or {}
    ns.S.minimap.hide = not show
    local icon = LibStub and LibStub("LibDBIcon-1.0", true)
    if icon and ldbObject then
        if show then icon:Show(ADDON) else icon:Hide(ADDON) end
    elseif ownButton then
        ownButton:SetShown(show)
    end
end

function ns.InitBroker()
    ns.S.minimap = ns.S.minimap or { hide = false }
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    if ldb then
        ldbObject = ldb:NewDataObject(ADDON, {
            type = "data source",
            label = "Friendsmith",
            text = "Friendsmith",
            icon = ns.LOGO,
            OnClick = function(_, btn) OnClick(btn) end,
            OnTooltipShow = FillTooltip,
        })
    end
    local icon = LibStub and LibStub("LibDBIcon-1.0", true)
    if icon and ldbObject then
        icon:Register(ADDON, ldbObject, ns.S.minimap)
    else
        CreateOwnButton()
        if ownButton and ns.S.minimap.hide then ownButton:Hide() end
    end
    C_Timer.After(5, ns.RefreshBroker)
end

-- Addon-Menue (Addon Compartment), siehe .toc
function Friendsmith_OnAddonCompartmentClick(_, button)
    OnClick(button)
end

function Friendsmith_OnAddonCompartmentEnter(_, frame)
    GameTooltip:SetOwner(frame or UIParent, "ANCHOR_LEFT")
    FillTooltip(GameTooltip)
    GameTooltip:Show()
end

function Friendsmith_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
