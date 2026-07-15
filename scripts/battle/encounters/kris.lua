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
local FULL_MERCY = 100
local MERCY_FINALE_LAYER = BATTLE_LAYERS["ui"] - 2
local FAST_SPEED = 4 / 30
local MERCY_FINALE_MUSIC_FADE_TIME = 0.25
local MERCY_FINALE_MUSIC_END_WINDOW = 1
local MERCY_FINALE_ENEMY_TURN_DURATION = 5
local MERCY_FINALE_UI_FADE_TIME = 0.9
local MERCY_FINALE_DETACHED_MOVE_SPEED = 3

local function isAttackAction(action)
    return action and (action.action == "ATTACK" or action.action == "AUTOATTACK")
end

function Kris:init()
    super.init(self)

    self:applyLocalization()
    self.music = "never_forgetting"
    self.background = false
    self.hide_world = true

    self.kris_enemy = self:addEnemy("kris", 507, 239)

    self.recharge = nil
    self.recharge_soul = nil
    self.recharge_light_radius = nil
    self.recharge_player_light = nil
    self.mercy_finale = nil
    self.mercy_finale_started = false
    self.mercy_finale_active = false
    self.mercy_finale_ui_released = false
    self.mercy_finale_postlude = false
    self.mercy_finale_leave_requested = false
    self.mercy_finale_detached = false
    self.mercy_finale_ui_alpha = 1
    self.mercy_finale_ui_fades = nil
    self.mercy_finale_suppress_narration = false
    self.mercy_finale_enemy_turn = false
    self.mercy_finale_enemy_turn_time = 0
    self.mercy_attack_increased = false
    self.mercy_attack_action_started = false
    self.mercy_before_actions = nil
end

function Kris:applyLocalization()
    self.text = Game:loc("* [name:chara:kris] slashes into the combat.", "enemy_kris_turn_1")
end

function Kris:getInitialEncounterText()
    if self.mercy_finale_suppress_narration then
        return ""
    end

    local enemy = Game.battle and Game.battle.enemies and Game.battle.enemies[1]
    if enemy and enemy.getEncounterText then
        return enemy:getEncounterText()
    end

    return self.text
end

function Kris:getEncounterText()
    if self.mercy_finale_suppress_narration then
        return ""
    end

    return super.getEncounterText(self)
end

function Kris:getKrisEnemy()
    if self.kris_enemy and self.kris_enemy.parent then
        return self.kris_enemy
    end

    local battle = Game.battle
    for _, enemy in ipairs(battle and battle.enemies or {}) do
        if enemy.actor and enemy.actor.id == "kris" then
            self.kris_enemy = enemy
            return enemy
        end
    end
end

function Kris:isFullMercy()
    local enemy = self:getKrisEnemy()
    local mercy = enemy and (enemy.mercy or 0) + (enemy.temporary_mercy or 0)
    return enemy and not enemy.done_state and mercy >= FULL_MERCY
end

function Kris:markKrisAttackMercyIncrease(enemy)
    if enemy == self:getKrisEnemy() then
        self.mercy_attack_increased = true
    end
end

function Kris:handleMercyFinaleMusic(battle)
    local music = battle and battle.music
    if not music then
        return
    end

    music:setLooping(false)

    if not music.source or not music:isPlaying() then
        return
    end

    local duration = music.source:getDuration()
    local position = music:tell()
    local remaining = duration and duration > 0 and duration - position or nil

    if remaining and remaining <= MERCY_FINALE_MUSIC_END_WINDOW then
        return
    end

    music:fade(0, MERCY_FINALE_MUSIC_FADE_TIME, function(current_music)
        current_music:stop()
    end)
end

function Kris:tryStartMercyFinale(reason)
    if self.mercy_finale_started or not self:isFullMercy() then
        return false
    end

    local battle = Game.battle
    local enemy = self:getKrisEnemy()
    if not battle or not enemy then
        return false
    end

    self.mercy_finale_started = true
    self.mercy_finale_active = true
    self.mercy_finale_ui_released = false
    self.mercy_finale_leave_requested = false
    self.mercy_finale_detached = false
    self.mercy_finale_ui_alpha = 1
    self.mercy_finale_ui_fades = nil
    self.mercy_finale_reason = reason
    self:handleMercyFinaleMusic(battle)

    enemy:setAnimation({ "twist", FAST_SPEED, true })

    self.mercy_finale = KrisMercyFinale(enemy, {
        layer = MERCY_FINALE_LAYER,
        on_black_screen = function()
            self:clearRechargeForMercyFinale()
        end,
        on_light_ready = function()
            self:releaseMercyFinaleToPlayerTurn()
        end,
    })
    battle:addChild(self.mercy_finale)
    return true
