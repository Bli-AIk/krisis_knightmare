local actor, super = Class(Actor, "kris")

local ANIMATION_SPEED = 5 / 30

function actor:init()
    super.init(self)

    self.name = "KRIS"

    self.width = 108
    self.height = 60

    self.color = { 1, 0, 0 }

    self.path = "enemies/kris"
    self.default = "idle"

    self.animations = {
        ["idle"] = { "idle", ANIMATION_SPEED, true },

        ["appear"] = { "appear", ANIMATION_SPEED, false, next = "idle" },
        ["act"] = { "act", ANIMATION_SPEED, false, next = "idle" },
        ["catch_sword"] = { "catch_sword", ANIMATION_SPEED, false, next = "idle" },
        ["grab_soul"] = { "grab_soul", ANIMATION_SPEED, false, next = "idle" },
        ["throw_soul"] = { "throw_soul", ANIMATION_SPEED, false, next = "idle" },
        ["put_back"] = { "put_back", ANIMATION_SPEED, false, next = "idle" },

        ["slash1"] = { "slash1", ANIMATION_SPEED, false, next = "idle" },
        ["slash2"] = { "slash2", ANIMATION_SPEED, false, next = "idle" },
        ["thrust_ready"] = { "thrust_ready", ANIMATION_SPEED, false, next = "idle" },
        ["thrust"] = { "thrust", ANIMATION_SPEED, false, next = "idle" },

        ["sword_hall_disappear"] = { "sword_hall_disappear", ANIMATION_SPEED, false, next = "idle" },
        ["flying_sword_disappear"] = { "flying_sword_disappear", ANIMATION_SPEED, false, next = "idle" },
        ["twist"] = { "twist", ANIMATION_SPEED, false, next = "idle" },

        ["phase2_slide"] = { "phase2_slide", ANIMATION_SPEED, false, next = "idle" },
        ["phase2_run"] = { "phase2_run", ANIMATION_SPEED, true },

        ["angry_shake"] = { "angry_shake", ANIMATION_SPEED, true },
        ["hurt"] = { "hurt", ANIMATION_SPEED, true, temp = true, duration = 0.5 },
    }

    self.offsets = {}
end

return actor
