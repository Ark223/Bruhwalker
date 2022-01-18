
local Version = 1.06

local function AutoUpdate()
    local url = "https://raw.githubusercontent.com/Ark223/Bruhwalker/main/"
    local result = http:get(url .. "Orbwalker.version")
    if result and result ~= "" and tonumber(result) > Version then
        http:download_file(url .. "Orbwalker.lua", "Orbwalker.lua")
        console:log("[Orbwalker] Successfully updated. Please reload!")
    end
end

local Class = function(...)
    local cls = {}; cls.__index = cls
    cls.__call = function(_, ...) return cls:New(...) end
    function cls:New(...)
        local instance = setmetatable({}, cls)
        cls.__init(instance, ...)
        return instance
    end
    return setmetatable(cls, {__call = cls.__call})
end

local myHero = game.local_player
local prediction = _G.Prediction
if not prediction then return end

--------------------------------------
-- Language INtegrated Query (LINQ) --

local function ParseFunc(func)
    if func == nil then return function(x) return x end end
    if type(func) == "function" then return func end
    local index = string.find(func, "=>")
    local arg = string.sub(func, 1, index - 1)
    local func = string.sub(func, index + 2, #func)
    return load(string.format("return function"
        .. " %s return %s end", arg, func))()
end

local function Linq(tab)
    return setmetatable(tab or {}, {__index = table})
end

function table.All(source, func)
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        if not func(value, index) then
            return false
        end
    end
    return true
end

function table.Any(source, func)
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        if func(value, index) then
            return true
        end
    end
    return false
end

function table.Concat(first, second)
    local result, index = Linq(), 0
    for _, value in ipairs(first) do
        index = index + 1
        result[index] = value
    end
    for _, value in ipairs(second) do
        index = index + 1
        result[index] = value
    end
    return result
end

function table.Distinct(source)
    local result = Linq()
    local hash, index = {}, 0
    for _, value in ipairs(source) do
        if hash[value] == nil then
            index = index + 1
            result[index] = value
            hash[value] = true
        end
    end
    return result
end

function table.First(source, func)
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        if func(value, index) then
            return value
        end
    end
    return nil
end

function table.ForEach(source, func)
    for index, value in pairs(source) do
        func(value, index)
    end
end

function table.Last(source, func)
    local func = ParseFunc(func)
    for index = #source, 1, -1 do
        local value = source[index]
        if func(value, index) then
            return value
        end
    end
    return nil
end

function table.Select(source, func)
    local result = Linq()
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        result[index] = func(value, index)
    end
    return result
end

function table.Where(source, func)
    local result, iteration = Linq(), 0
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        if func(value, index) then
            iteration = iteration + 1
            result[iteration] = value
        end
    end
    return result
end

-----------------------------
-- Merge sorting algorithm --

function Merge(array, left, mid, right, comp)
    local i, j, k, temp = left, mid + 1, left, {}
    for p = left, right do temp[p] = array[p] end
    -- merge the temp arrays back into array
    while i <= mid and j <= right do
        if not comp(temp[i], temp[j]) then
            array[k] = temp[i]
            k, i = k + 1, i + 1
        else
            array[k] = temp[j]
            k, j = k + 1, j + 1
        end
    end
    -- copy the remaining elements
    while i <= mid do
        array[k] = temp[i]
        k, i = k + 1, i + 1
    end
end

function MergeSort(array, left, right, comp)
    if left >= right then return end
    local mid = math.floor((left + right) / 2)
    MergeSort(array, left, mid, comp)
    MergeSort(array, mid + 1, right, comp)
    Merge(array, left, mid, right, comp)
end

table.merge_sort = function(array, comp)
    MergeSort(array, 1, #array, comp or
        function(a, b) return a > b end)
end

----------------------
-- Access validator --

--[[
local id, users = tostring(client.id), Linq()
local resp = http:get("https://raw.githubusercontent.com/Ark223/Bruhwalker/main/Access.txt")
if not resp or resp == "" then
    console:log("[Orbwalker] Failed to read response from server!")
    return
end
for str in resp:gmatch("[^\r\n]+") do users[#users + 1] = str end
if not users:Any(function(s) return s == id end) then
    console:log("[Orbwalker] You are not authorised to use this script.")
    console:log("[Orbwalker] Contact Uncle Ark in order to gain the access.")
    console:log(string.format("[Orbwalker] Your client ID: %s", id))
    return
end
--]]

------------------
-- Damage class --

local Damage = Class()

function Damage:__init()
    self.heroPassives = {
        ["Aatrox"] = function(args) local source = args.source
            if not source:has_buff("aatroxpassiveready") then return end
            args.rawPhysical = args.rawPhysical + (4.59 + 0.41
                * source.level) * 0.01 * args.unit.max_health
        end,
        ["Akali"] = function(args) local source = args.source
            if not source:has_buff("akalishadowstate") then return end
            local mod = ({35, 38, 41, 44, 47, 50, 53, 62, 71, 80,
                89, 98, 107, 122, 137, 152, 167, 182})[source.level]
            args.rawMagical = args.rawMagical + mod + 0.55 *
                source.ability_power + 0.6 * source.bonus_attack_damage
        end,
        ["Akshan"] = function(args) local source = args.source
            local buff = args.unit:get_buff("AkshanPassiveDebuff")
            if not buff or buff.count ~= 2 then return end
            local mod = ({20, 25, 30, 35, 40, 45, 50, 55, 65, 75,
                85, 95, 105, 115, 130, 145, 160, 175})[source.level]
            args.rawMagical = args.rawMagical + mod
        end,
        ["Ashe"] = function(args) local source = args.source
            local totalDmg = source.total_attack_damage
            local slowed = args.unit:has_buff("ashepassiveslow")
            local mod = 0.0075 + (source:has_item(3031) and 0.0035 or 0)
            local percent = slowed and 0.1 + source.crit_chance * mod or 0
            args.rawPhysical = args.rawPhysical + percent * totalDmg
            if not source:has_buff("AsheQAttack") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical * (1 + 0.05 * lvl)
        end,
        ["Bard"] = function(args) local source = args.source
            if not source:has_buff("bardpspiritammocount") then return end
            local chimes = source:get_buff("bardpdisplaychimecount")
            if not chimes or chimes.count <= 0 then return end
            args.rawMagical = args.rawMagical + (12 * math.floor(
                chimes.count / 5)) + 30 + 0.3 * source.ability_power
        end,
        ["Blitzcrank"] = function(args) local source = args.source
            if not source:has_buff("PowerFist") then return end
            args.rawPhysical = args.rawPhysical + source.total_attack_damage
        end,
        ["Braum"] = function(args) local source = args.source
            local buff = args.unit:get_buff("BraumMark")
            if not buff or buff.count ~= 3 then return end
            args.rawMagical = args.rawMagical + 16 + 10 * source.level
        end,
        ["Caitlyn"] = function(args) local source = args.source
            if not source:has_buff("caitlynpassivedriver") then return end
            local mod = 1.09375 + (source:has_item(3031) and 0.21875 or 0)
            args.rawPhysical = args.rawPhysical + (1 + (mod * 0.01 *
                source.crit_chance)) * source.total_attack_damage
        end,
        ["Camille"] = function(args) local source = args.source
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            if source:has_buff("CamilleQ") then
                args.rawPhysical = args.rawPhysical + (0.15 +
                    0.05 * lvl) * source.total_attack_damage
            elseif source:has_buff("CamilleQ2") then
                args.trueDamage = args.trueDamage + math.min(
                    0.36 + 0.04 * source.level, 1) * (0.3 +
                    0.1 * lvl) * source.total_attack_damage
            end
        end,
        ["Chogath"] = function(args) local source = args.source
            if not source:has_buff("VorpalSpikes") then return end
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            args.rawMagical = args.rawMagical + 10 + 12 * lvl + 0.3 *
                source.ability_power + 0.03 * args.unit.max_health
        end,
        ["Darius"] = function(args) local source = args.source
            if not source:has_buff("DariusNoxianTacticsONH") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawPhysical = args.rawPhysical + (0.35 +
                0.05 * lvl) * source.total_attack_damage
        end,
        ["Diana"] = function(args) local source = args.source
            local buff = source:get_buff("dianapassivemarker")
            if not buff or buff.count ~= 2 then return end
            local mod = ({20, 25, 30, 35, 40, 55, 65, 75, 85,
                95, 120, 135, 150, 165, 180, 210, 230, 250})[source.level]
            args.rawMagical = args.rawMagical + mod + 0.4 * source.ability_power
        end,
        ["Draven"] = function(args) local source = args.source
            if not source:has_buff("DravenSpinningAttack") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 35 + 5 * lvl +
                (0.6 + 0.1 * lvl) * source.bonus_attack_damage
        end,
        ["DrMundo"] = function(args) local source = args.source
            if not source:has_buff("DrMundoE") then return end
            --[[ local lvl = spellbook:get_spell_slot(SLOT_E).level
            local bonusHealth = source.max_health - (494 + source.level * 89)
            args.rawPhysical = args.rawPhysical + (0.14 * bonusHealth - 10
                + 20 * lvl) * (1 + 1.5 * math.min((source.max_health
                - source.health) / source.max_health, 0.4)) --]]
        end,
        ["Ekko"] = function(args) local source = args.source
            local buff = args.unit:get_buff("ekkostacks")
            if buff ~= nil and buff.count == 2 then
                local mod = ({30, 40, 50, 60, 70, 80, 85, 90, 95, 100,
                    105, 110, 115, 120, 125, 130, 135, 140})[source.level]
                args.rawMagical = args.rawMagical + mod + 0.8 * source.ability_power
            end
            if source:has_buff("ekkoeattackbuff") then
                local lvl = spellbook:get_spell_slot(SLOT_E).level
                args.rawMagical = args.rawMagical + 25 +
                    25 * lvl + 0.4 * source.ability_power
            end
        end,
        ["Fizz"] = function(args) local source = args.source
            if not source:has_buff("FizzW") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical + 30 +
                20 * lvl + 0.5 * source.ability_power
        end,
        ["Galio"] = function(args) local source = args.source
            if not source:has_buff("galiopassivebuff") then return end
            --[[ local bonusResist = source.mr - (30.75 + 1.25 * source.level)
            args.rawMagical, args.rawPhysical = args.rawMagical + 4.12 +
                10.88 * source.level + source.total_attack_damage +
                0.5 * source.ability_power + 0.6 * bonusResist, 0 --]]
        end,
        ["Garen"] = function(args) local source = args.source
            if not source:has_buff("GarenQ") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 30 *
                lvl + 0.5 * source.total_attack_damage
        end,
        ["Gnar"] = function(args) local source = args.source
            local buff = args.unit:get_buff("gnarwproc")
            if not buff or buff.count ~= 2 then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical - 10 + 10 * lvl + (0.04 +
                0.02 * lvl) * args.unit.max_health + source.ability_power
        end,
        ["Gragas"] = function(args) local source = args.source
            if not source:has_buff("gragaswattackbuff") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical - 10 + 30 * lvl + 0.07
                * args.unit.max_health + 0.7 * source.ability_power
        end,
        ["Gwen"] = function(args) local source = args.source
            args.rawMagical = args.rawMagical + (0.01 + 0.008 *
                0.01 * source.ability_power) * args.unit.max_health
            if args.unit.health / args.unit.max_health <= 0.4
                and args.unit.champ_name:find("Minion") then
                local mod = 6.71 + 1.29 * source.level
                args.rawPhysical = args.rawPhysical + mod
            elseif not args.unit.champ_name:find("Minion") then
                args.rawMagical = math.max(args.rawMagical,
                    10 + 0.25 * source.ability_power)
            end
        end,
        ["Illaoi"] = function(args) local source = args.source
            if not source:has_buff("IllaoiW") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            local damage = math.min(300, math.max(10 + 10 * lvl,
                args.unit.max_health * (0.025 + 0.005 * lvl
                + 0.0002 * source.total_attack_damage)))
            args.rawPhysical = args.rawPhysical + damage
        end,
        ["Irelia"] = function(args) local source = args.source
            local buff = source:get_buff("ireliapassivestacks")
            if not buff or buff.count ~= 4 then return end
            args.rawMagical = args.rawMagical + 7 + 3 *
                source.level + 0.3 * source.bonus_attack_damage
        end,
        ["JarvanIV"] = function(args) local source = args.source
            if not args.unit:has_buff("jarvanivmartialcadencecheck") then return end
            local damage = math.min(400, math.max(20, 0.1 * args.unit.health))
            args.rawPhysical = args.rawPhysical + damage
        end,
        ["Jax"] = function(args) local source = args.source
            if source:has_buff("JaxEmpowerTwo") then
                local lvl = spellbook:get_spell_slot(SLOT_W).level
                args.rawMagical = args.rawMagical + 5 +
                    35 * lvl + 0.6 * source.ability_power
            end
            if source:has_buff("JaxRelentlessAssault") then
                local lvl = spellbook:get_spell_slot(SLOT_R).level
                args.rawMagical = args.rawMagical + 60 +
                    40 * lvl + 0.7 * source.ability_power
            end
        end,
        ["Jayce"] = function(args) local source = args.source
            if source:has_buff("JaycePassiveMeleeAttack") then
                local mod = ({25, 25, 25, 25, 25, 65,
                    65, 65, 65, 65, 105, 105, 105, 105,
                    105, 145, 145, 145})[source.level]
                args.rawMagical = args.rawMagical + mod
                    + 0.25 * source.bonus_attack_damage
            end -- JayceHyperCharge buff count not working?
        end,
        ["Jhin"] = function(args) local source = args.source
            if not source:has_buff("jhinpassiveattackbuff") then return end
            local missingHealth, mod = args.unit.max_health - args.unit.health,
                source.level < 6 and 0.15 or source.level < 11 and 0.2 or 0.25
            args.rawPhysical = args.rawPhysical + mod * missingHealth
        end,
        ["Jinx"] = function(args) local source = args.source
            if not source:has_buff("JinxQ") then return end
            args.rawPhysical = args.rawPhysical
                + source.total_attack_damage * 0.1
        end,
        ["Kaisa"] = function(args) local source = args.source
            local buff = args.unit:get_buff("kaisapassivemarker")
            local count = buff ~= nil and buff.count or 0
            local damage = ({1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
                4, 4, 4, 4, 5, 5, 5})[source.level] * count +
                (0.075 - 0.025 * count) * source.ability_power
            if count == 4 then damage = damage +
                (0.15 + (0.025 * source.ability_power / 100)) *
                (args.unit.max_health - args.unit.health) end
            args.rawMagical = args.rawMagical + damage
        end,
        ["Kassadin"] = function(args) local source = args.source
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            if source:has_buff("NetherBlade") then
                args.rawMagical = args.rawMagical + 45 +
                    25 * lvl + 0.8 * source.ability_power
            elseif lvl > 0 then
                args.rawMagical = args.rawMagical +
                    20 + 0.1 * source.ability_power
            end
        end,
        ["Kayle"] = function(args) local source = args.source
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            if lvl > 0 then args.rawMagical = args.rawMagical
                + 10 + 5 * lvl + 0.2 * source.ability_power
                + 0.1 * source.bonus_attack_damage end
            if source:has_buff("JudicatorRighteousFury") then
                args.rawMagical = args.rawMagical + (7 + lvl +
                    source.ability_power * 0.01 * 2) * 0.01 *
                    (args.unit.max_health - args.unit.health)
            end
        end,
        ["Kennen"] = function(args) local source = args.source
            if not source:has_buff("kennendoublestrikelive") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical + 10 + 10 * lvl + (0.5 + 0.1 *
                lvl) * source.bonus_attack_damage + 0.25 * source.ability_power
        end,
        ["KogMaw"] = function(args) local source = args.source
            if not source:has_buff("KogMawBioArcaneBarrage") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical + (0.02 + 0.01 * lvl +
                0.0001 * source.ability_power) * args.unit.max_health
        end,
        ["Leona"] = function(args) local source = args.source
            if not source:has_buff("LeonaSolarFlare") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawMagical = args.rawMagical - 15 +
                25 * lvl + 0.3 * source.ability_power
        end,
        ["Lux"] = function(args) local source = args.source
            if not args.unit:has_buff("LuxIlluminatingFraulein") then return end
            args.rawMagical = args.rawMagical + 10 + 10 *
                source.level + 0.2 * source.ability_power
        end,
        ["Malphite"] = function(args) local source = args.source
            if not source:has_buff("MalphiteCleave") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawPhysical = args.rawPhysical + 15 + 15 * lvl
                + 0.2 * source.ability_power + 0.1 * source.armor
        end,
        ["MasterYi"] = function(args) local source = args.source
            if not source:has_buff("wujustylesuperchargedvisual") then return end
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            args.trueDamage = args.trueDamage + 20 + 10 *
                lvl + 0.35 * source.bonus_attack_damage
        end,
        -- MissFortune - can't detect buff ??
        ["Mordekaiser"] = function(args) local source = args.source
            args.rawMagical = args.rawMagical + 0.4 * source.ability_power
        end,
        ["Nami"] = function(args) local source = args.source
            if not source:has_buff("NamiE") then return end
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            args.rawMagical = args.rawMagical + 10 +
                15 * lvl + 0.2 * source.ability_power
        end,
        ["Nasus"] = function(args) local source = args.source
            if not source:has_buff("NasusQ") then return end
            local buff = source:get_buff("NasusQStacks")
            local stacks = buff ~= nil and buff.count or 0
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 10 + 20 * lvl + stacks
        end,
        ["Nautilus"] = function(args) local source = args.source
            if args.unit:has_buff("nautiluspassivecheck") then return end
            args.rawPhysical = args.rawPhysical + 2 + 6 * source.level
        end,
        ["Nidalee"] = function(args) local source = args.source
            if not source:has_buff("Takedown") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawMagical = args.rawMagical + (-20 + 25 *
                lvl + 0.75 * source.total_attack_damage + 0.4 *
                source.ability_power) * ((args.unit.max_health -
                args.unit.health) / args.unit.max_health + 1)
            if args.unit:has_buff("NidaleePassiveHunted") then
                args.rawMagical = args.rawMagical * 1.4 end
            args.rawPhysical = 0
        end,
        ["Neeko"] = function(args) local source = args.source
            if not source:has_buff("neekowpassiveready") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical + 30 +
                20 * lvl + 0.6 * source.ability_power
        end,
        ["Nocturne"] = function(args) local source = args.source
            if not source:has_buff("nocturneumbrablades") then return end
            args.rawPhysical = args.rawPhysical + 0.2 * source.total_attack_damage
        end,
        ["Orianna"] = function(args) local source = args.source
            args.rawMagical = args.rawMagical + 2 + math.ceil(
                source.level / 3) * 8 + 0.15 * source.ability_power
            local buff = source:get_buff("orianapowerdaggerdisplay")
            if not buff or buff.count == 0 then return end
            args.rawMagical = raw.rawMagical * (1 + 0.2 * buff.count)
        end,
        ["Poppy"] = function(args) local source = args.source
            if not source:has_buff("poppypassivebuff") then return end
            args.rawMagical = args.rawMagical + 10.59 + 9.41 * source.level
        end,
        ["Quinn"] = function(args) local source = args.source
            if not args.unit:has_buff("QuinnW") then return end
            args.rawPhysical = args.rawPhysical + 5 + 5 * source.level +
                (0.14 + 0.02 * source.level) * source.total_attack_damage
        end,
        ["RekSai"] = function(args) local source = args.source
            if not source:has_buff("RekSaiQ") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 15 + 6 *
                lvl + 0.5 * source.bonus_attack_damage
        end,
        ["Rell"] = function(args) local source = args.source
            args.rawMagical = args.rawMagical + 7.53 + 0.47 * source.level
            if not source:has_buff("RellWEmpoweredAttack") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical - 5 +
                15 * lvl + 0.4 * source.ability_power
        end,
        ["Rengar"] = function(args) local source = args.source
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            if source:has_buff("RengarQ") then
                args.rawPhysical = args.rawPhysical + 30 * lvl +
                    (-0.05 + 0.05 * lvl) * source.total_attack_damage
            elseif source:has_buff("RengarQEmp") then
                local mod = ({30, 45, 60, 75, 90, 105,
                    120, 135, 145, 155, 165, 175, 185,
                    195, 205, 215, 225, 235})[source.level]
                args.rawPhysical = args.rawPhysical +
                    mod + 0.4 * source.total_attack_damage
            end
        end,
        ["Riven"] = function(args) local source = args.source
            if not source:has_buff("RivenPassiveAABoost") then return end
            args.rawPhysical = args.rawPhysical + (source.level >= 6 and 0.36 + 0.06 *
                math.floor((source.level - 6) / 3) or 0.3) * source.total_attack_damage
        end,
        ["Rumble"] = function(args) local source = args.source
            if not source:has_buff("RumbleOverheat") then return end
            args.rawMagical = args.rawMagical + 2.94 + 2.06 * source.level
                + 0.25 * source.ability_power + 0.06 * args.unit.max_health
        end,
        ["Sett"] = function(args) local source = args.source
            if not source:has_buff("SettQ") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical +
                10 * lvl + (0.01 + (0.005 + 0.005 * lvl) * 0.01 *
                source.total_attack_damage) * args.unit.max_health
        end,
        ["Shaco"] = function(args) local source = args.source
            local turned = not Geometry:IsFacing(args.unit, source)
            if turned then args.rawPhysical = args.rawPhysical + 19.12 +
                0.88 * source.level + 0.15 * source.bonus_attack_damage end
            if not source:has_buff("Deceive") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 15 +
                10 * lvl + 0.25 * source.bonus_attack_damage
            local mod = 0.3 + (source:has_item(3031) and 0.35 or 0)
            if turned then args.rawPhysical = args.rawPhysical
                + mod * source.total_attack_damage end
        end,
        -- Seraphine
        ["Shen"] = function(args) local source = args.source
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            if source:has_buff("shenqbuffweak") then
                args.rawMagical = args.rawMagical + 4 + 6 * math.ceil(
                    source.level / 3) + (0.015 + 0.005 * lvl + 0.015 *
                    source.ability_power / 100) * args.unit.max_health
            elseif source:has_buff("shenqbuffstrong") then
                args.rawMagical = args.rawMagical + 4 + 6 * math.ceil(
                    source.level / 3) + (0.045 + 0.005 * lvl + 0.02 *
                    source.ability_power / 100) * args.unit.max_health
            end
        end,
        ["Shyvana"] = function(args) local source = args.source
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            if source:has_buff("ShyvanaDoubleAttack") then
                args.rawPhysical = args.rawPhysical + (0.05 + 0.15 * lvl) *
                    source.total_attack_damage + 0.25 * source.ability_power
            end
            if args.unit:has_buff("ShyvanaFireballMissile") then
                local damage = 0.0375 * args.unit.max_health
                if args.unit.is_minion == true and
                    not args.unit.champ_name:find("Minion")
                    and damage > 150 then damage = 150 end
                args.rawMagical = args.rawMagical + damage
            end
        end,
        ["Skarner"] = function(args) local source = args.source
            if not source:has_buff("skarnerpassivebuff") then return end
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            args.rawPhysical = args.rawPhysical + 10 + 20 * lvl
        end,
        ["Sona"] = function(args) local source = args.source
            if source:has_buff("SonaQProcAttacker") then
                local lvl = spellbook:get_spell_slot(SLOT_Q).level
                args.rawMagical = args.rawMagical + 5 +
                    5 * lvl + 0.2 * source.ability_power
            end -- SonaPassiveReady
        end,
        ["Sylas"] = function(args) local source = args.source
            if not source:has_buff("SylasPassiveAttack") then return end
            args.rawMagical, args.rawPhysical = source.ability_power
                * 0.25 + source.total_attack_damage * 1.3, 0
        end,
        ["TahmKench"] = function(args) local source = args.source
            args.rawMagical = args.rawMagical + 4.94 + 3.06 * source.level
                + 0.025 * (source.max_health - (475 + 95 * source.level))
        end,
        ["Taric"] = function(args) local source = args.source
            if not source:has_buff("taricgemcraftbuff") then return end
            args.rawMagical = args.rawMagical + 21 + 4 *
                source.level + 0.15 * source.bonus_armor
        end,
        ["Teemo"] = function(args) local source = args.source
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            if lvl == 0 then return end
            local damage = 3 + 11 * lvl + 0.3 * source.ability_power
            local mod = not args.unit.champ_name:find("Minion")
                and args.unit.is_minion == true and 1.5 or 1
            args.rawMagical = args.rawMagical + mod * damage
        end,
        ["Trundle"] = function(args) local source = args.source
            if not source:has_buff("TrundleTrollSmash") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 20 * lvl +
                (0.05 + 0.1 * lvl) * source.total_attack_damage
        end,
        ["TwistedFate"] = function(args) local source = args.source
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            if source:has_buff("BlueCardPreAttack") then
                args.rawMagical = args.rawMagical + 20 + 20 * lvl +
                    source.total_attack_damage + 0.9 * source.ability_power
            elseif source:has_buff("RedCardPreAttack") then
                args.rawMagical = args.rawMagical + 15 + 15 * lvl +
                    source.total_attack_damage + 0.6 * source.ability_power
            elseif source:has_buff("GoldCardPreAttack") then
                args.rawMagical = args.rawMagical + 7.5 + 7.5 * lvl +
                    source.total_attack_damage + 0.5 * source.ability_power
            end
            if args.rawMagical > 0 then args.rawPhysical = 0 end
            if source:has_buff("cardmasterstackparticle") then
                local lvl = spellbook:get_spell_slot(SLOT_E).level
                args.rawMagical = args.rawMagical + 40 +
                    25 * lvl + 0.5 * source.ability_power
            end
        end,
        ["Varus"] = function(args) local source = args.source
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            if lvl > 0 then args.rawMagical = args.rawMagical +
                6 + lvl + 0.25 * source.ability_power end
        end,
        ["Vayne"] = function(args) local source = args.source
            if source:has_buff("vaynetumblebonus") then
                local lvl = spellbook:get_spell_slot(SLOT_Q).level
                args.rawPhysical = args.rawPhysical + (0.55 +
                    0.05 * lvl) * source.total_attack_damage
            end
            local buff = args.unit:get_buff("VayneSilveredDebuff")
            if not buff or buff.count ~= 2 then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            local damage = math.max((0.015 + 0.025 * lvl)
                * args.unit.max_health, 35 + 15 * lvl)
            if not args.unit.champ_name:find("Minion")
                and args.unit.is_minion == true and
                damage > 200 then damage = 200 end
            args.trueDamage = args.trueDamage + damage
        end,
        -- Vex
        ["Vi"] = function(args) local source = args.source
            if source:has_buff("ViE") then
                local lvl = spellbook:get_spell_slot(SLOT_E).level
                --[[ args.rawPhysical = 20 * lvl - 10 + source.ability_power
                    * 0.9 + 1.1 * source.total_attack_damage --]]
            end
            local buff = args.unit:get_buff("viwproc")
            if not buff or buff.count ~= 2 then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawPhysical = args.rawPhysical + (0.04 + 0.015 * lvl + 0.01
                * source.bonus_attack_damage / 35) * args.unit.max_health
        end,
        ["Viego"] = function(args) local source = args.source
            --[[ local lvl = spellbook:get_spell_slot(SLOT_Q).level
            if lvl > 0 then args.rawPhysical = args.rawPhysical + math.max(
                5 + 5 * lvl, (0.01 + 0.01 * lvl) * args.unit.health) end --]]
        end,
        ["Viktor"] = function(args) local source = args.source
            if not source:has_buff("ViktorPowerTransferReturn") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawMagical, args.rawPhysical = args.rawMagical - 5 + 25 * lvl
                + source.total_attack_damage + 0.6 * source.ability_power, 0
        end,
        ["Volibear"] = function(args) local source = args.source
            if not source:has_buff("volibearpapplicator") then return end
            local mod = ({11, 12, 13, 15, 17, 19, 22, 25,
                28, 31, 34, 37, 40, 44, 48, 52, 56, 60})[source.level]
            args.rawMagical = args.rawMagical + mod + 0.4 * source.ability_power
        end,
        ["Warwick"] = function(args) local source = args.source
            args.rawMagical = args.rawMagical + 10 + 2 * source.level + 0.15
                * source.bonus_attack_damage + 0.1 * source.ability_power
        end,
        ["MonkeyKing"] = function(args) local source = args.source
            if not source:has_buff("MonkeyKingDoubleAttack") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical - 5 +
                25 * lvl + 0.45 * source.bonus_attack_damage
        end,
        ["XinZhao"] = function(args) local source = args.source
            if not source:has_buff("XinZhaoQ") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 7 +
                9 * lvl + 0.4 * source.bonus_attack_damage
        end,
        -- Yone
        ["Yorick"] = function(args) local source = args.source
            if not source:has_buff("yorickqbuff") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 5 +
                25 * lvl + 0.4 * source.total_attack_damage
        end,
        -- Zed
        ["Zeri"] = function(args) local source = args.source
            if not spellbook:can_cast(SLOT_Q) then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = 5 + 5 * lvl + 1.1 * myHero.total_attack_damage
        end,
        ["Ziggs"] = function(args) local source = args.source
            if not source:has_buff("ZiggsShortFuse") then return end
            local mod = ({20, 24, 28, 32, 36, 40, 48, 56, 64,
                72, 80, 88, 100, 112, 124, 136, 148, 160})[source.level]
            args.rawMagical = args.rawMagical + mod + 0.5 * source.ability_power
        end,
        ["Zoe"] = function(args) local source = args.source
            if not source:has_buff("zoepassivesheenbuff") then return end
            local mod = ({16, 20, 24, 28, 32, 36, 42, 48, 54,
                60, 66, 74, 82, 90, 100, 110, 120, 130})[source.level]
            args.rawMagical = args.rawMagical + mod + 0.2 * source.ability_power
        end
    }
    self.itemPassives = {
        [3504] = function(args) local source = args.source -- Ardent Censer
            if not source:has_buff("3504Buff") then return end
            args.rawMagical = args.rawMagical + 4.12 + 0.88 * args.unit.level
        end,
        [3153] = function(args) local source = args.source -- Blade of the Ruined King
            local damage = math.min(math.max((source.is_melee
                and 0.1 or 0.06) * args.unit.health, 15), 60)
            args.rawPhysical = args.rawPhysical + damage
        end,
        [6632] = function(args) local source = args.source -- Divine Sunderer
            if not source:has_buff("6632buff") then return end
            local attackDmg = source.total_attack_damage
            local mod = source.is_melee and 0.12 or 0.09
            local damage = math.min(attackDmg
                * 1.5, mod * args.unit.max_health)
            if not args.unit.champ_name:find("Minion")
                and args.unit.is_minion and damage > 2.5 *
                attackDmg then damage = 2.5 * attackDmg end
            args.rawPhysical = args.rawPhysical + damage
        end,
        [1056] = function(args) -- Doran's Ring
            args.rawPhysical = args.rawPhysical + 5
        end,
        [1054] = function(args) -- Doran's Shield
            args.rawPhysical = args.rawPhysical + 5
        end,
        [3508] = function(args) local source = args.source -- Essence Reaver
            if not source:has_buff("3508buff") then return end
            args.rawPhysical = args.rawPhysical + 0.4 *
                source.bonus_attack_damage + source.base_attack_damage
        end,
        [3124] = function(args) local source = args.source -- Guinsoo's Rageblade
            args.rawPhysical = args.rawPhysical +
                math.min(200, source.crit_chance * 200)
        end,
        [2015] = function(args) local source = args.source -- Kircheis Shard
            local buff = source:get_buff("itemstatikshankcharge")
            local damage = buff and buff.stacks2 == 100 and 80 or 0
            args.rawMagical = args.rawMagical + damage
        end,
        [6672] = function(args) local source = args.source -- Kraken Slayer
            local buff = source:get_buff("6672buff")
            if not buff or buff.count ~= 2 then return end
            args.trueDamage = args.trueDamage + 60 +
                0.45 * source.bonus_attack_damage
        end,
        [3100] = function(args) local source = args.source -- Lich Bane
            if not source:has_buff("lichbane") then return end
            args.rawMagical = args.rawMagical + 1.5 *
                source.base_attack_damage + 0.4 * source.ability_power
        end,
        [3036] = function(args) local source = args.source -- Lord Dominik's Regards
            local diff = math.min(2000, math.max(0,
                args.unit.max_health - source.max_health))
            args.rawPhysical = args.rawPhysical + (1 + diff /
                100 * 0.75) * source.bonus_attack_damage
        end,
        [3042] = function(args) -- Muramana
            args.rawPhysical = args.rawPhysical 
                + args.source.max_mana * 0.025
        end,
        [3115] = function(args) -- Nashor's Tooth
            args.rawMagical = args.rawMagical + 15
                + 0.2 * args.source.ability_power
        end,
        [6670] = function(args) -- Noonquiver
            args.rawPhysical = args.rawPhysical + 20
        end,
        [6677] = function(args) local source = args.source -- Rageknife
            args.rawPhysical = args.rawPhysical +
                math.min(175, 175 * source.crit_chance)
        end,
        [3094] = function(args) local source = args.source -- Rapid Firecannon
            local buff = source:get_buff("itemstatikshankcharge")
            local damage = buff and buff.stacks2 == 100 and 120 or 0
            args.rawMagical = args.rawMagical + damage
        end,
        [1043] = function(args) -- Recurve Bow
            args.rawPhysical = args.rawPhysical + 15
        end,
        [3057] = function(args) local source = args.source -- Sheen
            if not source:has_buff("sheen") then return end
            args.rawPhysical = args.rawPhysical + source.base_attack_damage
        end,
        [3095] = function(args) local source = args.source -- Stormrazor
            local buff = source:get_buff("itemstatikshankcharge")
            local damage = buff and buff.stacks2 == 100 and 120 or 0
            args.rawMagical = args.rawMagical + damage
        end,
        [3070] = function(args) -- Tear of the Goddess
            args.rawPhysical = args.rawPhysical + 5
        end,
        [3748] = function(args) local source = args.source -- Titanic Hydra
            local damage = source.is_melee and (5 + source.max_health
                * 0.015) or (3.75 + source.max_health * 0.01125)
            args.rawPhysical = args.rawPhysical + damage
        end,
        [3078] = function(args) local source = args.source -- Trinity Force
            if not source:has_buff("3078trinityforce") then return end
            args.rawPhysical = args.rawPhysical + 2 * source.base_attack_damage
        end,
        [6664] = function(args) local source = args.source -- Turbo Chemtank
            local buff = source:has_buff("item6664counter")
            if not buff or buff.stacks2 ~= 100 then return end
            args.rawMagical = args.rawMagical + 35.29 + 4.71 * source.level
                + 0.01 * source.max_health + 0.03 * source.move_speed
        end,
        [3091] = function(args) local source = args.source -- Wit's End
            local damage = ({15, 15, 15, 15, 15, 15, 15, 15, 25, 35,
                45, 55, 65, 75, 76.25, 77.5, 78.75, 80})[source.level]
            args.rawMagical = args.rawMagical + damage
        end
    }
end

function Damage:CalcAutoAttackDamage(source, unit)
    local name = source.champ_name
    local physical = source.total_attack_damage
    if name == "Corki" and physical > 0 then return
        self:CalcMixedDamage(source, unit, physical) end
    local args = {rawMagical = 0, rawPhysical = physical,
        trueDamage = 0, source = myHero, unit = unit}
    local ids = Linq(myHero.items):Where("(i) => i ~= nil")
        :Select("(i) => i.item_id"):Distinct():ForEach(function(i)
        if self.itemPassives[i] then self.itemPassives[i](args) end end)
    if self.heroPassives[name] then self.heroPassives[name](args) end
    local magical = self:CalcMagicalDamage(source, unit, args.rawMagical)
    local physical = self:CalcPhysicalDamage(source, unit, args.rawPhysical)
    return magical + physical + args.trueDamage
end

function Damage:CalcEffectiveDamage(source, unit, amount)
    return source.ability_power > source.total_attack_damage
        and self:CalcMagicalDamage(source, unit, amount)
        or self:CalcPhysicalDamage(source, unit, amount)
end

function Damage:CalcMagicalDamage(source, unit, amount)
    local amount = amount or source.ability_power
    if amount <= 0 then return amount end
    local magicRes = unit.mr
    if magicRes < 0 then
        local reduction = 2 - 100 / (100 - magicRes)
        return math.floor(amount * reduction)
    end
    local magicPen = source.percent_magic_penetration
    local flatPen = source.flat_magic_penetration
    local res = magicRes * magicPen - flatPen
    local reduction = res < 0 and 1 or 100 / (100 + res)
    return math.floor(amount * reduction)
end

function Damage:CalcMixedDamage(source, unit, amount)
    return self:CalcMagicalDamage(source, unit, amount * 0.8)
        + self:CalcPhysicalDamage(source, unit, amount * 0.2)
end

function Damage:CalcPhysicalDamage(source, unit, amount)
    local amount = amount or source.total_attack_damage
    if amount <= 0 then return amount end
    if source.champ_name == "Kalista" then
        amount = amount * 0.9
    elseif source.champ_name == "Graves" then
        local percent = 0.68235 + source.level * 0.01765
        amount = amount * percent
    end
    local armor = unit.armor
    if armor < 0 then
        local reduction = 2 - 100 / (100 - armor)
        return math.floor(amount * reduction)
    end
    local bonusArmor = unit.bonus_armor
    local armorPen = source.percent_armor_penetration
    local bonusPen = source.percent_bonus_armor_penetration
    local lethality = source.lethality * (0.6 + 0.4 * source.level / 18)
    local res = armor * armorPen - (bonusArmor * (1 - bonusPen)) - lethality
    return math.floor(amount * (res < 0 and 1 or 100 / (100 + res)))
end

----------------
-- Data class --

local Data = Class()

function Data:__init()
    self.hybridRange = {"Elise", "Gnar", "Jayce", "Kayle", "Nidalee", "Zeri"}
    self.lethalTempoBuff = "ASSETS/Perks/Styles/Precision/LethalTempo/LethalTempoEmpowered.lua"
    self.lethalTempoCooldown = "ASSETS/Perks/Styles/Precision/LethalTempo/LethalTempoCooldown.lua"
    self.blockAttackBuffs = {
        ["Akshan"] = {"AkshanR"}, ["Darius"] = {"dariusqcast"}, ["Galio"] = {"GalioW"},
        ["Gragas"] = {"gragaswself"}, ["Jhin"] = {"JhinPassiveReload"}, ["Kaisa"] = {"KaisaE"},
        ["KogMaw"] = {"KogMawIcathianSurprise"}, ["Lillia"] = {"LilliaQ"}, ["Lucian"] = {"LucianR"},
        ["Pyke"] = {"PykeQ"}, ["Sion"] = {"SionR"}, ["Urgot"] = {"UrgotW"}, ["Varus"] = {"VarusQ"},
        ["Vi"] = {"ViQ"}, ["Vladimir"] = {"VladimirE"}, ["Xerath"] = {"XerathArcanopulseChargeUp"}
    }
    self.blockOrbBuffs = {
        ["Caitlyn"] = {"CaitlynAceintheHole"}, ["FiddleSticks"] = {"Drain", "Crowstorm"},
        ["Galio"] = {"GalioR"}, ["Gwen"] = {"gwenz_lockfacing"}, ["Irelia"] = {"ireliawdefense"},
        ["Janna"] = {"ReapTheWhirlwind"}, ["Karthus"] = {"KarthusDeathDefiedBuff", "karthusfallenonecastsound"},
        ["Katarina"] = {"katarinarsound"}, ["Malzahar"] = {"MalzaharRSound"}, ["MasterYi"] = {"Meditate"},
        ["MissFortune"] = {"missfortunebulletsound"}, ["Pantheon"] = {"PantheonRJump"},
        ["Shen"] = {"shenstandunitedlock"}, ["Sion"] = {"SionQ"}, ["Taliyah"] = {"TaliyahR"},
        ["TwistedFate"] = {"Gate"}, ["Velkoz"] = {"VelkozR"}, ["Warwick"] = {"WarwickRSound"},
        ["Xerath"] = {"XerathLocusOfPower2"}, ["Zac"] = {"ZacE"}
    }
    self.buffStackNames = {
        ["Akshan"] = "AkshanPassiveDebuff", ["Braum"] = "BraumMark", ["Darius"] = "DariusHemo",
        ["Ekko"] = "ekkostacks", ["Gnar"] = "gnarwproc", ["Kaisa"] = "kaisapassivemarker",
        ["Kalista"] = "KalistaExpungeMarker", ["Kennen"] = "kennenmarkofstorm",
        ["Kindred"] = "kindredecharge", ["Tristana"] = "tristanaechargesound",
        ["Twitch"] = "TwitchDeadlyVenom", ["Vayne"] = "VayneSilveredDebuff", ["Vi"] = "viwproc",
    }
    self.monsterNames = {
        ["SRU_Baron"] = true, ["SRU_Blue"] = true, ["Sru_Crab"] = true, ["SRU_Dragon_Air"] = true,
        ["SRU_Dragon_Chemtech"] = true, ["SRU_Dragon_Earth"] = true, ["SRU_Dragon_Elder"] = true,
        ["SRU_Dragon_Fire"] = true, ["SRU_Dragon_Hextech"] = true, ["SRU_Dragon_Water"] = true,
        ["SRU_Gromp"] = true, ["SRU_Krug"] = true, ["SRU_KrugMini"] = true,
        ["SRU_KrugMiniMini"] = true, ["SRU_Murkwolf"] = true, ["SRU_MurkwolfMini"] = true,
        ["SRU_Plant_Vision"] = true, ["SRU_Razorbeak"] = true, ["SRU_RazorbeakMini"] = true,
        ["SRU_Red"] = true, ["SRU_RiftHerald"] = true
    }
    self.petNames = {
        ["AnnieTibbers"] = true, ["EliseSpiderling"] = true, ["HeimerTBlue"] = true,
        ["HeimerTYellow"] = true, ["IvernMinion"] = true, ["KalistaSpawn"] = true,
        ["MalzaharVoidling"] = true, ["SennaSoul"] = true, ["ShacoBox"] = true,
        ["TeemoMushroom"] = true, ["YorickBigGhoul"] = true, ["YorickGhoulMelee"] = true,
        ["YorickWGhoul"] = true, ["ZyraGraspingPlant"] = true, ["ZyraThornPlant"] = true
    }
    self.resetAttackNames = {
        ["AatroxE"] = true, ["AkshanBasicAttack"] = true, ["AkshanCritAttack"] = true,
        ["AsheQ"] = true, ["PowerFist"] = true, ["CamilleQ"] = true, ["CamilleQ2"] = true,
        ["VorpalSpikes"] = true, ["DariusNoxianTacticsONH"] = true, ["DrMundoE"] = true,
        ["EkkoE"] = true, ["EliseSpiderW"] = true, ["FioraE"] = true, ["FizzW"] = true,
        ["GarenQ"] = true, ["GravesMove"] = true, ["GravesAutoAttackRecoilCastEDummy"] = true,
        ["GwenE"] = true, ["HecarimRamp"] = true, ["IllaoiW"] = true, ["JaxEmpowerTwo"] = true,
        ["JayceHyperCharge"] = true, ["KaisaR"] = true, ["NetherBlade"] = true,
        ["KatarinaEWrapper"] = true, ["KayleE"] = true, ["KindredQ"] = true,
        ["LeonaShieldOfDaybreak"] = true, ["LucianE"] = true, ["Obduracy"] = true,
        ["Meditate"] = true, ["NasusQ"] = true, ["NautilusPiercingGaze"] = true,
        ["Takedown"] = true, ["RekSaiQ"] = true, ["RenektonPreExecute"] = true,
        ["RengarQ"] = true, ["RengarQEmp"] = true, ["RivenTriCleave"] = true,
        ["SejuaniE"] = true, ["SettQ"] = true, ["ShyvanaDoubleAttack"] = true, ["SivirW"] = true,
        ["TalonQ"] = true, ["VayneTumble"] = true, ["TrundleTrollSmash"] = true, ["ViE"] = true,
        ["ViegoW"] = true, ["VolibearQ"] = true, ["MonkeyKingDoubleAttack"] = true,
        ["XinZhaoQ"] = true, ["YorickQ"] = true, ["ZacQ"] = true, ["ZeriE"] = true
    }
    self.apheliosProjectileSpeeds = Linq({
        [1] = {buff = "ApheliosCalibrumManager", speed = 2500},
        [2] = {buff = "ApheliosCrescendumManager", speed = 5000},
        [3] = {buff = "ApheliosInfernumManager", speed = 1500},
        [4] = {buff = "ApheliosGravitumManager", speed = 1500},
        [5] = {buff = "ApheliosSeverumManager", speed = math.huge}
    })
    self.specialProjectileSpeeds = {
        ["Viktor"] = {buff = "ViktorPowerTransferReturn", speed = math.huge},
        ["Zoe"] = {buff = "zoepassivesheenbuff", speed = math.huge},
        ["Caitlyn"] = {buff = "caitlynpassivedriver", speed = 3000},
        ["Jhin"] = {buff = "jhinpassiveattackbuff", speed = 3000},
        ["Jinx"] = {buff = "JinxQ", speed = 2000},
        ["Kayle"] = {buff = "KayleE", speed = 1750},
        ["Neeko"] = {buff = "neekowpassiveready", speed = 3500},
        ["Poppy"] = {buff = "poppypassivebuff", speed = 1600}
    }
    self.undyingBuffs = {
        ["aatroxpassivedeath"] = true, ["FioraW"] = true,
        ["JaxCounterStrike"] = true, ["JudicatorIntervention"] = true,
        ["KarthusDeathDefiedBuff"] = true, ["kindredrnodeathbuff"] = false,
        ["KogMawIcathianSurprise"] = true, ["SamiraW"] = true, ["ShenWBuff"] = true,
        ["TaricR"] = true, ["UndyingRage"] = false, ["VladimirSanguinePool"] = true,
        ["ChronoShift"] = false, ["chronorevive"] = true, ["zhonyasringshield"] = true
    }
end

function Data:CanAttack()
    local name = myHero.champ_name
    local buffs = self.blockAttackBuffs[name]
    if not buffs then return true end
    if myHero:has_buff("gragaswattackbuff") and
        name == "Gragas" then return true end
    return not Linq(buffs):Any(function(b)
        return myHero:has_buff(b) end)
end

function Data:CanOrbwalk()
    if myHero.is_dead then return false end
    local name = myHero.champ_name
    local buffs = self.blockOrbBuffs[name]
    if not buffs then return true end
    return not Linq(buffs):Any(function(b)
        return myHero:has_buff(b) end)
end

function Data:GetAutoAttackRange(unit)
    local unit = unit or myHero
    return unit.attack_range + unit.bounding_radius
end

function Data:GetProjectileSpeed()
    local ranged = not self:IsMelee(myHero)
    local name = myHero.champ_name
    if name == "Aphelios" then
        local data = self.apheliosProjectileSpeeds:First(
            function(a) return myHero:has_buff(a.buff) end)
        if data ~= nil then return data.speed end
    elseif name == "Azir" or name == "Senna" or
        name == "Thresh" or name == "Velkoz" or
        name:find("Melee") then return math.huge
    elseif name == "Kayle" then
        local data = spellbook:get_spell_slot(SLOT_R)
        if data and data.level > 0 then return 5000 end
    elseif name == "Jayce" and ranged then return 2000
    elseif name == "Zeri" and ranged == true and
        spellbook:can_cast(SLOT_Q) then return 2600 end
    local data = self.specialProjectileSpeeds[name]
    if data ~= nil and myHero:has_buff(data.buff) then
        return data.speed
    end
    local data = myHero:get_basic_attack_data()
    local speed = data.missile_speed
    return ranged and speed ~= nil and
        speed > 0 and speed or math.huge
end

function Data:GetSpecialWindup()
    local name = myHero.champ_name
    if name ~= "Jayce" and name ~=
        "TwistedFate" then return nil end
    return Linq(myHero.buffs):Any(function(b) return
        b.is_valid and b.duration > 0 and b.count > 0
        and (b.name == "JayceHyperCharge" or b.name
        :find("CardPreAttack")) end) and 0.125 or nil
end

function Data:IsImmortal(unit)
    return Linq(unit.buffs):Any(function(b)
        if not b.is_valid or b.duration <= 0 or
            b.count <= 0 then return false end
        local buff = self.undyingBuffs[b.name]
        if buff == nil then return false end
        return buff == false and unit.health /
            unit.max_health < 0.05 or buff == true
    end) or unit.is_immortal
end

function Data:IsMelee(unit)
    return unit.is_melee or unit.attack_range < 300
        and self.hybridRange[unit.champ_name] ~= nil
end

function Data:IsValid(unit)
    return unit and unit.is_valid and unit.is_visible
        and unit.is_alive and unit.is_targetable
end

function Data:Latency()
    return game.ping / 1000 + 0.034
end

--------------------
-- Geometry class --

_G.Geometry = Class()

function Geometry:__init() end

function Geometry:AngleBetween(p1, p2, p3)
    local angle = math.deg(
        math.atan(p3.z - p1.z, p3.x - p1.x) -
        math.atan(p2.z - p1.z, p2.x - p1.x))
    if angle < 0 then angle = angle + 360 end
    return angle > 180 and 360 - angle or angle
end

function Geometry:CircleToPolygon(center, radius, steps, offset)
    local result = {}
    for i = 0, steps - 1 do
        local phi = 2 * math.pi / steps * (i + 0.5)
        local cx = center.x + radius * math.cos(phi + offset)
        local cy = center.z + radius * math.sin(phi + offset)
        table.insert(result, vec3.new(cx, center.y, cy))
    end
    return result
end

function Geometry:DrawPolygon(polygon, color, width)
    local size, c, w = #polygon, color, width
    if size < 3 then return end
    for i = 1, size do
        local p1, p2 = polygon[i], polygon[i % size + 1]
        local a = game:world_to_screen(p1.x, p1.y, p1.z)
        local b = game:world_to_screen(p2.x, p2.y, p2.z)
        renderer:draw_line(a.x, a.y, b.x, b.y, w, c.r, c.g, c.b, c.a)
    end
end

function Geometry:Distance(p1, p2)
    return math.sqrt(self:DistanceSqr(p1, p2))
end

function Geometry:DistanceSqr(p1, p2)
    local dx, dy = p2.x - p1.x, p2.z - p1.z
    return dx * dx + dy * dy
end

function Geometry:IsFacing(source, unit)
    local dir = source.direction
    local p1, p2 = source.origin, unit.origin
    local p3 = {x = p1.x + dir.x * 2, z = p1.z + dir.z * 2}
    return self:AngleBetween(p1, p2, p3) < 80
end

function Geometry:IsInAutoAttackRange(unit)
    local range = Data:GetAutoAttackRange()
    if myHero.champ_name == "Aphelios"
        and unit.is_hero and unit:has_buff(
        "aphelioscalibrumbonusrangedebuff")
        then range = 1800
    elseif myHero.champ_name == "Caitlyn"
        and (unit:has_buff("caitlynwsight")
        or unit:has_buff("CaitlynEMissile"))
        then range = range + 425
    elseif myHero.champ_name == "Zeri"
        and spellbook:can_cast(SLOT_Q)
        then range = 800 end
    local p1 = myHero.path.server_pos
    local p2 = unit.path ~= nil and
        unit.path.server_pos or unit.origin
    local hitbox = unit.bounding_radius
    local dist = self:DistanceSqr(p1, p2)
    return dist <= (range + hitbox) ^ 2
end

--------------------------
-- Object Manager class --

local ObjectManager = Class()

function ObjectManager:__init() end

function ObjectManager:GetAllyHeroes(range)
    local pos = myHero.path.server_pos
    return Linq(game.players):Where(function(u)
        return Data:IsValid(u) and not u.is_enemy and
            u.object_id ~= myHero.object_id and range >=
            Geometry:Distance(pos, u.path.server_pos)
    end)
end

function ObjectManager:GetAllyMinions(range)
    local pos = myHero.path.server_pos
    return Linq(game.minions):Where(function(u)
        return Data:IsValid(u) and not u.is_enemy and
            Geometry:Distance(pos, u.origin) <= range
    end)
end

function ObjectManager:GetClosestAllyTurret()
    local turrets = Linq(game.turrets):Where(function(t)
        return Data:IsValid(t) and not t.is_enemy end)
    if #turrets == 0 then return nil end
    local pos = myHero.path.server_pos
    table.sort(turrets, function(a, b) return
        Geometry:DistanceSqr(pos, a.origin) <
        Geometry:DistanceSqr(pos, b.origin) end)
    return turrets[1]
end

function ObjectManager:GetEnemyHeroes(range)
    local pos = myHero.path.server_pos
    return Linq(game.players):Where(function(u)
        return Data:IsValid(u) and u.is_enemy
            and (range and Geometry:Distance(
            pos, u.path.server_pos) <= range
            or Geometry:IsInAutoAttackRange(u))
    end)
end

function ObjectManager:GetEnemyMinions()
    return Linq(game.minions):Where(function(u)
        return Data:IsValid(u) and u.is_enemy
            and Geometry:IsInAutoAttackRange(u)
    end)
end

function ObjectManager:GetEnemyMonsters()
    return Linq(game.jungle_minions):Where(function(u)
        return Data:IsValid(u) and u.is_enemy
            and Geometry:IsInAutoAttackRange(u)
    end)
end

function ObjectManager:GetEnemyPets()
    return Linq(game.pets):Where(function(u)
        return Data:IsValid(u) and u.is_enemy
            and Geometry:IsInAutoAttackRange(u)
    end)
end

function ObjectManager:GetEnemyStructure()
    return Linq(game.nexus):Concat(
        game.inhibs):First(function(t)
        return Data:IsValid(t) and t.is_enemy
            and Geometry:IsInAutoAttackRange(t)
    end)
end

function ObjectManager:GetEnemyTurret()
    return Linq(game.turrets):First(function(t)
        return Data:IsValid(t) and t.is_enemy
            and Geometry:IsInAutoAttackRange(t)
    end)
end

function ObjectManager:GetEnemyWard()
    return Linq(game.wards):First(function(w)
        return Data:IsValid(w) and w.is_enemy
            and Geometry:IsInAutoAttackRange(w)
    end)
end

---------------------------
-- Target Selector class --

local TargetSelector = Class()

function TargetSelector:__init(data)
    self.data = data
    self.priorityList = {
        ["Aatrox"] = 3, ["Ahri"] = 4, ["Akali"] = 4, ["Akshan"] = 5, ["Alistar"] = 1,
        ["Amumu"] = 1, ["Anivia"] = 4, ["Annie"] = 4, ["Aphelios"] = 5, ["Ashe"] = 5,
        ["AurelionSol"] = 4, ["Azir"] = 4, ["Bard"] = 3, ["Blitzcrank"] = 1, ["Brand"] = 4,
        ["Braum"] = 1, ["Caitlyn"] = 5, ["Camille"] = 3, ["Cassiopeia"] = 4, ["Chogath"] = 1,
        ["Corki"] = 5, ["Darius"] = 2, ["Diana"] = 4, ["DrMundo"] = 1, ["Draven"] = 5,
        ["Ekko"] = 4, ["Elise"] = 3, ["Evelynn"] = 4, ["Ezreal"] = 5, ["FiddleSticks"] = 3,
        ["Fiora"] = 3, ["Fizz"] = 4, ["Galio"] = 1, ["Gangplank"] = 4, ["Garen"] = 1,
        ["Gnar"] = 1, ["Gragas"] = 2, ["Graves"] = 4, ["Gwen"] = 3, ["Hecarim"] = 2,
        ["Heimerdinger"] = 3, ["Illaoi"] = 3, ["Irelia"] = 3, ["Ivern"] = 1, ["Janna"] = 2,
        ["JarvanIV"] = 3, ["Jax"] = 3, ["Jayce"] = 4, ["Jhin"] = 5, ["Jinx"] = 5, ["Kaisa"] = 5,
        ["Kalista"] = 5, ["Karma"] = 4, ["Karthus"] = 4, ["Kassadin"] = 4, ["Katarina"] = 4,
        ["Kayle"] = 4, ["Kayn"] = 4, ["Kennen"] = 4, ["Khazix"] = 4, ["Kindred"] = 4,
        ["Kled"] = 2, ["KogMaw"] = 5, ["Leblanc"] = 4, ["LeeSin"] = 3, ["Leona"] = 1,
        ["Lillia"] = 4, ["Lissandra"] = 4, ["Lucian"] = 5, ["Lulu"] = 3, ["Lux"] = 4,
        ["Malphite"] = 1, ["Malzahar"] = 3, ["Maokai"] = 2, ["MasterYi"] = 5,
        ["MissFortune"] = 5, ["MonkeyKing"] = 3, ["Mordekaiser"] = 4, ["Morgana"] = 3,
        ["Nami"] = 3, ["Nasus"] = 2, ["Nautilus"] = 1, ["Neeko"] = 4, ["Nidalee"] = 4,
        ["Nocturne"] = 4, ["Nunu"] = 2, ["Olaf"] = 2, ["Orianna"] = 4, ["Ornn"] = 2,
        ["Pantheon"] = 3, ["Poppy"] = 2, ["Pyke"] = 4, ["Qiyana"] = 4, ["Quinn"] = 5,
        ["Rakan"] = 3, ["Rammus"] = 1, ["RekSai"] = 2, ["Rell"] = 5, ["Renekton"] = 2,
        ["Rengar"] = 4, ["Riven"] = 4, ["Rumble"] = 4, ["Ryze"] = 4, ["Samira"] = 5,
        ["Sejuani"] = 2, ["Senna"] = 5, ["Seraphine"] = 4, ["Sett"] = 2, ["Shaco"] = 4,
        ["Shen"] = 1, ["Shyvana"] = 2, ["Singed"] = 1, ["Sion"] = 1, ["Sivir"] = 5,
        ["Skarner"] = 2, ["Sona"] = 3, ["Soraka"] = 3, ["Swain"] = 3, ["Sylas"] = 4,
        ["Syndra"] = 4, ["TahmKench"] = 1, ["Taliyah"] = 4, ["Talon"] = 4, ["Taric"] = 1,
        ["Teemo"] = 4, ["Thresh"] = 1, ["Tristana"] = 5, ["Trundle"] = 2, ["Tryndamere"] = 4,
        ["TwistedFate"] = 4, ["Twitch"] = 5, ["Udyr"] = 2, ["Urgot"] = 2, ["Varus"] = 5,
        ["Vayne"] = 5, ["Veigar"] = 4, ["Velkoz"] = 4, ["Vex"] = 4, ["Vi"] = 2, ["Viego"] = 4,
        ["Viktor"] = 4, ["Vladimir"] = 3, ["Volibear"] = 2, ["Warwick"] = 2, ["Xayah"] = 5,
        ["Xerath"] = 4, ["Xinzhao"] = 3, ["Yasuo"] = 4, ["Yone"] = 4, ["Yorick"] = 2, ["Yuumi"] = 3,
        ["Zac"] = 1, ["Zed"] = 4, ["Ziggs"] = 4, ["Zilean"] = 3, ["Zoe"] = 4, ["Zyra"] = 2
    }
    self.sortingModes = {
        [1] = function(a, b) -- AUTO_PRIORITY
            local a_dmg = Damage:CalcEffectiveDamage(myHero, a, 100)
            local b_dmg = Damage:CalcEffectiveDamage(myHero, b, 100)
            return a_dmg / (1 + a.health) * self:GetPriority(a)
                > b_dmg / (1 + b.health) * self:GetPriority(b)
        end,
        [2] = function(a, b) -- LESS_ATTACK
            local a_dmg = Damage:CalcPhysicalDamage(myHero, a, 100)
            local b_dmg = Damage:CalcPhysicalDamage(myHero, b, 100)
            return a_dmg / (1 + a.health) * self:GetPriority(a)
                > b_dmg / (1 + b.health) * self:GetPriority(b)
        end,
        [3] = function(a, b) -- LESS_CAST
            local a_dmg = Damage:CalcMagicalDamage(myHero, a, 100)
            local b_dmg = Damage:CalcMagicalDamage(myHero, b, 100)
            return a_dmg / (1 + a.health) * self:GetPriority(a)
                > b_dmg / (1 + b.health) * self:GetPriority(b)
        end,
        [4] = function(a, b) -- MOST_AD
            return Damage:CalcPhysicalDamage(myHero, a)
                > Damage:CalcPhysicalDamage(myHero, b)
        end,
        [5] = function(a, b) -- MOST_AP
            return Damage:CalcMagicalDamage(myHero, a)
                > Damage:CalcMagicalDamage(myHero, b)
        end,
        [6] = function(a, b) -- LOW_HEALTH
            return a.health < b.health
        end,
        [7] = function(a, b) -- CLOSEST
            local pos = myHero.origin
            return Geometry:DistanceSqr(pos, b.origin)
                < Geometry:DistanceSqr(pos, a.origin)
        end,
        [8] = function(a, b) -- NEAR_MOUSE
            local pos = game.mouse_pos
            return Geometry:DistanceSqr(pos, b.origin)
                < Geometry:DistanceSqr(pos, a.origin)
        end
    }
end

function TargetSelector:GetPriority(unit)
    local name = unit.champ_name
    local mod = {1, 1.5, 1.75, 2, 2.5}
    return mod[self.priorityList[name] or 3]
end

function TargetSelector:GetTarget(range, mode)
    local enemies = ObjectManager:GetEnemyHeroes(range):Where(
        function(e) return not self.data:IsImmortal(e) end)
    if #enemies <= 1 then return enemies[1] or nil end
    table.sort(enemies, self.sortingModes[mode or 1])
    return enemies[1]
end

---------------------
-- Orbwalker class --

local Orbwalker = Class()

function Orbwalker:__init()
    self.attackDelay = 0
    self.attackTimer = 0
    self.attackWindup = 0
    self.baseAttackSpeed = 0
    self.baseWindupTime = 0
    self.blockTimer = 0
    self.dashTimer = 0
    self.moveTimer = 0
    self.orbwalkMode = 0
    self.waitTimer = 0
    self.forcedPos = nil
    self.forcedTarget = nil
    self.lastTarget = nil
    self.attacksEnabled = true
    self.canFirePostEvent = true
    self.movementEnabled = true
    self.waitForEvent = false
    self.onBasicAttack = {}
    self.onPostAttack = {}
    self.onPreAttack = {}
    self.onPreMovement = {}
    self.onUnkillable = {}
    self.monsters = Linq()
    self.pets = Linq()
    self.waveMinions = Linq()
    self.damage = Damage:New()
    self.data = Data:New()
    self.geometry = Geometry:New()
    self.objectManager = ObjectManager:New()
    self.targetSelector = TargetSelector:New(self.data)
    self.baseAttackSpeed = 1 / (myHero.attack_delay * myHero.attack_speed)
    self.baseWindupTime = 1 / (myHero.attack_cast_delay * myHero.attack_speed)
    self.gravesDelay = function(delay) return 1.422 * delay - 1.525 end
    self.menu = menu:add_category("Orbwalker v" .. tostring(Version))
    self.main = menu:add_subcategory("Main Settings", self.menu)
    self.b_orbon = menu:add_checkbox("Enable Orbwalking", self.main, 1)
    self.b_reset = menu:add_checkbox("Reset Attacks", self.main, 1, "Resets auto-attack timer when hero casts a specific spell.")
    self.b_support = menu:add_checkbox("Support Mode", self.main, 0, "Turns off last-hits and helps your ally to laneclear faster.")
    self.b_windwall = menu:add_checkbox("Windwall Check", self.main, 0, "Blocks auto-attack if it would collide with windwall.")
    if myHero.champ_name == "Akshan" then self.b_akshan = menu:add_toggle("Use Passive On Hero", 1, self.main, string.byte("N"), true) end
    self.s_anim = menu:add_slider("Extra Animation Time", self.main, 0, 100, 0)
    self.s_windup = menu:add_slider("Extra Windup Time", self.main, 0, 100, 0)
    self.s_hradius = menu:add_slider("Hold Radius", self.main, 50, 150, 75)
    self.farm = menu:add_subcategory("Farm Settings", self.menu)
    self.b_fastclear = menu:add_checkbox("Fast Lane Clear", self.farm, 0, "No longer waits for last-hit and keeps attacking.")
    self.b_stack = menu:add_checkbox("Focus Most Stacked", self.farm, 0, "Attacks minions containing applied stacks as first.")
    self.b_priocn = menu:add_checkbox("Prioritize Cannon Minions", self.farm, 1, "Last-hits a cannon minion first without any condition check.")
    self.b_priolh = menu:add_checkbox("Prioritize Last Hits", self.farm, 0, "Harass mode will focus on last-hit instead of enemy hero.")
    self.s_farm = menu:add_slider("Extra Farm Delay", self.farm, 0, 100, 0, "Defines a delay for last-hit execution.")
    self.keys = menu:add_subcategory("Key Settings", self.menu)
    self.k_combo = menu:add_keybinder("Combo Key", self.keys, string.byte(' '))
    self.k_harass = menu:add_keybinder("Harass Key", self.keys, string.byte('C'))
    self.k_laneclear = menu:add_keybinder("Lane Clear Key", self.keys, string.byte('V'))
    self.k_lasthit = menu:add_keybinder("Last Hit Key", self.keys, string.byte('X'))
    self.k_freeze = menu:add_keybinder("Freeze Key", self.keys, string.byte('A'))
    self.k_flee = menu:add_keybinder("Flee Key", self.keys, string.byte('Z'))
    self.selector = menu:add_subcategory("Selector Settings", self.menu)
    self.b_focus = menu:add_checkbox("Focus Left-Clicked", self.selector, 1)
    self.c_mode = menu:add_combobox("Target Selector Mode", self.selector, {"Auto", "Less Attack",
        "Less Cast", "Most AD", "Most AP", "Low Health", "Closest", "Near Mouse"}, 0)
    self.drawings = menu:add_subcategory("Drawing Settings", self.menu)
    self.b_drawon = menu:add_checkbox("Enable Drawings", self.drawings, 1)
    self.b_indicator = menu:add_checkbox("Draw Damage Indicator", self.drawings, 1, "Draws predicted damage to lane minions.")
    self.b_range = menu:add_checkbox("Draw Player Attack Range", self.drawings, 1, "Draws auto-attack range around your hero.")
    self.color_p = menu:add_subcategory("Player Range Color", self.drawings)
    self.r1 = menu:add_slider("Red Value", self.color_p, 0, 255, 255)
    self.g1 = menu:add_slider("Green Value", self.color_p, 0, 255, 255)
    self.b1 = menu:add_slider("Blue Value", self.color_p, 0, 255, 255)
    self.b_enemy = menu:add_checkbox("Draw Enemy Attack Range", self.drawings, 1, "Draws auto-attack range around enemy.")
    self.color_e = menu:add_subcategory("Enemy Range Color", self.drawings)
    self.r2 = menu:add_slider("Red Value", self.color_e, 0, 255, 255)
    self.g2 = menu:add_slider("Green Value", self.color_e, 0, 255, 255)
    self.b2 = menu:add_slider("Blue Value", self.color_e, 0, 255, 255)
    self.b_markmin = menu:add_checkbox("Mark Lane Minions", self.drawings, 1)
    self.b_marktrg = menu:add_checkbox("Mark Forced Target", self.drawings, 1)
    self.humanizer = menu:add_subcategory("Humanizer Settings", self.menu)
    self.b_humanon = menu:add_checkbox("Enable Humanizer", self.humanizer, 1)
    self.s_min = menu:add_slider("Min Move Delay", self.humanizer, 75, 200, 125)
    self.s_max = menu:add_slider("Max Move Delay", self.humanizer, 75, 200, 175)
    client:set_event_callback("on_tick", function() self:OnTick() end)
    client:set_event_callback("on_draw", function() self:OnDraw() end)
    client:set_event_callback("on_process_spell", function(...) self:OnProcessSpell(...) end)
    client:set_event_callback("on_stop_cast", function(...) self:OnStopCast(...) end)
    client:set_event_callback("on_wnd_proc", function(...) self:OnWndProc(...) end)
end

function Orbwalker:AttackUnit(unit)
    if self:HasAttacked() then return end
    if self.forcedPos then return end
    local args = {target = unit, process = true}
    self:FireOnPreAttack(args)
    if not args.process then return end
    self.lastTarget = unit
    local zeri = myHero.champ_name == "Zeri"
    if zeri and spellbook:can_cast(SLOT_Q) then
        local input = {source = myHero, delay = 0,
            speed = 2600, range = 800, radius = 40, hitbox = true,
            collision = {"minion", "wind_wall"}, type = "linear"}
        local pred = prediction:get_prediction(input, unit)
        if pred.hit_chance <= 0 and unit.is_hero then return end
        pred.pred_pos = pred.pred_pos or unit.path.server_pos
        spellbook:cast_spell(SLOT_Q, 0.1, pred.pred_pos.x,
            pred.pred_pos.y, pred.pred_pos.z) return end
    self.attackTimer = game.game_time
    self.waitForEvent = true
    issueorder:attack_unit(unit)
end

function Orbwalker:CanAttack(delay)
    if self:HasAttacked() then return false end
    if evade:is_evading() then return false end
    local zeri = myHero.champ_name == "Zeri"
    if zeri and spellbook:can_cast(SLOT_Q) and not
        self:IsAutoAttacking(0) then return true end
    local blind = myHero:has_buff_type(26)
    local kalista = myHero.champ_name == "Kalista"
    if not kalista and blind then return false end
    if not self.data:CanOrbwalk() then return false end
    if not self.data:CanAttack() then return false end
    local graves = myHero.champ_name == "Graves"
    local dashElapsed = game.game_time - self.dashTimer
    if not kalista and dashElapsed < 0.2 then return false end
    if graves and not myHero:has_buff("gravesbasicattackammo1")
        or myHero.is_winding_up then return false end
    local extraAnimation = menu:get_value(self.s_anim) * 0.001
    local endTime = self.attackTimer + self:GetAnimationTime()
    return game.game_time >= endTime + extraAnimation + delay
end

function Orbwalker:CanMove(delay)
    if self:HasAttacked() then return false end
    if evade:is_evading() then return false end
    if not self.data:CanOrbwalk() then return false end
    local kalista = myHero.champ_name == "Kalista"
    local kaisa = myHero.champ_name == "Kaisa"
    if kaisa == true and myHero:has_buff("KaisaE")
        or kalista == true then return true end
    local graves = myHero.champ_name == "Graves"
    local dashElapsed = game.game_time - self.dashTimer
    if not kalista and dashElapsed < 0.2 then return false end
    if not graves and myHero.is_winding_up then return false end
    return not self:IsAutoAttacking(delay)
end

function Orbwalker:GetAnimationTime()
    local name = myHero.champ_name
    if name == "Graves" then
        return self.gravesDelay(myHero.attack_delay)
    elseif name == "Jhin" then return self.attackDelay end
    return 1 / (myHero.attack_speed * self.baseAttackSpeed)
end

function Orbwalker:GetTarget(range, mode)
    local target = self.forcedTarget
    if target and self.data:IsValid(target) then
        local heroPos = myHero.path.server_pos
        local targetPos = target.path.server_pos
        if range and self.geometry:DistanceSqr(
            heroPos, targetPos) <= range * range
            or self.geometry:IsInAutoAttackRange(
            target) then return target end
    end
    local mode = mode or (menu:get_value(self.c_mode) + 1)
    return self.targetSelector:GetTarget(range, mode)
end

function Orbwalker:GetWindupTime()
    local windup = self.data:GetSpecialWindup()
    if windup ~= nil then return windup end
    local name = myHero.champ_name
    if name == "Graves" or name == "Jhin"
        then return self.attackWindup end
    return math.max(myHero.attack_cast_delay, 1 /
        (myHero.attack_speed * self.baseWindupTime))
end

function Orbwalker:HasAttacked()
    local latency = self.data:Latency() - 0.034
    return self.waitForEvent and game.game_time -
        self.attackTimer <= math.max(0.1, latency)
end

function Orbwalker:IsAutoAttacking(delay)
    local extraWindup = menu:get_value(self.s_windup) * 0.001
    local endTime = self.attackTimer + self:GetWindupTime()
    return game.game_time < endTime + extraWindup + delay
end

function Orbwalker:IsCollidingWindwall(endPos)
    local speed = self.data:GetProjectileSpeed()
    if speed == math.huge then return false end
    local windup = self:GetWindupTime()
    local input = {source = myHero, speed = speed,
        delay = windup, collision = {"windwall"}}
    return #prediction:get_collision(input, endPos) > 0
end

function Orbwalker:MoveTo()
    if game.game_time < self.moveTimer then return end
    local position = self.forcedPos or game.mouse_pos
    local radius = menu:get_value(self.s_hradius)
    if not self.forcedPos and self.geometry:Distance(
        myHero.origin, position) <= radius then
        issueorder:stop(myHero.origin) return end
    local tmin = menu:get_value(self.s_min)
    local tmax = menu:get_value(self.s_max)
    local delay = menu:get_value(self.b_humanon) == 1
        and math.random(tmin, tmax) * 0.001 or 0.01
    local args = {position = position, process = true}
    self:FireOnPreMovement(args)
    if not args.process then return end
    issueorder:move(position)
    self.moveTimer = game.game_time + delay
    if self.forcedPos then self.forcedPos = nil end
end

function Orbwalker:ShouldWait(mod)
    if support == 1 then return false end
    local wait = self.waveMinions:Any(function(m)
        return m.clearPred - m.damage <= 0 end)
    if wait then self.waitTimer = game.game_time end
    return game.game_time - self.waitTimer <= 0.125
end

function Orbwalker:GetOrbwalkerTarget(mode)
    if not mode or mode == 0 then return nil end
    if mode <= 2 or mode == 3 and self.forcedTarget then
        -- attack the enemy hero or forced target
        local target = self:GetTarget()
        if target ~= nil and (mode >= 1 and mode <= 2
            and target.is_hero or mode == 3 and not
            target.is_hero) then return target end
    end
    local support = menu:get_value(self.b_support)
    if #self.objectManager:GetAllyHeroes(1500) == 0
        and support == 1 then support = 0 end
    if mode >= 2 and mode <= 5 and support == 0 then
        -- last hit a wave minion
        local minions = self.waveMinions:Where(
            function(m) return m.killable end)
        if mode == 5 and #minions > 0 and minions:All(
            function(m) return m.healthPred >= 50 and
            m.freezePred > 0 end) then return nil end
        if #minions > 0 then
            -- prioritize cannon minions
            local prioCannon = menu:get_value(self.b_priocn) == 1
            if prioCannon then table.merge_sort(minions, function(a, b)
                local a_obj, b_obj = a.gameObject, b.gameObject
                local a_siege = a_obj.champ_name:find("Siege")
                local b_siege = b_obj.champ_name:find("Siege")
                return a_siege and not b_siege end) end
            local minion = minions[#minions]
            if prioCannon and minion.gameObject.champ_name:find(
                "Siege") then return minion.gameObject end
            local attacked = self.waveMinions:First(function(m)
                return m.clearPred <= 0 and m.healthPred > 0
                and m.gameObject ~= minion.gameObject end)
            if attacked ~= nil and minion.clearPred > 0 then
                -- two candidates, decide if should last hit or wait
                local killable = attacked.damage > attacked.healthPred
                return killable and attacked.gameObject or nil end
            return minions[1].gameObject
        end
    end
    if mode == 3 then
        -- attack a pet for ex. Annie's Tibbers
        if #self.pets > 0 then return self.pets[1] end
        local fast = menu:get_value(self.b_fastclear)
        local turret = self.objectManager:GetClosestAllyTurret()
        if fast == 0 and turret ~= nil then
            -- under-turret logic
            local turretMinions = self.waveMinions:Where(function(m)
                local obj = m.gameObject; local waypoints = obj.path.waypoints
                local pos = #waypoints == 0 and obj.origin or waypoints[#waypoints]
                return Geometry:DistanceSqr(pos, turret.origin) <= 739600 end)
            for _, m in ipairs(turretMinions) do local unit = m.gameObject
                local damage = prediction:calc_auto_attack_damage(turret, unit)
                if m.healthPred <= m.damage then return nil end
                -- balance minions to make them last-hitable
                if m.healthPred > 3 * damage or unit.health %
                    damage > m.damage then return unit end
            end if #turretMinions > 0 then return nil end
        end
        local shouldWait = self:ShouldWait(support)
        if fast == 0 and shouldWait then return nil end
        -- attack the closest turret
        local turret = self.objectManager:GetEnemyTurret()
        if turret ~= nil then return turret end
        -- attack the closest inhibitor or nexus
        local struct = self.objectManager:GetEnemyStructure()
        if struct ~= nil then return struct end
        -- attack the closest ward
        local ward = self.objectManager:GetEnemyWard()
        if ward ~= nil then return ward end
        -- lane clear the wave minions
        local mod = fast == 1 and 0 or support == 0 and 2 or 3
        local minions = self.waveMinions:Where(function(m)
            return mod == 0 or m.clearPred > mod * m.damage or
            mod == 2 and m.clearPred == m.gameObject.health end)
        if #minions > 0 then
            -- decide which minion we should attack
            local minion = #self.waveMinions == #minions
                and minions[1] or minions[#minions]
            local stack = self.data.buffStackNames[myHero.champ_name]
            if stack and menu:get_value(self.b_stack) == 1 then
                -- choose the most stacked minion
                table.merge_sort(minions, function(a, b)
                    return a.gameObject:has_buff(stack)
                    and not b.gameObject:has_buff(stack)
                end) minion = minions[#minions]
            end
            if minion then return minion.gameObject end
        end
        -- attack a monster with the lowest hp
        return self.monsters[1] or nil
    end
    return nil
end

function Orbwalker:UpdateMinionData()
    local minions = self.objectManager:GetEnemyMinions()
    local monsters = self.objectManager:GetEnemyMonsters()
    local pets = self.objectManager:GetEnemyPets()
    self.monsters = monsters:Where(function(m) return
        self.data.monsterNames[m.champ_name] ~= nil end)
    self.pets = pets:Where(function(p) return
        self.data.petNames[p.champ_name] ~= nil end)
    table.sort(self.monsters, function(a, b)
        return (a.health or 0) < (b.health or 0) end)
    local waveMinions = minions:Where(function(m)
        return m.champ_name:find("Minion") end)
    if #waveMinions == 0 then
        self.waveMinions = Linq() return end
    local canMove = self:CanMove(0.034)
    local canAttack = self:CanAttack(0)
    local pos = myHero.path.server_pos
    local latency = self.data:Latency() - 0.034
    local waitTime = self:GetAnimationTime() * 2
    local speed = self.data:GetProjectileSpeed()
    local delay = menu:get_value(self.s_farm) * 0.001
    local windup = self:GetWindupTime() + latency * 0.5
    self.waveMinions = waveMinions:Select(function(m)
        local damage = self.damage:CalcAutoAttackDamage(myHero, m)
        local timeToHit = self.geometry:Distance(pos, m.origin) / speed + windup
        local clearPred = prediction:get_lane_clear_health_prediction(m, waitTime)
        local freezePred = prediction:get_health_prediction(m, timeToHit + 1)
        local healthPred = prediction:get_health_prediction(m, timeToHit, delay)
        local killPred = prediction:get_health_prediction(m, timeToHit - latency)
        if canMove and not canAttack and killPred <= 0 then self:FireOnUnkillable(m) end
        local killable = killPred > 0 and m.health > 0 and healthPred <= damage
        return {damage = damage, gameObject = m, killable = killable, timeToHit = timeToHit,
            clearPred = clearPred, freezePred = freezePred, healthPred = healthPred}
    end)
    table.sort(self.waveMinions, function(a, b)
        local a_obj, b_obj = a.gameObject, b.gameObject
        local a_siege = a_obj.champ_name:find("Siege")
        local b_siege = b_obj.champ_name:find("Siege")
        local a_hp, b_hp = a.healthPred, b.healthPred
        return not a_siege and b_siege or a_siege ==
            b_siege and a_hp < b_hp or a_hp == b_hp
            and a_obj.max_health > b_obj.max_health
    end)
end

-- Delegates

function Orbwalker:FireOnBasicAttack(target)
    for i = 1, #self.onBasicAttack do
        self.onBasicAttack[i](target) end
end

function Orbwalker:FireOnPostAttack(target)
    for i = 1, #self.onPostAttack do
        self.onPostAttack[i](target) end
end

function Orbwalker:FireOnPreAttack(args)
    for i = 1, #self.onPreAttack do
        self.onPreAttack[i](args) end
end

function Orbwalker:FireOnPreMovement(args)
    for i = 1, #self.onPreMovement do
        self.onPreMovement[i](args) end
end

function Orbwalker:FireOnUnkillable(minion)
    for i = 1, #self.onUnkillable do
        self.onUnkillable[i](minion) end
end

function Orbwalker:OnBasicAttack(func)
    table.insert(self.onBasicAttack, func)
end

function Orbwalker:OnPostAttack(func)
    table.insert(self.onPostAttack, func)
end

function Orbwalker:OnPreAttack(func)
    table.insert(self.onPreAttack, func)
end

function Orbwalker:OnPreMovement(func)
    table.insert(self.onPreMovement, func)
end

function Orbwalker:OnUnkillableMinion(func)
    table.insert(self.onUnkillable, func)
end

-- Events

function Orbwalker:OnTick()
    self:UpdateMinionData()
    if myHero.path.is_dashing then
        self.dashTimer = game.game_time end
    if self.canFirePostEvent and game.game_time >=
        self.attackTimer + self:GetWindupTime() then
        self:FireOnPostAttack(self.lastTarget)
        self.canFirePostEvent = false
    end
    if self.forcedTarget ~= nil and not
        self.data:IsValid(self.forcedTarget)
        then self.forcedTarget = nil end
    selector:set_focus_target(self.forcedTarget
        and self.forcedTarget.object_id or 0)
    if menu:get_value(self.b_orbon) == 0 then return end
    local combo = menu:get_value(self.k_combo)
    local harass = menu:get_value(self.k_harass)
    local laneClear = menu:get_value(self.k_laneclear)
    local lastHit = menu:get_value(self.k_lasthit)
    local freeze = menu:get_value(self.k_freeze)
    local flee = menu:get_value(self.k_flee)
    local mode = game:is_key_down(combo) and 1
        or game:is_key_down(harass) and 2
        or game:is_key_down(laneClear) and 3
        or game:is_key_down(lastHit) and 4
        or game:is_key_down(freeze) and 5
        or game:is_key_down(flee) and 6 or nil
    self.orbwalkMode = mode or 0
    client:set_mode(self.orbwalkMode)
    if game.game_time > self.blockTimer and
        self.attacksEnabled and self:CanAttack(0) then
        local target = self:GetOrbwalkerTarget(mode)
        if target and not (menu:get_value(self.b_windwall) == 1
            and self:IsCollidingWindwall(target.origin)) then
            self.waitTimer = 0; self:AttackUnit(target)
        end
    end
    if mode and self.movementEnabled and
        self:CanMove(0) then self:MoveTo() end
end

function Orbwalker:OnDraw()
    if menu:get_value(self.b_drawon) == 0 then return end
    if menu:get_value(self.b_range) == 1 then
        local range = self.data:GetAutoAttackRange()
        local pos, r = myHero.origin, menu:get_value(self.r1)
        local g, b = menu:get_value(self.g1), menu:get_value(self.b1)
        renderer:draw_circle(pos.x, pos.y, pos.z, range, r, g, b, 128)
    end
    if menu:get_value(self.b_enemy) == 1 then
        Linq(game.players):Where(function(u) return
            self.data:IsValid(u) and u.is_enemy end):ForEach(function(u)
            local range = self.data:GetAutoAttackRange(u)
            local pos, r = u.origin, menu:get_value(self.r2)
            local g, b = menu:get_value(self.g2), menu:get_value(self.b2)
            renderer:draw_circle(pos.x, pos.y, pos.z, range, r, g, b, 128)
        end)
    end
    self.waveMinions:Concat({self.forcedTarget}):ForEach(function(m)
        local o = m and m.gameObject or m; local bar = o and o.health_bar
        if not bar or not bar.is_on_screen then return end
        -- animated drawings <3
        local minion, hero = o.is_minion, o.is_hero
        if minion and menu:get_value(self.b_markmin) == 1 or
            hero and menu:get_value(self.b_marktrg) == 1 then
            local elapsed = math.rad((game.game_time % 5) * 72)
            local points = self.geometry:CircleToPolygon(
                o.origin, o.bounding_radius + 50, 5, elapsed)
            local color = {r = 255, g = 235, b = 140, a = 128}
            if minion then
                color = m.damage >= m.healthPred and
                {r = 255, g = 85, b = 85, a = 128}
                or m.clearPred - m.damage <= 0
                and m.clearPred ~= o.health and
                {r = 255, g = 215, b = 0, a = 128} or
                {r = 255, g = 255, b = 255, a = 128}
            end
            self.geometry:DrawPolygon(points, color, 2)
        end
        -- HP bar total damage split overlay
        local drawIndicator = menu:get_value(self.b_indicator) == 1
        if not drawIndicator or not m.healthPred then return end
        local pos = {x = bar.pos.x - 31, y = bar.pos.y - 5}
        local isSuper = o.champ_name:find("Super")
        if isSuper then pos.x = pos.x - 15 end
        local origin = {x = pos.x, y = pos.y}
        local width = isSuper and 90 or 60
        local maxHealth, health = o.max_health, o.health
        local ratio = width * m.damage / maxHealth
        local start = pos.x + width * health / maxHealth
        for step = 1, math.floor(health / m.damage) do
            pos.x = math.floor(start - ratio * step + 0.5)
            if pos.x > origin.x and pos.x < origin.x + width then
                renderer:draw_line(pos.x, pos.y, pos.x,
                    pos.y + 4, 2, 16, 16, 16, 255)
            end
        end
    end)
end

function Orbwalker:OnProcessSpell(unit, args)
    if unit.object_id ~= myHero.object_id then return end
    local reset = self.data.resetAttackNames[args.spell_name]
    local canReset = menu:get_value(self.b_reset) == 1
    local isAkshan = myHero.champ_name == "Akshan"
    if reset ~= nil and canReset and (isAkshan
        and menu:get_toggle_state(self.b_akshan) and
        self.lastTarget and self.lastTarget.is_hero or
        not isAkshan) then self.attackTimer = 0 return end
    if not args.is_autoattack then return end
    self.attackTimer = game.game_time - self.data:Latency()
    self.canFirePostEvent, self.waitForEvent = true, false
    self.attackWindup = myHero.attack_cast_delay
    self.attackDelay = myHero.attack_delay
    if not args.target then return end
    self.lastTarget = args.target
    self:FireOnBasicAttack(self.lastTarget)
end

function Orbwalker:OnStopCast(unit, args)
    if unit.object_id ~= myHero.object_id
        or not args.stop_animation or not
        args.destroy_missile then return end
    self.blockTimer = game.game_time + 0.125
    issueorder:stop(myHero.path.server_pos)
    self.attackTimer = 0
end

function Orbwalker:OnWndProc(msg, wparam)
    if menu:get_value(self.b_focus) == 0
        or msg ~= 514 or wparam ~= 0 or
        game.is_shop_opened then return end
    local mousePos = game.mouse_pos
    local target = Linq(game.players):First(
        function(u) return self.data:IsValid(u) and
        u.is_enemy and self.geometry:DistanceSqr(
        game.mouse_pos, u.origin) <= 10000 end)
    self.forcedTarget = target or nil
end

local orb = Orbwalker:New()
console:log("[Orbwalker] Successfully loaded!")
AutoUpdate()

_G.orbwalker = {
    attack_target = function(self, unit) orb:AttackUnit(unit) end,
    can_attack = function(self, delay) return orb:CanAttack(delay or 0) end,
    can_move = function(self, delay) return orb:CanMove(delay or 0) end,
    disable_auto_attacks = function(self) orb.attacksEnabled = false end,
    disable_move = function(self) orb.movementEnabled = false end,
    enable_auto_attacks = function(self) orb.attacksEnabled = true end,
    enable_move = function(self) orb.movementEnabled = true end,
    force_target = function(self, target) orb.forcedTarget = target end,
    get_animation_time = function(self) return orb:GetAnimationTime() end,
    get_auto_attack_range = function(self, unit) return orb.data:GetAutoAttackRange(unit) end,
    get_orbwalker_target = function(self) return orb.lastTarget end,
    get_projectile_speed = function(self) return orb.data:GetProjectileSpeed() end,
    get_target = function(self, range) return orb:GetTarget(range, mode) end,
    get_windup_time = function(self) return orb:GetWindupTime() end,
    is_auto_attacking = function(self) return not orb:IsAutoAttacking(0) end,
    is_auto_attack_enabled = function(self) return orb.attacksEnabled end,
    is_movement_enabled = function(self) return orb.movementEnabled end,
    move_to = function(self, x, y, z) orb.forcedPos = x and y
        and z and vec3.new(x, y, z) or game.mouse_pos end,
    on_basic_attack = function(self, func) orb:OnBasicAttack(func) end,
    on_post_attack = function(self, func) orb:OnPostAttack(func) end,
    on_pre_attack = function(self, func) orb:OnPreAttack(func) end,
    on_pre_movement = function(self, func) orb:OnPreMovement(func) end,
    on_unkillable_minion = function(self, func) orb:OnUnkillableMinion(func) end,
    reset_aa = function(self) orb.attackTimer = 0 end
}

_G.combo = {
    get_mode = function(self)
        return ({[0] = MODE_NONE, [1] = MODE_COMBO,
            [2] = MODE_HARASS, [3] = MODE_LANECLEAR,
            [4] = MODE_LASTHIT, [5] = MODE_FREEZE,
            [6] = MODE_FLEE})[orb.orbwalkMode]
    end
}
