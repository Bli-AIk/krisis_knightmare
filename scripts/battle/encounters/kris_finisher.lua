local KrisFinisher, super = Class(Encounter)

local FINISHER_KRIS_X = 50
local FINISHER_KRIS_Y = 100
local FINISHER_KRIS_SOUL_X = 140 - FINISHER_KRIS_X
local FINISHER_KRIS_SOUL_Y = 170 - FINISHER_KRIS_Y
local FINISHER_KRIS_LAYER = BATTLE_LAYERS["battlers"]
local FINISHER_KRIS_ANIMATION_SPEED = 4 / 30
local FINISHER_KRIS_SCALE = 2
local FINISHER_KRIS_MOVE_DISTANCE = 17
local FINISHER_KRIS_MOVE_SEGMENT_TIME = 2
local FINISHER_WARP_BACKGROUND_ALPHA = 0.15
local FINISHER_TP50_FULLSCREEN_FILTER_PROGRESS = 0.01
local FINISHER_SLIDE_HOLD_FRAME = 6
local FINISHER_SLIDE_LOOP_START_FRAME = 3
local FINISHER_SLIDE_LOOP_COUNT = 1
local FINISHER_SLIDE_LAST_WAIT_FRAME = 8
local FINISHER_SLIDE_END_FRAME = 9
local FINISHER_SLIDE_AFTERIMAGE_ALPHA = 0.5
local FINISHER_SLIDE_AFTERIMAGE_FADE_SPEED = 0.05
local FINISHER_SLIDE_AFTERIMAGE_SPEED = 2

local FINISHER_SWORD_START_X = SCREEN_WIDTH / 2
local FINISHER_SWORD_START_Y = SCREEN_HEIGHT * 0.35
local FINISHER_SWORD_RISE_FADE_TIME = 0.5
local FINISHER_SWORD_RISE_TIME = 0.8
local FINISHER_SWORD_TOP_HOLD_TIME = 8 / 60
local FINISHER_SWORD_DIVE_TIME = 8 / 60
local FINISHER_SWORD_POST_EXIT_PAUSE = 6 / 60
local FINISHER_SWORD_BLUR_ALPHA = 0.22
local FINISHER_SWORD_BLUR_FADE_SPEED = 0.12
local FINISHER_SWORD_BLUR_DRIFT = -5

local FINISHER_ELLIPSE_GROW_TIME = 0.22
local FINISHER_ELLIPSE_CENTER_Y = SCREEN_HEIGHT * 0.90
local FINISHER_ELLIPSE_RADIUS_X = SCREEN_WIDTH * 0.125
local FINISHER_ELLIPSE_START_RADIUS_Y = SCREEN_HEIGHT * 0.20
local FINISHER_ELLIPSE_TARGET_RADIUS_Y = SCREEN_HEIGHT * 1.25

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
local FINISHER_TRANSITION_DURATION = 1
local FINISHER_EXPOSURE_DURATION = 0.2
local FINISHER_GLOW_DURATION = 0.3
local FINISHER_RGB_OFFSET = 6.0
local FINISHER_TRANSITION_SHADER_PRIORITY = 1000

local FINISHER_INVERT_SHADER_SOURCE = [[
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
        vec4 source = Texel(tex, uv);
        return vec4(vec3(1.0) - source.rgb, source.a) * color;
    }
]]

local FINISHER_TRANSITION_SHADER_SOURCE = [[
    extern vec2 texSize;
    extern float exposure;
    extern float glowStrength;
    extern float rgbOffset;
    extern float overlayEdge;
    extern float overlayWidth;
    extern float overlayAlpha;

    vec4 sampleClamped(Image tex, vec2 uv) {
        return Texel(tex, clamp(uv, vec2(0.0), vec2(1.0)));
    }

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
        vec2 xOffset = vec2(rgbOffset / texSize.x, 0.0);
        vec4 center = sampleClamped(tex, uv);

        // Separate the channels along X only, using the configured offset.
        float red = sampleClamped(tex, uv - xOffset).r;
        float green = center.g;
        float blue = sampleClamped(tex, uv + xOffset).b;
        vec3 separated = vec3(red, green, blue);

        // A short cross-shaped blur gives the exposure flash a soft glow.
        vec2 xBlur = vec2(4.0 / texSize.x, 0.0);
        vec2 yBlur = vec2(0.0, 4.0 / texSize.y);
        vec3 glow = (
            sampleClamped(tex, uv - xBlur).rgb
            + sampleClamped(tex, uv + xBlur).rgb
            + sampleClamped(tex, uv - yBlur).rgb
            + sampleClamped(tex, uv + yBlur).rgb
        ) * 0.25;

        vec3 result = separated * (1.0 + exposure) + glow * glowStrength;

        // A red sheet starts on the left and moves left past the screen.
        float sheet = 1.0 - smoothstep(
            overlayEdge - overlayWidth,
            overlayEdge,
            uv.x
        );
        result = mix(
            result,
            vec3(178.0 / 255.0, 0.0, 0.0),
            clamp(sheet * overlayAlpha, 0.0, 1.0)
        );

        return vec4(result, center.a) * color;
    }
]]

