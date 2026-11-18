-- Friendsmith – Spezialisierung erkennen und Gegenstaende nach Werten bewerten
-- Solange ein Charakter keine Talentpunkte verteilt hat, wird nach Itemlevel bewertet.

local ADDON, ns = ...
local L = ns.L

local GetItemStatsFn = (C_Item and C_Item.GetItemStats) or GetItemStats

---------------------------------------------------------------------------
-- Werte
---------------------------------------------------------------------------
-- Kurzname -> Schluessel aus GetItemStats
local STAT_KEYS = {
    STR   = "ITEM_MOD_STRENGTH_SHORT",
    AGI   = "ITEM_MOD_AGILITY_SHORT",
    STA   = "ITEM_MOD_STAMINA_SHORT",
    INT   = "ITEM_MOD_INTELLECT_SHORT",
    SPI   = "ITEM_MOD_SPIRIT_SHORT",
    ARMOR = "RESISTANCE0_NAME",
    DPS   = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
    AP    = "ITEM_MOD_ATTACK_POWER_SHORT",
    RAP   = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    SP    = "ITEM_MOD_SPELL_POWER_SHORT",
    HEAL  = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    MP5   = "ITEM_MOD_MANA_REGENERATION_SHORT",
    DEF   = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    HIT   = "ITEM_MOD_HIT_RATING_SHORT",
    CRIT  = "ITEM_MOD_CRIT_RATING_SHORT",
}
ns.STAT_ORDER = { "STR", "AGI", "STA", "INT", "SPI", "AP", "RAP", "SP", "HEAL", "MP5", "HIT", "CRIT", "DEF", "DPS", "ARMOR" }
ns.STAT_NAMES = {
    STR = L["Strength"], AGI = L["Agility"], STA = L["Stamina"], INT = L["Intellect"], SPI = L["Spirit"],
    ARMOR = L["Armor"], DPS = L["Damage/sec"], AP = L["Attack Power"], RAP = L["Ranged AP"], SP = L["Spell Power"],
    HEAL = L["Healing"], MP5 = L["Mana per 5 sec"], DEF = L["Defense"], HIT = L["Hit"], CRIT = L["Crit"],
}

-- Werte, die zeigen "fuer wen ist dieses Teil gemacht". Hat ein Teil solche Werte,
-- aber keinen davon braucht die Spezialisierung, wird es nicht vorgeschlagen
-- (Zauber-Ausruestung fuer Krieger, Nahkampf-Ausruestung fuer Magier).
local DEFINING = { "STR", "AGI", "INT", "SPI", "AP", "RAP", "SP", "HEAL", "MP5" }

---------------------------------------------------------------------------
-- Gewichtungen (Classic, grob fuers Leveln; Rueckmeldungen willkommen)
---------------------------------------------------------------------------
local P = {
    melee  = { STR = 1.0, AGI = 0.75, STA = 0.35, AP = 0.5, HIT = 8, CRIT = 8, DPS = 3.0, ARMOR = 0.01 },
    enh    = { STR = 1.0, AGI = 0.65, STA = 0.35, INT = 0.25, AP = 0.5, HIT = 8, CRIT = 8, DPS = 3.0, ARMOR = 0.01 },
    tank   = { STA = 1.0, AGI = 0.6, STR = 0.55, DEF = 1.5, ARMOR = 0.05, AP = 0.2, HIT = 4, DPS = 1.0 },
    ptank  = { STA = 1.0, STR = 0.5, INT = 0.35, AGI = 0.4, DEF = 1.5, SP = 0.4, ARMOR = 0.05, DPS = 1.0 },
    hunter = { AGI = 1.0, AP = 0.45, RAP = 0.45, INT = 0.35, STA = 0.35, STR = 0.05, HIT = 8, CRIT = 8, DPS = 1.5, ARMOR = 0.01 },
    rogue  = { AGI = 1.0, STR = 0.55, AP = 0.5, STA = 0.35, HIT = 8, CRIT = 8, DPS = 3.0, ARMOR = 0.01 },
    feral  = { AGI = 1.0, STR = 1.0, STA = 0.6, AP = 0.5, HIT = 6, CRIT = 6, ARMOR = 0.03 },
    caster = { SP = 1.0, INT = 0.8, STA = 0.35, SPI = 0.25, HIT = 6, CRIT = 6, MP5 = 1.0, ARMOR = 0.005 },
    lock   = { SP = 1.0, INT = 0.6, STA = 0.6, SPI = 0.3, HIT = 6, CRIT = 4, MP5 = 0.8, ARMOR = 0.005 },
    healer = { INT = 1.0, HEAL = 0.8, SP = 0.5, SPI = 0.6, MP5 = 2.0, STA = 0.35, CRIT = 4, ARMOR = 0.005 },
}

-- Reihenfolge der Talentbaeume wie im Classic-Talentfenster
local SPECS = {
    WARRIOR = { { L["Arms"], P.melee }, { L["Fury"], P.melee }, { L["Protection"], P.tank } },
    PALADIN = { { L["Holy"], P.healer }, { L["Protection"], P.ptank }, { L["Retribution"], P.melee } },
    HUNTER  = { { L["Beast Mastery"], P.hunter }, { L["Marksmanship"], P.hunter }, { L["Survival"], P.hunter } },
    ROGUE   = { { L["Assassination"], P.rogue }, { L["Combat"], P.rogue }, { L["Subtlety"], P.rogue } },
    PRIEST  = { { L["Discipline"], P.healer }, { L["Holy"], P.healer }, { L["Shadow"], P.caster } },
    SHAMAN  = { { L["Elemental"], P.caster }, { L["Enhancement"], P.enh }, { L["Restoration"], P.healer } },
    MAGE    = { { L["Arcane"], P.caster }, { L["Fire"], P.caster }, { "Frost", P.caster } },
    WARLOCK = { { L["Affliction"], P.lock }, { L["Demonology"], P.lock }, { L["Destruction"], P.lock } },
    DRUID   = { { L["Balance"], P.caster }, { L["Feral Combat"], P.feral }, { L["Restoration"], P.healer } },
}

