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
Corner.RingArc=200
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
-- The buy actions (the press starts the buy crank) and the egg colour each drops. The Customization Egg wears the Hue art.
Corner.BuyActions=table.freeze({toyBuy="Toy",hueBuy="Hue",lookBuy="Hue",materialBuy="Material",featureBuy="Feature",statEggBuy="Stat"})

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
