local SoulDepthEcho, super = Class(Object)

local TEXTURE = "bullets/soul/soul_4"
local EXPAND_TIME = 10 / 60
local RETURN_SCALE_TIME = 5 / 60
local START_SCALE = 1
local EXPANDED_SCALE = 2
local UNDER_SOUL_LAYER = -0.5
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
    self.white_start_alpha = self.alpha
    self.expanded = false
    self.white_layer_ready = false
    self.white_fading = false
    self.returning_to_base = false
    self.return_timer = 0
    self.return_start_scale_x = START_SCALE
    self.return_start_scale_y = START_SCALE

    self.sprite = Sprite(TEXTURE)
    self.sprite:setOrigin(0.5, 0.5)
    self.sprite.inherit_color = true
    self:addChild(self.sprite)

    self:setScale(START_SCALE)
end

function SoulDepthEcho:startReturnScale()
    self.expanded = true
    self.returning_to_base = true
    self.return_timer = 0
    self.return_start_scale_x = self.scale_x or START_SCALE
    self.return_start_scale_y = self.scale_y or self.return_start_scale_x
end

function SoulDepthEcho:prepareWhiteLayer()
    if self.white_layer_ready then
        return
    end

    self.expanded = true
    self.white_layer_ready = true
    self:setLayer(OVER_SOUL_LAYER)
    self:setScale(START_SCALE)
end

function SoulDepthEcho:startWhiteFade(delay, duration)
    self:startReturnScale()
    self.white_delay = delay or 0
    self.white_duration = duration or self.white_duration
    self.white_timer = 0
    self.white_start_alpha = self.alpha
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
        self.expanded = true
        self:setScale(EXPANDED_SCALE)
    end
end

function SoulDepthEcho:updateReturnScale()
    if not self.returning_to_base then
        return
    end

    self.return_timer = math.min(self.return_timer + DT, RETURN_SCALE_TIME)
    local progress = RETURN_SCALE_TIME > 0 and clamp(self.return_timer / RETURN_SCALE_TIME, 0, 1) or 1
    self:setScale(
        lerp(self.return_start_scale_x, START_SCALE, progress),
        lerp(self.return_start_scale_y, START_SCALE, progress)
    )

    if progress >= 1 then
        self.returning_to_base = false
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

    if not self.white_layer_ready then
        return
    end

    self.white_timer = math.min(self.white_timer + DT, self.white_duration)
    local progress = self.white_duration > 0 and clamp(self.white_timer / self.white_duration, 0, 1) or 1
    self.alpha = lerp(self.white_start_alpha or 0, 1, progress)
end

function SoulDepthEcho:update()
    self:updateExpand()
    self:updateReturnScale()
    self:updateWhiteFade()

    super.update(self)
end

return SoulDepthEcho
