local Bullet, super = HookSystem.hookScript(Bullet)

function Bullet:onDamage(soul)
    local battle = Game and Game.battle
    local previous_context = battle and battle.krisis_stats_bullet_damage_active
    if battle then
        battle.krisis_stats_bullet_damage_active = true
    end

    local result = super.onDamage(self, soul)

    if battle then
        battle.krisis_stats_bullet_damage_active = previous_context
    end
    return result
end

return Bullet
