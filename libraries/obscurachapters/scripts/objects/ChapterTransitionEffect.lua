local ChapterTransitionEffect, super = Class(Object)

---@param chapter ChapterSelect.Chapter
---@param texture love.Drawable
function ChapterTransitionEffect:init(chapter, texture)
    super.init(self,  SCREEN_WIDTH, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self:setOrigin(0.5, 0)
    self.chapter = chapter
    self.texture = texture
    self.clock = 0
    self.title_shown = false
end

function ChapterTransitionEffect:update()
    super.update(self)
    if not self.title_shown then
        self.clock = self.clock + (DT * 0.7)
        if self.clock > 1 then
            self.title_shown = true
            self:remove()
            Game.world:openMenu(ChapterTitle(self.chapter, function()
                Game.fader:fadeOut(function()
                    if Mod and Mod.startKrisisBattlePrep then
                        Mod:startKrisisBattlePrep()
                    else
                        Game.world:loadMap(self.chapter.map)
                    end
                    Game.fader:fadeIn()
                end, {speed = 1})
            end))
        end
    end
end

function ChapterTransitionEffect:onAdd(parent)
    super.onAdd(self, parent)
    Assets.playSound(self.chapter.sound or "ui_spooky_action")
end

function ChapterTransitionEffect:draw()
    super.draw(self)
    if self.title_shown then return end
    Draw.setColor(1,1,1,1-self.clock)
    love.graphics.scale(1-self.clock, 1-(self.clock / 3))
    Draw.draw(self.texture, -SCREEN_WIDTH/2, 0)
end

return ChapterTransitionEffect
