local KrisPhase1_01, super = Class(Wave)

local PLAYER_START_OFFSET_X = -28
local CHASER_START_OFFSET_X = 28
local DEPTH_MASK_SPAWN_TIME = 42 / 60
local SOUL_BULLET_LAYER = BATTLE_LAYERS["above_bullets"] + 2

local function getChaserOrigin(fallback_x, fallback_y)
    local attackers = Game.battle and Game.battle.getActiveEnemies and Game.battle:getActiveEnemies() or {}
    local attacker = attackers[1]
    if attacker and attacker.parent then
        if attacker.sprite then
            return attacker:localToScreenPos((attacker.sprite.width / 2) - 4.5, attacker.sprite.height / 2)
        end
        return attacker:localToScreenPos(attacker.width / 2, attacker.height / 2)
    end

    return fallback_x, fallback_y
end

function KrisPhase1_01:getArenaHeight()
    local arena = Game.battle and Game.battle.arena
    if arena then
        if arena.getTop and arena.getBottom then
            return math.abs(arena:getBottom() - arena:getTop())
        end
        return arena.height or 142
    end

    return 142
end

function KrisPhase1_01:spawnSoulDepthMask()
    local soul = self.chaser_soul
    if not soul or not soul.parent then
        return
    end

    local arena_height = self:getArenaHeight()
    self:spawnObjectTo(soul, SoulDepthMask(arena_height * 0.5, arena_height * 0.8), soul.width / 2, soul.height / 2)
end

function KrisPhase1_01:spawnChaserSoul()
    if self.chaser_soul and self.chaser_soul.parent then
        return self.chaser_soul
    end

    local arena = Game.battle and Game.battle.arena
    local x, y
    if arena then
        x, y = arena:getCenter()
    else
        x, y = SCREEN_WIDTH / 2, (SCREEN_HEIGHT - 155) / 2 + 10
    end

    local target_x, target_y = x + CHASER_START_OFFSET_X, y
    local origin_x, origin_y = getChaserOrigin(target_x, target_y)
    local soul = self:spawnBullet("chasing_soul", origin_x, origin_y)
    self.chaser_soul = soul
    soul:transitionTo(target_x, target_y)

    local burst = HeartBurst(origin_x - 2, origin_y + 1, { 1, 1, 1 })
    burst.layer = SOUL_BULLET_LAYER
    Game.battle:addChild(burst)

    return soul
end

function KrisPhase1_01:init()
    super.init(self)
    self.time = 5
    self.soul_offset_x = PLAYER_START_OFFSET_X
    self.soul_offset_y = 0
end

function KrisPhase1_01:onArenaEnter()
    self:spawnChaserSoul()
end

function KrisPhase1_01:onStart()
    local soul = self:spawnChaserSoul()
    if soul and soul.startChaseDelay then
        soul:startChaseDelay()
    end

    self.timer:after(DEPTH_MASK_SPAWN_TIME, function()
        self:spawnSoulDepthMask()
    end)
end

function KrisPhase1_01:update()
    super.update(self)
end

return KrisPhase1_01
