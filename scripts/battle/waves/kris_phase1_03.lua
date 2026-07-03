local KrisPhase1_03, super = Class(Wave)

local FPS = 30
local WAVE_SECONDS = 6
local EXTRA_FRAMES = 50
local WAVE_FRAMES = WAVE_SECONDS * FPS + EXTRA_FRAMES
local SPAWN_INTERVAL_FRAMES = 5
local TOTAL_SHARP_SWORDS = 27
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
local PAIR_SPAWN_MAX_COUNT = 2
local PAIR_GAP_RATIO = 0.44
local PAIR_GAP_MIN = 72
local PAIR_GAP_MAX = 84
local PAIR_GAP_WOBBLE = 8
local CENTER_BLOCK_DEADZONE = 12
local CURVE_BLOCKER_BAND_DEPTH = 10
local DENSITY_HISTORY_FRAMES = 30
local DENSITY_Y_RADIUS = 54
local DENSITY_GLOBAL_WEIGHT = 0.08
local DENSITY_SCALE_STEP = 0.28
local DENSITY_MIN_SCALE = 1
local SHARP_SWORD_MIN_SPEED = 4
local SHARP_SWORD_MAX_SPEED = 16
local SHARP_SWORD_ACCEL_DURATION = 0.75

local SHOW_SAFE_CURVE = false

local SAFE_CURVE_DRAW_STEPS = 72
local SAFE_CURVE_DRAW_WINDOW_FRAMES = 120
local SIDE_PATTERN = { "top", "bottom" }

local KRIS_FAR_X = 10000
local KRIS_FAR_Y = 10000
local KRIS_SWORD_HALL_FRAME_FRAMES = 4
local KRIS_SWORD_HALL_BULLET_START_FRAME = 6
local KRIS_SWORD_HALL_BULLET_START_WAVE_FRAME =
    (KRIS_SWORD_HALL_BULLET_START_FRAME - 1) * KRIS_SWORD_HALL_FRAME_FRAMES

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function deterministicNoise(index, salt)
    local value = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453
    return value - math.floor(value)
end

local function moveAttackerTo(attacker, x, y)
    attacker.target_x = x
    attacker.target_y = y
    attacker:setPosition(attacker.target_x, attacker.target_y)
end

local function moveAttackerAway(attacker)
    moveAttackerTo(attacker, KRIS_FAR_X, KRIS_FAR_Y)
end

local function playSwordHallDisappear(attacker, on_bullet_start, on_finished)
    attacker:setAnimation({
        "sword_hall_disappear",
        function(sprite, wait)
            local frame_count = sprite.frames and #sprite.frames or 0
            for frame = 1, frame_count do
                sprite:setFrame(frame)

                if frame == KRIS_SWORD_HALL_BULLET_START_FRAME and on_bullet_start then
                    on_bullet_start()
                    on_bullet_start = nil
                end

                wait(KRIS_SWORD_HALL_FRAME_FRAMES / FPS)
            end

            if on_bullet_start then
                on_bullet_start()
            end
        end,
        next = "idle",
    }, on_finished)
end

function KrisPhase1_03:init()
    super.init(self)
    self.time = WAVE_FRAMES / FPS
    self.wave_frame = 0
    self.recent_sharp_swords = {}
    self.pattern_seed = 0
    self.sharp_sword_started = false
end

function KrisPhase1_03:getSpawnBounds()
    local arena = Game.battle.arena

    return arena.top - ARENA_Y_MARGIN, arena.bottom + ARENA_Y_MARGIN
end

function KrisPhase1_03:getSafeCurveY(frame)
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

function KrisPhase1_03:getSafeCurvePadding()
    local arena = Game.battle.arena
    local arena_height = arena.bottom - arena.top

    return clamp((arena_height - SHARP_SWORD_HEIGHT * 2) / 4, 8, SAFE_CURVE_PADDING)
end

function KrisPhase1_03:overlapsSafeCurve(y, scale_y, curve_y)
    local padding = self:getSafeCurvePadding()
    local half_height = SHARP_SWORD_HEIGHT * scale_y / 2
    return math.abs(y - curve_y) < half_height + padding
