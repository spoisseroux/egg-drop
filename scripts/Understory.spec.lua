-- The garden understory, P1 (GARDEN-B38-BRIEF 4b): the counts, sizes and budget; every bush, flowering bush and reed
-- clump against the LIVE keep lists (Understory.check: GroundDressing.Keep, GardenClearance, GardenKeepOut, the ball
-- homes, the frond bushes) and the ground; clusters in threes and pairs as the brief places them; the art's placeholder
-- ids drawing nothing; UnderstoryClient on fakes (built only with `scene` on, inert parts at their frames with the
-- import's pi turn, blobs under bushes only, torn down when the switch goes off); the motion maths and the loop (reeds
-- lean downwind, bushes only shiver on a strong blow, Reduced Motion and budget level 2 put everything at rest).
-- If a module moves, rerun scripts/build_understory_place.py.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.Understory)(PlayerScripts.Client)
-- Offline: python scripts/run_dash_server_specs.py (DASH_SPECS="Understory")
return function(client,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local U=require(Shared.Understory)
	local Art=require(Shared.UnderstoryArt)
	local Data=require(Shared.UnderstoryData)
	local Alive=require(Shared.Alive)
	local World=require(Shared.HollowWorldLayout)
	local Wind=require(Shared.Wind)
	local Client=require(client.UnderstoryClient)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local LIVE=96451847774961
	-- CFrames compared by place and turn (the offline mocks' CFrames are tables)
	local function same(a,b)
		return(a.Position-b.Position).Magnitude<1e-6 and(a.LookVector-b.LookVector).Magnitude<1e-6 and(a.UpVector-b.UpVector).Magnitude<1e-6
	end
	local function signal()
		if type(offline)=="table"and offline.signal then return offline.signal()end
		local b=Instance.new("BindableEvent")
		return{Connect=function(_,fn)return b.Event:Connect(fn)end,Fire=function(_,...)b:Fire(...)end}
	end

	test("the brief's counts and budget: 24 bushes in eight threes, 8 flowering in pairs, 14 reeds; 46 parts, 10,772 tris",function()
		assert(#Data.Bushes==U.Counts.bushes and #Data.Flowering==U.Counts.flowering and #Data.Reeds==U.Counts.reeds)
		assert(U.Budget.instances==#Data.Bushes+#Data.Flowering+#Data.Reeds)
		assert(U.Budget.blobs==#Data.Bushes+#Data.Flowering)
		local tris=(#Data.Bushes)*Art.Meshes.bush.tris+(#Data.Flowering)*Art.Meshes.flower.tris+(#Data.Reeds)*Art.Meshes.reeds.tris
		assert(tris==U.Budget.triangles and Art.Meshes.bush.tris<=U.Budget.bushCap and Art.Meshes.flower.tris==Art.Meshes.bush.tris and Art.Meshes.reeds.tris<=U.Budget.reedsCap,"triangles "..tris)
		local sites={}
		for _,row in ipairs(Data.Bushes)do sites[row[7]]=(sites[row[7]]or 0)+1 end
		local n=0
		for site,count in pairs(sites)do n+=1;assert(count==3,"a cluster of three: "..site)end
		assert(n==8,"eight clusters")
		local pairs_={}
		for _,row in ipairs(Data.Flowering)do pairs_[row[7]]=(pairs_[row[7]]or 0)+1 end
		for _,site in ipairs({"hub_west","hub_east","fountain_west","fountain_east"})do assert(pairs_[site]==2,"a pair: "..site)end
		local reeds={}
		for _,row in ipairs(Data.Reeds)do reeds[row[6]]=(reeds[row[6]]or 0)+1 end
		assert(reeds.stream_east==4 and reeds.stream_west==4 and reeds.falls_pool==3 and reeds.fountain==3,"reeds by the water")
	end)

	test("sizes: bushes 2.5 to 4 across and 1.5 to 2.5 tall (see-over), both sizes used; flowering 2.5 to 3; reeds .8 to 1.15",function()
		local small,big=0,0
		for _,row in ipairs(Data.Bushes)do
			local S=U.Sizes.bush
			assert(row[4]>=S.across[1]and row[4]<=S.across[2]and row[5]>=S.tall[1]and row[5]<=S.tall[2],"bush size")
			if row[4]<=2.6 then small+=1 elseif row[4]>=3.8 then big+=1 end
		end
		assert(small>=8 and big>=8,"two sizes")
		for _,row in ipairs(Data.Flowering)do
			local S=U.Sizes.flower
			assert(row[4]>=S.across[1]and row[4]<=S.across[2]and row[5]>=S.tall[1]and row[5]<=S.tall[2],"flowering size")
		end
		for _,row in ipairs(Data.Reeds)do assert(row[4]>=U.Sizes.reeds.scale[1]and row[4]<=U.Sizes.reeds.scale[2],"reed scale")end
	end)

	test("every plant is clear of the live keep lists, on the ground, and not inside another group",function()
		local all={}
		for _,kind in ipairs(U.Kinds)do
			for _,row in ipairs(U.rows(kind))do
				local r=U.radius(kind,row)
				local site=row[#row]
				local ok,why=U.check(kind,row[1],row[3],r,site=="fountain")
				assert(ok,kind.." "..site.." at "..row[1]..", "..row[3]..": "..tostring(why))
				local y=World.groundY(row[1],row[3])
				assert(math.abs(row[2]-y)<U.Keep.height,kind.." "..site.." floats or sinks: "..row[2].." vs "..y)
				table.insert(all,{x=row[1],z=row[3],r=r,site=site})
			end
		end
		for i=1,#all do
			for j=i+1,#all do
				local a,b=all[i],all[j]
				if a.site~=b.site then
					assert(Vector2.new(a.x-b.x,a.z-b.z).Magnitude>=a.r+b.r,"groups overlap: "..a.site.." and "..b.site)
				end
			end
		end
	end)

	test("the rules bite: a station, the Dash pad, a find spot, the stream, a ball home, a trunk; reeds far from water",function()
		local Course=require(Shared.DashCourse)
		local Finds=require(Shared.FindSpots)
		local Balls=require(Shared.BumbleBalls)
		local Kit=require(Shared.WorldAeroKit)
		local spots={{-31,-11,"station"},{Course.Pad.x/100,Course.Pad.z/100,"pad"},{Finds[1].x/100,Finds[1].z/100,"find"},
			{3.2,20.6,"stream"},{Balls.List[1].home.X,Balls.List[1].home.Y,"ball"},{Kit.crowns[1].pivot[1],Kit.crowns[1].pivot[3],"trunk"}}
		for _,s in ipairs(spots)do assert(U.check("bush",s[1],s[2],1.25)==false,"a bush allowed on the "..s[3])end
		assert(U.check("reeds",-60,6,1)==false,"reeds on a dry lawn")
	end)

	test("the reeds stand by the water, the fountain's three round its basin, the flowering pairs by the hub and fountain",function()
		for _,row in ipairs(Data.Reeds)do
			if row[6]=="fountain"then
				local d=Vector2.new(row[1]-52,row[3]-3).Magnitude
				assert(d>=4 and d<=7,"round the basin: "..d)
			end
		end
		for _,row in ipairs(Data.Flowering)do
			local hub=string.sub(row[7],1,3)=="hub"
			local d=if hub then Vector2.new(row[1]+30,row[3]-4).Magnitude else Vector2.new(row[1]-52,row[3]-3).Magnitude
			assert(d<=22,row[7].." is "..d.." from its place")
		end
	end)

	test("the art: placeholder ids draw nothing (never an error); a filled kind needs its mesh and the atlas",function()
		for _,kind in ipairs(U.Kinds)do assert(Art.ready(kind)==Art.filled(Art.Meshes[kind].id)and Art.filled(Art.Atlas)==Art.ready(kind))end
		local fake={Atlas="rbxassetid://5",Blob=nil,filled=Art.filled,ready=Art.ready,
			Meshes={bush={id="rbxassetid://7",size=Art.Meshes.bush.size,centre=Art.Meshes.bush.centre,tris=320},
				flower={id=nil,size=Art.Meshes.flower.size,centre=Art.Meshes.flower.centre,tris=320},
				reeds=Art.Meshes.reeds}}
		assert(Art.ready("bush",fake)==true and Art.ready("flower",fake)==false)
		assert(Art.ready("bush",{Atlas=nil,Meshes=fake.Meshes})==false,"no atlas, nothing")
		assert(not Art.filled("rbxassetid://")and not Art.filled("123")and Art.filled("rbxassetid://123"))
	end)

	-- A client on fakes: `on` is the scene switch; meshes are mock MeshParts that clone.
	local function fakeMesh()
		local made=0
		return function(kind,id)
			assert(type(id)=="string")
			local function part()
				local p=Instance.new("MeshPart")
				p.Clone=function()made+=1;return part()end
				return p
			end
			return part()
		end,function()return made end
	end
	local function mountWith(opts)
		local changed=signal()
		local state={on=opts.on,moves={},level=opts.level or 0,reduced=opts.reduced or false,time=opts.time or 0}
		local parent=Instance.new("Folder")
		local mesh=fakeMesh()
		local c=Client.mount({
			alive={ceiling=function()return opts.ceiling~=false end,on=function(name)return name=="scene"and state.on end,
				changed=function()return changed end},
			art=opts.art,mesh=mesh,parent=parent,heartbeat=false,worldVersion="v7",
			now=function()return state.time end,camera=function()return Vector3.new(0,10,0)end,
			reduced=function()return state.reduced end,phone=function()return false end,level=function()return state.level end,
			mode=function()return "Room"end,
			move=function(parts,frames)for i,p in ipairs(parts)do p.CFrame=frames[i];state.moves[p]=(state.moves[p]or 0)+1 end end})
		return c,state,changed,parent
	end
	local FILLED={Atlas="rbxassetid://11",Blob="rbxassetid://12",filled=Art.filled,ready=Art.ready,Meshes={
		bush={id="rbxassetid://21",size=Art.Meshes.bush.size,centre=Art.Meshes.bush.centre,tris=320},
		flower={id="rbxassetid://22",size=Art.Meshes.flower.size,centre=Art.Meshes.flower.centre,tris=320},
		reeds={id="rbxassetid://23",size=Art.Meshes.reeds.size,centre=Art.Meshes.reeds.centre,tris=38}}}

	test("the client: nothing on live or with scene off; the shipped placeholders build an empty folder, no error",function()
		assert(Alive.ceiling("scene",nil,LIVE,false)==false,"never on live")
		assert(Client.mount({alive={ceiling=function()return false end}})==nil,"no ceiling, no client")
		local c,_,_,parent=mountWith({on=false,art=FILLED})
		assert(c and #parent:GetChildren()==0,"scene off: nothing built")
		c:destroy()
		local c2,_,_,parent2=mountWith({on=true})   -- the shipped UnderstoryArt (every id nil)
		local folder=parent2:FindFirstChild(Client.Folder)
		assert(folder and #folder:GetChildren()==0 and folder:GetAttribute("UnderstoryParts")==0,"placeholders: nothing drawn")
		c2:destroy()
	end)

	test("with the uploads filled: 46 inert MeshParts at their frames (the pi turn in), 32 blobs under bushes; off tears down",function()
		local c,state,changed,parent=mountWith({on=true,art=FILLED})
		local folder=parent:FindFirstChild(Client.Folder)
		assert(folder:GetAttribute("UnderstoryParts")==46 and folder:GetAttribute("UnderstoryBlobs")==32)
		local meshes,blobs=0,0
		for _,p in ipairs(folder:GetChildren())do
			assert(p.Anchored==true and p.CanCollide==false and p.CanQuery==false and p.CanTouch==false and p.CastShadow==false,p.Name)
			if p.ClassName=="MeshPart"then
				meshes+=1
				assert(p.TextureID==FILLED.Atlas,"the atlas")
			else
				blobs+=1
				local decal=p:FindFirstChildOfClass("Decal")
				assert(p.Transparency==1 and decal and decal.Texture==FILLED.Blob and decal.Transparency==U.Look.blobTransparency)
				assert(string.find(p.Name,"reeds")==nil,"no blob under reeds")
			end
		end
		assert(meshes==46 and blobs==32)
		-- one bush and one reed at their frames: the foot, the centre from it, the turn
		local row=Data.Bushes[1]
		local p=folder:FindFirstChild("bush_1")
		local frame,size,foot=U.frame("bush",row,FILLED)
		assert(same(p.CFrame,frame)and p.Size==size)
		assert((foot-Vector3.new(row[1],row[2],row[3])).Magnitude<1e-6)
		local scale=U.scale("bush",row,FILLED)
		assert(math.abs(size.X-row[4]*FILLED.Meshes.bush.size.X/3)<1e-3 and math.abs(size.Y-row[5])<1e-3,"Size: across and tall")
		assert(math.abs(scale.X-scale.Z)<1e-9)
		local look=(frame*U.Turn:Inverse()).LookVector
		local want=CFrame.Angles(0,row[6],0).LookVector
		assert((look-want).Magnitude<1e-6,"the pi turn comes after the yaw")
		assert(math.abs(frame.Position.Y-(row[2]+FILLED.Meshes.bush.centre.Y*scale.Y))<1e-6,"the bounds centre over the foot")
		state.on=false;changed:Fire()
		assert(parent:FindFirstChild(Client.Folder)==nil,"switched off: gone")
		state.on=true;changed:Fire()
		assert(parent:FindFirstChild(Client.Folder):GetAttribute("UnderstoryParts")==46,"and back")
		c:destroy()
		assert(parent:FindFirstChild(Client.Folder)==nil)
	end)

	test("motion maths: reeds lean downwind with the wind (none in still air); bushes shiver only on a strong blow",function()
		assert(U.reedLean(0,1,0,2)==0 and U.reedLean(nil,1)==0)
		local calm,gale=0,0
		for k=0,40 do calm+=U.reedLean(.2,k/10,0,2);gale+=U.reedLean(1,k/10,0,2)end
		assert(gale/41>calm/41+5,"leans further in a gust")
		for k=0,40 do assert(math.abs(U.reedLean(1,k/10,.3,2))<=U.Motion.reed.lean+1.4*U.Motion.reed.sway+1e-9)end
		for k=0,20 do assert(U.bushShiver(.7,k/7,.2)==0 and U.bushShiver(.5,k/7,.2)==0)end
		local most=0
		for k=0,40 do most=math.max(most,math.abs(U.bushShiver(1,k/97,.1)))end
		assert(most>.5*U.Motion.bush.degrees and most<=U.Motion.bush.degrees+1e-9,"a small shiver at full blow")
		local rest=CFrame.new(3,4.5,2)
		local foot=Vector3.new(3,3,2)
		assert(same(U.pose(rest,foot,0),rest))
		local leaned=U.pose(rest,foot,10,Wind.Direction)
		local top=leaned*Vector3.new(0,2,0)-rest*Vector3.new(0,2,0)
		assert(top:Dot(Wind.Direction)>.1,"the top goes downwind")
		assert((U.pose(rest,foot,10,Wind.Direction)*CFrame.new(0,-1.5,0)).Position.Y<3.1,"turns about the foot")
	end)

	test("the loop: reeds near the camera move in a gust, Reduced Motion and budget level 2 put everything back at rest",function()
		local c,state=mountWith({on=true,art=FILLED})
		-- find a time with a strong gust at the reeds nearest the camera (0, 0)
		local near
		for _,r in ipairs(c.records)do
			if r.kind=="reeds"and(near==nil or r.foot.Magnitude<near.foot.Magnitude)then near=r end
		end
		assert(near and Vector2.new(near.foot.X,near.foot.Z).Magnitude<=U.Motion.range.desktop)
		for t=0,200,.5 do if Wind.gust(near.foot,t)>.8 then state.time=t;break end end
		c:step(1)
		assert(state.moves[near.part],"a reed moved")
		assert((near.part.CFrame.Position-near.rest.Position).Magnitude>1e-4,"leaned")
		state.reduced=true
		c:step(1)
		for _,r in ipairs(c.records)do assert(same(r.part.CFrame,r.rest),"at rest under Reduced Motion: "..r.part.Name)end
		state.reduced=false
		c:step(1)
		state.level=2
		c:step(1)
		for _,r in ipairs(c.records)do assert(same(r.part.CFrame,r.rest),"at rest at level 2")end
		c:destroy()
	end)

	return{passed=#cases,cases=cases}
end
