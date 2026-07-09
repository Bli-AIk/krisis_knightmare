---@class ChapterSelect: Object
local ChapterSelect, super = Class(Object)

local NAME_STYLE_TRANSLATED = "translated"
local NAME_STYLE_ORIGINAL = "original"
local NAME_STYLE_PROMPT_FADE_IN = 0.25
local NAME_STYLE_PROMPT_HOLD = 1
local NAME_STYLE_PROMPT_FADE_OUT = 0.35
local NAME_STYLE_PROMPT_DURATION = NAME_STYLE_PROMPT_FADE_IN + NAME_STYLE_PROMPT_HOLD + NAME_STYLE_PROMPT_FADE_OUT
local NAME_STYLE_LABELS = {
    [NAME_STYLE_TRANSLATED] = "人名翻译版",
    [NAME_STYLE_ORIGINAL] = "人名原文版",
}
local NAME_STYLE_LABEL_COLORS = {
    [NAME_STYLE_TRANSLATED] = { 1, 0.45, 0.95 },
    [NAME_STYLE_ORIGINAL] = { 1, 1, 0 },
}
local NAME_STYLE_PROMPT_COLOR_CURRENT = { 0.45, 1, 0.45 }
local NAME_STYLE_PROMPT_COLOR_KEY = { 0, 0.95, 1 }
local NAME_STYLE_PROMPT_COLOR_TEXT = { 1, 1, 1 }
local NAME_STYLE_PROMPT_CJK_TEXT_SPACING = 4
local KRIS_SHORTCUT_CHAPTER_INDEX = 6
local KRIS_SHORTCUT_SEQUENCE_MAX_GAP = 0.55
local KRIS_SHORTCUT_PROMPT_INPUT_DELAY = 0.5
local KRIS_SHORTCUT_HOLD_TIME = 0.65
local KRIS_SHORTCUT_SEQUENCE = { "confirm", "cancel", "confirm", "cancel", "confirm", "cancel" }
local KRIS_SHORTCUT_YELLOW = { 1, 1, 0 }
local KRIS_SHORTCUT_WHITE = { 1, 1, 1 }

local function loc(default, id, vars)
    if Game and Game.loc then
        return Game:loc(default, id, vars)
    end

    if type(default) == "string" and type(vars) == "table" then
        for key, value in pairs(vars) do
            default = default:gsub("%[var:" .. tostring(key) .. "%]", tostring(value))
        end
    end
    return default
end

local function isNameStylePromptCjkCodepoint(codepoint)
    return (codepoint >= 0x2E80 and codepoint <= 0x9FFF)
        or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
        or (codepoint >= 0xFE10 and codepoint <= 0xFE1F)
        or (codepoint >= 0xFF00 and codepoint <= 0xFFEF)
        or (codepoint >= 0x20000 and codepoint <= 0x2FA1F)
end

local function getNameStylePromptTextWidth(font, text)
    local width = 0
    for _, codepoint in utf8.codes(text) do
        local char = utf8.char(codepoint)
        width = width + font:getWidth(char)
        if isNameStylePromptCjkCodepoint(codepoint) then
            width = width + NAME_STYLE_PROMPT_CJK_TEXT_SPACING
        end
    end
    return width
end

local function drawNameStylePromptText(text, x, y)
    local font = love.graphics.getFont()
    local cursor_x = 0

    for _, codepoint in utf8.codes(text) do
        local char = utf8.char(codepoint)
        love.graphics.print(char, x + cursor_x, y)
        cursor_x = cursor_x + font:getWidth(char)
        if isNameStylePromptCjkCodepoint(codepoint) then
            cursor_x = cursor_x + NAME_STYLE_PROMPT_CJK_TEXT_SPACING
        end
    end
end

local function getPromptSegmentsWidth(font, segments)
    local width = 0
    for _, segment in ipairs(segments) do
        width = width + getNameStylePromptTextWidth(font, tostring(segment.text or ""))
    end
    return width
end

local function drawPromptSegments(segments, x, y, align, alpha)
    local font = love.graphics.getFont()
    local width = getPromptSegmentsWidth(font, segments)
    local cursor_x = x

    if align == "center" then
        cursor_x = x - (width / 2)
    elseif align == "right" then
        cursor_x = x - width
    end

    for _, segment in ipairs(segments) do
        local text = tostring(segment.text or "")
        local color = segment.color or KRIS_SHORTCUT_WHITE
        Draw.setColor(color[1], color[2], color[3], alpha or 1)
        drawNameStylePromptText(text, cursor_x, y)
        cursor_x = cursor_x + getNameStylePromptTextWidth(font, text)
    end
