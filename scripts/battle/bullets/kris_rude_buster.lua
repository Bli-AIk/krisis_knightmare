---@class KrisRudeBuster : Bullet
local KrisRudeBuster, super = Class(Bullet)

local TWO_PI = math.pi * 2
local FPS = 30
local DAMAGE = 100
local MOVE_DURATION = 0.12
local SHRINK_DURATION = 0.12
local ROTATION = -math.pi / 2
local SPAWN_INSET = 8
local MIN_RANDOM_SPEED = 7.5
local MAX_RANDOM_SPEED = 14
local MAX_CHAIN_SPEED = MAX_RANDOM_SPEED
local DIAMOND_START_MIN_COUNT = 4
local DIAMOND_START_MAX_COUNT = 6
local DIAMOND_SPLIT_MIN_COUNT = 2
local DIAMOND_MIN_SPEED_LEAD = 1.5
local DIAMOND_MAX_SPEED_LEAD = 3.5
local DIAMOND_MAX_SPEED = 8
local MIN_BOUNCE_SECONDS = 0.5
local SAFE_DIRECTION_ATTEMPTS = 48
local RAY_EPSILON = 0.0001
local BUSTER_SCALE = 0.5
local WALL_IMPACT_SOUND = "kris_buster_wall"

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function randomBetween(min, max)
    return min + (max - min) * Mod:randomKrisis("kris_rude_buster")
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

local function spawnDiamond(wave, edge, x, y, bullet_speed, speed_factor)
    local direction = randomInwardDirection(edge, 0, 180)
    bullet_speed = bullet_speed or MIN_RANDOM_SPEED
    local min_speed = math.min(bullet_speed + DIAMOND_MIN_SPEED_LEAD, DIAMOND_MAX_SPEED)
    local max_speed = math.max(min_speed, math.min(bullet_speed + DIAMOND_MAX_SPEED_LEAD, DIAMOND_MAX_SPEED))
    local speed = randomBetween(min_speed, max_speed) * (speed_factor or 1)
    local easing = Mod:randomKrisis("kris_rude_buster") < 0.5 and "linear" or "in-cubic"

    return wave:spawnBullet("kris_buster_diamond", x, y, direction, {
        speed = speed,
        easing = easing,
        accel_duration = randomBetween(0.2, 0.75),
    })
end

local function getSplitDiamondCount(total_count, bullet_count, index)
    bullet_count = math.max(bullet_count or 1, 1)
    index = math.max(index or 1, 1)

    local count = math.floor(total_count / bullet_count)
    if index <= (total_count % bullet_count) then
        count = count + 1
    end

    return math.max(count, DIAMOND_SPLIT_MIN_COUNT)
end

local function spawnFollowup(wave, edge, impact_x, impact_y, options)
    if not wave or wave.finished then
        return
    end

    options = options or {}

    Assets.playSound(WALL_IMPACT_SOUND)
    wave:spawnBullet("kris_buster_explode", impact_x, impact_y)

    local spawn_x, spawn_y = getSpawnPosition(edge, impact_x, impact_y)
    local bullet_count = math.max(options.bullet_count or 1, 1)
    local max_diamond_count = math.max(
        options.max_diamond_count or DIAMOND_START_MAX_COUNT,
        DIAMOND_START_MIN_COUNT
    )
    local total_diamond_count = DIAMOND_START_MIN_COUNT
    local diamond_count_divisor = options.diamond_count_divisor or 1
    local speed_factor = options.speed_factor or 1

    for bullet_index = 1, bullet_count do
        local bullet_speed = options.bullet_speed
            or randomBetween(MIN_RANDOM_SPEED, MAX_RANDOM_SPEED) * speed_factor
        local direction
        direction, bullet_speed = randomSafeInwardDirection(edge, spawn_x, spawn_y, bullet_speed, 45, 135)
        wave:spawnBullet("kris_buster_bullet", spawn_x, spawn_y, direction, {
            speed = bullet_speed,
            chain_depth = 1,
            diamond_count_divisor = diamond_count_divisor,
            max_diamond_count = max_diamond_count,
            bounce_speed_factor = options.bounce_speed_factor,
            bounce_speed_factors = options.bounce_speed_factors,
            max_chain_speed = options.max_chain_speed,
            speed_factor = speed_factor,
        })

        local diamond_count = options.split_diamonds
            and getSplitDiamondCount(total_diamond_count, bullet_count, bullet_index)
            or total_diamond_count
        for _ = 1, diamond_count do
            spawnDiamond(wave, edge, spawn_x, spawn_y, bullet_speed, speed_factor)
        end
    end
end

function KrisRudeBuster:init(x, y, options)
    super.init(self, x, y, "bullets/rude_buster")

    options = options or {}

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
    self.followup_bullet_count = options.followup_bullet_count or 1
    self.followup_split_diamonds = options.followup_split_diamonds == true
    self.followup_diamond_count_divisor = options.followup_diamond_count_divisor or 1
    self.followup_max_diamond_count = math.max(
        options.followup_max_diamond_count or DIAMOND_START_MAX_COUNT,
        DIAMOND_START_MIN_COUNT
    )
    self.followup_speed_factor = options.followup_speed_factor or 1
    self.followup_bounce_speed_factor = options.followup_bounce_speed_factor
    self.followup_bounce_speed_factors = options.followup_bounce_speed_factors
    self.followup_max_chain_speed =
        (options.followup_max_chain_speed or MAX_CHAIN_SPEED) * self.followup_speed_factor
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
        spawnFollowup(self.wave, "left", self.impact_x, self.impact_y, {
            bullet_count = self.followup_bullet_count,
            split_diamonds = self.followup_split_diamonds,
            diamond_count_divisor = self.followup_diamond_count_divisor,
            max_diamond_count = self.followup_max_diamond_count,
            speed_factor = self.followup_speed_factor,
            bounce_speed_factor = self.followup_bounce_speed_factor,
            bounce_speed_factors = self.followup_bounce_speed_factors,
            max_chain_speed = self.followup_max_chain_speed,
        })
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
