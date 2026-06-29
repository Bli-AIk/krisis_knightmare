local actor, super = Class(Actor, "vessel_dark_transition")

function actor:init()
    super.init(self)

    self.name = "Vessel"

    self.width = 19
    self.height = 37

    self.path = "party/vessel/dark_transition"
    self.default = "run"
end

return actor
