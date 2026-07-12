---@class FinisherStar : Bullet
local FinisherStar, super = Class(Bullet)

local FADE_DISTANCE = 32
local DEFAULT_MIN_RADIUS = 0
local DEFAULT_TRAVEL_TIME = 1.5
local DEFAULT_ORBIT_SPEED = math.rad(12)

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function FinisherStar:init(x, y, center, angle, radius, min_radius, travel_time, orbit_speed)
    super.init(self, x, y, "bullets/star")

    self.center = center
    self.angle = angle or 0
    self.radius = radius or DEFAULT_MIN_RADIUS
    self.start_radius = self.radius
    self.min_radius = min_radius or DEFAULT_MIN_RADIUS
    self.travel_time = travel_time or DEFAULT_TRAVEL_TIME
    self.orbit_speed = orbit_speed or DEFAULT_ORBIT_SPEED

    self.layer = BATTLE_LAYERS["bullets"] - 1
    self.damage = 50
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self:setScale(1, 1)
end

function FinisherStar:getCenterPosition()
    if not self.center or not self.center.parent or not self.parent then
        return
    end

    return self.center:getRelativePos(
        self.center.width / 2,
        self.center.height / 2,
        self.parent
    )
end

function FinisherStar:update()
    if self.reached_center then
        self:remove()
        return
    end

    self.elapsed = (self.elapsed or 0) + DT

    local center_x, center_y = self:getCenterPosition()
    if not center_x then
        self:remove()
        return
    end

    local progress = self.travel_time > 0
        and clamp(self.elapsed / self.travel_time, 0, 1)
        or 1
    self.radius = self.start_radius - (self.start_radius - self.min_radius) * progress
    self.angle = self.angle + self.orbit_speed * DT
    self.x = center_x + math.cos(self.angle) * self.radius
    self.y = center_y + math.sin(self.angle) * self.radius

    -- Fade during the final approach, but only become fully transparent at the soul's center.
    self.alpha = clamp(self.radius / FADE_DISTANCE, 0, 1)
    self.collidable = self.alpha > 0.05

    if progress >= 1 then
        self.reached_center = true
    end

    super.update(self)
end

return FinisherStar
