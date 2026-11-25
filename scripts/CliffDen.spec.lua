-- The beta's cliff path / Play Den / terrace top swap (CliffDenSwap, CLIFF-DEN-ISLAND-SCOPE) and its data
-- (CliffDenData). Usage (Server): require(ServerScriptService.Server.ZZSpecs.CliffDen)(ServerScriptService.Server);
-- offline in scripts/run_dash_server_specs.py.
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Swap=require(server.CliffDenSwap)
	local Data=require(Shared.CliffDenData)
	local Live=require(Shared.WorldV7Data)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function part(name,parent)
		local p=Instance.new("Part");p.Name=name
		p.Clone=function(self)local c=Instance.new("Part");c.Name=self.Name;c.Clone=self.Clone;return c end
		if parent then p.Parent=parent end
		return p
	end
	-- A world clone with every live part the swap hides, plus one it never touches.
	local function rig(version,missing)
		local world=Instance.new("Model");world.Name="World"
		part("W7_Bridge__marble",world)
		for _,pair in ipairs(Data.swap)do if pair.hide then part(pair.hide,world)end end
		local storage=Instance.new("Folder")
		local pack=Instance.new("Folder");pack.Name="WorldBeta";pack.Parent=storage
		pack:SetAttribute("Version",version or Data.version)
		local v7=Instance.new("Folder");v7.Name="WorldV7";v7.Parent=pack
		for _,pair in ipairs(Data.swap)do if pair.show and pair.show~=missing then part(pair.show,v7)end end
		return world,storage,Instance.new("Workspace")
	end
	local function names(world)local out={};for _,k in ipairs(world:GetChildren())do out[k.Name]=true end;return out end
	test("live never swaps: not the beta place and not Studio (or no pack) leaves the clone whole",function()
		local world,storage,ws=rig()
		assert(Swap.apply(world,{flags={Tier=true},place=96451847774961,studio=false,storage=storage,data=Data,workspace=ws})==nil)
		assert(Swap.apply(world,{flags={Tier=false},place=Swap.PlaceId,studio=false,storage=storage,data=Data,workspace=ws})==nil)
		assert(names(world)["W7_Rocks__cliff_rock"]and not names(world)["W7_CD_Rocks__cliff_rock"]and ws:GetAttribute("CliffDen")==nil)
		assert(Swap.apply(world,{flags={Tier=true},place=Swap.PlaceId,studio=false,storage=Instance.new("Folder"),data=Data,workspace=ws})==nil)
		assert(names(world)["W7_Rocks__cliff_rock"])
	end)
	test("a stale or incomplete pack swaps nothing (all or nothing)",function()
		local world,storage,ws=rig(Data.version.."-stale")
		assert(Swap.apply(world,{flags={Tier=true},place=Swap.PlaceId,storage=storage,data=Data,workspace=ws})==nil)
		assert(names(world)["W7_Rocks__cliff_rock"])
		world,storage,ws=rig(nil,"W7_CD_PlayDen__cliff_rock")
		assert(Swap.apply(world,{flags={Tier=true},place=Swap.PlaceId,storage=storage,data=Data,workspace=ws})==nil)
		assert(names(world)["W7_Rocks__cliff_rock"]and not names(world)["W7_CD_CliffPath__dirt_path"])
	end)
	test("the beta place swaps every pair, keeps the rest, and says so (CliffDen on the world and workspace)",function()
		local world,storage,ws=rig()
		local got=Swap.apply(world,{flags={Tier=true},place=Swap.PlaceId,storage=storage,data=Data,workspace=ws})
		assert(got==Data)
		local now=names(world)
		for _,pair in ipairs(Data.swap)do
			if pair.hide then assert(not now[pair.hide],pair.hide)end
			if pair.show then assert(now[pair.show],pair.show)end
		end
		assert(now["W7_Bridge__marble"]and world:GetAttribute("CliffDen")==true and ws:GetAttribute("CliffDen")==true)
		assert(Swap.apply(Instance.new("Model"),{flags={Tier=true},studio=true,place=1,storage=storage,data=Data,workspace=ws})~=nil)   -- Studio too
	end)
	test("the data: every shown part has an entry; every hidden one is a live part; the carved copies keep their live region and motion",function()
		for _,pair in ipairs(Data.swap)do
			assert(pair.show or pair.hide)
			if pair.show then
				local e=Data.parts[pair.show]
				assert(e and type(e.region)=="string"and #e.center==3 and #e.size==3,pair.show)
				assert(string.sub(pair.show,1,6)=="W7_CD_"or string.sub(pair.show,1,7)=="W7C_CD_",pair.show)   -- Aero and floor filters
			end
			if pair.hide then
				local was=Live.parts[pair.hide]
				assert(was or string.match(pair.hide,"^W7C_Ground_%d+$"),pair.hide)
				if was and pair.show then
					assert(Data.parts[pair.show].region==was.region,pair.show)
					assert((Data.parts[pair.show].motion~=nil)==(was.motion~=nil),pair.show)
				end
			end
		end
		assert(Data.parts["W7_CD_Crystals__glow_aqua"].motion.kind=="pulse")
		assert(Data.parts["W7_CD_CliffPath__cliff_rock"].region=="CliffPath"and Data.parts["W7_CD_PlayDen__cliff_rock"].region=="PlayDen")
		assert(Data.parts["W7C_CD_CliffPath"].collide==true)
	end)
	test("the anchors: the den inside the ring's rule (rounded back corners), the mouth under the lintel, the path foot to arrival",function()
		local den=Data.den
		assert(den.floorY>4 and den.floorY<4.5 and den.peakY==16 and den.wallY==11)
		assert(den.mouth.top<10.2 and den.mouth.x1<den.mouth.x2 and den.mouth.x2-den.mouth.x1>=15)
		assert(den.sign.under=="W7_Landmarks__trim")
		local p=Data.path
		assert(math.abs(p.foot[2]-4.6)<.05 and math.abs(p.arrival[2]-29)<.05 and p.turn[2]>22 and p.turn[2]<24)
		assert(#p.centreLine>30)
		local steepest=0
		for i=2,#p.centreLine do
			local a,b=p.centreLine[i-1],p.centreLine[i]
			local run=math.sqrt((b.x-a.x)^2+(b.z-a.z)^2)
			if run>.5 and not a.steps and not b.steps then steepest=math.max(steepest,math.deg(math.atan(math.abs(b.y-a.y)/run)))end
		end
		assert(steepest<20,steepest)   -- the shelves (the steps are drawn; their collision ramp is checked in Studio)
		assert(Data.schema==1 and Data.terrace.maxGroundY==27 and #Data.evacuate==3)
		-- The closer (Play Den architect review): on the mouth line, spanning it into both jambs, floor to the lintel.
		local b=den.mouth.blocker
		assert(b.center[3]==den.mouth.z,"blocker off the mouth line")
		assert(b.size[1]>den.mouth.x2-den.mouth.x1,"blocker narrower than the mouth")
		assert(math.abs(b.center[2]-b.size[2]/2-den.floorY)<.01,"blocker not on the floor")
		assert(#den.bays==5 and den.bays[1].use=="DashGate"and den.bays[3].use=="DeckTable")
		for _,bay in ipairs(den.bays)do assert(bay.roof>=11 and bay.roof<=16 and bay.at[2]==den.floorY,bay.name)end
		assert(#den.doorstep.at==3 and #den.doorstep.landing==3 and #den.pin==3 and #den.board.at==3 and #den.lanterns==4)
		assert(#Data.safe.rows>10)
		assert(#Data.ground>0 and #Data.walk.grid>0 and #Data.walk.surface>0)
	end)
	test("the Play Den reads it: DenLayout.fromData (schema 1) gives the room, DenHost takes the world's blocker, the greybox fits",function()
		local Layout=require(Shared.DenLayout)
		local Greybox=require(Shared.DenGreybox)
		local Host=require(server.DenHost)
		local L,why=Layout.fromData(Data)
		assert(L,why)
		assert(L.variant=="room"and #L.bays==5 and L.bays[1].kind=="dash"and L.bays[3].kind=="deck")
		local b=Data.den.mouth.blocker
		assert(Host.blockerFits({Position=Vector3.new(b.center[1],b.center[2],b.center[3]),Size=Vector3.new(b.size[1],b.size[2],b.size[3])},L))
		-- The doorstep and its landing are out of everything the close clears (room, waiting area, pets' floor; slack 1).
		local d=L.doorstep
		for _,p in ipairs({d.at,d.landing})do
			assert(not Layout.inRoom(L,p,1)and not Layout.inWait(L,p,1)and not Layout.petFloor(L,p,true),"doorstep in the den")
		end
		assert(math.abs(L.pin.Y-Data.den.floorY)<.01 and L.pin.Z>Data.den.mouth.z)   -- Show me's pin: on the floor out of the mouth
		local s=Layout.prompts(L);assert((s.gate-s.deck).Magnitude>=7)
		assert(#Greybox.rows(L)<=Greybox.MaxParts)
		-- Every bay's furniture (its footprint, not grown) and every safe cell in the room stand inside the den's outline.
		local poly=Data.den.outline
		local function inside(x,z)
			local hit=false
			for i=1,#poly do
				local a,c=poly[i],poly[i%#poly+1]
				if(a[2]>z)~=(c[2]>z)and x<a[1]+(z-a[2])*(c[1]-a[1])/(c[2]-a[2])then hit=not hit end
			end
			return hit
		end
		for _,f in ipairs(Layout.feet(L,0))do
			if string.sub(f.name,1,3)=="bay"then
				for _,q in ipairs({{f.x1,f.z1},{f.x1,f.z2},{f.x2,f.z1},{f.x2,f.z2}})do
					local w=f.frame:PointToWorldSpace(Vector3.new(q[1],0,q[2]))
					assert(inside(w.X,w.Z),f.name.." pokes out of the den")
				end
			end
		end
		for x=-22,6 do for z=-119,-102 do   -- the room (the mouth line is the outline's edge; the apron is out of it)
			if Layout.safeCell(L,x+.5,z+.5)then assert(inside(x+.5,z+.5),"safe cell outside the den "..x..","..z)end
		end end
		-- The posts stand out of the mouth (the blocker's volume and the passage stay clear).
		for _,l in ipairs(L.lanterns)do
			if l.post then assert(l.at.Z>Data.den.mouth.z+1,"post in the mouth")end
		end
	end)
	return{passed=#cases,cases=cases}
end
