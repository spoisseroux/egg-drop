return function(client,parent)
 local Preview=require(client.MaterialFinishPreview);local Config=require(client.PetMaterialConfig)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(500,240);root.Parent=parent
 local owners={};local temporaryPacks={};local environments={};local cases={};local function test(name,f)f();table.insert(cases,name)end
 local faces={"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp"}
 local function settleEnvironment()game:GetService("RunService").Heartbeat:Wait()end
 local function environment(complete)
  local folder=Instance.new("Folder");table.insert(environments,folder)
  local sky=Instance.new("Sky");sky.Name="WorldSky"
  for i,face in ipairs(faces)do sky[face]=if complete then "rbxassetid://"..(100+i)else ""end
  sky.Parent=folder;return folder,sky
 end
 local cache=require(client.EggPreview3D);local source;local loaded=false
 cache.loadTemplates(function(ok)
  assert(ok,"actual Core mesh cache failed")
  local copies=assert(cache.cloneTemplates());source=copies.Core
  for name,part in pairs(copies)do if name~="Core"then part:Destroy()end end;loaded=true
 end)
 local deadline=os.clock()+12;repeat game:GetService("RunService").Heartbeat:Wait()until loaded or os.clock()>deadline
 assert(source and source.MeshId==require(game.ReplicatedStorage.Shared.EggModels).Egg.Core.mesh,"real round Core required")
 local function make(finish,options)
  options=options or {};options.autoLoad=false
  if finish=="jelly"and not options.templates then
   local pack=game.ReplicatedStorage.PetMaterials:Clone();local candidate=pack:FindFirstChild("BodyJelly")
   assert(candidate,"current Jelly template missing");candidate:SetAttribute("NativeVerified",true)
   options.templates=pack;table.insert(temporaryPacks,pack) -- isolated lifecycle fixture, no production flag mutation
  end
  local o=Preview.new(root,{finishId=finish},UDim2.fromOffset(0,0),UDim2.fromOffset(200,200),3,options);table.insert(owners,o);return o
 end
 local ok,err=pcall(function()
  test("all finishes immediately show an honestly labeled opaque fallback and ground shadow",function()
   for _,finish in ipairs({"matte","gloss","jelly"})do local o=make(finish)
    assert(o.root:GetAttribute("PreviewBackend")=="ShadedFallback"and o.fallback.Parent==o.world and o.fallback.Shape==Enum.PartType.Ball)
    assert(o.fallback.Color==Color3.fromHex("#69D7D5")and o.root.BackgroundColor3==Color3.fromHex("#314E59")and o.root.GroundShadow.Visible)
    assert(o.root:GetAttribute("AccessibleLabel")==({matte="Matte",gloss="Gloss",jelly="Jelly"})[finish].." material sample"and o.fallback.Transparency==0)
    assert(not o.fallback:FindFirstChildWhichIsA("SurfaceAppearance")and math.abs(o.highlight.Transparency-(if finish=="gloss"then .06 else 1))<.00001)
   end
  end)
  test("both finishes retain identical camera framing upper-left key and fill",function()
   local a,b=make("matte"),make("gloss");local av,bv=a.root.FinishViewport,b.root.FinishViewport
   assert(av.Ambient==bv.Ambient and av.LightColor==bv.LightColor and av.LightDirection==bv.LightDirection)
   assert(av.CurrentCamera.CFrame==bv.CurrentCamera.CFrame and av.CurrentCamera.FieldOfView==30)
   local distance=av.CurrentCamera.CFrame.Position.Z;assert(math.abs(1/(distance*math.tan(math.rad(15)))-.70)<.001)
  end)
  test("cold readiness success swaps exact verified production profiles only onto MeshParts",function()
   for _,finish in ipairs({"matte","gloss","jelly"})do
    local complete;local cancelled=false;local queue={request=function(_,key,mesh,signature,parts,priority,callback)complete=callback;return{cancel=function()cancelled=true end}end}
    local o=make(finish,{readiness=queue,meshSource=source});assert(o:tryUpgrade()and complete and o.fallback.Parent==o.world)
    complete(true);local mesh=o.world:FindFirstChild("ProductionFinishSphere");assert(mesh and mesh:IsA("MeshPart")and o.ready and not o.fallback.Parent)
    local surface=mesh:FindFirstChildWhichIsA("SurfaceAppearance");assert(surface and surface:GetAttribute("NativeVerified")==true and surface:GetAttribute("MaterialProfile")==Config.FinishProfiles[finish])
    assert(o.root:GetAttribute("PreviewBackend")=="ProductionPBR"and math.abs(mesh.Transparency-(if finish=="jelly"then .15 else 0))<1e-6);o:destroy();assert(cancelled)
   end
  end)
  test("failed and unverified loads leave immediate fallback and destroy prevents late resurrection",function()
   local callback;local queue={request=function(_,a,b,c,d,e,f)callback=f;return{cancel=function()end}end}
   local o=make("gloss",{readiness=queue,meshSource=source});assert(o:tryUpgrade());callback(false);assert(not o.ready and o.fallback.Parent==o.world)
   o:destroy();callback(true);assert(not o.root.Parent and not o.ready)
   for _,finish in ipairs({"gloss","matte","jelly"})do
    local pack=game.ReplicatedStorage.PetMaterials:Clone();local profile=Config.FinishProfiles[finish];local count=0
    for _,template in ipairs(pack:GetChildren())do
     if template.Name==profile or template:GetAttribute("MaterialProfile")==profile then template:SetAttribute("NativeVerified",false);count+=1 end
    end
    assert(count>0,"fixture finish profile missing")
    local unverified=make(finish,{templates=pack,readiness=queue,meshSource=source})
    assert(not unverified:tryUpgrade()and not unverified.ready and unverified.fallback.Transparency==0)
    unverified:destroy();pack:Destroy()
   end
  end)
  test("receipt sample has no input physics queries lights particles or independent frame clock",function()
   local o=make("gloss");for _,node in ipairs(o.root:GetDescendants())do
    if node:IsA("GuiObject")then assert(not node.Active and not node.Selectable)end
    if node:IsA("BasePart")then assert(node.Anchored and not node.CanCollide and not node.CanTouch and not node.CanQuery)end
    assert(not node:IsA("Light")and not node:IsA("ParticleEmitter")and not node:IsA("Sound"))
   end
  end)
  test("two ordinary Core owners bind independently and retire only their own clones",function()
   local destroyed=0;local readyCache={cloneTemplates=function()
    local copies={Core=source:Clone(),TopShell=Instance.new("Part"),BottomShell=Instance.new("Part")}
    for _,part in pairs(copies)do part.Destroying:Connect(function()destroyed+=1 end)end;return copies
   end,loadTemplates=function()error("ready cache must not start another loader")end}
   local a,b=make("gloss",{cache=readyCache}),make("matte",{cache=readyCache})
   assert(a:tryUpgrade()and b:tryUpgrade()and a.ready and b.ready and destroyed==6)
   assert(a.world.ProductionFinishSphere~=b.world.ProductionFinishSphere and a.root:GetAttribute("PreviewMeshSource")=="EggCore")
   a:destroy();assert(b.world.ProductionFinishSphere.Parent==b.world and b.ready and source.Parent==nil)
  end)
  test("cancelled and timed-out Core waiters cannot resurrect or invalidate a surviving owner",function()
   local callbacks={};local available=false
   local waiting={cloneTemplates=function()if not available then return nil end;return{Core=source:Clone(),TopShell=Instance.new("Part"),BottomShell=Instance.new("Part")}end,
    loadTemplates=function(callback)table.insert(callbacks,callback)end}
   local timeout;local a=make("gloss",{cache=waiting});local b=make("matte",{cache=waiting})
   local expired=make("gloss",{cache=waiting,delay=function(_,callback)timeout=callback end})
   assert(not a:tryUpgrade()and not b:tryUpgrade()and not expired:tryUpgrade()and #callbacks==3)
   a:destroy();timeout();available=true;for _,callback in ipairs(callbacks)do callback(true)end
   assert(not a.ready and not a.root.Parent and not expired.ready and expired.root:GetAttribute("PreviewBackend")=="ShadedFallback")
   assert(b.ready and b.root:GetAttribute("PreviewReadiness")=="BoundVerifiedPBR"and not source.Parent)
  end)
  test("shared six-face environment is independently cloned without changing matched finish lighting or its source",function()
   local folder,sky=environment(true);local a,b=make("gloss",{environmentRoot=folder}),make("matte",{environmentRoot=folder})
   assert(a.skyClone and b.skyClone and a.skyClone~=b.skyClone and a.skyClone.Parent==a.viewport and b.skyClone.Parent==b.viewport)
   for _,face in ipairs(faces)do assert(a.skyClone[face]==sky[face]and b.skyClone[face]==sky[face])end
   assert(sky.Name=="WorldSky"and sky.Parent==folder and #folder:GetChildren()==1)
   assert(a.root:GetAttribute("PreviewEnvironmentReady")==true and a.root:GetAttribute("PreviewEnvironmentReadiness")=="BoundSixFaceSky")
   assert(not a.ready and a.root:GetAttribute("PreviewBackend")=="ShadedFallback","environment must not claim mesh/profile readiness")
   assert(a.viewport.Ambient==b.viewport.Ambient and a.viewport.LightDirection==b.viewport.LightDirection and a.viewport.CurrentCamera.CFrame==b.viewport.CurrentCamera.CFrame)
   local old=a.skyClone;a:destroy();assert(not old.Parent and b.skyClone.Parent==b.viewport and sky.Parent==folder)
  end)
  test("late complete and replaced garden skies update only the owning viewport",function()
   local folder,sky=environment(false);local o=make("jelly",{environmentRoot=folder})
   assert(not o.skyClone and o.root:GetAttribute("PreviewEnvironmentReady")==false)
   assert(o.root:GetAttribute("PreviewEnvironmentReadiness")=="IncompleteSixFaceSky")
   for i,face in ipairs(faces)do sky[face]="rbxassetid://"..(200+i)end
   settleEnvironment()
   assert(o.skyClone and o.root:GetAttribute("PreviewEnvironmentReady")==true)
   local old=o.skyClone;sky.SkyboxUp="";settleEnvironment();assert(not old.Parent and not o.skyClone and not o.root:GetAttribute("PreviewEnvironmentReady"))
   sky.Parent=nil;settleEnvironment();assert(o.root:GetAttribute("PreviewEnvironmentReadiness")=="Unavailable")
   local replacement=sky:Clone();replacement.Name="WaitingSky";replacement.SkyboxUp="rbxassetid://999";replacement.Parent=folder
   settleEnvironment();assert(not o.skyClone);replacement.Name="WorldSky";settleEnvironment();assert(o.skyClone and o.skyClone.SkyboxUp==replacement.SkyboxUp)
   sky:Destroy()
  end)
  test("root retirement disconnects environment listeners and prevents late sky resurrection",function()
   local folder,sky=environment(true);local o=make("gloss",{environmentRoot=folder});local clone=o.skyClone
   o.root:Destroy();settleEnvironment();assert(o.destroyed and not clone.Parent and not o.skyClone)
   assert(#o.environmentConnections==0 and #o.skyFaceConnections==0 and next(o.skyNameConnections)==nil)
   sky.SkyboxUp="rbxassetid://123";local late=sky:Clone();late.Parent=folder;settleEnvironment()
   assert(not o.skyClone and not o.root.Parent and #folder:GetChildren()==2)
  end)
 end)
 for _,o in ipairs(owners)do o:destroy()end;for _,p in ipairs(temporaryPacks)do p:Destroy()end;for _,e in ipairs(environments)do e:Destroy()end;source:Destroy();root:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
