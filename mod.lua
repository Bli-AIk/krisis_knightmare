local function escapeLocPattern(value)
    return tostring(value):gsub("([^%w])", "%%%1")
end

local function applyLocVars(text, vars)
    if type(text) ~= "string" or type(vars) ~= "table" then
        return text
    end

    for key, value in pairs(vars) do
        text = text:gsub("%[var:" .. escapeLocPattern(key) .. "%]", tostring(value))
    end
    return text
end

local function ensureLocalizationFallbacks()
    if not Game then
        return
    end

    -- Kristal v0.10 runs mod.lua before localization libraries install these helpers.
    if not Game.loc then
        function Game:loc(default, id, var)
            return applyLocVars(default, var)
        end
    end

    if not Game.locName then
        function Game:locName(category, id, default)
            return tostring(default or id)
        end
    end
end

ensureLocalizationFallbacks()

local function loc(default, id, var)
    ensureLocalizationFallbacks()
    if Game and Game.loc then
        return Game:loc(default, id, var)
    end
    return applyLocVars(default, var)
end

local localizeChapterSelectText
local CHAPTER_SELECT_CJK_TEXT_SPACING = 4
local VESSEL_ATTACK_SOUND = "vessel_thunder"

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

local function getKristalArg(name)
    local args = Kristal and Kristal.Args and Kristal.Args[name]
    if type(args) ~= "table" then
        return nil, false
    end

    return args[1], true
end

local function parsePositiveInteger(value)
    local number = tonumber(value)
    if not number then
        return nil
    end

    number = math.floor(number)
    if number < 1 then
        return nil
    end

    return number
end

local function parseNonNegativeNumber(value)
    local number = tonumber(value)
    if not number or number < 0 then
        return nil
    end

    return number
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
local KRISIS_RANDOM_MULTIPLIER = 48271
local KRISIS_SEED_ENTRY_MUSIC = {
    [1] = "man",
    [2] = "man",
    [3] = "man_nes",
    [4] = "man_2",
    [5] = "deltarune_piano_collections_by_trevor_alan_gomes",
}
local KRISIS_SEED_ENTRY_CHANCE = 50
local KRISIS_CHAPTER3_LEFT_TARGET = 100
local KRISIS_CHAPTER4_RIGHT_TARGET = 100
local KRISIS_CHAPTER4_ZX_TARGET = 8
local KRISIS_CHAPTER5_ALTERNATIONS_TARGET = 5
local KRISIS_SEED_DIGIT_COUNT = 10
local KRISIS_SEED_ENTRY_REACTION_TIME = 1
local KRISIS_SEED_TRANSITION_TIME = 0.75
local KRISIS_SEED_SLIDE_TIME = 0.35

local function normalizeSeedValue(value)
    if value == nil or value == false or value == "" then
        return nil
    end

    if type(value) == "number" then
        return math.floor(math.abs(value)) % KRISIS_RANDOM_MODULUS
    end

    local text = tostring(value)
    if text:match("^%d+$") then
        local seed = 0
        for i = 1, #text do
            seed = (seed * 10 + text:byte(i) - string.byte("0")) % KRISIS_RANDOM_MODULUS
        end
        return seed
    end

    local hash = 0
    for i = 1, #text do
        hash = (hash * 131 + text:byte(i)) % KRISIS_RANDOM_MODULUS
    end

    return hash
end

local function getSeedDisplayValue(value, seed)
    if type(value) == "string" and value ~= "" then
        return value
    end

    return tostring(seed)
end

function Mod:getKrisisConfiguredSeed()
    local configured_value
    if Game and Game.getConfig then
        configured_value = Game:getConfig("krisisRandomSeed")
        local configured_seed = normalizeSeedValue(configured_value)
        if configured_seed ~= nil then
            return configured_seed, getSeedDisplayValue(configured_value, configured_seed)
        end
    end

    local kristal_config = self.info
        and self.info.config
        and (self.info.config.kristal or self.info.config.KRISTAL)
        or {}

    configured_value = kristal_config.krisisRandomSeed
    local configured_seed = normalizeSeedValue(configured_value)
    if configured_seed ~= nil then
        return configured_seed, getSeedDisplayValue(configured_value, configured_seed)
    end
