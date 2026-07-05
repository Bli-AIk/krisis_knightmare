local item, super = Class(HealItem, "rhapsotea")

function item:init()
    super.init(self)

    self.name = "RhapsoTea"
    self.use_name = nil

    self.type = "item"
    self.icon = nil

    self.effect = "Heals\n115HP"
    self.shop = "Rhapsody\ntea\n115HP"
    self.description = "A smooth, silvery tea.\nHeals 115 HP."

    self.heal_amount = 115

    self.price = 250
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
