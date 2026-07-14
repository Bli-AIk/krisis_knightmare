---@class FlyingSwordChip : Bullet
local FlyingSwordChip, super = Class(Bullet)

local DAMAGE = 75
local MOVE_DURATION = 2.0
local SPEED_RANDOM_MIN = 0.96
local SPEED_RANDOM_MAX = 1.04
local OFFSCREEN_MARGIN = 56
local CHIP_INITIAL_SPEED = 1 -- Pixels per frame at 30 FPS.
local FRAMES_PER_SECOND = 30
local CONTROL_ONE_DISTANCE_RATIO = 0.32 / 4
local CONTROL_TWO_DISTANCE_RATIO = 1.0
local CONTROL_OFFSET_MIN = 28
local CONTROL_OFFSET_MAX = 72

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function cubicBezier(p0, p1, p2, p3, t)
    local inv = 1 - t
    local a = inv * inv * inv
    local b = 3 * inv * inv * t
    local c = 3 * inv * t * t
    local d = t * t * t

    return p0 * a + p1 * b + p2 * c + p3 * d
end

local function easeInWithInitialSpeed(t, initial_slope)
    return initial_slope * t + (1 - initial_slope) * t * t
end

local function randomBetween(min, max)
    return min + (max - min) * Mod:randomKrisis("flying_sword_chip")
end

local function getOffscreenTarget(x, y, angle)
    local dx = math.cos(angle)
    local dy = math.sin(angle)
    local distance = math.huge

    if dx > 0 then
        distance = math.min(distance, (SCREEN_WIDTH + OFFSCREEN_MARGIN - x) / dx)
    elseif dx < 0 then
        distance = math.min(distance, (-OFFSCREEN_MARGIN - x) / dx)
    end

    if dy > 0 then
        distance = math.min(distance, (SCREEN_HEIGHT + OFFSCREEN_MARGIN - y) / dy)
    elseif dy < 0 then
        distance = math.min(distance, (-OFFSCREEN_MARGIN - y) / dy)
    end

    if distance == math.huge then
        distance = SCREEN_WIDTH + OFFSCREEN_MARGIN
    end

    return x + dx * distance, y + dy * distance
end

function FlyingSwordChip:init(x, y, angle, options)
    super.init(self, x, y, "bullets/flying_sword/chip")

    options = options or {}

    self.damage = options.damage or DAMAGE
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.layer = BATTLE_LAYERS["bullets"] - 0.1
    self.elapsed = 0
    local speed_multiplier = options.speed_multiplier or randomBetween(SPEED_RANDOM_MIN, SPEED_RANDOM_MAX)
    self.duration = options.duration or (MOVE_DURATION / speed_multiplier)
    self.angle = angle or 0

    self:setScale(1, 1)
    self:setOrigin(0.5, 0.5)
    self:setHitbox(3, 3, self.width - 6, self.height - 6)

    self.start_x = x
    self.start_y = y
    self.end_x, self.end_y = getOffscreenTarget(x, y, self.angle)

    local side = Mod:randomKrisis("flying_sword_chip") < 0.5 and -1 or 1
    local curve_offset = randomBetween(CONTROL_OFFSET_MIN, CONTROL_OFFSET_MAX) * side
    local perpendicular_x = -math.sin(self.angle)
    local perpendicular_y = math.cos(self.angle)
    local dir_x = math.cos(self.angle)
    local dir_y = math.sin(self.angle)
    local target_distance = MathUtils.dist(x, y, self.end_x, self.end_y)
    local control_one_distance = target_distance * CONTROL_ONE_DISTANCE_RATIO
    local control_two_distance = target_distance * CONTROL_TWO_DISTANCE_RATIO

    self.control_one_x = x + dir_x * control_one_distance + perpendicular_x * curve_offset
    self.control_one_y = y + dir_y * control_one_distance + perpendicular_y * curve_offset
    self.control_two_x = x + dir_x * control_two_distance - perpendicular_x * curve_offset * 0.7
    self.control_two_y = y + dir_y * control_two_distance - perpendicular_y * curve_offset * 0.7
    local start_tangent_length = 3 * MathUtils.dist(
        self.start_x,
        self.start_y,
        self.control_one_x,
        self.control_one_y
    )
    self.initial_progress_slope = clamp(
        (CHIP_INITIAL_SPEED * FRAMES_PER_SECOND * self.duration) / math.max(start_tangent_length, 0.001),
        0,
        1
    )
    self.path_rotation = self.angle + math.pi / 2
    self.rotation = self.path_rotation
end

function FlyingSwordChip:update()
    self.elapsed = self.elapsed + DT

    local t = self.duration > 0 and clamp(self.elapsed / self.duration, 0, 1) or 1
    local previous_x = self.x
    local previous_y = self.y

    local movement_t = easeInWithInitialSpeed(t, self.initial_progress_slope)
    self.x = cubicBezier(self.start_x, self.control_one_x, self.control_two_x, self.end_x, movement_t)
    self.y = cubicBezier(self.start_y, self.control_one_y, self.control_two_y, self.end_y, movement_t)

    if self.x ~= previous_x or self.y ~= previous_y then
        self.path_rotation = MathUtils.angle(previous_x, previous_y, self.x, self.y) + math.pi / 2
    end
    self.rotation = self.path_rotation

    super.update(self)

    if t >= 1 then
        self:remove()
    end
end

return FlyingSwordChip
