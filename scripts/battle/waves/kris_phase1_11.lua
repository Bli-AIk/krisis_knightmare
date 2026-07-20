local KrisPhase1_11, super = Class("kris_phase1_01")

local DEPTH_MASK_DIAMETER_SCALE = 1.25
local STAR_BURST_INTERVAL = 1.0
local STAR_BURST_COUNT = 6
local STAR_ANGLE_STEP = math.rad(60)
local STAR_BURST_ANGLE_OFFSET = math.rad(15)
local STAR_TRAVEL_SPEED = 48
local STAR_START_SCALE = 0.9
local STAR_END_SCALE = 0.2
local FixedInvertStarBursts, fixed_super = Class(Object)

function FixedInvertStarBursts:init(depth_mask)
    fixed_super.init(self, 0, 0)

    self.depth_mask = depth_mask
    self.burst_timer = STAR_BURST_INTERVAL
    self.burst_index = 0
end

function FixedInvertStarBursts:spawnBurst()
    local depth_mask = self.depth_mask
    if not depth_mask or not depth_mask.parent or not depth_mask.wave or not depth_mask.star_bursts_enabled then
        return
    end

    local parent = depth_mask.parent
    local center_x, center_y = depth_mask:getCenterInSoul()
    local base_angle = self.burst_index * STAR_BURST_ANGLE_OFFSET
    local spawn_distance = depth_mask.radius
    local travel_time = math.max(
        spawn_distance / STAR_TRAVEL_SPEED * depth_mask.star_travel_time_scale,
        1 / 60
    )

    for i = 0, STAR_BURST_COUNT - 1 do
        local angle = base_angle + i * STAR_ANGLE_STEP
        local start_x = center_x + math.cos(angle) * spawn_distance
        local start_y = center_y + math.sin(angle) * spawn_distance

        depth_mask:spawnStarIndicatorParticle(angle, {
            alpha = 0.25,
            blend_mode = "alpha",
            color = { 0, 0, 0 },
        })

        depth_mask.wave:spawnBulletTo(
            parent,
            "soul_depth_star",
            start_x,
            start_y,
            center_x,
            center_y,
            travel_time,
            STAR_START_SCALE,
            STAR_END_SCALE,
            {
                texture = "bullets/star_invert",
                collision_delay = depth_mask.star_collision_delay,
            }
        )
    end

    self.burst_index = self.burst_index + 1
end

function FixedInvertStarBursts:update()
    local depth_mask = self.depth_mask
    if not depth_mask or not depth_mask.parent then
        self:remove()
        return
    end

    if not depth_mask.star_bursts_enabled then
        fixed_super.update(self)
        return
    end

    self.burst_timer = self.burst_timer - DT
    while self.burst_timer <= 0 do
        self:spawnBurst()
        self.burst_timer = self.burst_timer + STAR_BURST_INTERVAL
    end

    fixed_super.update(self)
end

function KrisPhase1_11:spawnSoulDepthMask()
    local soul = self.chaser_soul
    if not soul or not soul.parent then
        return
    end

    local arena_height = self:getArenaHeight()
    local start_diameter = arena_height * 0.5
    local target_diameter = arena_height * DEPTH_MASK_DIAMETER_SCALE
    local depth_mask = SoulDepthMask(start_diameter, target_diameter, self:getSoulDepthMaskOptions({
        star_burst_min_count = 1,
        star_burst_max_count = 2,
        finale_options = {
            star_wave_count = 6,
            star_wave_interval = 5 / 60 * 2,
            star_min_count = 8,
            star_max_count = 16,
        },
    }))

    self.depth_mask = self:spawnObjectTo(soul, depth_mask, soul.width / 2, soul.height / 2)
    self.fixed_invert_star_bursts = self:spawnObjectTo(
        soul,
        FixedInvertStarBursts(depth_mask),
        soul.width / 2,
        soul.height / 2
    )

    if self.depth_mask_finished and self.depth_mask.beginWhiteFade then
        self.depth_mask:beginWhiteFade()
    end
end

return KrisPhase1_11
