local KrisMercyFinale, super = Class(Object)

local TWIST_DELAY = 1
local FLASH_FADE_TIME = 0.12
local CIRCLE_DELAY = 2
local CIRCLE_DURATION = 4
local CIRCLE_COUNT = 34
local CIRCLE_MIN_RADIUS = 8
local CIRCLE_MAX_RADIUS = 22
local CIRCLE_BORDER_WIDTH = 8
local CIRCLE_SEGMENTS = 48
local CIRCLE_LAYOUT_RADIUS = 96
local CIRCLE_OUTWARD_DISTANCE = 92
local CIRCLE_BOB_MIN = 6
local CIRCLE_BOB_MAX = 18
local CIRCLE_BOB_SPEED_MIN = 4.5
local CIRCLE_BOB_SPEED_MAX = 8
local BLACK_SCREEN_DELAY = 1
local LIGHT_MIN_SCALE = 0.05
local LIGHT_GROW_DURATION = 1
local LIGHT_SPRITE = "battle/light"
local LIGHT_OFFSET_X = 16
local DEFEAT_LIGHT_OFFSET_X = 11
local LIGHT_BRIGHTNESS = 1.15
local LIGHT_BREATH_AMPLITUDE = 0.025
local LIGHT_BREATH_SPEED = 2

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function easeOutCubic(progress)
    local inverse = 1 - clamp(progress, 0, 1)
    return 1 - inverse * inverse * inverse
end

local function randomFloat(min, max)
    return min + Mod:randomKrisis("kris_mercy_finale") * (max - min)
end

local function getMaxCornerDistance(x, y)
    local result = 0
    local corners = {
        { 0, 0 },
        { SCREEN_WIDTH, 0 },
        { 0, SCREEN_HEIGHT },
        { SCREEN_WIDTH, SCREEN_HEIGHT },
    }

    for _, corner in ipairs(corners) do
        result = math.max(result, MathUtils.dist(x, y, corner[1], corner[2]))
    end

    return result
end

local function isBattleUiObject(battle, child)
    if child == battle.battle_ui or child == battle.tension_bar then
        return true
    end

    local battle_ui = battle.battle_ui
    if not battle_ui then
        return false
    end

    return child == battle_ui.encounter_text
        or child == battle_ui.choice_box
        or child == battle_ui.short_act_text_1
        or child == battle_ui.short_act_text_2
        or child == battle_ui.short_act_text_3
end

function KrisMercyFinale:init(enemy, options)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    options = options or {}

    self.enemy = enemy
    self.layer = options.layer or (BATTLE_LAYERS["ui"] - 2)
    self.phase = "TWIST"
    self.phase_time = 0
    self.flash_alpha = 0
    self.circle_time = 0
    self.circles = {}
    self.black_screen = false
    self.player_light = nil
    self.light_texture = Assets.getTexture(LIGHT_SPRITE)
    self.light_mask_shader = love.graphics.newShader([[
        extern Image light_texture;
        extern vec2 light_center;
        extern vec2 light_size;
        extern float light_strength;

        // The light texture is a visibility mask for the black overlay. Its
        // alpha controls how much of the battle scene remains visible.
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            vec2 uv = (screen_coords - light_center) / light_size + vec2(0.5);
            float illumination = 0.0;

            if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
                illumination = Texel(light_texture, uv).a * light_strength;
            }

            float darkness = 1.0 - clamp(illumination, 0.0, 1.0);
            return vec4(0.0, 0.0, 0.0, darkness) * color;
        }
    ]])
    self.saved_layers = {}
    self.on_black_screen = options.on_black_screen
    self.on_light_ready = options.on_light_ready

    self.origin_x, self.origin_y = self:getEnemyOrigin()
    self.cover_radius = getMaxCornerDistance(self.origin_x, self.origin_y) + 180
end

function KrisMercyFinale:getEnemyOrigin()
    if self.enemy and self.enemy.parent then
        if self.enemy.sprite then
            return self.enemy:localToScreenPos(
                (self.enemy.sprite.width / 2) - 4.5,
                self.enemy.sprite.height / 2
            )
        end
        return self.enemy:localToScreenPos(self.enemy.width / 2, self.enemy.height / 2)
    end

    return SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
end

function KrisMercyFinale:getVesselOrigin()
    local battle = self.battle or Game.battle
    for _, battler in ipairs(battle and battle.party or {}) do
        if battler.chara and battler.chara.id == "vessel" then
            if battler.sprite then
                return battler:localToScreenPos(
                    (battler.sprite.width / 2) - 4.5,
                    battler.sprite.height / 2
                )
            end
            return battler:localToScreenPos(battler.width / 2, battler.height / 2)
        end
    end

    return SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
