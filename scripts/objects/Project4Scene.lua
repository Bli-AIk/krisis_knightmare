local Project4Scene, super = Class(Object)

local ASSET_ROOT = "project4_scene/"
local CANVAS_WIDTH = 640
local CANVAS_HEIGHT = 480
local AM_TO_LOGICAL = 4 / 9
local PARTICLE_START = 17.766
local PRE_PARTICLE_CHARACTER_Y = 10

local RED_INSIDE = {
    r = {1.62960814, 0.04430889, -0.02988506},
    g = {-0.07813644, 1.07658359, -0.02264298},
    b = {-0.02097847, 0.09461343, 0.74275520},
    bias = {-0.28019685, 0.02620522, -0.00261041},
}

local RED_OUTSIDE = {
    r = {0.38803291, 0.06311858, 0.04618515},
    g = {-0.00924253, 0.27976412, 0.00130628},
    b = {-0.02133120, 0.06292299, 0.14748536},
    bias = {-0.08467776, -0.00833182, -0.00009326},
}

local GRAY_INSIDE = {
    r = {0.36303810, 0.82005515, 0.05269631},
    g = {0.36303810, 0.82005515, 0.05269631},
    b = {0.36303810, 0.82005515, 0.05269631},
    bias = {-0.07422465, -0.07422465, -0.07422465},
}

local GRAY_OUTSIDE = {
    r = {0.11319166, 0.14510631, 0.04080734},
    g = {0.11319166, 0.14510631, 0.04080734},
    b = {0.11319166, 0.14510631, 0.04080734},
    bias = {-0.03213870, -0.03213870, -0.03213870},
}

local COLOR_MATRIX_SHADER = [[
extern Image light_texture;
extern vec3 matrix_r;
extern vec3 matrix_g;
extern vec3 matrix_b;
extern vec3 matrix_bias;
extern float light_enabled;
extern float color_layers_enabled;
extern float red_multiply_enabled;
extern float pre_spotlight_black;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 pixel = Texel(texture, texture_coords) * color;
    vec3 graded = pixel.rgb;

    vec4 light_pixel = Texel(light_texture, texture_coords);
    vec3 tinted_light = mix(light_pixel.rgb, vec3(1.0, 0.0, 0.0), 0.56);
    vec3 screened_light = 1.0 - ((1.0 - graded) * (1.0 - tinted_light));
    graded = mix(graded, screened_light, light_pixel.a * 0.417969 * light_enabled);

    vec3 colored = graded * (1.0 - 0.203125);
    colored *= mix(vec3(1.0), vec3(0.866667, 0.266667, 0.866667), 0.660156);
    vec3 screened_red = 1.0 - ((1.0 - colored) * (1.0 - vec3(0.749020, 0.0, 0.0)));
    colored = mix(colored, screened_red, 0.515625);
    graded = mix(graded, colored, color_layers_enabled);

    vec3 red_multiply = graded * mix(
        vec3(1.0),
        vec3(0.329412, 0.301961, 0.345098),
        0.482422
    );
    graded = mix(graded, red_multiply, red_multiply_enabled);
    graded *= 1.0 - pre_spotlight_black;

    vec3 mapped = vec3(
        dot(graded, matrix_r) + matrix_bias.r,
        dot(graded, matrix_g) + matrix_bias.g,
        dot(graded, matrix_b) + matrix_bias.b
    );
    return vec4(clamp(mapped, 0.0, 1.0), 1.0);
}
]]

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function lerp(a, b, amount)
    return a + (b - a) * amount
end

local function cubicCoordinate(t, p1, p2)
    local inv = 1 - t
    return (3 * inv * inv * t * p1) + (3 * inv * t * t * p2) + (t * t * t)
end

local function cubicBezier(value, x1, y1, x2, y2)
    local low = 0
    local high = 1
    local parameter = value

    for _ = 1, 12 do
        parameter = (low + high) / 2
        if cubicCoordinate(parameter, x1, x2) < value then
            low = parameter
        else
            high = parameter
        end
    end
    return cubicCoordinate(parameter, y1, y2)
