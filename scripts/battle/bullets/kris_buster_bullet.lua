---@class KrisBusterBullet : Bullet
local KrisBusterBullet, super = Class(Bullet)

local TWO_PI = math.pi * 2
local FPS = 30
local DAMAGE = 75
local MIN_RANDOM_SPEED = 7.5
local MAX_RANDOM_SPEED = 14
local MIN_CHAIN_SPEED = 5.5
local BOUNCE_SPEED_FACTOR = 0.94
local MAX_CHAIN_SPEED = MAX_RANDOM_SPEED
local FLIGHT_END_SPEED_FACTOR = 0.84
local DECEL_DURATION = 1.15
local RED_SHIFT_DURATION = 0.22
local SPAWN_INSET = 8
local DIAMOND_START_MIN_COUNT = 4
local DIAMOND_START_MAX_COUNT = 6
local DIAMOND_MAX_COUNT = 6
local DIAMOND_SPLIT_MIN_COUNT = 2
local DIAMOND_MIN_SPEED_LEAD = 1.5
local DIAMOND_MAX_SPEED_LEAD = 3.5
local DIAMOND_MAX_SPEED = 8
local MIN_BOUNCE_SECONDS = 0.5
local SAFE_DIRECTION_ATTEMPTS = 48
local RAY_EPSILON = 0.0001

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

local function getTravelDistanceToArenaEdge(x, y, direction)
    local left, right, top, bottom = getArenaBounds()
    local dx = math.cos(direction)
    local dy = math.sin(direction)
    local distance

    local function addCandidate(candidate)
        if candidate and candidate > RAY_EPSILON then
            distance = distance and math.min(distance, candidate) or candidate
        end
    end

    if dx > RAY_EPSILON then
        addCandidate((right - x) / dx)
    elseif dx < -RAY_EPSILON then
        addCandidate((left - x) / dx)
    end

    if dy > RAY_EPSILON then
        addCandidate((bottom - y) / dy)
    elseif dy < -RAY_EPSILON then
        addCandidate((top - y) / dy)
    end

    return distance or math.huge
end

local function randomSafeInwardDirection(edge, x, y, speed, min_degrees, max_degrees)
    local min_distance = speed * FPS * MIN_BOUNCE_SECONDS
    local best_direction
    local best_distance = -math.huge

    for _ = 1, SAFE_DIRECTION_ATTEMPTS do
        local direction = randomInwardDirection(edge, min_degrees, max_degrees)
        local distance = getTravelDistanceToArenaEdge(x, y, direction)

        if distance >= min_distance then
            return direction, speed
        end

        if distance > best_distance then
            best_direction = direction
            best_distance = distance
        end
    end

    if not best_direction then
        best_direction = edgeNormal(edge)
        best_distance = getTravelDistanceToArenaEdge(x, y, best_direction)
    end

    if best_distance == math.huge then
        return best_direction, speed
    end

    return best_direction, math.max(best_distance / (FPS * MIN_BOUNCE_SECONDS), 1)
end

local function getDiamondCount(depth, divisor)
    depth = math.max(depth or 1, 1)
    divisor = math.max(divisor or 1, 1)

    local growth = depth - 1
    local min_count = clamp(DIAMOND_START_MIN_COUNT + growth, DIAMOND_START_MIN_COUNT, DIAMOND_MAX_COUNT)
    local total_count = love.math.random(min_count, DIAMOND_MAX_COUNT)

    if divisor <= 1 then
        return total_count
    end

    return math.max(DIAMOND_SPLIT_MIN_COUNT, math.floor(total_count / divisor))
end

local function spawnDiamond(wave, edge, x, y, bullet_speed)
    local direction = randomInwardDirection(edge, 0, 180)
    bullet_speed = bullet_speed or MIN_RANDOM_SPEED
    local min_speed = math.min(bullet_speed + DIAMOND_MIN_SPEED_LEAD, DIAMOND_MAX_SPEED)
    local max_speed = math.max(min_speed, math.min(bullet_speed + DIAMOND_MAX_SPEED_LEAD, DIAMOND_MAX_SPEED))
    local speed = randomBetween(min_speed, max_speed)
    local easing = love.math.random() < 0.5 and "linear" or "in-cubic"

    return wave:spawnBullet("kris_buster_diamond", x, y, direction, {
        speed = speed,
        easing = easing,
        accel_duration = randomBetween(0.2, 0.75),
    })
end

local function spawnFollowup(wave, edge, impact_x, impact_y, options)
    if not wave or wave.finished then
        return
    end

    options = options or {}

    wave:spawnBullet("kris_buster_explode", impact_x, impact_y)

    local chain_depth = options.chain_depth or 1
    local diamond_count_divisor = options.diamond_count_divisor or 1
    local bullet_speed = math.max(options.bullet_speed or randomBetween(MIN_RANDOM_SPEED, MAX_RANDOM_SPEED), MIN_CHAIN_SPEED)
    local spawn_x, spawn_y = getSpawnPosition(edge, impact_x, impact_y)
    local direction
    direction, bullet_speed = randomSafeInwardDirection(edge, spawn_x, spawn_y, bullet_speed, 45, 135)
    wave:spawnBullet("kris_buster_bullet", spawn_x, spawn_y, direction, {
        speed = bullet_speed,
        chain_depth = chain_depth,
        diamond_count_divisor = diamond_count_divisor,
        bounce_speed_factor = options.bounce_speed_factor,
        max_chain_speed = options.max_chain_speed,
    })

    for _ = 1, getDiamondCount(chain_depth, diamond_count_divisor) do
        spawnDiamond(wave, edge, spawn_x, spawn_y, bullet_speed)
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
    self.start_speed = math.max(options.speed or randomBetween(MIN_RANDOM_SPEED, MAX_RANDOM_SPEED), MIN_CHAIN_SPEED)
    self.end_speed = math.max(self.start_speed * FLIGHT_END_SPEED_FACTOR, MIN_CHAIN_SPEED)
    self.decel_duration = options.decel_duration or DECEL_DURATION
    self.chain_depth = options.chain_depth or 1
    self.diamond_count_divisor = options.diamond_count_divisor or 1
    self.bounce_speed_factor = options.bounce_speed_factor or BOUNCE_SPEED_FACTOR
    self.max_chain_speed = options.max_chain_speed or MAX_CHAIN_SPEED
    self.elapsed = 0
    self.impacting = false
    self.rotation = (direction or 0) + math.pi / 2
    self:setScale(1.0, 1.0)
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
    spawnFollowup(self.wave, edge, x, y, {
        bullet_speed = math.min(self.start_speed * self.bounce_speed_factor, self.max_chain_speed),
        chain_depth = self.chain_depth + 1,
        diamond_count_divisor = self.diamond_count_divisor,
        bounce_speed_factor = self.bounce_speed_factor,
        max_chain_speed = self.max_chain_speed,
    })
    self:remove()
end

function KrisBusterBullet:update()
    self.elapsed = self.elapsed + DT

    local speed_t = self.decel_duration > 0 and clamp(self.elapsed / self.decel_duration, 0, 1) or 1
    self.physics.speed = self.start_speed + (self.end_speed - self.start_speed) * easeOutCubic(speed_t)

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
