local KrisPhase1_8, super = Class("kris_phase1_3")

local FPS = 30
local PHASE3_SPAWN_INTERVAL_SECONDS = 5 / FPS
local SPAWN_INTERVAL_SECONDS = 0.5
local TOTAL_SHARP_SWORD_WAVES = 16
local FINAL_FIRE_WAVES = 5
local ARENA_EDGE_SPAWN_DISTANCE = 100
local LEFT_FADE_WIDTH = 90
local PAIR_SPAWN_RATIO = 0.4
local INTERVAL_SPEED_MULTIPLIER = PHASE3_SPAWN_INTERVAL_SECONDS / SPAWN_INTERVAL_SECONDS
local SPEED_MULTIPLIER = INTERVAL_SPEED_MULTIPLIER * 0.75
local FIRE_SPEED_MULTIPLIER = INTERVAL_SPEED_MULTIPLIER * 1.7
local FIRE_ACCEL_DURATION = 0.2
local MIN_FIRE_PHASE_SECONDS = 1.5
local MIN_SINGLE_SHARP_SWORD_SCALE = 2.55
local SHARP_SWORD_HEIGHT = 33
local SPAWN_TOP_Y = 80
local TOP_CAMP_Y = 110
local TOP_CAMP_SINGLE_INTERVAL = 3
local RANDOM_EDGE_PLACEMENT_CHANCE = 0.35
local RANDOM_EDGE_BAND_DEPTH = 36
local TOP_CAMP_SCALE_MAX = 1.8
local PAIR_GAP_SIZE = 68
local PAIR_TOP_Y_MIN = SPAWN_TOP_Y
local PAIR_TOP_Y_MAX = TOP_CAMP_Y
local PAIR_TOP_REACH_Y = TOP_CAMP_Y
local PAIR_SCALE_MIN = 1
local PAIR_SCALE_MAX = 3
local SINGLE_CLOSE_Y_DISTANCE = 56
local SINGLE_FORCED_SEPARATION_DISTANCE = 96
local SINGLE_HISTORY_LIMIT = 2

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function lerp(from, to, t)
    return from + (to - from) * t
end

function KrisPhase1_8:init()
    super.init(self)
    self.time = -1
    self.can_finish = false
    self.all_spawns_done = false
    self.pending_fire_count = 0
    self.started_fire_count = 0
    self.launched_fire_count = 0
    self.expected_fire_count = 0
    self.fire_started = false
    self.minimum_fire_phase_elapsed = false
    self.fire_release_timer_started = false
    self.recent_single_sharp_swords = {}
end

function KrisPhase1_8:rollPatternSeed()
    if Mod and Mod.nextKrisisRandomSeed then
        return Mod:nextKrisisRandomSeed("kris_phase1_8")
    end

    return os.time()
end

function KrisPhase1_8:getSpawnBounds()
    local spawn_top, spawn_bottom = super.getSpawnBounds(self)
    return math.min(spawn_top, SPAWN_TOP_Y), spawn_bottom
end

function KrisPhase1_8:buildSharpSwordSpawnPlan()
    local plan = {}
    local interval_frames = SPAWN_INTERVAL_SECONDS * FPS
    local fire_start_index = TOTAL_SHARP_SWORD_WAVES - FINAL_FIRE_WAVES + 1
    local non_fire_wave_count = fire_start_index - 1
    local pair_count = math.floor(non_fire_wave_count * PAIR_SPAWN_RATIO)
    local pair_candidates = {}
    local pair_indexes = {}

    for index = 1, non_fire_wave_count do
        table.insert(pair_candidates, {
            index = index,
            score = self:noise(index, 80),
        })
    end

    table.sort(pair_candidates, function(a, b)
        return a.score < b.score
    end)

    for index = 1, pair_count do
        pair_indexes[pair_candidates[index].index] = true
    end

    for index = 1, TOTAL_SHARP_SWORD_WAVES do
        table.insert(plan, {
            frame = (index - 1) * interval_frames,
            index = index,
            pair = pair_indexes[index] or false,
            fire = index >= fire_start_index,
        })
    end

    return plan
