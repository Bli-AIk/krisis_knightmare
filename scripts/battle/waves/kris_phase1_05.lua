local KrisPhase1_05, super = Class(Wave)

local FPS = 30
local DISAPPEAR_FRAME_SECONDS = 4 / FPS
local SWORD_ENTER_AND_RAMP_FRAMES = 6
local SWORD_ROUND_TRIP_FRAMES = 2 * FPS + 16
local SWORD_ROUND_TRIP_COUNT = 3.5
local SWORD_STOP_FRAMES = 3
local SWORD_RETURN_FRAMES = 0.5 * FPS
local CATCH_FINISH_FRAMES = 2 * 5
local END_DELAY_FRAMES = 5
local DISAPPEAR_HOLD_FRAME = 1
local DISAPPEAR_HOLD_SECONDS = 1.25
local SWORD_SPAWN_DELAY_SECONDS = DISAPPEAR_FRAME_SECONDS * DISAPPEAR_HOLD_FRAME + DISAPPEAR_HOLD_SECONDS
local APPEAR_SOUND = "grab"
local BIG_SWORD_SWING_SOUND = "swing"

local CATCH_KRIS_OFFSET_X = 24

function KrisPhase1_05:init()
    super.init(self)
    self.time = (
        SWORD_ENTER_AND_RAMP_FRAMES
        + SWORD_ROUND_TRIP_FRAMES * SWORD_ROUND_TRIP_COUNT
        + SWORD_STOP_FRAMES
        + SWORD_RETURN_FRAMES
        + CATCH_FINISH_FRAMES
        + END_DELAY_FRAMES
    ) / FPS + SWORD_SPAWN_DELAY_SECONDS
end

local KRIS_FAR_X = 10000
local KRIS_FAR_Y = 10000

local function moveAttackerTo(attacker, x, y)
    attacker.target_x = x
    attacker.target_y = y
    attacker:setPosition(attacker.target_x, attacker.target_y)
end

local function moveAttackerAway(attacker)
    moveAttackerTo(attacker, KRIS_FAR_X, KRIS_FAR_Y)
end

local function playDisappearingWithHold(attacker, callback)
    attacker:setAnimation({
        "flying_sword_disappear",
        function(sprite, wait)
            local frame_count = sprite.frames and #sprite.frames or 0
            for frame = 1, frame_count do
                sprite:setFrame(frame)

                if frame == DISAPPEAR_HOLD_FRAME then
                    wait(DISAPPEAR_FRAME_SECONDS + DISAPPEAR_HOLD_SECONDS)
                else
                    wait(DISAPPEAR_FRAME_SECONDS)
                end
            end
        end,
        next = "idle",
    }, callback)
end

function KrisPhase1_05:spawnFlyingSword()
    Assets.playSound(BIG_SWORD_SWING_SOUND)
    local sword = self:spawnBullet("flying_sword", 320, 240, 0, math.rad(12))
    sword.on_catch_ready = function()
        self:startCatchSword()
    end
    sword.on_sword_destroyed = function()
        self:finishCatchSword()
    end
    return sword
end

function KrisPhase1_05:onStart()
    Assets.playSound(APPEAR_SOUND, 0.8)

    self.kris_home_positions = {}
    self.can_finish = false
    self.catch_ready_started = false
    self.catch_finish_started = false

    for _, attacker in ipairs(self:getAttackers()) do
        self.kris_home_positions[attacker] = {
            x = attacker.target_x or attacker.x,
            y = attacker.target_y or attacker.y,
        }
        playDisappearingWithHold(attacker, function()
            moveAttackerAway(attacker)
        end)
    end

    if SWORD_SPAWN_DELAY_SECONDS <= 0 then
        self:spawnFlyingSword()
    else
        self.timer:after(SWORD_SPAWN_DELAY_SECONDS, function()
            self:spawnFlyingSword()
        end)
    end
end

function KrisPhase1_05:startCatchSword()
    if self.catch_ready_started then
        return
    end
    self.catch_ready_started = true

    for _, attacker in ipairs(self:getAttackers()) do
        local home = self.kris_home_positions and self.kris_home_positions[attacker]
        local x = (home and home.x or attacker.x) + CATCH_KRIS_OFFSET_X
        local y = home and home.y or attacker.y
        moveAttackerTo(attacker, x, y)
        attacker:setAnimation("catch_sword_ready")
    end
end

function KrisPhase1_05:finishCatchSword()
    if self.catch_finish_started then
        return
    end
    self.catch_finish_started = true

    for _, attacker in ipairs(self:getAttackers()) do
        attacker:setAnimation("catch_sword_finish", function()
            moveAttackerAway(attacker)
        end)
    end

    self.timer:after((CATCH_FINISH_FRAMES + END_DELAY_FRAMES) / FPS, function()
        self.can_finish = true
    end)
end

function KrisPhase1_05:onEnd(death)
    Assets.playSound(APPEAR_SOUND, 0.8)

    for _, attacker in ipairs(self:getAttackers()) do
        local home = self.kris_home_positions and self.kris_home_positions[attacker]
        if home then
            moveAttackerTo(attacker, home.x, home.y)
        end
        attacker:setAnimation("appear")
    end

    return super.onEnd(self, death)
end

function KrisPhase1_05:canEnd()
    return self.can_finish
end

function KrisPhase1_05:update()
    super.update(self)
end

return KrisPhase1_05
