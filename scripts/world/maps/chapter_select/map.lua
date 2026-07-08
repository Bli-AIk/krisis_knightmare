---@class maps.chapter_select : Map
local map, super = Class(Map)

local function openChapterSelect(world)
    world:transitionMusic("AUDIO_DRONE")
    world:openMenu(ChapterSelect())
end

function map:init(world,data)
    super.init(self,world,data)
    self.music = nil
    self.border = "simple"
end
function map:onEnter()
    self.world.player.visible = false
    -- It's the funniest thing ever! If you press F6, you'll see A SINGLE GREEN PIXEL!!!
    self.world.player:setPosition(-4,19)
    self.world.can_open_menu = false

    if Mod.krisis_update_check_seen then
        openChapterSelect(self.world)
        return
    end

    Mod.krisis_update_check_seen = true

    if UpdateCheckSplash then
        self.world:addChild(UpdateCheckSplash(function()
            openChapterSelect(self.world)
        end))
    else
        openChapterSelect(self.world)
    end
end

return map
