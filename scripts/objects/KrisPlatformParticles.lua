local DEFAULT_TEXTURE = "battle/backgrounds/kris_platform_adjusted"
local SPAWN_MIN_INTERVAL = 0.006
local SPAWN_MAX_INTERVAL = 0.018
local MAX_PARTICLES = 80
local PARTICLE_MIN_LIFETIME = 0.44
local PARTICLE_MAX_LIFETIME = 0.92
local PARTICLE_MIN_SIZE = 1
local PARTICLE_MAX_SIZE = 2
local PARTICLE_MIN_SPEED = 14
local PARTICLE_MAX_SPEED = 30
local PARTICLE_MAX_DRIFT = 4
local SAMPLE_ATTEMPTS = 64
local MIN_SAMPLE_BRIGHTNESS = 0.22
local COLOR_DARKEN = 0.58

local KrisPlatformParticles, super = Class(Object)

local function randomFloat(min, max)
    return min + Mod:randomKrisis("kris_platform_particles") * (max - min)
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function KrisPlatformParticles:init(platform, texture_path)
    super.init(self, 0, 0)

    self.platform = platform
    self.texture_path = texture_path or DEFAULT_TEXTURE
    self.target_texture_path = nil
    self.fade_time = 0
    self.fade_timer = 0
    self.texture_data = {}
    self.particles = {}
    self.spawn_timer = randomFloat(SPAWN_MIN_INTERVAL, SPAWN_MAX_INTERVAL)

    self:cacheTextureData(self.texture_path)
end

function KrisPlatformParticles:cacheTextureData(texture_path)
    if texture_path and self.texture_data[texture_path] == nil then
        self.texture_data[texture_path] = Assets.getTextureData(texture_path) or false
    end
    return texture_path and self.texture_data[texture_path] or nil
end

function KrisPlatformParticles:getTextureData(texture_path)
    local data = self:cacheTextureData(texture_path)
    if data == false then
        return nil
    end
    return data
end

function KrisPlatformParticles:crossFadeTo(texture_path, time)
    if not texture_path or texture_path == self.target_texture_path then
        return
    end
    if texture_path == self.texture_path then
        self.target_texture_path = nil
        self.fade_timer = 0
        self.fade_time = 0
        return
    end

    self:cacheTextureData(texture_path)
    self.target_texture_path = texture_path
    self.fade_time = math.max(time or 0, 0)
    self.fade_timer = 0

    if self.fade_time <= 0 then
        self.texture_path = texture_path
        self.target_texture_path = nil
    end
end

function KrisPlatformParticles:getFadeProgress()
    if not self.target_texture_path or self.fade_time <= 0 then
        return 0
    end
    return clamp(self.fade_timer / self.fade_time, 0, 1)
end

function KrisPlatformParticles:updateTextureFade()
    if not self.target_texture_path then
        return
    end

    self.fade_timer = self.fade_timer + DT
    if self.fade_timer >= self.fade_time then
        self.texture_path = self.target_texture_path
        self.target_texture_path = nil
        self.fade_timer = 0
        self.fade_time = 0
    end
end

function KrisPlatformParticles:getPlatformScale()
    local platform = self.platform
    if not platform then
        return 1, 1
    end
    return platform.scale_x or 1, platform.scale_y or platform.scale_x or 1
end

function KrisPlatformParticles:getPixel(data, x, y)
    if not data then
        return 0, 0, 0, 0
    end
    return data:getPixel(x, y)
end

function KrisPlatformParticles:getBlendedPixel(source_data, target_data, pixel_x, pixel_y, fade)
    local sr, sg, sb, sa = self:getPixel(source_data, pixel_x, pixel_y)
    local tr, tg, tb, ta = self:getPixel(target_data, pixel_x, pixel_y)

    if target_data then
        return sr + (tr - sr) * fade,
            sg + (tg - sg) * fade,
            sb + (tb - sb) * fade,
            sa + (ta - sa) * fade
    end

    return sr, sg, sb, sa
end

function KrisPlatformParticles:samplePosition(source_data, target_data, fade)
    local width = source_data:getWidth()
    local height = source_data:getHeight()
    for _ = 1, SAMPLE_ATTEMPTS do
        local pixel_x = Mod:randomKrisis("kris_platform_particles", 0, width - 1)
        local pixel_y = Mod:randomKrisis("kris_platform_particles", 0, height - 1)
        local _, _, _, alpha = self:getBlendedPixel(source_data, target_data, pixel_x, pixel_y, fade)
        if alpha > 0 then
            return pixel_x, pixel_y, alpha
        end
    end
