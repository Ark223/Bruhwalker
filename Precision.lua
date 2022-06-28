
--[[

    ,------.                     ,--.       ,--.                
    |  .--. ',--.--. ,---.  ,---.`--' ,---. `--' ,---. ,--,--,  
    |  '--' ||  .--'| .-. :| .--',--.(  .-' ,--.| .-. ||      \ 
    |  | --' |  |   \   --.\ `--.|  |.-'  `)|  |' '-' '|  ||  | 
    `--'     `--'    `----' `---'`--'`----' `--' `---' `--''--' 

    Uncle Ark <3

--]]

local Version = 0.04
local Url = "https://raw.githubusercontent.com/Ark223/Bruhwalker/main/"

local function AutoUpdate()
    local result = http:get(Url .. "Precision.version")
    if result and result ~= "" and tonumber(result) > Version then
        http:download_file(Url .. "Precision.lua", "Precision.lua")
        console:log("[Precision] Successfully updated. Please reload!")
        return true
    end
    return false
end

local Class = function(...)
    local cls = {}
    cls.__index = cls
    function cls:New(...)
        local instance = setmetatable({}, cls)
        cls.__init(instance, ...)
        return instance
    end
    cls.__call = function(_, ...) return cls:New(...) end
    return setmetatable(cls, {__call = cls.__call})
end

local pred = _G.Prediction
local myHero = game.local_player
local EC = require "EvadeCore"
local Line = EC.Line
local Linq = EC.Linq
local Vector = EC.Vector

local function CalcMagicalDamage(source, unit, amount, time)
    local mr, time = unit.mr or 0, time or 0
    local amount = amount + unit.health_regen * time
    local magicPen = source.percent_magic_penetration
    local flatPen = source.flat_magic_penetration
    local magicRes = mr * magicPen - flatPen
    local value = mr < 0 and 2 - 100 / (100 - mr) or
        magicRes < 0 and 1 or (100 / (100 + magicRes))
    return math.max(0, math.floor(amount * value))
end

local function CalcPhysicalDamage(source, unit, amount, time)
    local armor, time = unit.armor or 0, time or 0
    local amount = amount + unit.health_regen * time
    local armorPen = source.percent_armor_penetration
    local bonusPen = source.percent_bonus_armor_penetration
    local scaling = 0.6 + 0.4 * source.level / 18
    local lethality = source.lethality * scaling
    local bonus = unit.bonus_armor * (1 - bonusPen)
    local armorRes = armor * armorPen - bonus - lethality
    local value = armor < 0 and 2 - 100 / (100 - armor)
        or armorRes < 0 and 1 or 100 / (100 + armorRes)
    return math.max(0, math.floor(amount * value))
end

local function CollisionTime(startPos, endPos, obstacle, speed, hitbox)
    local dir = endPos - startPos
    local vel = dir:Normalize() * speed
    local dir = startPos - obstacle
    local a = vel:LengthSquared()
    local b = 2 * dir:DotProduct(vel)
    local c = dir:LengthSquared() - hitbox ^ 2
    local delta = b * b - 4 * a * c
    if delta < 0 then return nil end
    local delta = math.sqrt(delta)
    local t1 = (-b - delta) / (2 * a)
    local t2 = (-b + delta) / (2 * a)
    return math.max(0, math.min(t1, t2))
end

local function ClosestCollision(units, skillshot)
    local closest = {pos = nil, time = math.huge}
    local speed = skillshot.speed or 1450
    closest.time = skillshot.range / speed
    local startPos = skillshot.startPos
    local endPos = skillshot.endPos
    local delay = skillshot.preDelay
    local radius = skillshot.radius
    for _, unit in ipairs(units) do
        local output = pred:get_fast_prediction(
            startPos, unit, speed, delay, true)
        local time = CollisionTime(startPos, endPos, Vector:New(
            output), speed, radius + unit.bounding_radius + 10)
        if time ~= nil and time >= 0 and time < closest.time then
            closest.pos = startPos:Extend(endPos, speed * time)
            closest.time = time
        end
    end
    return closest.pos
end

