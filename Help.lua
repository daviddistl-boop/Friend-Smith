-- Friendsmith – Berufshilfe
--
-- Beim Oeffnen des Berufsfensters merkt sich das Addon die Fertigkeit (z. B. 132/150) und welche
-- bekannten Rezepte gerade orange oder gelb sind. Daraus entsteht ein Vorschlag fuer den naechsten
-- grossen Schritt (75/150/225/300): "ca. 18x Dunkle Lederstiefel craften – braucht 72x Leichtes Leder …".
-- Sync: Nachricht "P" (Gilde und Freunde), ausgewertet in Comm.lua.

local ADDON, ns = ...
local L = ns.L

local STEPS = { 75, 150, 225, 300 }
local MAX_SKILL = 300
local MAX_CANDS = 4
local YELLOW_FACTOR = 2 -- gelbe Rezepte geben nur manchmal einen Punkt: grob doppelt so viele Herstellungen

---------------------------------------------------------------------------
-- Aus dem offenen Berufsfenster lesen
---------------------------------------------------------------------------
local function ProfInfo()
    local T = C_TradeSkillUI
    if T and T.GetBaseProfessionInfo then
        local ok, info = pcall(T.GetBaseProfessionInfo)
        if ok and type(info) == "table" and info.professionName and info.skillLevel then
            return info.professionName, info.skillLevel, info.maxSkillLevel
        end
    end
    if T and T.GetTradeSkillLine then
        local ok, _, name, rank, max = pcall(T.GetTradeSkillLine)
        if ok and type(name) == "string" and rank then return name, rank, max end
    end
    if GetTradeSkillLine then
        local name, rank, max = GetTradeSkillLine()
        if name and name ~= "UNKNOWN" and rank then return name, rank, max end
    end
end

-- "o" = orange (sicherer Punkt), "y" = gelb (manchmal), sonst nil
local function Color(info)
    if info.index and GetTradeSkillInfo then
        local _, kind = GetTradeSkillInfo(info.index)
        if kind == "optimal" then return "o" end
        if kind == "medium" then return "y" end
        return nil
    end
    local T = C_TradeSkillUI
    if info.recipeID and T and T.GetRecipeInfo then
        local ok, r = pcall(T.GetRecipeInfo, info.recipeID)
        if ok and type(r) == "table" then
            local d = r.relativeDifficulty or r.difficulty
            if d == 0 or d == "optimal" then return "o" end
            if d == 1 or d == "medium" then return "y" end
        end
    end
end

local function MatCount(itemID)
    local n = 0
    for _, m in ipairs(ns.Reagents(itemID) or {}) do n = n + m[2] end
    return n
end

---------------------------------------------------------------------------
-- Optional: Leveling-Route aus dem Skill-Up-Planer von OneForAll (wenn installiert).
-- Wir rufen nur dessen oeffentliche Funktion auf, es werden keine Daten von OneForAll mitgeliefert.
-- Der Planer rechnet fuer den eingeloggten Charakter (seine Rezepte und Taschen).
---------------------------------------------------------------------------
local MAX_GUIDE = 8

local function OFA()
    local o = _G.OneForAll
    if type(o) == "table" and type(o.SkillUp) == "table" and type(o.SkillUp.Plan) == "function"
        and type(o.PROFESSION_RECIPES) == "table" then
        return o
    end
end
ns.HasOneForAll = function() return OFA() ~= nil end

-- Einstellungen von OneForAll, die die Route beeinflussen
local function OfaSignature()
    local sdb = type(OneForAllDB) == "table" and type(OneForAllDB.skillUp) == "table" and OneForAllDB.skillUp or {}
    return (sdb.ah ~= false and "a" or "-") .. (sdb.vendor ~= false and "v" or "-") .. (sdb.noAlts and "n" or "-")
end

-- englischer Berufsname von OneForAll fuer unseren (lokalisierten) Namen
local function OfaProf(o, name, map)
    local key = type(o.ProfKey) == "function" and select(2, pcall(o.ProfKey, name)) or name
    if type(key) == "string" and o.PROFESSION_RECIPES[key] then return key end
    if o.PROFESSION_RECIPES[name] then return name end
    -- Rueckfall: Beruf ueber die hergestellten Gegenstaende erkennen
    for prof, list in pairs(o.PROFESSION_RECIPES) do
        for _, r in ipairs(list) do
            if r.i and map[r.i] then return prof end
        end
    end
end

