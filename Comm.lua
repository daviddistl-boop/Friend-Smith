-- Friendsmith – Synchronisation ueber unsichtbare Addon-Nachrichten
-- Gilde: ueber den Gildenkanal. Freunde: per Fluester-Addonnachricht an Online-Freunde.
-- Daten per Fluestern werden nur von Leuten angenommen, die auf deiner Freundesliste stehen.

local ADDON, ns = ...
local L = ns.L

local PREFIX = "FSMITH1"
local PROTO  = "1"
ns.PROTO = PROTO
local CHUNK  = 200
local FRIEND_HELLO_COOLDOWN = 600 -- pro Freund hoechstens alle 10 Minuten automatisch austauschen
local SendAddon      = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix

local queue, buffers = {}, {}
local lastBroadcast = 0
local counter = 0
local lastFriendHello, lastFriendAnswer = {}, {}

local function NewId()
    counter = counter + 1
    return tostring(math.random(100, 999)) .. tostring(counter)
end

---------------------------------------------------------------------------
-- Freundesliste
---------------------------------------------------------------------------
local function MyRealm()
    return ns.PlayerKey():match("%-([^%-]+)$") or ""
end

-- "Name" oder "Name-Realm" -> "Name-Realm"
local function Normalize(name)
    if not name or name == "" then return nil end
    name = name:gsub("%s", "")
    if not name:find("-", 1, true) then name = name .. "-" .. MyRealm() end
    return name
end

-- { ["Name-Realm"] = online (true/false) }
function ns.FriendList()
    local set = {}
    local CF = C_FriendList
    local n = (CF and CF.GetNumFriends and CF.GetNumFriends()) or (GetNumFriends and GetNumFriends()) or 0
    for i = 1, n do
        local name, connected
        if CF and CF.GetFriendInfoByIndex then
            local info = CF.GetFriendInfoByIndex(i)
            if info then name, connected = info.name, info.connected end
        elseif GetFriendInfo then
            local nm, _, _, _, conn = GetFriendInfo(i)
            name, connected = nm, conn
        end
        local key = Normalize(name)
        if key then set[key] = connected and true or false end
    end
    return set
end

ns.NormalizeName = Normalize

local function IsFriend(sender)
    local key = Normalize(sender)
    return key ~= nil and ns.FriendList()[key] ~= nil
end