end

function Kris:releaseMercyFinaleToPlayerTurn()
    if self.mercy_finale_ui_released then
        return
    end

    self.mercy_finale_active = false
    self.mercy_finale_ui_released = true
    self.mercy_finale_postlude = true

    local enemy = self:getKrisEnemy()
    if enemy and enemy.enterMercyFinaleAftermath then
        enemy:enterMercyFinaleAftermath()
    end

    local battle = Game.battle
    if not battle then
        return
    end

    self.mercy_finale_suppress_narration = true
    if battle:getState() ~= "ACTIONSELECT" then
        battle:setState("ACTIONSELECT", "MERCY_FINALE")
    else
        battle:showUI()
    end
    self.mercy_finale_suppress_narration = false
end

function Kris:isMercyFinalePostlude()
    return self.mercy_finale_postlude == true
end

function Kris:isMercyFinaleDetached()
    return self.mercy_finale_detached == true
end

function Kris:requestMercyFinaleLeave(battler)
    if not self.mercy_finale_postlude or self.mercy_finale_detached then
        return
    end

    self.mercy_finale_leave_requested = true

    local battle = Game.battle
    local action = battle and battle:getActionBy(battler)
    if action then
        -- Leave has no text to advance, so finish the ACT directly. The
        -- detached state is entered after the normal ACT end animation.
        battle:finishAction(action)
    end
end

function Kris:addMercyFinaleUiFade(object)
    if not object then
        return
    end

    self.mercy_finale_ui_fades = self.mercy_finale_ui_fades or {}
    local fx = object:getFX("mercy_finale_detached_ui")
    if not fx then
        fx = object:addFX(AlphaFX(1), "mercy_finale_detached_ui")
    end
    table.insert(self.mercy_finale_ui_fades, fx)
end

function Kris:fadeMercyFinaleUi(battle)
    self.mercy_finale_ui_alpha = 1
    self.mercy_finale_ui_fades = {}

    self:addMercyFinaleUiFade(battle.battle_ui)
    self:addMercyFinaleUiFade(battle.tension_bar)

    if battle.battle_ui then
        self:addMercyFinaleUiFade(battle.battle_ui.encounter_text)
        self:addMercyFinaleUiFade(battle.battle_ui.choice_box)
        self:addMercyFinaleUiFade(battle.battle_ui.short_act_text_1)
        self:addMercyFinaleUiFade(battle.battle_ui.short_act_text_2)
        self:addMercyFinaleUiFade(battle.battle_ui.short_act_text_3)
    end
end

function Kris:playMercyFinaleDetachedAnimation(battle)
    local enemy = self:getKrisEnemy()
    if enemy then
        enemy:setAnimation({
            "put_back",
            1 / 15,
            false,
            frames = { 1 },
            callback = function(sprite)
                sprite:setFrame(1)
                sprite:pause()
            end,
        })
    end

    local vessel = battle:getPartyBattler("vessel")
    if not vessel then
        return
    end

    vessel.defending = false
    if enemy then
        local defeat_layer = (enemy.layer or BATTLE_LAYERS["battlers"]) + 0.5
        if self.mercy_finale and defeat_layer >= self.mercy_finale.layer then
            defeat_layer = self.mercy_finale.layer - 0.5
        end
        vessel:setLayer(defeat_layer)
    end
    vessel:setAnimation({
        "battle/defeat",
        1 / 15,
        false,
        frames = { "1-10" },
        callback = function(sprite)
            -- Keep the final defeat pose even if the animation is interrupted.
            sprite:setFrame(10)
            sprite:pause()
        end,
    })
end

function Kris:enterMercyFinaleDetached()
    if self.mercy_finale_detached then
        return
    end

    local battle = Game.battle
    if not battle then
        return
    end

    self.mercy_finale_detached = true
    self.mercy_finale_leave_requested = false
    self.mercy_finale_enemy_turn = false
    self.mercy_finale_enemy_turn_time = 0

    if battle.battle_ui then
        battle.battle_ui:clearEncounterText()
        battle.battle_ui.choice_box.visible = false
        battle.battle_ui.short_act_text_1:setText("")
        battle.battle_ui.short_act_text_2:setText("")
        battle.battle_ui.short_act_text_3:setText("")
    end
    battle:clearMenuItems()
    battle:hideTargets()
    if battle.arena then
        battle.arena:remove()
        battle.arena = nil
    end
    battle.current_selecting = 0

    self:playMercyFinaleDetachedAnimation(battle)
    self:fadeMercyFinaleUi(battle)
    battle:setState("MERCY_FINALE_DETACHED", "MERCY_FINALE_LEAVE")
