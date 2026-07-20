local Kris, super = Class(EnemyBattler)

local WAIT = "[wait:5]"
local HEARTBEAT_SOUL_SPEED = 6
local RECHARGE_MIN_TENSION = 50
local RECHARGE_ACT_FLASH_SPEED = 6
local MERCY_TEXT_LAYER_OFFSET = 1
local TURN_WAVES = {
    [1] = "kris_phase1_01",
    [2] = "kris_phase1_02",
    [3] = "kris_phase1_03",
    [4] = "kris_phase1_04",
    [5] = "kris_phase1_05",
    [6] = "kris_phase1_06",
    [7] = "kris_phase1_07",
    [8] = "kris_phase1_08",
    [9] = "kris_phase1_09",
    [10] = "kris_phase1_10",
    [11] = "kris_phase1_11",
    [12] = "kris_phase1_12",
    [13] = "kris_phase1_13",
    [14] = "kris_phase1_14",
    [15] = "kris_phase1_15",
}
local WAVE_PHASES = {
    { first = 1, last = 5 },
    { first = 6, last = 10 },
    { first = 11, last = 15 },
}
local RECHARGE_AVOID_WAVES = {
    [1] = true,
    [2] = true,
    [3] = true,
    [6] = true,
    [8] = true,
    [9] = true,
    [11] = true,
    [12] = true,
    [15] = true,
}
local RECHARGE_FALLBACK_WAVES = {
    [10] = 4,
    [14] = 4,
}

local function makeWaveList(first, last)
    local waves = {}
    for i = first, last do
        table.insert(waves, TURN_WAVES[i])
    end
    return waves
end

local function randomWaveNumber(first, last)
    return Mod:randomKrisis("kris_wave_selection", first, last)
end

local function normalizeWaveNumber(value)
    local number = tonumber(value)
    if not number then
        return nil
    end

    number = math.floor(number)
    if not TURN_WAVES[number] then
        return nil
    end

    return number
end

local function getConfiguredWaveOptions()
    if not Mod or not Mod.getKrisisRunWaveOptions then
        return nil, nil
    end

    local start_wave, forced_wave = Mod:getKrisisRunWaveOptions()
    return normalizeWaveNumber(start_wave), normalizeWaveNumber(forced_wave)
end

local function getWavePhaseForNumber(wave_number)
    for phase_index, phase in ipairs(WAVE_PHASES) do
        if wave_number >= phase.first and wave_number <= phase.last then
            return phase_index, phase
        end
    end
end

local function liftMercyTextLayer(enemy, mercy_text)
    if not mercy_text then
        return
    end

    mercy_text.layer = math.max(
        mercy_text.layer or BATTLE_LAYERS["damage_numbers"],
        (enemy.layer or BATTLE_LAYERS["battlers"]) + MERCY_TEXT_LAYER_OFFSET
    )
end

local function getVesselAttackResults(points)
    points = tonumber(points) or 0
    if points <= 0 then
        return nil
    end

    local t = (points - 100) / 50
    if t < 0 then t = 0 elseif t > 1 then t = 1 end

    return math.floor(40 - 20 * t + 0.5),
        math.floor(4 + 2 * t + 0.5)
end

function Kris:init()
    super.init(self)

    -- Sets the actor, which handles the enemy's sprites (see scripts/data/actors/kris.lua)
    self:setActor("kris")
    self.layer = BATTLE_LAYERS["above_bullets"] + 1

    -- Enemy health
    self.max_health = 450
    self.health = 450
    -- Enemy attack (determines bullet damage)
    self.attack = 4
    -- Enemy defense (usually 0)
    self.defense = 0
    -- Enemy reward
    self.money = 100

    -- Mercy is earned through attacks; directly selecting MERCY should not add any.
    self.spare_points = 0

    -- Used by the base battle code/debug paths; selectWave controls the actual order.
    self.waves = makeWaveList(1, 15)
    self.wave_phase = 1
    self.wave_phase_turns_played = 0
    self.wave_select_turn_count = nil
    self.selected_wave_number = nil
    self.recharge_wave_phase_advance_pending = false

    self.start_wave_number, self.forced_wave_number = getConfiguredWaveOptions()
    if self.start_wave_number then
        local phase_index, phase = getWavePhaseForNumber(self.start_wave_number)
        if phase_index and phase then
            self.wave_phase = phase_index
            self.wave_phase_turns_played = self.start_wave_number - phase.first
        end
    end

    self.dialogue = {}
    self.heartbeat_speed_boosted = false
    self.heartbeat_original_soul_speed = nil

    self:applyLocalization()
    self.recharge_act = self:registerAct(
        self.act_recharge,
        self.act_recharge_description,
        { "vessel" },
        RECHARGE_MIN_TENSION
    )
    self:registerAct(self.act_heartbeat, self.act_heartbeat_description, { "vessel" })

    self.recharge_act_was_available = false
    self.recharge_ready_text_pending = false
    self.recharge_ready_text_shown = false
