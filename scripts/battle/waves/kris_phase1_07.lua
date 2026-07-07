local KrisPhase1_07, super = Class(Wave)

local RECT_DURATION = 20 / 60
local RECT_WIDTH = 24
local RECT_HEIGHT = SCREEN_HEIGHT * 1.4
local RECT_ROTATION = math.rad(5)
local RECT_LAYER = BATTLE_LAYERS["top"] + 1
local ELLIPSE_START_DELAY = 8 / 60
local ELLIPSE_GROW_TIME = 5 / 60
local ELLIPSE_FADE_TIME = 3 / 60
local ELLIPSE_START_WIDTH = 4
local ELLIPSE_TARGET_WIDTH = 16
local ELLIPSE_BORDER_WIDTH = 2

function KrisPhase1_07:init()
    super.init(self)
    self.time = 10
    self.red_rect = nil
    self.black_ellipse_fill = nil
    self.black_ellipse_border = nil
end

function KrisPhase1_07:onStart()
    local rect = Rectangle(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, RECT_WIDTH, RECT_HEIGHT)
    rect:setOrigin(0.5, 0.5)
    rect.color = { 1, 0, 0 }
    rect.alpha = 1
    rect.layer = RECT_LAYER

    self.red_rect = rect
    self:spawnObject(rect)

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

    self.timer:after(ELLIPSE_START_DELAY, function()
        self:spawnBlackEllipse()
    end)
end

function KrisPhase1_07:getArenaHeight()
    local arena = Game.battle and Game.battle.arena
    if arena then
        return arena.height or math.abs((arena:getBottom() or 0) - (arena:getTop() or 0))
    end

    return 142
end

function KrisPhase1_07:getArenaCenter()
    local arena = Game.battle and Game.battle.arena
    if arena then
        return arena:getCenter()
    end

    return SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
end

function KrisPhase1_07:spawnBlackEllipse()
    local start_height = self:getArenaHeight()
    local x, y = self:getArenaCenter()
    local fill = Ellipse(x, y, ELLIPSE_START_WIDTH / 2, start_height / 2)
    local border = Ellipse(x, y, ELLIPSE_START_WIDTH / 2, start_height / 2)

    fill.color = { 0, 0, 0 }
    fill.layer = 1

    border.color = { 1, 1, 1 }
    border.line = true
    border.line_width = ELLIPSE_BORDER_WIDTH
    border.layer = 1.01

    self.black_ellipse_fill = fill
    self.black_ellipse_border = border
    self:addChild(fill)
    self:addChild(border)

    self.timer:tween(ELLIPSE_GROW_TIME, fill, {
        width = ELLIPSE_TARGET_WIDTH,
        height = SCREEN_HEIGHT,
    }, "out-quad", function()
        self:fadeBlackEllipse()
    end)
    self.timer:tween(ELLIPSE_GROW_TIME, border, {
        width = ELLIPSE_TARGET_WIDTH,
        height = SCREEN_HEIGHT,
    }, "out-quad")
end

function KrisPhase1_07:fadeBlackEllipse()
    local fill = self.black_ellipse_fill
    local border = self.black_ellipse_border
    if not fill or not border then
        return
    end

    self.timer:tween(ELLIPSE_FADE_TIME, fill, {
        width = 0,
        alpha = 0,
    }, "in-quad", function()
        if fill.parent then
            fill:remove()
        end
        if border.parent then
            border:remove()
        end
        if self.black_ellipse_fill == fill then
            self.black_ellipse_fill = nil
        end
        if self.black_ellipse_border == border then
            self.black_ellipse_border = nil
        end
    end)
    self.timer:tween(ELLIPSE_FADE_TIME, border, {
        width = 0,
        alpha = 0,
    }, "in-quad")
end

function KrisPhase1_07:update()
    super.update(self)
end

return KrisPhase1_07
