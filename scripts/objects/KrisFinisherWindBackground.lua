-- Background RGB color, with each channel in the 0.0-1.0 range.
local BACKGROUND_COLOR_RGB = { 0.698 / 2, 0, 0 }
local BACKGROUND_FILL_RGB = { 0, 0, 0 }

local WIND_TEXTURE = "battle/backgrounds/kris_finisher_wind"
local WIND_ROTATION = -math.pi / 2
local WIND_SCALE = 4
local WIND_SCROLL_SPEED = 42 * 4
local WIND_ALPHA = 0.24 / 1.25

local NOISE_ALPHA = 0.055
local NOISE_SCALE = 1.5
local NOISE_SPEED = 0.32

local FULLSCREEN_FILTER_COLOR_RGB = { 0.698 / 4, 0, 0 }
local FULLSCREEN_FILTER_ALPHA = 0.35
local FULLSCREEN_FILTER_NOISE_ALPHA = 0.02
local FULLSCREEN_FILTER_NOISE_SCALE = 10.5
local FULLSCREEN_FILTER_NOISE_SPEED = 0.32

-- Red particle controls. All of these values are easy to tune here.
local PARTICLE_COLOR = { 1, 0.08, 0.06 }
local PARTICLE_MIN_INTERVAL = 0.25 -- minimum seconds between spawns
local PARTICLE_MAX_INTERVAL = 0.5 -- maximum seconds between spawns
local PARTICLE_MIN_WIDTH = 2 -- vertical thickness, in pixels
local PARTICLE_MAX_WIDTH = 5
local PARTICLE_MIN_LENGTH = 150 -- horizontal length, in pixels
local PARTICLE_MAX_LENGTH = 420
local PARTICLE_MIN_SPEED = 640 -- leftward speed, in pixels per second
local PARTICLE_MAX_SPEED = 980
local PARTICLE_MIN_ALPHA = 0.34 / 4
local PARTICLE_MAX_ALPHA = 0.72 / 4
local PARTICLE_MAX_COUNT = 5
local PARTICLE_SPAWN_MARGIN = 16 -- empty space kept above and below the screen
local PARTICLE_VERTICAL_GAP = 1 -- minimum visible gap between particle rows
local PARTICLE_POSITION_ATTEMPTS = 96

local KrisFinisherWindBackground, super = Class(Object)

local function randomBetween(min, max)
    return min + (max - min) * love.math.random()
end

function KrisFinisherWindBackground:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = BATTLE_LAYERS["background"]
    self.time = 0
    self.scroll = 0
    self.next_particle = randomBetween(PARTICLE_MIN_INTERVAL, PARTICLE_MAX_INTERVAL)
    self.particles = {}
    self.fullscreen_filter_progress = 0

    self.texture = Assets.getTexture(WIND_TEXTURE)
    self.texture:setFilter("nearest", "nearest")
    self.texture:setWrap("repeat", "repeat")

    -- The rotated image is 208px wide and 640px tall at native scale.
    self.rotated_width = self.texture:getHeight() * WIND_SCALE
    self.rotated_height = self.texture:getWidth() * WIND_SCALE

    self.noise_shader = love.graphics.newShader([[
        extern float time;
        extern float amount;
        extern float scale;

        float hash(vec2 p) {
            p = fract(p * vec2(123.34, 456.21));
            p += dot(p, p + 45.32);
            return fract(p.x * p.y);
        }

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec4 source = Texel(tex, uv);
            vec2 cell = floor(screen_coords / scale);
            float noise = hash(cell + floor(time * 6.0));
            float grain = (noise - 0.5) * amount;
            return vec4(source.rgb + grain, source.a) * color;
        }
    ]])

    self.fullscreen_filter_shader = love.graphics.newShader([[
        extern vec3 filterColor;
        extern float filterAlpha;
        extern float time;
        extern float amount;
        extern float scale;

        float hash(vec2 p) {
            p = fract(p * vec2(123.34, 456.21));
            p += dot(p, p + 45.32);
            return fract(p.x * p.y);
        }

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec2 cell = floor(screen_coords / scale);
            float noise = hash(cell + floor(time * 6.0));
            float grain = (noise - 0.5) * amount;
            vec3 result = clamp(filterColor + grain, 0.0, 1.0);
            return vec4(result, filterAlpha) * color;
        }
    ]])
end

function KrisFinisherWindBackground:findParticleY(height)
    local min_y = PARTICLE_SPAWN_MARGIN
    local max_y = SCREEN_HEIGHT - PARTICLE_SPAWN_MARGIN - height
    if max_y < min_y then
        return nil
    end

    local function isAvailable(y)
        for _, other in ipairs(self.particles) do
            local other_y = other.y
            local other_height = other.width
            local separated_above = y + height + PARTICLE_VERTICAL_GAP <= other_y
            local separated_below = other_y + other_height + PARTICLE_VERTICAL_GAP <= y
            if not separated_above and not separated_below then
                return false
            end
        end
        return true
    end

    -- Try random positions first so the rows do not look evenly distributed.
    for _ = 1, PARTICLE_POSITION_ATTEMPTS do
        local y = love.math.random(min_y, max_y)
        if isAvailable(y) then
            return y
        end
    end

    -- If random sampling misses a gap, scan every pixel before giving up.
    for y = min_y, max_y do
        if isAvailable(y) then
            return y
        end
    end
end

