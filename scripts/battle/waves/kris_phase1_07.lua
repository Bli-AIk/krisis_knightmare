local KrisPhase1_07, super = Class(Wave)

local TWO_PI = math.pi * 2

local RECT_DURATION = 20 / 60
local RECT_WIDTH = 24
local RECT_HEIGHT = SCREEN_HEIGHT * 1.4
local RECT_ROTATION = math.rad(5)
local RECT_LAYER = BATTLE_LAYERS["top"] + 1
local ELLIPSE_START_DELAY = 8 / 60
local ELLIPSE_GROW_TIME = 5 / 60
local ELLIPSE_FADE_TIME = 3 / 60
local ELLIPSE_START_WIDTH = 4
local ELLIPSE_TARGET_WIDTH = 16
local ELLIPSE_BORDER_WIDTH = 2
local DISTORTED_ELLIPSE_DELAY = 2 / 60
local DISTORTED_ELLIPSE_WIDTH_SCALE = 1 / 3
local DISTORTED_ELLIPSE_HEIGHT_SCALE = 1.5
local DISTORTED_ELLIPSE_LAYER = 2
local DISTORTED_ELLIPSE_LIFETIME = 4 / 60
local ARENA_SHIFT_X = -9
local ARENA_SHIFT_Y = -6
local ARENA_SHIFT_OUT_TIME = 4 / 60
local ARENA_SHIFT_RETURN_TIME = 12 / 60
local SCREEN_SHAKE_X = -10
local SCREEN_SHAKE_Y = -8
local SCREEN_SHAKE_FRICTION = 3
local KRIS_SWORD_HALL_FRAME_TIME = 4 / 30
local KRIS_SWORD_HALL_EFFECT_START_DELAY = (5.5 * KRIS_SWORD_HALL_FRAME_TIME)
local KRIS_FAR_X = 10000
local KRIS_FAR_Y = 10000
local BURST_CIRCLE_COUNT = 6
local BURST_CIRCLE_DURATION = (20 / 60) * 3
local BURST_CIRCLE_LINE_WIDTH = 2
local BURST_CIRCLE_LAYER = 1.02
local BURST_CIRCLE_RADII = { 8, 10, 9, 11, 9.5, 8.5 }
local BURST_CIRCLE_DISTANCES = { 66, 82, 74, 88, 78, 70 }
local BURST_CIRCLE_ANGLE_OFFSET = math.rad(-14)
local SPLIT_SWORD_PULSE_INTERVAL_SECONDS = 50 * 2 / 60
local SPLIT_SWORD_ROTATION_DURATION_SECONDS = 2
local SPLIT_SWORD_INITIAL_ROTATION = math.pi
local SPLIT_SWORD_CLOSED_HOLD_SECONDS = 0.2

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function easeOutCubic(t)
    t = clamp(t, 0, 1)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

local function moveAttackerTo(attacker, x, y)
    attacker.target_x = x
    attacker.target_y = y
    attacker:setPosition(attacker.target_x, attacker.target_y)
end

local function moveAttackerAway(attacker)
    moveAttackerTo(attacker, KRIS_FAR_X, KRIS_FAR_Y)
end

local BurstCircle, burst_circle_super = Class(Object)

function BurstCircle:init(x, y, angle, distance, radius)
    burst_circle_super.init(self, x, y)

    self.origin_x = x
    self.origin_y = y
    self.angle = angle
    self.distance = distance
    self.radius = radius
    self.time = 0
    self.duration = BURST_CIRCLE_DURATION
    self.line_width = BURST_CIRCLE_LINE_WIDTH
    self.layer = BURST_CIRCLE_LAYER
end

function BurstCircle:update()
    self.time = self.time + DT

    local progress = clamp(self.time / self.duration, 0, 1)
    local eased = easeOutCubic(progress)
    self.x = self.origin_x + math.cos(self.angle) * self.distance * eased
    self.y = self.origin_y + math.sin(self.angle) * self.distance * eased
    self.alpha = 1 - easeOutCubic(progress)

    if progress >= 1 then
        self:remove()
        return
    end

    burst_circle_super.update(self)