end

function KrisMercyFinale:getLayerBelowBattleUi(battle)
    local ui_layer = battle.battle_ui and battle.battle_ui.layer or BATTLE_LAYERS["ui"]
    local tp_layer = battle.tension_bar and battle.tension_bar.layer or (ui_layer - 1)
    return math.min(ui_layer, tp_layer) - 1
end

function KrisMercyFinale:syncLayer()
    if not self.battle then
        return
    end

    local layer = self:getLayerBelowBattleUi(self.battle)
    if self.layer == layer then
        return
    end

    self.layer = layer
    for child, _ in pairs(self.saved_layers) do
        if child.parent == self.battle then
            child.layer = self.layer - 1
        end
    end
    self.battle.update_child_list = true
end

function KrisMercyFinale:onAdd(parent)
    self.battle = parent
    self.layer = self:getLayerBelowBattleUi(parent)

    -- Keep the overlay above the battle scene while leaving TP and player UI on top.
    for _, child in ipairs(parent.children) do
        if child ~= self and not isBattleUiObject(parent, child) then
            self.saved_layers[child] = child.layer
            child.layer = self.layer - 1
        end
    end
    parent.update_child_list = true
end

function KrisMercyFinale:restoreBattleLayers()
    if not self.battle then
        return
    end

    for child, layer in pairs(self.saved_layers) do
        if child.parent == self.battle then
            child.layer = layer
        end
    end
    self.battle.update_child_list = true
    self.saved_layers = {}
end

function KrisMercyFinale:onRemove(parent)
    self:restoreBattleLayers()
    super.onRemove(self, parent)
end

function KrisMercyFinale:makeCircle(index)
    local angle = ((index - 1) / CIRCLE_COUNT) * math.pi * 2
        + randomFloat(-0.18, 0.18)
    local distance = randomFloat(8, CIRCLE_LAYOUT_RADIUS)
    local layout_scale = randomFloat(0.58, 1.08)

    return {
        base_x = self.origin_x + math.cos(angle) * distance * layout_scale,
        base_y = self.origin_y + math.sin(angle) * distance * layout_scale * 0.74,
        angle = angle,
        start_radius = randomFloat(CIRCLE_MIN_RADIUS, CIRCLE_MAX_RADIUS),
        target_radius = self.cover_radius + randomFloat(-28, 24),
        outward_distance = randomFloat(CIRCLE_OUTWARD_DISTANCE * 0.65, CIRCLE_OUTWARD_DISTANCE),
        bob_amplitude = randomFloat(CIRCLE_BOB_MIN, CIRCLE_BOB_MAX),
        bob_speed = randomFloat(CIRCLE_BOB_SPEED_MIN, CIRCLE_BOB_SPEED_MAX),
        bob_phase = randomFloat(0, math.pi * 2),
    }
end

function KrisMercyFinale:spawnCircles()
    self.circles = {}
    for index = 1, CIRCLE_COUNT do
        self.circles[index] = self:makeCircle(index)
    end
    self.phase = "CIRCLES"
    self.circle_time = 0
end

function KrisMercyFinale:getCircleState(circle)
    local progress = clamp(self.circle_time / CIRCLE_DURATION, 0, 1)
    local eased = easeOutCubic(progress)
    local outward = circle.outward_distance * eased
    local bob = math.sin(self.circle_time * circle.bob_speed + circle.bob_phase)
        * circle.bob_amplitude
        * (1 - progress * 0.35)

    return circle.base_x + math.cos(circle.angle) * outward,
        circle.base_y + math.sin(circle.angle) * outward * 0.65 + bob,
        circle.start_radius + (circle.target_radius - circle.start_radius) * eased
end

function KrisMercyFinale:enterBlackScreen()
    self.circles = {}
    self.flash_alpha = 0
    self.phase = "BLACK_WAIT"
    self.phase_time = 0
    self.black_screen = true

    if self.on_black_screen then
        local callback = self.on_black_screen
        self.on_black_screen = nil
        callback(self)
    end
end

function KrisMercyFinale:spawnPlayerLight()
    local x, y = self:getVesselOrigin()
    self.player_light = {
        x = x + LIGHT_OFFSET_X,
        y = y,
        scale = LIGHT_MIN_SCALE,
        alpha = 1,
        time = 0,
    }
    self.phase = "LIGHT"
    self.phase_time = 0
end

function KrisMercyFinale:finishLightReveal()
    self.phase = "READY"
    self.phase_time = 0

    if self.on_light_ready then
        local callback = self.on_light_ready
        self.on_light_ready = nil
        callback(self)
    end