end

function Kris:applyLocalization(update_acts)
    local old_check = self.act_check
    local old_recharge = self.act_recharge
    local old_heartbeat = self.act_heartbeat

    self.name = Game:locName("actor", "kris", "KRIS")
    self.mercy_finale_enemy_name = Game:loc("???", "enemy_kris_mercy_finale_name")

    -- Check text (automatically has "ENEMY NAME - " at the start)
    self.check = {
        Game:loc("?? ATK ??? DEF", "enemy_kris_check_1"),
        Game:loc("Darkness grants them regeneration." .. WAIT .. "\n* Transformed into a monster\nof pure aggressive instinct.", "enemy_kris_check_2"),
        Game:loc("Use your power to defeat them.", "enemy_kris_check_3"),
    }

    local late_turn_text = Game:loc("* Darkness rushes towards you at high speed.", "enemy_kris_turn_9")
    self.recharge_available_text = Game:loc(
        "* Your soul is full of the POWER OF LIGHT.",
        "enemy_kris_recharge_available"
    )
    self.text = {
        Game:loc("* [name:chara:kris] slashes into the combat.", "enemy_kris_turn_1"),
        Game:loc("* The darkness froze on the blade.", "enemy_kris_turn_2"),
        Game:loc("* Suddenly, the earth was torn apart by swords.", "enemy_kris_turn_3"),
        Game:loc("* [name:chara:kris] prepares to use \"Darkness Buster\".", "enemy_kris_turn_4"),
        Game:loc("* Darkness emerges from the crack, surging towards the sky.", "enemy_kris_turn_5"),
        Game:loc("* Suddenly, your body seized up.", "enemy_kris_turn_6"),
        Game:loc("* The thick fog gathered, then formed its shape.", "enemy_kris_turn_7"),
        Game:loc("* Countless swords make you dizzy.", "enemy_kris_turn_8"),
        late_turn_text,
        Game:loc("* It makes the earth tremble and roar.", "enemy_kris_turn_10"),
        Game:loc("* Suddenly, your body was torn apart.", "enemy_kris_turn_11"),
        late_turn_text,
        late_turn_text,
        Game:loc("* The fragments of darkness solidified into a vaguely familiar shape.", "enemy_kris_turn_14"),
        Game:loc("* The earth released its final breath.", "enemy_kris_turn_15"),
    }
    self.low_health_text = nil

    self.act_check = Game:loc("Check", "act_check")
    self.act_check_description = Game:loc("Consider\nstrategy", "act_kris_check_description")
    self.act_mercy_finale_view = Game:loc("View", "act_kris_mercy_finale_view")
    self.act_mercy_finale_leave = Game:loc("Detach", "act_kris_mercy_finale_leave")
    self.act_mercy_finale_view_text = Game:loc("", "act_kris_mercy_finale_view_text")
    self.act_mercy_finale_leave_text = ""
    self.act_recharge = Game:loc("Recharge", "act_kris_recharge")
    self.act_recharge_description = Game:loc("SHINE", "act_kris_recharge_description")
    self.act_heartbeat = Game:loc("Heartbeat", "act_kris_heartbeat")
    if self.heartbeat_speed_boosted then
        self.act_heartbeat_description = Game:loc(
            "Seems ineffective",
            "act_kris_heartbeat_repeat_description"
        )
    else
        self.act_heartbeat_description = Game:loc("Speed\nUp", "act_kris_heartbeat_description")
    end

    if self.acts[1] then
        self.acts[1].name = self.act_check
        self.acts[1].description = self.act_check_description
    end

    if update_acts then
        for _, act in ipairs(self.acts or {}) do
            if act.name == old_check then
                act.name = self.act_check
                act.description = self.act_check_description
            elseif act.name == old_recharge then
                act.name = self.act_recharge
                act.description = self.act_recharge_description
                self.recharge_act = act
            elseif act.name == old_heartbeat then
                act.name = self.act_heartbeat
                act.description = self.act_heartbeat_description
            end
        end
    end
