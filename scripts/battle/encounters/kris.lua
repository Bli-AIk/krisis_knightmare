local Kris, super = Class(Encounter)

function Kris:init()
    super.init(self)

    self.text = "* KRIS slashes into the combat."

    self.music = "never_forgetting"
    self.background = true

    self:addEnemy("kris")
end

return Kris
