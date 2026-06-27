local KrisPhase1_1, super = Class(Wave)

function KrisPhase1_1:init()
    super.init(self)
    self.time = 5
end

function KrisPhase1_1:onStart()
end

function KrisPhase1_1:update()
    super.update(self)
end

return KrisPhase1_1
