local KrisFinisher, super = Class(Encounter)

local FINISHER_KRIS_X = 50
local FINISHER_KRIS_Y = 100
local FINISHER_KRIS_SOUL_X = 140 - FINISHER_KRIS_X
local FINISHER_KRIS_SOUL_Y = 170 - FINISHER_KRIS_Y
local FINISHER_KRIS_LAYER = BATTLE_LAYERS["battlers"]
local FINISHER_KRIS_ANIMATION_SPEED = 4 / 30
local FINISHER_KRIS_SCALE = 2

local FINISHER_STAR_WAVE_MAX_INTERVAL = 15 / 30
local FINISHER_STAR_WAVE_MIN_INTERVAL = 15 / 60
local FINISHER_STAR_INTERVAL_TRANSITION_TIME = 10
local FINISHER_STAR_FIRST_WAVE_COUNT = 12
local FINISHER_STAR_WAVE_COUNT = 24
local FINISHER_STAR_RADIUS_MARGIN = 18
local FINISHER_STAR_INITIAL_RADIUS_SCALE = 1.25
local FINISHER_STAR_MIN_RADIUS = 0
local FINISHER_STAR_TRAVEL_TIME = 3
local FINISHER_STAR_ORBIT_SPEED = math.rad(12)
local FINISHER_STAR_WAVE_ROTATION_STEP = math.rad(7.5)
local FINISHER_STOP_TP = 50
local FINISHER_PLAYER_DRIFT_SPEED = 4 / 2 * 0.75
local FINISHER_HURT_FLASH_MAX_ALPHA = 0.5
local FINISHER_HURT_FLASH_RISE_TIME = 0.08
local FINISHER_HURT_FLASH_FALL_TIME = 0.12 * 1.5

local FINISHER_MUSIC = "creepychase"
local FINISHER_MUSIC_PITCH = 1.2

local FinisherHurtFlash, hurt_flash_super = Class(Object)

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function FinisherHurtFlash:init()
    hurt_flash_super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = BATTLE_LAYERS["top"] + 1
    self.time = 0
    self.alpha = 0
end

function FinisherHurtFlash:restart()
    self.time = 0
    self.alpha = 0
    self.active = true
    self.visible = true
end

function FinisherHurtFlash:update()
    hurt_flash_super.update(self)

    self.time = self.time + DT
    if self.time <= FINISHER_HURT_FLASH_RISE_TIME then
        self.alpha = FINISHER_HURT_FLASH_MAX_ALPHA * clamp(
            self.time / FINISHER_HURT_FLASH_RISE_TIME,
            0,
            1
        )
        return
    end

    local fall_progress = (self.time - FINISHER_HURT_FLASH_RISE_TIME)
        / FINISHER_HURT_FLASH_FALL_TIME
    self.alpha = FINISHER_HURT_FLASH_MAX_ALPHA * (1 - clamp(fall_progress, 0, 1))

    if fall_progress >= 1 then
        self:remove()
    end
end

function FinisherHurtFlash:draw()
    Draw.setColor(1, 0, 0, self.alpha)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
end

function KrisFinisher:init()
    super.init(self)

    self.music = FINISHER_MUSIC
    self.background = false
    self.hide_world = true
    self.no_end_message = true

    self.finisher_stars = {}
    self.finisher_star_emitting = false
    self.finisher_star_elapsed = 0
    self.finisher_star_next_wave = 0
    self.finisher_star_wave_index = 0
    self.finisher_star_initial_radius = nil
    self.finisher_hurt_flash = nil
    self.finisher_status_message_restore = {}
end

function KrisFinisher:onBattleInit()
    local battle = Game.battle

    -- Keep the battle alive in a custom state so Kristal never opens the action menu.
    battle.state = "KRIS_FINISHER"
    battle.state_reason = nil

    self:hidePlayerUI(battle)
    battle.tension_bar:show()
    battle.music:play(self.music, nil, FINISHER_MUSIC_PITCH)
    self:createFinisherKris(battle)
    self:createWindowArena(battle)
    self:hideVesselDamageNumbers(battle)
    self:startFinisherStarEmitter(battle)

    return true
end

