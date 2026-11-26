-- The garden's fruit (GARDEN-PLAY-BRIEF-2 section 5; Spencer, beta 35 note 8: "should he gain some stats? ... a little
-- brighter? ... a 3d object that they eat for longer ... shrinks ... make a sound ... put them in the trees and they can
-- shake them down"). Shared and pure: the look, the shake, the five bites and the Heart XP rules, and the one copy of
-- "did a fruit fall from tree i lately" that both sides read (the clients draw the grove, LifeSim; the server checks a
-- claim against the same wind, FruitHost). Behind the Alive `fruit` switch (beta and Studio; missing = on).
--
-- Trees: the Aero kit's lime-able crowns (WorldAeroKit kind foliage_blossom), sorted by tree name: index i is the
-- grove's crown index (LifeSim.kitCrowns sorts the same way), `centre` its crown's centre (AeroKit.crownFrame's
-- position; the gusts are timed there), `x, z` its trunk (the crown's pivot) and `trunk` the trunk's radius.
local Shared=script.Parent
local Wind=require(Shared.Wind)
local Fruit={}
Fruit.Feature="fruit"

-- Stats: Heart, the same as one petting; never the daily Bonus XP, never a Stars payout; no counter anywhere.
Fruit.Stat="heart"
Fruit.XP=2
Fruit.Gap=60          -- seconds: at most one paid fruit a minute (per player, on the server)
Fruit.DailyLimit=12   -- a day (24 XP); after it the pet still eats happily
-- What falls (LifeSim.Fruit.chance / dropAt: the LifeSim spec holds them equal).
Fruit.Chance=.5
Fruit.DropAt=.8
Fruit.Kinds=table.freeze({foliage_blossom=true})
-- A claim is for a fruit that let go at most Window seconds ago: fall and bounces (about 1.5 s), resting 30 s, a bat
-- or nudges, the fade, the pet's trot and five bites.
Fruit.Window=45
Fruit.Reach=14        -- studs from its tree's trunk a fruit can lie (the fall's spread, the roll, a bat, a few nudges)
Fruit.PetReach=11     -- the server's pet from the fruit (LifePet's notice 8, plus lag)
Fruit.OwnerReach=24   -- the player from the fruit (LifePet's leash 16, plus nudges and lag)

-- The shake (client-local, as the gust drops): walk into a trunk (root within trunk + Reach of its centre) faster than
-- Speed; the crown rocks Rock degrees Rocks times in RockTime, Leaves leaf cards fall, one fruit drops with the gust
-- drop's fall. That slot is empty Hidden seconds, then grows back over Grow; the tree has nothing to shake till then.
Fruit.Shake=table.freeze({reach=1.6,speed=4,rock=6,rocks=3,rockTime=.6,leaves=8,hidden=60,grow=20,
	slack=2,       -- the server's root may lag the client's
	gap=75})       -- the server: one shake a tree a player this often (Hidden + Grow, less slack)
Fruit.Trunk=.6   -- a trunk's radius at crown scale 1 (GardenKeepOut.Trunk)
Fruit.TrunkOf=table.freeze({Landmark_BlossomPointTree=1.1})

-- The look (brighter, 3D): a body, a blush sunk in one shoulder, a stem and a leaf. SmoothPlastic, no gloss.
Fruit.Look=table.freeze({
	body=table.freeze({size=.9,colour="#FF8A4C"}),
	blush=table.freeze({size=.5,colour="#FFD166",at=Vector3.new(.24,.14,.18)}),   -- from the body's centre
	stem=table.freeze({size=Vector3.new(.3,.08,.08),colour="#6B4A2E",at=Vector3.new(0,.56,0)}), -- a Cylinder stood up
	leaf=table.freeze({size=Vector3.new(.4,.04,.22),colour="#7FBF4D",at=Vector3.new(.16,.62,0),tilt=25}),
})
-- Eating: five bites over 3.2 s, the fruit at each scale after that bite, turning `turn` degrees a bite; three crumbs a
-- bite in the body's colour; the stem and leaf drop and fade over `stemFade`; the cheeks puff `cheeks` on a bite.
Fruit.Bites=table.freeze({count=5,time=3.2,scales=table.freeze({1,.78,.58,.40,.22,0}),turn=25,crumbs=3,stemFade=1,
	stemDrop=.5,cheeks=1.15,cheekTime=.25})
-- Sounds (existing ids only; tree_shake is a new take to make). Volumes.
Fruit.Sounds=table.freeze({rustle="asmr_flake",rustles=2,rustleVolume=.5,land="land",landVolume=.4,
	bites=table.freeze({"snack_nom_a","snack_nom_b","snack_nom_c"}),biteVolume=.6,gulp="snack_gulp",gulpVolume=.5,
	happy="snack_happy_squeak",happyVolume=.5})
Fruit.Buzz="settle"   -- Haptics, the local player only, on the shake

function Fruit.on()
	local ok,on=pcall(function()
		local Alive=require(Shared.Alive)
		return Alive.ceiling(Fruit.Feature)and Alive.on(Fruit.Feature)
	end)
	return ok and on==true
end

local function vector(list)return Vector3.new(list[1],list[2],list[3])end
local treesCache
-- The fruit trees (see the header). data: WorldAeroKit (specs pass their own; nil reads it).
function Fruit.trees(data)
	if data==nil and treesCache then return treesCache end
	local kit=data or require(Shared.WorldAeroKit)
	local out={}
	for _,crown in ipairs(kit.crowns or {})do
		local mesh=kit.meshes and kit.meshes[crown.mesh]
		if mesh and Fruit.Kinds[mesh.kind]then
			local pivot=vector(crown.pivot)
			local centre=pivot+CFrame.Angles(0,crown.yaw,0):VectorToWorldSpace(vector(mesh.pivotToCentre)*crown.scale)
			table.insert(out,{tree=crown.tree,centre=centre,x=pivot.X,z=pivot.Z,
				trunk=Fruit.TrunkOf[crown.tree]or Fruit.Trunk*crown.scale})
		end
	end
	table.sort(out,function(a,b)return a.tree<b.tree end)
	for i,tree in ipairs(out)do tree.i=i;out[i]=table.freeze(tree)end
	out=table.freeze(out)
	if data==nil then treesCache=out end
	return out
end

local function flat(ax,az,bx,bz)return math.sqrt((ax-bx)^2+(az-bz)^2)end
-- Is (x, z) a place a fruit of this tree can lie?
function Fruit.nearTree(tree,x,z)
	return type(tree)=="table"and type(x)=="number"and type(z)=="number"and flat(tree.x,tree.z,x,z)<=Fruit.Reach
end
-- Is a root at (x, z) moving `speed` studs a second walking into this tree's trunk? slack: extra reach (the server's).
function Fruit.shakes(tree,x,z,speed,slack)
	if type(tree)~="table"or type(x)~="number"or type(z)~="number"then return false end
	if type(speed)=="number"and speed<Fruit.Shake.speed then return false end
	return flat(tree.x,tree.z,x,z)<=tree.trunk+Fruit.Shake.reach+(slack or 0)
