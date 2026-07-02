local Kris, super = Class(Encounter)

function Kris:init()
    super.init(self)

    self:applyLocalization()
    self.music = "never_forgetting"
    self.background = false
    self.hide_world = true

    self:addEnemy("kris", 507, 239)
end

function Kris:applyLocalization()
    self.text = Game:loc("* KRIS slashes into the combat.", "enemy_kris_turn_1")
end

function Kris:setupBackground(battle)
    self.bg_platform = Sprite("battle/backgrounds/kris_platform_adjusted", 0, 0)
    self.bg_platform.layer = BATTLE_LAYERS["bottom"]
    self.bg_platform:setScale(2, 2)
    battle:addChild(self.bg_platform)

    self.bg_depth = KrisDepthBackground()
    self.bg_depth.layer = BATTLE_LAYERS["bottom"] + 0.5
    battle:addChild(self.bg_depth)

    self.vignette = KrisVignette()
    self.vignette.layer = BATTLE_LAYERS["bottom"] + 1
    battle:addChild(self.vignette)
end

return Kris