end

function BurstCircle:draw()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    local old_line_width = love.graphics.getLineWidth()
    local alpha = self.alpha or 1

    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.circle("fill", 0, 0, self.radius, 48)
    love.graphics.setLineWidth(self.line_width)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("line", 0, 0, self.radius, 48)

    love.graphics.setLineWidth(old_line_width)
    love.graphics.setColor(old_r, old_g, old_b, old_a)

    burst_circle_super.draw(self)
end

local DistortedArenaEllipse, distorted_super = Class(Object)

function DistortedArenaEllipse:init(x, y, width, height)
    distorted_super.init(self, x, y, width, height)

    self:setOrigin(0.5, 0.5)
    self.time = 0
    self.shader = love.graphics.newShader([[
        extern vec2 iResolution;
        extern vec2 iTopLeft;
        extern float iTime;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec2 fragCoord = screen_coords - iTopLeft;
            vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;

            vec2 rx_ry = vec2(0.08, 0.9);

            float amplitude = 0.15;
            float frequency = 10.0 * 3.14159265;

            float speed = 5.0;
            float rotationAngle = 1.57079632679 + (iTime * speed);

            vec2 dir = vec2(cos(rotationAngle), sin(rotationAngle));
            vec2 dirNormal = vec2(-dir.y, dir.x);

            float waveInput = dot(uv, dir) * frequency;
            float distortion = amplitude * sin(waveInput);

            vec2 distortedUV = uv + dirNormal * distortion;
            float eVal = length(distortedUV / rx_ry);

            float edgeSoftness = 0.005;
            float mask = 1.0 - smoothstep(1.0 - edgeSoftness, 1.0 + edgeSoftness, eVal);

            return vec4(color.rgb * mask, color.a * mask);
        }
    ]])
    self.shader:send("iResolution", { width, height })
    self.shader:send("iTime", 0)
end

function DistortedArenaEllipse:update()
    self.time = self.time + DT

    if self.follow_arena and Game.battle and Game.battle.arena then
        self:setPosition(Game.battle.arena:getCenter())
    end

    distorted_super.update(self)
end

function DistortedArenaEllipse:draw()
    local old_shader = love.graphics.getShader()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    local x, y = self:localToScreenPos(0, 0)

    self.shader:send("iResolution", { self.width, self.height })
    self.shader:send("iTopLeft", { x, y })
    self.shader:send("iTime", self.time)

    love.graphics.setShader(self.shader)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
    love.graphics.setShader(old_shader)

    distorted_super.draw(self)
end

function KrisPhase1_07:init()
    super.init(self)
    self.time = 10
    self.red_rect = nil
    self.black_ellipse_fill = nil
    self.black_ellipse_border = nil
    self.distorted_ellipse = nil
    self.arena_shift_origin = nil
    self.kris_home_positions = nil
    self.ellipse_peak_effects_spawned = false
end

function KrisPhase1_07:onStart()
    self.kris_home_positions = {}

    for _, attacker in ipairs(self:getAttackers()) do
        self.kris_home_positions[attacker] = {
            x = attacker.target_x or attacker.x,
            y = attacker.target_y or attacker.y,
        }
        attacker:setAnimation("sword_hall_disappear", function()
            moveAttackerAway(attacker)
        end)
    end

    self.timer:after(KRIS_SWORD_HALL_EFFECT_START_DELAY, function()
        self:startDelayedEffects()
    end)
end

function KrisPhase1_07:startDelayedEffects()
    local rect = Rectangle(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, RECT_WIDTH, RECT_HEIGHT)
    rect:setOrigin(0.5, 0.5)
    rect.color = { 1, 0, 0 }
    rect.alpha = 1
    rect.layer = RECT_LAYER

    self.red_rect = rect
    self:spawnObject(rect)

    self.timer:tween(RECT_DURATION, rect, {
        rotation = RECT_ROTATION,
        alpha = 0,
    }, "linear", function()
        if rect.parent then
            rect:remove()
        end
        if self.red_rect == rect then
            self.red_rect = nil
        end
    end)

    self.timer:after(ELLIPSE_START_DELAY, function()
        self:spawnBlackEllipse()
    end)