end

function Kris:updateMercyFinaleDetached()
    local battle = Game.battle
    if not battle then
        return
    end

    local vessel = battle:getPartyBattler("vessel")
    if vessel then
        local dx = (Input.down("right") and 1 or 0) - (Input.down("left") and 1 or 0)
        local dy = (Input.down("down") and 1 or 0) - (Input.down("up") and 1 or 0)
        if dx ~= 0 or dy ~= 0 then
            local length = math.sqrt(dx * dx + dy * dy)
            local speed = MERCY_FINALE_DETACHED_MOVE_SPEED * DTMULT / length
            vessel.x = vessel.x + dx * speed
            vessel.y = vessel.y + dy * speed
        end

        local x_margin = (vessel.width * vessel.scale_x) / 2
        local y_margin = vessel.height * vessel.scale_y
        vessel.x = MathUtils.clamp(vessel.x, x_margin, SCREEN_WIDTH - x_margin)
        vessel.y = MathUtils.clamp(vessel.y, y_margin, SCREEN_HEIGHT - 4)
    end

    if self.mercy_finale_ui_fades then
        self.mercy_finale_ui_alpha = math.max(
            0,
            self.mercy_finale_ui_alpha - DT / MERCY_FINALE_UI_FADE_TIME
        )
        for _, fx in ipairs(self.mercy_finale_ui_fades) do
            fx.alpha = self.mercy_finale_ui_alpha
        end
    end
end

function Kris:clearMercyFinaleHighlights()
    local battle = Game.battle
    if not battle then
        return
    end

    for _, battler in ipairs(battle.enemies or {}) do
        if battler.highlight then
            battler.highlight.amount = 0
        end
        battler.flash_timer = 0
        battler.last_highlighted = false
    end

    for _, battler in ipairs(battle.party or {}) do
        if battler.highlight then
            battler.highlight.amount = 0
        end
        battler.flash_timer = 0
        battler.last_highlighted = false
    end
end

function Kris:resetMercyFinalePlayerSprites()
    local battle = Game.battle
    if not battle then
        return
    end

    for _, battler in ipairs(battle.party or {}) do
        battler.defending = false
        if battler.sprite and battler.sprite.anim ~= "battle/idle" then
            battler:resetSprite()
        end
    end
end

function Kris:startMercyFinaleEnemyTurn()
    local battle = Game.battle
    if not battle then
        return
    end

    self.mercy_finale_enemy_turn = true
    self.mercy_finale_enemy_turn_time = MERCY_FINALE_ENEMY_TURN_DURATION

    -- Use a private state so the engine does not create an arena or start a
    -- wave. The five-second interval is still a real enemy-turn phase for
    -- the postlude, with all player input ignored by Battle's state handler.
    if battle.battle_ui then
        battle.battle_ui:clearEncounterText()
    end
    battle:hideTargets()
    if battle.arena then
        battle.arena:remove()
        battle.arena = nil
    end
    battle.current_selecting = 0
    battle:setState("MERCY_FINALE_ENEMY_TURN", "MERCY_FINALE")
end

function Kris:finishMercyFinaleEnemyTurn()
    local battle = Game.battle
    if not battle then
        return
    end

    self.mercy_finale_enemy_turn = false
    self.mercy_finale_enemy_turn_time = 0

    local enemy = self:getKrisEnemy()
    if enemy then
        enemy:resetSprite()
    end

    for _, battler in ipairs(battle.party or {}) do
        local was_defending = battler.defending
        battler.defending = false
        if was_defending
            or (battler.sprite and battler.sprite.anim == "battle/defend")
        then
            battler:resetSprite()
        end
    end

    -- nextTurn() is entered synchronously by ACTIONSELECT while the
    -- narration guard is active, so this turn remains textless.
    self.mercy_finale_suppress_narration = true
    battle:setState("ACTIONSELECT", "MERCY_FINALE_RETURN")
    self.mercy_finale_suppress_narration = false
end