end

local function applyEase(value, ease)
    if not ease then
        return value
    end

    local x1, y1, x2, y2 = ease:match(
        "^cubicBezier%s+([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)$"
    )
    if x1 then
        return cubicBezier(value, tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2))
    end
    return value
end

local function interpolateKeyframes(keyframes, time)
    if time <= keyframes[1].t then
        return keyframes[1].x, keyframes[1].y
    end

    for index = 2, #keyframes do
        local target = keyframes[index]
        if time <= target.t then
            local source = keyframes[index - 1]
            local amount = (time - source.t) / (target.t - source.t)
            amount = applyEase(clamp(amount, 0, 1), target.ease)
            return lerp(source.x, target.x, amount), lerp(source.y, target.y, amount)
        end
    end

    local last = keyframes[#keyframes]
    return last.x, last.y
end

local function copyMatrix(matrix)
    return {
        r = {matrix.r[1], matrix.r[2], matrix.r[3]},
        g = {matrix.g[1], matrix.g[2], matrix.g[3]},
        b = {matrix.b[1], matrix.b[2], matrix.b[3]},
        bias = {matrix.bias[1], matrix.bias[2], matrix.bias[3]},
    }
end

local function blendMatrices(first, second, amount)
    local result = copyMatrix(first)
    for _, key in ipairs({"r", "g", "b", "bias"}) do
        for index = 1, 3 do
            result[key][index] = lerp(first[key][index], second[key][index], amount)
        end
    end
    return result
end

local function adjustmentMatrix(inside, fitted_outside, fitted_alpha)
    local result = copyMatrix(inside)
    for _, key in ipairs({"r", "g", "b", "bias"}) do
        for index = 1, 3 do
            result[key][index] = (
                fitted_outside[key][index] - ((1 - fitted_alpha) * inside[key][index])
            ) / fitted_alpha
        end
    end
    return result
end

local SIMPLEX_PERM = {
    151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
    140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
    247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
    57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175,
    74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122,
    60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
    65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
    200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
    52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
    207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
    119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
    129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
    218,
    246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241, 81,
    51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157, 184,
    84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222,
    114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180,
}

local SIMPLEX_GRADIENTS = {
    {1, 1, 0}, {-1, 1, 0}, {1, -1, 0}, {-1, -1, 0},
    {1, 0, 1}, {-1, 0, 1}, {1, 0, -1}, {-1, 0, -1},
    {0, 1, 1}, {0, -1, 1}, {0, 1, -1}, {0, -1, -1},
}

local function simplexPerm(index)
    return SIMPLEX_PERM[(index % 256) + 1]
end

local function simplexDot(gradient, x, y, z)
    return (gradient[1] * x) + (gradient[2] * y) + (gradient[3] * z)
end

-- This is the three-dimensional simplexNoise implementation used by AM's scatter repeat.
local function simplexNoise(x, y, z)
    local skew = (x + y + z) / 3
    local i = math.floor(x + skew)
    local j = math.floor(y + skew)
    local k = math.floor(z + skew)
    local unskew = (i + j + k) / 6
    local x0 = x - (i - unskew)
    local y0 = y - (j - unskew)
    local z0 = z - (k - unskew)

    local i1, j1, k1, i2, j2, k2
    if x0 >= y0 then
        if y0 >= z0 then
            i1, j1, k1, i2, j2, k2 = 1, 0, 0, 1, 1, 0
        elseif x0 >= z0 then
            i1, j1, k1, i2, j2, k2 = 1, 0, 0, 1, 0, 1
        else
            i1, j1, k1, i2, j2, k2 = 0, 0, 1, 1, 0, 1
        end
    elseif x0 < z0 then
        i1, j1, k1, i2, j2, k2 = 0, 0, 1, 0, 1, 1
    elseif y0 < z0 then
        i1, j1, k1, i2, j2, k2 = 0, 1, 0, 0, 1, 1
    else
        i1, j1, k1, i2, j2, k2 = 0, 1, 0, 1, 1, 0
    end

    local x1 = x0 - i1 + (1 / 6)
    local y1 = y0 - j1 + (1 / 6)
    local z1 = z0 - k1 + (1 / 6)
    local x2 = x0 - i2 + (1 / 3)
    local y2 = y0 - j2 + (1 / 3)
    local z2 = z0 - k2 + (1 / 3)
    local x3 = x0 - 1 + (1 / 2)
    local y3 = y0 - 1 + (1 / 2)
    local z3 = z0 - 1 + (1 / 2)

    local ii, jj, kk = i % 256, j % 256, k % 256
    local gi0 = simplexPerm(ii + simplexPerm(jj + simplexPerm(kk))) % 12
    local gi1 = simplexPerm(ii + i1 + simplexPerm(jj + j1 + simplexPerm(kk + k1))) % 12
    local gi2 = simplexPerm(ii + i2 + simplexPerm(jj + j2 + simplexPerm(kk + k2))) % 12
    local gi3 = simplexPerm(ii + 1 + simplexPerm(jj + 1 + simplexPerm(kk + 1))) % 12

    local function contribution(t, dx, dy, dz, gradientIndex)
        if t < 0 then
            return 0
        end
        local t2 = t * t
        return t2 * t2 * simplexDot(SIMPLEX_GRADIENTS[gradientIndex + 1], dx, dy, dz)
    end

    local n0 = contribution(0.6 - x0 * x0 - y0 * y0 - z0 * z0, x0, y0, z0, gi0)
    local n1 = contribution(0.6 - x1 * x1 - y1 * y1 - z1 * z1, x1, y1, z1, gi1)
    local n2 = contribution(0.6 - x2 * x2 - y2 * y2 - z2 * z2, x2, y2, z2, gi2)
    local n3 = contribution(0.6 - x3 * x3 - y3 * y3 - z3 * z3, x3, y3, z3, gi3)
    return (n0 + n1 + n2 + n3) * 32
end

function Project4Scene:init(options)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    options = options or {}
    self.layer = 1000000
    self.timeline = _G.project4_timeline or Registry.getObject("project4_timeline")
    assert(self.timeline, "Project 4 timeline data was not registered")

    self.time = clamp(tonumber(options.start_time) or 0, 0, self.timeline.duration)
    self.paused = options.paused == true
    self.loop = options.loop == true
    self.disable_particles = options.disable_particles == true
    self.particle_center_x = tonumber(options.particle_center_x) or 320
    self.particle_center_y = tonumber(options.particle_center_y) or 240
    self.quit_after_capture = options.quit_after_capture == true
    self.capture_times = options.capture_times
    self.capture_directory = options.capture_directory or "debug/project4_scene_capture"
    self.capture_index = 1
    self.capture_requested = false
    self.capture_wait_frames = 0
    self.capture_complete = false
    self.ready = false
    self.ready_frames = 0

    if self.capture_times and #self.capture_times > 0 then
        self.paused = true
        self.time = clamp(self.capture_times[1], 0, self.timeline.duration)
        love.filesystem.createDirectory(self.capture_directory)
    end

    self.textures = {}
    self.base_canvas = love.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT, {
        format = "rgba8",
        dpiscale = 1,
    })
    self.base_canvas:setFilter("nearest", "nearest")
    self.output_canvas = love.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT, {
        format = "rgba8",
        dpiscale = 1,
    })
    self.output_canvas:setFilter("nearest", "nearest")
    self.color_shader = love.graphics.newShader(COLOR_MATRIX_SHADER)

    self.red_adjustment = adjustmentMatrix(RED_INSIDE, RED_OUTSIDE, 0.761719)
    self.gray_adjustment = adjustmentMatrix(GRAY_INSIDE, GRAY_OUTSIDE, 0.761719)
    self.particle_layouts = self:createParticleLayouts()
