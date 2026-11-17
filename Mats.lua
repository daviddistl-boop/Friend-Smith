-- Friendsmith – Mats: Zutaten der Rezepte, eigene Taschen/Bank, Gildenbank und Mats-Gesuche
--
-- * Zutaten liest der Handwerker aus seinem offenen Berufsfenster und teilt sie mit (Nachricht "M").
-- * Taschen und Bank aller eigenen Charaktere werden lokal gemerkt (nur fuer Zutaten, nie verschickt).
-- * Die Gildenbank wird gelesen, wenn jemand sie offen hat, und an die Gilde verteilt ("B", nur Gilde).
-- * Mats-Gesuche: "ich suche fuer Item X noch diese Mats" ("A" = offen, "X" = erledigt, nur Gilde).
--   Ein Gesuch wird nur vom Absender selbst angenommen bzw. geschlossen.

local ADDON, ns = ...
local L = ns.L

local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local MAX_MATS = 10
local REQUEST_DAYS = 3
local MAX_REQUESTS_PER_PLAYER = 10
local GB_SLOTS = MAX_GUILDBANK_SLOTS_PER_TAB or 98

local function DB()
    local d = FriendsmithDB
    d.reagents = d.reagents or {} -- itemID -> { {matID, anzahl}, ... }
    d.gbank = d.gbank or {}       -- Gilde -> tab -> { t, by, items = { matID -> anzahl } }
    d.requests = d.requests or {} -- id -> { id, from, item, mats, t, guild }
    return d
end

