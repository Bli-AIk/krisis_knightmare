local item, super = Class(HealItem, "tvslop")

function item:init()
    super.init(self)

    self.name = "TVSlop"
    self.use_name = nil

    self.type = "item"
    self.icon = nil

    self.effect = "Heals\n80HP"
    self.shop = "TV food\nheals\n80HP"
    self.description = "Some sort of bland cafeteria food.\nHeals 80 HP."

    self.heal_amount = 80

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

return item
