local item, super = Class(HealItem, "emerfood")

local HEAL_PERCENT = 0.8

local function getPercentHealAmount(chara)
    return math.ceil(chara:getStat("health") * HEAL_PERCENT)
end

function item:init()
    super.init(self)

    self.name = "Emerfood"
    self.use_name = nil

    self.type = "item"
    self.icon = nil

    self.effect = "Heals\n80%HP"
    self.shop = "Emergency\nfood\n80%HP"
    self.description = "Emergency food.\nHeals 80% of max HP."

    self.heal_amount = 0

    self.price = 200
    self.can_sell = true

    self.target = "ally"
    self.usable_in = "all"
    self.result_item = nil
    self.instant = false

    self.bonuses = {}
    self.bonus_name = nil
    self.bonus_icon = nil
    self.can_equip = {}

    self.reactions = {}
end

function item:onWorldUse(target)
    Game.world:heal(target, getPercentHealAmount(target))
    return true
end

function item:onBattleUse(user, target)
    local amount = getPercentHealAmount(target.chara)
    target:heal(Game.battle:applyHealBonuses(amount, user.chara))
end

return item