function KrisFinisher:triggerHurtFlash()
    local battle = Game.battle
    if not battle then
        return
    end

    if self.finisher_hurt_flash and self.finisher_hurt_flash.parent then
        self.finisher_hurt_flash:restart()
    else
        self.finisher_hurt_flash = FinisherHurtFlash()
        battle:addChild(self.finisher_hurt_flash)
    end
end

function KrisFinisher:hideVesselDamageNumbers(battle)
    for _, battler in ipairs(battle.party or {}) do
        if battler.chara and battler.chara.id == "vessel" then
            local original_status_message = battler.statusMessage
            self.finisher_status_message_restore[battler] = original_status_message
            battler.statusMessage = function(party_battler, message_type, arg, color, kill, delay)
                if message_type == "damage" then
                    if tonumber(arg) and tonumber(arg) > 0 then
                        self:triggerHurtFlash()
                    end
                    return
                elseif message_type == "msg" then
                    if arg == "down" or arg == "swoon" then
                        self:triggerHurtFlash()
                    end
                end

                return original_status_message(party_battler, message_type, arg, color, kill, delay)
            end
        end
    end
end

function KrisFinisher:restoreVesselDamageNumbers()
    for battler, original_status_message in pairs(self.finisher_status_message_restore) do
        if battler then
            battler.statusMessage = original_status_message
        end
    end
    self.finisher_status_message_restore = {}
end

function KrisFinisher:createFinisherKris(battle)
    local kris = Object(
        FINISHER_KRIS_X,
        FINISHER_KRIS_Y,
        108 * FINISHER_KRIS_SCALE,
        60 * FINISHER_KRIS_SCALE
    )
    kris.layer = FINISHER_KRIS_LAYER

    local actor = Registry.createActor("kris")
    local sprite = actor:createSprite()
    sprite:setScale(FINISHER_KRIS_SCALE)
    sprite:setAnimation({ "finisher_run", FINISHER_KRIS_ANIMATION_SPEED, true })
    sprite:setPosition(0, 0)
    kris:addChild(sprite)

    local kris_soul = Registry.createBullet(
        "finisher_soul",
        FINISHER_KRIS_SOUL_X,
        FINISHER_KRIS_SOUL_Y
    )
    kris:addChild(kris_soul)

    battle:addChild(kris)
    self.finisher_kris = kris
    self.finisher_soul = kris_soul
end

function KrisFinisher:getFinisherSoulPosition(battle)
    if self.finisher_soul and self.finisher_soul.parent then
        return self.finisher_soul:getRelativePos(
            self.finisher_soul.width / 2,
            self.finisher_soul.height / 2,
            battle
        )
    end

    if battle.soul and battle.soul.parent then
        return battle.soul:getRelativePos(0, 0, battle)
    end
end

function KrisFinisher:getFinisherStarWaveInterval(elapsed)
    elapsed = elapsed or self.finisher_star_elapsed

    local progress = FINISHER_STAR_INTERVAL_TRANSITION_TIME > 0
        and MathUtils.clamp(elapsed / FINISHER_STAR_INTERVAL_TRANSITION_TIME, 0, 1)
        or 1

    return FINISHER_STAR_WAVE_MAX_INTERVAL
        + (FINISHER_STAR_WAVE_MIN_INTERVAL - FINISHER_STAR_WAVE_MAX_INTERVAL) * progress
end

function KrisFinisher:startFinisherStarEmitter(battle)
    self.finisher_star_battle = battle
    self.finisher_star_emitting = true
    self.finisher_star_elapsed = 0
    self.finisher_star_next_wave = 0
    self.finisher_star_wave_index = 0
    self.finisher_star_initial_radius = nil

    if Game:getTension() >= FINISHER_STOP_TP then
        self:stopFinisherStarEmitter()
        return
    end

    self:spawnFinisherStarWave()
    self.finisher_star_next_wave = FINISHER_STAR_WAVE_MAX_INTERVAL
end

