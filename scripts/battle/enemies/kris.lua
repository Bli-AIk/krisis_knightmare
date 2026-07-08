local Kris, super = Class(EnemyBattler)

local WAIT = "[wait:5]"
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
    [6] = true,
    [11] = true,
}
local FORCED_TURN = nil

local function makeWaveList(first, last)
    local waves = {}
    for i = first, last do
        table.insert(waves, TURN_WAVES[i])
    end
    return waves
end

local function randomWaveNumber(first, last)
    if love and love.math and love.math.random then
        return love.math.random(first, last)
    end
    return math.random(first, last)
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

    -- Mercy given when sparing this enemy before its spareable (20% for basic enemies)
    self.spare_points = 20

    -- Used by the base battle code/debug paths; selectWave controls the actual order.
    self.waves = makeWaveList(1, 15)
    self.wave_phase = 1
    self.wave_phase_turns_played = 0
    self.wave_select_turn_count = nil
    self.selected_wave_number = nil
    self.recharge_wave_phase_advance_pending = false

    self.dialogue = {}

    self:applyLocalization()
    self.recharge_act = self:registerAct(
        self.act_recharge,
        self.act_recharge_description,
        { "vessel" },
        RECHARGE_MIN_TENSION
    )
    self:registerAct(self.act_heartbeat, self.act_heartbeat_description, { "vessel" })

    self.heartbeat_bonuses = {}
    self.heartbeat_stacks = 0
    self.heartbeat_active = false
end

function Kris:applyLocalization(update_acts)
    local old_check = self.act_check
    local old_recharge = self.act_recharge
    local old_heartbeat = self.act_heartbeat

    self.name = Game:locName("actor", "kris", "KRIS")

    -- Check text (automatically has "ENEMY NAME - " at the start)
    self.check = {
        Game:loc("?? ATK ??? DEF", "enemy_kris_check_1"),
        Game:loc("Darkness grants them regeneration." .. WAIT .. "\n* Transformed into a monster\nof pure aggressive instinct.", "enemy_kris_check_2"),
        Game:loc("Use your power to defeat them.", "enemy_kris_check_3"),
    }

    self.text = {
        Game:loc("* [name:chara:kris] slashes into the combat.", "enemy_kris_turn_1"),
        Game:loc("* The darkness froze on the blade.", "enemy_kris_turn_2"),
        Game:loc("* Suddenly, the earth was torn apart by swords.", "enemy_kris_turn_3"),
        Game:loc("* Your soul is full of the POWER OF LIGHT.", "enemy_kris_turn_4"),
        Game:loc("* Darkness emerges from the crack, surging towards the sky.", "enemy_kris_turn_5"),
        Game:loc("* Suddenly, your body seized up.", "enemy_kris_turn_6"),
        Game:loc("* The thick fog gathered, then formed its shape.", "enemy_kris_turn_7"),
        Game:loc("* Countless swords make you dizzy.", "enemy_kris_turn_8"),
        Game:loc("* Your soul is full of POWER.", "enemy_kris_turn_9"),
    }
    self.low_health_text = nil

    self.act_check = Game:loc("Check", "act_check")
    self.act_check_description = Game:loc("Consider\nstrategy", "act_kris_check_description")
    self.act_recharge = Game:loc("Recharge", "act_kris_recharge")
    self.act_recharge_description = Game:loc("SHINE", "act_kris_recharge_description")
    self.act_heartbeat = Game:loc("Heartbeat", "act_kris_heartbeat")
    self.act_heartbeat_description = Game:loc("Raise\nDefend", "act_kris_heartbeat_description")

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

function Kris:getRechargeActTPCost()
    local tension = Game and Game.getTension and Game:getTension() or 0
    if tension >= RECHARGE_MIN_TENSION then
        return tension
    end

    return RECHARGE_MIN_TENSION
end