local OPENING_STATE = "KRISIS_OPENING"
local OPENING_REVEAL_DELAY = 50 / 60
local OPENING_INITIAL_FLICKER_INTERVAL = 15 / 60
local OPENING_INITIAL_FLICKER_COUNT = 3
local OPENING_FOURTH_FLICKER_INTERVAL = 13 / 60
local OPENING_ACCELERATION_TIME = 60 / 60
local OPENING_MIN_FLICKER_INTERVAL = 1 / 60
local OPENING_FLICKER_CURVE_POWER = 2

-- Adjust the opening heart position here.
local OPENING_PLAYER_POSITION = {
    x = SCREEN_WIDTH / 2,
    y = 170,
}

local FinisherHurtFlash, hurt_flash_super = Class(Object)

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function easeInOutSine(progress)
    return -(math.cos(math.pi * progress) - 1) / 2
end

local function copySpriteState(sprite)
    return {
        color = { sprite.color[1], sprite.color[2], sprite.color[3] },
        alpha = sprite.alpha,
        visible = sprite.visible,
        active = sprite.active,
        inherit_color = sprite.inherit_color,
    }
end

local function restoreSpriteState(sprite, state)
    if not sprite or not state then
        return
    end

    sprite:setColor(state.color[1], state.color[2], state.color[3], state.alpha)
    sprite.visible = state.visible
    sprite.active = state.active
    sprite.inherit_color = state.inherit_color
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

local FinisherInversionBackdrop, inversion_backdrop_super = Class(Object)

function FinisherInversionBackdrop:init()
    inversion_backdrop_super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self.layer = BATTLE_LAYERS["bottom"]
end

function FinisherInversionBackdrop:draw()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    love.graphics.push()
    love.graphics.origin()
    Draw.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.pop()

    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

local FinisherEllipse, ellipse_super = Class(Object)

function FinisherEllipse:init(options)
    options = options or {}
    ellipse_super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = BATTLE_LAYERS["top"] + 100
    self.elapsed = 0
    self.grow_finished = false
    self.on_grow_complete = options.on_grow_complete
    self.center_x = SCREEN_WIDTH / 2
    self.center_y = FINISHER_ELLIPSE_CENTER_Y
    self.radius_x = FINISHER_ELLIPSE_RADIUS_X
    self.radius_y = FINISHER_ELLIPSE_START_RADIUS_Y
    self:setColor(0, 0, 0, 1)
end

function FinisherEllipse:update()
    self.elapsed = self.elapsed + DT

    local progress = clamp(self.elapsed / FINISHER_ELLIPSE_GROW_TIME, 0, 1)
    local eased = 1 - (1 - progress) * (1 - progress) * (1 - progress)
    self.radius_y = FINISHER_ELLIPSE_START_RADIUS_Y
        + (FINISHER_ELLIPSE_TARGET_RADIUS_Y - FINISHER_ELLIPSE_START_RADIUS_Y) * eased

    if progress >= 1 and not self.grow_finished then
        self.grow_finished = true
        if self.on_grow_complete then
            self.on_grow_complete(self)
        end
    end

    ellipse_super.update(self)
end

function FinisherEllipse:draw()
    local r, g, b, a = self:getDrawColor()

    love.graphics.push()
    love.graphics.origin()
    Draw.setColor(r, g, b, a)
    love.graphics.ellipse(
        "fill",
        self.center_x,
        self.center_y,
        self.radius_x,
        self.radius_y
    )
    love.graphics.pop()
end

local FinisherFlyingSword, finisher_sword_super = Class(Bullet)

function FinisherFlyingSword:init(x, y, options)
    options = options or {}
    finisher_sword_super.init(self, x, y, "bullets/flying_sword/normal")

    -- This is a visual finisher prop, so it uses the normal sword sprite but
    -- does not participate in the regular bullet path or collision system.
    self:setSprite("bullets/flying_sword/normal")
    self:setScale(2.25)
    self.rotation = math.pi
    self.layer = BATTLE_LAYERS["top"] + 1
    self.collidable = false
    self.can_graze = false
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.physics.speed_x = 0
    self.physics.speed_y = 0

    self.phase = "RISE"
    self.elapsed = 0
    self.start_x = x
    self.start_y = y
    self.target_x = x
    self.target_y = self:getScaledHeight() / 2
    self.exit_y = SCREEN_HEIGHT + self:getScaledHeight() / 2 + 8
    self.exit_started = false
    self.motion_blurs = {}
    self.on_exit = options.on_exit

    self:setColor(1, 1, 1, 0)
end