function KrisFinisherWindBackground:spawnParticle()
    if #self.particles >= PARTICLE_MAX_COUNT then
        return
    end

    -- Integer dimensions keep the one-pixel gap reliable after rasterization.
    local width = love.math.random(PARTICLE_MIN_WIDTH, PARTICLE_MAX_WIDTH)
    local length = randomBetween(PARTICLE_MIN_LENGTH, PARTICLE_MAX_LENGTH)
    local speed = randomBetween(PARTICLE_MIN_SPEED, PARTICLE_MAX_SPEED)
    local y = self:findParticleY(width)
    if not y then
        return
    end

    table.insert(self.particles, {
        x = SCREEN_WIDTH + length,
        y = y,
        width = width,
        length = length,
        speed = speed,
        alpha = randomBetween(PARTICLE_MIN_ALPHA, PARTICLE_MAX_ALPHA),
    })
end

function KrisFinisherWindBackground:updateParticles()
    for index = #self.particles, 1, -1 do
        local particle = self.particles[index]
        particle.x = particle.x - particle.speed * DT

        -- Keep the strip fully opaque until its right edge leaves the screen.
        if particle.x + particle.length < 0 then
            table.remove(self.particles, index)
        end
    end
end

function KrisFinisherWindBackground:setFullscreenFilterProgress(progress)
    self.fullscreen_filter_progress = math.max(0, math.min(1, progress))
end

function KrisFinisherWindBackground:clear()
    self.particles = {}
    self.fullscreen_filter_progress = 0
    self.active = false
    self.visible = false
    if self.parent then
        self:remove()
    end
end

function KrisFinisherWindBackground:update()
    super.update(self)

    self.time = self.time + DT
    self.scroll = (self.scroll + WIND_SCROLL_SPEED * DT) % self.rotated_width
    self.next_particle = self.next_particle - DT

    while self.next_particle <= 0 do
        self:spawnParticle()
        self.next_particle = self.next_particle + randomBetween(
            PARTICLE_MIN_INTERVAL,
            PARTICLE_MAX_INTERVAL
        )
    end

    self:updateParticles()
end

function KrisFinisherWindBackground:drawWind()
    if not self.texture then
        return
    end

    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    local old_shader = love.graphics.getShader()

    love.graphics.push()
    love.graphics.origin()
    love.graphics.translate(0, SCREEN_HEIGHT)
    love.graphics.rotate(WIND_ROTATION)

    Draw.setColor(
        BACKGROUND_COLOR_RGB[1],
        BACKGROUND_COLOR_RGB[2],
        BACKGROUND_COLOR_RGB[3],
        WIND_ALPHA
    )
    self.noise_shader:send("time", self.time * NOISE_SPEED)
    self.noise_shader:send("amount", NOISE_ALPHA)
    self.noise_shader:send("scale", NOISE_SCALE)
    love.graphics.setShader(self.noise_shader)

    -- Under the -90 degree transform, local Y becomes screen X.
    local y = -self.rotated_width - self.scroll
    while y < SCREEN_WIDTH + self.rotated_width do
        love.graphics.draw(self.texture, 0, y, 0, WIND_SCALE, WIND_SCALE)
        y = y + self.rotated_width
    end

    love.graphics.pop()
    love.graphics.setShader(old_shader)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

function KrisFinisherWindBackground:drawBase()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    local old_shader = love.graphics.getShader()

    love.graphics.push()
    love.graphics.origin()
    love.graphics.setShader()
    Draw.setColor(
        BACKGROUND_FILL_RGB[1],
        BACKGROUND_FILL_RGB[2],
        BACKGROUND_FILL_RGB[3],
        1
    )
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.pop()

    love.graphics.setShader(old_shader)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

function KrisFinisherWindBackground:drawParticles()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    for _, particle in ipairs(self.particles) do
        Draw.setColor(PARTICLE_COLOR[1], PARTICLE_COLOR[2], PARTICLE_COLOR[3], particle.alpha)
        love.graphics.rectangle(
            "fill",
            math.floor(particle.x),
            math.floor(particle.y),
            math.ceil(particle.length),
            math.ceil(particle.width)
        )
    end

    Draw.setColor(old_r, old_g, old_b, old_a)
end

function KrisFinisherWindBackground:drawFullscreenFilter()
    local filter_alpha = FULLSCREEN_FILTER_ALPHA * self.fullscreen_filter_progress
    if filter_alpha <= 0 then
        return
    end

    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    local old_shader = love.graphics.getShader()

    self.fullscreen_filter_shader:send(
        "filterColor",
        FULLSCREEN_FILTER_COLOR_RGB
    )
    self.fullscreen_filter_shader:send("filterAlpha", filter_alpha)
    self.fullscreen_filter_shader:send(
        "time",
        self.time * FULLSCREEN_FILTER_NOISE_SPEED
    )
    self.fullscreen_filter_shader:send(
        "amount",
        FULLSCREEN_FILTER_NOISE_ALPHA
    )
    self.fullscreen_filter_shader:send(
        "scale",
        FULLSCREEN_FILTER_NOISE_SCALE
    )

    love.graphics.push()
    love.graphics.origin()
    love.graphics.setShader(self.fullscreen_filter_shader)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.pop()

    love.graphics.setShader(old_shader)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

function KrisFinisherWindBackground:draw()
    self:drawBase()
    self:drawWind()
    self:drawParticles()
end

return KrisFinisherWindBackground
