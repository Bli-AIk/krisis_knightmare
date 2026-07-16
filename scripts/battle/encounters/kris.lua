local Kris, super = Class(Encounter)

local RECHARGE_FULL_TENSION = 100
local RECHARGE_FULL_TURNS = 2
local RECHARGE_DEFAULT_TURNS = 1
local RECHARGE_TENSION_RATE = 120
local RECHARGE_PLATFORM_FADE_TIME = 0.3
local RECHARGE_LIGHT_SPRITE = "battle/light"
local RECHARGE_PLAYER_LIGHT_SPRITE = "battle/player_light"
local RECHARGE_DEFAULT_SOUL_SPRITE = "player/heart_dodge"
local RECHARGE_LIGHT_SCALE = 1
local RECHARGE_LIGHT_RADIUS_FACTOR = 0.45
local RECHARGE_MERCY_INTERVAL = 0.15
local RECHARGE_ACT_EFFECT_FRAME = 5
local RECHARGE_ACT_FRAME_DELAY = 1 / 15
local RECHARGE_SOUL_LAYER = BATTLE_LAYERS["above_bullets"] + 2
local RECHARGE_PLAYER_START_OFFSET_X = -28
local RECHARGE_PLAYER_START_OFFSET_Y = 0
local RECHARGE_SOUL_START_OFFSET_X = 28
local RECHARGE_SOUL_START_OFFSET_Y = 0
local RECHARGE_RETURN_TARGET_OFFSET_X = -2
local RECHARGE_RETURN_TARGET_OFFSET_Y = 1
local PLATFORM_SPRITE = "battle/backgrounds/kris_platform_adjusted"
local PLATFORM_LIGHT_SPRITE = "battle/backgrounds/kris_platform_light"
local FULL_MERCY = 100
local MERCY_FINALE_LAYER = BATTLE_LAYERS["ui"] - 2
local FAST_SPEED = 4 / 30
local MERCY_FINALE_MUSIC_FADE_TIME = 0.25
local MERCY_FINALE_MUSIC_END_WINDOW = 1
local MERCY_FINALE_ENEMY_TURN_DURATION = 5
local MERCY_FINALE_UI_FADE_TIME = 3
local MERCY_FINALE_SOUL_MOVE_SPEED = 4
local MERCY_FINALE_ATTACH_DISTANCE = 18
local MERCY_FINALE_REINSTALL_DELAY = 1
local MERCY_FINALE_LIGHT_FADE_TIME = 1
local MERCY_FINALE_POST_REINSTALL_WAIT = 5
local MERCY_FINALE_ANGRY_SHAKE_WAIT = 1
local MERCY_FINALE_NARRATION_WAIT = 1
local MERCY_FINALE_FIRST_TEXT_DURATION = 2
local MERCY_FINALE_MEMORY_TEXT_DELAY = 2
local MERCY_FINALE_MEMORY_TEXT_DURATION = 2
local MERCY_FINALE_FINAL_REINSTALL_DELAY = 2
local MERCY_FINALE_FINAL_AFTERIMAGE_WAIT = 2
local MERCY_FINALE_SOUL_GRAB_SPEED = 5 / 30
local MERCY_FINALE_SOUL_THROW_SPEED = FAST_SPEED
local MERCY_FINALE_SOUL_IDLE_WAIT = 3
local MERCY_FINALE_SOUL_AFTERIMAGE_INTERVAL = 0.08
local MERCY_FINALE_SOUL_AFTERIMAGE_ALPHA = 0.35
local MERCY_FINALE_SOUL_AFTERIMAGE_FADE_SPEED = 0.045
local MERCY_FINALE_SOUL_HEART_EXPAND_TIME = 0.18
local MERCY_FINALE_SOUL_HEART_HOLD_TIME = 1.15
local MERCY_FINALE_SOUL_HEART_FADE_TIME = 0.25
local MERCY_FINALE_SCREEN_SHAKE_AMOUNT = 2
local MERCY_FINALE_SCREEN_SHAKE_PERIOD = 0.25
local MERCY_FINALE_RIGHT_TEXT_OFFSET_X = 32
local MERCY_FINALE_PUT_BACK_FRAMES = {
    1, 2, 3,
    4, 5, 6, 7,
    4, 5, 6, 7,
    8, 9, 10, 11, 12,
}

-- These offsets are relative to the final center pose. They follow the
-- reference clip's upper-left grab into a diagonal return to center.
local MERCY_FINALE_SOUL_GRAB_OFFSETS = {
    { -65, -82 },
    { -66, -62 },
    { -43, -47 },
    { -19, -26 },
    { -3, -8 },
    { 0, 0 },
}

local MERCY_FINALE_SOUL_THROW_OFFSETS = {
    { 0, 0 },
    { 0, 0 },
    { 0, 0 },
    { 0, 0 },
    { 0, 0 },
    { 0, 0 },
    { 0, 0 },
    { 0, 0 },
    { 0, 0 },
    { 0, -4 },
    { 2, -8 },
    { 4, -5 },
    { 6, -8 },
    { 0, 0 },
}

-- Keep the body position aligned to the animation frame. This intentionally
-- uses stepped positions so the jump reads like the source sprite animation.
local function getSoulMotionOffset(offsets, frame)
    local frame_index = MathUtils.clamp(frame or 1, 1, #offsets)
    local offset = offsets[frame_index]
    return offset[1], offset[2]
end

local function isAttackAction(action)
    return action and (action.action == "ATTACK" or action.action == "AUTOATTACK")
end

local MercyFinaleActionBoxMask, action_box_mask_super = Class(Object)

function MercyFinaleActionBoxMask:init(action_box)
    action_box_mask_super.init(self, 0, action_box.box.y)

    self.action_box = action_box
    self.layer = 0.5
end

function MercyFinaleActionBoxMask:update()
    self.y = self.action_box.box.y
end

function MercyFinaleActionBoxMask:draw()
    Draw.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 2, 2, 209, 35)
end

local MercyFinaleActionBoxBorder, action_box_border_super = Class(Object)

function MercyFinaleActionBoxBorder:init(action_box)
    action_box_border_super.init(self, 0, action_box.box.y)

    self.action_box = action_box
    self.layer = 2
end

function MercyFinaleActionBoxBorder:update()
    self.y = self.action_box.box.y
end

function MercyFinaleActionBoxBorder:draw()
    local r, g, b, a = self.action_box.battler.chara:getColor()
    Draw.setColor(r, g, b, a)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, 1, 213, 1)
    love.graphics.line(1, 1, 1, 36)
    love.graphics.line(212, 1, 212, 36)
    Draw.setColor(1, 1, 1, 1)
end

local MercyFinaleMemoryLine, memory_line_super = Class(Object)

local MEMORY_LINE_SEGMENTS = 80
local MEMORY_LINE_BASE_WIDTH = 1
local MEMORY_LINE_MAX_WIDTH = 3
local MEMORY_LINE_NOISE_INTERVAL = 0.24
local MEMORY_LINE_NOISE_CELL_SPAN = 2
local MEMORY_LINE_SCROLL_SPEED = 500
local MEMORY_LINE_NOISE_TEXTURE_WIDTH = 128
local MEMORY_LINE_NOISE_TEXTURE_HEIGHT = 5
local MEMORY_LINE_NOISE_STRETCH_X = 4
local MEMORY_LINE_NOISE_ALPHA = 1

local function memoryLineNoise(index, time, offset, scroll)
    local segment_width = SCREEN_WIDTH / MEMORY_LINE_SEGMENTS
    local scroll_index = scroll / segment_width
    local cell = math.floor((index + scroll_index + offset) / MEMORY_LINE_NOISE_CELL_SPAN)
    local step = math.floor(time / MEMORY_LINE_NOISE_INTERVAL)
    local value = math.sin(cell * 17.123 + step * 41.731 + offset * 3.7) * 43758.5453
    return value - math.floor(value)
end

function MercyFinaleMemoryLine:init(finale)
    memory_line_super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.finale = finale
    self.time = 0
    self.scroll = 0
    self.center_y = SCREEN_HEIGHT / 2
    self.layer = BATTLE_LAYERS["ui"] - 1

    local noise_data = love.image.newImageData(
        MEMORY_LINE_NOISE_TEXTURE_WIDTH,
        MEMORY_LINE_NOISE_TEXTURE_HEIGHT
    )
    for y = 0, MEMORY_LINE_NOISE_TEXTURE_HEIGHT - 1 do
        for x = 0, MEMORY_LINE_NOISE_TEXTURE_WIDTH - 1 do
            local band = math.floor(y / 2)
            local value = math.sin((x + 1) * 19.17 + (band + 1) * 37.41) * 43758.5453
            value = value - math.floor(value)
            local alpha = value < 0.31 and MEMORY_LINE_NOISE_ALPHA or 0
            noise_data:setPixel(x, y, 0, 0, 0, alpha)
        end
    end

    self.noise_texture = love.graphics.newImage(noise_data)
    self.noise_texture:setFilter("nearest", "nearest")
    self.noise_texture:setWrap("repeat", "clamp")
    self.noise_source_width = SCREEN_WIDTH / MEMORY_LINE_NOISE_STRETCH_X
    self.noise_quad = love.graphics.newQuad(
        0,
        0,
        self.noise_source_width,
        MEMORY_LINE_NOISE_TEXTURE_HEIGHT,
        MEMORY_LINE_NOISE_TEXTURE_WIDTH,
        MEMORY_LINE_NOISE_TEXTURE_HEIGHT
    )
end

