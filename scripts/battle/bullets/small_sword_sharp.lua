---@class SmallSwordSharp : Bullet
local SmallSwordSharp, super = Class(Bullet)

local FPS = 30
local FADE_FRAMES = 10
local DEFAULT_MIN_SPEED = 4
local DEFAULT_MAX_SPEED = 16
local DEFAULT_ACCEL_DURATION = 0.75

local function easeInCubic(t)
    return t * t * t
end

---@param x number
---@param y number
---@param scale_y number?
---@param flip_y boolean?
---@param min_speed number?
---@param max_speed number?
---@param accel_duration number?
function SmallSwordSharp:init(x, y, scale_y, flip_y, min_speed, max_speed, accel_duration)
    super.init(self, x, y, "bullets/small_sword_sharp")

    self:setScale(1, scale_y or 1)
    self.flip_y = flip_y or false
    self.damage = 75
    self.destroy_on_hit = false
    self.alpha = 0

    self.min_speed = min_speed or DEFAULT_MIN_SPEED
    self.max_speed = max_speed or DEFAULT_MAX_SPEED
    self.accel_duration = accel_duration or DEFAULT_ACCEL_DURATION
    self.elapsed = 0
    self.fade_time = FADE_FRAMES / FPS

    self.physics.direction = math.pi
    self.physics.speed = 0
end

function SmallSwordSharp:update()
    self.elapsed = self.elapsed + DT

    local fade_t = math.min(self.elapsed / self.fade_time, 1)
    self.alpha = easeInCubic(fade_t)

    local speed_t = self.accel_duration > 0 and math.min(self.elapsed / self.accel_duration, 1) or 1
    self.physics.speed = self.min_speed + (self.max_speed - self.min_speed) * easeInCubic(speed_t)

    super.update(self)
end

return SmallSwordSharp
