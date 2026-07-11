local KrisPhase1_06, super = Class("kris_phase1_01")

local ATTRACT_MAX_SPEED = 3.75
local ATTRACT_START_STRENGTH = 0.32
local ATTRACT_RAMP_TIME = 0.18
local ATTRACT_MIN_DISTANCE = 5
local ATTRACT_ARENA_MARGIN = 2
local ATTRACT_FALLOFF_RADIUS_SCALE = 0.75
local ATTRACT_MIN_STRENGTH = 0.25
local PLAYER_AFTERIMAGE_INTERVAL = 0.09
local PLAYER_AFTERIMAGE_ALPHA = 0.5
local PLAYER_AFTERIMAGE_FADE_SPEED = 0.055

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function KrisPhase1_06:spawnSoulDepthMask()
    local soul = self.chaser_soul
    if not soul or not soul.parent then
        return
    end

    local arena_height = self:getArenaHeight()
    local depth_mask = SoulDepthMask(arena_height * 0.5, arena_height * 0.8, self:getSoulDepthMaskOptions({
        radial_particles = true,
        radial_rings = true,
    }))
    self.depth_mask = self:spawnObjectTo(soul, depth_mask, soul.width / 2, soul.height / 2)
    self:startPlayerAttraction()

    if self.depth_mask_finished and self.depth_mask.beginWhiteFade then
        self.depth_mask:beginWhiteFade()
    end
end

function KrisPhase1_06:startPlayerAttraction()
    self.player_attraction_active = true
    self.player_attraction_timer = 0
    self:startPlayerAfterImages()
end

function KrisPhase1_06:spawnPlayerAfterImage()
    local player_soul = Game.battle and Game.battle.soul
    local sprite = player_soul and player_soul.sprite
    if not player_soul or not player_soul.parent or not sprite or not sprite.parent or sprite:isRemoved() then
        return
    end

    local img = AfterImage(sprite, PLAYER_AFTERIMAGE_ALPHA, PLAYER_AFTERIMAGE_FADE_SPEED)
    img.depth_mask_clip = self.depth_mask
    player_soul:addChild(img)
end

function KrisPhase1_06:startPlayerAfterImages()
    if self.player_afterimage_handle then
        return
    end

    self:spawnPlayerAfterImage()
    self.player_afterimage_handle = self.timer:every(PLAYER_AFTERIMAGE_INTERVAL, function()
        self:spawnPlayerAfterImage()
    end)
end

function KrisPhase1_06:stopPlayerAfterImages()
    if self.player_afterimage_handle then
        self.timer:cancel(self.player_afterimage_handle)
        self.player_afterimage_handle = nil
    end
end

function KrisPhase1_06:onStart()
    self.player_attraction_active = false
    self.player_attraction_timer = 0

    super.onStart(self)
end

function KrisPhase1_06:beginSoulDepthFinale()
    self.player_attraction_active = false
    self:stopPlayerAfterImages()
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

function KrisPhase1_06:getAttractionFalloff(distance)
    local depth_mask = self.depth_mask
    local falloff_radius = depth_mask and depth_mask.radius and depth_mask.radius * ATTRACT_FALLOFF_RADIUS_SCALE

    if not falloff_radius or falloff_radius <= ATTRACT_MIN_DISTANCE then
        return 1
    end

    local progress = clamp((distance - ATTRACT_MIN_DISTANCE) / (falloff_radius - ATTRACT_MIN_DISTANCE), 0, 1)
    local eased = progress * progress
    return ATTRACT_MIN_STRENGTH + (1 - ATTRACT_MIN_STRENGTH) * eased
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
    local progress = ATTRACT_RAMP_TIME > 0 and clamp(self.player_attraction_timer / ATTRACT_RAMP_TIME, 0, 1) or 1
    local ramp = ATTRACT_START_STRENGTH + (1 - ATTRACT_START_STRENGTH) * progress
    local falloff = self:getAttractionFalloff(distance)
    local amount = math.min(distance - ATTRACT_MIN_DISTANCE, ATTRACT_MAX_SPEED * ramp * falloff * DTMULT)
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

function KrisPhase1_06:onEnd(death)
    self:stopPlayerAfterImages()
    return super.onEnd(self, death)
end

return KrisPhase1_06
