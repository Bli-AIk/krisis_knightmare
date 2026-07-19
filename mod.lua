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

local function parseNumberList(value)
    local result = {}
    if type(value) ~= "string" then
        return result
    end

    for item in value:gmatch("[^,]+") do
        local number = tonumber(item)
        if number then
            table.insert(result, number)
        end
    end
    return result
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

local function parseMercyValue(value)
    local number = tonumber(value)
    if not number or number < 0 or number > 100 then
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
local KRISIS_FINISHER_RESUME_FILE = "kris_finisher_resume"
local KRISIS_FINISHER_RESUME_VERSION = 2
local KRISIS_STATS_PAYLOAD_VERSION = 3
local KRISIS_STATS_MAGIC = "KRS"
local KRISIS_STATS_BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local KRISIS_STATS_ENCOUNTERS = {
    kris = true,
    kris_finisher = true,
}
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
local KRISIS_CHAPTER_SECRET_SOUND_START = 10
local KRISIS_CHAPTER_SECRET_SOUND_MAX_VOLUME = 1.225
local KRISIS_CHAPTER5_ALTERNATIONS_TARGET = 5
local KRISIS_SEED_DIGIT_COUNT = 10
local KRISIS_SEED_ENTRY_REACTION_TIME = 1
local KRISIS_SEED_TRANSITION_TIME = 0.75
local KRISIS_SEED_SLIDE_TIME = 0.35

local function getNonNegativeInteger(value)
    value = tonumber(value)
    if not value or value < 0 then
        return 0
    end
    return math.floor(value)
end

local function newKrisisGameStats(previous_failures, seed_display)
    return {
        encounters = {
            kris = {
                bullet_damage = 0,
                bullet_hits = 0,
                no_hit_turns = {},
            },
            kris_finisher = {
                bullet_damage = 0,
                bullet_hits = 0,
                no_hit_turns = {},
            },
        },
        items_used = 0,
        total_healed = 0,
        max_graze_combo = 0,
        current_graze_combo = 0,
        total_grazes = 0,
        previous_failures = getNonNegativeInteger(previous_failures),
        elapsed_milliseconds = 0,
        seed_display = tostring(seed_display or ""),
    }
end

local function appendByte(parts, value)
    table.insert(parts, string.char(value % 256))
end

local function appendUint16(parts, value)
    value = getNonNegativeInteger(value) % 65536
    appendByte(parts, math.floor(value / 256))
    appendByte(parts, value)
end

local function appendUint32(parts, value)
    value = getNonNegativeInteger(value) % 4294967296
    appendByte(parts, math.floor(value / 16777216))
    appendByte(parts, math.floor(value / 65536))
    appendByte(parts, math.floor(value / 256))
    appendByte(parts, value)
end

local function readByte(data, position)
    if position > #data then
        return nil, position
    end
    return string.byte(data, position), position + 1
end

local function readUint16(data, position)
    local first, next_position = readByte(data, position)
    if not first then
        return nil, position
    end
    local second
    second, next_position = readByte(data, next_position)
    if not second then
        return nil, position
    end
    return first * 256 + second, next_position
end

local function readUint32(data, position)
    local first, next_position = readByte(data, position)
    if not first then
        return nil, position
    end
    local second
    second, next_position = readByte(data, next_position)
    if not second then
        return nil, position
    end
    local third
    third, next_position = readByte(data, next_position)
    if not third then
        return nil, position
    end
    local fourth
    fourth, next_position = readByte(data, next_position)
    if not fourth then
        return nil, position
    end
    return first * 16777216 + second * 65536 + third * 256 + fourth, next_position
end

local function checksumBytes(data, context)
    local checksum = 2166136261
    local salt = table.concat({
        os.getenv("USER") or os.getenv("USERNAME") or "unknown-user",
        os.getenv("HOME") or os.getenv("USERPROFILE") or "unknown-home",
        os.getenv("HOSTNAME") or os.getenv("COMPUTERNAME") or "unknown-host",
    }, "\0")
    local material = salt .. "\0" .. tostring(context or "stats")
    for index = 1, #material do
        checksum = (checksum * 16777619 + string.byte(material, index)) % 4294967296
    end
    for index = 1, #data do
        checksum = (checksum * 16777619 + string.byte(data, index)) % 4294967296
    end
    return checksum
end

