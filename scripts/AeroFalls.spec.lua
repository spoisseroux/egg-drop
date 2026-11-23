-- Studio Client, or offline: DASH_SPECS=AeroFalls python scripts/run_dash_server_specs.py <luau.exe>. The waterfall layers
-- (AeroFalls inside AeroAdditions, WORLD-PASS-2026-11-22 item 4 step 1) on a fake world: built at the walk map's falls,
-- inert, draw counts per budget level, the 120-stud gate, the mist keep-out (fades, never cleared), daylight, Reduced
-- Motion, touch-only devices at level 1, TextureSpeed written once, and the picture put back when the additions go. The
-- live room is never touched. Garden hour slice C: with the hour off the additions are today's; on, the rainbow and the
-- dew glints by day only (> .7) and the fireflies at night (12, 6 at level 1, following the blends, Reduced Motion, the
-- camera keep-out, where the areas sit).
-- Usage: require(PlayerScripts.Client.ZZSpecs.AeroFalls)(PlayerScripts.Client)
return function(client,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Values=require(Shared.WorldAero)
	local Look=Values.Waterfall
	local Additions=require(client.AeroAdditions)
	-- The device is pinned to a desktop here (the touch case sets its own) and put back after.
	local Falls=require(client.AeroFalls)
	local realTouch=Falls.touch
	Falls.touch=function()return false end
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local holder=Instance.new("Folder");holder.Name="_AeroFallsSpec";holder.Parent=workspace
	local function near(a,b,within)return math.abs(a-b)<(within or 1e-3)end
	local function at(a,b,within)return(a-b).Magnitude<(within or 1e-3)end
	local function v(list)return Vector3.new(list[1],list[2],list[3])end

	-- The walk map's falls (assets/world/world-v7-walk.json falls = WorldV7Data.beams.sheets).
	local SHEETS={
		{name="Water_TumbleFalls_Upper",top={81.4254,51.6046,-81.4254},bottom={79.7284,22.25,-79.7284},width0=8.4,width1=9.6,normal={-.7071,0,.7071}},
		{name="Water_TumbleFalls_Lower",top={73.9649,22.3,-73.9649},bottom={72.6921,3.2,-72.6921},width0=11.4,width1=12.6,normal={-.7071,0,.7071}},
		{name="Water_SkyFalls",top={-5.3674,3.25,61.072},bottom={-5.6213,-68,63.9609},width0=7.3,width1=12,normal={.0875,0,-.9962}},
	}
	local DATA={beams={sheets=SHEETS}}
	local n,t=Vector3.new(-.7071,0,.7071).Unit,Vector3.new(.7071,0,.7071).Unit
	local I=Vector3.new(72.6921,Look.PoolTop,-72.6921)
	local NEAR=I+n*30+Vector3.new(0,5,0)
	local SKY=v(SHEETS[3].top)+Vector3.new(.0875,0,-.9962)*30

	local function world()
		local w=Instance.new("Folder");w.Name="_FallsWorld";w.Parent=holder
		-- The server's back sheet, which the layers never touch.
		local room=Instance.new("Folder");room.Name="EggDropLounge";room.Parent=w
		local flow=Instance.new("Folder");flow.Name="WaterFlow";flow.Parent=room
		local anchor=Instance.new("Part");anchor.Name="FlowAnchor";anchor.Anchored=true;anchor.Transparency=1;anchor.Parent=flow
		local beam=Instance.new("Beam");beam.Name="Water_TumbleFalls_Lower";beam.TextureSpeed=1.3;beam.Enabled=true;beam.Parent=anchor
		local mist=Instance.new("ParticleEmitter");mist.Name="Mist";mist.Rate=4;mist.Enabled=true;mist.Parent=anchor
		return w
	end
	-- The garden hour is a fixture: off (false) unless a case passes one, so a Studio session's own hour never leaks in.
	local function build(parent,hour)
		return Additions.build({parent=parent,data=DATA,clouds=false,groundY=function()return 4.5 end,hour=hour or false})
	end
	local function layer(added,group,name,nth)
		local seen=0
		for _,each in ipairs(added.falls.layers)do
			if each.group==group and each.name==name then seen+=1;if seen==(nth or 1)then return each end end
		end
		error("no layer "..group.."/"..name)
	end
	-- Counted from the instances, not the controller's notes.
	local function cleared(added,group,name)return offline and(layer(added,group,name).item.cleared or 0)or 0 end
	local function draws(added)
		local count=0
		for _,item in ipairs(added.falls.folder:GetDescendants())do
			if item:IsA("Beam")or item:IsA("ParticleEmitter")then
				if item.Enabled then count+=1 end
			elseif item:IsA("Part")and item.Transparency<1 then
				count+=1
			end
		end
		assert(count==added.falls.draws(),"draws "..count.." vs "..added.falls.draws())
		return count
	end
	local function go(added,state)
		added.update(state)
		return draws(added)
	end
	local PROPS={"Enabled","TextureSpeed","Rate","Transparency","Width0","Name"}
	local function picture(root)
		local out={}
		for _,item in ipairs(root:GetDescendants())do
			local got={parent=item.Parent}
			for _,key in ipairs(PROPS)do
				local ok,value=pcall(function()return item[key]end)
				if ok then got[key]=value end
			end
			out[item]=got
		end
		return out
	end
	local function samePicture(a,b)
		for item,got in pairs(a)do
			assert(b[item],item.Name.." is missing")
			for key,value in pairs(got)do assert(b[item][key]==value,item.Name.."."..key.." "..tostring(b[item][key]).." was "..tostring(value))end
		end
		for item in pairs(b)do assert(a[item],item.Name.." is new")end
	end

	local ok,problem=pcall(function()
		test("with the world kit standing: LOOK-R2's white water at Tumble, today's layers without it",function()
			local Kit=Look.Kit
			local kit={falls={Water_TumbleFalls_Upper={curve=2},Water_TumbleFalls_Lower={curve=2}}}
			local added=Additions.build({parent=holder,data=DATA,clouds=false,groundY=function()return 4.5 end,hour=false,kit=kit})
			local names={}
			for _,each in ipairs(added.falls.layers)do if each.group=="Tumble"then names[each.name]=(names[each.name]or 0)+1 end end
			for _,gone in ipairs({"StrandA","StrandB","Ribbon","Lip","Foam","LedgeFoam","Rings","Mist","LedgeMist","Rainbow"})do
				assert(names[gone]==nil,gone.." is not in the kit stack")
			end
			assert(names.FlowA==2 and names.FlowB==2 and names.Apron==1 and names.BoilPool==1 and names.BoilLedge==1
				and names.Droplets==1 and names.KitMist==1)
			for nth=1,2 do
				local beam=layer(added,"Tumble","FlowA",nth).item
				assert(beam.CurveSize0==0 and beam.FaceCamera==false and beam.Segments==6 and beam.Texture==Kit.Textures.White,
					"flow beams are straight and flat on the sheet (LOOK-R2 round 4)")
			end
			assert(layer(added,"Tumble","FlowB",1).item.Texture==Kit.Textures.Veil)
			local sky=layer(added,"Sky","StrandA").item
			assert(sky.CurveSize0==0 and sky.Segments==6,"Sky Falls keeps today's layers")
			-- 9 at Tumble near the falls, 4 at level 1, none under Reduced Motion.
			assert(go(added,{camera=NEAR,level=0,reduced=false,daylight=.9})==9,"near Tumble: its 9 (Sky Falls is the other group)")
			assert(go(added,{level=1})==4)
			assert(go(added,{level=0,reduced=true})==0)
			added.destroy()
			-- And without it, today's flat falls exactly.
			added=build(holder)
			assert(layer(added,"Tumble","Lip",1)and layer(added,"Tumble","Lip",2))
			local flat=layer(added,"Tumble","StrandA",2).item
			assert(flat.CurveSize0==0 and flat.CurveSize1==0 and flat.Segments==6)
			added.destroy()
		end)
		test("the falls the layers use are the walk map's",function()
			local data=require(Shared.WorldV7Data)
			local byName={}
			for _,sheet in ipairs(data.beams.sheets)do byName[sheet.name]=sheet end
			for _,sheet in ipairs(SHEETS)do
				local real=byName[sheet.name];assert(real,sheet.name)
				assert(at(v(real.top),v(sheet.top))and at(v(real.bottom),v(sheet.bottom))and near(real.width0,sheet.width0),sheet.name)
			end
			assert(Look.Tiers[SHEETS[1].name]=="Upper"and Look.Tiers[SHEETS[2].name]=="Lower"and Look.Sky==SHEETS[3].name)
		end)
		test("built at the falls: strands, ribbons, lips, foam, rings, mist and rainbow where the look puts them",function()
			local added=build(holder)
			local falls=added.falls
			assert(falls.folder.Parent==added.folder and added.folder.Parent==holder)
			local function ends(each)
				local a0,a1=each.item.Attachment0,each.item.Attachment1
				return(a0.Parent.CFrame*a0.CFrame).Position,(a1.Parent.CFrame*a1.CFrame).Position
			end
			local upper,lower=SHEETS[1],SHEETS[2]
			local top,bottom=ends(layer(added,"Tumble","StrandA",1))
			assert(at(top,v(upper.top)+n*.15)and at(bottom,v(upper.bottom)+n*.15),"strand A, upper")
			local strandA=layer(added,"Tumble","StrandA",1).item
			assert(near(strandA.Width0,9.4)and near(strandA.Width1,10.6)and strandA.TextureLength==20 and near(strandA.TextureSpeed,.55))
			assert(strandA.FaceCamera==false and strandA.Segments==6 and strandA.Texture==Look.Textures.Strand)
			top=ends(layer(added,"Tumble","StrandB",2))
			assert(at(top,v(lower.top)+n*.3+t*.6),"strand B, lower")
			local strandB=layer(added,"Tumble","StrandB",2).item
			assert(near(strandB.Width0,11.4*.7)and strandB.TextureLength==9 and near(strandB.TextureSpeed,1.1))
			local ribbon=layer(added,"Tumble","Ribbon",2)
			top=ends(ribbon)
			assert(at(top,v(lower.top)+n*.45)and near(ribbon.item.Width0,13)and ribbon.item.TextureLength==16 and ribbon.item.Texture==Look.Textures.Ribbon)
			local lipUpper,lipLower=layer(added,"Tumble","Lip",1).item,layer(added,"Tumble","Lip",2).item
			assert(at(lipUpper.CFrame.Position,v(upper.top)+n*.3)and at(lipUpper.Size,Vector3.new(8,.5,.5)),"top lip")
			assert(at(lipLower.CFrame.Position,v(lower.top)+n*.3)and at(lipLower.Size,Vector3.new(10.6,.6,.6)),"ledge roll")
			assert(at(lipUpper.CFrame.RightVector,t),"a cylinder lies along t")
			assert(lipUpper.Color==Look.LipLook.Color and near(lipUpper.Reflectance,.1))
			local foam=layer(added,"Tumble","Foam").item.Parent
			assert(at(foam.CFrame.Position,Vector3.new(I.X,Look.PoolTop+.3,I.Z)+n*.75)and at(foam.Size,Vector3.new(12,.6,1.5)),"pool foam box")
			assert(at(foam.CFrame.RightVector,t)and at(foam.CFrame.LookVector,-n),"the box faces n")
			local ledge=layer(added,"Tumble","LedgeFoam").item.Parent
			assert(at(ledge.CFrame.Position,v(lower.top)+n*.6)and at(ledge.Size,Vector3.new(10.5,.5,2)),"ledge foam box")
			local rings=layer(added,"Tumble","Rings").item
			assert(at(rings.Parent.CFrame.Position,Vector3.new(I.X,Look.PoolTop+.08,I.Z)+n*2)and rings.Texture==Look.Textures.Ripple)
			assert(rings.Orientation==Enum.ParticleOrientation.VelocityPerpendicular)
			local mist=layer(added,"Tumble","Mist").item
			assert(at(mist.Parent.CFrame.Position,Vector3.new(I.X,Look.PoolTop+3,I.Z)+n*1)and at(mist.Parent.Size,Vector3.new(10,1,1.5)),"pool mist box")
			assert(mist.ZOffset==-2 and mist.Texture==Look.Textures.Mist)
			-- The pool bed is walkable: the foam box ends within 1.5 studs of the sheet along n; the mist box is centred
			-- within it and starts above pet height (Fable r1).
			local foamBox,mistBox=foam,mist.Parent
			assert(math.abs((foamBox.CFrame.Position-I):Dot(n))+foamBox.Size.Z/2<=1.5+1e-3,"foam box reach")
			assert(math.abs((mistBox.CFrame.Position-I):Dot(n))<=1.5 and mistBox.CFrame.Position.Y-mistBox.Size.Y/2>=Look.PoolTop+2.5-1e-3,"mist box")
			local rainbow=layer(added,"Tumble","Rainbow").item
			local foot0,foot1=ends(layer(added,"Tumble","Rainbow"))
			assert(at(foot0,Vector3.new(66.3,4.2,-76.2),.1)and at(foot1,Vector3.new(76.2,4.2,-66.3),.1),"rainbow feet")
			local a0=rainbow.Attachment0
			assert(at((a0.Parent.CFrame*a0.CFrame).RightVector,Vector3.new(0,1,0)),"axis up")
			assert(rainbow.CurveSize0==8 and rainbow.CurveSize1==-8 and rainbow.FaceCamera==true and rainbow.TextureSpeed==0)
			top=ends(layer(added,"Sky","StrandA"))
			assert(at(top,v(SHEETS[3].top)+Vector3.new(.0875,0,-.9962).Unit*.15)and layer(added,"Sky","StrandA").item.TextureLength==28)
			assert(layer(added,"Sky","Ribbon").item.TextureLength==22)
			if not offline then
				assert(near(strandA.Transparency.Keypoints[2].Value,.28)and near(rainbow.Transparency.Keypoints[3].Value,.8))
				assert(near(layer(added,"Tumble","StrandB",1).item.Transparency.Keypoints[2].Value,.62))
				assert(near(mist.Transparency.Keypoints[2].Value,.62)and near(mist.Size.Keypoints[2].Value,5))
				assert(near(layer(added,"Sky","Mist").item.Size.Keypoints[2].Value,6.5),"Sky Falls mist keeps its size")
			end
			local beams,emitters,parts,attachments=0,0,0,0
			for _,item in ipairs(falls.folder:GetDescendants())do
				assert(string.sub(item.Name,1,3)~="W7_",item.Name)
				if item:IsA("Part")then
					parts+=1
					assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch and not item.CastShadow,item.Name)
				elseif item:IsA("Beam")then beams+=1
				elseif item:IsA("ParticleEmitter")then emitters+=1
				elseif item:IsA("Attachment")then attachments+=1 end
			end
			-- Tumble: 4 strands, 2 ribbons, a rainbow; 2 foam, rings, 2 mist; 2 lips, 5 boxes, an anchor. Sky: 2 beams, a mist, a box, an anchor.
			assert(beams==9 and emitters==6 and parts==10 and attachments==18,beams.." "..emitters.." "..parts.." "..attachments)
			added.destroy()
		end)
		test("built switched off: nothing shows until the camera is known",function()
			local added=build(holder)
			assert(draws(added)==0)
			added.destroy()
		end)
		test("per budget level: 14 at Tumble, 8 or fewer at level 1, none at level 2",function()
			local added=build(holder)
			assert(go(added,{level=0,camera=NEAR,daylight=.9})==14)
			local ledge=cleared(added,"Tumble","LedgeFoam")
			assert(go(added,{level=1})==8)
			for _,name in ipairs({"StrandB","LedgeFoam","LedgeMist","Rings","Rainbow"})do assert(not layer(added,"Tumble",name).item.Enabled,name)end
			if offline then assert(cleared(added,"Tumble","LedgeFoam")==ledge+1,"the level clears what it switches off")end
			assert(layer(added,"Tumble","Foam").item.Rate==8 and near(layer(added,"Tumble","Mist").item.Rate,1.5))
			assert(go(added,{level=2})==0)
			assert(go(added,{level=0})==14 and layer(added,"Tumble","Foam").item.Rate==22 and layer(added,"Tumble","Mist").item.Rate==3)
			assert(go(added,{camera=SKY})==3 and layer(added,"Sky","StrandA").item.Enabled)
			assert(go(added,{level=1})==0,"no Sky Falls at level 1")
			added.destroy()
		end)
		test("the distance gate: on within 120 studs of the falls, off (not destroyed) past it",function()
			local added=build(holder)
			local count=#added.falls.folder:GetDescendants()
			assert(go(added,{level=0,camera=I+t*119,daylight=.9})==14)
			local foam=cleared(added,"Tumble","Foam")
			assert(go(added,{camera=I+t*121})==0)
			if offline then assert(cleared(added,"Tumble","Foam")==foam,"leaving lets the foam fade")end
			assert(go(added,{camera=Vector3.new(400,80,-400)})==0 and #added.falls.folder:GetDescendants()==count)
			assert(go(added,{camera=NEAR})==14)
			added.destroy()
		end)
		test("the mist keeps out of the camera within 16 studs and fades (not cleared); the rainbow is day only",function()
			local added=build(holder)
			go(added,{level=0,camera=NEAR,daylight=.9})
			local mist,ledgeMist=cleared(added,"Tumble","Mist"),cleared(added,"Tumble","LedgeMist")
			assert(go(added,{camera=I+n*10+Vector3.new(0,2,0)})==12)
			assert(not layer(added,"Tumble","Mist").item.Enabled and not layer(added,"Tumble","LedgeMist").item.Enabled)
			if offline then
				assert(cleared(added,"Tumble","Mist")==mist and cleared(added,"Tumble","LedgeMist")==ledgeMist,"the keep-out lets mist fade")
				-- Still fading when level 1 cuts the ledge mist: cleared then, once.
				go(added,{level=1});go(added,{level=1})
				assert(cleared(added,"Tumble","LedgeMist")==ledgeMist+1 and cleared(added,"Tumble","Mist")==mist,"a later cut clears")
				go(added,{level=0})
			end
			assert(go(added,{camera=NEAR,daylight=.4})==13 and not layer(added,"Tumble","Rainbow").item.Enabled)
			-- RainbowDaylight .7 (garden hour slice C): golden's .55 shows none; Aero's .9 does.
			assert(Look.RainbowDaylight==.7)
			assert(go(added,{daylight=.55})==13 and go(added,{daylight=.7})==13,"not at .7 itself")
			assert(go(added,{daylight=.75})==14 and go(added,{daylight=Values.Daylight})==14)
			added.destroy()
		end)
		test("Reduced Motion: none of the layers, emitters cleared; back as they were after",function()
			local added=build(holder)
			go(added,{level=0,camera=NEAR,daylight=.9})
			local foam=cleared(added,"Tumble","Foam")
			added.still(true)
			assert(draws(added)==0)
			if offline then assert(cleared(added,"Tumble","Foam")==foam+1,"emitters cleared")end
			added.update({level=0,camera=NEAR})
			assert(draws(added)==0,"the check keeps them still")
			added.still(false)
			assert(draws(added)==14 and near(layer(added,"Tumble","StrandA").item.TextureSpeed,.55)and layer(added,"Tumble","Ribbon").item.TextureSpeed==1)
			added.destroy()
		end)
		test("TextureSpeed is written once, at build: no check, level or Reduced Motion writes it again",function()
			local added=build(holder)
			local strand=layer(added,"Tumble","StrandB").item
			assert(near(strand.TextureSpeed,1.1))
			strand.TextureSpeed=7 -- a value only this spec writes
			go(added,{level=0,camera=NEAR,daylight=.9});go(added,{level=1});go(added,{level=0})
			added.still(true);added.still(false);go(added,{camera=SKY});go(added,{camera=NEAR})
			assert(strand.TextureSpeed==7,"written again: "..strand.TextureSpeed)
			added.destroy()
		end)
		test("touch-only devices start the falls on the level 1 set; the budget can still take them to 2",function()
			Falls.touch=function()return true end
			local added=build(holder)
			Falls.touch=function()return false end
			assert(go(added,{level=0,camera=NEAR,daylight=.9})==8)
			assert(not layer(added,"Tumble","StrandB").item.Enabled and layer(added,"Tumble","Foam").item.Rate==8)
			assert(go(added,{level=2})==0 and go(added,{level=0})==8)
			added.destroy()
			local desktop=build(holder)
			assert(desktop.falls.state.touch==false,"read per build")
			desktop.destroy()
		end)
		test("off: the additions go and the picture is the one before, server sheet untouched",function()
			local w=world()
			local before=picture(w)
			local added=build(w)
			go(added,{level=0,camera=NEAR,daylight=.9})
			added.still(true);added.still(false);go(added,{level=1})
			added.destroy()
			samePicture(before,picture(w))
			assert(#w:GetChildren()==1)
		end)
		test("no data, no falls; the rest of the additions still build",function()
			local added=Additions.build({parent=holder,data={},clouds=false,groundY=function()return 4.5 end})
			assert(#added.falls.layers==0 and go(added,{level=0,camera=NEAR,daylight=.9})==0)
			added.destroy()
			local none=Additions.build({parent=holder,falls=false,clouds=false,groundY=function()return 4.5 end,hour=false})
			assert(none.falls==nil);none.update({level=0,camera=NEAR});none.still(true);none.destroy()
		end)

		-- Garden hour slice C (GARDEN-HOUR-BUILD-PLAN-2026-11-23; GARDEN-HOUR-LOOK 5): the rainbow and dew glints by day
		-- only, the v7 fireflies at night. The hour is a fixture with GardenHour's own phase().
		local Hour=require(Shared.GardenHour)
		local Fly=Values.Fireflies
		local DAY,GOLDEN,NIGHT,DAWN=1000,2600,3300,200
		local function clock(seconds,on)
			local h={on=on~=false,t=seconds}
			h.fixture={on=function()return h.on end,time=function()return h.t end,phase=Hour.phase}
			return h
		end
		local function glints(added)
			local n=0
			for _,e in ipairs(added.emitters)do if e.Enabled==true then n+=1 end end
			return n
		end
		local function glintsCleared(added)
			local n=0
			if offline then for _,e in ipairs(added.emitters)do n+=e.cleared or 0 end end
			return n
		end
		local function rows(added)return added.fireflies()or {}end
		local function row(added,name)
			for _,each in ipairs(rows(added))do if each.area.name==name then return each end end
			error("no firefly area "..name)
		end
		-- Fireflies alive at the steady rate: Rate times the longest life, over the areas switched on.
		local function alive(added)
			local n=0
			for _,each in ipairs(rows(added))do
				if each.emitter.Enabled==true then n+=each.emitter.Rate*Fly.Life[2]end
			end
			return n
		end
		local function lit(added)
			local n=0
			for _,each in ipairs(rows(added))do if each.emitter.Enabled==true then n+=1 end end
			return n
		end
		local function fliesCleared(added)
			local n=0
			if offline then for _,each in ipairs(rows(added))do n+=each.emitter.cleared or 0 end end
			return n
		end
		local FAR=Vector3.new(400,80,-400) -- no falls, no firefly area near

		test("hour off: the additions are today's (glints at any daylight, no fireflies built, the rainbow at .7)",function()
			for _,hour in ipairs({false,clock(NIGHT,false).fixture})do
				local added=build(holder,hour)
				added.still(false)
				for _,daylight in ipairs({Values.Daylight,.55,.12})do
					go(added,{level=0,camera=NEAR,daylight=daylight})
					assert(glints(added)==Values.MaxGlints,"glints at "..daylight)
					assert(added.fireflies()==nil,"no fireflies built")
					assert(added.state.on==false and added.state.daylight==daylight)
				end
				for _,item in ipairs(added.folder:GetChildren())do assert(string.sub(item.Name,1,9)~="Fireflies",item.Name)end
				assert(go(added,{daylight=Values.Daylight})==14)
				added.destroy()
			end
		end)
		test("hour on: day shows the rainbow and the glints; golden, night and dawn neither (they fade, not cleared)",function()
			local h=clock(DAY)
			local added=build(holder,h.fixture)
			added.still(false)
			-- AeroWorld's daylight is ignored while the hour is on.
			assert(go(added,{level=0,camera=NEAR,daylight=.12})==14,"day: rainbow")
			assert(added.state.on and added.state.daylight==Values.Daylight and glints(added)==Values.MaxGlints)
			assert(#rows(added)==#Fly.Areas and lit(added)==0 and alive(added)==0,"fireflies built, all off by day")
			local cleared=glintsCleared(added)
			for _,case in ipairs({{GOLDEN,.55},{NIGHT,.12},{DAWN,.5}})do
				h.t=case[1]
				assert(go(added,{daylight=Values.Daylight})==13,case[1]..": no rainbow")
				assert(math.abs(added.state.daylight-case[2])<1e-9 and glints(added)==0,case[1]..": no glints")
			end
			assert(glintsCleared(added)==cleared,"glints fade out, never cleared by the hour")
			h.t=DAY
			assert(go(added,{})==14 and glints(added)==Values.MaxGlints,"day again")
			added.destroy()
		end)
		test("night: 12 fireflies in five areas, 6 at budget level 1; none by day, golden or dawn",function()
			local h=clock(NIGHT)
			local added=build(holder,h.fixture)
			added.still(false)
			go(added,{level=0,camera=FAR,daylight=.9})
			assert(lit(added)==5 and math.abs(alive(added)-12)<1e-4,"12: "..alive(added))
			for _,each in ipairs(rows(added))do
				assert(math.abs(each.emitter.Rate*Fly.Life[2]-each.area.count)<1e-4,each.area.name)
			end
			assert(math.abs(row(added,"Bank").emitter.Rate*Fly.Life[2]-4)<1e-4,"4 along the stream bank")
			go(added,{level=1})
			assert(lit(added)==5 and math.abs(alive(added)-6)<1e-4,"level 1: 6")
			go(added,{level=0})
			assert(math.abs(alive(added)-12)<1e-4)
			local cleared=fliesCleared(added)
			for _,t in ipairs({DAWN,DAY,GOLDEN})do
				h.t=t
				go(added,{})
				assert(lit(added)==0 and alive(added)==0,t..": none")
			end
			assert(fliesCleared(added)==cleared,"the last ones fade, never cleared")
			added.destroy()
		end)
		test("the count follows the blends: up through golden to night, down through night to dawn, only under .3",function()
			local h=clock(2880)
			local added=build(holder,h.fixture)
			added.still(false)
			go(added,{level=0,camera=FAR})
			local last=-1
			for step=0,24 do
				h.t=2880+120*step/24
				go(added,{})
				local daylight=added.state.daylight
				local want=12*Additions.fireflyRamp(daylight)
				assert(math.abs(alive(added)-want)<1e-4,"golden to night "..step)
				assert(alive(added)>=last-1e-4,"rising")
				assert((alive(added)>0)==(daylight<Fly.Spawn),"spawns only under .3: "..daylight)
				last=alive(added)
			end
			assert(math.abs(last-12)<1e-4,"full at night")
			for step=0,18 do
				h.t=90*step/18
				go(added,{})
				local daylight=added.state.daylight
				assert(alive(added)<=last+1e-4,"falling")
				assert((alive(added)>0)==(daylight<Fly.Spawn),"stops at .3: "..daylight)
				last=alive(added)
			end
			assert(last==0)
			assert(Additions.fireflyRamp(.3)==0 and Additions.fireflyRamp(.12)==1 and Additions.fireflyRamp(0)==1 and Additions.fireflyRamp(nil)==0)
			added.destroy()
		end)
		test("Reduced Motion: no fireflies (cleared) and no glints; back as they were after",function()
			local h=clock(NIGHT)
			local added=build(holder,h.fixture)
			added.still(false)
			go(added,{level=0,camera=FAR})
			local cleared=fliesCleared(added)
			added.still(true)
			assert(lit(added)==0 and glints(added)==0)
			if offline then assert(fliesCleared(added)==cleared+5,"cleared")end
			go(added,{})
			assert(lit(added)==0,"the check keeps them off")
			added.still(false)
			assert(math.abs(alive(added)-12)<1e-4)
			-- Reduced Motion from the start: none are even built.
			local still=build(holder,h.fixture)
			still.still(true);go(still,{level=0,camera=FAR})
			assert(still.fireflies()==nil)
			still.still(false)
			assert(math.abs(alive(still)-12)<1e-4)
			added.destroy();still.destroy()
		end)
		test("the camera keep-out: an area within 6 studs (plus the drift) of the camera stops, and fades",function()
			local h=clock(NIGHT)
			local added=build(holder,h.fixture)
			added.still(false)
			go(added,{level=0,camera=FAR})
			local south=row(added,"South")
			local top=south.box.CFrame.Position+Vector3.new(0,south.box.Size.Y/2,0)
			go(added,{level=0,camera=top+Vector3.new(0,Fly.CameraKeepOut+Fly.Reach+.5,0)})
			assert(south.emitter.Enabled and lit(added)==5,"just outside")
			local cleared=fliesCleared(added)
			go(added,{camera=top+Vector3.new(0,Fly.CameraKeepOut+Fly.Reach-.5,0)})
			assert(not south.emitter.Enabled and lit(added)==4 and math.abs(alive(added)-10)<1e-4,"inside")
			assert(fliesCleared(added)==cleared,"faded, not cleared")
			local east=row(added,"East")
			go(added,{camera=east.box.CFrame.Position})
			assert(south.emitter.Enabled and not east.emitter.Enabled)
			added.destroy()
		end)
		test("fireflies, the look: #E8FF8A, .6 studs (the LifeArt dot), emissive, 4 to 6 s with a 1 s fade, 1.5 to 4 studs up, inert",function()
			local want=Color3.fromHex("#E8FF8A")
			assert(near(Fly.Color.R,want.R,1e-6)and near(Fly.Color.G,want.G,1e-6)and near(Fly.Color.B,want.B,1e-6),"#E8FF8A")
			assert(Fly.Size==.6 and Fly.LightEmission==1)
			assert(Fly.Texture==require(Shared.LifeArt).id("fireflyDot"),"the soft dot (or its stand-in)")
			assert(Fly.Life[1]==4 and Fly.Life[2]==6 and Fly.Fade==1 and Fly.Pulse==1.8 and Fly.Speed==.6)
			assert(Fly.Spawn==.3 and Fly.Full==Hour.Holds.night.Daylight,"full at the night hold")
			assert(Fly.Speed/(Fly.Drag*math.log(2))<=Fly.Reach,"the drift stays within Reach")
			assert(Fly.Low==1.5 and Fly.Low+Fly.Band+Fly.Reach<=4+1e-9,"1.5 to 4 studs up")
			local count,count1=0,0
			for _,area in ipairs(Fly.Areas)do count+=area.count;count1+=area.count1 end
			assert(#Fly.Areas==5 and count==12 and count1==6)
			local h=clock(NIGHT)
			local added=build(holder,h.fixture)
			added.still(false);go(added,{level=0,camera=FAR})
			for _,each in ipairs(rows(added))do
				local box,e=each.box,each.emitter
				assert(box.Parent==added.folder and e.Parent==box and box.Transparency==1)
				assert(box.Anchored and not box.CanCollide and not box.CanQuery and not box.CanTouch and not box.CastShadow,box.Name)
				assert(math.abs(box.CFrame.Position.Y-(4.5+Fly.Low+Fly.Band/2))<1e-6 and math.abs(box.Size.Y-Fly.Band)<1e-9)
				assert(e.Texture==Fly.Texture and e.LightInfluence==0 and e.LightEmission==1 and math.abs(e.Drag-Fly.Drag)<1e-6)
				assert(e:FindFirstChildOfClass("PointLight")==nil and box:FindFirstChildOfClass("PointLight")==nil,"no light")
				if not offline then
					assert(e.Lifetime.Min==4 and e.Lifetime.Max==6 and near(e.Size.Keypoints[1].Value,.6))
					local fade=e.Transparency.Keypoints
					assert(fade[1].Value==1 and fade[#fade].Value==1 and math.abs(fade[2].Time-.2)<1e-6,"1 s in and out of 5")
				end
			end
			added.destroy()
		end)
		test("firefly areas: on flat lawn, off the water, clear of every station, rest, bridge and the nest",function()
			local Layout=require(Shared.HollowWorldLayout)
			local data=require(Shared.WorldV7Data)
			local keep={}
			for _,frame in pairs(Layout.Stations)do table.insert(keep,frame.Position)end
			for _,point in pairs(Layout.Rest)do table.insert(keep,point)end
			for _,span in pairs(Layout.WalkableSpans or {})do table.insert(keep,span.center)end
			-- The nest (Nest.Spot, the plaza since beta 12 QA O2), the creek rest nook (GardenLayout), the west bridge.
			for _,point in ipairs({require(Shared.Nest).Spot,Vector3.new(26,4.175,-15.5),Vector3.new(-83,4.25,35)})do table.insert(keep,point)end
			-- Wet boxes: measured with both yaw senses, so the answer holds whichever way the walk map turns them.
			local function wet(x,z)
				local best=math.huge
				for _,box in ipairs(data.wet)do
					for _,sense in ipairs({1,-1})do
						local c,s=math.cos(box.yaw*sense),math.sin(box.yaw*sense)
						local dx,dz=x-box.center[1],z-box.center[3]
						local lx,lz=c*dx-s*dz,s*dx+c*dz
						local ex,ez=math.max(math.abs(lx)-box.size[1]/2,0),math.max(math.abs(lz)-box.size[3]/2,0)
						best=math.min(best,math.sqrt(ex*ex+ez*ez))
					end
				end
				return best
			end
			for _,area in ipairs(Fly.Areas)do
				local c,s=math.cos(area.yaw),math.sin(area.yaw)
				local low,high=math.huge,-math.huge
				for a=0,8 do for b=0,8 do
					local lx,lz=(a/8-.5)*area.width,(b/8-.5)*area.depth
					local x,z=area.x+c*lx+s*lz,area.z-s*lx+c*lz
					assert(wet(x,z)>=Fly.Keep.water,area.name.." over water at "..x..", "..z)
					for _,point in ipairs(keep)do
						local d=math.sqrt((x-point.X)^2+(z-point.Z)^2)
						assert(d>=Fly.Keep.station,area.name.." within "..d.." of "..tostring(point))
					end
					local y=Layout.groundY(x,z)
					low,high=math.min(low,y),math.max(high,y)
				end end
				assert(high-low<=.5,area.name.." ground "..low.." to "..high)
			end
		end)
		test("a firefly build that throws partway leaves no boxes and is not tried again (the 5 s pass)",function()
			local h=clock(NIGHT)
			local failing,calls=false,0
			local added=Additions.build({parent=holder,data=DATA,clouds=false,hour=h.fixture,groundY=function()
				if failing then calls+=1;if calls==3 then error("ground",0)end end
				return 4.5
			end})
			local ok,problem=pcall(function()
				failing=true
				added.still(false)
				go(added,{level=0,camera=FAR,daylight=.9})
				assert(calls==3 and Additions.firefliesFailed==true,"tried once, failed on the third area")
				assert(added.fireflies()==nil,"no rows")
				for _,item in ipairs(added.folder:GetChildren())do assert(string.sub(item.Name,1,9)~="Fireflies",item.Name)end
				for _=1,4 do go(added,{level=0,camera=FAR})end
				assert(calls==3 and added.fireflies()==nil,"not rebuilt")
				assert(glints(added)==0,"the rest of the additions follow the hour")
			end)
			Additions.firefliesFailed=nil
			added.destroy()
			assert(ok,problem)
			-- Cleared, the next build builds them.
			local again=build(holder,h.fixture)
			again.still(false);go(again,{level=0,camera=FAR,daylight=.9})
			assert(#rows(again)==#Fly.Areas,"built");again.destroy()
		end)
		test("the hour going off at night is today again; on and off, the picture is the one before",function()
			local h=clock(NIGHT)
			local w=world()
			local before=picture(w)
			local added=build(w,h.fixture)
			added.still(false)
			go(added,{level=0,camera=NEAR,daylight=Values.Daylight})
			assert(lit(added)==5 and glints(added)==0)
			h.on=false
			assert(go(added,{})==14,"today's daylight: rainbow")
			assert(lit(added)==0 and glints(added)==Values.MaxGlints and added.state.daylight==Values.Daylight)
			added.destroy()
			samePicture(before,picture(w))
			assert(#w:GetChildren()==1)
		end)
	end)
	Falls.touch=realTouch
	holder:Destroy()
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