end

-- When gust n lets fruit go at `position` (a crown's centre): the first 1/60 s on the gust's way up that it reaches
-- DropAt there, or nil. World time. LifeSim.fruitTrigger is this.
function Fruit.trigger(position,n)
	if typeof(position)~="Vector3"or type(n)~="number"or Wind.peak(n)<=0 then return nil end
	local start=Wind.start(n)+position:Dot(Wind.Direction)/Wind.Speed
	if Wind.at(position,start+Wind.Rise)<Fruit.DropAt then return nil end
	for step=0,math.ceil(Wind.Rise*60)do
		local t=start+step/60
		if Wind.at(position,t)>=Fruit.DropAt then return t end
	end
	return nil
end
-- The big breath's let-go (the Alive `scene` switch): it always counts as a strong gust. LifeSim.fruitBreathTrigger.
function Fruit.breathTrigger(position,b)
	if typeof(position)~="Vector3"or type(b)~="number"then return nil end
	local start=Wind.breathStart(b)+position:Dot(Wind.Direction)/Wind.Speed
	for step=0,math.ceil(Wind.BreathRise*60)do
		local t=start+step/60
		if Wind.breathEnvelope(t-start)>=Fruit.DropAt then return t end
	end
	return nil
end
-- Did tree i (Fruit.trees order, centre its crown's centre) let a fruit go within [now - window, now]? The seeded chance
-- and the trigger only (LifeSim.fruitCandidate's first two rules): a superset of what the clients draw, which also need
-- good ground to land on. breath: the big breath's drops count too.
function Fruit.dropped(i,centre,now,window,breath)
	if type(i)~="number"or typeof(centre)~="Vector3"or type(now)~="number"or now~=now then return false end
	window=window or Fruit.Window
	local a=now-window
	local offset=centre:Dot(Wind.Direction)/Wind.Speed
	local lo,hi=math.floor((a-offset-Wind.Rise-Wind.Jitter)/Wind.Slot),math.ceil((now-offset+Wind.Jitter)/Wind.Slot)
	for n=lo,hi do
		if Wind.hash(n*16+i,13)<Fruit.Chance then
			local t=Fruit.trigger(centre,n)
			if t and t>=a and t<=now then return true end
		end
	end
	if breath then
		local blo=math.floor((a-offset-Wind.BreathRise-Wind.BreathJitter)/Wind.BreathSlot)
		local bhi=math.ceil((now-offset+Wind.BreathJitter)/Wind.BreathSlot)
		for b=blo,bhi do
			if Wind.hash(b*16+i,17)<Fruit.Chance then
				local t=Fruit.breathTrigger(centre,b)
				if t and t>=a and t<=now then return true end
			end
		end
	end
	return false
end

-- The fruit's scale after `t` seconds of eating (1 before, 0 after the fifth bite), the bite it is on (0 before the
-- first lands, 1..count), and its turn (degrees) so far.
function Fruit.bite(t)
	local B=Fruit.Bites
	if type(t)~="number"or t~=t or t<0 then return 1,0,0 end
	local each=B.time/B.count
	local n=math.min(B.count,math.floor(t/each))
	return B.scales[n+1],n,n*B.turn
end

return table.freeze(Fruit)
