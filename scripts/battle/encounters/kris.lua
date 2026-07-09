local Kris, super = Class(Encounter)

local RECHARGE_FULL_TENSION = 100
local RECHARGE_FULL_TURNS = 2
local RECHARGE_DEFAULT_TURNS = 1
local RECHARGE_TENSION_RATE = 120
local RECHARGE_PLATFORM_FADE_TIME = 0.3
local RECHARGE_LIGHT_SPRITE = "battle/light"
local RECHARGE_PLAYER_LIGHT_SPRITE = "battle/player_light"
local RECHARGE_DEFAULT_SOUL_SPRITE = "player/heart_dodge"
local RECHARGE_LIGHT_SCALE = 1
local RECHARGE_LIGHT_RADIUS_FACTOR = 0.45
local RECHARGE_MERCY_INTERVAL = 0.3
local RECHARGE_ACT_EFFECT_FRAME = 5
local RECHARGE_ACT_FRAME_DELAY = 1 / 15
local RECHARGE_SOUL_LAYER = BATTLE_LAYERS["above_bullets"] + 2
local RECHARGE_PLAYER_START_OFFSET_X = -28
local RECHARGE_PLAYER_START_OFFSET_Y = 0
local RECHARGE_SOUL_START_OFFSET_X = 28
local RECHARGE_SOUL_START_OFFSET_Y = 0
local RECHARGE_RETURN_TARGET_OFFSET_X = -2
local RECHARGE_RETURN_TARGET_OFFSET_Y = 1
local PLATFORM_SPRITE = "battle/backgrounds/kris_platform_adjusted"
local PLATFORM_LIGHT_SPRITE = "battle/backgrounds/kris_platform_light"

function Kris:init()
    super.init(self)

    self:applyLocalization()
    self.music = "never_forgetting"
    self.background = false
    self.hide_world = true

    self:addEnemy("kris", 507, 239)

    self.recharge = nil
    self.recharge_soul = nil
    self.recharge_light_radius = nil
    self.recharge_player_light = nil
end

function Kris:applyLocalization()
    self.text = Game:loc("* [name:chara:kris] slashes into the combat.", "enemy_kris_turn_1")
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

    if Game:getConfig("krisisDebugRechargeRadial") then
        self:spawnRechargeRadialBurst(Game.battle.party[1], {
            capture = Game:getConfig("krisisDebugRechargeRadialCapture"),
            quit_after_capture = Game:getConfig("krisisDebugRechargeRadialQuit"),
        })
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
        if recharge.enemy and recharge.enemy.finishRechargeWavePhaseAdvance then
            recharge.enemy:finishRechargeWavePhaseAdvance()
        end
    end
end

function Kris:onStateChange(old, new, reason)
    if new == "ACTIONSELECT" then
        self:beginRechargeDrain()
    elseif new == "DEFENDINGBEGIN" or new == "DEFENDING" then
        self:updateRechargeLight()
    elseif new == "DEFENDINGEND" then
        self:restoreRechargePlayerLight()
        self:removeRechargeSoul(false)
    end
end

function Kris:isRechargeActive()
    return self.recharge ~= nil
end

function Kris:isRechargeSustaining()
    return self.recharge
        and not self.recharge.expiring
        and not self.recharge.draining
end

function Kris:applyRechargeSoulOffsets(waves)
    if not self:isRechargeSustaining() then
        return
    end

    for _, wave in ipairs(waves or {}) do
        wave.soul_offset_x = wave.soul_offset_x or RECHARGE_PLAYER_START_OFFSET_X
        wave.soul_offset_y = wave.soul_offset_y or RECHARGE_PLAYER_START_OFFSET_Y
    end
end

