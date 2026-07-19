local BattlePrepScene, super = Class(Object)

local ASSET_ROOT = "battle_prep/kris/"
local FRAME_TIME = 4 / 30
local TEXT_HOLD_TIME = 2
local TEXT_FADE_OUT_TIME = 0.5
local PRE_BATTLE_WHITE_TIME = 3
local BATTLE_WHITE_HOLD_TIME = 0.5
local BATTLE_WHITE_FADE_TIME = 0.5
local FRAME_SCALE_X = SCREEN_WIDTH / 320
local FRAME_SCALE_Y = SCREEN_HEIGHT / 240

local SEQUENCE_FRAMES = {
    1, 2, 3,
    4, 5, 6,
    4, 5, 6,
    4, 5, 6,
    4, 5, 6,
}

local CJK_TEXT_SPACING = 8

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function isCjkCodepoint(codepoint)
    return (codepoint >= 0x2E80 and codepoint <= 0x9FFF)
        or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
        or (codepoint >= 0xFE10 and codepoint <= 0xFE1F)
        or (codepoint >= 0xFF00 and codepoint <= 0xFFEF)
        or (codepoint >= 0x20000 and codepoint <= 0x2FA1F)
end

local function getSpacedTextWidth(font, text)
    local width = 0
    for _, codepoint in utf8.codes(text) do
        local char = utf8.char(codepoint)
        width = width + font:getWidth(char)
        if isCjkCodepoint(codepoint) then
            width = width + CJK_TEXT_SPACING
        end
    end
    return width
end

local function drawSpacedText(text, x, y)
    local font = love.graphics.getFont()
    local cursor_x = 0
    for _, codepoint in utf8.codes(text) do
        local char = utf8.char(codepoint)
        love.graphics.print(char, x + cursor_x, y)
        cursor_x = cursor_x + font:getWidth(char)
        if isCjkCodepoint(codepoint) then
            cursor_x = cursor_x + CJK_TEXT_SPACING
        end
    end
end

local function drawGonerText(text, font, center_x, center_y, alpha, timer)
    if alpha <= 0 then
        return
    end

    local width = getSpacedTextWidth(font, text)
    local x = center_x - (width / 2)
    local y = center_y - (font:getHeight() / 2)
    love.graphics.setFont(font)

    Draw.setColor(1, 1, 1, alpha)
    drawSpacedText(text, x, y)

    local outline_alpha = alpha * (0.3 + (math.sin(timer / 14) * 0.1))
    Draw.setColor(1, 1, 1, outline_alpha)
    drawSpacedText(text, x + 2, y)
    drawSpacedText(text, x - 2, y)
    drawSpacedText(text, x, y + 2)
    drawSpacedText(text, x, y - 2)

    local outer_outline_alpha = alpha * (0.08 + (math.sin(timer / 14) * 0.04))
    Draw.setColor(1, 1, 1, outer_outline_alpha)
    drawSpacedText(text, x + 2, y)
    drawSpacedText(text, x - 2, y)
    drawSpacedText(text, x, y + 2)
    drawSpacedText(text, x, y - 2)
end

local function loc(default, id)
    if Game and Game.loc then
        return Game:loc(default, id)
    end
    return default
end

function BattlePrepScene:init(options)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    options = options or {}
    self.layer = 1000000
    self.encounter = options.encounter or "kris"
    self.state = "TEXT"
    self.state_time = 0
    self.sequence_index = 1
    self.battle_started = false
    self.font_language = nil
    self.text_font = nil

    self.frames = {}
    for index = 1, 6 do
        local frame = assert(
            Assets.getTexture(ASSET_ROOT .. tostring(index)),
            "Missing battle prep frame: " .. tostring(index)
        )
        frame:setFilter("nearest", "nearest")
        self.frames[index] = frame
    end

    self:refreshFonts(true)
end

function BattlePrepScene:refreshFonts(force)
    local language = Game and Game.getLanguage and Game:getLanguage() or nil
    if force and language and Game.setLanguage then
        Game:setLanguage(language, true)
    end

    if not force and self.font_language == language and self.text_font then
        return
    end

    self.font_language = language
    self.text_font = Assets.getFont("main_mono")
end

function BattlePrepScene:update()
    super.update(self)

    self.state_time = self.state_time + DT

    if self.state == "TEXT" then
        if self.state_time >= TEXT_HOLD_TIME + TEXT_FADE_OUT_TIME then
            self.state = "SEQUENCE"
            self.state_time = 0
        end
    elseif self.state == "SEQUENCE" then
        while self.state_time >= FRAME_TIME and self.state == "SEQUENCE" do
            self.state_time = self.state_time - FRAME_TIME
            self.sequence_index = self.sequence_index + 1
            if self.sequence_index > #SEQUENCE_FRAMES then
                self.state = "PRE_BATTLE_WHITE"
                self.state_time = 0
            end
        end
    elseif self.state == "PRE_BATTLE_WHITE" then
        if self.state_time >= PRE_BATTLE_WHITE_TIME then
            Game:encounter(self.encounter, false)
            self.state = "BATTLE_WHITE"
            self.state_time = 0
            self.battle_started = true
        end
    elseif self.state == "BATTLE_WHITE" then
        if self.state_time >= BATTLE_WHITE_HOLD_TIME + BATTLE_WHITE_FADE_TIME then
            self:remove()
        end
    end
end

function BattlePrepScene:getTextAlpha()
    if self.state ~= "TEXT" then
        return 0
    end

    if self.state_time <= TEXT_HOLD_TIME then
        return 1
    end

    return 1 - clamp(
        (self.state_time - TEXT_HOLD_TIME) / TEXT_FADE_OUT_TIME,
        0,
        1
    )
end

function BattlePrepScene:getWhiteAlpha()
    if self.state == "PRE_BATTLE_WHITE" then
        return 1
    end
    if self.state ~= "BATTLE_WHITE" then
        return 0
    end
    if self.state_time <= BATTLE_WHITE_HOLD_TIME then
        return 1
    end

    return 1 - clamp(
        (self.state_time - BATTLE_WHITE_HOLD_TIME) / BATTLE_WHITE_FADE_TIME,
        0,
        1
    )
end

function BattlePrepScene:draw()
    self:refreshFonts(false)
    love.graphics.push("all")
    love.graphics.origin()

    if self.state ~= "BATTLE_WHITE" then
        Draw.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    end

    if self.state == "SEQUENCE" then
        local frame_index = SEQUENCE_FRAMES[self.sequence_index]
        local frame = self.frames[frame_index]
        Draw.setColor(1, 1, 1, 1)
        Draw.draw(frame, 0, 0, 0, FRAME_SCALE_X, FRAME_SCALE_Y)
    end

    local text_alpha = self:getTextAlpha()
    drawGonerText(
        loc("SOMETHING IN SHELTER", "battle_prep.in_shelter"),
        self.text_font,
        SCREEN_WIDTH / 2,
        SCREEN_HEIGHT / 2,
        text_alpha,
        self.state_time * 60
    )

    local white_alpha = self:getWhiteAlpha()
    if white_alpha > 0 then
        Draw.setColor(1, 1, 1, white_alpha)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    end

    love.graphics.pop()
end

return BattlePrepScene
