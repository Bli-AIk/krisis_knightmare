---@class ChapterTitle: Object
local ChapterTitle, super = Class(Object)

local VIDEO_PATH = Mod.info.path .. "/libraries/chapter_title/assets/video/title.ogv"
local AUDIO_PATH = Mod.info.path .. "/libraries/chapter_title/assets/audio/start.wav"
local DURATION = 464 / 30
local FADE_DURATION = 0.5

function ChapterTitle:init(chapter, onComplete)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self.chapter = chapter
    self.onComplete = onComplete

    self.video = love.graphics.newVideo(VIDEO_PATH, {audio = false})
    self.video:setFilter("nearest", "nearest")
    self.video:play()
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

end

function ChapterTitle:_startFade()
    if self.fading_out or self.ended then
        return
    end
    self.running = false
    self.fading_out = true
    self.fade_timer = 0
    self.video:pause()
end

function ChapterTitle:_reset()
    self.elapsed = 0
    self.fading_out = false
    self.fade_timer = 0
    self.ended = false
    self.running = true
    self.audio_started = false
    self.audio:stop()
    self.audio:setVolume(2)
    self.video:seek(0)
    self.video:play()
end

function ChapterTitle:_finish()
    self.running = false
    self.ended = true
    self.audio:stop()
    self.video:pause()
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

    if self.video then
        local alpha = 1
        if self.fading_out then
            alpha = 1 - math.min(self.fade_timer / FADE_DURATION, 1)
        end
        Draw.setColor(1, 1, 1, alpha)
        love.graphics.draw(
            self.video,
            0,
            0,
            0,
            SCREEN_WIDTH / self.video:getWidth(),
            SCREEN_HEIGHT / self.video:getHeight()
        )
    end

    if self.debug_mode and self.debug_subtitle_alpha > 0 then
        love.graphics.setFont(self.debug_font)
        Draw.setColor(1, 1, 1, self.debug_subtitle_alpha)
        Draw.printAlign("Scene transition blocked. Press [C] to continue, [R] to replay.", SCREEN_WIDTH - 10, SCREEN_HEIGHT - 30, "right")
    end
end

return ChapterTitle
