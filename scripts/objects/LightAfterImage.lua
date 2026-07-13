---@class LightAfterImage : Object
---@overload fun(...) : LightAfterImage
local LightAfterImage, super = Class(Object)

-- Static sprite trails do not need a full-screen render target. Keep the
-- source transform and draw the original texture directly instead.
function LightAfterImage:init(sprite, fade, speed)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.sprite = sprite
    self.texture = sprite:getTexture()
    self.transform = sprite:getFullTransform()

    local r, g, b, a = sprite:getDrawColor()
    self.sprite_r = r
    self.sprite_g = g
    self.sprite_b = b
    self.sprite_alpha = a

    self.alpha = fade
    self.debug_select = false
    self:fadeOutSpeedAndRemove(speed)
end

function LightAfterImage:onAdd(parent)
    local sibling
    local other_parents = self.sprite:getHierarchy()

    for _, v in ipairs(self:getHierarchy()) do
        for _, o in ipairs(other_parents) do
            if o.parent and o.parent == v then
                sibling = o
                break
            end
        end
        if sibling then
            break
        end
    end

    if sibling then
        self.layer = sibling.layer - 0.001
    end
end

function LightAfterImage:applyTransformTo(transform)
    if self.parent then
        transform:reset()
    end
    super.applyTransformTo(self, transform)
end

function LightAfterImage:draw()
    if self.texture then
        love.graphics.applyTransform(self.transform)
        Draw.setColor(
            self.sprite_r,
            self.sprite_g,
            self.sprite_b,
            self.sprite_alpha * self.alpha
        )
        Draw.draw(self.texture)
    end
end

return LightAfterImage
