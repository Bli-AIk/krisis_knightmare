local RechargeRadialBurst, super = Class(Object)

local DURATION = 0.95
local TWO_PI = math.pi * 2
local FAR_RADIUS = 780
local MIN_RAY_COUNT = 3
local MAX_RAY_COUNT = 6
local CAPTURE_TIMES = { 0.08, 0.20, 0.34, 0.50, 0.68 }
local CAPTURE_DIR = "debug/recharge_radial_capture"

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function randomFloat(min, max)
    return min + (max - min) * love.math.random()
end

local function angularDistance(a, b)
    return math.abs(((a - b + math.pi) % TWO_PI) - math.pi)
end

local function isAngleSeparated(angle, angles, min_distance)
    for _, other in ipairs(angles) do
        if angularDistance(angle, other) < min_distance then
            return false
        end
    end

    return true
end

local function generateRayAngles(count)
    local angles = {}
    local min_distance = randomFloat(0.46, 0.62)
    local attempts = 0

    while #angles < count do
        local angle = randomFloat(-math.pi, math.pi)
        if isAngleSeparated(angle, angles, min_distance) then
            table.insert(angles, angle)
        end

        attempts = attempts + 1
        if attempts > 80 then
            min_distance = min_distance * 0.9
            attempts = 0
        end
    end

    return angles
end

local function generateRays()
    local count = love.math.random(MIN_RAY_COUNT, MAX_RAY_COUNT)
    local angles = generateRayAngles(count)
    local rays = {}

    for i, angle in ipairs(angles) do
        local thin = love.math.random() < 0.45
        local pale = love.math.random() < 0.35

        rays[i] = {
            angle = angle,
            width = thin and randomFloat(0.010, 0.022) or randomFloat(0.030, 0.060),
            delay = randomFloat(0.00, 0.18),
            life = randomFloat(0.42, 0.70),
            alpha = thin and randomFloat(0.48, 0.74) or randomFloat(0.30, 0.52),
            length = randomFloat(0.56, 1.08),
            color = pale
                and { 1.00, randomFloat(0.94, 1.00), randomFloat(0.72, 0.92) }
                or { 1.00, randomFloat(0.76, 0.92), randomFloat(0.28, 0.58) },
        }
    end

    return rays
end

local function easeOutCubic(t)
    t = clamp(t, 0, 1)
    return 1 - ((1 - t) * (1 - t) * (1 - t))
end

local function drawRay(cx, cy, ray, age)
    local p = (age - ray.delay) / ray.life
    if p <= 0 or p >= 1 then
        return
    end

    local grow = easeOutCubic(p)
    local fade = math.sin(p * math.pi)
    local width = ray.width * (0.75 + 0.25 * grow)
    local inner = 6 + 14 * grow
    local outer = FAR_RADIUS * (ray.length or 1) * (0.34 + 0.66 * grow)
    local angle = ray.angle + math.sin((age * 8) + ray.angle) * 0.006
    local color = ray.color

    love.graphics.setColor(color[1], color[2], color[3], (ray.alpha or 1) * fade)
    love.graphics.polygon("fill",
        cx + math.cos(angle - width) * inner,
        cy + math.sin(angle - width) * inner,
        cx + math.cos(angle - width) * outer,
        cy + math.sin(angle - width) * outer,
        cx + math.cos(angle + width) * outer,
        cy + math.sin(angle + width) * outer,
        cx + math.cos(angle + width) * inner,
        cy + math.sin(angle + width) * inner
    )
end

function RechargeRadialBurst:init(x, y, options)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    options = options or {}

    self.origin_x = x or (SCREEN_WIDTH / 2)
    self.origin_y = y or (SCREEN_HEIGHT / 2)
    self.time = 0
    self.duration = options.duration or DURATION
    self.capture = options.capture
    self.quit_after_capture = options.quit_after_capture
    self.capture_index = 1
    self.capture_pending = false
    self.capture_printed = false
    self.rays = generateRays()
    self.layer = options.layer or (BATTLE_LAYERS["top"] - 10)

    if self.capture then
        love.filesystem.createDirectory(CAPTURE_DIR)
    end
end

function RechargeRadialBurst:update()
    super.update(self)

    self.time = self.time + DT

    if self.capture and CAPTURE_TIMES[self.capture_index] and self.time >= CAPTURE_TIMES[self.capture_index] then
        self.capture_pending = self.capture_index
        self.capture_index = self.capture_index + 1
    end

    if self.quit_after_capture and self.capture_index > #CAPTURE_TIMES and self.time >= (CAPTURE_TIMES[#CAPTURE_TIMES] + 0.12) then
        love.event.quit(0)
    end

    if self.time >= self.duration then
        self:remove()
    end
end

function RechargeRadialBurst:captureFrame(index)
    local path = string.format("%s/game_%02d.png", CAPTURE_DIR, index)
    love.graphics.captureScreenshot(path)

    if not self.capture_printed then
        self.capture_printed = true
        print("[RechargeRadialBurst] capture dir: " .. love.filesystem.getSaveDirectory() .. "/" .. CAPTURE_DIR)
    end
    print("[RechargeRadialBurst] captured " .. path)
end

function RechargeRadialBurst:draw()
    love.graphics.push()
    love.graphics.origin()

    local old_blend, old_alpha_mode = love.graphics.getBlendMode()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    love.graphics.setBlendMode("add")
    for _, ray in ipairs(self.rays) do
        drawRay(self.origin_x, self.origin_y, ray, self.time)
    end

    love.graphics.setBlendMode(old_blend, old_alpha_mode)
    love.graphics.setColor(old_r, old_g, old_b, old_a)

    if self.capture_pending then
        self:captureFrame(self.capture_pending)
        self.capture_pending = false
    end

    love.graphics.pop()
end

return RechargeRadialBurst
