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

    if OverworldScene then
        world:addChild(OverworldScene({
            on_complete = function()
                openChapterSelect(world)
            end,
        }))
    else
        openChapterSelect(world)
    end
end

local UPDATE_CHECK_BLACK_DELAY = 2.0

local function startIntroAfterUpdateCheck(world)
    local black_screen = Rectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    black_screen.layer = 1000000
    black_screen:setColor(0, 0, 0)
    world:addChild(black_screen)

    local function continueToIntro()
        black_screen:remove()
        openIntro(world)
    end

    if world.timer then
        world.timer:after(UPDATE_CHECK_BLACK_DELAY, continueToIntro)
    else
        continueToIntro()
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
            startIntroAfterUpdateCheck(self.world)
        end))
    else
        openIntro(self.world)
    end
end

return map