end

local function cleanInputText(text, fallback)
    text = tostring(text or fallback or "")
    text = text:gsub("^%[", ""):gsub("%]$", "")
    return text ~= "" and text or tostring(fallback or "")
end

---@class ChapterSelect.Chapter
---@field sound string|love.sound
---@field image string|love.Image
---@field unlocked boolean?
---@field instant boolean?
---@field map string?
---@field name string
---@field index integer
---@field shadow_crystal_flag string
---@field slots ChapterSelect.SaveSlot[]?

---@class ChapterSelect.SaveSlot
---@field normal_file boolean
---@field completion_file boolean
---@field shadow_crystal boolean

function ChapterSelect:init()
    super.init(self,0,0,SCREEN_WIDTH,SCREEN_HEIGHT)
    self:updateFonts(true)
    self:loadChapters()
    self.info = {
        Kristal.getLibConfig("obscurachapters", "infoAuthor") or ("By: " .. (Mod.info.author or "Unknown")),
        Kristal.getLibConfig("obscurachapters", "infoProject") or (
            Mod.info.name .. " " .. (Kristal.getLibConfig("obscurachapters", "infoVersion") or Mod.info.version)
        ),
    }
    self.selected_x = 1
    self.selected_y = 1
    self.heart = Assets.getTexture("player/heart_menu")
    self.scroll = -40
    self.last_scroll_target = self.scroll
    ---@type "SELECT" | "CHAPTER"
    self.state = "SELECT"
    self.star, self.empty_star = unpack(Assets.getFrames("chapters/star"))
    self.timer = self:addChild(Timer())
    self.alpha = 0
    self:fadeTo(1, 1)
    self.scroll_tween = self.timer:tween(1, self, {scroll = 0}, "out-quad", function ()
        self.last_scroll_target = 0
        self:updateScroll()
    end)
    local language = Game.getLanguage and Game:getLanguage() or nil
    local name_style = Game.getNameStyle and Game:getNameStyle() or nil
    self.name_style_prompt_timer = nil
    self.name_style_prompt_last_language = language
    self.name_style_prompt_last_name_style = name_style
    self.name_style_prompt_pending_initial = self:shouldShowInitialNameStylePrompt(language)
    self.name_style_prompt_loaded_frames = 0
    self.kris_shortcut_sequence_position = 1
    self.kris_shortcut_last_input_time = nil
    self.kris_shortcut_prompt = false
    self.kris_shortcut_prompt_time = 0
    self.kris_shortcut_hold_time = 0
    self.kris_shortcut_starting = false
end

function ChapterSelect:update()
    super.update(self)

    if self.kris_shortcut_prompt then
        self:updateKrisShortcutPrompt()
        return
    end

    self:updateNameStylePromptTrigger()
    self:updateInitialNameStylePrompt()

    if self.name_style_prompt_timer then
        self.name_style_prompt_timer = self.name_style_prompt_timer + DT
        if self.name_style_prompt_timer >= NAME_STYLE_PROMPT_DURATION then
            self.name_style_prompt_timer = nil
        end
    end
end

function ChapterSelect:updateFonts(force)
    local language = Game.getLanguage and Game:getLanguage() or nil
    if not force and self.font_language == language then
        return
    end

    self.font_language = language
    self.font = Assets.getFont("main")
    self.smfont = Assets.getFont("main",16)
end

function ChapterSelect:loadChapters()
    ---@type ChapterSelect.Chapter[]
    self.chapters = Kristal.getLibConfig("obscurachapters",
        "chapters",
        Kristal.getLibConfig("obscurachapters", "include_example")
    )
    for index, value in ipairs(self.chapters) do
        if type(value.image or "chapters/blank") == "string" then
            value.image = Assets.getTexture(value.image or "chapters/blank") or Assets.getTexture("chapters/blank")
        end
        value.index = value.index or index
        -- Check current mod's save files for completion stars
        local save_path = "saves/" .. Mod.info.id
        value.slots = {}
        for i = 1, 3 do
            local slot = {
                completion_file = nil ~= love.filesystem.getInfo(save_path .. "/completion_" .. i .. ".json"),
                normal_file = nil ~= love.filesystem.getInfo(save_path .. "/file_" .. i .. ".json"),
                shadow_crystal = false,
            }
            if slot.completion_file then
                local data = JSON.decode(love.filesystem.read(save_path .. "/completion_" .. i .. ".json"))
                slot.shadow_crystal = (data.flags[value.shadow_crystal_flag or ("shadow_crystal_" .. index)])
            end
            table.insert(value.slots, slot)
        end
    end
