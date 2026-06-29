---@class ChapterTitle: Object
local ChapterTitle, super = Class(Object)

function ChapterTitle:init(chapter, onComplete)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self.chapter = chapter
    self.onComplete = onComplete

    self.font = Assets.getFont("main", 32)
    self.name_font = Assets.getFont("main")
    self.debug_font = Assets.getFont("main", 12)

    self.timer = self:addChild(Timer())
    self.text_x = SCREEN_WIDTH + 80
    self.alpha = 1
    self.phase = "slide_in"
    self.debug_mode = Mod.info.dev
    self.debug_blocked = false
    self.debug_subtitle_alpha = 0
    self.running = true

    self:_startSlideIn()
end

function ChapterTitle:_startSlideIn()
    self.phase = "slide_in"
    self.text_x = SCREEN_WIDTH + 80
    self.alpha = 1
    self.timer:tween(0.5, self, {text_x = 0}, "out-quad", function()
        if not self.running then return end
        self.phase = "hold"
        self:_startHold()
    end)
end

function ChapterTitle:_startHold()
    self.phase = "hold"
    self.timer:after(2, function()
        if not self.running then return end
        self:_startFadeOut()
    end)
end

function ChapterTitle:_startFadeOut()
    self.phase = "fade_out"
    self:fadeTo(0, 0.5)
    self.timer:after(0.5, function()
        if not self.running then return end
        if self.debug_blocked then
            self.phase = "blocked"
            self.debug_subtitle_alpha = 1
        else
            self:_finish()
        end
    end)
end

function ChapterTitle:_finish()
    self.running = false
    self.phase = "done"
    Game.world:closeMenu()
    if self.onComplete then
        self.onComplete()
    end
end

function ChapterTitle:onKeyPressed(key)
    if not self.debug_mode then return end
    if self.phase == "done" then return end

    if key == "c" then
        if self.debug_blocked then
            self.debug_subtitle_alpha = 0
            self.debug_blocked = false
            self:_finish()
        else
            self.debug_blocked = true
            if self.phase == "blocked" then
                self.debug_subtitle_alpha = 1
            end
        end
    elseif key == "r" and self.debug_blocked then
        self.debug_subtitle_alpha = 0
        self.alpha = 1
        self.running = true
        self:_startSlideIn()
    end
end

function ChapterTitle:update()
    super.update(self)
    if self.debug_mode and self.debug_subtitle_alpha > 0 and not self.debug_blocked then
        self.debug_subtitle_alpha = math.max(0, self.debug_subtitle_alpha - DT * 3)
    end
end

function ChapterTitle:draw()
    Draw.setColor(0, 0, 0, self.alpha)
    Draw.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    if self.phase == "done" then return end

    love.graphics.push()
    love.graphics.translate(self.text_x, 0)

    love.graphics.setFont(self.font)
    Draw.setColor(Game:getSoulColor())
    Draw.printAlign("CHAPTER " .. self.chapter.index, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 - 30, "center")

    love.graphics.setFont(self.name_font)
    Draw.setColor(COLORS.white)
    Draw.printAlign(self.chapter.name, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 + 10, "center")

    love.graphics.pop()

    if self.debug_mode and self.debug_subtitle_alpha > 0 then
        love.graphics.setFont(self.debug_font)
        Draw.setColor(1, 1, 1, self.debug_subtitle_alpha)
        Draw.printAlign("Scene transition blocked. Press [C] to continue, [R] to replay.", SCREEN_WIDTH - 10, SCREEN_HEIGHT - 30, "right")
    end
end

return ChapterTitle
