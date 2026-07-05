local SoulDepthEcho, super = Class(Object)

local TEXTURE = "bullets/soul/soul_4"
local EXPAND_TIME = 10 / 60
local START_SCALE = 1
local EXPANDED_SCALE = 2
local UNDER_SOUL_LAYER = -0.75
local OVER_SOUL_LAYER = 2

local function lerp(from, to, t)
    return from + (to - from) * t
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function SoulDepthEcho:init(alpha)
    super.init(self, 0, 0)

    self.layer = UNDER_SOUL_LAYER
    self.alpha = alpha or 1
    self.expand_timer = 0
    self.white_delay = 0
    self.white_timer = 0
    self.white_duration = 20 / 60
    self.expanded = false
    self.white_fading = false

    self.sprite = Sprite(TEXTURE)
    self.sprite:setOrigin(0.5, 0.5)
    self.sprite.inherit_color = true
    self:addChild(self.sprite)

    self:setScale(START_SCALE)
end

function SoulDepthEcho:prepareWhiteLayer()
    if self.expanded then
        return
    end

    self.expanded = true
    self:setLayer(OVER_SOUL_LAYER)
    self:setScale(START_SCALE)
    self.alpha = 0
end

function SoulDepthEcho:startWhiteFade(delay, duration)
    self:prepareWhiteLayer()
    self.white_delay = delay or 0
    self.white_duration = duration or self.white_duration
    self.white_timer = 0
    self.white_fading = true
end

function SoulDepthEcho:updateExpand()
    if self.expanded then
        return
    end

    self.expand_timer = math.min(self.expand_timer + DT, EXPAND_TIME)
    local progress = EXPAND_TIME > 0 and clamp(self.expand_timer / EXPAND_TIME, 0, 1) or 1
    self:setScale(lerp(START_SCALE, EXPANDED_SCALE, progress))

    if progress >= 1 then
        self:prepareWhiteLayer()
    end
end

function SoulDepthEcho:updateWhiteFade()
    if not self.white_fading then
        return
    end

    if self.white_delay > 0 then
        self.white_delay = math.max(self.white_delay - DT, 0)
        return
    end

    self.white_timer = math.min(self.white_timer + DT, self.white_duration)
    local progress = self.white_duration > 0 and clamp(self.white_timer / self.white_duration, 0, 1) or 1
    self.alpha = progress
end

function SoulDepthEcho:update()
    self:updateExpand()
    self:updateWhiteFade()

    super.update(self)
end

return SoulDepthEcho
