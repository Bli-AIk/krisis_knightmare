local Kris, super = Class(EnemyBattler)

local WAIT = "[wait:5]"

function Kris:init()
    super.init(self)

    self.name = "KRIS"
    -- Sets the actor, which handles the enemy's sprites (see scripts/data/actors/dummy.lua)
    self:setActor("dummy")

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

    -- List of possible wave ids, randomly picked each turn
    self.waves = {
        "kris_phase1_1",
        "kris_phase1_2",
        "kris_phase1_3",
        "kris_phase1_4",
        "kris_phase1_5",
    }

    self.dialogue = {}

    -- Check text (automatically has "ENEMY NAME - " at the start)
    self.check = {
        "?? ATK ??? DEF",
        "Darkness grants them regeneration." .. WAIT .. "\n* Transformed into a monster\nof pure aggressive instinct.",
        "Use your power to defeat them.",
    }

    self.text = {}
    self.low_health_text = nil

    self.acts[1].description = "Consider\nstrategy"
    self:registerAct("Recharge", "SHINE", { "vessel" }, 100)
    self:registerAct("Heartbeat", "Raise\nDefend", { "vessel" })

    self.heartbeat_turn = 0
    self.heartbeat_battler = nil
end

function Kris:selectWave()
    local turn = Game.battle.turn_count

    ---[[ 临时强制设置
    do return "kris_phase1_" .. 1 end
    --]]

    if turn <= 5 then
        self.selected_wave = "kris_phase1_" .. turn
        return self.selected_wave
    end

    return super.selectWave(self)
end

function Kris:onAct(battler, name)
    if name == "Heartbeat" then
        local vessel = nil
        for _, pb in ipairs(Game.battle.party) do
            if pb.chara.id == "vessel" then
                vessel = pb
                break
            end
        end
        if vessel then
            vessel.chara.stats.defense = vessel.chara.stats.defense + 5
            self.heartbeat_battler = vessel
            self.heartbeat_turn = Game.battle.turn_count
        end
        return {
            "* Your heartbeat quickened.\n" .. WAIT ..
            "* Your DEF raised.\n" .. WAIT ..
            "* Your Invincible shorter."
        }
    elseif name == "Recharge" then
        return "* Your SOUL emitted a strange glow!"
    end

    return super.onAct(self, battler, name)
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

function Kris:update()
    if self.heartbeat_turn > 0 then
        if Game.battle.soul and Game.battle.soul.inv_timer > 4 / 60 then
            Game.battle.soul.inv_timer = 4 / 60
        end
        if Game.battle.turn_count > self.heartbeat_turn then
            if self.heartbeat_battler then
                self.heartbeat_battler.chara.stats.defense = self.heartbeat_battler.chara.stats.defense - 5
                self.heartbeat_battler = nil
            end
            self.heartbeat_turn = 0
        end
    end
    super.update(self)
end

return Kris
