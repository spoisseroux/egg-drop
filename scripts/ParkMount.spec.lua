-- Pet Park equipment mount (BUILD-PLAN 2026-11-13, slice K3): flag off builds nothing; visual meshes
-- are anchored and non-queryable / non-colliding / non-touching; invisible colliders and bench Seats
-- exist; the garden's path and ground raycasts (RespectCanCollide + Include lounge, as in
-- init.server validWander / resolveTarget / petAnchor) pass straight through every park part; the
-- rest-path solid filter skips the park. Fake meshes (no AssetService) and a throwaway room model.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.ParkMount)(ServerScriptService.Server)
return function(server,parent)
	local Mount=require(server.ParkMount)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Park=require(Shared.ParkLayout)
	local Data=require(Shared.ParkPoseData)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	assert(Park.Enabled,"ParkLayout needs the v7 world")
	local room=Instance.new("Model");room.Name="_ParkMountSpec"
	-- A flat stand-in lawn exactly at the park's ground height, far enough below nothing else.
	local floor=Instance.new("Part");floor.Name="Floor";floor.Anchored=true;floor.Size=Vector3.new(80,1,80)
	floor.CFrame=CFrame.new(Park.Center.X,Park.Center.Y-.025-.5,Park.Center.Z);floor.Parent=room
	room.Parent=parent or workspace
	-- The park mounts beside the lounge, not inside it (2026-11-13 Studio run): the garden's
	-- RespectCanCollide + Include-lounge rays then never see the player colliders.
	local host=Instance.new("Folder");host.Name="_ParkMountHost";host.Parent=parent or workspace
	local loads=0
	local function fakeMesh(id)loads+=1;assert(type(id)=="string"and string.find(id,"^rbxassetid://%d+$"),"bad mesh id "..tostring(id));return Instance.new("MeshPart")end
	local ok,err=pcall(function()
		test("flag off builds nothing",function()
			assert(Mount.build(host,{enabled=false,createMesh=fakeMesh,async=false})==nil,"built with the flag off")
			assert(host:FindFirstChild(Mount.ModelName)==nil and loads==0,"instances or loads with the flag off")
		end)

		local model=Mount.build(host,{enabled=true,createMesh=fakeMesh,async=false})
		local layout=Data.layout()
		test("visual meshes are anchored and invisible to raycasts, collisions and touches",function()
			assert(model and model.Parent==host and model:GetAttribute("ParkMeshesReady")==true,"model not mounted")
			local meshes=model.Meshes:GetChildren()
			assert(#meshes==#layout.static and #meshes>=30,"mesh count "..#meshes)
			local kerb,posts,orbs=0,0,0
			for _,part in ipairs(meshes)do
				assert(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch,part.Name.." collides or queries")
				assert(part:IsA("MeshPart")and part.TextureID==Data.Texture,part.Name.." lacks the palette texture")
				assert(Mount.isParkPart(part))
				if string.find(part.Name,"^Park_KerbSegment")then kerb+=1 end
				if string.find(part.Name,"^Park_GatePost")then posts+=1 end
				if string.find(part.Name,"^Park_GateStarOrb")then orbs+=1;assert(part:FindFirstChildOfClass("PointLight"),"orb without light")end
			end
			assert(kerb==layout.kerbSegments and kerb>=16 and posts==4 and orbs==4,"kerb "..kerb.." posts "..posts.." orbs "..orbs)
			for _,name in ipairs(Data.Moving)do
				for _,part in ipairs(meshes)do assert(not string.find(part.Name,"^"..name.."_"),"moving mesh "..name.." mounted on the server")end
			end
		end)

		test("kerb leaves both gateways open",function()
			for _,gate in ipairs(Park.Gateways)do
				for _,part in ipairs(model.Meshes:GetChildren())do
					if string.find(part.Name,"^Park_KerbSegment")then
						local gap=Vector2.new(part.Position.X-gate.position.X,part.Position.Z-gate.position.Z).Magnitude
						assert(gap>gate.width*.5,"kerb segment inside gateway "..gate.id)
					end
				end
			end
		end)

		test("players get invisible colliders and bench Seats",function()
			local colliders=model.Colliders:GetChildren()
			assert(#colliders==#layout.colliders and #colliders>=15,"collider count "..#colliders)
			for _,part in ipairs(colliders)do
				assert(part.Anchored and part.CanCollide and not part.CanQuery and not part.CanTouch and part.Transparency==1,part.Name)
				assert(Mount.isParkPart(part))
			end
			local seats=model.Seats:GetChildren()
			local expected=0;for _,bench in ipairs(Park.Benches)do expected+=bench.seats end
			assert(#seats==expected,"seat count "..#seats)
			for _,seat in ipairs(seats)do
				assert(seat:IsA("Seat")and seat.Anchored and not seat.CanTouch and not seat.CanQuery and not seat.CanCollide and seat:FindFirstChild("SitPrompt"),seat.Name.." (prompt-only seat)")
				assert(seat.SitPrompt.ActionText=="Sit","seat prompt text")
				assert(Park.inside(seat.Position,0),"seat outside the kerb: "..seat.Name)
			end
		end)

		test("QA Q4: one five-seat bench by the entrance, every seat facing the playground centre",function()
			assert(#Park.Benches==1 and Park.Benches[1].seats==5,"keep only the entrance bench, with five seats")
			local seats=model.Seats:GetChildren()
			assert(#seats==5,"five seats")
			for _,seat in ipairs(seats)do
				-- A seated player faces the Seat's LookVector.
				local toCentre=Vector3.new(Park.Center.X-seat.Position.X,0,Park.Center.Z-seat.Position.Z).Unit
				assert(seat.CFrame.LookVector:Dot(toCentre)>.9,seat.Name.." faces away from the playground")
			end
			-- The visual backrest sits behind the sitter: the bench mesh's authored front (+Z, after the
			-- import turn is undone) points the same way as the seats.
			for _,part in ipairs(model.Meshes:GetChildren())do
				if string.find(part.Name,"^Park_Bench")then
					local authored=part.CFrame*Data.ImportTurn
					assert(authored.LookVector:Dot(seats[1].CFrame.LookVector)<-.9,part.Name.." mesh turned away from its seats")
				end
			end
		end)

		test("QA Q4: every mesh carries the import turn, so the slide's ladder is where pets climb",function()
			local slide
			for _,part in ipairs(model.Meshes:GetChildren())do if string.find(part.Name,"^Park_Slide")then slide=part end end
			assert(slide,"no slide mesh")
			-- The uploaded mesh is the authored mesh turned by pi about Y; undo it to read authored axes.
			local authored=slide.CFrame*Data.ImportTurn
			local ladder=authored:PointToObjectSpace(Data.Slide.ladder[1])
			local chute=authored:PointToObjectSpace(Data.Slide.chute[#Data.Slide.chute])
			assert(ladder.Z<-3,"ladder foot is not on the mesh's ladder side ("..ladder.Z..")")
			assert(chute.Z>3,"chute end is not on the mesh's chute side ("..chute.Z..")")
			assert((slide.CFrame*slide.PivotOffset).Position:FuzzyEq(Data.Roots.Slide.Position,1e-3),"slide pivot is not the group root")
		end)

		test("anchor frames for the client are published as attributes",function()
			for key,frame in pairs(layout.anchors)do
				assert(model:GetAttribute(key)==frame,"attribute "..key)
			end
		end)

		test("ground and path raycasts ignore every park part",function()
			local params=RaycastParams.new();params.RespectCanCollide=true
			params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
			local probes={Park.Slots.slide.approach,Park.Slots.slide.chuteEnd,Data.Slide.platform,Park.Slots.swing1.approach,
				Park.Slots.seesaw2.approach,Park.Slots.sand1.approach,Park.Slots.ball2.approach}
			for _,bench in ipairs(Park.Benches)do table.insert(probes,bench.position)end
			for _,part in ipairs(model.Colliders:GetChildren())do table.insert(probes,part.Position)end
			for _,part in ipairs(model.Meshes:GetChildren())do table.insert(probes,part.Position)end
			for _,probe in ipairs(probes)do
				local hit=workspace:Raycast(Vector3.new(probe.X,Park.Center.Y+8,probe.Z),Vector3.new(0,-80,0),params)
				assert(hit and hit.Instance==floor,"a park part caught a ground ray at "..tostring(probe))
			end
			-- Horizontal segment checks (validWander's lifted chord) cross the whole park untouched.
			local lift=Vector3.new(0,.7,0)
			for _,pair in ipairs({{Park.Slots.ball1.approach,Park.Slots.swing2.approach},{Park.Slots.slide.approach,Park.Slots.slide.chuteEnd},{Park.Gateways[1].position,Park.Gateways[2].position}})do
				local a,b=pair[1],pair[2]
				assert(workspace:Raycast(a+lift,b-a,params)==nil,"a park part blocks a pet chord")
			end
		end)

		test("rest-path solids skip park colliders (pets are visuals)",function()
			local solids=0
			for _,node in ipairs(room:GetDescendants())do
				if node:IsA("BasePart")and node.CanCollide and node.Name~="Floor"and not Mount.isParkPart(node)then solids+=1 end
			end
			assert(solids==0,"park parts would enter the rest-path solids")
		end)

		test("a failed mesh becomes a grey box of the same size",function()
			local part=Mount.makePart("Park_Bench",function()return nil end)
			assert(part:IsA("Part")and part:GetAttribute("ParkFallback")==true and not part.CanQuery and not part.CanCollide)
			part:Destroy()
		end)

		test("rebuilding replaces the old model",function()
			local again=Mount.build(host,{enabled=true,createMesh=fakeMesh,async=false})
			local count=0
			for _,child in ipairs(host:GetChildren())do if child.Name==Mount.ModelName then count+=1 end end
			assert(count==1 and again.Parent==host and model.Parent==nil,"duplicate park models")
		end)
	end)
	room:Destroy();host:Destroy()
	assert(ok,err)
	return {passed=#cases,cases=cases}
end
