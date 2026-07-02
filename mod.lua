local function loc(default, id, var)
    if Game and Game.loc then
        return Game:loc(default, id, var)
    end
    return default
end

local function chapterNameKey(index)
    return "chapter_select.chapter_" .. tostring(index) .. "_name"
end

local function localizeChapterSelectText(text)
    if type(text) ~= "string" then
        return text
    end

    local chapter_index = text:match("^Chapter%s+(%d+)$")
    if chapter_index then
        return loc("Chapter [var:index]", "chapter_select.chapter_label", {
            index = chapter_index
        })
    end

    local keys = {
        ["Quit"] = "chapter_select.quit",
        ["Options"] = "chapter_select.options",
        ["Play"] = "chapter_select.play",
        ["Do Not"] = "chapter_select.do_not",
    }
    local id = keys[text]
    if id then
        return loc(text, id)
    end

    return text
end

local function updateChapterSelectLocalization(menu)
    if not menu then
        return
    end

    if menu.info and menu.info_defaults then
        menu.info[1] = loc(menu.info_defaults[1], "chapter_select.info_author")
        menu.info[2] = loc(menu.info_defaults[2], "chapter_select.info_project")
    end

    for index, chapter in ipairs(menu.chapters or {}) do
        chapter.name_default = chapter.name_default or chapter.name
        chapter.name_id = chapter.name_id or chapterNameKey(chapter.index or index)
        chapter.name = loc(chapter.name_default, chapter.name_id)
    end
end

function Mod:hookChapterSelectLocalization()
    if self.chapter_select_localization_hooked or not ChapterSelect then
        return
    end
    self.chapter_select_localization_hooked = true

    HookSystem.hook(ChapterSelect, "init", function(orig, menu, ...)
        orig(menu, ...)
        menu.info_defaults = {
            menu.info and menu.info[1] or "TEAM KRISIS",
            menu.info and menu.info[2] or "KRISIS: KNIGHTMARE",
        }
        updateChapterSelectLocalization(menu)
    end)

    HookSystem.hook(ChapterSelect, "loadChapters", function(orig, menu, ...)
        orig(menu, ...)
        for index, chapter in ipairs(menu.chapters or {}) do
            chapter.name_default = chapter.name_default or chapter.name
            chapter.name_id = chapter.name_id or chapterNameKey(chapter.index or index)
        end
        updateChapterSelectLocalization(menu)
    end)

    HookSystem.hook(ChapterSelect, "draw", function(orig, menu, ...)
        updateChapterSelectLocalization(menu)

        local old_print = love.graphics.print
        local old_print_align = Draw.printAlign

        love.graphics.print = function(text, ...)
            return old_print(localizeChapterSelectText(text), ...)
        end
        Draw.printAlign = function(text, ...)
            return old_print_align(localizeChapterSelectText(text), ...)
        end

        local result = { pcall(orig, menu, ...) }
        love.graphics.print = old_print
        Draw.printAlign = old_print_align

        if not result[1] then
            error(result[2])
        end
        return unpack(result, 2)
    end)
end

function Mod:hookWorldMenuRestore()
    if self.world_menu_restore_hooked or not World then
        return
    end
    self.world_menu_restore_hooked = true

    HookSystem.hook(World, "loadMap", function(orig, world, ...)
        local previous_map_id = world.map and world.map.id
        local result = { pcall(orig, world, ...) }
        if not result[1] then
            error(result[2])
        end

        local map_id = world.map and world.map.id
        if previous_map_id == "chapter_select" and map_id ~= "chapter_select" and map_id ~= "options" then
            world.can_open_menu = true
        end

        return unpack(result, 2)
    end)
end

function Mod:init()
    self:hookChapterSelectLocalization()
    self:hookWorldMenuRestore()

    Game:registerEvent("squeak", function(data)
        return Squeak(data.x, data.y, {data.width, data.height, data.polygon})
    end)
    print(loc("Loaded [var:name]!", "mod.loaded", {name = self.info.name}))
end

function Mod:updateBattleLocalization()
    if Game.battle then
        for _, enemy in ipairs(Game.battle.enemies or {}) do
            if enemy.applyLocalization then
                enemy:applyLocalization(true)
            end
        end
        if Game.battle.encounter and Game.battle.encounter.applyLocalization then
            Game.battle.encounter:applyLocalization()
        end
    end
end

function Mod:postUpdate()
    self:hookChapterSelectLocalization()
    self:hookWorldMenuRestore()

    if Game.getLanguage then
        local language = Game:getLanguage()
        if language ~= self.current_language then
            self.current_language = language
            self:updateBattleLocalization()
        end
    end
end

function Mod:onKeyPressed(key, is_repeat)
    if is_repeat or key ~= "f6" or not Game.setLanguage then
        return
    end

    local next_language = Game:getLanguage() == "zh_hans" and "en" or "zh_hans"
    if Game:setLanguage(next_language) then
        self:updateBattleLocalization()

        local message = loc("* Language switched to [var:language].", "mod.language_switched", {
            language = Game:getLanguageName()
        })
        print(message)

        if Game.world and not Game.world:hasCutscene() and not Game.world.menu then
            Game.world:showText(message)
        end

        return true
    end
end