-- { {kind="c", item, crafts, from, to, learn}, {kind="t", cap, at}, ... }
local function GuideFromOFA(name, rank, target, map)
    local o = OFA()
    if not o or target <= rank then return nil end
    local prof = OfaProf(o, name, map)
    if not prof then return nil end
    -- dieselben Einstellungen wie im Skill-Up-Helfer von OneForAll ("Muster aus dem AH / von Haendlern"),
    -- damit die Route gleich ist und OneForAll seine gespeicherte Route wiederverwendet
    local sdb = type(OneForAllDB) == "table" and type(OneForAllDB.skillUp) == "table" and OneForAllDB.skillUp or {}
    local opts = { from = rank, to = target, ah = sdb.ah ~= false, vendor = sdb.vendor ~= false }
    local ok, plan = pcall(o.SkillUp.Plan, prof, opts)
    if not ok or type(plan) ~= "table" or type(plan.steps) ~= "table" then return nil end
    local guide = {}
    local d = FriendsmithDB
    d.reagents = d.reagents or {}
    for _, st in ipairs(plan.steps) do
        if #guide >= MAX_GUIDE then break end
        if st.kind == "train" then
            guide[#guide + 1] = { kind = "t", cap = tonumber(st.cap) or 0, at = tonumber(st.at) or rank }
        elseif st.kind == "craft" and type(st.r) == "table" and st.r.i then
            local item = st.r.i
            guide[#guide + 1] = {
                kind = "c", item = item, crafts = math.max(1, math.floor(tonumber(st.safe or st.expected) or 1)),
                from = tonumber(st.from) or rank, to = tonumber(st.to) or target, learn = st.learn and true or false,
            }
            -- Zutaten kennen wir dann auch fuer Rezepte, die der Spieler noch lernen muss
            if not d.reagents[item] and type(st.r.r) == "table" then
                local mats = {}
                for _, g in ipairs(st.r.r) do
                    if tonumber(g[1]) and tonumber(g[2]) and #mats < 10 then mats[#mats + 1] = { tonumber(g[1]), tonumber(g[2]) } end
                end
                if #mats > 0 then d.reagents[item] = mats end
            end
        end
    end
    return #guide > 0 and guide or nil
end

-- Von ScanRecipes aufgerufen
function ns.RecordProfession(map, rec)
    local name, rank, max = ProfInfo()
    if not name or not rank then return false end
    local cands = {}
    for itemID, info in pairs(map) do
        if rec.recipes[itemID] and ns.Reagents(itemID) then
            local c = Color(info)
            if c then cands[#cands + 1] = { itemID, c } end
        end
    end
    table.sort(cands, function(a, b)
        if a[2] ~= b[2] then return a[2] == "o" end
        local ma, mb = MatCount(a[1]), MatCount(b[1])
        if ma ~= mb then return ma < mb end
        return a[1] < b[1]
    end)
    for i = #cands, MAX_CANDS + 1, -1 do cands[i] = nil end
    rec.profs = rec.profs or {}
    local old = rec.profs[name]
    if old and ns.CheckProfStep then ns.CheckProfStep(name, old.rank, rank) end
    local changed = not old or old.rank ~= rank or old.max ~= max or #old.cands ~= #cands
    if not changed then
        for i, c in ipairs(cands) do
            if old.cands[i][1] ~= c[1] or old.cands[i][2] ~= c[2] then changed = true end
        end
    end
    -- Route von OneForAll nur neu rechnen, wenn sich die Fertigkeit geaendert hat (der Planer ist nicht billig)
    local guide = old and old.guide
    -- neu rechnen bei neuer Fertigkeit, geaenderten OneForAll-Einstellungen oder nach 30 Minuten (Preise)
    local sig = OfaSignature()
    if changed or not guide or (old and (old.guideFor ~= rank or old.guideSig ~= sig or ns.Now() - (old.guideT or 0) > 1800)) then
        local plan = ns.ProfPlan({ rank = rank, max = max or MAX_SKILL, cands = {} })
        local target = plan and plan.next or rank
        guide = GuideFromOFA(name, rank, target, map)
        if guide then changed = true end
    end
    rec.profs[name] = { rank = rank, max = max or MAX_SKILL, t = ns.Now(), cands = cands, guide = guide, guideFor = guide and rank or nil,
        guideSig = guide and sig or nil, guideT = guide and ns.Now() or nil }
    return changed
end

---------------------------------------------------------------------------
-- Sync: "P;key;Beruf;rang;max;zeit;itemID:o,itemID:y" – je Beruf eine Nachricht
---------------------------------------------------------------------------
function ns.ProfessionPayloads(rec)
    local out = {}
    local names = {}
    for name in pairs(rec.profs or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local p = rec.profs[name]
        local c = {}
        for _, x in ipairs(p.cands) do c[#c + 1] = x[1] .. ":" .. x[2] end
        local g = {}
        for _, s in ipairs(p.guide or {}) do
            if s.kind == "t" then
                g[#g + 1] = "t:" .. s.cap .. ":" .. s.at
            else
                g[#g + 1] = "c:" .. s.item .. ":" .. s.crafts .. ":" .. s.from .. ":" .. s.to .. ":" .. (s.learn and 1 or 0)
            end
        end
        out[#out + 1] = table.concat({ (name:gsub("[;,:~]", "")), p.rank, p.max, p.t, table.concat(c, ","), table.concat(g, ",") }, ";")
    end
    return out
end

function ns.ParseProfession(rec, f)
    local name, rank, max, t = f[4], tonumber(f[5]), tonumber(f[6]), tonumber(f[7])
    if not name or name == "" or #name > 40 or not rank or not max or rank < 0 or rank > 1000 or max > 1000 then return end
    local cands = {}
    for id, c in (f[8] or ""):gmatch("(%d+):([oy])") do
        if #cands < MAX_CANDS then cands[#cands + 1] = { tonumber(id), c } end
    end
    rec.profs = rec.profs or {}
    local n = 0
    for k in pairs(rec.profs) do if k ~= name then n = n + 1 end end
    if n >= 6 then return end -- mehr Berufe gibt es nicht
    local guide
    for entry in (f[9] or ""):gmatch("[^,]+") do
        if guide and #guide >= MAX_GUIDE then break end
        local a = { strsplit(":", entry) }
        if a[1] == "t" and tonumber(a[2]) and tonumber(a[3]) then
            guide = guide or {}
            guide[#guide + 1] = { kind = "t", cap = tonumber(a[2]), at = tonumber(a[3]) }
        elseif a[1] == "c" and tonumber(a[2]) and tonumber(a[3]) and tonumber(a[4]) and tonumber(a[5]) then
            local crafts = tonumber(a[3])
            if crafts >= 1 and crafts <= 500 then
                guide = guide or {}
                guide[#guide + 1] = { kind = "c", item = tonumber(a[2]), crafts = crafts,
                    from = tonumber(a[4]), to = tonumber(a[5]), learn = a[6] == "1" }
            end
        end
    end
    rec.profs[name] = { rank = rank, max = max, t = t or ns.Now(), cands = cands, guide = guide }
end

---------------------------------------------------------------------------
-- Plan
---------------------------------------------------------------------------
-- { next, target, points, trainer, options = { { itemID, color, crafts, mats = {{id, n}} } } }
function ns.ProfPlan(p)
    local nextStep
    for _, s in ipairs(STEPS) do
        if p.rank < s then nextStep = s; break end
    end
    if not nextStep then return nil end -- Maximum erreicht
    local plan = { next = nextStep }
    if p.max and p.rank >= p.max then
        plan.trainer = true
        plan.target = p.max
        plan.points = 0
        plan.options = {}
        return plan
    end
    plan.target = math.min(nextStep, p.max or nextStep)
    plan.points = plan.target - p.rank
    plan.options = {}
    local function scaled(itemID, crafts)
        local base = ns.Reagents(itemID)
        if not base then return nil end
        local out = {}
        for i, m in ipairs(base) do out[i] = { m[1], m[2] * crafts } end
        return out
    end
    if p.guide and #p.guide > 0 then
        -- Route (OneForAll): erst "ganze Route" mit allen Mats, dann die einzelnen Schritte
        plan.guide = true
        local total, known, crafts = {}, true, 0
        local steps = {}
        for _, s in ipairs(p.guide) do
            if s.kind == "c" and s.to > p.rank then
                local m = scaled(s.item, s.crafts)
                if not m then known = false end
                for _, x in ipairs(m or {}) do total[x[1]] = (total[x[1]] or 0) + x[2] end
                crafts = crafts + s.crafts
                steps[#steps + 1] = { itemID = s.item, crafts = s.crafts, from = s.from, to = s.to, learn = s.learn, mats = m, color = "g" }
            elseif s.kind == "t" then
                steps[#steps + 1] = { train = true, cap = s.cap, at = s.at }
            end
        end
        local list = {}
        for id, n in pairs(total) do list[#list + 1] = { id, n } end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        local first
        for _, s in ipairs(steps) do if s.itemID then first = s; break end end
        if first then
            plan.options[1] = { total = true, itemID = first.itemID, crafts = crafts, mats = known and list or nil, color = "g" }
        end
        for _, s in ipairs(steps) do plan.options[#plan.options + 1] = s end
        return plan
    end
    for _, c in ipairs(p.cands) do
        local crafts = plan.points * (c[2] == "y" and YELLOW_FACTOR or 1)
        local mats
        local base = ns.Reagents(c[1])
        if base then
            mats = {}
            for i, m in ipairs(base) do mats[i] = { m[1], m[2] * crafts } end
        end
        plan.options[#plan.options + 1] = { itemID = c[1], color = c[2], crafts = crafts, mats = mats }
    end
    return plan
end

-- Eintraege fuer die Ansicht: alle Berufe unter 300 von relevanten Charakteren
function ns.ProfHelpList()
    local DB = FriendsmithDB
    local myGuild = GetGuildInfo("player")
    local now = time()
    local out = {}
    for key, rec in pairs(DB.chars) do
        if rec.profs and ns.IsRelevant(rec, myGuild, now) then
            for name, p in pairs(rec.profs) do
                local plan = ns.ProfPlan(p)
                if plan then
                    local first = plan.options[1]
                    out[#out + 1] = {
                        prof = true, key = key, name = name, p = p, plan = plan,
                        itemID = first and first.itemID, crafters = { key },
                    }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.name < b.name
    end)
    return out
end
