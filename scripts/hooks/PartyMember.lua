local PartyMember, super = HookSystem.hookScript(PartyMember)

function PartyMember:heal(amount, playsound)
    local before = self:getHealth()
    local result = super.heal(self, amount, playsound)
    if Mod and Mod.recordKrisisHeal then
        Mod:recordKrisisHeal(self, before, self:getHealth())
    end
    return result
end

return PartyMember