function Kris:onEnemySelect(state_reason, enemy_index)
    if state_reason ~= "ACT" or not Game.battle then
        return
    end

    local battle = Game.battle
    if #battle.enemies_index == 0 then
        return true
    end

    battle.ui_select:stop()
    battle.ui_select:play()
    battle.selected_enemy = enemy_index

    local enemy = battle:_getEnemyByIndex(enemy_index)
    if enemy.updateRechargeActTPCost then
        enemy:updateRechargeActTPCost()
    end

    battle:clearMenuItems()
    for _, act in ipairs(enemy.acts) do
        local insert = not act.hidden
        if act.character and battle.party[battle.current_selecting].chara.id ~= act.character then
            insert = false
        end
        if act.party and (#act.party > 0) then
            for _, party_id in ipairs(act.party) do
                if not battle:getPartyIndex(party_id) then
                    insert = false
                    break
                end
            end
        end
        if insert then
            local color = act.color or { 1, 1, 1, 1 }
            if act == enemy.recharge_act and enemy.getRechargeActMenuColor then
                color = function()
                    return enemy:getRechargeActMenuColor()
                end
            end

            battle:addMenuItem({
                ["name"] = act.name,
                ["tp"] = act.tp or 0,
                ["unusable"] = act.unusable or false,
                ["description"] = act.description,
                ["party"] = act.party,
                ["color"] = color,
                ["highlight"] = act.highlight or enemy,
                ["icons"] = act.icons,
                ["callback"] = function(menu_item)
                    battle:pushAction("ACT", enemy, menu_item)
                end
            })
        end
    end
    battle:setState("MENUSELECT", "ACT")
    return true
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

function Kris:getRechargeRadialBurstOrigin(battler)
    if battler and battler.parent then
        return battler:getRelativePos(battler.width / 2, battler.height / 2, Game.battle)
    end

    if Game.battle and Game.battle.party and Game.battle.party[1] then
        local party = Game.battle.party[1]
        return party:getRelativePos(party.width / 2, party.height / 2, Game.battle)
    end

    return SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
end

function Kris:spawnRechargeRadialBurst(battler, options)
    if not Game.battle then
        return
    end

    local x, y = self:getRechargeRadialBurstOrigin(battler)
    local burst = RechargeRadialBurst(x, y, options)
    Game.battle:addChild(burst)
    return burst
end

function Kris:spawnRechargeWhiteFlash(battler)
    if Game.battle then
        Game.battle:addChild(RechargeWhiteFlash(battler))
    end
end

function Kris:setPlatformSprite(texture, fade_time)
    if self.bg_platform then
        self.bg_platform:crossFadeTo(texture, fade_time)
    end
    if self.bg_platform_particles then
        self.bg_platform_particles:crossFadeTo(texture, fade_time)
    end
end

function Kris:triggerRechargeActVisuals(battler)
    Assets.playSound("vessel_charge")
    self:spawnRechargeRadialBurst(battler, {
        after_snapshot = function()
            self:spawnRechargeWhiteFlash(battler)
        end
    })
end

function Kris:playRechargeActAnimation(battler)
    if not battler then
        return
    end

    local triggered = false
    battler:setAnimation({
        "battle/act",
        function(sprite, wait)
            for frame = 1, 7 do
                sprite:setFrame(frame)
                if frame == RECHARGE_ACT_EFFECT_FRAME and not triggered then
                    triggered = true
                    self:triggerRechargeActVisuals(battler)
                end
                wait(RECHARGE_ACT_FRAME_DELAY)
            end
        end
    })
end

function Kris:ensureRechargeVisuals(enemy, battler)
    self:setPlatformSprite(PLATFORM_LIGHT_SPRITE, RECHARGE_PLATFORM_FADE_TIME)

    local texture = Assets.getTexture(RECHARGE_LIGHT_SPRITE)
    self.recharge_light_radius = ((texture and texture:getWidth()) or 20) * RECHARGE_LIGHT_SCALE * RECHARGE_LIGHT_RADIUS_FACTOR
    self:updateRechargeLight()
end

function Kris:getRechargeSoulSpawnPosition()
    if self.recharge_soul and self.recharge_soul.parent then
        return self.recharge_soul.x, self.recharge_soul.y
    end

    if Game.battle and Game.battle.arena then
        local x, y = Game.battle.arena:getCenter()
        return x + RECHARGE_SOUL_START_OFFSET_X, y + RECHARGE_SOUL_START_OFFSET_Y
    end

    return SCREEN_WIDTH / 2 + RECHARGE_SOUL_START_OFFSET_X,
        (SCREEN_HEIGHT - 155) / 2 + 10 + RECHARGE_SOUL_START_OFFSET_Y
end

function Kris:getRechargeSoulOriginPosition(enemy)
    enemy = enemy or (self.recharge and self.recharge.enemy)
    if enemy and enemy.parent then
        if enemy.sprite then
            return enemy:localToScreenPos((enemy.sprite.width / 2) - 4.5, enemy.sprite.height / 2)
        end
        return enemy:localToScreenPos(enemy.width / 2, enemy.height / 2)
    end

    return self:getRechargeSoulSpawnPosition()
end

function Kris:getRechargeLightRadius()
    if not self.recharge_light_radius then
        local texture = Assets.getTexture(RECHARGE_LIGHT_SPRITE)
        self.recharge_light_radius = ((texture and texture:getWidth()) or 20) * RECHARGE_LIGHT_SCALE * RECHARGE_LIGHT_RADIUS_FACTOR
    end
    return self.recharge_light_radius
end

function Kris:getRechargeLightPosition()
    if not self.recharge or self.recharge.draining then
        return
    end

    local soul = self:getRechargeLightTarget()
    if soul then
        return soul.x, soul.y, self:getRechargeLightRadius()
    end
end

function Kris:getRechargeLightTarget()
    if not Game.battle then
        return
    end

    if not self.recharge or self.recharge.draining then
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

function Kris:applyRechargePlayerLight(soul)
    if not soul or not soul.sprite then
        return
    end

    if self.recharge_player_light and self.recharge_player_light.soul == soul then
        return
    end

    self:restoreRechargePlayerLight()
    self.recharge_player_light = {
        soul = soul,
        sprite = soul.sprite.texture_path,
        inherit_color = soul.sprite.inherit_color,
    }
    soul.sprite:setSprite(RECHARGE_PLAYER_LIGHT_SPRITE)
    soul.sprite:setOrigin(0.5, 0.5)
    soul.sprite.inherit_color = false

    local light = Sprite(RECHARGE_LIGHT_SPRITE, 0, 0)
    light:setOrigin(0.5, 0.5)
    light:setScale(RECHARGE_LIGHT_SCALE)
    light.layer = (soul.sprite.layer or 0) - 1
    light.alpha = 0
    soul:addChild(light)
    light:fadeTo(1, RECHARGE_PLATFORM_FADE_TIME)
    self.recharge_player_light.light = light
end

function Kris:restoreRechargePlayerLight()
    local data = self.recharge_player_light
    if not data then
        return
    end

    if data.soul and data.soul.parent and data.soul.sprite then
        if data.light then
            data.light:remove()
        end
        data.soul.sprite:setSprite(data.sprite or RECHARGE_DEFAULT_SOUL_SPRITE)
        data.soul.sprite:setOrigin(0.5, 0.5)
        data.soul.sprite.inherit_color = data.inherit_color
    elseif data.light then
        data.light:remove()
    end
    self.recharge_player_light = nil
end

function Kris:removeRechargeSoul(instant, enemy)
    if not self.recharge_soul then
        return
    end

    local soul = self.recharge_soul
    self.recharge_soul = nil

    if not soul.parent then
        return
    end

    if instant then
        soul:remove()
    elseif soul.transitionBackTo then
        enemy = enemy or soul.target_enemy or (self.recharge and self.recharge.enemy)
        local target_x, target_y = self:getRechargeSoulOriginPosition(enemy)
        soul:transitionBackTo(
            target_x + RECHARGE_RETURN_TARGET_OFFSET_X,
            target_y + RECHARGE_RETURN_TARGET_OFFSET_Y
        )
    else
        soul:fadeOutAndRemove(RECHARGE_PLATFORM_FADE_TIME)
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
    local recharge = self.recharge
    if not recharge or recharge.draining then
        self:restoreRechargePlayerLight()
        self:removeRechargeSoul(true)
        return
    end

    local target = self:getRechargeLightTarget()
    if not target then
        self:restoreRechargePlayerLight()
        local state = Game.battle and Game.battle:getState()
        self:removeRechargeSoul(state ~= "DEFENDINGEND", recharge.enemy)
        return
    end

    self:applyRechargePlayerLight(target)

    if not self.recharge_soul or not self.recharge_soul.parent then
        local origin_x, origin_y = self:getRechargeSoulOriginPosition(recharge.enemy)
        local target_x, target_y = self:getRechargeSoulSpawnPosition()
        self.recharge_soul = Registry.createBullet("recharge_soul", origin_x, origin_y, recharge.enemy, self:getRechargeLightRadius())
        self.recharge_soul:transitionTo(target_x, target_y)
        local burst = HeartBurst(origin_x - 2, origin_y + 1, { 1, 1, 1 })
        burst.layer = RECHARGE_SOUL_LAYER
        Game.battle:addChild(burst)
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

    self:restoreRechargePlayerLight()
    self:removeRechargeSoul(true)

    self:setPlatformSprite(PLATFORM_SPRITE, RECHARGE_PLATFORM_FADE_TIME)
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
    self:restoreRechargePlayerLight()
    self:removeRechargeSoul(instant, self.recharge and self.recharge.enemy)
    self.recharge = nil
end

function Kris:update()
    super.update(self)
    self:updateRechargeMercyCooldown()
    self:updateRechargeLight()
    self:updateRechargeTension()
end

function Kris:setupBackground(battle)
    self.bg_platform = Sprite(PLATFORM_SPRITE, 0, 0)
    self.bg_platform.layer = BATTLE_LAYERS["bottom"]
    self.bg_platform:setScale(2, 2)
    battle:addChild(self.bg_platform)

    self.bg_platform_particles = KrisPlatformParticles(self.bg_platform, PLATFORM_SPRITE)
    self.bg_platform_particles.layer = BATTLE_LAYERS["bottom"] + 0.25
    battle:addChild(self.bg_platform_particles)

    self.bg_depth = KrisDepthBackground()
    self.bg_depth.layer = BATTLE_LAYERS["bottom"] + 0.5
    battle:addChild(self.bg_depth)

    self.vignette = KrisVignette()
    self.vignette.layer = BATTLE_LAYERS["bottom"] + 1
    battle:addChild(self.vignette)
end

return Kris
