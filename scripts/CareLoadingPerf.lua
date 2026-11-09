-- QA ONLY, deliberately outside Rojo. Run from a real isolated client VM.
-- require(module)({current=clientFolder,baseline=replicatedBaselineClientFolder,
--   baselineRevision="c549451",candidateRevision="working-tree"})
-- Returns immediately: owner:status(), owner.result, owner:destroy().
-- Default: three noon + three midnight PAIRS, alternating baseline/current order.
-- Measures real rendered frames, with the same deterministic 60Hz virtual motion
-- samples on each cohort. Raw CPU/frame arrays are retained; no outlier removal.
return function(api)
 api=api or {}
 local Run=game:GetService("RunService");local Lighting=game:GetService("Lighting")
 assert(Run:IsClient() and game:GetService("Players").LocalPlayer,"ordinary native Client required")
 assert(api.current and api.baseline and api.current~=api.baseline,"distinct current and baseline client folders required")
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Activity=require(Shared.GardenActivity);local Pets=require(Shared.PetCatalog)
 local Follow=require(api.current.PetFollow);local Readiness=require(api.current.PetAssetReadiness)
 local cohorts={baseline={Factory=require(api.baseline.PetFactory),Clock=require(api.baseline.HollowClock)},
  candidate={Factory=require(api.current.PetFactory),Clock=require(api.current.HollowClock)}}
 local ids={"pip","puddle","wick","orbit","bloom_pip","foxfire_wick","eclipse_orbit"}
 local warmFrames=api.warmFrames or 180;local sampleFrames=api.sampleFrames or 180;local pairsPerHour=api.pairsPerHour or 3
 assert(warmFrames>=1 and warmFrames<=3600 and warmFrames%1==0 and sampleFrames>=1 and sampleFrames<=3600 and sampleFrames%1==0
  and pairsPerHour>=1 and pairsPerHour<=6 and pairsPerHour%1==0,"invalid bounded frame/pair counts")
 local origin=api.origin or Vector3.new(-45,4.025,30)
 local target=api.cameraTarget or origin+Vector3.new(0,1.1,0)
 local offset=api.cameraOffset or Vector3.new(0,4,21)
 local owner={phase="initializing",done=false,destroyed=false,result=nil,visuals={},actors={},cameras={},rounds={},pair=0,frame=0}
 local folder=Instance.new("Folder");folder.Name="_CareLoadingPerf_FIXTURE";folder:SetAttribute("FixtureOnly",true);folder.Parent=workspace
 owner.folder=folder
 local bind="CareLoadingPerf_"..game:GetService("HttpService"):GenerateGUID(false)
 local environmentKeys={"ClockTime","Brightness","ExposureCompensation","Ambient","OutdoorAmbient","ColorShift_Top","EnvironmentDiffuseScale","EnvironmentSpecularScale"}
 local air=Lighting:FindFirstChildOfClass("Atmosphere");local grade=Lighting:FindFirstChild("SproutHollowGrade")
 local savedEnvironment,savedAir,savedLamps={},{},{};local savedGrade=grade and grade.TintColor
 for _,k in ipairs(environmentKeys)do savedEnvironment[k]=Lighting[k]end
 if air then for _,k in ipairs({"Color","Decay","Density"})do savedAir[k]=air[k]end end
 for _,p in ipairs(workspace:GetDescendants())do if p:IsA("PointLight")and p:GetAttribute("HollowLamp")==true then savedLamps[p]=p.Brightness end end
 local cleanupConnection
 local clockStates={}
 for _,cohort in pairs(cohorts)do
  local clock=cohort.Clock
  if not clockStates[clock]then
   local c=clock.controller;clockStates[clock]={hour=clock.lastHour,daylight=clock.lastDaylight,controller=c,
    now=c and c.now,elapsed=c and c.elapsed,controllerDaylight=c and c.daylight}
  end
 end
 local Clock=cohorts.candidate.Clock;local controller=Clock.controller;local borrowed=controller and not controller.destroyed
 local hour=12;local heldNow=function()return ((hour-Clock.TimeZoneOffsetHours)%24)*3600 end
 local targetEnvironment,targetAir,targetGrade={},{},nil;local daylight;local corrections=0
 local quality="unknown";pcall(function()quality=tostring(UserSettings():GetService("UserGameSettings").SavedQualityLevel)end)
 local function vector(v)return {v.X,v.Y,v.Z}end
 local function summary(values)
  local sorted=table.clone(values);table.sort(sorted);local sum=0;for _,v in ipairs(values)do sum+=v end
  local function p(n)return sorted[math.max(1,math.ceil(#sorted*n))]end
  return {count=#values,mean=if #values>0 then sum/#values else 0,p50=p(.5),p95=p(.95),p99=p(.99),max=sorted[#sorted]}
 end
 local function retire()
  for _,v in ipairs(owner.visuals)do v:destroy()end
  table.clear(owner.visuals);table.clear(owner.actors)
 end
 local function restore()
  Run:UnbindFromRenderStep(bind);if cleanupConnection then cleanupConnection:Disconnect();cleanupConnection=nil end;retire()
  if controller and not borrowed then controller:destroy()end
  for clock,s in pairs(clockStates)do
   local c=s.controller
   if c and not c.destroyed and c.now==heldNow then c.now,c.elapsed,c.daylight=s.now,s.elapsed,s.controllerDaylight end
   clock.lastHour,clock.lastDaylight=s.hour,s.daylight
  end
  for k,v in pairs(savedEnvironment)do Lighting[k]=v end
  if air and air.Parent then for k,v in pairs(savedAir)do air[k]=v end end
  if grade and grade.Parent then grade.TintColor=savedGrade end
  for light,brightness in pairs(savedLamps)do if light.Parent then light.Brightness=brightness end end
  for camera,s in pairs(owner.cameras)do if camera.Parent then pcall(function()
   camera.CFrame,camera.Focus,camera.FieldOfView,camera.CameraSubject,camera.CameraType=s.cf,s.focus,s.fov,s.subject,s.kind
  end)end end
  if folder.Parent then folder:Destroy()end
 end
 function owner:destroy()
  if self.destroyed then return end;self.destroyed=true
  if not self.done then self.phase="cancelled";self.done=true;self.result={ok=false,error="Cancelled",rounds=self.rounds}end
  restore()
 end
 function owner:status()
  return {phase=self.phase,done=self.done,destroyed=self.destroyed,pair=self.pair,totalPairs=pairsPerHour*2,
   cohort=self.cohort,hour=hour,frame=self.frame,rounds=#self.rounds,elapsed=os.clock()-(self.started or os.clock()),
   ready=self.readyCount or 0,error=self.error}
 end
 cleanupConnection=folder.Destroying:Connect(function()owner:destroy()end)
 local function fail(problem)
  owner.error=tostring(problem);owner.phase="failed";owner.done=true
  owner.result={ok=false,error=owner.error,rounds=owner.rounds,scope="rig-only-current-world",fixture=true}
  owner:destroy()
 end
 local function light(newHour)
  hour=newHour
  for clock,s in pairs(clockStates)do if s.controller and not s.controller.destroyed then s.controller.now=heldNow end end
  controller:apply(heldNow());daylight=select(2,Clock.sample(heldNow()))
  for _,k in ipairs(environmentKeys)do targetEnvironment[k]=Lighting[k]end
  if air and air.Parent then for _,k in ipairs({"Color","Decay","Density"})do targetAir[k]=air[k]end end
  targetGrade=grade and grade.Parent and grade.TintColor or nil
 end
 local function hold()
  for clock in pairs(clockStates)do clock.lastHour,clock.lastDaylight=hour,daylight end
  for k,v in pairs(targetEnvironment)do if Lighting[k]~=v then Lighting[k]=v;corrections+=1 end end
  if air and air.Parent then for k,v in pairs(targetAir)do if air[k]~=v then air[k]=v;corrections+=1 end end end
  if targetGrade and grade and grade.Parent and grade.TintColor~=targetGrade then grade.TintColor=targetGrade;corrections+=1 end
  for lamp,record in pairs(controller.lights)do controller:paint(lamp,record)end
  local camera=workspace.CurrentCamera
  if camera then
   if not owner.cameras[camera]then owner.cameras[camera]={cf=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView,subject=camera.CameraSubject,kind=camera.CameraType}end
   camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=45
   camera.CFrame=CFrame.lookAt(target+offset,target);camera.Focus=CFrame.new(target)
  end
 end
 local function actor(base)
  local route={Vector3.new(0,0,-2),Vector3.new(0,0,2),Vector3.new(3,0,2),Vector3.new(0,0,2)}
  local position=base+route[1];local first=position;local yaw=0;local path={};local total=0
  local function append(to,pause)
   local legs,duration=Activity.plan(position,to,Vector3.zero,4,pause or 0,yaw)
   for _,leg in ipairs(legs)do table.insert(path,leg)end
   local endPose=Activity.sample({from=Activity.pack(position),to=Activity.pack(to),startTime=0,endTime=duration,path=legs},duration)
   position,yaw=endPose.position,endPose.yaw;total+=duration
  end
  for i=2,#route do append(base+route[i]);if i<#route then append(position,.55)end end;append(position,2)
  return {from=Activity.pack(first),to=Activity.pack(position),startTime=0,endTime=total,path=path,mode="Room",behavior="follow",generation=1,actionId=1,yaw=yaw},total
 end
 local function make(name,options)
  retire();owner.cohort=name;local Factory=cohorts[name].Factory
  for i,id in ipairs(ids)do
   local a,duration=actor(origin+Vector3.new((i-4)*2.6,0,0))
   local v=Factory.new(folder,Activity.vector(a.from),Pets.byId[id],.72,{charmVisible=true,charmShape="dot"},options)
   owner.visuals[i]=v;owner.actors[i]={actor=a,duration=duration};v.cosmeticSeed=i*7919;v.poseCadence=15;v.reducedEffects=false
  end
 end
 local function update(frame)
  local now=frame/60;local started=os.clock()
  for i,v in ipairs(owner.visuals)do
   local record=owner.actors[i];local sampleTime=now%(record.duration+1)
   v.cosmeticTime=now
   v.perfFollow=Follow.activity(v,record.actor,sampleTime+.12,1/60,v.perfFollow,false);v:update(1/60)
  end
  return (os.clock()-started)*1000
 end
 local function ready()
  local count=0;for _,v in ipairs(owner.visuals)do if v.backend=="AuthoredMesh"then count+=1 end end
  owner.readyCount=count;return count==#ids
 end
 local schedule={}
 for _,h in ipairs({12,0})do for pair=1,pairsPerHour do
  local first=if pair%2==1 then "baseline"else "candidate";local second=if first=="baseline"then "candidate"else "baseline"
  table.insert(schedule,{hour=h,pair=pair,cohort=first});table.insert(schedule,{hour=h,pair=pair,cohort=second})
 end end
 local index=0;local current;local cpu,intervals;local measuredEnvironment
 local function beginRound()
  index+=1;current=schedule[index]
  if not current then return false end
  owner.pair=(if current.hour==12 then 0 else pairsPerHour)+current.pair
  light(current.hour);make(current.cohort);assert(ready(),"warmed family unexpectedly returned a non-authored rig")
  owner.phase="warming";owner.frame=0;cpu={};intervals={};measuredEnvironment={clockTime=Lighting.ClockTime,daylight=daylight,exposure=Lighting.ExposureCompensation,brightness=Lighting.Brightness}
  return true
 end
 local swapJobs,swapQueue;local swapFrames={};local swapCompletionMS;local swapAt;local swapBefore
 local function beginSwap()
  light(12);swapJobs={};swapQueue=Readiness.new({load=function(_,complete)table.insert(swapJobs,complete)end})
  make("candidate",{readiness=swapQueue});owner.phase="swap-warming";owner.frame=0
  swapBefore={};for i,v in ipairs(owner.visuals)do assert(v.backend=="NativeRecipe","injected queue must start as whole fallback");swapBefore[i]=v.rigRevision or 0 end
 end
 local function finish()
  local swaps=0;for i,v in ipairs(owner.visuals)do assert(v.backend=="AuthoredMesh"and v.rigRevision==swapBefore[i]+1,"missing or duplicate injected swap");swaps+=1 end
  local camera=workspace.CurrentCamera
  owner.phase="complete";owner.done=true
  owner.result={ok=true,fixture=true,scope="seven native rigs, current world; no live profile/device/GPU readiness claim",
   baselineRevision=api.baselineRevision or "c549451",candidateRevision=api.candidateRevision or "working-tree",
   baselineFolder=api.baseline:GetFullName(),candidateFolder=api.current:GetFullName(),graphics=quality,
   viewport=camera and {camera.ViewportSize.X,camera.ViewportSize.Y},origin=vector(origin),cameraTarget=vector(target),cameraOffset=vector(offset),fov=45,
   worldScale=.72,pets=ids,cadence=15,reducedMotion=false,motion="accepted straight/90/180/stop sequence",
   motionClock="deterministic 1/60 step per real rendered frame; root+Follow+Sampler included in CPU",
   warmFrames=warmFrames,sampleFrames=sampleFrames,pairsPerHour=pairsPerHour,rounds=owner.rounds,
   lightingCorrections=corrections,assetWarmSeconds=owner.assetWarmSeconds,
   swap={fixture=true,injectedReadiness=true,downloadMeasured=false,rawAssetsPreviouslyWarmed=true,swaps=swaps,
    completionCPUms=swapCompletionMS,commitFrame=swapAt,frames=swapFrames,note="All seven fake callbacks completed in one driver frame, then production update commits all seven. Frame interval after commit includes its rendered-frame impact."}}
  owner:destroy()
 end
 local initialized,problem=pcall(function()
  if not borrowed then controller=Clock.new({now=heldNow,auto=false})end
  owner.started=os.clock();light(12);make("candidate");owner.phase="asset-warm";owner.deadline=os.clock()+15
  Run:BindToRenderStep(bind,Enum.RenderPriority.Last.Value+20,function(dt)
   if owner.destroyed then return end
   local ok,err=pcall(function()
    hold()
    if owner.phase=="asset-warm"then
     update(owner.frame);owner.frame+=1
     if ready()then owner.assetWarmSeconds=os.clock()-owner.started;beginRound()
     elseif os.clock()>=owner.deadline then error("authored readiness warm exceeded 15 seconds; fallback is not a valid comparison")end
    elseif owner.phase=="warming"or owner.phase=="measuring"then
     owner.frame+=1;local elapsedCPU=update(owner.frame)
     if owner.phase=="measuring"then
      table.insert(cpu,elapsedCPU);table.insert(intervals,dt*1000)
      if #cpu==sampleFrames then
       assert(ready(),"backend changed during measurement")
       local camera=workspace.CurrentCamera;local roundQuality="unknown"
       pcall(function()roundQuality=tostring(UserSettings():GetService("UserGameSettings").SavedQualityLevel)end)
       table.insert(owner.rounds,{hour=current.hour,pair=current.pair,cohort=current.cohort,order=index,backend="AuthoredMesh",rigCount=7,
        environment=measuredEnvironment,actualEndClockTime=Lighting.ClockTime,graphics=roundQuality,
        viewport=camera and {camera.ViewportSize.X,camera.ViewportSize.Y},
        cpuMS=cpu,frameMS=intervals,cpu=summary(cpu),frame=summary(intervals)})
       if not beginRound()then beginSwap()end
      end
     elseif owner.frame==warmFrames then owner.phase="measuring"end
    elseif owner.phase=="swap-warming"then
     owner.frame+=1;update(owner.frame)
     if owner.frame==warmFrames then owner.phase="swap-measuring";owner.frame=0 end
    elseif owner.phase=="swap-measuring"then
     owner.frame+=1;local completeMS=0
     if owner.frame==31 then
      local start=os.clock();local n=1
      while swapJobs[n]do local complete=swapJobs[n];n+=1;complete(true)end
      assert(n-1==7 and swapQueue.active==0,"injected queue did not finish seven independent families")
      completeMS=(os.clock()-start)*1000;swapCompletionMS=completeMS;swapAt=owner.frame
     end
     local updateMS=update(owner.frame)
     table.insert(swapFrames,{frame=owner.frame,frameMS=dt*1000,updateCPUms=updateMS,completionCPUms=completeMS,totalCPUms=updateMS+completeMS})
     if owner.frame==61 then finish()end
    end
   end)
   if not ok then fail(err)end
  end)
 end)
 if not initialized then fail(problem)end
 return owner
end
