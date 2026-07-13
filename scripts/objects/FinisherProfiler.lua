local FinisherProfiler, super = Class(Object)

local function envFlag(name)
    local value = os.getenv(name)
    if not value then
        return false
    end

    value = tostring(value):lower()
    return value == "1" or value == "true" or value == "yes" or value == "on"
end

local function now()
    return love.timer.getTime()
end

local function getMilliseconds(seconds)
    return seconds * 1000
end

local function updateAggregate(aggregate, elapsed)
    aggregate.count = aggregate.count + 1
    aggregate.total = aggregate.total + elapsed
    aggregate.maximum = math.max(aggregate.maximum, elapsed)
end

local function formatAggregate(aggregate)
    if aggregate.count == 0 then
        return "n/a"
    end

    return string.format(
        "avg %.3f ms, max %.3f ms, frames %d",
        getMilliseconds(aggregate.total / aggregate.count),
        getMilliseconds(aggregate.maximum),
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

    self.enabled = envFlag("KRISIS_FINISHER_PROFILE")
    self.god_mode = os.getenv("KRISIS_FINISHER_PROFILE_GODMODE") ~= "0"
    self.quit_after = tonumber(os.getenv("KRISIS_FINISHER_PROFILE_SECONDS"))
    self.report_interval = tonumber(os.getenv("KRISIS_FINISHER_PROFILE_REPORT_INTERVAL")) or 2
    self.report_path = "debug/finisher_profile_latest.txt"

    self.started = false
    self.finished = false
    self.elapsed = 0
    self.last_report = 0
    self.update_start = nil
    self.draw_start = nil
    self.last_graphics_stats = nil

    self.update = { count = 0, total = 0, maximum = 0 }
    self.draw = { count = 0, total = 0, maximum = 0 }
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
    self.profile_samples = 0
    self.profile_stacks = {}
    self.profile_api = nil
end

function FinisherProfiler:isFinisherActive()
    local battle = Game and Game.battle
    local encounter = battle and battle.encounter
    return encounter and encounter.id == "kris_finisher"
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
        "[FinisherProfiler] started; report: %s/%s; LuaJIT: %s",
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
    local lines = {
        "KRISIS KNIGHTMARE FINISHER PROFILE",
        "reason: " .. tostring(reason),
        string.format("runtime: %.3f s", self.elapsed),
        "",
        "UPDATE: " .. formatAggregate(self.update),
        "DRAW: " .. formatAggregate(self.draw),
        string.format("slow updates (> 33.333 ms): %d", self.slow_updates),
        string.format("slow draws (> 33.333 ms): %d", self.slow_draws),
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

    if not self.started and self:isFinisherActive() then
        self:start()
    end

    if self.started and not self.finished then
        if self.god_mode and Game.battle and Game.battle.soul then
            -- Keep the test alive without disabling the normal collision scan.
            Game.battle.soul.inv_timer = math.max(Game.battle.soul.inv_timer or 0, 1)
        end
        self.update_start = now()
    end
end

function FinisherProfiler:postUpdate()
    if not self.started or self.finished then
        return
    end

    if self.update_start then
        local elapsed = now() - self.update_start
        updateAggregate(self.update, elapsed)
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
    elseif not self:isFinisherActive() then
        self:stop("battle ended")
    end
end

function FinisherProfiler:preDraw()
    if self.started and not self.finished and self:isFinisherActive() then
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
    self:collectGraphicsMetrics()
end

return FinisherProfiler