function MercyFinaleMemoryLine:update()
    self.time = self.time + DT
    self.scroll = (self.scroll + MEMORY_LINE_SCROLL_SPEED * DT) % SCREEN_WIDTH
    memory_line_super.update(self)
end

function MercyFinaleMemoryLine:draw()
    local old_shader = love.graphics.getShader()
    local old_blend, old_alpha_mode = love.graphics.getBlendMode()

    love.graphics.push()
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")

    love.graphics.setColor(1, 1, 1, 1)
    local center_y = self.center_y
    if self.finale and self.finale.origin_y then
        center_y = self.finale.origin_y
    end

    love.graphics.rectangle("fill", 0, center_y - 0.5, SCREEN_WIDTH, 1)

    local segment_width = SCREEN_WIDTH / MEMORY_LINE_SEGMENTS
    for index = 0, MEMORY_LINE_SEGMENTS - 1 do
        local x1 = index * segment_width
        local x2 = (index + 1) * segment_width + 0.5
        local width_a = MEMORY_LINE_BASE_WIDTH
            + memoryLineNoise(index, self.time, 2.1, self.scroll) * MEMORY_LINE_MAX_WIDTH
        local width_b = MEMORY_LINE_BASE_WIDTH
            + memoryLineNoise(index + 1, self.time, 7.4, self.scroll) * MEMORY_LINE_MAX_WIDTH
        local center_offset_a = (memoryLineNoise(index, self.time, 12.8, self.scroll) - 0.5) * 1.5
        local center_offset_b = (memoryLineNoise(index + 1, self.time, 18.6, self.scroll) - 0.5) * 1.5

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.polygon(
            "fill",
            x1,
            center_y + center_offset_a - width_a / 2,
            x2,
            center_y + center_offset_b - width_b / 2,
            x2,
            center_y + center_offset_b + width_b / 2,
            x1,
            center_y + center_offset_a + width_a / 2
        )

    end

    if self.noise_texture then
        local source_x = self.scroll / MEMORY_LINE_NOISE_STRETCH_X
        self.noise_quad:setViewport(
            source_x,
            0,
            self.noise_source_width,
            MEMORY_LINE_NOISE_TEXTURE_HEIGHT,
            MEMORY_LINE_NOISE_TEXTURE_WIDTH,
            MEMORY_LINE_NOISE_TEXTURE_HEIGHT
        )
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.draw(
            self.noise_texture,
            self.noise_quad,
            0,
            center_y - MEMORY_LINE_NOISE_TEXTURE_HEIGHT / 2,
            0,
            MEMORY_LINE_NOISE_STRETCH_X,
            1
        )
    end

    love.graphics.setShader(old_shader)
    love.graphics.setBlendMode(old_blend, old_alpha_mode)
    love.graphics.pop()
end

local MercyFinaleAfterimage, afterimage_super = Class(Object)

local MERCY_FINALE_AFTERIMAGE_ALPHA = 0.25
local MERCY_FINALE_AFTERIMAGE_AMPLITUDE = 1.5
local MERCY_FINALE_AFTERIMAGE_SPEED = 5

function MercyFinaleAfterimage:init(sprite)
    afterimage_super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.sprite = sprite
    self.time = 0
    self.alpha = MERCY_FINALE_AFTERIMAGE_ALPHA
    self.canvas = love.graphics.newCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)

    Draw.pushCanvas(self.canvas)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.clear()
    love.graphics.applyTransform(self.sprite:getFullTransform())
    Draw.setColor(self.sprite:getDrawColor())
    self.sprite:draw()
    love.graphics.pop()
    Draw.popCanvas()
end

function MercyFinaleAfterimage:update()
    self.time = self.time + DT
    self.x = math.sin(self.time * MERCY_FINALE_AFTERIMAGE_SPEED) * MERCY_FINALE_AFTERIMAGE_AMPLITUDE
    afterimage_super.update(self)
end

function MercyFinaleAfterimage:onRemove(parent)
    if self.canvas then
        self.canvas:release()
        self.canvas = nil
    end
    afterimage_super.onRemove(self, parent)
end

function MercyFinaleAfterimage:applyTransformTo(transform)
    if self.parent then
        transform:reset()
    end
    afterimage_super.applyTransformTo(self, transform)
end

function MercyFinaleAfterimage:draw()
    Draw.draw(self.canvas)
    afterimage_super.draw(self)
end

local MercyFinaleSoulHeart, soul_heart_super = Class(Object)

function MercyFinaleSoulHeart:init(x, y)
    soul_heart_super.init(self, x, y, 16, 16)

    self.timer = 0
    self.expand_time = MERCY_FINALE_SOUL_HEART_EXPAND_TIME
    self.hold_time = MERCY_FINALE_SOUL_HEART_HOLD_TIME
    self.fade_time = MERCY_FINALE_SOUL_HEART_FADE_TIME
    self.start_scale = 0.25
    self.end_scale = 4.5

    self.sprite = Sprite("player/heart")
    self.sprite:setOrigin(0.5, 0.5)
    self.sprite:setColor(1, 0, 0, 1)
    self.sprite:setScale(self.start_scale)
    self:addChild(self.sprite)
end

function MercyFinaleSoulHeart:update()
    self.timer = self.timer + DT

    local scale
    if self.timer <= self.expand_time then
        local progress = MathUtils.clamp(self.timer / self.expand_time, 0, 1)
        scale = self.start_scale + (self.end_scale - self.start_scale) * progress
    else
        scale = self.end_scale
    end

    local fade_start = self.expand_time + self.hold_time
    if self.timer <= fade_start then
        self.alpha = 1
    else
        local progress = MathUtils.clamp((self.timer - fade_start) / self.fade_time, 0, 1)
        self.alpha = 1 - progress
    end

    self.sprite:setScale(scale)
    self.sprite.alpha = self.alpha
    if self.alpha <= 0 then
        self:remove()
        return
    end

    soul_heart_super.update(self)
end

function Kris:init()
    super.init(self)

    self:applyLocalization()
    self.music = "never_forgetting"
    self.background = false
    self.hide_world = true

    self.kris_enemy = self:addEnemy("kris", 507, 239)

    self.recharge = nil
    self.recharge_soul = nil
    self.recharge_light_radius = nil
    self.recharge_player_light = nil
    self.mercy_finale = nil
    self.mercy_finale_started = false
    self.mercy_finale_active = false
    self.mercy_finale_ui_released = false
    self.mercy_finale_postlude = false
    self.mercy_finale_leave_requested = false
    self.mercy_finale_detached = false
    self.mercy_finale_ui_alpha = 1
    self.mercy_finale_ui_fades = nil
    self.mercy_finale_detached_phase = nil
    self.mercy_finale_detached_timer = 0
    self.mercy_finale_put_back_heart_shown = false
    self.mercy_finale_narration_texts = nil
    self.mercy_finale_memory_line = nil
    self.mercy_finale_afterimage = nil
    self.mercy_finale_soul_heart = nil
    self.mercy_finale_soul_afterimage_timer = 0
    self.mercy_finale_soul_afterimages = {}
    self.mercy_finale_screen_shaking = false
    self.mercy_finale_screen_shake_time = 0
    self.mercy_finale_screen_shake_restore = nil
    self.mercy_finale_suppress_narration = false
    self.mercy_finale_enemy_turn = false
    self.mercy_finale_enemy_turn_time = 0
    self.mercy_attack_increased = false
    self.mercy_attack_action_started = false
    self.mercy_before_actions = nil
end

function Kris:applyLocalization()
    self.text = Game:loc("* [name:chara:kris] slashes into the combat.", "enemy_kris_turn_1")
    self.mercy_finale_reinstall_text = Game:loc("REINSTALL", "act_kris_mercy_finale_reinstall")
    self.mercy_finale_do_what_text = Game:loc(
        "DO WHAT\nYOU SHALL DO",
        "act_kris_mercy_finale_do_what"
    )
    self.mercy_finale_promised_text = Game:loc(
        "YOU\nPROMISED",
        "act_kris_mercy_finale_promised"
    )
    self.mercy_finale_memorize_text = Game:loc(
        "MEMORIZE",
        "act_kris_mercy_finale_memorize"
    )
    self.mercy_finale_proceed_text = Game:loc(
        "PROCEED",
        "act_kris_mercy_finale_proceed"
    )
end

function Kris:getInitialEncounterText()
    if self.mercy_finale_suppress_narration then
        return ""
    end

    local enemy = Game.battle and Game.battle.enemies and Game.battle.enemies[1]
    if enemy and enemy.getEncounterText then
        return enemy:getEncounterText()
    end

    return self.text
end

function Kris:getEncounterText()
    if self.mercy_finale_suppress_narration then
        return ""
    end

    return super.getEncounterText(self)
end

function Kris:getKrisEnemy()
    if self.kris_enemy and self.kris_enemy.parent then
        return self.kris_enemy
    end

    local battle = Game.battle
    for _, enemy in ipairs(battle and battle.enemies or {}) do
        if enemy.actor and enemy.actor.id == "kris" then
            self.kris_enemy = enemy
            return enemy
        end
    end
end

function Kris:isFullMercy()
    local enemy = self:getKrisEnemy()
    local mercy = enemy and (enemy.mercy or 0) + (enemy.temporary_mercy or 0)
    return enemy and not enemy.done_state and mercy >= FULL_MERCY
end

function Kris:markKrisAttackMercyIncrease(enemy)
    if enemy == self:getKrisEnemy() then
        self.mercy_attack_increased = true
    end
end

