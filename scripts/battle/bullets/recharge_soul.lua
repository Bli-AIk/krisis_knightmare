local RechargeSoul, super = Class(Bullet)

local MOVE_DISTANCE = 54
local TRANSITION_TIME = 7
local FADE_IN_TIME = 3
local DEFAULT_MOVE_SPEED = 4
local EDGE_BIAS_CHANCE = 0.6
local EDGE_MARGIN = 18
local DEFAULT_LIGHT_RADIUS = 45
local SOUL_BULLET_LAYER = BATTLE_LAYERS["above_bullets"] + 2

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function RechargeSoul:init(x, y, target_enemy, light_radius)
    super.init(self, x, y, "bullets/soul/soul_0")

    self.layer = SOUL_BULLET_LAYER
    self:setScale(1)
    self.target_enemy = target_enemy
    self.light_radius = light_radius or DEFAULT_LIGHT_RADIUS
    self.damage = 0
    self.can_graze = false
    self.destroy_on_hit = false
    self.remove_offscreen = false

    self.enabled = true
    self.transitioning = false
    self.transition_destroy = false
end

function RechargeSoul:getTargetEnemy()
    if self.target_enemy and self.target_enemy.parent and not self.target_enemy.done_state then
        return self.target_enemy
    end

    if Game.battle then
        local active = Game.battle:getActiveEnemies()
        self.target_enemy = active[1]
    end
    return self.target_enemy
end

function RechargeSoul:getBounds()
    local arena = Game.battle and Game.battle.arena
    if arena then
        return arena:getLeft() + EDGE_MARGIN,
            arena:getRight() - EDGE_MARGIN,
            arena:getTop() + EDGE_MARGIN,
            arena:getBottom() - EDGE_MARGIN
    end

    return 48, SCREEN_WIDTH - 48, 48, SCREEN_HEIGHT - 190
end

function RechargeSoul:clampToBounds()
    if self.move_target_x or self.transitioning then
        return
    end

    local left, right, top, bottom = self:getBounds()
    self.x = clamp(self.x, left, right)
    self.y = clamp(self.y, top, bottom)
end

function RechargeSoul:transitionTo(x, y)
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

function RechargeSoul:transitionBackTo(x, y)
    if self.transitioning and self.transition_destroy then
        return
    end

    self.enabled = false
    self.move_dx = nil
    self.move_dy = nil
    self.move_remaining = nil
    self.move_target_x = nil
    self.move_target_y = nil

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

function RechargeSoul:updateTransition()
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

function RechargeSoul:isLit()
    local encounter = Game.battle and Game.battle.encounter
    if not encounter or not encounter.getRechargeLightPosition then
        return false
    end

    local light_x, light_y, radius = encounter:getRechargeLightPosition()
    if not light_x then
        return false
    end

    radius = radius or self.light_radius
    return Utils.dist(self.x, self.y, light_x, light_y) <= radius
end

function RechargeSoul:addRechargeMercy()
    local encounter = Game.battle and Game.battle.encounter
    if encounter and encounter.tryAddRechargeMercy then
        encounter:tryAddRechargeMercy(self:getTargetEnemy())
    end
end

function RechargeSoul:chooseMoveDirection()
    local left, right, top, bottom = self:getBounds()
    local directions = {
        { dx = -1, dy = 0, space = self.x - left },
        { dx = 1, dy = 0, space = right - self.x },
        { dx = 0, dy = -1, space = self.y - top },
        { dx = 0, dy = 1, space = bottom - self.y },
    }

    local best_space = -math.huge
    local best = {}
    local available = {}
    for _, direction in ipairs(directions) do
        if direction.space > 2 then
            table.insert(available, direction)
        end
        if direction.space > best_space + 1 then
            best_space = direction.space
            best = { direction }
        elseif math.abs(direction.space - best_space) <= 1 then
            table.insert(best, direction)
        end
    end

    if #available == 0 then
        return nil
    end

    local biased = love.math.random() < EDGE_BIAS_CHANCE
    return TableUtils.pick(biased and best or available), left, right, top, bottom
end

function RechargeSoul:startMove()
    local direction, left, right, top, bottom = self:chooseMoveDirection()
    if not direction then
        return
    end

    local distance = math.min(MOVE_DISTANCE, math.max(direction.space - 2, 0))
    if distance <= 0 then
        return
    end

    self.move_dx = direction.dx
    self.move_dy = direction.dy
    self.move_remaining = distance
    self.move_target_x = clamp(self.x + direction.dx * distance, left, right)
    self.move_target_y = clamp(self.y + direction.dy * distance, top, bottom)
end

function RechargeSoul:getMoveSpeed()
    if Game.battle and Game.battle.soul then
        return Game.battle.soul.speed or DEFAULT_MOVE_SPEED
    end

    return DEFAULT_MOVE_SPEED
end

function RechargeSoul:updateMove()
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

function RechargeSoul:update()
    self:clampToBounds()

    if self:updateTransition() then
        if self.parent then
            super.update(self)
        end
        return
    end

    if self:updateMove() then
        super.update(self)
        return
    end

    if self.enabled and self:isLit() then
        self:addRechargeMercy()
        self:startMove()
    end

    super.update(self)
end

return RechargeSoul
