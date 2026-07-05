local SoulDepthMask, super = Class(Object)

local DEPTH_TEXTURE = "battle/backgrounds/kris_depth_hot"
local DEPTH_ALPHA = 0.56
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
local STAR_START_SCALE = 0.9
local STAR_END_SCALE = 0.2
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
    return min + love.math.random() * (max - min)
end

local function angleDistance(a, b)
    local diff = math.abs((a - b + math.pi) % (math.pi * 2) - math.pi)
    return diff
end

function SoulDepthMask:init(start_diameter, target_diameter)
    super.init(self, 0, 0)

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
    self.star_burst_timer = randomFloat(STAR_BURST_MIN_INTERVAL, STAR_BURST_MAX_INTERVAL)
    self.star_bursts_enabled = true
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
    self.depth_echo = self.wave:spawnObjectTo(self.parent, SoulDepthEcho(DEPTH_ALPHA), self.x, self.y)
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

    local finale = SoulDepthFinale(x, y, self.wave, self.depth_echo)
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
    local count = love.math.random(STAR_BURST_MIN_COUNT, STAR_BURST_MAX_COUNT)
    local angles = self:getStarBurstAngles(count)
    local distance = self.radius + STAR_EDGE_OFFSET

    for i = 1, count do
        local angle = angles[i]
        local spawn_distance = distance + randomFloat(0, STAR_DISTANCE_JITTER)
        local start_x = center_x + math.cos(angle) * spawn_distance
        local start_y = center_y + math.sin(angle) * spawn_distance
        local travel_time = randomFloat(STAR_TRAVEL_MIN_TIME, STAR_TRAVEL_MAX_TIME)

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

    if old_stencil_mode then
        love.graphics.setStencilTest(old_stencil_mode, old_stencil_value)
    else
        love.graphics.setStencilTest()
    end
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

return SoulDepthMask