end

function Kris:enterMercyFinaleAftermath()
    self.mercy = 0
    self.temporary_mercy = 0

    if self.temporary_mercy_percent then
        self.temporary_mercy_percent:remove()
        self.temporary_mercy_percent = nil
    end

    self.name = self.mercy_finale_enemy_name or "???"
end

function Kris:isMercyFinalePostlude()
    local encounter = Game.battle and Game.battle.encounter
    return encounter
        and encounter.isMercyFinalePostlude
        and encounter:isMercyFinalePostlude()
end

function Kris:getRechargeActTPCost()
    local tension = Game and Game.getTension and Game:getTension() or 0
    if tension >= RECHARGE_MIN_TENSION then
        return tension
    end

    return RECHARGE_MIN_TENSION
end

function Kris:updateRechargeActTPCost()
    local encounter = Game.battle and Game.battle.encounter
    local recharge_active = encounter
        and encounter.isRechargeActive
        and encounter:isRechargeActive()
    local available = Game.battle
        and Game:getTension() >= RECHARGE_MIN_TENSION
        and not recharge_active

    if available and not self.recharge_act_was_available and not self.recharge_ready_text_shown then
        self.recharge_ready_text_pending = true
    end
    self.recharge_act_was_available = available or false

    if self.recharge_act then
        self.recharge_act.tp = self:getRechargeActTPCost()
        self.recharge_act.unusable = recharge_active or false
    end
end

function Kris:getRechargeActMenuColor()
    local time = Kristal.getTime and Kristal.getTime() or love.timer.getTime()
    local yellow = (math.sin((time * RECHARGE_ACT_FLASH_SPEED) - (math.pi / 2)) + 1) / 2

    return { 1, 1, 1 - yellow, 1 }
end

function Kris:statusMessage(type, ...)
    local message = super.statusMessage(self, type, ...)
    if type == "mercy" then
        liftMercyTextLayer(self, message)
    end
    return message
end

function Kris:addTemporaryMercy(...)
    super.addTemporaryMercy(self, ...)
    liftMercyTextLayer(self, self.temporary_mercy_percent)
end

