---@class SmallSword : Bullet
local SmallSword, super = Class(Bullet)

---@param x number # The X position of the bullet
---@param y number # The Y position of the bullet
---@param dir number # The dir (in radians) of the bullet
---@param min_speed number # Starting speed (pixels per frame at 30FPS)
---@param max_speed number # Peak speed after acceleration completes
---@param duration number # How many seconds to go from min_speed to max_speed
function SmallSword:init(x, y, dir, min_speed, max_speed, duration)
    super.init(self, x, y, "bullets/small_sword")

    self.physics.direction = dir
    self.physics.speed = min_speed

    self:setScale(1, 1)
    self.damage = 75

    self.min_speed = min_speed
    self.max_speed = max_speed
    self.duration = duration
    self.elapsed = 0
end

function SmallSword:update()
    self.elapsed = self.elapsed + DT
    local t = self.duration > 0 and math.min(self.elapsed / self.duration, 1.0) or 1.0
    self.physics.speed = self.min_speed + (self.max_speed - self.min_speed) * t * t

    super.update(self)

    -- 贴图剑尖朝上，需要 +π/2 才能指向飞行方向
    self.rotation = self.physics.direction + math.pi / 2
end

return SmallSword
