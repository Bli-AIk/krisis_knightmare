local KrisPhase1_5, super = Class(Wave)

local FPS = 30
local SWORD_ENTER_AND_RAMP_FRAMES = 6
local SWORD_ROUND_TRIP_FRAMES = 2 * FPS + 16
local SWORD_ROUND_TRIP_COUNT = 3.5
local SWORD_STOP_FRAMES = 3
local SWORD_RETURN_FRAMES = 0.5 * FPS
local CATCH_FINISH_FRAMES = 2 * 5
local END_DELAY_FRAMES = 5

local CATCH_KRIS_OFFSET_X = 24

function KrisPhase1_5:init()
    super.init(self)
    self.time = (
        SWORD_ENTER_AND_RAMP_FRAMES
        + SWORD_ROUND_TRIP_FRAMES * SWORD_ROUND_TRIP_COUNT
        + SWORD_STOP_FRAMES
        + SWORD_RETURN_FRAMES
        + CATCH_FINISH_FRAMES
        + END_DELAY_FRAMES
    ) / FPS
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

function KrisPhase1_5:onStart()
    self.kris_home_positions = {}
    self.can_finish = false
    self.catch_ready_started = false
    self.catch_finish_started = false

    for _, attacker in ipairs(self:getAttackers()) do
        self.kris_home_positions[attacker] = {
            x = attacker.target_x or attacker.x,
            y = attacker.target_y or attacker.y,
        }
        attacker:setAnimation("flying_sword_disappear", function()
            moveAttackerAway(attacker)
        end)
    end

    local sword = self:spawnBullet("flying_sword", 320, 240, 0, math.rad(12))
    sword.on_catch_ready = function()
        self:startCatchSword()
    end
    sword.on_sword_destroyed = function()
        self:finishCatchSword()
    end
end

function KrisPhase1_5:startCatchSword()
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

function KrisPhase1_5:finishCatchSword()
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

function KrisPhase1_5:onEnd(death)
    for _, attacker in ipairs(self:getAttackers()) do
        local home = self.kris_home_positions and self.kris_home_positions[attacker]
        if home then
            moveAttackerTo(attacker, home.x, home.y)
        end
        attacker:setAnimation("appear")
    end

    return super.onEnd(self, death)
end

function KrisPhase1_5:canEnd()
    return self.can_finish
end

function KrisPhase1_5:update()
    super.update(self)
end

return KrisPhase1_5