function Kris:handleMercyFinaleMusic(battle)
    local music = battle and battle.music
    if not music then
        return
    end

    music:setLooping(false)

    if not music.source or not music:isPlaying() then
        return
    end

    local duration = music.source:getDuration()
    local position = music:tell()
    local remaining = duration and duration > 0 and duration - position or nil

    if remaining and remaining <= MERCY_FINALE_MUSIC_END_WINDOW then
        return
    end

    music:fade(0, MERCY_FINALE_MUSIC_FADE_TIME, function(current_music)
        current_music:stop()
    end)
end

function Kris:tryStartMercyFinale(reason)
    if self.mercy_finale_started or not self:isFullMercy() then
        return false
    end

    local battle = Game.battle
    local enemy = self:getKrisEnemy()
    if not battle or not enemy then
        return false
    end

    self.mercy_finale_started = true
    self.mercy_finale_active = true
    self.mercy_finale_ui_released = false
    self.mercy_finale_leave_requested = false
    self.mercy_finale_detached = false
    self.mercy_finale_ui_alpha = 1
    self.mercy_finale_ui_fades = nil
    self.mercy_finale_reason = reason
    self:handleMercyFinaleMusic(battle)

    enemy:setAnimation({ "twist", FAST_SPEED, true })

    self.mercy_finale = KrisMercyFinale(enemy, {
        layer = MERCY_FINALE_LAYER,
        on_black_screen = function()
            self:clearRechargeForMercyFinale()
        end,
        on_light_ready = function()
            self:releaseMercyFinaleToPlayerTurn()
        end,
    })
    battle:addChild(self.mercy_finale)
    return true
end

function Kris:startMercyFinaleProceedDebug()
    if self.mercy_finale_started then
        return
    end

    local battle = Game.battle
    local enemy = self:getKrisEnemy()
    if not battle or not enemy then
        return
    end

    self.mercy_finale_started = true
    self.mercy_finale_active = false
    self.mercy_finale_ui_released = true
    self.mercy_finale_postlude = true
    self.mercy_finale_detached = true
    self.mercy_finale_leave_requested = false
    self.mercy_finale_ui_alpha = 1
    self.mercy_finale_ui_fades = nil
    self.mercy_finale_detached_phase = "FINAL_AFTERIMAGE_WAIT"
    self.mercy_finale_detached_timer = 0
    self.mercy_finale_suppress_narration = true

    self.mercy_finale = KrisMercyFinale(enemy, {
        layer = MERCY_FINALE_LAYER,
    })
    battle:addChild(self.mercy_finale)
    battle:showUI()
    battle:clearMenuItems()
    battle:hideTargets()

    local vessel = battle:getPartyBattler("vessel")
    if vessel then
        vessel.visible = false
        vessel.active = false
    end

    self.mercy_finale:showFinalBlackScreen()
    self:showMercyFinaleProceed()
    battle:setState("MERCY_FINALE_DETACHED", "MERCY_FINALE_DEBUG")
    self.mercy_finale_suppress_narration = false
end

function Kris:releaseMercyFinaleToPlayerTurn()
    if self.mercy_finale_ui_released then
        return
    end

    self.mercy_finale_active = false
    self.mercy_finale_ui_released = true
    self.mercy_finale_postlude = true

    local enemy = self:getKrisEnemy()
    if enemy and enemy.enterMercyFinaleAftermath then
        enemy:enterMercyFinaleAftermath()
    end

    local battle = Game.battle
    if not battle then
        return
    end

    self.mercy_finale_suppress_narration = true
    if battle:getState() ~= "ACTIONSELECT" then
        battle:setState("ACTIONSELECT", "MERCY_FINALE")
    else
        battle:showUI()
    end
    self.mercy_finale_suppress_narration = false
end

function Kris:isMercyFinalePostlude()
    return self.mercy_finale_postlude == true
end

function Kris:isMercyFinaleDetached()
    return self.mercy_finale_detached == true
end

function Kris:requestMercyFinaleLeave(battler)
    if not self.mercy_finale_postlude or self.mercy_finale_detached then
        return
    end

    self.mercy_finale_leave_requested = true

    local battle = Game.battle
    local vessel_index = battle and battle:getPartyIndex("vessel")
    if vessel_index then
        battle.current_selecting = vessel_index
        local action_box = battle.battle_ui and battle.battle_ui.action_boxes[vessel_index]
        if action_box then
            action_box.box.y = -32
        end
    end

    local action = battle and battle:getActionBy(battler)
    if action then
        -- Leave has no text to advance, so finish the ACT directly. The
        -- detached state is entered after the normal ACT end animation.
        battle:finishAction(action)
    end
end

function Kris:addMercyFinaleUiFade(object)
    if not object then
        return
    end

    self.mercy_finale_ui_fades = self.mercy_finale_ui_fades or {}
    local fx = object:getFX("mercy_finale_detached_ui")
    if not fx then
        fx = object:addFX(AlphaFX(1), "mercy_finale_detached_ui")
    end
    table.insert(self.mercy_finale_ui_fades, fx)
end

function Kris:fadeMercyFinaleUi(battle)
    self.mercy_finale_ui_alpha = 1
    self.mercy_finale_ui_fades = {}

    if battle.battle_ui then
        for _, action_box in ipairs(battle.battle_ui.action_boxes or {}) do
            -- The display contains only the portrait, name, HP and their
            -- status panel. Keep the action buttons and battle text visible.
            self:addMercyFinaleUiFade(action_box.box)
        end
    end
end

function Kris:playMercyFinaleDetachedAnimation(battle)
    local enemy = self:getKrisEnemy()
    if enemy then
        enemy:setAnimation({
            "put_back",
            1 / 15,
            false,
            frames = { 1 },
            callback = function(sprite)
                sprite:setFrame(1)
                sprite:pause()
            end,
        })
    end

    local vessel = battle:getPartyBattler("vessel")
    if not vessel then
        return
    end

    vessel.defending = false
    if enemy then
        local defeat_layer = (enemy.layer or BATTLE_LAYERS["battlers"]) + 0.5
        if self.mercy_finale and defeat_layer >= self.mercy_finale.layer then
            defeat_layer = self.mercy_finale.layer - 0.5
        end
        vessel:setLayer(defeat_layer)
    end
    vessel:setAnimation({
        "battle/defeat",
        1 / 15,
        false,
        frames = { "1-10" },
        callback = function(sprite)
            -- Keep the final defeat pose even if the animation is interrupted.
            sprite:setFrame(10)
            sprite:pause()
        end,
    })
end

function Kris:enterMercyFinaleDetached()
    if self.mercy_finale_detached then
        return
    end

    local battle = Game.battle
    if not battle then
        return
    end

    self.mercy_finale_detached = true
    self.mercy_finale_leave_requested = false
    self.mercy_finale_enemy_turn = false
    self.mercy_finale_enemy_turn_time = 0
    self.mercy_finale_detached_phase = "MOVING"
    self.mercy_finale_detached_timer = 0
    self.mercy_finale_put_back_heart_shown = false
    self.mercy_finale_screen_shaking = false
    self.mercy_finale_screen_shake_time = 0
    if self.mercy_finale_memory_line and self.mercy_finale_memory_line.parent then
        self.mercy_finale_memory_line:remove()
    end
    self.mercy_finale_memory_line = nil
    if self.mercy_finale_afterimage and self.mercy_finale_afterimage.parent then
        self.mercy_finale_afterimage:remove()
    end
    self.mercy_finale_afterimage = nil
    if self.mercy_finale_soul_heart and self.mercy_finale_soul_heart.parent then
        self.mercy_finale_soul_heart:remove()
    end
    self.mercy_finale_soul_heart = nil
    self.mercy_finale_soul_afterimage_timer = 0
    battle:clearMenuItems()
    battle:hideTargets()
    if battle.arena then
        battle.arena:remove()
        battle.arena = nil
    end

    -- The engine clears this index after committing the final action, which
    -- makes ActionBox retract. Keep the vessel's action strip in its open
    -- position while the detached state is active.
    local vessel_index = battle:getPartyIndex("vessel")
    if vessel_index then
        battle.current_selecting = vessel_index
        local action_box = battle.battle_ui and battle.battle_ui.action_boxes[vessel_index]
        if action_box then
            action_box.box.y = -32
            action_box:addChild(MercyFinaleActionBoxMask(action_box))
            action_box:addChild(MercyFinaleActionBoxBorder(action_box))
        end
    end

    self:playMercyFinaleDetachedAnimation(battle)
    self:fadeMercyFinaleUi(battle)
    battle:setState("MERCY_FINALE_DETACHED", "MERCY_FINALE_LEAVE")
end

