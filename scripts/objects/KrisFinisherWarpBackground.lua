local KrisFinisherWarpBackground, super = Class(Object)

local FRAME_RATE = 60
local FRAME_COUNT = 218
local FRAMES_PER_CHANNEL = 5
local FRAMES_PER_TEXTURE = FRAMES_PER_CHANNEL * 3
local OUTPUT_ALPHA = 0.36
local TEXTURE_PREFIX = "battle/backgrounds/kris_finisher_warp_"

local WARP_SHADER_SOURCE = [[
    extern float frameSlot;
    extern float outputAlpha;
    extern vec3 palette1;
    extern vec3 palette2;
    extern vec3 palette3;

    float selectChannel(vec3 encodedChannels, float channel) {
        if (channel < 0.5) {
            return floor(encodedChannels.r * 255.0 + 0.5);
        }
        if (channel < 1.5) {
            return floor(encodedChannels.g * 255.0 + 0.5);
        }
        return floor(encodedChannels.b * 255.0 + 0.5);
    }

    float ternaryPlace(float digit) {
        if (digit < 0.5) {
            return 1.0;
        }
        if (digit < 1.5) {
            return 3.0;
        }
        if (digit < 2.5) {
            return 9.0;
        }
        if (digit < 3.5) {
            return 27.0;
        }
        return 81.0;
    }

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
        float channel = floor(frameSlot / 5.0);
        float digit = mod(frameSlot, 5.0);
        float encoded = selectChannel(Texel(tex, uv).rgb, channel);
        float paletteIndex = mod(floor(encoded / ternaryPlace(digit)), 3.0);
        vec3 result = paletteIndex < 0.5
            ? palette1
            : (paletteIndex < 1.5 ? palette2 : palette3);

        return vec4(result, outputAlpha) * color;
    }
]]

local function getTexturePath(index)
    return TEXTURE_PREFIX .. string.format("%02d", index)
end

function KrisFinisherWarpBackground:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = BATTLE_LAYERS["background"]
    self.elapsed = -1 / FRAME_RATE
    self.frame_index = 0
    self.texture_index = nil
    self.texture = nil
    self.shader = love.graphics.newShader(WARP_SHADER_SOURCE)

    self.shader:send("outputAlpha", OUTPUT_ALPHA)
    self.shader:send("palette1", { 0x2F / 255, 0, 0 })
    self.shader:send("palette2", { 0x67 / 255, 0, 0 })
    self.shader:send("palette3", { 1, 0, 0 })
    self:setFrame(0)
end

function KrisFinisherWarpBackground:setFrame(frame_index)
    self.frame_index = math.max(0, math.min(FRAME_COUNT - 1, frame_index))

    local texture_index = math.floor(self.frame_index / FRAMES_PER_TEXTURE) + 1
    if texture_index ~= self.texture_index then
        self.texture_index = texture_index
        self.texture = Assets.getTexture(getTexturePath(texture_index))
        self.texture:setFilter("nearest", "nearest")
    end
end

function KrisFinisherWarpBackground:update()
    super.update(self)

    self.elapsed = self.elapsed + DT
    self:setFrame(math.floor(math.max(self.elapsed, 0) * FRAME_RATE + 0.0001))
end

function KrisFinisherWarpBackground:clear()
    self.active = false
    self.visible = false
    if self.parent then
        self:remove()
    end
end

function KrisFinisherWarpBackground:draw()
    if not self.texture then
        return
    end

    local old_shader = love.graphics.getShader()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    love.graphics.push()
    love.graphics.origin()
    self.shader:send("frameSlot", self.frame_index % FRAMES_PER_TEXTURE)
    love.graphics.setShader(self.shader)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.draw(
        self.texture,
        0,
        0,
        0,
        SCREEN_WIDTH / self.texture:getWidth(),
        SCREEN_HEIGHT / self.texture:getHeight()
    )
    love.graphics.setShader(old_shader)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
    love.graphics.pop()
end

return KrisFinisherWarpBackground