function FinisherFlyingSword:spawnMotionBlur()
    if not self.parent then
        return
    end

    for index = 1, 2 do
        local blur = AfterImage(
            self.sprite,
            FINISHER_SWORD_BLUR_ALPHA / index,
            FINISHER_SWORD_BLUR_FADE_SPEED
        )
        blur.physics.speed_y = FINISHER_SWORD_BLUR_DRIFT * index
        self.parent:addChild(blur)
        blur.layer = self.layer - index * 0.01
        table.insert(self.motion_blurs, blur)
    end
end

function FinisherFlyingSword:clearMotionBlur()
    for index = #self.motion_blurs, 1, -1 do
        local blur = self.motion_blurs[index]
        if blur and blur.parent then
            blur:remove()
        end
        self.motion_blurs[index] = nil
    end
end

function FinisherFlyingSword:update()
    self.elapsed = self.elapsed + DT

    if self.phase == "RISE" then
        local move_progress = clamp(self.elapsed / FINISHER_SWORD_RISE_TIME, 0, 1)
        local move_eased = 1 - (1 - move_progress) * (1 - move_progress) * (1 - move_progress)
        self.x = self.start_x + (self.target_x - self.start_x) * move_eased
        self.y = self.start_y + (self.target_y - self.start_y) * move_eased

        local color_progress = move_eased
        local alpha = clamp(self.elapsed / FINISHER_SWORD_RISE_FADE_TIME, 0, 1)
        self:setColor(1, 1 - color_progress, 1 - color_progress, alpha)

        if move_progress >= 1 then
            self.phase = "TOP_HOLD"
            self.elapsed = 0
            self:setColor(1, 0, 0, 1)
        end
    elseif self.phase == "TOP_HOLD" then
        self.x = self.target_x
        self.y = self.target_y
        self:setColor(1, 0, 0, 1)

        if self.elapsed >= FINISHER_SWORD_TOP_HOLD_TIME then
            self.phase = "DIVE"
            self.elapsed = 0
        end
    elseif self.phase == "DIVE" then
        local progress = clamp(self.elapsed / FINISHER_SWORD_DIVE_TIME, 0, 1)
        local eased = progress * progress * progress
        self.y = self.target_y + (self.exit_y - self.target_y) * eased
        self:setColor(1, 0, 0, 1)
        self:spawnMotionBlur()
    end

    finisher_sword_super.update(self)

    if self.phase == "DIVE" and not self.exit_started then
        local _, screen_y = self:getScreenPos()
        local half_height = self:getScaledHeight() / 2
        if screen_y - half_height >= SCREEN_HEIGHT then
            self.exit_started = true
            if self.on_exit then
                self.on_exit(self)
            end
            self:remove()
        end
    end
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
    self.finisher_star_center_x = nil
    self.finisher_star_center_y = nil
    self.finisher_kris_move_elapsed = 0
    self.finisher_hurt_flash = nil
    self.finisher_status_message_restore = {}
    self.finisher_opening = nil
    self.finisher_transition = nil
    self.finisher_transition_battle = nil
    self.finisher_transition_fx = nil
    self.finisher_transition_shader = nil
    self.finisher_wind_background = nil
    self.finisher_warp_background = nil
    self.finisher_slide_afterimage = nil
    self.finisher_tp_flash = nil
    self.finisher_sword = nil
    self.finisher_sword_post_exit_delay = nil
    self.finisher_sword_post_exit_battle = nil
    self.finisher_inversion_shader = nil
    self.finisher_inversion_battle = nil
    self.finisher_inversion_backdrop = nil
    self.finisher_inversion_fx = nil
    self.finisher_inversion_soul = nil
    self.finisher_inversion_soul_state = nil
    self.finisher_inversion_soul_sprite = nil
    self.finisher_inversion_soul_sprite_state = nil
    self.finisher_ellipse = nil
    self.finisher_tp_reached = false
end

function KrisFinisher:createBackground()
    local battle = Game.battle
    if not battle then
        return
    end

    local background = KrisFinisherWindBackground()
    self.finisher_wind_background = background
    return battle:addChild(background)
end

function KrisFinisher:onBattleInit()
    local battle = Game.battle

    if not battle then
        return
    end

    -- Direct finisher launches skip Kris:onBattleStart because this encounter
    -- owns the custom opening state. Apply the command-line TP here instead.
    local initial_tp = Game:getConfig("krisisInitialTP")
    if initial_tp ~= nil then
        initial_tp = tonumber(initial_tp)
        if initial_tp then
            Game:setTension(initial_tp)
        end
    end

    -- Keep the battle in the opening until the finisher scene is ready to show.
    battle.state = OPENING_STATE
    battle.state_reason = nil

    self.finisher_opening = {
        battle = battle,
        phase = "WAIT",
        timer = 0,
        flicker_timer = 0,
        acceleration_timer = 0,
        flicker_count = 0,
        fourth_flicker_done = false,
        heart_visible = false,
        kris_alpha = 0,
        prepared = false,
        child_states = {},
        kris_position = nil,
    }

    self:hidePlayerUI(battle)
    self:createFinisherKris(battle)
    self:createWindowArena(battle)
    self:hideVesselDamageNumbers(battle)

    return true
