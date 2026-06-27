local KrisPhase1_1, super = Class(Wave)
local ShaderFX = require("src.engine.drawfx.shaderfx")

local function makeSoftCircle(size, blur, scale)
    scale = scale or {1, 1}
    local sx, sy = scale[1], scale[2]
    local imagedata = love.image.newImageData(size, size)
    local cx, cy = (size - 1) / 2, (size - 1) / 2
    local radius = cx
    local inner = radius - blur
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local dx = (x - cx) / sx
            local dy = (y - cy) / sy
            local dist = math.sqrt(dx * dx + dy * dy)
            local alpha
            if dist <= inner then
                alpha = 1
            elseif dist >= radius then
                alpha = 0
            else
                local t = (dist - inner) / blur
                alpha = 1 - t * t * (3 - 2 * t)
            end
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

    self.fx = ShaderFX(love.graphics.newShader([[
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
        texSize = {size, size},
    })

    local texture = makeSoftCircle(size, 25, {0.05, 1})
    local circle = Sprite(texture, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
    circle:setOrigin(0.5, 0.5)
    circle:addFX(self.fx)

    self:addChild(circle)
end

function KrisPhase1_1:update()
    -- self.fx.vars.phase = self.fx.vars.phase + 25 * DT
    super.update(self)
end

return KrisPhase1_1
