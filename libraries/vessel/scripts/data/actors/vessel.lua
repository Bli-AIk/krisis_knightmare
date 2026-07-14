local actor, super = Class(Actor, "vessel")

function actor:init()
    super.init(self)

    self.name = "Vessel"

    self.width = 19
    self.height = 37

    self.hitbox = {0, 25, 19, 14}

    self.soul_offset = {10, 24}

    self.color = {0, 1, 1}

    self.path = "party/vessel/dark"
    self.default = "walk"

    self.voice = nil
    self.portrait_path = nil
    self.portrait_offset = nil

    self.can_blush = false

    self.animations = {
        ["slide"]               = {"slide", 4/30, true},

        ["battle/idle"]         = {"battle/idle", 1/6, true},

        ["battle/attack"]       = {"battle/attack", 1/15, false},
        ["battle/act"]          = {"battle/act", 1/15, false},
        ["battle/spell"]        = {"battle/act", 1/15, false},
        ["battle/item"]         = {"battle/item", 1/12, false, next="battle/idle"},
        ["battle/spare"]        = {"battle/act", 1/15, false, next="battle/idle"},

        ["battle/attack_ready"] = {"battle/attackready", 0.2, true},
        ["battle/act_ready"]    = {"battle/actready", 0.2, true},
        ["battle/spell_ready"]  = {"battle/actready", 0.2, true},
        ["battle/item_ready"]   = {"battle/itemready", 0.2, true},
        ["battle/defend_ready"] = {"battle/defend", 1/15, false},

        ["battle/act_end"]      = {"battle/actend", 1/15, false, next="battle/idle"},

        ["battle/hurt"]         = {"battle/hurt", 1/15, false, temp=true, duration=0.5},
        ["battle/defeat"]       = {"battle/defeat", 1/15, false},
        ["battle/swooned"]      = {"battle/defeat", 1/15, false},

        ["battle/transition"]   = {"sword_jump_down", 0.2, true},
        ["battle/intro"]        = {"battle/attack", 1/15, false},
        ["battle/victory"]      = {"battle/victory", 1/10, false},
        ["battle/transition_out"] = {"battle/transition_out", 1/15, false},

        ["jump_fall"]           = {"fall", 1/5, true},
        ["jump_ball"]           = {"ball", 1/15, true},
        ["jump_ball_slow"]      = {"ball", 4/30, true},
    }

    self.mirror_sprites = {
        ["walk/down"] = "walk/up",
        ["walk/up"] = "walk/down",
        ["walk/left"] = "walk/left",
        ["walk/right"] = "walk/right",
    }

    self.offsets = {
        ["walk/left"] = {0, 0},
        ["walk/right"] = {0, 0},
        ["walk/up"] = {0, 0},
        ["walk/down"] = {0, 0},

        ["walk_blush/down"] = {0, 0},

        ["slide"] = {0, 0},

        ["battle/idle"] = {0, -1},

        ["battle/attack"] = {-9, -3},
        ["battle/attackready"] = {-5, -5},
        ["battle/act"] = {-6, -1},
        ["battle/actend"] = {-6, -1},
        ["battle/actready"] = {-6, -1},
        ["battle/item"] = {0, -5},
        ["battle/itemready"] = {-1, -1},
        ["battle/itemend"] = {0, -1},
        ["battle/defend"] = {-18, -1},

        ["battle/defeat"] = {2, -3},
        ["battle/hurt"] = {2, 1},

        ["battle/intro"] = {-6, -11},
        ["battle/victory"] = {-5, -2},
        ["battle/transition_out"] = {-4, 1},

        ["climb/climbing"] = {-5, -15},
        ["climb/fall"] = {-3, -14},
        ["climb/charge"] = {-4, -12},
        ["climb/charge_right"] = {-4, -12},
        ["climb/charge_left"] = {-4, -12},
        ["climb/slip_right"] = {-3, -13},
        ["climb/slip_left"] = {-2, -13},
        ["climb/jump_up"] = {-4, -13},
        ["climb/land_right"] = {-4, -13},
        ["climb/land_left"] = {-4, -13},

        ["pose"] = {-4, -2},

        ["fall"] = {-5, -6},
        ["ball"] = {1, 8},
        ["landed"] = {-4, -2},

        ["fell"] = {-14, 1},

        ["sword_jump_down"] = {-19, -5},
        ["sword_jump_settle"] = {-27, 4},
        ["sword_jump_up"] = {-17, 2},

        ["hug_left"] = {-4, -1},
        ["hug_right"] = {-2, -1},

        ["peace"] = {0, 0},
        ["rude_gesture"] = {0, 0},

        ["reach"] = {-3, -1},

        ["sit"] = {-3, 0},

        ["t_pose"] = {-4, 0},
    }
end

return actor
