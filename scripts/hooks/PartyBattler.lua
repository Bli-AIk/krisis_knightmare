local PartyBattler, super = HookSystem.hookScript(PartyBattler)

function PartyBattler:hurt(amount, exact, color, options)
    local before = self.chara and self.chara:getHealth()
    local result = super.hurt(self, amount, exact, color, options)
    local after = self.chara and self.chara:getHealth()
    local battle = Game and Game.battle
    if before and after
        and battle and battle.krisis_stats_bullet_damage_active
        and Mod and Mod.recordKrisisBulletDamage
    then
        Mod:recordKrisisBulletDamage(self, before, after)
    end
    return result
end

return PartyBattler
