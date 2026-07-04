local RechargeRadialBurst, super = Class(Object)

local DURATION = 0.95
local FAR_RADIUS = 780
local CAPTURE_TIMES = { 0.08, 0.20, 0.34, 0.50, 0.68 }
local CAPTURE_DIR = "debug/recharge_radial_capture"

local RAYS = {
    { angle = -0.95, width = 0.018, delay = 0.02, life = 0.50, alpha = 0.72, length = 1.03, color = { 1.00, 0.98, 0.82 } },
    { angle = -0.63, width = 0.045, delay = 0.04, life = 0.62, alpha = 0.48, length = 1.05, color = { 1.00, 0.88, 0.48 } },
    { angle = -0.27, width = 0.013, delay = 0.12, life = 0.44, alpha = 0.66, length = 0.98, color = { 1.00, 0.96, 0.72 } },
    { angle =  0.30, width = 0.060, delay = 0.08, life = 0.68, alpha = 0.36, length = 0.98, color = { 1.00, 0.78, 0.30 } },
    { angle =  0.76, width = 0.028, delay = 0.14, life = 0.54, alpha = 0.44, length = 0.82, color = { 1.00, 0.90, 0.55 } },
    { angle =  1.46, width = 0.016, delay = 0.20, life = 0.46, alpha = 0.38, length = 0.62, color = { 1.00, 0.97, 0.78 } },
    { angle =  2.95, width = 0.020, delay = 0.10, life = 0.48, alpha = 0.30, length = 0.52, color = { 1.00, 0.86, 0.46 } },
}

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
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
    for _, ray in ipairs(RAYS) do
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
