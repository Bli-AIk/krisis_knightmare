local RechargeWhiteFlash, super = Class(Object)

local HOLD_TIME = 0.12
local FADE_TIME = 0.18

function RechargeWhiteFlash:init(battler, options)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    options = options or {}

    self.time = 0
    self.hold_time = options.hold_time or HOLD_TIME
    self.fade_time = options.fade_time or FADE_TIME
    self.layer = options.layer or (BATTLE_LAYERS["top"] - 5)
    self.alpha = 1

    self.battler = battler
    self.old_battler_layer = battler and battler.layer
    self.elevated_battler_layer = self.layer + 1

    if battler then
        battler.layer = self.elevated_battler_layer
    end
end

function RechargeWhiteFlash:restoreBattlerLayer()
    local battler = self.battler
    if battler and battler.layer == self.elevated_battler_layer then
        battler.layer = self.old_battler_layer
    end
    self.battler = nil
end

function RechargeWhiteFlash:update()
    super.update(self)

    self.time = self.time + DT

    if self.time > self.hold_time then
        local fade = (self.time - self.hold_time) / self.fade_time
        self.alpha = 1 - MathUtils.clamp(fade, 0, 1)
    end

    if self.alpha <= 0 then
        self:restoreBattlerLayer()
        self:remove()
    end
end

function RechargeWhiteFlash:onRemove(parent)
    self:restoreBattlerLayer()
    super.onRemove(self, parent)
end

function RechargeWhiteFlash:draw()
    Draw.setColor(1, 1, 1, self.alpha)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
end

return RechargeWhiteFlash
