-- Run on Server with the production Server folder and StarterPlayerScripts.Client.
-- Real planner/factory/coordinator/care broker; isolated models and injected time.
-- No CurrentCamera, Player character, real remote, storage, or reward mutation.
return function(server,client)
    local Shot=require(client.PetGreetingShot)
    local Room=require(client.RoomView)
    local Factory=require(client.PetFactory)
    local Prestige=require(client.PetPrestige)
    local Garden=require(server.GardenState)
    local Contact=require(server.PetContact)
    local Activity=require(game.ReplicatedStorage.Shared.GardenActivity)
    local Bounds=require(client.PetRigBounds)
    local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
    local fixture=Instance.new("Folder");fixture.Name="_GardenFocusReach";fixture.Parent=workspace
    local floor={cf=CFrame.new(0,3.5,0),size=Vector3.new(160,1,128)}
    local cases,metrics={},{};local tested=0
    local function test(name,run)run();table.insert(cases,name)end
    local function owner(position)
        local model=Instance.new("Model");model.Name="FixtureOwner";model.Parent=fixture
        local parts={}
        for _,entry in ipairs({{Vector3.zero,Vector3.new(2,2,1)},{Vector3.new(0,1.6,0),Vector3.new(1.2,1.2,1.2)},
            {Vector3.new(-1.5,0,0),Vector3.new(.8,2,1)},{Vector3.new(1.5,0,0),Vector3.new(.8,2,1)},
            {Vector3.new(-.5,-2,0),Vector3.new(.9,2,1)},{Vector3.new(.5,-2,0),Vector3.new(.9,2,1)}})do
            local part=Instance.new("Part");part.Size=entry[2];part.CFrame=CFrame.new(position+entry[1]);part.Anchored=true
            part.CanQuery,part.CanCollide=false,false;part.Parent=model;table.insert(parts,part)
        end
        return model,parts
    end
    local function arguments(visual,viewport,root,parts,pet)
        local bounds,size,points,focusEnvelope=Room.captureFocusSubject(visual,(pet or visual.pet).family or(pet or visual.pet).id)
        return {rootPosition=root,forward=if root.X>70 then Vector3.new(root.X,0,root.Z).Unit else Vector3.new(0,0,1),
            size=size,silhouette=points,focusEnvelope=focusEnvelope,centerOffset=CFrame.Angles(0,visual.yaw or 0,0):VectorToObjectSpace(bounds.Position-visual.origin),
            aspect=viewport.X/viewport.Y,viewportHeight=viewport.Y,safeTopInset=40,safeBottomInset=12,
            crestPixelReserve=Prestige.crestReserve(visual),animationTopReserve=.55*(visual.worldScale or 1),floor=floor,
            ground=function()return 4.025 end,clear=function(position,target,origin)
                local right=CFrame.lookAt(position,target).RightVector*math.max(size.X,size.Z)*.5
                for _,point in ipairs({target,origin+Vector3.new(0,1,0),origin+Vector3.new(0,.12,0)-right,origin+Vector3.new(0,.12,0)+right})do
                    if Shot.segmentBlocked(position,point,parts)then return false end
                end
                return true
            end}
    end
    local ok,problem=pcall(function()
        test("all seven production rigs and supported Dot states acquire and keep the public anchor independent of their private stage",function()
            for _,pet in ipairs(Pets.collection)do
                local appearances=if pet.id=="pip"or pet.id=="puddle"then {true,false}else {true}
                for _,visible in ipairs(appearances)do
                    local visual=Factory.new(fixture,Vector3.new(0,4.025,0),pet,.72,{charmVisible=visible})
                    visual.focusPose=true
                    for _,viewport in ipairs({Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(390,740),Vector2.new(568,160)})do
                        for _,root in ipairs({Vector3.new(-11,6.998,4),Vector3.new(75,6.998,58)})do
                            local avatar,parts=owner(root)
                            local args=arguments(visual,viewport,root,parts,pet)
                            local plan=Shot.plan(args)
                            assert(plan,string.format("%s Dot=%s viewport=%s root=%s no legal stage",pet.id,tostring(visible),tostring(viewport),tostring(root)))
                            local reach=(plan.origin-root).Magnitude
                            assert(reach<=6.7 and reach<7,"planner exceeded activity authority")
                            visual.origin,visual.yaw,visual.lastFrame=plan.origin,plan.yaw,-1;visual:update(0)
                            local function fitsPose()
                                if args.focusEnvelope then
                                    local points,names={},{}
                                    for _,entry in ipairs(visual.pieces)do
                                        local part=entry.part;if part.Transparency>=.99 then continue end
                                        for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                                            table.insert(points,part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*.5));table.insert(names,part.Name)
                                        end end end
                                    end
                                    local fits,part,edge=Shot.sweptFits(plan.camera,{points=points,names=names},CFrame.identity,args.aspect,Shot.Fov,args.crestPixelReserve,viewport.Y,40,12)
                                    assert(fits,"accepted focus clips "..pet.id.."/"..tostring(part).."/"..tostring(edge).." at "..tostring(viewport))
                                else
                                    local bounds,size=Bounds.get(visual)
                                    assert(Shot.fits(plan.camera,bounds.Position,size,args.aspect,Shot.Fov,args.crestPixelReserve,viewport.Y,40,12),
                                        "accepted focus clips "..pet.id.." at "..tostring(viewport))
                                end
                            end
                            fitsPose()
                            if pet.id=="pip"or pet.id=="puddle"then
                                visual:greet()
                                for _=1,60 do visual:update(1/60);fitsPose()end
                            end
                            local now=0
                            local input={petId=pet.id,owned=true,alive=true,mode="Room",position=root,anchor=Vector3.new(root.X,4.025,root.Z),
                                characterId=1,petGeneration=2,yaw=0,charmVisible=visible}
                            local coordinator=Garden.new({now=function()return now end,validFocus=function()return true end})
                            coordinator:syncOne(101,input)
                            assert(coordinator:focus(101,{kind="focus",seq=1,petId=pet.id,characterId=1,petGeneration=2,position=Activity.pack(plan.origin),yaw=plan.yaw}),"actual coordinator rejected legal planner target")
                            now=.5;assert(coordinator:focus(101,{kind="focusPulse",seq=1,petId=pet.id,characterId=1,petGeneration=2}))
                            local sample=Activity.sample(coordinator:snapshot().actors["101"],now)
                            assert((sample.position-input.anchor).Magnitude<.0001 and math.abs(sample.yaw-input.yaw)<.0001)
                            local anchor=coordinator:focusAnchor(101,pet.id,1,2,root)
                            assert(anchor and(anchor-input.anchor).Magnitude<.0001,"care anchor differs from the visible/peer pet")
                            local state={mode="Room",petId=pet.id,owned=true,alive=true,ready=true,status="Ready",position=root,character=avatar,root=parts[1],epoch=1}
                            local broker=Contact.new({now=function()return now end,guid=function()return "focus-care"end,read=function()return state end,
                                anchor=function()return coordinator:focusAnchor(101,pet.id,1,2,root)end,emit=function()end,
                                random=function()error("short focus fixture must not roll a reward")end})
                            assert(broker:begin({requestGeneration=1,petId=pet.id})and(broker.lease.anchor-input.anchor).Magnitude<.0001)
                            broker:destroy();tested+=1
                            table.insert(metrics,{petId=pet.id,dot=visible,viewport=tostring(viewport),edge=root.X>70,reach=reach,bearing=plan.bearing})
                            avatar:Destroy()
                        end
                    end
                    visual:destroy()
                end
            end
        end)
        test("Dot and viewport reframe keeps the accepted stage while solving an independent lens",function()
            local visual=Factory.new(fixture,Vector3.new(0,4.025,0),Pets.byId.pip,.72,{charmVisible=true})
            local root=Vector3.new(-11,6.998,4);local avatar,parts=owner(root)
            local first=assert(Shot.plan(arguments(visual,Vector2.new(733,307),root,parts, Pets.byId.pip)))
            visual:applyAppearance({charmVisible=false})
            local args=arguments(visual,Vector2.new(390,740),root,parts, Pets.byId.pip);args.preferredOrigin,args.preferredBearing=first.origin,first.bearing
            local second=assert(Shot.plan(args))
            assert((second.origin-first.origin).Magnitude<.0001 and second.bearing==first.bearing)
            assert((second.camera.Position-first.camera.Position).Magnitude>.01,"lens should be independently remeasured")
            avatar:Destroy();visual:destroy()
        end)
        test("same accepted target is rejected for stale pet or character generation",function()
            local now=0;local g=Garden.new({now=function()return now end})
            local root=Vector3.new(-11,6.998,4);local input={petId="pip",owned=true,alive=true,mode="Room",position=root,anchor=Vector3.new(-11,4.025,4),characterId=1,petGeneration=1}
            g:syncOne(1,input);assert(g:focus(1,{kind="focus",seq=1,petId="pip",characterId=1,petGeneration=1,position={-8.6,4.025,8.8},yaw=0}))
            assert(g:focusAnchor(1,"pip",1,1,root))
            assert(g:focusAnchor(1,"pip",2,1,root)==nil and g:focusAnchor(1,"pip",1,2,root)==nil)
        end)
        test("the exact pre-focus camera survives staging and owner translation",function()
            local avatar,parts=owner(Vector3.new(-11,6.998,4));local root=parts[1]
            local camera=Instance.new("Camera");camera.CFrame=CFrame.lookAt(Vector3.new(-6,12,16),Vector3.new(-11,7,4));camera.Focus=CFrame.new(-11,7,4);camera.FieldOfView=65;camera.Parent=fixture
            local saved=Shot.capture(camera,root);local delta=Vector3.new(2,0,-1);root.CFrame+=delta
            camera.CFrame=CFrame.new(30,20,10);camera.Focus=CFrame.new(30,20,0);camera.FieldOfView=Shot.Fov
            assert(Shot.restore(saved,camera,root))
            assert((camera.CFrame.Position-(saved.transform+delta).Position).Magnitude<.0001 and camera.CFrame.LookVector:Dot(saved.transform.LookVector)>.99999)
            assert((camera.Focus.Position-(saved.focus+delta).Position).Magnitude<.0001 and camera.FieldOfView==65)
            avatar:Destroy();camera:Destroy()
        end)
    end)
    fixture:Destroy();assert(ok,problem)
    return{passed=#cases,cases=cases,plans=tested,metrics=metrics}
end
