---@class KrisBusterDiamond : Bullet
local KrisBusterDiamond, super = Class(Bullet)

local END_SPEED_FACTOR = 0.82
local MIN_SPEED = 4
local DIAMOND_FRAME_DURATION = 2 / 30
local DIAMOND_OPAQUE_RECTS = {
    {
        { 10, 2, 2, 2 },
        { 8, 4, 6, 4 },
        { 6, 8, 10, 4 },
        { 4, 12, 14, 4 },
        { 2, 16, 18, 4 },
        { 4, 20, 14, 4 },
        { 6, 24, 10, 4 },
        { 8, 28, 6, 4 },
        { 10, 32, 2, 2 },
    },
    {
        { 10, 2, 2, 4 },
        { 8, 6, 6, 4 },
        { 8, 10, 8, 4 },
        { 6, 14, 10, 8 },
        { 6, 22, 8, 6 },
        { 8, 28, 6, 4 },
        { 10, 32, 2, 2 },
    },
    {
        { 10, 2, 2, 2 },
        { 10, 4, 4, 2 },
        { 8, 6, 6, 8 },
        { 8, 14, 8, 8 },
        { 8, 22, 6, 10 },
        { 10, 32, 2, 2 },
    },
    {
        { 11, 2, 2, 10 },
        { 10, 12, 2, 12 },
        { 9, 24, 2, 10 },
    },
    {
        { 10, 2, 2, 2 },
        { 8, 4, 4, 2 },
        { 8, 6, 6, 8 },
        { 6, 14, 8, 8 },
        { 8, 22, 6, 10 },
        { 10, 32, 2, 2 },
    },
    {
        { 10, 2, 2, 4 },
        { 8, 6, 6, 4 },
        { 8, 10, 8, 4 },
        { 6, 14, 10, 8 },
        { 6, 22, 8, 6 },
        { 8, 28, 6, 4 },
        { 10, 32, 2, 2 },
    },
}

local function easeInCubic(t)
    return t * t * t
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function KrisBusterDiamond:updateHitboxForFrame()
    if not self.use_frame_hitbox then
        return
    end

    local frame = self.sprite and self.sprite.frame or 1
    if self.hitbox_frame == frame then
        return
    end

    local collider = self.frame_colliders[frame]
    if not collider then
        local hitboxes = {}
        for _, rect in ipairs(DIAMOND_OPAQUE_RECTS[frame] or DIAMOND_OPAQUE_RECTS[1]) do
            table.insert(hitboxes, Hitbox(self, unpack(rect)))
        end
        collider = ColliderGroup(self, hitboxes)
        self.frame_colliders[frame] = collider
    end

    self.collider = collider
    self.hitbox_frame = frame
end

function KrisBusterDiamond:init(x, y, direction, options)
    super.init(self, x, y, "bullets/buster/diamond")

    options = options or {}

    self.damage = 75
    self.destroy_on_hit = false
    self.remove_offscreen = true
    self.physics.direction = direction or 0
    self.physics.speed = 0

    self.start_speed = options.speed or 6
    self.end_speed = math.max(self.start_speed * END_SPEED_FACTOR, MIN_SPEED)
    self.easing = options.easing or "linear"
    self.decel_duration = options.accel_duration or 1.0
    self.elapsed = 0
    self.frame_colliders = {}

    self:setScale(1, 1)
    self.sprite:play(DIAMOND_FRAME_DURATION, true)
    self.rotation = (direction or 0) + math.pi / 2
    self:setHitbox(4, 6, self.width - 8, self.height - 12)
end

function KrisBusterDiamond:onWaveSpawn(wave)
    super.onWaveSpawn(self, wave)

    self.use_frame_hitbox = wave.precise_buster_hitboxes == true
    self:updateHitboxForFrame()
end

function KrisBusterDiamond:update()
    self.elapsed = self.elapsed + DT

    local raw_t = self.decel_duration > 0 and clamp(self.elapsed / self.decel_duration, 0, 1) or 1
    local t = self.easing == "in-cubic" and easeInCubic(raw_t) or raw_t
    self.physics.speed = self.start_speed + (self.end_speed - self.start_speed) * t

    self.rotation = self.physics.direction + math.pi / 2

    super.update(self)
    self:updateHitboxForFrame()
end

return KrisBusterDiamond
