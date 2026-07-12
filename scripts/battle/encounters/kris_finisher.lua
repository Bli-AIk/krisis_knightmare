local KrisFinisher, super = Class(Encounter)

local FINISHER_KRIS_X = 50
local FINISHER_KRIS_Y = 100
local FINISHER_KRIS_SOUL_X = 140 - FINISHER_KRIS_X
local FINISHER_KRIS_SOUL_Y = 170 - FINISHER_KRIS_Y
local FINISHER_KRIS_LAYER = BATTLE_LAYERS["battlers"]
local FINISHER_KRIS_ANIMATION_SPEED = 4 / 30
local FINISHER_KRIS_SCALE = 2

local FINISHER_MUSIC = "creepychase"
local FINISHER_MUSIC_PITCH = 1.2

function KrisFinisher:init()
    super.init(self)

    self.music = FINISHER_MUSIC
    self.background = false
    self.hide_world = true
    self.no_end_message = true
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

return KrisFinisher
