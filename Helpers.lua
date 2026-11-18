-- Friendsmith – Helfer-Profil und Willkommen fuer Neue
--
-- Helfer-Profil: Jeder kann ankreuzen, wobei er gerne hilft (feste Themen, kein Freitext).
-- Schuechterne und neue Mitglieder sehen dann in der Ansicht "Helfer", wen sie wofuer ansprechen koennen.
-- Sync: Nachricht "F" (Gilde und Freunde) mit den Themen; gehoert zu den Charakterdaten (Pruefsumme).
--
-- Willkommen: Tritt jemand der Gilde bei, merkt sich Friendsmith das (Systemnachricht) und teilt es im
-- Gilden-Feed. Wer selbst neu in einer Gilde ist, bekommt eine Woche lang einen Willkommens-Hinweis.

local ADDON, ns = ...
local L = ns.L

local TOPICS = { "crafting", "mats", "dungeons", "quests", "gathering", "questions", "leveling" }
local VALID = {}
for _, t in ipairs(TOPICS) do VALID[t] = true end
ns.HELP_TOPICS = TOPICS

local LABELS = {
    crafting = L["Crafting for others"],
    mats = L["Sharing mats"],
    dungeons = L["Running dungeons"],
    quests = L["Quests & elite quests"],
    gathering = L["Gathering (herbs, ore, leather)"],
    questions = L["Questions & tips"],
    leveling = L["Leveling together"],
}
function ns.TopicLabel(t) return LABELS[t] or t end

local NEWCOMER_DAYS = 14
local WELCOME_DAYS = 7

---------------------------------------------------------------------------
-- Eigenes Profil
---------------------------------------------------------------------------
function ns.MyHelpTopics()
    local set
    for t, on in pairs(ns.S.helpTopics or {}) do
        if on and VALID[t] then set = set or {}; set[t] = true end
    end
    return set
end

function ns.SetHelpTopic(topic, on)
    if not VALID[topic] then return end
    ns.S.helpTopics = ns.S.helpTopics or {}
    ns.S.helpTopics[topic] = on and true or nil
    local set = ns.MyHelpTopics()
    for _, rec in pairs(FriendsmithDB.chars) do
        if rec.mine then rec.help = set end
    end
    ns.MarkDirty()
    ns.Debounce("sendhelp", 5, function()
        if ns.SendChar then ns.SendChar(ns.PlayerKey(), "R") end
    end)
end

