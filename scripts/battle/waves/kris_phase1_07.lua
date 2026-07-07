local KrisPhase1_07, super = Class(Wave)

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
    distorted_super.update(self)
    self.time = self.time + DT
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
end

function KrisPhase1_07:onStart()
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

function KrisPhase1_07:spawnDistortedEllipse()
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
