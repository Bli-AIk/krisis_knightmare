---@class ChapterTitle: Object
local ChapterTitle, super = Class(Object)

local FRAME_DIR = Mod.info.path .. "/libraries/chapter_title/assets/frames/"
local FPS = 30
local TOTAL_FRAMES = 464
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
    self.frame_timer = 0

    -- 渐出
    self.fading_out = false
    self.fade_timer = 0

    self.debug_mode = Mod.info.dev
    self.debug_font = Assets.getFont("main", 12)
    self.debug_blocked = false
    self.debug_subtitle_alpha = 0
    self.running = true
    self.ended = false

    self:_nextFrame()
end

function ChapterTitle:_framePath(n)
    return FRAME_DIR .. string.format("f_%03d.png", n)
end

function ChapterTitle:_nextFrame()
    self.frame = self.frame + 1
    if self.frame > TOTAL_FRAMES then
        if self.debug_blocked then
            self.debug_subtitle_alpha = 1
        else
            self:_finish()
        end
        return
    end
    local path = self:_framePath(self.frame)
    local info = love.filesystem.getInfo(path)
    if not info then
        return
    end
    -- 只加载存在的帧，缺失帧保留上一帧
    if self.cur_img then
        self.cur_img:release()
    end
    self.cur_img = love.graphics.newImage(path)
    self.cur_sx = SCREEN_WIDTH / self.cur_img:getWidth()
    self.cur_sy = SCREEN_HEIGHT / self.cur_img:getHeight()
end

function ChapterTitle:_reset()
    self.frame = 0
    self.frame_timer = 0
    self.fading_out = false
    self.fade_timer = 0
    self.ended = false
    self.running = true
    self:_nextFrame()
end

function ChapterTitle:_finish()
    self.running = false
    self.ended = true
    Game.world:closeMenu()
    if self.onComplete then
        self.onComplete()
    end
end

function ChapterTitle:onKeyPressed(key)
    if self.ended then return end

    if key == "z" then
        self.fading_out = true
        self.fade_timer = 0
        self.running = false
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
        if self.fade_timer >= FADE_DURATION then
            self.fading_out = false
            self:_finish()
        end
        return
    end

    if not self.running then return end

    self.frame_timer = self.frame_timer + DT
    if self.frame_timer >= 1 / FPS then
        self.frame_timer = self.frame_timer - 1 / FPS
        self:_nextFrame()
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
        Draw.setColor(1, 1, 1, 1)
        Draw.draw(self.cur_img, 0, 0, 0, self.cur_sx, self.cur_sy)
    end

    if self.fading_out then
        local alpha = math.min(self.fade_timer / FADE_DURATION, 1)
        Draw.setColor(0, 0, 0, alpha)
        Draw.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    end

    if self.debug_mode and self.debug_subtitle_alpha > 0 then
        love.graphics.setFont(self.debug_font)
        Draw.setColor(1, 1, 1, self.debug_subtitle_alpha)
        Draw.printAlign("Scene transition blocked. Press [C] to continue, [R] to replay.", SCREEN_WIDTH - 10, SCREEN_HEIGHT - 30, "right")
    end
end

return ChapterTitle
