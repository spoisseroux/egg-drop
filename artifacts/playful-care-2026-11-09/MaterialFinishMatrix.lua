-- QA only. Mount beside ItemEggsVisualStudy and invoke from a real client LocalScript.
-- require(module)(client,{Finish="Gloss",Hour=12,View="pair",PetA="pip",PetB="puddle"})
-- Use the root's isolated cloned client namespace with Body.day=.12/Charm.day=.25
-- for baseline; report reads exact strengths from that namespace. Never edit live config.
-- No remotes, avatars, purchases, profile writes or production script edits.
local Run = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Http = game:GetService("HttpService")
local Gui = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage").Shared
local ids = {"pip", "puddle", "wick", "orbit", "bloom_pip", "foxfire_wick", "eclipse_orbit"}
local origin = Vector3.new(-9, 4.025, 70)
local offsets = {
    Vector3.new(-4.35, 0, 1.8), Vector3.new(-1.45, 0, 1.8),
    Vector3.new(1.45, 0, 1.8), Vector3.new(4.35, 0, 1.8),
    Vector3.new(-3.1, 0, -2.6), Vector3.new(0, 0, -2.6), Vector3.new(3.1, 0, -2.6),
}
local function percentile(values, fraction)
    local sorted = table.clone(values)
    table.sort(sorted)
    return sorted[math.ceil(#sorted * fraction)]
end
local function equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) == "number" then return math.abs(left - right) < .00001 end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end
local function quality()
    local qualityLevel = "unknown"
    pcall(function() qualityLevel = tostring(UserSettings():GetService("UserGameSettings").SavedQualityLevel) end)
    return qualityLevel
end
local function facts(study)
    local nodes, parts, lights = 0, 0, 0
    for _, item in workspace:GetDescendants() do
        if not item:IsDescendantOf(study.folder) then
            nodes += 1
            if item:IsA("BasePart") then parts += 1 elseif item:IsA("Light") then lights += 1 end
        end
    end
    local camera = workspace.CurrentCamera
    local ordinaryScreens = {}
    for _, item in study.gui.Parent:GetChildren() do
        if item:IsA("ScreenGui") and item ~= study.gui then ordinaryScreens[item.Name] = item.Enabled end
    end
    local stats = study:stats()
    return {nodes=nodes,parts=parts,lights=lights,quality=quality(),menu=Gui.MenuIsOpen,
        viewport={camera.ViewportSize.X,camera.ViewportSize.Y},camera=stats.cameraFrame,
        fov=camera.FieldOfView,environment=stats.environment,ordinaryScreens=ordinaryScreens}
end
local function rendered(study)
    local subjects = {}
    for i, visual in ipairs(study.visuals) do
        local surfaces, ring = 0, "none"
        local profiles, strengths = {}, {}
        local instances=#visual.model:GetDescendants()+1
        for _, entry in ipairs(visual.pieces) do
            if entry.part:FindFirstChildOfClass("SurfaceAppearance") then
                surfaces += 1
                local profile=entry.materialProfile or "unowned"
                profiles[profile]=(profiles[profile]or 0)+1
                if entry.materialSurface then
                    local strength=entry.materialSurface.EmissiveStrength
                    local range=strengths[profile]or {minimum=strength,maximum=strength}
                    range.minimum=math.min(range.minimum,strength);range.maximum=math.max(range.maximum,strength);strengths[profile]=range
                end
            end
            if entry.charmShape == "ring" and (entry.part.Transparency < .99
                or entry.decals and entry.decals[1] and entry.decals[1].Transparency < .99) then
                ring = entry.charmBackend or "unknown"
            end
        end
        subjects[i] = {id=visual.petId,backend=visual.backend,surfaces=surfaces,profiles=profiles,strengths=strengths,instances=instances,finish=visual.appearance and visual.appearance.finish,qaBypass=visual.allowUnverifiedFinish==true,ring=ring,revision=visual.rigRevision}
    end
    return subjects
end

return function(client, options)
    options = options or {}
    local inherited = options.driver or script.Parent:FindFirstChild("ItemEggsVisualStudy")
    assert(inherited, "Mount the existing ItemEggsVisualStudy ModuleScript beside this module")
    local Factory = require(client.PetFactory)
    local Pets = require(Shared.PetCatalog)
    local Hue = require(Shared.HueCatalog)
    local Activity = require(Shared.GardenActivity)
    local config = {Hour=12,Body="neutral",Materials=true,Emission=true,Fallback=false,Finish="Standard",View="all",PetA="pip",PetB="puddle"}
    local MaterialConfig=require(client.PetMaterialConfig)
    local activeIds=ids
    for key, value in options do if config[key] ~= nil then config[key] = value end end
    local function stage()
        return {pets=activeIds,origin=origin,view="lineup",motion="idle",cadence=15,reduced=false,
            frozen=false,preset="neutral",markers=false,hideUI=true,hour=config.Hour,
            cameraTarget=origin+Vector3.new(0,.85,0),cameraOffset=if config.View=="pair"then Vector3.new(0,1.9,6.2)else Vector3.new(0,6.5,10.2),fov=35}
    end
    local study = require(inherited)(client, stage())
    local folder = study.folder
    folder.Name = "_MaterialFinishMatrix_FIXTURE"
    local owner = {study=study, folder=folder, results={}, connections={}}
    local label = assert(study.gui:FindFirstChild("FixtureMetadata"))
    local busy = false
    local function apply()
        assert(config.Hour==0 or config.Hour==12 or config.Hour==18, "Hour accepts 0, 12 or 18")
        assert(config.View=="all"or config.View=="pair","View accepts all or pair")
        assert(Pets.byId[config.PetA]and Pets.byId[config.PetB],"Known pair pets required")
        local finish=string.lower(config.Finish)
        assert(({standard=true,gloss=true,matte=true,metal=true})[finish],"Finish accepts Standard, Gloss, Matte or Metal")
        activeIds=if config.View=="pair"then {config.PetA,config.PetB}else ids
        assert(config.Body=="neutral" or config.Body=="mixed" or config.Body=="rose-tide", "Unknown Body")
        for _, key in {"Materials","Emission","Fallback"} do assert(type(config[key])=="boolean", key.." must be boolean") end
        local success, why = study:set(stage())
        assert(success, why)
        local main, secondary = Hue.emptyCounts(), Hue.emptyCounts()
        if config.Body=="mixed" then main.rose,main.tide,secondary.citrus = 5,5,5 end
        if config.Body=="rose-tide" then main.rose,secondary.tide = 5,5 end
        local appearance = {mainDoses=main,secondaryDoses=secondary,charmVisible=true,charmShape="ring",finish=finish}
        study.appearance = appearance
        for i, id in ipairs(activeIds) do
            local position = origin+(if config.View=="pair"then Vector3.new(if i==1 then -1.25 else 1.25,0,0)else offsets[i])
            local old = study.visuals[i]
            local visual = Factory.new(folder, position, Pets.byId[id], .72, appearance,
                {native=config.Fallback,materialsEnabled=config.Materials,emissionEnabled=config.Emission})
            study.visuals[i] = visual
            old:destroy()
            visual.allowUnverifiedFinish=true -- Explicit evidence fixture; purchases remain gated.
            visual:applyAppearance(appearance)
            visual.cosmeticSeed,visual.poseCadence,visual.poseDirty = i*113,15,true
            visual.greeting = 2
            study.actors[i] = {from=Activity.pack(position),to=Activity.pack(position),mode="Room",
                startTime=0,endTime=1,behavior="follow",yaw=.10,actionId=i}
        end
        label.Text = string.format("FIXTURE - %02d:00 - %s - %s finish - %s view - QA unverified rendering allowed\nmaterials %s / emission %s / forced fallback %s / day Body %.2f Charm %.2f",
            config.Hour,config.Body,config.Finish,config.View,tostring(config.Materials),tostring(config.Emission),tostring(config.Fallback),MaterialConfig.Profiles.Body.day,MaterialConfig.Profiles.Charm.day)
    end
    function owner:destroy()
        if self.retired then return end
        self.retired=true
        for _, connection in self.connections do connection:Disconnect() end
        study:destroy()
    end
    function owner:report()
        return {actualHour=Lighting.ClockTime,controlled=study:lightingIsControlled(),quality=quality(),
            state=table.clone(config),profiles=MaterialConfig.Profiles,subjects=rendered(study),source="native fixture rigs / explicit QA material bypass; no ownership or live grant claim"}
    end
    local function tick()
        Run.RenderStepped:Wait()
        assert(not owner.retired and not study.destroyed, "Study retired")
    end
    local function settle()
        local deadline=os.clock()+18
        repeat
            tick()
            local subjects=rendered(study)
            local ready=true
            for _, subject in subjects do
                if config.Fallback then ready=ready and subject.backend=="NativeRecipe"
                else
                    local expected=MaterialConfig.FinishProfiles[string.lower(config.Finish)]
                    ready=ready and subject.backend=="AuthoredMesh"and subject.ring=="mesh"
                        and(if config.Materials then subject.surfaces>0 and(subject.profiles[expected]or 0)>0 else subject.surfaces==0)
                end
            end
            if ready and #subjects==#activeIds then return end
        until os.clock()>deadline
        error("requested authored bodies, true Ring meshes or requested material states did not settle: "..Http:JSONEncode(rendered(study)))
    end
    function owner:benchmark()
        assert(not busy and not owner.retired, "Already benchmarking or retired")
        assert(not config.Fallback, "Benchmark requires authored rigs")
        busy=true
        local initial=config.Materials
        local success, problem=pcall(function()
            self.results={}
            local reference
            -- Alternate which configuration goes first in each pair.
            for round, materials in ipairs({false,true,true,false,false,true}) do
                config.Materials=materials
                folder:SetAttribute("Materials",materials)
                apply()
                settle()
                for _=1,180 do tick() end
                local before=facts(study)
                local startRigs=rendered(study)
                local frameMs,rigMs={},{}
                local controlled=0
                for _=1,180 do
                    tick()
                    table.insert(frameMs,study.lastFrameSeconds*1000)
                    table.insert(rigMs,study.lastRigCPUSeconds*1000)
                    local camera=workspace.CurrentCamera
                    if study:lightingIsControlled() and math.abs(Lighting.ClockTime-config.Hour)<.00001
                        and camera.CFrame==study.cameraFrame and camera.FieldOfView==35 then controlled+=1 end
                end
                local after=facts(study)
                local valid=controlled==180 and equal(before,after) and equal(startRigs,rendered(study)) and not after.menu
                if not reference then reference=before else valid=valid and equal(before,reference) end
                local result={round=round,materials=materials,warmFrames=180,frames=180,controlled=controlled,valid=valid,
                    frameP50=percentile(frameMs,.5),frameP95=percentile(frameMs,.95),
                    rigP50=percentile(rigMs,.5),rigP95=percentile(rigMs,.95),
                    frameMs=frameMs,rigMs=rigMs,subjects=startRigs,before=before,after=after}
                table.insert(self.results,result)
                local raw=folder:FindFirstChild("Round"..round) or Instance.new("StringValue")
                raw.Name,raw.Value="Round"..round,Http:JSONEncode(result)
                raw.Parent=folder
                folder:SetAttribute("BenchmarkRound",round)
            end
            local groups={[true]={},[false]={}}
            for _, result in self.results do
                if result.valid then table.insert(groups[result.materials],result.frameP95) end
            end
            local summary={scope="same-world idle companion finish fixtures",finish=config.Finish,view=config.View,subjects=#activeIds,on=#groups[true],off=#groups[false]}
            if summary.on==3 and summary.off==3 then
                summary.medianOn=percentile(groups[true],.5)
                summary.medianOff=percentile(groups[false],.5)
                summary.deltaPct=100*(summary.medianOn/summary.medianOff-1)
            end
            folder:SetAttribute("BenchmarkSummary",Http:JSONEncode(summary))
        end)
        if not self.retired then
            config.Materials=initial
            folder:SetAttribute("Materials",initial)
            apply()
        end
        busy=false
        if not success then error(problem) end
        return self.results
    end
    function owner:set(values)
        assert(not busy and not self.retired,"Busy or retired")
        local previous=table.clone(config)
        for key,value in pairs(values)do assert(config[key]~=nil,"Unknown matrix option "..tostring(key));config[key]=value end
        local ok,why=pcall(apply)
        if not ok then config=previous;error(why)end
        self.writing=true;for key,value in pairs(config)do folder:SetAttribute(key,value)end;self.writing=false
        return self:report()
    end
    function owner:settle()settle();return self:report()end
    local initialized, problem=pcall(function()
        apply()
        for key, value in config do folder:SetAttribute(key,value) end
        for key in config do
            table.insert(owner.connections,folder:GetAttributeChangedSignal(key):Connect(function()
                if busy or owner.retired or owner.writing or config[key]==folder:GetAttribute(key)then return end
                local previous=config[key]
                config[key]=folder:GetAttribute(key)
                local ok, why=pcall(apply)
                if not ok then config[key]=previous;folder:SetAttribute("LastError",tostring(why))else folder:SetAttribute("LastError",nil)end
            end))
        end
        table.insert(owner.connections,folder.Destroying:Connect(function()owner:destroy()end))
        table.insert(owner.connections,folder:GetAttributeChangedSignal("Cleanup"):Connect(function()
            if folder:GetAttribute("Cleanup")==true then owner:destroy() end
        end))
        table.insert(owner.connections,folder:GetAttributeChangedSignal("RequestReport"):Connect(function()
            if not owner.retired then folder:SetAttribute("Report",Http:JSONEncode(owner:report())) end
        end))
        table.insert(owner.connections,folder:GetAttributeChangedSignal("Benchmark"):Connect(function()
            if folder:GetAttribute("Benchmark")==true and not busy then
                task.spawn(function()
                    local ok,why=pcall(owner.benchmark,owner)
                    if not owner.retired then
                        if not ok then folder:SetAttribute("LastError",tostring(why)) end
                        folder:SetAttribute("Benchmark",false)
                    end
                end)
            end
        end))
    end)
    if not initialized then owner:destroy();error(problem) end
    return owner
end
