local Sprite, super = HookSystem.hookScript(Sprite)

local VESSEL_ATTACK_SPRITE = "battle/attack/spr_quiz_lightning_big"
local VESSEL_ATTACK_ORIGIN_UP = 48 - 13 - 1
local VESSEL_ATTACK_SCALE = 0.5
local VESSEL_ATTACK_SOUND = "vessel_thunder"
local VESSEL_ATTACK_SOUND_FRAME = 2

local function getVesselAttackFrames()
    local frames = {}
    local index = 0

    while true do
        local texture = Assets.getTexture(VESSEL_ATTACK_SPRITE .. "_" .. index)
        if not texture then
            break
        end

        table.insert(frames, texture)
        index = index + 1
    end

    return #frames > 0 and frames or nil
end

local function applyVesselAttackOrigin(sprite)
    if not sprite.krisis_vessel_attack_origin then
        return
    end

    sprite.origin_x = sprite.width / 2- 10
    sprite.origin_y = sprite.height - VESSEL_ATTACK_ORIGIN_UP
    sprite.origin_exact = true
end

local function isVesselAttackDamageSprite(sprite)
    if not sprite.krisis_vessel_attack_origin or not sprite.battler_id then
        return false
    end

    local battler = Game.battle and Game.battle.party and Game.battle.party[sprite.battler_id]
    return battler and battler.chara and battler.chara.id == "vessel"
end

local function playVesselAttackSoundOnFrame(sprite)
    if sprite.frame ~= VESSEL_ATTACK_SOUND_FRAME
        or sprite.krisis_vessel_attack_sound_played
        or not isVesselAttackDamageSprite(sprite)
    then
        return
    end

    sprite.krisis_vessel_attack_sound_played = true
    Assets.stopAndPlaySound(VESSEL_ATTACK_SOUND)
end

function Sprite:setSprite(texture, keep_anim)
    if type(texture) == "string" then
        self.krisis_vessel_attack_origin = self:getPath(texture) == VESSEL_ATTACK_SPRITE
    else
        self.krisis_vessel_attack_origin = false
    end
    self.krisis_vessel_attack_sound_played = false

    super.setSprite(self, texture, keep_anim)
    applyVesselAttackOrigin(self)
end

function Sprite:setFrame(frame)
    super.setFrame(self, frame)
    playVesselAttackSoundOnFrame(self)
end

function Sprite:setFrames(frames, keep_anim)
    super.setFrames(self, frames, keep_anim)

    if self.krisis_vessel_attack_origin then
        local vessel_frames = getVesselAttackFrames()
        if vessel_frames then
            self.frames = vessel_frames
            self:setFrame(keep_anim and self.frame or 1)
        end
    end

    applyVesselAttackOrigin(self)
end

function Sprite:setTextureExact(texture)
    super.setTextureExact(self, texture)
    applyVesselAttackOrigin(self)
end

function Sprite:setOrigin(x, y)
    super.setOrigin(self, x, y)
    applyVesselAttackOrigin(self)
end

function Sprite:setScale(x, y)
    if self.krisis_vessel_attack_origin then
        local scale_x = x or 1
        local scale_y = y or x or 1

        super.setScale(self, scale_x * VESSEL_ATTACK_SCALE, scale_y * VESSEL_ATTACK_SCALE)
        return
    end

    super.setScale(self, x, y)
end

return Sprite