end

function KrisPhase1_03:getRecentSwordPressure(spawn_frame, y)
    if not self.recent_sharp_swords then
        return 0
    end

    local pressure = 0
    for _, sword in ipairs(self.recent_sharp_swords) do
        local age = spawn_frame - sword.frame

        if age > 0 and age <= DENSITY_HISTORY_FRAMES then
            local age_weight = 1 - age / DENSITY_HISTORY_FRAMES
            local distance = math.abs(y - sword.y)
            local reach = DENSITY_Y_RADIUS + SHARP_SWORD_HEIGHT * sword.scale_y / 2
            local local_weight = 0

            if distance < reach then
                local_weight = 1 - distance / reach
            end

            pressure = pressure
                + age_weight
                * (DENSITY_GLOBAL_WEIGHT + local_weight * (0.7 + sword.scale_y * 0.25))
        end
    end

    return pressure
end

function KrisPhase1_03:applyDensityScale(spawn_frame, y, scale_y)
    local pressure = self:getRecentSwordPressure(spawn_frame, y)

    if pressure <= 0 then
        return scale_y
    end

    return clamp(scale_y - pressure * DENSITY_SCALE_STEP, DENSITY_MIN_SCALE, scale_y)
end

function KrisPhase1_03:rememberSharpSword(spawn_frame, y, scale_y)
    self.recent_sharp_swords = self.recent_sharp_swords or {}

    table.insert(self.recent_sharp_swords, {
        frame = spawn_frame,
        y = y,
        scale_y = scale_y,
    })

    while #self.recent_sharp_swords > 0
        and spawn_frame - self.recent_sharp_swords[1].frame > DENSITY_HISTORY_FRAMES do
        table.remove(self.recent_sharp_swords, 1)
    end
end

function KrisPhase1_03:rollPatternSeed()
    if Mod and Mod.nextKrisisRandomSeed then
        return Mod:nextKrisisRandomSeed("kris_phase1_03")
    end

    return os.time()
end

function KrisPhase1_03:noise(index, salt)
    local seed = self.pattern_seed or 0

    return deterministicNoise(index + seed * 0.013, salt + seed * 0.017)
end