local function DrawDamageOverBar(unit, amount)
    local health = unit.health or 0
    if health <= 0 then return end
    local bar = unit.health_bar
    if not bar.is_on_screen then return end
    local amount = math.min(amount, health)
    local percent = amount / unit.max_health
    local x, y = bar.pos.x - 45, bar.pos.y - 24
    local width, height = 105, 11
    local max = math.floor(percent * width)
    renderer:draw_rect_fill(x, y, x + max,
        y, x, y + height, x + max, y +
        height, 255, 165, 0, 255)
    local step = width * 100 / health
    for i = 1, math.floor(amount / 100) do
        local tx = math.floor(x + step)
        renderer:draw_line(tx, y - 1,
            tx, y + 6, 1, 0, 0, 0, 255)
        x = x + step
    end
end

local function GetMinions(range)
    local heroPos = Vector:New(myHero.origin)
    return Linq(game.minions):Where(function(m) return
        m.is_valid and m.champ_name:find("Minion") end)
        :Concat(game.jungle_minions):Where(function(m)
        return m.is_valid and m.is_enemy and m.is_alive
        and m.is_visible and heroPos:DistanceSquared(
        Vector:New(m.origin)) <= range * range end)
end

---------------------------------
---------- Damage Data ----------

local Damage = {
    ["Jayce"] = {
        ['Q'] = function(unit, stance)
            if stance == "Hammer" then
                local level = spellbook:get_spell_slot(SLOT_Q).level
                local base = ({55, 95, 135, 175, 215, 255})[level]
                local amount = base + 1.2 * myHero.bonus_attack_damage
                return CalcPhysicalDamage(myHero, unit, amount, 0.5)
            elseif stance == "Cannon" then
                if spellbook:can_cast(SLOT_E) then
                    local level = spellbook:get_spell_slot(SLOT_Q).level
                    local base = ({77, 154, 231, 308, 385, 462})[level]
                    local amount = base + 1.68 * myHero.bonus_attack_damage
                    return CalcPhysicalDamage(myHero, unit, amount, 0.2143)
                else
                    local level = spellbook:get_spell_slot(SLOT_Q).level
                    local base = ({55, 110, 165, 220, 275, 330})[level]
                    local amount = base + 1.2 * myHero.bonus_attack_damage
                    return CalcPhysicalDamage(myHero, unit, amount, 0.2143)
                end
            end
        end,
        ['W'] = function(unit, stance)
            if stance == "Cannon" then return 0 end
            local level = spellbook:get_spell_slot(SLOT_W).level
            local base = ({25, 40, 55, 70, 85, 100})[level]
            local amount = base + 0.25 * myHero.ability_power
            return CalcMagicalDamage(myHero, unit, amount * 4)
        end,
        ['E'] = function(unit, stance)
            if stance == "Cannon" then return 0 end
            local level = spellbook:get_spell_slot(SLOT_E).level
            local base = ({8, 10.4, 12.8, 15.2, 17.6, 20})[level]
            local amount = base * 0.01 * unit.max_health
            amount = amount + myHero.bonus_attack_damage
            return CalcMagicalDamage(myHero, unit, amount, 0.25)
        end
    }
}

---------------------------------
------------- Jayce -------------

local Jayce = Class()

