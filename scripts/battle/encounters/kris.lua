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
local RECHARGE_MERCY_INTERVAL = 0.15
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

local OPENING_STATE = "KRISIS_OPENING"
local OPENING_REVEAL_DELAY = 50 / 60
local OPENING_INITIAL_FLICKER_INTERVAL = 15 / 60
local OPENING_INITIAL_FLICKER_COUNT = 3
local OPENING_FOURTH_FLICKER_INTERVAL = 13 / 60
local OPENING_ACCELERATION_TIME = 60 / 60
local OPENING_MIN_FLICKER_INTERVAL = 1 / 60
local OPENING_FLICKER_CURVE_POWER = 2

-- Adjust the opening heart position here.
local OPENING_PLAYER_POSITION = {
    x = SCREEN_WIDTH / 2,
    y = (SCREEN_HEIGHT - 155) / 2 + 10,
}

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function copySpriteState(sprite)
    return {
        color = { sprite.color[1], sprite.color[2], sprite.color[3] },
        alpha = sprite.alpha,
        visible = sprite.visible,
        active = sprite.active,
        inherit_color = sprite.inherit_color,
    }
end

local function restoreSpriteState(sprite, state)
    if not sprite or not state then
        return
    end

    sprite:setColor(state.color[1], state.color[2], state.color[3], state.alpha)
    sprite.visible = state.visible
    sprite.active = state.active
    sprite.inherit_color = state.inherit_color
end

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

function Kris:getInitialEncounterText()
    local enemy = Game.battle and Game.battle.enemies and Game.battle.enemies[1]
    if enemy and enemy.getEncounterText then
        return enemy:getEncounterText()
    end

    return self.text
end

function Kris:onBattleInit()
    local battle = Game.battle
    if not battle then
        return
    end

    -- Hold the battle in a custom state until the opening has finished.
    battle.state = OPENING_STATE
    battle.state_reason = nil

    self.krisis_opening = {
        battle = battle,
        phase = "WAIT",
        timer = 0,
        flicker_timer = 0,
        acceleration_timer = 0,
        flicker_count = 0,
        fourth_flicker_done = false,
        heart_visible = false,
        kris_alpha = 0,
        prepared = false,
        child_states = {},
        party_positions = {},
        enemy_positions = {},
    }

    return true
end

function Kris:onBattleAdd(battle)
    local opening = self.krisis_opening
    if not opening or opening.prepared then
        return
    end

    opening.prepared = true

    local soul = battle.soul
    local opening_soul_created = false
    if not soul then
        soul = self:createSoul(
            OPENING_PLAYER_POSITION.x,
            OPENING_PLAYER_POSITION.y,
            { self:getSoulColor() }
        )
        battle.soul = soul
        battle:addChild(soul)
        opening_soul_created = true
    end

    soul:setPosition(OPENING_PLAYER_POSITION.x, OPENING_PLAYER_POSITION.y)

    opening.opening_soul_created = opening_soul_created
    opening.soul = soul
    opening.soul_state = {
        color = { soul.color[1], soul.color[2], soul.color[3] },
        alpha = soul.alpha,
        active = soul.active,
        visible = soul.visible,
    }
    if soul.sprite then
        opening.soul_sprite = soul.sprite
        opening.soul_sprite_state = copySpriteState(soul.sprite)
    end
    if soul.graze_sprite then
        opening.soul_graze_sprite = soul.graze_sprite
        opening.soul_graze_sprite_state = copySpriteState(soul.graze_sprite)
    end
    soul:setColor(0, 0, 0, soul.alpha)
    soul.active = false
    soul.visible = false
    if soul.graze_sprite then
        soul.graze_sprite.active = false
        soul.graze_sprite.visible = false
    end

    for _, child in ipairs(battle.children) do
        opening.child_states[child] = {
            active = child.active,
            visible = child.visible,
        }
        child.active = false
        child.visible = false
    end

    for index, battler in ipairs(battle.party or {}) do
        local target = battle.battler_targets[index]
        local x = target and target[1] or battler.x
        local y = target and target[2] or battler.y

        opening.party_positions[index] = { x, y }
        battler:setPosition(x, y)
        battle.party_beginning_positions[index] = { x, y }
    end

    for _, enemy in ipairs(battle.enemies or {}) do
        local x = enemy.target_x or enemy.x
        local y = enemy.target_y or enemy.y

        opening.enemy_positions[enemy] = { x, y }
        enemy.target_x = x
        enemy.target_y = y
        enemy:setPosition(x, y)
        battle.enemy_beginning_positions[enemy] = { x, y }
    end

    opening.kris = battle.enemies and battle.enemies[1]

    if opening.kris then
        opening.kris.active = true
        opening.kris.visible = false

        if opening.kris.sprite then
            opening.kris_sprite = opening.kris.sprite
            opening.kris_sprite_state = copySpriteState(opening.kris.sprite)
            opening.kris:setAnimation("idle")
            opening.kris.sprite:setColor(0, 0, 0, 0)
            opening.kris.sprite.visible = true
            opening.kris.sprite.active = true
        end
    end

    battle.transition_timer = 10
end

function Kris:beforeStateChange(old, new, reason)
    if self.krisis_opening then
        return true
    end
end

function Kris:getOpeningFlickerInterval(progress)
    progress = clamp(progress, 0, 1)
    local eased_progress = progress ^ OPENING_FLICKER_CURVE_POWER
    return OPENING_INITIAL_FLICKER_INTERVAL * (1 - eased_progress)
end

