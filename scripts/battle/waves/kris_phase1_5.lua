local KrisPhase1_5, super = Class(Wave)

function KrisPhase1_5:init()
    super.init(self)
    self.time = 5
end

local KRIS_FAR_X = 10000
local KRIS_FAR_Y = 10000

local function moveAttackerTo(attacker, x, y)
    attacker.target_x = x
    attacker.target_y = y
    attacker:setPosition(attacker.target_x, attacker.target_y)
end

local function moveAttackerAway(attacker)
    moveAttackerTo(attacker, KRIS_FAR_X, KRIS_FAR_Y)
end

function KrisPhase1_5:onStart()
    self.kris_home_positions = {}

    self:spawnBullet("flying_sword", 320, 240, 0, math.rad(12))
    for _, attacker in ipairs(self:getAttackers()) do
        self.kris_home_positions[attacker] = {
            x = attacker.target_x or attacker.x,
            y = attacker.target_y or attacker.y,
        }
        attacker:setAnimation("flying_sword_disappear", function()
            moveAttackerAway(attacker)
        end)
    end
end

function KrisPhase1_5:onEnd(death)
    for _, attacker in ipairs(self:getAttackers()) do
        local home = self.kris_home_positions and self.kris_home_positions[attacker]
        if home then
            moveAttackerTo(attacker, home.x, home.y)
        end
        attacker:setAnimation("appear")
    end

    return super.onEnd(self, death)
end

function KrisPhase1_5:update()
    super.update(self)
end

return KrisPhase1_5
