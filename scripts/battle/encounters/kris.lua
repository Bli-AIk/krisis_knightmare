local Kris, super = Class(Encounter)

local RECHARGE_FULL_TENSION = 100
local RECHARGE_FULL_TURNS = 2
local RECHARGE_DEFAULT_TURNS = 1
local RECHARGE_TENSION_RATE = 120
local RECHARGE_PLATFORM_FADE_TIME = 0.3
local RECHARGE_LIGHT_SCALE = 1
local RECHARGE_LIGHT_RADIUS_FACTOR = 0.45
local RECHARGE_MERCY_INTERVAL = 0.3

function Kris:init()
    super.init(self)

    self:applyLocalization()
    self.music = "never_forgetting"
    self.background = false
    self.hide_world = true

    self:addEnemy("kris", 507, 239)

    self.recharge = nil
    self.recharge_light = nil
    self.recharge_soul = nil
    self.recharge_light_radius = nil
end

function Kris:applyLocalization()
    self.text = Game:loc("* KRIS slashes into the combat.", "enemy_kris_turn_1")
end

function Kris:onBattleStart()
    local initial_tp = Game:getConfig("krisisInitialTP")
    if initial_tp ~= nil then
        initial_tp = tonumber(initial_tp)
        if initial_tp then
            Game:setTension(initial_tp)
        end
    end

    for _, enemy in ipairs(Game.battle.enemies or {}) do
        if enemy.updateRechargeActTPCost then
            enemy:updateRechargeActTPCost()
        end
    end
end

function Kris:onBattleEnd()
    self:clearRecharge(true)

    for _, enemy in ipairs(Game.battle.enemies or {}) do
        if enemy.clearHeartbeatBonuses then
            enemy:clearHeartbeatBonuses()
        end
    end
end

function Kris:onTurnEnd()
    local recharge = self.recharge
    if not recharge or recharge.draining or recharge.expiring then
        return
    end

    recharge.turns_remaining = math.max((recharge.turns_remaining or 1) - 1, 0)
    if recharge.turns_remaining <= 0 then
        recharge.expiring = true
    end
end

function Kris:onStateChange(old, new, reason)
    if new == "ACTIONSELECT" then
        self:beginRechargeDrain()
    end
end

function Kris:activateRecharge(enemy, battler, pre_spend_tension)
    local turns = pre_spend_tension >= RECHARGE_FULL_TENSION and RECHARGE_FULL_TURNS or RECHARGE_DEFAULT_TURNS

    self.recharge = self.recharge or {}
    self.recharge.enemy = enemy
    self.recharge.battler = battler
    self.recharge.turns_remaining = math.max(self.recharge.turns_remaining or 0, turns)
    self.recharge.expiring = false
    self.recharge.draining = false
    self.recharge.filling = true
    self.recharge.mercy_cooldown = 0

    self:ensureRechargeVisuals(enemy, battler)
end

function Kris:ensureRechargeVisuals(enemy, battler)
    if self.bg_platform then
        self.bg_platform:crossFadeTo("battle/backgrounds/kris_platform_light", RECHARGE_PLATFORM_FADE_TIME)
    end

    if not self.recharge_light or not self.recharge_light.parent then
        self.recharge_light = Sprite("battle/light", 0, 0)
        self.recharge_light:setOrigin(0.5, 0.5)
        self.recharge_light:setScale(RECHARGE_LIGHT_SCALE)
        self.recharge_light.alpha = 0
        self.recharge_light.visible = false
        self.recharge_light.layer = BATTLE_LAYERS["soul"] - 1
        Game.battle:addChild(self.recharge_light)
    else
        self.recharge_light.visible = false
        self.recharge_light.alpha = 0
    end

    self.recharge_light_radius = (self.recharge_light.width or 100) * RECHARGE_LIGHT_SCALE * RECHARGE_LIGHT_RADIUS_FACTOR
    self:updateRechargeLight()
end

function Kris:getRechargeSoulSpawnPosition()
    if self.recharge_soul and self.recharge_soul.parent then
        return self.recharge_soul.x, self.recharge_soul.y
    end

    if Game.battle and Game.battle.arena then
        return Game.battle.arena:getCenter()
    end

    return SCREEN_WIDTH / 2, (SCREEN_HEIGHT - 155) / 2 + 10
end

function Kris:getRechargeLightRadius()
    return self.recharge_light_radius or 90
end

function Kris:getRechargeLightPosition()
    if self.recharge_light and self.recharge_light.parent and self.recharge_light.visible then
        return self.recharge_light.x, self.recharge_light.y, self:getRechargeLightRadius()
    end
end

function Kris:getRechargeLightTarget()
    if not Game.battle then
        return
    end

    local state = Game.battle:getState()
    if state ~= "DEFENDINGBEGIN" and state ~= "DEFENDING" then
        return
    end

    if Game.battle.soul and Game.battle.soul.parent and Game.battle.soul.visible then
        return Game.battle.soul
    end
end

function Kris:isRechargeMercyDisplayActive()
    local state = Game.battle and Game.battle:getState()
    return self.recharge
        and not self.recharge.draining
        and (state == "DEFENDINGBEGIN" or state == "DEFENDING" or state == "DEFENDINGEND")