local function Serialize(list)
    local t = {}
    for _, m in ipairs(list) do t[#t + 1] = m[1] .. ":" .. m[2] end
    return table.concat(t, "/")
end

local function ParseMats(s)
    local out = {}
    for sid, sn in (s or ""):gmatch("(%d+):(%d+)") do
        local id, n = tonumber(sid), tonumber(sn)
        if id and n and n > 0 and n < 1000 and #out < MAX_MATS then out[#out + 1] = { id, n } end
    end
    return out
end
ns.ParseMats = ParseMats

---------------------------------------------------------------------------
-- Zutaten aus dem offenen Berufsfenster
---------------------------------------------------------------------------
local function ReadReagents(info)
    local out, incomplete = {}, false
    local function add(id, n)
        id, n = tonumber(id), tonumber(n)
        if not id or not n then incomplete = true; return end
        if n > 0 and #out < MAX_MATS then out[#out + 1] = { id, n } end
    end
    local T = C_TradeSkillUI
    if info.recipeID and T then
        if T.GetRecipeSchematic then
            local ok, s = pcall(T.GetRecipeSchematic, info.recipeID, false)
            if ok and type(s) == "table" and s.reagentSlotSchematics then
                local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
                for _, slot in ipairs(s.reagentSlotSchematics) do
                    local r = slot.reagents and slot.reagents[1]
                    if (slot.reagentType == nil or basic == nil or slot.reagentType == basic) and r then
                        add(r.itemID, slot.quantityRequired)
                    end
                end
                return (not incomplete and #out > 0) and out or nil
            end
        end
        if T.GetRecipeNumReagents and T.GetRecipeReagentInfo then
            for r = 1, T.GetRecipeNumReagents(info.recipeID) or 0 do
                local _, _, count = T.GetRecipeReagentInfo(info.recipeID, r)
                local link = T.GetRecipeReagentItemLink and T.GetRecipeReagentItemLink(info.recipeID, r)
                add(link and link:match("item:(%d+)"), count)
            end
        end
    elseif info.index and GetTradeSkillNumReagents then
        for r = 1, GetTradeSkillNumReagents(info.index) or 0 do
            local _, _, count = GetTradeSkillReagentInfo(info.index, r)
            local link = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(info.index, r)
            add(link and link:match("item:(%d+)"), count)
        end
    end
    return (not incomplete and #out > 0) and out or nil
end

-- Wird von ScanRecipes aufgerufen. Gibt die Anzahl neuer/geaenderter Zutatenlisten zurueck.
function ns.RecordReagents(map, rec)
    local d = DB()
    local changed = 0
    for itemID, info in pairs(map) do
        if rec.recipes[itemID] then
            local ok, list = pcall(ReadReagents, info)
            if ok and list then
                local old = d.reagents[itemID]
                if not old or Serialize(old) ~= Serialize(list) then
                    d.reagents[itemID] = list
                    changed = changed + 1
                end
            end
        end
    end
    if changed > 0 then ns.UpdateInventory() end
    return changed
end

function ns.Reagents(itemID)
    return FriendsmithDB and FriendsmithDB.reagents and FriendsmithDB.reagents[itemID]
end

-- Fuer Nachricht "M": "itemID=mat:n/mat:n,itemID=..."
function ns.ReagentPayload(rec)
    local d = DB()
    local parts = {}
    local seen = {}
    local function add(itemID)
        local r = d.reagents[itemID]
        if r and not seen[itemID] then
            seen[itemID] = true
            parts[#parts + 1] = itemID .. "=" .. Serialize(r)
        end
    end
    for itemID in pairs(rec.recipes or {}) do add(itemID) end
    -- auch Rezepte aus der Leveling-Route, die der Spieler erst noch lernen muss
    for _, p in pairs(rec.profs or {}) do
        for _, s in ipairs(p.guide or {}) do
            if s.item then add(s.item) end
        end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ",")
end

---------------------------------------------------------------------------
-- Taschen und Bank der eigenen Charaktere
---------------------------------------------------------------------------
local bankOpen = false

local function TrackedIDs()
    local ids = {}
    for _, list in pairs(DB().reagents) do
        for _, m in ipairs(list) do ids[m[1]] = true end
    end
    return ids
end

function ns.UpdateInventory()
    if not FriendsmithDB or not GetItemCount then return end
    local rec = FriendsmithDB.chars[ns.PlayerKey()]
    if not rec then return end
    local bags, bank = {}, bankOpen and {} or nil
    for id in pairs(TrackedIDs()) do
        local inBags = GetItemCount(id) or 0
        if inBags > 0 then bags[id] = inBags end
        if bank then
            local all = GetItemCount(id, true) or 0
            if all > inBags then bank[id] = all - inBags end
        end
    end
    rec.bags = bags
    if bank then rec.bank = bank end
    ns.Debounce("matsui", 0.5, function() if ns.RefreshUI then ns.RefreshUI() end end)
end

-- Summe ueber alle eigenen Charaktere (Taschen + Bank)
function ns.OwnCount(id)
    local total = 0
    local me = ns.PlayerKey()
    for key, rec in pairs(FriendsmithDB.chars) do
        if rec.mine then
            if key == me and GetItemCount then
                total = total + (GetItemCount(id) or 0)
            else
                total = total + ((rec.bags and rec.bags[id]) or 0)
            end
            total = total + ((rec.bank and rec.bank[id]) or 0)
        end
    end
    return total
end

---------------------------------------------------------------------------
-- Gildenbank
---------------------------------------------------------------------------
local function MyBank()
    local guild = GetGuildInfo("player")
    if not guild then return nil end
    local d = DB()
    d.gbank[guild] = d.gbank[guild] or {}
    return d.gbank[guild], guild
end

function ns.GuildBankCount(id)
    local g = MyBank()
    if not g then return 0 end
    local n = 0
    for _, tab in pairs(g) do n = n + ((tab.items and tab.items[id]) or 0) end
    return n
end

-- Zeitpunkt des aeltesten bekannten Fachs (nil = noch nie gesehen)
function ns.GuildBankTime()
    local g = MyBank()
    if not g then return nil end
    local oldest
    for _, tab in pairs(g) do
        if not oldest or tab.t < oldest then oldest = tab.t end
    end
    return oldest
end

local function SendTab(tab)
    local g = MyBank()
    local data = g and g[tab]
    if not data or not ns.Enqueue then return end
    local parts = {}
    for id, n in pairs(data.items) do parts[#parts + 1] = id .. ":" .. n end
    ns.Enqueue(table.concat({ ns.PROTO, "B", tab, data.t, table.concat(parts, ",") }, ";"), "GUILD")
end

local pendingTabs = {}
local function ScanGuildBank()
    if not GetNumGuildBankTabs or InCombatLockdown() then return end
    local g = MyBank()
    if not g then return end
    local cur = GetCurrentGuildBankTab and GetCurrentGuildBankTab()
    local any = false
    for tab = 1, GetNumGuildBankTabs() or 0 do
        local _, _, viewable = GetGuildBankTabInfo(tab)
        if viewable then
            local items, filled = {}, false
            for slot = 1, GB_SLOTS do
                local link = GetGuildBankItemLink(tab, slot)
                local id = link and tonumber(link:match("item:(%d+)"))
                if id then
                    local _, count = GetGuildBankItemInfo(tab, slot)
                    items[id] = (items[id] or 0) + (count or 1)
                    filled = true
                end
            end
            -- noch nicht geladene Faecher sind leer; ein leeres Fach zaehlt nur, wenn es gerade offen ist
            if filled or tab == cur then
                g[tab] = { t = ns.Now(), by = ns.PlayerKey(), items = items }
                pendingTabs[tab] = true
                any = true
            end
        end
    end
    if any then
        ns.Debounce("matsui", 0.5, function() if ns.RefreshUI then ns.RefreshUI() end end)
        ns.Debounce("sendgbank", 15, function()
            for tab in pairs(pendingTabs) do SendTab(tab) end
            wipe(pendingTabs)
        end)
    end
end
ns.ScanGuildBank = ScanGuildBank

local function OnGuildBankOpened()
    if not GetNumGuildBankTabs then return end
    for tab = 1, GetNumGuildBankTabs() or 0 do
        local _, _, viewable = GetGuildBankTabInfo(tab)
        if viewable and QueryGuildBankTab then pcall(QueryGuildBankTab, tab) end
    end
    ns.Debounce("gbscan", 1, ScanGuildBank)
end

---------------------------------------------------------------------------
-- Mats-Gesuche
---------------------------------------------------------------------------
local function Expired(r) return (ns.Now() - (r.t or 0)) > REQUEST_DAYS * 86400 end

local function SendRequest(r)
    if ns.Enqueue then
        ns.Enqueue(table.concat({ ns.PROTO, "A", r.from, r.item, r.t, Serialize(r.mats) }, ";"), "GUILD")
    end
end

local function TrimFrom(from)
    local mine = {}
    for _, r in pairs(DB().requests) do if r.from == from then mine[#mine + 1] = r end end
    table.sort(mine, function(a, b) return a.t > b.t end)
    for i = MAX_REQUESTS_PER_PLAYER + 1, #mine do DB().requests[mine[i].id] = nil end
end

-- offene Gesuche der eigenen Gilde, neueste zuerst
function ns.OpenRequests()
    local d = DB()
    local guild = GetGuildInfo("player")
    local out = {}
    for id, r in pairs(d.requests) do
        if Expired(r) then
            d.requests[id] = nil
        elseif guild and (r.guild == guild or r.guild == "?") then
            r.guild = guild
            out[#out + 1] = r
        end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    return out
end

function ns.CreateRequest(itemID, mats)
    local guild = GetGuildInfo("player")
    if not guild or not mats or #mats == 0 then return nil end
    local key = ns.PlayerKey()
    local list = {}
    for i = 1, math.min(#mats, MAX_MATS) do list[i] = { mats[i][1], mats[i][2] } end
    -- gleiches Item schon gesucht? Dann ersetzen
    for id, r in pairs(DB().requests) do
        if r.from == key and r.item == itemID then DB().requests[id] = nil end
    end
    local t = ns.Now()
    local r = { id = key .. ":" .. t, from = key, item = itemID, mats = list, t = t, guild = guild }
    DB().requests[r.id] = r
    TrimFrom(key)
    SendRequest(r)
    ns.Debounce("matsui", 0.2, function() if ns.RefreshUI then ns.RefreshUI() end end)
    return r
end

function ns.CloseRequest(r)
    if not r or r.from ~= ns.PlayerKey() then return end
    DB().requests[r.id] = nil
    if ns.Enqueue then ns.Enqueue(table.concat({ ns.PROTO, "X", r.from, r.t }, ";"), "GUILD") end
    ns.Debounce("matsui", 0.2, function() if ns.RefreshUI then ns.RefreshUI() end end)
end

---------------------------------------------------------------------------
-- Empfangen (von Comm.lua aufgerufen). true = Nachricht wurde hier behandelt.
---------------------------------------------------------------------------
function ns.HandleExtra(kind, f, sender, channel)
    if kind == "M" then
        local d = DB()
        for entry in (f[4] or ""):gmatch("[^,]+") do
            local item, mats = entry:match("^(%d+)=(.+)$")
            item = tonumber(item)
            if item and not d.reagents[item] then
                local list = ParseMats(mats)
                if #list > 0 then d.reagents[item] = list end
            end
        end
        ns.Debounce("matsui", 1, function() if ns.RefreshUI then ns.RefreshUI() end end)
        return true
    end
    if kind ~= "B" and kind ~= "A" and kind ~= "X" then return false end
    if channel ~= "GUILD" then return true end -- Gildenbank und Gesuche nur aus der eigenen Gilde

    if kind == "B" then
        local tab, t = tonumber(f[3]), tonumber(f[4])
        local g = MyBank()
        if not g or not tab or tab < 1 or tab > 8 or not t or t > ns.Now() + 3600 then return true end
        if g[tab] and g[tab].t >= t then return true end
        local items = {}
        for id, n in (f[5] or ""):gmatch("(%d+):(%d+)") do items[tonumber(id)] = tonumber(n) end
        g[tab] = { t = t, by = ns.NormalizeName(sender), items = items }
    else
        local key = f[3]
        if not key or not ns.SameName(key, sender) then -- nur eigene Gesuche
            ns.Debug(string.format("Gesuch verworfen: Name %s passt nicht zu Absender %s", tostring(key), tostring(sender)))
            return true
        end
        if kind == "A" then
            local item, t = tonumber(f[4]), tonumber(f[5])
            local mats = ParseMats(f[6])
            if not item or not t or #mats == 0 or t > ns.Now() + 3600 then
                ns.Debug("Gesuch verworfen: ungueltige Daten oder Zeit")
                return true
            end
            local r = { id = key .. ":" .. t, from = key, sender = sender, item = item, mats = mats, t = t,
                        guild = GetGuildInfo("player") or "?" }
            if Expired(r) then ns.Debug("Gesuch verworfen: abgelaufen"); return true end
            for id, old in pairs(DB().requests) do
                if old.from == key and old.item == item and old.t < t then DB().requests[id] = nil end
            end
            DB().requests[r.id] = r
            TrimFrom(key)
        else
            DB().requests[key .. ":" .. tostring(f[4])] = nil
        end
    end
    ns.Debounce("matsui", 1, function() if ns.RefreshUI then ns.RefreshUI() end end)
    return true
end

-- Antwort auf eine Gildenanfrage: eigene offene Gesuche und selbst gelesene Gildenbank-Faecher
function ns.BroadcastExtra()
    local me = ns.PlayerKey()
    for _, r in ipairs(ns.OpenRequests()) do
        if r.from == me then SendRequest(r) end
    end
    local g = MyBank()
    if g then
        for tab, data in pairs(g) do
            if data.by == me and ns.Now() - data.t < 2 * 86400 then SendTab(tab) end
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED", "GUILDBANKFRAME_OPENED", "GUILDBANKBAGSLOTS_CHANGED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }) do
    pcall(ev.RegisterEvent, ev, e)
end

local PIT = Enum and Enum.PlayerInteractionType
local BANKER = PIT and PIT.Banker or 8
local GUILD_BANKER = PIT and PIT.GuildBanker or 10

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(5, ns.UpdateInventory)
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.Debounce("inventory", 2, ns.UpdateInventory)
    elseif event == "BANKFRAME_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and arg1 == BANKER) then
        bankOpen = true
        ns.Debounce("inventory", 1, ns.UpdateInventory)
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if bankOpen then ns.Debounce("inventory", 1, ns.UpdateInventory) end
    elseif event == "BANKFRAME_CLOSED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and arg1 == BANKER) then
        if bankOpen then ns.UpdateInventory() end
        bankOpen = false
    elseif event == "GUILDBANKFRAME_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and arg1 == GUILD_BANKER) then
        OnGuildBankOpened()
    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        ns.Debounce("gbscan", 1, ScanGuildBank)
    end
end)
