local CreditsScene, super = Class(Object)

local CREDITS_BPM = 80
local CREDITS_BEATS_PER_CARD = 8
local CARD_DURATION = CREDITS_BEATS_PER_CARD * 60 / CREDITS_BPM
local CREDITS_MUSIC = "credits"
local CREDITS_MUSIC_VOLUME = 0.8
local HOLD_TO_SKIP_TIME = 0.65
local CREDITS_FONT_SIZE = 32
local NAME_LINE_HEIGHT = 32
local ROLE_LINE_HEIGHT = 32
local CJK_TEXT_SPACING = 2
local TYPEWRITER_CHAR_DELAY = 0.04
local TYPEWRITER_PUNCTUATION_PAUSE = 0.55
local RECORD_ROLL_TIME = 0.8
local VERDICT_WAIT_TIME = 4 * 60 / CREDITS_BPM
local SETTLEMENT_HOLD_TIME = 2.5
local FINAL_TEXT_HOLD_TIME = 2.5
local ROLE_COLOR = {0.55, 0.55, 0.55}
local NAME_COLOR = {1, 1, 1}

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

local function drawSpacedText(font, text, x, y)
    local cursor_x = x
    for _, codepoint in utf8.codes(text) do
        local char = utf8.char(codepoint)
        love.graphics.print(char, cursor_x, y)
        cursor_x = cursor_x + font:getWidth(char)
        if isCjkCodepoint(codepoint) then
            cursor_x = cursor_x + CJK_TEXT_SPACING
        end
    end
end

local function drawCenteredSpacedText(font, text, y, center_x)
    center_x = center_x or SCREEN_WIDTH / 2
    local x = center_x - (getSpacedTextWidth(font, text) / 2)
    drawSpacedText(font, text, x, y)
end

local function splitLines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function formatDuration(milliseconds)
    local total_seconds = math.floor((milliseconds or 0) / 1000)
    local hours = math.floor(total_seconds / 3600)
    local minutes = math.floor((total_seconds % 3600) / 60)
    local seconds = total_seconds % 60
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, seconds)
    end
    return string.format("%02d:%02d", minutes, seconds)
end

local function loc(default, id)
    if Game and Game.loc then
        return Game:loc(default, id)
    end
    return default
end

local CREDIT_DEFAULTS = {
    ["credits.role_deltarune_author"] = "DELTARUNE Author",
    ["credits.role_lead_production"] = "Lead Production",
    ["credits.role_bullet_hell_design"] = "Bullet Hell Design",
    ["credits.role_design"] = "Design",
    ["credits.role_script"] = "Script",
    ["credits.role_sound"] = "Sound",
    ["credits.chapter_final_prophecy"] = "-FINAL PROPHECY-",
    ["credits.chapter_never_forgetting"] = "-NEVER FORGETTING-",
    ["credits.chapter_dark_outskirts"] = "-DARK OUTSKIRTS-",
    ["credits.chapter_rebirth"] = "-REBIRTH-",
    ["credits.role_cover_art"] = "Cover Art",
    ["credits.role_trailer"] = "Trailer",
    ["credits.role_special_thanks"] = "Special Thanks",
    ["credits.role_game_developer"] = "Game Developer",
    ["credits.role_game_testing"] = "Game Testing",
    ["credits.role_engine"] = "Engine",
}

local CREDIT_FINAL_DEFAULTS = {
    ["credits.final_text"] = "The story of DELTARUNE\nwill continue here.",
    ["credits.final_text_original"] = "DELTARUNE 的故事\n将于此续写下去。",
    ["credits.thank_you_text"] = "- And most importantly... -\nYou, the Player.\n\nThank you for playing.",
}

local CREDIT_RECORD_DEFAULTS = {
    title = "GAME RECORD",
    kris_hits = "KRIS HITS",
    kris_bullet_hits = "KRIS BULLET HITS",
    finisher_hits = "FINISHER HITS",
    finisher_bullet_hits = "FINISHER BULLET HITS",
    items_used = "ITEMS USED",
    total_healed = "TOTAL HP RECOVERED",
    no_hit_turns = "NO-HIT TURNS",
    max_graze_combo = "MAX GRAZE COMBO",
    previous_failures = "PREVIOUS FAILURES",
    total_grazes = "TOTAL GRAZES",
    game_time = "GAME TIME",
    run_seed = "RUN SEED",
}

local CREDIT_VERDICT_DEFAULTS = {
    normal = "THE DARKNESS KEEPS GROWING",
    no_item = "NO ITEM - THE SHADOWS CUTTING DEEPER",
    no_hit = "NO HIT - SEEMS VERY VERY INTERESTING",
}