end

function Project4Scene:createParticleLayouts()
    local layouts = {}
    for _, group in ipairs(self.timeline.particles) do
        local particles = {}
        for index = 1, group.count do
            particles[index] = {
                index = index - 1,
                progress = (index + 0.5) / (group.count + 1),
            }
        end
        layouts[group.id] = particles
    end
    return layouts
end

function Project4Scene:getTexture(filename)
    local id = filename:gsub("%.png$", "")
    local texture = self.textures[id]
    if not texture then
        texture = assert(Assets.getTexture(ASSET_ROOT .. id), "Missing Project 4 texture: " .. id)
        texture:setFilter("nearest", "nearest")
        self.textures[id] = texture
    end
    return texture
end

function Project4Scene:drawTexture(filename, x, y, width, height)
    local texture = self:getTexture(filename)
    love.graphics.draw(
        texture,
        x or 0,
        y or 0,
        0,
        (width or CANVAS_WIDTH) / texture:getWidth(),
        (height or CANVAS_HEIGHT) / texture:getHeight()
    )
end

function Project4Scene:getSpotlight(time)
    local offset_x, offset_y = interpolateKeyframes(self.timeline.spotlight_offset, time)
    local center_x = 313 + (offset_x / 3)
    local center_y = -39 + (offset_y / 3)
    local pulse = 1.03 + (0.07 * math.cos((math.pi * 2 * (time - 1)) / 5))
    local radius = 65.8342 * pulse
    return center_x, center_y, radius