function KrisPhase1_03:getPreferredSide(spawn_index)
    local side_offset = self:noise(1, 31) < 0.5 and 0 or 1

    return SIDE_PATTERN[((spawn_index - 1 + side_offset) % #SIDE_PATTERN) + 1]
end

function KrisPhase1_03:getEdgeAnchoredY(scale_y, side)
    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local half_height = SHARP_SWORD_HEIGHT * scale_y / 2

    if side == "top" then
        return spawn_top + half_height
    end

    return spawn_bottom - half_height
end

function KrisPhase1_03:getEdgeBandY(spawn_index, side)
    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local salt = side == "top" and 9 or 10
    local offset = self:noise(spawn_index * 17, salt) * EDGE_BAND_DEPTH

    if side == "top" then
        return spawn_top + offset
    end

    return spawn_bottom - offset
end

function KrisPhase1_03:tryEdgePlacement(spawn_index, curve_y, preferred_side)
    preferred_side = preferred_side or self:getPreferredSide(spawn_index)
    local side = preferred_side

    for attempt = 0, 7 do
        local seed = spawn_index * 7 + attempt * 19 + (side == "top" and 0 or 1)
        local scale_y = 1 + 2 * self:noise(seed, 4)
        local y = self:getEdgeBandY(seed, side)

        if not self:overlapsSafeCurve(y, scale_y, curve_y) then
            return y, scale_y
        end
    end
end

function KrisPhase1_03:tryFloatingPlacement(spawn_index, curve_y, preferred_side)
    local arena = Game.battle.arena
    local arena_center_y = (arena.top + arena.bottom) / 2
    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local spawn_height = spawn_bottom - spawn_top
    local band_depth = spawn_height * FLOAT_BAND_RATIO
    local padding = self:getSafeCurvePadding()

    for attempt = 0, 23 do
        local seed = spawn_index * 31 + attempt
        local scale_y = 1 + 2 * self:noise(seed, 2)
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

        local y = min_y + (max_y - min_y) * self:noise(seed, 1)

        if not self:overlapsSafeCurve(y, scale_y, curve_y) then
            return y, scale_y
        end
    end
end

function KrisPhase1_03:getCenterBlockingSide(curve_y, preferred_side)
    local arena = Game.battle.arena
    local arena_center_y = (arena.top + arena.bottom) / 2

    if curve_y < arena_center_y - CENTER_BLOCK_DEADZONE then
        return "bottom"
    elseif curve_y > arena_center_y + CENTER_BLOCK_DEADZONE then
        return "top"
    end

    return preferred_side
end

function KrisPhase1_03:tryCurveBlockerPlacement(spawn_index, curve_y, preferred_side)
    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local side = self:getCenterBlockingSide(curve_y, preferred_side)
    local padding = self:getSafeCurvePadding()

    for attempt = 0, 15 do
        local seed = spawn_index * 43 + attempt
        local scale_y = 1 + 2 * self:noise(seed, 12)
        local half_height = SHARP_SWORD_HEIGHT * scale_y / 2
        local offset = padding + half_height + self:noise(seed, 13) * CURVE_BLOCKER_BAND_DEPTH
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

function KrisPhase1_03:getPairPlacement(spawn_frame, spawn_index)
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
    local gap_center = curve_y + (self:noise(spawn_index, 8) - 0.5) * PAIR_GAP_WOBBLE
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

function KrisPhase1_03:buildSharpSwordSpawnPlan()
    local total_slots = math.floor((WAVE_FRAMES - 1) / SPAWN_INTERVAL_FRAMES) + 1
    local pair_roll = self:noise(WAVE_FRAMES, 20)
    local pair_count = pair_roll < 0.18 and 0
        or pair_roll < 0.88 and 1
        or PAIR_SPAWN_MAX_COUNT
    local event_count = TOTAL_SHARP_SWORDS - pair_count
    local pair_events = {}
    local plan = {}

    for pair_index = 1, pair_count do
        local min_event = math.min(2, event_count)
        local max_event = math.max(min_event, event_count - 1)
        local event_span = max_event - min_event + 1
        local event_index = min_event + math.floor(self:noise(pair_index, 21) * event_span)

        while pair_events[event_index] do
            event_index = event_index + 1
            if event_index > max_event then
                event_index = min_event
            end
        end

        pair_events[event_index] = true
    end

    local start_slot = 0

    for event_index = 1, event_count do
        local slot = start_slot + event_index - 1

        table.insert(plan, {
            frame = slot * SPAWN_INTERVAL_FRAMES,
            index = event_index,
            pair = pair_events[event_index] or false,
        })
    end

    return plan
end

function KrisPhase1_03:getSharpSwordPlacement(spawn_frame, spawn_index)
    local min_y, max_y = self:getSpawnBounds()
    local curve_y = self:getSafeCurveY(spawn_frame + SAFE_CURVE_LOOKAHEAD_FRAMES)
    local placement_roll = self:noise(spawn_index, 6)
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

function KrisPhase1_03:getSharpSwordSpawnX()
    return SCREEN_WIDTH - SPAWN_RIGHT_OFFSET
end

function KrisPhase1_03:getSharpSwordBulletOptions(y, scale_y, flip_y)
    return {
        min_speed = SHARP_SWORD_MIN_SPEED,
        max_speed = SHARP_SWORD_MAX_SPEED,
        accel_duration = SHARP_SWORD_ACCEL_DURATION,
    }
end

function KrisPhase1_03:onSharpSwordSpawned(spawn, spawned)
end

function KrisPhase1_03:spawnSharpSwordAt(y, scale_y)
    local arena = Game.battle.arena
    local arena_center_y = (arena.top + arena.bottom) / 2
    local flip_y = y < arena_center_y

    return self:spawnBullet(
        "small_sword_sharp",
        self:getSharpSwordSpawnX(),
        y,
        scale_y,
        flip_y,
        self:getSharpSwordBulletOptions(y, scale_y, flip_y)
    )
end

function KrisPhase1_03:spawnSharpSwordPair(spawn_frame, spawn_index)
    local placement = self:getPairPlacement(spawn_frame, spawn_index)
    local top_scale_y = self:applyDensityScale(spawn_frame, placement.top_y, placement.top_scale_y)
    local bottom_scale_y = self:applyDensityScale(spawn_frame, placement.bottom_y, placement.bottom_scale_y)
    local top_y = self:getEdgeAnchoredY(top_scale_y, "top")
    local bottom_y = self:getEdgeAnchoredY(bottom_scale_y, "bottom")

    local top = self:spawnBullet(
        "small_sword_sharp",
        self:getSharpSwordSpawnX(),
        top_y,
        top_scale_y,
        true,
        self:getSharpSwordBulletOptions(top_y, top_scale_y, true)
    )
    local bottom = self:spawnBullet(
        "small_sword_sharp",
        self:getSharpSwordSpawnX(),
        bottom_y,
        bottom_scale_y,
        false,
        self:getSharpSwordBulletOptions(bottom_y, bottom_scale_y, false)
    )
    self:rememberSharpSword(spawn_frame, top_y, top_scale_y)
    self:rememberSharpSword(spawn_frame, bottom_y, bottom_scale_y)

    return { top, bottom }
end

function KrisPhase1_03:spawnSharpSword(spawn_frame, spawn_index)
    local y, scale_y = self:getSharpSwordPlacement(spawn_frame, spawn_index)
    scale_y = self:applyDensityScale(spawn_frame, y, scale_y)

    local sword = self:spawnSharpSwordAt(y, scale_y)
    self:rememberSharpSword(spawn_frame, y, scale_y)
    return sword
end

function KrisPhase1_03:startSharpSwordPattern()
    if self.sharp_sword_started then
        return
    end

    self.sharp_sword_started = true

    for _, spawn in ipairs(self:buildSharpSwordSpawnPlan()) do
        local relative_frame = spawn.frame
        local absolute_frame = KRIS_SWORD_HALL_BULLET_START_WAVE_FRAME + relative_frame
        local delay = relative_frame / FPS

        local function spawnNow()
            local spawned
            self.current_sharp_sword_spawn = spawn
            if spawn.pair then
                spawned = self:spawnSharpSwordPair(absolute_frame, spawn.index)
            else
                spawned = self:spawnSharpSword(absolute_frame, spawn.index)
            end
            self.current_sharp_sword_spawn = nil
            self:onSharpSwordSpawned(spawn, spawned)
        end

        if delay <= 0 then
            spawnNow()
        else
            self.timer:after(delay, spawnNow)
        end
    end
end

function KrisPhase1_03:onStart()
    self.wave_frame = 0
    self.recent_sharp_swords = {}
    self.pattern_seed = self:rollPatternSeed()
    self.kris_home_positions = {}
    self.sharp_sword_started = false

    local attacker_count = 0
    for _, attacker in ipairs(self:getAttackers()) do
        attacker_count = attacker_count + 1
        self.kris_home_positions[attacker] = {
            x = attacker.target_x or attacker.x,
            y = attacker.target_y or attacker.y,
        }
        playSwordHallDisappear(attacker, function()
            self:startSharpSwordPattern()
        end, function()
            moveAttackerAway(attacker)
        end)
    end

    if attacker_count == 0 then
        self.timer:after(KRIS_SWORD_HALL_BULLET_START_WAVE_FRAME / FPS, function()
            self:startSharpSwordPattern()
        end)
    end
end

function KrisPhase1_03:onEnd(death)
    for _, attacker in ipairs(self:getAttackers()) do
        local home = self.kris_home_positions and self.kris_home_positions[attacker]
        if home then
            moveAttackerTo(attacker, home.x, home.y)
        end
        attacker:setAnimation("appear")
    end

    return super.onEnd(self, death)
end

function KrisPhase1_03:update()
    self.wave_frame = math.min((self.wave_frame or 0) + DTMULT, WAVE_FRAMES)
    super.update(self)
end

function KrisPhase1_03:drawSafeCurve()
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

function KrisPhase1_03:draw()
    super.draw(self)

    if SHOW_SAFE_CURVE then
        self:drawSafeCurve()
    end
end

return KrisPhase1_03
