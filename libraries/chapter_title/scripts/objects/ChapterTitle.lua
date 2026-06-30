---@class ChapterTitle: Object
local ChapterTitle, super = Class(Object)

local FRAME_DIR = Mod.info.path .. "/libraries/chapter_title/assets/frames/"
local AUDIO_PATH = Mod.info.path .. "/libraries/chapter_title/assets/audio/start.wav"
local FPS = 30
local TOTAL_FRAMES = 464
local DURATION = TOTAL_FRAMES / FPS
local FADE_DURATION = 0.5

function ChapterTitle:init(chapter, onComplete)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self.chapter = chapter
    self.onComplete = onComplete

    -- PNG 序列
    self.frame = 0
    self.cur_img = nil
    self.cur_sx = 1
    self.cur_sy = 1
    self.elapsed = 0

    -- 音频
    self.audio = love.audio.newSource(AUDIO_PATH, "static")
    self.audio:setVolume(2)
    self.audio_started = false

    -- 渐出
    self.fading_out = false
    self.fade_timer = 0

    self.debug_mode = Mod.info.dev
    self.debug_font = Assets.getFont("main", 12)
    self.debug_blocked = false
    self.debug_subtitle_alpha = 0
    self.running = true
    self.ended = false

    self:_advanceFrame()
end

function ChapterTitle:_framePath(n)
    return FRAME_DIR .. string.format("f_%03d.png", n)
end

function ChapterTitle:_loadFrame(n)
    local path = self:_framePath(n)
    if not love.filesystem.getInfo(path) then
        return false
    end
    if self.cur_img then
        self.cur_img:release()
    end
    self.cur_img = love.graphics.newImage(path)
    self.cur_sx = SCREEN_WIDTH / self.cur_img:getWidth()
    self.cur_sy = SCREEN_HEIGHT / self.cur_img:getHeight()
    return true
end

function ChapterTitle:_advanceFrame()
    self.frame = self.frame + 1
    if self.frame > TOTAL_FRAMES then
        return
    end
    self:_loadFrame(self.frame)
end

function ChapterTitle:_seekToFrame(target)
    while self.frame < target and self.frame < TOTAL_FRAMES do
        self.frame = self.frame + 1
        self:_loadFrame(self.frame)
    end
end

function ChapterTitle:_startFade()
    self.running = false
    self.fading_out = true
    self.fade_timer = 0
end

function ChapterTitle:_reset()
    self.frame = 0
    self.elapsed = 0
    self.fading_out = false
    self.fade_timer = 0
    self.ended = false
    self.running = true
    self.audio_started = false
    self.audio:stop()
    self.audio:setVolume(2)
    self:_advanceFrame()
end

function ChapterTitle:_finish()
    self.running = false
    self.ended = true
    self.audio:stop()
    Game.world:closeMenu()
    if self.onComplete then
        self.onComplete()
    end
end

function ChapterTitle:onKeyPressed(key)
    if self.ended then return end

    if key == "z" then
        self:_startFade()
        return
    end

    if not self.debug_mode then return end

    if key == "c" then
        if self.debug_blocked then
            self.debug_subtitle_alpha = 0
            self.debug_blocked = false
            self:_finish()
        else
            self.debug_blocked = true
        end
    elseif key == "r" and self.debug_blocked then
        self.debug_subtitle_alpha = 0
        self:_reset()
    end
end

function ChapterTitle:update()
    super.update(self)

    if self.fading_out then
        self.fade_timer = self.fade_timer + DT
        local progress = math.min(self.fade_timer / FADE_DURATION, 1)
        self.audio:setVolume(2 * (1 - progress))
        if self.fade_timer >= FADE_DURATION then
            self.fading_out = false
            self:_finish()
        end
        return
    end

    if not self.running then return end

    self.elapsed = self.elapsed + DT
    if not self.audio_started and self.elapsed >= 0.5 then
        self.audio_started = true
        self.audio:play()
    end
    local target_frame = math.floor(self.elapsed * FPS) + 1
    if target_frame > self.frame then
        self:_seekToFrame(target_frame)
    end
    if self.elapsed >= DURATION then
        if self.debug_blocked then
            self.debug_subtitle_alpha = 1
        else
            self:_startFade()
        end
    end

    if self.debug_mode and self.debug_subtitle_alpha > 0 and not self.debug_blocked then
        self.debug_subtitle_alpha = math.max(0, self.debug_subtitle_alpha - DT * 3)
    end
end

function ChapterTitle:draw()
    Draw.setColor(0, 0, 0, 1)
    Draw.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    if self.ended then return end

    if self.cur_img then
        local alpha = 1
        if self.fading_out then
            alpha = 1 - math.min(self.fade_timer / FADE_DURATION, 1)
        end
        Draw.setColor(1, 1, 1, alpha)
        Draw.draw(self.cur_img, 0, 0, 0, self.cur_sx, self.cur_sy)
    end

    if self.debug_mode and self.debug_subtitle_alpha > 0 then
        love.graphics.setFont(self.debug_font)
        Draw.setColor(1, 1, 1, self.debug_subtitle_alpha)
        Draw.printAlign("Scene transition blocked. Press [C] to continue, [R] to replay.", SCREEN_WIDTH - 10, SCREEN_HEIGHT - 30, "right")
    end
end

return ChapterTitle
