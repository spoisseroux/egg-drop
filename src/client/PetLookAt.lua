-- Look at owner (FEEL-ALIVE-DIRECTION-2026-11-13 B2): when the owner is within 12
-- studs and starts or stops moving, the head turns toward them (up to 35 degrees,
-- eased at 4 per second) and relaxes after 3 s. While sitting near the owner the
-- head keeps following. Starting a look asks for a curious coo 20 % of the time.
-- Inputs on the visual (set by RoomView for the owner's own pet): ownerPosition,
-- ownerMoving. Returns a head yaw offset in radians.
local Look = {}
Look.Range, Look.Max, Look.Rate, Look.Hold, Look.CooChance = 12, math.rad(35), 4, 3, .2

-- Relative yaw from the pet's facing to a target, both on the ground plane.
function Look.relative(origin, yaw, target)
	local d = target - origin
	if d.X * d.X + d.Z * d.Z < .25 then return 0 end
	local wanted = math.atan2(d.X, d.Z)
	local delta = wanted - (yaw or 0)
	return math.atan2(math.sin(delta), math.cos(delta))
end

function Look.step(visual, dt, allowed)
	dt = math.clamp(dt or 0, 0, .25)
	local owner = visual.ownerPosition
	local time = visual.time or 0
	local target = 0
	if allowed and typeof(owner) == "Vector3" and not visual.reducedEffects then
		local flat = Vector3.new(owner.X - visual.origin.X, 0, owner.Z - visual.origin.Z).Magnitude
		if flat <= Look.Range then
			local moving = visual.ownerMoving == true
			if visual.lookOwnerMoving ~= moving then
				visual.lookOwnerMoving = moving
				local fresh = time >= (visual.lookOwnerUntil or -math.huge)
				visual.lookOwnerUntil = time + Look.Hold
				if fresh then
					visual.lookRandom = visual.lookRandom or Random.new(math.floor(math.abs(visual.cosmeticSeed or 0)) + 101)
					if visual.lookRandom:NextNumber() < Look.CooChance then visual.pendingCoo = "pet_coo_1" end
				end
			end
			if time < (visual.lookOwnerUntil or -math.huge) or (visual.sitWeight or 0) > .5 then
				target = math.clamp(Look.relative(visual.origin, visual.yaw, owner), -Look.Max, Look.Max)
			end
		else
			visual.lookOwnerMoving = nil
		end
	end
	local yaw = visual.lookYaw or 0
	yaw += (target - yaw) * math.min(1, dt * Look.Rate)
	if math.abs(yaw) < 1e-4 and target == 0 then yaw = 0 end
	visual.lookYaw = yaw
	return yaw
end

return Look
