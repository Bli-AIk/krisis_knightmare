---@class ChapterTitle: Object
local ChapterTitle, super = Class(Object)

function ChapterTitle:init(chapter, onComplete)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self.chapter = chapter
    self.onComplete = onComplete

    self.title_tex = Assets.getTexture("title")
    self.debug_tex = Assets.getTexture("debug")
    self.debug_font = Assets.getFont("main", 12)

    self.timer = self:addChild(Timer())
    self.debug_mode = Mod.info.dev
    self.debug_blocked = false
    self.debug_subtitle_alpha = 0
    self.running = true

    -- 调试参考层 不可被 ctrl+o 选中
    local debug_tex = self.debug_tex
    self.debug_overlay = self:addChild(Object(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT))
    self.debug_overlay.layer = -2
    self.debug_overlay.debug_select = false
    self.debug_overlay.visible = self.debug_mode
    function self.debug_overlay:draw()
        local dw, dh = debug_tex:getDimensions()
        love.graphics.draw(debug_tex, 0, 0, 0, SCREEN_WIDTH / dw, SCREEN_HEIGHT / dh)
    end

    -- 标题子对象 可被 ctrl+o 选中移动缩放
    local title_tex = self.title_tex
    local tw, th = title_tex:getDimensions()
    self.title_child = self:addChild(Object(96, 206.5, tw, th))
    self.title_child.layer = -1
    self.title_child.scale_x = 0.4375
    self.title_child.scale_y = 0.445
    function self.title_child:draw()
        Draw.setColor(1, 1, 1, 1)
        Draw.draw(title_tex, 0, 0)
    end

    self.timer:after(5, function()
        if not self.running then return end
        if self.debug_blocked then
            self.debug_subtitle_alpha = 1
        else
            self:_finish()
        end
    end)
end

function ChapterTitle:_finish()
    self.running = false
    Game.world:closeMenu()
    if self.onComplete then
        self.onComplete()
    end
end

function ChapterTitle:onKeyPressed(key)
    if not self.debug_mode then return end
    if not self.running then return end

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
        self.running = true
        self.timer:after(5, function()
            if not self.running then return end
            if self.debug_blocked then
                self.debug_subtitle_alpha = 1
            else
                self:_finish()
            end
        end)
    end
end

function ChapterTitle:update()
    super.update(self)
    if self.debug_mode and self.debug_subtitle_alpha > 0 and not self.debug_blocked then
        self.debug_subtitle_alpha = math.max(0, self.debug_subtitle_alpha - DT * 3)
    end
end

function ChapterTitle:draw()
    Draw.setColor(0, 0, 0, 1)
    Draw.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    if not self.running then return end

    -- 绘制所有子对象（debug参考层 → 标题）
    self:drawChildren()

    -- 调试提示文字 最上层
    if self.debug_mode and self.debug_subtitle_alpha > 0 then
        love.graphics.setFont(self.debug_font)
        Draw.setColor(1, 1, 1, self.debug_subtitle_alpha)
        Draw.printAlign("Scene transition blocked. Press [C] to continue, [R] to replay.", SCREEN_WIDTH - 10, SCREEN_HEIGHT - 30, "right")
    end
end

return ChapterTitle
