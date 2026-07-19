local Soul, super = HookSystem.hookScript(Soul)

function Soul:onDamage(bullet, amount)
    if Mod and Mod.recordKrisisBulletHit then
        Mod:recordKrisisBulletHit(self, bullet, amount)
    end
    return super.onDamage(self, bullet, amount)
end

function Soul:onGraze(bullet, old_graze)
    if Mod and Mod.recordKrisisGraze then
        Mod:recordKrisisGraze(self, bullet, old_graze)
    end
    return super.onGraze(self, bullet, old_graze)
end

return Soul
