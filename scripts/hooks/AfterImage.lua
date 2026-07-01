local AfterImage, super = HookSystem.hookScript(AfterImage)

function AfterImage:canDebugSelect()
    return false
end

return AfterImage