---------------------------------------------------------------------------
-- Senden
---------------------------------------------------------------------------
local function Enqueue(payload, channel, target)
    local n = math.max(1, math.ceil(#payload / CHUNK))
    local id = NewId()
    for i = 1, n do
        queue[#queue + 1] = {
            text = id .. "~" .. i .. "~" .. n .. "~" .. payload:sub((i - 1) * CHUNK + 1, i * CHUNK),
            channel = channel or "GUILD",
            target = target,
            tries = 0,
        }
    end
end

ns.Enqueue = Enqueue

local function CleanBuffers()
    local now = GetTime()
    for k, b in pairs(buffers) do
        if now - b.t > 120 then buffers[k] = nil end
    end
end

local pumps = 0
local function Pump()
    pumps = pumps + 1
    if pumps % 100 == 0 then CleanBuffers() end
    if #queue == 0 or InCombatLockdown() then return end
    local item = table.remove(queue, 1)
    if item.channel == "GUILD" and not IsInGuild() then return end
    local ok, res = pcall(SendAddon, PREFIX, item.text, item.channel, item.target)
    -- Moderne Clients melden Erfolg mit 0 (oder true). Bei Drosselung spaeter erneut versuchen.
    local failed = (not ok) or res == false or (type(res) == "number" and res ~= 0)
    if failed then
        item.tries = item.tries + 1
        if item.tries < 6 then table.insert(queue, 1, item) end
    end
end

local function SendCharTo(key, what, channel, target)
    local rec = FriendsmithDB.chars[key]
    if not rec then return end
    if what ~= "R" then
        local parts = {}
        for slot, id in pairs(rec.gear or {}) do parts[#parts + 1] = slot .. ":" .. id end
        local sfx = {}
        for slot, v in pairs(rec.suffix or {}) do sfx[#sfx + 1] = slot .. ":" .. v end
        -- Felder 7 (Spec) und 8 (Zufallseigenschaften) ignorieren aeltere Versionen einfach
        Enqueue(table.concat({ PROTO, "G", key, rec.class or "", tostring(rec.level or 0), table.concat(parts, ","),
            tostring(rec.spec or 0), table.concat(sfx, ",") }, ";"), channel, target)
    end
    if what ~= "G" then
        local ids = {}
        for id in pairs(rec.recipes or {}) do ids[#ids + 1] = id end
        if #ids > 0 then
            Enqueue(table.concat({ PROTO, "R", key, table.concat(ids, ",") }, ";"), channel, target)
        end
        -- Zutaten der Rezepte (aeltere Versionen ignorieren "M")
        local mats = ns.ReagentPayload and ns.ReagentPayload(rec)
        if mats then Enqueue(table.concat({ PROTO, "M", key, mats }, ";"), channel, target) end
    end
end

local function OnlineFriends()
    local list = {}
    if not ns.S.shareFriends then return list end
    for name, online in pairs(ns.FriendList()) do
        if online then list[#list + 1] = name end
    end
    return list
end

-- Daten eines eigenen Charakters an die Gilde und an alle Online-Freunde senden
-- (nach Ausruestungswechsel, neuen Rezepten usw.).
function ns.SendChar(key, what)
    local rec = FriendsmithDB.chars[key]
    if not rec then return end
    local myGuild = IsInGuild() and GetGuildInfo("player")
    if myGuild and rec.guild == myGuild then SendCharTo(key, what, "GUILD") end
    for _, name in ipairs(OnlineFriends()) do SendCharTo(key, what, "WHISPER", name) end
end

-- Alle eigenen Charaktere, die in derselben Gilde sind, an die Gilde.
function ns.BroadcastAll()
    if not IsInGuild() then return end
    local myGuild = GetGuildInfo("player")
    if not myGuild then return end
    lastBroadcast = GetTime()
    for key, rec in pairs(FriendsmithDB.chars) do
        if rec.mine and rec.guild == myGuild then SendCharTo(key, nil, "GUILD") end
    end
    if ns.BroadcastExtra then ns.BroadcastExtra() end
end

-- Alle eigenen Charaktere an einen Freund.
local function SendMineTo(target)
    for key, rec in pairs(FriendsmithDB.chars) do
        if rec.mine then SendCharTo(key, nil, "WHISPER", target) end
    end
end

-- Mit einem Freund austauschen: um Daten bitten und eigene senden.
local function HelloFriend(name, force)
    local now = GetTime()
    if not force and lastFriendHello[name] and now - lastFriendHello[name] < FRIEND_HELLO_COOLDOWN then return end
    lastFriendHello[name] = now
    Enqueue(PROTO .. ";Q", "WHISPER", name)
    SendMineTo(name)
end

-- Beim Einloggen und per "Sync": Gilde und Online-Freunde.
function ns.Hello(force)
    ns.UpdateSelf()
    if IsInGuild() then
        Enqueue(PROTO .. ";Q", "GUILD")
        ns.BroadcastAll()
    end
    for _, name in ipairs(OnlineFriends()) do HelloFriend(name, force) end
end

---------------------------------------------------------------------------
-- Empfangen
---------------------------------------------------------------------------
function ns.HandlePayload(sender, payload, channel)
    channel = channel or "GUILD"
    local f = { strsplit(";", payload) }
    if f[1] ~= PROTO then return end
    local kind = f[2]

    if kind == "Q" then
        if channel == "GUILD" then
            if GetTime() - lastBroadcast > 120 then
                ns.Debounce("answer", math.random(5, 25), ns.BroadcastAll)
            end
        else
            local who = Normalize(sender)
            local now = GetTime()
            if who and (not lastFriendAnswer[who] or now - lastFriendAnswer[who] > 60) then
                lastFriendAnswer[who] = now
                ns.Debounce("answer:" .. who, math.random(2, 6), function() SendMineTo(who) end)
            end
        end
        return
    end

    -- Zutaten, Gildenbank, Mats-Gesuche (Mats.lua)
    if ns.HandleExtra and ns.HandleExtra(kind, f, sender, channel) then return end

    local key = f[3]
    if not key or key == "" then return end
    local DB = FriendsmithDB
    local rec = DB.chars[key]
    if rec and rec.mine then return end -- eigene Daten haben Vorrang
    rec = rec or {}
    DB.chars[key] = rec
    if channel == "GUILD" then
        rec.guild = GetGuildInfo("player")
    else
        rec.friend = true -- kam ueber einen Freund
    end
    rec.updated = time()
    rec.sender = sender

    if kind == "G" then
        if ns.CLASSES[f[4]] then rec.class = f[4] end
        rec.level = tonumber(f[5]) or rec.level
        local gear = {}
        for slot, id in (f[6] or ""):gmatch("(%d+):(%d+)") do
            gear[tonumber(slot)] = tonumber(id)
        end
        rec.gear = gear
        local spec = tonumber(f[7])
        rec.spec = (spec and spec >= 1 and spec <= 3) and spec or nil
        local sfx = {}
        for slot, v in (f[8] or ""):gmatch("(%d+):(%-?%d+)") do
            sfx[tonumber(slot)] = tonumber(v)
        end
        rec.suffix = sfx
    elseif kind == "R" then
        local s = {}
        for id in (f[4] or ""):gmatch("%d+") do s[tonumber(id)] = true end
        rec.recipes = s
    else
        return
    end
    ns.MarkDirty()
end

local function OnAddonMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX or type(text) ~= "string" then return end
    if channel == "WHISPER" then
        -- nur von Leuten auf der eigenen Freundesliste
        if not ns.S.shareFriends or not IsFriend(sender) then return end
    elseif channel ~= "GUILD" then
        return
    end
    local id, i, n, data = text:match("^(%w+)~(%d+)~(%d+)~(.*)$")
    if not id then return end
    i, n = tonumber(i), tonumber(n)
    if not i or not n or n < 1 or n > 80 or i < 1 or i > n then return end
    local bk = channel .. "/" .. tostring(sender) .. "/" .. id
    local b = buffers[bk]
    if not b then
        b = { n = n, got = 0, parts = {}, t = GetTime() }
        buffers[bk] = b
    end
    if not b.parts[i] then
        b.parts[i] = data
        b.got = b.got + 1
    end
    if b.got >= b.n then
        buffers[bk] = nil
        ns.HandlePayload(sender, table.concat(b.parts, "", 1, b.n), channel)
    end
end

---------------------------------------------------------------------------
-- Freunde, die online kommen, automatisch begruessen
---------------------------------------------------------------------------
local wasOnline
local function OnFriendList()
    local now = ns.FriendList()
    if wasOnline and ns.S.shareFriends then
        for name, online in pairs(now) do
            if online and not wasOnline[name] then
                -- kurz warten, bis der Freund fertig eingeloggt ist
                ns.Debounce("friend:" .. name, 20, function() HelloFriend(name) end)
            end
        end
    end
    wasOnline = {}
    for name, online in pairs(now) do if online then wasOnline[name] = true end end
end

function ns.InitComm()
    if RegisterPrefix then pcall(RegisterPrefix, PREFIX) end
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    pcall(f.RegisterEvent, f, "FRIENDLIST_UPDATE")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "FRIENDLIST_UPDATE" then
            ns.Debounce("friendlist", 2, OnFriendList)
        else
            OnAddonMessage(...)
        end
    end)
    if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends)
    elseif ShowFriends then pcall(ShowFriends) end
    C_Timer.NewTicker(0.4, Pump)
end
