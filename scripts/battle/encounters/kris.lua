local Kris, super = Class(Encounter)

function Kris:init()
    super.init(self)

    self.text = "* KRIS slashes into the combat."
    self.music = "never_forgetting"
    self.background = false
    self.hide_world = true

    self:addEnemy("kris")
end

function Kris:setupBackground(battle)
    self.bg_platform = Sprite("battle/backgrounds/kris_platform", 0, 0)
    self.bg_platform.layer = BATTLE_LAYERS["bottom"]
    self.bg_platform:setScale(2, 2)
    battle:addChild(self.bg_platform)

    self.vignette = KrisVignette()
    self.vignette.layer = BATTLE_LAYERS["bottom"] + 1
    battle:addChild(self.vignette)
end

return Kris
