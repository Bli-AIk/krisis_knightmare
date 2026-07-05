---@class KrisBusterBullet : Bullet
local KrisBusterBullet, super = Class(Bullet)

local TWO_PI = math.pi * 2
local DAMAGE = 75
local DEFAULT_SPEED = 11
local ACCEL_DURATION = 0.35
local RED_SHIFT_DURATION = 0.22
local SPAWN_INSET = 8
local DIAMOND_MIN_COUNT = 4
local DIAMOND_MAX_COUNT = 7

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function randomBetween(min, max)
    return min + (max - min) * love.math.random()
end

local function easeInCubic(t)
    return t * t * t
end

local function edgeNormal(edge)
    if edge == "left" then
        return 0
    elseif edge == "right" then
        return math.pi
    elseif edge == "top" then
        return math.pi / 2
    end

    return -math.pi / 2
end

local function randomInwardDirection(edge, min_degrees, max_degrees)
    local normal = edgeNormal(edge)
    local offset = math.rad(randomBetween(min_degrees, max_degrees) - 90)
    return (normal + offset) % TWO_PI
end

local function getArenaBounds()
    local arena = Game.battle and Game.battle.arena
    if not arena then
        return 0, SCREEN_WIDTH, 0, SCREEN_HEIGHT
    end

    local left = arena.getLeft and arena:getLeft() or arena.left
    local right = arena.getRight and arena:getRight() or arena.right
    local top = arena.getTop and arena:getTop() or arena.top
    local bottom = arena.getBottom and arena:getBottom() or arena.bottom
    return left, right, top, bottom
end

local function getSpawnPosition(edge, x, y)
    local left, right, top, bottom = getArenaBounds()
    x = clamp(x, left, right)
    y = clamp(y, top, bottom)

    if edge == "left" then
        return left + SPAWN_INSET, y
    elseif edge == "right" then
        return right - SPAWN_INSET, y
    elseif edge == "top" then
        return x, top + SPAWN_INSET
    end

    return x, bottom - SPAWN_INSET
end

local function spawnDiamond(wave, edge, x, y)
    local direction = randomInwardDirection(edge, 0, 180)
    local speed = randomBetween(3.5, 9.5)
    local easing = love.math.random() < 0.5 and "linear" or "in-cubic"

    return wave:spawnBullet("kris_buster_diamond", x, y, direction, {
        speed = speed,
        easing = easing,
        accel_duration = randomBetween(0.2, 0.75),
    })
end

local function spawnFollowup(wave, edge, impact_x, impact_y)
    if not wave or wave.finished then
        return
    end

    wave:spawnBullet("kris_buster_explode", impact_x, impact_y)

    local spawn_x, spawn_y = getSpawnPosition(edge, impact_x, impact_y)
    wave:spawnBullet("kris_buster_bullet", spawn_x, spawn_y, randomInwardDirection(edge, 45, 135), {
        speed = randomBetween(9.5, 13),
    })

    for _ = 1, love.math.random(DIAMOND_MIN_COUNT, DIAMOND_MAX_COUNT) do
        spawnDiamond(wave, edge, spawn_x, spawn_y)
    end
end

function KrisBusterBullet:init(x, y, direction, options)
    super.init(self, x, y, "bullets/buster/bullet")

    options = options or {}

    self.damage = DAMAGE
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.physics.direction = direction or 0
    self.physics.speed = 0
    self.target_speed = options.speed or DEFAULT_SPEED
    self.accel_duration = options.accel_duration or ACCEL_DURATION
    self.elapsed = 0
    self.impacting = false
    self.rotation = (direction or 0) + math.pi / 2
    self:setScale(0.5, 0.5)
    self:setHitbox(5, 5, self.width - 10, self.height - 10)
end

function KrisBusterBullet:getArenaImpact()
    local left, right, top, bottom = getArenaBounds()

    if self.x <= left then
        return "left", left, clamp(self.y, top, bottom)
    elseif self.x >= right then
        return "right", right, clamp(self.y, top, bottom)
    elseif self.y <= top then
        return "top", clamp(self.x, left, right), top
    elseif self.y >= bottom then
        return "bottom", clamp(self.x, left, right), bottom
    end
end

function KrisBusterBullet:impact(edge, x, y)
    if self.impacting then
        return
    end

    self.impacting = true
    spawnFollowup(self.wave, edge, x, y)
    self:remove()
end

function KrisBusterBullet:update()
    self.elapsed = self.elapsed + DT

    local speed_t = self.accel_duration > 0 and clamp(self.elapsed / self.accel_duration, 0, 1) or 1
    self.physics.speed = self.target_speed * easeInCubic(speed_t)

    local red_t = clamp(self.elapsed / RED_SHIFT_DURATION, 0, 1)
    self.color = { 1, 1 - red_t, 1 - red_t }
    self.rotation = self.physics.direction + math.pi / 2

    super.update(self)

    if self.parent and not self.impacting then
        local edge, x, y = self:getArenaImpact()
        if edge then
            self:impact(edge, x, y)
        end
    end
end

return KrisBusterBullet
