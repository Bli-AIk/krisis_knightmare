---@class FlyingSword : Bullet
local FlyingSword, super = Class(Bullet)

local TWO_PI = math.pi * 2

local ENTER_FRAMES = { "enter_0", "enter_1", "enter_2", "enter_3" }
local ENTER_FRAME_DURATION = 2
local ENTER_TOTAL_FRAMES = #ENTER_FRAMES * ENTER_FRAME_DURATION

local TARGET_RPM = 60
local TARGET_SPIN = (TARGET_RPM * TWO_PI / 60) / 30
local SPIN_RAMP_START_FRAME = ENTER_FRAME_DURATION
local SPIN_RAMP_END_FRAME = ENTER_FRAME_DURATION * 3

local ROUND_TRIP_FRAMES = 2 * 30 + 16
local APEX_INTERVAL_FRAMES = ROUND_TRIP_FRAMES / 2
local ROUND_TRIP_COUNT = 3.5
local MOVE_START_FRAME = SPIN_RAMP_END_FRAME
local MOVE_TOTAL_FRAMES = ROUND_TRIP_FRAMES * ROUND_TRIP_COUNT
local SPIN_DECEL_FRAMES = 16

local LEFT_TARGET_OFFSET_X = -260
local LEFT_TARGET_OFFSET_Y = 0
local LEFT_ROTATION = -math.pi / 2

local STOP_FRAMES = 3
local RETURN_FRAMES = 0.5 * 30
local GRAZE_TP_MAX = 3
local DAMAGE = 100

local NORMAL_HITBOX_X = 25
local NORMAL_HITBOX_Y = 4
local NORMAL_HITBOX_WIDTH = 10
local NORMAL_HITBOX_HEIGHT = 54
local HALF_HITBOX_HEIGHT = NORMAL_HITBOX_HEIGHT / 2
local HALF_UP_HITBOX_Y = NORMAL_HITBOX_Y
local HALF_DOWN_HITBOX_Y = NORMAL_HITBOX_Y + HALF_HITBOX_HEIGHT

local SPLIT_PULSE_INTERVAL_SECONDS = 50 * 2 / 60
local SPLIT_ROTATION_DURATION_SECONDS = 2
local SPLIT_CLOSED_HOLD_SECONDS = 0.2

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function easeOutCubic(t)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

local function easeInCubic(t)
    return t * t * t
end

local function nextRotationInSpinDirection(rotation, target)
    while target <= rotation do
        target = target + TWO_PI
    end
    return target
end

local function isHalfSwordSprite(sprite)
    return sprite == "half_up" or sprite == "half_down"
end

---@param x number # The X position of the bullet
---@param y number # The Y position of the bullet
---@param dir number # The dir (in radians) of the bullet
---@param spin number? # Unused legacy argument
function FlyingSword:init(x, y, dir, spin, options)
    if type(spin) == "table" and options == nil then
        options = spin
        spin = nil
    end

    options = options or {}

    super.init(self, x, y, "bullets/flying_sword/enter_0")

    self.physics.direction = dir or 0
    self.graphics.spin = 0
    self.current_spin = 0
    self.damage = DAMAGE

    self.target_spin = TARGET_SPIN
    self.frame_timer = 0
    self.destroy_on_hit = false
    self.current_sword_sprite = "enter_0"

    self.start_x = x
    self.start_y = y
    self.left_x = SCREEN_WIDTH / 2 + LEFT_TARGET_OFFSET_X
    self.left_y = self.start_y + LEFT_TARGET_OFFSET_Y

    self.state = "move"
    self.decel_started = false
    self.last_graze_reset_apex = nil
    self.pause_timer = 0
    self.stop_timer = 0
    self.return_timer = 0

    self.scale_x = 2.25
    self.scale_y = 2.25

    self.sword_sprite = options.sprite or options.sword_sprite
    self.split_mode = options.split_mode or isHalfSwordSprite(self.sword_sprite)
    self.ignore_attacker_position = options.ignore_attacker_position == true

    if self.split_mode then
        self.sword_sprite = self.sword_sprite or "half_up"
        self.state = "split"
        self.rotation = dir or 0
        self.split_elapsed = 0
        self.split_graze_rotation_index = 0
        self.split_base_x = x
        self.split_base_y = y
        self.split_follow_arena_center = options.follow_arena_center == true
        self.split_motion_sign = options.split_motion_sign
            or (self.sword_sprite == "half_up" and -1 or 1)
        self.split_pulse_interval = options.split_pulse_interval_seconds
            or options.split_pulse_interval
            or SPLIT_PULSE_INTERVAL_SECONDS
        self.split_rotation_duration = options.split_rotation_duration_seconds
            or options.split_rotation_duration
            or SPLIT_ROTATION_DURATION_SECONDS
        self.split_closed_hold = options.split_closed_hold_seconds
            or options.split_closed_hold
            or SPLIT_CLOSED_HOLD_SECONDS
        self.split_pulse_distance = options.split_pulse_distance
            or (HALF_HITBOX_HEIGHT * self.scale_y * 0.5)
        self:setSwordSprite(self.sword_sprite)

        local hitbox_y = self.sword_sprite == "half_down" and HALF_DOWN_HITBOX_Y or HALF_UP_HITBOX_Y
        self:setHitbox(NORMAL_HITBOX_X, hitbox_y, NORMAL_HITBOX_WIDTH, HALF_HITBOX_HEIGHT)
    else
        self:setHitbox(NORMAL_HITBOX_X, NORMAL_HITBOX_Y, NORMAL_HITBOX_WIDTH, NORMAL_HITBOX_HEIGHT)
    end