function Kris:lockOpeningPositions(opening)
    local battle = opening.battle
    if not battle then
        return
    end

    for index, position in pairs(opening.party_positions) do
        local battler = battle.party[index]
        if battler then
            battler:setPosition(position[1], position[2])
        end
    end

    for enemy, position in pairs(opening.enemy_positions) do
        if enemy and enemy.parent then
            enemy:setPosition(position[1], position[2])
        end
    end
end

function Kris:applyOpeningVisuals(opening)
    if opening.kris_sprite and opening.kris_sprite_state then
        local alpha = opening.kris_sprite_state.alpha * clamp(opening.kris_alpha, 0, 1)
        opening.kris_sprite:setColor(0, 0, 0, alpha)
    end
end

function Kris:finishOpening()
    local opening = self.krisis_opening
    if not opening then
        return
    end

    local battle = opening.battle
    opening.heart_visible = true
    opening.kris_alpha = 1
    self:applyOpeningVisuals(opening)

    if opening.kris_sprite and opening.kris_sprite_state then
        restoreSpriteState(opening.kris_sprite, opening.kris_sprite_state)
    end

    if opening.soul and opening.soul_state then
        opening.soul:setColor(
            opening.soul_state.color[1],
            opening.soul_state.color[2],
            opening.soul_state.color[3],
            opening.soul_state.alpha
        )
        opening.soul.active = opening.soul_state.active
        opening.soul.visible = opening.soul_state.visible
        restoreSpriteState(opening.soul_sprite, opening.soul_sprite_state)
        restoreSpriteState(opening.soul_graze_sprite, opening.soul_graze_sprite_state)
    end

    for child, state in pairs(opening.child_states) do
        if child.parent == battle then
            child.active = state.active
            child.visible = state.visible
        end
    end

    if battle then
        battle.transition_timer = 10
    end

    if opening.opening_soul_created and opening.soul and opening.soul.parent then
        opening.soul:remove()
        battle.soul = nil
    end

    self.krisis_opening = nil

    if battle and battle.parent then
        battle:setState("INTRO")
    end
end

function Kris:updateOpening()
    local opening = self.krisis_opening
    if not opening then
        return
    end

    if not opening.prepared and Game.battle then
        self:onBattleAdd(Game.battle)
    end

    self:lockOpeningPositions(opening)

    if opening.phase == "WAIT" then
        opening.timer = opening.timer + DT
        if opening.timer >= OPENING_REVEAL_DELAY then
            opening.phase = "INITIAL_FLICKER"
            opening.timer = 0
            opening.heart_visible = true
        end
    elseif opening.phase == "INITIAL_FLICKER" then
        opening.flicker_timer = opening.flicker_timer + DT

        local steps = 0
        while opening.flicker_timer >= OPENING_INITIAL_FLICKER_INTERVAL
            and opening.phase == "INITIAL_FLICKER"
            and steps < 64
        do
            opening.flicker_timer = opening.flicker_timer - OPENING_INITIAL_FLICKER_INTERVAL
            opening.heart_visible = not opening.heart_visible
            steps = steps + 1

            if opening.heart_visible then
                opening.flicker_count = opening.flicker_count + 1
                if opening.flicker_count >= OPENING_INITIAL_FLICKER_COUNT then
                    opening.phase = "ACCELERATING"
                    opening.flicker_timer = 0
                    opening.acceleration_timer = 0
                    opening.fourth_flicker_done = false
                    opening.heart_visible = true
                end
            end
        end
    elseif opening.phase == "ACCELERATING" then
        opening.acceleration_timer = opening.acceleration_timer + DT
        local progress = clamp(opening.acceleration_timer / OPENING_ACCELERATION_TIME, 0, 1)

        opening.kris_alpha = progress

        local interval = opening.fourth_flicker_done
            and self:getOpeningFlickerInterval(progress)
            or OPENING_FOURTH_FLICKER_INTERVAL
        if interval > OPENING_MIN_FLICKER_INTERVAL then
            opening.flicker_timer = opening.flicker_timer + DT

            local steps = 0
            while opening.flicker_timer >= interval and steps < 64 do
                opening.flicker_timer = opening.flicker_timer - interval
                opening.heart_visible = not opening.heart_visible
                opening.fourth_flicker_done = true
                steps = steps + 1
            end
        else
            opening.flicker_timer = 0
        end

        if progress >= 1 then
            opening.phase = "DONE"
            opening.heart_visible = true
        end
    end

    self:applyOpeningVisuals(opening)
    self:lockOpeningPositions(opening)

    if opening.phase == "DONE" then
        self:finishOpening()
    end
end

function Kris:drawOpeningBattler(battler)
    if battler and battler.parent then
        battler:fullDraw()
    end
end

function Kris:draw(fade)
    super.draw(self, fade)

    local opening = self.krisis_opening
    if not opening then
        return
    end

    love.graphics.push()
    love.graphics.origin()
    Draw.setColor(1, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.pop()

    if opening.heart_visible then
        self:drawOpeningBattler(opening.soul)
    end
    if opening.kris_alpha > 0 then
        self:drawOpeningBattler(opening.kris)
    end

    Draw.setColor(1, 1, 1, 1)
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
    self.finisher_battle_pending = true
    self:clearRecharge(true)

    for _, enemy in ipairs(Game.battle.enemies or {}) do
        if enemy.clearHeartbeatSpeedBoost then
            enemy:clearHeartbeatSpeedBoost()
        end
    end
end

function Kris:startFinisherBattle()
    return self.finisher_battle_pending == true
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
    self:updateOpening()
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
