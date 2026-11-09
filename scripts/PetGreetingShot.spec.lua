-- Native Client geometry/lifetime fixtures. Uses real pet models and isolated cameras;
-- does not change CurrentCamera, a player character, inventory, or live room state.
return function(client, _parent)
	local Shot = require(client.PetGreetingShot)
	local Pets = require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
	local fixture = Instance.new("Folder")
	fixture.Name, fixture.Parent = "_PetGreetingShotSpec", workspace
	local floor = { cf = CFrame.new(0, 3.5, 0), size = Vector3.new(112, 1, 96) }
	local cases, visuals, projections = {}, {}, 0
	local function test(name, run) run(); table.insert(cases, name) end
	local function makeVisual(pet,worldScale)
		local family = pet.family or pet.id
		local module = if family == "pip" then client.PipVisual elseif family == "puddle" then client.PuddleVisual else client.BonusPetVisual
		local visual = require(module).new(fixture, Vector3.new(0, 4.025, 0), pet,worldScale or .72)
		table.insert(visuals, visual)
		return visual
	end
	local function arguments(visual, aspect, rootPosition, forward)
		local bounds, size = visual.model:GetBoundingBox()
		return { rootPosition = rootPosition or Vector3.new(0, 7, 0), forward = forward or Vector3.new(0, 0, -1),
			silhouette=Shot.captureSilhouette(visual,bounds),animationTopReserve=.9*(visual.worldScale or 1),animationSideReserve=if visual.focusPose then .35 else .6,
			size = size, centerOffset = CFrame.Angles(0, visual.yaw or 0, 0):VectorToObjectSpace(bounds.Position - visual.origin),
			aspect = aspect or 16 / 9, floor = floor, ground = function() return 4.025 end, clear = function() return true end }
	end
	local function assertProjection(visual, plan, aspect, label)
		local bounds, size = visual.model:GetBoundingBox()
		assert(plan.fov == 43 and Shot.fits(plan.camera, bounds.Position, size, aspect, 43), label .. " bounding box exceeds padded frustum")
		local vertical = math.tan(math.rad(43) / 2)
		for _, part in ipairs(visual.model:GetDescendants()) do
			if not part:IsA("BasePart") then continue end
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local world = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				local point = plan.camera:PointToObjectSpace(world)
				local depth = -point.Z
				assert(depth > 0.5 and math.abs(point.X) <= depth * vertical * aspect * 0.90001
					and math.abs(point.Y) <= depth * vertical * 0.90001, label .. " clips " .. part.Name)
			end end end
		end
		projections += 1
	end
	local function assertFootprint(visual)
		for _, part in ipairs(visual.model:GetDescendants()) do
			if not part:IsA("BasePart") then continue end
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = floor.cf:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5))
				assert(math.abs(point.X) <= 56.0001 and math.abs(point.Z) <= 48.0001, "pet footprint crossed lounge edge: " .. part.Name)
			end end end
		end
	end
	local function sameFrame(actual, expected)
		return (actual.Position - expected.Position).Magnitude < 0.0001
			and (actual.LookVector - expected.LookVector).Magnitude < 0.0001
			and (actual.UpVector - expected.UpVector).Magnitude < 0.0001
	end
	local ok, problem = pcall(function()
		test("representative rest silhouette occupies55to65percent of post-inset safe height",function()
			for _,viewport in ipairs({Vector2.new(1649,971),Vector2.new(390,740),Vector2.new(733,307)})do
				local args={rootPosition=Vector3.new(0,7,0),forward=Vector3.new(0,0,-1),size=Vector3.new(1.5,2.4,1.1),centerOffset=Vector3.new(0,1.2,0),
					aspect=viewport.X/viewport.Y,viewportHeight=viewport.Y,safeTopInset=40,safeBottomInset=12,animationTopReserve=.65,
					floor=floor,ground=function()return 4.025 end,clear=function()return true end}
				local plan=Shot.plan(args);assert(plan,"no representative close focus")
				local fraction=Shot.projectedHeight(plan.camera,plan.origin+args.centerOffset,args.size)/(1-52/viewport.Y)
				assert(fraction>=.55 and fraction<=.65,"representative pet too distant or cropped: "..tostring(fraction).." at "..tostring(viewport))
			end
		end)
		test("actual Pip and Wick close focus fills safe height on desktop and portrait",function()
			for _,pet in ipairs({Pets.byId.pip,Pets.byId.wick})do
				for _,viewport in ipairs({Vector2.new(1649,971),Vector2.new(385,703)})do
					local visual=makeVisual(pet,.72);visual.focusPose=true;local args=arguments(visual,viewport.X/viewport.Y)
					local bounds=visual.model:GetBoundingBox();args.silhouette=Shot.captureSilhouette(visual,bounds)
					args.viewportHeight,args.safeTopInset,args.safeBottomInset,args.animationTopReserve=viewport.Y,58,0,.55*(visual.worldScale or 1)
					local plan=Shot.plan(args);assert(plan,"no actual close focus for "..pet.id)
					visual.origin,visual.yaw=plan.origin,plan.yaw;visual:update(0)
					local basis=CFrame.new(plan.origin)*CFrame.Angles(0,plan.yaw,0)*CFrame.new(args.centerOffset)
					local fraction=Shot.projectedPointsHeight(plan.camera,args.silhouette,basis)/(1-58/viewport.Y)
					assert(fraction>=.55 and fraction<=.65,pet.id.." actual safe-height fraction "..tostring(fraction).." at "..tostring(viewport))
					visual:destroy()
				end
			end
		end)
		test("piece capture excludes ripple and glints and near-plane projection fails closed",function()
			local body={Parent=true,CFrame=CFrame.new(0,1,0),Size=Vector3.new(1,2,1),Transparency=0}
			local huge={Parent=true,CFrame=CFrame.new(0,100,0),Size=Vector3.new(100,100,100),Transparency=0}
			local points=Shot.captureSilhouette({yaw=0,pieces={{part=body},{part=huge,role="ripple"},{part=huge,faceRole="spark"}}},CFrame.new(0,1,0))
			assert(#points==8)
			local camera=CFrame.lookAt(Vector3.new(0,0,8),Vector3.zero)
			assert(Shot.projectedPointsHeight(camera,points)>0 and Shot.projectedPointsHeight(CFrame.identity,points)==math.huge)
		end)
		for _,pet in ipairs(Pets.collection)do
			for _,focused in ipairs({false,true})do
				for _,viewport in ipairs({{"landscape",16/9},{"portrait",390/740},{"wide",568/160}})do
					test(pet.id..(if focused then " focused"else " ordinary").." complete greeting fits "..viewport[1],function()
						local visual=makeVisual(pet);visual.focusPose=focused
						local args=arguments(visual,viewport[2]);args.animationTopReserve=(if focused then .55 else .9)*visual.worldScale
						local plan=Shot.plan(args);assert(plan,"no supported greeting shot for "..pet.id)
						assert((plan.origin-args.rootPosition).Magnitude<=6.7,"greeting must remain inside authoritative reach")
						visual.origin,visual.yaw=plan.origin,plan.yaw;visual:update(0)
						assertProjection(visual,plan,viewport[2],pet.id..(if focused then "/focused/"else "/ordinary/")..viewport[1].."/rest")
						visual:greet()
						for frame=1,90 do visual:update(1/60);assertProjection(visual,plan,viewport[2],pet.id..(if focused then "/focused/"else "/ordinary/")..viewport[1].."/greeting@"..frame)end
						visual:destroy()
					end)
				end
			end
		end
		test("rest subject capture restores in-flight greeting fields and every visible pose",function()
			local Room=require(client.RoomView)
			for _,pet in ipairs(Pets.collection)do
				local v=makeVisual(pet);v:greet();v:update(.33)
				local greeting,focusPose,gait,bob,tilt,last=v.greeting,v.focusPose,v.gaitWeight,v.movementBob,v.affectionTilt,v.lastFrame
				local frames={};for _,entry in ipairs(v.pieces)do frames[entry.part]=entry.part.CFrame end
				local bounds,size,points=Room.captureFocusSubject(v,pet.family or pet.id)
				assert(bounds and size.Y>0 and #points>0)
				assert(v.greeting==greeting and v.focusPose==focusPose and v.gaitWeight==gait and v.movementBob==bob and v.affectionTilt==tilt and v.lastFrame==last,pet.id.." snapshot changed greeting ownership")
				for part,frame in pairs(frames)do assert((part.Position-frame.Position).Magnitude<.00001 and part.CFrame.LookVector:Dot(frame.LookVector)>.999999,pet.id.." snapshot changed original pose")end
				-- A cleared focus flag restores the full ordinary renderer at the same clock.
				v.focusPose=true;v:update(0);assert(v.model.PrimaryPart.Position.Y<frames[v.model.PrimaryPart].Y,pet.id.." focus did not soften greeting")
				v.focusPose=nil;v:update(0);assert((v.model.PrimaryPart.Position-frames[v.model.PrimaryPart].Position).Magnitude<.00001,pet.id.." ordinary greeting did not restore")
				v:destroy()
			end
		end)
		test("edges and corners keep the complete greeting footprint on supported floor", function()
			for _, edge in ipairs({ Vector3.new(52, 7, 0), Vector3.new(-52, 7, 0), Vector3.new(0, 7, 44), Vector3.new(0, 7, -44),
				Vector3.new(52, 7, 44), Vector3.new(-52, 7, 44), Vector3.new(52, 7, -44), Vector3.new(-52, 7, -44) }) do
				local visual = makeVisual(Pets.byId.foxfire_wick)
				local outward = Vector3.new(edge.X, 0, edge.Z).Unit
				local args = arguments(visual, 390 / 740, edge, outward)
				local groundCalls, clearCalls = 0, 0
				args.ground = function() groundCalls += 1; return 4.025 end
				args.clear = function() clearCalls += 1; return true end
				local plan = Shot.plan(args)
				assert(plan and (plan.origin - edge):Dot(outward) <= 0.001, "edge shot must turn toward available floor")
				assert(groundCalls <= 8 and clearCalls <= 8)
				visual.origin, visual.yaw = plan.origin, plan.yaw
				visual:greet(); visual:update(0.3)
				assertFootprint(visual)
				assertProjection(visual, plan, args.aspect, "edge " .. tostring(edge))
				visual:destroy()
			end
		end)
		test("missing floor or invalid viewport fails before world queries", function()
			local visual = makeVisual(Pets.byId.pip)
			local args, calls = arguments(visual), 0
			args.ground = function() calls += 1; return 4.025 end
			args.clear = function() calls += 1; return true end
			args.floor = nil; assert(Shot.plan(args) == nil and calls == 0)
			args.floor, args.aspect = floor, 0; assert(Shot.plan(args) == nil and calls == 0)
			visual:destroy()
		end)
		for _, condition in ipairs({ "no ground", "high ground", "blocked" }) do
			test(condition .. " falls back after bounded world queries", function()
				local visual = makeVisual(Pets.byId.pip)
				local args, groundCalls, clearCalls = arguments(visual), 0, 0
				args.ground = function()
					groundCalls += 1
					return if condition == "no ground" then nil elseif condition == "high ground" then 8 else 4.025
				end
				args.clear = function() clearCalls += 1; return false end
				assert(Shot.plan(args) == nil and groundCalls > 0 and groundCalls <= 8 and clearCalls <= 8)
				if condition ~= "blocked" then assert(clearCalls == 0) else assert(clearCalls > 0) end
				visual:destroy()
			end)
		end
		local function blocker(size, transform)
			local part = Instance.new("Part")
			part.Name, part.Size, part.CFrame = "OpaqueNonQuerySign", size, transform
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			part.Parent = fixture
			return part
		end
		test("a rotated non-query sign occludes a finite camera segment", function()
			local sign = blocker(Vector3.new(5, 0.6, 0.2), CFrame.new(0, 2, -5) * CFrame.Angles(0, math.rad(35), 0))
			assert(Shot.segmentBlocked(Vector3.new(0, 2, 0), Vector3.new(0, 2, -10), { sign }))
			assert(not sign.CanQuery and not sign.CanCollide, "visibility checks must preserve physics/query flags")
			sign:Destroy()
		end)
		test("parallel misses and padded grazes are distinguished", function()
			local sign = blocker(Vector3.new(2, 2, 2), CFrame.identity)
			assert(not Shot.segmentBlocked(Vector3.new(1.081, 0, -5), Vector3.new(1.081, 0, 5), { sign }))
			assert(Shot.segmentBlocked(Vector3.new(1.079, 0, -5), Vector3.new(1.079, 0, 5), { sign }), "0.08 visual padding must cover a near graze")
			sign:Destroy()
		end)
		test("blockers behind the camera or beyond the target do not occlude", function()
			local behind = blocker(Vector3.new(2, 2, 2), CFrame.new(0, 0, 3))
			local beyond = blocker(Vector3.new(2, 2, 2), CFrame.new(0, 0, -13))
			assert(not Shot.segmentBlocked(Vector3.zero, Vector3.new(0, 0, -10), { behind, beyond }))
			behind:Destroy(); beyond:Destroy()
		end)
		test("lower-body and side occluders can block while the center ray remains clear", function()
			local cameraPosition, center = Vector3.new(0, 3, 0), Vector3.new(0, 3, -10)
			local low = blocker(Vector3.new(3, 0.2, 0.2), CFrame.new(0, 1.5, -5))
			assert(not Shot.segmentBlocked(cameraPosition, center, { low }))
			assert(Shot.segmentBlocked(cameraPosition, Vector3.new(0, 0, -10), { low }))
			local side = blocker(Vector3.new(0.2, 0.8, 0.2), CFrame.new(1.5, 3, -5))
			assert(not Shot.segmentBlocked(cameraPosition, center, { side }))
			assert(Shot.segmentBlocked(cameraPosition, Vector3.new(3, 3, -10), { side }))
			low:Destroy(); side:Destroy()
		end)
		test("a blocked first candidate falls back to a clear shot within the query budget", function()
			local visual = makeVisual(Pets.byId.pip)
			local args, groundCalls, clearCalls = arguments(visual), 0, 0
			args.ground = function() groundCalls += 1; return 4.025 end
			args.clear = function() clearCalls += 1; return clearCalls > 1 end
			local plan = Shot.plan(args)
			assert(plan and clearCalls == 2 and groundCalls <= 8 and math.abs(plan.origin.X) > 1)
			visual.origin, visual.yaw = plan.origin, plan.yaw
			visual:greet(); visual:update(0.3)
			assertProjection(visual, plan, args.aspect, "second clear candidate")
			visual:destroy()
		end)
		test("a visible non-query owner accessory makes the lens choose another clear bearing",function()
			local visual=makeVisual(Pets.byId.pip);local args=arguments(visual)
			local first=assert(Shot.plan(args))
			local accessory=blocker(Vector3.new(1.5,4,.8),CFrame.new(first.camera.Position:Lerp(first.target,.5)))
			accessory.Name="VisibleOwnerAccessory"
			args.clear=function(from,target)return not Shot.segmentBlocked(from,target,{accessory})end
			local plan=assert(Shot.plan(args))
			assert(plan.bearing~=first.bearing and not Shot.segmentBlocked(plan.camera.Position,plan.target,{accessory}))
			assert(accessory.Transparency==0 and not accessory.CanQuery and not accessory.CanCollide)
			accessory:Destroy();visual:destroy()
		end)
		test("every visually blocked candidate yields a bounded roam fallback", function()
			local visual = makeVisual(Pets.byId.pip)
			local args, groundCalls, clearCalls = arguments(visual), 0, 0
			local enclosure = blocker(Vector3.new(100, 100, 100), CFrame.new(0, 4, 0))
			args.ground = function() groundCalls += 1; return 4.025 end
			args.clear = function(from, target)
				clearCalls += 1
				return not Shot.segmentBlocked(from, target, { enclosure })
			end
			assert(Shot.plan(args) == nil and groundCalls > 0 and groundCalls <= 8 and clearCalls > 0 and clearCalls <= 8)
			enclosure:Destroy(); visual:destroy()
		end)
		local character = Instance.new("Model")
		character.Name, character.Parent = "FixtureCharacter", fixture
		local root = Instance.new("Part")
		root.Name, root.Anchored, root.CanCollide, root.Position, root.Parent = "HumanoidRootPart", true, false, Vector3.new(2, 7, 3), character
		local camera = Instance.new("Camera")
		camera.Parent = fixture
		camera.CFrame, camera.Focus, camera.FieldOfView = CFrame.lookAt(Vector3.new(14, 12, 22), Vector3.new(1, 4, 0)), CFrame.new(1, 4, 0), 61
		local saved = Shot.capture(camera, root)
		test("restore keeps the original shot and focus translated by player motion", function()
			local delta = Vector3.new(3, 1, -5)
			root.Position += delta
			camera.CFrame, camera.Focus, camera.FieldOfView = CFrame.new(90, 80, 70), CFrame.new(60, 50, 40), 43
			assert(Shot.restore(saved, camera, root))
			assert(sameFrame(camera.CFrame, saved.transform + delta) and sameFrame(camera.Focus, saved.focus + delta) and camera.FieldOfView == 61)
		end)
		test("replacement camera or root cannot receive an old greeting restoration", function()
			local otherCamera = Instance.new("Camera")
			otherCamera.CFrame, otherCamera.Parent = CFrame.new(10, 20, 30), fixture
			local original = otherCamera.CFrame
			assert(not Shot.restore(saved, otherCamera, root) and sameFrame(otherCamera.CFrame, original))
			local otherRoot = root:Clone(); otherRoot.Parent = character
			assert(not Shot.restore(saved, camera, otherRoot))
			otherRoot:Destroy(); otherCamera:Destroy()
		end)
		test("a root reparented into another character or detached invalidates the snapshot", function()
			local nextCharacter = Instance.new("Model")
			nextCharacter.Parent = fixture
			root.Parent = nextCharacter
			local original = camera.CFrame
			assert(not Shot.restore(saved, camera, root) and sameFrame(camera.CFrame, original))
			root.Parent = nil; assert(not Shot.restore(saved, camera, root))
			root:Destroy(); nextCharacter:Destroy()
		end)
	end)
	for _, visual in ipairs(visuals) do visual:destroy() end
	fixture:Destroy()
	assert(ok, problem)
	return { passed = #cases, cases = cases, projectionChecks = projections, models = #Pets.collection }
end
