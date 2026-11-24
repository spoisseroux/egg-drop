-- Studio Client. Texture on the ground (beta 14 QA W3 row 7; GARDEN-LIFE-BUILD-PLAN section 4): GroundDressing's 8
-- litter, 10 lawn and 12 path-fray plates, each clear of the LIVE modules (the Dash course and pad with the rope ring,
-- find spots, park kerbs, stations, water; the nest only warns: it is moving in another slice), and WorldDressingClient
-- building them only with the `scene` switch on: inert flat plates with the look's decals, none for a pending texture,
-- and none on the live place (the ceiling). If a module moves, rerun scripts/build_ground_dressing.py.
-- Usage: require(PlayerScripts.Client.ZZSpecs.GroundDressing)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="GroundDressing").
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Ground=require(Shared.GroundDressing)
	local Course=require(Shared.DashCourse)
	local Finds=require(Shared.FindSpots)
	local Park=require(Shared.ParkLayout)
	local Layout=require(Shared.HollowWorldLayout)
	local Data=require(Shared.WorldV7Data)
	local Nest=require(Shared.Nest)
	local Alive=require(Shared.Alive)
	local Flowers=require(client.WorldDressingClient)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local LIVE=96451847774961

	local function lineDistance(x,z,list)
		local best=math.huge
		local n=#list//4
		for i=1,n-1 do
			local ax,az,bx,bz=list[i*4-2]/100,list[i*4]/100,list[(i+1)*4-2]/100,list[(i+1)*4]/100
			local dx,dz=bx-ax,bz-az
			local length=dx*dx+dz*dz
			local t=if length>0 then math.clamp(((x-ax)*dx+(z-az)*dz)/length,0,1)else 0
			best=math.min(best,math.sqrt((x-ax-dx*t)^2+(z-az-dz*t)^2))
		end
		return best
	end
	local function all()
		local out={}
		for _,row in ipairs(Ground.Litter)do table.insert(out,{row=row,radius=row[4]/2*math.sqrt(2),kind="litter"})end
		for _,row in ipairs(Ground.Lawn)do table.insert(out,{row=row,radius=row[4]/2,kind="lawn"})end
		for _,row in ipairs(Ground.Fray)do table.insert(out,{row=row,radius=row[4]/2,kind="fray"})end
		return out
	end

	test("the plates: 8 litter 3 x 3, 10 lawn 7 to 11 (a and b), 12 path fray 4 x 1.5; the look's numbers",function()
		assert(#Ground.Litter==8 and #Ground.Lawn==10 and #Ground.Fray==12)
		for _,row in ipairs(Ground.Litter)do assert(row[4]==3)end
		local a,b=0,0
		for _,row in ipairs(Ground.Lawn)do
			assert(row[4]>=7 and row[4]<=11,"lawn size "..row[4])
			if row[6]=="a"then a+=1 elseif row[6]=="b"then b+=1 end
		end
		assert(a==5 and b==5)
		for _,row in ipairs(Ground.Fray)do assert(row[4]==4)end
		local L=Ground.Look
		assert(L.litter.transparency==.15 and L.lawn.transparency==.55 and L.fray.transparency==0 and L.fray.depth==1.5)
		assert(L.lawn.lift<L.fray.lift and L.fray.lift<L.litter.lift and L.litter.lift<.055,"stacked under the dapple (.055) and flowers (.06)")
	end)

	test("every plate is clear of the live course and pad (rope ring), finds, kerbs, stations and water; the nest only warns",function()
		local pad=Course.Pad
		local K=Ground.Keep
		local warnings=0
		for _,p in ipairs(all())do
			local x,z,r=p.row[1],p.row[3],p.radius
			local where=p.kind.." at "..x..", "..z
			assert(lineDistance(x,z,Course.Main)>=K.course+r-.75 and lineDistance(x,z,Course.Branch)>=K.course+r-.75,"on the course: "..where)
			assert(math.sqrt((x-pad.x/100)^2+(z-pad.z/100)^2)>=4+2+r-.5,"on the waiting pad's rope ring: "..where)
			for _,spot in ipairs(Finds)do
				assert(math.sqrt((x-spot.x/100)^2+(z-spot.z/100)^2)>=K.find+r-.75,"on a find spot: "..where)
			end
			for _,site in ipairs(Park.Sites or {Park})do
				local dx,dz=(x-site.Center.X)/(site.Radius.X+K.kerb),(z-site.Center.Z)/(site.Radius.Y+K.kerb)
				assert(dx*dx+dz*dz>1,"on a park kerb: "..where)
			end
			for name,frame in pairs(Layout.Stations)do
				local d=math.sqrt((x-frame.Position.X)^2+(z-frame.Position.Z)^2)
				assert(d>=K.station+r-.75,"on station "..name..": "..where)
			end
			for _,box in ipairs(Data.wet or {})do
				local frame=CFrame.new(box.center[1],box.center[2],box.center[3])*CFrame.Angles(0,box.yaw or 0,0)
				local q=frame:PointToObjectSpace(Vector3.new(x,box.center[2],z))
				assert(math.abs(q.X)>box.size[1]/2+K.water or math.abs(q.Z)>box.size[3]/2+K.water,"in the water: "..where)
			end
			local n=Nest.Spot
			if math.abs(x-n.X)<Nest.Block/2+K.nest+r and math.abs(z-n.Z)<Nest.Block/2+K.nest+r then
				warnings+=1
				print("WARNING ground plate near the nest (moving in another slice; rerun build_ground_dressing.py): "..where)
			end
		end
		print(string.format("ground plates: %d near the nest (warnings, not failures)",warnings))
	end)

	test("the client builds them only with scene on: 30 inert flat plates with the look's decals; none for a pending texture",function()
		assert(#Flowers.groundPlates({scene=false,art=function()return "rbxassetid://1"end})==0,"scene off: none")
		local plates=Flowers.groundPlates({scene=true,art=function(key)return "rbxassetid://"..#key end,groundY=function()return 4 end})
		assert(#plates==30,"30 plates: "..#plates)
		local looks={GroundLitter=Ground.Look.litter,GroundLawn=Ground.Look.lawn,GroundFray=Ground.Look.fray}
		for _,plate in ipairs(plates)do
			local p=plate.part
			assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow and p.Transparency==1,p.Name)
			local look=assert(looks[p.Name],p.Name)
			assert(math.abs(p.CFrame.Position.Y-(4+look.lift))<1e-6,"on the ground plus its lift")
			local decal=p:FindFirstChildOfClass("Decal")
			assert(decal and decal.Transparency==look.transparency,p.Name)
			assert(plate.ground==true)
			p:Destroy()
		end
		local some=Flowers.groundPlates({scene=true,art=function(key)return if key=="litter"then "rbxassetid://9"else nil end,groundY=function()return 4 end})
		assert(#some==8,"only the uploaded litter: "..#some)
		for _,plate in ipairs(some)do plate.part:Destroy()end
	end)

	test("live safety: the scene ceiling is false on the live place, so WorldDressingClient builds zero plates there",function()
		local on=Alive.ceiling("scene",nil,LIVE,false)
		assert(on==false)
		assert(#Flowers.groundPlates({scene=on,art=function()return "rbxassetid://1"end})==0)
	end)

	return{passed=#cases,cases=cases}
end
