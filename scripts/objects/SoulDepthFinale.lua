local SoulDepthFinale, super = Class(Object)

local FLASH_IN_TIME = 2 / 60
local FLASH_OUT_TIME = 6 / 60
local SNAPSHOT_ALPHA = 0.42
local SNAPSHOT_FADE_TIME = 0.9
local SNAPSHOT_MOVE_X = 30
local SNAPSHOT_MOVE_Y = 30
local STAR_WAVE_COUNT = 3
local STAR_WAVE_INTERVAL = 5 / 60 * 3
local STAR_MIN_COUNT = 6
local STAR_MAX_COUNT = 12
local STAR_SCALE = 0.85
local STAR_MIN_DISTANCE = math.max(SCREEN_WIDTH, SCREEN_HEIGHT) + 120
local STAR_MAX_DISTANCE = math.max(SCREEN_WIDTH, SCREEN_HEIGHT) + 240
local STAR_MIN_TRAVEL_TIME = 1.45 * 2
local STAR_MAX_TRAVEL_TIME = 2.05 * 2
local STAR_LAYER = BATTLE_LAYERS["above_bullets"] + 3

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function lerp(from, to, t)
    return from + (to - from) * t
end

local function randomFloat(min, max)
    return min + love.math.random() * (max - min)
end

local function shuffle(values)
    for i = #values, 2, -1 do
        local j = love.math.random(i)
        values[i], values[j] = values[j], values[i]
    end
    return values
end

local function stratifiedAngles(count)
    local angles = {}
    local base = randomFloat(0, math.pi * 2)
    for i = 0, count - 1 do
        local segment_t = (i + love.math.random()) / count
        table.insert(angles, base + segment_t * math.pi * 2)
    end
    return shuffle(angles)
end

function SoulDepthFinale:init(x, y, wave, soul_echo)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.source_x = x or (SCREEN_WIDTH / 2)
    self.source_y = y or (SCREEN_HEIGHT / 2)
    self.wave = wave
    self.layer = BATTLE_LAYERS["top"] + 20
    self.waiting_for_snapshot = true
    self.time = 0
    self.next_star_wave = 1
    self.snapshot = nil
    self.soul_echo = soul_echo
    self.soul_echo_removed = false
    self.soul_echo_snapshot_hidden = false
    self.soul_echo_snapshot_visible = nil
    self.done_time = math.max(SNAPSHOT_FADE_TIME, FLASH_IN_TIME + FLASH_OUT_TIME)

    self:hideSoulEchoForSnapshot()
    love.graphics.captureScreenshot(function(image_data)
        self:restoreSoulEchoForSnapshot()
        if self.parent then
            self.snapshot = love.graphics.newImage(image_data)
            self.snapshot:setFilter("nearest", "nearest")
            self.waiting_for_snapshot = false
        end
    end)
end

function SoulDepthFinale:hideSoulEchoForSnapshot()
    if self.soul_echo and self.soul_echo.parent then
        self.soul_echo_snapshot_hidden = true
        self.soul_echo_snapshot_visible = self.soul_echo.visible
        self.soul_echo.visible = false
    end
end

function SoulDepthFinale:restoreSoulEchoForSnapshot()
    if not self.soul_echo_snapshot_hidden then
        return
    end

    self.soul_echo_snapshot_hidden = false
    if self.soul_echo and self.soul_echo.parent then
        self.soul_echo.visible = self.soul_echo_snapshot_visible
    end
    self.soul_echo_snapshot_visible = nil
end

function SoulDepthFinale:removeSoulEcho()
    if self.soul_echo_removed then
        return
    end

    self.soul_echo_removed = true
    if self.soul_echo and self.soul_echo.parent then
        self.soul_echo:remove()
    end
    self.soul_echo = nil
end

function SoulDepthFinale:spawnStarWave()
    local wave = self.wave
    if not wave or not wave.parent then
        return
    end

    local count = love.math.random(STAR_MIN_COUNT, STAR_MAX_COUNT)
    local angles = stratifiedAngles(count)

    for _, angle in ipairs(angles) do
        local distance = randomFloat(STAR_MIN_DISTANCE, STAR_MAX_DISTANCE)
        local target_x = self.source_x + math.cos(angle) * distance
        local target_y = self.source_y + math.sin(angle) * distance
        local travel_time = randomFloat(STAR_MIN_TRAVEL_TIME, STAR_MAX_TRAVEL_TIME)

        wave:spawnBullet(
            "soul_depth_star",
            self.source_x,
            self.source_y,
            target_x,
            target_y,
            travel_time,
            STAR_SCALE,
            STAR_SCALE,
            {
                alpha = 1,
                fade = false,
                layer = STAR_LAYER,
                rotation = angle,
                spin_speed = math.rad(240),
            }
        )
    end
end

function SoulDepthFinale:updateStarWaves()
    while self.next_star_wave <= STAR_WAVE_COUNT
        and self.time >= (self.next_star_wave - 1) * STAR_WAVE_INTERVAL do
        self:spawnStarWave()
        self.next_star_wave = self.next_star_wave + 1
    end
end

function SoulDepthFinale:getFlashAlpha()
    if self.time < FLASH_IN_TIME then
        return clamp(self.time / FLASH_IN_TIME, 0, 1)
    end

    local fade_time = self.time - FLASH_IN_TIME
    return clamp(1 - (fade_time / FLASH_OUT_TIME), 0, 1)
end

function SoulDepthFinale:getSnapshotAlpha()
    local progress = clamp(self.time / SNAPSHOT_FADE_TIME, 0, 1)
    return SNAPSHOT_ALPHA * (1 - progress)
end

function SoulDepthFinale:update()
    super.update(self)

    if self.waiting_for_snapshot then
        return
    end

    self.time = self.time + DT
    if self.time >= FLASH_IN_TIME then
        self:removeSoulEcho()
    end
    self:updateStarWaves()

    if self.time >= self.done_time and self.next_star_wave > STAR_WAVE_COUNT then
        self:remove()
    end
end

function SoulDepthFinale:draw()
    if self.waiting_for_snapshot then
        return
    end

    love.graphics.push()
    love.graphics.origin()

    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    if self.snapshot then
        local progress = clamp(self.time / SNAPSHOT_FADE_TIME, 0, 1)
        local alpha = self:getSnapshotAlpha()
        local x = lerp(0, SNAPSHOT_MOVE_X, progress)
        local y = lerp(0, SNAPSHOT_MOVE_Y, progress)
        local scale_x = SCREEN_WIDTH / self.snapshot:getWidth()
        local scale_y = SCREEN_HEIGHT / self.snapshot:getHeight()
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(self.snapshot, x, y, 0, scale_x, scale_y)
    end

    local flash_alpha = self:getFlashAlpha()
    if flash_alpha > 0 then
        love.graphics.setColor(1, 1, 1, flash_alpha)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    end

    love.graphics.setColor(old_r, old_g, old_b, old_a)
    love.graphics.pop()
end

function SoulDepthFinale:onRemove(parent)
    self:restoreSoulEchoForSnapshot()
    super.onRemove(self, parent)
end

return SoulDepthFinale
