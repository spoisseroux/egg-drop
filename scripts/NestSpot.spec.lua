-- The nest in the plaza (beta 12 QA O2; GARDEN-LIFE-NEST-LOOK 4, spot A): Nest.Spot keeps Fable's clearances from
-- the stations, the Dash course and pad, the arrival walking line, the flower patches and the firefly areas, faces the
-- plaza's middle, and the server keeps pets off its square (one GardenBlockedRegion box in LoungeWorldV7Art, only
-- with the onboarding v3 ceiling: beta and Studio). Pure data plus the world build; no Studio needed.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.NestSpot)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Nest=require(Shared.Nest)
	local Layout=require(Shared.HollowWorldLayout)
	local Course=require(Shared.DashCourse)
	local Dressing=require(Shared.WorldDressing)
	local Aero=require(Shared.WorldAero)
	local Onboard=require(Shared.Onboard)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function flat(a,x,z)return math.sqrt((a.X-x)^2+(a.Z-z)^2)end
	local function segment(px,pz,ax,az,bx,bz)
		local dx,dz=bx-ax,bz-az
		local length=dx*dx+dz*dz
		local t=if length>0 then math.clamp(((px-ax)*dx+(pz-az)*dz)/length,0,1)else 0
		return math.sqrt((px-ax-dx*t)^2+(pz-az-dz*t)^2)
	end
	local spot=Nest.Spot
	local Plaza=Vector3.new(-30,0,-4)

	test("spot A: (-17.5, 4.07, -2.5) on the plaza's east rim, 12.6 from its middle, facing it",function()
		assert(spot==Vector3.new(-17.5,4.07,-2.5),tostring(spot))
		assert(math.abs(flat(spot,Plaza.X,Plaza.Z)-12.59)<.05,"on the rim")
		assert(Nest.Facing==Vector3.new(-30,4.07,-4)and Nest.Block==5.5)
	end)

	test("clear of every station, the Dash course and pad, the arrival walking line, the flowers and the firefly areas",function()
		local want={Journal=12,Eggs=15,Customize=25,ToyLawn=20,ArrivalDais=100}
		for name,frame in pairs(Layout.Stations)do
			local d=flat(spot,frame.Position.X,frame.Position.Z)
			assert(d>=(want[name]or 8),name..": "..d)
		end
		local best=math.huge
		for _,list in ipairs({Course.Main,Course.Branch})do
			for i=1,#list//4-1 do
				best=math.min(best,segment(spot.X,spot.Z,list[i*4-2]/100,list[i*4]/100,list[i*4+2]/100,list[i*4+4]/100))
			end
		end
		assert(best>=12,"the Dash course: "..best)
		assert(flat(spot,Course.Pad.x/100,Course.Pad.z/100)-Course.Pad.r/100>=10,"the waiting pad")
		local route=Layout.Routes.ArrivalToHub
		local line=math.huge
		for i=1,#route-1 do line=math.min(line,segment(spot.X,spot.Z,route[i].X,route[i].Y,route[i+1].X,route[i+1].Y))end
		assert(line>=9,"the arrival walking line: "..line)
		for _,row in ipairs(Dressing.Flowers or {})do
			assert(flat(spot,row[1],row[3])>=Nest.Block/2+2,"a flower patch under the fringe: "..row[1]..", "..row[3])
		end
		for _,area in ipairs(Aero.Fireflies.Areas)do assert(flat(spot,area.x,area.z)>=10+area.width,area.name)end
	end)

	test("the server keeps pets off the nest's square: one GardenBlockedRegion, 5.5 studs, at the spot (Onboarding v3 places only)",function()
		local room=Instance.new("Folder")
		local ok,problem=pcall(function()require(server.LoungeWorldV7Art).collision(room)end)
		assert(ok,problem)
		local regions=room:FindFirstChild("PetRegions")
		local box=regions and regions:FindFirstChild("SleepyNest")
		if Onboard.ceiling()then
			assert(box,"the box is there with the ceiling on")
			assert(box:GetAttribute("GardenBlockedRegion")==true and box.CanCollide==false and box.Transparency==1)
			assert(box.Size==Vector3.new(5.5,1,5.5))
			local at=box.CFrame.Position
			assert(math.abs(at.X-spot.X)<1e-6 and math.abs(at.Z-spot.Z)<1e-6)
		else
			assert(box==nil,"no box without the ceiling (live)")
		end
		assert(Onboard.ceiling({place=96451847774961,studio=false})==false,"live: never")
	end)

	return{passed=#cases,cases=cases}
end
