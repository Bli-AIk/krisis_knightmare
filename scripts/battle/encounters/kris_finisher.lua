local KrisFinisher, super = Class(Encounter)

local FINISHER_KRIS_X = 50
local FINISHER_KRIS_Y = 100
local FINISHER_KRIS_SOUL_X = 140 - FINISHER_KRIS_X
local FINISHER_KRIS_SOUL_Y = 170 - FINISHER_KRIS_Y
local FINISHER_KRIS_LAYER = BATTLE_LAYERS["battlers"]
local FINISHER_KRIS_ANIMATION_SPEED = 4 / 30
local FINISHER_KRIS_SCALE = 2

local FINISHER_STAR_WAVE_INTERVAL = 15 / 30
local FINISHER_STAR_FIRST_WAVE_COUNT = 12
local FINISHER_STAR_WAVE_COUNT = 24
local FINISHER_STAR_RADIUS_MARGIN = 18
local FINISHER_STAR_INITIAL_RADIUS_SCALE = 1.25
local FINISHER_STAR_MIN_RADIUS = 28
local FINISHER_STAR_TRAVEL_TIME = 3
local FINISHER_STAR_ORBIT_SPEED = math.rad(12)
local FINISHER_STAR_WAVE_ROTATION_STEP = math.rad(7.5)
local FINISHER_STOP_TP = 50

local FINISHER_MUSIC = "creepychase"
local FINISHER_MUSIC_PITCH = 1.2

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
    self:startFinisherStarEmitter(battle)

    return true
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
        return self.finisher_soul:getRelativePos(0, 0, battle)
    end

    if battle.soul and battle.soul.parent then
        return battle.soul:getRelativePos(0, 0, battle)
    end
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
    self.finisher_star_next_wave = FINISHER_STAR_WAVE_INTERVAL
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
        self.finisher_star_next_wave = self.finisher_star_next_wave + FINISHER_STAR_WAVE_INTERVAL
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
end

function KrisFinisher:onBattleEnd()
    self:stopFinisherStarEmitter()
end

return KrisFinisher