local function localizeCredit(id)
    return loc(CREDIT_DEFAULTS[id] or id, id)
end

local function makeRole(id)
    return {
        role = id,
        names = {},
    }
end

local function makeCard(groups, gap)
    return {
        groups = groups,
        gap = gap,
    }
end

local function group(role, names)
    local entry = makeRole(role)
    entry.names = names
    return entry
end

local function getCards()
    return {
        makeCard({
            group("credits.role_deltarune_author", {"TOBY FOX"}),
            group("credits.role_lead_production", {"UJB传说官方"}),
            group("credits.role_bullet_hell_design", {"滑稽体验镇魂曲"}),
        }, 110),
        makeCard({
            group("credits.role_design", {"Nahisa图文"}),
            group("credits.role_script", {"这里不是红耀西"}),
            group("credits.role_sound", {"5P4mt0n"}),
        }, 110),
        makeCard({
            group("credits.chapter_final_prophecy", {"_B0TtLE_ (Bilibili)"}),
            group("credits.chapter_never_forgetting", {"Local, H00ligan, The Joker"}),
            group("credits.chapter_dark_outskirts", {"Vision Crew's Deltarune"}),
            group("credits.chapter_rebirth", {"Chirou-P (Bilibili)"}),
        }, 28),
        makeCard({
            group("credits.role_cover_art", {"GFM"}),
            group("credits.role_trailer", {"GA"}),
            group("credits.role_design", {"Waga_Love"}),
        }, 50),
        makeCard({
            group("credits.role_special_thanks", {
                "Aug_ust八月",
                "Alivall_",
                "Saarasin",
                "青柠不是人",
            }),
        }, 0),
        makeCard({
            group("credits.role_special_thanks", {
                "飞上天的开心果",
                "GoodTeaIce",
                "Xx_FrekGT_xX",
                "Rock",
            }),
        }, 0),
        makeCard({
            group("credits.role_game_developer", {"Bli_AIk"}),
            group("credits.role_game_testing", {
                "church_wafer",
                "Nahisa图文",
                "滑稽体验镇魂曲",
                "Gpie_A",
                "Anskiyy",
            }),
            group("credits.role_engine", {"Kristal"}),
        }, 26),
        {
            final_text = "credits.thank_you_text",
            static_text = true,
        },
        {
            record = true,
        },
        {
            final_text = "credits.final_text",
            manual_advance = true,
        },
    }
end

function CreditsScene:init(on_complete)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = WORLD_LAYERS["above_textbox"] + 1
    self.on_complete = on_complete
    self.cards = getCards()
    self.card_index = 1
    self.card_timer = 0
    self.current_language = nil
    self.current_name_style = nil
    self.finished = false
    self.final_characters = {}
    self.final_visible_count = 0
    self.final_reveal_timer = 0
    self.final_char_delay = TYPEWRITER_CHAR_DELAY
    self.record_roll_timer = 0
    self.verdict_wait_timer = 0
    self.settlement_hold_timer = 0
    self.final_text_hold_timer = 0
    self.record_stats = Mod and Mod.getKrisisGameStatsSnapshot
        and Mod:getKrisisGameStatsSnapshot()
        or nil
    self.hold_time = 0
    self.music = Music()
    self.music:play(CREDITS_MUSIC, CREDITS_MUSIC_VOLUME)

    self:refreshLocalization(true)
end

function CreditsScene:getVerdictKey()
    local stats = self.record_stats or {}
    local encounters = stats.encounters or {}
    local kris = encounters.kris or {}
    local finisher = encounters.kris_finisher or {}
    if (kris.actual_hits or 0) == 0 and (finisher.actual_hits or 0) == 0 then
        return "no_hit"
    elseif (stats.items_used or 0) == 0 then
        return "no_item"
    end
    return "normal"
end

function CreditsScene:getVerdictColor()
    local key = self:getVerdictKey()
    if key == "no_item" then
        return {1, 1, 0}
    elseif key == "no_hit" then
        return {1, 0.45, 0.75}
    end
    return {1, 1, 1}
end

