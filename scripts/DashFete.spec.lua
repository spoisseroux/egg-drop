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
	test("wet band 1.12 x as wide, 35% darker, top 3.25; colliders 2.9 across, .03 under each top, 1.2 deep",function()
		for _,stone in ipairs(Stones.Rows)do
			local band=Stones.band(stone)
			assert(near(band.length,stone.length*1.12)and near(band.top,3.25)and near(band.colour.R,stone.colour.R*.65))
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
		-- The company stones stand clear of the walk and low.
		for _,small in ipairs(Stones.Company)do
			assert(small.top>=3.4 and small.top<=3.6 and math.max(small.length,small.width)<=1.1)
			for _,stone in ipairs(rows)do
				assert(Vector2.new(small.x-stone.x,small.z-stone.z).Magnitude>Stones.Collider.diameter/2+small.length/2,small.name)
			end
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
	test("about 50 parts (Mount 60), and every one anchored and out of everybody's way",function()
		local start=Fete.start(PostOut,lanes())
		local count=#start+#Fete.finish()+#Fete.pad(2.5)+3 -- the three rope anchors
		assert(count>=40 and count<=Fete.MaxParts,count)
	end)

	test("mount, scene on: the fete set, the stones (cylinders until carved) and three walkable colliders; off: as before",function()
		local room=Instance.new("Folder")
		local model=Mount.build(room,{fete=true,carve=false})
		assert(model:GetAttribute("Fete")==true and model:GetAttribute("Start")and model:GetAttribute("Finish"))
		local colliders,props,beams,stones=0,0,0,0
		for _,node in ipairs(model:GetDescendants())do
			if node.ClassName=="Part"then
				assert(node.Anchored==true and node.CanTouch==false,node.Name)
				if node:GetAttribute("StoneCollider")then
					colliders+=1
					assert(node.CanCollide==true and node.Transparency==1 and near(node.Size.Y,2.9))
				else
					assert(node.CanCollide==false and node.CanQuery==false,node.Name)
					if node.Parent==model then props+=1 end
				end
			end
			if node.ClassName=="Beam"then beams+=1 end
			if node.ClassName=="Model"and node:GetAttribute("Stone")then stones+=1 end
		end
		assert(colliders==3,colliders)
		assert(props>=40 and props<=60,"props "..props)
		assert(beams==6,"ropes "..beams) -- start rope, two drops, two guy lines; the finish rope
		-- three stones, three bands, three company, two landings
		assert(stones==11,stones)
		local off=Instance.new("Folder")
		local old=Mount.build(off,{fete=false})
		assert(old:GetAttribute("Fete")==nil and old:FindFirstChild(Mount.StonesName)==nil and old:FindFirstChild("Stone_1"))
		Mount.remove(room);assert(#room:GetChildren()==0)
	end)
	test("the carve: the stone builder swaps the cylinders for the carved stone, keeps them when it throws or the mount is gone",function()
		local stone=Stones.Rows[2]
		local folder=Instance.new("Folder")
		local carved=Instance.new("Part")
		local seen
		local model=Builder.stone(folder,stone,{carve=function(ball,blocks)seen={ball=ball,blocks=blocks};return carved end,spawn=function(fn)fn()end})
		assert(seen and #seen.blocks>=5 and #seen.blocks<=7)
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
