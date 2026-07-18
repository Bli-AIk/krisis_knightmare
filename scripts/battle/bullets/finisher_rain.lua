---@class FinisherRain : Bullet
local FinisherRain, super = Class(Bullet)

local RAIN_FRAME_TIME = 6 / 30
local RAIN_SCALE = 1
local RAIN_SPEED = 8 -- Pixels per frame at 30 FPS.
local RAIN_TEXTURE = "bullets/finisher_rain/rain"

function FinisherRain:init(x, y)
    super.init(self, x, y, RAIN_TEXTURE)

    self:setScale(RAIN_SCALE, RAIN_SCALE)
    self.sprite:play(RAIN_FRAME_TIME, true)
    self:setHitbox(4, 4, self.width - 8, self.height - 8)
    self.physics.speed_x = 0
    self.physics.speed_y = RAIN_SPEED
    self.damage = 50
    self.destroy_on_hit = false
    self.remove_offscreen = true
end

return FinisherRain
