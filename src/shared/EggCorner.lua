-- The egg corner (artifacts/qa-2026-11-24-beta15/EGG-CORNER-LOOK.md and its Placement rulings R2;
-- EGG-CORNER-BUILD-PLAN.md): one nest, one egg machine. Shared and pure: the numbers, the switch read and the two data
-- switches the island re-export flips. HollowWorldLayout is not edited: V7.Stations.Eggs stays the old station (live and
-- every spec that reads it); everything the corner moves reads this module.
--   Onboard.on("corner")  the runtime switch, under the onboarding v3 ceiling (beta and Studio only; live never)
--   EggCorner.split()     the island export carries the old Eggs station as its own parts (W7_EggsStation__*): only
--                         then can the steps, glow egg and stele be hidden, so only then does the nest move to (-31, -11)
local Shared=script.Parent
local Onboard=require(Shared.Onboard)
local Nest=require(Shared.Nest)
local Corner={}

-- The machine (R2 1): M5. The west bench, both egg statues and Pad_Future_B already went in the 2026-11-13 declutter
-- (the island session, 2026-11-24), so M5 needs no re-export. Front (local +Z) looks at Face.
Corner.Spot=Vector3.new(-41,4.13,2)
Corner.Face=Vector3.new(-26,4.13,7)
Corner.Reach=7
Corner.PromptAt=Vector3.new(0,2.2,2.6)  -- machine-local: in front of the dial, outside the block box
Corner.Block=Vector3.new(4.8,1,4.4)     -- the pets' box, turned with the machine
Corner.TrailAhead=3                     -- the Hatch eggs trail ends this far in front
Corner.PinLift=1.6                      -- the Eggs pin over the machine's top
Corner.Ring=3                          -- the Eggs attract ring at the machine (Fable R8 FIX 2: 3.6 showed its back arc on grass)
-- Studio check R9: at r 3 the back still crossed grass (105 to 167 degrees from the facing) and no radius fixes it, so
-- the ring is a front arc, RingArc degrees centred on the facing (+-100 clears every R9 sample; 220 did not). r 3.6 with
-- the arc would reach 15.67 from the paving's middle (edge 15.5), so it stays 3.
Corner.RingArc=194 -- Fable R10 3
-- The machine's facing, flat (front +Z of the frame): what the ring's arc is centred on.
function Corner.facing()
	local d=Corner.Face-Corner.Spot
	return Vector3.new(d.X,0,d.Z).Unit
end
Corner.Height=7.2                       -- the machine's height when no model is there to measure
-- The nest (R2 3): on plain marble at the old station's spot once the station is split out; until then E1 (beta only).
Corner.NestSpot=Vector3.new(-31,4.07,-11)
Corner.NestFacing=Nest.Facing
-- EggNestLight at the nest: lower and tighter (LOOK 1).
Corner.Light=table.freeze({lift=2.5,range=8,was=table.freeze({lift=4,range=10})})
-- What the beta hides now (R2 2): the halo and the cup's leaves are their own world parts; the dome and the Eggs lip are
-- client Aero additions. After the split (branch claude/eggs-station-split) the station is six parts named
-- W7_EggsStation__<material> (marble, marble_smooth and trim collide; palette, foliage and glow_warm do not; the halo,
-- glow_warm, keeps region "NestHalo"): hidden by that name prefix, never by region.
Corner.Hide=table.freeze({"W7_NestHalo__glow_warm","W7_Stations__foliage"})
Corner.SplitPrefix="W7_EggsStation__"
Corner.Aero=table.freeze({"EggDome","GlossLip_Eggs"})
-- The dropped egg is the loose egg scaled up (R1: 0.66 -> 0.72 wide); EggMachineData's own `dropScale` wins when present.
Corner.DropScale=.72/.66

