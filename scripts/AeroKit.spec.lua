-- Studio Client, or offline (default run of scripts/run_dash_server_specs.py). The island re-export (WORLD-PASS-2026-11-22
-- row 6): the Aero world kit's data (Shared.WorldAeroKit), how AeroKit places it, and the crowns' sway (WindClient's
-- second kind). Fixture templates, no live room: the island is never touched.
-- Usage: require(PlayerScripts.Client.ZZSpecs.AeroKit)(PlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Data=require(Shared.WorldAeroKit)
	local Kit=require(client.AeroKit)
	local Wind=require(client.Wind)
	local WindClient=require(client.WindClient)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function v(list)return Vector3.new(list[1],list[2],list[3])end
	local function near(a,b,within)return math.abs(a-b)<(within or 1e-3)end
	local function tip(rest,cf)return math.deg(math.acos(math.clamp(rest.UpVector:Dot(cf.UpVector),-1,1)))end

	-- Fixture templates: one MeshPart a name, cloned as the game clones ReplicatedStorage.AeroKit's.
	local function templates(missing)
		local made={}
		return{FindFirstChild=function(_,name)
			if name==missing or not Data.meshes[name]then return nil end
			made[name]=made[name]or{IsA=function(_,class)return class=="MeshPart"end,
				Clone=function()local p=Instance.new("MeshPart");p.Name=name;p.CastShadow=true;return p end}
			return made[name]
		end}
	end

	test("the data: 21 crowns on 4 crown meshes, the hides, rocks with a footprint, falls curves",function()
		assert(#Data.crowns==21,"crowns "..#Data.crowns)
		local meshes={}
		for _,crown in ipairs(Data.crowns)do
			local mesh=Data.meshes[crown.mesh]
			assert(mesh and mesh.role=="crown"and mesh.pivotToCentre,crown.mesh)
			assert(crown.scale>.5 and crown.scale<2 and typeof(v(crown.pivot))=="Vector3",crown.tree)
			meshes[crown.mesh]=true
		end
		local n=0;for _ in pairs(meshes)do n+=1 end
		assert(n==4,"crown meshes "..n)
		local hides=table.clone(Data.hides);table.sort(hides)
		assert(table.concat(hides,",")=="W7_Bubbles__bubble,W7_Landmarks__water,W7_Vegetation__foliage,W7_Vegetation__foliage_blossom,"
			.."W7_Water__foam,W7_Water__waterfall_tumble")
		local f=Data.fountain
		assert(f and near(f.centre[1],52)and near(f.centre[3],3)and f.top>f.bowl.y and f.bowl.y>f.water and f.water>f.centre[2])
		assert(#Data.rocks==10)
		for _,rock in ipairs(Data.rocks)do assert(rock.radius>.3 and rock.radius<2,rock.kind)end
		for name,fall in pairs(Data.falls)do assert(near(fall.curve,fall.bow/.75),name)end
	end)

	test("a shared crown stands on its own pivot: the pivot is where its tree's trunk ends, the yaw turns it",function()
		for _,crown in ipairs(Data.crowns)do
			local mesh=Data.meshes[crown.mesh]
			local cframe,size,pivot=Kit.crownFrame(crown,mesh)
			assert(pivot==v(crown.pivot))
			-- Back out: the centre seen from the pivot, unturned and unscaled, is the mesh's own offset.
			local back=CFrame.Angles(0,crown.yaw,0):VectorToObjectSpace(cframe.Position-pivot)/crown.scale
			assert((back-v(mesh.pivotToCentre)).Magnitude<1e-3,crown.tree)
			assert((size-v(mesh.size)*crown.scale).Magnitude<1e-3)
			-- The import turned every mesh by pi about Y; the tree's yaw comes on top.
			local want=CFrame.Angles(0,crown.yaw,0)*Kit.Turn
			assert((cframe.LookVector-want.LookVector).Magnitude<1e-3 and (cframe.UpVector-want.UpVector).Magnitude<1e-3)
		end
	end)

	test("build: crowns sway-ready and shadowless, rest and falls in place, an invisible ball a rock, one folder",function()
		local room=Instance.new("Folder")
		local built=Kit.build({data=Data,templates=templates(),parent=room})
		assert(built.folder.Parent==room and built.folder.Name==Kit.Folder)
		local crowns,balls,placed,stems,lime=0,0,0,0,0
		for _,p in ipairs(built.folder:GetChildren())do
			if p.Name=="FountainCollision"then
				stems+=1
				assert(p.CanCollide==true and p.CanQuery==false and p.Transparency==1)
				assert(near(p.CFrame.Position.X,52)and near(p.CFrame.Position.Z,3))
			elseif p.Name=="RockCollision"then
				balls+=1
				assert(p.CanCollide==true and p.CanQuery==false and p.CanTouch==false and p.Transparency==1 and p.Anchored)
			else
				assert(p.Anchored and p.CanCollide==false and p.CanQuery==false and p.CanTouch==false and p:GetAttribute("WorldMesh")==true,p.Name)
				if p:GetAttribute("WorldDressing")=="crown"then
					crowns+=1
					assert(p.CastShadow==false,"a moving crown casts no shadow")
					assert(p:GetAttribute("WorldRestCFrame")==p.CFrame and typeof(p:GetAttribute("WorldPivot"))=="Vector3")
				else
					placed+=1
					local mesh=Data.meshes[p.Name]
					assert(mesh and(mesh.role=="rest"or mesh.role=="falls"or mesh.role=="fountain"))
					assert((p.CFrame.Position-v(mesh.center)).Magnitude<1e-3)
				end
			end
		end
		assert(stems==1,"one stem collider")
		assert(crowns==21 and balls==#Data.rocks and placed==4,tostring(crowns).." "..tostring(balls).." "..tostring(placed))
		built.destroy()
		assert(built.folder.Parent==nil)
	end)

	test("near fade: the camera inside a crown clears it to .8, the avatar to .5, out of Room mode straight back to 0",function()
		local part=Instance.new("Part");part.Size=Vector3.new(8,6,8);part.CFrame=CFrame.new(10,10,10)
		part:SetAttribute("WorldDressing","crown")
		assert(Kit.fadeTarget(part,Vector3.new(10,10,10),nil)==.8 and Kit.fadeTarget(part,Vector3.new(15.4,10,10),nil)==.8)
		assert(Kit.fadeTarget(part,Vector3.new(16,10,10),nil)==0,"past the margin")
		assert(Kit.fadeTarget(part,Vector3.new(40,10,10),Vector3.new(10,8,10))==.5,"only the avatar inside")
		assert(Kit.fadeTarget(part,nil,nil)==0)
		local on,cam=true,Vector3.new(10,10,10)
		local fader=Kit.fader({part},{active=function()return on end,camera=function()return cam end,root=function()return nil end})
		for _=1,20 do fader.step(1/30)end
		assert(near(part.LocalTransparencyModifier,.8),"in over a quarter second: "..tostring(part.LocalTransparencyModifier))
		cam=Vector3.new(50,10,10)
		for _=1,8 do fader.step(1/30)end -- the next look (every .15 s), then a few frames out
		assert(part.LocalTransparencyModifier<.8 and part.LocalTransparencyModifier>0,"easing out")
		on=false;fader.step(1/30)
		assert(part.LocalTransparencyModifier==0,"a race or the deck: back to 0 at once")
		part.LocalTransparencyModifier=.75 -- another owner (DashFade) now
		for _=1,10 do fader.step(1/30)end
		assert(part.LocalTransparencyModifier==.75,"closed: writes nothing")
		fader.destroy()
		assert(part.LocalTransparencyModifier==.75,"destroy leaves another owner's value alone")
		-- Faded when it goes: back to 0.
		part.LocalTransparencyModifier=0;on=true;cam=Vector3.new(10,10,10)
		local again=Kit.fader({part},{active=function()return true end,camera=function()return cam end,root=function()return nil end})
		for _=1,20 do again.step(1/30)end
		assert(part.LocalTransparencyModifier>.5);again.destroy();assert(part.LocalTransparencyModifier==0)
	end)
	test("a missing template or bad data throws before anything reaches the room",function()
		local room=Instance.new("Folder")
		assert(not pcall(Kit.build,{data=Data,templates=templates("W7_Kit_Crown_Tall__foliage"),parent=room}))
		assert(not pcall(Kit.build,{data={},templates=templates(),parent=room}))
		assert(not pcall(Kit.build,{data=Data,templates=nil,parent=room}))
		assert(#room:GetChildren()==0)
	end)

	test("crown sway: 1.2 degrees at the breeze, 4 at full wind, leaning up to 1.5 downwind with the gust",function()
		local c=WindClient.Crown
		assert(c.Rest==1.2 and c.Peak==4 and c.Lean==1.5 and c.PeriodMin==3.4 and c.PeriodMax==4.6)
		assert(near(WindClient.amplitude(Wind.Breeze,c.Rest,c.Peak),1.2)and near(WindClient.amplitude(1,c.Rest,c.Peak),4))
		assert(WindClient.amplitude(0,c.Rest,c.Peak)==0 and WindClient.gustShare(Wind.Breeze)==0 and WindClient.gustShare(1)==1)
		assert(WindClient.gustShare(0/0)==0 and WindClient.amplitude(0/0)==0)
		-- Bushes keep their own numbers.
		assert(near(WindClient.amplitude(1),WindClient.Peak)and near(WindClient.amplitude(Wind.Breeze),WindClient.Rest))
		local pivot=Vector3.new(10,8,-4)
		local rest=CFrame.new(10,9,-4)*CFrame.Angles(0,.7,0)
		-- Still air and zero shown: exactly at rest.
		assert(WindClient.crownPose(rest,pivot,0,1,.3)==rest and WindClient.crownPose(rest,pivot,1,0,.3)==rest)
		-- Full wind at the swing's middle (turn 0: no swing along the wind): the lean alone, downwind, about the pivot.
		local pose=WindClient.crownPose(rest,pivot,1,1,0)
		local top=pose:PointToWorldSpace(Vector3.new(0,1,0))-rest:PointToWorldSpace(Vector3.new(0,1,0))
		assert(top:Dot(Wind.Direction)>0,"the lean is downwind")
		assert((pose:PointToWorldSpace(rest:PointToObjectSpace(pivot))-pivot).Magnitude<1e-4,"the pivot does not move")
		local worst=0
		for k=0,40 do worst=math.max(worst,tip(rest,WindClient.crownPose(rest,pivot,1,1,k/40)))end
		assert(worst<=c.Peak+c.Lean+.05 and worst>=c.Peak,"peak tilt "..worst)
	end)

	test("caps: crowns first up to their quota, bushes fill the rest; no kit, the bushes as before",function()
		local function rig(bushes,crowns,caps)
			local self={entries={},caps=caps,eye=function()return Vector3.zero end}
			for i=1,bushes do table.insert(self.entries,{kind="bush",rest=CFrame.new(i,0,0)})end
			for i=1,crowns do table.insert(self.entries,{kind="crown",rest=CFrame.new(0,0,i+.5)})end
			WindClient.select(self,0)
			local b,c=0,0
			for _,e in ipairs(self.entries)do if e.wanted then if e.kind=="crown"then c+=1 else b+=1 end end end
			return b,c
		end
		local b,c=rig(30,0,WindClient.Phone);assert(b==16 and c==0,"no kit on a phone: "..b)
		b,c=rig(30,21,WindClient.Phone);assert(b==10 and c==6,"phone "..tostring(b).."+"..tostring(c))
		b,c=rig(60,21,WindClient.Desktop);assert(b==32 and c==12,"desktop "..tostring(b).."+"..tostring(c))
		b,c=rig(3,21,WindClient.Phone);assert(b==3 and c==6)
		b,c=rig(30,2,WindClient.Phone);assert(b==14 and c==2)
		assert(WindClient.Phone.count==16 and WindClient.Phone.range==120,"the phone cap is unchanged")
		assert(WindClient.Folders.Dressing=="bush"and WindClient.Folders.AeroKit=="crown"and Kit.Folder=="AeroKit")
	end)

	return{passed=#cases,cases=cases}
end
