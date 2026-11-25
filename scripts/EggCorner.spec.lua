-- The egg corner's numbers and switches (EggCorner; EGG-CORNER-LOOK and its Placement rulings R2; EGG-CORNER-BUILD-PLAN):
-- the machine at M5 facing (-26, 7), reach 7, its box, trail end and pin; the plaza's 12-stud rule; the nest's spot by
-- the switch and the island split; the light; the hide list and the split prefix; the buy actions; the straw scatter.
-- Pure data plus the world data; no Studio needed.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.EggCorner)(ServerScriptService.Server); offline in
-- scripts/run_dash_server_specs.py.
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Corner=require(Shared.EggCorner)
	local Nest=require(Shared.Nest)
	local Onboard=require(Shared.Onboard)
	local Layout=require(Shared.HollowWorldLayout)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function flat(a,x,z)return math.sqrt((a.X-x)^2+(a.Z-z)^2)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-3)end

	test("the machine stands at M5 (-41, 2), front (+Z) toward (-26, 7), Turn reach 7 (R2 1: the bench went in the declutter)",function()
		assert(Corner.Spot.X==-41 and Corner.Spot.Z==2 and Corner.Reach==7)
		local frame=Corner.frame(4.13)
		local front=frame.LookVector*-1 -- turned by pi: +Z is the front
		local want=(Vector3.new(-26,4.13,7)-frame.Position).Unit
		assert(front:Dot(want)>.9999,tostring(front))
		assert(near(frame.Position.Y,4.13))
	end)
	test("the plaza's 12-stud rule: the machine, the nest, the Style deck, the care arch and the toy lawn",function()
		local spots={{"machine",Corner.Spot.X,Corner.Spot.Z},{"nest",-31,-11},{"Style deck",-46,-9},{"care arch",-17,-15},{"toy lawn",-30,18.5}}
		for i=1,#spots do for j=i+1,#spots do
			local a,b=spots[i],spots[j]
			local d=math.sqrt((a[2]-b[2])^2+(a[3]-b[3])^2)
			assert(d>=12,a[1].." to "..b[1]..string.format(" %.2f",d))
		end end
	end)
	test("the machine's probe ring (r 2.8) stays on the paving (r 15.5 round (-30, -4)) and off the Blossom path mouth (-44, -2)",function()
		local reach=flat(Corner.Spot,-30,-4)+2.8
		assert(reach<=15.5,string.format("%.2f",reach))
		assert(flat(Corner.Spot,-44,-2)>=4.5)
	end)
	test("the prompt sits in front of the dial, outside the pets' box; the trail ends 3 in front; the pin is top + 1.6",function()
		local frame=Corner.frame(4.13)
		local prompt=Corner.promptFrame(4.13).Position
		local into=frame:PointToObjectSpace(prompt)
		assert(near(into.Z,2.6)and near(into.Y,2.2)and into.Z>Corner.Block.Z/2)
		local trail=Corner.trailEnd(4.13)
		local local3=frame:PointToObjectSpace(trail)
		assert(near(local3.Z,3)and near(local3.X,0),tostring(local3))
		assert(Corner.pinHeight(7.2)==8.8 and Corner.pinHeight(nil)==Corner.Height+1.6 and Corner.pinHeight(7.6)==9.2)
		assert(Corner.Ring==3 and Corner.Block==Vector3.new(4.8,1,4.4))
	end)
	test("the nest: Nest.Spot (E1) unless the corner is on AND the station is split out; then (-31, -11) facing the plaza middle",function()
		assert(Corner.nestSpot(false,false)==Nest.Spot and Corner.nestSpot(false,true)==Nest.Spot and Corner.nestSpot(true,false)==Nest.Spot)
		assert(Corner.nestSpot(true,true)==Vector3.new(-31,4.07,-11)and Corner.nestFacing()==Nest.Facing)
		-- On the paving between the star (r 3.2) and the inlay ring (10.4): the fringe (r 2.57) clears both (R2 3).
		local d=flat(Corner.NestSpot,-30,-4)
		assert(d-2.57>3.2 and d+2.57<10.4,string.format("%.2f",d))
	end)
	test("split(): any W7_EggsStation__* part (the island split, by name; the halo keeps region NestHalo)",function()
		assert(not Corner.split({parts={W7_Stations__marble={region="Stations"},W7_NestHalo__glow_warm={region="NestHalo"}}}))
		assert(Corner.split({parts={W7_EggsStation__glow_warm={region="NestHalo"}}}))
		assert(Corner.split({parts={W7_EggsStation__marble={region="EggsStation"}}}))
		assert(not Corner.split({}))
		assert(Corner.SplitPrefix=="W7_EggsStation__")
		-- The island carries the split now (claude/eggs-station-split, native pack 326424 bytes).
		assert(Corner.split()==true)
	end)
	test("what the beta hides now: the halo, the cup's leaves, the Aero dome and the Eggs lip",function()
		assert(table.find(Corner.Hide,"W7_NestHalo__glow_warm")and table.find(Corner.Hide,"W7_Stations__foliage")and #Corner.Hide==2)
		assert(table.find(Corner.Aero,"EggDome")and table.find(Corner.Aero,"GlossLip_Eggs"))
	end)
	test("EggNestLight: +4 / range 10 off, +2.5 / range 8 on (the nest's warm light)",function()
		local offOffset,offRange=Corner.light(false)
		local onOffset,onRange=Corner.light(true)
		assert(offOffset==Vector3.new(0,4,0)and offRange==10 and onOffset==Vector3.new(0,2.5,0)and onRange==8)
		-- The old station is still the light's spot (the nest moves there).
		assert(Layout.Stations.Eggs.Position.X==-31 and Layout.Stations.Eggs.Position.Z==-11)
	end)
	test("the buy actions and the egg each drops (the Customization Egg wears the Hue art); the drop scale",function()
		local B=Corner.BuyActions
		assert(B.toyBuy=="Toy"and B.hueBuy=="Hue"and B.lookBuy=="Hue"and B.materialBuy=="Material"and B.featureBuy=="Feature"and B.statEggBuy=="Stat")
		assert(B.nameEggBuy==nil and B.wearableBuy==nil)
		local data=Corner.machineData()
		for _,kind in pairs(B)do assert(data.eggTypes[kind],kind)end
		assert(near(Corner.dropScale({}),.72/.66)and Corner.dropScale({dropScale=1.2})==1.2)
		assert(#data.loose==6 and data.pivots.Dial and data.pivots.Sprout and data.chute.top and data.chute["end"]and data.cup)
	end)
	test("the straw scatter: 12 strands and 3 leaves, r 2.7 to 3.6, two thirds toward the tree, clear of the Bear and the prompt",function()
		local root=CFrame.lookAt(Vector3.new(-31,4.07,-11),Vector3.new(-30,4.07,-4))
		local bear,prompt=Vector3.new(-2.2,0,-1.4),Vector3.new(0,0,-2.6)
		local bits=Corner.scatter(root,bear,prompt)
		assert(#bits==15,#bits)
		local leaves,toward=0,0
		local tree=root:VectorToObjectSpace(Vector3.new(Corner.Tree.X-root.X,0,Corner.Tree.Z-root.Z)).Unit
		for _,bit in ipairs(bits)do
			local r=Vector2.new(bit.at.X,bit.at.Z).Magnitude
			assert(r>=2.7-1e-6 and r<=3.6+1e-6,r)
			assert((Vector2.new(bit.at.X-bear.X,bit.at.Z-bear.Z)).Magnitude>1 and(Vector2.new(bit.at.X-prompt.X,bit.at.Z-prompt.Z)).Magnitude>1)
			if bit.leaf then leaves+=1 end
			if Vector3.new(bit.at.X,0,bit.at.Z).Unit:Dot(tree)>0 then toward+=1 end
		end
		assert(leaves==3 and toward>=10,leaves..","..toward)
		assert(#Corner.scatter(root,bear,prompt)==15) -- fixed: every client draws the same
	end)
	test("the switch is an onboarding v3 part: off the ceiling (live) it is off",function()
		Onboard.inject({flags={OnboardingV3=false},studio=true})
		assert(not Corner.on()and not Corner.ceiling())
		Onboard.inject({flags={OnboardingV3=true},studio=true,corner=false})
		assert(not Corner.on()and Corner.ceiling())
		Onboard.inject({flags={OnboardingV3=true},studio=true})
		assert(Corner.on())
		Onboard.inject(nil)
	end)
	test("beta (16) B2: the machine's prompt says what it does (Hatch eggs, on the Egg machine), localized",function()
		local UICopy=require(Shared.UICopy)
		assert(UICopy.get("r5.station.Eggs.name")=="Hatch eggs"and UICopy.get("r5.station.Eggs.machine")=="Egg machine")
	end)
	return{passed=#cases,cases=cases}
end
