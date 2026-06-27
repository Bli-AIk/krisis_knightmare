local KrisPhase1_1, super = Class(Wave)
local ShaderFX = require("src.engine.drawfx.shaderfx")
local Rectangle = require("src.engine.objects.rectangle")

local function makeHardCircle(size, scale, inner_radius)
    scale = scale or { 1, 1 }
    inner_radius = inner_radius or 0
    local sx, sy = scale[1], scale[2]
    local imagedata = love.image.newImageData(size, size)
    local cx, cy = (size - 1) / 2, (size - 1) / 2
    local radius = cx
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local dx = (x - cx) / sx
            local dy = (y - cy) / sy
            local dist = math.sqrt(dx * dx + dy * dy)
            local alpha = (dist > inner_radius and dist <= radius) and 1 or 0
            imagedata:setPixel(x, y, 1, 1, 1, alpha)
        end
    end
    return love.graphics.newImage(imagedata)
end

function KrisPhase1_1:init()
    super.init(self)
    self.time = 8
end

function KrisPhase1_1:onStart()
    local size = 200
    local ts = { size, size }

    -- 1. 形变 shader（先运行）
    self.distort_fx = ShaderFX(love.graphics.newShader([[
        extern float phase;
        extern float yspace;
        extern float xspace;
        extern float yamp;
        extern float xamp;
        extern vec2  texSize;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec2 st   = uv * texSize;
            vec2 offs = vec2(
                sin((st.y + phase) / yspace) * yamp,
                sin((st.x + phase) / xspace) * xamp
            );
            return Texel(tex, uv + offs / texSize) * color;
        }
    ]]), {
        phase   = -5.5,
        yspace  = 20.0,
        yamp    = -3.0 * 0.08,
        xspace  = 20.0,
        xamp    = -10.0,
        texSize = ts,
    }, false, 0)

    -- 2-3. 水平+垂直高斯模糊（在形变之后）
    self.hblur_fx = ShaderFX(love.graphics.newShader([[
        extern vec2 texSize;
        extern float radius;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec2 d = vec2(radius / texSize.x, 0.0);
            float w0 = 0.227, w1 = 0.194, w2 = 0.121, w3 = 0.054, w4 = 0.016;
            vec4 c = Texel(tex, uv) * w0;
            c += Texel(tex, uv - d    ) * w1;
            c += Texel(tex, uv + d    ) * w1;
            c += Texel(tex, uv - d*2.0) * w2;
            c += Texel(tex, uv + d*2.0) * w2;
            c += Texel(tex, uv - d*3.0) * w3;
            c += Texel(tex, uv + d*3.0) * w3;
            c += Texel(tex, uv - d*4.0) * w4;
            c += Texel(tex, uv + d*4.0) * w4;
            return c * color;
        }
    ]]), {
        texSize = function()
            local w, h = love.graphics.getDimensions(); return { w, h }
        end,
        radius  = 1.0,
    }, false, 1)

    self.vblur_fx = ShaderFX(love.graphics.newShader([[
        extern vec2 texSize;
        extern float radius;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec2 d = vec2(0.0, radius / texSize.y);
            float w0 = 0.227, w1 = 0.194, w2 = 0.121, w3 = 0.054, w4 = 0.016;
            vec4 c = Texel(tex, uv) * w0;
            c += Texel(tex, uv - d    ) * w1;
            c += Texel(tex, uv + d    ) * w1;
            c += Texel(tex, uv - d*2.0) * w2;
            c += Texel(tex, uv + d*2.0) * w2;
            c += Texel(tex, uv - d*3.0) * w3;
            c += Texel(tex, uv + d*3.0) * w3;
            c += Texel(tex, uv - d*4.0) * w4;
            c += Texel(tex, uv + d*4.0) * w4;
            return c * color;
        }
    ]]), {
        texSize = function()
            local w, h = love.graphics.getDimensions(); return { w, h }
        end,
        radius  = 1.0,
    }, false, 2)

    -- 圆
    local texture = makeHardCircle(size, { 0.05, 1 }, 40)
    local circle = Sprite(texture, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
    circle:setOrigin(0.5, 0.5)
    circle:addFX(self.distort_fx)
    circle:addFX(self.hblur_fx)
    circle:addFX(self.vblur_fx)
    self:addChild(circle)
    circle.scale_x = 2.5
    circle.scale_y = 2.5

    -- 竖线
    local line_h = circle.height * circle.scale_y
    local line = Rectangle(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 1, line_h)
    line:setOrigin(0.5, 0.5)
    line.color = { 1, 1, 1 }
    line.alpha = 0
    line.layer = -1
    self:addChild(line)

    -- 圆形缩小
    circle.color = { 1, 0, 0 }
    Game.battle.timer:tween(15 / 60, circle, { scale_x = 0 })

    -- 圆形快消失时线以白色出现
    self.timer:after(10 / 60, function()
        Game.battle.timer:tween(5 / 60, line, { alpha = 1 }, "out-quad")
    end)

    self.timer:after(4 / 60, function()
        circle.color = { 1, 1, 1 }
    end)

    -- 15/60 后，线变红 → 再0.5秒渐变消失+下移
    self.timer:after(15 / 60, function()
        line.color = { 1, 0, 0 }
        Game.battle.timer:tween(0.5, line, {
            alpha = 0,
            y     = line.y + line_h,
        }, "out-quad")
    end)
end

function KrisPhase1_1:update()
    -- self.fx.vars.phase = self.fx.vars.phase + 25 * DT
    super.update(self)
end

return KrisPhase1_1
