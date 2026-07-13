-- Background RGB color, with each channel in the 0.0-1.0 range.
local BACKGROUND_COLOR_RGB = { 0.698, 0, 0 }
local BACKGROUND_FILL_RGB = { 0, 0, 0 }

local WIND_TEXTURE = "battle/backgrounds/kris_finisher_wind"
local WIND_ROTATION = -math.pi / 2
local WIND_SCALE = 4
local WIND_SCROLL_SPEED = 42 * 4
local WIND_ALPHA = 0.24 / 1.25

local NOISE_ALPHA = 0.055
local NOISE_SCALE = 1.5
local NOISE_SPEED = 0.32

local PARTICLE_COLOR = { 1, 0.08, 0.06 }
local PARTICLE_MIN_INTERVAL = 0.42
local PARTICLE_MAX_INTERVAL = 1.25
local PARTICLE_MIN_WIDTH = 2
local PARTICLE_MAX_WIDTH = 5
local PARTICLE_MIN_LENGTH = 150
local PARTICLE_MAX_LENGTH = 420
local PARTICLE_MIN_SPEED = 640
local PARTICLE_MAX_SPEED = 980
local PARTICLE_MIN_LIFETIME = 0.72
local PARTICLE_MAX_LIFETIME = 1.35
local PARTICLE_MAX_COUNT = 5

local KrisFinisherWindBackground, super = Class(Object)

local function randomBetween(min, max)
    return min + (max - min) * love.math.random()
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function KrisFinisherWindBackground:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = BATTLE_LAYERS["background"]
    self.time = 0
    self.scroll = 0
    self.next_particle = randomBetween(PARTICLE_MIN_INTERVAL, PARTICLE_MAX_INTERVAL)
    self.particles = {}

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
end

function KrisFinisherWindBackground:spawnParticle()
    if #self.particles >= PARTICLE_MAX_COUNT then
        return
    end

    local width = randomBetween(PARTICLE_MIN_WIDTH, PARTICLE_MAX_WIDTH)
    local length = randomBetween(PARTICLE_MIN_LENGTH, PARTICLE_MAX_LENGTH)
    local speed = randomBetween(PARTICLE_MIN_SPEED, PARTICLE_MAX_SPEED)
    local lifetime = randomBetween(PARTICLE_MIN_LIFETIME, PARTICLE_MAX_LIFETIME)

    table.insert(self.particles, {
        x = SCREEN_WIDTH + length,
        y = randomBetween(16, SCREEN_HEIGHT - 16),
        width = width,
        length = length,
        speed = speed,
        lifetime = lifetime,
        age = 0,
        alpha = randomBetween(0.34, 0.72),
    })
end

function KrisFinisherWindBackground:updateParticles()
    for index = #self.particles, 1, -1 do
        local particle = self.particles[index]
        particle.age = particle.age + DT
        particle.x = particle.x - particle.speed * DT

        if particle.age >= particle.lifetime or particle.x + particle.length < -8 then
            table.remove(self.particles, index)
        end
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
        local progress = clamp(particle.age / particle.lifetime, 0, 1)
        local fade_in = clamp(progress / 0.08, 0, 1)
        local fade_out = 1 - clamp((progress - 0.72) / 0.28, 0, 1)
        local alpha = particle.alpha * fade_in * fade_out

        Draw.setColor(PARTICLE_COLOR[1], PARTICLE_COLOR[2], PARTICLE_COLOR[3], alpha)
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

function KrisFinisherWindBackground:draw()
    self:drawBase()
    self:drawWind()
    self:drawParticles()
end

return KrisFinisherWindBackground