local function base64Encode(data)
    local result = {}
    local alphabet = KRISIS_STATS_BASE64_ALPHABET
    for index = 1, #data, 3 do
        local first = string.byte(data, index) or 0
        local second = string.byte(data, index + 1)
        local third = string.byte(data, index + 2)
        local value = first * 65536 + (second or 0) * 256 + (third or 0)
        local first_index = math.floor(value / 262144) % 64 + 1
        local second_index = math.floor(value / 4096) % 64 + 1
        local third_index = math.floor(value / 64) % 64 + 1
        local fourth_index = value % 64 + 1

        table.insert(result, alphabet:sub(first_index, first_index))
        table.insert(result, alphabet:sub(second_index, second_index))
        table.insert(result, second and alphabet:sub(third_index, third_index) or "=")
        table.insert(result, third and alphabet:sub(fourth_index, fourth_index) or "=")
    end
    return table.concat(result)
end

local function base64Decode(data)
    if type(data) ~= "string" or (#data % 4) ~= 0 then
        return nil
    end

    local alphabet = KRISIS_STATS_BASE64_ALPHABET
    local result = {}
    for index = 1, #data, 4 do
        local values = {}
        local padding = 0
        for offset = 0, 3 do
            local character = data:sub(index + offset, index + offset)
            if character == "=" then
                values[offset + 1] = 0
                padding = padding + 1
            else
                local value = alphabet:find(character, 1, true)
                if not value then
                    return nil
                end
                values[offset + 1] = value - 1
            end
        end

        local combined = values[1] * 262144
            + values[2] * 4096
            + values[3] * 64
            + values[4]
        appendByte(result, math.floor(combined / 65536))
        if padding < 2 then
            appendByte(result, math.floor(combined / 256))
        end
        if padding == 0 then
            appendByte(result, combined)
        end
    end
    return table.concat(result)
end

local function encodeKrisisGameStats(stats, context)
    if type(stats) ~= "table" then
        return nil
    end

    local kris = stats.encounters and stats.encounters.kris or {}
    local finisher = stats.encounters and stats.encounters.kris_finisher or {}
    local seed_display = tostring(stats.seed_display or "")
    local seed_length = math.min(#seed_display, 65535)
    seed_display = seed_display:sub(1, seed_length)

    local parts = {
        KRISIS_STATS_MAGIC,
        string.char(KRISIS_STATS_PAYLOAD_VERSION),
    }
    local values = {
        kris.bullet_damage,
        kris.bullet_hits,
        #kris.no_hit_turns,
        finisher.bullet_damage,
        finisher.bullet_hits,
        #finisher.no_hit_turns,
        stats.items_used,
        stats.total_healed,
        stats.max_graze_combo,
        stats.previous_failures,
        stats.total_grazes,
        stats.elapsed_milliseconds,
    }
    for _, value in ipairs(values) do
        appendUint32(parts, value)
    end
    appendUint16(parts, seed_length)
    table.insert(parts, seed_display)
    appendUint16(parts, math.min(#kris.no_hit_turns, 65535))
    for index = 1, math.min(#kris.no_hit_turns, 65535) do
        appendUint16(parts, kris.no_hit_turns[index])
    end
    appendUint16(parts, math.min(#finisher.no_hit_turns, 65535))
    for index = 1, math.min(#finisher.no_hit_turns, 65535) do
        appendUint16(parts, finisher.no_hit_turns[index])
    end

    local body = table.concat(parts)
    local payload = body .. string.char(
        math.floor(checksumBytes(body, context) / 16777216) % 256,
        math.floor(checksumBytes(body, context) / 65536) % 256,
        math.floor(checksumBytes(body, context) / 256) % 256,
        checksumBytes(body, context) % 256
    )
    return base64Encode(payload)
end

local function decodeKrisisGameStats(payload, context)
    local data = base64Decode(payload)
    if not data or #data < 4 + (12 * 4) + 2 + 4 then
        return nil
    end

    local body = data:sub(1, -5)
    local stored_checksum = readUint32(data, #data - 3)
    if not stored_checksum or checksumBytes(body, context) ~= stored_checksum then
        return nil
    end
    if data:sub(1, 3) ~= KRISIS_STATS_MAGIC
        or string.byte(data, 4) ~= KRISIS_STATS_PAYLOAD_VERSION
    then
        return nil
    end

    local position = 5
    local values = {}
    for index = 1, 12 do
        local value
        value, position = readUint32(data, position)
        if value == nil then
            return nil
        end
        values[index] = value
    end
    local seed_length
    seed_length, position = readUint16(data, position)
    if not seed_length or position + seed_length - 1 > #body then
        return nil
    end
    local seed_display = data:sub(position, position + seed_length - 1)

    local stats = newKrisisGameStats(values[10], seed_display)
    stats.encounters.kris.bullet_damage = values[1]
    stats.encounters.kris.bullet_hits = values[2]
    stats.encounters.kris.no_hit_turns = {}
    stats.encounters.kris_finisher.bullet_damage = values[4]
    stats.encounters.kris_finisher.bullet_hits = values[5]
    stats.encounters.kris_finisher.no_hit_turns = {}
    stats.items_used = values[7]
    stats.total_healed = values[8]
    stats.max_graze_combo = values[9]
    stats.total_grazes = values[11]
    stats.elapsed_milliseconds = values[12]
    position = position + seed_length
    local kris_no_hit_count
    kris_no_hit_count, position = readUint16(data, position)
    if not kris_no_hit_count then
        return nil
    end
    for _ = 1, kris_no_hit_count do
        local round
        round, position = readUint16(data, position)
        if not round then
            return nil
        end
        table.insert(stats.encounters.kris.no_hit_turns, round)
    end
    local finisher_no_hit_count
    finisher_no_hit_count, position = readUint16(data, position)
    if not finisher_no_hit_count then
        return nil
    end
    for _ = 1, finisher_no_hit_count do
        local round
        round, position = readUint16(data, position)
        if not round then
            return nil
        end
        table.insert(stats.encounters.kris_finisher.no_hit_turns, round)
    end
    return stats
end

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
    elseif key == "krisisInitialMercy" then
        self:loadKrisisRunOptions()
        if self.krisis_run_initial_mercy ~= nil then
            return self.krisis_run_initial_mercy
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

local function playChapterSeedProgressSound(count, target)
    if count <= KRISIS_CHAPTER_SECRET_SOUND_START then
        return
    end

    local progress = (count - KRISIS_CHAPTER_SECRET_SOUND_START)
        / (target - KRISIS_CHAPTER_SECRET_SOUND_START)
    local volume = math.min(progress, 1) * KRISIS_CHAPTER_SECRET_SOUND_MAX_VOLUME
    Assets.playSound("ui_move", volume)
end

function Mod:resetChapterSeedInputState(menu)
    if not menu then
        return
    end

    menu.krisis_seed_input_chapter = nil
    menu.krisis_seed_chapter3_left_count = 0
    menu.krisis_seed_chapter4_right_count = 0
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
        playChapterSeedProgressSound(
            menu.krisis_seed_chapter3_left_count,
            KRISIS_CHAPTER3_LEFT_TARGET
        )
        if menu.krisis_seed_chapter3_left_count >= KRISIS_CHAPTER3_LEFT_TARGET then
            Assets.playSound("snd_flee")
            self:beginChapterSeedEntry(menu, chapter_index)
            return true
        end
    elseif chapter_index == 4 and Input.is("right", key) then
        menu.krisis_seed_chapter4_right_count = menu.krisis_seed_chapter4_right_count + 1
        playChapterSeedProgressSound(
            menu.krisis_seed_chapter4_right_count,
            KRISIS_CHAPTER4_RIGHT_TARGET
        )
        if menu.krisis_seed_chapter4_right_count >= KRISIS_CHAPTER4_RIGHT_TARGET then
            self:beginChapterSeedEntry(menu, chapter_index)
            return true
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

function Mod:initializeKrisisGameStats()
    self.krisis_game_stats = nil
    self.krisis_retry_stats = nil
    self.krisis_run_started = false
    self.krisis_run_completed = false
    self.krisis_failure_recorded = false
    self.krisis_stats_start_playtime = nil
    self.krisis_stats_elapsed_base = 0
    self.krisis_finisher_resume_saved = false
end

function Mod:restoreKrisisGameStats(stats, continue_run)
    if type(stats) ~= "table" then
        return false
    end

    if stats.seed_display and stats.seed_display ~= "" then
        local ok = pcall(function()
            self:setKrisisRunSeed(stats.seed_display)
        end)
        if not ok then
            return false
        end
    end

    if continue_run then
        self.krisis_game_stats = stats
        self.krisis_retry_stats = nil
        self.krisis_run_started = true
        self.krisis_stats_start_playtime = Game and Game.playtime or 0
        self.krisis_stats_elapsed_base = stats.elapsed_milliseconds or 0
    else
        self.krisis_retry_stats = stats
    end
    return true
end

function Mod:startKrisisGameStats(encounter_id)
    if not KRISIS_STATS_ENCOUNTERS[encounter_id] then
        return false
    end
    if self.krisis_run_started then
        return true
    end

    local retry_stats = self.krisis_retry_stats
    local previous_failures = retry_stats and retry_stats.previous_failures or 0
    local seed_display = self.krisis_run_seed_display
    if not seed_display and retry_stats then
        seed_display = retry_stats.seed_display
    end
    self:getKrisisRunSeed()
    seed_display = seed_display or self.krisis_run_seed_display or self.krisis_run_seed

    self.krisis_game_stats = newKrisisGameStats(previous_failures, seed_display)
    self.krisis_retry_stats = nil
    self.krisis_run_started = true
    self.krisis_run_completed = false
    self.krisis_failure_recorded = false
    self.krisis_stats_start_playtime = Game and Game.playtime or 0
    self.krisis_stats_elapsed_base = 0
    return true
end

function Mod:beginKrisisBattle(battle)
    local encounter = battle and battle.encounter
    local encounter_id = encounter and encounter.id
    if not self:startKrisisGameStats(encounter_id) then
        return
    end

    battle.krisis_stats_encounter_id = encounter_id
    battle.krisis_stats_round_active = false
    battle.krisis_stats_round_hurt = false
end

function Mod:getKrisisStatsForBattle(battle)
    if not battle or not self.krisis_game_stats then
        return nil
    end
    local encounter_id = battle.krisis_stats_encounter_id
    if not KRISIS_STATS_ENCOUNTERS[encounter_id] then
        return nil
    end
    return self.krisis_game_stats.encounters[encounter_id], self.krisis_game_stats
end

function Mod:recordKrisisBulletDamage(battler, before, after)
    local battle = Game and Game.battle
    local encounter_stats, stats = self:getKrisisStatsForBattle(battle)
    if not encounter_stats then
        return
    end

    local damage = math.max((before or 0) - (after or 0), 0)
    if damage > 0 then
        encounter_stats.bullet_damage = encounter_stats.bullet_damage + damage
    end
end

function Mod:recordKrisisBulletHit(soul, bullet)
    local battle = Game and Game.battle
    local encounter_stats, stats = self:getKrisisStatsForBattle(battle)
    if not encounter_stats then
        return
    end

    encounter_stats.bullet_hits = encounter_stats.bullet_hits + 1
    if battle.krisis_stats_round_active then
        battle.krisis_stats_round_hurt = true
    end
    stats.current_graze_combo = 0
end

function Mod:recordKrisisGraze(soul, bullet, old_graze)
    if old_graze then
        return
    end
    local _, stats = self:getKrisisStatsForBattle(Game and Game.battle)
    if not stats then
        return
    end

    stats.total_grazes = stats.total_grazes + 1
    stats.current_graze_combo = stats.current_graze_combo + 1
    stats.max_graze_combo = math.max(stats.max_graze_combo, stats.current_graze_combo)
end

function Mod:recordKrisisItemUse(item)
    local _, stats = self:getKrisisStatsForBattle(Game and Game.battle)
    if stats then
        stats.items_used = stats.items_used + 1
    end
end

function Mod:recordKrisisHeal(party_member, before, after)
    local _, stats = self:getKrisisStatsForBattle(Game and Game.battle)
    if not stats then
        return
    end

    stats.total_healed = stats.total_healed + math.max((after or 0) - (before or 0), 0)
end

function Mod:finishKrisisBattleRound(battle, count_no_hit)
    if not battle or not battle.krisis_stats_round_active then
        return
    end

    local encounter_stats = self:getKrisisStatsForBattle(battle)
    if encounter_stats and count_no_hit and not battle.krisis_stats_round_hurt then
        table.insert(encounter_stats.no_hit_turns, math.max(battle.turn_count or 0, 1))
    end
    battle.krisis_stats_round_active = false
end

function Mod:onKrisisBattleStateChange(battle, old, new)
    if new == "DEFENDINGBEGIN" then
        battle.krisis_stats_round_active = true
        battle.krisis_stats_round_hurt = false
    elseif old == "DEFENDING" and new ~= "DEFENDINGBEGIN" then
        self:finishKrisisBattleRound(battle, new ~= "TRANSITIONOUT")
    end
end

function Mod:onKrisisBattleGameOver(battle)
    self:finishKrisisBattleRound(battle, false)
end

function Mod:getKrisisGameStatsElapsedMilliseconds()
    local stats = self.krisis_game_stats
    if not stats then
        return 0
    end

    local elapsed = self.krisis_stats_elapsed_base or 0
    if self.krisis_stats_start_playtime ~= nil and Game and Game.playtime then
        elapsed = elapsed + math.max(Game.playtime - self.krisis_stats_start_playtime, 0) * 1000
    end
    return math.floor(elapsed)
end

function Mod:getKrisisGameStatsSnapshot()
    local stats = self.krisis_game_stats
    if not stats then
        stats = newKrisisGameStats(0, self.krisis_run_seed_display or self.krisis_run_seed or "")
    end

    local snapshot = newKrisisGameStats(stats.previous_failures, stats.seed_display)
    for _, encounter_id in ipairs({"kris", "kris_finisher"}) do
        for key, value in pairs(stats.encounters[encounter_id]) do
            if key == "no_hit_turns" then
                snapshot.encounters[encounter_id][key] = {}
                for _, round in ipairs(value) do
                    table.insert(snapshot.encounters[encounter_id][key], round)
                end
            else
                snapshot.encounters[encounter_id][key] = value
            end
        end
    end
    snapshot.items_used = stats.items_used
    snapshot.total_healed = stats.total_healed
    snapshot.max_graze_combo = stats.max_graze_combo
    snapshot.total_grazes = stats.total_grazes
    snapshot.elapsed_milliseconds = self:getKrisisGameStatsElapsedMilliseconds()
    snapshot.seed_display = stats.seed_display
        or self.krisis_run_seed_display
        or tostring(self.krisis_run_seed or "")
    return snapshot
end

function Mod:saveKrisisRunState(encounter)
    if not Kristal or not Kristal.saveData or not self.krisis_game_stats then
        return false
    end

    local payload = encodeKrisisGameStats(self:getKrisisGameStatsSnapshot(), encounter)
    if not payload then
        return false
    end

    local ok, err = pcall(function()
        Kristal.saveData(KRISIS_FINISHER_RESUME_FILE, {
            version = KRISIS_FINISHER_RESUME_VERSION,
            encounter = encounter,
            payload = payload,
        })
    end)
    if not ok then
        print("[KRISIS] Failed to save run state: " .. tostring(err))
        return false
    end
    return true
end

function Mod:recordKrisisGameOver()
    if not self.krisis_run_started or self.krisis_run_completed or self.krisis_failure_recorded then
        return
    end

    self.krisis_failure_recorded = true
    self.krisis_game_stats.previous_failures = self.krisis_game_stats.previous_failures + 1
    self:onKrisisBattleGameOver(Game and Game.battle)
    self:saveKrisisRunState("retry")
end

function Mod:completeKrisisGameStats()
    self.krisis_run_completed = true
    self.krisis_retry_stats = nil
    if Kristal and Kristal.eraseData then
        pcall(Kristal.eraseData, KRISIS_FINISHER_RESUME_FILE)
    end
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

function Mod:saveKrisisFinisherResume()
    if self.krisis_finisher_resume_saved then
        return true
    end

    if not self:saveKrisisRunState("kris_finisher") then
        print("[KRISIS] Failed to save finisher resume")
        return false
    end

    self.krisis_finisher_resume_saved = true
    return true
end

function Mod:loadKrisisFinisherResume()
    if self.krisis_finisher_resume_checked then
        return self.krisis_finisher_resume_pending == true
    end
    self.krisis_finisher_resume_checked = true

    local _, has_encounter = getKristalArg("encounter")
    if not Kristal or not Kristal.loadData then
        return false
    end

    local ok, data = pcall(Kristal.loadData, KRISIS_FINISHER_RESUME_FILE)
    if not ok then
        print("[KRISIS] Failed to load finisher resume: " .. tostring(data))
        return false
    end

    if type(data) ~= "table"
        or (data.version ~= 1 and data.version ~= KRISIS_FINISHER_RESUME_VERSION)
        or (data.encounter ~= "kris_finisher" and data.encounter ~= "retry")
    then
        return false
    end

    if data.payload then
        local stats = decodeKrisisGameStats(data.payload, data.encounter)
        if not stats then
            print("[KRISIS] Ignoring run state with an invalid local checksum")
            return false
        end
        if data.encounter == "retry" then
            self:restoreKrisisGameStats(stats, false)
            return false
        end
        if has_encounter or not self:restoreKrisisGameStats(stats, true) then
            return false
        end
    elseif has_encounter then
        return false
    end

    self.krisis_finisher_resume_pending = true
    self:setTemporaryDefaultBattleEntry("kris_finisher")
    self.krisis_update_check_seen = true
    self.krisis_intro_seen = true
    return true
end

function Mod:consumeKrisisFinisherResume()
    if not self.krisis_finisher_resume_pending
        or not Game
        or not Game.battle
        or not Game.battle.encounter
        or Game.battle.encounter.id ~= "kris_finisher"
        or not Kristal
        or not Kristal.eraseData
    then
        return
    end

    local ok, err = pcall(function()
        Kristal.eraseData(KRISIS_FINISHER_RESUME_FILE)
    end)
    if not ok then
        print("[KRISIS] Failed to clear finisher resume: " .. tostring(err))
        return
    end

    self.krisis_finisher_resume_pending = false
    self.krisis_finisher_resume_consumed = true
end

function Mod:startKrisisBattlePrep()
    local stage = (Game and Game.stage) or (Kristal and Kristal.Stage)
    if BattlePrepScene and stage then
        stage:addChild(BattlePrepScene({
            encounter = "kris",
        }))
    elseif Game then
        Game:encounter("kris", false)
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
    local initial_mercy, has_initial_mercy = getKristalArg("mercy")
    if not has_initial_mercy then
        initial_mercy, has_initial_mercy = getKristalArg("initial-mercy")
    end
    local _, has_proceed = getKristalArg("proceed")

    self.krisis_run_proceed = has_proceed

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

    if has_initial_mercy then
        self.krisis_run_initial_mercy = parseMercyValue(initial_mercy)
        if self.krisis_run_initial_mercy == nil then
            print("Ignoring invalid --mercy value: " .. tostring(initial_mercy))
        end
    end

    if (self.krisis_run_wave or self.krisis_run_wave_force or self.krisis_run_initial_tp ~= nil
        or self.krisis_run_initial_mercy ~= nil or self.krisis_run_proceed)
        and not has_encounter
    then
        self:setTemporaryDefaultBattleEntry("kris")
    end
end

function Mod:isKrisisRunProceed()
    self:loadKrisisRunOptions()
    return self.krisis_run_proceed == true
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
    self:initializeKrisisGameStats()
    self.krisis_finisher_resume_checked = false
    self.krisis_finisher_resume_pending = false
    self:loadKrisisFinisherResume()
    self:getKrisisRunSeed()
    self:updateKrisisWindowTitle()

    if envFlag("KRISIS_DEBUG_PROJECT4_SCENE") and OverworldScene and Kristal.Stage then
        self.krisis_update_check_seen = true
        self.krisis_intro_seen = true
        local capture_times = parseNumberList(os.getenv("KRISIS_PROJECT4_CAPTURE_TIMES"))
        if #capture_times == 0 then
            capture_times = nil
        elseif love.window then
            love.window.setMode(1280, 960, {resizable = false, vsync = 0})
        end

        self.overworld_scene = Kristal.Stage:addChild(OverworldScene({
            start_time = tonumber(os.getenv("KRISIS_PROJECT4_START_TIME")),
            capture_times = capture_times,
            capture_directory = os.getenv("KRISIS_PROJECT4_CAPTURE_DIR"),
            disable_particles = envFlag("KRISIS_PROJECT4_DISABLE_PARTICLES"),
            particle_center_x = os.getenv("KRISIS_PROJECT4_PARTICLE_CENTER_X"),
            particle_center_y = os.getenv("KRISIS_PROJECT4_PARTICLE_CENTER_Y"),
            quit_after_capture = envFlag("KRISIS_PROJECT4_QUIT"),
        }))
    end

    if (envFlag("KRISIS_FINISHER_PROFILE") or envFlag("KRISIS_PROFILE")) and FinisherProfiler then
        self.finisher_profiler = FinisherProfiler()
    end

    Game:registerEvent("squeak", function(data)
        return Squeak(data.x, data.y, {data.width, data.height, data.polygon})
    end)
    print(loc("Loaded [var:name]!", "mod.loaded", {name = self.info.name}))
end

function Mod:postLoad()
    if self.krisis_run_started then
        self.krisis_stats_start_playtime = Game and Game.playtime or 0
    end
    if not self.krisis_finisher_resume_pending or Game.battle then
        return
    end

    -- A normal save file skips Game:load's new-file encounter branch. Start
    -- the resumed battle here after the saved world has been reconstructed.
    Game:encounter("kris_finisher", false)
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

    local battle = Game.battle
    local encounter = battle and battle.encounter
    if encounter and encounter.drawFinisherHurtFlash then
        encounter:drawFinisherHurtFlash()
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
