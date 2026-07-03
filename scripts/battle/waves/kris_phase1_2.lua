local KrisPhase1_2, super = Class(Wave)
local ShaderFX = require("src.engine.drawfx.shaderfx")
local Rectangle = require("src.engine.objects.rectangle")

local function randomBetween(min, max)
    return min + (max - min) * love.math.random()
end

local SLASH_CIRCLE_SIZE = 200
local SLASH_START_DELAY = 16 / 30
local DEFAULT_SLASH_INTERVAL = 50 / 60
local KRIS_FAR_X = 10000
local KRIS_FAR_Y = 10000
local TOP_SLASH_Y = 88
local UPPER_SLASH_Y = 125
local LOWER_SLASH_Y = 235
local BOTTOM_SLASH_Y = 245
local TOP_KRIS_Y = 148
local UPPER_KRIS_Y = 155
local LOWER_KRIS_Y = 327

local DEFAULT_SLASHES = {
    { x = 480 + 50 - 15, y = TOP_SLASH_Y,   r = math.rad(360 - 199), kris_x = 550, kris_y = TOP_KRIS_Y },
    { x = 480 + 50 - 20, y = BOTTOM_SLASH_Y, r = math.rad(360 - 167), kris_x = 550, kris_y = LOWER_KRIS_Y },
    { x = 480 + 50,      y = UPPER_SLASH_Y, r = math.rad(360 - 199), kris_x = 550, kris_y = UPPER_KRIS_Y },
    { x = 480 + 50 - 15, y = LOWER_SLASH_Y, r = math.rad(360 - 173), kris_x = 550, kris_y = LOWER_KRIS_Y },
    { x = 480 + 50 - 15, y = UPPER_SLASH_Y, r = math.rad(360 - 205), kris_x = 550, kris_y = UPPER_KRIS_Y },
    { x = 480 + 50 - 15, y = LOWER_SLASH_Y, r = math.rad(360 - 173), kris_x = 550, kris_y = LOWER_KRIS_Y },
    { x = 480 + 50 - 15, y = TOP_SLASH_Y,   r = math.rad(360 - 212), kris_x = 550, kris_y = TOP_KRIS_Y },
}

local function moveAttackerTo(attacker, x, y)
    attacker.target_x = x
    attacker.target_y = y
    attacker:setPosition(attacker.target_x, attacker.target_y)
end

local function moveAttackerAway(attacker)
    moveAttackerTo(attacker, KRIS_FAR_X, KRIS_FAR_Y)
end

local function clearArenaShake(arena)
    local timer = Game.battle.timer
    if arena.kris_shake_tweens then
        for _, handle in ipairs(arena.kris_shake_tweens) do
            timer:cancel(handle)
        end
    end
    if arena.kris_shake_restore then
        arena.graphics.shake_friction = arena.kris_shake_restore.friction
        arena.graphics.shake_delay = arena.kris_shake_restore.delay
        arena.kris_shake_restore = nil
    end
    arena.kris_shake_tweens = nil
    arena.graphics.shake_x = 0
    arena.graphics.shake_y = 0
    arena.graphics.shake_timer = 0
end

local function shakeArena(from_x, from_y)
    local arena = Game.battle.arena
    if arena then
        clearArenaShake(arena)

        local center_x, center_y = arena:getCenter()
        local angle = MathUtils.angle(from_x or center_x, from_y or center_y, center_x, center_y)
        local jitter = randomBetween(math.rad(8), math.rad(18))
        if love.math.random() < 0.5 then
            jitter = -jitter
        end
        angle = angle + jitter

        local amount = 12
        local dx = math.cos(angle) * amount
        local dy = math.sin(angle) * amount
        local graphics = arena.graphics
        local timer = Game.battle.timer
        local handles = {}

        arena.kris_shake_tweens = handles
        arena.kris_shake_restore = {
            friction = graphics.shake_friction,
            delay = graphics.shake_delay,
        }
        graphics.shake_friction = 0
        graphics.shake_delay = math.huge

        local function addTween(handle)
            table.insert(handles, handle)
        end

        addTween(timer:tween(1 / 30, graphics, { shake_x = dx, shake_y = dy }, "linear", function()
            if arena.kris_shake_tweens ~= handles then return end
            addTween(timer:tween(3 / 30, graphics, { shake_x = -dx * 0.45, shake_y = -dy * 0.45 }, "linear", function()
                if arena.kris_shake_tweens ~= handles then return end
                addTween(timer:tween(2 / 30, graphics, { shake_x = 0, shake_y = 0 }, "linear", function()
                    if arena.kris_shake_tweens ~= handles then return end
                    clearArenaShake(arena)
                end))
            end))
        end))
    end
end

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

local SlashParticles, slash_super = Class(Object)