function Kris:getCurrentWavePhase()
    return WAVE_PHASES[self.wave_phase] or WAVE_PHASES[#WAVE_PHASES]
end

function Kris:getPhaseSequenceLength(phase)
    phase = phase or self:getCurrentWavePhase()
    return (phase.last - phase.first) + 1
end

function Kris:isPhaseSequenceComplete()
    return (self.wave_phase_turns_played or 0) >= self:getPhaseSequenceLength()
end

function Kris:isRechargeSustaining()
    return Game.battle
        and Game.battle.encounter
        and Game.battle.encounter.isRechargeSustaining
        and Game.battle.encounter:isRechargeSustaining()
end

function Kris:shouldAvoidWaveNumber(wave_number)
    return self:isRechargeSustaining() and RECHARGE_AVOID_WAVES[wave_number] == true
end

function Kris:getRechargeWaveNumber(wave_number)
    if not self:isRechargeSustaining() then
        return wave_number
    end

    return RECHARGE_FALLBACK_WAVES[wave_number] or wave_number
end

function Kris:getRandomPhaseWaveNumber(phase)
    local candidates = {}
    for i = phase.first, phase.last do
        if not self:shouldAvoidWaveNumber(i) then
            table.insert(candidates, i)
        end
    end

    if #candidates > 0 then
        return candidates[randomWaveNumber(1, #candidates)]
    end

    return randomWaveNumber(phase.first, phase.last)
end

function Kris:getNextPhaseWaveNumber()
    local phase = self:getCurrentWavePhase()
    local played = self.wave_phase_turns_played or 0

    if played < self:getPhaseSequenceLength(phase) then
        for wave_number = phase.first + played, phase.last do
            if not self:shouldAvoidWaveNumber(wave_number) then
                return wave_number, (wave_number - phase.first) + 1
            end
        end
    end

    return self:getRandomPhaseWaveNumber(phase), played + 1
end

function Kris:getEncounterTextWaveNumber()
    if self.forced_wave_number then
        return self.forced_wave_number
    end

    local battle_turn = Game.battle and Game.battle.turn_count
    if self.wave_select_turn_count == battle_turn and self.selected_wave_number then
        return self.selected_wave_number
    end

    local phase = self:getCurrentWavePhase()
    local played = self.wave_phase_turns_played or 0
    if played < self:getPhaseSequenceLength(phase) then
        local wave_number = self:getNextPhaseWaveNumber()
        return self:getRechargeWaveNumber(wave_number)
    end

    return phase.last
end

function Kris:queueRechargeWavePhaseAdvance()
    self.recharge_wave_phase_advance_pending = "recharge"
end

function Kris:finishRechargeWavePhaseAdvance()
    if self.recharge_wave_phase_advance_pending ~= "recharge" then
        return false
    end

    if not self:isPhaseSequenceComplete() then
        self.recharge_wave_phase_advance_pending = "sequence"
        return false
    end

    self.recharge_wave_phase_advance_pending = false
    return self:advanceWavePhase()
end

function Kris:tryFinishQueuedWavePhaseAdvance()
    if self.recharge_wave_phase_advance_pending ~= "sequence"
        or not self:isPhaseSequenceComplete()
    then
        return false
    end

    self.recharge_wave_phase_advance_pending = false
    return self:advanceWavePhase()
end

function Kris:advanceWavePhase()
    if (self.wave_phase or 1) >= #WAVE_PHASES then
        return false
    end

    self.wave_phase = (self.wave_phase or 1) + 1
    self.wave_phase_turns_played = 0
    self.wave_select_turn_count = nil
    self.selected_wave = nil
    self.selected_wave_number = nil
    self.recharge_wave_phase_advance_pending = false
    return true
end

function Kris:selectWave()
    if self.forced_wave_number then
        local forced_wave = TURN_WAVES[self.forced_wave_number]
        if forced_wave then
            self.selected_wave = forced_wave
            self.selected_wave_number = self.forced_wave_number
            print("playing wave: " .. self.selected_wave)
            return self.selected_wave
        end
    end

    local battle_turn = Game.battle and Game.battle.turn_count
    if self.wave_select_turn_count == battle_turn and self.selected_wave then
        return self.selected_wave
    end

    local wave_number, next_phase_turns_played = self:getNextPhaseWaveNumber()
    local selected_wave_number = self:getRechargeWaveNumber(wave_number)
    local turn_wave = TURN_WAVES[selected_wave_number]
    if turn_wave then
        self.selected_wave = turn_wave
        self.selected_wave_number = selected_wave_number
        self.wave_select_turn_count = battle_turn
        self.wave_phase_turns_played = next_phase_turns_played or ((self.wave_phase_turns_played or 0) + 1)
        print("playing wave: " .. self.selected_wave)
        return self.selected_wave
    end

    return super.selectWave(self)
end

function Kris:onActStart(battler, name)
    if name == self.act_recharge
        and Game.battle
        and Game.battle.encounter
        and Game.battle.encounter.playRechargeActAnimation
    then
        Game.battle.encounter:playRechargeActAnimation(battler)
        return
    end

    return super.onActStart(self, battler, name)
end

function Kris:onAct(battler, name)
    if self:isMercyFinalePostlude() and name == self.act_mercy_finale_view then
        return { self.act_mercy_finale_view_text }
    elseif self:isMercyFinalePostlude() and name == self.act_mercy_finale_leave then
        local battle = Game.battle
        local encounter = battle and battle.encounter
        if encounter and encounter.requestMercyFinaleLeave then
            encounter:requestMercyFinaleLeave(battler)
        end
        return nil
    elseif name == self.act_check then
        return super.onAct(self, battler, "Check")
    elseif name == self.act_heartbeat then
        local already_boosted = self.heartbeat_speed_boosted
        local soul = Game.battle and Game.battle.soul
        if soul then
            if not already_boosted then
                self.heartbeat_original_soul_speed = soul.speed
            end
            soul.speed = HEARTBEAT_SOUL_SPEED
        end
        self.heartbeat_speed_boosted = true

        self.act_heartbeat_description = Game:loc(
            "Seems ineffective",
            "act_kris_heartbeat_repeat_description"
        )
        for _, act in ipairs(self.acts or {}) do
            if act.name == self.act_heartbeat then
                act.description = self.act_heartbeat_description
            end
        end

        local text = already_boosted
            and Game:loc("* Your heartbeat quickened.", "act_kris_heartbeat_repeat_text")
            or Game:loc(
                "* Your heartbeat quickened.\n" .. WAIT .. "* Your SOUL sped up.",
                "act_kris_heartbeat_text"
            )
        return {
            text
        }
    elseif name == self.act_recharge then
        self.recharge_ready_text_pending = false
        self.recharge_ready_text_shown = true

        local action = Game.battle:getCurrentAction()
        local pre_spend_tension = Game:getTension() - ((action and action.tp) or 0)
        if Game.battle.encounter and Game.battle.encounter.activateRecharge then
            Game.battle.encounter:activateRecharge(self, battler, pre_spend_tension)
            self:queueRechargeWavePhaseAdvance()
        end
        return Game:loc("* Your SOUL emitted a strange glow!", "act_kris_recharge_text")
    end

    return super.onAct(self, battler, name)
end

function Kris:getEncounterText()
    if self.recharge_ready_text_pending then
        self.recharge_ready_text_pending = false
        self.recharge_ready_text_shown = true
        return self.recharge_available_text
    end

    local turn = self:getEncounterTextWaveNumber()
    if self.text[turn] then
        return self.text[turn]
    end
    return self.text[#self.text]
end

function Kris:getSpareText(battler, success)
    local spare_text = Game:loc(
        "* [name:chara:vessel] spared [name:actor:kris]!",
        "enemy_kris_spare"
    )
    if success then
        return spare_text
    end

    return {
        spare_text,
        Game:loc("* But it seems ineffective...", "enemy_kris_spare_failed"),
    }
end

function Kris:onMercy(battler)
    if not self:canSpare() then
        return false
    end

    local encounter = Game.battle and Game.battle.encounter
    if encounter and encounter.tryStartMercyFinale
        and encounter:tryStartMercyFinale("mercy")
    then
        return true
    end

    self:spare()
    return true
end

function Kris:getAttackDamage(damage, battler, points)
    if self:isMercyFinalePostlude() then
        return 0
    end

    if battler and battler.chara.id == "vessel" then
        return points or 0
    end
    return super.getAttackDamage(self, damage, battler, points)
end

function Kris:preHurtVesselOnAttackStart(battler, points, action)
    if not battler or not battler.chara or battler.chara.id ~= "vessel" then
        return false
    end

    if action and action.krisis_vessel_attack_pre_hurt then
        return true
    end

    local vessel_damage = getVesselAttackResults(points)
    if not vessel_damage then
        return false
    end

    if action then
        action.krisis_vessel_attack_pre_hurt = true
    end
    battler:hurt(vessel_damage, true)
    return true
end

function Kris:hurt(amount, battler, on_defeat, color, show_status, attacked)
    if battler and battler.chara.id == "vessel" then
        local vessel_damage, mercy = getVesselAttackResults(amount)
        if vessel_damage then
            local old_mercy = self.mercy
            self:addMercy(mercy)

            if self.mercy > old_mercy
                and Game.battle
                and Game.battle.encounter
                and Game.battle.encounter.markKrisAttackMercyIncrease
            then
                Game.battle.encounter:markKrisAttackMercyIncrease(self)
            end

            local action = Game.battle and Game.battle.getCurrentAction and Game.battle:getCurrentAction()
            if not action or not action.krisis_vessel_attack_pre_hurt then
                battler:hurt(vessel_damage, true)
            end
            return
        end
    end
    super.hurt(self, amount, battler, on_defeat, color, show_status, attacked)
end

function Kris:clearHeartbeatSpeedBoost()
    local soul = Game.battle and Game.battle.soul
    if soul and self.heartbeat_original_soul_speed ~= nil then
        soul.speed = self.heartbeat_original_soul_speed
    end
    self.heartbeat_original_soul_speed = nil
    self.heartbeat_speed_boosted = false
end

function Kris:onTurnEnd()
    self:tryFinishQueuedWavePhaseAdvance()
    return super.onTurnEnd(self)
end

function Kris:onRemove(parent)
    self:clearHeartbeatSpeedBoost()
    super.onRemove(self, parent)
end

function Kris:update()
    self:updateRechargeActTPCost()

    if self.heartbeat_speed_boosted and Game.battle and Game.battle.soul then
        Game.battle.soul.speed = HEARTBEAT_SOUL_SPEED
    end

    super.update(self)
end

return Kris
