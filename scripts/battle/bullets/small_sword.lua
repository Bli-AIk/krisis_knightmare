---@class SmallSword : Bullet
local SmallSword, super = Class(Bullet)

---@param x number # The X position of the bullet
---@param y number # The Y position of the bullet
---@param dir number # Final direction (perpendicular to slash line)
---@param min_speed number # Starting speed (pixels per frame at 30FPS)
---@param max_speed number # Peak speed after acceleration completes
---@param accel_duration number # How many seconds to go from min_speed to max_speed
function SmallSword:init(x, y, dir, min_speed, max_speed, accel_duration)
	super.init(self, x, y, "bullets/small_sword")

	self:setScale(1, 1)
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
	wave.timer:every(1/15, function()
		if not ghost_ref or ghost_ref:isRemoved() then
			return false
		end
		local img = AfterImage(ghost_ref, 0.4, 0.1)
		img:addFX(ColorMaskFX())
		ghost_ref:addChild(img)
	end)
end

function SmallSword:update()
	self.elapsed = self.elapsed + DT

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

	super.update(self)

	-- 贴图剑尖朝上，+π/2 指向飞行方向
	self.rotation = self.physics.direction + math.pi / 2
end

return SmallSword
