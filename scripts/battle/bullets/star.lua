---@class Star : Bullet
local Star, super = Class(Bullet)

function Star:init(x, y, dir, min_speed, max_speed, accel_duration)
	super.init(self, x, y, "bullets/star_invert")

	self:setScale(0.8, 0.8)
	self.damage = 38
	self.inv_timer = Game:getConfig("defaultInvulnTime") / 30
	self.destroy_on_hit = false
	self.alpha = 0

	self.min_speed = min_speed
	self.max_speed = max_speed
	self.accel_duration = accel_duration
	self.elapsed = 0

	self.initial_dir = dir + math.pi / 2
	self.final_dir = dir
	self.physics.direction = self.initial_dir
	self.physics.speed = 0

	self.wait_time = 5 / 30
	self.transition_time = 15 / 30

	self.ghost = Sprite("bullets/star_invert", 0, 0)
	self.ghost:setColor(1, 1, 1, 1.0)
	self.ghost.layer = -0.001
	self:addChild(self.ghost)

	self.spin = 0
	self.osc_time = 0
end

function Star:getDamage()
	if self.scale_x <= 0.5 and self.scale_y <= 0.5 then
		return 0
	end

	return super.getDamage(self)
end

function Star:onWaveSpawn(wave)
	super.onWaveSpawn(self, wave)

	local ghost_ref = self.ghost
	-- A longer interval and faster fade preserve the motion cue without creating
	-- dozens of full-screen canvases per star during dense waves.
	local handle = wave.timer:every(0.04, function()
		if not ghost_ref or ghost_ref:isRemoved() then
			return false
		end
		local img = LightAfterImage(ghost_ref, 0.4, 0.08)
		ghost_ref:addChild(img)
	end)
	wave.timer:tween(1.0, handle, {limit = 0.2})
end

function Star:update()
	self.elapsed = self.elapsed + DT

	local lt = self.wait_time + self.transition_time

	if self.elapsed < self.wait_time then
	elseif self.elapsed < lt then
		local raw = (self.elapsed - self.wait_time) / self.transition_time
		local t = 1 - (1 - raw) * (1 - raw) * (1 - raw)
		self.alpha = t
		self.physics.direction = self.initial_dir + (self.final_dir - self.initial_dir) * t
	else
		self.alpha = 1
		self.physics.direction = self.final_dir
		local t = self.accel_duration > 0 and math.min((self.elapsed - lt) / self.accel_duration, 1.0) or 1.0
		self.physics.speed = self.min_speed + (self.max_speed - self.min_speed) * t * t * t
	end

	super.update(self)

	-- spin: 273 deg / 1.5s = 182 deg/s
	self.spin = self.spin + math.rad(182) * DT
	self.rotation = self.physics.direction + math.pi / 2 + self.spin

	-- scale oscillation: 3.5 sin cycles per 1.17s, pixel range / 18px
	self.osc_time = self.osc_time + DT
	local t = math.sin(self.osc_time * 2 * math.pi * 3.5 / 1.17)
	local sx = (34.45 + 12.05 * t) / 18 -- 22.4..46.5 px -> 1.24..2.58 scale
	local sy = (36.15 + 8.35 * t) / 18 -- 27.8..44.5 px -> 1.54..2.47 scale
	self:setScale(sx * 0.5 * 0.8, sy * 0.5 * 0.8)
end

return Star
