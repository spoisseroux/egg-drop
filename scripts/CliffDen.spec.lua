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
		for _,pair in ipairs(Data.pocket)do if pair.show~=missing and not v7:FindFirstChild(pair.show)then part(pair.show,v7)end end
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
		assert(Data.parts["W7C_CD_CliffPath"]==nil and Data.parts["W7_CD_CliffPath__cliff_rock"].collide==false and Data.parts["W7_CD_PlayDen__cliff_rock"].collide==false)
		for name,e in pairs(Data.parts)do if string.sub(name,1,10)=="W7_CD_Regi"then assert(e.collide==false,name)end end   -- Studio R1
	end)
	test("the anchors: the den inside the ring's rule (rounded back corners), the mouth under the lintel, the path foot to arrival",function()
		local den=Data.den
		-- round 6 (Spencer beta 25, Fable DEN-ROUND6-LOOK): the room 36 x 24, walls 10 and peak 17 over the floor; the mouth
		-- an arch 18 wide, its crown 11 over the floor; no trim lintel (the old door is carved away)
		assert(den.floorY>4 and den.floorY<4.5 and den.peakY==21.2 and den.wallY==14.2)
		assert(math.abs(den.mouth.top-den.floorY-11)<.01 and den.mouth.x1<den.mouth.x2 and den.mouth.x2-den.mouth.x1>=18)
		assert(den.sign.under==nil and den.sign.at[2]-1.1>=den.floorY+9-1e-6)
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
		for _,bay in ipairs(den.bays)do assert(bay.roof>=14.2 and bay.roof<=21.2 and bay.at[2]==den.floorY,bay.name)end
		assert(#den.doorstep.at==3 and #den.doorstep.landing==3 and #den.pin==3 and #den.board.at==3 and #den.lanterns==4)
		assert(#Data.safe.rows>10)
		assert(#Data.ground>0 and #Data.walk.grid>0 and #Data.walk.surface>0)
	end)
	test("step A's layer (CliffDen false): the palette copy (round 6: the bigger mouth carves the old bars away); no CliffDen, the sculpt untouched",function()
		local world,storage,ws=rig()
		local got,mode=Swap.apply(world,{flags={Tier=true,CliffDen=false},place=Swap.PlaceId,storage=storage,data=Data,workspace=ws})
		assert(got==Data and mode=="pocket")
		local now=names(world)
		assert(not now["W7_Landmarks__palette"]and now["W7_CD_Pocket__palette"]and(Data.bars==nil or now[Data.bars])and not now["W7_CD_Landmarks__palette"])
		assert(now["W7_Rocks__cliff_rock"]and not now["W7_CD_Rocks__cliff_rock"]and not now["W7_CD_PlayDen__cliff_rock"])
		assert(world:GetAttribute("CliffDen")==nil and ws:GetAttribute("CliffDen")==nil)
		assert(#Data.pocket==(if Data.bars then 2 else 1)and(Data.bars==nil or(Data.parts[Data.bars].collide==false and Data.parts[Data.bars].region=="CaveBars")))
		local _,den=Swap.apply(rig(),{flags={Tier=true},place=Swap.PlaceId,storage=storage,data=Data,workspace=Instance.new("Workspace")})
		assert(den=="den")
		local listed=false
		for _,pair in ipairs(Data.swap)do if pair.show==Data.bars then listed=true end end
		assert(listed or Data.bars==nil,"the room's layer has the bars too")
	end)
	test("the bars hide while Den_open is true and come back when it clears; no bars part, nothing",function()
		local Den=require(Shared.PlayDen)
		local world=Instance.new("Model")
		local barsData={bars="W7_CD_CaveBars__palette"} -- round 6: the real data has none (carved away); the behaviour stands
		local bars=part(barsData.bars,world)
		local attrs,listeners={},{}
		local ws={
			GetAttribute=function(_,k)return attrs[k]end,
			GetAttributeChangedSignal=function(_,k)
				return{Connect=function(_,f)listeners[k]=f;return{Disconnect=function()listeners[k]=nil end}end}
			end,
		}
		local function set(v)attrs[Den.OpenAttribute]=v;if listeners[Den.OpenAttribute]then listeners[Den.OpenAttribute]()end end
		assert(Swap.bars(world,barsData,{workspace=ws}))
		assert(bars.Transparency==0)
		set(true);assert(bars.Transparency==1)
		set(nil);assert(bars.Transparency==0)
		attrs[Den.OpenAttribute]=true
		local w2=Instance.new("Model");local b2=part(barsData.bars,w2)
		Swap.bars(w2,barsData,{workspace=ws});assert(b2.Transparency==1,"already open at start")
		assert(Swap.bars(Instance.new("Model"),barsData,{workspace=ws})==nil and Swap.bars(world,nil,{workspace=ws})==nil)
		assert(Data.bars==nil or Data.parts[Data.bars])
	end)
	test("the collision boxes: the den's floor at the floor under every safe cell, headroom to 11.5, the path's treads under its centre line and nothing over it",function()
		local boxes=Data.collision.boxes
		assert(#boxes>40)
		local frames={}
		for i,b in ipairs(boxes)do
			local r=b.r
			frames[i]={cf=CFrame.new(b.c[1],b.c[2],b.c[3],r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9]),h=Vector3.new(b.s[1]/2,b.s[2]/2,b.s[3]/2),kind=b.kind}
			-- orthonormal and right-handed
			local X,Y,Z=Vector3.new(r[1],r[4],r[7]),Vector3.new(r[2],r[5],r[8]),Vector3.new(r[3],r[6],r[9])
			assert(math.abs(X.Magnitude-1)<1e-3 and math.abs(Y.Magnitude-1)<1e-3 and math.abs(X:Dot(Y))<1e-3 and (X:Cross(Y)-Z).Magnitude<1e-3,b.kind)
		end
		local function solid(p)
			for _,f in ipairs(frames)do
				local q=f.cf:PointToObjectSpace(p)
				if math.abs(q.X)<=f.h.X and math.abs(q.Y)<=f.h.Y and math.abs(q.Z)<=f.h.Z then return f.kind end
			end
			return nil
		end
		local F=Data.den.floorY
		local n=0
		for _,row in ipairs(Data.safe.rows)do
			local z=row[1]
			if z<=-96 then
				for x=row[2],row[3]do
					n+=1
					assert(solid(Vector3.new(x,F-.05,z)),"no floor at "..x..","..z)
					-- by the mouth: under its arch's shoulders (round 6: the lintel box sits there); elsewhere 11.5
					local head=if z>Data.den.mouth.z-1 then(Data.den.mouth.shoulder or Data.den.mouth.top)-.3 else 11.5
					for _,y in ipairs({F+.05,F+2,F+5,head})do assert(not solid(Vector3.new(x,y,z)),"blocked at "..x..","..y..","..z)end
				end
			end
		end
		assert(n>400,n)
		local samples=0
		for _,c in ipairs(Data.path.centreLine)do
			samples+=1
			assert(solid(Vector3.new(c.x,c.y-.1,c.z))=="tread","no tread under "..c.x..","..c.z)
			for _,dy in ipairs({.15,1.5,3,5})do
				local k=solid(Vector3.new(c.x,c.y+dy,c.z))
				assert(not k,string.format("%s over the path at %.1f,%.1f +%.2f",tostring(k),c.x,c.z,dy))
			end
		end
		assert(samples>30)
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
	test("Studio R2: the dressing the sculpt leaves floating is skipped only while the sculpt is in; marble and trim stay live",function()
		local Hide=require(Shared.CliffDenDressing)
		local Dressing=require(Shared.WorldDressing)
		assert(#Data.dressingHide>=9)
		local skipped=0
		for _,list in ipairs({Dressing.Flowers,Dressing.Bushes})do
			for _,row in ipairs(list)do
				if Hide.skip(row[1],row[3],true,Data)then skipped+=1 end
				assert(not Hide.skip(row[1],row[3],false,Data),"skipped with the sculpt out")
			end
		end
		assert(skipped==#Data.dressingHide,skipped)
		local hidden={}
		for _,pair in ipairs(Data.swap)do if pair.hide then hidden[pair.hide]=true end end
		-- round 6: the old door's marble and trim are carved (the bigger mouth takes them in); what is left of the marble
		-- shows only as 32-stud tiles, never as one re-baked island-wide mesh (Studio R2: that bridged the plaza)
		for name,info in pairs(Data.parts)do
			if string.find(name,"marble")or string.find(name,"__trim")then
				assert(string.match(name,"_%d%d%d%d$")and info.size[1]<=34 and info.size[3]<=34,name.." is not a tile")
			end
		end
		assert(hidden.W7_Rocks__cliff_rock and hidden.W7_Ground__ground and Data.parts.W7_CD_Ground__ground.collide==false)
		for name,info in pairs(Data.parts)do assert(info.size[1]>=.05 and info.size[2]>=.05 and info.size[3]>=.05,name.." is a sliver")end
	end)
	test("Fable fix 9: the den mouth's dressing: two bushes each side at the jambs, a boulder on the left slope, within budget",function()
		local Hide=require(Shared.CliffDenDressing)
		local Dressing=require(Shared.WorldDressing)
		local m=Data.den.mouth
		-- The budget: the mouth bushes take the places of the bushes the sculpt skips.
		local skipped=0
		for index,row in ipairs(Dressing.Bushes)do
			if index<=Dressing.MaxBushes and Hide.skip(row[1],row[3],true,Data)then skipped+=1 end
		end
		assert(#Hide.MouthBushes==4 and #Hide.MouthBushes<=skipped,"budget "..skipped)
		local left,right=0,0
		for _,row in ipairs(Hide.MouthBushes)do
			local x,y,z,kind,_,scale=table.unpack(row)
			assert(Dressing.BushKinds[kind]~=nil and scale>=1 and scale<=2)
			assert(x<m.x1-1.5 or x>m.x2+1.5,"out of the mouth's opening "..x)
			assert(z>m.z and z<m.z+6,"at the jamb rocks' feet "..z)
			assert(y>=4 and y<=5.2,"on the apron or the lawn "..y)
			if x<m.x1 then left+=1;assert(math.abs(x-(m.x1-3))<=1.5)else right+=1;assert(math.abs(x-(m.x2+3))<=2.5)end -- round 6: by the jambs
			-- Behind the notice board's face, never in front of it.
			local board=Vector3.new(table.unpack(Data.den.board.at))
			if math.abs(x-board.X)<3 then assert(z<board.Z-1,"behind the board")end
		end
		assert(left==2 and right==2)
		-- The boulder: left of the mouth, clear of the cliff path's treads (its footprint ellipse), Hollow-row shaped.
		local b=Hide.MouthBoulder
		assert(b.x<m.x1-5 and typeof(b.size)=="Vector3"and type(b.colour)=="string"and type(b.seed)=="number")
		local frame=CFrame.new(b.x,0,b.z)*CFrame.Angles(0,b.yaw,0)
		local treads=0
		for _,box in ipairs(Data.collision.boxes)do
			if box.kind=="tread"then
				treads+=1
				local r=box.r
				local cf=CFrame.new(box.c[1],box.c[2],box.c[3],r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9])
				for _,sx in ipairs({-.5,.5})do for _,sz in ipairs({-.5,.5})do
					local corner=(cf*CFrame.new(box.s[1]*sx,0,box.s[3]*sz)).Position
					local q=frame:PointToObjectSpace(Vector3.new(corner.X,0,corner.Z))
					local e=(q.X/(b.size.X/2))^2+(q.Z/(b.size.Z/2))^2
					assert(e>1.1,"the boulder covers a tread corner "..e)
				end end
			end
		end
		assert(treads>=10,treads)
	end)
	return{passed=#cases,cases=cases}
end