function CreditsScene:refreshLocalization(force)
    local language = Game and Game.getLanguage and Game:getLanguage() or "en"
    local name_style = Game and Game.getNameStyle and Game:getNameStyle() or nil
    if not force and language == self.current_language and name_style == self.current_name_style then
        return
    end

    self.current_language = language
    self.current_name_style = name_style
    local font_path = "lang/" .. tostring(language) .. "/main_mono"
    self.role_font = Assets.getFont(font_path, CREDITS_FONT_SIZE)
        or Assets.getFont("main_mono", CREDITS_FONT_SIZE)
    self.name_font = Assets.getFont(font_path, CREDITS_FONT_SIZE)
        or Assets.getFont("main_mono", CREDITS_FONT_SIZE)
    self.localized_cards = {}

    for index, card in ipairs(self.cards) do
        if card.final_text then
            local final_text_id = card.final_text
            if card.final_text == "credits.final_text"
                and language == "zh_hans"
                and name_style == "original"
            then
                final_text_id = "credits.final_text_original"
            end
            self.localized_cards[index] = {
                final_text = loc(
                    CREDIT_FINAL_DEFAULTS[final_text_id] or final_text_id,
                    final_text_id
                ),
                static_text = card.static_text == true,
            }
        elseif card.record then
            local record = {
                record = true,
                labels = {},
                verdict_text = loc(
                    CREDIT_VERDICT_DEFAULTS[self:getVerdictKey()],
                    "credits.verdict_" .. self:getVerdictKey()
                ),
                verdict_color = self:getVerdictColor(),
            }
            for key, default in pairs(CREDIT_RECORD_DEFAULTS) do
                record.labels[key] = loc(default, "credits.record_" .. key)
            end
            self.localized_cards[index] = record
        else
            local localized = {
                groups = {},
                gap = card.gap,
            }
            for group_index, credit_group in ipairs(card.groups) do
                localized.groups[group_index] = {
                    role = localizeCredit(credit_group.role),
                    names = credit_group.names,
                }
            end
            self.localized_cards[index] = localized
        end
    end

    self:resetFinalText()
end

function CreditsScene:resetFinalText()
    local final_card = self.localized_cards[self.card_index]
    self.record_roll_timer = 0
    self.verdict_wait_timer = 0
    self.settlement_hold_timer = 0
    self.final_text_hold_timer = 0
    if not final_card or (not final_card.final_text and not final_card.verdict_text) then
        self.final_characters = {}
        return
    end

    self.final_characters = {}
    local text = final_card.final_text or final_card.verdict_text
    for _, codepoint in utf8.codes(text) do
        table.insert(self.final_characters, utf8.char(codepoint))
    end
    if final_card.static_text then
        self.final_visible_count = #self.final_characters
        self.final_reveal_timer = 0
        return
    end
    self.final_char_delay = TYPEWRITER_CHAR_DELAY
    if #self.final_characters > 0 then
        local reveal_duration = CARD_DURATION
        if final_card.record then
            reveal_duration = math.max(CARD_DURATION - VERDICT_WAIT_TIME, TYPEWRITER_CHAR_DELAY)
        end
        self.final_char_delay = math.min(
            TYPEWRITER_CHAR_DELAY,
            reveal_duration / #self.final_characters
        )
    end
    self.final_visible_count = 0
    self.final_reveal_timer = 0
end

local function isCreditsPunctuation(character)
    return character == "."
        or character == ","
        or character == "!"
        or character == "?"
        or character == ";"
        or character == ":"
        or character == "。"
        or character == "，"
        or character == "！"
        or character == "？"
        or character == "；"
        or character == "："
        or character == "、"
        or character == "…"
        or character == "】"
        or character == ")"
        or character == "）"
end

function CreditsScene:getFinalCharacterDelay()
    local previous = self.final_characters[self.final_visible_count]
    if previous and isCreditsPunctuation(previous) then
        return self.final_char_delay + TYPEWRITER_PUNCTUATION_PAUSE
    end
    return self.final_char_delay
end

function CreditsScene:advanceCard()
    self.card_timer = 0
    self.card_index = self.card_index + 1
    Input.clear("confirm", true)
    self:resetFinalText()
    if self.card_index > #self.localized_cards then
        self:finish()
    end
end

function CreditsScene:getSettlementCardIndex()
    for index, card in ipairs(self.localized_cards or {}) do
        if card.record then
            return index
        end
    end
    return nil
end

function CreditsScene:jumpToSettlement()
    local settlement_index = self:getSettlementCardIndex()
    if not settlement_index or self.card_index >= settlement_index then
        self.hold_time = 0
        Input.clear("confirm", true)
        return
    end

    self.card_index = settlement_index
    self.card_timer = 0
    self.hold_time = 0
    Input.clear("confirm", true)
    self:resetFinalText()
end

function CreditsScene:revealFinalText(delta_time)
    self.final_reveal_timer = self.final_reveal_timer + delta_time
    while self.final_reveal_timer >= self:getFinalCharacterDelay()
        and self.final_visible_count < #self.final_characters
    do
        self.final_reveal_timer = self.final_reveal_timer - self:getFinalCharacterDelay()
        self.final_visible_count = self.final_visible_count + 1
    end