end

function FlyingSword:getGrazeTension()
    local default_tp = super.getGrazeTension(self)
    local progress = clamp(math.abs(self.current_spin) / TARGET_SPIN, 0, 1)
    return default_tp + (GRAZE_TP_MAX - default_tp) * progress
end

function FlyingSword:onWaveSpawn(wave)
    super.onWaveSpawn(self, wave)

    if self.attacker and not self.ignore_attacker_position then
        local parent = self.parent or Game.battle
        local x, y = self.attacker:getRelativePos(self.attacker.width / 2, self.attacker.height / 2, parent)
        self:setPosition(x, y)
    end

    if self.split_mode then
        if self.split_follow_arena_center and Game.battle and Game.battle.arena then
            self.split_base_x, self.split_base_y = Game.battle.arena:getCenter()
            self:setPosition(self.split_base_x, self.split_base_y)
        else
            self.split_base_x = self.x
            self.split_base_y = self.y
        end
        return
    end

    self.start_x = self.x
    self.start_y = self.y
    self.left_x = SCREEN_WIDTH / 2 + LEFT_TARGET_OFFSET_X
    self.left_y = self.start_y + LEFT_TARGET_OFFSET_Y
end

function FlyingSword:setSwordSprite(sprite)
    if self.current_sword_sprite == sprite then
        return
    end

    self.current_sword_sprite = sprite
    self:setSprite("bullets/flying_sword/" .. sprite)
end