function KrisFinisher:spawnFinisherStarWave()
    if not self.finisher_star_emitting then
        return
    end

    local battle = self.finisher_star_battle
    local center_x, center_y = self:getFinisherSoulPosition(battle)
    if not battle or not center_x then
        return
    end

    if not self.finisher_star_initial_radius then
        self.finisher_star_initial_radius = math.max(
            (SCREEN_WIDTH - center_x + FINISHER_STAR_RADIUS_MARGIN) * FINISHER_STAR_INITIAL_RADIUS_SCALE,
            FINISHER_STAR_MIN_RADIUS
        )
    end

    -- Each wave begins from the same outer ring and shrinks independently.
    local radius = self.finisher_star_initial_radius
    local count = self.finisher_star_wave_index == 0
        and FINISHER_STAR_FIRST_WAVE_COUNT
        or FINISHER_STAR_WAVE_COUNT
    local base_angle = self.finisher_star_wave_index * FINISHER_STAR_WAVE_ROTATION_STEP
    local angle_step = (math.pi * 2) / count

    for index = 0, count - 1 do
        local angle = base_angle + index * angle_step
        local star = Registry.createBullet(
            "finisher_star",
            center_x + math.cos(angle) * radius,
            center_y + math.sin(angle) * radius,
            self.finisher_soul,
            angle,
            radius,
            FINISHER_STAR_MIN_RADIUS,
            FINISHER_STAR_TRAVEL_TIME,
            FINISHER_STAR_ORBIT_SPEED
        )
        battle:addChild(star)
        table.insert(self.finisher_stars, star)
    end

    self.finisher_star_wave_index = self.finisher_star_wave_index + 1
end

function KrisFinisher:clearFinisherStars()
    for _, star in ipairs(self.finisher_stars) do
        if star and star.parent then
            star:remove()
        end
    end
    self.finisher_stars = {}
end

function KrisFinisher:stopFinisherStarEmitter()
    if not self.finisher_star_emitting then
        return
    end

    self.finisher_star_emitting = false
    self:clearFinisherStars()
end

function KrisFinisher:updateFinisherStarEmitter()
    if not self.finisher_star_emitting then
        return
    end

    if Game:getTension() >= FINISHER_STOP_TP then
        self:stopFinisherStarEmitter()
        return
    end

    self.finisher_star_elapsed = self.finisher_star_elapsed + DT
    while self.finisher_star_elapsed >= self.finisher_star_next_wave do
        self:spawnFinisherStarWave()
        self.finisher_star_next_wave = self.finisher_star_next_wave
            + self:getFinisherStarWaveInterval(self.finisher_star_next_wave)
    end
end

function KrisFinisher:updatePlayerDrift()
    if Game:getTension() >= FINISHER_STOP_TP then
        return
    end

    local soul = Game.battle and Game.battle.soul
    if soul and soul.parent and soul.move then
        soul:move(-FINISHER_PLAYER_DRIFT_SPEED * DTMULT, 0)
    end
end

function KrisFinisher:hidePlayerUI(battle)
    battle.battle_ui.visible = false
    battle.battle_ui.active = false

    -- These are children of Battle rather than BattleUI, so hide them explicitly.
    battle.battle_ui.encounter_text.visible = false
    battle.battle_ui.choice_box.visible = false
    battle.battle_ui.short_act_text_1.visible = false
    battle.battle_ui.short_act_text_2.visible = false
    battle.battle_ui.short_act_text_3.visible = false

    for _, battler in ipairs(battle.party) do
        battler.visible = false
    end
end

function KrisFinisher:createWindowArena(battle)
    local arena = Arena(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, {
        { 0,            0 },
        { SCREEN_WIDTH, 0 },
        { SCREEN_WIDTH, SCREEN_HEIGHT },
        { 0,            SCREEN_HEIGHT },
    })
    arena.layer = BATTLE_LAYERS["arena"]
    -- Arena:onAdd normally spawns the green expanding border and afterimages.
    arena.onAdd = function() end
    arena.sprite.visible = false
    arena.sprite:setScale(1)
    arena.sprite.alpha = 1
    arena.sprite.rotation = 0
    battle.arena = arena
    battle:addChild(arena)

    battle:spawnSoul(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
    battle.soul.transitioning = false
    battle.soul.alpha = battle.soul.target_alpha or 1
    battle.soul:setPosition(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
end

function KrisFinisher:update()
    super.update(self)
    self:updateFinisherStarEmitter()
    self:updatePlayerDrift()
end

function KrisFinisher:onBattleEnd()
    self:stopFinisherStarEmitter()
    self:restoreVesselDamageNumbers()
    if self.finisher_hurt_flash and self.finisher_hurt_flash.parent then
        self.finisher_hurt_flash:remove()
    end
    self.finisher_hurt_flash = nil
end

return KrisFinisher
