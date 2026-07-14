local SoulDepthMask, super = Class(Object)

local DEPTH_TEXTURE = "battle/backgrounds/kris_depth_hot"
local DEPTH_ALPHA = 0.56
local SOUL_ECHO_ALPHA = 0.28
local GROW_TIME = 1
local DEPTH_WHITE_TIME = 10 / 60
local DEPTH_SHRINK_TIME = 5 / 60
local SOUL_WHITE_DELAY = 0.1
local SOUL_WHITE_TIME = 40 / 60
local FINALE_DELAY = 20 / 60
local SCROLL_SPEED = 12
local TEXTURE_SCALE_X = 1.8
local TEXTURE_SCALE_Y = 1.75
local TEXTURE_OFFSET_X = 11
local TEXTURE_OFFSET_Y = 237
local CHILD_LAYER = -1
local CHILD_LAYER_SPLIT = 0
local STAR_EDGE_OFFSET = 8
local STAR_BURST_MIN_INTERVAL = 0.5
local STAR_BURST_MAX_INTERVAL = 1.5
local STAR_BURST_MIN_COUNT = 2
local STAR_BURST_MAX_COUNT = 4
local STAR_MIN_ANGLE_SPACING = math.rad(18)
local STAR_ANGLE_RANDOM_ATTEMPTS = 16
local STAR_DISTANCE_JITTER = 3
local STAR_TRAVEL_MIN_TIME = 1.25
local STAR_TRAVEL_MAX_TIME = 1.75
local STAR_TRAVEL_TIME_SCALE = 1.35
local STAR_INDICATOR_ALPHA = 0.75
local STAR_START_SCALE = 0.9
local STAR_END_SCALE = 0.2
local RADIAL_PARTICLE_INITIAL_COUNT = 100
local RADIAL_PARTICLE_MAX_COUNT = 180
local RADIAL_PARTICLE_MIN_INTERVAL = 0.018
local RADIAL_PARTICLE_MAX_INTERVAL = 0.045
local RADIAL_PARTICLE_MIN_EMIT_COUNT = 2
local RADIAL_PARTICLE_MAX_EMIT_COUNT = 5
local RADIAL_PARTICLE_MIN_LIFE = 0.36
local RADIAL_PARTICLE_MAX_LIFE = 0.74
local RADIAL_PARTICLE_MIN_RADIUS = 0.10
local RADIAL_PARTICLE_MAX_RADIUS = 0.94
local RADIAL_PARTICLE_MIN_LENGTH = 7
local RADIAL_PARTICLE_MAX_LENGTH = 23
local RADIAL_PARTICLE_MIN_SPEED = 0.18
local RADIAL_PARTICLE_MAX_SPEED = 0.46
local RADIAL_PARTICLE_MIN_WIDTH = 1
local RADIAL_PARTICLE_MAX_WIDTH = 2
local RADIAL_PARTICLE_MASK_SCALE = 0.8
local RADIAL_RING_FIRST_DELAY = 0.75
local RADIAL_RING_LEAD_COUNT = 3
local RADIAL_RING_LEAD_LIFE = 0.84
local RADIAL_RING_LIFE = 1.0
local RADIAL_RING_SHORT_INTERVAL = 0.22
local RADIAL_RING_GROUP_INTERVAL = 0.16
local RADIAL_RING_MIN_RADIUS_SCALE = 0.08
local RADIAL_RING_WIDTH_SCALE = 0.2
local RADIAL_RING_ALPHA = 0.3
local CAPTURE_DIR = "debug/soul_depth_capture"
local CAPTURE_TIME = 0.2
local DEPTH_WHITE_SHADER = [[
    extern float white_amount;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 pixel = Texel(tex, texture_coords);
        pixel.rgb = mix(pixel.rgb, vec3(1.0), white_amount);
        return pixel * color;
    }
]]

local function easeOutCubic(t)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local function lerp(from, to, t)
    return from + (to - from) * t
end