function Kris:updateMercyFinaleDetached()
    local battle = Game.battle
    if not battle then
        return
    end

    local vessel = battle:getPartyBattler("vessel")
    local phase = self.mercy_finale_detached_phase
    if self.mercy_finale_screen_shaking then
        self:updateMercyFinaleScreenShake(battle)
    end
    if vessel and phase == "MOVING" then
        local speed = MERCY_FINALE_SOUL_MOVE_SPEED
        if Input.down("cancel") then
            speed = speed / 2
        end

        local move_x, move_y = 0, 0
        if Input.down("left") then move_x = move_x - 1 end
        if Input.down("right") then move_x = move_x + 1 end
        if Input.down("up") then move_y = move_y - 1 end
        if Input.down("down") then move_y = move_y + 1 end

        if move_x ~= 0 or move_y ~= 0 then
            vessel:move(move_x, move_y, speed * DTMULT)
        end

        local x_margin = (vessel.width * vessel.scale_x) / 2
        local y_margin = vessel.height * vessel.scale_y
        vessel.x = MathUtils.clamp(vessel.x, x_margin, SCREEN_WIDTH - x_margin)
        vessel.y = MathUtils.clamp(vessel.y, y_margin, SCREEN_HEIGHT - 4)

        if self.mercy_finale then
            local target_x, target_y = self.mercy_finale:getEnemyOrigin()
            local light_x, light_y = self.mercy_finale:getDetachedLightOrigin()
            if MathUtils.dist(target_x, target_y, light_x, light_y) <= MERCY_FINALE_ATTACH_DISTANCE then
                self.mercy_finale_detached_phase = "ATTACHING"
            end
        end
    elseif vessel and phase == "ATTACHING" then
        local target_x, target_y = self.mercy_finale:getDetachedVesselTarget()
        local vessel_x, vessel_y = self.mercy_finale:getVesselOrigin()
        local move_x, move_y = target_x - vessel_x, target_y - vessel_y
        local distance = MathUtils.dist(0, 0, move_x, move_y)
        local step = MERCY_FINALE_SOUL_MOVE_SPEED * DTMULT
        if distance <= step then
            vessel:move(move_x, move_y)
            self.mercy_finale_detached_phase = "LOCKED"
            self.mercy_finale_detached_timer = 0
        elseif distance > 0 then
            vessel:move(move_x / distance, move_y / distance, step)
        end
    elseif vessel and (phase == "LOCKED" or phase == "PROMPT") then
        local target_x, target_y = self.mercy_finale:getDetachedVesselTarget()
        local vessel_x, vessel_y = self.mercy_finale:getVesselOrigin()
        vessel:move(target_x - vessel_x, target_y - vessel_y)

        if phase == "LOCKED" then
            self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
            if self.mercy_finale_detached_timer >= MERCY_FINALE_REINSTALL_DELAY then
                self:showMercyFinaleReinstallPrompt()
            end
        end
    elseif phase == "REINSTALLING" then
        self:showMercyFinalePutBackHeart()
    elseif phase == "POST_REINSTALL_WAIT" then
        self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
        if self.mercy_finale_detached_timer >= MERCY_FINALE_POST_REINSTALL_WAIT then
            local enemy = self:getKrisEnemy()
            if enemy then
                enemy:setAnimation({ "angry_shake", FAST_SPEED, true })
            end
            self.mercy_finale_detached_phase = "ANGRY_SHAKE_WAIT"
            self.mercy_finale_detached_timer = 0
        end
    elseif phase == "ANGRY_SHAKE_WAIT" then
        self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
        if self.mercy_finale_detached_timer >= MERCY_FINALE_ANGRY_SHAKE_WAIT then
            self:startMercyFinaleScreenShake(battle)
            self.mercy_finale_detached_phase = "NARRATION_WAIT"
            self.mercy_finale_detached_timer = 0
        end
    elseif phase == "NARRATION_WAIT" then
        self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
        if self.mercy_finale_detached_timer >= MERCY_FINALE_NARRATION_WAIT then
            self:showMercyFinaleFinalNarration()
        end
    elseif phase == "NARRATION" then
        self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
        if self.mercy_finale_detached_timer >= MERCY_FINALE_FIRST_TEXT_DURATION then
            self:clearMercyFinaleNarrationTexts()
            battle.battle_ui:clearEncounterText()
            self:showMercyFinaleMemoryLine(battle)
            self.mercy_finale_detached_phase = "MEMORY_WAIT"
            self.mercy_finale_detached_timer = 0
        end
    elseif phase == "MEMORY_WAIT" then
        self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
        if self.mercy_finale_detached_timer >= MERCY_FINALE_MEMORY_TEXT_DELAY then
            self:showMercyFinaleMemoryNarration()
        end
    elseif phase == "MEMORY_TEXT" then
        self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
        if self.mercy_finale_detached_timer >= MERCY_FINALE_MEMORY_TEXT_DURATION then
            self:clearMercyFinaleNarrationTexts()
            battle.battle_ui:clearEncounterText()
            self.mercy_finale_detached_phase = "MEMORY_DONE"
            self.mercy_finale_detached_timer = 0
        end
    elseif phase == "MEMORY_DONE" then
        self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
        if self.mercy_finale_detached_timer >= MERCY_FINALE_FINAL_REINSTALL_DELAY then
            self:startMercyFinaleFinalReinstall()
        end
    elseif phase == "FINAL_REINSTALLING" then
        self:showMercyFinalePutBackHeart()
    elseif phase == "FINAL_AFTERIMAGE_WAIT" then
        self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
        if self.mercy_finale_detached_timer >= MERCY_FINALE_FINAL_AFTERIMAGE_WAIT then
            self:showMercyFinaleProceed()
        end
    elseif phase == "SOUL_GRAB" then
        self:updateMercyFinaleSoulCutscene()
    elseif phase == "SOUL_IDLE" then
        self:updateMercyFinaleSoulCutscene()
        self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
        if self.mercy_finale_detached_timer >= MERCY_FINALE_SOUL_IDLE_WAIT then
            self:startMercyFinaleSoulThrow()
        end
    elseif phase == "SOUL_THROW" then
        self:updateMercyFinaleSoulCutscene()
    elseif phase == "SOUL_HEART" then
        self:updateMercyFinaleSoulCutscene()
        self.mercy_finale_detached_timer = self.mercy_finale_detached_timer + DT
        if self.mercy_finale_detached_timer >= MERCY_FINALE_SOUL_HEART_EXPAND_TIME
            + MERCY_FINALE_SOUL_HEART_HOLD_TIME
            + MERCY_FINALE_SOUL_HEART_FADE_TIME
        then
            local enemy = self:getKrisEnemy()
            if enemy then
                enemy:setAnimation({ "idle", 5 / 30, true })
            end
            self.mercy_finale_detached_phase = "SOUL_DONE"
        end
    end

    if self.mercy_finale_ui_fades then
        self.mercy_finale_ui_alpha = math.max(
            0,
            self.mercy_finale_ui_alpha - DT / MERCY_FINALE_UI_FADE_TIME
        )
        for _, fx in ipairs(self.mercy_finale_ui_fades) do
            fx.alpha = self.mercy_finale_ui_alpha
        end
    end
end

function Kris:startMercyFinaleScreenShake(battle)
    if self.mercy_finale_screen_shaking or not battle or not battle.graphics then
        return
    end

    local graphics = battle.graphics
    self.mercy_finale_screen_shaking = true
    self.mercy_finale_screen_shake_time = 0
    self.mercy_finale_screen_shake_restore = {
        shake_x = graphics.shake_x,
        shake_y = graphics.shake_y,
        shake_friction = graphics.shake_friction,
        shake_delay = graphics.shake_delay,
        shake_timer = graphics.shake_timer,
    }
end

function Kris:stopMercyFinaleScreenShake(battle)
    if not self.mercy_finale_screen_shaking then
        return
    end

    local graphics = battle and battle.graphics
    local restore = self.mercy_finale_screen_shake_restore
    if graphics and restore then
        graphics.shake_x = restore.shake_x
        graphics.shake_y = restore.shake_y
        graphics.shake_friction = restore.shake_friction
        graphics.shake_delay = restore.shake_delay
        graphics.shake_timer = restore.shake_timer
    end

    self.mercy_finale_screen_shaking = false
    self.mercy_finale_screen_shake_time = 0
    self.mercy_finale_screen_shake_restore = nil
end

function Kris:updateMercyFinaleScreenShake(battle)
    if not battle or not battle.graphics then
        return
    end

    self.mercy_finale_screen_shake_time = self.mercy_finale_screen_shake_time + DT

    local half_period = MERCY_FINALE_SCREEN_SHAKE_PERIOD / 2
    local pulse = math.floor(self.mercy_finale_screen_shake_time / half_period) % 2
    local diagonal = math.floor(self.mercy_finale_screen_shake_time / MERCY_FINALE_SCREEN_SHAKE_PERIOD) % 2
    local horizontal = pulse == 0 and -1 or 1
    local vertical
    if diagonal == 0 then
        vertical = pulse == 0 and 1 or -1
    else
        vertical = pulse == 0 and -1 or 1
    end

    local graphics = battle.graphics
    graphics.shake_x = horizontal * MERCY_FINALE_SCREEN_SHAKE_AMOUNT
    graphics.shake_y = vertical * MERCY_FINALE_SCREEN_SHAKE_AMOUNT
    graphics.shake_friction = 0
    graphics.shake_delay = math.huge
    graphics.shake_timer = 0
end

function Kris:showMercyFinalePutBackHeart()
    if self.mercy_finale_put_back_heart_shown then
        return
    end

    local battle = Game.battle
    local enemy = self:getKrisEnemy()
    if not battle or not enemy or not enemy.sprite or enemy.sprite.frame ~= 8 then
        return
    end

    local x, y = self.mercy_finale:getEnemyOrigin()
    local burst = HeartBurst(x - 2, y + 1, { 1, 0, 0 })
    burst.layer = (enemy.layer or BATTLE_LAYERS["battlers"]) + 0.1
    battle:addChild(burst)
    self.mercy_finale_put_back_heart_shown = true
end

function Kris:startMercyFinaleFinalReinstall()
    if self.mercy_finale_detached_phase ~= "MEMORY_DONE" then
        return
    end

    local enemy = self:getKrisEnemy()
    if not enemy then
        return
    end

    self.mercy_finale_detached_phase = "FINAL_REINSTALLING"
    self.mercy_finale_detached_timer = 0
    self.mercy_finale_put_back_heart_shown = false
    enemy:setAnimation({
        "put_back",
        FAST_SPEED,
        false,
        frames = { 12, 11, 10, 9, 8, 7 },
        callback = function(sprite)
            sprite:setFrame(7)
            sprite:pause()
            self:stopMercyFinaleScreenShake(Game.battle)
            self:showMercyFinaleAfterimage()
            self.mercy_finale_detached_phase = "FINAL_AFTERIMAGE_WAIT"
            self.mercy_finale_detached_timer = 0
        end,
    })
