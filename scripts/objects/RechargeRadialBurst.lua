local RechargeRadialBurst, super = Class(Object)

local DURATION = 1.35
local TWO_PI = math.pi * 2
local FAR_RADIUS = 780
local MIN_RAY_COUNT = 3
local MAX_RAY_COUNT = 6
local MAGNIFY_SCALE = 1.11
local MAGNIFY_RING_DELAY = 0.03
local MAGNIFY_RING_LIFE = 1.08
local MAGNIFY_RING_THICKNESS = 72
local CAPTURE_TIMES = { 0.08, 0.20, 0.34, 0.50, 0.68 }
local CAPTURE_DIR = "debug/recharge_radial_capture"
local REQUIRED_RAY_RANGES = {
    { min = -0.96, max = -0.44 },
    { min =  0.44, max =  1.05 },
}

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function randomFloat(min, max)
    return min + (max - min) * Mod:randomKrisis("recharge_radial_burst")
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

    for _, range in ipairs(REQUIRED_RAY_RANGES) do
        table.insert(angles, randomFloat(range.min, range.max))
    end

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
    local count = Mod:randomKrisis("recharge_radial_burst", MIN_RAY_COUNT, MAX_RAY_COUNT)
    count = math.max(count, #REQUIRED_RAY_RANGES)
    local angles = generateRayAngles(count)
    local rays = {}

    for i, angle in ipairs(angles) do
        local thin = Mod:randomKrisis("recharge_radial_burst") < 0.45
        local pale = Mod:randomKrisis("recharge_radial_burst") < 0.35

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

local function maxCornerDistance(x, y)
    local distances = {
        Utils.dist(x, y, 0, 0),
        Utils.dist(x, y, SCREEN_WIDTH, 0),
        Utils.dist(x, y, 0, SCREEN_HEIGHT),
        Utils.dist(x, y, SCREEN_WIDTH, SCREEN_HEIGHT),
    }

    return math.max(unpack(distances))
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
    self.snapshot = nil
    self.waiting_for_snapshot = true
    self.after_snapshot = options.after_snapshot
    self.ring_max_radius = maxCornerDistance(self.origin_x, self.origin_y) + MAGNIFY_RING_THICKNESS
    self.layer = options.layer or (BATTLE_LAYERS["top"] - 10)

    love.graphics.captureScreenshot(function(image_data)
        if self.parent then
            self.snapshot = love.graphics.newImage(image_data)
            self.snapshot:setFilter("nearest", "nearest")
            self.waiting_for_snapshot = false
            if self.after_snapshot then
                local after_snapshot = self.after_snapshot
                self.after_snapshot = nil
                after_snapshot(self)
            end
        end
    end)

    if self.capture then
        love.filesystem.createDirectory(CAPTURE_DIR)
    end
end

function RechargeRadialBurst:update()
    super.update(self)

    if self.waiting_for_snapshot then
        return
    end

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

function RechargeRadialBurst:drawMagnifiedSnapshot()
    local image = self.snapshot
    if not image then
        return
    end

    local scale_x = (SCREEN_WIDTH / image:getWidth()) * MAGNIFY_SCALE
    local scale_y = (SCREEN_HEIGHT / image:getHeight()) * MAGNIFY_SCALE
    local draw_x = self.origin_x * (1 - MAGNIFY_SCALE)
    local draw_y = self.origin_y * (1 - MAGNIFY_SCALE)

    love.graphics.setColor(1, 1, 1, 0.92)
    love.graphics.draw(image, draw_x, draw_y, 0, scale_x, scale_y)
end

function RechargeRadialBurst:drawMagnifyRing()
    local p = (self.time - MAGNIFY_RING_DELAY) / MAGNIFY_RING_LIFE
    if p <= 0 or p >= 1 then
        return
    end

    p = clamp(p, 0, 1)
    local grow = easeOutCubic(p)
    local outer = self.ring_max_radius * grow
    local thickness = MAGNIFY_RING_THICKNESS * (1.25 - (0.25 * p))
    local inner = math.max(outer - thickness, 0)
    local alpha = (1 - p) * 0.62

    love.graphics.setBlendMode("alpha")
    love.graphics.stencil(function()
        love.graphics.circle("fill", self.origin_x, self.origin_y, outer, 96)
    end, "replace", 1)
    love.graphics.stencil(function()
        love.graphics.circle("fill", self.origin_x, self.origin_y, inner, 96)
    end, "replace", 0, true)
    love.graphics.setStencilTest("equal", 1)
    self:drawMagnifiedSnapshot()
    love.graphics.setStencilTest()
end

function RechargeRadialBurst:draw()
    if self.waiting_for_snapshot then
        return
    end

    love.graphics.push()
    love.graphics.origin()

    local old_blend, old_alpha_mode = love.graphics.getBlendMode()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    self:drawMagnifyRing()

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