---------------------------------------------------------------------------
-- Spezialisierung
---------------------------------------------------------------------------
-- Talentbaum mit den meisten Punkten, nil wenn noch keine Punkte verteilt sind.
function ns.DetectSpec()
    if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
    local best, bestPts = nil, 0
    for i = 1, (GetNumTalentTabs() or 0) do
        local r = { GetTalentTabInfo(i) }
        -- alter Client: name, icon, punkte, ... / neuer Client: id, name, beschreibung, icon, punkte, ...
        local pts = (type(r[1]) == "string") and r[3] or r[5]
        pts = tonumber(pts) or 0
        if pts > bestPts then best, bestPts = i, pts end
    end
    return best
end

-- Auswahl je Charakter: nil = automatisch, 0 = Itemlevel, 1-3 = fester Talentbaum
local function Override(key)
    return ns.S.specOverride and ns.S.specOverride[key]
end

-- Liefert Index des Talentbaums, nach dem bewertet wird, oder nil fuer Itemlevel.
local function SpecIndex(key)
    local rec = FriendsmithDB.chars[key]
    if not rec or not SPECS[rec.class or ""] then return nil end
    local o = Override(key)
    if o == 0 then return nil end
    if o then return o end
    if not ns.S.useStats then return nil end
    return rec.spec
end

function ns.WeightsFor(key)
    local i = SpecIndex(key)
    if not i then return nil end
    local s = SPECS[FriendsmithDB.chars[key].class][i]
    return s and s[2]
end

-- Fuer Verzauberungen: Gewichte der Spezialisierung, ohne Talente die des ersten Talentbaums der Klasse
function ns.ClassWeights(key)
    local w = ns.WeightsFor(key)
    if w then return w end
    local rec = FriendsmithDB.chars[key]
    local s = rec and SPECS[rec.class or ""]
    return s and s[1] and s[1][2] or nil
end

function ns.SpecLabel(key)
    local i = SpecIndex(key)
    local rec = FriendsmithDB.chars[key]
    local name = i and rec and SPECS[rec.class] and SPECS[rec.class][i] and SPECS[rec.class][i][1]
    local o = Override(key)
    if name then return name .. (o and L[" (manual)"] or "") end
    if o == 0 then return L["Item level (manual)"] end
    if not ns.S.useStats then return L["Item level"] end
    return L["Item level (no talents)"]
end

-- Automatisch -> Baum 1 -> 2 -> 3 -> Itemlevel -> Automatisch
function ns.CycleSpec(key)
    ns.S.specOverride = ns.S.specOverride or {}
    local o = ns.S.specOverride[key]
    if o == nil then o = 1
    elseif o == 0 then o = nil
    elseif o >= 3 then o = 0
    else o = o + 1 end
    ns.S.specOverride[key] = o
    ns.MarkDirty()
end

---------------------------------------------------------------------------
-- Gegenstandswerte
---------------------------------------------------------------------------
local statCache = {}

-- suffix = Zufallseigenschaft ("... des Affen"), damit gruene Teile richtig bewertet werden
function ns.ItemStats(itemID, suffix)
    if not itemID then return nil end
    suffix = tonumber(suffix) or 0
    local ck = itemID .. ":" .. suffix
    local s = statCache[ck]
    if s then return s end
    if not ns.ItemData(itemID) then return nil end
    local link = (suffix ~= 0) and ("item:" .. itemID .. ":0:0:0:0:0:" .. suffix) or ("item:" .. itemID)
    local raw
    if GetItemStatsFn then
        local ok, res = pcall(GetItemStatsFn, link)
        if ok and type(res) == "table" then raw = res end
    end
    raw = raw or {}
    s = {}
    for short, full in pairs(STAT_KEYS) do s[short] = tonumber(raw[full]) or 0 end
    statCache[ck] = s
    return s
end

function ns.Score(w, s)
    local total = 0
    for k, v in pairs(s) do
        if v ~= 0 and w[k] then total = total + v * w[k] end
    end
    return total
end

function ns.Irrelevant(w, s)
    local has = false
    for _, k in ipairs(DEFINING) do
        if s[k] > 0 then
            has = true
            if (w[k] or 0) >= 0.25 then return false end
        end
    end
    return has
end

-- Unterschiede zweier Wertetabellen als Text, z. B. "+4 Beweglichkeit, -2 Intelligenz"
function ns.StatDiffText(new, cur, w)
    local parts = {}
    for _, k in ipairs(ns.STAT_ORDER) do
        local d = (new and new[k] or 0) - (cur and cur[k] or 0)
        if k == "DPS" then d = math.floor(d * 10 + 0.5) / 10 else d = math.floor(d + 0.5) end
        if d ~= 0 and (k ~= "ARMOR" or #parts < 4) then
            local useful = w == nil or (w[k] or 0) > 0
            local col = not useful and "|cff8f96a8" or (d > 0 and "|cff5cdb6b" or "|cffe0603a")
            parts[#parts + 1] = col .. (d > 0 and "+" or "") .. d .. " " .. ns.STAT_NAMES[k] .. "|r"
        end
    end
    return table.concat(parts, ", ")
end