end

function Mod:getConfig(key)
    if key == "krisisInitialTP" then
        self:loadKrisisRunOptions()
        if self.krisis_run_initial_tp ~= nil then
            return self.krisis_run_initial_tp
        end
    elseif key == "krisisDebugRechargeRadial" then
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

    local configured_seed, configured_seed_display = self:getKrisisConfiguredSeed()
    if configured_seed ~= nil then
        self.krisis_run_seed = configured_seed
        self.krisis_run_seed_display = configured_seed_display
        self.krisis_random_fixed = true
    else
        local seed = os.time()
        if love and love.timer and love.timer.getTime then
            seed = seed + math.floor(love.timer.getTime() * 1000)
        end
        if love and love.math and love.math.random then
            seed = seed + love.math.random(1, KRISIS_RANDOM_MODULUS - 1)
        end

        self.krisis_run_seed = seed % KRISIS_RANDOM_MODULUS
        if self.krisis_run_seed == 0 then
            self.krisis_run_seed = 1
        end
        self.krisis_random_fixed = false
        self.krisis_run_seed_display = nil
        print("[KRISIS] Generated random seed: " .. tostring(self.krisis_run_seed))
    end

    self.krisis_seed_counter = 0
    return self.krisis_run_seed
end

function Mod:getKrisisRandomStream(label)
    self:getKrisisRunSeed()
    self.krisis_random_streams = self.krisis_random_streams or {}

    label = tostring(label or "krisis")
    local stream = self.krisis_random_streams[label]
    if stream then
        return stream
    end

    local label_seed = normalizeSeedValue(label) or 0
    local state = (self.krisis_run_seed + label_seed * 9176 + 1009) % KRISIS_RANDOM_MODULUS
    if state == 0 then
        state = 1
    end

    stream = {
        state = state,
    }

    function stream:nextFloat()
        self.state = (self.state * KRISIS_RANDOM_MULTIPLIER) % KRISIS_RANDOM_MODULUS
        return self.state / KRISIS_RANDOM_MODULUS
    end

    function stream:random(min, max)
        local value = self:nextFloat()
        if min == nil then
            return value
        end

        if max == nil then
            max = math.floor(min)
            min = 1
        else
            min = math.ceil(min)
            max = math.floor(max)
        end

        assert(min <= max, "invalid KRISIS random range")
        return min + math.floor(value * (max - min + 1))
    end

    self.krisis_random_streams[label] = stream
    return stream
end

function Mod:randomKrisis(label, min, max)
    return self:getKrisisRandomStream(label):random(min, max)
end

function Mod:setKrisisRunSeed(value)
    local seed = normalizeSeedValue(value)
    assert(seed ~= nil, "A KRISIS seed must be a number or non-empty string.")

    self.krisis_run_seed = seed
    self.krisis_run_seed_display = getSeedDisplayValue(value, seed)
    self.krisis_random_fixed = true
    self.krisis_random_streams = {}
    self.krisis_seed_counter = 0
    self:updateKrisisWindowTitle()
    return seed
end