end

function KrisPhase1_8:getSharpSwordSpawnX()
    local arena = Game.battle.arena
    return (arena and arena.right or SCREEN_WIDTH) + ARENA_EDGE_SPAWN_DISTANCE
end

function KrisPhase1_8:getSharpSwordLeftFadeX()
    local arena = Game.battle.arena
    return (arena and arena.left or 0) - ARENA_EDGE_SPAWN_DISTANCE
end

function KrisPhase1_8:getSharpSwordBulletOptions(y, scale_y, flip_y)
    local spawn = self.current_sharp_sword_spawn
    local queued_fire = spawn and spawn.fire == true
    local auto_fire_delay

    if queued_fire then
        auto_fire_delay = math.max((TOTAL_SHARP_SWORD_WAVES - spawn.index) * SPAWN_INTERVAL_SECONDS, 0)
    end

    return {
        min_speed = 4 * SPEED_MULTIPLIER,
        max_speed = 18 * SPEED_MULTIPLIER,
        accel_duration = 0.75,
        left_fade_x = self:getSharpSwordLeftFadeX(),
        left_fade_width = LEFT_FADE_WIDTH,
        fire_speed = 18 * FIRE_SPEED_MULTIPLIER * 3,
        fire_accel_duration = FIRE_ACCEL_DURATION,
        queued_fire = queued_fire,
        phase8_fire_candidate = queued_fire,
        auto_fire_delay = auto_fire_delay,
        on_fire_scheduled = queued_fire and function(sword)
            self:onSharpSwordFireScheduled(sword)
        end or nil,
        on_fire_started = queued_fire and function(sword)
            self:onSharpSwordFireStarted(sword)
        end or nil,
        on_fire_launched = queued_fire and function(sword)
            self:onSharpSwordFireLaunched(sword)
        end or nil,
        on_fire_finished = queued_fire and function(sword)
            self:onSharpSwordFireFinished(sword)
        end or nil,
    }
end

function KrisPhase1_8:getTopCampScale()
    local spawn_top = self:getSpawnBounds()
    return clamp((TOP_CAMP_Y - spawn_top) / (SHARP_SWORD_HEIGHT / 2), 1, TOP_CAMP_SCALE_MAX)
end

function KrisPhase1_8:getTopCampPlacement()
    return TOP_CAMP_Y, self:getTopCampScale()
end

function KrisPhase1_8:getSharpSwordPlacement(spawn_frame, spawn_index)
    local spawn = self.current_sharp_sword_spawn
    if spawn and (spawn.fire or spawn.index % TOP_CAMP_SINGLE_INTERVAL == 1) then
        return self:getTopCampPlacement()
    end

    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local side = self:noise(spawn_index * 13 + spawn_frame * 0.11, 20) < 0.5 and "top" or "bottom"
    local scale_y = lerp(1.1, 3, self:noise(spawn_index * 17 + spawn_frame * 0.07, 21))
    local half_height = SHARP_SWORD_HEIGHT * scale_y / 2

    if self:noise(spawn_index * 19 + spawn_frame * 0.05, 22) < RANDOM_EDGE_PLACEMENT_CHANCE then
        local edge_offset = self:noise(spawn_index * 23 + spawn_frame * 0.03, 23) * RANDOM_EDGE_BAND_DEPTH
        local y = side == "top"
            and spawn_top + half_height + edge_offset
            or spawn_bottom - half_height - edge_offset
        return clamp(y, spawn_top + half_height, spawn_bottom - half_height), scale_y
    end

    local min_y = spawn_top + half_height
    local max_y = spawn_bottom - half_height
    if min_y > max_y then
        return (spawn_top + spawn_bottom) / 2, scale_y
    end

    local y = lerp(min_y, max_y, self:noise(spawn_index * 29 + spawn_frame * 0.13, 24))
    return y, scale_y
end

