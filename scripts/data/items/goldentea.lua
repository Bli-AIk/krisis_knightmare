local item, super = Class(HealItem, "goldentea")

function item:init()
    super.init(self)

    self.name = "GoldenTea"
    self.use_name = nil

    self.type = "item"
    self.icon = nil

    self.effect = "Heals\n150HP"
    self.shop = "Bright tea\nheals\n150HP"
    self.description = "A golden flower tea.\nHeals 150 HP."

    self.heal_amount = 150

    self.price = 300
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
