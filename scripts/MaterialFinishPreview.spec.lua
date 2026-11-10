return function(client,parent)
 local Preview=require(client.MaterialFinishPreview);local Config=require(client.PetMaterialConfig)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(500,240);root.Parent=parent
 local owners={};local cases={};local function test(name,f)f();table.insert(cases,name)end
 local source=game.ReplicatedStorage.PetAssets.Zivvi:FindFirstChild("Zivvi__CharmDot",true)
 local function make(finish,options)
  options=options or {};options.autoLoad=false
  local o=Preview.new(root,{finishId=finish},UDim2.fromOffset(0,0),UDim2.fromOffset(200,200),3,options);table.insert(owners,o);return o
 end
 local ok,err=pcall(function()
  test("Matte and Gloss immediately show teal shaded sphere slate tile and ground shadow",function()
   for _,finish in ipairs({"matte","gloss"})do local o=make(finish)
    assert(o.root:GetAttribute("PreviewBackend")=="ShadedFallback"and o.fallback.Parent==o.world and o.fallback.Shape==Enum.PartType.Ball)
    assert(o.fallback.Color==Color3.fromHex("#69D7D5")and o.root.BackgroundColor3==Color3.fromHex("#314E59")and o.root.GroundShadow.Visible)
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
   for _,finish in ipairs({"matte","gloss"})do
    local complete;local cancelled=false;local queue={request=function(_,key,mesh,signature,parts,priority,callback)complete=callback;return{cancel=function()cancelled=true end}end}
    local o=make(finish,{readiness=queue,meshSource=source});assert(o:tryUpgrade()and complete and o.fallback.Parent==o.world)
    complete(true);local mesh=o.world:FindFirstChild("ProductionFinishSphere");assert(mesh and mesh:IsA("MeshPart")and o.ready and not o.fallback.Parent)
    local surface=mesh:FindFirstChildWhichIsA("SurfaceAppearance");assert(surface and surface:GetAttribute("NativeVerified")==true and surface:GetAttribute("MaterialProfile")==Config.FinishProfiles[finish])
    assert(o.root:GetAttribute("PreviewBackend")=="ProductionPBR");o:destroy();assert(cancelled)
   end
  end)
  test("failed and unverified loads leave immediate fallback and destroy prevents late resurrection",function()
   local callback;local queue={request=function(_,a,b,c,d,e,f)callback=f;return{cancel=function()end}end}
   local o=make("gloss",{readiness=queue,meshSource=source});assert(o:tryUpgrade());callback(false);assert(not o.ready and o.fallback.Parent==o.world)
   o:destroy();callback(true);assert(not o.root.Parent and not o.ready)
   local pack=game.ReplicatedStorage.PetMaterials:Clone();local template=pack:FindFirstChild(Config.FinishProfiles.gloss);template:SetAttribute("NativeVerified",false)
   local unverified=make("gloss",{templates=pack,readiness=queue,meshSource=source});assert(not unverified:tryUpgrade()and not unverified.ready);unverified:destroy();pack:Destroy()
  end)
  test("receipt sample has no input physics queries lights particles or independent frame clock",function()
   local o=make("gloss");for _,node in ipairs(o.root:GetDescendants())do
    if node:IsA("GuiObject")then assert(not node.Active and not node.Selectable)end
    if node:IsA("BasePart")then assert(node.Anchored and not node.CanCollide and not node.CanTouch and not node.CanQuery)end
    assert(not node:IsA("Light")and not node:IsA("ParticleEmitter")and not node:IsA("Sound"))
   end
  end)
 end)
 for _,o in ipairs(owners)do o:destroy()end;root:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
