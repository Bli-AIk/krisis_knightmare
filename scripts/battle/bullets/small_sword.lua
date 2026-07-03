---@class SmallSword : Bullet
local SmallSword, super = Class(Bullet)

local FIRE_ALPHA_DURATION = 0.12
local FIRE_AIM_DURATION = 0.5
local FIRE_COLOR_DURATION = 0.6

local function easeOutCubic(t)
	local inv = 1 - t
	return 1 - inv * inv * inv
end

local function easeInQuart(t)
	return t * t * t * t
end

local function lerp(from, to, t)
	return from + (to - from) * t
end

---@param x number # The X position of the bullet
---@param y number # The Y position of the bullet
---@param dir number # Final direction (perpendicular to slash line)
---@param min_speed number # Starting speed (pixels per frame at 30FPS)
---@param max_speed number # Peak speed after acceleration completes
---@param accel_duration number # How many seconds to go from min_speed to max_speed
---@param options table? # Optional behavior flags
function SmallSword:init(x, y, dir, min_speed, max_speed, accel_duration, options)
	super.init(self, x, y, "bullets/small_sword")

	options = options or {}

	self:setScale(0.8, 0.8)
	self.damage = 75
	self.destroy_on_hit = false
	self.alpha = 0

	self.min_speed = min_speed
	self.max_speed = max_speed
	self.accel_duration = accel_duration
	self.elapsed = 0

	-- 初始朝向沿线，最终朝向垂直线
	self.initial_dir = dir + math.pi / 2
	self.final_dir = dir
	self.physics.direction = self.initial_dir
	self.physics.speed = 0

	self.wait_time = 5 / 30
	self.transition_time = 15 / 30
	self.fire_on_left_edge = options.fire_on_left_edge == true
	self.fire_left_x = options.fire_left_x or -self.width
	self.fire_speed = options.fire_speed or self.max_speed
	self.fire_accel_duration = options.fire_accel_duration or 0.2
	if self.fire_on_left_edge then
		self.remove_offscreen = false
	end

	-- 纯白半透明虚影 sprite（ColorMaskFX: 非透明像素全部渲染为纯白）
	self.ghost = Sprite("bullets/small_sword", 0, 0)
	self.ghost:addFX(ColorMaskFX())
	self.ghost:setColor(1, 1, 1, 0.19)
	self.ghost.layer = -0.001
	self:addChild(self.ghost)
end

function SmallSword:onWaveSpawn(wave)
	super.onWaveSpawn(self, wave)

	local ghost_ref = self.ghost
	wave.timer:every(1 / 15, function()
		if not ghost_ref or ghost_ref:isRemoved() then
			return false
		end
		local img = AfterImage(ghost_ref, 0.4, 0.1)
		img:addFX(ColorMaskFX())
		ghost_ref:addChild(img)
	end)
end

function SmallSword:getTargetDirection()
	local target = Game.battle and Game.battle.soul
	if target then
		return MathUtils.angle(self.x, self.y, target.x, target.y)
	end
	return self.physics.direction or self.final_dir or 0
end

function SmallSword:getRotationForDirection(direction)
	return direction + math.pi / 2
end

function SmallSword:hasReachedFireLeftEdge()
	local x = self:getScreenPos()
	return x <= self.fire_left_x
end

function SmallSword:fire()
	if self.fire_state then
		return false
	end

	local _, screen_y = self:getScreenPos()
	if self.fire_left_x then
		self:setScreenPos(self.fire_left_x, screen_y)
	end

	local target_direction = self:getTargetDirection()
	local start_rotation = self.rotation or self:getRotationForDirection(self.physics.direction or self.final_dir or 0)
	local rotation_distance = MathUtils.angleDiff(self:getRotationForDirection(target_direction), start_rotation)

	self.fire_state = "aiming"
	self.fire_elapsed = 0
	self.fire_alpha_start = self.alpha
	self.fire_rotation_start = start_rotation
	self.fire_rotation_distance = rotation_distance
	self.fire_target_rotation = start_rotation + rotation_distance
	self.fire_target_direction = target_direction
	self.physics.speed = 0
	self.remove_offscreen = false

	if self.ghost then
		self.ghost:setColor(1, 0, 0, 0.28)
	end

	return true
