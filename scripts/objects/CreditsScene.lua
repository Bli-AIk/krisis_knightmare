local CreditsScene, super = Class(Object)

local CREDITS_BPM = 80
local CREDITS_BEATS_PER_CARD = 8
local CARD_DURATION = CREDITS_BEATS_PER_CARD * 60 / CREDITS_BPM
local CREDITS_MUSIC = "credits"
local CREDITS_MUSIC_VOLUME = 0.8
local HOLD_TO_SKIP_TIME = 0.65
local CREDITS_FONT_SIZE = 32
local CREDITS_EN_RECORD_FONT_SIZE = 16
local CREDITS_EN_RECORD_ROW_HEIGHT = 24
local CREDIT_NAME_FONT_PATH = "lang/zh_hans/main_mono"
local NAME_LINE_HEIGHT = 32
local ROLE_LINE_HEIGHT = 32
local CJK_TEXT_SPACING = 2
local RECORD_ROLL_TIME = 0.8
local RECORD_ROLL_SOUND_INTERVAL = 0.06
local VERDICT_WAIT_TIME = 4 * 60 / CREDITS_BPM
local FINAL_TEXT_FADE_OUT_TIME = 1
local FINAL_TEXT_RIGHT_PADDING = 16
local FINAL_TEXT_BOTTOM_PADDING = 8
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
    local parts = {}
    if hours > 0 then
        table.insert(parts, string.format("%dh", hours))
    end
    if minutes > 0 then
        table.insert(parts, string.format("%dm", minutes))
    end
    if seconds > 0 or #parts == 0 then
        table.insert(parts, string.format("%ds", seconds))
    end
    return table.concat(parts, " ")
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
    ["credits.final_text"] = "[speed:0.5]The story of DELTARUNE[wait:0.5s]\nwill continue here.",
    ["credits.final_text_original"] = "[speed:0.5]DELTARUNE 的故事[wait:0.5s]\n将于此续写下去。",
    ["credits.thank_you_text"] = "- And most importantly... -\nYou, the Player.\n\nThank you for playing.",
}

