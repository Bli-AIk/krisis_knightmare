-- 参考分辨率: 1080p 4:3 = 1440x1080
-- 游戏分辨率: 640x480
-- 缩放因子: 480/1080 = 4/9
local REF_SCALE = 4 / 9

local ELLIPSE_RX = 1120 * REF_SCALE
local ELLIPSE_RY = 617.9 * REF_SCALE
local HOLE_MIN_X = 1251.0
local HOLE_MIN_Y = 690.2
local HOLE_MAX_X = 1334.1
local HOLE_MAX_Y = 736.0
local VIGNETTE_X = 320
local VIGNETTE_Y = 170
local VIGNETTE_SCALE = 1.08
local VIGNETTE_PERIOD = 8

local KrisVignette, super = Class(Object)

function KrisVignette:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.time = 0
    self.period = VIGNETTE_PERIOD

    -- 两个环形区域, 从中心向外, 互不重叠
    -- 每层: { alpha, 内边界(大洞), 外边界(小洞) }
    self.rings = {
        { alpha = 0.77, inner = 1.16, outer = 1.0  }, -- 半透明环
        { alpha = 1.00, inner = 1.0,  outer = nil }, -- 最外环 (outer=nil → 椭圆边缘)
    }

    self.hole_w = HOLE_MIN_X * REF_SCALE
    self.hole_h = HOLE_MIN_Y * REF_SCALE

    if self.initVignetteDebug then
        self:initVignetteDebug()
    end
end

function KrisVignette:update()
    super.update(self)
    self.time = self.time + DT

    local t = (self.time % self.period) / self.period
    local f = (math.sin(t * 2 * math.pi) + 1) / 2

    self.hole_w = (HOLE_MIN_X + (HOLE_MAX_X - HOLE_MIN_X) * f) * REF_SCALE
    self.hole_h = (HOLE_MIN_Y + (HOLE_MAX_Y - HOLE_MIN_Y) * f) * REF_SCALE

    if self.updateVignetteDebug then
        self:updateVignetteDebug()
    end
end

function KrisVignette:draw()
    love.graphics.push()
    love.graphics.origin()

    local cx = VIGNETTE_X
    local cy = VIGNETTE_Y
    local scale = VIGNETTE_SCALE

    if self.getVignetteDebugTransform then
        cx, cy, scale = self:getVignetteDebugTransform(cx, cy, scale)
    end

    for _, ring in ipairs(self.rings) do
        -- 内边界 (大洞, 半径): hole / inner
        local irx = ((self.hole_w / 2) / ring.inner) * scale
        local iry = ((self.hole_h / 2) / ring.inner) * scale

        if ring.outer then
            -- 外边界 (小洞, 半径): hole / outer
            local orx = ((self.hole_w / 2) / ring.outer) * scale
            local ory = ((self.hole_h / 2) / ring.outer) * scale

            -- stencil: 先画外边界, 再挖掉内边界, 留下环形区域=1
            love.graphics.stencil(function()
                love.graphics.ellipse("fill", cx, cy, orx, ory)
            end, "replace", 1)
            love.graphics.stencil(function()
                love.graphics.ellipse("fill", cx, cy, irx, iry)
            end, "replace", 0, true)
            love.graphics.setStencilTest("equal", 1)
        else
            -- 最外环: 画出大洞(内边界)=1, 椭圆外=0, 区域=0
            love.graphics.stencil(function()
                love.graphics.ellipse("fill", cx, cy, irx, iry)
            end, "replace", 1)
            love.graphics.setStencilTest("equal", 0)
        end

        love.graphics.setColor(0, 0, 0, ring.alpha)
        love.graphics.ellipse("fill", cx, cy, ELLIPSE_RX * scale, ELLIPSE_RY * scale)
        love.graphics.setStencilTest()
    end

    love.graphics.pop()
end

--[[
-- 临时调试
function KrisVignette:initVignetteDebug()
    self.debug_vignette_x = SCREEN_WIDTH / 2
    self.debug_vignette_y = SCREEN_HEIGHT / 2
    self.debug_vignette_scale = 1
    self.debug_vignette_keys = {}
end

function KrisVignette:updateVignetteDebug()
    local mx, my = Input.getCurrentCursorPosition()

    if mx and my then
        self.debug_vignette_x = mx
        self.debug_vignette_y = my
    end

    if self:vignetteDebugPressed("i") then
        self:scaleVignetteDebug(1.08)
    end

    if self:vignetteDebugPressed("o") then
        self:scaleVignetteDebug(1 / 1.08)
    end

    if self:vignetteDebugPressed("p") then
        self:printVignetteDebug()
    end
end

function KrisVignette:getVignetteDebugTransform(cx, cy, scale)
    return self.debug_vignette_x or cx,
        self.debug_vignette_y or cy,
        self.debug_vignette_scale or scale
end

function KrisVignette:vignetteDebugPressed(key)
    local down = love.keyboard.isDown(key)
    local pressed = down and not self.debug_vignette_keys[key]

    self.debug_vignette_keys[key] = down

    return pressed
end

function KrisVignette:scaleVignetteDebug(mult)
    local scale = self.debug_vignette_scale or 1

    scale = scale * mult
    self.debug_vignette_scale = math.max(0.1, math.min(5, scale))
end

function KrisVignette:printVignetteDebug()
    print(string.format(
        "[KrisVignette] x=%.2f y=%.2f scale=%.4f",
        self.debug_vignette_x or SCREEN_WIDTH / 2,
        self.debug_vignette_y or SCREEN_HEIGHT / 2,
        self.debug_vignette_scale or 1
    ))
end
--]]

return KrisVignette
