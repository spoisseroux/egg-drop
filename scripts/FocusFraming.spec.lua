-- Actual factory body size and focused envelope, independent of authority/camera owner.
return function(client)
    local Factory=require(client.PetFactory);local Room=require(client.RoomView);local Shot=require(client.PetGreetingShot)
    local Bounds=require(client.PetRigBounds);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
    local folder=Instance.new("Folder");folder.Name="_FocusFraming";folder.Parent=workspace
    local floor={cf=CFrame.new(0,3.5,0),size=Vector3.new(160,1,128)}
    local cases,metrics={},{};local function test(name,run)run();table.insert(cases,name)end
    local function args(visual,pet,root,viewport,badge)
        local bounds,size,body,envelope=Room.captureFocusSubject(visual,pet.id)
        return{rootPosition=root,forward=Vector3.new(0,0,1),size=size,silhouette=body,focusEnvelope=envelope,
            centerOffset=CFrame.Angles(0,visual.yaw or 0,0):VectorToObjectSpace(bounds.Position-visual.origin),
            aspect=viewport.X/viewport.Y,viewportHeight=viewport.Y,safeTopInset=58,safeBottomInset=0,crestPixelReserve=badge or 0,
            floor=floor,ground=function()return 4.025 end,clear=function()return true end}
    end
    local function bodyFraction(visual,plan,argument)
        local bounds=Bounds.getBody(visual)
        local points=Shot.captureSilhouette(visual,bounds)
        local basis=CFrame.new(bounds.Position)*CFrame.Angles(0,visual.yaw or 0,0)
        return Shot.projectedPointsHeight(plan.camera,points,basis)/(1-58/argument.viewportHeight)
    end
    local function contained(visual,plan,argument)
        local points,names={},{}
        for _,entry in ipairs(visual.pieces)do
            local p=entry.part;if p.Transparency>=.99 then continue end
            for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                table.insert(points,p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)*.5));table.insert(names,p.Name)
            end end end
        end
        local fits,part,edge=Shot.sweptFits(plan.camera,{points=points,names=names},CFrame.identity,argument.aspect,Shot.Fov,argument.crestPixelReserve,argument.viewportHeight,58,0)
        assert(fits,tostring(part).." crosses "..tostring(edge))
    end
    local ok,problem=pcall(function()
        test("both backends keep long idle, gaze, blink and independent Dot inside the focused envelope",function()
            local Visual=require(client.GardenPetVisual)
            for _,id in ipairs({"pip","puddle"})do for _,native in ipairs({false,true})do for _,dot in ipairs({true,false})do
                local visual=Visual.new(folder,Vector3.new(0,4.025,0),Pets.byId[id],.72,{charmVisible=dot},{native=native})
                visual.focusPose=true;visual.cosmeticSeed=823
                local argument=args(visual,Pets.byId[id],Vector3.new(-11,6.998,4),Vector2.new(749,381),0)
                assert(argument.focusEnvelope.motionBoundsVersion==require(client.PetIdleMotion).Version)
                local plan=assert(Shot.plan(argument));visual.origin,visual.yaw=plan.origin,plan.yaw
                for _,expression in ipairs({"neutral","curious","affectionate"})do
                    visual.expression=expression;visual.greeting=2
                    for i=0,120 do
                        visual.cosmeticTime=i*.2;visual:update(0);contained(visual,plan,argument)
                        local fraction=bodyFraction(visual,plan,argument)
                        assert(fraction>=.55 and fraction<=.65,string.format("idle %s native=%s Dot=%s %s time=%g body=%g",id,tostring(native),tostring(dot),expression,visual.cosmeticTime,fraction))
                    end
                end
                visual:destroy()
            end end end
        end)
        test("749x381 factory body fills55to65percent with Dot ON and OFF while every focused pose fits",function()
            for _,id in ipairs({"pip","puddle"})do for _,dot in ipairs({true,false})do
                local visual=Factory.new(folder,Vector3.new(0,4.025,0),Pets.byId[id],.72,{charmVisible=dot});visual.focusPose=true
                for _,root in ipairs({Vector3.new(-11,6.998,4),Vector3.new(75,6.998,58)})do
                    local argument=args(visual,Pets.byId[id],root,Vector2.new(749,381),0)
                    local plan=assert(Shot.plan(argument));visual.origin,visual.yaw=plan.origin,plan.yaw
                    for _,expression in ipairs({"neutral","curious","affectionate"})do
                        visual.expression,visual.petting,visual.affection,visual.affectionTilt=expression,expression=="affectionate",0,0
                        visual.greeting=2;visual:update(0)
                        local fraction=bodyFraction(visual,plan,argument)
                        assert(fraction>=.55 and fraction<=.65,string.format("%s Dot=%s %s body=%g neutralPlan=%g limited=%s limiter=%s/%s",id,tostring(dot),expression,fraction,plan.bodyFraction,tostring(plan.fitLimited),tostring(plan.limitingPart),tostring(plan.limitingEdge)))
                        visual:greet()
                        for _=1,75 do visual:update(1/60);contained(visual,plan,argument)end
                        table.insert(metrics,{pet=id,dot=dot,pose=expression,bodyFraction=fraction,limited=plan.fitLimited,part=plan.limitingPart,edge=plan.limitingEdge})
                    end
                    assert((plan.origin-root).Magnitude<=6.7)
                end
                visual:destroy()
            end end
        end)
        test("capture is independent of world yaw and restores an in-flight contact exactly",function()
            local visual=Factory.new(folder,Vector3.new(13,4.025,-9),Pets.byId.pip,.72,{charmVisible=true})
            visual.yaw=.83;visual.focusPose=true;visual.petting=true;visual.affection=.7;visual.affectionTilt=.031;visual.expression="curious";visual:greet();visual:update(.33)
            local fields={"origin","yaw","time","greeting","focusPose","petting","affection","affectionTilt","expression","gardenAction","actionPhase","charmVisible"}
            local original={};for _,key in ipairs(fields)do original[key]=visual[key]end
            local frames={};for _,entry in ipairs(visual.pieces)do frames[entry.part]={cf=entry.part.CFrame,size=entry.part.Size,transparency=entry.part.Transparency}end
            local _,_,body,envelope=Room.captureFocusSubject(visual,"pip")
            for _,key in ipairs(fields)do assert(visual[key]==original[key],"capture changed "..key)end
            for part,value in pairs(frames)do assert((part.Position-value.cf.Position).Magnitude<.00001 and part.CFrame.LookVector:Dot(value.cf.LookVector)>.999999 and part.Size==value.size and part.Transparency==value.transparency)end
            visual.origin,visual.yaw=Vector3.zero,0;visual:update(0)
            local _,_,secondBody,second=Room.captureFocusSubject(visual,"pip")
            assert(#body==#secondBody and #envelope.points==#second.points)
            for i,point in ipairs(envelope.points)do assert((point-second.points[i]).Magnitude<.00001,"envelope depends on world yaw")end
            visual:destroy()
        end)
        test("a reduced first capture reserves motion and restoring contact pose does not animate it",function()
            local visual=Factory.new(folder,Vector3.new(0,4.025,0),Pets.byId.puddle,.72,{charmVisible=true})
            visual.focusPose,visual.reducedEffects,visual.expression,visual.petting=true,true,"curious",false
            visual.greeting=.33;visual:update(0)
            local frames={};for _,entry in ipairs(visual.pieces)do frames[entry.part]=entry.part.CFrame end
            local argument=args(visual,Pets.byId.puddle,Vector3.new(-11,6.998,4),Vector2.new(749,381),0)
            for part,frame in pairs(frames)do assert((part.Position-frame.Position).Magnitude<.00001 and part.CFrame.LookVector:Dot(frame.LookVector)>.999999)end
            assert(visual.reducedEffects and visual.greeting==.33)
            local plan=assert(Shot.plan(argument));visual.origin,visual.yaw=plan.origin,plan.yaw
            local _,_,_,envelope,cached=Room.captureFocusSubject(visual,"puddle")
            assert(cached and envelope==argument.focusEnvelope and #envelope.points<=#visual.pieces*8)
            visual.reducedEffects=false;visual:greet()
            for _=1,90 do visual:update(1/60);contained(visual,plan,argument)end
            visual.petting=true;visual.affection=.9;visual:update(0)
            assert(require(client.PetExpression).name(visual)=="affectionate")
            visual:destroy()
        end)
        test("greeting preserves curious eyes while actual contact remains affectionate",function()
            local visual=Factory.new(folder,Vector3.new(0,4.025,0),Pets.byId.pip,.72,{charmVisible=true})
            visual.expression,visual.affection="curious",0
            local player=game:GetService("Players").LocalPlayer
            local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local owner={focusing=true,mode="Room",busy=false,menuOpen=false,overlayOpen=function()return false end,
                pet=visual,shownPet=Pets.byId.pip,greetingCamera={root=root,camera=workspace.CurrentCamera},reduceEffects=function()return false end,audio={play=function()end}}
            assert(Room.reactPet(owner,false))
            assert(require(client.PetExpression).name(visual)=="curious"and visual.affection==0)
            visual.petting,visual.affection=true,.9
            assert(require(client.PetExpression).name(visual)=="affectionate")
            owner.petContactActive,owner.contactPet=true,visual
            assert(Room.setPetContact(owner,false))
            assert(require(client.PetExpression).name(visual)=="curious"and visual.affection==0)
            visual:destroy()
        end)
        test("badge and other viewports keep a fully safe envelope and expose actual size limits",function()
            for _,id in ipairs({"pip","puddle"})do
                local visual=Factory.new(folder,Vector3.new(0,4.025,0),Pets.byId[id],.72,{charmVisible=true});visual.focusPose=true
                for _,viewport in ipairs({Vector2.new(1649,971),Vector2.new(390,740),Vector2.new(568,160)})do
                    local argument=args(visual,Pets.byId[id],Vector3.new(-11,6.998,4),viewport,32)
                    local plan=assert(Shot.plan(argument));visual.origin,visual.yaw=plan.origin,plan.yaw
                    visual.expression="curious";visual.greeting=2;visual:update(0);contained(visual,plan,argument)
                    table.insert(metrics,{pet=id,dot=true,badge=32,viewport=tostring(viewport),bodyFraction=plan.bodyFraction,limited=plan.fitLimited,part=plan.limitingPart,edge=plan.limitingEdge})
                    assert(plan.bodyFraction>0 and plan.bodyFraction<=.601 and plan.limitingPart and plan.limitingEdge)
                end
                visual:destroy()
            end
        end)
    end)
    folder:Destroy();assert(ok,problem)
    return{passed=#cases,cases=cases,metrics=metrics}
end
