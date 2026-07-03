---@class SmallSwordSharp : Bullet
local SmallSwordSharp, super = Class(Bullet)

local FPS = 30
local FADE_FRAMES = 10
local DEFAULT_MIN_SPEED = 4
local DEFAULT_MAX_SPEED = 18
local DEFAULT_ACCEL_DURATION = 0.75
local FIRE_ALPHA_DURATION = 0.12
local FIRE_AIM_DURATION = 0.5
local FIRE_COLOR_DURATION = 0.8
local TWO_PI = math.pi * 2
local UNFLIPPED_TIP_DIRECTION = -math.pi / 2
local FLIPPED_TIP_DIRECTION = math.pi / 2
local ROTATION_SIGN_SAMPLE = 0.001

local function easeInCubic(t)
    return t * t * t
end

local function easeOutCubic(t)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local function easeInQuart(t)
    return t * t * t * t
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function lerp(from, to, t)
    return from + (to - from) * t
end

---@param x number
---@param y number
---@param scale_y number?
---@param flip_y boolean?
---@param min_speed number|table?
---@param max_speed number?
---@param accel_duration number?
function SmallSwordSharp:init(x, y, scale_y, flip_y, min_speed, max_speed, accel_duration)
    super.init(self, x, y, "bullets/small_sword_sharp")

    local options = {}
    if type(min_speed) == "table" then
        options = min_speed
        min_speed = options.min_speed
        max_speed = options.max_speed
        accel_duration = options.accel_duration
    end

    self:setScale(1, scale_y or 1)
    self.flip_y = flip_y or false
    self.damage = 75
    self.destroy_on_hit = false
    self.alpha = 0

    self.min_speed = min_speed or DEFAULT_MIN_SPEED
    self.max_speed = max_speed or DEFAULT_MAX_SPEED
    self.accel_duration = accel_duration or DEFAULT_ACCEL_DURATION
    self.elapsed = 0
    self.fade_time = FADE_FRAMES / FPS
    self.left_fade_x = options.left_fade_x
    self.left_fade_width = options.left_fade_width or 80
    self.fire_speed = options.fire_speed or self.max_speed
    self.fire_accel_duration = options.fire_accel_duration or self.accel_duration
    self.on_fire_launched = options.on_fire_launched
    self.on_fire_finished = options.on_fire_finished
    self.on_fire_scheduled = options.on_fire_scheduled
    self.on_fire_started = options.on_fire_started
    self.auto_fire_delay = options.auto_fire_delay
    self.queued_fire = options.queued_fire == true
    self.phase8_fire_candidate = options.phase8_fire_candidate == true
    if self.queued_fire then
        self.remove_offscreen = false
    end

    self.physics.direction = math.pi
    self.physics.speed = 0
end

function SmallSwordSharp:getTargetDirection()
    local target = Game.battle and Game.battle.soul
    if target then
        return MathUtils.angle(self.x, self.y, target.x, target.y)
    end
    return self.physics.direction or self.rotation or math.pi
end

function SmallSwordSharp:getTransformForRotation(rotation)
    local old_rotation = self.rotation or 0
    self.rotation = rotation

    local transform = self:createTransform()

    self.rotation = old_rotation
    return transform
end

function SmallSwordSharp:getPointForRotation(rotation, x, y)
    if not love or not love.math then
        return nil
    end

    return self:getTransformForRotation(rotation):transformPoint(x, y)
end

function SmallSwordSharp:getTipPositionForRotation(rotation)
    return self:getPointForRotation(rotation, self.width / 2, 0)
end

function SmallSwordSharp:getTipDirectionForRotation(rotation)
    if not love or not love.math then
        return nil
    end

    local center_x, center_y = self:getPointForRotation(rotation, self.width / 2, self.height / 2)
    local tip_x, tip_y = self:getTipPositionForRotation(rotation)

    if not center_x or not tip_x then
        return nil
    end

    return MathUtils.angle(center_x, center_y, tip_x, tip_y)
end

function SmallSwordSharp:getTipRotationSign()
    local base_direction = self:getTipDirectionForRotation(0)
    local sample_direction = self:getTipDirectionForRotation(ROTATION_SIGN_SAMPLE)

    if base_direction and sample_direction then
        local diff = MathUtils.angleDiff(sample_direction, base_direction)
        if math.abs(diff) > 0.000001 then
            return diff < 0 and -1 or 1
        end
    end

    return self.flip_y and -1 or 1
end

function SmallSwordSharp:getRotationForDirection(direction)
    local tip_direction = self:getTipDirectionForRotation(0)
        or (self.flip_y and FLIPPED_TIP_DIRECTION or UNFLIPPED_TIP_DIRECTION)
    local direction_delta = MathUtils.angleDiff(direction, tip_direction)
    return direction_delta / self:getTipRotationSign()
end

function SmallSwordSharp:startFireAfterImages()
    if self.fire_afterimages_started or not self.wave then
        return
    end
    self.fire_afterimages_started = true

    local ghost = Sprite("bullets/small_sword_sharp", 0, 0)
    ghost:setColor(1, 0, 0, 1)
    ghost.layer = -0.001
    self:addChild(ghost)
    self.fire_ghost = ghost

    local ghost_ref = ghost
    local handle = self.wave.timer:every(0.01, function()
        if not ghost_ref or ghost_ref:isRemoved() then
            return false
        end
        local img = AfterImage(ghost_ref, 0.4, 0.03)
        ghost_ref:addChild(img)
    end)
    self.wave.timer:tween(1.0, handle, { limit = 0.189 })
