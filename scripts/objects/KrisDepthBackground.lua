local DEPTH_TEXTURE = "battle/backgrounds/kris_depth_adjusted"
local TWIST_STRENGTH = 0.9
local TWIST_FREQUENCY = 50.0
local TWIST_SPEED = 0.05
local DEPTH_ALPHA = 0.15

local KrisDepthBackground, super = Class(Object)

function KrisDepthBackground:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.time = 0
    self.texture = Assets.getTexture(DEPTH_TEXTURE)
    self.texture:setWrap("repeat", "repeat")

    self.quad = love.graphics.newQuad(
        0, 0,
        SCREEN_WIDTH, SCREEN_HEIGHT,
        self.texture:getWidth(), self.texture:getHeight()
    )

    self.shader = love.graphics.newShader([[
        extern vec2 iResolution;
        extern float iTime;
        extern vec2 tileScale;
        extern float strength;
        extern float frequency;
        extern float speed;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec2 uv = screen_coords / iResolution;

            float centerX = 0.5;
            float xFromCenter = uv.x - centerX;
            float twist = sin(uv.y * frequency - iTime * speed);
            float distortedX = centerX + xFromCenter * (1.0 + strength * twist);
            vec2 texCoord = vec2(distortedX, uv.y) * tileScale;

            return Texel(tex, texCoord) * color;
        }
    ]])

    self.shader:send("iResolution", { SCREEN_WIDTH, SCREEN_HEIGHT })
    self.shader:send("tileScale", {
        SCREEN_WIDTH / self.texture:getWidth(),
        SCREEN_HEIGHT / self.texture:getHeight(),
    })
    self.shader:send("strength", TWIST_STRENGTH)
    self.shader:send("frequency", TWIST_FREQUENCY)
    self.shader:send("speed", TWIST_SPEED)
end

function KrisDepthBackground:update()
    super.update(self)
    self.time = self.time + DT
end

function KrisDepthBackground:draw()
    love.graphics.push()
    love.graphics.origin()

    local old_shader = love.graphics.getShader()
    local r, g, b, a = love.graphics.getColor()

    self.shader:send("iTime", self.time)

    love.graphics.setShader(self.shader)
    love.graphics.setColor(1, 1, 1, DEPTH_ALPHA)
    love.graphics.draw(self.texture, self.quad, 0, 0)
    love.graphics.setColor(r, g, b, a)
    love.graphics.setShader(old_shader)

    love.graphics.pop()
end

return KrisDepthBackground
