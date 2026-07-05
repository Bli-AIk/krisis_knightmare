local AfterImage, super = HookSystem.hookScript(AfterImage)

function AfterImage:canDebugSelect()
    return false
end

function AfterImage:getDepthMaskClipCircle()
    local mask = self.depth_mask_clip
    if not mask or not mask.parent or not mask.radius or mask.radius <= 0 then
        return
    end

    local x, y = mask:localToScreenPos(0, 0)
    local edge_x, edge_y = mask:localToScreenPos(mask.radius, 0)
    local radius = Utils.dist(x, y, edge_x, edge_y)
    if radius <= 0 then
        return
    end

    return x, y, radius
end

function AfterImage:draw()
    local x, y, radius = self:getDepthMaskClipCircle()
    if not x then
        if self.depth_mask_clip then
            return
        end
        return super.draw(self)
    end

    local old_stencil_mode, old_stencil_value = love.graphics.getStencilTest()

    love.graphics.setStencilTest()
    love.graphics.stencil(function()
        love.graphics.push()
        love.graphics.origin()
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        love.graphics.pop()
    end, "replace", 0)
    love.graphics.stencil(function()
        love.graphics.push()
        love.graphics.origin()
        love.graphics.circle("fill", x, y, radius, 96)
        love.graphics.pop()
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 1)

    super.draw(self)

    if old_stencil_mode then
        love.graphics.setStencilTest(old_stencil_mode, old_stencil_value)
    else
        love.graphics.setStencilTest()
    end
end

return AfterImage
