local KrisPhase1_2, super = Class(Wave)

function KrisPhase1_2:init()
    super.init(self)
    self.time = 5
end

function KrisPhase1_2:onStart()
end

function KrisPhase1_2:update()
    super.update(self)
end

return KrisPhase1_2
