
local Version = 1.0
local Url = "https://raw.githubusercontent.com/Ark223/Bruhwalker/main/"

local function AutoUpdate()
    local result = http:get(Url .. "BaseUlt.version")
    if result and result ~= "" and tonumber(result) > Version then
        http:download_file(Url .. "BaseUlt.lua", "BaseUlt.lua")
        console:log("[BaseUlt] Successfully updated. Please reload!")
    end
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

local myHero = game.local_player
local prediction = _G.Prediction
if not prediction then return end

----------------
-- Spell data --

local DamageType = {["PHYSICAL"] = 0, ["MAGICAL"] = 1}

local SpellData = {
    ["Ashe"] = {
        speed = 1600, delay = 0.25, radius = 130,
        collision = true, type = DamageType.MAGICAL,
        damage = function(level, target) return
            200 * level + myHero.ability_power end
    },
    --[[ ["Draven"] = {
        speed = 2000, delay = 0.4, radius = 160,
        collision = true, type = DamageType.PHYSICAL,
        damage = function(level, target) return 200 * level + 150
            + (0.4 + level + 1.8) * myHero.bonus_attack_damage end
    }, --]]
    ["Ezreal"] = {
        speed = 2000, delay = 1, radius = 160,
        collision = false, type = DamageType.MAGICAL,
        damage = function(level, target) return 150 * level + 200 + 0.9
            * myHero.ability_power + myHero.bonus_attack_damage end
    },
    ["Jinx"] = {
        speed = 1700, delay = 0.6, radius = 140,
        collision = true, type = DamageType.PHYSICAL,
        damage = function(level, target) return 150 * level + 100
            + 1.5 * myHero.bonus_attack_damage + (0.05 * level
            + 0.2) * (target.max_health - target.health) end
    },
    ["Senna"] = {
        speed = 20000, delay = 1, radius = 160,
        collision = false, type = DamageType.PHYSICAL,
        damage = function(level, target) return 125 * level + 125 + 0.7
            * myHero.ability_power + myHero.bonus_attack_damage end
    }
}

-----------------------
-- Base Ult instance --

local BaseUlt = Class()

function BaseUlt:__init()
    self.recalls = {}
    self.base = myHero.team ~= 100 and
        {x = 410, y = 183, z = 420} or
        {x = 14300, y = 172, z = 14390}
    self.width = game.screen_size.width
    self.height = game.screen_size.height
    self.len = math.floor(0.25 * self.width)
    self.x = math.floor((self.width - self.len) / 2)
    self.y = math.floor(0.675 * self.height)
    self.p1 = {x = self.x, y = self.y}
    self.p2 = {x = self.x + self.len, y = self.y}
    self.p3 = {x = self.x + self.len, y = self.y + 30}
    self.p4 = {x = self.x, y = self.y + 30}
    client:set_event_callback("on_draw",
        function() return self:OnDraw() end)
    client:set_event_callback("on_tick",
        function() return self:OnTick() end)
    client:set_event_callback("on_teleport",
        function(...) return self:OnTeleport(...) end)
end

function BaseUlt:BaseDistance(start)
    local dx = self.base.x - start.x
    local dy = self.base.z - start.z
    return math.sqrt(dx * dx + dy * dy)
end

function BaseUlt:CalculateHitTime()
    local spell = SpellData[myHero.champ_name]
    if spell == nil then return 0.0 end
    local dist = self:BaseDistance(myHero.origin)
    local jinx = myHero.champ_name == "Jinx"
    -- super advanced formula right here
    if jinx then spell.speed = 2200 - 743250 / dist end
    local duration = spell.delay + dist / spell.speed
    return duration + spell.radius / spell.speed
end

function BaseUlt:DrawFilledProgress(c, o1, o2)
    renderer:draw_rect_fill(self.p1.x + o2,
        self.p1.y + o1, self.p2.x,
        self.p2.y + o1, self.p4.x + o2,
        self.p4.y + o1, self.p3.x, 
        self.p3.y + o1, c.r, c.g, c.b, c.a)