local function randomFloat(min, max)
    return min + Mod:randomKrisis("soul_depth_mask") * (max - min)
end

local function angleDistance(a, b)
    local diff = math.abs((a - b + math.pi) % (math.pi * 2) - math.pi)
    return diff
end

function SoulDepthMask:init(start_diameter, target_diameter, options)
    super.init(self, 0, 0)

    options = options or {}

    self.layer = CHILD_LAYER
    self.start_diameter = start_diameter or 0
    self.target_diameter = target_diameter or self.start_diameter
    self.diameter = self.start_diameter
    self.radius = self.diameter / 2
    self.target_radius = self.target_diameter / 2
    self.debug_rect = { -self.target_radius, -self.target_radius, self.target_diameter, self.target_diameter }
    self.grow_timer = 0
    self.texture_x = TEXTURE_OFFSET_X
    self.texture_y = TEXTURE_OFFSET_Y
    self.finale_options = options.finale_options
    self.star_burst_min_count = options.star_burst_min_count or STAR_BURST_MIN_COUNT
    self.star_burst_max_count = options.star_burst_max_count or STAR_BURST_MAX_COUNT
    self.star_burst_timer = randomFloat(STAR_BURST_MIN_INTERVAL, STAR_BURST_MAX_INTERVAL)
    self.star_bursts_enabled = true
    self.star_travel_time_scale = options.star_travel_time_scale or STAR_TRAVEL_TIME_SCALE
    self.radial_particles_enabled = options.radial_particles == true
    self.radial_particles = {}
    self.star_indicator_particles = {}
    self.star_indicator_particles_enabled = options.star_indicator_particles ~= false
    self.radial_particle_initial_count = options.radial_particle_initial_count or RADIAL_PARTICLE_INITIAL_COUNT
    self.radial_particle_max_count = options.radial_particle_max_count or RADIAL_PARTICLE_MAX_COUNT
    self.radial_particle_min_interval = options.radial_particle_min_interval or RADIAL_PARTICLE_MIN_INTERVAL
    self.radial_particle_max_interval = options.radial_particle_max_interval or RADIAL_PARTICLE_MAX_INTERVAL
    self.radial_particle_min_emit_count = options.radial_particle_min_emit_count or RADIAL_PARTICLE_MIN_EMIT_COUNT
    self.radial_particle_max_emit_count = options.radial_particle_max_emit_count or RADIAL_PARTICLE_MAX_EMIT_COUNT
    self.radial_particle_mask_scale = options.radial_particle_mask_scale or RADIAL_PARTICLE_MASK_SCALE
    self.radial_particle_timer = randomFloat(self.radial_particle_min_interval, self.radial_particle_max_interval)
    self.radial_rings_enabled = options.radial_rings == true
    self.radial_rings = {}
    self.radial_ring_elapsed = 0
    self.radial_ring_next_spawn = options.radial_ring_first_delay or RADIAL_RING_FIRST_DELAY
    self.radial_ring_spawn_index = 1
    self.radial_ring_lead_count = options.radial_ring_lead_count or RADIAL_RING_LEAD_COUNT
    self.radial_ring_lead_life = options.radial_ring_lead_life or RADIAL_RING_LEAD_LIFE
    self.radial_ring_life = options.radial_ring_life or RADIAL_RING_LIFE
    self.radial_ring_short_interval = options.radial_ring_short_interval or RADIAL_RING_SHORT_INTERVAL
    self.radial_ring_group_interval = options.radial_ring_group_interval or RADIAL_RING_GROUP_INTERVAL
    self.radial_ring_min_radius_scale = options.radial_ring_min_radius_scale or RADIAL_RING_MIN_RADIUS_SCALE
    self.radial_ring_width_scale = options.radial_ring_width_scale or RADIAL_RING_WIDTH_SCALE
    self.radial_ring_alpha = options.radial_ring_alpha or RADIAL_RING_ALPHA
    self.depth_echo_spawned = false
    self.white_fading = false
    self.white_timer = 0
    self.white_elapsed = 0
    self.white_progress = 0
    self.shrinking = false
    self.shrink_done = false
    self.shrink_timer = 0
    self.shrink_start_diameter = self.diameter
    self.finale_triggered = false
    self.soul_white_complete_elapsed = nil
    self.capture_timer = 0
    self.capture_done = false

    self.white_shader = love.graphics.newShader(DEPTH_WHITE_SHADER)
    self.texture = Assets.getTexture(DEPTH_TEXTURE)
    if self.texture then
        self.texture:setWrap("repeat", "repeat")
        self.quad = love.graphics.newQuad(
            0, 0,
            math.max((self.target_radius * 2) / TEXTURE_SCALE_X, 1),
            math.max((self.target_radius * 2) / TEXTURE_SCALE_Y, 1),
            self.texture:getWidth(),
            self.texture:getHeight()
        )
    end

    if self.radial_particles_enabled then
        for _ = 1, self.radial_particle_initial_count do
            self:spawnRadialParticle(Mod:randomKrisis("soul_depth_mask"))
        end
    end
