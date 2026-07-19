local KrisFinisher, super = Class(Encounter)
local LineCollider = require("src.engine.colliders.linecollider")
local ShaderFX = require("src.engine.drawfx.shaderfx")

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
local FINISHER_SLIDE_LOOP_COUNT = 0
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
local FINISHER_SOUND = {
    tp50 = "kris_knee_slide",
    fountain_wave = "fountain_digging",
    fountain_open = "fountain_open_2s",
    fountain_open_pitch = 0.8,
    fountain_open_hold_time = 2,
    fountain_open_fade_time = 0.5,
    fountain_wave_midpoint = 6 / 60,
}

local FINISHER_ELLIPSE_GROW_TIME = 0.22
local FINISHER_ELLIPSE_START_CENTER_Y = SCREEN_HEIGHT * 0.90
local FINISHER_ELLIPSE_TARGET_CENTER_Y = SCREEN_HEIGHT * 0.05
local FINISHER_ELLIPSE_RADIUS_X = SCREEN_WIDTH * 0.125
local FINISHER_ELLIPSE_START_RADIUS_Y = SCREEN_HEIGHT * 0.20
local FINISHER_ELLIPSE_TARGET_RADIUS_Y = SCREEN_HEIGHT * 0.95
local FINISHER_ELLIPSE_SCALE_AMPLITUDE = 0.025
local FINISHER_ELLIPSE_HORIZONTAL_SCALE_AMPLITUDE = 0.075
local FINISHER_ELLIPSE_SCALE_PERIOD = 0.25
local FINISHER_ELLIPSE_PIXEL_STEP = 2

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

local FINISHER_SOUL_LIGHT_GROW_TIME = 18 / 30
local FINISHER_SOUL_LIGHT_FADE_TIME = 5 / 30
local FINISHER_SOUL_LIGHT_MAX_ALPHA = 0.5
local FINISHER_SOUL_ATTACK_RING_SMALL = 18
local FINISHER_SOUL_ATTACK_RING_MEDIUM = 32
local FINISHER_SOUL_ATTACK_RING_LARGE = 48
local FINISHER_SOUL_ATTACK_WAVE_INTERVAL = 3 / 30
local FINISHER_SOUL_ATTACK_PURE_FADE_TIME = 8 / 30
local FINISHER_SOUL_OUTWARD_STAR_TIME = 0.9
local FINISHER_SOUL_OUTWARD_STAR_START_SCALE = 1
local FINISHER_SOUL_OUTWARD_STAR_SCALE_AMPLITUDE = 0.35
local FINISHER_SOUL_OUTWARD_STAR_INITIAL_SPEED_RATIO = 0.25
local FINISHER_SOUL_OUTWARD_STAR_AFTERIMAGE_INTERVAL = 0.03
local FINISHER_SOUL_OUTWARD_STAR_AFTERIMAGE_ALPHA = 0.65
local FINISHER_SOUL_OUTWARD_STAR_AFTERIMAGE_FADE_TIME = 0.18
local FINISHER_SOUL_ATTACK_MOVE_DELAY = FINISHER_SOUL_OUTWARD_STAR_TIME + 4 / 30
local FINISHER_SOUL_ATTACK_MOVE_TIME = 0.5
local FINISHER_SOUL_ATTACK_MIN_PLAYER_DISTANCE = 104
local FINISHER_SOUL_ATTACK_POSITION_MARGIN = 72
local FINISHER_SOUL_ATTACK_FOUNTAIN_CLEARANCE = 96
local FINISHER_SOUL_ATTACK_SIDE_SWITCH_CHANCE = 0.85
local FINISHER_SOUL_ATTACK_ANGLE_OFFSET = math.rad(15)
local FINISHER_SOUL_ATTACK_ELLIPSE_SIZE = 200
local FINISHER_SOUL_ATTACK_ELLIPSE_TEXTURE_SCALE = { 0.05, 1 }
local FINISHER_SOUL_ATTACK_ELLIPSE_INNER_RADIUS = 40
local FINISHER_SOUL_ATTACK_ELLIPSE_SCALE_X = 3
local FINISHER_SOUL_ATTACK_BEAM_OVERHANG = 48
local FINISHER_SOUL_ATTACK_BEAM_MIN_LENGTH = math.sqrt(
    SCREEN_WIDTH * SCREEN_WIDTH + SCREEN_HEIGHT * SCREEN_HEIGHT
) + FINISHER_SOUL_ATTACK_BEAM_OVERHANG
local FINISHER_SOUL_ATTACK_BEAM_LENGTH_MULTIPLIER = 2
local FINISHER_SOUL_ATTACK_WINDUP_LINE_TRAVEL_TIME = 20 / 60
local FINISHER_SOUL_ATTACK_WINDUP_LINE_WIDTH = 4
local FINISHER_SOUL_ATTACK_WINDUP_LINE_EXIT_MARGIN = 8
local FINISHER_SOUL_ATTACK_WINDUP_LINE_DELAY = 0.18
local FINISHER_SOUL_ATTACK_ELLIPSE_START_DELAY = FINISHER_SOUL_ATTACK_WINDUP_LINE_TRAVEL_TIME
    + FINISHER_SOUL_ATTACK_WINDUP_LINE_DELAY
local FINISHER_SOUL_ATTACK_ELLIPSE_EXPAND_TIME = 4 / 60
local FINISHER_SOUL_ATTACK_ELLIPSE_HOLLOW_DELAY = FINISHER_SOUL_ATTACK_ELLIPSE_EXPAND_TIME
local FINISHER_SOUL_ATTACK_ELLIPSE_HOLD_TIME = 2 / 60
local FINISHER_SOUL_ATTACK_ELLIPSE_SHRINK_TIME = 15 / 60
local FINISHER_SOUL_ATTACK_ELLIPSE_LIFETIME = FINISHER_SOUL_ATTACK_ELLIPSE_EXPAND_TIME
    + FINISHER_SOUL_ATTACK_ELLIPSE_HOLD_TIME
    + FINISHER_SOUL_ATTACK_ELLIPSE_SHRINK_TIME
local FINISHER_SOUL_ATTACK_WINDUP_LINE_LIFETIME = FINISHER_SOUL_ATTACK_ELLIPSE_START_DELAY
    + FINISHER_SOUL_ATTACK_ELLIPSE_LIFETIME
-- Keep the finisher effects below the TP bar while preserving Soul-over-effect order.
local FINISHER_SOUL_ATTACK_STAR_LAYER = BATTLE_LAYERS["ui"] - 5
local FINISHER_SOUL_ATTACK_ELLIPSE_LAYER = BATTLE_LAYERS["ui"] - 4
local FINISHER_SOUL_ATTACK_CIRCLE_LAYER = BATTLE_LAYERS["ui"] - 3
local FINISHER_SOUL_LIGHT_OVERLAY_LAYER = BATTLE_LAYERS["ui"] - 2.5
local FINISHER_SOUL_OVERLAY_LAYER = BATTLE_LAYERS["ui"] - 2
local FINISHER_PLAYER_SOUL_LAYER = FINISHER_SOUL_ATTACK_ELLIPSE_LAYER
local FINISHER_SOUL_ATTACK_BEAM_DAMAGE = 42
local FINISHER_SOUL_ATTACK_BEAM_DAMAGE_DELAY = FINISHER_SOUL_ATTACK_ELLIPSE_START_DELAY
local FINISHER_SOUL_ATTACK_BEAM_DAMAGE_TIME = 1 / 60

local FINISHER_WAVE_CIRCLE_BASE_Y = 60
local FINISHER_WAVE_CIRCLE_RADIUS = 56
local FINISHER_WAVE_CIRCLE_BORDER_WIDTH = 4
local FINISHER_WAVE_CIRCLE_SPACING = 92
local FINISHER_WAVE_CIRCLE_SPEED = 84
local FINISHER_WAVE_CIRCLE_BOB_AMPLITUDE = 1.75
local FINISHER_WAVE_CIRCLE_BOB_SPEED = 2.4
local FINISHER_WAVE_CIRCLE_PATTERN = { 16, 4, -10, 4, 16 }
local FINISHER_WAVE_CIRCLE_CURTAIN_RAISE = 20
local FINISHER_WAVE_CIRCLE_FALL_TIME = 5
local FINISHER_WAVE_CIRCLE_PATTERN_MAX = 16
local FINISHER_WAVE_CIRCLE_START_HEIGHT = -(
    FINISHER_WAVE_CIRCLE_BASE_Y
        + FINISHER_WAVE_CIRCLE_RADIUS
        + FINISHER_WAVE_CIRCLE_BORDER_WIDTH
        + FINISHER_WAVE_CIRCLE_PATTERN_MAX
        + 4
)
-- Move down by one full base-height after entering from above the screen.
local FINISHER_WAVE_CIRCLE_TARGET_HEIGHT = FINISHER_WAVE_CIRCLE_BASE_Y
local FINISHER_WAVE_CIRCLE_COUNT = math.ceil(SCREEN_WIDTH / FINISHER_WAVE_CIRCLE_SPACING) + 4

-- These centers are measured from the 1280x960 reference composite and
-- divided by two for the 640x480 battle coordinate space.
local FINISHER_FOUNTAIN_FLASH_POSITIONS = {
    { 226.4, 188.2 },
    { 242.9, 205.6 },
    { 264.7, 184.5 },
    { 284.0, 174.9 },
    { 300.6, 192.3 },
    { 322.5, 171.4 },
    { 355.7, 193.6 },
    { 390.5, 176.6 },
    { 407.0, 194.1 },
    { 428.5, 172.9 },
}
local FINISHER_FOUNTAIN_FLASH_FIRST_WAVE_COUNT = 2

local FINISHER_RAIN_TEXTURE_WIDTH = 22
local FINISHER_RAIN_TEXTURE_HEIGHT = 30
local FINISHER_RAIN_SCALE = 1
local FINISHER_RAIN_SPAWN_Y = -(FINISHER_RAIN_TEXTURE_HEIGHT * FINISHER_RAIN_SCALE) / 2
local FINISHER_RAIN_SPAWN_INTERVAL_MIN = 0.01
local FINISHER_RAIN_SPAWN_INTERVAL_MAX = 0.5
local FINISHER_RAIN_SPAWN_INTERVAL_BIAS_POWER = 4
local FINISHER_RAIN_MAX_SPAWNS_PER_UPDATE = 32
-- 50 TP starts the existing finisher sequence. 100 TP is the final quiet
-- scene layered on top of the fountain that sequence creates.
local FINISHER_STOP_TP = 50
local FINISHER_FINAL_TP = 100
local FINISHER_TP100 = {
    post_tp_bullet_tp = 2,
    red_delay = 2,
    center_delay = 1,
    player_move_time = 1,
    player_burst_time = 0.2,
    player_burst_layer = BATTLE_LAYERS["ui"] - 3.5,
    echo_delay = 1,
    echo_duration = 20 / 30,
    echo_second_offset = (20 / 30) / 2,
    echo_to_sequence_delay = 0.5,
    soul_shine_frame_time = 4 / 30,
    soul_shine_frame_count = 11,
    soul_shine_shake_frame = 8,
    soul_shine_layer = BATTLE_LAYERS["ui"] - 1.5,
    soul_shine_texture = "kris_finisher/soul_shine/frame_",
    final_white_hold_time = 1,
    final_black_fade_time = 0.6,
    final_black_hold_time = 5,
    final_shake_x = 8,
}
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

