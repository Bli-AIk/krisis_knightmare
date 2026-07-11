---@class KrisBusterDiamond : Bullet
local KrisBusterDiamond, super = Class(Bullet)

local END_SPEED_FACTOR = 0.82
local MIN_SPEED = 4
local DIAMOND_FRAME_DURATION = 2 / 30

local function easeInCubic(t)
    return t * t * t
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function KrisBusterDiamond:init(x, y, direction, options)
    super.init(self, x, y, "bullets/buster/diamond")

    options = options or {}

    self.damage = 75
    self.destroy_on_hit = false
    self.remove_offscreen = true
    self.physics.direction = direction or 0
    self.physics.speed = 0

    self.start_speed = options.speed or 6
    self.end_speed = math.max(self.start_speed * END_SPEED_FACTOR, MIN_SPEED)
    self.easing = options.easing or "linear"
    self.decel_duration = options.accel_duration or 1.0
    self.elapsed = 0

    self:setScale(1, 1)
    self.sprite:play(DIAMOND_FRAME_DURATION, true)
    self.rotation = (direction or 0) + math.pi / 2
    self:setHitbox(4, 6, self.width - 8, self.height - 12)
end

function KrisBusterDiamond:update()
    self.elapsed = self.elapsed + DT

    local raw_t = self.decel_duration > 0 and clamp(self.elapsed / self.decel_duration, 0, 1) or 1
    local t = self.easing == "in-cubic" and easeInCubic(raw_t) or raw_t
    self.physics.speed = self.start_speed + (self.end_speed - self.start_speed) * t

    self.rotation = self.physics.direction + math.pi / 2

    super.update(self)
end

return KrisBusterDiamond
