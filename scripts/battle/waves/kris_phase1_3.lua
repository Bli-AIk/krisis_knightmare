local KrisPhase1_3, super = Class(Wave)

local FPS = 30
local WAVE_SECONDS = 6
local EXTRA_FRAMES = 50
local WAVE_FRAMES = WAVE_SECONDS * FPS + EXTRA_FRAMES
local SPAWN_INTERVAL_FRAMES = 5
local ARENA_Y_MARGIN = 20
local SPAWN_RIGHT_OFFSET = 50
local SAFE_CURVE_PADDING = 16
local SAFE_CURVE_WALL_PADDING = 18
local SAFE_CURVE_LOOKAHEAD_FRAMES = 30
local SAFE_CURVE_AMPLITUDE = 0.68
local SHARP_SWORD_HEIGHT = 33
local EDGE_PLACEMENT_CHANCE = 0.58
local CURVE_BLOCKER_CHANCE = 0.34
local EDGE_BAND_DEPTH = 28
local FLOAT_BAND_RATIO = 0.38
local PAIR_SPAWN_INTERVAL = 11
local PAIR_SPAWN_PHASE = 6
local PAIR_GAP_RATIO = 0.44
local PAIR_GAP_MIN = 72
local PAIR_GAP_MAX = 84
local PAIR_GAP_WOBBLE = 8
local CENTER_BLOCK_DEADZONE = 12
local CURVE_BLOCKER_BAND_DEPTH = 10
local SHOW_SAFE_CURVE = true
local SAFE_CURVE_DRAW_STEPS = 72
local SAFE_CURVE_DRAW_WINDOW_FRAMES = 120
local SIDE_PATTERN = { "top", "bottom" }

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function deterministicNoise(index, salt)
    local value = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453
    return value - math.floor(value)
end

function KrisPhase1_3:init()
    super.init(self)
    self.time = WAVE_FRAMES / FPS
    self.wave_frame = 0
end

function KrisPhase1_3:getSpawnBounds()
    local arena = Game.battle.arena

    return arena.top - ARENA_Y_MARGIN, arena.bottom + ARENA_Y_MARGIN
end

function KrisPhase1_3:getSafeCurveY(frame)
    local arena = Game.battle.arena
    local arena_center_y = (arena.top + arena.bottom) / 2
    local arena_half_height = (arena.bottom - arena.top) / 2
    local amplitude = arena_half_height * SAFE_CURVE_AMPLITUDE
    local t = frame / WAVE_FRAMES
    local wave = math.sin(t * math.pi * 2 * 2.15 - math.pi / 2) * 0.82
        + math.sin(t * math.pi * 2 * 4.3 + 0.6) * 0.18
    wave = clamp(wave, -1, 1)

    return clamp(
        arena_center_y + amplitude * wave,
        arena.top + SAFE_CURVE_WALL_PADDING,
        arena.bottom - SAFE_CURVE_WALL_PADDING
    )
end

function KrisPhase1_3:getSafeCurvePadding()
    local arena = Game.battle.arena
    local arena_height = arena.bottom - arena.top

    return clamp((arena_height - SHARP_SWORD_HEIGHT * 2) / 4, 8, SAFE_CURVE_PADDING)
end

function KrisPhase1_3:overlapsSafeCurve(y, scale_y, curve_y)
    local padding = self:getSafeCurvePadding()
    local half_height = SHARP_SWORD_HEIGHT * scale_y / 2
    return math.abs(y - curve_y) < half_height + padding
end

