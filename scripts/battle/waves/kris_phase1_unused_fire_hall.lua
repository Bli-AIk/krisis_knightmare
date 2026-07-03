local KrisPhase1UnusedFireHall = Class("kris_phase1_03")

local FIRE_LEFT_EDGE_PADDING = 24
local FIRE_SPEED = 24
local FIRE_ACCEL_DURATION = 0.18

function KrisPhase1UnusedFireHall:shouldFireSharpSwordSpawn(spawn)
    return spawn and spawn.index >= 1 and (spawn.index - 1) % 3 == 0
end

function KrisPhase1UnusedFireHall:getFireLeftX()
    local arena = Game.battle and Game.battle.arena
    if arena then
        if arena.getLeft then
            return arena:getLeft() - FIRE_LEFT_EDGE_PADDING
        end
        return (arena.left or 0) - FIRE_LEFT_EDGE_PADDING
    end
    return -FIRE_LEFT_EDGE_PADDING
end

function KrisPhase1UnusedFireHall:getSharpSwordBulletOptions(y, scale_y, flip_y)
    if not self:shouldFireSharpSwordSpawn(self.current_sharp_sword_spawn) then
        return nil
    end

    return {
        fire_on_left_edge = true,
        fire_left_x = self:getFireLeftX(),
        fire_speed = FIRE_SPEED,
        fire_accel_duration = FIRE_ACCEL_DURATION,
    }
end

return KrisPhase1UnusedFireHall
