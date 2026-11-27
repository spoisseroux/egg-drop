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
-- Beta 38 (GARDEN-B38-BRIEF 3b): the crown rocks 8 degrees, three swings in .7 s easing out, and 12 leaf cards fall.
Fruit.Shake=table.freeze({reach=1.6,speed=4,rock=8,rocks=3,rockTime=.7,leaves=12,hidden=60,grow=20,
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
-- Beta 38 (GARDEN-B38-BRIEF 3a, Fable; Spencer's note 15 "fruit in the trees like Animal Crossing"): the fruit sits in
-- the canopy. Five slots a tree, all full when grown (Blossom Point seven): `under` hang under the skirt as before, the
-- rest are seated on the crown's outer face between seatFrom and seatTo degrees under its widest line, sunk `sunk` of
-- the body into the leaves with a darker leaf disc behind and a two-leaf sprig on top. In the tree the body is `size`
-- (1.15); a dropped one settles to Look.body.size (.9) over its first bounce. Look only: the rules above are unchanged.
Fruit.Canopy=table.freeze({slots=5,slotsOf=table.freeze({Landmark_BlossomPointTree=7}),under=2,seatFrom=15,seatTo=40,
	sunk=.35,size=1.15,
	hull=.9,       -- [PLACEHOLDER] the leaves' face as a share of the crown's bounding ellipsoid (hulls overstate the leaves)
	shadow=table.freeze({colour="#2F6B34",thick=.04,across=1.25}),   -- the leaf disc behind a seated fruit
	sprig=table.freeze({at=Vector3.new(-.16,.62,0),tilt=-25}),       -- the second leaf, mirrored over the first
})
-- Three varieties, one a tree (look only), all warm against the lime crowns; `tall` stretches the body upright.
Fruit.Varieties=table.freeze({
	sunset=table.freeze({body="#FF8A4C",blush="#FFD166",tall=1}),
	berry=table.freeze({body="#E8456B",blush="#FF9DB5",tall=1}),
	pear=table.freeze({body="#F2C14E",blush="#FFF0B0",tall=1.2}),
	golden=table.freeze({body="#FFC83D",blush="#FFEFC2",tall=1}),
})
Fruit.VarietyOf=table.freeze({Tree_05_blossom="sunset",Tree_10_blossom="sunset",Tree_17_blossom="sunset",
	Tree_07_blossom="berry",Tree_14_blossom="berry",Tree_21_blossom="berry",Tree_19_blossom="pear",
	Landmark_BlossomPointTree="golden"})
-- The hanging pendulum: Rest degrees on each fruit's own Period (seconds, from periodMin to periodMax), up to Gust in a
-- gust; the seated ones half as much. Reduced Motion: still.
Fruit.Sway=table.freeze({rest=3,gust=10,periodMin=2.2,periodMax=3,seated=.5})
-- The shake's beats (3b): the first fruit lets go `first` s in (the second swing), and one shake in `secondChance` a
-- second fruit `second` s after it. A fruit's landing ticks `landBuzz`.
Fruit.Drops=table.freeze({first=.3,second=.3,secondChance=.25})
Fruit.LandBuzz="drop"
-- The prompt (3b): a "Shake" pill at the trunk while a shake is allowed for me. Fable asks for 6 studs; the server's
-- shake reach (trunk + Shake.reach + Shake.slack, unchanged) is the limit, so the pill shows within half the slack of
-- the bump's reach and a prompt shake is never refused as Far.
Fruit.Prompt=table.freeze({reach=6,height=2.4})

-- Pure: tree name -> its variety (sunset when unlisted); its slots (5, Blossom Point 7).
function Fruit.variety(tree)return Fruit.Varieties[Fruit.VarietyOf[tree]or "sunset"]end
function Fruit.slotsFor(tree)return Fruit.Canopy.slotsOf[tree]or Fruit.Canopy.slots end
-- Pure: the body's scale (1 = Look.body.size) for a fruit in the tree (`landed` nil) or one that first landed at
-- `landed` and finishes its first bounce at `settled`, at `now`: the tree's 1.15 till the landing, easing to .9.
function Fruit.sizeAt(now,landed,settled)
	local tree=Fruit.Canopy.size/Fruit.Look.body.size
	if type(now)~="number"or type(landed)~="number"or now<=landed then return tree end
	local span=math.max(1e-3,(settled or landed)-landed)
	local u=math.clamp((now-landed)/span,0,1)
	return tree+(1-tree)*u*u*(3-2*u)
end
-- Pure: the prompt's reach from a trunk's centre (XZ): Fable's 6 when the server allows it, else within the server's.
function Fruit.promptReach(tree)
	local S=Fruit.Shake
	local trunk=type(tree)=="table"and type(tree.trunk)=="number"and tree.trunk or Fruit.Trunk
	return math.min(Fruit.Prompt.reach,trunk+S.reach+S.slack/2)
end
-- Pure: the let-go times after a shake at `now` for a shake numbered `count` (the client's own count): the first on
-- the second swing, and one shake in four a second (Wind.hash, the same on a re-run). Both clamp to the fruit on the tree.
function Fruit.dropTimes(now,count)
	local D=Fruit.Drops
	local out={now+D.first}
	if type(count)=="number"and Wind.hash(count,21)<D.secondChance then table.insert(out,now+D.first+D.second)end
	return out
end

-- Eating: five bites over 3.2 s, the fruit at each scale after that bite, turning `turn` degrees a bite; three crumbs a
-- bite in the body's colour; the stem and leaf drop and fade over `stemFade`; the cheeks puff `cheeks` on a bite.
Fruit.Bites=table.freeze({count=5,time=3.2,scales=table.freeze({1,.78,.58,.40,.22,0}),turn=25,crumbs=3,stemFade=1,
	stemDrop=.5,cheeks=1.15,cheekTime=.25})
-- Sounds (existing ids only; tree_shake is a new take to make). Volumes.
-- Beta 38 (3b): the shake's layer is `shake` (the tree_shake take to record; blanket_rustle stands in) at .6, the
-- rustles, a low wooden creak, then per fruit a stem pluck and the land thud. An empty shake is the shake and the
-- rustles alone at `emptyPitch`, so "nothing" sounds different from "something".
Fruit.Sounds=table.freeze({rustle="asmr_flake",rustles=2,rustleVolume=.5,land="land",landVolume=.4,
	shake="blanket_rustle",shakeVolume=.6,shakePitch=.8,creak="asmr_creak_a",creakVolume=.3,creakPitch=.7,
	pluck="asmr_pop_a",pluckVolume=.3,pluckPitch=1.4,emptyPitch=.85,
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
local treesCache={}
-- The fruit trees (see the header). data: WorldAeroKit (specs pass their own; nil reads it). Beta 38: graded
-- (TreeGrades.kit) while the tree grades are on (`graded`; nil asks TreeGrades.on), so the centre, the trunk's spot and
-- its radius (Trunk x the trunk's own scale) are the trees every client draws; the rules on them are unchanged.
function Fruit.trees(data,graded)
	local Grades=require(Shared.TreeGrades)
	if graded==nil then graded=Grades.on()end
	local key=if graded then "graded"else "today"
	if data==nil and treesCache[key]then return treesCache[key]end
	local kit=Grades.kit(data or require(Shared.WorldAeroKit),graded)
	local out={}
	for _,crown in ipairs(kit.crowns or {})do
		local mesh=kit.meshes and kit.meshes[crown.mesh]
		if mesh and Fruit.Kinds[mesh.kind]then
			local pivot=vector(crown.pivot)
			local centre=pivot+CFrame.Angles(0,crown.yaw,0):VectorToWorldSpace(vector(mesh.pivotToCentre)*Grades.scaleOf(crown))
			table.insert(out,{tree=crown.tree,centre=centre,x=pivot.X,z=pivot.Z,
				trunk=Fruit.TrunkOf[crown.tree]or Fruit.Trunk*(crown.trunk or crown.scale)})
		end
	end
	table.sort(out,function(a,b)return a.tree<b.tree end)
	for i,tree in ipairs(out)do tree.i=i;out[i]=table.freeze(tree)end
	out=table.freeze(out)
	if data==nil then treesCache[key]=out end
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
-- Pure: may the prompt shake this tree from a root at (x, z)? Within promptReach (no speed: the prompt is the press).
function Fruit.promptShakes(tree,x,z)
	if type(tree)~="table"or type(x)~="number"or type(z)~="number"then return false end
	return flat(tree.x,tree.z,x,z)<=Fruit.promptReach(tree)
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
