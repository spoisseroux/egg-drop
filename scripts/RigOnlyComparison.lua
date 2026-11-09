-- QA ONLY. Compare two real Factory implementations in today's unchanged world.
-- Build the verified archive in Edit; run one bounded round at a time in a client VM.
local Run=game:GetService("RunService");local Lighting=game:GetService("Lighting");local ReplicatedStorage=game:GetService("ReplicatedStorage");local Http=game:GetService("HttpService")
local Compare={};Compare.__index=Compare
local revision="bb8c60bdfac1fff1f77669b918c2b34da14cfad0"
local function percentile(values,fraction)local sorted=table.clone(values);table.sort(sorted);return sorted[math.clamp(math.ceil(#sorted*fraction),1,#sorted)]end
local function equal(a,b)
 if type(a)~=type(b)then return false end
 if type(a)=="number"then return math.abs(a-b)<.00001 end
 if type(a)~="table"then return a==b end
 for key,value in pairs(a)do if not equal(value,b[key])then return false end end
 for key in pairs(b)do if a[key]==nil then return false end end
 return true
end
local function graphics()
 local result={};pcall(function()result.saved=tostring(UserSettings():GetService("UserGameSettings").SavedQualityLevel)end)
 pcall(function()result.renderer=tostring(settings().Rendering.QualityLevel)end);return result
end
local function worldFacts(study)
 local world={nodes=0,parts=0,lights=0,highlights=0};local fixture={nodes=0,parts=0,lights=0,highlights=0}
 for _,node in ipairs(workspace:GetDescendants())do
  local group=if node:IsDescendantOf(study.folder)then fixture else world;group.nodes+=1
  if node:IsA("BasePart")then group.parts+=1 elseif node:IsA("Light")then group.lights+=1 elseif node:IsA("Highlight")then group.highlights+=1 end
 end
 local toy;local folder=ReplicatedStorage:FindFirstChild("GardenState")
 if folder then local ok,value=pcall(Http.JSONDecode,Http,folder:GetAttribute("Snapshot")or "");if ok and type(value)=="table"and type(value.toy)=="table"then
  local t=value.toy;toy={kind=t.kind,ownerId=t.ownerId,actionId=t.actionId,state=t.returnAction and t.returnAction.state}
 end end
 local ui={};local player=game:GetService("Players").LocalPlayer;local playerGui=player and player:FindFirstChildOfClass("PlayerGui")
 if playerGui then for _,node in ipairs(playerGui:GetChildren())do if node:IsA("ScreenGui")and node~=study.gui then table.insert(ui,{name=node.Name,enabled=node.Enabled})end end end
 table.sort(ui,function(a,b)return a.name<b.name end)
 return{world=world,fixture=fixture,backgroundToy=toy,graphics=graphics(),ui=ui,coreMenu=game:GetService("GuiService").MenuIsOpen}
end
function Compare.new(client,driver,archive,options)
 assert(archive and archive.Parent==ReplicatedStorage and archive.Name=="_RigStudyArchive_bb8c60b"and archive:GetAttribute("FixtureOnly")==true and archive:GetAttribute("SourceRevision")==revision,"verified Edit-built archive missing")
 local self=setmetatable({client=client,Study=require(driver),archive=archive,options=options or{},results={}},Compare)
 self.baseline={sourceRevision=revision,Factory=require(archive.Client.PetFactory),Clock=require(archive.Client.HollowClock),Pets=require(archive.Shared.PetCatalog)}
 self.fixture={pets="all",view="lineup",origin=Vector3.new(-8,4.025,8),motion="sequence",cadence=15,frozen=false,hideUI=true,markers=false,hour=12,preset="neutral",activeToy=true}
 for key,value in pairs(self.options.fixture or{})do self.fixture[key]=value end
 return self
end
function Compare:runRound(candidate,round,options)
 assert(not self.destroyed and not self.active,"comparison is destroyed or already sampling")
 assert(candidate=="current"or candidate=="archived","candidate must be current or archived")
 options=options or{};local warmup=options.warmupFrames or 180;local frames=options.frames or 180
 assert(type(warmup)=="number"and warmup%1==0 and warmup>=0 and warmup<=600 and type(frames)=="number"and frames%1==0 and frames>=1 and frames<=600,"invalid bounded frame budget")
 local study=self.Study(self.client,self.fixture,if candidate=="archived"then self.baseline else nil);self.active=study
 local before;local event=Instance.new("BindableEvent");local bind="RigOnlySample_"..Http:GenerateGUID(false)
 local count=0;local rigCPU,frameTime={},{};local controlled=0;local cameraFrames=0;local sampled,errorMessage
 local function finish(problem)
  if sampled or errorMessage then return end
  errorMessage=problem
  Run:UnbindFromRenderStep(bind)
  if not problem then
   local stats=study:stats();local after=worldFacts(study)
   sampled={scope="rig-only-current-world",historicalPlaceComparison=false,candidate=candidate,round=round,sourceRevision=stats.sourceRevision,archiveManifestSHA256=self.archive:GetAttribute("SourceManifestSHA256"),
    warmupFrames=warmup,frames=frames,controlledFrames=controlled,cameraMatchedFrames=cameraFrames,
    rigCPUms={p50=percentile(rigCPU,.5),p95=percentile(rigCPU,.95),samples=rigCPU},frameMs={p50=percentile(frameTime,.5),p95=percentile(frameTime,.95),samples=frameTime},
    before=before,after=after,backgroundStable=equal(before.world,after.world)and equal(before.backgroundToy,after.backgroundToy)and equal(before.graphics,after.graphics)and equal(before.ui,after.ui)and before.coreMenu==after.coreMenu and not after.coreMenu,study=stats}
   sampled.valid=controlled==frames and cameraFrames==frames and sampled.backgroundStable and stats.lightingControlled
  end
  event:Fire()
 end
 self.finish=finish
 Run:BindToRenderStep(bind,Enum.RenderPriority.Last.Value+21,function()
  local ok,err=pcall(function()
   if study.destroyed then finish("fixture retired during sample");return end
   count+=1
   -- Construction/UI transients belong to warmup. Measure the same warmed world at both ends.
   if count==warmup or(warmup==0 and count==1)then before=worldFacts(study)end
   if count<=warmup then return end
   table.insert(rigCPU,(study.lastRigCPUSeconds or 0)*1000);table.insert(frameTime,(study.lastFrameSeconds or 0)*1000)
   if study:lightingIsControlled()and math.abs(Lighting.ClockTime-self.fixture.hour)<.00001 then controlled+=1 end
   local camera=workspace.CurrentCamera;if camera and camera.CFrame==study.cameraFrame and camera.FieldOfView==(self.fixture.fov or 45)then cameraFrames+=1 end
   if #rigCPU>=frames then finish()end
  end)
  if not ok then finish(tostring(err))end
 end)
 event.Event:Wait();Run:UnbindFromRenderStep(bind);event:Destroy();self.finish=nil;study:destroy();self.active=nil
 assert(not errorMessage,errorMessage)
 table.insert(self.results,sampled);return sampled
end
function Compare:summary()
 local groups={current={},archived={}}
 for _,result in ipairs(self.results)do if result.valid and result.frames==180 and result.warmupFrames>=180 then table.insert(groups[result.candidate],result)end end
 local output={scope="rig-only-current-world",historicalPlaceComparison=false,rounds=self.results,currentRounds=#groups.current,archivedRounds=#groups.archived}
 if #groups.current==3 and #groups.archived==3 then
  local reference=groups.archived[1];local matched=true
  for _,candidate in ipairs({"current","archived"})do for _,sample in ipairs(groups[candidate])do
   matched=matched and equal(sample.study.environment,reference.study.environment)and equal(sample.before.world,reference.before.world)and equal(sample.before.graphics,reference.before.graphics)and equal(sample.before.backgroundToy,reference.before.backgroundToy)and equal(sample.before.ui,reference.before.ui)and sample.before.coreMenu==reference.before.coreMenu
    and equal(sample.study.cameraFrame,reference.study.cameraFrame)and sample.study.cameraFov==reference.study.cameraFov and sample.study.cadence==reference.study.cadence and sample.study.motion==reference.study.motion and sample.study.fixtureActorCount==7 and sample.study.activeToyFixture and equal(sample.study.appearance,reference.study.appearance)and equal(sample.study.origin,reference.study.origin)and sample.study.reduced==reference.study.reduced and sample.study.frozen==reference.study.frozen and sample.study.view==reference.study.view
  end end
  output.matched=matched
  if matched then
   local cpu={current={},archived={}};local frame={current={},archived={}}
   for _,candidate in ipairs({"current","archived"})do for _,sample in ipairs(groups[candidate])do table.insert(cpu[candidate],sample.rigCPUms.p95);table.insert(frame[candidate],sample.frameMs.p95)end end
   output.medianRoundP95CPUms={current=percentile(cpu.current,.5),archived=percentile(cpu.archived,.5)}
   output.medianRoundP95FrameMs={current=percentile(frame.current,.5),archived=percentile(frame.archived,.5)}
   output.rigCPUDeltaPercent=(output.medianRoundP95CPUms.current/output.medianRoundP95CPUms.archived-1)*100
   output.frameDeltaPercent=(output.medianRoundP95FrameMs.current/output.medianRoundP95FrameMs.archived-1)*100
  end
 end
 return output
end
function Compare:destroy()
 if self.destroyed then return end;self.destroyed=true
 if self.finish then self.finish("comparison owner destroyed")end
 if self.active then self.active:destroy()end
end
return Compare