function KrisPhase1_8:getPairPlacement(spawn_frame, spawn_index)
    local _, spawn_bottom = self:getSpawnBounds()
    local gap_size = PAIR_GAP_SIZE
    local top_y = lerp(
        PAIR_TOP_Y_MIN,
        PAIR_TOP_Y_MAX,
        self:noise(spawn_index * 37 + spawn_frame * 0.09, 26)
    )
    local min_top_scale = clamp(
        (PAIR_TOP_REACH_Y - top_y) * 2 / SHARP_SWORD_HEIGHT,
        PAIR_SCALE_MIN,
        PAIR_SCALE_MAX
    )
    local max_top_scale = clamp(
        (spawn_bottom - gap_size - SHARP_SWORD_HEIGHT - top_y) * 2 / SHARP_SWORD_HEIGHT,
        min_top_scale,
        PAIR_SCALE_MAX
    )
    local top_scale_y = lerp(
        min_top_scale,
        max_top_scale,
        self:noise(spawn_index * 41 + spawn_frame * 0.05, 27)
    )
    local top_bottom_y = top_y + SHARP_SWORD_HEIGHT * top_scale_y / 2
    local gap_bottom = top_bottom_y + gap_size
    local max_bottom_scale = (spawn_bottom - gap_bottom) / SHARP_SWORD_HEIGHT
    local bottom_scale_y = PAIR_SCALE_MIN

    if max_bottom_scale > PAIR_SCALE_MIN then
        bottom_scale_y = lerp(
            PAIR_SCALE_MIN,
            math.min(max_bottom_scale, PAIR_SCALE_MAX),
            self:noise(spawn_index * 43 + spawn_frame * 0.04, 28)
        )
    end

    bottom_scale_y = clamp(bottom_scale_y, PAIR_SCALE_MIN, PAIR_SCALE_MAX)
    local bottom_half_height = SHARP_SWORD_HEIGHT * bottom_scale_y / 2

    return {
        top_y = top_y,
        top_scale_y = top_scale_y,
        bottom_y = gap_bottom + bottom_half_height,
        bottom_scale_y = bottom_scale_y,
    }
end

