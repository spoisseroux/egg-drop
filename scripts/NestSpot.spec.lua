-- Beta 14 D1 (WORLD-AND-NEST-LOOK 3, Nest merge rulings R2): the nest at the Eggs station's east foot (E1), one place
-- for eggs. Earlier: the plaza (beta 12 QA O2; GARDEN-LIFE-NEST-LOOK 4, spot A). Nest.Spot keeps Fable's clearances from
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
	local Walk=require(Shared.GardenWalkability)
	local Catchup=require(Shared.PetCatchup)
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
	local Hub=Layout.Landmarks.Hub

	test("E1: (-25.27, 4.07, -9.80) at the Eggs station's east foot, 5.85 from it, 7.48 from the marble circle's middle, facing it",function()
		assert(spot==Vector3.new(-25.27,4.07,-9.80),tostring(spot))
		local S=Layout.Stations.Eggs.Position
		assert(math.abs(flat(spot,S.X,S.Z)-5.85)<.05 and math.abs(flat(spot,-30,-4)-7.48)<.05)
		-- Fable's (-30, -4), not the layout's Hub (-30, 4): the Studio probe put the Hub facing's prompt on a trim strip.
		assert(Nest.Facing==Vector3.new(-30,4.07,-4)and Hub==Vector2.new(-30,4))
		assert(Nest.Block==4.2 and Nest.Front==2.6)
	end)

	test("clear of every station, the Dash course and pad, the arrival walking line, the flowers and the firefly areas",function()
		-- Beside the Eggs station (part of its corner), clear of every other station.
		local want={Journal=9,Eggs=5.5,Customize=18,ToyLawn=20,ArrivalDais=100}
		for name,frame in pairs(Layout.Stations)do
			local d=flat(spot,frame.Position.X,frame.Position.Z)
			assert(d>=(want[name]or 8),name..": "..d)
		end
		local eggs=Layout.Stations.Eggs.Position
		assert(flat(spot,eggs.X,eggs.Z)<=6.5,"part of the egg corner")
		-- The prompt point is past the nest's own reach from the station's middle, and the walk from the plaza's hub to
		-- the station passes the nest's box by a stride.
		local root=CFrame.lookAt(Vector3.new(spot.X,spot.Y,spot.Z),Vector3.new(Nest.Facing.X,spot.Y,Nest.Facing.Z))
		local front=root*Vector3.new(0,0,-Nest.Front)
		assert(flat(front,eggs.X,eggs.Z)>=4.5,"the prompt point and the station: "..flat(front,eggs.X,eggs.Z))
		assert(segment(spot.X,spot.Z,Hub.X,Hub.Y,eggs.X,eggs.Z)>=Nest.Block/2+1,"the hub-to-Eggs walk")
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

	-- The world built under an Onboarding v3 environment (nil: the real one), its SleepyNest box or nil.
	local function build(env)
		Onboard.inject(env)
		local room=Instance.new("Folder")
		local ok,problem=pcall(function()require(server.LoungeWorldV7Art).collision(room)end)
		Onboard.inject(nil)
		assert(ok,problem)
		local regions=room:FindFirstChild("PetRegions")
		return regions and regions:FindFirstChild("SleepyNest"),regions
	end

	test("the server keeps pets off the nest: one GardenBlockedRegion, turned with the nest, on the beta and in Studio only",function()
		local box=build({flags={OnboardingV3=true},place=107705084891479,studio=false})
		assert(box,"the beta: the box is there")
		assert(box:GetAttribute("GardenBlockedRegion")==true and box.CanCollide==false and box.Transparency==1)
		assert(box.Size==Vector3.new(4.2,1,4.2))
		local at=box.CFrame.Position
		assert(math.abs(at.X-spot.X)<1e-6 and math.abs(at.Z-spot.Z)<1e-6)
		local toward=Vector3.new(Nest.Facing.X-spot.X,0,Nest.Facing.Z-spot.Z).Unit
		assert((box.CFrame.LookVector-toward).Magnitude<1e-6,"its front faces the plaza like the nest")
		assert(build({flags={OnboardingV3=true},studio=true}),"Studio: the box is there")
		assert(build({place=96451847774961,studio=false})==nil,"live: no box")
		assert(build({flags={OnboardingV3=false},place=107705084891479,studio=false})==nil,"the flag off: no box")
	end)

	test("pets stay off the rim and straw; the prompt, the trail end and a catch-up landing beside a player there stay open",function()
		local box=build({flags={OnboardingV3=true},studio=true})
		local wet={box}
		local root=CFrame.lookAt(Vector3.new(spot.X,spot.Y,spot.Z),Vector3.new(Nest.Facing.X,spot.Y,Nest.Facing.Z))
		for k=0,15 do
			local a=k/16*math.pi*2
			local rim=root*Vector3.new(math.cos(a)*2.4,0,math.sin(a)*2.4)
			assert(not Walk.segmentAllowed(rim,rim,wet),"a pet in the nest at "..k)
		end
		local prompt=root*Vector3.new(0,0,-Nest.Front)
		assert(Walk.segmentAllowed(prompt,prompt,wet),"the prompt point is open")
		-- A player standing at the prompt: the catch-up's first candidate (ring 0) is the player's own spot.
		local open=0
		local list=Catchup.candidates(prompt,(prompt-root.Position).Unit)
		assert(list[1]==prompt or(list[1]-prompt).Magnitude<1e-6,"ring 0 is the anchor")
		assert(Walk.segmentAllowed(list[1],list[1],wet),"ring 0 (the player's own spot) is a landing")
		for _,candidate in ipairs(list)do if Walk.segmentAllowed(candidate,candidate,wet)then open+=1 end end
		assert(open>=#list-4,"only the candidates over the nest are taken: "..open.." of "..#list)
	end)

	return{passed=#cases,cases=cases}
end
