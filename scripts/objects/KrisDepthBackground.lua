local DEPTH_TEXTURE = "battle/backgrounds/kris_depth_adjusted"
local PEAKS_TEXTURE = "battle/backgrounds/kris_peaks"
-- This is a screen-space offset, so 0.12 displaced the texture by roughly
-- 77 game pixels. Keep it visible but pixel-scale rather than stretching the
-- whole texture from the center.
local FLOW_BEND_AMPLITUDE = 0.018
-- The upper half of the battle field contains one complete S-shaped channel.
local FLOW_CURVE_FREQUENCY = math.pi * 4
local FLOW_PHASE_SPEED = 0.2 * 10
local FLOW_SPEED_DIVISOR = 10
-- Preserve the effective vertical speed from the previous implementation
-- while keeping it independent from the number of visible S curves.
local FLOW_SCROLL_SPEED = FLOW_PHASE_SPEED / (math.pi * 2 * FLOW_SPEED_DIVISOR)
local DEPTH_NON_PEAKS_ALPHA = 0.20
local DEPTH_PEAKS_ALPHA = 0.55

local KrisDepthBackground, super = Class(Object)

function KrisDepthBackground:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.time = 0
    self.texture = Assets.getTexture(DEPTH_TEXTURE)
    self.texture:setWrap("repeat", "repeat")
    self.peaks_texture = Assets.getTexture(PEAKS_TEXTURE)
    self.peaks_texture:setFilter("nearest", "nearest")
    self.peaks_texture:setWrap("clamp", "clamp")

    self.quad = love.graphics.newQuad(
        0, 0,
        SCREEN_WIDTH, SCREEN_HEIGHT,
        self.texture:getWidth(), self.texture:getHeight()
    )

    self.shader = love.graphics.newShader([[
        extern vec2 iResolution;
        extern float iTime;
        extern vec2 tileScale;
        extern float bendAmplitude;
        extern float curveFrequency;
        extern float flowSpeed;
        extern Image peaksTexture;
        extern float nonPeaksAlpha;
        extern float peaksAlpha;
        extern vec3 glowColor;
        extern float glowAmount;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec2 uv = screen_coords / iResolution;

            // The channel stays fixed in screen space while the texture moves
            // through it. A texel therefore travels down an S path instead of
            // making the left and right sides stretch back and forth.
            float downstreamY = uv.y - iTime * flowSpeed;
            float sOffset = sin(uv.y * curveFrequency) * bendAmplitude;
            vec2 texCoord = vec2(uv.x + sOffset, downstreamY) * tileScale;
            vec4 depth = Texel(tex, texCoord);
            float peaksMask = Texel(peaksTexture, uv).a;
            float alpha = mix(nonPeaksAlpha, peaksAlpha, step(0.5, peaksMask));
            float value = max(max(depth.r, depth.g), depth.b);
            vec3 warmDepth = value * glowColor;
            vec3 outputColor = mix(depth.rgb, warmDepth, glowAmount);

            return vec4(outputColor * color.rgb, depth.a * alpha * color.a);
        }
    ]])

    self.shader:send("iResolution", { SCREEN_WIDTH, SCREEN_HEIGHT })
    self.shader:send("tileScale", {
        SCREEN_WIDTH / self.texture:getWidth(),
        SCREEN_HEIGHT / self.texture:getHeight(),
    })
    self.shader:send("bendAmplitude", FLOW_BEND_AMPLITUDE)
    self.shader:send("curveFrequency", FLOW_CURVE_FREQUENCY)
    self.shader:send("flowSpeed", FLOW_SCROLL_SPEED)
    self.shader:send("peaksTexture", self.peaks_texture)
    self.shader:send("nonPeaksAlpha", DEPTH_NON_PEAKS_ALPHA)
    self.shader:send("peaksAlpha", DEPTH_PEAKS_ALPHA)
    self.shader:send("glowColor", { 1, 1, 1 })
    self.shader:send("glowAmount", 0)
end

function KrisDepthBackground:setGlowColor(color, amount)
    self.shader:send("glowColor", color)
    self.shader:send("glowAmount", amount or 1)
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
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.texture, self.quad, 0, 0)
    love.graphics.setColor(r, g, b, a)
    love.graphics.setShader(old_shader)

    love.graphics.pop()
end

return KrisDepthBackground
