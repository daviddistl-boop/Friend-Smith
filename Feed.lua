-- Friendsmith – Danke & Gilden-Feed
--
-- Der Feed zeigt schoene Momente der Gilde: Berufsschritte (75/150/225/300), Level-Meilensteine,
-- erfuellte Mats-Gesuche und Dankeschoens. So sieht jeder, dass in der Gilde geholfen wird.
-- Nachrichten (nur Gilde): "E" = Ereignis, "K" = Danke. Angenommen wird nur, was der Absender ueber
-- sich selbst meldet. Freitext gibt es bewusst nicht – nur feste Texte.

local ADDON, ns = ...
local L = ns.L

local MAX_ENTRIES = 80
local KEEP_DAYS = 14
local RESEND_DAYS = 3
local THANK_COOLDOWN = 300 -- dieselbe Person hoechstens alle 5 Minuten bedanken
local MAX_PER_SENDER_DAY = 15
local STEPS = { [75] = true, [150] = true, [225] = true, [300] = true }

local function Feed(create)
    local guild = GetGuildInfo("player")
    if not guild then return nil end
    local d = FriendsmithDB
    d.feed = d.feed or {}
    if not d.feed[guild] and create then d.feed[guild] = {} end
    return d.feed[guild]
end

local function Changed()
    ns.Debounce("matsui", 0.3, function() if ns.RefreshUI then ns.RefreshUI() end end)
end