end

function KrisMercyFinale:update()
    super.update(self)
    self:syncLayer()

    if self.player_light then
        self.player_light.time = self.player_light.time + DT
        local x, y = self:getVesselOrigin()
        local offset_x = LIGHT_OFFSET_X
        local encounter = self.battle and self.battle.encounter
        if encounter
            and encounter.isMercyFinaleDetached
            and encounter:isMercyFinaleDetached()
        then
            offset_x = offset_x + DEFEAT_LIGHT_OFFSET_X
        end
        self.player_light.x = x + offset_x
        self.player_light.y = y
    end

    if self.phase == "READY" then
        return
    end

    self.phase_time = self.phase_time + DT

    if self.phase == "TWIST" then
        if self.phase_time >= TWIST_DELAY then
            self.phase = "FLASH"
            self.phase_time = 0
            self.flash_alpha = 1
        end
    elseif self.phase == "FLASH" then
        self.flash_alpha = 1 - clamp(self.phase_time / FLASH_FADE_TIME, 0, 1)
        if self.phase_time >= FLASH_FADE_TIME then
            self.phase = "CIRCLE_WAIT"
            self.phase_time = 0
            self.flash_alpha = 0
        end
    elseif self.phase == "CIRCLE_WAIT" then
        if self.phase_time >= CIRCLE_DELAY then
            self:spawnCircles()
        end
    elseif self.phase == "CIRCLES" then
        self.circle_time = self.circle_time + DT
        if self.circle_time >= CIRCLE_DURATION then
            self:enterBlackScreen()
        end
    elseif self.phase == "BLACK_WAIT" then
        if self.phase_time >= BLACK_SCREEN_DELAY then
            self:spawnPlayerLight()
        end
    elseif self.phase == "LIGHT" then
        local progress = clamp(self.phase_time / LIGHT_GROW_DURATION, 0, 1)
        local scale = LIGHT_MIN_SCALE + (1 - LIGHT_MIN_SCALE) * easeOutCubic(progress)
        self.player_light.scale = scale
        if self.phase_time >= LIGHT_GROW_DURATION then
            self:finishLightReveal()
        end
    end
end

function KrisMercyFinale:drawCircles()
    local positions = {}
    for _, circle in ipairs(self.circles) do
        local x, y, radius = self:getCircleState(circle)
        table.insert(positions, { x = x, y = y, radius = radius })
    end

    -- The expanded white silhouettes are drawn first. Black union fills cover
    -- every interior border, leaving only the outside edge visible.
    love.graphics.setColor(1, 1, 1, 1)
    for _, circle in ipairs(positions) do
        love.graphics.circle(
            "fill",
            circle.x,
            circle.y,
            circle.radius + CIRCLE_BORDER_WIDTH,
            CIRCLE_SEGMENTS
        )
    end

    love.graphics.setColor(0, 0, 0, 1)
    for _, circle in ipairs(positions) do
        love.graphics.circle(
            "fill",
            circle.x,
            circle.y,
            circle.radius,
            CIRCLE_SEGMENTS
        )
    end
end

function KrisMercyFinale:drawBlackScreen()
    if not self.player_light or not self.light_texture or not self.light_mask_shader then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        return
    end

    local breathing = 1 + math.sin(self.player_light.time * LIGHT_BREATH_SPEED)
        * LIGHT_BREATH_AMPLITUDE
    local scale = self.player_light.scale * breathing
    local width = self.light_texture:getWidth() * scale
    local height = self.light_texture:getHeight() * scale
    self.light_mask_shader:send("light_texture", self.light_texture)
    self.light_mask_shader:send("light_center", { self.player_light.x, self.player_light.y })
    self.light_mask_shader:send("light_size", { width, height })
    self.light_mask_shader:send(
        "light_strength",
        self.player_light.alpha * LIGHT_BRIGHTNESS
    )

    local old_shader = love.graphics.getShader()
    love.graphics.setShader(self.light_mask_shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.setShader(old_shader)
end

function KrisMercyFinale:draw()
    love.graphics.push()
    love.graphics.origin()

    local old_blend, old_alpha_mode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("alpha")

    if self.phase == "CIRCLES" and #self.circles > 0 then
        self:drawCircles()
    elseif self.black_screen then
        self:drawBlackScreen()
    end

    if self.flash_alpha > 0 then
        love.graphics.setColor(1, 1, 1, self.flash_alpha)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    end

    love.graphics.setBlendMode(old_blend, old_alpha_mode)
    love.graphics.pop()
end

return KrisMercyFinale
