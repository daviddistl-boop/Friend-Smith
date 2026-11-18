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
local wanted, lastAnswered = {}, {}

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

-- Gleicher Spieler? WoW Forever liefert je nach Client unterschiedliche Realm-Namen
-- (z. B. interne Servernamen), deshalb nur den Charakternamen vergleichen.
-- Bei Namen mit Nachnamen ("Vorname Nachname") zaehlt auch der Vorname allein.
local function BareName(name)
    name = tostring(name or ""):gsub("%-[^%-]*$", "")
    return name:lower()
end
function ns.SameName(a, b)
    local x, y = BareName(a), BareName(b)
    if x == "" or y == "" then return false end
    if x == y then return true end
    if x:gsub("%s", "") == y:gsub("%s", "") then return true end
    local fx, fy = x:match("^(%S+)"), y:match("^(%S+)")
    return fx ~= nil and fx == fy
end

-- Serverzeit statt PC-Uhr (die kann bei jedem Spieler anders gehen)
function ns.Now()
    return (GetServerTime and GetServerTime()) or time()
end

function ns.Debug(msg)
    if ns.S and ns.S.debug then ns.Print("|cff8f96a8[debug]|r " .. tostring(msg)) end
end

local function IsFriend(sender)
    if not sender then return false end
    for name in pairs(ns.FriendList()) do
        if ns.SameName(name, sender) then return true end
    end
    return false
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

-- Kurze Pruefsumme (32 Bit) – damit andere erkennen, ob sie unsere Daten schon kennen
local function Hash(str)
    local h = 5381
    for i = 1, #str do h = (h * 33 + str:byte(i)) % 4294967296 end
    return string.format("%08x", h)
end

local function sortedPairsList(t, fmt)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = fmt(k, t[k]) end
    return out
end

