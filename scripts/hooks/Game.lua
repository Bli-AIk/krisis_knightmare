local Game, super = HookSystem.hookScript(Game)

function Game:gameOver(x, y)
    if Mod and Mod.recordKrisisGameOver then
        Mod:recordKrisisGameOver()
    end
    return super.gameOver(self, x, y)
end

return Game