end

function KrisPlatformParticles:sampleColor(source_data, target_data, fade)
    local width = source_data:getWidth()
    local height = source_data:getHeight()
    local best

    for _ = 1, SAMPLE_ATTEMPTS do
        local pixel_x = Mod:randomKrisis("kris_platform_particles", 0, width - 1)
        local pixel_y = Mod:randomKrisis("kris_platform_particles", 0, height - 1)
        local r, g, b, alpha = self:getBlendedPixel(source_data, target_data, pixel_x, pixel_y, fade)

        if alpha > 0 then
            local brightness = r + g + b
            if brightness >= MIN_SAMPLE_BRIGHTNESS then
                return r * COLOR_DARKEN, g * COLOR_DARKEN, b * COLOR_DARKEN
            end
            if not best or brightness > best.brightness then
                best = { r = r, g = g, b = b, brightness = brightness }
            end
        end
    end

    if best then
        return best.r * COLOR_DARKEN, best.g * COLOR_DARKEN, best.b * COLOR_DARKEN
    end
end

function KrisPlatformParticles:samplePixel()
    local source_data = self:getTextureData(self.texture_path)
    if not source_data then
        return
    end

    local target_data = self:getTextureData(self.target_texture_path)
    local fade = self:getFadeProgress()
    local pixel_x, pixel_y, alpha = self:samplePosition(source_data, target_data, fade)
    if not pixel_x then
        return
    end

    local r, g, b = self:sampleColor(source_data, target_data, fade)
    if not r then
        r, g, b = 0, 0, 0
    end

    return pixel_x, pixel_y, r, g, b, alpha
end

function KrisPlatformParticles:spawnParticle()
    if #self.particles >= MAX_PARTICLES then
        return
    end

    local pixel_x, pixel_y, r, g, b, a = self:samplePixel()
    if not pixel_x then
        return
    end

    local platform = self.platform
    local scale_x, scale_y = self:getPlatformScale()
    local x = ((platform and platform.x) or 0) + (pixel_x + Mod:randomKrisis("kris_platform_particles")) * scale_x
    local y = ((platform and platform.y) or 0) + (pixel_y + Mod:randomKrisis("kris_platform_particles")) * scale_y

    table.insert(self.particles, {
        x = x,
        y = y,
        vx = randomFloat(-PARTICLE_MAX_DRIFT, PARTICLE_MAX_DRIFT),
        vy = -randomFloat(PARTICLE_MIN_SPEED, PARTICLE_MAX_SPEED),
        size = Mod:randomKrisis("kris_platform_particles", PARTICLE_MIN_SIZE, PARTICLE_MAX_SIZE),
        lifetime = randomFloat(PARTICLE_MIN_LIFETIME, PARTICLE_MAX_LIFETIME),
        age = 0,
        r = r,
        g = g,
        b = b,
        a = a,
    })
end

function KrisPlatformParticles:updateEmission()
    self.spawn_timer = self.spawn_timer - DT

    while self.spawn_timer <= 0 do
        self:spawnParticle()
        self.spawn_timer = self.spawn_timer + randomFloat(SPAWN_MIN_INTERVAL, SPAWN_MAX_INTERVAL)
    end
end

function KrisPlatformParticles:updateParticles()
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.age = particle.age + DT

        if particle.age >= particle.lifetime then
            table.remove(self.particles, i)
        else
            particle.x = particle.x + particle.vx * DT
            particle.y = particle.y + particle.vy * DT
        end
    end
end

function KrisPlatformParticles:update()
    super.update(self)
    self:updateTextureFade()
    self:updateEmission()
    self:updateParticles()
end

function KrisPlatformParticles:draw()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    for _, particle in ipairs(self.particles) do
        local progress = clamp(particle.age / particle.lifetime, 0, 1)
        local alpha = particle.a * (1 - progress)
        Draw.setColor(particle.r, particle.g, particle.b, alpha)
        love.graphics.rectangle(
            "fill",
            math.floor(particle.x + 0.5),
            math.floor(particle.y + 0.5),
            particle.size,
            particle.size
        )
    end

    Draw.setColor(old_r, old_g, old_b, old_a)
    super.draw(self)
end

return KrisPlatformParticles