end

function Project4Scene:getWalkFrame(time)
    for _, embed in ipairs(self.timeline.walk_embeds) do
        if time >= embed.start and time <= embed.finish then
            local local_time = time - embed.start
            if embed.loop then
                local_time = local_time % 0.683
            end
            for _, frame in ipairs(embed.frames) do
                if local_time >= frame.in_time and local_time <= frame.out_time then
                    return frame.image, embed.id
                end
            end
            return embed.frames[#embed.frames].image, embed.id
        end
    end
end

function Project4Scene:getCharacterFrame(time)
    for _, loop in ipairs(self.timeline.character_loops) do
        if time >= loop.start and time <= loop.finish then
            local local_time = (time - loop.start) % loop.cycle
            for _, frame in ipairs(loop.frames) do
                if local_time >= frame.in_time and local_time <= frame.out_time then
                    return frame.image
                end
            end
        end
    end

    for _, frame in ipairs(self.timeline.character_frames) do
        if time >= frame.in_time and time <= frame.out_time then
            return frame.image, frame
        end
    end
end

function Project4Scene:drawWalkCharacter(time, expected_embed)
    local image, embed_id = self:getWalkFrame(time)
    if not image or embed_id ~= expected_embed then
        return
    end

    local center_x, center_y = self:getSpotlight(time)
    self:drawTexture(image, center_x - 30, center_y - 25, 60, 68)
end

function Project4Scene:drawFullCharacter(time)
    local image, frame = self:getCharacterFrame(time)
    if not image then
        return
    end

    local location_x = 724.983765
    if frame and frame.id == 12362543 then
        local normalized = (time - frame.in_time) / (frame.out_time - frame.in_time)
        if normalized <= 0.009156 then
            location_x = 695.608765
        elseif normalized < 0.161750 then
            local amount = (normalized - 0.009156) / (0.161750 - 0.009156)
            location_x = lerp(695.608765, 724.983765, cubicBezier(amount, 0.2, 0.8, 0.4, 1))
        end
    end

    local location_y = time < PARTICLE_START and PRE_PARTICLE_CHARACTER_Y or 0
    self:drawTexture(image, (location_x - 720) * AM_TO_LOGICAL, location_y)
end

function Project4Scene:drawBackgroundLayers(time)
    if time <= 34.782 then
        self:drawTexture("1771128825718.png")
    end

    self:drawWalkCharacter(time, 12362510)

    if time <= 17.665 then
        self:drawTexture("1771134387871.png")
    elseif time <= 17.766 then
        self:drawTexture("1771134395564.png")
    elseif time <= 17.932 then
        self:drawTexture("1771144096953.png")
    elseif time <= 18.099 then
        self:drawTexture("1771144099381.png")
    elseif time <= 30.915 then
        self:drawTexture("1771144096953.png")
    end

    if time <= 31.665 then
        self:drawTexture("1771132756840.png")
    end

    self:drawWalkCharacter(time, 12362511)
    self:drawWalkCharacter(time, 12362513)
    self:drawFullCharacter(time)
end

function Project4Scene:interpolateParticleValue(keyframes, time, field)
    if time <= keyframes[1].t then
        return keyframes[1][field]
    end

    local target = keyframes[2]
    local amount = clamp((time - keyframes[1].t) / (target.t - keyframes[1].t), 0, 1)
    amount = applyEase(amount, target.ease)
    return lerp(keyframes[1][field], target[field], amount)
end

function Project4Scene:drawParticles(time)
    local circle = self:getTexture("1771143741888.png")
    for _, group in ipairs(self.timeline.particles) do
        if time >= group.start and time <= group.finish then
            local local_time = ((time - group.start) * group.speed) % group.cycle
            local radius = self:interpolateParticleValue(group.keyframes.radius, local_time, "value")
            local evolution = self:interpolateParticleValue(group.keyframes.evolution, local_time, "value")
            local offset_x = self:interpolateParticleValue(group.keyframes.offset, local_time, "x")
            local offset_y = self:interpolateParticleValue(group.keyframes.offset, local_time, "y")
            local alpha = 1
            if group.id == 12362624 or group.id == 12362627 or group.id == 12362621 then
                alpha = 1 - clamp((local_time - 3.225) / 0.717, 0, 1)
            elseif group.id == 12362623 then
                alpha = 1 - clamp((local_time - 3.242) / 0.667, 0, 1)
            end

            love.graphics.setColor(1, 1, 1, alpha)
            for _, particle in ipairs(self.particle_layouts[group.id]) do
                local noise_x = simplexNoise(
                    evolution,
                    0.31 + (24791.93781 * group.scatterSeed),
                    231571.93341 * particle.index
                )
                local noise_y = simplexNoise(
                    evolution,
                    0.25 + (30452.37729 * group.scatterSeed),
                    733243.74533 * particle.index
                )
                local x = self.particle_center_x
                    + ((noise_x * radius) + (offset_x * particle.progress)) * AM_TO_LOGICAL
                local y = self.particle_center_y
                    + ((noise_y * radius) + (offset_y * particle.progress)) * AM_TO_LOGICAL
                local particle_scale = lerp(1, group.scale, particle.progress)
                local particle_radius = 49.7345 * 0.670361 * AM_TO_LOGICAL * particle_scale
                local diameter = particle_radius * 2
                love.graphics.draw(
                    circle,
                    x - particle_radius,
                    y - particle_radius,
                    0,
                    diameter / circle:getWidth(),
                    diameter / circle:getHeight()
                )
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Project4Scene:buildBaseCanvas(time)
    Draw.pushCanvas(self.base_canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)

    self:drawBackgroundLayers(time)
    if not self.disable_particles then
        self:drawParticles(time)
    end

    love.graphics.setColor(1, 1, 1, 1)
    Draw.popCanvas()
end

function Project4Scene:getSpotlightOpacity(time)
    if time <= 28.925 then
        return 0.761719
    end
    return lerp(0.761719, 1, clamp((time - 28.925) / (31.443 - 28.925), 0, 1))
end

function Project4Scene:sendMatrix(matrix)
    self.color_shader:send("matrix_r", matrix.r)
    self.color_shader:send("matrix_g", matrix.g)
    self.color_shader:send("matrix_b", matrix.b)
    self.color_shader:send("matrix_bias", matrix.bias)
end

function Project4Scene:sendGradeState(time)
    self.color_shader:send("light_texture", self:getTexture("1771129253481.png"))
    self.color_shader:send("light_enabled", time <= 34.132 and 1 or 0)
    self.color_shader:send("color_layers_enabled", time <= 34.332 and 1 or 0)
    self.color_shader:send("red_multiply_enabled", time <= 21.299 and 1 or 0)

    local pre_spotlight_black = 0
    if time >= 32.891 and time <= 36.132 then
        pre_spotlight_black = clamp((time - 32.891) / (34.258 - 32.891), 0, 1)
    end
    self.color_shader:send("pre_spotlight_black", pre_spotlight_black)
end

function Project4Scene:drawCompositedScene(time)
    if time >= 35.265 then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT)
        return
    end

    local grayscale = time >= 21.283
    local inside = grayscale and GRAY_INSIDE or RED_INSIDE
    local adjustment = grayscale and self.gray_adjustment or self.red_adjustment
    local outside = blendMatrices(inside, adjustment, self:getSpotlightOpacity(time))
    local center_x, center_y, radius = self:getSpotlight(time)

    love.graphics.setShader(self.color_shader)
    self:sendGradeState(time)
    self:sendMatrix(outside)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.base_canvas, 0, 0)

    love.graphics.setShader()
    love.graphics.stencil(function()
        love.graphics.circle("fill", center_x, center_y, radius, 96)
    end, "replace", 1, false)
    love.graphics.setStencilTest("equal", 1)
    love.graphics.setShader(self.color_shader)
    self:sendMatrix(inside)
    love.graphics.draw(self.base_canvas, 0, 0)
    love.graphics.setStencilTest()
    love.graphics.setShader()

    if time <= 2.591 then
        local alpha = 1
        if time > 2.008 then
            alpha = 1 - clamp((time - 2.008) / (2.591 - 2.008), 0, 1)
        end
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT)
    end

    if time >= 29.958 and time <= 34.316 then
        local alpha = 0.433594 * clamp((time - 29.958) / (30.608 - 29.958), 0, 1)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT)
    end
