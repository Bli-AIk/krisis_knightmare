---@class FinisherFountainFlash : Sprite
local FinisherFountainFlash, super = Class(Sprite)

local FLASH_0 = "battle/kris_fountain_flash/spr_kris_make_fountain_flash_0"
local FLASH_1 = "battle/kris_fountain_flash/spr_kris_make_fountain_flash_1"
local FRAME_TIME = 6 / 60

function FinisherFountainFlash:init(x, y, options)
    options = options or {}

    -- Keep the two files as explicit frames. The source names end in _0/_1,
    -- while Kristal's automatic frame indexing is one-based.
    super.init(self, Assets.getTexture(FLASH_0), x, y)
    self:setFrames({
        Assets.getTexture(FLASH_0),
        Assets.getTexture(FLASH_1),
    })
    self:setOrigin(0.5, 0.5)
    self:setScale(2)
    self.layer = options.layer or (BATTLE_LAYERS["above_bullets"] + 3)
    self.collidable = false
    self.on_flash_one = options.on_flash_one

    self:setAnimation({
        function(anim_sprite, wait)
            anim_sprite:setFrame(1)
            wait(FRAME_TIME)

            anim_sprite:setFrame(2)
            if self.on_flash_one then
                self.on_flash_one(self)
            end
            wait(FRAME_TIME)
        end,
        callback = function()
            self.visible = false
            self:remove()
        end,
    })
end

return FinisherFountainFlash
