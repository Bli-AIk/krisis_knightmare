local ActionButton, super = HookSystem.hookScript(ActionButton)

local function canSelectRechargeAct(enemy, battler)
    local battle = Game.battle
    local act = enemy and enemy.recharge_act
    if not battle or not battler or not act or act.hidden then
        return false
    end

    if act.character and battler.chara.id ~= act.character then
        return false
    end

    if enemy.updateRechargeActTPCost then
        enemy:updateRechargeActTPCost()
    end

    if act.unusable or ((act.tp or 0) > Game:getTension()) then
        return false
    end

    if act.party then
        for _, party_id in ipairs(act.party) do
            local party_index = battle:getPartyIndex(party_id)
            local party_battler = party_index and battle.party[party_index]
            local action = party_index and battle.character_actions[party_index]
            if (not party_battler) or (not party_battler:isActive()) or (action and action.cancellable == false) then
                return false
            end
        end
    end

    return true
end

function ActionButton:hasSpecial()
    if super.hasSpecial(self) then
        return true
    end

    if self.type ~= "act" or not Game.battle then
        return false
    end

    for _, enemy in ipairs(Game.battle:getActiveEnemies()) do
        if canSelectRechargeAct(enemy, self.battler) then
            return true
        end
    end

    return false
end

return ActionButton