end

function Project4Scene:updateCapture()
    if not self.capture_times or self.capture_complete then
        return
    end

    if not self.capture_requested then
        return
    end

    self.capture_wait_frames = self.capture_wait_frames + 1
    if self.capture_wait_frames < 3 then
        return
    end

    self.capture_index = self.capture_index + 1
    self.capture_requested = false
    self.capture_wait_frames = 0
    local next_time = self.capture_times[self.capture_index]
    if next_time then
        self.time = clamp(next_time, 0, self.timeline.duration)
    else
        self.capture_complete = true
        if self.quit_after_capture then
            love.event.quit(0)
        end
    end
end

function Project4Scene:update()
    super.update(self)

    if not self.ready then
        local loader_idle = not Kristal.Loader or Kristal.Loader.waiting == 0
        local overlay_clear = not Kristal.Overlay or Kristal.Overlay.load_alpha <= 0
        if Kristal.getState() == Game and Game.world and loader_idle and overlay_clear then
            self.ready_frames = self.ready_frames + 1
            self.ready = self.ready_frames >= 3
        else
            self.ready_frames = 0
        end
        return
    end

    if self.capture_times then
        self:updateCapture()
        return
    end

    if not self.paused then
        self.time = self.time + DT
        if self.time >= self.timeline.duration then
            if self.loop then
                self.time = self.time % self.timeline.duration
            else
                self.time = self.timeline.duration
                self.paused = true
            end
        end
    end
end

function Project4Scene:seek(time)
    self.time = clamp(tonumber(time) or 0, 0, self.timeline.duration)
end

function Project4Scene:setPaused(paused)
    self.paused = paused == true
end

function Project4Scene:draw()
    love.graphics.push("all")
    love.graphics.origin()
    self:buildBaseCanvas(self.time)

    Draw.pushCanvas(self.output_canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 1)
    self:drawCompositedScene(self.time)
    Draw.popCanvas()

    love.graphics.origin()
    love.graphics.setShader()
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.output_canvas, 0, 0)
    love.graphics.setBlendMode("alpha", "alphamultiply")

    if self.ready and self.capture_times and not self.capture_requested and not self.capture_complete then
        local milliseconds = math.floor((self.time * 1000) + 0.5)
        local filename = string.format("frame_%06d.png", milliseconds)
        local path = self.capture_directory .. "/" .. filename
        love.graphics.captureScreenshot(path)
        print(string.format("[Project4Scene] capture %.3fs -> %s", self.time, path))
        self.capture_requested = true
    end

    love.graphics.pop()
end

return Project4Scene