end

function SoulDepthMask:onAdd(parent)
    self.old_draw_children_below = parent.draw_children_below
    self.old_draw_children_above = parent.draw_children_above

    if parent.draw_children_below == nil or parent.draw_children_below <= self.layer then
        parent.draw_children_below = CHILD_LAYER_SPLIT
    end
    parent.draw_children_above = parent.draw_children_above or CHILD_LAYER_SPLIT
end

function SoulDepthMask:onRemove(parent)
    if parent and parent.draw_children_below == CHILD_LAYER_SPLIT then
        parent.draw_children_below = self.old_draw_children_below
    end
    if parent and parent.draw_children_above == CHILD_LAYER_SPLIT then
        parent.draw_children_above = self.old_draw_children_above
    end
end

function SoulDepthMask:getCenterInSoul()
    return self.x, self.y
end

function SoulDepthMask:spawnDepthEcho()
    if self.depth_echo_spawned or not self.wave or not self.parent then
        return
    end

    self.depth_echo_spawned = true
    self.depth_echo = self.wave:spawnObjectTo(self.parent, SoulDepthEcho(SOUL_ECHO_ALPHA), self.x, self.y)
end

function SoulDepthMask:beginWhiteFade()
    if self.white_fading then
        return
    end

    self.star_bursts_enabled = false
    self.white_fading = true
    self.white_timer = 0
    self.white_elapsed = 0
    self.soul_white_complete_elapsed = nil

    if self.parent and self.parent.stopChase then
        self.parent:stopChase()
    end

    if not self.depth_echo or not self.depth_echo.parent then
        self:spawnDepthEcho()
    end
    if self.depth_echo and self.depth_echo.startWhiteFade then
        self.depth_echo:startWhiteFade(SOUL_WHITE_DELAY, SOUL_WHITE_TIME)
    end
end

function SoulDepthMask:beginShrink()
    if self.shrinking or self.shrink_done then
        return
    end

    self.shrinking = true
    self.shrink_timer = 0
    self.shrink_start_diameter = self.diameter
end

function SoulDepthMask:isSoulWhiteComplete()
    if self.depth_echo and self.depth_echo.parent then
        return (self.depth_echo.alpha or 0) >= 1
    end

    return self.white_elapsed >= SOUL_WHITE_DELAY + SOUL_WHITE_TIME
end

function SoulDepthMask:triggerFinale()
    if self.finale_triggered then
        return
    end

    self.finale_triggered = true

    local x, y
    if self.parent and self.parent.getRelativePos then
        x, y = self.parent:getRelativePos(self.x, self.y, Game.battle)
    else
        x, y = self:getRelativePos(0, 0, Game.battle)
    end

    local finale = SoulDepthFinale(x, y, self.wave, self.depth_echo, self.finale_options)
    if self.wave and self.wave.spawnObject then
        self.wave:spawnObject(finale)
    else
        Game.battle:addChild(finale)
    end
    self:remove()
end

