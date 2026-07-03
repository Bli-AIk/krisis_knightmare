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
end

function KrisPhase1_8:rollPatternSeed()
    if Mod and Mod.nextKrisisRandomSeed then
        return Mod:nextKrisisRandomSeed("kris_phase1_8")
    end

    return os.time()
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

function KrisPhase1_8:spawnSharpSword(spawn_frame, spawn_index)
    local y, scale_y = self:getSharpSwordPlacement(spawn_frame, spawn_index)
    scale_y = self:applyDensityScale(spawn_frame, y, scale_y)
    scale_y = math.max(scale_y, MIN_SINGLE_SHARP_SWORD_SCALE)

    local sword = self:spawnSharpSwordAt(y, scale_y)
    self:rememberSharpSword(spawn_frame, y, scale_y)
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
    super.onStart(self)
end

function KrisPhase1_8:canEnd()
    return self.can_finish
end

return KrisPhase1_8