function SlashParticles:init(x, y, rotation)
    slash_super.init(self, x, y)

    self.rotation = rotation or 0
    self.visible = false
    self.emit_time = 0
    self.emit_duration = 11 / 60
    self.hide_time = 0
    self.emitting = false
    self.rx = 10
    self.ry = 152
    self.next_emit = 0
    self.particles = {}
    self.vertical_angles = {
        -1.66, -1.60, -1.55, -1.49,
        1.48, 1.54, 1.59, 1.66,
        4.62, 4.70, 4.78,
    }
    self.accent_angles = {
        -0.72, -0.38, 0.42, 0.78,
        2.32, 2.70, 3.44, 3.86,
    }
end

function SlashParticles:startEmission()
    self.visible = true
    self.emitting = true
    self.emit_time = 0
    self.hide_time = 0
    self.next_emit = 0
    self.particles = {}

    for _ = 1, 4 * 4 do
        self:spawnParticle()
    end
end

function SlashParticles:stopEmission()
    self.emitting = false
    self.hide_time = 0
end

function SlashParticles:spawnParticle()
    local angle_pool = love.math.random() < 0.8 and self.vertical_angles or self.accent_angles
    local theta = angle_pool[love.math.random(1, #angle_pool)] + randomBetween(-0.08, 0.08)
    local dx, dy = math.cos(theta), math.sin(theta)
    local vertical_degrees = math.deg(math.asin(math.min(math.abs(dy), 1)))
    local vertical_amount = vertical_degrees >= 85 and 1 or 0
    local speed = randomBetween(120, 260) + randomBetween(520, 820) * vertical_amount
    local lifetime = randomBetween(0.12, 0.28) + randomBetween(0.55, 0.95) * vertical_amount
    local length = randomBetween(16, 34) + randomBetween(78, 150) * vertical_amount
    local width = vertical_amount > 0.5 and (love.math.random() < 0.55 and 2 or 1) or 1
    local base_x = dx * self.rx
    local base_y = dy * self.ry

    table.insert(self.particles, {
        x = base_x,
        y = base_y,
        dx = dx,
        dy = dy,
        speed = speed,
        lifetime = lifetime,
        length = length,
        width = width,
        age = 0,
    })
end

function SlashParticles:update()
    if self.emitting then
        self.emit_time = self.emit_time + DT
        self.next_emit = self.next_emit - DT
        while self.next_emit <= 0 do
            self:spawnParticle()
            self.next_emit = self.next_emit + randomBetween(0.01, 0.024)
        end
        if self.emit_time >= self.emit_duration then
            self:stopEmission()
        end
    else
        self.hide_time = self.hide_time + DT
        if self.hide_time > 0.24 and #self.particles == 0 then
            self.visible = false
        end
    end

    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.age = particle.age + DT
        if particle.age >= particle.lifetime then
            table.remove(self.particles, i)
        end
    end

    slash_super.update(self)
end

function SlashParticles:draw()
    local old_width = love.graphics.getLineWidth()

    for _, particle in ipairs(self.particles) do
        local t = particle.age / particle.lifetime
        local dist = particle.speed * particle.age
        local x = particle.x + particle.dx * dist
        local y = particle.y + particle.dy * dist
        local half_length = particle.length * (1 - t * 0.35) / 2

        love.graphics.setLineWidth(particle.width)
        Draw.setColor(1, 1, 1, (1 - t) * (1 - t * 0.35))
        love.graphics.line(
            x - particle.dx * half_length,
            y - particle.dy * half_length,
            x + particle.dx * half_length,
            y + particle.dy * half_length
        )
    end

    love.graphics.setLineWidth(old_width)
    Draw.setColor(1, 1, 1, 1)
    slash_super.draw(self)
end

function KrisPhase1_2:init()
    super.init(self)
    self.time = 8
end

function KrisPhase1_2:getSlashInterval()
    return DEFAULT_SLASH_INTERVAL
end

function KrisPhase1_2:getInitialSlashDelay()
    return DEFAULT_SLASH_INTERVAL
end

function KrisPhase1_2:getSlashes()
    return DEFAULT_SLASHES
end

function KrisPhase1_2:getKrisSlashAnimationFrameDelay()
    return nil
end

function KrisPhase1_2:spawnKrisSlashAnimation(x, y, animation)
    local sprite = ActorSprite("kris")
    sprite:setOrigin(0.5, 1)
    sprite:setScale(2)
    sprite.layer = BATTLE_LAYERS["above_bullets"] + 1

    local frame_delay = self:getKrisSlashAnimationFrameDelay()
    local anim = frame_delay and { animation, frame_delay, false } or animation
    sprite:setAnimation(anim, function()
        sprite:remove()
    end)
    self:spawnObject(sprite, x, y)
    return sprite
end

function KrisPhase1_2:setupSlashAssets()
    if self.slash_assets then
        return
    end

    local size = SLASH_CIRCLE_SIZE
    local ts = { size, size }

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
    }, true, 0)

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
    }, true, 1)

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
    }, true, 2)

    local tex_solid = makeHardCircle(size, { 0.05, 1 }, 0)
    local tex_donut = makeHardCircle(size, { 0.05, 1 }, 40)

    self.slash_assets = {
        solid = tex_solid,
        donut = tex_donut,
    }
