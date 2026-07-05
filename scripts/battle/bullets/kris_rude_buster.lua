---@class KrisRudeBuster : Bullet
local KrisRudeBuster, super = Class(Bullet)

local TWO_PI = math.pi * 2
local DAMAGE = 100
local MOVE_DURATION = 0.12
local SHRINK_DURATION = 0.12
local ROTATION = -math.pi / 2
local SPAWN_INSET = 8
local DIAMOND_MIN_COUNT = 4
local DIAMOND_MAX_COUNT = 7
local BUSTER_SCALE = 0.5

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function randomBetween(min, max)
    return min + (max - min) * love.math.random()
end

local function easeOutCubic(t)
    local inv = 1 - t
    return 1 - inv * inv * inv
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

function KrisRudeBuster:init(x, y)
    super.init(self, x, y, "bullets/rude_buster")

    self.damage = DAMAGE
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.rotation = ROTATION
    self.start_x = x
    self.start_y = y
    self.elapsed = 0
    self.state = "moving"
    self.impact_x = x
    self.impact_y = y
    self.followup_spawned = false
    self.start_scale_x = BUSTER_SCALE
    self.start_scale_y = BUSTER_SCALE
    self:setScale(self.start_scale_x, self.start_scale_y)
    self:setHitbox(4, 8, self.width - 8, self.height - 16)
end

function KrisRudeBuster:getTargetX()
    local left = getArenaBounds()
    local half_length = self.height * math.abs(self.scale_y or 1) / 2
    return left + half_length
end

function KrisRudeBuster:startShrink()
    if self.state ~= "moving" then
        return
    end

    local left, _, top, bottom = getArenaBounds()
    self.state = "shrinking"
    self.elapsed = 0
    self.impact_x = left
    self.impact_y = clamp(self.y, top, bottom)
    self.x = self:getTargetX()
    self.y = self.impact_y

    if not self.followup_spawned then
        self.followup_spawned = true
        spawnFollowup(self.wave, "left", self.impact_x, self.impact_y)
    end
end

function KrisRudeBuster:finishShrink()
    self:remove()
end

function KrisRudeBuster:updateMoving()
    self.elapsed = self.elapsed + DT

    local t = MOVE_DURATION > 0 and clamp(self.elapsed / MOVE_DURATION, 0, 1) or 1
    self.x = self.start_x + (self:getTargetX() - self.start_x) * t
    self.y = self.start_y

    if t >= 1 then
        self:startShrink()
    end
end

function KrisRudeBuster:updateShrinking()
    self.elapsed = self.elapsed + DT

    local t = SHRINK_DURATION > 0 and clamp(self.elapsed / SHRINK_DURATION, 0, 1) or 1
    self.scale_x = self.start_scale_x * (1 - easeOutCubic(t))
    self.scale_y = self.start_scale_y

    if t >= 1 then
        self:finishShrink()
    end
end

function KrisRudeBuster:update()
    if self.state == "moving" then
        self:updateMoving()
    elseif self.state == "shrinking" then
        self:updateShrinking()
    end

    super.update(self)
end

return KrisRudeBuster