function SoulDepthMask:getStarBurstAngles(count)
    local angles = {}

    for _ = 1, count do
        local chosen
        for _ = 1, STAR_ANGLE_RANDOM_ATTEMPTS do
            local candidate = randomFloat(0, math.pi * 2)
            local valid = true
            for _, angle in ipairs(angles) do
                if angleDistance(candidate, angle) < STAR_MIN_ANGLE_SPACING then
                    valid = false
                    break
                end
            end
            if valid then
                chosen = candidate
                break
            end
        end

        table.insert(angles, chosen or randomFloat(0, math.pi * 2))
    end

    return angles
end

function SoulDepthMask:spawnStarBurst()
    if not self.wave or not self.parent or not self.parent.parent then
        return
    end

    local center_x, center_y = self:getCenterInSoul()
    local count = Mod:randomKrisis("soul_depth_mask", self.star_burst_min_count, self.star_burst_max_count)
    local angles = self:getStarBurstAngles(count)
    local distance = self.radius + STAR_EDGE_OFFSET

    for i = 1, count do
        local angle = angles[i]
        local spawn_distance = distance + randomFloat(0, STAR_DISTANCE_JITTER)
        local start_x = center_x + math.cos(angle) * spawn_distance
        local start_y = center_y + math.sin(angle) * spawn_distance
        local travel_time = randomFloat(STAR_TRAVEL_MIN_TIME, STAR_TRAVEL_MAX_TIME)
            * self.star_travel_time_scale

        self:spawnStarIndicatorParticle(angle)

        self.wave:spawnBulletTo(
            self.parent,
            "soul_depth_star",
            start_x,
            start_y,
            center_x,
            center_y,
            travel_time,
            STAR_START_SCALE,
            STAR_END_SCALE
        )
    end
end

function SoulDepthMask:spawnStarIndicatorParticle(angle, options)
    if not self.star_indicator_particles_enabled then
        return
    end

    options = options or {}
    local particle = self:makeRadialParticle()
    particle.angle = angle
    particle.radius = 1
    particle.to_center = true
    particle.alpha = options.alpha or STAR_INDICATOR_ALPHA
    particle.color = options.color or { 1, 1, 1 }
    particle.blend_mode = options.blend_mode
    particle.life = randomFloat(RADIAL_PARTICLE_MIN_LIFE * 0.72, RADIAL_PARTICLE_MAX_LIFE * 0.82)
    particle.age = 0

    table.insert(self.star_indicator_particles, particle)
end

function SoulDepthMask:updateStarBursts()
    if not self.star_bursts_enabled then
        return
    end

    self.star_burst_timer = self.star_burst_timer - DT
    if self.star_burst_timer > 0 then
        return
    end

    self:spawnStarBurst()
    self.star_burst_timer = randomFloat(STAR_BURST_MIN_INTERVAL, STAR_BURST_MAX_INTERVAL)
end

function SoulDepthMask:makeRadialParticle(age_progress)
    local age = age_progress and randomFloat(0, RADIAL_PARTICLE_MAX_LIFE) * age_progress or 0
    local life = randomFloat(RADIAL_PARTICLE_MIN_LIFE, RADIAL_PARTICLE_MAX_LIFE)
    age = math.min(age, life * 0.92)

    return {
        angle = randomFloat(0, math.pi * 2),
        radius = randomFloat(RADIAL_PARTICLE_MIN_RADIUS, RADIAL_PARTICLE_MAX_RADIUS),
        speed = randomFloat(RADIAL_PARTICLE_MIN_SPEED, RADIAL_PARTICLE_MAX_SPEED),
        length = randomFloat(RADIAL_PARTICLE_MIN_LENGTH, RADIAL_PARTICLE_MAX_LENGTH),
        width = randomFloat(RADIAL_PARTICLE_MIN_WIDTH, RADIAL_PARTICLE_MAX_WIDTH),
        alpha = randomFloat(0.38, 0.92),
        life = life,
        age = age,
        flicker = randomFloat(0, math.pi * 2),
        angle_drift = randomFloat(-0.025, 0.025),
    }
