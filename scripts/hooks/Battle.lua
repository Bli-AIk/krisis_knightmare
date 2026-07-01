local Battle, super = HookSystem.hookScript(Battle)

function Battle:onAdd(stage)
    super.onAdd(self, stage)

    local enc = self.encounter
    if enc and enc.setupBackground then
        enc:setupBackground(self)
    end
end

return Battle
