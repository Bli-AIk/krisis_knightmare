local Battle, super = HookSystem.hookScript(Battle)

function Battle:onAdd(stage)
    super.onAdd(self, stage)

    local enc = self.encounter
    if enc and enc.setupBackground then
        enc:setupBackground(self)
    end
    if enc and enc.onBattleAdd then
        enc:onBattleAdd(self)
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

function Battle:returnToWorld()
    local start_finisher = self.encounter
        and self.encounter.startFinisherBattle
        and self.encounter:startFinisherBattle()

    super.returnToWorld(self)

    if start_finisher then
        Game:encounter("kris_finisher", false)
    end
end

function Battle:handleAttackingInput(key)
    local encounter = self.encounter
    if encounter
        and encounter.isMercyFinalePostlude
        and encounter:isMercyFinalePostlude()
    then
        if Input.isConfirm(key) then
            -- Fight is intentionally inert during the postlude. Clear the
            -- press as well so AttackBox cannot flash in response to Z.
            Input.clear("confirm", true)
        end
        return
    end

    return super.handleAttackingInput(self, key)
end

function Battle:onKeyPressed(key)
    local encounter = self.encounter
    if encounter
        and encounter.isMercyFinaleDetached
        and encounter:isMercyFinaleDetached()
    then
        -- Keep confirm from being consumed by a stale menu or by the next
        -- battle state. Direction keys remain available to the encounter's
        -- held-input movement logic.
        Input.clear("confirm", true)
        Input.clear("cancel", true)
        Input.clear("menu", true)
        return
    end

    return super.onKeyPressed(self, key)
end

return Battle