-- The machine's data (branch claude/egg-machine, src/shared/EggMachineData.lua, r3): the generated module when it is
-- there, else this copy of its numbers (machine-local studs, origin on the ground at the base's centre, +Z the front).
Corner.MachineData=table.freeze({
	model="EggMachine",size={4.2,7.2,3.8},front={0,0,1},dialFace={0,0,1},
	pivots={Dial={0,1.95,1.7014},Sprout={0,7.08,0}},
	egg={size={.6578,.86,.6578}},cup={1.25,.1,1.75},chute={top={1.05,1.1,1.5886},["end"]={1.25,.55,1.95}},light={0,5,0},
	eggTypes={Toy="#FFB340",Hue="#FF7AB8",Material="#8FF0E4",Feature="#9CFFDD",Stat="#FF8A5C"},
	loose={{at={.1745,5.5551,.721},type="Feature"},{at={.6489,5.5472,.2441},type="Material"},{at={.4453,5.5766,-.3768},type="Feature"},
		{at={-.2363,5.5907,-.521},type="Hue"},{at={-.6801,5.5834,-.0441},type="Feature"},{at={-.4847,5.5491,.5768},type="Stat"}},
})
function Corner.machineData()
	local module=Shared:FindFirstChild("EggMachineData")
	if module then
		local ok,data=pcall(require,module)
		if ok and type(data)=="table"and type(data.pivots)=="table"and type(data.loose)=="table"then return data end
	end
	return Corner.MachineData
end
function Corner.dropScale(data)
	data=data or Corner.machineData()
	return if type(data.dropScale)=="number"and data.dropScale>0 then data.dropScale else Corner.DropScale
end
-- Beta (34) "the leaf at the bottom of the spout is clipping into the egg": the dropped egg's path, machine-local. The
-- old path ran the egg's centre down the leaf chute's own centre line (chute top to chute end) and seated it in the
-- cup's middle, so the leaf cut .35 deep into the 0.72 x 0.94 egg the whole roll and the curled tip stayed .156 inside
-- the egg while it sat in the cup. The leaf's lower half hangs nearly upright through the cup's front half (its tip
-- 0.2 to 0.26 in front of the cup's centre, 0.59 to 0.70 up), so the only clear seat is the cup's back right, and no
-- path from the leaf reaches it without crossing the leaf (worked through in the spec on scripts/build_egg_machine.py's
-- chute). The egg now comes out of the belly under the leaf: it starts hidden inside the base, slides out over the cup's
-- back lip and settles in the back of the cup, the leaf's tip in front of it. Clearance to the leaf (the egg's own
-- profile at dropScale against the chute's top and under faces): 0.019 or more all the way and seated, 0.013 at the
-- landing rock's peak. The cup's straw lip brushes the egg's base as it slides over (0.19 at most, about 0.1 s).
-- A path that rides the leaf needs the chute mesh changed (its tip out of the cup), not these numbers.
-- ChuteTop / ChuteEnd / CupSeat keep their names (the client binds them): from, exit, seat.
Corner.DropSeat=Vector3.new(.04,0,-.19)   -- from the cup's centre on the floor (+ half the dropped egg's height)
Corner.DropFrom=Vector3.new(0,.431,-.96)  -- from the seat: hidden inside the belly
Corner.DropExit=Vector3.new(0,.071,-.22)  -- from the seat: out of the belly, over the cup's back lip
-- Beta (35) "the leaf is still in the way, can we just make it a hole": the egg comes out of a round hole in the belly.
-- The leaf is baked into the Body mesh (build_egg_machine.py build_body), so the client cannot remove it; the client
-- draws the hole (EggMachineClient: a dark recessed disc and a rim) where the egg's path crosses the belly. Rebuilt with
-- LEAF_CHUTE = False the script leaves the leaf out and writes `leafless` into the data (egg_machine_assets.py): then
-- the hole sits higher, right over the cup's back lip, and the egg pops straight out along the belly's normal and drops
-- into the cup's middle. Until then (the leaf still in the mesh) the beta 34 path under the leaf stays, its hole where
-- that path leaves the belly.
-- The belly (BASE_PROFILE and BASE_DEPTH in build_egg_machine.py): radius by height, the front squashed by Depth.
Corner.Belly=table.freeze({profile=table.freeze({{1.35,.37},{1.85,.7},{2.1,1.4},{2.0,2.0},{1.8,2.55},{1.6,2.95}}),depth=1.8/2.1,bottom=.35})
-- The hole: Spot (x, y) on the belly's surface (the leafless mesh), the egg starts In behind it and leaves Out in front,
-- both along the belly's normal; Radius the clear opening, Rim the rim's tube radius (it rides the opening's edge).
-- Under the leaf (the mesh as uploaded) no hole fits: the beta 34 path leaves the belly .2 above its bottom, so any
-- opening the egg clears hangs below the belly; the hole waits for the leafless Body.
Corner.Hole=table.freeze({spot=Vector2.new(1.29,1.1),inside=.55,out=.45,radius=.5,rim=.06})
-- Spencer (render-path-mouth, after beta 36) "shouldn't it have a hole or something for the egg to come out of": the
-- Body bakes a real mouth at the hole (build_egg_machine.py MOUTH; the data says `mouth`): the belly cut, a throat in
-- along the normal to a dark cavity the egg starts in, a rounded lip in the band's tan. Its profiles, mirrored from the
-- build (which refuses to build when these differ): cavity {rho, h} from the back's middle out to the throat, h along
-- the normal from the hole's centre plane; lip {rho, h} from the throat's top over the lip to its foot, h along the
-- normal over the belly's surface at that rho. The clear opening is Hole.radius (the throat, the lip's inner edge).
Corner.Mouth=table.freeze({cavity={{0,-1},{.36,-.92},{.56,-.62},{.5,-.24}},lip={{.5,-.05},{.505,.04},{.545,.09},{.6,.105},{.66,.085},{.7,.035},{.72,0}},segments=24})
function Corner.bellyRadius(y)
	local profile=Corner.Belly.profile
	if y<=profile[1][2]then return profile[1][1]end
	for i=1,#profile-1 do
		local r0,y0,r1,y1=profile[i][1],profile[i][2],profile[i+1][1],profile[i+1][2]
		if y>=y0 and y<=y1 then return r0+(r1-r0)*(y-y0)/(y1-y0)end
	end
	return profile[#profile][1]
end
-- < 0 inside the belly, 0 on its surface, > 0 outside (and below its bottom). Machine-local.
function Corner.belly(p)
	if p.Y<Corner.Belly.bottom or p.Y>Corner.Belly.profile[#Corner.Belly.profile][2]then return 1 end
	local r=Corner.bellyRadius(p.Y)
	return(p.X/r)^2+(p.Z/(r*Corner.Belly.depth))^2-1
end
function Corner.bellyNormal(p)
	local e=1e-4
	local g=Vector3.new(Corner.belly(p+Vector3.new(e,0,0))-Corner.belly(p-Vector3.new(e,0,0)),
		Corner.belly(p+Vector3.new(0,e,0))-Corner.belly(p-Vector3.new(0,e,0)),Corner.belly(p+Vector3.new(0,0,e))-Corner.belly(p-Vector3.new(0,0,e)))
	return g.Unit
end
-- The mesh has no leaf (rebuilt with LEAF_CHUTE = False).
function Corner.leafless(data)return type(data)=="table"and data.leafless==true end
-- The Body has the baked mouth (built with MOUTH): the client draws no hole of its own. Only on the leafless Body.
function Corner.mouth(data)return Corner.leafless(data)and data.mouth==true end
function Corner.dropPoints(data)
	data=data or Corner.machineData()
	local cup=data.cup
	local half=Vector3.new(0,data.egg.size[2]*Corner.dropScale(data)/2,0)
	if Corner.leafless(data)then
		local h=Corner.Hole
		local x,y=h.spot.X,h.spot.Y
		local centre=Vector3.new(x,y,Corner.Belly.depth*math.sqrt(Corner.bellyRadius(y)^2-x*x))
		local normal=Corner.bellyNormal(centre)
		return{from=centre-normal*h.inside,exit=centre+normal*h.out,seat=Vector3.new(cup[1],cup[2],cup[3])+half}
	end
	local seat=Vector3.new(cup[1],cup[2],cup[3])+Corner.DropSeat+half
	return{from=seat+Corner.DropFrom,exit=seat+Corner.DropExit,seat=seat}
end
-- The hole the egg comes out of: where its path (from -> exit) crosses the belly, facing out. {centre, normal, radius,
-- rim}, machine-local; nil while the Body still has its leaf.
function Corner.hole(data)
	data=data or Corner.machineData()
	if not Corner.leafless(data)then return nil end
	local drop=Corner.dropPoints(data)
	local lo,hi=0,1
	for _=1,40 do
		local mid=(lo+hi)/2
		if Corner.belly(drop.from:Lerp(drop.exit,mid))<0 then lo=mid else hi=mid end
	end
	local centre=drop.from:Lerp(drop.exit,lo)
	local h=Corner.Hole
	return{centre=centre,normal=Corner.bellyNormal(centre),radius=h.radius,rim=h.rim}
end
-- STANDING RULE (Spencer, beta 35: "we need all eggs to have the crank animation, even in the future for eggs"): every
-- egg bought or granted comes out of the machine. One row per EggModels.Order type the machine sells: `drop` its name
-- here (its colour in EggMachineData.eggTypes, its shell EggModels.Types[type]), `actions` the sends that buy it (the
-- press arms the crank), `reveal` how its reveal waits for the egg in the cup (EggMachineClient:deliver, the one path):
--   "cinematic"  a HatchCinematic reveal (HatchCinematic.onPlay hands it to deliver): its clock held, off the screen
--   "deferred"   its own reveal module: deliver opens it only at the hand-off (SnackHost for the Stat Egg)
-- Medal eggs are Stat Eggs (statEggBuy, free): the same row. A type the machine does not sell is in NotMachine with
-- the reason; every other `...Buy` send in the game is in OtherBuys. scripts/EggDelivery.spec.lua fails for an
-- EggModels type in neither table, a send in no table, or an Eggs row whose reveal is not routed.
Corner.Eggs=table.freeze({
	toy=table.freeze({drop="Toy",actions=table.freeze({"toyBuy"}),reveal="cinematic"}),
	material=table.freeze({drop="Material",actions=table.freeze({"materialBuy"}),reveal="cinematic"}),
	-- The Customization Egg (lookBuy) wears the Hue art.
	hue=table.freeze({drop="Hue",actions=table.freeze({"hueBuy","lookBuy"}),reveal="cinematic"}),
	feature=table.freeze({drop="Feature",actions=table.freeze({"featureBuy"}),reveal="cinematic"}),
	-- `host`: the client module that opens a deferred reveal (through the machine's deliver).
	stat=table.freeze({drop="Stat",actions=table.freeze({"statEggBuy"}),reveal="deferred",host="SnackHost"}),
})
Corner.NotMachine=table.freeze({
	companion="the pet's own egg: it hatches in the Sleepy Nest (the arrival hatch and the First Hatch's crack ritual), never sold by the machine",
})
-- Every other `...Buy` send: not an egg, or (nameEggBuy) an egg sold on the naming screen with no shell in EggModels
-- (Spencer to rule whether it comes out of the machine too).
Corner.OtherBuys=table.freeze({ballThemeBuy="a ball theme (shop)",faceplateBuy="a faceplate (shop)",wearableBuy="a wearable (shop)",
	potBuy="a paint pot (PAINT-SHINE-DRESS-PLAN), not an egg: no longer sold (beta 38, gacha only; the server refuses it and only replays a buy already saved)",
	nameEggBuy="the Names Egg: bought on the naming screen (Companions, Name), its own NameEggReveal; no shell in EggModels"})
-- The buy actions (the press starts the buy crank) and the egg each drops: from Eggs.
local buyActions={}
for _,row in pairs(Corner.Eggs)do for _,action in ipairs(row.actions)do buyActions[action]=row.drop end end
Corner.BuyActions=table.freeze(buyActions)
-- The EggModels type id for a drop name ("Stat" -> "stat"), and the row.
function Corner.eggType(drop)return if type(drop)=="string"then string.lower(drop)else nil end
function Corner.eggRow(drop)return Corner.Eggs[Corner.eggType(drop)or ""]end

-- ── Switch and data switches ─────────────────────────────────────────────────────────────────────────────────────
function Corner.ceiling()return Onboard.ceiling()end
function Corner.on()return Onboard.on("corner")end
local function worldData(data)
	if data then return data end
	local ok,found=pcall(function()return require(Shared.WorldV7Data)end)
	return if ok and type(found)=="table"then found else {}
end
-- The re-export split the old station out (any W7_EggsStation__* part).
function Corner.split(data)
	data=worldData(data)
	for name in pairs(data.parts or {})do
		if type(name)=="string"and string.sub(name,1,#Corner.SplitPrefix)==Corner.SplitPrefix then return true end
	end
	return false
end

-- ── Layout ─────────────────────────────────────────────────────────────────────────────────────────────────────────
-- The machine's frame on floor `y`: +Z (the front) looks at Face.
function Corner.frame(y)
	local at=Corner.Spot
	y=y or at.Y
	return CFrame.lookAt(Vector3.new(at.X,y,at.Z),Vector3.new(Corner.Face.X,y,Corner.Face.Z))*CFrame.Angles(0,math.pi,0)
end
function Corner.promptFrame(y)return Corner.frame(y)*CFrame.new(Corner.PromptAt)end
-- Where the Hatch eggs trail ends: TrailAhead in front of the machine.
function Corner.trailEnd(y)
	local frame=Corner.frame(y)
	-- The frame is turned by pi, so the front (local +Z) is -LookVector.
	return frame.Position-frame.LookVector*Corner.TrailAhead
end
-- The Eggs pin's height over the machine's floor: the model's top + PinLift (Height without a model).
function Corner.pinHeight(top)
	return(if type(top)=="number"and top>0 then top else Corner.Height)+Corner.PinLift
end
-- Where the nest stands: the old station's spot once the station is split out and the corner is on; else Nest.Spot.
function Corner.nestSpot(on,split)
	if on==nil then on=Corner.on()end
	if split==nil then split=Corner.split()end
	return if on and split then Corner.NestSpot else Nest.Spot
end
function Corner.nestFacing()return Corner.NestFacing end
-- EggNestLight: {offset, range} for the corner on / off, over the old station's spot.
function Corner.light(on)
	local l=if on then Corner.Light else Corner.Light.was
	return Vector3.new(0,l.lift,0),l.range
end

-- ── The nest's straw scatter and contact shadow (R2 3), root-local ─────────────────────────────────────────────────
-- 12 flat strands and 3 fallen leaves, radius 2.7 to 3.6, two thirds on the tree side (the hatch tree, north-west of the
-- nest), none within 1.0 of the Bear spot or on the prompt point. Fixed, so every client draws the same.
Corner.Tree=Vector3.new(-36,0,-18)
Corner.ScatterAvoid=1.0
function Corner.scatter(root,bear,prompt,inner,outer)
	inner,outer=inner or 2.7,outer or 3.6
	local toTree=root:VectorToObjectSpace(Vector3.new(Corner.Tree.X-root.X,0,Corner.Tree.Z-root.Z)).Unit
	local treeAngle=math.atan2(toTree.X,toTree.Z)
	local out={}
	local function free(p)
		return(Vector2.new(p.X-bear.X,p.Z-bear.Z)).Magnitude>Corner.ScatterAvoid
			and(Vector2.new(p.X-prompt.X,p.Z-prompt.Z)).Magnitude>Corner.ScatterAvoid
	end
	-- Golden-angle spread: 10 of 15 inside +-70 degrees of the tree's bearing, the rest round the far side.
	local k,tries=0,0
	while #out<15 and tries<200 do
		tries+=1
		k+=1
		local near=#out<10
		local spread=if near then math.rad(70)else math.rad(110)
		local base=if near then treeAngle else treeAngle+math.pi
		local a=base+spread*(((k*0.618034)%1)*2-1)
		local r=inner+(outer-inner)*((k*0.381966)%1)
		local p=Vector3.new(math.sin(a)*r,0,math.cos(a)*r)
		if free(p)then
			local leaf=#out>=12
			table.insert(out,{at=p,yaw=math.deg(a)+((k*37)%60)-30,length=if leaf then .3 else .5+.4*((k*0.7548776)%1),leaf=leaf})
		end
	end
	return out
end
-- The contact shadow: concentric discs that add up to about 22% black in the middle and fade to 0 at r 3.0.
Corner.Shadow=table.freeze({radius=3,rings=6,transparency=.96})

return table.freeze(Corner)
