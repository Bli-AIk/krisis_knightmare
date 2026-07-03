local KrisPhase1_12, super = Class("kris_phase1_08")

local FIRE_SPEED = 24
local FIRE_ACCEL_DURATION = 0.18

function KrisPhase1_12:shouldFireSharpSwordSpawn(spawn)
    return spawn and spawn.index >= 1 and (spawn.index - 1) % 3 == 0
end

function KrisPhase1_12:getFireLeftX()
    return self:getSharpSwordLeftFadeX()
end

function KrisPhase1_12:getSharpSwordBulletOptions(y, scale_y, flip_y)
    local options = super.getSharpSwordBulletOptions(self, y, scale_y, flip_y)

    if not self:shouldFireSharpSwordSpawn(self.current_sharp_sword_spawn) then
        return options
    end

    options.fire_on_left_edge = true
    options.fire_left_x = self:getFireLeftX()
    options.fire_speed = FIRE_SPEED
    options.fire_accel_duration = FIRE_ACCEL_DURATION
    options.skip_left_fade_alpha = true

    return options
end

return KrisPhase1_12
