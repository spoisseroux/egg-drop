-- Bumble balls: the pets' nose-bunt (GARDEN-PLAY-BRIEF section 1 "Pets"). Server only, read-only on the garden: a free
-- pet already standing at a resting ball sometimes noses it on (a server kick at Balls.BuntScale), at most once per
-- Cooldown per ball, after the ball has settled. It never moves a pet: the trot over, the hop after and the ears/head
-- tracking need the pet walking code (GardenState, being rewritten), so they wait for it.
local Shared=game:GetService("ReplicatedStorage").Shared
local Balls=require(Shared.BumbleBalls)
local Pets={}
Pets.Range=1.8      -- the pet's centre within this of the ball's surface, in plan [PLACEHOLDER]
Pets.Chance=1/3     -- about one in three
Pets.Cooldown=8     -- per ball, a roll at most this often (a failed roll waits too)
Pets.Settled=1.5    -- the ball has rested this long
Pets.Still=1.5      -- the pet moves slower than this (studs/s)

-- Pure. balls: {[id] = {rest: Vector3, restAt, buntAt}} (buntAt is written here); pets: {{ownerId, position}};
-- rng: NextNumber(). The bunts: {{id, origin, velocity, ownerId}} (velocity already at BuntScale).
function Pets.pick(balls,pets,now,rng)
	local out={}
	for _,entry in ipairs(Balls.List)do
		local ball=balls[entry.id]
		if not ball or now<ball.restAt+Pets.Settled or now-(ball.buntAt or -math.huge)<Pets.Cooldown then continue end
		local best,gap=nil,math.huge
		for _,pet in ipairs(pets)do
			local d=Balls.planDistance(pet.position,ball.rest)
			if d-Balls.Radius<=Pets.Range and d<gap then best,gap=pet,d end
		end
		if not best then continue end
		ball.buntAt=now
		if rng:NextNumber()>=Pets.Chance then continue end
		local away=Balls.flat(ball.rest-best.position)
		if away.Magnitude<1e-3 then continue end
		local velocity=(away.Unit*Balls.KickFlat+Vector3.new(0,Balls.KickUp,0))*Balls.BuntScale
		table.insert(out,{id=entry.id,origin=ball.rest,velocity=velocity,ownerId=best.ownerId})
	end
	return out
end

-- The free pets in the garden: in the garden (not deck, focus, a Dash race, a park game or a greeting), standing still.
function Pets.free(garden,now)
	local Activity=require(Shared.GardenActivity)
	local out={}
	for id,actor in pairs(garden and garden.actors or {})do
		if actor.mode~="Room"or actor.dash or actor.pairId or(actor.park and actor.park.session)then continue end
		local sample=Activity.sample(actor,now)
		if sample and typeof(sample.position)=="Vector3"and(typeof(sample.velocity)~="Vector3"or sample.velocity.Magnitude<Pets.Still)then
			table.insert(out,{ownerId=actor.ownerId or id,position=sample.position})
		end
	end
	return out
end
return table.freeze(Pets)
