local UpdateCheckSplash, super = Class(Object)

local RELEASE_API_URL = "https://api.github.com/repos/Bli-AIk/krisis_knightmare/releases"
local RELEASE_DOWNLOAD_URL = "https://github.com/Bli-AIk/krisis_knightmare/releases"
local CHECK_TIMEOUT = 8
local HOLD_TO_SKIP_TIME = 0.35
local COPY_MESSAGE_HOLD_TIME = 0.5
local COPY_MESSAGE_FADE_TIME = 0.5
local LATEST_AUTO_DISMISS_DELAY = 0.5
local FADE_OUT_TIME = 0.25
local CJK_TEXT_SPACING = 4
local UPDATE_YELLOW = {1, 1, 0}
local UPDATE_CYAN = {0, 1, 1}

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

local function drawCenteredSpacedText(text, x, y)
    local font = love.graphics.getFont()
    drawSpacedText(text, x - (getSpacedTextWidth(font, text) / 2), y)
end

local function drawCenteredSpacedLines(text, x, y, line_height)
    local lines = {}
    local text_value = tostring(text)
    local position = 1

    while true do
        local newline_start = text_value:find("\n", position, true)
        if not newline_start then
            table.insert(lines, text_value:sub(position))
            break
        end

        table.insert(lines, text_value:sub(position, newline_start - 1))
        position = newline_start + 1
    end

    if #lines == 0 then
        return
    end

    local start_y = y - ((#lines - 1) * line_height / 2)
    for index, line in ipairs(lines) do
        drawCenteredSpacedText(line, x, start_y + ((index - 1) * line_height))
    end
end

local function getSpacedSegmentsWidth(font, segments)
    local width = 0
    for _, segment in ipairs(segments) do
        width = width + getSpacedTextWidth(font, segment.text or "")
    end
    return width
end

local function drawSpacedSegments(segments, x, y, alpha)
    local font = love.graphics.getFont()
    local cursor_x = 0

    for _, segment in ipairs(segments) do
        local color = segment.color or {1, 1, 1}
        Draw.setColor(color[1], color[2], color[3], alpha)
        drawSpacedText(segment.text or "", x + cursor_x, y)
        cursor_x = cursor_x + getSpacedTextWidth(font, segment.text or "")
    end
end

local function drawCenteredSpacedSegments(segments, x, y, alpha)
    local font = love.graphics.getFont()
    drawSpacedSegments(segments, x - (getSpacedSegmentsWidth(font, segments) / 2), y, alpha)
end

local function getChineseFont(size)
    return Assets.getFont("lang/zh_hans/main", size)
        or Assets.getFont("lang/zh_hans/zh_main", size)
        or Assets.getFont("main", size)
end

local function getCurrentVersion()
    return tostring(Mod and Mod.info and Mod.info.version or "v?.?.?")
end

local function playSelectSound()
    if Assets.stopAndPlaySound then
        Assets.stopAndPlaySound("ui_select")
    elseif Assets.playSound then
        Assets.playSound("ui_select")
    end
end

local function parseVersion(version)
    if type(version) ~= "string" then
        return nil
    end

    local major, minor, patch = version:match("^v?(%d+)%.(%d+)%.(%d+)")
    if not major then
        return nil
    end

    return tonumber(major), tonumber(minor), tonumber(patch)
end

local function compareVersions(left, right)
    local left_major, left_minor, left_patch = parseVersion(left)
    local right_major, right_minor, right_patch = parseVersion(right)

    if not left_major or not right_major then
        return nil
    end

    if left_major ~= right_major then
        return left_major > right_major and 1 or -1
    elseif left_minor ~= right_minor then
        return left_minor > right_minor and 1 or -1
    elseif left_patch ~= right_patch then
        return left_patch > right_patch and 1 or -1
    end

    return 0
end

local function isUsableRelease(release)
    return type(release) == "table"
        and release.draft ~= true
        and type(release.tag_name) == "string"
        and parseVersion(release.tag_name) ~= nil
end

local function getNewestRelease(data)
    if type(data) ~= "table" then
        return nil
    end

    if isUsableRelease(data) then
        return data
    end

    local newest = nil
    for _, release in ipairs(data) do
        if isUsableRelease(release) then
            if not newest or compareVersions(release.tag_name, newest.tag_name) > 0 then
                newest = release
            end
        end
    end

    return newest
end

function UpdateCheckSplash:init(done_callback)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = WORLD_LAYERS["above_textbox"] + 1
    self.done_callback = done_callback
    self.status = "checking"
    self.elapsed = 0
    self.hold_time = 0
    self.copy_message_timer = 0
    self.download_url = RELEASE_DOWNLOAD_URL
    self.finished = false
    self.has_drawn = false
    self.request_started = false
    self.status_time = 0
    self.fade_out = false
    self.fade_time = 0

    self:refreshFonts(true)
end

function UpdateCheckSplash:refreshFonts(force)
    if force and Game and Game.getLanguage and Game.setLanguage then
        local language = Game:getLanguage()
        if language then
            Game:setLanguage(language, true)
        end
    end

    if not force and self.font and self.small_font then
        return
    end

    self.font = getChineseFont()
    self.small_font = getChineseFont(16)
end

function UpdateCheckSplash:startRequest()
    if self.request_started then
        return
    end
    self.request_started = true

    if not Kristal or not Kristal.fetch then
        self:setStatus("failed")
        return
    end

    local started = Kristal.fetch(RELEASE_API_URL, {
        headers = {
            ["Accept"] = "application/vnd.github+json",
        },
        callback = function(response, body)
            self:onResponse(response, body)
        end,
    })

    if not started then
        self:setStatus("failed")
    end
end

function UpdateCheckSplash:onResponse(response, body)
    if self.finished or self.status ~= "checking" then
        return
    end

    if tonumber(response) ~= 200 or type(body) ~= "string" then
        self:setStatus("failed")
        return
    end

    local ok, data = pcall(JSON.decode, body)
    if not ok then
        self:setStatus("failed")
        return
    end

    local release = getNewestRelease(data)
    if not release then
        self:setStatus("failed")
        return
    end

    self.remote_version = release.tag_name
    self.download_url = release.html_url or RELEASE_DOWNLOAD_URL

    local current_version = Mod and Mod.info and Mod.info.version
    local comparison = compareVersions(self.remote_version, current_version)

    if comparison == nil then
        if self.remote_version == current_version then
            self:setStatus("latest")
        else
            self:setStatus("failed")
        end
    elseif comparison > 0 then
        self:setStatus("new")
    else
        self:setStatus("latest")
    end
end

function UpdateCheckSplash:setStatus(status)
    self.status = status
    self.status_time = 0
    self.message = nil

    if status == "new" then
        return
    elseif status == "latest" then
        self.message = loc(
            "Current version [var:version] is the latest",
            "update_check.latest",
            { version = getCurrentVersion() }
        )
    elseif status == "failed" then
        self.message = loc("Update check failed", "update_check.failed")
    end
end

function UpdateCheckSplash:copyDownloadUrl()
    if not self.download_url then
        return
    end

    if love.system and love.system.setClipboardText then
        love.system.setClipboardText(self.download_url)
        playSelectSound()
        self.copy_message = loc("Download link copied", "update_check.copy_copied")
    elseif love.system and love.system.openURL then
        love.system.openURL(self.download_url)
        playSelectSound()
        self.copy_message = loc("Download page opened", "update_check.copy_opened")
    else
        self.copy_message = loc("Unable to copy download link", "update_check.copy_failed")
    end

    self.copy_message_timer = COPY_MESSAGE_HOLD_TIME + COPY_MESSAGE_FADE_TIME
end

function UpdateCheckSplash:finish()
    if self.finished then
        return
    end

    self.finished = true
    Input.clear("confirm", true)
    self:remove()

    if self.done_callback then
        self.done_callback()
    end
end

function UpdateCheckSplash:startFadeOut()
    if self.fade_out then
        return
    end

    self.fade_out = true
    self.fade_time = 0
end

function UpdateCheckSplash:update()
    super.update(self)

    self.elapsed = self.elapsed + DT
    self.status_time = self.status_time + DT

    if self.fade_out then
        self.fade_time = self.fade_time + DT
        self.alpha = 1 - math.min(self.fade_time / FADE_OUT_TIME, 1)
        if self.fade_time >= FADE_OUT_TIME then
            self:finish()
        end
        return
    end

    if self.has_drawn and not self.request_started then
        self:startRequest()
    end

    if self.status == "checking" and self.elapsed >= CHECK_TIMEOUT then
        self:setStatus("failed")
    end

    if self.status == "latest" and self.status_time >= LATEST_AUTO_DISMISS_DELAY then
        self:startFadeOut()
        return
    end

    if Input.down("confirm") then
        self.hold_time = self.hold_time + DT
        if self.hold_time >= HOLD_TO_SKIP_TIME then
            self:finish()
            return
        end
    else
        self.hold_time = 0
    end

    if self.status == "new" and Input.pressed("c") then
        self:copyDownloadUrl()
    end

    if self.copy_message_timer > 0 then
        self.copy_message_timer = math.max(self.copy_message_timer - DT, 0)
    end

end

function UpdateCheckSplash:drawLoadingText()
    if self.status ~= "checking" then
        return
    end

    local current_line = loc(
        "Current version: [var:version]",
        "update_check.current_version_label",
        { version = getCurrentVersion() }
    )
    local checking_line = loc("Checking for updates...", "update_check.checking")

    love.graphics.setFont(self.small_font)
    Draw.setColor(1, 1, 1, self.alpha)
    drawSpacedText(current_line, 18, SCREEN_HEIGHT - 62)
    drawSpacedText(checking_line, 18, SCREEN_HEIGHT - 38)
end

function UpdateCheckSplash:drawStatusMessage()
    if self.status == "new" then
        self:drawNewVersionMessage()
        return
    end

    if not self.message then
        return
    end

    love.graphics.setFont(self.font)
    Draw.setColor(1, 1, 1, self.alpha)
    drawCenteredSpacedLines(self.message, SCREEN_WIDTH / 2, 220, 36)
end

function UpdateCheckSplash:drawNewVersionMessage()
    love.graphics.setFont(self.font)

    local remote_version = tostring(self.remote_version or "v?.?.?")

    drawCenteredSpacedSegments({
        { text = loc("New version found ", "update_check.new_found_prefix"), color = {1, 1, 1} },
        { text = remote_version, color = UPDATE_YELLOW },
    }, SCREEN_WIDTH / 2, 214, self.alpha)

    drawCenteredSpacedSegments({
        { text = loc("Press ", "update_check.copy_prompt_left"), color = {1, 1, 1} },
        { text = "C", color = UPDATE_CYAN },
        { text = loc(" to copy the download link", "update_check.copy_prompt_right"), color = {1, 1, 1} },
    }, SCREEN_WIDTH / 2, 262, self.alpha)
end

function UpdateCheckSplash:drawSkipText()
    love.graphics.setFont(self.small_font)

    local left = loc("Hold ", "update_check.skip_left")
    local right = loc(" to skip", "update_check.skip_right")
    local key_text = Input.getText("confirm")
    local key_texture = nil
    local key_width = getSpacedTextWidth(self.small_font, key_text)
    local icon_scale = 2

    if Input.usingGamepad() then
        key_texture = Input.getTexture("confirm")
        if key_texture then
            key_width = key_texture:getWidth() * icon_scale
        end
    end

    local total_width = getSpacedTextWidth(self.small_font, left)
        + key_width
        + getSpacedTextWidth(self.small_font, right)
    local x = SCREEN_WIDTH - total_width - 20
    local y = SCREEN_HEIGHT - 34

    Draw.setColor(1, 1, 1, self.alpha)
    drawSpacedText(left, x, y)
    x = x + getSpacedTextWidth(self.small_font, left)

    if key_texture then
        Draw.setColor(1, 1, 1, self.alpha)
        Draw.draw(key_texture, x, y - 3, 0, icon_scale, icon_scale)
    else
        Draw.setColor(1, 1, 1, self.alpha)
        drawSpacedText(key_text, x, y)
    end
    x = x + key_width

    drawSpacedText(right, x, y)
end

function UpdateCheckSplash:drawHoldProgress()
    if self.hold_time <= 0 then
        return
    end

    local width = 224
    local height = 4
    local x = SCREEN_WIDTH - width - 20
    local y = SCREEN_HEIGHT - 10
    local progress = math.min(self.hold_time / HOLD_TO_SKIP_TIME, 1)

    Draw.setColor(0.28, 0.28, 0.28, self.alpha)
    love.graphics.rectangle("fill", x, y, width, height)
    Draw.setColor(1, 1, 1, self.alpha)
    love.graphics.rectangle("fill", x, y, width * progress, height)
end

function UpdateCheckSplash:drawCopyMessage()
    if self.copy_message_timer <= 0 or not self.copy_message then
        return
    end

    local alpha = self.alpha
    if self.copy_message_timer <= COPY_MESSAGE_FADE_TIME then
        alpha = alpha * (self.copy_message_timer / COPY_MESSAGE_FADE_TIME)
    end

    love.graphics.setFont(self.small_font)
    Draw.setColor(1, 1, 1, alpha)
    drawSpacedText(self.copy_message, 18, SCREEN_HEIGHT - 38)
end

function UpdateCheckSplash:draw()
    self:refreshFonts(false)

    Draw.setColor(0, 0, 0, self.alpha)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    super.draw(self)

    self:drawStatusMessage()
    self:drawLoadingText()
    self:drawSkipText()
    self:drawHoldProgress()
    self:drawCopyMessage()

    self.has_drawn = true
end

return UpdateCheckSplash
