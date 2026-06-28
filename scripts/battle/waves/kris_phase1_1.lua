local KrisPhase1_1, super = Class(Wave)
local ShaderFX = require("src.engine.drawfx.shaderfx")
local Rectangle = require("src.engine.objects.rectangle")

local function randomBetween(min, max)
    return min + (max - min) * love.math.random()
end

local SLASH_CIRCLE_SIZE = 200

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
    -- 接近垂直的角度：只有这些方向允许长拉伸、飞很远
    self.vertical_angles = {
        -1.66, -1.60, -1.55, -1.49,
         1.48,  1.54,  1.59,  1.66,
         4.62,  4.70,  4.78,
    }
    -- 点缀角度：保持短粒子，避免效果变成均匀圆形
    self.accent_angles = {
        -0.72, -0.38, 0.42, 0.78,
         2.32,  2.70, 3.44, 3.86,
    }
end

function SlashParticles:startEmission()
    self.visible = true
    self.emitting = true
    self.emit_time = 0
    self.hide_time = 0
    self.next_emit = 0
    self.particles = {}

    -- 初始爆发数量
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
    -- 设多少度以上使用长拉伸、远飞参数
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
            -- 持续发射间隔；数值越小，粒子越多
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

function KrisPhase1_1:init()
    super.init(self)
    self.time = 8
end

function KrisPhase1_1:setupSlashAssets()
    if self.slash_assets then
        return
    end

    local size = SLASH_CIRCLE_SIZE
    local ts = { size, size }

    -- 1. 形变 shader（先运行）
    -- 使用 transformed=true：先在劈砍本地坐标里做形变，再整体旋转，避免角度改变时形变方向跟屏幕轴互相干扰。
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

    -- 2-3. 水平+垂直高斯模糊（在形变之后）
    -- 同样放在本地坐标处理，保持不同 rotation 下的视觉一致。
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

    -- 圆（实心 + 空心）
    local tex_solid = makeHardCircle(size, { 0.05, 1 }, 0)
    local tex_donut = makeHardCircle(size, { 0.05, 1 }, 40)

    self.slash_assets = {
        solid = tex_solid,
        donut = tex_donut,
    }
end

function KrisPhase1_1:spawnSlash(x, y, rotation)
    self:setupSlashAssets()

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

    local circle_solid = makeCircle(self.slash_assets.solid, 1)  -- 初始可见
    local circle_donut = makeCircle(self.slash_assets.donut, 0)  -- 初始隐藏

    local slash_particles = SlashParticles(x, y, rotation)
    slash_particles.layer = 5
    self:addChild(slash_particles)

    -- 竖线
    local line_h = circle_solid.height * circle_solid.scale_y
    local line = Rectangle(x, y, 1, line_h)
    line:setOrigin(0.5, 0.5)
    line.rotation = rotation
    line.color = { 1, 1, 1 }
    line.alpha = 0
    line.layer = -1
    self:addChild(line)

    -- 圆形缩小（两个一起）
    Game.battle.timer:tween(15 / 60, circle_solid, { scale_x = 0 })
    Game.battle.timer:tween(15 / 60, circle_donut, { scale_x = 0 })

    -- 圆形快消失时线以白色出现
    self.timer:after(10 / 60, function()
        Game.battle.timer:tween(5 / 60, line, { alpha = 1 }, "out-quad")
    end)

    -- 变白时：实心换空心
    self.timer:after(4 / 60, function()
        circle_solid.alpha = 0
        circle_donut.alpha = 1
        circle_solid.color = { 1, 1, 1 }
        circle_donut.color = { 1, 1, 1 }
        slash_particles:startEmission()
    end)

    -- 15/60 后，线变红 → 再0.5秒渐变消失+下移
    self.timer:after(15 / 60, function()
        slash_particles:stopEmission()
        line.color = { 1, 0, 0 }
        circle_donut.color = { 1, 0, 0 }
        -- 红线沿劈砍方向滑出，rotation 为 0 时保持原本的向下移动。
        local slide_x = -math.sin(rotation) * line_h
        local slide_y = math.cos(rotation) * line_h
        Game.battle.timer:tween(0.5, line, {
            alpha = 0,
            x     = line.x + slide_x,
            y     = line.y + slide_y,
        }, "out-quad")
    end)
end

function KrisPhase1_1:onStart()
    -- rotation 使用弧度；需要角度时传 math.rad(角度)
    self:spawnSlash(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, math.rad(45))
end

function KrisPhase1_1:update()
    -- self.fx.vars.phase = self.fx.vars.phase + 25 * DT
    super.update(self)
end

return KrisPhase1_1