function Jayce:__init()
    -- Variables
    self.x = 0
    self.y = 0
    self.offsetX = 0
    self.offsetY = 0
    self.blockTimer = 0
    self.burstReqTimer = 0
    self.delayTimer = 0
    self.chargeTimer = 0
    self.comboMode = "Poke"
    self.hypercharged = false
    self.skillshot = nil
    self.data = {['H'] = {}, ['C'] = {}}
    self.drag = {point = nil, process = false}
    self.icons = os.getenv('APPDATA'):gsub("Roaming",
        "Local\\leaguesense\\spell_sprites\\")
    self.dataQ = {source = myHero, collision = {"wind_wall"},
        speed = 1450, range = 1050, delay = 0.2143, 
        radius = 70, type = "linear", hitbox = true}

    -- menu
    self.menu = menu:add_category_sprite("[Precision] Jayce", self.icons .. "Jayce.png")
    self.label1 = menu:add_label("Main", self.menu)
    self.switchKey = menu:add_keybinder("Combo Switch Key", self.menu, string.byte('A'))
    self.fleeKey = menu:add_keybinder("Flee Mode Key", self.menu, string.byte('Z'))
    self.hopKey = menu:add_keybinder("Wall Hop Key", self.menu, string.byte('C'))
    self.label2 = menu:add_label("Drawings", self.menu)
    self.rangeQ = menu:add_checkbox("Draw Q Range", self.menu, 1)
    self.predDmg = menu:add_checkbox("Draw Spell Damage", self.menu, 1)

    -- spell data and icons
    for _, slot in ipairs({'Q', 'W', 'E', 'R'}) do
        self.data['H'][slot] = {endTime = 0, sprite = nil}
        self.data['C'][slot] = {endTime = 0, sprite = nil}
    end
    self.names = {"JayceToTheSkies.png", "JayceStaticField.png",
        "JayceThunderingBlow.png", "JayceStanceHtG.png", "JayceShockBlast.png",
        "JayceHyperCharge.png", "JayceAccelerationGate.png", "JayceStanceGtH.png"}
    self.data['H']['Q'].sprite = renderer:add_sprite(self.icons .. self.names[1], 32, 32)
    self.data['H']['W'].sprite = renderer:add_sprite(self.icons .. self.names[2], 32, 32)
    self.data['H']['E'].sprite = renderer:add_sprite(self.icons .. self.names[3], 32, 32)
    self.data['H']['R'].sprite = renderer:add_sprite(self.icons .. self.names[4], 32, 32)
    self.data['C']['Q'].sprite = renderer:add_sprite(self.icons .. self.names[5], 32, 32)
    self.data['C']['W'].sprite = renderer:add_sprite(self.icons .. self.names[6], 32, 32)
    self.data['C']['E'].sprite = renderer:add_sprite(self.icons .. self.names[7], 32, 32)
    self.data['C']['R'].sprite = renderer:add_sprite(self.icons .. self.names[8], 32, 32)

    -- events
    _G.orbwalker:on_pre_attack(function(...) self:OnPreAttack(...) end)
    _G.orbwalker:on_post_attack(function(...) self:OnPostAttack(...) end)
    client:set_event_callback("on_tick", function() return self:OnTick() end)
    client:set_event_callback("on_draw", function() return self:OnDraw() end)
    client:set_event_callback("on_wnd_proc", function(...) return self:OnWndProc(...) end)
    client:set_event_callback("on_object_deleted", function(...) return self:OnObjectDeleted(...) end)
    client:set_event_callback("on_process_spell", function(...) return self:OnProcessSpell(...) end)
end

function Jayce:Converter(name)
    return ({
        ["JayceToTheSkies"] = {SLOT_Q, 'H', 'Q', 0},
        ["JayceStaticField"] = {SLOT_W, 'H', 'W', 0},
        ["JayceThunderingBlow"] = {SLOT_E, 'H', 'E', 0.25},
        ["JayceStanceHtG"] = {SLOT_R, 'H', 'R', 0},
        ["JayceShockBlast"] = {SLOT_Q, 'C', 'Q', 0.2143},
        ["JayceHyperCharge"] = {SLOT_W, 'C', 'W', 0},
        ["JayceAccelerationGate"] = {SLOT_E, 'C', 'E', 0},
        ["JayceStanceGtH"] = {SLOT_R, 'C', 'R', 0}
    })[name]
end

function Jayce:BlowLogic(ks)
    local heroPos = Vector:New(myHero.origin)
    local target = orbwalker:get_target(340)
    local eready = spellbook:can_cast(SLOT_E)
    local hammer = self:Stance() == "Hammer"
    if not (target and eready and hammer) then return end
    local pos = Vector:New(target.path.server_pos)
    local damage = Damage["Jayce"]['E'](target, "Hammer")
    local canCast = not ks or ks and target.health <= damage
    if heroPos:Distance(pos) > 240 + target.bounding_radius +
        myHero.bounding_radius or not canCast then return end
    spellbook:cast_spell_targetted(SLOT_E, target, 0.25)
end

