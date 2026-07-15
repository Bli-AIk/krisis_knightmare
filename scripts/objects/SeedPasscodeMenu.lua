local SeedPasscodeMenu, super = Class(Object)

local SEED_DIGIT_COUNT = 10

local function loc(default, id)
    if Game and Game.loc then
        return Game:loc(default, id)
    end
    return default
end

function SeedPasscodeMenu:init(on_submit, on_cancel, initial_seed)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.on_submit = on_submit
    self.on_cancel = on_cancel
    self.layer = (WORLD_LAYERS and WORLD_LAYERS["ui"] or 600) + 100
    self.font = Assets.getFont("main")
    self.small_font = Assets.getFont("main", 16)

    self.passcodebox = Passcodebox(56, 226, 529, 104, {
        check_correct = false,
        spacing = 9,
        color = COLORS.white,
        highlight = COLORS.yellow,
    })
    self:addChild(self.passcodebox)

    for _ = 1, SEED_DIGIT_COUNT do
        self.passcodebox:addRow({ preset = "numbers" })
    end

    initial_seed = tostring(initial_seed or "")
    if initial_seed:match("^%d+$") and #initial_seed == SEED_DIGIT_COUNT then
        for index = 1, SEED_DIGIT_COUNT do
            self.passcodebox.selected_characters[index] = initial_seed:byte(index) - string.byte("0") + 1
        end
    end
end

function SeedPasscodeMenu:update()
    super.update(self)

    if self.passcodebox.done and not self.submitted then
        self.submitted = true
        self.on_submit(table.concat(self.passcodebox:getSelectedCharacters()))
    end
end

function SeedPasscodeMenu:cancel()
    if self.submitted then
        return
    end

    self.submitted = true
    self.on_cancel()
end

function SeedPasscodeMenu:draw()
    Draw.setColor(COLORS.black)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    local old_font = love.graphics.getFont()
    love.graphics.setFont(self.font)
    Draw.setColor(COLORS.white)
    Draw.printAlign(loc("SEED", "seed_passcode.title"), SCREEN_WIDTH / 2, 128, "center")

    love.graphics.setFont(self.small_font)
    Draw.setColor(COLORS.gray)
    Draw.printAlign(loc("RANDOM SEED", "seed_passcode.subtitle"), SCREEN_WIDTH / 2, 178, "center")
    love.graphics.setFont(old_font)

    super.draw(self)
end

return SeedPasscodeMenu
