local TestStar, super = Class(Wave)

function TestStar:init()
    super.init(self)
    self.time = 5
end

function TestStar:onStart()
    local bx = SCREEN_WIDTH / 2
    local by = SCREEN_HEIGHT / 2
    local dir = math.pi / 2
    local star = self:spawnBullet("star", bx, by, dir, 0, 0, 0)
    star.wait_time = 0
    star.transition_time = 0
    star.alpha = 1
end

function TestStar:update()
    super.update(self)
end

return TestStar