end

function Kris:showMercyFinaleAfterimage()
    local battle = Game.battle
    local enemy = self:getKrisEnemy()
    if not battle or not enemy or not enemy.sprite then
        return
    end

    if self.mercy_finale_afterimage and self.mercy_finale_afterimage.parent then
        self.mercy_finale_afterimage:remove()
    end

    local afterimage = MercyFinaleAfterimage(enemy.sprite)
    afterimage.layer = (enemy.layer or BATTLE_LAYERS["battlers"]) - 0.001
    battle:addChild(afterimage)
    self.mercy_finale_afterimage = afterimage
end

function Kris:getMercyFinaleSoulSceneTarget()
    return SCREEN_WIDTH / 2 + 10, SCREEN_HEIGHT * 0.43
end

function Kris:setMercyFinaleSoulSceneEnemyOrigin(enemy, x, y)
    if not enemy or not enemy.sprite then
        return
    end

    local sprite = enemy.sprite
    local scale_x = enemy.scale_x or 1
    local scale_y = enemy.scale_y or 1
    local local_x = (sprite.width / 2) + 4.5
    local local_y = (sprite.height / 2) + 7

    -- Battlers use a centered/bottom origin; convert the visible sprite anchor
    -- used by KrisMercyFinale back to the battler position.
    enemy.x = x - (local_x - enemy.width / 2) * scale_x
    enemy.y = y - (local_y - enemy.height) * scale_y
end

function Kris:clearMercyFinaleSoulCutsceneEffects()
    for _, image in ipairs(self.mercy_finale_soul_afterimages or {}) do
        if image.parent then
            image:remove()
        end
    end
    self.mercy_finale_soul_afterimages = {}

    if self.mercy_finale_soul_heart and self.mercy_finale_soul_heart.parent then
        self.mercy_finale_soul_heart:remove()
    end
    self.mercy_finale_soul_heart = nil
end

function Kris:spawnMercyFinaleSoulAfterimage()
    local battle = Game.battle
    local enemy = self:getKrisEnemy()
    if not battle or not enemy or not enemy.parent then
        return
    end

    local image = AfterImage(
        enemy,
        MERCY_FINALE_SOUL_AFTERIMAGE_ALPHA,
        MERCY_FINALE_SOUL_AFTERIMAGE_FADE_SPEED
    )
    image:addFX(ColorMaskFX({ 0.2, 0, 0 }, 1))
    image.layer = (enemy.layer or BATTLE_LAYERS["battlers"]) - 0.001
    battle:addChild(image)
    table.insert(self.mercy_finale_soul_afterimages, image)
end

function Kris:updateMercyFinaleSoulCutscene()
    local enemy = self:getKrisEnemy()
    if not enemy or not enemy.sprite then
        return
    end

    local target_x, target_y = self:getMercyFinaleSoulSceneTarget()
    local phase = self.mercy_finale_detached_phase
    local offset_x, offset_y = 0, 0

    if phase == "SOUL_GRAB" then
        local frame = enemy.sprite.frame or 1
        offset_x, offset_y = getSoulMotionOffset(
            MERCY_FINALE_SOUL_GRAB_OFFSETS,
            frame
        )
        self:setMercyFinaleSoulSceneEnemyOrigin(
            enemy,
            target_x + offset_x,
            target_y + offset_y
        )

        if frame >= 3 then
            self.mercy_finale_soul_afterimage_timer = self.mercy_finale_soul_afterimage_timer + DT
            while self.mercy_finale_soul_afterimage_timer >= MERCY_FINALE_SOUL_AFTERIMAGE_INTERVAL do
                self.mercy_finale_soul_afterimage_timer = self.mercy_finale_soul_afterimage_timer
                    - MERCY_FINALE_SOUL_AFTERIMAGE_INTERVAL
                self:spawnMercyFinaleSoulAfterimage()
            end
        else
            self.mercy_finale_soul_afterimage_timer = 0
        end
    elseif phase == "SOUL_THROW" then
        local frame = enemy.sprite.frame or 1
        offset_x, offset_y = getSoulMotionOffset(
            MERCY_FINALE_SOUL_THROW_OFFSETS,
            frame
        )
        self:setMercyFinaleSoulSceneEnemyOrigin(
            enemy,
            target_x + offset_x,
            target_y + offset_y
        )
    else
        self:setMercyFinaleSoulSceneEnemyOrigin(enemy, target_x, target_y)
    end
end

function Kris:startMercyFinaleSoulCutscene()
    if self.mercy_finale_detached_phase ~= "PROCEED" then
        return
    end

    local battle = Game.battle
    local enemy = self:getKrisEnemy()
    if not battle or not enemy or not self.mercy_finale then
        return
    end

    self:clearMercyFinaleNarrationTexts()
    self:clearMercyFinaleSoulCutsceneEffects()
    if battle.battle_ui then
        battle.battle_ui:clearEncounterText()
    end

    self.mercy_finale:hideFinalBlackScreen()
    self.mercy_finale:setEnemyAboveBlackScreen(false)
    self.mercy_finale_ui_alpha = 1
    for _, fx in ipairs(self.mercy_finale_ui_fades or {}) do
        fx.alpha = 1
    end

    local target_x, target_y = self:getMercyFinaleSoulSceneTarget()
    local first_offset = MERCY_FINALE_SOUL_GRAB_OFFSETS[1]
    self.mercy_finale_detached_phase = "SOUL_GRAB"
    self.mercy_finale_detached_timer = 0
    self.mercy_finale_soul_afterimage_timer = 0
    enemy.visible = true
    enemy.active = true
    self:setMercyFinaleSoulSceneEnemyOrigin(
        enemy,
        target_x + first_offset[1],
        target_y + first_offset[2]
    )
    enemy:setAnimation({
        "grab_soul",
        MERCY_FINALE_SOUL_GRAB_SPEED,
        false,
        callback = function(sprite)
            -- Hold throw_soul_1 during the center wait. This custom animation
            -- has no `next`, so it cannot fall back to the actor's idle pose.
            sprite:setAnimation({
                "throw_soul",
                MERCY_FINALE_SOUL_THROW_SPEED,
                false,
                frames = { 1 },
            })
            sprite:setFrame(1)
            sprite:pause()
            self.mercy_finale_detached_phase = "SOUL_IDLE"
            self.mercy_finale_detached_timer = 0
        end,
    })
end

function Kris:startMercyFinaleSoulThrow()
    if self.mercy_finale_detached_phase ~= "SOUL_IDLE" then
        return
    end

    local enemy = self:getKrisEnemy()
    if not enemy then
        return
    end

    self.mercy_finale_detached_phase = "SOUL_THROW"
    self.mercy_finale_detached_timer = 0
    enemy:setAnimation({
        "throw_soul",
        MERCY_FINALE_SOUL_THROW_SPEED,
        false,
        frames = { "1-14" },
        callback = function(sprite)
            sprite:setFrame(14)
            sprite:pause()
            self:spawnMercyFinaleSoulHeart()
            self.mercy_finale_detached_phase = "SOUL_HEART"
            self.mercy_finale_detached_timer = 0
        end,
    })
end

function Kris:spawnMercyFinaleSoulHeart()
    local battle = Game.battle
    local enemy = self:getKrisEnemy()
    if not battle or not enemy or not self.mercy_finale then
        return
    end

    local x, y = self.mercy_finale:getEnemyOrigin()
    local heart = MercyFinaleSoulHeart(x - 22, y - 16)
    heart.layer = (enemy.layer or BATTLE_LAYERS["battlers"]) + 0.1
    battle:addChild(heart)
    self.mercy_finale_soul_heart = heart
end

function Kris:clearMercyFinaleNarrationTexts()
    for _, text in ipairs(self.mercy_finale_narration_texts or {}) do
        if text.parent then
            text:remove()
        end
    end
    self.mercy_finale_narration_texts = nil
end

function Kris:showMercyFinaleNarrationTexts(left_value, right_value)
    local battle = Game.battle
    if not battle or not battle.battle_ui then
        return false
    end

    self:clearMercyFinaleNarrationTexts()

    local encounter_text = battle.battle_ui.encounter_text
    local left_x = encounter_text.x + encounter_text.text_x
    local text_y = encounter_text.y + encounter_text.text_y
    local right_edge = SCREEN_WIDTH - 30 - MERCY_FINALE_RIGHT_TEXT_OFFSET_X
    local text_layer = encounter_text.layer + 1
    local style_text = function(text)
        return "[instant][style:none][color:00ff00]"
            .. text
            .. "[color:reset][style:reset]"
    end

    local left_text = DialogueText(
        style_text(left_value),
        left_x,
        text_y,
        SCREEN_WIDTH - left_x,
        SCREEN_HEIGHT,
        {
            font = "main_mono",
            style = "none",
            color = { 0, 1, 0, 1 },
            wrap = false,
            line_offset = 0,
        }
    )
    left_text.skippable = false
    left_text.can_advance = false
    left_text.auto_advance = false
    left_text.layer = text_layer
    battle:addChild(left_text)

    local right_text = DialogueText(
        style_text(right_value),
        0,
        text_y,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        {
            font = "main_mono",
            style = "none",
            color = { 0, 1, 0, 1 },
            wrap = false,
            line_offset = 0,
            align = "left",
        }
    )
    right_text.skippable = false
    right_text.can_advance = false
    right_text.auto_advance = false
    right_text.layer = text_layer
    battle:addChild(right_text)

    -- Position using the width after the language hook has added CJK spacing.
    local right_width = right_text:getTextWidth()
    right_text.x = math.max(30, right_edge - right_width)

    self.mercy_finale_narration_texts = { left_text, right_text }
    return true
