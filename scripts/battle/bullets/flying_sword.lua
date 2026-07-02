---@class FlyingSword : Bullet
local FlyingSword, super = Class(Bullet)

---@param x number # The X position of the bullet
---@param y number # The Y position of the bullet
---@param dir number # The dir (in radians) of the bullet
---@param spin number # The visual spin of the bullet, in radians per frame at 30FPS
function FlyingSword:init(x, y, dir, spin)
    -- Last argument = sprite path
    super.init(self, x, y, "bullets/flying_sword/normal")

    -- Move the bullet in dir radians (0 = right, pi = left, clockwise rotation)
    self.physics.direction = dir
    -- Rotate the sprite visually without changing the bullet's movement direction.
    self.graphics.spin = spin or 0
end

function FlyingSword:update()
    -- For more complicated bullet behaviours, code here gets called every update

    super.update(self)
end

return FlyingSword
