local KrisPhase1_06, super = Class("kris_phase1_01")

local CHASING_SOUL_SPEED_MULTIPLIER = 0.5
local ATTRACT_START_TIME = 3.45
local ATTRACT_MAX_SPEED = 2.25
local ATTRACT_RAMP_TIME = 0.25
local ATTRACT_MIN_DISTANCE = 8
local ATTRACT_ARENA_MARGIN = 2

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function KrisPhase1_06:spawnChaserSoul()
    local soul = super.spawnChaserSoul(self)
    if soul then
        soul.speed_multiplier = CHASING_SOUL_SPEED_MULTIPLIER
    end
    return soul
end

function KrisPhase1_06:spawnSoulDepthMask()
    local soul = self.chaser_soul
    if not soul or not soul.parent then
        return
    end

    local arena_height = self:getArenaHeight()
    local depth_mask = SoulDepthMask(arena_height * 0.5, arena_height * 0.8, {
        radial_particles = true,
    })
    self.depth_mask = self:spawnObjectTo(soul, depth_mask, soul.width / 2, soul.height / 2)
    if self.depth_mask_finished and self.depth_mask.beginWhiteFade then
        self.depth_mask:beginWhiteFade()
    end
end

function KrisPhase1_06:onStart()
    self.player_attraction_active = false
    self.player_attraction_timer = 0

    super.onStart(self)

    self.timer:after(ATTRACT_START_TIME, function()
        self.player_attraction_active = true
        self.player_attraction_timer = 0
    end)
end

function KrisPhase1_06:beginSoulDepthFinale()
    self.player_attraction_active = false
    super.beginSoulDepthFinale(self)
end

function KrisPhase1_06:getAttractionTarget()
    local soul = self.chaser_soul
    if soul and soul.parent then
        return soul.x, soul.y
    end
end

function KrisPhase1_06:clampPlayerSoulPosition(x, y)
    local arena = Game.battle and Game.battle.arena
    if not arena then
        return x, y
    end

    return clamp(x, arena:getLeft() + ATTRACT_ARENA_MARGIN, arena:getRight() - ATTRACT_ARENA_MARGIN),
        clamp(y, arena:getTop() + ATTRACT_ARENA_MARGIN, arena:getBottom() - ATTRACT_ARENA_MARGIN)
end

function KrisPhase1_06:updatePlayerAttraction()
    if not self.player_attraction_active or self.depth_mask_finished then
        return
    end

    local player_soul = Game.battle and Game.battle.soul
    if not player_soul or not player_soul.parent or not player_soul.visible then
        return
    end

    local target_x, target_y = self:getAttractionTarget()
    if not target_x then
        return
    end

    local dx = target_x - player_soul.x
    local dy = target_y - player_soul.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance <= ATTRACT_MIN_DISTANCE then
        return
    end

    self.player_attraction_timer = self.player_attraction_timer + DT
    local ramp = ATTRACT_RAMP_TIME > 0 and clamp(self.player_attraction_timer / ATTRACT_RAMP_TIME, 0, 1) or 1
    local amount = math.min(distance - ATTRACT_MIN_DISTANCE, ATTRACT_MAX_SPEED * ramp * DTMULT)
    local x = player_soul.x + dx / distance * amount
    local y = player_soul.y + dy / distance * amount
    x, y = self:clampPlayerSoulPosition(x, y)

    if player_soul.setPosition then
        player_soul:setPosition(x, y)
    else
        player_soul.x = x
        player_soul.y = y
    end
end

function KrisPhase1_06:update()
    super.update(self)
    self:updatePlayerAttraction()
end

return KrisPhase1_06