local CREDIT_RECORD_DEFAULTS = {
    title = "GAME RECORD",
    kris_hits = "KRIS BULLET HITS",
    kris_bullet_hits = "KRIS BULLET DAMAGE",
    finisher_hits = "FINISHER BULLET HITS",
    finisher_bullet_hits = "FINISHER BULLET DAMAGE",
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
    no_item = "NO ITEM[wait:3s] - THE SHADOWS CUTTING DEEPER",
    no_hit = "NO HIT[wait:3s] - SEEMS VERY VERY INTERESTING",
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
    self.verdict_dialogue = nil
    self.final_dialogue = nil
    self.record_roll_timer = 0
    self.record_roll_sound_timer = 0
    self.verdict_wait_timer = 0
    self.fading_out = false
    self.fade_out_timer = 0
    self.fade_alpha = 1
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
    if (kris.bullet_hits or 0) == 0 and (finisher.bullet_hits or 0) == 0 then
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
    -- Contributor names stay in their original scripts, including Chinese.
    self.name_font = Assets.getFont(CREDIT_NAME_FONT_PATH, CREDITS_FONT_SIZE)
        or Assets.getFont(font_path, CREDITS_FONT_SIZE)
        or Assets.getFont("main_mono", CREDITS_FONT_SIZE)
    self.record_font = self.name_font
    if language == "en" then
        self.record_font = Assets.getFont(
            CREDIT_NAME_FONT_PATH,
            CREDITS_EN_RECORD_FONT_SIZE
        ) or Assets.getFont("main_mono", CREDITS_EN_RECORD_FONT_SIZE)
            or self.name_font
    end
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
                manual_advance = card.manual_advance == true,
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
    self.record_roll_sound_timer = 0
    self.verdict_wait_timer = 0
    if self.verdict_dialogue then
        self.verdict_dialogue.visible = false
        self.verdict_dialogue:setPaused(true)
    end
    if self.final_dialogue then
        self.final_dialogue.visible = false
        self.final_dialogue:setPaused(true)
    end
    if not final_card then
        return
    end

    if final_card.record then
        self:configureVerdictDialogue(final_card.verdict_text)
        return
    end

    if final_card.final_text and not final_card.static_text then
        self:configureFinalDialogue(final_card.final_text)
    end
end

local function stripTextCommands(text)
    return (text or ""):gsub("%b[]", "")
end

function CreditsScene:getCenteredTextLayout(text)
    local block_width = 0
    local lines = splitLines(stripTextCommands(text))
    for _, line in ipairs(lines) do
        block_width = math.max(block_width, getSpacedTextWidth(self.name_font, line))
    end
    block_width = math.max(block_width, 1)
    return (SCREEN_WIDTH - block_width) / 2,
        (SCREEN_HEIGHT - (#lines * NAME_LINE_HEIGHT)) / 2,
        block_width + FINAL_TEXT_RIGHT_PADDING,
        math.max(NAME_LINE_HEIGHT, #lines * NAME_LINE_HEIGHT) + FINAL_TEXT_BOTTOM_PADDING
end

function CreditsScene:configureVerdictDialogue(text)
    if not self.verdict_dialogue then
        self.verdict_dialogue = self:addChild(DialogueText("", 20, SCREEN_HEIGHT - NAME_LINE_HEIGHT - 18,
            SCREEN_WIDTH - 20, NAME_LINE_HEIGHT, {
                font = "main_mono",
                font_size = CREDITS_FONT_SIZE,
                style = "none",
                wrap = false,
                line_offset = 0,
            }))
        self.verdict_dialogue.can_advance = false
    end

    self.verdict_dialogue.font = "main_mono"
    self.verdict_dialogue.font_size = CREDITS_FONT_SIZE
    self.verdict_dialogue:setText(text)
    local color = self:getVerdictColor()
    self.verdict_dialogue:setColor(color[1], color[2], color[3], 1)
    self.verdict_dialogue.visible = false
    self.verdict_dialogue:setPaused(true)
end

function CreditsScene:configureFinalDialogue(text)
    local x, y, width, height = self:getCenteredTextLayout(text)
    if not self.final_dialogue then
        self.final_dialogue = self:addChild(DialogueText("", x, y, width, height, {
            font = "main_mono",
            font_size = CREDITS_FONT_SIZE,
            style = "none",
            wrap = false,
            line_offset = 0,
        }))
        self.final_dialogue.can_advance = false
    end

    self.final_dialogue.font = "main_mono"
    self.final_dialogue.font_size = CREDITS_FONT_SIZE
    self.final_dialogue.x = x
    self.final_dialogue.y = y
    self.final_dialogue.width = width
    self.final_dialogue.height = height
    self.final_dialogue:setText(text)
    self.final_dialogue:setColor(NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3], 1)
    self.final_dialogue.visible = true
    self.final_dialogue:setPaused(false)
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
            number(kris.bullet_hits),
        },
        {
            labels.kris_bullet_hits,
            number(kris.bullet_damage),
        },
        {
            labels.finisher_hits,
            number(finisher.bullet_hits),
        },
        {
            labels.finisher_bullet_hits,
            number(finisher.bullet_damage),
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
    local english_layout = self.current_language == "en"
    local record_font = self.record_font or self.name_font
    local column_x = {20, SCREEN_WIDTH / 2 + 2}
    local column_centers = {SCREEN_WIDTH * 0.25, SCREEN_WIDTH * 0.75}
    local first_y = english_layout and 88 or 78
    local row_height = english_layout and CREDITS_EN_RECORD_ROW_HEIGHT or 32
    for index, row in ipairs(rows) do
        local column = index <= 6 and 1 or 2
        local row_index = ((index - 1) % 6)
        local text = row[1] .. ": " .. row[2]
        local x = column_x[column]
        if english_layout then
            x = column_centers[column]
                - getSpacedTextWidth(record_font, text) / 2
        end
        love.graphics.setFont(record_font)
        drawSpacedText(record_font, text, x, first_y + row_index * row_height)
    end

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

function CreditsScene:startFadeOut()
    if self.fading_out then
        return
    end

    self.fading_out = true
    self.fade_out_timer = 0
    self.fade_alpha = 1
    self.hold_time = 0
    Input.clear("confirm", true)
    if self.music then
        self.music:fade(0, FINAL_TEXT_FADE_OUT_TIME)
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

    if self.fading_out then
        self.fade_out_timer = self.fade_out_timer + DT
        self.fade_alpha = 1 - math.min(self.fade_out_timer / FINAL_TEXT_FADE_OUT_TIME, 1)
        if self.fade_out_timer >= FINAL_TEXT_FADE_OUT_TIME then
            self:finish()
        end
        return
    end

    local card = self.localized_cards[self.card_index]

    local manual_page = card and (card.record or card.manual_advance)
    if not manual_page and Input.down("confirm") then
        self.hold_time = self.hold_time + DT
        if self.hold_time >= HOLD_TO_SKIP_TIME then
            self:jumpToSettlement()
            return
        end
    else
        self.hold_time = 0
    end

    local confirm_pressed = Input.pressed("confirm")
    if card and card.record then
        self.record_roll_timer = math.min(self.record_roll_timer + DT, RECORD_ROLL_TIME)
        if self.record_roll_timer < RECORD_ROLL_TIME then
            self.record_roll_sound_timer = self.record_roll_sound_timer + DT
            if self.record_roll_sound_timer >= RECORD_ROLL_SOUND_INTERVAL then
                self.record_roll_sound_timer = self.record_roll_sound_timer % RECORD_ROLL_SOUND_INTERVAL
                Assets.stopAndPlaySound("ui_select")
            end
        end
        if self.verdict_wait_timer < VERDICT_WAIT_TIME then
            self.verdict_wait_timer = self.verdict_wait_timer + DT
        elseif self.verdict_dialogue and self.verdict_dialogue:isPaused() then
            self.verdict_dialogue.visible = true
            self.verdict_dialogue:setPaused(false)
        end

        if confirm_pressed
            and self.verdict_wait_timer >= VERDICT_WAIT_TIME
            and self.verdict_dialogue
            and not self.verdict_dialogue:isTyping()
        then
            self:advanceCard()
            return
        end
    elseif card and card.final_text and not card.static_text then
        if confirm_pressed
            and card.manual_advance
            and self.final_dialogue
            and not self.final_dialogue:isTyping()
        then
            self:startFadeOut()
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
        if card.static_text then
            love.graphics.setFont(self.name_font)
            local full_lines = splitLines(card.final_text)
            local start_y = (SCREEN_HEIGHT - (#full_lines * NAME_LINE_HEIGHT)) / 2
            for index, line in ipairs(full_lines) do
                if line ~= "" then
                    if index == 1 then
                        love.graphics.setColor(ROLE_COLOR[1], ROLE_COLOR[2], ROLE_COLOR[3], alpha)
                    else
                        love.graphics.setColor(NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3], alpha)
                    end
                    local y = start_y + ((index - 1) * NAME_LINE_HEIGHT)
                    drawCenteredSpacedText(self.name_font, line, y)
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
    if self.verdict_dialogue then
        self.verdict_dialogue.alpha = self.fade_alpha
    end
    if self.final_dialogue then
        self.final_dialogue.alpha = self.fade_alpha
    end
    if card then
        self:drawCard(card, self.fade_alpha)
    end
    self:drawChildren()
    local manual_page = card and (card.record or card.manual_advance)
    if self.hold_time > 0 and not manual_page then
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
