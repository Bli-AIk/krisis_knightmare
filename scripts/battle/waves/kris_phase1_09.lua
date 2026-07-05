local KrisPhase1_09, super = Class("kris_phase1_02")

function KrisPhase1_09:init()
    super.init(self)
    self.time = self.time - 3
end

function KrisPhase1_09:getSlashInterval()
    return 25 / 60
end

function KrisPhase1_09:getKrisSlashAnimationFrameDelay()
    return 3 / 30
end

return KrisPhase1_09
