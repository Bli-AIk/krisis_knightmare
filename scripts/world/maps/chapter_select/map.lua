---@class maps.chapter_select : Map
local map, super = Class(Map)

local function openChapterSelect(world)
    world:transitionMusic("AUDIO_DRONE")
    world:openMenu(ChapterSelect())
end

local function openIntro(world)
    if Mod.krisis_intro_seen then
        openChapterSelect(world)
        return
    end

    Mod.krisis_intro_seen = true
    if world.music then
        world.music:stop()
    end

    if Project4Scene then
        world:addChild(Project4Scene({
            on_complete = function()
                openChapterSelect(world)
            end,
        }))
    else
        openChapterSelect(world)
    end
end

local function openIntroAfterUpdateCheck(world)
    if Mod.krisis_update_check_seen then
        openIntro(world)
        return
    end

    Mod.krisis_update_check_seen = true
    if UpdateCheckSplash then
        world:addChild(UpdateCheckSplash(function()
            openIntro(world)
        end))
    else
        openIntro(world)
    end
end

local function hasDefaultEncounter()
    return Kristal and Kristal.getModOption and Kristal.getModOption("encounter") ~= nil
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

    if hasDefaultEncounter() then
        Mod.krisis_update_check_seen = true
        Mod.krisis_intro_seen = true
        return
    end

    if Mod.krisis_update_check_seen then
        openIntro(self.world)
        return
    end

    Mod.krisis_update_check_seen = true
    if UpdateCheckSplash then
        self.world:addChild(UpdateCheckSplash(function()
            openIntro(self.world)
        end))
    else
        openIntro(self.world)
    end
end

return map
