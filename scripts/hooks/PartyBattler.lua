local PartyBattler, super = HookSystem.hookScript(PartyBattler)

function PartyBattler:hurt(amount, exact, color, options)
    local before = self.chara and self.chara:getHealth()
    local result = super.hurt(self, amount, exact, color, options)
    local after = self.chara and self.chara:getHealth()
    if before and after and after < before
        and Mod and Mod.recordKrisisBattleHurt
    then
        Mod:recordKrisisBattleHurt(self)
    end
    return result
end

return PartyBattler
