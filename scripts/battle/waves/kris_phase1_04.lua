local KrisPhase1_04, super = Class(Wave)

local FPS = 30
local WAVE_SECONDS = 8
local FAST_SPEED = 4 / FPS
local FOLLOWUP_SPEED_FACTOR = 0.9
local FOLLOWUP_MAX_DIAMOND_COUNT = 5
local FOLLOWUP_BOUNCE_SPEED_FACTORS = { 1, 0.9 }
local READY_TIME = 0.75
local THRUST_HOLD_TIME = 2
local RUDE_BUSTER_SPAWN_FRAMES_EARLY = 1
local RUDE_BUSTER_FALLBACK_X = 390
local APPEAR_SOUND = "grab"
local RUDE_BUSTER_APPEAR_SOUND = "kris_phase1_04_swing"
local RUDE_BUSTER_APPEAR_SOUND_LEAD_TIME = 0.25
local RUDE_BUSTER_APPEAR_SOUND_LEAD_FRAMES =
    math.max(math.floor(RUDE_BUSTER_APPEAR_SOUND_LEAD_TIME / FAST_SPEED + 0.5), 1)

local function getFrameCount(path)
    local frames = Assets.getFrames(path)
    return frames and #frames or 1
end

local function getAttackerBusterX(attacker)
    if not attacker or not attacker.parent then
        return RUDE_BUSTER_FALLBACK_X
    end

    return attacker.x - 50
end

function KrisPhase1_04:init()
    super.init(self)
    self.time = WAVE_SECONDS
    self.initial_buster_spawned = false
    self.initial_buster_sound_played = false
    self.kris_home_positions = {}
end

function KrisPhase1_04:getArenaCenterY()
    local arena = Game.battle and Game.battle.arena
    if arena then
        local _, y = arena:getCenter()
        return y
    end

    return (SCREEN_HEIGHT - 155) / 2 + 10
end

function KrisPhase1_04:getInitialRudeBusterOptions()
    return {
        followup_speed_factor = FOLLOWUP_SPEED_FACTOR,
        followup_max_diamond_count = FOLLOWUP_MAX_DIAMOND_COUNT,
        followup_bounce_speed_factors = FOLLOWUP_BOUNCE_SPEED_FACTORS,
    }
end

function KrisPhase1_04:playInitialRudeBusterSound()
    if self.initial_buster_sound_played then
        return
    end

    self.initial_buster_sound_played = true
    Assets.playSound(RUDE_BUSTER_APPEAR_SOUND)
end

function KrisPhase1_04:spawnInitialRudeBuster(attacker)
    if self.initial_buster_spawned then
        return
    end

    self.initial_buster_spawned = true
    local x = getAttackerBusterX(attacker)
    local y = self:getArenaCenterY()
    self:spawnBullet("kris_rude_buster", x, y, self:getInitialRudeBusterOptions())
end

function KrisPhase1_04:playThrust(attacker)
    if not attacker or not attacker.parent or not attacker.setAnimation then
        self:playInitialRudeBusterSound()
        self:spawnInitialRudeBuster(attacker)
        return
    end

    attacker:setAnimation({
        "thrust",
        function(sprite, wait)
            local frame_count = sprite.frames and #sprite.frames or getFrameCount("enemies/kris/thrust")
            local buster_spawn_frame = math.max(frame_count - RUDE_BUSTER_SPAWN_FRAMES_EARLY, 1)
            local buster_sound_frame =
                math.max(buster_spawn_frame - RUDE_BUSTER_APPEAR_SOUND_LEAD_FRAMES, 1)
            for frame = 1, frame_count do
                sprite:setFrame(frame)

                if frame == buster_sound_frame then
                    self:playInitialRudeBusterSound()
                end

                if frame == buster_spawn_frame then
                    self:spawnInitialRudeBuster(attacker)
                end

                if frame == frame_count then
                    wait(THRUST_HOLD_TIME)
                else
                    wait(FAST_SPEED)
                end
            end
        end,
        next = "idle",
    })
end

function KrisPhase1_04:onStart()
    Assets.playSound(APPEAR_SOUND, 0.8)

    local attacker_count = 0

    for _, attacker in ipairs(self:getAttackers()) do
        attacker_count = attacker_count + 1
        self.kris_home_positions[attacker] = {
            x = attacker.target_x or attacker.x,
            y = attacker.target_y or attacker.y,
        }

        if attacker.setAnimation then
            attacker:setAnimation({ "thrust_ready", FAST_SPEED, true })
        end
    end

    if attacker_count == 0 then
        self.timer:after(math.max(READY_TIME - RUDE_BUSTER_APPEAR_SOUND_LEAD_TIME, 0), function()
            self:playInitialRudeBusterSound()
        end)
    end

    self.timer:after(READY_TIME, function()
        if attacker_count == 0 then
            self:playThrust(nil)
            return
        end

        for _, attacker in ipairs(self:getAttackers()) do
            self:playThrust(attacker)
        end
    end)
end

function KrisPhase1_04:onEnd(death)
    for _, attacker in ipairs(self:getAttackers()) do
        local home = self.kris_home_positions and self.kris_home_positions[attacker]
        if home then
            attacker.target_x = home.x
            attacker.target_y = home.y
            attacker:setPosition(home.x, home.y)
        end
        if attacker.setAnimation then
            attacker:setAnimation("idle")
        end
    end

    return super.onEnd(self, death)
end

function KrisPhase1_04:update()
    super.update(self)
end

return KrisPhase1_04