end

function KrisFinisher:onBattleAdd(battle)
    local opening = self.finisher_opening
    if not opening or opening.prepared then
        return
    end

    opening.prepared = true

    local soul = battle.soul
    if soul then
        opening.soul = soul
        opening.soul_state = {
            color = { soul.color[1], soul.color[2], soul.color[3] },
            alpha = soul.alpha,
            active = soul.active,
            visible = soul.visible,
        }

        if soul.sprite then
            opening.soul_sprite = soul.sprite
            opening.soul_sprite_state = copySpriteState(soul.sprite)
        end
        if soul.graze_sprite then
            opening.soul_graze_sprite = soul.graze_sprite
            opening.soul_graze_sprite_state = copySpriteState(soul.graze_sprite)
        end

        soul:setColor(0, 0, 0, soul.alpha)
        soul.active = false
        soul.visible = false
        if soul.graze_sprite then
            soul.graze_sprite.active = false
            soul.graze_sprite.visible = false
        end
    end

    for _, child in ipairs(battle.children) do
        opening.child_states[child] = {
            active = child.active,
            visible = child.visible,
        }
        child.active = false
        child.visible = false
    end

    local kris = self.finisher_kris
    if kris then
        opening.kris = kris
        opening.kris_position = { kris.x, kris.y }
        kris.active = true
        kris.visible = false

        if self.finisher_kris_sprite then
            opening.kris_sprite = self.finisher_kris_sprite
            opening.kris_sprite_state = copySpriteState(self.finisher_kris_sprite)
            self.finisher_kris_sprite:setColor(0, 0, 0, 0)
            self.finisher_kris_sprite.active = true
            self.finisher_kris_sprite.visible = true
        end

        if self.finisher_soul then
            opening.finisher_soul_state = {
                active = self.finisher_soul.active,
                visible = self.finisher_soul.visible,
            }
            self.finisher_soul.active = false
            self.finisher_soul.visible = false
        end
    end

    battle.transition_timer = 10
end

function KrisFinisher:beforeStateChange(old, new, reason)
    if self.finisher_opening then
        return true
    end
end

function KrisFinisher:getOpeningFlickerInterval(progress)
    progress = clamp(progress, 0, 1)
    local eased_progress = progress ^ OPENING_FLICKER_CURVE_POWER
    return OPENING_INITIAL_FLICKER_INTERVAL * (1 - eased_progress)
end

function KrisFinisher:lockOpeningPositions(opening)
    if opening.kris and opening.kris_position then
        opening.kris:setPosition(opening.kris_position[1], opening.kris_position[2])
    end
end

function KrisFinisher:applyOpeningVisuals(opening)
    if opening.kris_sprite and opening.kris_sprite_state then
        local alpha = opening.kris_sprite_state.alpha * clamp(opening.kris_alpha, 0, 1)
        opening.kris_sprite:setColor(0, 0, 0, alpha)
    end
end

function KrisFinisher:finishOpening()
    local opening = self.finisher_opening
    if not opening then
        return
    end

    local battle = opening.battle
    opening.kris_alpha = 1
    self:applyOpeningVisuals(opening)

    restoreSpriteState(opening.kris_sprite, opening.kris_sprite_state)

    if self.finisher_soul and opening.finisher_soul_state then
        self.finisher_soul.active = opening.finisher_soul_state.active
        self.finisher_soul.visible = opening.finisher_soul_state.visible
    end

    for child, state in pairs(opening.child_states) do
        if child.parent == battle then
            child.active = state.active
            child.visible = state.visible
        end
    end

    if opening.soul and opening.soul_state then
        opening.soul:setColor(
            opening.soul_state.color[1],
            opening.soul_state.color[2],
            opening.soul_state.color[3],
            opening.soul_state.alpha
        )
        opening.soul.active = opening.soul_state.active
        opening.soul.visible = opening.soul_state.visible
        restoreSpriteState(opening.soul_sprite, opening.soul_sprite_state)
        restoreSpriteState(opening.soul_graze_sprite, opening.soul_graze_sprite_state)
    end

    if battle then
        battle.transition_timer = 10
        battle.tension_bar:show()
        battle.music:play(self.music, nil, FINISHER_MUSIC_PITCH)
    end

    self.finisher_kris_move_elapsed = 0
    self.finisher_opening = nil

    if battle and battle.parent then
        battle:setState("KRIS_FINISHER", "OPENING")
        self:startFinisherTransition(battle)
        self:startFinisherStarEmitter(battle)
    end
end