-- Alle Nachrichten zu einem eigenen Charakter, immer in derselben Reihenfolge.
-- Ergebnis: Liste von Nutzdaten, Pruefsumme ueber alles
local function CharPayloads(key, what)
    local rec = FriendsmithDB.chars[key]
    if not rec then return {}, nil end
    local list = {}
    local gIndex
    if what ~= "R" then
        local parts = sortedPairsList(rec.gear, function(slot, id) return slot .. ":" .. id end)
        local sfx = sortedPairsList(rec.suffix, function(slot, v) return slot .. ":" .. v end)
        -- Felder 7 (Spec), 8 (Zufallseigenschaften), 9 (Wunsch), 10 (Pruefsumme) ignorieren aeltere Versionen
        list[#list + 1] = table.concat({ PROTO, "G", key, rec.class or "", tostring(rec.level or 0), table.concat(parts, ","),
            tostring(rec.spec or 0), table.concat(sfx, ","), rec.wish and "1" or "0" }, ";")
        gIndex = #list
        -- komplette Links der getragenen Teile ("L"), damit Zufallseigenschaften ueberall stimmen
        local links = sortedPairsList(rec.links, function(slot, l) return slot .. "=" .. l end)
        if #links > 0 then list[#list + 1] = table.concat({ PROTO, "L", key, table.concat(links, ",") }, ";") end
    end
    if what ~= "G" then
        local ids = sortedPairsList(rec.recipes, function(id) return tostring(id) end)
        if #ids > 0 then list[#list + 1] = table.concat({ PROTO, "R", key, table.concat(ids, ",") }, ";") end
        -- Zutaten der Rezepte (aeltere Versionen ignorieren "M")
        local mats = ns.ReagentPayload and ns.ReagentPayload(rec)
        if mats then list[#list + 1] = table.concat({ PROTO, "M", key, mats }, ";") end
        -- Fertigkeit und Levelvorschlaege je Beruf (Berufshilfe)
        for _, p in ipairs(ns.ProfessionPayloads and ns.ProfessionPayloads(rec) or {}) do
            list[#list + 1] = table.concat({ PROTO, "P", key, p }, ";")
        end
        -- Helfer-Profil (aeltere Versionen ignorieren "F")
        local help = ns.HelpPayload and ns.HelpPayload(rec)
        if help then list[#list + 1] = table.concat({ PROTO, "F", key, help }, ";") end
        -- Verzauberungsformeln (aeltere Versionen ignorieren "V")
        local ench = ns.EnchantPayload and ns.EnchantPayload(rec)
        if ench then list[#list + 1] = table.concat({ PROTO, "V", key, ench }, ";") end
        -- Koch-Kategorien (aeltere Versionen ignorieren "C")
        local cats = ns.FoodCatPayload and ns.FoodCatPayload(rec)
        if cats then list[#list + 1] = table.concat({ PROTO, "C", key, cats }, ";") end
    end
    local digest
    if what == nil then
        digest = Hash(table.concat(list, "\n"))
        if gIndex then list[gIndex] = list[gIndex] .. ";" .. digest end
    end
    return list, digest
end

function ns.CharDigest(key)
    local _, d = CharPayloads(key, nil)
    return d
end

local function SendCharTo(key, what, channel, target)
    local list = CharPayloads(key, what)
    for _, p in ipairs(list) do Enqueue(p, channel, target) end
end

local function OnlineFriends()
    local list = {}
    if not ns.S.shareFriends then return list end
    for name, online in pairs(ns.FriendList()) do
        if online then list[#list + 1] = name end
    end
    return list
end

-- Gesuche, Gildenbank, Lagerziele, Feed: nur eigene Eintraege, hoechstens alle 2 Minuten
local lastExtras = -1000
local function BroadcastExtras()
    if not IsInGuild() or GetTime() - lastExtras < 120 then return end
    lastExtras = GetTime()
    if ns.BroadcastExtra then ns.BroadcastExtra() end
    if ns.BroadcastStock then ns.BroadcastStock() end
    if ns.BroadcastFeed then ns.BroadcastFeed() end
end

-- Pruefsummen der eigenen Charaktere in der Gilde ("H"): andere fragen gezielt nach, was ihnen fehlt
local lastDigest = -1000
local function SendDigest(force)
    if not IsInGuild() then return end
    if not force and GetTime() - lastDigest < 30 then return end
    lastDigest = GetTime()
    local myGuild = GetGuildInfo("player")
    local parts = {}
    for key, rec in pairs(FriendsmithDB.chars) do
        if rec.mine and rec.guild == myGuild then
            local d = ns.CharDigest(key)
            if d then parts[#parts + 1] = key .. "=" .. d end
        end
    end
    if #parts > 0 then Enqueue(table.concat({ PROTO, "H", table.concat(parts, ",") }, ";"), "GUILD") end
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
    lastExtras = -1000
    BroadcastExtras()
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
        -- "Q;2": neue Versionen antworten nur mit Pruefsummen, aeltere mit allen Daten
        Enqueue(PROTO .. ";Q;2", "GUILD")
        if force then
            ns.BroadcastAll()
        else
            SendDigest(true)
            BroadcastExtras()
        end
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
    ns.Debug(string.format("%s von %s (%s), %d Zeichen", tostring(kind), tostring(sender), channel, #payload))

    if kind == "Q" then
        if channel == "GUILD" then
            if f[3] == "2" then
                -- neue Version: kurze Pruefsummen statt aller Daten
                ns.Debounce("answer", math.random(2, 10), function() SendDigest(false); BroadcastExtras() end)
            elseif GetTime() - lastBroadcast > 120 then
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

    if kind == "H" then
        if channel ~= "GUILD" then return end
        local DB = FriendsmithDB
        for key, d in (f[3] or ""):gmatch("([^,=]+)=(%x+)") do
            local rec = DB.chars[key]
            if not (rec and rec.mine) and (not rec or rec.digest ~= d) then
                wanted[key] = true
            end
        end
        if next(wanted) then
            ns.Debounce("want", math.random(2, 5), function()
                local keys = {}
                for k in pairs(wanted) do
                    if #keys < 20 then keys[#keys + 1] = k end
                end
                wipe(wanted)
                Enqueue(table.concat({ PROTO, "N", table.concat(keys, ",") }, ";"), "GUILD")
            end)
        end
        return
    elseif kind == "N" then
        if channel ~= "GUILD" then return end
        local DB = FriendsmithDB
        local myGuild = GetGuildInfo("player")
        for key in (f[3] or ""):gmatch("[^,]+") do
            local rec = DB.chars[key]
            if rec and rec.mine and rec.guild == myGuild then
                local now = GetTime()
                if not lastAnswered[key] or now - lastAnswered[key] > 60 then
                    lastAnswered[key] = now
                    ns.Debounce("need:" .. key, math.random(1, 4), function() SendCharTo(key, nil, "GUILD") end)
                end
            end
        end
        return
    end

    -- Zutaten, Gildenbank, Mats-Gesuche (Mats.lua)
    if ns.HandleExtra and ns.HandleExtra(kind, f, sender, channel) then return end
    if ns.HandleStock and ns.HandleStock(kind, f, sender, channel) then return end
    if ns.HandleFeed and ns.HandleFeed(kind, f, sender, channel) then return end

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
        rec.wish = (f[9] == "1") or nil -- "freut sich ueber Hilfe"
        if f[10] and f[10]:match("^%x+$") then rec.digest = f[10] end
    elseif kind == "P" then
        if ns.ParseProfession then ns.ParseProfession(rec, f) end
    elseif kind == "F" then
        if ns.ParseHelp then ns.ParseHelp(rec, f) end
    elseif kind == "L" then
        local links = {}
        for sslot, l in (f[4] or ""):gmatch("(%d+)=(item:[%-%d:]+)") do
            local slot = tonumber(sslot)
            if slot and slot >= 1 and slot <= 19 and #l <= 160 then links[slot] = l end
        end
        rec.links = links
    elseif kind == "V" then
        if ns.ParseEnchants then ns.ParseEnchants(rec, f) end
    elseif kind == "C" then
        if ns.ParseFoodCats then ns.ParseFoodCats(rec, f) end
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
