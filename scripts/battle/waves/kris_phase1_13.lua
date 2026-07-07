local KrisPhase1_13, super = Class("kris_phase1_07")

local BLOCK_TEXTURE_TOP = "bullets/block/0"
local BLOCK_TEXTURE_BOTTOM = "bullets/block/1"
local BLOCK_WIDTH = 153
local BLOCK_HEIGHT = 80
local BLOCK_HITBOX_LEFT = 37
local BLOCK_HITBOX_TOP = 31
local BLOCK_HITBOX_WIDTH = 81
local BLOCK_HITBOX_HEIGHT = 17
local BLOCK_HITBOX_X = BLOCK_HITBOX_LEFT - (BLOCK_WIDTH / 2)
local BLOCK_HITBOX_Y = BLOCK_HITBOX_TOP - (BLOCK_HEIGHT / 2)
local BLOCK_Y_SPACING = 35
local BLOCK_SCALE = 0.7
local BLOCK_LAYER = BATTLE_LAYERS["above_arena"]

local CHIP_BURST_MIN_COUNT = 2
local CHIP_BURST_MAX_COUNT = 3
local CHIP_QUADRANT_PADDING = math.rad(10)

local function randomBetween(min, max)
    return min + (max - min) * love.math.random()
end

local BlockWall, block_wall_super = Class(Solid)

function BlockWall:init(texture, offset_y)
    block_wall_super.init(self, false, 0, 0, BLOCK_WIDTH, BLOCK_HEIGHT)

    self.offset_y = offset_y
    self.layer = BLOCK_LAYER
    self.squish_damage = 0
    self:setScale(BLOCK_SCALE)
    self:setHitbox(BLOCK_HITBOX_X, BLOCK_HITBOX_Y, BLOCK_HITBOX_WIDTH, BLOCK_HITBOX_HEIGHT)

    self.sprite = Sprite(texture, -BLOCK_WIDTH / 2, -BLOCK_HEIGHT / 2)
    self:addChild(self.sprite)
    self:syncToArena()
end

function BlockWall:syncToArena()
    local arena = Game.battle and Game.battle.arena
    local x, y

    if arena then
        x, y = arena:getCenter()
    else
        x, y = SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
    end

    self:setPosition(x, y + self.offset_y)
end

function BlockWall:update()
    self:syncToArena()
    block_wall_super.update(self)
end

function KrisPhase1_13:init()
    super.init(self)
    self.block_y_spacing = BLOCK_Y_SPACING
end

function KrisPhase1_13:onStart()
    super.onStart(self)
    self:spawnBlockWalls()
end

function KrisPhase1_13:spawnBlockWalls()
    local spacing = self:getBlockYSpacing()

    self:spawnObject(BlockWall(BLOCK_TEXTURE_TOP, -spacing))
    self:spawnObject(BlockWall(BLOCK_TEXTURE_BOTTOM, spacing))
end

function KrisPhase1_13:getBlockYSpacing()
    return self.block_y_spacing or BLOCK_Y_SPACING
end

function KrisPhase1_13:getChipBurstAngles()
    local count = love.math.random(CHIP_BURST_MIN_COUNT, CHIP_BURST_MAX_COUNT)
    local quadrants = { 0, 1, 2, 3 }
    local angles = {}

    for i = #quadrants, 2, -1 do
        local j = love.math.random(i)
        quadrants[i], quadrants[j] = quadrants[j], quadrants[i]
    end

    for i = 1, count do
        local quadrant = quadrants[i]
        local min_angle = quadrant * math.pi / 2 + CHIP_QUADRANT_PADDING
        local max_angle = (quadrant + 1) * math.pi / 2 - CHIP_QUADRANT_PADDING
        table.insert(angles, randomBetween(min_angle, max_angle))
    end

    for i = #angles, 2, -1 do
        local j = love.math.random(i)
        angles[i], angles[j] = angles[j], angles[i]
    end

    return angles
end

return KrisPhase1_13