function KrisFinisher:startFinisherTransition(battle)
    self:stopFinisherTransition()

    if self.finisher_wind_background then
        self.finisher_wind_background:setFullscreenFilterProgress(0)
    end

    local transition = {
        time = 0,
    }
    local shader = self.finisher_transition_shader
    if not shader then
        shader = love.graphics.newShader(FINISHER_TRANSITION_SHADER_SOURCE)
        self.finisher_transition_shader = shader
    end

    local function progress()
        return clamp(transition.time / FINISHER_TRANSITION_DURATION, 0, 1)
    end

    local function fastDecay(duration, power)
        return clamp(1 - transition.time / duration, 0, 1) ^ power
    end

    local fx = ShaderFX(shader, {
        texSize = { SCREEN_WIDTH, SCREEN_HEIGHT },
        exposure = function()
            return 5.0 * fastDecay(FINISHER_EXPOSURE_DURATION, 2)
        end,
        glowStrength = function()
            return 3.0 * fastDecay(FINISHER_GLOW_DURATION, 2)
        end,
        rgbOffset = function()
            return FINISHER_RGB_OFFSET * (1 - progress())
        end,
        overlayEdge = function()
            return 1.0 - progress() * 1.3
        end,
        overlayWidth = 1.0,
        overlayAlpha = function()
            return 0.86 * (1 - progress() * 0.25)
        end,
    }, false, FINISHER_TRANSITION_SHADER_PRIORITY)

    battle:addFX(fx, "kris_finisher_transition")
    self.finisher_transition = transition
    self.finisher_transition_battle = battle
    self.finisher_transition_fx = fx
end

function KrisFinisher:stopFinisherTransition()
    local battle = self.finisher_transition_battle
    local fx = self.finisher_transition_fx
    if battle and fx then
        battle:removeFX("kris_finisher_transition")
    end

    self.finisher_transition = nil
    self.finisher_transition_battle = nil
    self.finisher_transition_fx = nil
end

function KrisFinisher:updateFinisherTransition()
    local transition = self.finisher_transition
    if not transition then
        return
    end

    transition.time = transition.time + DT
    local progress = clamp(transition.time / FINISHER_TRANSITION_DURATION, 0, 1)
    if self.finisher_wind_background then
        self.finisher_wind_background:setFullscreenFilterProgress(progress)
    end

    if transition.time >= FINISHER_TRANSITION_DURATION then
        self:stopFinisherTransition()
    end
end

function KrisFinisher:clearFinisherWindBackground()
    local background = self.finisher_wind_background
    if background then
        background:clear()
    end
    self.finisher_wind_background = nil
end

function KrisFinisher:clearFinisherWarpBackground()
    local background = self.finisher_warp_background
    if background then
        background:clear()
    end
    self.finisher_warp_background = nil
end

function KrisFinisher:clearFinisherBulletObjects(battle)
    if not battle then
        return
    end

    battle:setWaves({})

    for index = #battle.children, 1, -1 do
        local child = battle.children[index]
        if child and child.includes and child:includes(Bullet) then
            child:remove()
        end
    end
end

function KrisFinisher:startFinisherWarpBackground(battle)
    self:clearFinisherWarpBackground()

    local background = KrisFinisherWarpBackground(FINISHER_WARP_BACKGROUND_ALPHA)
    self.finisher_warp_background = background
    battle:addChild(background)
end

function KrisFinisher:clearFinisherSlideAfterImage()
    local afterimage = self.finisher_slide_afterimage
    if afterimage and afterimage.parent then
        afterimage:remove()
    end
    self.finisher_slide_afterimage = nil
end

function KrisFinisher:clearFinisherSword()
    local sword = self.finisher_sword
    if sword then
        sword:clearMotionBlur()
        if sword.parent then
            sword:remove()
        end
    end
    self.finisher_sword = nil
    self.finisher_sword_post_exit_delay = nil
    self.finisher_sword_post_exit_battle = nil
end

function KrisFinisher:clearFinisherEllipse()
    local ellipse = self.finisher_ellipse
    if ellipse and ellipse.parent then
        ellipse:remove()
    end
    self.finisher_ellipse = nil
end

function KrisFinisher:clearFinisherInversion()
    local battle = self.finisher_inversion_battle
    if battle and self.finisher_inversion_fx then
        battle:removeFX("kris_finisher_invert")
    end
    if self.finisher_inversion_backdrop and self.finisher_inversion_backdrop.parent then
        self.finisher_inversion_backdrop:remove()
    end

    local soul = self.finisher_inversion_soul
    local soul_state = self.finisher_inversion_soul_state
    if soul and soul_state then
        soul:setColor(
            soul_state.color[1],
            soul_state.color[2],
            soul_state.color[3],
            soul_state.alpha
        )
    end
    restoreSpriteState(
        self.finisher_inversion_soul_sprite,
        self.finisher_inversion_soul_sprite_state
    )

    self.finisher_inversion_battle = nil
    self.finisher_inversion_backdrop = nil
    self.finisher_inversion_fx = nil
    self.finisher_inversion_soul = nil
    self.finisher_inversion_soul_state = nil
    self.finisher_inversion_soul_sprite = nil
    self.finisher_inversion_soul_sprite_state = nil
