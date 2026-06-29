local character, super = Class(PartyMember, "vessel")

function character:init()
    super.init(self)

    self.name = "Vessel"

    self:setActor("vessel")
    self:setLightActor("vessel_lw")
    self:setDarkTransitionActor("vessel_dark_transition")

    self.level = 1
    self.title = "Dark Hero\nCarries out fate\nwith the blade."

    self.soul_priority = 2
    self.soul_color = { 1, 0, 0 }

    self.has_act = true
    self.has_spells = false

    self.has_xact = true
    self.xact_name = "V-Action"

    self.health = 300

    self.stats = {
        health = 300,
        attack = 17,
        defense = 2,
        magic = 0
    }

    self.max_stats = {
        health = 300,
        attack = 19
    }

    self.stronger_absent = { "vessel", "susie", "ralsei" }

    self.weapon_icon = "ui/menu/equip/sword"

    self:setWeapon("wood_blade")

    self.lw_weapon_default = "light/pencil"
    self.lw_armor_default = "light/bandage"

    self.color = { 0.5, 0.5, 0.5 }
    self.dmg_color = { 0.25, 0.25, 0.25 }
    self.attack_bar_color = { 0, 162 / 255, 232 / 255 }
    self.attack_box_color = { 0, 0, 1 }
    self.xact_color = { 0.5, 1, 1 }

    self.menu_icon = "party/vessel/head"
    self.head_icons = "party/vessel/icon"
    self.name_sprite = "party/vessel/name"

    self.attack_sprite = "effects/attack/cut"
    self.attack_sound = "laz_c"
    self.attack_pitch = 1

    self.battle_offset = { 2, 1 }
    self.head_icon_offset = nil
    self.menu_icon_offset = nil

    self.gameover_message = nil
end

function character:onLevelUp(level)
    self:increaseStat("health", 2)
    if level % 10 == 0 then
        self:increaseStat("attack", 1)
    end
end

function character:drawPowerStat(index, x, y, menu)
    if index == 3 then
        local icon = Assets.getTexture("ui/menu/icon/fire")
        Draw.draw(icon, x - 26, y + 6, 0, 2, 2)
        love.graphics.print("Guts:", x, y)
        Draw.draw(icon, x + 90, y + 6, 0, 2, 2)
        return true
    end
end

return character
