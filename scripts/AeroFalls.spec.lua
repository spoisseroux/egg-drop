-- Studio Client, or offline: DASH_SPECS=AeroFalls python scripts/run_dash_server_specs.py <luau.exe>. The waterfall layers
-- (AeroFalls inside AeroAdditions, WORLD-PASS-2026-11-22 item 4 step 1) on a fake world: built at the walk map's falls,
-- inert, draw counts per budget level, the 120-stud gate, the mist keep-out, daylight, Reduced Motion, and the
-- picture put back when the additions go. The live room is never touched.
-- Usage: require(PlayerScripts.Client.ZZSpecs.AeroFalls)(PlayerScripts.Client)
return function(client,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Values=require(Shared.WorldAero)
	local Look=Values.Waterfall
	local Additions=require(client.AeroAdditions)
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
	local function build(parent)
		return Additions.build({parent=parent,data=DATA,clouds=false,groundY=function()return 4.5 end})
	end
	local function layer(added,group,name,nth)
		local seen=0
		for _,each in ipairs(added.falls.layers)do
			if each.group==group and each.name==name then seen+=1;if seen==(nth or 1)then return each end end
		end
		error("no layer "..group.."/"..name)
	end
	-- Counted from the instances, not the controller's notes.
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
			assert(near(strandB.Width0,11.4*.7)and strandB.TextureLength==13 and near(strandB.TextureSpeed,1.1))
			local ribbon=layer(added,"Tumble","Ribbon",2)
			top=ends(ribbon)
			assert(at(top,v(lower.top)+n*.45)and near(ribbon.item.Width0,13)and ribbon.item.TextureLength==16 and ribbon.item.Texture==Look.Textures.Ribbon)
			local lipUpper,lipLower=layer(added,"Tumble","Lip",1).item,layer(added,"Tumble","Lip",2).item
			assert(at(lipUpper.CFrame.Position,v(upper.top)+n*.3)and at(lipUpper.Size,Vector3.new(8.8,.9,.9)),"top lip")
			assert(at(lipLower.CFrame.Position,v(lower.top)+n*.3)and at(lipLower.Size,Vector3.new(11.8,1.1,1.1)),"ledge roll")
			assert(at(lipUpper.CFrame.RightVector,t),"a cylinder lies along t")
			local foam=layer(added,"Tumble","Foam").item.Parent
			assert(at(foam.CFrame.Position,Vector3.new(I.X,Look.PoolTop+.3,I.Z)+n*1)and at(foam.Size,Vector3.new(12,.6,2.5)),"pool foam box")
			assert(at(foam.CFrame.RightVector,t)and at(foam.CFrame.LookVector,-n),"the box faces n")
			local ledge=layer(added,"Tumble","LedgeFoam").item.Parent
			assert(at(ledge.CFrame.Position,v(lower.top)+n*.6)and at(ledge.Size,Vector3.new(10.5,.5,2)),"ledge foam box")
			local rings=layer(added,"Tumble","Rings").item
			assert(at(rings.Parent.CFrame.Position,Vector3.new(I.X,Look.PoolTop+.08,I.Z)+n*2.5)and rings.Texture==Look.Textures.Ripple)
			assert(rings.Orientation==Enum.ParticleOrientation.VelocityPerpendicular)
			local mist=layer(added,"Tumble","Mist").item
			assert(at(mist.Parent.CFrame.Position,Vector3.new(I.X,Look.PoolTop+2,I.Z)+n*1.5)and mist.ZOffset==-2 and mist.Texture==Look.Textures.Mist)
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
				assert(near(strandA.Transparency.Keypoints[2].Value,.35)and near(rainbow.Transparency.Keypoints[3].Value,.8))
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
			assert(go(added,{level=1})==8)
			for _,name in ipairs({"StrandB","LedgeFoam","LedgeMist","Rings","Rainbow"})do assert(not layer(added,"Tumble",name).item.Enabled,name)end
			assert(layer(added,"Tumble","Foam").item.Rate==8 and near(layer(added,"Tumble","Mist").item.Rate,1.5))
			assert(go(added,{level=2})==0)
			assert(go(added,{level=0})==14 and layer(added,"Tumble","Foam").item.Rate==16 and layer(added,"Tumble","Mist").item.Rate==3)
			assert(go(added,{camera=SKY})==3 and layer(added,"Sky","StrandA").item.Enabled)
			assert(go(added,{level=1})==0,"no Sky Falls at level 1")
			added.destroy()
		end)
		test("the distance gate: on within 120 studs of the falls, off (not destroyed) past it",function()
			local added=build(holder)
			local count=#added.falls.folder:GetDescendants()
			assert(go(added,{level=0,camera=I+t*119,daylight=.9})==14)
			assert(go(added,{camera=I+t*121})==0)
			assert(go(added,{camera=Vector3.new(400,80,-400)})==0 and #added.falls.folder:GetDescendants()==count)
			assert(go(added,{camera=NEAR})==14)
			added.destroy()
		end)
		test("the mist keeps out of the camera within 16 studs; the rainbow is day only",function()
			local added=build(holder)
			assert(go(added,{level=0,camera=I+n*10+Vector3.new(0,2,0),daylight=.9})==12)
			assert(not layer(added,"Tumble","Mist").item.Enabled and not layer(added,"Tumble","LedgeMist").item.Enabled)
			assert(go(added,{camera=NEAR,daylight=.4})==13 and not layer(added,"Tumble","Rainbow").item.Enabled)
			assert(go(added,{daylight=.55})==14)
			added.destroy()
		end)
		test("Reduced Motion: none of the layers, beams stopped; back as they were after",function()
			local added=build(holder)
			go(added,{level=0,camera=NEAR,daylight=.9})
			local cleared=offline and layer(added,"Tumble","Foam").item.cleared or 0
			added.still(true)
			assert(draws(added)==0)
			for _,each in ipairs(added.falls.layers)do
				if each.kind=="beam"then assert(each.item.TextureSpeed==0,each.name)end
			end
			if offline then assert(layer(added,"Tumble","Foam").item.cleared==cleared+1,"emitters cleared")end
			added.update({level=0,camera=NEAR})
			assert(draws(added)==0,"the check keeps them still")
			added.still(false)
			assert(draws(added)==14 and near(layer(added,"Tumble","StrandA").item.TextureSpeed,.55)and layer(added,"Tumble","Ribbon").item.TextureSpeed==1)
			added.destroy()
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
			local none=Additions.build({parent=holder,falls=false,clouds=false,groundY=function()return 4.5 end})
			assert(none.falls==nil);none.update({level=0,camera=NEAR});none.still(true);none.destroy()
		end)
	end)
	holder:Destroy()
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