end

function KrisFinisher:clearFinisherHurtFlash()
    if self.finisher_hurt_flash and self.finisher_hurt_flash.parent then
        self.finisher_hurt_flash:remove()
    end
    self.finisher_hurt_flash = nil

    if self.finisher_tp_flash and self.finisher_tp_flash.parent then
        self.finisher_tp_flash:remove()
    end
    self.finisher_tp_flash = nil
end

function KrisFinisher:removeFinisherKrisSprite()
    local sprite = self.finisher_kris_sprite
    if not sprite then
        return
    end

    sprite.active = false
    sprite.visible = false
    if sprite.parent then
        sprite:remove()
    end
end

function KrisFinisher:startFinisherInversion(battle)
    self:clearFinisherInversion()

    local soul = battle and battle.soul
    if soul then
        self.finisher_inversion_soul = soul
        self.finisher_inversion_soul_state = {
            color = { soul.color[1], soul.color[2], soul.color[3] },
            alpha = soul.alpha,
        }
        if soul.sprite then
            self.finisher_inversion_soul_sprite = soul.sprite
            self.finisher_inversion_soul_sprite_state = copySpriteState(soul.sprite)
        end

        -- The battle inversion turns white into black for the player's heart.
        soul:setColor(1, 1, 1, soul.alpha)
    end

    local backdrop = FinisherInversionBackdrop()
    battle:addChild(backdrop)

    local shader = self.finisher_inversion_shader
    if not shader then
        shader = love.graphics.newShader(FINISHER_INVERT_SHADER_SOURCE)
        self.finisher_inversion_shader = shader
    end

    local fx = ShaderFX(shader, nil, false, BATTLE_LAYERS["top"] + 100)
    battle:addFX(fx, "kris_finisher_invert")
    self.finisher_inversion_battle = battle
    self.finisher_inversion_backdrop = backdrop
    self.finisher_inversion_fx = fx
end

function KrisFinisher:startFinisherEllipse()
    self:clearFinisherEllipse()

    if not Game.stage then
        return
    end

    local ellipse = FinisherEllipse({
        on_grow_complete = function(current_ellipse)
            self:finishFinisherEllipseInversion(current_ellipse)
        end,
    })
    Game.stage:addChild(ellipse)
    self.finisher_ellipse = ellipse
end

function KrisFinisher:finishFinisherEllipseInversion(ellipse)
    if self.finisher_ellipse ~= ellipse then
        return
    end

    self:clearFinisherInversion()
    ellipse:setColor(1, 1, 1, 1)
end

function KrisFinisher:startFinisherSword(battle)
    self:clearFinisherSword()

    local sword = FinisherFlyingSword(
        FINISHER_SWORD_START_X,
        FINISHER_SWORD_START_Y,
        {
            on_exit = function(prop)
                self:finishFinisherSword(prop, battle)
            end,
        }
    )
    battle:addChild(sword)
    self.finisher_sword = sword
end

function KrisFinisher:finishFinisherSword(sword, battle)
    if self.finisher_sword ~= sword then
        return
    end

    self:stopFinisherTransition()
    self:clearFinisherWindBackground()
    self:clearFinisherWarpBackground()
    self:clearFinisherHurtFlash()
    self:removeFinisherKrisSprite()

    self.finisher_sword_post_exit_delay = FINISHER_SWORD_POST_EXIT_PAUSE
    self.finisher_sword_post_exit_battle = battle
end

function KrisFinisher:completeFinisherSword(battle)
    self:startFinisherInversion(battle)
    self:startFinisherEllipse()
end

function KrisFinisher:updateFinisherSword()
    local delay = self.finisher_sword_post_exit_delay
    if not delay then
        return
    end

    self.finisher_sword_post_exit_delay = delay - DT
    if self.finisher_sword_post_exit_delay > 0 then
        return
    end

    local battle = self.finisher_sword_post_exit_battle
    self.finisher_sword_post_exit_delay = nil
    self.finisher_sword_post_exit_battle = nil
    self:completeFinisherSword(battle)
end

