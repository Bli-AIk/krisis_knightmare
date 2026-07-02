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
local ROUND_TRIP_COUNT = 3.5
local MOVE_START_FRAME = SPIN_RAMP_END_FRAME
local MOVE_TOTAL_FRAMES = ROUND_TRIP_FRAMES * ROUND_TRIP_COUNT
local SPIN_DECEL_FRAMES = 16

local LEFT_TARGET_OFFSET_X = -260
local LEFT_TARGET_OFFSET_Y = 0
local LEFT_ROTATION = -math.pi / 2

local STOP_FRAMES = 3
local RETURN_FRAMES = 0.5 * 30

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

---@param x number # The X position of the bullet
---@param y number # The Y position of the bullet
---@param dir number # The dir (in radians) of the bullet
---@param spin number? # Unused legacy argument
function FlyingSword:init(x, y, dir, spin)
    super.init(self, x, y, "bullets/flying_sword/enter_0")

    self.physics.direction = dir or 0
    self.graphics.spin = 0
    self.damage = 100
    self.tp = 5

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
    self.stop_timer = 0
    self.return_timer = 0

    self.scale_x = 2.25
    self.scale_y = 2.25

    self:setHitbox(25, 4, 10, 54)
end

function FlyingSword:onWaveSpawn(wave)
    super.onWaveSpawn(self, wave)

    if self.attacker then
        local parent = self.parent or Game.battle
        local x, y = self.attacker:getRelativePos(self.attacker.width / 2, self.attacker.height / 2, parent)
        self:setPosition(x, y)
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
        self.rotation = self.decel_start_rotation + (self.decel_target_rotation - self.decel_start_rotation) * eased
        return
    end

    if self.frame_timer < SPIN_RAMP_START_FRAME then
        return
    end

    local spin = self.target_spin
    if self.frame_timer < SPIN_RAMP_END_FRAME then
        local t = (self.frame_timer - SPIN_RAMP_START_FRAME) / (SPIN_RAMP_END_FRAME - SPIN_RAMP_START_FRAME)
        spin = self.target_spin * clamp(t, 0, 1)
    end

    self.rotation = self.rotation + spin * DTMULT
end

function FlyingSword:startStop()
    self.state = "stop"
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
    self:updateMoveRotation(move_timer)
end

function FlyingSword:update()
    if self.state == "move" then
        self:updateMove()
    elseif self.state == "stop" then
        self:updateStop()
    elseif self.state == "return" then
        self:updateReturn()
    end

    super.update(self)
end

return FlyingSword