-- Eintrag aufnehmen (doppelte ignorieren, alte und ueberzaehlige wegraeumen)
local function Add(e)
    local f = Feed(true)
    if not f then return false end
    local now = ns.Now()
    if not e.t or e.t > now + 3600 or now - e.t > KEEP_DAYS * 86400 then return false end
    local perSender = 0
    for _, x in ipairs(f) do
        if x.id == e.id then return false end
        if x.key == e.key and now - x.t < 86400 then perSender = perSender + 1 end
    end
    if perSender >= MAX_PER_SENDER_DAY then return false end
    f[#f + 1] = e
    table.sort(f, function(a, b) return a.t > b.t end)
    for i = #f, 1, -1 do
        if i > MAX_ENTRIES or now - f[i].t > KEEP_DAYS * 86400 then table.remove(f, i) end
    end
    Changed()
    return true
end

function ns.FeedEntries()
    local f = Feed(false) or {}
    local now = ns.Now()
    local out = {}
    for _, e in ipairs(f) do
        if now - e.t <= KEEP_DAYS * 86400 then out[#out + 1] = e end
    end
    return out
end

---------------------------------------------------------------------------
-- Senden
---------------------------------------------------------------------------
local function SendEvent(e)
    if not ns.Enqueue or not IsInGuild() then return end
    ns.Enqueue(table.concat({ ns.PROTO, "E", e.key, e.t, e.kind, e.a or "", e.b or "" }, ";"), "GUILD")
end

local function SendThanks(e, channel, target)
    if not ns.Enqueue then return end
    ns.Enqueue(table.concat({ ns.PROTO, "K", e.key, e.to, e.t, e.a or 0 }, ";"), channel, target)
end

-- Eigenes Ereignis melden: "prof" (Beruf, Stufe), "lvl" (Level), "req" (Item)
function ns.PostEvent(kind, a, b)
    if ns.S.feedEvents == false or not IsInGuild() then return end
    local key = ns.PlayerKey()
    local e = { id = table.concat({ "E", key, kind, tostring(a), tostring(b) }, ":"), t = ns.Now(),
                kind = kind, key = key, a = a, b = b }
    if Add(e) then SendEvent(e) end
end

-- Name oder Schluessel -> Schluessel eines bekannten Charakters
local function ResolveKey(name)
    if not name or name == "" then return nil end
    for key in pairs(FriendsmithDB.chars) do
        if ns.SameName(key, name) then return key end
    end
    return (ns.NormalizeName and ns.NormalizeName(name)) or name
end
ns.ResolveKey = ResolveKey

local lastThanks = {}
-- Danke sagen. itemID ist optional (wofuer).
function ns.Thank(name, itemID)
    local to = ResolveKey(name)
    if not to then return false end
    if ns.SameName(to, ns.PlayerKey()) then
        ns.Print(L["You can't thank yourself – but nice try."])
        return false
    end
    local now = ns.Now()
    if lastThanks[to] and now - lastThanks[to] < THANK_COOLDOWN then
        ns.Print(L["You just thanked them."])
        return false
    end
    lastThanks[to] = now
    local key = ns.PlayerKey()
    local e = { id = table.concat({ "K", key, to, now }, ":"), t = now, kind = "thanks", key = key, to = to,
                a = tonumber(itemID) or nil }
    local rec = FriendsmithDB.chars[to]
    local myGuild = GetGuildInfo("player")
    if myGuild and (not rec or not rec.friend or rec.guild == myGuild) then
        Add(e)
        SendThanks(e, "GUILD")
    else
        -- Freund ausserhalb der Gilde: direkt an ihn
        local target = (rec and rec.sender) or ns.ShortName(to)
        SendThanks(e, "WHISPER", (target:gsub("%-[^%-]*$", "")))
    end
    ns.Print(string.format(L["Thanks sent to %s."], ns.ShortName(to)))
    return true
end

---------------------------------------------------------------------------
-- Empfangen
---------------------------------------------------------------------------
local function Link(id)
    local d = id and ns.ItemData(id)
    return d and d.link or (d and d.name) or nil
end

function ns.HandleFeed(kind, f, sender, channel)
    if kind ~= "E" and kind ~= "K" then return false end
    local key = f[3]
    if not key or not ns.SameName(key, sender) then return true end -- nur ueber sich selbst
    if kind == "E" then
        if channel ~= "GUILD" then return true end
        local t, ek = tonumber(f[4]), f[5]
        local a, b = f[6], f[7]
        if ek == "prof" then
            b = tonumber(b)
            if not a or a == "" or #a > 40 or not b or not STEPS[b] then return true end
        elseif ek == "lvl" then
            a = tonumber(a); b = nil
            if not a or a < 2 or a > 100 then return true end
        elseif ek == "req" then
            a = tonumber(a); b = nil
            if not a then return true end
        else
            return true
        end
        Add({ id = table.concat({ "E", key, ek, tostring(a), tostring(b) }, ":"), t = t, kind = ek, key = key, a = a, b = b })
    else
        local to, t, item = f[4], tonumber(f[5]), tonumber(f[6])
        if not to or to == "" or not t then return true end
        if item == 0 then item = nil end
        local e = { id = table.concat({ "K", key, to, t }, ":"), t = t, kind = "thanks", key = key, to = to, a = item }
        local new = true
        if channel == "GUILD" then new = Add(e) end
        -- Danke an mich? Kurz im eigenen Chat zeigen und mitzaehlen
        if new and ns.SameName(to, ns.PlayerKey()) then
            ns.S.thanksReceived = (ns.S.thanksReceived or 0) + 1
            local what = Link(item)
            ns.Print("|cffff8fc8" .. (what and string.format(L["%s says thanks for %s!"], ns.ShortName(key), what)
                or string.format(L["%s says thanks!"], ns.ShortName(key))) .. "|r")
            Changed()
        end
    end
    return true
end

-- Antwort auf Gildenanfragen: eigene Eintraege der letzten Tage noch einmal
function ns.BroadcastFeed()
    local me = ns.PlayerKey()
    local now = ns.Now()
    for _, e in ipairs(ns.FeedEntries()) do
        if e.key == me and now - e.t < RESEND_DAYS * 86400 then
            if e.kind == "thanks" then SendThanks(e, "GUILD") else SendEvent(e) end
        end
    end
end

---------------------------------------------------------------------------
-- Text eines Eintrags
---------------------------------------------------------------------------
function ns.FeedText(e, plain)
    local function who(k)
        if plain then return ns.ShortName(k) end
        return ns.Style and ns.Style.CharName(k) or ns.ShortName(k)
    end
    local item = e.a and type(e.a) == "number" and (plain and (ns.ItemData(e.a) and ns.ItemData(e.a).name) or Link(e.a))
    if e.kind == "prof" then
        return ns.Subst(L["{who} reached {prof} {step}!"], { who = who(e.key), prof = e.a, step = e.b })
    elseif e.kind == "lvl" then
        return ns.Subst(L["{who} is now level {lvl}!"], { who = who(e.key), lvl = e.a })
    elseif e.kind == "req" then
        return ns.Subst(L["{who} has all mats for {item} together."], { who = who(e.key), item = item or "?" })
    elseif e.kind == "thanks" then
        if item then
            return ns.Subst(L["{who} thanks {to} for {item}."], { who = who(e.key), to = who(e.to), item = item })
        end
        return ns.Subst(L["{who} thanks {to}."], { who = who(e.key), to = who(e.to) })
    end
    return "?"
end

---------------------------------------------------------------------------
-- Meilensteine: Level (Berufe meldet Help.lua, Gesuche Mats.lua)
---------------------------------------------------------------------------
function ns.CheckProfStep(name, oldRank, newRank)
    if not oldRank or not newRank or newRank <= oldRank then return end
    for step in pairs(STEPS) do
        if oldRank < step and newRank >= step then ns.PostEvent("prof", name, step) end
    end
end

---------------------------------------------------------------------------
-- Handeln: nach einem Handel mit Gilde/Freunden anbieten, Danke zu sagen
---------------------------------------------------------------------------
local trade = {}

local function TradePartner()
    local name = UnitName and UnitName("NPC")
    return name
end

local function ReceivedItem()
    if not GetTradeTargetItemLink then return nil, false end
    local first, any
    for i = 1, 6 do
        local link = GetTradeTargetItemLink(i)
        if link then
            any = true
            first = first or tonumber(link:match("item:(%d+)"))
        end
    end
    return first, any
end

if StaticPopupDialogs then
    StaticPopupDialogs["FRIENDSMITH_THANKS"] = {
        text = "%s",
        button1 = L["Say thanks"],
        button2 = L["No"],
        OnAccept = function(self, data) if data then ns.Thank(data.key, data.item) end end,
        timeout = 60,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

local function OfferThanks(name, item)
    if ns.S.tradeThanks == false or not name or not StaticPopup_Show then return end
    local key = ResolveKey(name)
    local rec = key and FriendsmithDB.chars[key]
    if not rec or rec.mine then return end
    local myGuild = GetGuildInfo("player")
    if not ((myGuild and rec.guild == myGuild) or rec.friend) then return end
    local what = Link(item)
    local text = what and string.format(L["%s gave you %s.\nSay thanks in the guild feed?"], ns.ShortName(key), what)
        or string.format(L["You received something from %s.\nSay thanks in the guild feed?"], ns.ShortName(key))
    StaticPopup_Show("FRIENDSMITH_THANKS", text, nil, { key = key, item = item })
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LEVEL_UP", "TRADE_SHOW", "TRADE_TARGET_ITEM_CHANGED", "TRADE_ACCEPT_UPDATE", "UI_INFO_MESSAGE", "TRADE_CLOSED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_LEVEL_UP" then
        local lvl = tonumber(a1)
        if lvl and (lvl % 10 == 0 or lvl == 60) then
            ns.Debounce("lvlpost", 5, function() ns.PostEvent("lvl", lvl) end)
        end
    elseif event == "TRADE_SHOW" then
        trade = { name = TradePartner() }
    elseif event == "TRADE_TARGET_ITEM_CHANGED" or event == "TRADE_ACCEPT_UPDATE" then
        trade.name = trade.name or TradePartner()
        local item, any = ReceivedItem()
        if any then trade.item, trade.any = item, true end
        local money = GetTargetTradeMoney and GetTargetTradeMoney() or 0
        if money and money > 0 then trade.any = true end
    elseif event == "UI_INFO_MESSAGE" then
        local msg = type(a2) == "string" and a2 or a1
        if ERR_TRADE_COMPLETE and msg == ERR_TRADE_COMPLETE and trade.any then
            local t = trade
            trade = {}
            C_Timer.After(1, function() OfferThanks(t.name, t.item) end)
        end
    end
end)
