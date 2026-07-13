local FinisherProfiler, super = Class(Object)

local function envFlag(name, default)
    local value = os.getenv(name)
    if not value then
        return default == true
    end

    value = tostring(value):lower()
    if value == "0" or value == "false" or value == "no" or value == "off" then
        return false
    end
    return value == "1" or value == "true" or value == "yes" or value == "on"
end

local function now()
    return love.timer.getTime()
end

local function getMilliseconds(seconds)
    return seconds * 1000
end

local function newAggregate()
    return {
        count = 0,
        total = 0,
        maximum = 0,
        minimum = math.huge,
        squared_total = 0,
        samples = {},
    }
end

local function updateAggregate(aggregate, elapsed)
    aggregate.count = aggregate.count + 1
    aggregate.total = aggregate.total + elapsed
    aggregate.maximum = math.max(aggregate.maximum, elapsed)
    aggregate.minimum = math.min(aggregate.minimum, elapsed)
    aggregate.squared_total = aggregate.squared_total + elapsed * elapsed
    table.insert(aggregate.samples, elapsed)
end

local function getPercentile(aggregate, percentile)
    if aggregate.count == 0 then
        return 0
    end

    local samples = {}
    for i, value in ipairs(aggregate.samples) do
        samples[i] = value
    end
    table.sort(samples)

    local index = math.max(1, math.ceil(#samples * percentile))
    return samples[index]
end

local function formatAggregate(aggregate)
    if aggregate.count == 0 then
        return "n/a"
    end

    local average = aggregate.total / aggregate.count
    local variance = math.max(aggregate.squared_total / aggregate.count - average * average, 0)
    local jitter = math.sqrt(variance)

    return string.format(
        "avg %.3f ms, p95 %.3f ms, p99 %.3f ms, max %.3f ms, jitter %.3f ms, frames %d",
        getMilliseconds(average),
        getMilliseconds(getPercentile(aggregate, 0.95)),
        getMilliseconds(getPercentile(aggregate, 0.99)),
        getMilliseconds(aggregate.maximum),
        getMilliseconds(jitter),
        aggregate.count
    )
end

local function addSample(aggregate, value)
    aggregate.count = aggregate.count + 1
    aggregate.total = aggregate.total + value
    aggregate.maximum = math.max(aggregate.maximum, value)
end

local function getObjectCount(stage, class)
    if not stage or not stage.objects_by_class or not class then
        return 0
    end

    local objects = stage.objects_by_class[class] or {}
    local count = 0
    for i = 1, #objects do
        if objects[i].stage == stage then
            count = count + 1
        end
    end
    return count
end

local function sortedCounts(counts, limit)
    local entries = {}
    for key, count in pairs(counts) do
        table.insert(entries, { key = key, count = count })
    end

    table.sort(entries, function(a, b)
        return a.count > b.count
    end)

    local result = {}
    for i = 1, math.min(limit, #entries) do
        table.insert(result, string.format("%5d  %s", entries[i].count, entries[i].key))
    end
    return result
end

function FinisherProfiler:init()
    super.init(self)

    self.enabled = envFlag("KRISIS_FINISHER_PROFILE") or envFlag("KRISIS_PROFILE")
    self.target_encounter = os.getenv("KRISIS_PROFILE_ENCOUNTER")
    if not self.target_encounter then
        self.target_encounter = envFlag("KRISIS_PROFILE") and "kris" or "kris_finisher"
    end
    self.god_mode = envFlag(
        "KRISIS_PROFILE_GODMODE",
        envFlag("KRISIS_FINISHER_PROFILE_GODMODE", true)
    )
    self.auto_defend = envFlag("KRISIS_PROFILE_AUTO_DEFEND", self.target_encounter == "kris")
    self.quit_after = tonumber(os.getenv("KRISIS_FINISHER_PROFILE_SECONDS"))
        or tonumber(os.getenv("KRISIS_PROFILE_SECONDS"))
    self.report_interval = tonumber(os.getenv("KRISIS_FINISHER_PROFILE_REPORT_INTERVAL"))
        or tonumber(os.getenv("KRISIS_PROFILE_REPORT_INTERVAL"))
        or 2
    self.report_path = os.getenv("KRISIS_PROFILE_REPORT_PATH")
        or os.getenv("KRISIS_PROFILE_REPORT")
        or "debug/finisher_profile_latest.txt"

    self.started = false
    self.finished = false
    self.elapsed = 0
    self.last_report = 0
    self.update_start = nil
    self.frame_start = nil
    self.update_elapsed = nil
    self.draw_start = nil
    self.last_graphics_stats = nil
    self.wave_ids = {}
    self.current_wave_id = nil
    self.auto_defend_count = 0

    self.update = newAggregate()
    self.draw = newAggregate()
    self.work = newAggregate()
    self.stars = { count = 0, total = 0, maximum = 0 }
    self.bullets = { count = 0, total = 0, maximum = 0 }
    self.gc = { count = 0, total = 0, maximum = 0 }
    self.graphics = {
        drawcalls = { count = 0, total = 0, maximum = 0 },
        canvasswitches = { count = 0, total = 0, maximum = 0 },
        shader_switches = { count = 0, total = 0, maximum = 0 },
    }

    self.slow_updates = 0
    self.slow_draws = 0
    self.slow_work = 0
    self.profile_samples = 0
    self.profile_stacks = {}
    self.profile_api = nil
end

function FinisherProfiler:isTargetActive()
    local battle = Game and Game.battle
    local encounter = battle and battle.encounter
    return encounter and encounter.id == self.target_encounter
end

function FinisherProfiler:getCurrentWaveId()
    local battle = Game and Game.battle
    if not battle then
        return nil
    end

    for _, wave in ipairs(battle.waves or {}) do
        if wave.parent and wave.active then
            return wave.id
        end
    end

    for _, enemy in ipairs(battle.enemies or {}) do
        if enemy.selected_wave then
            return enemy.selected_wave
        end
    end
end

function FinisherProfiler:getProfileTarget()
    local battle = Game and Game.battle
    local stage = Game and Game.stage
    local star_class = Registry and Registry.getBullet and Registry.getBullet("finisher_star")
    local bullet_class = Bullet

    return stage, star_class, bullet_class
end

function FinisherProfiler:collectObjectMetrics()
    local stage, star_class, bullet_class = self:getProfileTarget()
    local stars = getObjectCount(stage, star_class)
    local bullets = getObjectCount(stage, bullet_class)
    local wave_id = self:getCurrentWaveId()

    if wave_id then
        self.current_wave_id = wave_id
        self.wave_ids[wave_id] = true
    end

    addSample(self.stars, stars)
    addSample(self.bullets, bullets)
    addSample(self.gc, collectgarbage("count"))

    return stars, bullets
end

function FinisherProfiler:collectGraphicsMetrics()
    if not love.graphics.getStats then
        return
    end

    local stats = love.graphics.getStats()
    self.last_graphics_stats = stats
    for _, key in ipairs({ "drawcalls", "canvasswitches", "shaderswitches" }) do
        if stats[key] then
            addSample(self.graphics[key == "shaderswitches" and "shader_switches" or key], stats[key])
        end
    end
end

function FinisherProfiler:start()
    if self.started or self.finished or not self.enabled then
        return
    end

    self.started = true
    self.start_time = now()
    self.elapsed = 0
    self.last_report = 0

    love.filesystem.createDirectory("debug")

    local jit_profile_ok, profile = pcall(require, "jit.profile")
    if jit_profile_ok and profile and profile.start and profile.dumpstack then
        self.profile_api = profile
        local profiler = self
        local profile_started, profile_error = pcall(profile.start, "f10", function(thread, samples)
            profiler.profile_samples = profiler.profile_samples + samples
            local ok, stack = pcall(profile.dumpstack, thread, "pl", 8)
            if ok and stack and stack ~= "" then
                profiler.profile_stacks[stack] = (profiler.profile_stacks[stack] or 0) + samples
            end
        end)
        if not profile_started then
            self.profile_api = nil
            print("[FinisherProfiler] LuaJIT profiler unavailable: " .. tostring(profile_error))
        end
    end

    local jit_status = "unavailable"
    if jit and jit.status then
        jit_status = tostring(jit.status())
    end
    print(string.format(
        "[FinisherProfiler] started; target=%s god=%s auto_defend=%s report: %s/%s; LuaJIT: %s",
        self.target_encounter,
        tostring(self.god_mode),
        tostring(self.auto_defend),
        love.filesystem.getSaveDirectory(),
        self.report_path,
        jit_status
    ))
    self:writeReport("started")
end

function FinisherProfiler:stop(reason)
    if not self.started or self.finished then
        return
    end

    if self.profile_api then
        self.profile_api.stop()
        self.profile_api = nil
    end

    self.finished = true
    self:writeReport(reason or "stopped")
    print("[FinisherProfiler] stopped: " .. (reason or "stopped"))
end

function FinisherProfiler:writeReport(reason)
    if not self.started then
        return
    end

    local last_stats = self.last_graphics_stats or {}
    local wave_ids = {}
    for wave_id, _ in pairs(self.wave_ids) do
        table.insert(wave_ids, wave_id)
    end
    table.sort(wave_ids)
    local lines = {
        "KRISIS KNIGHTMARE PERFORMANCE PROFILE",
        "target encounter: " .. tostring(self.target_encounter),
        "waves: " .. (#wave_ids > 0 and table.concat(wave_ids, ", ") or "n/a"),
        "god mode: " .. tostring(self.god_mode),
        "auto defend: " .. tostring(self.auto_defend),
        "auto defend actions: " .. tostring(self.auto_defend_count),
        "reason: " .. tostring(reason),
        string.format("runtime: %.3f s", self.elapsed),
        "",
        "UPDATE: " .. formatAggregate(self.update),
        "DRAW: " .. formatAggregate(self.draw),
        "CPU WORK (update + draw): " .. formatAggregate(self.work),
        string.format("slow updates (> 33.333 ms): %d", self.slow_updates),
        string.format("slow draws (> 33.333 ms): %d", self.slow_draws),
        string.format("slow CPU frames (> 33.333 ms): %d", self.slow_work),
        string.format("stars: avg %.1f, peak %.0f", self.stars.count > 0 and self.stars.total / self.stars.count or 0, self.stars.maximum),
        string.format("bullets: avg %.1f, peak %.0f", self.bullets.count > 0 and self.bullets.total / self.bullets.count or 0, self.bullets.maximum),
        string.format("Lua memory: avg %.1f KB, peak %.1f KB", self.gc.count > 0 and self.gc.total / self.gc.count or 0, self.gc.maximum),
        "",
        string.format("graphics drawcalls: avg %.1f, peak %.0f, last %.0f", self.graphics.drawcalls.count > 0 and self.graphics.drawcalls.total / self.graphics.drawcalls.count or 0, self.graphics.drawcalls.maximum, last_stats.drawcalls or 0),
        string.format("graphics canvasswitches: avg %.1f, peak %.0f, last %.0f", self.graphics.canvasswitches.count > 0 and self.graphics.canvasswitches.total / self.graphics.canvasswitches.count or 0, self.graphics.canvasswitches.maximum, last_stats.canvasswitches or 0),
        string.format("graphics shaderswitches: avg %.1f, peak %.0f, last %.0f", self.graphics.shader_switches.count > 0 and self.graphics.shader_switches.total / self.graphics.shader_switches.count or 0, self.graphics.shader_switches.maximum, last_stats.shaderswitches or 0),
        "",
        "LuaJIT samples: " .. tostring(self.profile_samples),
        "LuaJIT top stacks:",
    }

    local stacks = sortedCounts(self.profile_stacks, 30)
    if #stacks == 0 then
        table.insert(lines, "(no samples)")
    else
        for _, line in ipairs(stacks) do
            table.insert(lines, line)
        end
    end

    love.filesystem.write(self.report_path, table.concat(lines, "\n") .. "\n")
end

function FinisherProfiler:preUpdate()
    if not self.enabled then
        return
    end

    if not self.started and self:isTargetActive() then
        self:start()
    end

    if self.started and not self.finished then
        if self.god_mode and Game.battle and Game.battle.soul then
            -- Keep the test alive without disabling the normal collision scan.
            Game.battle.soul.inv_timer = math.max(Game.battle.soul.inv_timer or 0, 1)
        end
        if self.auto_defend and self.target_encounter == "kris" then
            self:autoDefend()
        end
        self.update_start = now()
        self.frame_start = self.update_start
    end
end

function FinisherProfiler:autoDefend()
    local battle = Game and Game.battle
    if not battle or battle:getState() ~= "ACTIONSELECT" then
        return
    end

    local character_id = battle.current_selecting
    local battler = character_id and battle.party and battle.party[character_id]
    if not battler or not battler:isActive() then
        return
    end

    if battle.character_actions and battle.character_actions[character_id] then
        return
    end

    battle:pushAction("DEFEND")
    self.auto_defend_count = self.auto_defend_count + 1
end

function FinisherProfiler:postUpdate()
    if not self.started or self.finished then
        return
    end

    if self.update_start then
        local elapsed = now() - self.update_start
        updateAggregate(self.update, elapsed)
        self.update_elapsed = elapsed
        if elapsed > 1 / 30 then
            self.slow_updates = self.slow_updates + 1
        end
    end

    local stars, bullets = self:collectObjectMetrics()
    self.elapsed = self.elapsed + (DT or 0)

    if self.elapsed - self.last_report >= self.report_interval then
        self.last_report = self.elapsed
        self:writeReport("running")
        print(string.format(
            "[FinisherProfiler] t=%.1fs update=%.3fms stars=%d bullets=%d gc=%.1fKB",
            self.elapsed,
            getMilliseconds(self.update.count > 0 and self.update.total / self.update.count or 0),
            stars,
            bullets,
            collectgarbage("count")
        ))
    end

    if self.quit_after and self.elapsed >= self.quit_after then
        self:stop("time limit")
        love.event.quit()
    elseif not self:isTargetActive() then
        self:stop("battle ended")
    end
end

function FinisherProfiler:preDraw()
    if self.started and not self.finished and self:isTargetActive() then
        self.draw_start = now()
    end
end

function FinisherProfiler:postDraw()
    if not self.started or self.finished or not self.draw_start then
        return
    end

    local elapsed = now() - self.draw_start
    updateAggregate(self.draw, elapsed)
    if elapsed > 1 / 30 then
        self.slow_draws = self.slow_draws + 1
    end
    local work_elapsed = (self.update_elapsed or 0) + elapsed
    updateAggregate(self.work, work_elapsed)
    if work_elapsed > 1 / 30 then
        self.slow_work = self.slow_work + 1
    end
    self:collectGraphicsMetrics()
end

return FinisherProfiler
