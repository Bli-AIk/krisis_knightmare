---@class SmallSword : Bullet
local SmallSword, super = Class(Bullet)

local FIRE_ALPHA_DURATION = 0.12
local FIRE_AIM_DURATION = 0.5
local FIRE_COLOR_DURATION = 0.6
-- Change this one multiplier to scale both the black tail and its exit speed.
local PATH_SEGMENT_LENGTH_MULTIPLIER = 3
local PATH_SEGMENT_BASE_SPEED = 750 / 2
local PATH_SEGMENT_BASE_BLACK_LENGTH = 160
local PATH_SEGMENT_SPEED = PATH_SEGMENT_BASE_SPEED * PATH_SEGMENT_LENGTH_MULTIPLIER
local PATH_SEGMENT_BLACK_LENGTH = PATH_SEGMENT_BASE_BLACK_LENGTH * PATH_SEGMENT_LENGTH_MULTIPLIER
local PATH_SEGMENT_TRANSITION_LENGTH = 96
local PATH_SEGMENT_LENGTH = PATH_SEGMENT_BLACK_LENGTH + PATH_SEGMENT_TRANSITION_LENGTH
local PATH_SEGMENT_OFFSCREEN_MARGIN = 16
local PATH_SEGMENT_WIDTH = 2
local PATH_SEGMENT_TRANSITION_STEPS = 24

local SmallSwordPathSegment, segment_super = Class(Object)

function SmallSwordPathSegment:init(x, y, direction)
	segment_super.init(self, x, y)

	self.rotation = direction
	self.black_length = PATH_SEGMENT_BLACK_LENGTH
	self.transition_length = PATH_SEGMENT_TRANSITION_LENGTH
	self.length = PATH_SEGMENT_LENGTH
	self.physics.direction = direction
	self.physics.speed = PATH_SEGMENT_SPEED / 30
	self.layer = BATTLE_LAYERS["above_arena"]
	self.debug_select = false
end

function SmallSwordPathSegment:isFullyOffscreen()
	local head_x, head_y = self:getScreenPos()
	local tail_x = head_x - math.cos(self.rotation) * self.length
	local tail_y = head_y - math.sin(self.rotation) * self.length
	local margin = PATH_SEGMENT_OFFSCREEN_MARGIN
	local min_x, max_x = math.min(tail_x, head_x), math.max(tail_x, head_x)
	local min_y, max_y = math.min(tail_y, head_y), math.max(tail_y, head_y)

	return max_x < -margin or min_x > SCREEN_WIDTH + margin
		or max_y < -margin or min_y > SCREEN_HEIGHT + margin
end

function SmallSwordPathSegment:update()
	segment_super.update(self)

	if self:isFullyOffscreen() then
		self:remove()
	end
end

function SmallSwordPathSegment:getArenaBorderInLocalSpace()
	local arena = Game.battle and Game.battle.arena
	if not arena or not arena.border_line then
		return nil
	end

	local points = {}
	for i = 1, #arena.border_line, 2 do
		local screen_x, screen_y = arena:localToScreenPos(arena.border_line[i], arena.border_line[i + 1])
		local local_x, local_y = self:screenToLocalPos(screen_x, screen_y)
		table.insert(points, local_x)
		table.insert(points, local_y)
	end

	return points
end

function SmallSwordPathSegment:draw()
	local old_width = love.graphics.getLineWidth()
	local old_r, old_g, old_b, old_a = love.graphics.getColor()

	local transition_length = self.transition_length
	local border_points = self:getArenaBorderInLocalSpace()

	local function drawBlackTrail()
		if self.black_length <= 0 then
			return
		end

		love.graphics.setLineWidth(PATH_SEGMENT_WIDTH)
		Draw.setColor(0, 0, 0, 1)
		love.graphics.line(-self.length, 0, -transition_length, 0)
	end

	if border_points and #border_points >= 6 then
		love.graphics.stencil(function()
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.polygon("fill", unpack(border_points))
		end, "replace", 1)
		love.graphics.setStencilTest("greater", 0)
		drawBlackTrail()
		love.graphics.setStencilTest()
	else
		drawBlackTrail()
	end

	-- The bright head and its gradient intentionally stay outside the arena stencil.
	for i = 0, PATH_SEGMENT_TRANSITION_STEPS - 1 do
		local start_t = i / PATH_SEGMENT_TRANSITION_STEPS
		local end_t = (i + 1) / PATH_SEGMENT_TRANSITION_STEPS
		local start_x = -transition_length + transition_length * start_t
		local end_x = -transition_length + transition_length * end_t
		local t = end_t * end_t * (3 - 2 * end_t)
		local width = PATH_SEGMENT_WIDTH * (1 - 0.5 * end_t)

		love.graphics.setLineWidth(width)
		Draw.setColor(t, t, t, 1)
		love.graphics.line(start_x, 0, end_x, 0)
	end

	-- Keep the tip to a single bright pixel so the head stays streamlined.
	Draw.setColor(1, 1, 1, 1)
	love.graphics.rectangle("fill", -1, -1, 2, 2)

	love.graphics.setLineWidth(old_width)
	love.graphics.setColor(old_r, old_g, old_b, old_a)
end

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
	self.show_path_ray = options.show_path_ray == true
	if self.fire_on_left_edge then
		self.remove_offscreen = false
	end

	-- 纯白半透明虚影 sprite（ColorMaskFX: 非透明像素全部渲染为纯白）
	self.ghost = Sprite("bullets/small_sword", 0, 0)
	self.ghost:setColor(1, 1, 1, 0.19)
	self.ghost.layer = -0.001
	self:addChild(self.ghost)
end

function SmallSword:onWaveSpawn(wave)
	super.onWaveSpawn(self, wave)

	if self.show_path_ray and not self.path_ray_spawned then
		self.path_ray_spawned = true
		local x, y = self:getScreenPos()
		self.path_ray = wave:spawnObject(SmallSwordPathSegment(x, y, self.final_dir))
	end

	local ghost_ref = self.ghost
	-- The source texture is already white. Avoid a full-screen ColorMaskFX canvas
	-- for every trail image and keep fewer, shorter-lived images under dense waves.
	wave.timer:every(1 / 10, function()
		if not ghost_ref or ghost_ref:isRemoved() then
			return false
		end
		local img = LightAfterImage(ghost_ref, 0.4, 0.16)
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