end

SmallSword["发射"] = SmallSword.fire

function SmallSword:updateDefaultMovement()
	local lt = self.wait_time + self.transition_time

	if self.elapsed < self.wait_time then
		-- 阶段1：隐身，沿线方向，匀速
		-- already set
	elseif self.elapsed < lt then
		-- 阶段2：alpha 0→1，朝向沿线→垂直线（out-ease）
		local raw = (self.elapsed - self.wait_time) / self.transition_time
		local t = 1 - (1 - raw) * (1 - raw) * (1 - raw)
		self.alpha = t
		self.physics.direction = self.initial_dir + (self.final_dir - self.initial_dir) * t
	else
		-- 阶段3：垂直线方向，ease-in 加速
		self.alpha = 1
		self.physics.direction = self.final_dir
		local t = self.accel_duration > 0 and math.min((self.elapsed - lt) / self.accel_duration, 1.0) or 1.0
		self.physics.speed = self.min_speed + (self.max_speed - self.min_speed) * t * t * t
	end
end

function SmallSword:updateFire()
	self.fire_elapsed = self.fire_elapsed + DT

	local alpha_t = math.min(self.fire_elapsed / FIRE_ALPHA_DURATION, 1)
	self.alpha = lerp(self.fire_alpha_start or self.alpha, 1, alpha_t)

	local aim_t = easeOutCubic(math.min(self.fire_elapsed / FIRE_AIM_DURATION, 1))
	self.rotation = self.fire_rotation_start + self.fire_rotation_distance * aim_t

	local color_t = math.min(self.fire_elapsed / FIRE_COLOR_DURATION, 1)
	self.color = { 1, 1 - color_t, 1 - color_t }
	if self.ghost then
		self.ghost:setColor(1, 1 - color_t, 1 - color_t, 0.28)
	end

	self.physics.speed = 0

	if self.fire_elapsed >= FIRE_COLOR_DURATION then
		self.fire_state = "launched"
		self.fire_elapsed = 0
		self.rotation = self.fire_target_rotation
		self.physics.direction = self.fire_target_direction
	end
end

function SmallSword:updateLaunch()
	self.fire_elapsed = self.fire_elapsed + DT
	local t = self.fire_accel_duration > 0 and math.min(self.fire_elapsed / self.fire_accel_duration, 1) or 1

	self.alpha = 1
	self.color = { 1, 0, 0 }
	if self.ghost then
		self.ghost:setColor(1, 0, 0, 0.28)
	end
	self.rotation = self.fire_target_rotation
	self.physics.direction = self.fire_target_direction
	self.physics.speed = self.fire_speed * easeInQuart(t)
end

function SmallSword:isFireOffscreen()
	local size = self.width + self.height + 64
	local x, y = self:getScreenPos()
	return x < -size or y < -size or x > SCREEN_WIDTH + size or y > SCREEN_HEIGHT + size
end

function SmallSword:update()
	self.elapsed = self.elapsed + DT

	if self.fire_state == "aiming" then
		self:updateFire()
	elseif self.fire_state == "launched" then
		self:updateLaunch()
	else
		self:updateDefaultMovement()
	end

	super.update(self)

	if self.fire_state == "launched" and self:isFireOffscreen() then
		self:remove()
		return
	end

	-- 贴图剑尖朝上，+π/2 指向飞行方向
	if not self.fire_state then
		self.rotation = self:getRotationForDirection(self.physics.direction)
		if self.fire_on_left_edge and self:hasReachedFireLeftEdge() then
			self:fire()
		end
	end
end

return SmallSword
