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
    if Input.isConfirm(key)
        and encounter
        and encounter.isMercyFinalePostlude
        and encounter:isMercyFinalePostlude()
        and not self.attack_done
        and not self.cancel_attack
        and #self.battle_ui.attack_boxes > 0
    then
        -- In the postlude, confirming should always resolve the current
        -- attack bar. The enemy still returns zero damage, so this only
        -- restores the input response and does not make Fight effective.
        local attack
        for _, candidate in ipairs(self.battle_ui.attack_boxes) do
            if not candidate.attacked then
                attack = candidate
                break
            end
        end

        if attack then
            local points = attack:hit()
            local action = self:getActionBy(attack.battler, true)
            if action then
                action.points = points
                if self:processAction(action) then
                    self:finishAction(action)
                end
            end
        end
        return
    end

    return super.handleAttackingInput(self, key)
end

return Battle