local FINISHER_FOUNTAIN_COVER_SHADER_SOURCE = [[
    extern Image fountainMask;

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
        vec4 source = Texel(tex, uv);
        float amount = Texel(fountainMask, uv).a;
        vec3 result = mix(source.rgb, vec3(0.0), amount);
        float alpha = max(source.a, amount);
        return vec4(result, alpha) * color;
    }
]]

local FINISHER_FOUNTAIN_INVERT_SHADER_SOURCE = [[
    extern Image fountainMask;
    extern Image circleMask;

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
        vec4 source = Texel(tex, uv);
        float amount = Texel(fountainMask, uv).a;
        amount *= 1.0 - Texel(circleMask, uv).a;
        vec3 inverted = vec3(1.0) - source.rgb;
        vec3 result = mix(source.rgb, inverted, amount);
        float alpha = max(source.a, amount);
        return vec4(result, alpha) * color;
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
-- The WAV has trailing silence after about 0.904 seconds. Only schedule
-- through the last audible part so that silence is not counted as a lead.
local OPENING_ELECTRIC_SOUND_DURATION = 0.904014 - 0.1
local OPENING_ELECTRIC_SOUND = "kris_finisher_electric"
local OPENING_JUMPSCARE_SOUND = "kris_chase_jumpscare"

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

local function easeInOutCubic(progress)
    if progress < 0.5 then
        return 4 * progress * progress * progress
    end

    return 1 - ((-2 * progress + 2) ^ 3) / 2
end

local function makeHardEllipse(size, scale, inner_radius)
    local scale_x, scale_y = scale[1], scale[2]
    local image_data = love.image.newImageData(size, size)
    local center_x, center_y = (size - 1) / 2, (size - 1) / 2
    local radius = center_x

    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local dx = (x - center_x) / scale_x
            local dy = (y - center_y) / scale_y
            local distance = math.sqrt(dx * dx + dy * dy)
            local alpha = distance > inner_radius and distance <= radius and 1 or 0
            image_data:setPixel(x, y, 1, 1, 1, alpha)
        end
    end

    local image = love.graphics.newImage(image_data)
    image:setFilter("nearest", "nearest")
    return image
end

local function distanceToScreenEdge(x, y, direction_x, direction_y)
    local distance = math.huge

    if direction_x > 0 then
        distance = math.min(distance, (SCREEN_WIDTH - x) / direction_x)
    elseif direction_x < 0 then
        distance = math.min(distance, -x / direction_x)
    end
    if direction_y > 0 then
        distance = math.min(distance, (SCREEN_HEIGHT - y) / direction_y)
    elseif direction_y < 0 then
        distance = math.min(distance, -y / direction_y)
    end

    return math.max(distance, 0)
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
    self.visible = false
end

function FinisherHurtFlash:restart()
    self.time = 0
    self.alpha = 0
    self.active = true
    self.visible = false
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

-- A short red echo of the player's heart. It is deliberately a normal
-- sprite, so the TP100 scene does not depend on any post-processing stage.
local FinisherPlayerBurst, player_burst_super = Class(Sprite)

function FinisherPlayerBurst:init(x, y, base_scale, duration)
    player_burst_super.init(self, "player/heart_dodge", x, y)

    self:setOrigin(0.5, 0.5)
    self.layer = FINISHER_TP100.player_burst_layer
    self.base_scale = base_scale or 1
    self.duration = duration or FINISHER_TP100.player_burst_time
    self.elapsed = 0
    self:setScale(self.base_scale, self.base_scale)
    self:setColor(1, 0, 0, 1)
end

function FinisherPlayerBurst:update()
    self.elapsed = self.elapsed + DT
    local progress = clamp(self.elapsed / self.duration, 0, 1)
    self:setScale(
        self.base_scale * (1 + progress),
        self.base_scale * (1 + progress)
    )
    self.alpha = 1 - progress

    if progress >= 1 then
        self:remove()
        return
    end

    player_burst_super.update(self)
end

local FinisherSoulShineSequence, soul_shine_sequence_super = Class(Sprite)

function FinisherSoulShineSequence:init(battle, on_finished)
    local frames = {}
    for index = 1, FINISHER_TP100.soul_shine_frame_count do
        local texture = Assets.getTexture(string.format(
            "%s%02d",
            FINISHER_TP100.soul_shine_texture,
            index
        ))
        if not texture then
            break
        end
        texture:setFilter("nearest", "nearest")
        table.insert(frames, texture)
    end

    local first_frame = frames[1]
    if not first_frame then
        return
    end

    soul_shine_sequence_super.init(
        self,
        first_frame,
        SCREEN_WIDTH / 2,
        SCREEN_HEIGHT / 2
    )
    self:setFrames(frames)
    self:setFrame(1)
    self:setOrigin(0.5, 0.5)
    self:setScale(
        SCREEN_WIDTH / first_frame:getWidth(),
        SCREEN_HEIGHT / first_frame:getHeight()
    )
    self.layer = FINISHER_TP100.soul_shine_layer
    self.battle = battle
    self.on_finished = on_finished
    self.elapsed = 0
    self.shake_started = false
    self.finished = false
end

function FinisherSoulShineSequence:update()
    self.elapsed = self.elapsed + DT

    while self.elapsed >= FINISHER_TP100.soul_shine_frame_time
        and not self.finished
    do
        self.elapsed = self.elapsed - FINISHER_TP100.soul_shine_frame_time
        local next_frame = math.min(self.frame + 1, #self.frames)
        self:setFrame(next_frame)

        if next_frame >= FINISHER_TP100.soul_shine_shake_frame
            and not self.shake_started
        then
            self.shake_started = true
            if self.battle and self.battle.shakeCamera then
                self.battle:shakeCamera(FINISHER_TP100.final_shake_x, 0, 0)
            end
        end

        if next_frame >= #self.frames then
            self.finished = true
            self.elapsed = 0
            if self.on_finished then
                local callback = self.on_finished
                self.on_finished = nil
                callback(self)
            end
        end
    end

    soul_shine_sequence_super.update(self)
end

function FinisherSoulShineSequence:onRemove(parent)
    if self.battle and self.battle.camera and self.battle.camera.stopShake then
        self.battle.camera:stopShake()
    end
    soul_shine_sequence_super.onRemove(self, parent)
end

local FinisherFinalScreenOverlay, final_screen_overlay_super = Class(Object)

function FinisherFinalScreenOverlay:init(on_finished)
    final_screen_overlay_super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = BATTLE_LAYERS["top"] + 2
    self.phase = "WHITE"
    self.elapsed = 0
    self.white_alpha = 1
    self.black_alpha = 0
    self.on_finished = on_finished
end

function FinisherFinalScreenOverlay:update()
    self.elapsed = self.elapsed + DT

    if self.phase == "WHITE" then
        self.white_alpha = 1
        self.black_alpha = 0
        if self.elapsed >= FINISHER_TP100.final_white_hold_time then
            self.phase = "BLACK"
            self.elapsed = 0
        end
    elseif self.phase == "BLACK" then
        -- Keep the white layer underneath while black fades over it.
        self.white_alpha = 1
        self.black_alpha = clamp(
            self.elapsed / FINISHER_TP100.final_black_fade_time,
            0,
            1
        )
        if self.elapsed >= FINISHER_TP100.final_black_fade_time
            + FINISHER_TP100.final_black_hold_time
            and self.on_finished
        then
            local callback = self.on_finished
            self.on_finished = nil
            callback(self)
        end
    end

    final_screen_overlay_super.update(self)
end

function FinisherFinalScreenOverlay:draw()
    love.graphics.push("all")
    love.graphics.origin()
    Draw.setColor(1, 1, 1, self.white_alpha)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    if self.black_alpha > 0 then
        Draw.setColor(0, 0, 0, self.black_alpha)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    end
    love.graphics.pop()
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

local FinisherFountain, fountain_super = Class(Object)

function FinisherFountain:init(options)
    options = options or {}
    fountain_super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = BATTLE_LAYERS["background"] - 1
    self.elapsed = 0
    self.grow_finished = false
    self.on_grow_complete = options.on_grow_complete
    self.on_remove_callback = options.on_remove
    self.center_x = SCREEN_WIDTH / 2
    self.center_y = FINISHER_ELLIPSE_START_CENTER_Y
    self.radius_x = FINISHER_ELLIPSE_RADIUS_X
    self.radius_y = FINISHER_ELLIPSE_START_RADIUS_Y
    self.mask_canvas = love.graphics.newCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
    self.mask_canvas:setFilter("nearest", "nearest")
    self.ordinary_draw = false
    self.ordinary_color = { 1, 1, 1, 1 }
    self:setColor(0, 0, 0, 1)
    if not self.ordinary_draw then
        self:updateMaskCanvas()
    end
end

function FinisherFountain:update()
    self.elapsed = self.elapsed + DT

    local progress = clamp(self.elapsed / FINISHER_ELLIPSE_GROW_TIME, 0, 1)
    local eased = 1 - (1 - progress) * (1 - progress) * (1 - progress)
    if self.grow_finished then
        local cycle = (self.elapsed - FINISHER_ELLIPSE_GROW_TIME)
            / FINISHER_ELLIPSE_SCALE_PERIOD
        local scale_wave = math.sin(cycle * math.pi * 2)
        local scale_y = 1 + FINISHER_ELLIPSE_SCALE_AMPLITUDE * scale_wave
        local scale_x = 1 + FINISHER_ELLIPSE_HORIZONTAL_SCALE_AMPLITUDE * scale_wave
        self.radius_x = FINISHER_ELLIPSE_RADIUS_X * scale_x
        self.radius_y = FINISHER_ELLIPSE_TARGET_RADIUS_Y * scale_y
        self.center_y = SCREEN_HEIGHT - self.radius_y
    else
        self.center_y = FINISHER_ELLIPSE_START_CENTER_Y
            + (FINISHER_ELLIPSE_TARGET_CENTER_Y - FINISHER_ELLIPSE_START_CENTER_Y) * eased
        self.radius_y = FINISHER_ELLIPSE_START_RADIUS_Y
            + (FINISHER_ELLIPSE_TARGET_RADIUS_Y - FINISHER_ELLIPSE_START_RADIUS_Y) * eased
    end

    if not self.ordinary_draw then
        self:updateMaskCanvas()
    end

    if progress >= 1 and not self.grow_finished then
        self.grow_finished = true
        if self.on_grow_complete then
            self.on_grow_complete(self)
        end
    end

    fountain_super.update(self)
end

function FinisherFountain:drawPixelatedShape()
    -- Fill the ellipse in snapped scanlines so its boundary keeps a chunky,
    -- deliberately pixelated staircase instead of a smooth vector edge.
    local step = FINISHER_ELLIPSE_PIXEL_STEP
    local top = math.floor((self.center_y - self.radius_y) / step) * step
    local bottom = math.ceil((self.center_y + self.radius_y) / step) * step
    for y = top, bottom - step, step do
        local sample_y = y + step / 2
        local normalized_y = (sample_y - self.center_y) / self.radius_y
        if math.abs(normalized_y) <= 1 then
            local half_width = self.radius_x
                * math.sqrt(1 - normalized_y * normalized_y)
            local left = math.floor((self.center_x - half_width) / step) * step
            local right = math.ceil((self.center_x + half_width) / step) * step
            love.graphics.rectangle("fill", left, y, right - left, step)
        end
    end
end

function FinisherFountain:updateMaskCanvas()
    if not self.mask_canvas then
        return
    end

    local old_shader = love.graphics.getShader()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    Draw.pushCanvas(self.mask_canvas)
    love.graphics.setShader()
    love.graphics.clear(0, 0, 0, 0)
    Draw.setColor(1, 1, 1, 1)
    self:drawPixelatedShape()
    Draw.popCanvas()

    love.graphics.setShader(old_shader)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

function FinisherFountain:releaseMaskCanvas()
    if self.mask_canvas then
        self.mask_canvas:release()
        self.mask_canvas = nil
    end
end

function FinisherFountain:onRemove()
    if self.on_remove_callback then
        self.on_remove_callback(self)
    end
    self:releaseMaskCanvas()
end

function FinisherFountain:setOrdinaryDraw(enabled, r, g, b, a)
    self.ordinary_draw = enabled and true or false
    if r then
        self.ordinary_color = { r, g, b, a or 1 }
    end
    if self.ordinary_draw then
        self:releaseMaskCanvas()
    end
end

function FinisherFountain:setOrdinaryColor(r, g, b, a)
    self.ordinary_color = { r, g, b, a or self.ordinary_color[4] or 1 }
end

function FinisherFountain:draw()
    if not self.ordinary_draw then
        return
    end

    -- The fountain is authored in screen coordinates, matching its mask. Draw
    -- the same hard-pixel ellipse directly when the final scene disables FX.
    love.graphics.push("all")
    love.graphics.origin()
    Draw.setColor(
        self.ordinary_color[1],
        self.ordinary_color[2],
        self.ordinary_color[3],
        self.ordinary_color[4]
    )
    self:drawPixelatedShape()
    love.graphics.pop()
end

local FinisherFlyingSword, finisher_sword_super = Class(Bullet)

function FinisherFlyingSword:init(x, y, options)
    options = options or {}
    finisher_sword_super.init(self, x, y, "bullets/flying_sword/normal")

    -- Keep the finisher sword's damage and hitbox aligned with the normal
    -- round-5 flying sword.
    self:setSprite("bullets/flying_sword/normal")
    self:setScale(2.25)
    self.rotation = math.pi
    self.layer = BATTLE_LAYERS["top"] + 1
    self.damage = 42
    self.tp = FINISHER_TP100.post_tp_bullet_tp
    self:setHitbox(25, 4, 10, 54)
    self.collidable = true
    self.can_graze = true
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
    self.on_dive = options.on_dive

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
            if self.on_dive then
                self.on_dive(self)
            end
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

local FinisherSoulLight, soul_light_super = Class(Sprite)

function FinisherSoulLight:init(on_bright, on_finished)
    soul_light_super.init(self, "bullets/soul/light")

    self:setOrigin(0.5, 0.5)
    self:setScale(1)
    self:setColor(1, 1, 1, 0)
    self.layer = -1
    self.elapsed = 0
    self.phase = "GROW"
    self.on_bright = on_bright
    self.on_finished = on_finished
end

function FinisherSoulLight:update()
    self.elapsed = self.elapsed + DT

    if self.phase == "GROW" then
        local progress = clamp(self.elapsed / FINISHER_SOUL_LIGHT_GROW_TIME, 0, 1)
        local eased = progress * progress * progress
        self.alpha = FINISHER_SOUL_LIGHT_MAX_ALPHA * eased

        if progress >= 1 then
            self.phase = "FADE"
            self.elapsed = 0
            if self.on_bright then
                self.on_bright(self)
            end
        end
    else
        local progress = clamp(self.elapsed / FINISHER_SOUL_LIGHT_FADE_TIME, 0, 1)
        self.alpha = FINISHER_SOUL_LIGHT_MAX_ALPHA * (1 - progress)
        if progress >= 1 then
            local on_finished = self.on_finished
            self.on_finished = nil
            self:remove()
            if on_finished then
                on_finished(self)
            end
            return
        end
    end

    soul_light_super.update(self)
end

-- The source light stays attached to the enemy soul for positioning, but its
-- pixels are drawn by a Battle-level proxy so it can sit above the wave.
function FinisherSoulLight:draw() end

local FinisherSoulLightOverlay, soul_light_overlay_super = Class(Sprite)

function FinisherSoulLightOverlay:init()
    soul_light_overlay_super.init(self, "bullets/soul/light")

    self:setOrigin(0.5, 0.5)
    self.layer = FINISHER_SOUL_LIGHT_OVERLAY_LAYER
    self.source = nil
    self.visible = false
end

function FinisherSoulLightOverlay:update()
    local source = self.source
    if source and source.parent and self.parent then
        local x, y = source:getRelativePos(
            source.width / 2,
            source.height / 2,
            self.parent
        )
        self:setPosition(x, y)
        self:setScale(source.scale_x, source.scale_y)
        self.rotation = source.rotation
        self:setColor(source.color[1], source.color[2], source.color[3], source.alpha)
        self.visible = source:isFullyActive()
            and source.visible
            and source.parent.visible
    else
        self.visible = false
    end

    soul_light_overlay_super.update(self)
end

local FinisherWaveCircles, wave_circles_super = Class(Object)

function FinisherWaveCircles:init()
    wave_circles_super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = FINISHER_SOUL_ATTACK_CIRCLE_LAYER
    self.elapsed = 0
    self.wave_height = FINISHER_WAVE_CIRCLE_START_HEIGHT
    self.next_circle_index = FINISHER_WAVE_CIRCLE_COUNT + 1
    self.circles = {}

    for index = 1, FINISHER_WAVE_CIRCLE_COUNT do
        table.insert(self.circles, {
            x = (index - 2) * FINISHER_WAVE_CIRCLE_SPACING,
            index = index,
        })
    end

    self.mask_canvas = love.graphics.newCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
    self.mask_canvas:setFilter("nearest", "nearest")
    self:updateMaskCanvas()
end

function FinisherWaveCircles:update()
    self.elapsed = self.elapsed + DT
    local fall_progress = clamp(self.elapsed / FINISHER_WAVE_CIRCLE_FALL_TIME, 0, 1)
    local fall_eased = 1 - (1 - fall_progress) * (1 - fall_progress) * (1 - fall_progress)
    self.wave_height = FINISHER_WAVE_CIRCLE_START_HEIGHT
        + (FINISHER_WAVE_CIRCLE_TARGET_HEIGHT - FINISHER_WAVE_CIRCLE_START_HEIGHT)
        * fall_eased
    local shift = FINISHER_WAVE_CIRCLE_SPEED * DT

    for _, circle in ipairs(self.circles) do
        circle.x = circle.x - shift
    end

    local left_limit = -FINISHER_WAVE_CIRCLE_RADIUS - FINISHER_WAVE_CIRCLE_BORDER_WIDTH
    while self.circles[1] and self.circles[1].x < left_limit do
        local first = table.remove(self.circles, 1)
        local last = self.circles[#self.circles]
        first.x = last.x + FINISHER_WAVE_CIRCLE_SPACING
        first.index = self.next_circle_index
        self.next_circle_index = self.next_circle_index + 1
        table.insert(self.circles, first)
    end

    self:updateMaskCanvas()
    wave_circles_super.update(self)
end

function FinisherWaveCircles:getCircleY(circle)
    local pattern_index = ((circle.index - 1) % #FINISHER_WAVE_CIRCLE_PATTERN) + 1
    local bob = math.sin(
        self.elapsed * FINISHER_WAVE_CIRCLE_BOB_SPEED + circle.index * 0.55
    ) * FINISHER_WAVE_CIRCLE_BOB_AMPLITUDE
    return FINISHER_WAVE_CIRCLE_BASE_Y
        + self.wave_height
        + FINISHER_WAVE_CIRCLE_PATTERN[pattern_index]
        + bob
end

function FinisherWaveCircles:getCoverBottom()
    return FINISHER_WAVE_CIRCLE_BASE_Y
        + self.wave_height
        + FINISHER_WAVE_CIRCLE_RADIUS
        + FINISHER_WAVE_CIRCLE_PATTERN[3]
        - FINISHER_WAVE_CIRCLE_CURTAIN_RAISE
end

function FinisherWaveCircles:drawBlackCurtain()
    local cover_bottom = math.max(0, self:getCoverBottom())
    if cover_bottom <= 0 then
        return
    end
    love.graphics.rectangle(
        "fill",
        0,
        0,
        SCREEN_WIDTH,
        cover_bottom
    )
end

function FinisherWaveCircles:drawOuterCircles()
    for _, circle in ipairs(self.circles) do
        love.graphics.circle(
            "fill",
            circle.x,
            self:getCircleY(circle),
            FINISHER_WAVE_CIRCLE_RADIUS + FINISHER_WAVE_CIRCLE_BORDER_WIDTH,
            48
        )
    end
end

function FinisherWaveCircles:updateMaskCanvas()
    if not self.mask_canvas then
        return
    end

    local old_shader = love.graphics.getShader()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    love.graphics.push("all")
    love.graphics.origin()
    Draw.pushCanvas(self.mask_canvas)
    love.graphics.setShader()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    self:drawBlackCurtain()
    self:drawOuterCircles()
    Draw.popCanvas()
    love.graphics.pop()

    love.graphics.setShader(old_shader)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

function FinisherWaveCircles:onRemove()
    if self.mask_canvas then
        self.mask_canvas:release()
        self.mask_canvas = nil
    end
end

function FinisherWaveCircles:draw()
    love.graphics.push("all")
    love.graphics.origin()

    local old_blend, old_alpha_mode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("alpha")

    -- The area above the wave is a solid black curtain. The circle bottoms
    -- remain visible below it as the moving wave edge.
    love.graphics.setColor(0, 0, 0, 1)
    self:drawBlackCurtain()

    -- Draw all expanded white silhouettes first, then black interiors. This
    -- removes the borders between overlapping circles while keeping the outer
    -- outline connected across the entire wave.
    love.graphics.setColor(1, 1, 1, 1)
    self:drawOuterCircles()

    love.graphics.setColor(0, 0, 0, 1)
    for _, circle in ipairs(self.circles) do
        love.graphics.circle(
            "fill",
            circle.x,
            self:getCircleY(circle),
            FINISHER_WAVE_CIRCLE_RADIUS,
            48
        )
    end

    -- Hide the upper circle outlines so only the lower wave edge remains.
    love.graphics.setColor(0, 0, 0, 1)
    self:drawBlackCurtain()

    love.graphics.setBlendMode(old_blend, old_alpha_mode)
    love.graphics.pop()
end

local FinisherSoulOverlay, soul_overlay_super = Class(Sprite)

function FinisherSoulOverlay:init(source)
    soul_overlay_super.init(self, "bullets/soul/soul_0")

    self:setOrigin(0.5, 0.5)
    self.layer = FINISHER_SOUL_OVERLAY_LAYER
    self.source = source
    self.visible = false
end

function FinisherSoulOverlay:update()
    local source = self.source
    if not source or not source.parent or not self.parent then
        self:remove()
        return
    end

    local x, y = source:getRelativePos(
        source.width / 2,
        source.height / 2,
        self.parent
    )
    self:setPosition(x, y)
    self:setScale(source.scale_x, source.scale_y)
    self.rotation = source.rotation
    self:setColor(source.color[1], source.color[2], source.color[3], source.alpha)
    self.visible = source:isFullyActive() and source.visible and source.parent.visible

    soul_overlay_super.update(self)
end

local FinisherSoulPureStar, soul_pure_star_super = Class(Bullet)

function FinisherSoulPureStar:init(x, y, scale)
    soul_pure_star_super.init(self, x, y, "bullets/star_pure")

    self.layer = FINISHER_SOUL_ATTACK_STAR_LAYER
    self.damage = 42
    self.tp = FINISHER_TP100.post_tp_bullet_tp
    self.can_graze = false
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self:setScale(scale or 1)
    self:setColor(1, 1, 1, 1)
    self.elapsed = 0
    self.collidable = true
end

function FinisherSoulPureStar:update()
    self.elapsed = self.elapsed + DT
    local progress = clamp(self.elapsed / FINISHER_SOUL_ATTACK_PURE_FADE_TIME, 0, 1)
    self.alpha = 1 - progress
    self.collidable = progress < 1

    if progress >= 1 then
        self:remove()
        return
    end

    soul_pure_star_super.update(self)
end

local FinisherSoulOutwardStar, outward_star_super = Class(Bullet)

function FinisherSoulOutwardStar:init(x, y, angle, center_x, center_y)
    outward_star_super.init(self, x, y, "bullets/star")

    self.layer = FINISHER_SOUL_ATTACK_STAR_LAYER - 0.25
    self.damage = 42
    self.tp = FINISHER_TP100.post_tp_bullet_tp
    self.can_graze = true
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self:setColor(1, 1, 1, 1)
    self:setScale(FINISHER_SOUL_OUTWARD_STAR_START_SCALE)
    self.rotation = 0

    self.angle = angle
    self.center_x = center_x
    self.center_y = center_y
    self.start_radius = FINISHER_SOUL_ATTACK_RING_LARGE
    self.end_radius = math.max(SCREEN_WIDTH, SCREEN_HEIGHT) * 0.9
    self.elapsed = 0
    self.afterimage_elapsed = 0

    self.sprite.alpha = 1
    self.ghost = Sprite("bullets/star", 0, 0)
    self.ghost:setColor(1, 1, 1, 1)
    self.ghost.layer = -0.001
    self:addChild(self.ghost)
end

function FinisherSoulOutwardStar:spawnAfterImage()
    if not self.ghost or not self.ghost.parent then
        return
    end

    self.ghost:addChild(LightAfterImage(
        self.ghost,
        FINISHER_SOUL_OUTWARD_STAR_AFTERIMAGE_ALPHA,
        FINISHER_SOUL_OUTWARD_STAR_AFTERIMAGE_FADE_TIME
    ))
end

function FinisherSoulOutwardStar:update()
    self.elapsed = self.elapsed + DT
    local progress = clamp(self.elapsed / FINISHER_SOUL_OUTWARD_STAR_TIME, 0, 1)
    local cubic_movement = progress * progress * progress
    local movement = FINISHER_SOUL_OUTWARD_STAR_INITIAL_SPEED_RATIO * progress
        + (1 - FINISHER_SOUL_OUTWARD_STAR_INITIAL_SPEED_RATIO) * cubic_movement
    local radius = self.start_radius + (self.end_radius - self.start_radius) * movement

    self.x = self.center_x + math.cos(self.angle) * radius
    self.y = self.center_y + math.sin(self.angle) * radius
    self.rotation = 0

    local pulse = 0.5 + 0.5 * math.sin(self.elapsed * math.pi * 2 * 3.5)
    self:setScale(
        FINISHER_SOUL_OUTWARD_STAR_START_SCALE
            + FINISHER_SOUL_OUTWARD_STAR_SCALE_AMPLITUDE * pulse
    )

    self.afterimage_elapsed = self.afterimage_elapsed + DT
    while self.afterimage_elapsed >= FINISHER_SOUL_OUTWARD_STAR_AFTERIMAGE_INTERVAL do
        self.afterimage_elapsed = self.afterimage_elapsed
            - FINISHER_SOUL_OUTWARD_STAR_AFTERIMAGE_INTERVAL
        self:spawnAfterImage()
    end

    if progress >= 1 then
        self:remove()
        return
    end

    outward_star_super.update(self)
end

local FinisherSoulAttackEllipse, soul_attack_ellipse_super = Class(Sprite)

function FinisherSoulAttackEllipse:init(x, y, texture, rotation, beam_length, visible_start, visible_end)
    soul_attack_ellipse_super.init(self, texture, x, y)

    self:setOrigin(0.5, 0.5)
    self:setScale(
        0,
        beam_length / FINISHER_SOUL_ATTACK_ELLIPSE_SIZE
    )
    self:setColor(1, 1, 1, 0)
    self.layer = FINISHER_SOUL_ATTACK_ELLIPSE_LAYER
    self.rotation = rotation
    self.elapsed = 0
    self.visible_start = visible_start or 0
    self.visible_end = visible_end
end

function FinisherSoulAttackEllipse:update()
    self.elapsed = self.elapsed + DT

    local active_elapsed = self.elapsed - FINISHER_SOUL_ATTACK_ELLIPSE_START_DELAY
    if active_elapsed < 0 then
        self.scale_x = 0
        self.alpha = 0
    else
        if active_elapsed < FINISHER_SOUL_ATTACK_ELLIPSE_EXPAND_TIME then
            local expand_progress = clamp(
                active_elapsed / FINISHER_SOUL_ATTACK_ELLIPSE_EXPAND_TIME,
                0,
                1
            )
            self.scale_x = FINISHER_SOUL_ATTACK_ELLIPSE_SCALE_X * expand_progress
        elseif active_elapsed < FINISHER_SOUL_ATTACK_ELLIPSE_EXPAND_TIME
            + FINISHER_SOUL_ATTACK_ELLIPSE_HOLD_TIME
        then
            self.scale_x = FINISHER_SOUL_ATTACK_ELLIPSE_SCALE_X
        else
            local shrink_progress = clamp(
                (active_elapsed - FINISHER_SOUL_ATTACK_ELLIPSE_EXPAND_TIME
                    - FINISHER_SOUL_ATTACK_ELLIPSE_HOLD_TIME)
                    / FINISHER_SOUL_ATTACK_ELLIPSE_SHRINK_TIME,
                0,
                1
            )
            self.scale_x = FINISHER_SOUL_ATTACK_ELLIPSE_SCALE_X * (1 - shrink_progress)
        end
        self.alpha = active_elapsed >= self.visible_start
            and (not self.visible_end or active_elapsed < self.visible_end)
            and 1
            or 0
    end

    if active_elapsed >= FINISHER_SOUL_ATTACK_ELLIPSE_LIFETIME then
        self:remove()
        return
    end

    soul_attack_ellipse_super.update(self)
end

local FinisherSoulAttackWindupLine, windup_line_super = Class(Object)

function FinisherSoulAttackWindupLine:init(center_x, center_y, direction, length)
    local direction_x = math.cos(direction)
    local direction_y = math.sin(direction)
    local exit_padding = length / 2
        + FINISHER_SOUL_ATTACK_WINDUP_LINE_EXIT_MARGIN
    local start_distance = distanceToScreenEdge(
        center_x,
        center_y,
        -direction_x,
        -direction_y
    ) + exit_padding
    local start_x = center_x - direction_x * start_distance
    local start_y = center_y - direction_y * start_distance
    windup_line_super.init(
        self,
        start_x,
        start_y,
        length,
        FINISHER_SOUL_ATTACK_WINDUP_LINE_WIDTH
    )

    self:setOrigin(0.5, 0.5)
    self:setColor(1, 1, 1, 1)
    self.rotation = direction
    self.layer = FINISHER_SOUL_ATTACK_ELLIPSE_LAYER
    self.collidable = false
    self.start_x = start_x
    self.start_y = start_y
    self.center_x = center_x
    self.center_y = center_y
    self.elapsed = 0
end

function FinisherSoulAttackWindupLine:update()
    self.elapsed = self.elapsed + DT
    local progress = clamp(
        self.elapsed / FINISHER_SOUL_ATTACK_WINDUP_LINE_TRAVEL_TIME,
        0,
        1
    )
    self.x = self.start_x + (self.center_x - self.start_x) * progress
    self.y = self.start_y + (self.center_y - self.start_y) * progress

    if self.elapsed >= FINISHER_SOUL_ATTACK_WINDUP_LINE_LIFETIME then
        self:remove()
        return
    end

    windup_line_super.update(self)
end

function FinisherSoulAttackWindupLine:draw()
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
end

local FinisherSoulAttackBeam, soul_attack_beam_super = Class(Bullet)

function FinisherSoulAttackBeam:init(x, y, direction, length)
    soul_attack_beam_super.init(self, x, y)

    self.width = length
    self.height = 1
    self:setOrigin(0, 0)
    self:setScale(1, 1)
    self.rotation = direction
    self.layer = FINISHER_SOUL_ATTACK_ELLIPSE_LAYER
    self.collider = LineCollider(self, -length / 2, 0, length / 2, 0)
    self.damage = FINISHER_SOUL_ATTACK_BEAM_DAMAGE
    self.tp = FINISHER_TP100.post_tp_bullet_tp
    self.can_graze = true
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.collidable = false
    self.elapsed = 0
end

function FinisherSoulAttackBeam:update()
    self.elapsed = self.elapsed + DT
    if self.elapsed < FINISHER_SOUL_ATTACK_BEAM_DAMAGE_DELAY then
        self.collidable = false
    elseif self.elapsed < FINISHER_SOUL_ATTACK_BEAM_DAMAGE_DELAY
        + FINISHER_SOUL_ATTACK_BEAM_DAMAGE_TIME
    then
        self.collidable = true
    else
        self:remove()
        return
    end

    soul_attack_beam_super.update(self)
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
    self.finisher_soul_attack_battle = nil
    self.finisher_soul_attack_emitting = false
    self.finisher_soul_attack_phase = nil
    self.finisher_soul_attack_timer = 0
    self.finisher_soul_attack_center_x = nil
    self.finisher_soul_attack_center_y = nil
    self.finisher_soul_attack_move = nil
    self.finisher_soul_attack_last_side = nil
    self.finisher_soul_light = nil
    self.finisher_soul_light_overlay = nil
    self.finisher_soul_overlay = nil
    self.finisher_soul_attack_objects = {}
    self.finisher_soul_attack_ellipse_assets = nil
    self.finisher_wave_circles = nil
    self.finisher_wave_circle_empty_mask = nil
    self.finisher_fountain_flashes = {}
    self.finisher_fountain_flash_emitting = false
    self.finisher_fountain_flash_position = 1
    self.finisher_fountain_flash_wave = 0
    self.finisher_fountain_flash_interstitial_timer = nil
    self.finisher_rains = {}
    self.finisher_rain_emitting = false
    self.finisher_rain_spawn_timer = 0
    self.finisher_rain_battle = nil
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
    self.finisher_inversion_stage = nil
    self.finisher_inversion_stage_fx = nil
    self.finisher_fountain_cover_shader = nil
    self.finisher_fountain_inversion_shader = nil
    self.finisher_fountain = nil
    self.finisher_fountain_open_sound = nil
    self.finisher_fountain_open_sound_elapsed = 0
    self.finisher_tp_reached = false
    self.finisher_tp_finale_active = false
    self.finisher_tp_finale_phase = nil
    self.finisher_tp_finale_timer = 0
    self.finisher_tp_player_start = nil
    self.finisher_tp_finale_timer = 0
    self.finisher_tp_player_start = nil
    self.finisher_tp_player_can_move = nil
    self.finisher_tp_player_burst = nil
    self.finisher_tp_player_bursts = {}
    self.finisher_tp_echo_second_started = false
    self.finisher_tp_credits_started = false
    self.finisher_tp_sequence = nil
    self.finisher_tp_final_overlay = nil
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
        elapsed_timer = 0,
        flicker_count = 0,
        fourth_flicker_done = false,
        electric_started = false,
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
        Assets.playSound(OPENING_JUMPSCARE_SOUND)
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

function KrisFinisher:clearFinisherFountain()
    self:clearFinisherFountainOpenSound()

    if self.finisher_inversion_stage and self.finisher_inversion_stage_fx then
        self:clearFinisherInversion()
    end

    local fountain = self.finisher_fountain
    if fountain and fountain.parent then
        fountain:remove()
    end
    if fountain then
        fountain:releaseMaskCanvas()
    end
    self.finisher_fountain = nil
end

function KrisFinisher:clearFinisherFountainOpenSound()
    if self.finisher_fountain_open_sound then
        self.finisher_fountain_open_sound:stop()
    end
    self.finisher_fountain_open_sound = nil
    self.finisher_fountain_open_sound_elapsed = 0
end

function KrisFinisher:startFinisherFountainOpenSound()
    self:clearFinisherFountainOpenSound()

    local source = Assets.playSound(
        FINISHER_SOUND.fountain_open,
        1,
        FINISHER_SOUND.fountain_open_pitch
    )
    if source then
        self.finisher_fountain_open_sound = source
        self.finisher_fountain_open_sound_elapsed = 0
    end
end

function KrisFinisher:updateFinisherFountainOpenSound()
    local source = self.finisher_fountain_open_sound
    if not source then
        return
    end

    if not source:isPlaying() then
        self:clearFinisherFountainOpenSound()
        return
    end

    self.finisher_fountain_open_sound_elapsed =
        self.finisher_fountain_open_sound_elapsed + DT
    local fade_elapsed = self.finisher_fountain_open_sound_elapsed
        - FINISHER_SOUND.fountain_open_hold_time
    if fade_elapsed <= 0 then
        return
    end

    local fade_progress = clamp(
        fade_elapsed / FINISHER_SOUND.fountain_open_fade_time,
        0,
        1
    )
    source:setVolume(1 - fade_progress)
    if fade_progress >= 1 then
        self:clearFinisherFountainOpenSound()
    end
end

function KrisFinisher:clearFinisherInversion()
    local battle = self.finisher_inversion_battle
    if battle and self.finisher_inversion_fx then
        self.finisher_inversion_fx.active = false
        battle:removeFX("kris_finisher_invert")
    end
    local stage = self.finisher_inversion_stage
    if stage and self.finisher_inversion_stage_fx then
        self.finisher_inversion_stage_fx.active = false
        stage:removeFX("kris_finisher_fountain_cover")
        stage:removeFX("kris_finisher_fountain_invert")
    end
    if self.finisher_inversion_backdrop and self.finisher_inversion_backdrop.parent then
        self.finisher_inversion_backdrop:remove()
    end

    self.finisher_inversion_battle = nil
    self.finisher_inversion_backdrop = nil
    self.finisher_inversion_fx = nil
    self.finisher_inversion_stage = nil
    self.finisher_inversion_stage_fx = nil
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

function KrisFinisher:clearFinisherPlayerBurst()
    local bursts = self.finisher_tp_player_bursts or {}
    for _, burst in ipairs(bursts) do
        if burst and burst.parent then
            burst:remove()
        end
    end
    self.finisher_tp_player_bursts = {}
    self.finisher_tp_player_burst = nil
end

function KrisFinisher:startFinisherSoulShineSequence(battle)
    self:clearFinisherSoulShineSequence()

    local sequence = FinisherSoulShineSequence(battle, function()
        self.finisher_tp_final_overlay = FinisherFinalScreenOverlay(function()
            self:finishFinisherTPFinaleToCredits(battle)
        end)
        battle:addChild(self.finisher_tp_final_overlay)
    end)
    if not sequence.frames or #sequence.frames == 0 then
        return false
    end

    battle:addChild(sequence)
    self.finisher_tp_sequence = sequence
    return true
end

function KrisFinisher:clearFinisherSoulShineSequence()
    if self.finisher_tp_sequence and self.finisher_tp_sequence.parent then
        self.finisher_tp_sequence:remove()
    end
    self.finisher_tp_sequence = nil

    local battle = Game.battle
    if battle and battle.camera and battle.camera.stopShake then
        battle.camera:stopShake()
    end
end

function KrisFinisher:clearFinisherFinalScreenOverlay()
    if self.finisher_tp_final_overlay
        and self.finisher_tp_final_overlay.parent
    then
        self.finisher_tp_final_overlay:remove()
    end
    self.finisher_tp_final_overlay = nil
end

function KrisFinisher:finishFinisherTPFinaleToCredits(battle)
    if self.finisher_tp_credits_started then
        return
    end

    local world = Game.world
    if not world or not CreditsScene then
        return
    end

    self.finisher_tp_credits_started = true
    world:addChild(CreditsScene(function()
        if Game.world and Game.world.mapTransition then
            Game.world:mapTransition(
                "chapter_select",
                "spawn",
                "down",
                function()
                    if Game.world and ChapterSelect then
                        Game.world:openMenu(ChapterSelect())
                    end
                end
            )
        end
    end))
    self:onBattleEnd()

    if battle and battle.parent then
        battle:returnToWorld()
    end
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

    local stage = Game.stage
    local fountain = self.finisher_fountain
    if stage and fountain and fountain.mask_canvas then
        local cover_shader = self.finisher_fountain_cover_shader
        if not cover_shader then
            cover_shader = love.graphics.newShader(FINISHER_FOUNTAIN_COVER_SHADER_SOURCE)
            self.finisher_fountain_cover_shader = cover_shader
        end

        local cover_fx = ShaderFX(cover_shader, {
            fountainMask = function()
                return fountain.mask_canvas
            end,
        }, false, BATTLE_LAYERS["top"] + 100)
        stage:addFX(cover_fx, "kris_finisher_fountain_cover")
        self.finisher_inversion_stage = stage
        self.finisher_inversion_stage_fx = cover_fx
    end
end

function KrisFinisher:startFinisherFountain(battle)
    self:clearFinisherFountain()

    if not Game.stage then
        return
    end

    local fountain = FinisherFountain({
        on_grow_complete = function(current_fountain)
            if self.finisher_tp_finale_active then
                current_fountain:setOrdinaryDraw(true, 1, 1, 1, 1)
                return
            end
            self:finishFinisherFountainInversion(current_fountain, battle)
            self:startFinisherWaveCircles(battle)
            self:startFinisherRainEmitter(battle)
            self:startFinisherSoulAttackEmitter(battle)
        end,
        on_remove = function(current_fountain)
            if self.finisher_fountain == current_fountain then
                self:clearFinisherInversion()
                self.finisher_fountain = nil
            end
        end,
    })
    Game.stage:addChild(fountain)
    self.finisher_fountain = fountain
    self:startFinisherFountainOpenSound()
end

function KrisFinisher:finishFinisherFountainInversion(fountain, battle)
    if self.finisher_fountain ~= fountain then
        return
    end

    self:clearFinisherInversion()
    if self.finisher_tp_finale_active then
        fountain:setOrdinaryDraw(true, 1, 1, 1, 1)
        return
    end
    fountain:setColor(1, 1, 1, 1)

    local stage = Game.stage
    if not stage or not fountain.mask_canvas then
        return
    end

    local shader = self.finisher_fountain_inversion_shader
    if not shader then
        shader = love.graphics.newShader(FINISHER_FOUNTAIN_INVERT_SHADER_SOURCE)
        self.finisher_fountain_inversion_shader = shader
    end

    local fx = ShaderFX(shader, {
        fountainMask = function()
            return fountain.mask_canvas
        end,
        circleMask = function()
            return self:getFinisherWaveCircleMask()
        end,
    }, false, BATTLE_LAYERS["top"] + 100)
    stage:addFX(fx, "kris_finisher_fountain_invert")
    self.finisher_inversion_stage = stage
    self.finisher_inversion_stage_fx = fx
end

function KrisFinisher:getFinisherRainSpawnInterval()
    local random_value = Mod:randomKrisis("kris_finisher_rain")
    return FINISHER_RAIN_SPAWN_INTERVAL_MIN
        + (FINISHER_RAIN_SPAWN_INTERVAL_MAX - FINISHER_RAIN_SPAWN_INTERVAL_MIN)
        * (random_value ^ FINISHER_RAIN_SPAWN_INTERVAL_BIAS_POWER)
end

function KrisFinisher:startFinisherWaveCircles(battle)
    self:stopFinisherWaveCircles()
    if not battle or not battle.parent then
        return
    end

    local circles = FinisherWaveCircles()
    battle:addChild(circles)
    self.finisher_wave_circles = circles
end

function KrisFinisher:stopFinisherWaveCircles()
    if self.finisher_wave_circles and self.finisher_wave_circles.parent then
        self.finisher_wave_circles:remove()
    end
    self.finisher_wave_circles = nil
end

function KrisFinisher:getFinisherWaveCircleMask()
    if self.finisher_wave_circles and self.finisher_wave_circles.mask_canvas then
        return self.finisher_wave_circles.mask_canvas
    end

    if not self.finisher_wave_circle_empty_mask then
        local mask = love.graphics.newCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
        mask:setFilter("nearest", "nearest")
        local old_shader = love.graphics.getShader()
        Draw.pushCanvas(mask)
        love.graphics.setShader()
        love.graphics.clear(0, 0, 0, 0)
        Draw.popCanvas()
        love.graphics.setShader(old_shader)
        self.finisher_wave_circle_empty_mask = mask
    end

    return self.finisher_wave_circle_empty_mask
end

function KrisFinisher:clearFinisherRains()
    for index = #self.finisher_rains, 1, -1 do
        local rain = self.finisher_rains[index]
        if rain and rain.parent then
            rain:remove()
        end
        self.finisher_rains[index] = nil
    end
end

function KrisFinisher:pruneFinisherRains()
    local write_index = 1
    for read_index = 1, #self.finisher_rains do
        local rain = self.finisher_rains[read_index]
        if rain and rain.parent then
            self.finisher_rains[write_index] = rain
            write_index = write_index + 1
        end
    end

    for index = write_index, #self.finisher_rains do
        self.finisher_rains[index] = nil
    end
end

function KrisFinisher:isFinisherRainSpawnFree(x)
    local spawn_half_width = FINISHER_RAIN_TEXTURE_WIDTH * FINISHER_RAIN_SCALE / 2
    local spawn_half_height = FINISHER_RAIN_TEXTURE_HEIGHT * FINISHER_RAIN_SCALE / 2

    -- Check the actual spawn rectangles. Once an older rain has fallen clear
    -- of the top edge, its x lane can be reused without visual overlap.
    for _, rain in ipairs(self.finisher_rains) do
        if rain and rain.parent then
            local rain_half_width = rain:getScaledWidth() / 2
            local rain_half_height = rain:getScaledHeight() / 2
            local overlaps_x = math.abs(x - rain.x)
                < spawn_half_width + rain_half_width
            local overlaps_y = math.abs(FINISHER_RAIN_SPAWN_Y - rain.y)
                < spawn_half_height + rain_half_height
            if overlaps_x and overlaps_y then
                return false
            end
        end
    end

    return true
end

function KrisFinisher:spawnFinisherRain()
    local battle = self.finisher_rain_battle
    if not battle or not battle.parent then
        return false
    end

    local half_width = FINISHER_RAIN_TEXTURE_WIDTH * FINISHER_RAIN_SCALE / 2
    local min_x = half_width
    local max_x = SCREEN_WIDTH - half_width
    for _ = 1, 64 do
        local x = min_x + (max_x - min_x) * Mod:randomKrisis("kris_finisher_rain")
        if self:isFinisherRainSpawnFree(x) then
            local rain = Registry.createBullet("finisher_rain", x, FINISHER_RAIN_SPAWN_Y)
            rain.layer = FINISHER_SOUL_ATTACK_STAR_LAYER
            rain.tp = FINISHER_TP100.post_tp_bullet_tp
            battle:addChild(rain)
            table.insert(self.finisher_rains, rain)
            return true
        end
    end

    return false
end

function KrisFinisher:startFinisherRainEmitter(battle)
    self:stopFinisherRainEmitter()
    self.finisher_rain_battle = battle
    self.finisher_rain_emitting = true
    self:spawnFinisherRain()
    self.finisher_rain_spawn_timer = self:getFinisherRainSpawnInterval()
end

function KrisFinisher:stopFinisherRainEmitter()
    self.finisher_rain_emitting = false
    self.finisher_rain_spawn_timer = 0
    self.finisher_rain_battle = nil
    self:clearFinisherRains()
end

function KrisFinisher:updateFinisherRainEmitter()
    if not self.finisher_rain_emitting then
        return
    end

    local battle = self.finisher_rain_battle
    if not battle or not battle.parent then
        self:stopFinisherRainEmitter()
        return
    end

    self:pruneFinisherRains()
    self.finisher_rain_spawn_timer = self.finisher_rain_spawn_timer - DT

    local spawned = 0
    while self.finisher_rain_spawn_timer <= 0
        and spawned < FINISHER_RAIN_MAX_SPAWNS_PER_UPDATE
    do
        self:spawnFinisherRain()
        self.finisher_rain_spawn_timer = self.finisher_rain_spawn_timer
            + self:getFinisherRainSpawnInterval()
        spawned = spawned + 1
    end
end

function KrisFinisher:startFinisherSword(battle, on_dive)
    self:clearFinisherSword()

    local sword = FinisherFlyingSword(
        FINISHER_SWORD_START_X,
        FINISHER_SWORD_START_Y,
        {
            on_exit = function(prop)
                self:finishFinisherSword(prop, battle)
            end,
            on_dive = on_dive,
        }
    )
    battle:addChild(sword)
    self.finisher_sword = sword
    self:startFinisherFountainFlashEmitter(battle)
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
    if battle and battle.soul then
        -- The shared fountain post-process will invert this white source to black.
        battle.soul:setColor(1, 1, 1, battle.soul.alpha)
    end
    self:startFinisherFountain(battle)
    self:startFinisherInversion(battle)
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

    local sword_dive_started = false

    sprite:setAnimation({
        "finisher_slide",
        function(anim_sprite, wait)
            for frame = 1, FINISHER_SLIDE_HOLD_FRAME - 1 do
                anim_sprite:setFrame(frame)
                wait(FINISHER_KRIS_ANIMATION_SPEED)
            end

            self:startFinisherSword(battle, function()
                sword_dive_started = true
                anim_sprite:setFrame(FINISHER_SLIDE_END_FRAME)
            end)

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

            while not sword_dive_started and anim_sprite.parent do
                wait(1 / 60)
            end
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
    Assets.playSound(FINISHER_SOUND.tp50)
    self:stopFinisherStarEmitter()
    self:stopFinisherWaveCircles()
    self:stopFinisherFountainFlashEmitter()
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

function KrisFinisher:spawnFinisherPlayerBurst(battle)
    local x, y = self:getFinisherPlayerPosition(battle)
    if not x then
        return nil
    end

    local base_scale = 1
    if battle.soul and battle.soul.sprite then
        base_scale = battle.soul.sprite.scale_x or 1
    end

    local burst = FinisherPlayerBurst(
        x,
        y,
        base_scale,
        FINISHER_TP100.echo_duration
    )
    battle:addChild(burst)
    self.finisher_tp_player_burst = burst
    self.finisher_tp_player_bursts = self.finisher_tp_player_bursts or {}
    table.insert(self.finisher_tp_player_bursts, burst)
    return burst
end

function KrisFinisher:triggerFinisherTP100Reached()
    if self.finisher_tp_finale_active then
        return
    end

    local battle = Game.battle
    if not battle then
        return
    end

    self.finisher_tp_finale_active = true
    self.finisher_tp_reached = true
    self.finisher_tp_finale_phase = "WAIT_RED"
    self.finisher_tp_finale_timer = 0
    self.finisher_tp_player_start = nil
    self.finisher_tp_echo_second_started = false
    self:clearFinisherPlayerBurst()
    self:clearFinisherSoulShineSequence()
    self:clearFinisherFinalScreenOverlay()

    if battle.music then
        battle.music:stop()
    end

    -- This is the final clear: keep the arena soul, enemy soul proxy, fountain
    -- and TP bar, while removing every active bullet or auxiliary emitter.
    self:stopFinisherStarEmitter()
    self:stopFinisherWaveCircles()
    self:stopFinisherSoulAttackEmitter()
    self:stopFinisherRainEmitter()
    self:stopFinisherFountainFlashEmitter()
    self:clearFinisherStars()
    self:clearFinisherBulletObjects(battle)
    self:clearFinisherSword()
    self:clearFinisherSlideAfterImage()
    self:clearFinisherWarpBackground()
    self:stopFinisherTransition()
    self:clearFinisherWindBackground()
    self:clearFinisherInversion()
    self:removeFinisherKrisSprite()

    if battle.soul then
        self.finisher_tp_player_can_move = battle.soul.can_move
        battle.soul.can_move = false
        battle.soul.transitioning = false
        if battle.soul.physics then
            battle.soul.physics.move_target = nil
            battle.soul.physics.move_path = nil
        end
    end

    -- Direct TP100 launches may reach this branch before the normal sword has
    -- created a fountain. Create one in ordinary mode so the final scene is
    -- still complete and its grow callback cannot restart attacks.
    if not self.finisher_fountain or not self.finisher_fountain.parent then
        self:startFinisherFountain(battle)
    end
    if self.finisher_fountain then
        self.finisher_fountain:setOrdinaryDraw(true, 1, 1, 1, 1)
    end

    self:clearFinisherHurtFlash()
    local tp_flash = RechargeWhiteFlash(nil, {
        hold_time = 0.05,
        fade_time = 0.18,
        layer = BATTLE_LAYERS["top"] + 2,
    })
    battle:addChild(tp_flash)
    self.finisher_tp_flash = tp_flash
end

function KrisFinisher:updateFinisherTPFinale()
    if not self.finisher_tp_finale_active then
        return
    end

    local battle = Game.battle
    if not battle then
        return
    end

    self.finisher_tp_finale_timer = self.finisher_tp_finale_timer + DT

    if self.finisher_tp_finale_phase == "WAIT_RED" then
        if self.finisher_tp_finale_timer < FINISHER_TP100.red_delay then
            return
        end

        local soul = battle.soul
        if soul and soul.parent then
            soul:setColor(1, 0, 0, soul.alpha)
        end
        self.finisher_tp_finale_phase = "WAIT_CENTER"
        self.finisher_tp_finale_timer = 0
        return
    end

    if self.finisher_tp_finale_phase == "WAIT_CENTER" then
        if self.finisher_tp_finale_timer < FINISHER_TP100.center_delay then
            return
        end

        if self.finisher_fountain then
            self.finisher_fountain:setOrdinaryColor(0.5, 0.5, 0.5, 1)
        end

        local x, y = self:getFinisherPlayerPosition(battle)
        if x then
            self.finisher_tp_player_start = { x, y }
        end
        self.finisher_tp_finale_phase = "MOVE_PLAYER"
        self.finisher_tp_finale_timer = 0
        return
    end

    if self.finisher_tp_finale_phase == "MOVE_PLAYER" then
        local progress = clamp(
            self.finisher_tp_finale_timer / FINISHER_TP100.player_move_time,
            0,
            1
        )
        local eased = easeInOutCubic(progress)
        local start = self.finisher_tp_player_start
        local soul = battle.soul
        if start and soul and soul.parent then
            local x = start[1] + (SCREEN_WIDTH / 2 - start[1]) * eased
            local y = start[2] + (SCREEN_HEIGHT / 2 - start[2]) * eased
            if soul.setExactPosition then
                soul:setExactPosition(x, y)
            else
                soul:setPosition(x, y)
            end
            soul.moving_x = 0
            soul.moving_y = 0
        end

        if progress >= 1 then
            self.finisher_tp_finale_phase = "WAIT_ECHO"
            self.finisher_tp_finale_timer = 0
        end
        return
    end

    if self.finisher_tp_finale_phase == "WAIT_ECHO" then
        if self.finisher_tp_finale_timer < FINISHER_TP100.echo_delay then
            return
        end

        self:spawnFinisherPlayerBurst(battle)
        self.finisher_tp_echo_second_started = false
        self.finisher_tp_finale_phase = "ECHOES"
        self.finisher_tp_finale_timer = 0
        return
    end

    if self.finisher_tp_finale_phase == "ECHOES" then
        if not self.finisher_tp_echo_second_started
            and self.finisher_tp_finale_timer
                >= FINISHER_TP100.echo_second_offset
        then
            self:spawnFinisherPlayerBurst(battle)
            self.finisher_tp_echo_second_started = true
        end

        if self.finisher_tp_finale_timer
            >= FINISHER_TP100.echo_duration
                + FINISHER_TP100.echo_to_sequence_delay
        then
            if self:startFinisherSoulShineSequence(battle) then
                self.finisher_tp_finale_phase = "SOUL_SHINE"
            else
                self.finisher_tp_finale_phase = "DONE"
            end
            self.finisher_tp_finale_timer = 0
        end
    end
end

function KrisFinisher:updateFinisherWindBackground()
    -- A direct --tp launch starts above the threshold before the custom
    -- opening is visible. Wait until that cover is gone so the full 60 FPS
    -- background sequence is actually seen.
    if self.finisher_opening then
        return
    end

    if Game:getTension() >= FINISHER_FINAL_TP then
        self:triggerFinisherTP100Reached()
    elseif Game:getTension() >= FINISHER_STOP_TP then
        self:triggerFinisherTPReached()
    end
end

function KrisFinisher:updateOpening()
    local opening = self.finisher_opening
    if not opening then
        return
    end

    opening.elapsed_timer = opening.elapsed_timer + DT

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

    local opening_finish_time = OPENING_REVEAL_DELAY
        + OPENING_INITIAL_FLICKER_INTERVAL * OPENING_INITIAL_FLICKER_COUNT * 2
        + OPENING_ACCELERATION_TIME
    if not opening.electric_started
        and opening.elapsed_timer >= opening_finish_time - OPENING_ELECTRIC_SOUND_DURATION
    then
        Assets.playSound(OPENING_ELECTRIC_SOUND)
        opening.electric_started = true
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

    -- Keep the wind post-process separate from the Battle-layered finisher
    -- objects, which must remain underneath the TP bar.
    if self.finisher_wind_background then
        self.finisher_wind_background:drawFullscreenFilter()
    end

end

function KrisFinisher:drawFinisherHurtFlash()
    local flash = self.finisher_hurt_flash
    if not flash or not flash.parent then
        return
    end

    -- This is called from Mod:postDraw, after Battle and Stage post-processes.
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setShader()
    flash:draw()
    love.graphics.pop()
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
    -- The source soul keeps its local light children, while its sprite is
    -- rendered by a Battle-level proxy so it can sit below the TP bar.
    kris_soul.sprite.visible = false
    local soul_light_overlay = FinisherSoulLightOverlay()
    local soul_overlay = FinisherSoulOverlay(kris_soul)

    battle:addChild(kris)
    battle:addChild(soul_light_overlay)
    battle:addChild(soul_overlay)

    self.finisher_kris = kris
    self.finisher_kris_sprite = sprite
    self.finisher_soul = kris_soul
    self.finisher_soul_light_overlay = soul_light_overlay
    self.finisher_soul_overlay = soul_overlay
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

function KrisFinisher:getFinisherSoulAttackCenter(battle)
    if self.finisher_soul and self.finisher_soul.parent then
        return self.finisher_soul:getRelativePos(
            self.finisher_soul.width / 2,
            self.finisher_soul.height / 2,
            battle
        )
    end
end

function KrisFinisher:getFinisherPlayerPosition(battle)
    if battle and battle.soul and battle.soul.parent then
        return battle.soul:getRelativePos(0, 0, battle)
    end
end

function KrisFinisher:getFinisherSoulAttackDestination(battle, from_x, from_y)
    local player_x, player_y = self:getFinisherPlayerPosition(battle)
    if not player_x then
        player_x, player_y = SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
    end

    local margin = FINISHER_SOUL_ATTACK_POSITION_MARGIN
    local fountain_center_x = SCREEN_WIDTH / 2
    local side
    if self.finisher_soul_attack_last_side then
        side = self.finisher_soul_attack_last_side
        if Mod:randomKrisis("kris_finisher_soul_attack")
            < FINISHER_SOUL_ATTACK_SIDE_SWITCH_CHANCE
        then
            side = -side
        end
    else
        local current_side = from_x < fountain_center_x and -1 or 1
        side = -current_side
    end

    local min_x, max_x
    if side < 0 then
        min_x = margin
        max_x = fountain_center_x - FINISHER_SOUL_ATTACK_FOUNTAIN_CLEARANCE
    else
        min_x = fountain_center_x + FINISHER_SOUL_ATTACK_FOUNTAIN_CLEARANCE
        max_x = SCREEN_WIDTH - margin
    end
    local min_y, max_y = margin, SCREEN_HEIGHT - margin
    local min_distance = FINISHER_SOUL_ATTACK_MIN_PLAYER_DISTANCE
    local best_x, best_y, best_distance = nil, nil, -math.huge

    for _ = 1, 64 do
        local x = min_x + (max_x - min_x)
            * Mod:randomKrisis("kris_finisher_soul_attack")
        local y = min_y + (max_y - min_y)
            * Mod:randomKrisis("kris_finisher_soul_attack")
        local dx = x - player_x
        local dy = y - player_y
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance > best_distance then
            best_x, best_y, best_distance = x, y, distance
        end
        if distance >= min_distance then
            self.finisher_soul_attack_last_side = side
            return x, y
        end
    end

    self.finisher_soul_attack_last_side = side
    return best_x or from_x, best_y or from_y
end

function KrisFinisher:setFinisherSoulAttackCenter(x, y)
    if self.finisher_soul and self.finisher_soul.parent then
        self.finisher_soul:setScreenPos(x, y)
    end
end

function KrisFinisher:trackFinisherSoulAttackObject(object, battle)
    battle:addChild(object)
    table.insert(self.finisher_soul_attack_objects, object)
    return object
end

function KrisFinisher:setupFinisherSoulAttackEllipseAssets()
    if self.finisher_soul_attack_ellipse_assets then
        return self.finisher_soul_attack_ellipse_assets
    end

    -- This is kept finisher-local so the round-2 slash visuals stay untouched.
    local assets = {
        solid = makeHardEllipse(
            FINISHER_SOUL_ATTACK_ELLIPSE_SIZE,
            FINISHER_SOUL_ATTACK_ELLIPSE_TEXTURE_SCALE,
            0
        ),
        donut = makeHardEllipse(
            FINISHER_SOUL_ATTACK_ELLIPSE_SIZE,
            FINISHER_SOUL_ATTACK_ELLIPSE_TEXTURE_SCALE,
            FINISHER_SOUL_ATTACK_ELLIPSE_INNER_RADIUS
        ),
    }
    self.finisher_soul_attack_ellipse_assets = assets
    return assets
end

function KrisFinisher:spawnFinisherSoulAttackEllipse(battle, center_x, center_y)
    local target_x, target_y = self:getFinisherPlayerPosition(battle)
    if not target_x then
        target_x, target_y = center_x + 1, center_y
    end

    local direction = MathUtils.angle(center_x, center_y, target_x, target_y)
    local visual_rotation = direction - math.pi / 2
    local target_distance = MathUtils.dist(center_x, center_y, target_x, target_y)
    local beam_length = math.max(
        FINISHER_SOUL_ATTACK_BEAM_MIN_LENGTH,
        (target_distance + FINISHER_SOUL_ATTACK_BEAM_OVERHANG) * 2
    ) * FINISHER_SOUL_ATTACK_BEAM_LENGTH_MULTIPLIER
    local assets = self:setupFinisherSoulAttackEllipseAssets()
    self:trackFinisherSoulAttackObject(FinisherSoulAttackWindupLine(
        center_x,
        center_y,
        direction,
        beam_length
    ), battle)
    self:trackFinisherSoulAttackObject(FinisherSoulAttackEllipse(
        center_x,
        center_y,
        assets.solid,
        visual_rotation,
        beam_length,
        0,
        FINISHER_SOUL_ATTACK_ELLIPSE_HOLLOW_DELAY
    ), battle)
    self:trackFinisherSoulAttackObject(FinisherSoulAttackEllipse(
        center_x,
        center_y,
        assets.donut,
        visual_rotation,
        beam_length,
        FINISHER_SOUL_ATTACK_ELLIPSE_HOLLOW_DELAY
    ), battle)
    return self:trackFinisherSoulAttackObject(FinisherSoulAttackBeam(
        center_x,
        center_y,
        direction,
        beam_length
    ), battle)
end

function KrisFinisher:pruneFinisherSoulAttackObjects()
    local write_index = 1
    for read_index = 1, #self.finisher_soul_attack_objects do
        local object = self.finisher_soul_attack_objects[read_index]
        if object and object.parent then
            self.finisher_soul_attack_objects[write_index] = object
            write_index = write_index + 1
        end
    end

    for index = write_index, #self.finisher_soul_attack_objects do
        self.finisher_soul_attack_objects[index] = nil
    end
end

function KrisFinisher:spawnFinisherSoulAttackRing(battle, center_x, center_y, radius, scale)
    for index = 0, 11 do
        local angle = FINISHER_SOUL_ATTACK_ANGLE_OFFSET
            + index * (math.pi * 2 / 12)
        local star = FinisherSoulPureStar(
            center_x + math.cos(angle) * radius,
            center_y + math.sin(angle) * radius,
            scale
        )
        self:trackFinisherSoulAttackObject(star, battle)
    end
end

function KrisFinisher:spawnFinisherSoulOutwardStars(battle, center_x, center_y)
    for index = 0, 11 do
        local angle = FINISHER_SOUL_ATTACK_ANGLE_OFFSET
            + index * (math.pi * 2 / 12)
        local star = FinisherSoulOutwardStar(
            center_x + math.cos(angle) * FINISHER_SOUL_ATTACK_RING_LARGE,
            center_y + math.sin(angle) * FINISHER_SOUL_ATTACK_RING_LARGE,
            angle,
            center_x,
            center_y
        )
        self:trackFinisherSoulAttackObject(star, battle)
    end
end

function KrisFinisher:spawnFinisherSoulAttackBurst()
    local battle = self.finisher_soul_attack_battle
    if not battle or not battle.parent then
        return
    end

    local center_x, center_y = self:getFinisherSoulAttackCenter(battle)
    if not center_x then
        center_x = self.finisher_soul_attack_center_x
        center_y = self.finisher_soul_attack_center_y
    end
    if not center_x then
        return
    end

    self.finisher_soul_attack_center_x = center_x
    self.finisher_soul_attack_center_y = center_y
    self:spawnFinisherSoulAttackRing(
        battle,
        center_x,
        center_y,
        FINISHER_SOUL_ATTACK_RING_SMALL,
        1
    )
    self:spawnFinisherSoulAttackEllipse(battle, center_x, center_y)

    self.finisher_soul_attack_phase = "WAVE_MEDIUM"
    self.finisher_soul_attack_timer = FINISHER_SOUL_ATTACK_WAVE_INTERVAL
end

function KrisFinisher:beginFinisherSoulAttackCycle()
    local battle = self.finisher_soul_attack_battle
    local soul = self.finisher_soul
    if not self.finisher_soul_attack_emitting or not battle
        or not battle.parent or not soul or not soul.parent
    then
        return
    end

    self.finisher_soul_attack_phase = "LIGHT"
    self.finisher_soul_attack_timer = 0

    local light
    light = FinisherSoulLight(
        function()
            if self.finisher_soul_light ~= light
                or not self.finisher_soul_attack_emitting
            then
                return
            end
            self:spawnFinisherSoulAttackBurst()
        end,
        function()
            if self.finisher_soul_light == light then
                self.finisher_soul_light = nil
            end
            if self.finisher_soul_light_overlay
                and self.finisher_soul_light_overlay.source == light
            then
                self.finisher_soul_light_overlay.source = nil
            end
        end
    )
    light:setPosition(soul.width / 2, soul.height / 2)
    soul:addChild(light)
    self.finisher_soul_light = light
    if self.finisher_soul_light_overlay then
        self.finisher_soul_light_overlay.source = light
    end
end

function KrisFinisher:beginFinisherSoulAttackMove()
    local battle = self.finisher_soul_attack_battle
    local from_x, from_y = self:getFinisherSoulAttackCenter(battle)
    if not battle or not from_x then
        return
    end

    local target_x, target_y = self:getFinisherSoulAttackDestination(
        battle,
        from_x,
        from_y
    )
    self.finisher_soul_attack_move = {
        elapsed = 0,
        from_x = from_x,
        from_y = from_y,
        target_x = target_x,
        target_y = target_y,
        prepared = false,
    }
    self.finisher_soul_attack_phase = "MOVE"
end

function KrisFinisher:updateFinisherSoulAttackEmitter()
    if not self.finisher_soul_attack_emitting then
        return
    end

    local battle = self.finisher_soul_attack_battle
    if not battle or not battle.parent
        or not self.finisher_soul or not self.finisher_soul.parent
    then
        self:stopFinisherSoulAttackEmitter()
        return
    end

    self:pruneFinisherSoulAttackObjects()

    local move = self.finisher_soul_attack_move
    if move then
        move.elapsed = move.elapsed + DT
        local progress = clamp(move.elapsed / FINISHER_SOUL_ATTACK_MOVE_TIME, 0, 1)
        local eased = easeInOutCubic(progress)
        self:setFinisherSoulAttackCenter(
            move.from_x + (move.target_x - move.from_x) * eased,
            move.from_y + (move.target_y - move.from_y) * eased
        )

        if not move.prepared and progress >= 0.5 then
            move.prepared = true
            self:beginFinisherSoulAttackCycle()
        end

        if progress >= 1 then
            self.finisher_soul_attack_move = nil
            if not move.prepared then
                self:beginFinisherSoulAttackCycle()
            end
        end
    end

    if self.finisher_soul_attack_phase == "WAVE_MEDIUM"
        or self.finisher_soul_attack_phase == "WAVE_LARGE"
    then
        self.finisher_soul_attack_timer = self.finisher_soul_attack_timer - DT
        if self.finisher_soul_attack_timer <= 0 then
            if self.finisher_soul_attack_phase == "WAVE_MEDIUM" then
                self:spawnFinisherSoulAttackRing(
                    battle,
                    self.finisher_soul_attack_center_x,
                    self.finisher_soul_attack_center_y,
                    FINISHER_SOUL_ATTACK_RING_MEDIUM,
                    1
                )
                self.finisher_soul_attack_phase = "WAVE_LARGE"
            else
                self:spawnFinisherSoulOutwardStars(
                    battle,
                    self.finisher_soul_attack_center_x,
                    self.finisher_soul_attack_center_y
                )
                self.finisher_soul_attack_phase = "WAIT_MOVE"
            end
            self.finisher_soul_attack_timer = FINISHER_SOUL_ATTACK_WAVE_INTERVAL
            if self.finisher_soul_attack_phase == "WAIT_MOVE" then
                self.finisher_soul_attack_timer = FINISHER_SOUL_ATTACK_MOVE_DELAY
            end
        end
    elseif self.finisher_soul_attack_phase == "WAIT_MOVE" then
        self.finisher_soul_attack_timer = self.finisher_soul_attack_timer - DT
        if self.finisher_soul_attack_timer <= 0 then
            self:beginFinisherSoulAttackMove()
        end
    end
end

function KrisFinisher:startFinisherSoulAttackEmitter(battle)
    if self.finisher_soul_attack_emitting then
        return
    end

    self.finisher_soul_attack_battle = battle
    self.finisher_soul_attack_emitting = true
    self.finisher_soul_attack_move = nil
    self:beginFinisherSoulAttackCycle()
end

function KrisFinisher:clearFinisherSoulAttackObjects()
    for index = #self.finisher_soul_attack_objects, 1, -1 do
        local object = self.finisher_soul_attack_objects[index]
        if object and object.parent then
            object:remove()
        end
        self.finisher_soul_attack_objects[index] = nil
    end
end

function KrisFinisher:stopFinisherSoulAttackEmitter()
    self.finisher_soul_attack_emitting = false
    self.finisher_soul_attack_phase = nil
    self.finisher_soul_attack_timer = 0
    self.finisher_soul_attack_move = nil
    self.finisher_soul_attack_battle = nil
    if self.finisher_soul_light and self.finisher_soul_light.parent then
        self.finisher_soul_light:remove()
    end
    self.finisher_soul_light = nil
    if self.finisher_soul_light_overlay then
        self.finisher_soul_light_overlay.source = nil
    end
    self:clearFinisherSoulAttackObjects()
end

function KrisFinisher:getFinisherStarWaveInterval(elapsed)
    elapsed = elapsed or self.finisher_star_elapsed

    local progress = FINISHER_STAR_INTERVAL_TRANSITION_TIME > 0
        and MathUtils.clamp(elapsed / FINISHER_STAR_INTERVAL_TRANSITION_TIME, 0, 1)
        or 1

    return FINISHER_STAR_WAVE_MAX_INTERVAL
        + (FINISHER_STAR_WAVE_MIN_INTERVAL - FINISHER_STAR_WAVE_MAX_INTERVAL) * progress
end

function KrisFinisher:startFinisherFountainFlashEmitter(battle)
    self.finisher_fountain_flash_battle = battle
    self.finisher_fountain_flash_emitting = true
    self.finisher_fountain_flash_position = 1
    self.finisher_fountain_flash_wave = 0
    self.finisher_fountain_flash_interstitial_timer = nil

    self:spawnFinisherFountainFlashWave()
end

function KrisFinisher:spawnFinisherFountainFlashWave()
    if not self.finisher_fountain_flash_emitting then
        return
    end

    local battle = self.finisher_fountain_flash_battle
    if not battle or not battle.parent then
        return
    end

    local position_index = self.finisher_fountain_flash_position
    if position_index > #FINISHER_FOUNTAIN_FLASH_POSITIONS then
        return
    end

    local count = self.finisher_fountain_flash_wave == 0
        and FINISHER_FOUNTAIN_FLASH_FIRST_WAVE_COUNT
        or 1
    count = math.min(count, #FINISHER_FOUNTAIN_FLASH_POSITIONS - position_index + 1)

    Assets.playSound(FINISHER_SOUND.fountain_wave)

    local wave = {
        flash_one_count = 0,
        triggered = false,
    }
    local wave_index = self.finisher_fountain_flash_wave
    self.finisher_fountain_flash_wave = wave_index + 1
    self.finisher_fountain_flash_position = position_index + count
    if self.finisher_fountain_flash_position <= #FINISHER_FOUNTAIN_FLASH_POSITIONS then
        -- Each wave's two-frame animation takes 12/60 seconds; play the
        -- interstitial sound at the midpoint, 6/60 seconds after spawning.
        self.finisher_fountain_flash_interstitial_timer =
            FINISHER_SOUND.fountain_wave_midpoint
    else
        self.finisher_fountain_flash_interstitial_timer = nil
    end

    local function onFlashOne()
        if not self.finisher_fountain_flash_emitting or wave.triggered then
            return
        end

        wave.flash_one_count = wave.flash_one_count + 1
        if wave.flash_one_count < count then
            return
        end

        wave.triggered = true
        self:spawnFinisherFountainFlashWave()
    end

    for index = position_index, position_index + count - 1 do
        local position = FINISHER_FOUNTAIN_FLASH_POSITIONS[index]
        local flash = FinisherFountainFlash(position[1], position[2], {
            on_flash_one = onFlashOne,
        })
        battle:addChild(flash)
        table.insert(self.finisher_fountain_flashes, flash)
    end
end

function KrisFinisher:clearFinisherFountainFlashes()
    for index = #self.finisher_fountain_flashes, 1, -1 do
        local flash = self.finisher_fountain_flashes[index]
        if flash and flash.parent then
            flash:remove()
        end
        self.finisher_fountain_flashes[index] = nil
    end
end

function KrisFinisher:stopFinisherFountainFlashEmitter()
    self.finisher_fountain_flash_emitting = false
    self.finisher_fountain_flash_interstitial_timer = nil
    self:clearFinisherFountainFlashes()
    self.finisher_fountain_flash_battle = nil
end

function KrisFinisher:updateFinisherFountainFlashInterstitialSound()
    local timer = self.finisher_fountain_flash_interstitial_timer
    if not timer then
        return
    end

    timer = timer - DT
    if timer > 0 then
        self.finisher_fountain_flash_interstitial_timer = timer
        return
    end

    self.finisher_fountain_flash_interstitial_timer = nil
    if self.finisher_fountain_flash_emitting then
        Assets.playSound(FINISHER_SOUND.fountain_wave)
    end
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
        star.layer = FINISHER_SOUL_ATTACK_STAR_LAYER
        if Game:getTension() >= FINISHER_STOP_TP then
            star.tp = FINISHER_TP100.post_tp_bullet_tp
        end
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
    -- Keep the controllable soul above the finisher effects, but below the
    -- HP/TP UI layers.
    battle.soul.layer = FINISHER_PLAYER_SOUL_LAYER
    battle.soul.transitioning = false
    battle.soul.alpha = battle.soul.target_alpha or 1
    battle.soul:setPosition(OPENING_PLAYER_POSITION.x, OPENING_PLAYER_POSITION.y)
end

function KrisFinisher:update()
    super.update(self)

    self:updateFinisherWindBackground()
    self:updateFinisherSword()
    self:updateFinisherFountainFlashInterstitialSound()
    self:updateFinisherFountainOpenSound()

    if self.finisher_opening then
        self:updateOpening()
        return
    end

    self:updateFinisherTransition()
    self:updateFinisherKris()
    self:updateFinisherStarEmitter()
    self:updateFinisherSoulAttackEmitter()
    self:updateFinisherRainEmitter()
    self:updateFinisherTPFinale()
    self:updatePlayerDrift()
end

function KrisFinisher:onGameOver()
    -- GameOver is added after the battle is removed, while postDraw can still
    -- see the old Game.battle reference for the rest of this frame.
    self:clearFinisherHurtFlash()
    self:clearFinisherFountainOpenSound()
    self:clearFinisherWindBackground()
    self:stopFinisherTransition()
end

function KrisFinisher:onBattleEnd()
    self:clearFinisherWindBackground()
    self:clearFinisherWarpBackground()
    self:clearFinisherSlideAfterImage()
    self:clearFinisherSword()
    self:clearFinisherInversion()
    self:clearFinisherFountain()
    self:clearFinisherHurtFlash()
    self:stopFinisherTransition()
    self:stopFinisherStarEmitter()
    self:stopFinisherSoulAttackEmitter()
    self:stopFinisherFountainFlashEmitter()
    self:stopFinisherRainEmitter()
    self:stopFinisherWaveCircles()
    self:clearFinisherFinalScreenOverlay()
    self:clearFinisherSoulShineSequence()
    self:clearFinisherPlayerBurst()
    self.finisher_tp_finale_active = false
    self.finisher_tp_finale_phase = nil
    self.finisher_tp_echo_second_started = false
    self.finisher_tp_credits_started = false
    if Game.battle and Game.battle.soul and self.finisher_tp_player_can_move ~= nil then
        Game.battle.soul.can_move = self.finisher_tp_player_can_move
    end
    self.finisher_tp_player_can_move = nil
    self:restoreVesselDamageNumbers()
    if self.finisher_wave_circle_empty_mask then
        self.finisher_wave_circle_empty_mask:release()
        self.finisher_wave_circle_empty_mask = nil
    end

    if Mod and Mod.consumeKrisisFinisherResume then
        Mod:consumeKrisisFinisherResume()
    end
end

return KrisFinisher