end

function SoulDepthMask:spawnRadialParticle(age_progress)
    if #self.radial_particles >= self.radial_particle_max_count then
        return
    end

    table.insert(self.radial_particles, self:makeRadialParticle(age_progress))
end

function SoulDepthMask:updateRadialParticles()
    if not self.radial_particles_enabled and not self.star_indicator_particles_enabled then
        return
    end

    for i = #self.radial_particles, 1, -1 do
        local particle = self.radial_particles[i]
        particle.age = particle.age + DT
        if particle.age >= particle.life then
            table.remove(self.radial_particles, i)
        end
    end

    for i = #self.star_indicator_particles, 1, -1 do
        local particle = self.star_indicator_particles[i]
        particle.age = particle.age + DT
        if particle.age >= particle.life then
            table.remove(self.star_indicator_particles, i)
        end
    end

    if self.white_fading or not self.radial_particles_enabled then
        return
    end

    self.radial_particle_timer = self.radial_particle_timer - DT
    while self.radial_particle_timer <= 0 do
        local emit_count = Mod:randomKrisis(
            "soul_depth_mask",
            self.radial_particle_min_emit_count,
            self.radial_particle_max_emit_count
        )
        for _ = 1, emit_count do
            self:spawnRadialParticle()
        end
        self.radial_particle_timer = self.radial_particle_timer
            + randomFloat(self.radial_particle_min_interval, self.radial_particle_max_interval)
    end
end

function SoulDepthMask:getRadialParticleMaskRadius()
    return self.radius * self.radial_particle_mask_scale
end

function SoulDepthMask:getRadialRingInterval(index)
    local lead_count = self.radial_ring_lead_count

    if index < lead_count then
        return self.radial_ring_lead_life
    elseif index == lead_count then
        return self.radial_ring_lead_life + self.radial_ring_group_interval
    elseif index == lead_count + 1 then
        return self.radial_ring_short_interval
    elseif index == lead_count + 2 then
        return self.radial_ring_group_interval
    elseif index == lead_count + 3 or index == lead_count + 4 then
        return self.radial_ring_short_interval
    end
end

function SoulDepthMask:getRadialRingCount()
    return self.radial_ring_lead_count + 5
end

function SoulDepthMask:spawnRadialRing(index)
    local life = index <= self.radial_ring_lead_count
        and self.radial_ring_lead_life
        or self.radial_ring_life

    table.insert(self.radial_rings, {
        age = 0,
        life = life,
    })
end

function SoulDepthMask:updateRadialRings()
    if not self.radial_rings_enabled then
        return
    end

    self.radial_ring_elapsed = self.radial_ring_elapsed + DT

    for i = #self.radial_rings, 1, -1 do
        local ring = self.radial_rings[i]
        ring.age = ring.age + DT
        if ring.age >= ring.life then
            table.remove(self.radial_rings, i)
        end
    end

    while not self.white_fading
        and self.radial_ring_spawn_index <= self:getRadialRingCount()
        and self.radial_ring_elapsed >= self.radial_ring_next_spawn do
        local spawn_index = self.radial_ring_spawn_index
        self:spawnRadialRing(spawn_index)

        local interval = self:getRadialRingInterval(spawn_index)
        self.radial_ring_spawn_index = self.radial_ring_spawn_index + 1
        if interval then
            self.radial_ring_next_spawn = self.radial_ring_next_spawn + interval
        else
            self.radial_ring_next_spawn = math.huge
        end
    end
end

