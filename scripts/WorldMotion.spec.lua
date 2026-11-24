-- Studio Client. WorldMotion's arch chimes (beta 14 QA W3 row 2; GARDEN-LIFE-BUILD-PLAN section 4): with the Alive
-- `scene` switch on they swing along the wind about their hanging point, (3 + 11 g) degrees at .45 Hz, at 15 Hz (8 at
-- budget level 1) and only within 70 studs; off, and on the live place (the ceiling), today's sway exactly.
-- Usage: require(PlayerScripts.Client.ZZSpecs.WorldMotion)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="WorldMotion").
return function(client)
	local Motion=require(client.WorldMotion)
	local Wind=require(client.Wind)
	local Alive=require(game:GetService("ReplicatedStorage").Shared.Alive)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local LIVE=96451847774961
	local side=Vector3.new(-Wind.Direction.Z,0,Wind.Direction.X)

	-- A room with one chime and one pennant mover.
	local function room()
		local lounge=Instance.new("Folder");lounge.Name="_WorldMotionSpec"
		local world=Instance.new("Folder");world.Name="World";world.Parent=lounge
		local function mover(name,region,at)
			-- (The offline mock answers IsA by ClassName alone.)
			local p=Instance.new("BasePart");p.Name=name;p.Size=Vector3.new(.5,3,.5)
			local rest=CFrame.new(at)
			p.CFrame=rest
			p:SetAttribute("WorldMotion","sway");p:SetAttribute("WorldRegion",region);p:SetAttribute("WorldRestCFrame",rest)
			p:SetAttribute("WorldPivot",at+Vector3.new(0,1.5,0))
			p:SetAttribute("WorldMotionAmp",7);p:SetAttribute("WorldMotionPeriod",3);p:SetAttribute("WorldMotionPhase",.2)
			p.Parent=world
			return p
		end
		return lounge,mover("W7_Chime_2__palette","Chime_2",Vector3.new(86,14,56)),mover("W7_Pennant_1__palette","Pennant_1",Vector3.new(80,14,50))
	end
	local function motion(scene,lounge)
		local m=Motion.new(workspace)
		m.reduced=function()return false end
		m.slow=function()return false end
		m.alive={on=function(feature)return feature=="scene"and scene()end}
		m:bind(lounge)
		return m
	end

	test("the chime pose: (3 + 11 g) degrees along the wind about the hanging point; its number from the region",function()
		assert(Motion.chimeNumber("Chime_4")==4 and Motion.chimeNumber("Pennant_1")==nil and Motion.chimeNumber(nil)==nil)
		local rest=CFrame.new(86,14,56)
		local pivot=Vector3.new(86,15.5,56)
		local most={[0]=0,[1]=0}
		for _,g in ipairs({0,1})do
			for i=0,400 do
				local frame=Motion.chimePose(rest,pivot,g,i*.01,2)
				local tilt=math.deg(math.acos(math.clamp(frame.UpVector.Y,-1,1)))
				most[g]=math.max(most[g],tilt)
				assert(math.abs(frame.UpVector:Dot(side))<1e-6,"swings along the wind, not across it")
				assert((frame*Vector3.new(0,1.5,0)-pivot).Magnitude<1e-6,"the hanging point stays")
			end
		end
		assert(near(most[0],3,.05)and near(most[1],14,.05),"3 calm, 14 in a full gust: "..most[0].." "..most[1])
	end)

	test("scene on: the chime takes its own swing at 15 Hz near the camera; the pennant keeps today's",function()
		local lounge,chime,pennant=room()
		local m=motion(function()return true end,lounge)
		local writes,last=0,chime.CFrame
		for i=1,60 do
			m:apply(10+i/30)
			if chime.CFrame~=last and(chime.CFrame.Position~=last.Position or chime.CFrame.UpVector~=last.UpVector)then writes+=1;last=chime.CFrame end
		end
		assert(writes>=28 and writes<=31,"15 Hz over 2 s: "..writes)
		assert(math.abs(chime.CFrame.UpVector:Dot(side))<1e-6,"the new swing")
		local t=12
		m:apply(t)
		assert(pennant.CFrame.Position==Motion.pose("sway",pennant:GetAttribute("WorldRestCFrame"),pennant:GetAttribute("WorldPivot"),7,3,.2,t).Position)
	end)

	test("scene off, and the live place (the ceiling): the chime keeps today's sway exactly",function()
		for _,scene in ipairs({function()return false end,function()return Alive.ceiling("scene",nil,LIVE,false)end})do
			local lounge,chime=room()
			local m=motion(scene,lounge)
			for i=1,30 do
				local t=20+i/30
				m:apply(t)
				local want=Motion.pose("sway",chime:GetAttribute("WorldRestCFrame"),chime:GetAttribute("WorldPivot"),7,3,.2,t)
				assert((chime.CFrame.Position-want.Position).Magnitude<1e-9 and(chime.CFrame.UpVector-want.UpVector).Magnitude<1e-9,"today's pose")
			end
		end
		assert(Alive.ceiling("scene",nil,LIVE,false)==false and Alive.ceiling("snack",nil,LIVE,false)==false,"never on live")
	end)

	return{passed=#cases,cases=cases}
end