function Jayce:Stance()
    local slot = myHero:get_spell_slot(SLOT_W)
    local name = slot.spell_data.spell_name
    local hyper = name == "JayceHyperCharge"
    local caster = myHero.attack_range > 300
    return (hyper or caster) and "Cannon" or "Hammer"
end

function Jayce:OnPreAttack(args)
    if game.game_time - self.burstReqTimer < 0.05 and
        self.hypercharged then args.process = false end
end

function Jayce:OnPostAttack(target)
    if not target or not (target.is_hero
        or target.is_inhib or target.is_nexus
        or target.is_turret) then return end
    if self:Stance() ~= "Cannon" then return end
    if not spellbook:can_cast(SLOT_W) then return end
    client:delay_action(function()
        spellbook:cast_spell(SLOT_W)
        self.chargeTimer = game.game_time
        self.hypercharged = true end, 0)
end

function Jayce:OnWndProc(msg, wparam)
    local elapsed = game.game_time - self.delayTimer
    if elapsed < 0.25 then return end
    -- combo mode switch
    local key = menu:get_value(self.switchKey)
    if game:is_key_down(key) and msg == 256 then
        self.comboMode = self.comboMode ==
            "Burst" and "Poke" or "Burst"
        self.delayTimer = game.game_time
    end
    -- drag bar with cooldowns
    local cursor = game.mouse_2d
    if not self.drag.process and
        msg == 513 and wparam == 1 and
        cursor.x >= self.x and cursor.y >=
        self.y and cursor.x <= self.x + 133
        and cursor.y <= self.y + 34 then
        self.drag.point = cursor
        self.drag.process = true
    elseif msg == 514 and wparam == 0 then
        self.drag.process = false
    end
end

function Jayce:OnObjectDeleted(obj)
    if self.skillshot ~= nil and
        obj.object_name:find("Jayce") and
        obj.object_name:find("_Q_range_xp")
        then self.skillshot = nil end
end

function Jayce:OnProcessSpell(unit, args)
    if unit.object_id ~= myHero.object_id or
        args.is_autoattack then return end
    local name = args.spell_name
    local isSpell = name:find("Jayce")
    if not isSpell then return end
    local data = self:Converter(name)
    local spell = myHero:get_spell_slot(data[1])
    client:delay_action(function()
        local cooldown = spell.cooldown - data[4]
        local endTime = game.game_time + cooldown
        local form, slot = data[2], data[3]
        local data = self.data[form][slot]
        data.endTime = endTime
    end, data[4])
end