function SoulDepthMask:update()
    super.update(self)

    if self.shrinking then
        if not self.shrink_done then
            self.shrink_timer = math.min(self.shrink_timer + DT, DEPTH_SHRINK_TIME)
            local shrink_progress = DEPTH_SHRINK_TIME > 0 and MathUtils.clamp(self.shrink_timer / DEPTH_SHRINK_TIME, 0, 1) or 1
            self.diameter = lerp(self.shrink_start_diameter, 0, easeOutCubic(shrink_progress))
            self.radius = self.diameter / 2

            if shrink_progress >= 1 then
                self.shrink_done = true
                self.diameter = 0
                self.radius = 0
            end
        end
    else
        self.grow_timer = math.min(self.grow_timer + DT, GROW_TIME)
        local progress = GROW_TIME > 0 and MathUtils.clamp(self.grow_timer / GROW_TIME, 0, 1) or 1
        self.diameter = lerp(self.start_diameter, self.target_diameter, easeOutCubic(progress))
        self.radius = self.diameter / 2
        if progress >= 1 then
            self:spawnDepthEcho()
        end
    end

    self.texture_x = self.texture_x + SCROLL_SPEED * DT
    self.texture_y = self.texture_y + SCROLL_SPEED * DT
    self:updateStarBursts()
    self:updateRadialParticles()
    self:updateRadialRings()

    if self.white_fading then
        self.white_elapsed = self.white_elapsed + DT
        self.white_timer = math.min(self.white_timer + DT, DEPTH_WHITE_TIME)
        self.white_progress = DEPTH_WHITE_TIME > 0 and MathUtils.clamp(self.white_timer / DEPTH_WHITE_TIME, 0, 1) or 1

        if self.white_progress >= 1 and self:isSoulWhiteComplete() then
            self:beginShrink()
            self.soul_white_complete_elapsed = (self.soul_white_complete_elapsed or 0) + DT

            if self.soul_white_complete_elapsed >= FINALE_DELAY then
                self:triggerFinale()
                return
            end
        else
            self.soul_white_complete_elapsed = nil
        end
    end

    if Game:getConfig("krisisDebugSoulDepthCapture") and not self.capture_done then
        self.capture_timer = self.capture_timer + DT
        if self.capture_timer >= CAPTURE_TIME then
            self.capture_done = true
            love.filesystem.createDirectory(CAPTURE_DIR)
            local path = CAPTURE_DIR .. "/live.png"
            love.graphics.captureScreenshot(path)
            print("[SoulDepthMask] captured " .. love.filesystem.getSaveDirectory() .. "/" .. path)
        end
    end
end