end

function ChapterSelect:updateScroll()
    local duration = Utils.clampMap(self.alpha, 0,1, 1, 0.3)
    local prev_target = self.last_scroll_target
    local target = self:getScrollTarget()
    if prev_target == target then return end
    if self.scroll_tween then
        self.timer:cancel(self.scroll_tween)
        self.scroll_tween = nil
    end
    self.scroll_tween = self.timer:tween(duration, self, {scroll = target}, "out-quint")
end

function ChapterSelect:getScrollTarget()
    if self.selected_y > #self.chapters then return self.last_scroll_target end
    local scroll_target = self.scroll
    if self.selected_y <= 4 then
        scroll_target = 0
    elseif self.selected_y > #self.chapters - 4 then
        scroll_target = 60 * (#self.chapters - 7)
    else
        scroll_target = 60 * (self.selected_y - 4)
    end
    self.last_scroll_target = scroll_target
    return scroll_target
end

function ChapterSelect:draw()
    self:updateFonts()
    if self.kris_shortcut_prompt then
        self:drawKrisShortcutPrompt()
        return
    end

    super.draw(self)
    local canvas = Draw.pushCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.setFont(self.font)
    love.graphics.push()
    love.graphics.translate(49,15-self.scroll)
    for index, value in ipairs(self.chapters) do
        self:setChapterColor(index)
        self:drawChapter(index, value)
        love.graphics.translate(0,60)
    end
    love.graphics.pop()
    Draw.setColor(COLORS.black)
    love.graphics.push()
    if self.alpha < 1 then
    end
    Draw.rectangle("fill", 0,SCREEN_HEIGHT-52, SCREEN_WIDTH, 52)
    love.graphics.pop()
    if self:setColorSelect(1, #self.chapters + 1) then
        local prev = {love.graphics.getColor()}
        Draw.setColor(Game:getSoulColor())
        Draw.draw(self.heart, 180, 442, 0, 2,2)
        Draw.setColor(prev)
    end
    Draw.printAlign("Quit", 210, 434)
    if self:setColorSelect(2, #self.chapters + 1) then
        local prev = {love.graphics.getColor()}
        Draw.setColor(Game:getSoulColor())
        Draw.draw(self.heart, 322, 442, 0, 2,2)
        Draw.setColor(prev)
    end
    self:drawNextLanguageName(352, 434)
    love.graphics.push()
    love.graphics.translate(6,1)
    self:drawShadowCrystals()
    love.graphics.pop()
    self:drawVersionInfo()
    self:drawNameStylePrompt()
    Draw.popCanvas()
    Draw.setColor(self:getDrawColor())
    Draw.draw(canvas)
end

function ChapterSelect:getFontForLanguage(language, size)
    if language then
        local font = Assets.getFont("lang/" .. language .. "/main", size)
        if font then
            return font
        end
    end
    return size and Assets.getFont("main", size) or self.font
end

function ChapterSelect:getNextLanguage()
    if not Game.getLanguages or not Game.getLanguage then
        return nil
    end

    local languages = Game:getLanguages()
    if #languages == 0 then
        return nil
    end

    local current = Game:getLanguage()
    for index, language in ipairs(languages) do
        if language == current then
            return languages[(index % #languages) + 1]
        end
    end

    return languages[1]
end

function ChapterSelect:getNextLanguageName()
    local next_language = self:getNextLanguage()
    if next_language and Game.getLanguageName then
        return Game:getLanguageName(next_language)
    end
    return "Language"
end

function ChapterSelect:drawNextLanguageName(x, y)
    local next_language = self:getNextLanguage()
    local font = self:getFontForLanguage(next_language)
    local old_font = love.graphics.getFont()

    love.graphics.setFont(font)
    Draw.printAlign(self:getNextLanguageName(), x, y)
    love.graphics.setFont(old_font)
end

function ChapterSelect:isNameStylePromptLanguage(language)
    return type(language) == "string" and not language:lower():match("^en")
end

function ChapterSelect:canUseNameStylePrompt(language)
    return Game.getNameStyle and Game.setNameStyle and self:isNameStylePromptLanguage(language)
end

function ChapterSelect:shouldShowInitialNameStylePrompt(language)
    return type(language) == "string"
        and language:lower():match("^zh")
        and self:canUseNameStylePrompt(language)
end

function ChapterSelect:isInitialLoadComplete()
    return self.alpha >= 0.999 and math.abs(self.scroll) <= 0.01
end

function ChapterSelect:updateInitialNameStylePrompt()
    if not self.name_style_prompt_pending_initial then
        return
    end

    if not self:isInitialLoadComplete() then
        self.name_style_prompt_loaded_frames = 0
        return
    end

    self.name_style_prompt_loaded_frames = self.name_style_prompt_loaded_frames + 1
    if self.name_style_prompt_loaded_frames < 2 then
        return
    end

    self.name_style_prompt_pending_initial = false
    if self:shouldShowInitialNameStylePrompt(Game.getLanguage and Game:getLanguage() or nil) then
        self:showNameStylePrompt()
    end
end

function ChapterSelect:getCurrentNameStyle()
    if Game.getNameStyle then
        return Game:getNameStyle()
    end
    return NAME_STYLE_TRANSLATED
end

function ChapterSelect:getNextNameStyle()
    if self:getCurrentNameStyle() == NAME_STYLE_ORIGINAL then
        return NAME_STYLE_TRANSLATED
    end
    return NAME_STYLE_ORIGINAL
end

function ChapterSelect:getNameStyleLabel(style)
    return NAME_STYLE_LABELS[style] or NAME_STYLE_LABELS[NAME_STYLE_TRANSLATED]
end

function ChapterSelect:getNameStyleLabelColor(style)
    return NAME_STYLE_LABEL_COLORS[style] or NAME_STYLE_PROMPT_COLOR_TEXT
end

function ChapterSelect:showNameStylePrompt()
    if not self:canUseNameStylePrompt(Game.getLanguage and Game:getLanguage() or nil) then
        self.name_style_prompt_timer = nil
        return
    end

    self:updateFonts(true)
    self.name_style_prompt_timer = 0
end

function ChapterSelect:hideNameStylePrompt()
    self.name_style_prompt_timer = nil
end

function ChapterSelect:updateNameStylePromptTrigger()
    local language = Game.getLanguage and Game:getLanguage() or nil
    local name_style = Game.getNameStyle and Game:getNameStyle() or nil

    if language ~= self.name_style_prompt_last_language then
        self.name_style_prompt_last_language = language
        self.name_style_prompt_last_name_style = name_style
        if self:canUseNameStylePrompt(language) then
            self:showNameStylePrompt()
        else
            self:hideNameStylePrompt()
        end
    elseif name_style ~= self.name_style_prompt_last_name_style then
        self.name_style_prompt_last_name_style = name_style
        if self:canUseNameStylePrompt(language) then
            self:showNameStylePrompt()
        end
    end
end

function ChapterSelect:getNameStylePromptAlpha()
    if not self.name_style_prompt_timer then
        return 0
    end

    if self.name_style_prompt_timer < NAME_STYLE_PROMPT_FADE_IN then
        return self.name_style_prompt_timer / NAME_STYLE_PROMPT_FADE_IN
    end

    local fade_out_start = NAME_STYLE_PROMPT_FADE_IN + NAME_STYLE_PROMPT_HOLD
    if self.name_style_prompt_timer < fade_out_start then
        return 1
    end

    local progress = (self.name_style_prompt_timer - fade_out_start) / NAME_STYLE_PROMPT_FADE_OUT
    return 1 - math.min(progress, 1)
end

function ChapterSelect:drawNameStylePromptLine(segments, x, y, alpha)
    local font = love.graphics.getFont()
    local width = 0

    for _, segment in ipairs(segments) do
        width = width + getNameStylePromptTextWidth(font, segment.text)
    end

    local cursor_x = x - width
    for _, segment in ipairs(segments) do
        local color = segment.color or NAME_STYLE_PROMPT_COLOR_TEXT
        Draw.setColor(color[1], color[2], color[3], alpha)
        drawNameStylePromptText(segment.text, cursor_x, y)
        cursor_x = cursor_x + getNameStylePromptTextWidth(font, segment.text)
    end
end

function ChapterSelect:drawNameStylePrompt()
    local alpha = self:getNameStylePromptAlpha()
    if alpha <= 0 then
        return
    end

    local current_style = self:getCurrentNameStyle()
    local next_style = self:getNextNameStyle()
    local old_font = love.graphics.getFont()
    local x = SCREEN_WIDTH - 14
    local y = SCREEN_HEIGHT - 40

    love.graphics.setFont(self.smfont)
    self:drawNameStylePromptLine({
        { text = "当前使用", color = NAME_STYLE_PROMPT_COLOR_CURRENT },
        { text = " ", color = NAME_STYLE_PROMPT_COLOR_TEXT },
        { text = self:getNameStyleLabel(current_style), color = self:getNameStyleLabelColor(current_style) },
    }, x, y, alpha)
    self:drawNameStylePromptLine({
        { text = "按 ", color = NAME_STYLE_PROMPT_COLOR_TEXT },
        { text = "c", color = NAME_STYLE_PROMPT_COLOR_KEY },
        { text = " 切换到 ", color = NAME_STYLE_PROMPT_COLOR_TEXT },
        { text = self:getNameStyleLabel(next_style), color = self:getNameStyleLabelColor(next_style) },
    }, x, y + self.smfont:getHeight() + 4, alpha)
    love.graphics.setFont(old_font)
end

function ChapterSelect:getKrisShortcutKeyText(alias, fallback)
    if Input and Input.getText then
        return cleanInputText(Input.getText(alias), fallback)
    end
    return fallback
end

function ChapterSelect:getKrisShortcutKrisName()
    if Game and Game.locName then
        return Game:locName("actor", "kris", "KRIS")
    end
    return "KRIS"
end

function ChapterSelect:getKrisShortcutInput(key)
    if Input.isConfirm(key) then
        return "confirm"
    elseif Input.isCancel(key) then
        return "cancel"
    end
    return nil
end

function ChapterSelect:isKrisShortcutChapterSelected()
    local chapter = self.chapters and self.chapters[self.selected_y]
    return chapter and chapter.index == KRIS_SHORTCUT_CHAPTER_INDEX
end

function ChapterSelect:resetKrisShortcutSequence()
    self.kris_shortcut_sequence_position = 1
    self.kris_shortcut_last_input_time = nil
end

function ChapterSelect:updateKrisShortcutSequence(input)
    if not input then
        return false
    end

    if not self:isKrisShortcutChapterSelected() then
        self:resetKrisShortcutSequence()
        return false
    end

    local now = love.timer and love.timer.getTime and love.timer.getTime() or 0
    if self.kris_shortcut_last_input_time
        and now - self.kris_shortcut_last_input_time > KRIS_SHORTCUT_SEQUENCE_MAX_GAP
    then
        self:resetKrisShortcutSequence()
    end

    local position = self.kris_shortcut_sequence_position or 1
    if input == KRIS_SHORTCUT_SEQUENCE[position] then
        self.kris_shortcut_sequence_position = position + 1
    elseif input == KRIS_SHORTCUT_SEQUENCE[1] then
        self.kris_shortcut_sequence_position = 2
    else
        self:resetKrisShortcutSequence()
    end

    self.kris_shortcut_last_input_time = now

    if (self.kris_shortcut_sequence_position or 1) > #KRIS_SHORTCUT_SEQUENCE then
        self:openKrisShortcutPrompt()
        return true
    end

    return false
end

function ChapterSelect:openKrisShortcutPrompt()
    self.kris_shortcut_prompt = true
    self.kris_shortcut_prompt_time = 0
    self.kris_shortcut_hold_time = 0
    self.kris_shortcut_starting = false
    self.selected_x = 1
    self.state = "SELECT"
    self:resetKrisShortcutSequence()
    self:hideNameStylePrompt()

    if Game.world and Game.world.music then
        Game.world.music:stop()
    end
    if Assets.stopAllSounds then
        Assets.stopAllSounds()
    end
    Input.clear("confirm", true)
    Input.clear("cancel", true)
end

function ChapterSelect:closeKrisShortcutPrompt()
    self.kris_shortcut_prompt = false
    self.kris_shortcut_prompt_time = 0
    self.kris_shortcut_hold_time = 0
    self.kris_shortcut_starting = false
    self.selected_x = 1
    self.state = "SELECT"
    self:resetKrisShortcutSequence()

    Input.clear("confirm", true)
    Input.clear("cancel", true)
    if Game.world and Game.world.transitionMusic then
        Game.world:transitionMusic("AUDIO_DRONE")
    end
end

function ChapterSelect:startKrisShortcutBattle()
    if self.kris_shortcut_starting then
        return
    end

    self.kris_shortcut_starting = true
    if Mod.setTemporaryDefaultBattleEntry then
        Mod:setTemporaryDefaultBattleEntry("kris")
    else
        Mod.krisis_default_battle_entry = "kris"
        if Kristal then
            Kristal.krisis_default_battle_entry = "kris"
        end
        if Mod.info then
            Mod.info.encounter = "kris"
        end
    end

    if Game.world and Game.world.music then
        Game.world.music:stop()
    end
    if Assets.stopAllSounds then
        Assets.stopAllSounds()
    end

    Input.clear("confirm", true)
    Input.clear("cancel", true)

    if Game.world then
        Game.world:closeMenu()
    end
    Game:encounter("kris", false)
end

function ChapterSelect:updateKrisShortcutPrompt()
    self.kris_shortcut_prompt_time = (self.kris_shortcut_prompt_time or 0) + DT
    if self.kris_shortcut_prompt_time < KRIS_SHORTCUT_PROMPT_INPUT_DELAY then
        self.kris_shortcut_hold_time = 0
        return
    end

    if Input.down("confirm") then
        self.kris_shortcut_hold_time = self.kris_shortcut_hold_time + DT
        if self.kris_shortcut_hold_time >= KRIS_SHORTCUT_HOLD_TIME then
            self:startKrisShortcutBattle()
        end
    else
        self.kris_shortcut_hold_time = 0
    end
end

function ChapterSelect:onKeyPressedKrisShortcut(key)
    if (self.kris_shortcut_prompt_time or 0) < KRIS_SHORTCUT_PROMPT_INPUT_DELAY then
        return
    end

    if Input.isCancel(key) then
        self:closeKrisShortcutPrompt()
    end
end

function ChapterSelect:drawKrisShortcutPrompt()
    local old_font = love.graphics.getFont()
    local language = Game.getLanguage and Game:getLanguage() or nil
    local z_text = self:getKrisShortcutKeyText("confirm", "Z")
    local x_text = self:getKrisShortcutKeyText("cancel", "X")

    Draw.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    love.graphics.setFont(self:getFontForLanguage(language))
    drawPromptSegments({
        {
            text = loc("Jump directly to the battle with [var:kris]?", "chapter_select.kris_shortcut_question", {
                kris = self:getKrisShortcutKrisName(),
            }),
        },
    }, SCREEN_WIDTH / 2, 220, "center", 1)

    love.graphics.setFont(self:getFontForLanguage(language, 16))
    if (self.kris_shortcut_prompt_time or 0) < KRIS_SHORTCUT_PROMPT_INPUT_DELAY then
        love.graphics.setFont(old_font)
        return
    end

    drawPromptSegments({
        { text = loc("Hold ", "chapter_select.kris_shortcut_hold_left") },
        { text = z_text, color = KRIS_SHORTCUT_YELLOW },
        { text = loc(" to jump", "chapter_select.kris_shortcut_hold_right") },
    }, SCREEN_WIDTH - 20, SCREEN_HEIGHT - 82, "right", 1)
    drawPromptSegments({
        { text = loc("This will temporarily set the game to ", "chapter_select.kris_shortcut_default_left") },
        {
            text = loc("default battle entry", "chapter_select.kris_shortcut_default_highlight"),
            color = KRIS_SHORTCUT_YELLOW,
        },
        { text = loc("", "chapter_select.kris_shortcut_default_right") },
    }, SCREEN_WIDTH - 20, SCREEN_HEIGHT - 58, "right", 1)
    drawPromptSegments({
        { text = loc("Press ", "chapter_select.kris_shortcut_return_left") },
        { text = x_text, color = KRIS_SHORTCUT_YELLOW },
        { text = loc(" to return to Chapter Select", "chapter_select.kris_shortcut_return_right") },
    }, SCREEN_WIDTH - 20, SCREEN_HEIGHT - 34, "right", 1)

    if self.kris_shortcut_hold_time > 0 then
        local width = 224
        local height = 4
        local x = SCREEN_WIDTH - width - 20
        local y = SCREEN_HEIGHT - 10
        local progress = math.min(self.kris_shortcut_hold_time / KRIS_SHORTCUT_HOLD_TIME, 1)

        Draw.setColor(0.28, 0.28, 0.28, 1)
        love.graphics.rectangle("fill", x, y, width, height)
        Draw.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", x, y, width * progress, height)
    end

    love.graphics.setFont(old_font)
end

function ChapterSelect:switchNameStyle()
    if not self:canUseNameStylePrompt(Game.getLanguage and Game:getLanguage() or nil) then
        return false
    end

    local next_style = self:getNextNameStyle()
    if Game:setNameStyle(next_style) then
        self.name_style_prompt_last_name_style = next_style
        self:showNameStylePrompt()
        Assets.stopAndPlaySound("ui_select")
        return true
    end

    Assets.stopAndPlaySound("ui_cancel")
    return false
end

function ChapterSelect:switchLanguage()
    local next_language = self:getNextLanguage()
    if next_language and Game.setLanguage and Game:setLanguage(next_language) then
        local language = Game.getLanguage and Game:getLanguage() or next_language
        self.name_style_prompt_last_language = language
        self.name_style_prompt_last_name_style = Game.getNameStyle and Game:getNameStyle() or nil
        self:updateFonts(true)
        if self:canUseNameStylePrompt(language) then
            self:showNameStylePrompt()
        else
            self:hideNameStylePrompt()
        end
        Assets.stopAndPlaySound("ui_select")
    else
        Assets.stopAndPlaySound("ui_cancel")
    end
end

function ChapterSelect:openOptions()
    Assets.playSound("ui_select")
    Game.world:closeMenu()
    Game.world:loadMap("options")
end

function ChapterSelect:drawVersionInfo()
    love.graphics.push()
    love.graphics.translate(16,434)
    Draw.setColor(COLORS.gray)
    love.graphics.setFont(self.smfont)
    love.graphics.print(self.info[1])
    local mod_version = Mod.info.version
    love.graphics.print(self.info[2], 0, 16)
    love.graphics.setFont(self.font)
    love.graphics.pop()
end

function ChapterSelect:onAdd(parent)
    super.onAdd(self, parent)
    self:updateShadowCrystals()
end

function ChapterSelect:updateShadowCrystals()
    local blank = {{}, {}, {}}
    self.shadow_slots = {}
    local max_shadow_chapters = 0
    for ch_id, ch in ipairs(self.chapters) do
        local chslots = {}
        table.insert(self.shadow_slots, chslots)
        for slot_id, slot in ipairs(ch.slots or blank) do
            table.insert(chslots, not not slot.shadow_crystal)
            if slot.shadow_crystal then
                max_shadow_chapters = ch_id
            end
        end
    end
    while #self.shadow_slots > max_shadow_chapters do
        table.remove(self.shadow_slots, #self.shadow_slots)
    end
end

function ChapterSelect:drawShadowCrystals()
    Draw.setColor(COLORS.white)
    love.graphics.translate(580 - (#self.shadow_slots * 20),425)
    for ch_id, value in ipairs(self.shadow_slots) do
        for slot_id, slot in ipairs(value) do
            local x,y = ch_id * 20, slot_id * 10
            if slot then
                Draw.draw(Assets.getTexture("chapters/crystal"), x,y)
            else
                Draw.draw(Assets.getTexture("chapters/dot"), x+1,y+3)
            end
        end
    end
end

function ChapterSelect:setColorSelect(x,y)
    if (x == nil or self.selected_x == x) and (y == nil or self.selected_y == y) then
        Draw.setColor(COLORS.yellow)
        return true
    else
        Draw.setColor(COLORS.white)
        return false
    end
end

function ChapterSelect:setChapterColor(y)
    if self.selected_y == y then
        Draw.setColor(COLORS.yellow)
        return true
    elseif self.chapters[y] and self.chapters[y].unlocked == false then
        Draw.setColor(COLORS.gray)
    else
        Draw.setColor(COLORS.white)
        return false
    end
end

function ChapterSelect:onKeyPressed(key)
    if not Kristal.getLibConfig("obscurachapters", "interactable_while_fading") and self.alpha < 1 then
        return
    end
    if self.kris_shortcut_prompt then
        self:onKeyPressedKrisShortcut(key)
        return
    end
    if key == "escape" then
        self:openOptions()
        return
    end
    if key == "c" and self:switchNameStyle() then
        return
    end
    local kris_shortcut_input = self:getKrisShortcutInput(key)
    if self:updateKrisShortcutSequence(kris_shortcut_input) then
        return
    end
    if self.state == "SELECT" then
        self:onKeyPressedSelect(key)
    else
        self:onKeyPressedChapter(key)
    end
end

function ChapterSelect:onKeyPressedChapter(key)
    local old_sel_x = self.selected_x
    if Input.is("right", key) then
        self.selected_x = self.selected_x + 1
    elseif Input.is("left", key) then
        self.selected_x = self.selected_x - 1
    end
    self.selected_x = Utils.clamp(self.selected_x, 1, 2)
    if old_sel_x ~= self.selected_x then Assets.playSound("ui_move") end
    if Input.isConfirm(key) and self.selected_x == 1 then
        self:startEnterChapter(self.chapters[self.selected_y])
    elseif Input.isCancel(key) or Input.isConfirm(key) then
        Assets.playSound("ui_cancel")
        self.selected_x = 1
        self.state = "SELECT"
    end
end

---@param chapter ChapterSelect.Chapter
function ChapterSelect:startEnterChapter(chapter)
    if chapter.index and chapter.index <= 5 then
        Assets.playSound("ui_cancel")
        self:shake(12, 6, 0.7)
    else
        local texture = love.graphics.newImage(Draw.captureObject(self, "none"):newImageData())
        Game.world.music:stop()
        Game.world:closeMenu()
        local transition = Game.world:addChild(ChapterTransitionEffect(chapter, texture))
        if chapter.instant then
            transition.clock = 1000
        end
    end
end

function ChapterSelect:isValidSelection()
    return self.chapters[self.selected_y] == nil or self.chapters[self.selected_y].unlocked ~= false
end

function ChapterSelect:close()
    self:remove()
end

function ChapterSelect:onKeyPressedSelect(key)
    local old_sel_x = self.selected_x
    local old_sel_y = self.selected_y
    if Input.is("down", key) then
        repeat
            self.selected_y = self.selected_y + 1
        until self:isValidSelection()
    elseif Input.is("up", key) then
        repeat
            self.selected_y = self.selected_y - 1
        until self:isValidSelection()
    elseif Input.is("left", key) then
        self.selected_x = 1
    elseif Input.is("right", key) then
        self.selected_x = 2
    end
    if self.selected_y ~= (#self.chapters + 1) then
        self.selected_x = 1
    end
    self.selected_y = Utils.clampWrap(self.selected_y, 1, #self.chapters + 1)
    if old_sel_x ~= self.selected_x or old_sel_y ~= self.selected_y then Assets.playSound("ui_move") end
    if Input.isConfirm(key) then
        if self.selected_y <= #self.chapters then
            self:handleChapter(self.selected_y)
        elseif self.selected_x == 1 then
            Assets.playSound("ui_select")
            Game.fader:fadeOut(function()
                if TARGET_MOD and AUTO_MOD_START then
                    love.event.quit(0)
                else
                    Kristal.returnToMenu()
                end
            end, {speed = .5})
            Game.state = "EXIT"
        else
            self:switchLanguage()
        end
    end
    self:updateScroll()
end

function ChapterSelect:handleChapter(position)
    local chapter = self.chapters[position]
    if chapter.sound and not chapter.map then
        Assets.stopAndPlaySound(chapter.sound)
        return
    elseif not chapter.map then return end
    Assets.playSound("ui_select")
    self.state = "CHAPTER"
end

---@param index integer
---@param chapter ChapterSelect.Chapter
function ChapterSelect:drawChapter(index, chapter)
    love.graphics.print("Chapter "..chapter.index, 1, 1)
    Draw.draw(chapter.image, 504, -5, 0, 2, 2)
    if self.state == "CHAPTER" and self.selected_y == index then
        local first = self:setColorSelect(1)
        love.graphics.print("Play", 201, 1)
        self:setColorSelect(2)
        love.graphics.print("Do Not", 381,1)
        Draw.setColor(Game:getSoulColor())
        Draw.draw(self.heart, first and 171 or 351, 9, 0, 2,2)

    else
        Draw.printAlign(chapter.name, 311, 1, "center")
        Draw.setColor(Game:getSoulColor())
        if self.selected_y == index then
            Draw.draw(self.heart, -29, 9, 0, 2,2)
        end
        love.graphics.scale(1)
    end
    love.graphics.push()
    love.graphics.translate(131, 1)
    Draw.setColor(COLORS.white)
    for index, slot in ipairs(chapter.slots or {}) do
        if slot.completion_file then
            if slot.normal_file then
                Draw.draw(self.star)
            else
                Draw.draw(self.empty_star)
            end
        end
        love.graphics.translate(0, 12)
    end
    love.graphics.pop()
    Draw.setColor({43/255, 43/255, 43/255})
    love.graphics.setLineWidth(2)
    love.graphics.line(-49,49,SCREEN_WIDTH-49,49)
end


function ChapterSelect:close()
    self:remove()
end

return ChapterSelect