function KrisFinisher:startFinisherSlideAnimation(battle)
    local sprite = self.finisher_kris_sprite
    if not sprite or not sprite.parent then
        return
    end

    self:clearFinisherSlideAfterImage()

    sprite:setAnimation({
        "finisher_slide",
        function(anim_sprite, wait)
            for frame = 1, FINISHER_SLIDE_HOLD_FRAME - 1 do
                anim_sprite:setFrame(frame)
                wait(FINISHER_KRIS_ANIMATION_SPEED)
            end

            self:startFinisherSword(battle)

            for _ = 1, FINISHER_SLIDE_LOOP_COUNT do
                for frame = FINISHER_SLIDE_LOOP_START_FRAME, FINISHER_SLIDE_HOLD_FRAME do
                    anim_sprite:setFrame(frame)
                    wait(FINISHER_KRIS_ANIMATION_SPEED)
                end
            end

            for frame = FINISHER_SLIDE_HOLD_FRAME + 1, FINISHER_SLIDE_LAST_WAIT_FRAME do
                anim_sprite:setFrame(frame)
                wait(FINISHER_KRIS_ANIMATION_SPEED)
            end

            anim_sprite:setFrame(FINISHER_SLIDE_END_FRAME)
        end,
        callback = function(anim_sprite)
            anim_sprite:setFrame(FINISHER_SLIDE_END_FRAME)
            self:clearFinisherSlideAfterImage()
        end,
    })

    local afterimage = AfterImage(
        sprite,
        FINISHER_SLIDE_AFTERIMAGE_ALPHA,
        FINISHER_SLIDE_AFTERIMAGE_FADE_SPEED
    )
    afterimage.physics.speed_x = -FINISHER_SLIDE_AFTERIMAGE_SPEED
    battle:addChild(afterimage)
    self.finisher_slide_afterimage = afterimage
end

function KrisFinisher:triggerFinisherTPReached()
    if self.finisher_tp_reached then
        return
    end

    local battle = Game.battle
    if not battle then
        return
    end

    self.finisher_tp_reached = true
    self:stopFinisherStarEmitter()
    self:clearFinisherStars()
    self:clearFinisherBulletObjects(battle)
    self:stopFinisherTransition()
    if self.finisher_wind_background then
        self.finisher_wind_background:stopWindAnimation()
        -- Keep the red fullscreen filter from the pre-50 TP scene.
        -- It is intentionally weaker here so the post-50 warp stays near black.
        self.finisher_wind_background:setFullscreenFilterProgress(
            FINISHER_TP50_FULLSCREEN_FILTER_PROGRESS
        )
    end
    self:startFinisherWarpBackground(battle)
    self:startFinisherSlideAnimation(battle)

    local tp_flash = RechargeWhiteFlash(nil, {
        hold_time = 0.05,
        fade_time = 0.18,
        layer = BATTLE_LAYERS["top"] + 2,
    })
    battle:addChild(tp_flash)
    self.finisher_tp_flash = tp_flash
end

function KrisFinisher:updateFinisherWindBackground()
    -- A direct --tp launch starts above the threshold before the custom
    -- opening is visible. Wait until that cover is gone so the full 60 FPS
    -- background sequence is actually seen.
    if self.finisher_opening then
        return
    end

    if Game:getTension() >= FINISHER_STOP_TP then
        self:triggerFinisherTPReached()
    end
end

function KrisFinisher:updateOpening()
    local opening = self.finisher_opening
    if not opening then
        return
    end

    if not opening.prepared and Game.battle then
        self:onBattleAdd(Game.battle)
    end

    self:lockOpeningPositions(opening)

    if opening.phase == "WAIT" then
        opening.timer = opening.timer + DT
        if opening.timer >= OPENING_REVEAL_DELAY then
            opening.phase = "INITIAL_FLICKER"
            opening.timer = 0
            opening.heart_visible = true
        end
    elseif opening.phase == "INITIAL_FLICKER" then
        opening.flicker_timer = opening.flicker_timer + DT

        local steps = 0
        while opening.flicker_timer >= OPENING_INITIAL_FLICKER_INTERVAL
            and opening.phase == "INITIAL_FLICKER"
            and steps < 64
        do
            opening.flicker_timer = opening.flicker_timer - OPENING_INITIAL_FLICKER_INTERVAL
            opening.heart_visible = not opening.heart_visible
            steps = steps + 1

            if opening.heart_visible then
                opening.flicker_count = opening.flicker_count + 1
                if opening.flicker_count >= OPENING_INITIAL_FLICKER_COUNT then
                    opening.phase = "ACCELERATING"
                    opening.flicker_timer = 0
                    opening.acceleration_timer = 0
                    opening.fourth_flicker_done = false
                    opening.heart_visible = true
                end
            end
        end
    elseif opening.phase == "ACCELERATING" then
        opening.acceleration_timer = opening.acceleration_timer + DT
        local progress = clamp(opening.acceleration_timer / OPENING_ACCELERATION_TIME, 0, 1)

        opening.kris_alpha = progress

        local interval = opening.fourth_flicker_done
            and self:getOpeningFlickerInterval(progress)
            or OPENING_FOURTH_FLICKER_INTERVAL
        if interval > OPENING_MIN_FLICKER_INTERVAL then
            opening.flicker_timer = opening.flicker_timer + DT

            local steps = 0
            while opening.flicker_timer >= interval and steps < 64 do
                opening.flicker_timer = opening.flicker_timer - interval
                opening.heart_visible = not opening.heart_visible
                opening.fourth_flicker_done = true
                steps = steps + 1
            end
        else
            opening.flicker_timer = 0
        end

        if progress >= 1 then
            opening.phase = "DONE"
            opening.heart_visible = true
        end
    end

    self:applyOpeningVisuals(opening)
    self:lockOpeningPositions(opening)

    if opening.phase == "DONE" then
        self:finishOpening()
    end
