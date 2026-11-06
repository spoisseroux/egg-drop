-- Navigation starts only after the hatch view confirms its exact acknowledgment.
-- Equip and mode remain server-owned; cancellation fences all delayed work.
local Navigation = {}
Navigation.__index = Navigation

function Navigation.new(dependencies)
	return setmetatable({ dependencies = dependencies, generation = 0, active = false }, Navigation)
end

function Navigation:cancel()
	self.active = false
	self.generation += 1
	return self.generation
end

function Navigation:valid(generation)
	return self.generation == generation and not self.dependencies.blocked()
end

function Navigation:waitUntil(generation, seconds, condition)
	local d = self.dependencies
	local now, wait = d.now or os.clock, d.wait or task.wait
	local deadline = now() + seconds
	while self:valid(generation) and now() < deadline do
		if condition() then return self:valid(generation) end
		wait(.1)
	end
	return false
end

function Navigation:start(run)
	local generation, d = self:cancel(), self.dependencies
	self.active = true
	local spawn = d.spawn or task.spawn
	spawn(function()
		if self:valid(generation) then run(generation, d) end
		if self.generation == generation then self.active = false end
	end)
end

function Navigation:meet(petId)
	self:start(function(generation, d)
		if d.get("Mode") ~= "Room" then d.send("mode", "Room") end
		if not self:waitUntil(generation, 4, function() return d.get("Mode") == "Room" and d.ready() end) then return end
		local now = d.now or os.clock
		local lastRequest = -math.huge
		local equipped = self:waitUntil(generation, 3, function()
			if d.get("Mode") ~= "Room" then self:cancel(); return false end
			if d.get("CompanionId") == petId then return true end
			if now() - lastRequest >= .5 then
				lastRequest = now()
				d.send("companion", petId)
			end
			return false
		end)
		if not self:valid(generation) then return end
		if equipped and d.get("Mode") == "Room" and d.ready() then
			d.present(petId)
		elseif d.failure then
			d.failure()
		end
	end)
end

function Navigation:play()
	self:start(function(generation, d)
		if d.get("Mode") ~= "Board" then d.send("mode", "Board") end
		if not self:waitUntil(generation, 4, function() return d.get("Mode") == "Board" and d.ready() end) then return end
		if self:valid(generation) and d.get("RoundOver") then d.send("reset") end
	end)
end

return Navigation