end

function Kris:showMercyFinaleMemoryLine(battle)
    if self.mercy_finale_memory_line and self.mercy_finale_memory_line.parent then
        return
    end

    local line = MercyFinaleMemoryLine(self.mercy_finale)
    line.layer = (self.mercy_finale and self.mercy_finale.layer or BATTLE_LAYERS["ui"] - 2) + 0.005
    battle:addChild(line)
    self.mercy_finale_memory_line = line
end

function Kris:showMercyFinaleFinalNarration()
    if self.mercy_finale_detached_phase ~= "NARRATION_WAIT" then
        return
    end

    local battle = Game.battle
    if not battle or not battle.battle_ui then
        return
    end

    battle.battle_ui:clearEncounterText()
    if self:showMercyFinaleNarrationTexts(
        self.mercy_finale_do_what_text,
        self.mercy_finale_promised_text
    ) then
        self.mercy_finale_detached_phase = "NARRATION"
        self.mercy_finale_detached_timer = 0
    end
end

function Kris:showMercyFinaleMemoryNarration()
    if self.mercy_finale_detached_phase ~= "MEMORY_WAIT" then
        return
    end

    local battle = Game.battle
    if not battle or not battle.battle_ui then
        return
    end

    battle.battle_ui:clearEncounterText()
    if self:showMercyFinaleNarrationTexts(
        self.mercy_finale_memorize_text,
        self.mercy_finale_memorize_text
    ) then
        self.mercy_finale_detached_phase = "MEMORY_TEXT"
        self.mercy_finale_detached_timer = 0
    end
end

function Kris:showMercyFinaleProceed()
    if self.mercy_finale_detached_phase ~= "FINAL_AFTERIMAGE_WAIT" then
        return
    end

    local battle = Game.battle
    if not battle or not battle.battle_ui or not self.mercy_finale then
        return
    end

    self:clearMercyFinaleNarrationTexts()
    battle.battle_ui:clearEncounterText()

    if self.mercy_finale_memory_line and self.mercy_finale_memory_line.parent then
        self.mercy_finale_memory_line:remove()
    end
    self.mercy_finale_memory_line = nil

    if self.mercy_finale_afterimage and self.mercy_finale_afterimage.parent then
        self.mercy_finale_afterimage:remove()
    end
    self.mercy_finale_afterimage = nil

    self.mercy_finale:setEnemyAboveBlackScreen(false)
    self.mercy_finale:showFinalBlackScreen()

    local proceed_spacing = self.mercy_finale_proceed_text == "继续前进" and 2 or 8
    local proceed_text = DialogueText(
        "[instant][voice:none][style:none][color:00ff00]"
            .. "[image:player/heart:-16:1:2:2][spacing:"
            .. proceed_spacing
            .. "][shake:1]"
            .. self.mercy_finale_proceed_text
            .. "[color:reset][style:reset]",
        0,
        SCREEN_HEIGHT / 2 - 8,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        {
            font = "main_mono",
            style = "none",
            color = { 0, 1, 0, 1 },
            wrap = false,
            line_offset = 0,
            align = "center",
        }
    )
    proceed_text.skippable = false
    proceed_text.can_advance = false
    proceed_text.auto_advance = false
    proceed_text.layer = self.mercy_finale.layer + 1
    battle:addChild(proceed_text)
    for _, sprite in ipairs(proceed_text.sprites) do
        sprite:setColor(1, 0, 0, 1)
    end
    self.mercy_finale_narration_texts = { proceed_text }
    self.mercy_finale_detached_phase = "PROCEED"
    self.mercy_finale_detached_timer = 0
end

function Kris:showMercyFinaleReinstallPrompt()
    if self.mercy_finale_detached_phase ~= "LOCKED" then
        return
    end

    local battle = Game.battle
    if not battle or not battle.battle_ui then
        return
    end

    battle:infoText("[instant][style:none][color:00ff00]" .. self.mercy_finale_reinstall_text .. "[color:reset][style:reset]")
    self.mercy_finale_detached_phase = "PROMPT"
end

function Kris:handleMercyFinaleDetachedInput(key)
    if not Input.isConfirm(key) then
        return
    end

    if self.mercy_finale_detached_phase == "PROCEED" then
        Input.clear("confirm", true)
        self:startMercyFinaleSoulCutscene()
        return
    end

    if self.mercy_finale_detached_phase ~= "PROMPT" then
        return
    end

    local battle = Game.battle
    local vessel = battle and battle:getPartyBattler("vessel")
    local enemy = self:getKrisEnemy()
    if not battle or not vessel or not enemy then
        return
    end

    Input.clear("confirm", true)
    self.mercy_finale_detached_phase = "REINSTALLING"
    self.mercy_finale_detached_timer = 0
    self.mercy_finale_put_back_heart_shown = false
    battle.battle_ui:clearEncounterText()
    vessel.visible = false
    vessel.active = false

    enemy:setAnimation({
        "put_back",
        FAST_SPEED,
        false,
        frames = MERCY_FINALE_PUT_BACK_FRAMES,
        callback = function(sprite)
            sprite:setFrame(12)
            sprite:pause()
            self.mercy_finale_detached_phase = "POST_REINSTALL_WAIT"
            self.mercy_finale_detached_timer = 0
            if self.mercy_finale then
                -- Keep Kris visible while the light mask fades away.
                self.mercy_finale:setEnemyAboveBlackScreen(true)
                self.mercy_finale:startPlayerLightFade(MERCY_FINALE_LIGHT_FADE_TIME)
            end
        end,
    })
end

function Kris:clearMercyFinaleHighlights()
    local battle = Game.battle
    if not battle then
        return
    end

    for _, battler in ipairs(battle.enemies or {}) do
        if battler.highlight then
            battler.highlight.amount = 0
        end
        battler.flash_timer = 0
        battler.last_highlighted = false
    end

    for _, battler in ipairs(battle.party or {}) do
        if battler.highlight then
            battler.highlight.amount = 0
        end
        battler.flash_timer = 0
        battler.last_highlighted = false
    end
end

function Kris:resetMercyFinalePlayerSprites()
    local battle = Game.battle
    if not battle then
        return
    end

    for _, battler in ipairs(battle.party or {}) do
        battler.defending = false
        if battler.sprite and battler.sprite.anim ~= "battle/idle" then
            battler:resetSprite()
        end
    end
end

function Kris:startMercyFinaleEnemyTurn()
    local battle = Game.battle
    if not battle then
        return
    end

    self.mercy_finale_enemy_turn = true
    self.mercy_finale_enemy_turn_time = MERCY_FINALE_ENEMY_TURN_DURATION

    -- Use a private state so the engine does not create an arena or start a
    -- wave. The five-second interval is still a real enemy-turn phase for
    -- the postlude, with all player input ignored by Battle's state handler.
    if battle.battle_ui then
        battle.battle_ui:clearEncounterText()
    end
    battle:hideTargets()
    if battle.arena then
        battle.arena:remove()
        battle.arena = nil
    end
    battle.current_selecting = 0
    battle:setState("MERCY_FINALE_ENEMY_TURN", "MERCY_FINALE")
end

function Kris:finishMercyFinaleEnemyTurn()
    local battle = Game.battle
    if not battle then
        return
    end

    self.mercy_finale_enemy_turn = false
    self.mercy_finale_enemy_turn_time = 0

    local enemy = self:getKrisEnemy()
    if enemy then
        enemy:resetSprite()
    end

    for _, battler in ipairs(battle.party or {}) do
        local was_defending = battler.defending
        battler.defending = false
        if was_defending
            or (battler.sprite and battler.sprite.anim == "battle/defend")
        then
            battler:resetSprite()
        end
    end

    -- nextTurn() is entered synchronously by ACTIONSELECT while the
    -- narration guard is active, so this turn remains textless.
    self.mercy_finale_suppress_narration = true
    battle:setState("ACTIONSELECT", "MERCY_FINALE_RETURN")
    self.mercy_finale_suppress_narration = false
end

function Kris:onBattleStart()
    local initial_tp = Game:getConfig("krisisInitialTP")
    if initial_tp ~= nil then
        initial_tp = tonumber(initial_tp)
        if initial_tp then
            Game:setTension(initial_tp)
        end
    end

    local initial_mercy = Game:getConfig("krisisInitialMercy")
    if initial_mercy ~= nil then
        local enemy = self:getKrisEnemy()
        if enemy then
            enemy.mercy = MathUtils.clamp(tonumber(initial_mercy) or 0, 0, 100)
        end
    end

    for _, enemy in ipairs(Game.battle.enemies or {}) do
        if enemy.updateRechargeActTPCost then
            enemy:updateRechargeActTPCost()
        end
    end

    if Mod and Mod.isKrisisRunProceed and Mod:isKrisisRunProceed() then
        self:startMercyFinaleProceedDebug()
        return
    end

    if Game:getConfig("krisisDebugRechargeRadial") then
        self:spawnRechargeRadialBurst(Game.battle.party[1], {
            capture = Game:getConfig("krisisDebugRechargeRadialCapture"),
            quit_after_capture = Game:getConfig("krisisDebugRechargeRadialQuit"),
        })
    end

    if self:isFullMercy() then
        self:tryStartMercyFinale("battle_start")
    end
