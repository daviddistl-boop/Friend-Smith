-- Friendsmith – Gilden-Synchronisation ueber unsichtbare Addon-Nachrichten

local ADDON, ns = ...

local PREFIX = "FSMITH1"
local PROTO  = "1"
local CHUNK  = 200
local SendAddon      = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix

local queue, buffers = {}, {}
local lastBroadcast = 0
local counter = 0

local function NewId()
    counter = counter + 1
    return tostring(math.random(100, 999)) .. tostring(counter)
end

local function Enqueue(payload)
    local n = math.max(1, math.ceil(#payload / CHUNK))
    local id = NewId()
    for i = 1, n do
        queue[#queue + 1] = {
            text = id .. "~" .. i .. "~" .. n .. "~" .. payload:sub((i - 1) * CHUNK + 1, i * CHUNK),
            tries = 0,
        }
    end
end

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
    if #queue == 0 or InCombatLockdown() or not IsInGuild() then return end
    local item = table.remove(queue, 1)
    local ok, res = pcall(SendAddon, PREFIX, item.text, "GUILD")
    -- Moderne Clients melden Erfolg mit 0 (oder true). Bei Drosselung spaeter erneut versuchen.
    local failed = (not ok) or res == false or (type(res) == "number" and res ~= 0)
    if failed then
        item.tries = item.tries + 1
        if item.tries < 6 then table.insert(queue, 1, item) end
    end
end

function ns.SendChar(key, what)
    local rec = FriendsmithDB.chars[key]
    if not rec or not IsInGuild() then return end
    if what ~= "R" then
        local parts = {}
        for slot, id in pairs(rec.gear or {}) do parts[#parts + 1] = slot .. ":" .. id end
        local sfx = {}
        for slot, v in pairs(rec.suffix or {}) do sfx[#sfx + 1] = slot .. ":" .. v end
        -- Felder 7 (Spec) und 8 (Zufallseigenschaften) ignorieren aeltere Versionen einfach
        Enqueue(table.concat({ PROTO, "G", key, rec.class or "", tostring(rec.level or 0), table.concat(parts, ","),
            tostring(rec.spec or 0), table.concat(sfx, ",") }, ";"))
    end
    if what ~= "G" then
        local ids = {}
        for id in pairs(rec.recipes or {}) do ids[#ids + 1] = id end
        if #ids > 0 then
            Enqueue(table.concat({ PROTO, "R", key, table.concat(ids, ",") }, ";"))
        end
    end
end

-- Schickt alle eigenen Charaktere, die in derselben Gilde sind.
function ns.BroadcastAll()
    if not IsInGuild() then return end
    local myGuild = GetGuildInfo("player")
    if not myGuild then return end
    lastBroadcast = GetTime()
    for key, rec in pairs(FriendsmithDB.chars) do
        if rec.mine and rec.guild == myGuild then ns.SendChar(key) end
    end
end

-- Beim Einloggen: um Daten bitten und eigene Daten senden.
function ns.Hello()
    if not IsInGuild() then return end
    ns.UpdateSelf()
    Enqueue(PROTO .. ";Q")
    ns.BroadcastAll()
end

function ns.HandlePayload(sender, payload)
    local f = { strsplit(";", payload) }
    if f[1] ~= PROTO then return end
    local kind = f[2]

    if kind == "Q" then
        if GetTime() - lastBroadcast > 120 then
            ns.Debounce("answer", math.random(5, 25), ns.BroadcastAll)
        end
        return
    end

    local key = f[3]
    if not key or key == "" then return end
    local DB = FriendsmithDB
    local rec = DB.chars[key]
    if rec and rec.mine then return end -- eigene Daten haben Vorrang
    rec = rec or {}
    DB.chars[key] = rec
    rec.guild = GetGuildInfo("player")
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
    if prefix ~= PREFIX or channel ~= "GUILD" or type(text) ~= "string" then return end
    local id, i, n, data = text:match("^(%w+)~(%d+)~(%d+)~(.*)$")
    if not id then return end
    i, n = tonumber(i), tonumber(n)
    if not i or not n or n < 1 or n > 80 or i < 1 or i > n then return end
    local bk = tostring(sender) .. "/" .. id
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
        ns.HandlePayload(sender, table.concat(b.parts, "", 1, b.n))
    end
end

function ns.InitComm()
    if RegisterPrefix then pcall(RegisterPrefix, PREFIX) end
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:SetScript("OnEvent", function(_, _, ...) OnAddonMessage(...) end)
    C_Timer.NewTicker(0.4, Pump)
end
