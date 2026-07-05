local SoulDepthStar, super = Class(Bullet)

local DAMAGE = 50
local INV_TIMER = 4 / 60
local START_SCALE = 0.9
local END_SCALE = 0.2
local FADE_IN_END = 0.3
local FADE_OUT_START = 0.52
local SPIN_SPEED = math.rad(180)

local function lerp(from, to, t)
    return from + (to - from) * t
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function SoulDepthStar:init(x, y, target_x, target_y, duration, start_scale, end_scale)
    super.init(self, x, y, "bullets/star")

    self.layer = -0.5
    self.damage = DAMAGE
    self.inv_timer = INV_TIMER
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.alpha = 0

    self.start_x = x
    self.start_y = y
    self.target_x = target_x
    self.target_y = target_y
    self.duration = duration or 1
    self.elapsed = 0
    self.start_scale = start_scale or START_SCALE
    self.end_scale = end_scale or END_SCALE

    self:setScale(self.start_scale)
end

function SoulDepthStar:update()
    self.elapsed = self.elapsed + DT
    local progress = clamp(self.elapsed / self.duration, 0, 1)

    self.x = lerp(self.start_x, self.target_x, progress)
    self.y = lerp(self.start_y, self.target_y, progress)
    self.rotation = self.rotation + SPIN_SPEED * DT
    self:setScale(lerp(self.start_scale, self.end_scale, progress))

    local fade_in = clamp(progress / FADE_IN_END, 0, 1)
    local fade_out = clamp((1 - progress) / (1 - FADE_OUT_START), 0, 1)
    self.alpha = math.min(fade_in, fade_out)

    if progress >= 1 then
        self:remove()
        return
    end

    super.update(self)
end

return SoulDepthStar