end

function KrisPhase1_07:getArenaHeight()
    local arena = Game.battle and Game.battle.arena
    if arena then
        return arena.height or math.abs((arena:getBottom() or 0) - (arena:getTop() or 0))
    end

    return 142
end

function KrisPhase1_07:getArenaWidth()
    local arena = Game.battle and Game.battle.arena
    if arena then
        return arena.width or math.abs((arena:getRight() or 0) - (arena:getLeft() or 0))
    end

    return 142
end

function KrisPhase1_07:getArenaCenter()
    local arena = Game.battle and Game.battle.arena
    if arena then
        return arena:getCenter()
    end

    return SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
end

function KrisPhase1_07:spawnBlackEllipse()
    local start_height = self:getArenaHeight()
    local x, y = self:getArenaCenter()
    local fill = Ellipse(x, y, ELLIPSE_START_WIDTH / 2, start_height / 2)
    local border = Ellipse(x, y, ELLIPSE_START_WIDTH / 2, start_height / 2)

    fill.color = { 0, 0, 0 }
    fill.layer = 1

    border.color = { 1, 1, 1 }
    border.line = true
    border.line_width = ELLIPSE_BORDER_WIDTH
    border.layer = 1.01

    self.black_ellipse_fill = fill
    self.black_ellipse_border = border
    self:addChild(fill)
    self:addChild(border)

    self.timer:tween(ELLIPSE_GROW_TIME, fill, {
        width = ELLIPSE_TARGET_WIDTH,
        height = SCREEN_HEIGHT,
    }, "out-quad", function()
        self:spawnEllipsePeakEffects()
        self:fadeBlackEllipse()
    end)
    self.timer:tween(ELLIPSE_GROW_TIME, border, {
        width = ELLIPSE_TARGET_WIDTH,
        height = SCREEN_HEIGHT,
    }, "out-quad")

    self.timer:after(DISTORTED_ELLIPSE_DELAY, function()
        self:spawnDistortedEllipse()
    end)
end

function KrisPhase1_07:spawnEllipsePeakEffects()
    if self.ellipse_peak_effects_spawned then
        return
    end

    self.ellipse_peak_effects_spawned = true
    self:spawnBurstCircles()
    self:spawnSplitSwords()
end