end

function BaseUlt:DrawOutlineBar(c, w, o)
    local a, r, g, b = c.a, c.r, c.g, c.b
    renderer:draw_line(self.p1.x, self.p1.y + o,
        self.p2.x, self.p2.y + o, w, r, g, b, a)
    renderer:draw_line(self.p2.x, self.p2.y + o,
        self.p3.x, self.p3.y + o, w, r, g, b, a)
    renderer:draw_line(self.p3.x, self.p3.y + o,
        self.p4.x, self.p4.y + o, w, r, g, b, a)
    renderer:draw_line(self.p4.x, self.p4.y + o,
        self.p1.x, self.p1.y + o, w, r, g, b, a)
end

function BaseUlt:GetInvisibleDuration(unit)
    local time = prediction:get_invisible_duration(unit)
    return time == math.huge and 0 or time
end

function BaseUlt:OnTeleport(unit, duration, name, status)
    if name ~= "Recall" or not unit.is_enemy then return end
    if status ~= "Start" then self.recalls[unit.object_id] = nil
    else self.recalls[unit.object_id] = {killable = false,
        duration = duration, startTime = game.game_time} end
end

function BaseUlt:OnDraw()
    local offsetY = 0
    local time = self:CalculateHitTime()
    for id, data in pairs(self.recalls) do
        if data == nil then goto continue end
        local unit = game:get_object(id)
        local passed = math.min(data.duration,
            game.game_time - data.startTime)
        local coefficient = passed / data.duration
        local offsetX = math.ceil(coefficient * self.len)
        local color1 = {a = 255, r = 30, g = 50, b = 60}
        local color2 = {a = 255, r = 81, g = 123, b = 145}
        local color3 = {a = 255, r = 15, g = 30, b = 50}
        self:DrawFilledProgress(color1, offsetY, 0)
        self:DrawFilledProgress(color2, offsetY, offsetX)
        if data.killable then local pos = self.x +
            self.len - time / data.duration * self.len
            renderer:draw_line(pos, self.y + offsetY, pos,
            self.y + offsetY + 30, 4, 255, 69, 0, 255) end
        self:DrawOutlineBar(color3, 3, offsetY)
        renderer:draw_text_centered(self.x +
            self.len / 2, self.y + 7 + offsetY,
            string.format("%s (%0.1fs)", unit.champ_name,
            data.duration - passed), 255, 255, 255, 255)
        offsetY = offsetY - 45
        ::continue::
    end
end

function BaseUlt:OnTick()
    local pos = self.base
    local spell = SpellData[myHero.champ_name]
    if spell == nil then return end
    local time = self:CalculateHitTime()
    local latency = game.ping / 1000 + 0.034
    for id, data in pairs(self.recalls) do
        if data == nil then goto continue end
        local unit = game:get_object(id)
        local book = spellbook:get_spell_slot(SLOT_R)
        local invis = self:GetInvisibleDuration(unit)
        local damage = spell.damage(book.level or 1, unit)
        local left = data.duration - game.game_time + data.startTime
        local threshold = spell.radius * 2 / spell.speed + latency
        damage = damage - (time + invis) * unit.health_regen
        damage = spell.type == DamageType.MAGICAL and
            unit:calculate_magic_damage(damage) or
            unit:calculate_phys_damage(damage) or 0
        data.killable = spellbook:can_cast(SLOT_R) and
            time <= data.duration and damage >= unit.health
        if data.killable and time - threshold <= left and
            time >= left then spellbook:cast_spell_minimap(
            SLOT_R, 1, pos.x, pos.y, pos.z) return end
        ::continue::
    end
end

BaseUlt:New()
console:log("[BaseUlt] Successfully loaded!")
AutoUpdate()
