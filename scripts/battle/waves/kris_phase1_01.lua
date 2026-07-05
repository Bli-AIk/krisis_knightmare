local KrisPhase1_01, super = Class(Wave)

local PLAYER_START_OFFSET_X = -28
local CHASER_START_OFFSET_X = 28
local DEPTH_MASK_SPAWN_TIME = 42 / 60
local DEPTH_MASK_FINISH_TIME = 4.5
local ACT_FRAME_DELAY = 4 / 30
local RETURN_TARGET_OFFSET_X = -2
local RETURN_TARGET_OFFSET_Y = 1
local SOUL_BULLET_LAYER = BATTLE_LAYERS["above_bullets"] + 2

local function removeValue(list, value)
    if not list then
        return
    end

    for i = #list, 1, -1 do
        if list[i] == value then
            table.remove(list, i)
        end
    end
end

local function getChaserEnemy()
    local attackers = Game.battle and Game.battle.getActiveEnemies and Game.battle:getActiveEnemies() or {}
    return attackers[1]
end

local function getChaserOrigin(fallback_x, fallback_y, attacker)
    attacker = attacker or getChaserEnemy()
    if attacker and attacker.parent then
        if attacker.sprite then
            return attacker:localToScreenPos((attacker.sprite.width / 2) - 4.5, attacker.sprite.height / 2)
        end
        return attacker:localToScreenPos(attacker.width / 2, attacker.height / 2)
    end

    return fallback_x, fallback_y
end

local function getActFrameCount(attacker)
    local sprite = attacker and attacker.sprite
    if sprite and sprite.frames and sprite.isSprite and sprite:isSprite("act") then
        return #sprite.frames
    end

    local frames = Assets.getFrames("enemies/kris/act")
    return frames and #frames or 5
end

local function playActAnimation(attacker)
    if attacker and attacker.parent and attacker.setAnimation then
        attacker:setAnimation({ "act", ACT_FRAME_DELAY, false })
    end
end

local function playActAnimationReversed(attacker)
    if attacker and attacker.parent and attacker.setAnimation then
        local frame_count = getActFrameCount(attacker)
        attacker:setAnimation({
            "act",
            ACT_FRAME_DELAY,
            false,
            frames = { tostring(frame_count) .. "-1" },
        }, function()
            if attacker.parent then
                attacker:setAnimation("idle")
            end
        end)
    end
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
    local depth_mask = SoulDepthMask(arena_height * 0.5, arena_height * 0.8)
    self.depth_mask = self:spawnObjectTo(soul, depth_mask, soul.width / 2, soul.height / 2)
    if self.depth_mask_finished and self.depth_mask.beginWhiteFade then
        self.depth_mask:beginWhiteFade()
    end
end

function KrisPhase1_01:beginSoulDepthFinale()
    self.depth_mask_finished = true
    if self.depth_mask and self.depth_mask.parent and self.depth_mask.beginWhiteFade then
        self.depth_mask:beginWhiteFade()
    end
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

function KrisPhase1_01:returnChaserSoul()
    local soul = self.chaser_soul
    if not soul or not soul.parent or not soul.transitionBackTo then
        return
    end

    self.chaser_soul = nil
    removeValue(self.objects, soul)
    removeValue(self.bullets, soul)

    local attacker = getChaserEnemy()
    playActAnimationReversed(attacker)

    local origin_x, origin_y = getChaserOrigin(soul.x, soul.y, attacker)
    soul:transitionBackTo(origin_x + RETURN_TARGET_OFFSET_X, origin_y + RETURN_TARGET_OFFSET_Y)
end

function KrisPhase1_01:init()
    super.init(self)
    self.time = 8
    self.soul_offset_x = PLAYER_START_OFFSET_X
    self.soul_offset_y = 0
end

function KrisPhase1_01:onArenaEnter()
    self:spawnChaserSoul()
    playActAnimation(getChaserEnemy())
end

function KrisPhase1_01:onStart()
    local soul = self:spawnChaserSoul()
    if soul and soul.startChaseDelay then
        soul:startChaseDelay()
    end

    self.timer:after(DEPTH_MASK_SPAWN_TIME, function()
        self:spawnSoulDepthMask()
    end)

    self.timer:after(DEPTH_MASK_FINISH_TIME, function()
        self:beginSoulDepthFinale()
    end)
end

function KrisPhase1_01:onEnd(death)
    if not death then
        self:returnChaserSoul()
    end

    return super.onEnd(self, death)
end

function KrisPhase1_01:update()
    super.update(self)
end

return KrisPhase1_01
