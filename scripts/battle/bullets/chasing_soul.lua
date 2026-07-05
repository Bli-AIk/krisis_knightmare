local ChasingSoul, super = Class(Bullet)

local DEFAULT_MOVE_SPEED = 4
local EDGE_MARGIN = 18
local TARGET_EPSILON = 1
local TRANSITION_TIME = 7
local FADE_IN_TIME = 3
local CHASE_START_DELAY = 1.2
local SOUL_BULLET_LAYER = BATTLE_LAYERS["above_bullets"] + 2

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function ChasingSoul:init(x, y)
    super.init(self, x, y, "bullets/soul/soul_0")

    self.layer = SOUL_BULLET_LAYER
    self:setScale(1)
    self.damage = 0
    self.can_graze = false
    self.destroy_on_hit = false
    self.remove_offscreen = false

    self.transitioning = false
    self.transition_destroy = false
    self.chase_enabled = false
    self.chase_delay = 0
end

function ChasingSoul:getBounds()
    local arena = Game.battle and Game.battle.arena
    if arena then
        return arena:getLeft() + EDGE_MARGIN,
            arena:getRight() - EDGE_MARGIN,
            arena:getTop() + EDGE_MARGIN,
            arena:getBottom() - EDGE_MARGIN
    end

    return 48, SCREEN_WIDTH - 48, 48, SCREEN_HEIGHT - 190
end

function ChasingSoul:getTargetSoul()
    local soul = Game.battle and Game.battle.soul
    if soul and soul.parent and soul.visible then
        return soul
    end
end

function ChasingSoul:getTargetPosition()
    local soul = self:getTargetSoul()
    if not soul then
        return
    end

    if soul.getExactPosition then
        return soul:getExactPosition()
    end
    return soul.x, soul.y
end

function ChasingSoul:clampToBounds()
    if self.move_target_x or self.transitioning then
        return
    end

    local left, right, top, bottom = self:getBounds()
    self.x = clamp(self.x, left, right)
    self.y = clamp(self.y, top, bottom)
end

function ChasingSoul:getMoveSpeed()
    local multiplier = self.speed_multiplier or 1

    if Game.battle and Game.battle.soul then
        return (Game.battle.soul.speed or DEFAULT_MOVE_SPEED) * multiplier
    end

    return DEFAULT_MOVE_SPEED * multiplier
end

function ChasingSoul:transitionTo(x, y)
    self.transitioning = true
    self.transition_destroy = false
    self.transition_timer = 0
    self.transition_start_x = self.x
    self.transition_start_y = self.y
    self.transition_target_x = x
    self.transition_target_y = y
    self.transition_target_alpha = self.alpha
    self.alpha = 0
end

function ChasingSoul:transitionBackTo(x, y)
    if self.transitioning and self.transition_destroy then
        return
    end

    self:stopChase()
    self.transitioning = true
    self.transition_destroy = true
    self.transition_timer = 0
    self.transition_start_x = self.x
    self.transition_start_y = self.y
    self.transition_target_x = x
    self.transition_target_y = y
    self.transition_target_alpha = self.alpha
    self.alpha = 0
end

function ChasingSoul:startChaseDelay(delay)
    self.chase_enabled = true
    self.chase_delay = delay or CHASE_START_DELAY
end

function ChasingSoul:stopChase()
    self.chase_enabled = false
    self.chase_delay = 0
    self.move_dx = nil
    self.move_dy = nil
    self.move_remaining = nil
    self.move_target_x = nil
    self.move_target_y = nil
end

function ChasingSoul:updateTransition()
    if not self.transitioning then
        return false
    end

    if self.transition_timer >= TRANSITION_TIME then
        self.transitioning = false
        self:setPosition(self.transition_target_x, self.transition_target_y)
        self.alpha = self.transition_target_alpha or 1
        if self.transition_destroy then
            if Game.battle then
                local burst = HeartBurst(self.transition_target_x, self.transition_target_y, { 1, 1, 1 })
                burst.layer = SOUL_BULLET_LAYER
                Game.battle:addChild(burst)
            end
            self:remove()
        end
        return true
    end

    local progress = MathUtils.clamp(self.transition_timer / TRANSITION_TIME, 0, 1)
    self:setPosition(
        MathUtils.lerp(self.transition_start_x, self.transition_target_x, progress),
        MathUtils.lerp(self.transition_start_y, self.transition_target_y, progress)
    )
    self.alpha = MathUtils.lerp(0, self.transition_target_alpha or 1, MathUtils.clamp(self.transition_timer / FADE_IN_TIME, 0, 1))
    self.transition_timer = self.transition_timer + DTMULT
    return true
end

function ChasingSoul:startChase()
    local target_x, target_y = self:getTargetPosition()
    if not target_x then
        return
    end

    local left, right, top, bottom = self:getBounds()
    target_x = clamp(target_x, left, right)
    target_y = clamp(target_y, top, bottom)

    local dx = target_x - self.x
    local dy = target_y - self.y
    local abs_dx = math.abs(dx)
    local abs_dy = math.abs(dy)

    if abs_dx <= TARGET_EPSILON and abs_dy <= TARGET_EPSILON then
        return
    end

    local move_x = abs_dx >= abs_dy and abs_dx > TARGET_EPSILON
    local move_y = (not move_x) and abs_dy > TARGET_EPSILON
    if not move_x and not move_y then
        return
    end

    self.move_dx = move_x and MathUtils.sign(dx) or 0
    self.move_dy = move_y and MathUtils.sign(dy) or 0
    self.move_remaining = move_x and abs_dx or abs_dy
    self.move_target_x = move_x and target_x or self.x
    self.move_target_y = move_y and target_y or self.y
end

function ChasingSoul:updateMove()
    if not self.move_target_x then
        return false
    end

    local amount = math.min(self.move_remaining or 0, self:getMoveSpeed() * DTMULT)
    self.move_remaining = (self.move_remaining or 0) - amount
    self.x = self.x + (self.move_dx or 0) * amount
    self.y = self.y + (self.move_dy or 0) * amount

    if self.move_remaining <= 0 then
        self.x = self.move_target_x
        self.y = self.move_target_y
        self.move_dx = nil
        self.move_dy = nil
        self.move_remaining = nil
        self.move_target_x = nil
        self.move_target_y = nil
    end

    return true
end

function ChasingSoul:update()
    self:clampToBounds()

    if self:updateTransition() then
        if self.parent then
            super.update(self)
        end
        return
    end

    if not self.chase_enabled then
        super.update(self)
        return
    end

    if self.chase_delay > 0 then
        self.chase_delay = math.max(self.chase_delay - DT, 0)
        super.update(self)
        return
    end

    if not self:updateMove() then
        self:startChase()
    end

    super.update(self)
end

return ChasingSoul