function Kris:onBattleStart()
    local initial_tp = Game:getConfig("krisisInitialTP")
    if initial_tp ~= nil then
        initial_tp = tonumber(initial_tp)
        if initial_tp then
            Game:setTension(initial_tp)
        end
    end

    local initial_mercy = Game:getConfig("krisisInitialMercy")
    if initial_mercy ~= nil then
        local enemy = self:getKrisEnemy()
        if enemy then
            enemy.mercy = MathUtils.clamp(tonumber(initial_mercy) or 0, 0, 100)
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

    if self:isFullMercy() then
        self:tryStartMercyFinale("battle_start")
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
    if not self.mercy_finale_started and self:isFullMercy() then
        self:tryStartMercyFinale("turn_end")
        return true
    end

    local recharge = self.recharge
    if recharge and not recharge.draining and not recharge.expiring then
        recharge.turns_remaining = math.max((recharge.turns_remaining or 1) - 1, 0)
        if recharge.turns_remaining <= 0 then
            recharge.expiring = true
            if recharge.enemy and recharge.enemy.finishRechargeWavePhaseAdvance then
                recharge.enemy:finishRechargeWavePhaseAdvance()
            end
        end
    end
end

function Kris:onActionsEnd()
    if self.mercy_finale_active then
        return true
    end

    if self.mercy_finale_leave_requested then
        self:enterMercyFinaleDetached()
        return true
    end

    if self.mercy_finale_postlude then
        self:startMercyFinaleEnemyTurn()
        return true
    end

    local enemy = self:getKrisEnemy()
    local mercy_increased = self.mercy_attack_increased
    if not mercy_increased
        and self.mercy_attack_action_started
        and self.mercy_before_actions ~= nil
        and enemy
    then
        mercy_increased = (enemy.mercy or 0) > self.mercy_before_actions
    end

    if mercy_increased and self:isFullMercy()
        and self:tryStartMercyFinale("attack")
    then
        return true
    end
end

function Kris:beforeStateChange(old, new, reason)
    if self.mercy_finale_active then
        return true
    end
end

function Kris:onActionsStart()
    self.mercy_attack_increased = false
    self.mercy_attack_action_started = false

    local enemy = self:getKrisEnemy()
    self.mercy_before_actions = enemy and enemy.mercy or nil

    local battle = Game.battle
    for _, action in pairs(battle and battle.character_actions or {}) do
        if isAttackAction(action) then
            self.mercy_attack_action_started = true
            break
        end
    end
end

function Kris:onStateChange(old, new, reason)
    if new == "ATTACKING" then
        local battle = Game.battle
        self.mercy_attack_action_started = self.mercy_attack_action_started
            or (battle and #battle.attackers > 0 or false)
    elseif new == "ACTIONSELECT" then
        self:beginRechargeDrain()
        if self.mercy_finale_postlude then
            self:resetMercyFinalePlayerSprites()
            self:clearMercyFinaleHighlights()
        end
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
    if self.mercy_finale_postlude then
        self:clearMercyFinaleHighlights()
        battle:clearMenuItems()
        battle:addMenuItem({
            ["name"] = enemy.act_mercy_finale_view,
            ["description"] = "",
            ["party"] = { "vessel" },
            ["highlight"] = nil,
            ["callback"] = function(menu_item)
                battle:pushAction("ACT", enemy, menu_item)
            end,
        })
        battle:addMenuItem({
            ["name"] = enemy.act_mercy_finale_leave,
            ["description"] = "",
            ["party"] = { "vessel" },
            ["highlight"] = nil,
            ["callback"] = function(menu_item)
                battle:pushAction("ACT", enemy, menu_item)
            end,
        })
        battle:setState("MENUSELECT", "ACT")
        return true
    end

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

function Kris:clearRechargeForMercyFinale()
    if not self.recharge then
        return
    end

    self:clearRecharge(true)
    self:setPlatformSprite(PLATFORM_SPRITE, RECHARGE_PLATFORM_FADE_TIME)
    Game:setTension(0)
end

function Kris:update()
    super.update(self)

    if self.mercy_finale_detached then
        self:updateMercyFinaleDetached()
    end

    if self.mercy_finale_enemy_turn then
        self.mercy_finale_enemy_turn_time = self.mercy_finale_enemy_turn_time - DT
        if self.mercy_finale_enemy_turn_time <= 0 then
            self:finishMercyFinaleEnemyTurn()
        end
    end

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
