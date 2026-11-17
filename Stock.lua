-- Friendsmith – Gildenlager: Mindestmengen fuer die Gildenbank
--
-- Gildenmeister und Offiziere legen fest, wie viel von einem Gegenstand (Traenke, Essen, Verbaende …)
-- in der Gildenbank liegen soll. Alle sehen, was fehlt, wer es herstellen kann und welche Mats dafuer fehlen.
-- Sync: Nachricht "T" (nur Gilde) mit der kompletten Liste; angenommen nur von Gildenmeister/Offizieren.

local ADDON, ns = ...
local L = ns.L

local MAX_TARGETS = 60

local function DB()
    local d = FriendsmithDB
    d.targets = d.targets or {} -- Gilde -> { t, by, items = { itemID -> anzahl } }
    return d
end

local function MyTargets(create)
    local guild = GetGuildInfo("player")
    if not guild then return nil end
    local d = DB()
    if not d.targets[guild] and create then d.targets[guild] = { t = 0, items = {} } end
    return d.targets[guild]
end

function ns.StockTargets()
    local t = MyTargets(false)
    return t and t.items or {}, t
end

---------------------------------------------------------------------------
-- Wer darf Ziele setzen? Gildenmeister und Raenge mit Offizierschat.
---------------------------------------------------------------------------
local function RankAllowed(rankIndex)
    if rankIndex == nil then return false end
    if rankIndex == 0 then return true end
    local CG = C_GuildInfo
    if CG and CG.GuildControlGetRankFlags then
        local ok, flags = pcall(CG.GuildControlGetRankFlags, rankIndex + 1)
        if ok and type(flags) == "table" and flags[3] ~= nil then
            return flags[3] == true or flags[4] == true -- Offizierschat hoeren/sprechen
        end
    end
    return rankIndex <= 1 -- Rueckfall: Gildenmeister und der Rang direkt darunter
end

local function RosterRank(sender)
    if not GetNumGuildMembers then return nil end
    for i = 1, GetNumGuildMembers() or 0 do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name and ns.SameName(name, sender) then return rankIndex end
    end
    return nil
end

function ns.CanSetTargets()
    if not IsInGuild() then return false end
    if IsGuildLeader and IsGuildLeader() then return true end
    local _, _, rankIndex = GetGuildInfo("player")
    return RankAllowed(rankIndex)
end

local function SenderAllowed(sender)
    local rank = RosterRank(sender)
    if rank == nil then
        -- Mitgliederliste noch nicht geladen: anfordern, Nachricht diesmal verwerfen
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster)
        elseif GuildRoster then pcall(GuildRoster) end
        ns.Debug("Lagerziele verworfen: " .. tostring(sender) .. " nicht in der Mitgliederliste gefunden")
        return false
    end
    if not RankAllowed(rank) then
        ns.Debug("Lagerziele verworfen: " .. tostring(sender) .. " ist kein Offizier")
        return false
    end
    return true
end

---------------------------------------------------------------------------
-- Senden / Empfangen
---------------------------------------------------------------------------
local function SendTargets()
    local t = MyTargets(false)
    if not t or not ns.Enqueue then return end
    local parts = {}
    for id, n in pairs(t.items) do parts[#parts + 1] = id .. ":" .. n end
    ns.Enqueue(table.concat({ ns.PROTO, "T", t.t, table.concat(parts, ",") }, ";"), "GUILD")
end

local function Changed()
    ns.Debounce("matsui", 0.2, function() if ns.RefreshUI then ns.RefreshUI() end end)
    if ns.RefreshBroker then ns.RefreshBroker() end
end

-- Ziel setzen (anzahl 0 = entfernen). Nur fuer Gildenmeister/Offiziere.
function ns.SetTarget(itemID, amount)
    if not ns.CanSetTargets() then
        ns.Print(L["Only the guild master and officers can set stock targets."])
        return false
    end
    itemID, amount = tonumber(itemID), math.floor(tonumber(amount) or 0)
    if not itemID or amount < 0 or amount > 9999 then return false end
    local t = MyTargets(true)
    local count = 0
    for _ in pairs(t.items) do count = count + 1 end
    if amount > 0 and not t.items[itemID] and count >= MAX_TARGETS then
        ns.Print(string.format(L["At most %d stock targets."], MAX_TARGETS))
        return false
    end
    t.items[itemID] = amount > 0 and amount or nil
    t.t = ns.Now()
    t.by = ns.PlayerKey()
    Changed()
    ns.Debounce("sendtargets", 3, SendTargets)
    return true
end

function ns.HandleStock(kind, f, sender, channel)
    if kind ~= "T" then return false end
    if channel ~= "GUILD" then return true end
    local t = tonumber(f[3])
    if not t or t > ns.Now() + 3600 then return true end
    local cur = MyTargets(true)
    if not cur or t <= (cur.t or 0) then return true end
    if not SenderAllowed(sender) then return true end
    local items, n = {}, 0
    for sid, samount in (f[4] or ""):gmatch("(%d+):(%d+)") do
        local id, amount = tonumber(sid), tonumber(samount)
        if n < MAX_TARGETS and amount > 0 and amount <= 9999 then
            items[id] = amount
            n = n + 1
        end
    end
    cur.items, cur.t, cur.by = items, t, sender
    Changed()
    return true
end

-- Antwort auf Gildenanfragen: Offiziere verteilen die aktuelle Liste weiter
function ns.BroadcastStock()
    local t = MyTargets(false)
    if t and t.t > 0 and ns.CanSetTargets() then SendTargets() end
end

---------------------------------------------------------------------------
-- Auswertung
---------------------------------------------------------------------------
-- { itemID, target, have, missing, crafters = {...}, stock = true }, fehlende zuerst
function ns.StockList()
    local items = ns.StockTargets()
    local craftable = ns.craftable or {}
    local out = {}
    for itemID, target in pairs(items) do
        local have = ns.GuildBankCount(itemID)
        out[#out + 1] = {
            stock = true, itemID = itemID, target = target, have = have,
            missing = math.max(0, target - have), crafters = craftable[itemID] or {},
        }
    end
    table.sort(out, function(a, b)
        local fa, fb = a.have / a.target, b.have / b.target
        if (a.missing > 0) ~= (b.missing > 0) then return a.missing > 0 end
        if fa ~= fb then return fa < fb end
        return a.itemID < b.itemID
    end)
    return out
end
