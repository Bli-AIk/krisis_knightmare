---@class KrisBusterDiamond : Bullet
local KrisBusterDiamond, super = Class(Bullet)

local function easeInCubic(t)
    return t * t * t
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function KrisBusterDiamond:init(x, y, direction, options)
    super.init(self, x, y, "bullets/buster/diamond_0")

    options = options or {}

    self.damage = 75
    self.destroy_on_hit = false
    self.remove_offscreen = true
    self.physics.direction = direction or 0
    self.physics.speed = 0

    self.target_speed = options.speed or 6
    self.easing = options.easing or "linear"
    self.accel_duration = options.accel_duration or 0.45
    self.elapsed = 0

    self:setScale(1, 1)
    self.rotation = (direction or 0) + math.pi / 2
    self:setHitbox(4, 6, self.width - 8, self.height - 12)
end

function KrisBusterDiamond:update()
    self.elapsed = self.elapsed + DT

    if self.easing == "in-cubic" then
        local t = self.accel_duration > 0 and clamp(self.elapsed / self.accel_duration, 0, 1) or 1
        self.physics.speed = self.target_speed * easeInCubic(t)
    else
        self.physics.speed = self.target_speed
    end

    self.rotation = self.physics.direction + math.pi / 2

    super.update(self)
end

return KrisBusterDiamond
