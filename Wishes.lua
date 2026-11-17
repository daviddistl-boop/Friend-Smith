-- Friendsmith – Stille Wuensche
--
-- Wer nicht gern fragt, setzt einen Haken: "Ich freue mich ueber Hilfe". Friendsmith fragt dann fuer ihn:
-- Gildenmitglieder und Freunde sehen von selbst, womit sie helfen koennten (Upgrades craften,
-- Mats fuer den Beruf, offene Mats-Gesuche) – im Fenster, in der Berufsleiste und als kurzer Hinweis beim Login.
-- Der Haken wird mit der Ausruestung (Nachricht "G", Feld 9) geteilt. Ohne Haken bleibt alles wie bisher.

local ADDON, ns = ...
local L = ns.L

local NUDGE_LINES = 3          -- hoechstens so viele Hinweise pro Login
local NUDGE_REPEAT = 20 * 3600 -- denselben Hinweis fruehestens nach 20 Stunden wiederholen

function ns.Wishes(key)
    local r = FriendsmithDB and FriendsmithDB.chars[key]
    return r and r.wish and not r.mine or false
end

-- Eigenen Wunsch an/aus (gilt fuer alle eigenen Charaktere)
function ns.SetWishes(on)
    ns.S.wishes = on and true or false
    for _, rec in pairs(FriendsmithDB.chars) do
        if rec.mine then rec.wish = ns.S.wishes or nil end
    end
    ns.MarkDirty()
    if ns.SendChar then ns.SendChar(ns.PlayerKey(), "G") end
end

---------------------------------------------------------------------------
-- Was koennte ich fuer Leute tun, die sich ueber Hilfe freuen?
---------------------------------------------------------------------------
-- { { kind = "craft", key, itemID, entry }, { kind = "mats", key, matID, need, have, forItem }, ... }
function ns.WishHints()
    local out = {}
    local DB = FriendsmithDB
    local myGuild = GetGuildInfo("player")
    local now = time()

    -- 1) Upgrades, die einer meiner Charaktere craften kann
    for _, e in ipairs(ns.GetResults() or {}) do
        if ns.Wishes(e.target) then
            for _, k in ipairs(e.crafters) do
                if DB.chars[k] and DB.chars[k].mine then
                    out[#out + 1] = { kind = "craft", key = e.target, itemID = e.itemID, entry = e }
                    break
                end
            end
        end
    end

    -- 2) Mats, die ich habe und die jemand braucht: fuer seinen Beruf (Wunsch) oder per Mats-Gesuch
    local function offer(key, matID, need, forItem)
        local have = ns.OwnCount and ns.OwnCount(matID) or 0
        if have > 0 and need > 0 then
            out[#out + 1] = { kind = "mats", key = key, matID = matID, need = need, have = have, forItem = forItem }
        end
    end
    for key, rec in pairs(DB.chars) do
        if rec.wish and not rec.mine and rec.profs and ns.IsRelevant(rec, myGuild, now) then
            for _, p in pairs(rec.profs) do
                local plan = ns.ProfPlan and ns.ProfPlan(p)
                local o = plan and not plan.trainer and plan.options[1]
                for _, m in ipairs(o and o.mats or {}) do offer(key, m[1], m[2], o.itemID) end
            end
        end
    end
    for _, r in ipairs(ns.OpenRequests and ns.OpenRequests() or {}) do
        if not (DB.chars[r.from] and DB.chars[r.from].mine) then
            for _, m in ipairs(r.mats) do offer(r.from, m[1], m[2], r.item) end
        end
    end

    -- Craft-Hinweise zuerst, dann die groessten Mengen
    table.sort(out, function(a, b)
        if a.kind ~= b.kind then return a.kind == "craft" end
        if a.kind == "craft" then return (a.entry.rank or 0) > (b.entry.rank or 0) end
        return math.min(a.have, a.need) > math.min(b.have, b.need)
    end)
    return out
end

-- Anzahl verschiedener Spieler, denen ich helfen koennte
function ns.WishPeople(hints)
    local seen, n = {}, 0
    for _, h in ipairs(hints or ns.WishHints()) do
        if not seen[h.key] then seen[h.key] = true; n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Hinweistext (auch fuer die Uebersicht)
---------------------------------------------------------------------------
local function Link(id)
    local d = ns.ItemData(id)
    return d and d.link or (d and d.name) or ("item " .. id)
end

function ns.WishHintText(h)
    local who = ns.ShortName(h.key)
    if h.kind == "craft" then
        local e = h.entry
        local gain = ""
        if e.mode == "stat" and e.pct and e.pct < 999 then gain = string.format(" (+%d%%)", e.pct)
        elseif e.diff and e.diff > 0 then gain = " (+" .. e.diff .. " iLvl)" end
        return ns.Subst(L["{who} would be happy about help – you could craft {item}{gain}."],
            { who = who, item = Link(h.itemID), gain = gain })
    end
    return ns.Subst(L["You have {have}x {mat} – {who} needs {need} of it."],
        { have = h.have, mat = Link(h.matID), who = who, need = h.need })
end

---------------------------------------------------------------------------
-- Anstupser beim Login: ein paar Zeilen im eigenen Chat, nie an andere
---------------------------------------------------------------------------
function ns.Nudge(force)
    if not ns.S or ns.S.nudges == false or InCombatLockdown() then return end
    ns.S.nudged = ns.S.nudged or {}
    local now = time()
    for k, t in pairs(ns.S.nudged) do
        if now - t > 7 * 86400 then ns.S.nudged[k] = nil end
    end
    local shown, perPerson = 0, {}
    for _, h in ipairs(ns.WishHints()) do
        if shown >= NUDGE_LINES then break end
        local id = h.kind .. ":" .. h.key .. ":" .. (h.itemID or h.matID)
        local pk = h.kind .. ":" .. h.key -- pro Person nur ein Hinweis je Art
        if not perPerson[pk] and (force or not ns.S.nudged[id] or now - ns.S.nudged[id] > NUDGE_REPEAT) then
            perPerson[pk] = true
            ns.S.nudged[id] = now
            ns.Print(ns.WishHintText(h))
            shown = shown + 1
        end
    end
    if shown > 0 then ns.Print(L["Type /fsmith to see more – or /fsmith nudges to turn these hints off."]) end
    return shown
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
local done = false
ev:SetScript("OnEvent", function()
    if done then return end
    done = true
    -- nach dem Sync (Hello nach 15 s, Antworten bis ca. 40 s)
    C_Timer.After(60, function() ns.Nudge(false) end)
end)
