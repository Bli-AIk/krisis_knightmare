local item, super = Class(HealItem, "holieggnog")

function item:init()
    super.init(self)

    self.name = "HoliEggnog"
    self.use_name = nil

    self.type = "item"
    self.icon = nil

    self.effect = "Heals\n180HP"
    self.shop = "Holiday\nnog\n180HP"
    self.description = "A cup of holiday eggnog.\nHeals 180 HP."

    self.heal_amount = 180

    self.price = 360
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

return item