function SoulDepthMask:drawRadialRings()
    if not self.radial_rings_enabled or #self.radial_rings == 0 then
        return
    end

    local mask_radius = self:getRadialParticleMaskRadius()
    if mask_radius <= 0 then
        return
    end

    local old_line_width = love.graphics.getLineWidth()
    local old_blend, old_alpha_mode = love.graphics.getBlendMode()
    local old_stencil_mode, old_stencil_value = love.graphics.getStencilTest()
    local fade_with_white = 1 - (self.white_progress or 0)
    local line_width = mask_radius * self.radial_ring_width_scale
    local max_ring_radius = mask_radius + line_width * 0.5
    local min_ring_radius = math.max(mask_radius * self.radial_ring_min_radius_scale, line_width * 0.5)
    local ring_clip_radius = math.min(mask_radius + line_width, self.radius)

    love.graphics.setStencilTest()
    love.graphics.stencil(function()
        love.graphics.circle("fill", 0, 0, ring_clip_radius)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setBlendMode("add")
    love.graphics.setLineWidth(line_width)

    for _, ring in ipairs(self.radial_rings) do
        local progress = MathUtils.clamp(ring.age / ring.life, 0, 1)
        local radius_progress = easeOutCubic(progress)
        local ring_radius = lerp(max_ring_radius, min_ring_radius, radius_progress)
        local fade_in = MathUtils.clamp(progress / 0.18, 0, 1)
        local fade_out = MathUtils.clamp((1 - progress) / 0.22, 0, 1)
        local alpha = self.radial_ring_alpha * fade_in * fade_out * fade_with_white

        if alpha > 0 and ring_radius > line_width * 0.5 then
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.circle("line", 0, 0, ring_radius, 96)
        end
    end

    love.graphics.setBlendMode(old_blend, old_alpha_mode)
    love.graphics.setLineWidth(old_line_width)
    if old_stencil_mode then
        love.graphics.setStencilTest(old_stencil_mode, old_stencil_value)
    else
        love.graphics.setStencilTest()
    end
end

function SoulDepthMask:drawRadialParticle(particle, mask_radius, fade_with_white)
    local progress = MathUtils.clamp(particle.age / particle.life, 0, 1)
    local fade = math.sin(progress * math.pi)
    local angle = particle.angle + particle.angle_drift * progress
    local radius = particle.to_center
        and mask_radius * (1 - progress)
        or mask_radius * (particle.radius + particle.speed * progress)
    local half_length = particle.length * (0.55 + (0.45 * fade)) / 2
    local inner = math.max(radius - half_length, 0)
    local outer = math.min(radius + half_length, mask_radius)

    if outer <= inner then
        return
    end

    local pulse = 0.88 + 0.12 * math.sin((self.grow_timer + particle.flicker) * 34)
    local alpha = particle.alpha * fade * fade_with_white * pulse
    local color = particle.color or { 1, 1, 1 }
    love.graphics.setLineWidth(particle.width)
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.line(
        math.cos(angle) * inner,
        math.sin(angle) * inner,
        math.cos(angle) * outer,
        math.sin(angle) * outer
    )
end

function SoulDepthMask:drawRadialParticles()
    if (not self.radial_particles_enabled or #self.radial_particles == 0)
        and #self.star_indicator_particles == 0
    then
        return
    end

    if self.radius <= 0 then
        return
    end

    local old_line_width = love.graphics.getLineWidth()
    local old_blend, old_alpha_mode = love.graphics.getBlendMode()
    local old_stencil_mode, old_stencil_value = love.graphics.getStencilTest()
    local fade_with_white = 1 - (self.white_progress or 0)

    love.graphics.setStencilTest()
    love.graphics.stencil(function()
        love.graphics.circle("fill", 0, 0, self.radius)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    love.graphics.setBlendMode("add")
    for _, particle in ipairs(self.radial_particles) do
        self:drawRadialParticle(particle, self:getRadialParticleMaskRadius(), fade_with_white)
    end
    for _, particle in ipairs(self.star_indicator_particles) do
        love.graphics.setBlendMode(particle.blend_mode or "add")
        self:drawRadialParticle(particle, self.radius, fade_with_white)
    end

    love.graphics.setBlendMode(old_blend, old_alpha_mode)
    love.graphics.setLineWidth(old_line_width)
    if old_stencil_mode then
        love.graphics.setStencilTest(old_stencil_mode, old_stencil_value)
    else
        love.graphics.setStencilTest()
    end
end

function SoulDepthMask:draw()
    if not self.texture or not self.quad or self.radius <= 0 then
        return
    end

    local diameter = self.radius * 2
    self.quad:setViewport(
        self.texture_x,
        self.texture_y,
        diameter / TEXTURE_SCALE_X,
        diameter / TEXTURE_SCALE_Y,
        self.texture:getWidth(),
        self.texture:getHeight()
    )

    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    local old_stencil_mode, old_stencil_value = love.graphics.getStencilTest()

    love.graphics.stencil(function()
        love.graphics.circle("fill", 0, 0, self.radius)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    local old_shader = love.graphics.getShader()
    if self.white_shader then
        self.white_shader:send("white_amount", self.white_progress)
        love.graphics.setShader(self.white_shader)
    end

    love.graphics.setColor(1, 1, 1, DEPTH_ALPHA)
    love.graphics.draw(self.texture, self.quad, -self.radius, -self.radius, 0, TEXTURE_SCALE_X, TEXTURE_SCALE_Y)
    love.graphics.setShader(old_shader)
    self:drawRadialRings()
    self:drawRadialParticles()

    if old_stencil_mode then
        love.graphics.setStencilTest(old_stencil_mode, old_stencil_value)
    else
        love.graphics.setStencilTest()
    end
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

return SoulDepthMask
