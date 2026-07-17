local game = Game

HookSystem.hook(game, "load", function(orig, self, ...)
    orig(self, ...)

    if not Kristal.Args.credits or not self.world or not CreditsScene then
        return
    end

    if self.world.menu then
        self.world:closeMenu()
    end
    self.world:addChild(CreditsScene())
end)

return game