end

function CreditsScene:getRolledRecordValue(value)
    local progress = math.min(self.record_roll_timer / RECORD_ROLL_TIME, 1)
    return math.floor((tonumber(value) or 0) * progress)
end

function CreditsScene:getRecordRows(card)
    local stats = self.record_stats or {}
    local encounters = stats.encounters or {}
    local kris = encounters.kris or {}
    local finisher = encounters.kris_finisher or {}
    local labels = card.labels

    local function number(value)
        return tostring(self:getRolledRecordValue(value))
    end

    local function noHitTurns()
        local progress = math.min(self.record_roll_timer / RECORD_ROLL_TIME, 1)
        local parts = {}
        local function appendTurns(prefix, turns)
            local visible_count = math.floor(#turns * progress)
            if visible_count <= 0 then
                return
            end
            local values = {}
            for index = 1, visible_count do
                table.insert(values, tostring(turns[index]))
            end
            table.insert(parts, prefix .. ":" .. table.concat(values, ","))
        end
        appendTurns("K", kris.no_hit_turns or {})
        appendTurns("F", finisher.no_hit_turns or {})
        return #parts > 0 and table.concat(parts, " ") or "0"
    end

    local seed = tostring(stats.seed_display or "")
    if seed:match("^%d+$") then
        seed = tostring(self:getRolledRecordValue(tonumber(seed)))
    end

    return {
        {
            labels.kris_hits,
            number(kris.actual_hits),
        },
        {
            labels.kris_bullet_hits,
            number(kris.bullet_hits),
        },
        {
            labels.finisher_hits,
            number(finisher.actual_hits),
        },
        {
            labels.finisher_bullet_hits,
            number(finisher.bullet_hits),
        },
        {
            labels.items_used,
            number(stats.items_used),
        },
        {
            labels.total_healed,
            number(stats.total_healed),
        },
        {
            labels.no_hit_turns,
            noHitTurns(),
        },
        {
            labels.max_graze_combo,
            number(stats.max_graze_combo),
        },
        {
            labels.previous_failures,
            number(stats.previous_failures),
        },
        {
            labels.total_grazes,
            number(stats.total_grazes),
        },
        {
            labels.game_time,
            formatDuration(self:getRolledRecordValue(stats.elapsed_milliseconds)),
        },
        {
            labels.run_seed,
            seed,
        },
    }
end

function CreditsScene:drawRecordCard(card, alpha)
    love.graphics.setFont(self.name_font)
    love.graphics.setColor(NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3], alpha)
    drawCenteredSpacedText(self.name_font, card.labels.title, 30)

    local rows = self:getRecordRows(card)
    local column_x = {20, SCREEN_WIDTH / 2 + 2}
    local first_y = 78
    local row_height = 32
    for index, row in ipairs(rows) do
        local column = index <= 6 and 1 or 2
        local row_index = ((index - 1) % 6)
        local text = row[1] .. ": " .. row[2]
        drawSpacedText(
            self.name_font,
            text,
            column_x[column],
            first_y + row_index * row_height
        )
    end

    self:drawVerdictCard(card, alpha)
end

function CreditsScene:drawVerdictCard(card, alpha)
    if not card.verdict_text or self.verdict_wait_timer < VERDICT_WAIT_TIME then
        return
    end

    love.graphics.setFont(self.name_font)
    local text = table.concat(self.final_characters, "", 1, self.final_visible_count)
    local line_height = NAME_LINE_HEIGHT
    local color = card.verdict_color or NAME_COLOR
    Draw.setColor(color[1], color[2], color[3], alpha)
    drawSpacedText(self.name_font, text, 20, SCREEN_HEIGHT - line_height - 18)
end

function CreditsScene:finish()
    if self.finished then
        return
    end

    self.finished = true
    self.hold_time = 0
    Input.clear("confirm", true)
    self:remove()
    if self.on_complete then
        self.on_complete()
    end
end

function CreditsScene:onRemove(parent)
    super.onRemove(self, parent)
    if self.music then
        self.music:stop()
        self.music:remove()
        self.music = nil
    end
end

