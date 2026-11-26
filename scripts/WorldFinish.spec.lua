-- The world finish art's mount (WorldFinishMount, WORLD-FINISH-ART-BUILD.md). Usage (Server):
-- require(ServerScriptService.Server.ZZSpecs.WorldFinish)(ServerScriptService.Server); offline in
-- scripts/run_dash_server_specs.py. Synthetic data and pack (the generated WorldFinishData is checked for shape only).
return function(server)
	local Mount=require(server.WorldFinishMount)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function part(name,parent,class)
		local p=Instance.new(class or "Part");p.Name=name
		p.Clone=function(self)local c=Instance.new(self.ClassName);c.Name=self.Name;c.Clone=self.Clone;c.Template=true;return c end
		if parent then p.Parent=parent end
		return p
	end
	local function cf(x,y,z)return{x,y,z,1,0,0,0,1,0,0,0,1}end
	local function data(over)
		local d={version="v1",cliffDen="c1",slices={den={packed=true,triangles=100,
			templates={"W7_F_Den__shellWest","W7_CD_Region__cliff_rock","W7_F_OverRocks__cliff_rock_2016","W7_F_Den__crystal",
				"W7_F_Lantern__cage","W7_F_Lantern__pane","W7_F_Stone__flat"},
			hide={"W7_CD_PlayDen__cliff_rock"},
			fixed={{name="W7_F_Den__shellWest",cframe=cf(-15,10,-110),size={14,13,20}},
				{name="W7_CD_Region__cliff_rock",cframe=cf(0,0,0),size={1,1,1},replaces="W7_CD_Region__cliff_rock"},
				{name="W7_F_OverRocks__cliff_rock_2016",cframe=cf(0,0,0),size={1,1,1},overlays="W7_CD_Rocks__cliff_rock_2016"}},
			instances={{template="W7_F_Den__crystal",cframe=cf(2,4,-110),size={.4,1,.4}}},
			boxes={{kind="buttress",c={-18,7,-99},s={4,7,4}}},
			dress={lantern={W7_F_Lantern__cage={offset={0,.2,0},size={.95,1.6,.95}},W7_F_Lantern__pane={offset={0,0,0},size={.6,.9,.6}}},
				ledgeY=9.4,cord=.8,paw={size={1,.33,1},sink=.03,color="#8A8378",offset={0,-.03,0},unit={1,.54,1}}}}}}
		for k,v in pairs(over or {})do d[k]=v end
		return d
	end
	local function rig(d,skip)
		local storage=Instance.new("Folder")
		local pack=Instance.new("Folder");pack.Name=Mount.Pack;pack.Parent=storage
		local v=Instance.new("StringValue");v.Name="Version";v.Value="v1";v.Parent=pack
		for _,t in ipairs(d.slices.den.templates)do if t~=skip then part(t,pack,"MeshPart")end end
		local world=Instance.new("Model");world.Name="World"
		part("W7_CD_PlayDen__cliff_rock",world);part("W7_CD_Region__cliff_rock",world)
		local tile=part("W7_CD_Rocks__cliff_rock_2016",world);tile.CanCollide=true;tile.Transparency=0
		part("W7_Bridge__marble",world)
		return world,storage
	end
	local function names(world)local out={};for _,k in ipairs(world:GetChildren())do out[k.Name]=(out[k.Name]or 0)+1 end;return out end
	test("no pack, a stale pack, another sculpt or a missing template: nothing changes",function()
		local d=data()
		local world,storage=rig(d)
		assert(#Mount.world(world,{storage=Instance.new("Folder"),data=d,cliffVersion="c1"})==0)
		assert(#Mount.world(world,{storage=storage,data=data({version="v2"}),cliffVersion="c1"})==0)
		assert(#Mount.world(world,{storage=storage,data=d,cliffVersion="c2"})==0)
		local w2,s2=rig(d,"W7_F_Den__crystal")
		assert(#Mount.world(w2,{storage=s2,data=d,cliffVersion="c1"})==0)
		assert(names(world)["W7_CD_PlayDen__cliff_rock"]==1 and world:GetAttribute("WorldFinish_den")==nil)
		local unpacked=data();unpacked.slices.den.packed=false
		assert(#Mount.world(world,{storage=storage,data=unpacked,cliffVersion="c1"})==0)
	end)
	test("a part to hide or replace missing from the world: nothing changes (all or nothing)",function()
		local d=data()
		local world,storage=rig(d)
		world.W7_CD_PlayDen__cliff_rock:Destroy()
		assert(#Mount.world(world,{storage=storage,data=d,cliffVersion="c1"})==0)
		assert(names(world)["W7_F_Den__shellWest"]==nil and world.W7_CD_Rocks__cliff_rock_2016.Transparency==0)
		-- a target named twice (hide and replace): refused before anything is destroyed
		local twice=data();table.insert(twice.slices.den.hide,"W7_CD_Region__cliff_rock")
		world,storage=rig(twice)
		assert(#Mount.world(world,{storage=storage,data=twice,cliffVersion="c1"})==0)
		assert(names(world)["W7_CD_PlayDen__cliff_rock"]==1 and names(world)["W7_CD_Region__cliff_rock"]==1)
	end)
	test("the slice mounts: hides, replaces under the same name, overlays a colliding tile, places, builds boxes",function()
		local d=data()
		local world,storage=rig(d)
		local old=world.W7_CD_Region__cliff_rock
		old:SetAttribute("WorldRegion","Rocks")
		assert(Mount.world(world,{storage=storage,data=d,cliffVersion="c1"})[1]=="den")
		assert(world.W7_CD_Region__cliff_rock:GetAttribute("WorldRegion")=="Rocks","the copy keeps the pack part's attributes")
		local now=names(world)
		assert(now["W7_CD_PlayDen__cliff_rock"]==nil and now["W7_CD_Region__cliff_rock"]==1 and world.W7_CD_Region__cliff_rock~=old)
		assert(world.W7_CD_Region__cliff_rock.Template)
		local tile=world.W7_CD_Rocks__cliff_rock_2016
		assert(tile.Transparency==1 and tile.CanCollide==true,"the tile stays, invisible and colliding")
		local shell=world.W7_F_Den__shellWest
		assert(shell.CanCollide==false and shell.CanQuery==false and shell.Anchored==true)
		assert(shell.CFrame.Position==Vector3.new(-15,10,-110)and shell.Size==Vector3.new(14,13,20))
		assert(now["W7_F_Den__crystal"]==1 and now["W7_Bridge__marble"]==1)
		local box=world:FindFirstChild(Mount.BoxPrefix.."buttress_F1")
		assert(box and box.CanCollide==true and box.Transparency==1 and box.Size==Vector3.new(4,7,4))
		assert(world:GetAttribute("WorldFinish_den")==true and world:GetAttribute("WorldFinishTriangles")==100)
	end)
	test("the den's dress: only with the slice in the room's World; lanterns, paw stones and apron",function()
		local d=data()
		local world,storage=rig(d)
		local room=Instance.new("Model");world.Parent=room
		local function greybox()
			local model=Instance.new("Model")
			local lamp=part("W7D_Lantern3",model);lamp.CFrame=CFrame.new(0,8,-118.4);lamp.Size=Vector3.new(.8,1.1,.8);lamp.Transparency=0
			local light=Instance.new("PointLight");light.Shadows=true;light.Parent=lamp
			part("W7D_Lantern3Cap",model).Transparency=0
			part("W7D_LanternBracket3",model).Transparency=0
			local paw=part("W7D_Bay1Paw",model);paw.CFrame=CFrame.new(-18,4.23,-112);paw.Size=Vector3.new(.9,.06,.9);paw.Transparency=0
			local apron=part("W7D_ApronFront",model);apron.CanCollide=true;apron.Transparency=0
			local sill=part("W7D_FrameThreshold",model);sill.CanCollide=false;sill.Transparency=0
			local deck=part("W7D_bay2Deck",model);deck.Color=Color3.fromHex("#B8AE98");deck.Transparency=0
			local screen=part("W7D_bay2DeckScreen",model);screen.Color=Color3.fromHex("#9BE3C9")
			return model,lamp,light,paw,apron,sill,deck,screen
		end
		local model,lamp=greybox()
		assert(Mount.dressDen(model,room,{storage=storage,data=d,cliffVersion="c1"})==0 and lamp.Transparency==0,"no slice: no dress")
		Mount.world(world,{storage=storage,data=d,cliffVersion="c1"})
		local light,paw,apron,sill,deck,screen
		model,lamp,light,paw,apron,sill,deck,screen=greybox()
		assert(Mount.dressDen(model,room,{storage=storage,data=d,cliffVersion="c1"})==7)
		assert(sill.Transparency==1 and sill.CanCollide==false,"the gravel threshold row hides (the floor's shows)")
		assert(math.abs(deck.Color.R-0x5C/255)<1e-3 and math.abs(deck.Color.B-0x30/255)<1e-3 and deck.Transparency==0,"the Deck's body takes the stump's wood")
		assert(math.abs(screen.Color.G-0xE3/255)<1e-3,"the screen itself is untouched")
		assert(lamp.Transparency==1 and light.Shadows==false and model.W7D_Lantern3Cap.Transparency==1)
		assert(model.W7_F_Lantern__cage and model.W7_F_Lantern__pane and model.W7D_LanternCordF3,"the lantern and its cord")
		assert(model.W7D_LanternBracket3.Transparency==1 and paw.Transparency==1 and model.W7_F_Stone__flat)
		assert(apron.Transparency==1 and apron.CanCollide==true,"the slab keeps colliding")
	end)
	test("a slice that needs another mounts only on top of it; the terrace dress hides the greybox but keeps it colliding",function()
		local d=data()
		d.slices.path={packed=true,requires="den",templates={"W7_F_Den__crystal"},fixed={},
			instances={{template="W7_F_Den__crystal",cframe=cf(0,20,-60),size={.4,1,.4}}},hideBoxes={"lip"}}
		d.slices.terrace={packed=true,requires="path",templates={},fixed={},
			dressTier={prefix="W7T_",hide={"RimOuter"},remove={"ClumpOne"}}}
		local world,storage=rig(d)
		local oldLip=part(Mount.BoxPrefix.."lip_3",world)
		local keep=part(Mount.BoxPrefix.."lipstone_F1",world)
		local alone=table.clone(d.slices);alone.den=nil
		local d2=data({slices=alone})
		local w2,s2=rig(d)
		assert(#Mount.world(w2,{storage=s2,data=d2,cliffVersion="c1"})==0,"path without den: nothing")
		local got=Mount.world(world,{storage=storage,data=d,cliffVersion="c1"})
		assert(#got==3 and got[2]=="path"and got[3]=="terrace")
		assert(oldLip.Parent==nil and keep.Parent==world,"only the lip_ boxes go")
		local room=Instance.new("Model");world.Parent=room
		local model=Instance.new("Model")
		local rim=part("W7T_RimOuter",model);rim.CanCollide=true;rim.Transparency=0
		local clump=part("W7T_ClumpOne",model)
		local floor=part("W7T_Floor",model);floor.Transparency=0
		assert(Mount.dressTier(model,room,{storage=storage,data=d,cliffVersion="c1"})==2)
		assert(rim.Transparency==1 and rim.CanCollide==true and clump.Parent==nil and floor.Transparency==0)
	end)
	test("the den's dress, round 5: the lintel one plank row on the trim, the sign standing on it, the sheets cloth",function()
		local d=data()
		d.slices.den.dress.frame={lintel=.7,sign={7,1.8},gap=.15}
		d.slices.den.dress.cloth={color="#8C8474",material="SmoothPlastic"}
		local world,storage=rig(d)
		local room=Instance.new("Model");world.Parent=room
		Mount.world(world,{storage=storage,data=d,cliffVersion="c1"})
		local model=Instance.new("Model")
		local lintel=part("W7D_FrameLintel",model);lintel.Size=Vector3.new(17.5,1.3,1.2);lintel.CFrame=CFrame.new(-7,10.5,-98)
		local sign=part("W7D_Sign",model);sign.Size=Vector3.new(8,2.2,.25);sign.CFrame=CFrame.new(-7,10.5,-97.26)*CFrame.Angles(math.rad(-8),0,0)
		local sheet=part("W7D_bay3Sheet",model);sheet.Material=Enum.Material.Fabric
		local drape=part("W7D_bay3Drape",model)
		local crate=part("W7D_bay3Crate",model);crate.Material=Enum.Material.WoodPlanks
		assert(Mount.dressDen(model,room,{storage=storage,data=d,cliffVersion="c1"})==4)
		local under=lintel.CFrame.Position.Y-lintel.Size.Y/2
		assert(math.abs(under-9.85)<1e-4 and math.abs(lintel.Size.Y-.7)<1e-4,"the underside stays on the trim")
		local signBottom=sign.CFrame.Position.Y-sign.Size.Y/2
		assert(math.abs(signBottom-10.0)<1e-4 and sign.Size==Vector3.new(7,1.8,.25),"the sign stands on the lintel")
		assert(math.abs(sign.CFrame.Position.Z+97.26)<1e-4,"the sign keeps its tilt and depth")
		assert(sheet.Material==Enum.Material.SmoothPlastic and drape.Material==Enum.Material.SmoothPlastic)
		assert(math.abs(sheet.Color.R-0x8C/255)<1e-3 and crate.Material==Enum.Material.WoodPlanks,"only the cloth")
	end)
	test("the lip-stone kit for other builders: only with the path slice's kit; stretched to the stone it replaces",function()
		local d=data()
		local size=Vector3.new(3.6,2.6,2.4)
		assert(Mount.kitStone(2,Vector3.new(0,29,0),size,0,{storage=Instance.new("Folder"),data=d,cliffVersion="c1"})==nil,"no pack")
		d.slices.path={packed=true,requires="den",templates={"W7_F_Den__crystal"},fixed={},
			kit={W7_F_Lip2__boulder_rock={size={1.8,1.3,1.2},centre={0,.35,0}}}}
		local world,storage=rig(d)
		local env={storage=storage,data=d,cliffVersion="c1"}
		assert(Mount.kitStone(2,Vector3.new(0,29,0),size,0,env)==nil,"the pack is missing the kit piece")
		part("W7_F_Lip2__boulder_rock",storage[Mount.Pack],"MeshPart")
		assert(Mount.kitStone(4,Vector3.new(0,29,0),size,0,env)==nil,"no data for that piece")
		local stone=Mount.kitStone(2,Vector3.new(4,29,-6),size,0,env)
		assert(stone and stone.Template and stone.CanCollide==false and stone.Anchored==true)
		assert((stone.Size-size).Magnitude<1e-4,"the replaced stone's size")
		assert((stone.CFrame.Position-Vector3.new(4,29.7,-6)).Magnitude<1e-4,"its centre offset scaled per axis")
	end)
	test("the Top Lawn's stones come from the kit; the Hollow's stay carved (ParkHollowMount)",function()
		local Hollow=require(server.ParkHollowMount)
		local row={name="TopLawnRimBoulder",x=1,y=29,z=2,size=Vector3.new(2,1.1,1.7),yaw=.3,seed=20261161,colour="#8A8580"}
		local folder=Instance.new("Folder")
		local asked
		local drawn=Instance.new("Part")
		local got=Hollow.stone(row,folder,false,function(r)asked=r;return drawn end)
		assert(got==drawn and asked==row and drawn.Name=="TopLawnRimBoulder" and drawn.Parent==folder,"the kit stone stands in")
		assert(drawn.CanCollide==false and drawn.CastShadow==false and drawn:GetAttribute("ParkPart")==true)
		local carved=Hollow.stone(row,folder,false,function()return nil end)
		assert(carved and carved~=drawn and carved:GetAttribute("ParkFallback")==true,"no kit stone: its own stone")
	end)
	test("hideVisual: the tile goes invisible and keeps colliding; missing or named twice, nothing mounts",function()
		local d=data();d.slices.den.hideVisual={"W7_Bridge__marble"}
		local world,storage=rig(d)
		local bridge=world.W7_Bridge__marble;bridge.CanCollide=true;bridge.Transparency=0
		assert(Mount.world(world,{storage=storage,data=d,cliffVersion="c1"})[1]=="den")
		assert(bridge.Transparency==1 and bridge.CanCollide==true)
		local missing=data();missing.slices.den.hideVisual={"W7_Nowhere"}
		local w2,s2=rig(missing)
		assert(#Mount.world(w2,{storage=s2,data=missing,cliffVersion="c1"})==0)
		local twice=data();twice.slices.den.hideVisual={"W7_CD_Rocks__cliff_rock_2016"}
		local w3,s3=rig(twice)
		assert(#Mount.world(w3,{storage=s3,data=twice,cliffVersion="c1"})==0 and w3.W7_CD_Rocks__cliff_rock_2016.Transparency==0)
	end)
	test("the generated data: every slice names its templates and is bound to a sculpt",function()
		local ok,gen=pcall(function()return require(server.WorldFinishData)end)
		assert(ok and type(gen.version)=="string"and type(gen.cliffDen)=="string")
		for name,slice in pairs(gen.slices)do
			local set={};for _,t in ipairs(slice.templates)do set[t]=true end
			for _,row in ipairs(slice.fixed)do assert(set[row.name],name..": "..row.name)end
			for _,row in ipairs(slice.instances or {})do assert(set[row.template],name..": "..row.template)end
		end
	end)
	return {passed=#cases,cases=cases}
end
