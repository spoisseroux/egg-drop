-- Beta 17 world (WORLD-ALIVE-LOOK sections 3 and 4): the Garden Dash fete set (DashFete), the river stones (RiverStones,
-- StoneBuilder) and the mount that builds them while the Alive `scene` switch is on (DashMount). Pure data and the
-- mount on stand-in instances; the carve itself (GeometryService) is a Studio check.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DashFete)(ServerScriptService.Server); offline in
-- scripts/run_dash_server_specs.py.
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Fete=require(Shared.DashFete)
	local Stones=require(Shared.RiverStones)
	local Course=require(Shared.DashCourse)
	local Grid=require(Shared.DashGrid)
	local Mount=require(server.DashMount)
	local Builder=require(server.StoneBuilder)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
	local function lanes()
		local out={}
		for lane=1,Course.LaneCount do out[lane]=Grid.offset(0,false,lane,Course.LaneCount)/100 end
		return out
	end
	local PostOut=Grid.PostOut/100
	local extent

	test("stones: three, centres within .3 of DashCourse.Stones (where the hop is judged), tops .75 to .95 over the water",function()
		assert(#Stones.Rows==#Course.Stones and #Stones.Rows==3)
		for i,stone in ipairs(Stones.Rows)do
			local at=Course.Stones[i]
			assert(Vector2.new(stone.x-at.x/100,stone.z-at.z/100).Magnitude<=.3,stone.name)
			local shows=stone.top-Stones.Water
			assert(shows>=.75 and shows<=.95+1e-9,stone.name.." shows "..shows)
			assert(stone.top<Stones.Kerb,"steps down from the bank")
			assert(math.abs(stone.top-at.y/100)<1e-9,"the racing pets' height: none sinks in")
		end
	end)
	test("the carve: 5 to 7 cuts, faces at 85 to 100% of the footprint radius, leaning out 8 to 20 degrees, the same every time",function()
		for _,stone in ipairs(Stones.Rows)do
			local cuts=Stones.cuts(stone)
			assert(#cuts>=5 and #cuts<=7,#cuts)
			local again=Stones.cuts(stone)
			for k,cut in ipairs(cuts)do
				assert(cut.reach>=.85 and cut.reach<=1 and cut.lean>=8 and cut.lean<=20)
				assert(near(cut.distance,cut.reach*Stones.radius(stone,cut.theta)))
				assert(cut.yaw==again[k].yaw and cut.distance==again[k].distance,"seeded")
			end
		end
		-- The footprint radius is the half length along the stone and the half width across it.
		local s=Stones.Rows[1]
		assert(near(Stones.radius(s,0),s.length/2)and near(Stones.radius(s,math.pi/2),s.width/2))
		-- The ball clears the footprint at the plane's height, so every cut shows.
		for _,stone in ipairs({Stones.Rows[1],Stones.Rows[2],Stones.Rows[3],Stones.band(Stones.Rows[1]),Stones.Landings[1]})do
			local r=(stone.ball or Stones.Ball)*stone.length/2
			local dy=stone.top-r-(stone.base or Stones.Water)
			local across=math.sqrt(math.max(0,r*r-dy*dy))
			assert(across>=math.max(stone.length,stone.width)/2,stone.name.." "..across)
		end
	end)
	-- How far the carved stone reaches from its centre along flat `dir` at its base height (marching out in .02 steps
	-- until a block cuts it or the ball ends).
	local function inBlock(frame,size,point)
		local q=frame:Inverse()*point
		return math.abs(q.X)<=size/2 and math.abs(q.Y)<=size/2 and math.abs(q.Z)<=size/2
	end
	function extent(stone,dir)
		local frames,size=Stones.blocks(stone)
		local base=stone.base or Stones.Water
		local diameter=(stone.ball or Stones.Ball)*stone.length
		local centre=Vector3.new(stone.x,stone.top-diameter/2,stone.z)
		local d=0
		while d<20 do
			local point=Vector3.new(stone.x,base+.01,stone.z)+dir*(d+.02)
			if(point-centre).Magnitude>diameter/2 then break end
			local cut=false
			for _,frame in ipairs(frames)do if inBlock(frame,size,point)then cut=true;break end end
			if cut then break end
			d+=.02
		end
		return d
	end
	-- The end stone to its landing is no longer a water gap (beta 18): the landing sits in the kerb, and the end stones'
	-- waterline already runs under the kerb's water face (KerbFaces), so the landing is the bank there.
	test("Studio R13 acceptance: water between every pair of stones, .35 at least",function()
		local rows=Stones.Rows
		local pairs_={{rows[1],rows[2]},{rows[2],rows[3]},{Stones.band(rows[1]),Stones.band(rows[2])},{Stones.band(rows[2]),Stones.band(rows[3])}}
		for _,pair in ipairs(pairs_)do
			local a,b=pair[1],pair[2]
			local d=Vector3.new(b.x-a.x,0,b.z-a.z)
			local gap=d.Magnitude-extent(a,d.Unit)-extent(b,-d.Unit)
			assert(gap>=.35,a.name.." to "..b.name.." "..gap)
		end
	end)
	test("Studio R13: the carve cuts AWAY: no block reaches the stone's middle, every point a little past the footprint is in a block",function()
		local inside=inBlock
		local all={}
		for _,stone in ipairs(Stones.Rows)do table.insert(all,stone);table.insert(all,Stones.band(stone))end
		for _,stone in ipairs(Stones.Landings)do table.insert(all,stone)end
		for _,stone in ipairs(Stones.Company)do table.insert(all,stone)end
		for _,stone in ipairs(all)do
			local frames,size=Stones.blocks(stone)
			assert(size>=60 and #frames==#Stones.cuts(stone)+1)
			local base=stone.base or Stones.Water
			local middle=Vector3.new(stone.x,(base+stone.top)/2,stone.z)
			for _,frame in ipairs(frames)do assert(not inside(frame,size,middle),stone.name.." middle cut")end
			-- Round the footprint at the base: 70% in is kept, and what is kept never reaches 1.6 x the footprint (the ball
			-- rounds the polygon's corners), so no slab can spread.
			for k=0,35 do
				local dir=Vector3.new(math.cos(k/36*math.pi*2),0,-math.sin(k/36*math.pi*2))
				local reach=extent(stone,dir)
				local theta=k/36*math.pi*2-math.rad(stone.turn)
				local r=Stones.radius(stone,theta)
				assert(reach>=.7*r,stone.name.." keeps 70% (the faces stand at 85% of the radius at their own angle) "..reach.." of "..r)
				assert(reach<=1.6*r,stone.name.." spreads "..reach.." of "..r)
			end
			-- And the ball is gone a little under the water.
			local under=Vector3.new(stone.x,base-Stones.Floor-.1,stone.z)
			local cut=false
			for _,frame in ipairs(frames)do cut=cut or inside(frame,size,under)end
			assert(cut,stone.name.." floor")
			-- Nothing is wider than its kerb gap: the ball is at most 6 x the stone (no 28-stud balls).
			assert((stone.ball or Stones.Ball)<=6,stone.name)
		end
		assert(#Stones.Company==5 and Stones.Rows[1].colour.R<.5,"darker rows, five company stones")
	end)
	test("R13 wet band 1.04 x as wide, 45% darker, top 3.45; colliders 2.9 across, .03 under each top, 1.2 deep",function()
		for _,stone in ipairs(Stones.Rows)do
			local band=Stones.band(stone)
			assert(near(band.length,stone.length*1.04)and near(band.top,3.45)and near(band.colour.R,stone.colour.R*.55))
			local centre,depth,across,top=Stones.collider(stone)
			assert(across==2.9 and depth==1.2 and near(top,stone.top-.03)and near(centre.Y,top-.6))
		end
	end)
	test("the crossing is a walk: no gap over .3 between the colliders, and both landings reach under the end stones",function()
		local rows=Stones.Rows
		for i=1,#rows-1 do
			local a,b=rows[i],rows[i+1]
			local gap=Vector2.new(a.x-b.x,a.z-b.z).Magnitude-Stones.Collider.diameter
			assert(gap<=.3,"gap "..gap)
		end
		for _,pair in ipairs({{Stones.Landings[1],rows[1]},{Stones.Landings[2],rows[3]}})do
			local landing,stone=pair[1],pair[2]
			local reach=Vector2.new(landing.x-stone.x,landing.z-stone.z).Magnitude-Stones.Collider.diameter/2-landing.width/2
			assert(reach<=.3,landing.name.." "..reach)
			assert(near(landing.top,Stones.Kerb+Stones.LandingLift))
		end
		-- Beta 18: each landing has its own collider, its width across, top .03 under its top, overlapping the end
		-- stone's (no gap) and at most .5 over the lawn (4.0 by the kerb) and the end stone's collider.
		for _,pair in ipairs({{Stones.Landings[1],rows[1]},{Stones.Landings[2],rows[3]}})do
			local landing,stone=pair[1],pair[2]
			local centre,depth,across,top=Stones.landingCollider(landing)
			assert(across==landing.width and depth==1.2 and near(top,landing.top-.03)and near(centre.Y,top-.6))
			local gap=Vector2.new(landing.x-stone.x,landing.z-stone.z).Magnitude-Stones.Collider.diameter/2-across/2
			assert(gap<=0,landing.name.." collider gap "..gap)
			local _,_,_,stoneTop=Stones.collider(stone)
			assert(top-4<=.5 and top-stoneTop<=.5,landing.name.." step "..top)
		end
		-- The company stones stand clear of the walk and low.
		for _,small in ipairs(Stones.Company)do
			assert(small.top>=3.38-1e-9 and small.top<=3.6 and math.max(small.length,small.width)<=1.1)
			for _,stone in ipairs(rows)do
				assert(Vector2.new(small.x-stone.x,small.z-stone.z).Magnitude>Stones.Collider.diameter/2+small.length/2,small.name)
			end
		end
	end)

	-- Beta 18 (Studio R15 finding 3): the landings break the kerb. The kerb faces are the marble mesh's (KerbFaces).
	local function kept(stone,point)
		local d=Vector3.new(point.X-stone.x,0,point.Z-stone.z)
		if d.Magnitude<1e-6 then return true end
		return extent(stone,d.Unit)>=d.Magnitude
	end
	local function onLine(p,line)
		local a,b=Vector3.new(line[1][1],0,line[1][2]),Vector3.new(line[2][1],0,line[2][2])
		local t=(p-a):Dot(b-a)/(b-a):Dot(b-a)
		return a+(b-a)*t
	end
	test("beta 18: each landing sits in the kerb: both faces under it for .6 either side of the crossing, long side along it",function()
		for _,pair in ipairs({{Stones.Landings[1],Stones.KerbFaces.East},{Stones.Landings[2],Stones.KerbFaces.West}})do
			local landing,kerb=pair[1],pair[2]
			local a,b=kerb.inner[1],kerb.inner[2]
			local along=Vector3.new(b[1]-a[1],0,b[2]-a[2]).Unit
			-- The long side along the kerb (within 5 degrees).
			local turn=math.rad(landing.turn)
			local long=Vector3.new(math.cos(turn),0,-math.sin(turn))
			assert(math.abs(long:Dot(along))>=math.cos(math.rad(5)),landing.name.." turn")
			local centre=Vector3.new(landing.x,0,landing.z)
			for k=-6,6 do
				local p=centre+along*(k/10)
				assert(kept(landing,onLine(p,kerb.inner)),landing.name.." water face shows at "..k/10)
				assert(kept(landing,onLine(p,kerb.outer)),landing.name.." lawn face shows at "..k/10)
			end
			-- Not into the stream: its water edge at most .45 past the kerb's water face, on the crossing line.
			local face=onLine(centre,kerb.inner)
			local out=(face-centre).Unit
			local past=extent(landing,out)-(face-centre).Magnitude
			assert(past>=0 and past<=.45,landing.name.." past the face "..past)
			-- The dome's rim clears the kerb's top (4.28) across the kerb: top minus the sag at the farthest kerb point.
			local r=landing.ball*landing.length/2
			local far=math.max((onLine(centre+along*.6,kerb.inner)-centre).Magnitude,(onLine(centre+along*.6,kerb.outer)-centre).Magnitude)
			local sag=r-math.sqrt(r*r-far*far)
			assert(landing.top-sag>=4.28+.02,landing.name.." rim "..(landing.top-sag))
		end
	end)

	test("the start gate: posts at DashGrid.PostOut, nothing across the lanes under 9.6, timber, marble and gold, four cloths",function()
		local parts,ropes=Fete.start(PostOut,lanes())
		local tops={}
		for _,p in ipairs(parts)do
			local x=p.at.Position.X
			local within=math.abs(x)+p.size.X/2<PostOut-.3
			if within and p.at.Position.Y>2 then assert(Fete.bottom(p)>=Fete.Clear,p.name.." "..Fete.bottom(p))end
			if string.find(p.name,"Post$")then table.insert(tops,p.at.Position.Y+p.size.Y/2);assert(p.shadow==true)end
		end
		assert(#tops==2 and near(tops[1],11.85)and near(tops[2],11.85),"posts top at 11.85")
		for _,r in ipairs(ropes)do
			if r.name=="StartRope"then assert(near(r.a.Y-r.sag,11.2)and near(math.abs(r.a.X),PostOut))end
			local low=math.min(r.a.Y,r.b.Y)-r.sag
			if math.abs(r.a.X)<PostOut-.3 and math.abs(r.b.X)<PostOut-.3 then assert(low>=Fete.Clear,r.name)end
		end
		local header
		for _,p in ipairs(parts)do if p.name=="StartHeader"then header=p end end
		assert(header and near(header.at.Position.Y,10.4)and near(Fete.bottom(header),9.75)and header.words)
		local materials,cloth={},{}
		for _,p in ipairs(parts)do
			materials[p.material]=true
			if p.material=="Fabric"then cloth[string.format("%.3f %.3f %.3f",p.colour.R,p.colour.G,p.colour.B)]=true end
		end
		for _,m in ipairs({"Wood","Marble","SmoothPlastic","Fabric","Slate"})do assert(materials[m],m)end
		local n=0;for _ in pairs(cloth)do n+=1 end
		assert(n==4,"four cloth colours, "..n)
	end)
	test("the finish: 6.8 wide, posts topping at 7.2, a rosette at the rope's middle, the chalk line 6.8 long; the pad is earth",function()
		local parts,ropes=Fete.finish()
		local rosette,line
		for _,p in ipairs(parts)do
			if string.find(p.name,"Post$")then assert(near(p.at.Position.Y+p.size.Y/2,7.2)and near(math.abs(p.at.Position.X),3.4))end
			if p.name=="Rosette"then rosette=p end
			if p.name=="FinishLine"then line=p end
		end
		assert(rosette and near(rosette.at.Position.X,0)and line and near(line.size.X,6.8))
		assert(#ropes==1 and near(ropes[1].sag,.4))
		local pad=Fete.pad(2.5)
		assert(pad[1].material=="Ground"and near(pad[1].size.Y,5))
	end)
	test("beta 44 note 20: the start posts are solid boxes, ground to top, over each post's widest part; the way through stays open; the pad has no sign",function()
		local boxes=Fete.startColliders(PostOut)
		assert(#boxes==2)
		local posts={}
		for _,p in ipairs(Fete.start(PostOut,lanes()))do if string.find(p.name,"^Start%a+Foot$")or string.find(p.name,"^Start%a+Cap$")then table.insert(posts,p)end end
		assert(#posts==4)
		for _,box in ipairs(boxes)do
			local at=box.at.Position
			assert(near(math.abs(at.X),PostOut)and near(at.Y-box.size.Y/2,0)and near(at.Y+box.size.Y/2,11.85)and near(at.Z,0),box.name)
			for _,p in ipairs(posts)do
				if math.sign(p.at.Position.X)==math.sign(at.X)then assert(box.size.X>=p.size.X-1e-6 and box.size.Z>=p.size.Z-1e-6,p.name.." sticks out")end
			end
		end
		-- Every racer's slot is inside the boxes (the boxes are only the posts' own footprint), and the way through is
		-- about 11 studs: players walk onto the line. (Racing pets are drawn, never physical: PetFollow leaves the model out.)
		local widest=0;for _,o in ipairs(lanes())do widest=math.max(widest,math.abs(o))end
		local inner=PostOut-boxes[1].size.X/2
		assert(inner>=widest+.2 and inner*2>=10,"open "..(inner*2).." widest "..widest)
		local placeholder=Fete.startColliders(PostOut,.7,10.4)
		assert(near(placeholder[1].size.X,.7)and near(placeholder[1].size.Y,10.4))
		for _,p in ipairs(Fete.pad(2.5))do assert(not string.find(p.name,"Sign"),p.name)end
		assert(#Fete.pad(2.5)==1)
	end)
	test("about 50 parts (Mount 60), and every one anchored and out of everybody's way",function()
		local start=Fete.start(PostOut,lanes())
		local count=#start+#Fete.finish()+#Fete.pad(2.5)+3 -- the three rope anchors
		assert(count>=40 and count<=Fete.MaxParts,count)
	end)

	test("mount, scene on: the fete set, the stones (cylinders until carved) and three walkable colliders; off: as before",function()
		local room=Instance.new("Folder")
		local model=Mount.build(room,{fete=true,carve=false})
		assert(model:GetAttribute("Fete")==true and model:GetAttribute("Start")and model:GetAttribute("Finish"))
		local colliders,props,beams,stones,landings,starts=0,0,0,0,0,0
		for _,node in ipairs(model:GetDescendants())do
			if node.ClassName=="Part"then
				assert(node.Anchored==true and node.CanTouch==false,node.Name)
				if node:GetAttribute("StoneCollider")then
					colliders+=1
					assert(node.CanCollide==true and node.Transparency==1 and near(node.Size.Y,2.9))
				elseif node:GetAttribute("StartCollider")then
					starts+=1
					assert(node.CanCollide==true and node.CanQuery==true and node.Transparency==1 and node:GetAttribute("DashPart")==nil)
					assert(node.Parent==model and near(node.Size.Y,11.85)and near(node.Size.X,Fete.Start.cap.X))
				elseif node:GetAttribute("LandingCollider")then
					landings+=1
					assert(node.CanCollide==true and node.Transparency==1 and near(node.Size.Y,Stones.Landings[landings].width))
					assert(node:GetAttribute("DashPart")==nil)
				else
					assert(node.CanCollide==false and node.CanQuery==false,node.Name)
					if node.Parent==model then props+=1 end
				end
			end
			if node.ClassName=="Beam"then beams+=1 end
			if node.ClassName=="Model"and node:GetAttribute("Stone")then stones+=1 end
		end
		assert(colliders==3,colliders)
		assert(landings==2,landings)
		assert(starts==2,"two start post colliders "..starts)
		for _,name in ipairs({"Sign","SignPost","SignPost2"})do assert(model:FindFirstChild(name)==nil,"beta 44 note 20: no "..name)end
		assert(props>=40 and props<=60,"props "..props)
		assert(beams==6,"ropes "..beams) -- start rope, two drops, two guy lines; the finish rope
		-- three stones, three bands, five company (R13), two landings
		assert(stones==13,stones)
		local off=Instance.new("Folder")
		local old=Mount.build(off,{fete=false})
		assert(old:GetAttribute("Fete")==nil and old:FindFirstChild(Mount.StonesName)==nil and old:FindFirstChild("Stone_1"))
		-- Off too: the placeholder arch's posts are solid and the sign is gone.
		local solid=0
		for _,node in ipairs(old:GetChildren())do
			if node:GetAttribute("StartCollider")then
				solid+=1;assert(node.CanCollide==true and node.Transparency==1 and near(node.Size.Y,Mount.PostHeight)and near(node.Size.X,.7))
			elseif node.ClassName=="Part"then assert(node.CanCollide==false,node.Name)end
		end
		assert(solid==2 and old:FindFirstChild("Sign")==nil and old:FindFirstChild("SignPost")==nil)
		Mount.remove(room);assert(#room:GetChildren()==0)
	end)
	test("the carve: the stone builder swaps the cylinders for the carved stone, keeps them when it throws or the mount is gone",function()
		local stone=Stones.Rows[2]
		local folder=Instance.new("Folder")
		local carved=Instance.new("Part")
		local seen
		local model=Builder.stone(folder,stone,{carve=function(ball,blocks)seen={ball=ball,blocks=blocks};return carved end,spawn=function(fn)fn()end})
		assert(seen and #seen.blocks>=6 and #seen.blocks<=8,"5 to 7 cuts and the floor")
		assert(near(seen.ball.Size.X,1.5*stone.length)and near(seen.ball.CFrame.Position.Y+seen.ball.Size.X/2,stone.top))
		assert(model:GetAttribute("Carved")==true and carved.Parent==model and #model:GetChildren()==1)
		assert(carved.CanCollide==false and carved.Anchored==true)
		local kept=Builder.stone(folder,stone,{carve=function()error("CSG")end,spawn=function(fn)fn()end})
		assert(kept:GetAttribute("Carved")==nil and #kept:GetChildren()==2)
		local later
		local gone=Builder.stone(folder,stone,{carve=function()return Instance.new("Part")end,spawn=function(fn)later=fn end})
		gone.Parent=nil;later()
		assert(#gone:GetChildren()==2,"a mount gone keeps nothing new")
	end)
	return{passed=#cases,cases=cases}
end