end

function Kris:onBattleEnd()
    self.finisher_battle_pending = true
    self:clearRecharge(true)

    for _, enemy in ipairs(Game.battle.enemies or {}) do
        if enemy.clearHeartbeatSpeedBoost then
            enemy:clearHeartbeatSpeedBoost()
        end
    end
end

function Kris:startFinisherBattle()
    return self.finisher_battle_pending == true
end

function Kris:onTurnEnd()
    if not self.mercy_finale_started and self:isFullMercy() then
        self:tryStartMercyFinale("turn_end")
        return true
    end

    local recharge = self.recharge
    if recharge and not recharge.draining and not recharge.expiring then
        recharge.turns_remaining = math.max((recharge.turns_remaining or 1) - 1, 0)
        if recharge.turns_remaining <= 0 then
            recharge.expiring = true
            if recharge.enemy and recharge.enemy.finishRechargeWavePhaseAdvance then
                recharge.enemy:finishRechargeWavePhaseAdvance()
            end
        end
    end
end

function Kris:onActionsEnd()
    if self.mercy_finale_active then
        return true
    end

    if self.mercy_finale_leave_requested then
        self:enterMercyFinaleDetached()
        return true
    end

    if self.mercy_finale_postlude then
        self:startMercyFinaleEnemyTurn()
        return true
    end

    local enemy = self:getKrisEnemy()
    local mercy_increased = self.mercy_attack_increased
    if not mercy_increased
        and self.mercy_attack_action_started
        and self.mercy_before_actions ~= nil
        and enemy
    then
        mercy_increased = (enemy.mercy or 0) > self.mercy_before_actions
    end

    if mercy_increased and self:isFullMercy()
        and self:tryStartMercyFinale("attack")
    then
        return true
    end
end

function Kris:beforeStateChange(old, new, reason)
    if self.mercy_finale_active then
        return true
    end
end

function Kris:onActionsStart()
    self.mercy_attack_increased = false
    self.mercy_attack_action_started = false

    local enemy = self:getKrisEnemy()
    self.mercy_before_actions = enemy and enemy.mercy or nil

    local battle = Game.battle
    for _, action in pairs(battle and battle.character_actions or {}) do
        if isAttackAction(action) then
            self.mercy_attack_action_started = true
            break
        end
    end
end