end

function KrisPhase1_2:spawnSlash(x, y, rotation, kris_x, kris_y)
    self:setupSlashAssets()
    shakeArena(kris_x, kris_y)

    x = x or SCREEN_WIDTH / 2
    y = y or SCREEN_HEIGHT / 2
    rotation = rotation or 0

    local function makeCircle(tex, alpha)
        local c = Sprite(tex, x, y)
        c:setOrigin(0.5, 0.5)
        c:addFX(self.distort_fx)
        c:addFX(self.hblur_fx)
        c:addFX(self.vblur_fx)
        c.scale_x = 3
        c.scale_y = 2.5
        c.rotation = rotation
        c.color = { 1, 0, 0 }
        c.alpha = alpha
        self:addChild(c)
        return c
    end

    local circle_solid = makeCircle(self.slash_assets.solid, 1)
    local circle_donut = makeCircle(self.slash_assets.donut, 0)

    local slash_particles = SlashParticles(x, y, rotation)
    slash_particles.layer = 5
    self:addChild(slash_particles)

    local line_h = circle_solid.height * circle_solid.scale_y
    local line = Rectangle(x, y, 1, line_h)
    line:setOrigin(0.5, 0.5)
    line.rotation = rotation
    line.color = { 1, 1, 1 }
    line.alpha = 0
    line.layer = -1
    self:addChild(line)

    Game.battle.timer:tween(15 / 60, circle_solid, { scale_x = 0 })
    Game.battle.timer:tween(15 / 60, circle_donut, { scale_x = 0 })

    self.timer:after(10 / 60, function()
        Game.battle.timer:tween(5 / 60, line, { alpha = 1 }, "out-quad")
    end)

    self.timer:after(4 / 60, function()
        circle_solid.alpha = 0
        circle_donut.alpha = 1
        circle_solid.color = { 1, 1, 1 }
        circle_donut.color = { 1, 1, 1 }
        slash_particles:startEmission()
    end)

    self.timer:after(15 / 60, function()
        slash_particles:stopEmission()
        line.color = { 1, 0, 0 }
        circle_donut.color = { 1, 0, 0 }
        local slide_x = -math.sin(rotation) * line_h
        local slide_y = math.cos(rotation) * line_h
        Game.battle.timer:tween(0.5, line, {
            alpha = 0,
            x     = line.x + slide_x,
            y     = line.y + slide_y,
        }, "out-quad")
    end)

    local basic = 40
    local offsets = { -basic * 2, -basic, 0, basic, basic * 2 }
    local bullet_dir = rotation
    for _, d in ipairs(offsets) do
        local bx = x - math.sin(rotation) * d
        local by = y + math.cos(rotation) * d
        self:spawnBullet("small_sword", bx, by, bullet_dir, 5, 20, 0.75)
    end

    self.timer:after(10 / 60., function()
        for _, d in ipairs(offsets) do
            local bx = x - math.sin(rotation) * d
            local by = y + math.cos(rotation) * d
            local star = self:spawnBullet("star", bx, by, bullet_dir, 5, 20, 0.75)
            star.layer = BATTLE_LAYERS["bullets"] - 1
        end
    end)
end

function KrisPhase1_2:onStart()
    self.kris_home_positions = {}

    for _, attacker in ipairs(self:getAttackers()) do
        self.kris_home_positions[attacker] = {
            x = attacker.target_x or attacker.x,
            y = attacker.target_y or attacker.y,
        }
        attacker:setAnimation("flying_sword_disappear", function()
            moveAttackerAway(attacker)
        end)
    end

    self.slashes = self:getSlashes()
    self.slash_index = 0

    local function slashNext()
        self.slash_index = self.slash_index + 1
        local s = self.slashes[self.slash_index]
        if s then
            local animation = self.slash_index % 2 == 0 and "slash1" or "slash2"
            self:spawnKrisSlashAnimation(s.kris_x, s.kris_y, animation)
            self.timer:after(SLASH_START_DELAY, function()
                self:spawnSlash(s.x, s.y, s.r, s.kris_x, s.kris_y)
            end)

            if self.slashes[self.slash_index + 1] then
                self.timer:after(self:getSlashInterval(), slashNext)
            end
        end
    end

    self.timer:after(self:getInitialSlashDelay(), slashNext)
end

function KrisPhase1_2:onEnd(death)
    for _, attacker in ipairs(self:getAttackers()) do
        local home = self.kris_home_positions and self.kris_home_positions[attacker]
        if home then
            moveAttackerTo(attacker, home.x, home.y)
        end
        attacker:setAnimation("appear")
    end

    return super.onEnd(self, death)
end

function KrisPhase1_2:update()
    super.update(self)
end

function KrisPhase1_2:draw()
    super.draw(self)
end

return KrisPhase1_2