-- Nachricht "F": Themen durch Komma getrennt (auch leer, damit Abwaehlen ankommt)
function ns.HelpPayload(rec)
    if not rec.mine then return nil end
    local list = {}
    for _, t in ipairs(TOPICS) do
        if rec.help and rec.help[t] then list[#list + 1] = t end
    end
    return table.concat(list, ",")
end

function ns.ParseHelp(rec, f)
    local set
    for t in (f[4] or ""):gmatch("[^,]+") do
        if VALID[t] then set = set or {}; set[t] = true end
    end
    rec.help = set
end

---------------------------------------------------------------------------
-- Gildenliste (Online-Status, Level, Klasse auch fuer Spieler ohne Friendsmith)
---------------------------------------------------------------------------
local function Bare(name) return (tostring(name or ""):gsub("%-[^%-]*$", "")):lower() end

function ns.GuildRoster()
    local out = {}
    if not IsInGuild() or not GetNumGuildMembers then return out end
    for i = 1, GetNumGuildMembers() or 0 do
        local name, _, rankIndex, level, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
        if name then
            out[Bare(name)] = { name = name, level = level, class = class, online = online and true or false, rank = rankIndex }
        end
    end
    return out
end

function ns.RosterInfo(roster, key)
    return roster and roster[Bare(key)]
end

---------------------------------------------------------------------------
-- Helfer-Liste: { topic -> { {key, online, level}, ... } }
---------------------------------------------------------------------------
function ns.HelperList()
    local DB = FriendsmithDB
    local myGuild = GetGuildInfo("player")
    local now = time()
    local roster = ns.GuildRoster()
    local byTopic = {}
    for key, rec in pairs(DB.chars) do
        if rec.help and not rec.mine and ns.IsRelevant(rec, myGuild, now) then
            local r = ns.RosterInfo(roster, key)
            for t in pairs(rec.help) do
                byTopic[t] = byTopic[t] or {}
                table.insert(byTopic[t], { key = key, online = r and r.online or false, level = (r and r.level) or rec.level })
            end
        end
    end
    for _, list in pairs(byTopic) do
        table.sort(list, function(a, b)
            if a.online ~= b.online then return a.online end
            return a.key < b.key
        end)
    end
    return byTopic, roster
end

---------------------------------------------------------------------------
-- Neue Mitglieder
---------------------------------------------------------------------------
local function Newcomers(create)
    local guild = GetGuildInfo("player")
    if not guild then return nil end
    local d = FriendsmithDB
    d.newcomers = d.newcomers or {}
    if not d.newcomers[guild] and create then d.newcomers[guild] = {} end
    return d.newcomers[guild]
end

function ns.AddNewcomer(name, t)
    if not name or name == "" or #name > 48 then return false end
    local list = Newcomers(true)
    if not list then return false end
    local k = Bare(name)
    if list[k] then return false end
    list[k] = { name = name, t = t or ns.Now() }
    ns.Debounce("matsui", 0.5, function() if ns.RefreshUI then ns.RefreshUI() end end)
    return true
end

-- { {name, key, t, level, class, online}, ... }, neueste zuerst; nur wer noch in der Gilde ist
function ns.NewcomerList(roster)
    local list = Newcomers(false) or {}
    roster = roster or ns.GuildRoster()
    local now = ns.Now()
    local out = {}
    for k, n in pairs(list) do
        if now - n.t > NEWCOMER_DAYS * 86400 then
            list[k] = nil
        else
            local r = roster[k]
            if r or not next(roster) then
                out[#out + 1] = { name = n.name, key = ns.ResolveKey and ns.ResolveKey(n.name) or n.name, t = n.t,
                    level = r and r.level, class = r and r.class, online = r and r.online or false }
            end
        end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    return out
end

-- "%s ist der Gilde beigetreten." -> Muster
local joinPattern
if ERR_GUILD_JOIN_S then
    joinPattern = "^" .. ERR_GUILD_JOIN_S:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)") .. "$"
end

---------------------------------------------------------------------------
-- Selbst neu in einer Gilde?
---------------------------------------------------------------------------
function ns.IsWelcomePeriod()
    return ns.S.welcomeUntil and time() < ns.S.welcomeUntil and IsInGuild() or false
end

local function CheckOwnGuild()
    if not IsInGuild() then
        ns.S.lastGuild = ""
        return
    end
    local guild = GetGuildInfo("player")
    if not guild then return end -- noch nicht geladen
    if ns.S.lastGuild ~= nil and ns.S.lastGuild ~= guild then
        ns.S.welcomeUntil = time() + WELCOME_DAYS * 86400
        ns.Print(string.format(L["Welcome to <%s>! Open /fsmith to see who in your new guild is happy to help."], guild))
    end
    ns.S.lastGuild = guild
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_GUILD_UPDATE", "CHAT_MSG_SYSTEM", "GUILD_ROSTER_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, msg)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(10, CheckOwnGuild)
        C_Timer.After(12, function()
            if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster)
            elseif GuildRoster then pcall(GuildRoster) end
        end)
    elseif event == "PLAYER_GUILD_UPDATE" then
        ns.Debounce("ownguild", 5, CheckOwnGuild)
    elseif event == "CHAT_MSG_SYSTEM" and joinPattern and type(msg) == "string" then
        local name = msg:match(joinPattern)
        if name and not ns.SameName(name, ns.PlayerKey()) then
            ns.AddNewcomer(name)
            -- im Feed teilen, sobald die Gildenliste den Neuen kennt
            C_Timer.After(15, function() if ns.PostJoin then ns.PostJoin(name) end end)
        end
    elseif event == "GUILD_ROSTER_UPDATE" then
        ns.Debounce("matsui", 2, function() if ns.RefreshUI then ns.RefreshUI() end end)
    end
end)