function Jayce:OnTick()
    local heroPos = Vector:New(myHero.origin)
    -- fix hyper charge spell cooldown
    local buff = "JayceHyperCharge"
    local charged = myHero:has_buff(buff)
    if not self.hypercharged and charged then
        self.chargeTimer = game.game_time
        self.hypercharged = true
    elseif self.hypercharged and not charged then
        local elapsed = game.game_time - self.chargeTimer
        local endTime = self.data['C']['W'].endTime
        self.data['C']['W'].endTime = endTime + elapsed
        self.hypercharged = false
    end
    -- gather spell states and stance
    if evade:is_evading() then return end
    local qready = spellbook:can_cast(SLOT_Q)
    local wready = spellbook:can_cast(SLOT_W)
    local eready = spellbook:can_cast(SLOT_E)
    local rready = spellbook:can_cast(SLOT_R)
    local stance = self:Stance()
    -- wall hop logic
    local key = menu:get_value(self.hopKey)
    if key and game:is_key_down(key) then
        local mousePos = Vector:New(game.mouse_pos)
        local minion = GetMinions(600):First(function(m)
            return 60 > math.deg(heroPos:AngleBetween(
            Vector:New(m.origin), mousePos, true)) end)
        if minion ~= nil and stance == "Hammer" and qready then
            spellbook:cast_spell_targetted(SLOT_Q, minion, 0.25)
        elseif minion == nil and stance == "Cannon" and eready then
            local direction = (mousePos - heroPos):Normalize()
            local pos = heroPos + direction * 100
            if nav_mesh:is_wall(pos.x, 64, pos.y) then
                local pos = heroPos + direction * 650
                spellbook:cast_spell(SLOT_E, 0.25,
                    pos.x, myHero.origin.y, pos.y) end
        elseif rready == true and (minion ~= nil and
            stance == "Cannon" or stance == "Hammer")
            then spellbook:cast_spell(SLOT_R) end
    end
    -- flee logic
    local key = menu:get_value(self.fleeKey)
    if key and game:is_key_down(key) then
        if eready == true then
            if stance == "Hammer" then self:BlowLogic()
            else spellbook:cast_spell(SLOT_E, 0.25,
                heroPos.x, myHero.origin.y, heroPos.y) end
        elseif rready then spellbook:cast_spell(SLOT_R) end
        if qready == true and stance == "Hammer" then
            local minions = GetMinions(600)
            if #minions == 0 then return end
            table.sort(minions, function(a, b)
                local p1 = Vector:New(a.origin)
                local p2 = Vector:New(b.origin)
                return heroPos:DistanceSquared(p1) >
                    heroPos:DistanceSquared(p2) end)
            local pos = Vector:New(minions[1].origin)
            local mousePos = Vector:New(game.mouse_pos)
            local d1 = heroPos:DistanceSquared(pos)
            local d2 = mousePos:DistanceSquared(pos)
            if d1 < 90000 or d2 > 62500 then return end
            spellbook:cast_spell_targetted(
                SLOT_Q, minions[1], 0.25)
        end
    end
    -- combo logic
    local mode = combo:get_mode()
    if mode ~= MODE_COMBO then return end
    local attacking = myHero.is_auto_attacking
    if stance == "Cannon" then
        if eready and self.skillshot then
            self.skillshot:Update()
            local pos = self.skillshot.position
            local dir = self.skillshot.direction
            local castPos = pos + dir * 100
            if castPos:Distance(heroPos) <= 650 then
                spellbook:cast_spell(SLOT_E, 0.25, castPos.x,
                    myHero.origin.y or 65, castPos.y) end
        end
        local mana = ({55, 60, 65, 70, 75, 80})[qready
            and myHero:get_spell_slot(SLOT_Q).level or 1]
        local gated = eready and myHero.mana >= mana + 50
        self.dataQ.range = gated and 1600 or 1050
        local range = self.dataQ.range + 150
        local target = orbwalker:get_target(range)
        if qready and target ~= nil and
            game.game_time - self.blockTimer > 0.1 then
            if not gated and attacking then return end
            self.dataQ.speed = gated and 2350 or 1450
            self.dataQ.delay = 0.2143 + (gated and 0.034 or 0)
            local output = pred:get_prediction(self.dataQ, target)
            if output.cast_pos and output.hit_chance > 0.3 then
                local blastRadius = gated and 250 or 175
                local destPos = Vector:New(output.cast_pos)
                local predPos = Vector:New(output.pred_pos)
                self.skillshot = Line:New({arcStep = 10,
                    extraDuration = 0, preDelay = self.dataQ.delay,
                    radius = self.dataQ.radius, range = self.dataQ.range,
                    speed = self.dataQ.speed, fixedRange = true,
                    hitbox = true, startTime = game.game_time,
                    destPos = destPos, startPos = heroPos})
                local cols = ClosestCollision(GetMinions(
                    self.dataQ.range + 500), self.skillshot)
                if not cols or cols and cols:DistanceSquared(
                    predPos) <= blastRadius * blastRadius then
                    local castPos = heroPos:Extend(destPos, 500)
                    spellbook:cast_spell(SLOT_Q, 0.25, castPos.x,
                        target.origin.y or 65, castPos.y)
                    self.blockTimer = game.game_time return
                end self.skillshot = nil
            end
        end
        -- if Q spell is ready and enemy is in range, the exception might
        -- have happened that made script not launching it.. collision?
        -- however.. if enemy is too close we need to switch into hammer stance
        if game.game_time - self.blockTimer <= 0.1 then return end
        local target = orbwalker:get_target(myHero.attack_range + 150)
        if target and heroPos:Distance(Vector:New(target.origin))
            <= myHero.bounding_radius + target.bounding_radius
            + 125 then spellbook:cast_spell(SLOT_R) return end
        -- end here if we dont go for a burrrrrrst!
        if self.comboMode ~= "Burst" then return end
        self.burstReqTimer = game.game_time
        local target = orbwalker:get_target(600)
        local endTime = self.data['H']['Q'].endTime
        if target and myHero.mana >= 40 and not wready
            and rready and game.game_time >= endTime
            then spellbook:cast_spell(SLOT_R) end
    elseif stance == "Hammer" then
        if attacking == true then return end
        if qready and self.comboMode == "Burst" then
            local target = orbwalker:get_target(600) or nil
            if target then spellbook:cast_spell_targetted(
                SLOT_Q, target, 0.25) return end
        end
        if wready == true then
            local target = orbwalker:get_target(350) or nil
            if target then spellbook:cast_spell(SLOT_W) end
        end
        -- killsteal with hammer E
        if eready == true then self:BlowLogic(true) end
        -- switch to cannon stance if enemy is out of range
        local target = orbwalker:get_target(125 + 65 + 65)
        if not target and rready then spellbook:cast_spell(SLOT_R) end
    end
