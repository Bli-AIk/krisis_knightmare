local FinisherSoul, super = Class(Bullet)

function FinisherSoul:init(x, y)
    super.init(self, x, y, "bullets/soul/soul_0")

    self.layer = BATTLE_LAYERS["above_bullets"] + 1
    self:setColor(1, 1, 1)
    self:setScale(1)

    -- This is the soul carried by Kris, not the player's controllable soul.
    self.damage = 0
    self.can_graze = false
    self.destroy_on_hit = false
    self.remove_offscreen = false
end

return FinisherSoul