end

function KrisFinisher:drawOpeningObject(object)
    if object and object.parent then
        object:fullDraw()
    end
end

function KrisFinisher:draw(fade)
    super.draw(self, fade)

    local opening = self.finisher_opening
    if opening then
        love.graphics.push()
        love.graphics.origin()
        Draw.setColor(1, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        love.graphics.pop()

        if opening.heart_visible then
            self:drawOpeningObject(opening.soul)
        end
        if opening.kris_alpha > 0 then
            self:drawOpeningObject(opening.kris)
        end

        Draw.setColor(1, 1, 1, 1)
    end

    -- Encounter drawing happens after Battle's children, so this covers
    -- bullets, battlers, and Battle UI as one final full-screen layer.
    if self.finisher_wind_background then
        self.finisher_wind_background:drawFullscreenFilter()
    end
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
    self.finisher_kris_sprite = sprite
    self.finisher_soul = kris_soul
end

function KrisFinisher:updateFinisherKris()
    local kris = self.finisher_kris
    if not kris or not kris.parent then
        return
    end
    if self.finisher_tp_reached then
        return
    end

    self.finisher_kris_move_elapsed = self.finisher_kris_move_elapsed + DT

    local segment_time = FINISHER_KRIS_MOVE_SEGMENT_TIME
    local cycle_progress = (self.finisher_kris_move_elapsed % (segment_time * 4)) / segment_time
    local segment = math.floor(cycle_progress)
    local progress = easeInOutSine(cycle_progress - segment)
    local offset_x

    if segment == 0 then
        offset_x = -FINISHER_KRIS_MOVE_DISTANCE * progress
    elseif segment == 1 then
        offset_x = -FINISHER_KRIS_MOVE_DISTANCE * (1 - progress)
    elseif segment == 2 then
        offset_x = FINISHER_KRIS_MOVE_DISTANCE * progress
    else
        offset_x = FINISHER_KRIS_MOVE_DISTANCE * (1 - progress)
    end

    kris:setPosition(FINISHER_KRIS_X + offset_x, FINISHER_KRIS_Y)
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

    self.finisher_star_center_x, self.finisher_star_center_y = self:getFinisherSoulPosition(battle)

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
    if center_x then
        self.finisher_star_center_x = center_x
        self.finisher_star_center_y = center_y
    else
        center_x = self.finisher_star_center_x
        center_y = self.finisher_star_center_y
    end
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
            FINISHER_STAR_ORBIT_SPEED,
            center_x,
            center_y
        )
        battle:addChild(star)
        table.insert(self.finisher_stars, star)
    end

    self.finisher_star_wave_index = self.finisher_star_wave_index + 1
end

function KrisFinisher:clearFinisherStars()
    for index = #self.finisher_stars, 1, -1 do
        local star = self.finisher_stars[index]
        if star and star.parent then
            star:remove()
        end
        self.finisher_stars[index] = nil
    end
end

function KrisFinisher:pruneFinisherStars()
    local write_index = 1
    for read_index = 1, #self.finisher_stars do
        local star = self.finisher_stars[read_index]
        if star and star.parent then
            self.finisher_stars[write_index] = star
            write_index = write_index + 1
        end
    end

    for index = write_index, #self.finisher_stars do
        self.finisher_stars[index] = nil
    end
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

    self:pruneFinisherStars()

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

    battle:spawnSoul(OPENING_PLAYER_POSITION.x, OPENING_PLAYER_POSITION.y)
    battle.soul.transitioning = false
    battle.soul.alpha = battle.soul.target_alpha or 1
    battle.soul:setPosition(OPENING_PLAYER_POSITION.x, OPENING_PLAYER_POSITION.y)
end

function KrisFinisher:update()
    super.update(self)

    self:updateFinisherWindBackground()
    self:updateFinisherSword()

    if self.finisher_opening then
        self:updateOpening()
        return
    end

    self:updateFinisherTransition()
    self:updateFinisherKris()
    self:updateFinisherStarEmitter()
    self:updatePlayerDrift()
end

function KrisFinisher:onBattleEnd()
    self:clearFinisherWindBackground()
    self:clearFinisherWarpBackground()
    self:clearFinisherSlideAfterImage()
    self:clearFinisherSword()
    self:clearFinisherEllipse()
    self:clearFinisherInversion()
    self:clearFinisherHurtFlash()
    self:stopFinisherTransition()
    self:stopFinisherStarEmitter()
    self:restoreVesselDamageNumbers()
end

return KrisFinisher
