---@class KrisBusterExplode : Bullet
local KrisBusterExplode, super = Class(Bullet)

local EXPLODE_FRAME_DELAY = 3 / 60
local BUSTER_SCALE = 1.5

function KrisBusterExplode:init(x, y, options)
    super.init(self, x, y)

    options = options or {}

    self.collider = nil
    self.can_graze = false
    self.damage = 0
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.layer = BATTLE_LAYERS["above_bullets"]
    self.rotation = options.rotation or 0
    self:setScale((options.scale or 1) * BUSTER_SCALE)
    self:setSprite("bullets/buster/explode", EXPLODE_FRAME_DELAY, false, function()
        if self.parent then
            self:remove()
        end
    end)
end

return KrisBusterExplode
