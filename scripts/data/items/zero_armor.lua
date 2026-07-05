local item, super = Class(Item, "zero_armor")

function item:init()
    super.init(self)

    self.name = "Zero Armor"

    self.type = "armor"
    self.icon = "ui/menu/icon/armor"

    self.effect = ""
    self.shop = "No\nbonus"
    self.description = "Armor with no defensive effect."

    self.price = 0
    self.can_sell = false

    self.target = "none"
    self.usable_in = "all"
    self.result_item = nil
    self.instant = false

    self.bonuses = {
        defense = 0,
    }

    self.bonus_name = nil
    self.bonus_icon = nil

    self.can_equip = {}
end

return item
