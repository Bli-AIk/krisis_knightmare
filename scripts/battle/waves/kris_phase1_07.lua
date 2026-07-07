local KrisPhase1_07, super = Class(Wave)

local RECT_DURATION = 20 / 60
local RECT_WIDTH = 24
local RECT_HEIGHT = SCREEN_HEIGHT * 1.4
local RECT_ROTATION = math.rad(5)

function KrisPhase1_07:init()
    super.init(self)
    self.time = 10
    self.red_rect = nil
end

function KrisPhase1_07:onStart()
    local rect = Rectangle(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, RECT_WIDTH, RECT_HEIGHT)
    rect:setOrigin(0.5, 0.5)
    rect.color = { 1, 0, 0 }
    rect.alpha = 1

    self.red_rect = rect
    self:addChild(rect)

    self.timer:tween(RECT_DURATION, rect, {
        rotation = RECT_ROTATION,
        alpha = 0,
    }, "linear", function()
        if rect.parent then
            rect:remove()
        end
        if self.red_rect == rect then
            self.red_rect = nil
        end
    end)
end

function KrisPhase1_07:update()
    super.update(self)
end

return KrisPhase1_07