function Kris:updateRechargeActTPCost()
    if self.recharge_act then
        self.recharge_act.tp = self:getRechargeActTPCost()
        self.recharge_act.unusable = Game.battle
            and Game.battle.encounter
            and Game.battle.encounter.isRechargeActive
            and Game.battle.encounter:isRechargeActive()
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
    if FORCED_TURN then
        return FORCED_TURN
    end

    local battle_turn = Game.battle and Game.battle.turn_count
    if self.wave_select_turn_count == battle_turn and self.selected_wave_number then
        return self.selected_wave_number
    end

    local phase = self:getCurrentWavePhase()
    local played = self.wave_phase_turns_played or 0
    if played < self:getPhaseSequenceLength(phase) then
        local wave_number = self:getNextPhaseWaveNumber()
        return wave_number
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
    if FORCED_TURN then
        local forced_wave = TURN_WAVES[FORCED_TURN]
        if forced_wave then
            self.selected_wave = forced_wave
            self.selected_wave_number = FORCED_TURN
            print("playing wave: " .. self.selected_wave)
            return self.selected_wave
        end
    end

    local battle_turn = Game.battle and Game.battle.turn_count
    if self.wave_select_turn_count == battle_turn and self.selected_wave then
        return self.selected_wave
    end

    local wave_number, next_phase_turns_played = self:getNextPhaseWaveNumber()
    local turn_wave = TURN_WAVES[wave_number]
    if turn_wave then
        self.selected_wave = turn_wave
        self.selected_wave_number = wave_number
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
    if name == self.act_check then
        return super.onAct(self, battler, "Check")
    elseif name == self.act_heartbeat then
        local vessel = nil
        for _, pb in ipairs(Game.battle.party) do
            if pb.chara.id == "vessel" then
                vessel = pb
                break
            end
        end
        if vessel then
            vessel.chara.stats.defense = vessel.chara.stats.defense + 5
            self.heartbeat_bonuses[vessel.chara] = (self.heartbeat_bonuses[vessel.chara] or 0) + 5
            self.heartbeat_stacks = self.heartbeat_stacks + 1
            self.heartbeat_active = true
        end
        return {
            Game:loc("* Your heartbeat quickened.\n" .. WAIT ..
            "* Your DEF raised.\n" .. WAIT ..
            "* Your Invincible shorter.", "act_kris_heartbeat_text")
        }
    elseif name == self.act_recharge then
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
    local turn = self:getEncounterTextWaveNumber()
    if self.text[turn] then
        return self.text[turn]
    end
    return self.text[#self.text]
end

function Kris:getAttackDamage(damage, battler, points)
    if battler and battler.chara.id == "vessel" then
        return points or 0
    end
    return super.getAttackDamage(self, damage, battler, points)
end

function Kris:hurt(amount, battler, on_defeat, color, show_status, attacked)
    if battler and battler.chara.id == "vessel" then
        local points = amount
        if points > 0 then
            local t = (points - 100) / 50
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
            local vessel_damage = math.floor(40 - 20 * t + 0.5)
            local mercy = math.floor(4 + 4 * t + 0.5)
            self:addMercy(mercy)
            battler:hurt(vessel_damage, true)
            return
        end
    end
    super.hurt(self, amount, battler, on_defeat, color, show_status, attacked)
end

function Kris:clearHeartbeatBonuses()
    for chara, defense in pairs(self.heartbeat_bonuses or {}) do
        chara.stats.defense = chara.stats.defense - defense
    end
    self.heartbeat_bonuses = {}
    self.heartbeat_stacks = 0
    self.heartbeat_active = false
end

function Kris:getHeartbeatInvTimerCap()
    return math.max(1 / 60, (5 - self.heartbeat_stacks) / 60)
end

function Kris:onTurnEnd()
    self:tryFinishQueuedWavePhaseAdvance()
    return super.onTurnEnd(self)
end

function Kris:onRemove(parent)
    self:clearHeartbeatBonuses()
    super.onRemove(self, parent)
end

function Kris:update()
    self:updateRechargeActTPCost()

    if self.heartbeat_active then
        local inv_timer_cap = self:getHeartbeatInvTimerCap()
        if Game.battle.soul and Game.battle.soul.inv_timer > inv_timer_cap then
            Game.battle.soul.inv_timer = inv_timer_cap
        end
    end
    super.update(self)
end

return Kris
