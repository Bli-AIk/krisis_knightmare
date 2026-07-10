local KrisPhase1_15, super = Class("kris_phase1_02")

local SLASH_START_DELAY = 16 / 30
local DOUBLE_SLASH_INTERVAL = 46 / 60
local INITIAL_DOUBLE_SLASH_DELAY = 38 / 60
local DISAPPEAR_SOUND = "kris_disappear"
local KRIS_FAR_X = 10000
local KRIS_FAR_Y = 10000

local DOUBLE_SLASH_GROUPS = {
    {
        x = 515, y = 156, kris_x = 550, kris_y = 205,
        slashes = { math.rad(158), math.rad(202) },
    },
    {
        x = 510, y = 204, kris_x = 550, kris_y = 286,
        slashes = { math.rad(166), math.rad(194) },
    },
    {
        x = 530, y = 166, kris_x = 550, kris_y = 215,
        slashes = { math.rad(154), math.rad(206) },
    },
    {
        x = 520, y = 196, kris_x = 550, kris_y = 278,
        slashes = { math.rad(170), math.rad(190) },
    },
    {
        x = 508, y = 174, kris_x = 550, kris_y = 224,
        slashes = { math.rad(150), math.rad(210) },
    },
    {
        x = 526, y = 212, kris_x = 550, kris_y = 296,
        slashes = { math.rad(162), math.rad(198) },
    },
    {
        x = 512, y = 160, kris_x = 550, kris_y = 210,
        slashes = { math.rad(146), math.rad(214) },
    },
}

local function moveAttackerTo(attacker, x, y)
    attacker.target_x = x
    attacker.target_y = y
    attacker:setPosition(attacker.target_x, attacker.target_y)
end

local function moveAttackerAway(attacker)
    moveAttackerTo(attacker, KRIS_FAR_X, KRIS_FAR_Y)
end

function KrisPhase1_15:init()
    super.init(self)
    self.time = 8
end

function KrisPhase1_15:getSlashInterval()
    return DOUBLE_SLASH_INTERVAL
end

function KrisPhase1_15:getInitialSlashDelay()
    return INITIAL_DOUBLE_SLASH_DELAY
end

function KrisPhase1_15:getDoubleSlashGroups()
    return DOUBLE_SLASH_GROUPS
end

function KrisPhase1_15:onStart()
    self.kris_home_positions = {}

    for _, attacker in ipairs(self:getAttackers()) do
        self.kris_home_positions[attacker] = {
            x = attacker.target_x or attacker.x,
            y = attacker.target_y or attacker.y,
        }
        Assets.playSound(DISAPPEAR_SOUND)
        attacker:setAnimation("flying_sword_disappear", function()
            moveAttackerAway(attacker)
        end)
    end

    self.slashes = self:getDoubleSlashGroups()
    self.slash_index = 0

    local function slashNext()
        self.slash_index = self.slash_index + 1
        local group = self.slashes[self.slash_index]
        if not group then
            return
        end

        local animation = self.slash_index % 2 == 0 and "slash1" or "slash2"
        self:spawnKrisSlashAnimation(group.kris_x, group.kris_y, animation)
        self.timer:after(SLASH_START_DELAY, function()
            for _, rotation in ipairs(group.slashes) do
                self:spawnSlash(group.x, group.y, rotation, group.kris_x, group.kris_y)
            end
        end)

        if self.slashes[self.slash_index + 1] then
            self.timer:after(self:getSlashInterval(), slashNext)
        end
    end

    self.timer:after(self:getInitialSlashDelay(), slashNext)
end

function KrisPhase1_15:update()
    super.update(self)
end

return KrisPhase1_15