end

function Kris:tryAddRechargeMercy(enemy)
    local recharge = self.recharge
    if not recharge or not enemy or not self:isRechargeMercyDisplayActive() then
        return false
    end

    if (recharge.mercy_cooldown or 0) > 0 then
        return false
    end

    enemy:addTemporaryMercy(1, true, { 0, 100 }, function()
        return not Game.battle
            or not Game.battle.encounter
            or not Game.battle.encounter.isRechargeMercyDisplayActive
            or not Game.battle.encounter:isRechargeMercyDisplayActive()
    end)
    recharge.mercy_cooldown = RECHARGE_MERCY_INTERVAL
    return true
end

function Kris:getRechargeTargetPosition(target)
    if target == Game.battle.soul then
        return target.x, target.y
    end

    return target:getRelativePos(target.width / 2, target.height / 2, Game.battle)
end

function Kris:updateRechargeLight()
    if not self.recharge_light or not self.recharge_light.parent then
        return
    end

    local target = self:getRechargeLightTarget()
    if not target then
        self.recharge_light.visible = false
        self.recharge_light.alpha = 0
        if self.recharge_soul then
            self.recharge_soul.enabled = false
            self.recharge_soul.visible = false
        end
        return
    end

    local x, y = self:getRechargeTargetPosition(target)
    if not self.recharge_light.visible then
        self.recharge_light.alpha = 0
        self.recharge_light:fadeTo(1, RECHARGE_PLATFORM_FADE_TIME)
    end
    self.recharge_light.visible = true
    self.recharge_light:setPosition(x, y)
    self.recharge_light:setLayer((target.layer or BATTLE_LAYERS["soul"]) - 1)

    local recharge = self.recharge
    if not recharge then
        return
    end

    if not self.recharge_soul or not self.recharge_soul.parent then
        local soul_x, soul_y = self:getRechargeSoulSpawnPosition()
        self.recharge_soul = Registry.createBullet("recharge_soul", soul_x, soul_y, recharge.enemy, self:getRechargeLightRadius())
        Game.battle:addChild(self.recharge_soul)
    else
        self.recharge_soul.target_enemy = recharge.enemy
        self.recharge_soul.light_radius = self:getRechargeLightRadius()
        self.recharge_soul.enabled = true
        self.recharge_soul.visible = true
    end
end

function Kris:beginRechargeDrain()
    local recharge = self.recharge
    if not recharge or not recharge.expiring or recharge.draining then
        return
    end

    recharge.expiring = false
    recharge.draining = true
    recharge.filling = false

    if self.recharge_soul then
        self.recharge_soul.enabled = false
    end

    if self.bg_platform then
        self.bg_platform:crossFadeTo("battle/backgrounds/kris_platform_adjusted", RECHARGE_PLATFORM_FADE_TIME)
    end
end

function Kris:updateRechargeTension()
    local recharge = self.recharge
    if not recharge then
        return
    end

    if recharge.draining then
        if Game:getTension() > 0 then
            Game:removeTension(RECHARGE_TENSION_RATE * DT)
        end
        if Game:getTension() <= 0 then
            self:clearRecharge(false)
        end
    elseif recharge.filling then
        if Game:getTension() < Game:getMaxTension() then
            Game:giveTension(RECHARGE_TENSION_RATE * DT)
        end
        if Game:getTension() >= Game:getMaxTension() then
            recharge.filling = false
        end
    end
end

function Kris:updateRechargeMercyCooldown()
    local recharge = self.recharge
    if not recharge or not recharge.mercy_cooldown then
        return
    end

    recharge.mercy_cooldown = math.max(recharge.mercy_cooldown - DT, 0)
end

function Kris:clearRecharge(instant)
    self.recharge = nil

    if self.recharge_light then
        if instant then
            self.recharge_light:remove()
        else
            self.recharge_light:fadeOutAndRemove(RECHARGE_PLATFORM_FADE_TIME)
        end
        self.recharge_light = nil
    end

    if self.recharge_soul then
        if instant then
            self.recharge_soul:remove()
        else
            self.recharge_soul:fadeOutAndRemove(RECHARGE_PLATFORM_FADE_TIME)
        end
        self.recharge_soul = nil
    end
end

function Kris:update()
    super.update(self)
    self:updateRechargeMercyCooldown()
    self:updateRechargeLight()
    self:updateRechargeTension()
end

function Kris:setupBackground(battle)
    self.bg_platform = Sprite("battle/backgrounds/kris_platform_adjusted", 0, 0)
    self.bg_platform.layer = BATTLE_LAYERS["bottom"]
    self.bg_platform:setScale(2, 2)
    battle:addChild(self.bg_platform)

    self.bg_depth = KrisDepthBackground()
    self.bg_depth.layer = BATTLE_LAYERS["bottom"] + 0.5
    battle:addChild(self.bg_depth)

    self.vignette = KrisVignette()
    self.vignette.layer = BATTLE_LAYERS["bottom"] + 1
    battle:addChild(self.vignette)
end

return Kris