function Mod:getKrisisSeedPasscodeDefault()
    if not self.krisis_random_fixed then
        return string.rep("0", KRISIS_SEED_DIGIT_COUNT)
    end

    local display = tostring(self.krisis_run_seed_display or "")
    if display:match("^%d+$") and #display <= KRISIS_SEED_DIGIT_COUNT then
        return string.rep("0", KRISIS_SEED_DIGIT_COUNT - #display) .. display
    end

    return string.format("%0" .. KRISIS_SEED_DIGIT_COUNT .. "d", self:getKrisisRunSeed())
end

function Mod:updateKrisisWindowTitle()
    if not love or not love.window or not love.window.setTitle then
        return
    end

    local base_title = self.info and self.info.name or "KRISIS: KNIGHTMARE"
    if Kristal and Kristal.getDesiredWindowTitle then
        base_title = Kristal.getDesiredWindowTitle()
    end

    local title = tostring(base_title)
    if self.krisis_random_fixed then
        title = title .. " | " .. tostring(self.krisis_run_seed_display or self:getKrisisRunSeed())
    end
    if not love.window.getTitle or love.window.getTitle() ~= title then
        love.window.setTitle(title)
    end
end

local function getSelectedChapterIndex(menu)
    local chapter = menu and menu.chapters and menu.chapters[menu.selected_y]
    return chapter and chapter.index or nil
end

function Mod:clearChapterSeedInput()
    if not Input or not Input.clear then
        return
    end

    Input.clear("confirm", true)
    Input.clear("cancel", true)
    Input.clear("left", true)
    Input.clear("right", true)
    Input.clear("up", true)
    Input.clear("down", true)
end

function Mod:stopChapterSeedMusic()
    if Game and Game.world and Game.world.music then
        Game.world.music:stop()
    end
end

function Mod:playChapterSeedMusic(chapter_index)
    local music = KRISIS_SEED_ENTRY_MUSIC[chapter_index]
    if music and Game and Game.world and Game.world.music then
        Game.world.music:play(music)
    end
end

function Mod:resetChapterSeedInputState(menu)
    if not menu then
        return
    end

    menu.krisis_seed_input_chapter = nil
    menu.krisis_seed_chapter3_left_count = 0
    menu.krisis_seed_chapter4_right_count = 0
    menu.krisis_seed_chapter4_armed = false
    menu.krisis_seed_chapter4_expect_confirm = true
    menu.krisis_seed_chapter4_zx_count = 0
    menu.krisis_seed_chapter5_last_direction = nil
    menu.krisis_seed_chapter5_alternations = 0
end

function Mod:prepareChapterSeedInputState(menu, chapter_index)
    if menu.krisis_seed_input_chapter ~= chapter_index then
        self:resetChapterSeedInputState(menu)
        menu.krisis_seed_input_chapter = chapter_index
    end
end

function Mod:isChapterSeedEntryBusy(menu)
    return self.seed_passcode_menu ~= nil
        or self.seed_passcode_closing
        or (menu and menu.krisis_seed_entry_transitioning)
end

function Mod:openChapterSeedPasscode(menu, chapter_index)
    if self.seed_passcode_menu then
        return
    end

    if menu then
        menu.x = 0
    end

    self.seed_passcode_menu = SeedPasscodeMenu(function(seed)
        self:closeChapterSeedPasscode(menu, seed)
    end, function()
        self:closeChapterSeedPasscode(menu)
    end, self:getKrisisSeedPasscodeDefault())
    Game.world:addChild(self.seed_passcode_menu)
    self:playChapterSeedMusic(chapter_index)
    self:clearChapterSeedInput()
    Game.fader:fadeIn(nil, { speed = KRISIS_SEED_TRANSITION_TIME, music = false })
end

function Mod:beginChapterSeedEntry(menu, chapter_index, slide_left)
    if self:isChapterSeedEntryBusy(menu) then
        return
    end

    menu.krisis_seed_entry_transitioning = true
    self:stopChapterSeedMusic()

    local function fade_to_passcode()
        Game.fader:fadeOut(nil, { speed = KRISIS_SEED_TRANSITION_TIME, music = false })
        local function open_passcode()
            self:openChapterSeedPasscode(menu, chapter_index)
        end
        if menu.timer then
            menu.timer:after(KRISIS_SEED_TRANSITION_TIME, open_passcode)
        else
            open_passcode()
        end
    end

    local function start_transition()
        if slide_left and menu.timer then
            menu.timer:tween(KRISIS_SEED_SLIDE_TIME, menu, { x = -SCREEN_WIDTH }, "in-quad", fade_to_passcode)
        else
            fade_to_passcode()
        end
    end

    if menu.timer then
        menu.timer:after(KRISIS_SEED_ENTRY_REACTION_TIME, start_transition)
    else
        start_transition()
    end
end

function Mod:closeChapterSeedPasscode(menu, seed)
    if self.seed_passcode_closing then
        return
    end

    self.seed_passcode_closing = true
    self:stopChapterSeedMusic()
    Game.fader:fadeOut(nil, { speed = KRISIS_SEED_TRANSITION_TIME, music = false })

    local function finish_close()
        if seed then
            self:setKrisisRunSeed(seed)
        end

        if self.seed_passcode_menu then
            self.seed_passcode_menu:remove()
        end
        self.seed_passcode_menu = nil

        if menu then
            menu.x = 0
            menu.selected_x = 1
            menu.state = "SELECT"
            menu.krisis_seed_entry_transitioning = false
            self:resetChapterSeedInputState(menu)
        end

        self:clearChapterSeedInput()
        Game.fader:fadeIn(nil, { speed = KRISIS_SEED_TRANSITION_TIME, music = false })

        local function unlock_menu()
            self.seed_passcode_closing = false
            if Game.world and Game.world.transitionMusic then
                Game.world:transitionMusic("AUDIO_DRONE")
            end
        end
        if menu and menu.timer then
            menu.timer:after(KRISIS_SEED_TRANSITION_TIME, unlock_menu)
        else
            unlock_menu()
        end
    end

    if menu and menu.timer then
        menu.timer:after(KRISIS_SEED_TRANSITION_TIME, finish_close)
    else
        finish_close()
    end
end

function Mod:handleChapterSeedPasscodeInput(menu, key)
    if not self:isChapterSeedEntryBusy(menu) then
        return false
    end

    if self.seed_passcode_menu
        and not self.seed_passcode_closing
        and Input.isCancel(key)
    then
        self.seed_passcode_menu:cancel()
    end
    return true
end

function Mod:handleChapterSeedInput(menu, key)
    if menu.state ~= "CHAPTER" then
        self:resetChapterSeedInputState(menu)
        return false
    end

    local chapter_index = getSelectedChapterIndex(menu)
    if chapter_index ~= 3 and chapter_index ~= 4 and chapter_index ~= 5 then
        self:resetChapterSeedInputState(menu)
        return false
    end

    self:prepareChapterSeedInputState(menu, chapter_index)

    if chapter_index == 3 and Input.is("left", key) then
        menu.krisis_seed_chapter3_left_count = menu.krisis_seed_chapter3_left_count + 1
        if menu.krisis_seed_chapter3_left_count >= KRISIS_CHAPTER3_LEFT_TARGET then
            Assets.playSound("snd_flee")
            self:beginChapterSeedEntry(menu, chapter_index)
            return true
        end
    elseif chapter_index == 4 then
        if menu.krisis_seed_chapter4_armed then
            local expects_confirm = menu.krisis_seed_chapter4_expect_confirm
            if Input.isConfirm(key) and expects_confirm then
                menu.krisis_seed_chapter4_expect_confirm = false
                return true
            elseif Input.isCancel(key) and not expects_confirm then
                menu.krisis_seed_chapter4_expect_confirm = true
                menu.krisis_seed_chapter4_zx_count = menu.krisis_seed_chapter4_zx_count + 1
                if menu.krisis_seed_chapter4_zx_count >= KRISIS_CHAPTER4_ZX_TARGET then
                    self:beginChapterSeedEntry(menu, chapter_index)
                end
                return true
            elseif Input.isConfirm(key) or Input.isCancel(key) then
                menu.krisis_seed_chapter4_expect_confirm = true
                menu.krisis_seed_chapter4_zx_count = 0
                return true
            end
        elseif Input.is("right", key) then
            menu.krisis_seed_chapter4_right_count = menu.krisis_seed_chapter4_right_count + 1
            if menu.krisis_seed_chapter4_right_count >= KRISIS_CHAPTER4_RIGHT_TARGET then
                menu.krisis_seed_chapter4_armed = true
                menu.krisis_seed_chapter4_expect_confirm = true
                menu.krisis_seed_chapter4_zx_count = 0
                self:stopChapterSeedMusic()
                return true
            end
        end
    elseif chapter_index == 5 and (Input.is("left", key) or Input.is("right", key)) then
        local direction = Input.is("left", key) and "left" or "right"
        local previous = menu.krisis_seed_chapter5_last_direction
        if previous and previous ~= direction then
            menu.krisis_seed_chapter5_alternations = menu.krisis_seed_chapter5_alternations + 1
        else
            menu.krisis_seed_chapter5_alternations = 0
        end
        menu.krisis_seed_chapter5_last_direction = direction

        if menu.krisis_seed_chapter5_alternations >= KRISIS_CHAPTER5_ALTERNATIONS_TARGET then
            self:beginChapterSeedEntry(menu, chapter_index, true)
            return true
        end
    end

    return false
end

function Mod:trackChapterSeedEntry(menu, old_state, old_chapter_index)
    if old_state ~= "CHAPTER"
        or menu.state ~= "SELECT"
        or (old_chapter_index ~= 1 and old_chapter_index ~= 2)
    then
        return
    end

    if self:randomKrisis("chapter_seed_entry", 1, KRISIS_SEED_ENTRY_CHANCE) == 1 then
        self:beginChapterSeedEntry(menu, old_chapter_index)
    end
end

function Mod:hookChapterSeedInput()
    if self.chapter_seed_input_hooked or not ChapterSelect or not SeedPasscodeMenu then
        return
    end
    self.chapter_seed_input_hooked = true

    HookSystem.hook(ChapterSelect, "onKeyPressed", function(orig, menu, key, ...)
        if self:handleChapterSeedPasscodeInput(menu, key) then
            return
        end
        if self:handleChapterSeedInput(menu, key) then
            return
        end

        local old_state = menu.state
        local old_chapter_index = getSelectedChapterIndex(menu)
        local result = { pcall(orig, menu, key, ...) }
        if not result[1] then
            error(result[2])
        end

        self:trackChapterSeedEntry(menu, old_state, old_chapter_index)
        return (table.unpack or unpack)(result, 2)
    end)
end

function Mod:hookItemTossRandom()
    if self.item_toss_random_hooked or not Item or not love or not love.math then
        return
    end
    self.item_toss_random_hooked = true

    HookSystem.hook(Item, "onToss", function(orig, item, ...)
        local original_random = love.math.random
        love.math.random = function(min, max)
            return self:randomKrisis("item_toss", min, max)
        end

        local result = { pcall(orig, item, ...) }
        love.math.random = original_random

        if not result[1] then
            error(result[2])
        end
        return (table.unpack or unpack)(result, 2)
    end)
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

function Mod:hookTemporaryDefaultBattleEntry()
    if self.temporary_default_battle_entry_hooked or not Kristal then
        return
    end
    self.temporary_default_battle_entry_hooked = true

    HookSystem.hook(Kristal, "getModOption", function(orig, key, ...)
        if key == "encounter" and Kristal.krisis_default_battle_entry then
            return Kristal.krisis_default_battle_entry
        end
        if key == "map" and (Kristal.krisis_default_battle_entry or orig("encounter")) then
            return nil
        end
        return orig(key, ...)
    end)
end

function Mod:queueSuppressVesselAttackSound()
    self.suppress_next_vessel_attack_sound = true
end

function Mod:hookVesselAttackSound()
    if self.vessel_attack_sound_hooked or not Assets then
        return
    end
    self.vessel_attack_sound_hooked = true

    HookSystem.hook(Assets, "stopAndPlaySound", function(orig, sound, volume, pitch, actually_stop)
        if self.suppress_next_vessel_attack_sound then
            self.suppress_next_vessel_attack_sound = false
            if sound == VESSEL_ATTACK_SOUND then
                return orig(sound, 0, pitch, actually_stop)
            end
        end

        return orig(sound, volume, pitch, actually_stop)
    end)
end

function Mod:setTemporaryDefaultBattleEntry(encounter)
    self.krisis_default_battle_entry = encounter
    if Kristal then
        Kristal.krisis_default_battle_entry = encounter
    end
    if self.info then
        self.info.encounter = encounter
    end
end

function Mod:loadKrisisRunOptions()
    if self.krisis_run_options_loaded then
        return
    end
    self.krisis_run_options_loaded = true

    local encounter, has_encounter = getKristalArg("encounter")
    if has_encounter then
        self:setTemporaryDefaultBattleEntry(encounter or "kris")
    end

    local wave, has_wave = getKristalArg("wave")
    local wave_force, has_wave_force = getKristalArg("wave-force")
    local initial_tp, has_initial_tp = getKristalArg("tp")
    if not has_initial_tp then
        initial_tp, has_initial_tp = getKristalArg("initial-tp")
    end

    if has_wave then
        self.krisis_run_wave = parsePositiveInteger(wave)
        if not self.krisis_run_wave then
            print("Ignoring invalid --wave value: " .. tostring(wave))
        end
    end

    if has_wave_force then
        self.krisis_run_wave_force = parsePositiveInteger(wave_force)
        if not self.krisis_run_wave_force then
            print("Ignoring invalid --wave-force value: " .. tostring(wave_force))
        end
    end

    if has_initial_tp then
        self.krisis_run_initial_tp = parseNonNegativeNumber(initial_tp)
        if self.krisis_run_initial_tp == nil then
            print("Ignoring invalid --tp value: " .. tostring(initial_tp))
        end
    end

    if (self.krisis_run_wave or self.krisis_run_wave_force or self.krisis_run_initial_tp ~= nil)
        and not has_encounter
    then
        self:setTemporaryDefaultBattleEntry("kris")
    end
end

function Mod:getKrisisRunWaveOptions()
    self:loadKrisisRunOptions()
    return self.krisis_run_wave, self.krisis_run_wave_force
end

function Mod:init()
    self:hookTemporaryDefaultBattleEntry()
    self:hookChapterSelectLocalization()
    self:hookChapterSeedInput()
    self:hookWorldMenuRestore()
    self:hookVesselAttackSound()
    self:hookItemTossRandom()
    self:loadKrisisRunOptions()
    self:getKrisisRunSeed()
    self:updateKrisisWindowTitle()

    if (envFlag("KRISIS_FINISHER_PROFILE") or envFlag("KRISIS_PROFILE")) and FinisherProfiler then
        self.finisher_profiler = FinisherProfiler()
    end

    Game:registerEvent("squeak", function(data)
        return Squeak(data.x, data.y, {data.width, data.height, data.polygon})
    end)
    print(loc("Loaded [var:name]!", "mod.loaded", {name = self.info.name}))
end

function Mod:preUpdate()
    if self.finisher_profiler then
        self.finisher_profiler:preUpdate()
    end
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
    self:hookTemporaryDefaultBattleEntry()
    self:hookChapterSelectLocalization()
    self:hookChapterSeedInput()
    self:hookWorldMenuRestore()
    self:hookVesselAttackSound()
    self:updateKrisisWindowTitle()

    if Game.getLanguage then
        local language = Game:getLanguage()
        local name_style = Game.getNameStyle and Game:getNameStyle() or nil
        if language ~= self.current_language or name_style ~= self.current_name_style then
            self.current_language = language
            self.current_name_style = name_style
            self:updateBattleLocalization()
        end
    end

    if self.finisher_profiler then
        self.finisher_profiler:postUpdate()
    end
end

function Mod:preDraw()
    if self.finisher_profiler then
        self.finisher_profiler:preDraw()
    end
end

function Mod:postDraw()
    if self.finisher_profiler then
        self.finisher_profiler:postDraw()
    end
end

function Mod:onKeyPressed(key, is_repeat)
    -- F6 is reserved by Kristal for debug rendering.
    if is_repeat or key ~= "f7" or not Game.setLanguage then
        return
    end

    local next_language = Game:getLanguage() == "zh_hans" and "en" or "zh_hans"
    if Game:setLanguage(next_language) then
        self:updateBattleLocalization()

        local message = loc("* Language switched to [var:language].", "mod.language_switched", {
            language = Game:getLanguageName()
        })
        print(message)

        if Game.world and Game.world.player and not Game.world:hasCutscene() and not Game.world.menu then
            Game.world:showText(message)
        end

        return true
    end
end
