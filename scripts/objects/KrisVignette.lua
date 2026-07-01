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

local KrisVignette, super = Class(Object)

function KrisVignette:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.time = 0
    self.period = 4

    -- 三个环形区域, 从中心向外, 互不重叠
    -- 每层: { alpha, 内边界(大洞), 外边界(小洞) }
    self.rings = {
        { alpha = 0.39, inner = 1.29, outer = 1.16 }, -- 最内环
        { alpha = 0.77, inner = 1.16, outer = 1.0  }, -- 中环
        { alpha = 1.00, inner = 1.0,  outer = nil }, -- 最外环 (outer=nil → 椭圆边缘)
    }

    self.hole_w = HOLE_MIN_X * REF_SCALE
    self.hole_h = HOLE_MIN_Y * REF_SCALE
end

function KrisVignette:update()
    super.update(self)
    self.time = self.time + DT

    local t = (self.time % self.period) / self.period
    local f = (math.sin(t * 2 * math.pi) + 1) / 2

    self.hole_w = (HOLE_MIN_X + (HOLE_MAX_X - HOLE_MIN_X) * f) * REF_SCALE
    self.hole_h = (HOLE_MIN_Y + (HOLE_MAX_Y - HOLE_MIN_Y) * f) * REF_SCALE
end

function KrisVignette:draw()
    love.graphics.push()
    love.graphics.origin()

    local cx = SCREEN_WIDTH / 2
    local cy = SCREEN_HEIGHT / 2

    for _, ring in ipairs(self.rings) do
        -- 内边界 (大洞, 半径): hole / inner
        local irx = (self.hole_w / 2) / ring.inner
        local iry = (self.hole_h / 2) / ring.inner

        if ring.outer then
            -- 外边界 (小洞, 半径): hole / outer
            local orx = (self.hole_w / 2) / ring.outer
            local ory = (self.hole_h / 2) / ring.outer

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
        love.graphics.ellipse("fill", cx, cy, ELLIPSE_RX, ELLIPSE_RY)
        love.graphics.setStencilTest()
    end

    love.graphics.pop()
end

return KrisVignette