end

function Jayce:OnDraw()
    local stance = self:Stance()
    local qready = spellbook:can_cast(SLOT_Q)
    local wready = spellbook:can_cast(SLOT_W)
    local eready = spellbook:can_cast(SLOT_E)
    local heroPos = Vector:New(myHero.origin)
    -- draw damage over enemy hp bar
    if menu:get_value(self.predDmg) == 1 then
        for _, unit in ipairs(game.players) do
            if unit.is_valid and unit.is_visible
                and unit.is_enemy and unit.is_alive and not
                unit.is_immortal and heroPos:DistanceSquared(
                Vector:New(unit.origin)) <= 2560000 then
                local amount = 0
                if qready == true then amount = amount +
                    Damage["Jayce"]['Q'](unit, stance) end
                if wready == true then amount = amount +
                    Damage["Jayce"]['W'](unit, stance) end
                if eready == true then amount = amount +
                    Damage["Jayce"]['E'](unit, stance) end
                DrawDamageOverBar(unit, amount)
            end
        end
    end
    -- draw combo mode
    local heroPos = myHero.origin
    local pos = game:world_to_screen(
        heroPos.x, heroPos.y, heroPos.z)
    renderer:draw_text_centered(
        pos.x, pos.y + 25, "Combo Mode: " ..
        self.comboMode, 255, 255, 255, 255)
    -- draw spell range
    if menu:get_value(self.rangeQ) == 1 then
        local r, g, b = 255, 204, 0
        local cannon = stance == "Cannon"
        if cannon then r, g, b = 102, 255, 255 end
        renderer:draw_circle(heroPos.x, heroPos.y,
            heroPos.z, cannon and eready and 1600 or
            cannon and 1050 or 600, r, g, b, 192)
    end
    -- draw spell cooldowns
    if self.drag.process then
        local cursor = game.mouse_2d
        local previous = self.drag.point
        local x = cursor.x - previous.x
        local y = cursor.y - previous.y
        self.drag.point = cursor
        self.offsetX = self.offsetX + x
        self.offsetY = self.offsetY + y
    end
    local offset = 1
    local pos = myHero.health_bar.pos
    self.x = pos.x + self.offsetX - 70
    self.y = pos.y + self.offsetY - 65
    renderer:draw_rect_fill(self.x,
        self.y, self.x + 133, self.y,
        self.x, self.y + 34, self.x + 133,
        self.y + 34, 16, 16, 16, 192)
    local range = myHero.attack_range
    local oppos = range < 300 and 'C' or 'H'
    local data = self.data[oppos] or {}
    local slots = {'Q', 'W', 'E', 'R'}
    for _, slot in ipairs(slots) do
        local endTime = data[slot].endTime
        local sprite = data[slot].sprite
        local cooldown = endTime - game.game_time
        local x, y = self.x + offset, self.y + 1
        sprite:draw(x, y); offset = offset + 33
        if cooldown > 0 then
            renderer:draw_text_centered(x + 16,
                y - 16, string.format("%0.1f",
                cooldown), 255, 255, 255, 224)
        end
    end
end

local update = AutoUpdate()
if update == true then return end

if myHero.champ_name == "Jayce" then
    Jayce:New()
end