end

function SmallSwordSharp:onWaveSpawn(wave)
    super.onWaveSpawn(self, wave)

    if self.auto_fire_delay == nil then
        return
    end

    if self.on_fire_scheduled and not self.fire_scheduled_called then
        self.fire_scheduled_called = true
        self.on_fire_scheduled(self)
    end

    local function startAutoFire()
        if self:isRemoved() or self.fire_state then
            return
        end
        self:fire()
    end

    if self.auto_fire_delay <= 0 then
        startAutoFire()
    else
        wave.timer:after(self.auto_fire_delay, startAutoFire)
    end
end

function SmallSwordSharp:queueFire()
    if self.fire_state then
        return false
    end

    self.queued_fire = true
    self.phase8_fire_candidate = true
    self.remove_offscreen = false
    return true
end

function SmallSwordSharp:fire()
    if self.fire_state then
        return false
    end

    self.queued_fire = false
    self.phase8_fire_candidate = false
    local target_direction = self:getTargetDirection()
    local start_rotation = self.rotation or 0
    local target_rotation = self:getRotationForDirection(target_direction)
    local clockwise_delta = (target_rotation - start_rotation) % TWO_PI

    self.fire_state = "aiming"
    self.fire_elapsed = 0
    self.fire_alpha_start = self.alpha
    self.fire_rotation_start = start_rotation
    self.fire_rotation_distance = clockwise_delta + TWO_PI
    self.fire_target_rotation = start_rotation + self.fire_rotation_distance
    self.fire_target_direction = target_direction
    self.physics.speed = 0
    if self.on_fire_started and not self.fire_started_called then
        self.fire_started_called = true
        self.on_fire_started(self)
    end
    return true
end

SmallSwordSharp["发射"] = SmallSwordSharp.fire

SmallSwordSharp["准备发射"] = SmallSwordSharp.queueFire

function SmallSwordSharp:updateDefaultMovement()
    local fade_t = math.min(self.elapsed / self.fade_time, 1)
    local alpha = easeInCubic(fade_t)

    if self.left_fade_x then
        local left_fade_t = clamp((self.x - self.left_fade_x) / self.left_fade_width, 0, 1)
        alpha = alpha * left_fade_t
        if self.x <= self.left_fade_x and left_fade_t <= 0 then
            if not self.queued_fire then
                self:remove()
                return false
            end
        end
    end

    self.alpha = alpha

    local speed_t = self.accel_duration > 0 and math.min(self.elapsed / self.accel_duration, 1) or 1
    self.physics.speed = self.min_speed + (self.max_speed - self.min_speed) * easeInCubic(speed_t)
end

function SmallSwordSharp:updateFire()
    self.fire_elapsed = self.fire_elapsed + DT

    local alpha_t = math.min(self.fire_elapsed / FIRE_ALPHA_DURATION, 1)
    self.alpha = lerp(self.fire_alpha_start or self.alpha, 1, alpha_t)

    local aim_t = easeOutCubic(math.min(self.fire_elapsed / FIRE_AIM_DURATION, 1))
    self.rotation = self.fire_rotation_start + self.fire_rotation_distance * aim_t

    local color_t = math.min(self.fire_elapsed / FIRE_COLOR_DURATION, 1)
    self.color = { 1, 1 - color_t, 1 - color_t }

    if self.fire_elapsed >= FIRE_COLOR_DURATION then
        self.fire_state = "launched"
        self.fire_elapsed = 0
        self.rotation = self.fire_target_rotation
        self.physics.direction = self.fire_target_direction
        self.fire_launched = true
        self:startFireAfterImages()
        if self.on_fire_launched then
            self.on_fire_launched(self)
        end
    end
end

function SmallSwordSharp:updateLaunch()
    self.fire_elapsed = self.fire_elapsed + DT
    local t = self.fire_accel_duration > 0 and math.min(self.fire_elapsed / self.fire_accel_duration, 1) or 1
    self.alpha = 1
    self.color = { 1, 0, 0 }
    self.rotation = self.fire_target_rotation
    self.physics.direction = self.fire_target_direction
    self.physics.speed = self.fire_speed * easeInQuart(t)
end

function SmallSwordSharp:isFireOffscreen()
    local size = self.width + self.height + 64
    local x, y = self:getScreenPos()
    return x < -size or y < -size or x > SCREEN_WIDTH + size or y > SCREEN_HEIGHT + size
end

function SmallSwordSharp:update()
    self.elapsed = self.elapsed + DT

    if self.fire_state == "aiming" then
        self:updateFire()
    elseif self.fire_state == "launched" then
        self:updateLaunch()
    else
        if self:updateDefaultMovement() == false then
            return
        end
    end

    super.update(self)

    if self.fire_state == "launched" and self:isFireOffscreen() then
        self:remove()
    end
end

function SmallSwordSharp:onRemove(parent)
    if self.fire_launched and self.on_fire_finished and not self.fire_finished_called then
        self.fire_finished_called = true
        self.on_fire_finished(self)
    end
    super.onRemove(self, parent)
end

return SmallSwordSharp
