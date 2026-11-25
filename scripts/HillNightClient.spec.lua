-- The hill at night on the client (WORLD-FINISH-LOOK slice F): HillNightClient with fakes (the den's panes and lamps,
-- the daylight, the gate, the tier), and LifeSim's firefly pool with the terrace's spots (the same draws without them).
-- Usage (Client): require(ZZSpecs.HillNightClient)(StarterPlayerScripts.Client, workspace)
-- Offline: python scripts/run_dash_server_specs.py
return function(client,parent)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Night=require(Shared.HillNight)
	local Hill=require(client.HillNightClient)
	local Sim=require(client.LifeSim)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end

	local function den(room)
		local model=Instance.new("Model");model.Name="PlayDen"
		local pane=Instance.new("Part");pane.Name="W7_F_Lantern__pane";pane.Color=Color3.fromHex("#C9772E");pane.Parent=model
		local row=Instance.new("Part");row.Name="W7D_Lantern1";row.Parent=model
		local light=Instance.new("PointLight");light.Brightness=.9;light.Parent=row
		model.Parent=room
		return model,pane,light
	end

	test("the lanterns lift at night without leaving their hue; the lamps graded; the gate off puts every value back",function()
		local room=Instance.new("Model");room.Parent=parent or workspace
		local model,pane,light=den(room)
		local daylight,gate,tier=1,true,true
		local h=Hill.mount({daylight=function()return daylight end,gate=function()return gate end,tierOn=function()return tier end,
			room=function()return room end,parent=parent or workspace,heartbeat=false,now=function()return 0 end,spots={}})
		local ok,err=pcall(function()
			h:step(.3)
			assert(near(pane.Color.R,Color3.fromHex("#C9772E").R),"by day: its own colour")
			assert(light:GetAttribute("HollowLamp")==true and near(light:GetAttribute("HollowDayBrightness"),Night.LightDay))
			daylight=0;h:step(.3)
			assert(near(pane.Color.R,1,1e-6)and near(pane.Color.R/pane.Color.G,201/119,1e-3),"at night: lifted, still amber")
			assert(near(light:GetAttribute("HollowNightBrightness"),Night.LightNight))
			assert(near(h.folder:GetAttribute("HillLift"),1.5,1e-3),"the lift for probes")
			-- The den closes (its model goes): let go at once; a new den is lifted.
			model.Parent=nil;h:step(.3)
			assert(h.den==nil and next(h.panes)==nil and next(h.lights)==nil,"the old den let go")
			local model2,pane2=den(room)
			h:step(.3)
			assert(h.den==model2 and near(pane2.Color.R,1,1e-6),"the new den lifted")
			gate=false;h:step(.3)
			assert(near(pane2.Color.R,Color3.fromHex("#C9772E").R),"put back")
			assert(h.folder:GetAttribute("HillOn")==false)
			gate=true;h:step(.3)
			local _,_,light3=model2,pane2,model2:FindFirstChild("W7D_Lantern1"):FindFirstChildOfClass("PointLight")
			gate=false;h:step(.3)
			assert(light3:GetAttribute("HollowLamp")==nil and near(light3.Brightness,.9),"the lamp put back")
		end)
		h:destroy();room:Destroy();assert(ok,err)
	end)

	test("glow-caps: none made by day, in at dusk, hidden with the tier closed; never collide, query or cast a shadow",function()
		local room=Instance.new("Model");room.Parent=parent or workspace
		local daylight,tier=1,true
		local spots={{position=Vector3.new(0,5,0),seed=1,cluster=3},{position=Vector3.new(4,5,0),seed=2,cluster=2}}
		local h=Hill.mount({daylight=function()return daylight end,gate=function()return true end,tierOn=function()return tier end,
			room=function()return room end,parent=parent or workspace,heartbeat=false,now=function()return 0 end,spots=spots})
		local ok,err=pcall(function()
			h:step(.3)
			assert(#h.caps==0,"none made by day")
			daylight=.3;h:step(.3)
			assert(#h.caps==5,"five caps")
			for _,c in ipairs(h.caps)do
				for _,p in ipairs({c.cap,c.stem})do assert(not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow and p.Anchored)end
				assert(near(c.cap.Transparency,Night.CapTransparency,1e-6)and c.stem.Transparency==0)
			end
			tier=false;h:step(.3)
			for _,c in ipairs(h.caps)do assert(c.cap.Transparency==1 and c.stem.Transparency==1)end
		end)
		h:destroy();room:Destroy();assert(ok,err)
	end)

	test("LifeSim: the terrace's firefly spots join the pool only when set; without them the same picks as before",function()
		local camera=Vector3.new(0,10,0)
		local world={camera=camera,player=camera,ground=function()return 4 end,safe=function()return true end}
		local patches={Vector3.new(5,4,5),Vector3.new(-6,4,2)}
		local picks={}
		local r1=Random.new(42)
		for i=1,20 do picks[i]=Sim.fireflySpot(r1,world,{patches=patches,banks={}},{})end
		local r2=Random.new(42)
		for i=1,20 do assert(Sim.fireflySpot(r2,world,{patches=patches,banks={},terrace=nil},{})==picks[i],"the same draws")end
		local terrace={Vector3.new(10,29,0)}
		local seen=false
		local r3=Random.new(7)
		for _=1,60 do if Sim.fireflySpot(r3,world,{patches={},banks={},terrace=terrace},{})==terrace[1]then seen=true end end
		assert(seen,"a terrace spot is picked when set")
	end)

	return{passed=#cases,cases=cases}
end
