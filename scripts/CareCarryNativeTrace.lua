-- QA-only observer for ordinary Studio controls. Never sends an intent or writes
-- a profile. Inject as a ModuleScript only in an isolated native test lifetime.
return function(options)
    options=options or {}
    local RunService=game:GetService("RunService")
    assert(RunService:IsClient(),"Client observer only")
    local Players=game:GetService("Players")
    local RS=game:GetService("ReplicatedStorage")
    local Http=game:GetService("HttpService")
    local localPlayer=Players.LocalPlayer
    local requested=tonumber(options.duration)
    if not requested or requested~=requested or math.abs(requested)==math.huge then requested=180 end
    local duration=math.clamp(requested,1,600)
    local samples,events,models={},{},{}
    local connections={}
    local started,elapsed,accumulator=os.clock(),0,0
    local stopped=false
    local lastModes={}
    local trace={kind="Ordinary-control read-only client trace",samples=samples,events=events}
    local function vector(v)return {v.X,v.Y,v.Z}end
    local function observe(n)
        if n:IsA("Model")and n:GetAttribute("CompanionOwnerId")~=nil then models[n]=true end
    end
    for _,n in ipairs(workspace:GetChildren())do observe(n)end
    table.insert(connections,workspace.ChildAdded:Connect(function(n)
        -- Factory publishes the model immediately before its owner attribute.
        task.defer(function()if not stopped and n.Parent==workspace then observe(n)end end)
    end))
    table.insert(connections,workspace.ChildRemoved:Connect(function(n)models[n]=nil end))
    function trace:stop()
        if stopped then return self end
        stopped=true
        for _,c in ipairs(connections)do c:Disconnect()end
        self.elapsed=os.clock()-started
        table.clear(models)
        return self
    end
    function trace:mark(label)
        if not stopped then table.insert(events,{t=os.clock()-started,label=tostring(label):sub(1,120)})end
    end
    table.insert(connections,script.Destroying:Connect(function()trace:stop()end))
    table.insert(connections,RunService.RenderStepped:Connect(function(dt)
        elapsed+=math.max(0,dt);accumulator+=math.max(0,dt)
        if elapsed>=duration then trace:stop();return end
        if accumulator<1/15 then return end
        accumulator%=1/15
        local raw=RS:FindFirstChild("GardenState")
        local snapshot
        if raw then
            local ok,value=pcall(Http.JSONDecode,Http,raw:GetAttribute("Snapshot")or "{}")
            if ok and type(value)=="table"then snapshot=value end
        end
        local sample={t=os.clock()-started,actors={},visuals={},boards={},careBay=snapshot and snapshot.careBay}
        local camera=workspace.CurrentCamera
        if camera then sample.cameraType=camera.CameraType.Name;sample.camera=vector(camera.CFrame.Position)end
        local ch=localPlayer.Character
        local root=ch and ch:FindFirstChild("HumanoidRootPart")
        local h=ch and ch:FindFirstChildOfClass("Humanoid")
        if root then sample.owner=vector(root.Position)end
        if h then sample.walkSpeed=h.WalkSpeed;sample.autoRotate=h.AutoRotate end
        for id,a in pairs(snapshot and snapshot.actors or {})do
            local key=if tonumber(id)==localPlayer.UserId then "local"else "visitor:"..id
            sample.actors[key]={petId=a.petId,mode=a.mode,behavior=a.behavior,
                generation=a.generation,characterId=a.characterId,petGeneration=a.petGeneration,
                action=a.action,claimId=a.claimId,care=a.care}
            if lastModes[key]~=a.mode then
                table.insert(events,{t=sample.t,owner=key,mode=a.mode,petId=a.petId})
                lastModes[key]=a.mode
            end
        end
        for m in pairs(models)do
            if not m.Parent then models[m]=nil;continue end
            local id=m:GetAttribute("CompanionOwnerId")
            local key=if id==localPlayer.UserId then "local"else "visitor:"..tostring(id)
            local ok,cf,size=pcall(m.GetBoundingBox,m)
            if ok then table.insert(sample.visuals,{owner=key,petId=m:GetAttribute("PetFamily"),
                backend=m:GetAttribute("RigBackend"),revision=m:GetAttribute("RigRevision"),
                position=vector(cf.Position),size=vector(size)})end
        end
        local boards=RS:FindFirstChild("EggDropBoards")
        if boards then for _,b in ipairs(boards:GetChildren())do
            local key=if tonumber(b.Name)==localPlayer.UserId then "local"else "visitor:"..b.Name
            sample.boards[key]={petId=b:GetAttribute("CompanionId"),generation=b:GetAttribute("CompanionGeneration"),
                mode=b:GetAttribute("Mode"),stars=b:GetAttribute("Stars"),nectar=b:GetAttribute("Nectar"),
                owned=b:GetAttribute("OwnedPets")}
        end end
        table.insert(samples,sample)
    end))
    return trace
end
