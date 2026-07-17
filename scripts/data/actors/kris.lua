local actor, super = Class(Actor, "kris")

local NORMAL_SPEED = 5 / 30
local FAST_SPEED = 4 / 30
local GRAB_SOUL_SPEED = 3 / 30

function actor:init()
    super.init(self)

    self.name = "KRIS"

    self.width = 108
    self.height = 60

    self.color = { 1, 0, 0 }

    self.path = "enemies/kris"
    self.default = "idle"

    self.animations = {
        ["idle"] = { "idle", NORMAL_SPEED, true },

        ["appear"] = { "appear", FAST_SPEED, false, next = "idle" },
        ["act"] = { "act", NORMAL_SPEED, false, next = "idle" },
        ["catch_sword"] = { "catch_sword", NORMAL_SPEED, false, next = "idle" },
        ["catch_sword_ready"] = { "catch_sword", NORMAL_SPEED, false, frames = { "1-4" } },
        ["catch_sword_finish"] = { "catch_sword", FAST_SPEED, false, frames = { "5-6" } },
        ["grab_soul"] = { "grab_soul", GRAB_SOUL_SPEED, false, next = "idle" },
        ["throw_soul"] = { "throw_soul", NORMAL_SPEED, false, next = "idle" },
        ["put_back"] = { "put_back", NORMAL_SPEED, false, next = "idle" },
        ["memory"] = { "memory", FAST_SPEED, false, next = "idle" },

        ["slash1"] = { "slash1", FAST_SPEED, false, next = "idle" },
        ["slash2"] = { "slash2", FAST_SPEED, false, next = "idle" },
        ["thrust_ready"] = { "thrust_ready", NORMAL_SPEED, false, next = "idle" },
        ["thrust"] = { "thrust", NORMAL_SPEED, false, next = "idle" },

        ["sword_hall_disappear"] = { "sword_hall_disappear", FAST_SPEED, false, next = "idle" },
        ["flying_sword_disappear"] = { "flying_sword_disappear", FAST_SPEED, false, next = "idle" },
        ["twist"] = { "twist", NORMAL_SPEED, false, next = "idle" },

        ["finisher_slide"] = { "finisher_slide", NORMAL_SPEED, false, next = "idle" },
        ["finisher_run"] = { "finisher_run", FAST_SPEED, true },

        ["angry_shake"] = { "angry_shake", NORMAL_SPEED, true },
        ["hurt"] = { "hurt", NORMAL_SPEED, true, temp = true, duration = 0.5 },
    }

    self.offsets = {}
end

return actor