function KrisPhase1_8:lastTwoSingleSharpSwordsAreClose()
    local recent = self.recent_single_sharp_swords
    if not recent or #recent < 2 then
        return false
    end

    local first = recent[#recent - 1]
    local second = recent[#recent]
    return math.abs(first.y - second.y) <= SINGLE_CLOSE_Y_DISTANCE
end

function KrisPhase1_8:getSeparatedSingleSharpSwordY(spawn_frame, spawn_index, y, scale_y)
    if not self:lastTwoSingleSharpSwordsAreClose() then
        return y
    end

    local recent = self.recent_single_sharp_swords
    local cluster_y = (recent[#recent - 1].y + recent[#recent].y) / 2
    local spawn_top, spawn_bottom = self:getSpawnBounds()
    local half_height = SHARP_SWORD_HEIGHT * scale_y / 2
    local min_y = spawn_top + half_height
    local max_y = spawn_bottom - half_height

    if min_y > max_y then
        return y
    end

    local spawn_center_y = (spawn_top + spawn_bottom) / 2
    local move_down = cluster_y < spawn_center_y
    local separated_min_y = min_y
    local separated_max_y = max_y

    if move_down then
        separated_min_y = math.max(min_y, cluster_y + SINGLE_FORCED_SEPARATION_DISTANCE)
    else
        separated_max_y = math.min(max_y, cluster_y - SINGLE_FORCED_SEPARATION_DISTANCE)
    end

    if separated_min_y > separated_max_y then
        return move_down and max_y or min_y
    end

    return lerp(
        separated_min_y,
        separated_max_y,
        self:noise(spawn_index * 53 + spawn_frame * 0.08, 30)
    )
end

function KrisPhase1_8:rememberSingleSharpSword(y, scale_y)
    self.recent_single_sharp_swords = self.recent_single_sharp_swords or {}

    table.insert(self.recent_single_sharp_swords, {
        y = y,
        scale_y = scale_y,
    })

    while #self.recent_single_sharp_swords > SINGLE_HISTORY_LIMIT do
        table.remove(self.recent_single_sharp_swords, 1)
    end
end

function KrisPhase1_8:spawnSharpSwordPair(spawn_frame, spawn_index)
    local placement = self:getPairPlacement(spawn_frame, spawn_index)
    local top_y = placement.top_y
    local top_scale_y = placement.top_scale_y
    local bottom_scale_y = placement.bottom_scale_y
    local bottom_y = placement.bottom_y

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

function KrisPhase1_8:spawnSharpSword(spawn_frame, spawn_index)
    local y, scale_y = self:getSharpSwordPlacement(spawn_frame, spawn_index)
    scale_y = self:applyDensityScale(spawn_frame, y, scale_y)
    scale_y = math.max(scale_y, MIN_SINGLE_SHARP_SWORD_SCALE)
    y = self:getSeparatedSingleSharpSwordY(spawn_frame, spawn_index, y, scale_y)

    local sword = self:spawnSharpSwordAt(y, scale_y)
    self:rememberSharpSword(spawn_frame, y, scale_y)
    self:rememberSingleSharpSword(y, scale_y)
    return sword
end

function KrisPhase1_8:finishIfReady()
    if self.all_spawns_done
        and self.fire_started
        and self.minimum_fire_phase_elapsed
        and self.expected_fire_count >= FINAL_FIRE_WAVES
        and self.started_fire_count >= self.expected_fire_count
        and self.launched_fire_count >= self.expected_fire_count
        and self.pending_fire_count <= 0
    then
        self.can_finish = true
        self:setFinished()
    end
end

function KrisPhase1_8:onSharpSwordFireScheduled()
    self.pending_fire_count = (self.pending_fire_count or 0) + 1
    self.expected_fire_count = (self.expected_fire_count or 0) + 1

    if self.expected_fire_count == FINAL_FIRE_WAVES then
        print("[kris_phase1_8] scheduled 5 auto-fire swords")
    end
end

function KrisPhase1_8:onSharpSwordFireStarted()
    self.started_fire_count = (self.started_fire_count or 0) + 1

    if self.started_fire_count == FINAL_FIRE_WAVES then
        print("[kris_phase1_8] started 5 auto-fire swords")
    end

    if self.fire_started then
        self:finishIfReady()
        return
    end

    self.fire_started = true
    self.minimum_fire_phase_elapsed = false

    self.timer:after(MIN_FIRE_PHASE_SECONDS, function()
        self.minimum_fire_phase_elapsed = true
        self:finishIfReady()
    end)

    self:finishIfReady()
end

function KrisPhase1_8:onSharpSwordFireLaunched()
    self.launched_fire_count = (self.launched_fire_count or 0) + 1
    self:finishIfReady()
end

function KrisPhase1_8:onSharpSwordFireFinished()
    self.pending_fire_count = math.max((self.pending_fire_count or 0) - 1, 0)
    self:finishIfReady()
end

function KrisPhase1_8:startSharpSwordPattern()
    if self.fire_release_timer_started then
        return super.startSharpSwordPattern(self)
    end

    super.startSharpSwordPattern(self)

    self.fire_release_timer_started = true
    local release_delay = (TOTAL_SHARP_SWORD_WAVES - 1) * SPAWN_INTERVAL_SECONDS + 1 / FPS
    self.timer:after(release_delay, function()
        self.all_spawns_done = true
        self:finishIfReady()
    end)
end

function KrisPhase1_8:onSharpSwordSpawned(spawn, spawned)
    if spawn.index >= TOTAL_SHARP_SWORD_WAVES then
        self.all_spawns_done = true
        self:finishIfReady()
    end
end

function KrisPhase1_8:onStart()
    self.can_finish = false
    self.all_spawns_done = false
    self.pending_fire_count = 0
    self.started_fire_count = 0
    self.launched_fire_count = 0
    self.expected_fire_count = 0
    self.fire_started = false
    self.minimum_fire_phase_elapsed = false
    self.fire_release_timer_started = false
    self.recent_single_sharp_swords = {}
    super.onStart(self)
end

function KrisPhase1_8:canEnd()
    return self.can_finish
end

return KrisPhase1_8
