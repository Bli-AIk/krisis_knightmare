local KrisPhase1_01, super = Class(Wave)

function KrisPhase1_01:init()
    super.init(self)
    self.time = 5
end

function KrisPhase1_01:onStart()
end

function KrisPhase1_01:update()
    super.update(self)
end

return KrisPhase1_01