function FlyingSword:updateEnterSprite()
    if self.frame_timer >= ENTER_TOTAL_FRAMES then
        self:setSwordSprite("normal")
        return
    end

    local index = math.floor(self.frame_timer / ENTER_FRAME_DURATION) + 1
    self:setSwordSprite(ENTER_FRAMES[clamp(index, 1, #ENTER_FRAMES)])
end

function FlyingSword:updateMovePosition(move_timer)
    local cycle_frame = move_timer % ROUND_TRIP_FRAMES
    local t = cycle_frame / ROUND_TRIP_FRAMES
    local amount = math.sin(math.pi * t)
    amount = amount * amount

    self.x = self.start_x + (self.left_x - self.start_x) * amount
    self.y = self.start_y + (self.left_y - self.start_y) * amount
end

function FlyingSword:updateGrazeReset(move_timer)
    local apex_index = math.floor(move_timer / APEX_INTERVAL_FRAMES)
    if self.last_graze_reset_apex ~= apex_index then
        self.grazed = false
        self.last_graze_reset_apex = apex_index
    end
end

function FlyingSword:updateMoveRotation(move_timer)
    local decel_start = MOVE_TOTAL_FRAMES - SPIN_DECEL_FRAMES

    if move_timer >= decel_start then
        if not self.decel_started then
            self.decel_started = true
            self.decel_start_rotation = self.rotation
            self.decel_target_rotation = nextRotationInSpinDirection(self.rotation, LEFT_ROTATION)
            if self.on_catch_ready then
                self.on_catch_ready(self)
            end
        end

        local t = clamp((move_timer - decel_start) / SPIN_DECEL_FRAMES, 0, 1)
        local eased = easeOutCubic(t)
        local previous_rotation = self.rotation
        self.rotation = self.decel_start_rotation + (self.decel_target_rotation - self.decel_start_rotation) * eased
        self.current_spin = math.abs(self.rotation - previous_rotation) / math.max(DTMULT, 0.001)
        return
    end

    if self.frame_timer < SPIN_RAMP_START_FRAME then
        self.current_spin = 0
        return
    end

    local spin = self.target_spin
    if self.frame_timer < SPIN_RAMP_END_FRAME then
        local t = (self.frame_timer - SPIN_RAMP_START_FRAME) / (SPIN_RAMP_END_FRAME - SPIN_RAMP_START_FRAME)
        spin = self.target_spin * clamp(t, 0, 1)
    end

    self.current_spin = spin
    self.rotation = self.rotation + spin * DTMULT
end

function FlyingSword:pauseMovement(frames)
    self.pause_timer = math.max(self.pause_timer or 0, frames)
end

function FlyingSword:startStop()
    self.state = "stop"
    self.current_spin = 0
    self.grazed = false
    self.last_graze_reset_apex = math.floor(MOVE_TOTAL_FRAMES / APEX_INTERVAL_FRAMES)
    self.stop_timer = 0
    self.x = self.left_x
    self.y = self.left_y
    self.rotation = LEFT_ROTATION
end

function FlyingSword:updateStop()
    self.stop_timer = self.stop_timer + DTMULT
    self.x = self.left_x
    self.y = self.left_y
    self.rotation = LEFT_ROTATION

    if self.stop_timer >= STOP_FRAMES then
        self.state = "return"
        self.return_timer = 0
        self.return_start_x = self.x
        self.return_start_y = self.y
    end
end

function FlyingSword:updateReturn()
    self.return_timer = self.return_timer + DTMULT
    self.current_spin = 0

    local t = clamp(self.return_timer / RETURN_FRAMES, 0, 1)
    local eased = easeInCubic(t)
    self.x = self.return_start_x + (self.start_x - self.return_start_x) * eased
    self.y = self.return_start_y + (self.start_y - self.return_start_y) * eased
    self.rotation = LEFT_ROTATION

    if t >= 1 then
        if self.on_sword_destroyed then
            self.on_sword_destroyed(self)
        end
        self:remove()
    end
end

function FlyingSword:updateMove()
    self.frame_timer = self.frame_timer + DTMULT
    self:updateEnterSprite()

    local move_timer = math.max(self.frame_timer - MOVE_START_FRAME, 0)
    if move_timer >= MOVE_TOTAL_FRAMES then
        self:startStop()
        return
    end

    self:updateMovePosition(move_timer)
    self:updateGrazeReset(move_timer)
    self:updateMoveRotation(move_timer)
end

function FlyingSword:updateSplit()
    self.split_elapsed = self.split_elapsed + DT
    local rotation_duration = math.max(self.split_rotation_duration or SPLIT_ROTATION_DURATION_SECONDS, 0.001)
    local rotation_speed = TWO_PI / rotation_duration
    local rotation_index = math.floor(self.split_elapsed / rotation_duration)
    if rotation_index ~= (self.split_graze_rotation_index or 0) then
        self.grazed = false
        self.split_graze_rotation_index = rotation_index
    end

    self.current_spin = rotation_speed / 30
    self.rotation = (self.rotation or 0) + rotation_speed * DT

    if self.split_follow_arena_center and Game.battle and Game.battle.arena then
        self.split_base_x, self.split_base_y = Game.battle.arena:getCenter()
    end

    local interval = math.max(self.split_pulse_interval or SPLIT_PULSE_INTERVAL_SECONDS, 0.001)
    local closed_hold = math.max(self.split_closed_hold or SPLIT_CLOSED_HOLD_SECONDS, 0)
    local cycle_elapsed = self.split_elapsed % (interval + closed_hold)
    local amount

    if cycle_elapsed < closed_hold then
        amount = 0
    else
        local cycle_t = (cycle_elapsed - closed_hold) / interval
        if cycle_t < 0.5 then
            amount = easeOutCubic(cycle_t * 2)
        else
            amount = 1 - easeInCubic((cycle_t - 0.5) * 2)
        end
    end

    local offset = amount * (self.split_pulse_distance or 0) * (self.split_motion_sign or 1)
    local axis_x = -math.sin(self.rotation)
    local axis_y = math.cos(self.rotation)

    self.x = self.split_base_x + axis_x * offset
    self.y = self.split_base_y + axis_y * offset
end

function FlyingSword:update()
    if self.pause_timer > 0 then
        self.pause_timer = math.max(self.pause_timer - DTMULT, 0)
        self.current_spin = 0
        super.update(self)
        return
    end

    if self.state == "move" then
        self:updateMove()
    elseif self.state == "stop" then
        self:updateStop()
    elseif self.state == "return" then
        self:updateReturn()
    elseif self.state == "split" then
        self:updateSplit()
    end

    super.update(self)
end

return FlyingSword
