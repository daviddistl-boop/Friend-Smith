-- Friendsmith – /fsmith apicheck
-- Ermittelt, welche Funktionen und Daten der Spielclient (WoW Forever) wirklich liefert, und speichert einen
-- Bericht in FriendsmithDB.apiReport (SavedVariables; wird beim /reload oder Ausloggen geschrieben).
-- Nur lesen, nichts veraendern, nichts verschicken.

local ADDON, ns = ...

local function has(path)
    local t = _G
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return false end
        t = t[part]
    end
    return t ~= nil
end

local function call(fn, ...)
    if type(fn) ~= "function" then return false, "fehlt" end
    return pcall(fn, ...)
end

local function short(v, depth)
    depth = depth or 0
    local tv = type(v)
    if tv == "string" then return '"' .. v:gsub("|", "||"):sub(1, 120) .. '"' end
    if tv ~= "table" then return tostring(v) end
    if depth > 1 then return "{…}" end
    local parts, n = {}, 0
    for k, x in pairs(v) do
        n = n + 1
        if n > 14 then parts[#parts + 1] = "…"; break end
        parts[#parts + 1] = tostring(k) .. "=" .. short(x, depth + 1)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function packed(...) return { n = select("#", ...), ... } end
local function list(p)
    local t = {}
    for i = 1, p.n do t[#t + 1] = short(p[i]) end
    return table.concat(t, ", ")
end

function ns.ApiCheck()
    local R = {}
    local function add(section, text) R[#R + 1] = "[" .. section .. "] " .. text end

    -- Client
    local b = packed(call(GetBuildInfo))
    add("client", "GetBuildInfo: " .. list(b))
    add("client", "Locale " .. tostring(GetLocale and GetLocale()) .. ", Friendsmith " .. tostring(ns.VERSION))
    local _, _, classID = UnitClass("player")
    add("client", string.format("Klasse %s (%s), Level %s", tostring(select(2, UnitClass("player"))), tostring(classID), tostring(UnitLevel("player"))))

    -- Talente
    for _, f in ipairs({ "GetNumTalentTabs", "GetTalentTabInfo", "GetSpecialization", "C_SpecializationInfo.GetSpecialization",
        "C_ClassTalents.GetActiveConfigID", "C_Traits.GetConfigInfo", "C_Traits.GetTreeNodes", "C_Traits.GetNodeInfo",
        "C_Traits.GetSubTreeInfo", "C_ClassTalents.GetActiveSpecID" }) do
        add("talents", f .. ": " .. (has(f) and "ja" or "nein"))
    end
    if GetNumTalentTabs then
        local n = GetNumTalentTabs() or 0
        for i = 1, n do add("talents", "GetTalentTabInfo(" .. i .. "): " .. list(packed(call(GetTalentTabInfo, i)))) end
    end
    if has("C_ClassTalents.GetActiveConfigID") then
        local ok, cfg = call(C_ClassTalents.GetActiveConfigID)
        add("talents", "ActiveConfigID: " .. tostring(ok and cfg))
        if ok and cfg and has("C_Traits.GetConfigInfo") then
            local okc, ci = call(C_Traits.GetConfigInfo, cfg)
            add("talents", "ConfigInfo: " .. short(okc and ci))
            if okc and ci and ci.treeIDs then
                local nodes, ranks, subs, sample = 0, 0, {}, nil
                for _, tree in ipairs(ci.treeIDs) do
                    local okn, ids = call(C_Traits.GetTreeNodes, tree)
                    for _, id in ipairs(okn and ids or {}) do
                        local oki, ni = call(C_Traits.GetNodeInfo, cfg, id)
                        if oki and ni then
                            nodes = nodes + 1
                            ranks = ranks + (ni.currentRank or ni.ranksPurchased or 0)
                            if ni.subTreeID then subs[ni.subTreeID] = (subs[ni.subTreeID] or 0) + (ni.currentRank or 0) end
                            if not sample and (ni.currentRank or 0) > 0 then sample = ni end
                        end
                    end
                end
                add("talents", string.format("Knoten %d, Punkte %d, Teilbaeume %s", nodes, ranks, short(subs)))
                add("talents", "Beispielknoten: " .. short(sample))
            end
        end
    end
    local o = _G.OneForAll
    if type(o) == "table" and type(o.TalentPointsPerTree) == "function" then
        add("talents", "OneForAll TalentPointsPerTree: " .. short(select(2, pcall(o.TalentPointsPerTree))))
    end
    add("talents", "Friendsmith erkennt Baum: " .. tostring(ns.DetectSpec and ns.DetectSpec()) .. " -> " .. tostring(ns.SpecLabel and ns.SpecLabel(ns.PlayerKey())))

    -- Berufe (Fenster sollte offen sein)
    add("prof", "TradeSkillFrame: " .. tostring(TradeSkillFrame ~= nil) .. (TradeSkillFrame and (" sichtbar " .. tostring(TradeSkillFrame:IsShown())) or "")
        .. ", ProfessionsFrame: " .. tostring(ProfessionsFrame ~= nil))
    add("prof", "GetTradeSkillLine: " .. list(packed(call(GetTradeSkillLine))))
    ns.WithRawList(function()
        local n = GetNumTradeSkills and GetNumTradeSkills() or 0
        add("prof", "GetNumTradeSkills: " .. tostring(n))
        local shown = 0
        for i = 1, n do
            if shown >= 6 then break end
            local p = packed(call(GetTradeSkillInfo, i))
            if p[3] ~= "header" or shown < 3 then
                add("prof", "  Zeile " .. i .. ": " .. list(p) .. " | Link: " .. short(select(2, call(GetTradeSkillItemLink, i)))
                    .. " | Rezeptlink: " .. short(select(2, call(GetTradeSkillRecipeLink, i))))
                shown = shown + 1
            end
        end
        local T = C_TradeSkillUI
        if T then
            local fns = {}
            for k, v in pairs(T) do if type(v) == "function" then fns[#fns + 1] = k end end
            table.sort(fns)
            add("prof", "C_TradeSkillUI (" .. #fns .. " Funktionen): " .. table.concat(fns, " "):sub(1, 900))
            if T.GetAllRecipeIDs then
                local ok, ids = call(T.GetAllRecipeIDs)
                add("prof", "GetAllRecipeIDs: " .. tostring(ok and ids and #ids))
                local rid = ok and ids and ids[1]
                if rid then
                    add("prof", "GetRecipeInfo(" .. rid .. "): " .. short(select(2, call(T.GetRecipeInfo, rid))))
                    if T.GetRecipeOutputItemData then add("prof", "OutputItem: " .. short(select(2, call(T.GetRecipeOutputItemData, rid)))) end
                end
            end
            if T.GetBaseProfessionInfo then add("prof", "BaseProfessionInfo: " .. short(select(2, call(T.GetBaseProfessionInfo)))) end
        end
    end)

    -- Gegenstaende: getragene Teile
    for _, slot in ipairs({ 1, 5, 7, 9, 16 }) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            local info = packed(call(GetItemInfo, id))
            add("items", string.format("Platz %d: %s", slot, link:gsub("|", "||")))
            add("items", "  GetItemInfo liefert " .. (info.n - 1) .. " Werte, Feld 14-17: "
                .. short(info[15]) .. ", " .. short(info[16]) .. ", " .. short(info[17]) .. ", " .. short(info[18]))
            local okS, st = call(GetItemStats or (C_Item and C_Item.GetItemStats), link)
            add("items", "  GetItemStats(Link): " .. short(okS and st))
        end
    end
    add("items", "C_Item.GetItemInfo: " .. tostring(has("C_Item.GetItemInfo")) .. ", GetItemStats: " .. tostring(GetItemStats ~= nil)
        .. ", C_Item.GetItemStats: " .. tostring(has("C_Item.GetItemStats")))

    -- Tooltip eines Koch-Rezepts
    add("tooltip", "C_TooltipInfo.GetItemByID: " .. tostring(has("C_TooltipInfo.GetItemByID")))
    local rec = FriendsmithDB.chars[ns.PlayerKey()]
    local food
    for id in pairs(rec and rec.foodCat or {}) do food = id break end
    if not food then
        for id in pairs(rec and rec.recipes or {}) do
            local d = ns.ItemData(id)
            if d and d.class == 0 then food = id break end
        end
    end
    if food and has("C_TooltipInfo.GetItemByID") then
        local ok, data = call(C_TooltipInfo.GetItemByID, food)
        local lines = {}
        for _, l in ipairs(ok and data and data.lines or {}) do lines[#lines + 1] = tostring(l.leftText) end
        add("tooltip", "Item " .. food .. ": " .. table.concat(lines, " / "):gsub("|", "||"):sub(1, 600))
    end
    add("tooltip", "Satt-Zauber 19705: " .. tostring(GetSpellInfo and GetSpellInfo(19705)) .. " / "
        .. tostring(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(19705)))
    add("tooltip", "Kochkunst-Zauber 2550: " .. tostring(GetSpellInfo and GetSpellInfo(2550)) .. ", Verzauberkunst 7411: "
        .. tostring(GetSpellInfo and GetSpellInfo(7411)))
    add("tooltip", "ITEM_SPELL_TRIGGER_ONUSE: " .. short(ITEM_SPELL_TRIGGER_ONUSE) .. ", ERR_GUILD_JOIN_S: " .. short(ERR_GUILD_JOIN_S)
        .. ", ERR_TRADE_COMPLETE: " .. short(ERR_TRADE_COMPLETE))

    -- Taschen, Gildenbank, Sonstiges
    add("bags", "C_Container.GetContainerItemInfo: " .. tostring(has("C_Container.GetContainerItemInfo")) .. ", alt: " .. tostring(GetContainerItemInfo ~= nil))
    if has("C_Container.GetContainerItemInfo") then
        add("bags", "Beispiel Tasche 0/1: " .. short(select(2, call(C_Container.GetContainerItemInfo, 0, 1))))
    end
    add("guildbank", "GetNumGuildBankTabs: " .. tostring(GetNumGuildBankTabs ~= nil) .. " " .. tostring(GetNumGuildBankTabs and GetNumGuildBankTabs())
        .. ", QueryGuildBankTab: " .. tostring(QueryGuildBankTab ~= nil) .. ", PlayerInteractionType.GuildBanker: "
        .. tostring(Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker))
    add("guild", "GetGuildInfo: " .. list(packed(call(GetGuildInfo, "player"))) .. ", GuildControlGetRankFlags: " .. tostring(has("C_GuildInfo.GuildControlGetRankFlags")))
    add("misc", "Settings.RegisterCanvasLayoutCategory: " .. tostring(has("Settings.RegisterCanvasLayoutCategory"))
        .. ", InterfaceOptions_AddCategory: " .. tostring(InterfaceOptions_AddCategory ~= nil)
        .. ", ChatFrame_SendTell: " .. tostring(ChatFrame_SendTell ~= nil) .. ", Ambiguate: " .. tostring(Ambiguate ~= nil)
        .. ", GetServerTime: " .. tostring(GetServerTime ~= nil))
    add("misc", "Spieler-Schluessel: " .. ns.PlayerKey() .. ", Realm: " .. tostring(GetRealmName and GetRealmName())
        .. " / normalisiert: " .. tostring(GetNormalizedRealmName and GetNormalizedRealmName()))

    -- die letzten fuenf Durchlaeufe behalten (z. B. einmal im Kochfenster, einmal in Lederverarbeitung)
    FriendsmithDB.apiReports = FriendsmithDB.apiReports or {}
    table.insert(FriendsmithDB.apiReports, 1, { t = time(), lines = R })
    while #FriendsmithDB.apiReports > 5 do table.remove(FriendsmithDB.apiReports) end
    FriendsmithDB.apiReport = nil
    ns.Print(string.format("API-Check: %d Zeilen gespeichert. Jetzt /reload eingeben (oder ausloggen), damit der Bericht in die Datei geschrieben wird.", #R))
    ns.Print("Tipp: Mit offenem Berufsfenster ausfuehren – dann sind auch die Berufsdaten dabei.")
end