function KrisPhase1_3:getPreferredSide(spawn_index)
    return SIDE_PATTERN[((spawn_index - 1) % #SIDE_PATTERN) + 1]
end

function KrisPhase1_3:getEdgeAnchoredY(scale_y, side)
    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local half_height = SHARP_SWORD_HEIGHT * scale_y / 2

    if side == "top" then
        return spawn_top + half_height
    end

    return spawn_bottom - half_height
end

function KrisPhase1_3:getEdgeBandY(spawn_index, side)
    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local salt = side == "top" and 9 or 10
    local offset = deterministicNoise(spawn_index * 17, salt) * EDGE_BAND_DEPTH

    if side == "top" then
        return spawn_top + offset
    end

    return spawn_bottom - offset
end

function KrisPhase1_3:tryEdgePlacement(spawn_index, curve_y, preferred_side)
    preferred_side = preferred_side or self:getPreferredSide(spawn_index)
    local side = preferred_side

    for attempt = 0, 7 do
        local seed = spawn_index * 7 + attempt * 19 + (side == "top" and 0 or 1)
        local scale_y = 1 + 2 * deterministicNoise(seed, 4)
        local y = self:getEdgeBandY(seed, side)

        if not self:overlapsSafeCurve(y, scale_y, curve_y) then
            return y, scale_y
        end
    end
end

function KrisPhase1_3:tryFloatingPlacement(spawn_index, curve_y, preferred_side)
    local arena = Game.battle.arena
    local arena_center_y = (arena.top + arena.bottom) / 2
    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local spawn_height = spawn_bottom - spawn_top
    local band_depth = spawn_height * FLOAT_BAND_RATIO
    local padding = self:getSafeCurvePadding()

    for attempt = 0, 23 do
        local seed = spawn_index * 31 + attempt
        local scale_y = 1 + 2 * deterministicNoise(seed, 2)
        local max_y
        local min_y

        if preferred_side == "top" then
            max_y = math.min(spawn_top + band_depth, arena_center_y - padding)
            min_y = spawn_top
        else
            min_y = math.max(spawn_bottom - band_depth, arena_center_y + padding)
            max_y = spawn_bottom
        end

        if min_y > max_y then
            min_y = spawn_top
            max_y = spawn_bottom
            scale_y = 1
        end

        local y = min_y + (max_y - min_y) * deterministicNoise(seed, 1)

        if not self:overlapsSafeCurve(y, scale_y, curve_y) then
            return y, scale_y
        end
    end
end

function KrisPhase1_3:getCenterBlockingSide(curve_y, preferred_side)
    local arena = Game.battle.arena
    local arena_center_y = (arena.top + arena.bottom) / 2

    if curve_y < arena_center_y - CENTER_BLOCK_DEADZONE then
        return "bottom"
    elseif curve_y > arena_center_y + CENTER_BLOCK_DEADZONE then
        return "top"
    end

    return preferred_side
end

function KrisPhase1_3:tryCurveBlockerPlacement(spawn_index, curve_y, preferred_side)
    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local side = self:getCenterBlockingSide(curve_y, preferred_side)
    local padding = self:getSafeCurvePadding()

    for attempt = 0, 15 do
        local seed = spawn_index * 43 + attempt
        local scale_y = 1 + 2 * deterministicNoise(seed, 12)
        local half_height = SHARP_SWORD_HEIGHT * scale_y / 2
        local offset = padding + half_height + deterministicNoise(seed, 13) * CURVE_BLOCKER_BAND_DEPTH
        local y

        if side == "top" then
            y = curve_y - offset
        else
            y = curve_y + offset
        end

        if y >= spawn_top and y <= spawn_bottom and not self:overlapsSafeCurve(y, scale_y, curve_y) then
            return y, scale_y
        end
    end

    return self:tryFloatingPlacement(spawn_index, curve_y, side)
end

function KrisPhase1_3:getPairPlacement(spawn_frame, spawn_index)
    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local spawn_height = spawn_bottom - spawn_top
    local gap_size = clamp(spawn_height * PAIR_GAP_RATIO, PAIR_GAP_MIN, PAIR_GAP_MAX)
    local min_gap_center = spawn_top + SHARP_SWORD_HEIGHT + gap_size / 2
    local max_gap_center = spawn_bottom - SHARP_SWORD_HEIGHT - gap_size / 2

    if min_gap_center > max_gap_center then
        gap_size = math.max(20, spawn_height - SHARP_SWORD_HEIGHT * 2)
        min_gap_center = (spawn_top + spawn_bottom) / 2
        max_gap_center = min_gap_center
    end

    local curve_y = self:getSafeCurveY(spawn_frame + SAFE_CURVE_LOOKAHEAD_FRAMES)
    local gap_center = curve_y + (deterministicNoise(spawn_index, 8) - 0.5) * PAIR_GAP_WOBBLE
    gap_center = clamp(gap_center, min_gap_center, max_gap_center)

    local top_length = gap_center - gap_size / 2 - spawn_top
    local bottom_length = spawn_bottom - (gap_center + gap_size / 2)
    local top_scale_y = clamp(top_length / SHARP_SWORD_HEIGHT, 1, 3)
    local bottom_scale_y = clamp(bottom_length / SHARP_SWORD_HEIGHT, 1, 3)

    return {
        top_y = self:getEdgeAnchoredY(top_scale_y, "top"),
        top_scale_y = top_scale_y,
        bottom_y = self:getEdgeAnchoredY(bottom_scale_y, "bottom"),
        bottom_scale_y = bottom_scale_y,
    }
end

function KrisPhase1_3:shouldSpawnPair(spawn_index)
    return spawn_index % PAIR_SPAWN_INTERVAL == PAIR_SPAWN_PHASE
end

function KrisPhase1_3:getSharpSwordPlacement(spawn_frame, spawn_index)
    local min_y, max_y = self:getSpawnBounds()
    local curve_y = self:getSafeCurveY(spawn_frame + SAFE_CURVE_LOOKAHEAD_FRAMES)
    local placement_roll = deterministicNoise(spawn_index, 6)
    local preferred_side = self:getPreferredSide(spawn_index)
    local fallback_side = preferred_side == "top" and "bottom" or "top"

    local y, scale_y
    if placement_roll < EDGE_PLACEMENT_CHANCE then
        y, scale_y = self:tryEdgePlacement(spawn_index, curve_y, preferred_side)
        if y then
            return y, scale_y
        end

        y, scale_y = self:tryFloatingPlacement(spawn_index, curve_y, preferred_side)
        if y then
            return y, scale_y
        end

        y, scale_y = self:tryEdgePlacement(spawn_index, curve_y, fallback_side)
        if y then
            return y, scale_y
        end

        y, scale_y = self:tryFloatingPlacement(spawn_index, curve_y, fallback_side)
        if y then
            return y, scale_y
        end
    elseif placement_roll < EDGE_PLACEMENT_CHANCE + CURVE_BLOCKER_CHANCE then
        y, scale_y = self:tryCurveBlockerPlacement(spawn_index, curve_y, preferred_side)
        if y then
            return y, scale_y
        end

        y, scale_y = self:tryEdgePlacement(spawn_index, curve_y, preferred_side)
        if y then
            return y, scale_y
        end

        y, scale_y = self:tryFloatingPlacement(spawn_index, curve_y, fallback_side)
        if y then
            return y, scale_y
        end
    else
        y, scale_y = self:tryFloatingPlacement(spawn_index, curve_y, preferred_side)
        if y then
            return y, scale_y
        end

        y, scale_y = self:tryEdgePlacement(spawn_index, curve_y, preferred_side)
        if y then
            return y, scale_y
        end

        y, scale_y = self:tryFloatingPlacement(spawn_index, curve_y, fallback_side)
        if y then
            return y, scale_y
        end

        y, scale_y = self:tryEdgePlacement(spawn_index, curve_y, fallback_side)
        if y then
            return y, scale_y
        end
    end

    local scale_y = 1
    local y = curve_y < (min_y + max_y) / 2
        and self:getEdgeBandY(spawn_index, "bottom")
        or self:getEdgeBandY(spawn_index, "top")

    return y, scale_y
end

function KrisPhase1_3:spawnSharpSwordAt(y, scale_y)
    local arena = Game.battle.arena
    local arena_center_y = (arena.top + arena.bottom) / 2
    local flip_y = y < arena_center_y

    self:spawnBullet("small_sword_sharp", SCREEN_WIDTH - SPAWN_RIGHT_OFFSET, y, scale_y, flip_y)
end

function KrisPhase1_3:spawnSharpSwordPair(spawn_frame, spawn_index)
    local placement = self:getPairPlacement(spawn_frame, spawn_index)

    self:spawnBullet("small_sword_sharp", SCREEN_WIDTH - SPAWN_RIGHT_OFFSET, placement.top_y, placement.top_scale_y, true)
    self:spawnBullet("small_sword_sharp", SCREEN_WIDTH - SPAWN_RIGHT_OFFSET, placement.bottom_y, placement.bottom_scale_y, false)
end

function KrisPhase1_3:spawnSharpSword(spawn_frame, spawn_index)
    local y, scale_y = self:getSharpSwordPlacement(spawn_frame, spawn_index)

    self:spawnSharpSwordAt(y, scale_y)
end

function KrisPhase1_3:onStart()
    self.wave_frame = 0

    local spawn_count = math.floor((WAVE_FRAMES - 1) / SPAWN_INTERVAL_FRAMES) + 1
    for i = 0, spawn_count - 1 do
        local spawn_frame = i * SPAWN_INTERVAL_FRAMES
        local delay = spawn_frame / FPS
        self.timer:after(delay, function()
            local spawn_index = i + 1
            if self:shouldSpawnPair(spawn_index) then
                self:spawnSharpSwordPair(spawn_frame, spawn_index)
            else
                self:spawnSharpSword(spawn_frame, spawn_index)
            end
        end)
    end
end

function KrisPhase1_3:update()
    self.wave_frame = math.min((self.wave_frame or 0) + DTMULT, WAVE_FRAMES)
    super.update(self)
end

function KrisPhase1_3:drawSafeCurve()
    local arena = Game.battle.arena
    if not arena then
        return
    end

    local padding = self:getSafeCurvePadding()
    local old_width = love.graphics.getLineWidth()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    local function buildPoints(y_offset)
        local points = {}
        for i = 0, SAFE_CURVE_DRAW_STEPS do
            local progress = i / SAFE_CURVE_DRAW_STEPS
            local frame = (self.wave_frame or 0) + (progress - 0.5) * SAFE_CURVE_DRAW_WINDOW_FRAMES
            local x = arena.left + (arena.right - arena.left) * progress
            local y = self:getSafeCurveY(frame) + y_offset
            table.insert(points, x)
            table.insert(points, y)
        end
        return points
    end

    love.graphics.setLineWidth(1)
    Draw.setColor(0, 1, 1, 0.25)
    love.graphics.line(buildPoints(-padding))
    love.graphics.line(buildPoints(padding))

    love.graphics.setLineWidth(2)
    Draw.setColor(0, 1, 1, 0.9)
    love.graphics.line(buildPoints(0))

    love.graphics.setLineWidth(old_width)
    Draw.setColor(old_r, old_g, old_b, old_a)
end

function KrisPhase1_3:draw()
    super.draw(self)

    if SHOW_SAFE_CURVE then
        self:drawSafeCurve()
    end
end

return KrisPhase1_3
