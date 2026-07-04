local function loc(default, id, var)
    if Game and Game.loc then
        return Game:loc(default, id, var)
    end
    return default
end

local localizeChapterSelectText
local CHAPTER_SELECT_CJK_TEXT_SPACING = 4

local function isChapterSelectCjkCodepoint(codepoint)
    return (codepoint >= 0x2E80 and codepoint <= 0x9FFF)
        or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
        or (codepoint >= 0xFE10 and codepoint <= 0xFE1F)
        or (codepoint >= 0xFF00 and codepoint <= 0xFFEF)
        or (codepoint >= 0x20000 and codepoint <= 0x2FA1F)
end

local function hasChapterSelectCjkText(text)
    if type(text) ~= "string" or not utf8 or not utf8.codes then
        return false
    end

    for _, codepoint in utf8.codes(text) do
        if isChapterSelectCjkCodepoint(codepoint) then
            return true
        end
    end
    return false
end

local function hasMultipleCodepoints(text)
    if type(text) ~= "string" or not utf8 or not utf8.codes then
        return false
    end

    local count = 0
    for _ in utf8.codes(text) do
        count = count + 1
        if count > 1 then
            return true
        end
    end
    return false
end

local function shouldSpaceChapterSelectCjkText(text)
    return type(text) == "string"
        and hasChapterSelectCjkText(text)
        and hasMultipleCodepoints(text)
end

local function getChapterSelectCjkTextWidth(font, text)
    local width = 0
    for _, codepoint in utf8.codes(text) do
        local char = utf8.char(codepoint)
        width = width + font:getWidth(char)
        if isChapterSelectCjkCodepoint(codepoint) then
            width = width + CHAPTER_SELECT_CJK_TEXT_SPACING
        end
    end
    return width
end

local function printChapterSelectCjkText(print_orig, text, x, y, r, sx, sy, ox, oy, kx, ky)
    local font = love.graphics.getFont()
    local cursor_x = 0
    local cursor_y = 0

    love.graphics.push()
    love.graphics.translate(x or 0, y or 0)
    if r then
        love.graphics.rotate(r)
    end
    love.graphics.scale(sx or 1, sy or sx or 1)
    if kx or ky then
        love.graphics.shear(kx or 0, ky or 0)
    end
    love.graphics.translate(-(ox or 0), -(oy or 0))

    for _, codepoint in utf8.codes(text) do
        local char = utf8.char(codepoint)
        if char == "\n" then
            cursor_x = 0
            cursor_y = cursor_y + font:getHeight()
        else
            print_orig(char, cursor_x, cursor_y)
            cursor_x = cursor_x + font:getWidth(char)
            if isChapterSelectCjkCodepoint(codepoint) then
                cursor_x = cursor_x + CHAPTER_SELECT_CJK_TEXT_SPACING
            end
        end
    end

    love.graphics.pop()
end

local function printChapterSelectText(print_orig, text, ...)
    text = localizeChapterSelectText(text)
    if shouldSpaceChapterSelectCjkText(text) then
        return printChapterSelectCjkText(print_orig, text, ...)
    end
    return print_orig(text, ...)
end

local function printChapterSelectTextAlign(print_orig, print_align_orig, text, x, y, align, r, sx, sy, ox, oy, kx, ky)
    text = localizeChapterSelectText(text)
    if not shouldSpaceChapterSelectCjkText(text) then
        return print_align_orig(text, x, y, align, r, sx, sy, ox, oy, kx, ky)
    end

    local new_line_space = 0
    local new_line_space_height = love.graphics.getFont():getHeight()
    if type(align) == "table" then
        if align["line_offset"] then
            new_line_space_height = new_line_space_height + align["line_offset"]
        end
        if align["align"] then
            align = align["align"]
        end
    end

    for line in string.gmatch(text, "([^\n]+)") do
        local line_width = getChapterSelectCjkTextWidth(love.graphics.getFont(), line)
        local offset_x = 0
        if align == "center" then
            offset_x = (line_width / 2) * (sx or 1)
        elseif align == "right" then
            offset_x = line_width * (sx or 1)
        end

        printChapterSelectCjkText(
            print_orig,
            line,
            x - offset_x,
            y + new_line_space,
            r,
            sx, sy, ox, oy, kx, ky
        )
        new_line_space = new_line_space + new_line_space_height * (sy or 1)
    end
end

local function envFlag(name)
    local value = os.getenv(name)
    if not value then
        return nil
    end

    value = tostring(value):lower()
    return value == "1" or value == "true" or value == "yes" or value == "on"
end

local function chapterNameKey(index)
    return "chapter_select.chapter_" .. tostring(index) .. "_name"
end

localizeChapterSelectText = function(text)
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

local KRISIS_RANDOM_MODULUS = 2147483647

local function normalizeSeedValue(value)
    if value == nil or value == false or value == "" then
        return nil
    end

    if type(value) == "number" then
        return math.floor(math.abs(value)) % KRISIS_RANDOM_MODULUS
    end

    local text = tostring(value)
    local hash = 0
    for i = 1, #text do
        hash = (hash * 131 + text:byte(i)) % KRISIS_RANDOM_MODULUS
    end

    return hash
end

function Mod:getKrisisConfiguredSeed()
    if Game and Game.getConfig then
        return normalizeSeedValue(Game:getConfig("krisisRandomSeed"))
    end

    local kristal_config = self.info
        and self.info.config
        and (self.info.config.kristal or self.info.config.KRISTAL)
        or {}

    return normalizeSeedValue(kristal_config.krisisRandomSeed)
end

function Mod:getConfig(key)
    if key == "krisisDebugRechargeRadial" then
        return envFlag("KRISIS_DEBUG_RECHARGE_RADIAL")
    elseif key == "krisisDebugRechargeRadialCapture" then
        return envFlag("KRISIS_DEBUG_RECHARGE_RADIAL_CAPTURE")
    elseif key == "krisisDebugRechargeRadialQuit" then
        return envFlag("KRISIS_DEBUG_RECHARGE_RADIAL_QUIT")
    end

    if key == "mercyMessages"
        and Game
        and Game.battle
        and Game.battle.encounter
        and Game.battle.encounter.isRechargeMercyDisplayActive
        and Game.battle.encounter:isRechargeMercyDisplayActive()
    then
        return true
    end
end

function Mod:getKrisisRunSeed()
    if self.krisis_run_seed then
        return self.krisis_run_seed
    end

    local configured_seed = self:getKrisisConfiguredSeed()
    if configured_seed then
        self.krisis_run_seed = configured_seed
        self.krisis_random_fixed = true
    else
        local seed = os.time()
        if love and love.math and love.math.random then
            seed = seed + love.math.random(1, 1000000)
        end
        if love and love.timer and love.timer.getTime then
            seed = seed + math.floor(love.timer.getTime() * 1000)
        end
        self.krisis_run_seed = seed % KRISIS_RANDOM_MODULUS
        self.krisis_random_fixed = false
    end

    self.krisis_seed_counter = 0
    return self.krisis_run_seed
end

function Mod:nextKrisisRandomSeed(label)
    local base_seed = self:getKrisisRunSeed()
    local label_seed = normalizeSeedValue(label or "krisis") or 0

    self.krisis_seed_counter = (self.krisis_seed_counter or 0) + 1

    return (base_seed + label_seed * 9176 + self.krisis_seed_counter * 1009) % KRISIS_RANDOM_MODULUS
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
            return printChapterSelectText(old_print, text, ...)
        end
        Draw.printAlign = function(text, ...)
            return printChapterSelectTextAlign(old_print, old_print_align, text, ...)
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
