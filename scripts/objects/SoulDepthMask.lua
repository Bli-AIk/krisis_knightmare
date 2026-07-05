local SoulDepthMask, super = Class(Object)

local DEPTH_TEXTURE = "battle/backgrounds/kris_depth_hot"
local DEPTH_ALPHA = 0.56
local GROW_TIME = 1
local SCROLL_SPEED = 12
local TEXTURE_SCALE_X = 1.8
local TEXTURE_SCALE_Y = 1.75
local TEXTURE_OFFSET_X = 11
local TEXTURE_OFFSET_Y = 237
local CHILD_LAYER = -1
local CHILD_LAYER_SPLIT = 0
local CAPTURE_DIR = "debug/soul_depth_capture"
local CAPTURE_TIME = 0.2

local function easeOutCubic(t)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local function lerp(from, to, t)
    return from + (to - from) * t
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
    self.capture_timer = 0
    self.capture_done = false

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

function SoulDepthMask:update()
    super.update(self)

    self.grow_timer = math.min(self.grow_timer + DT, GROW_TIME)
    local progress = GROW_TIME > 0 and MathUtils.clamp(self.grow_timer / GROW_TIME, 0, 1) or 1
    self.diameter = lerp(self.start_diameter, self.target_diameter, easeOutCubic(progress))
    self.radius = self.diameter / 2

    self.texture_x = self.texture_x + SCROLL_SPEED * DT
    self.texture_y = self.texture_y + SCROLL_SPEED * DT

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

    love.graphics.setColor(1, 1, 1, DEPTH_ALPHA)
    love.graphics.draw(self.texture, self.quad, -self.radius, -self.radius, 0, TEXTURE_SCALE_X, TEXTURE_SCALE_Y)

    if old_stencil_mode then
        love.graphics.setStencilTest(old_stencil_mode, old_stencil_value)
    else
        love.graphics.setStencilTest()
    end
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

return SoulDepthMask