function KrisPhase1_07:spawnBurstCircles()
    local x, y = self:getArenaCenter()

    for i = 1, BURST_CIRCLE_COUNT do
        local angle = BURST_CIRCLE_ANGLE_OFFSET + ((i - 1) / BURST_CIRCLE_COUNT) * TWO_PI
        local radius = BURST_CIRCLE_RADII[i] or BURST_CIRCLE_RADII[#BURST_CIRCLE_RADII]
        local distance = BURST_CIRCLE_DISTANCES[i] or BURST_CIRCLE_DISTANCES[#BURST_CIRCLE_DISTANCES]
        self:addChild(BurstCircle(x, y, angle, distance, radius))
    end
end

function KrisPhase1_07:spawnSplitSwords()
    local x, y = self:getArenaCenter()

    self:spawnBullet("flying_sword", x, y, SPLIT_SWORD_INITIAL_ROTATION, {
        sprite = "half_up",
        split_motion_sign = -1,
        ignore_attacker_position = true,
        follow_arena_center = true,
        split_pulse_interval_seconds = SPLIT_SWORD_PULSE_INTERVAL_SECONDS,
        split_rotation_duration_seconds = SPLIT_SWORD_ROTATION_DURATION_SECONDS,
        split_closed_hold_seconds = SPLIT_SWORD_CLOSED_HOLD_SECONDS,
    })
    self:spawnBullet("flying_sword", x, y, SPLIT_SWORD_INITIAL_ROTATION, {
        sprite = "half_down",
        split_motion_sign = 1,
        ignore_attacker_position = true,
        follow_arena_center = true,
        split_pulse_interval_seconds = SPLIT_SWORD_PULSE_INTERVAL_SECONDS,
        split_rotation_duration_seconds = SPLIT_SWORD_ROTATION_DURATION_SECONDS,
        split_closed_hold_seconds = SPLIT_SWORD_CLOSED_HOLD_SECONDS,
    })
end

function KrisPhase1_07:spawnDistortedEllipse()
    self:shiftArenaForDistortion()

    local arena_width = self:getArenaWidth()
    local arena_height = self:getArenaHeight()
    local x, y = self:getArenaCenter()
    local ellipse = DistortedArenaEllipse(
        x,
        y,
        arena_width * DISTORTED_ELLIPSE_WIDTH_SCALE,
        arena_height * DISTORTED_ELLIPSE_HEIGHT_SCALE
    )
    ellipse.layer = DISTORTED_ELLIPSE_LAYER
    ellipse.follow_arena = true

    self.distorted_ellipse = ellipse
    self:addChild(ellipse)

    self.timer:after(DISTORTED_ELLIPSE_LIFETIME, function()
        if ellipse.parent then
            ellipse:remove()
        end
        if self.distorted_ellipse == ellipse then
            self.distorted_ellipse = nil
        end
    end)
end

function KrisPhase1_07:shiftArenaForDistortion()
    local battle = Game.battle
    local arena = battle and battle.arena
    if not arena then
        return
    end

    local start_x = arena.x
    local start_y = arena.y
    local target_x = start_x + ARENA_SHIFT_X
    local target_y = start_y + ARENA_SHIFT_Y
    self.arena_shift_origin = { x = start_x, y = start_y }

    if battle.shakeCamera then
        battle:shakeCamera(SCREEN_SHAKE_X, SCREEN_SHAKE_Y, SCREEN_SHAKE_FRICTION)
    end

    self.timer:tween(ARENA_SHIFT_OUT_TIME, arena, {
        x = target_x,
        y = target_y,
    }, "out-quad", function()
        self.timer:tween(ARENA_SHIFT_RETURN_TIME, arena, {
            x = start_x,
            y = start_y,
        }, "out-quad", function()
            if self.arena_shift_origin
                and self.arena_shift_origin.x == start_x
                and self.arena_shift_origin.y == start_y
            then
                self.arena_shift_origin = nil
            end
        end)
    end)
end

function KrisPhase1_07:onEnd(death)
    local arena = Game.battle and Game.battle.arena
    if arena and self.arena_shift_origin then
        arena:setPosition(self.arena_shift_origin.x, self.arena_shift_origin.y)
        self.arena_shift_origin = nil
    end

    for _, attacker in ipairs(self:getAttackers()) do
        local home = self.kris_home_positions and self.kris_home_positions[attacker]
        if home then
            moveAttackerTo(attacker, home.x, home.y)
        end
        attacker:setAnimation("appear")
    end

    return super.onEnd(self, death)
end

function KrisPhase1_07:fadeBlackEllipse()
    local fill = self.black_ellipse_fill
    local border = self.black_ellipse_border
    if not fill or not border then
        return
    end

    self.timer:tween(ELLIPSE_FADE_TIME, fill, {
        width = 0,
        alpha = 0,
    }, "in-quad", function()
        if fill.parent then
            fill:remove()
        end
        if border.parent then
            border:remove()
        end
        if self.black_ellipse_fill == fill then
            self.black_ellipse_fill = nil
        end
        if self.black_ellipse_border == border then
            self.black_ellipse_border = nil
        end
    end)
    self.timer:tween(ELLIPSE_FADE_TIME, border, {
        width = 0,
        alpha = 0,
    }, "in-quad")
end

function KrisPhase1_07:update()
    super.update(self)
end

return KrisPhase1_07