function Kris:onStateChange(old, new, reason)
    if new == "ATTACKING" then
        local battle = Game.battle
        self.mercy_attack_action_started = self.mercy_attack_action_started
            or (battle and #battle.attackers > 0 or false)
    elseif new == "ACTIONSELECT" then
        self:beginRechargeDrain()
        if self.mercy_finale_postlude then
            self:resetMercyFinalePlayerSprites()
            self:clearMercyFinaleHighlights()
        end
    elseif new == "DEFENDINGBEGIN" or new == "DEFENDING" then
        self:updateRechargeLight()
    elseif new == "DEFENDINGEND" then
        self:restoreRechargePlayerLight()
        self:removeRechargeSoul(false)
    end
end

function Kris:isRechargeActive()
    return self.recharge ~= nil
end

function Kris:isRechargeSustaining()
    return self.recharge
        and not self.recharge.expiring
        and not self.recharge.draining
end

function Kris:applyRechargeSoulOffsets(waves)
    if not self:isRechargeSustaining() then
        return
    end

    for _, wave in ipairs(waves or {}) do
        wave.soul_offset_x = wave.soul_offset_x or RECHARGE_PLAYER_START_OFFSET_X
        wave.soul_offset_y = wave.soul_offset_y or RECHARGE_PLAYER_START_OFFSET_Y
    end
end

function Kris:onEnemySelect(state_reason, enemy_index)
    if state_reason ~= "ACT" or not Game.battle then
        return
    end

    local battle = Game.battle
    if #battle.enemies_index == 0 then
        return true
    end

    battle.ui_select:stop()
    battle.ui_select:play()
    battle.selected_enemy = enemy_index

    local enemy = battle:_getEnemyByIndex(enemy_index)
    if self.mercy_finale_postlude then
        self:clearMercyFinaleHighlights()
        battle:clearMenuItems()
        battle:addMenuItem({
            ["name"] = enemy.act_mercy_finale_view,
            ["description"] = "",
            ["party"] = { "vessel" },
            ["highlight"] = nil,
            ["callback"] = function(menu_item)
                battle:pushAction("ACT", enemy, menu_item)
            end,
        })
        battle:addMenuItem({
            ["name"] = enemy.act_mercy_finale_leave,
            ["description"] = "",
            ["party"] = { "vessel" },
            ["highlight"] = nil,
            ["callback"] = function(menu_item)
                battle:pushAction("ACT", enemy, menu_item)
            end,
        })
        battle:setState("MENUSELECT", "ACT")
        return true
    end

    if enemy.updateRechargeActTPCost then
        enemy:updateRechargeActTPCost()
    end

    battle:clearMenuItems()
    for _, act in ipairs(enemy.acts) do
        local insert = not act.hidden
        if act.character and battle.party[battle.current_selecting].chara.id ~= act.character then
            insert = false
        end
        if act.party and (#act.party > 0) then
            for _, party_id in ipairs(act.party) do
                if not battle:getPartyIndex(party_id) then
                    insert = false
                    break
                end
            end
        end
        if insert then
            local color = act.color or { 1, 1, 1, 1 }
            if act == enemy.recharge_act and enemy.getRechargeActMenuColor then
                color = function()
                    return enemy:getRechargeActMenuColor()
                end
            end

            battle:addMenuItem({
                ["name"] = act.name,
                ["tp"] = act.tp or 0,
                ["unusable"] = act.unusable or false,
                ["description"] = act.description,
                ["party"] = act.party,
                ["color"] = color,
                ["highlight"] = act.highlight or enemy,
                ["icons"] = act.icons,
                ["callback"] = function(menu_item)
                    battle:pushAction("ACT", enemy, menu_item)
                end
            })
        end
    end
    battle:setState("MENUSELECT", "ACT")
    return true
end

function Kris:activateRecharge(enemy, battler, pre_spend_tension)
    local turns = pre_spend_tension >= RECHARGE_FULL_TENSION and RECHARGE_FULL_TURNS or RECHARGE_DEFAULT_TURNS

    self.recharge = self.recharge or {}
    self.recharge.enemy = enemy
    self.recharge.battler = battler
    self.recharge.turns_remaining = math.max(self.recharge.turns_remaining or 0, turns)
    self.recharge.expiring = false
    self.recharge.draining = false
    self.recharge.filling = true
    self.recharge.mercy_cooldown = 0

    self:ensureRechargeVisuals(enemy, battler)
end

function Kris:getRechargeRadialBurstOrigin(battler)
    if battler and battler.parent then
        return battler:getRelativePos(battler.width / 2, battler.height / 2, Game.battle)
    end

    if Game.battle and Game.battle.party and Game.battle.party[1] then
        local party = Game.battle.party[1]
        return party:getRelativePos(party.width / 2, party.height / 2, Game.battle)
    end

    return SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
end

function Kris:spawnRechargeRadialBurst(battler, options)
    if not Game.battle then
        return
    end

    local x, y = self:getRechargeRadialBurstOrigin(battler)
    local burst = RechargeRadialBurst(x, y, options)
    Game.battle:addChild(burst)
    return burst
end

function Kris:spawnRechargeWhiteFlash(battler)
    if Game.battle then
        Game.battle:addChild(RechargeWhiteFlash(battler))
    end
end

function Kris:setPlatformSprite(texture, fade_time)
    if self.bg_platform then
        self.bg_platform:crossFadeTo(texture, fade_time)
    end
    if self.bg_platform_particles then
        self.bg_platform_particles:crossFadeTo(texture, fade_time)
    end
end

function Kris:triggerRechargeActVisuals(battler)
    Assets.playSound("vessel_charge")
    self:spawnRechargeRadialBurst(battler, {
        after_snapshot = function()
            self:spawnRechargeWhiteFlash(battler)
        end
    })
end

function Kris:playRechargeActAnimation(battler)
    if not battler then
        return
    end

    local triggered = false
    battler:setAnimation({
        "battle/act",
        function(sprite, wait)
            for frame = 1, 7 do
                sprite:setFrame(frame)
                if frame == RECHARGE_ACT_EFFECT_FRAME and not triggered then
                    triggered = true
                    self:triggerRechargeActVisuals(battler)
                end
                wait(RECHARGE_ACT_FRAME_DELAY)
            end
        end
    })
end

function Kris:ensureRechargeVisuals(enemy, battler)
    self:setPlatformSprite(PLATFORM_LIGHT_SPRITE, RECHARGE_PLATFORM_FADE_TIME)

    local texture = Assets.getTexture(RECHARGE_LIGHT_SPRITE)
    self.recharge_light_radius = ((texture and texture:getWidth()) or 20) * RECHARGE_LIGHT_SCALE * RECHARGE_LIGHT_RADIUS_FACTOR
    self:updateRechargeLight()
end

function Kris:getRechargeSoulSpawnPosition()
    if self.recharge_soul and self.recharge_soul.parent then
        return self.recharge_soul.x, self.recharge_soul.y
    end

    if Game.battle and Game.battle.arena then
        local x, y = Game.battle.arena:getCenter()
        return x + RECHARGE_SOUL_START_OFFSET_X, y + RECHARGE_SOUL_START_OFFSET_Y
    end

    return SCREEN_WIDTH / 2 + RECHARGE_SOUL_START_OFFSET_X,
        (SCREEN_HEIGHT - 155) / 2 + 10 + RECHARGE_SOUL_START_OFFSET_Y
end

function Kris:getRechargeSoulOriginPosition(enemy)
    enemy = enemy or (self.recharge and self.recharge.enemy)
    if enemy and enemy.parent then
        if enemy.sprite then
            return enemy:localToScreenPos((enemy.sprite.width / 2) - 4.5, enemy.sprite.height / 2)
        end
        return enemy:localToScreenPos(enemy.width / 2, enemy.height / 2)
    end

    return self:getRechargeSoulSpawnPosition()
end

function Kris:getRechargeLightRadius()
    if not self.recharge_light_radius then
        local texture = Assets.getTexture(RECHARGE_LIGHT_SPRITE)
        self.recharge_light_radius = ((texture and texture:getWidth()) or 20) * RECHARGE_LIGHT_SCALE * RECHARGE_LIGHT_RADIUS_FACTOR
    end
    return self.recharge_light_radius
end

function Kris:getRechargeLightPosition()
    if not self.recharge or self.recharge.draining then
        return
    end

    local soul = self:getRechargeLightTarget()
    if soul then
        return soul.x, soul.y, self:getRechargeLightRadius()
    end
end

function Kris:getRechargeLightTarget()
    if not Game.battle then
        return
    end

    if not self.recharge or self.recharge.draining then
        return
    end

    local state = Game.battle:getState()
    if state ~= "DEFENDINGBEGIN" and state ~= "DEFENDING" then
        return
    end

    if Game.battle.soul and Game.battle.soul.parent and Game.battle.soul.visible then
        return Game.battle.soul
    end
end

function Kris:applyRechargePlayerLight(soul)
    if not soul or not soul.sprite then
        return
    end

    if self.recharge_player_light and self.recharge_player_light.soul == soul then
        return
    end

    self:restoreRechargePlayerLight()
    self.recharge_player_light = {
        soul = soul,
        sprite = soul.sprite.texture_path,
        inherit_color = soul.sprite.inherit_color,
    }
    soul.sprite:setSprite(RECHARGE_PLAYER_LIGHT_SPRITE)
    soul.sprite:setOrigin(0.5, 0.5)
    soul.sprite.inherit_color = false

    local light = Sprite(RECHARGE_LIGHT_SPRITE, 0, 0)
    light:setOrigin(0.5, 0.5)
    light:setScale(RECHARGE_LIGHT_SCALE)
    light.layer = (soul.sprite.layer or 0) - 1
    light.alpha = 0
    soul:addChild(light)
    light:fadeTo(1, RECHARGE_PLATFORM_FADE_TIME)
    self.recharge_player_light.light = light
end

function Kris:restoreRechargePlayerLight()
    local data = self.recharge_player_light
    if not data then
        return
    end

    if data.soul and data.soul.parent and data.soul.sprite then
        if data.light then
            data.light:remove()
        end
        data.soul.sprite:setSprite(data.sprite or RECHARGE_DEFAULT_SOUL_SPRITE)
        data.soul.sprite:setOrigin(0.5, 0.5)
        data.soul.sprite.inherit_color = data.inherit_color
    elseif data.light then
        data.light:remove()
    end
    self.recharge_player_light = nil
end

function Kris:removeRechargeSoul(instant, enemy)
    if not self.recharge_soul then
        return
    end

    local soul = self.recharge_soul
    self.recharge_soul = nil

    if not soul.parent then
        return
    end

    if instant then
        soul:remove()
    elseif soul.transitionBackTo then
        enemy = enemy or soul.target_enemy or (self.recharge and self.recharge.enemy)
        local target_x, target_y = self:getRechargeSoulOriginPosition(enemy)
        soul:transitionBackTo(
            target_x + RECHARGE_RETURN_TARGET_OFFSET_X,
            target_y + RECHARGE_RETURN_TARGET_OFFSET_Y
        )
    else
        soul:fadeOutAndRemove(RECHARGE_PLATFORM_FADE_TIME)
    end
end

function Kris:isRechargeMercyDisplayActive()
    local state = Game.battle and Game.battle:getState()
    return self.recharge
        and not self.recharge.draining
        and (state == "DEFENDINGBEGIN" or state == "DEFENDING" or state == "DEFENDINGEND")
end

function Kris:tryAddRechargeMercy(enemy)
    local recharge = self.recharge
    if not recharge or not enemy or not self:isRechargeMercyDisplayActive() then
        return false
    end

    if (recharge.mercy_cooldown or 0) > 0 then
        return false
    end

    enemy:addTemporaryMercy(1, true, { 0, 100 }, function()
        return not Game.battle
            or not Game.battle.encounter
            or not Game.battle.encounter.isRechargeMercyDisplayActive
            or not Game.battle.encounter:isRechargeMercyDisplayActive()
    end)
    recharge.mercy_cooldown = RECHARGE_MERCY_INTERVAL
    return true
end

function Kris:getRechargeTargetPosition(target)
    if target == Game.battle.soul then
        return target.x, target.y
    end

    return target:getRelativePos(target.width / 2, target.height / 2, Game.battle)
end

function Kris:updateRechargeLight()
    local recharge = self.recharge
    if not recharge or recharge.draining then
        self:restoreRechargePlayerLight()
        self:removeRechargeSoul(true)
        return
    end

    local target = self:getRechargeLightTarget()
    if not target then
        self:restoreRechargePlayerLight()
        local state = Game.battle and Game.battle:getState()
        self:removeRechargeSoul(state ~= "DEFENDINGEND", recharge.enemy)
        return
    end

    self:applyRechargePlayerLight(target)

    if not self.recharge_soul or not self.recharge_soul.parent then
        local origin_x, origin_y = self:getRechargeSoulOriginPosition(recharge.enemy)
        local target_x, target_y = self:getRechargeSoulSpawnPosition()
        self.recharge_soul = Registry.createBullet("recharge_soul", origin_x, origin_y, recharge.enemy, self:getRechargeLightRadius())
        self.recharge_soul:transitionTo(target_x, target_y)
        local burst = HeartBurst(origin_x - 2, origin_y + 1, { 1, 1, 1 })
        burst.layer = RECHARGE_SOUL_LAYER
        Game.battle:addChild(burst)
        Game.battle:addChild(self.recharge_soul)
    else
        self.recharge_soul.target_enemy = recharge.enemy
        self.recharge_soul.light_radius = self:getRechargeLightRadius()
        self.recharge_soul.enabled = true
        self.recharge_soul.visible = true
    end
end

function Kris:beginRechargeDrain()
    local recharge = self.recharge
    if not recharge or not recharge.expiring or recharge.draining then
        return
    end

    recharge.expiring = false
    recharge.draining = true
    recharge.filling = false

    self:restoreRechargePlayerLight()
    self:removeRechargeSoul(true)

    self:setPlatformSprite(PLATFORM_SPRITE, RECHARGE_PLATFORM_FADE_TIME)
end

function Kris:updateRechargeTension()
    local recharge = self.recharge
    if not recharge then
        return
    end

    if recharge.draining then
        if Game:getTension() > 0 then
            Game:removeTension(RECHARGE_TENSION_RATE * DT)
        end
        if Game:getTension() <= 0 then
            self:clearRecharge(false)
        end
    elseif recharge.filling then
        if Game:getTension() < Game:getMaxTension() then
            Game:giveTension(RECHARGE_TENSION_RATE * DT)
        end
        if Game:getTension() >= Game:getMaxTension() then
            recharge.filling = false
        end
    end
end

function Kris:updateRechargeMercyCooldown()
    local recharge = self.recharge
    if not recharge or not recharge.mercy_cooldown then
        return
    end

    recharge.mercy_cooldown = math.max(recharge.mercy_cooldown - DT, 0)
end

function Kris:clearRecharge(instant)
    self:restoreRechargePlayerLight()
    self:removeRechargeSoul(instant, self.recharge and self.recharge.enemy)
    self.recharge = nil
end

function Kris:clearRechargeForMercyFinale()
    if not self.recharge then
        return
    end

    self:clearRecharge(true)
    self:setPlatformSprite(PLATFORM_SPRITE, RECHARGE_PLATFORM_FADE_TIME)
    Game:setTension(0)
end

function Kris:update()
    super.update(self)

    if self.mercy_finale_detached then
        self:updateMercyFinaleDetached()
    end

    if self.mercy_finale_enemy_turn then
        self.mercy_finale_enemy_turn_time = self.mercy_finale_enemy_turn_time - DT
        if self.mercy_finale_enemy_turn_time <= 0 then
            self:finishMercyFinaleEnemyTurn()
        end
    end

    self:updateRechargeMercyCooldown()
    self:updateRechargeLight()
    self:updateRechargeTension()
end

function Kris:setupBackground(battle)
    self.bg_platform = Sprite(PLATFORM_SPRITE, 0, 0)
    self.bg_platform.layer = BATTLE_LAYERS["bottom"]
    self.bg_platform:setScale(2, 2)
    battle:addChild(self.bg_platform)

    self.bg_platform_particles = KrisPlatformParticles(self.bg_platform, PLATFORM_SPRITE)
    self.bg_platform_particles.layer = BATTLE_LAYERS["bottom"] + 0.25
    battle:addChild(self.bg_platform_particles)

    self.bg_depth = KrisDepthBackground()
    self.bg_depth.layer = BATTLE_LAYERS["bottom"] + 0.5
    battle:addChild(self.bg_depth)

    self.vignette = KrisVignette()
    self.vignette.layer = BATTLE_LAYERS["bottom"] + 1
    battle:addChild(self.vignette)
end

return Kris
