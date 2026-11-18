-- Friendsmith – Datenpflege
-- Raeumt alte Daten weg, damit die SavedVariables nicht immer weiter wachsen.
-- Laeuft automatisch kurz nach dem Login und mit /fsmith cleanup.

local ADDON, ns = ...
local L = ns.L

local DAY = 86400
local KEEP_CHAR_DAYS = 60      -- Charaktere, die so lange nichts gesendet haben
local KEEP_LEFT_DAYS = 14      -- Charaktere einer anderen Gilde (Gilde verlassen), die keine Freunde sind
local KEEP_OTHER_GUILD = 30    -- Gildenbank/Lagerziele/Feed fremder Gilden (z. B. nach Gildenwechsel)

local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

function ns.Cleanup(verbose)
    local DB = FriendsmithDB
    if not DB or not DB.chars or InCombatLockdown() then return end
    local now = time()
    local snow = ns.Now and ns.Now() or now
    local myGuild = GetGuildInfo("player")
    local removed = { chars = 0, feed = 0, requests = 0, reagents = 0, other = 0 }

    -- 1) Charaktere anderer Spieler
    for key, rec in pairs(DB.chars) do
        if not rec.mine then
            local age = now - (rec.updated or 0)
            local left = myGuild and rec.guild and rec.guild ~= myGuild and not rec.friend
            if age > KEEP_CHAR_DAYS * DAY or (left and age > KEEP_LEFT_DAYS * DAY) then
                DB.chars[key] = nil
                removed.chars = removed.chars + 1
            end
        end
    end

    -- 2) Mats-Gesuche: abgelaufene (alle Gilden)
    for id, r in pairs(DB.requests or {}) do
        if snow - (r.t or 0) > 3 * DAY or not r.mats then
            DB.requests[id] = nil
            removed.requests = removed.requests + 1
        end
    end

    -- 3) Feed: alte Eintraege; fremde Gilden ganz, wenn lange nichts kam
    for guild, list in pairs(DB.feed or {}) do
        for i = #list, 1, -1 do
            if snow - (list[i].t or 0) > 14 * DAY then
                table.remove(list, i)
                removed.feed = removed.feed + 1
            end
        end
        if #list == 0 and guild ~= myGuild then DB.feed[guild] = nil end
    end

    -- 4) Gildenbank und Lagerziele fremder Gilden
    for guild, tabs in pairs(DB.gbank or {}) do
        if guild ~= myGuild then
            local newest = 0
            for _, tab in pairs(tabs) do newest = math.max(newest, tab.t or 0) end
            if snow - newest > KEEP_OTHER_GUILD * DAY then DB.gbank[guild] = nil; removed.other = removed.other + 1 end
        end
    end
    for guild, t in pairs(DB.targets or {}) do
        if guild ~= myGuild and snow - (t.t or 0) > 3 * KEEP_OTHER_GUILD * DAY then
            DB.targets[guild] = nil
            removed.other = removed.other + 1
        end
    end

    -- 5) Zutatenlisten, die nichts mehr braucht (kein Rezept, keine Route, kein Gesuch, kein Lagerziel)
    if DB.reagents then
        local used = {}
        for _, rec in pairs(DB.chars) do
            for id in pairs(rec.recipes or {}) do used[id] = true end
            for _, p in pairs(rec.profs or {}) do
                for _, c in ipairs(p.cands or {}) do used[c[1]] = true end
                for _, st in ipairs(p.guide or {}) do if st.item then used[st.item] = true end end
            end
        end
        for _, r in pairs(DB.requests or {}) do used[r.item] = true end
        for _, t in pairs(DB.targets or {}) do for id in pairs(t.items or {}) do used[id] = true end end
        for id in pairs(DB.reagents) do
            if not used[id] then DB.reagents[id] = nil; removed.reagents = removed.reagents + 1 end
        end
    end

    -- 6) Kleinkram in den Einstellungen
    local S = ns.S
    if S.collapsed and count(S.collapsed) > 300 then S.collapsed = {} end
    for k, t in pairs(S.nudged or {}) do
        if now - t > 7 * DAY then S.nudged[k] = nil end
    end
    for k in pairs(S.specOverride or {}) do
        if not DB.chars[k] then S.specOverride[k] = nil end
    end

    local total = removed.chars + removed.feed + removed.requests + removed.reagents + removed.other
    if total > 0 then ns.MarkDirty() end
    if verbose then
        if total == 0 then
            ns.Print(L["Nothing to clean up."])
        else
            ns.Print(string.format(L["Cleaned up: %d characters, %d feed entries, %d requests, %d mats lists, %d other."],
                removed.chars, removed.feed, removed.requests, removed.reagents, removed.other))
        end
    elseif ns.Debug then
        ns.Debug(string.format("Aufgeraeumt: %d Charaktere, %d Feed, %d Gesuche, %d Zutaten, %d sonst",
            removed.chars, removed.feed, removed.requests, removed.reagents, removed.other))
    end
    return removed
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    -- nach dem Laden der Gildeninfo, vor dem grossen Sync-Verkehr
    C_Timer.After(30, function() ns.Cleanup(false) end)
end)