function CreditsScene:update()
    super.update(self)
    self:refreshLocalization(false)

    if Input.down("confirm") then
        self.hold_time = self.hold_time + DT
        if self.hold_time >= HOLD_TO_SKIP_TIME then
            self:jumpToSettlement()
            return
        end
    else
        self.hold_time = 0
    end

    local confirm_pressed = Input.pressed("confirm")
    local card = self.localized_cards[self.card_index]
    if card and card.record then
        self.record_roll_timer = math.min(self.record_roll_timer + DT, RECORD_ROLL_TIME)
        if self.verdict_wait_timer < VERDICT_WAIT_TIME then
            self.verdict_wait_timer = self.verdict_wait_timer + DT
        elseif self.final_visible_count < #self.final_characters then
            self:revealFinalText(DT)
        else
            self.settlement_hold_timer = self.settlement_hold_timer + DT
        end

        if confirm_pressed
            and self.verdict_wait_timer >= VERDICT_WAIT_TIME
            and self.final_visible_count >= #self.final_characters
            and self.settlement_hold_timer >= SETTLEMENT_HOLD_TIME
        then
            self:advanceCard()
            return
        end
    elseif card and card.final_text and not card.static_text then
        if self.final_visible_count < #self.final_characters then
            self:revealFinalText(DT)
        else
            self.final_text_hold_timer = self.final_text_hold_timer + DT
        end

        if confirm_pressed
            and card.manual_advance
            and self.final_visible_count >= #self.final_characters
            and self.final_text_hold_timer >= FINAL_TEXT_HOLD_TIME
        then
            self:finish()
            return
        end
    end

    if card and (card.record or card.manual_advance) then
        return
    end

    self.card_timer = self.card_timer + DT
    if self.card_timer < CARD_DURATION then
        return
    end

    self:advanceCard()
end

function CreditsScene:drawGroup(credit_group, y, alpha)
    local role = "- " .. credit_group.role .. " -"

    love.graphics.setFont(self.role_font)
    love.graphics.setColor(ROLE_COLOR[1], ROLE_COLOR[2], ROLE_COLOR[3], alpha)
    drawCenteredSpacedText(self.role_font, role, y)

    love.graphics.setFont(self.name_font)
    love.graphics.setColor(NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3], alpha)
    for index, name in ipairs(credit_group.names) do
        drawCenteredSpacedText(self.name_font, name, y + ROLE_LINE_HEIGHT + ((index - 1) * NAME_LINE_HEIGHT))
    end
end

function CreditsScene:drawCard(card, alpha)
    if card.record then
        self:drawRecordCard(card, alpha)
        return
    end

    if card.final_text then
        love.graphics.setFont(self.name_font)
        love.graphics.setColor(NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3], alpha)
        local text = table.concat(self.final_characters, "", 1, self.final_visible_count)
        local full_lines = splitLines(card.final_text)
        local block_width = 0
        for _, line in ipairs(full_lines) do
            block_width = math.max(block_width, getSpacedTextWidth(self.name_font, line))
        end
        local block_x = (SCREEN_WIDTH - block_width) / 2
        local start_y = (SCREEN_HEIGHT - (#full_lines * NAME_LINE_HEIGHT)) / 2
        local visible_lines = splitLines(text)
        for index, line in ipairs(visible_lines) do
            if line ~= "" then
                if card.static_text and index == 1 then
                    love.graphics.setColor(ROLE_COLOR[1], ROLE_COLOR[2], ROLE_COLOR[3], alpha)
                else
                    love.graphics.setColor(NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3], alpha)
                end
                local y = start_y + ((index - 1) * NAME_LINE_HEIGHT)
                if card.static_text then
                    drawCenteredSpacedText(self.name_font, line, y)
                else
                    drawSpacedText(self.name_font, line, block_x, y)
                end
            end
        end
        return
    end

    local total_height = 0
    local group_heights = {}
    for index, credit_group in ipairs(card.groups) do
        local height = ROLE_LINE_HEIGHT + (#credit_group.names * NAME_LINE_HEIGHT)
        group_heights[index] = height
        total_height = total_height + height
        if index < #card.groups then
            total_height = total_height + card.gap
        end
    end

    local y = (SCREEN_HEIGHT - total_height) / 2
    for index, credit_group in ipairs(card.groups) do
        self:drawGroup(credit_group, y, alpha)
        y = y + group_heights[index] + card.gap
    end
end

function CreditsScene:draw()
    self:refreshLocalization(false)

    local old_font = love.graphics.getFont()
    local card = self.localized_cards[self.card_index]

    love.graphics.push()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    if card then
        self:drawCard(card, 1)
    end
    if self.hold_time > 0 then
        local width = 224
        local height = 4
        local x = SCREEN_WIDTH - width - 20
        local y = SCREEN_HEIGHT - 10
        local progress = math.min(self.hold_time / HOLD_TO_SKIP_TIME, 1)

        Draw.setColor(0.28, 0.28, 0.28, 1)
        love.graphics.rectangle("fill", x, y, width, height)
        Draw.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", x, y, width * progress, height)
    end
    love.graphics.pop()
    love.graphics.setFont(old_font)
end

return CreditsScene
