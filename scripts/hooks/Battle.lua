local Battle, super = HookSystem.hookScript(Battle)

function Battle:onAdd(stage)
    super.onAdd(self, stage)

    local enc = self.encounter
    if enc and enc.setupBackground then
        enc:setupBackground(self)
    end
end

function Battle:setWaves(waves, allow_duplicates)
    local created_waves = super.setWaves(self, waves, allow_duplicates)

    local enc = self.encounter
    if self.state == "DEFENDINGBEGIN" and enc and enc.applyRechargeSoulOffsets then
        enc:applyRechargeSoulOffsets(created_waves)
    end

    return created_waves
end

return Battle
