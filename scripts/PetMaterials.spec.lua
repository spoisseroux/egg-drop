-- Binding/lifecycle tests only: processed GPU appearance remains actual native evidence.
return function(client)
 local Materials=require(client.PetMaterials)
 local source=assert(game.ReplicatedStorage:FindFirstChild("PetMaterials"),"Mounted material pack missing")
 local folder=Instance.new("Folder");folder.Name="_MaterialLifecycle";folder.Parent=workspace
 local cases={};local connections={}
 local function test(name,run)run();table.insert(cases,name)end
 local function make(pack)
  local owner=Materials.new({templates=pack or source})
  local model=Instance.new("Model");model.Parent=folder
  local part=Instance.new("MeshPart");part.Anchored=true;part.Size=Vector3.one;part.Parent=model
  local entry={part=part,name="Body",colorRole="body",color=Color3.fromHex("#E44183"),faceBaseMaterial=Enum.Material.SmoothPlastic}
  local visual={model=model,pieces={entry},charmVisible=true,renderCharmShape="dot",worldContext=true}
  return owner,entry,visual
 end
 local ok,problem=pcall(function()
  test("owned template clones once, tints once and leaves stable properties untouched",function()
   local owner,e,v=make();assert(owner:paint(e,v,0));local surface=e.materialSurface
   assert(surface.Color==e.color and surface.EmissiveTint==Color3.new(1,1,1)and math.abs(surface.EmissiveStrength-.46)<.00001)
   local changes=0;table.insert(connections,surface.Changed:Connect(function()changes+=1 end))
   for _=1,60 do assert(owner:paint(e,v,0)and e.materialSurface==surface)end
   task.wait();assert(changes==0 and #e.part:GetChildren()==1,"steady binding wrote/rebuilt material")
   e.color=Color3.fromHex("#059DC1");owner:paint(e,v,0);assert(surface.Color==e.color and surface.EmissiveTint==Color3.new(1,1,1),"squared hue")
  end)
  test("eyes stay nonemissive, pale catchlight keeps its own profile, mouth remains protected",function()
   local owner,e,v=make();e.name="EyeL";e.colorRole="face";assert(owner:paint(e,v,0));assert(e.materialProfile=="Eye"and e.materialSurface.EmissiveStrength==0)
   local owner2,spark,v2=make();spark.name="GlintL";spark.colorRole="ivory";spark.faceRole="spark";spark.color=Color3.fromHex("#FFF6E9")
   assert(owner2:paint(spark,v2,0)and spark.materialProfile=="Catchlight"and spark.materialSurface.Color==spark.color)
   local owner3,mouth,v3=make();mouth.name="MouthSmile";mouth.colorRole="face";assert(not owner3:paint(mouth,v3,0)and not mouth.materialSurface)
  end)
  test("hidden or unselected charm has zero emission while visible charm exceeds body",function()
   local owner,e,v=make();e.role="charm";e.colorRole="secondary";e.name="CharmDot"
   assert(owner:paint(e,v,0)and math.abs(e.materialSurface.EmissiveStrength-.98)<.00001)
   v.charmVisible=false;owner:paint(e,v,0);assert(e.materialSurface.EmissiveStrength==0)
   v.charmVisible=true;v.renderCharmShape="ring";owner:paint(e,v,0);assert(e.materialSurface.EmissiveStrength==0)
   v.renderCharmShape="dot";owner:paint(e,v,1);assert(math.abs(e.materialSurface.EmissiveStrength-.38)<.00001)
  end)
  test("emission-off retains exact same tinted surface and hidden pieces emit zero",function()
   local owner,e,v=make();assert(owner:paint(e,v,0));local surface=e.materialSurface
   v.emissionEnabled=false;assert(owner:paint(e,v,0)and e.materialSurface==surface and surface.EmissiveStrength==0 and surface.Color==e.color)
   v.emissionEnabled=true;e.renderHidden=true;owner:paint(e,v,0);assert(surface.EmissiveStrength==0)
   e.renderHidden=false;owner:paint(e,v,0);assert(math.abs(surface.EmissiveStrength-.46)<.00001)
  end)
  test("late pack profile binds, removal releases opaque surface, reappearance binds once",function()
   local pack=Instance.new("Folder");pack.Parent=folder;local owner,e,v=make(pack)
   assert(not owner:paint(e,v,0)and owner:status()=="AuthoredPackAvailable")
   local template=source.Body:Clone();template.Parent=pack;assert(owner:paint(e,v,0));local old=e.materialSurface
   template.Parent=nil;assert(not owner:paint(e,v,0)and old.Parent==nil and not e.materialSurface)
   template.Parent=pack;assert(owner:paint(e,v,0)and #e.part:GetChildren()==1)
  end)
  test("explicit fallback releases its owned opaque surface and can restore once",function()
   local owner,e,v=make();assert(owner:paint(e,v,0));local old=e.materialSurface
   v.materialsEnabled=false;assert(not owner:paint(e,v,0)and old.Parent==nil and not e.materialSurface)
   v.materialsEnabled=true;assert(owner:paint(e,v,0)and #e.part:GetChildren()==1)
  end)
  test("adopted authored clone avoids duplicate surface and primitive stays unsupported",function()
   local owner,e,v=make();local cloned=source.Body:Clone();cloned.Parent=e.part
   assert(owner:paint(e,v,0)and e.materialSurface==cloned and #e.part:GetChildren()==1)
   local primitive=Instance.new("Part");primitive.Parent=v.model;e.part=primitive;e.materialSurface=nil
   assert(not owner:paint(e,v,0)and not primitive:FindFirstChildWhichIsA("SurfaceAppearance"))
  end)
  test("late binding retires an emptied fallback group without scanning every pose",function()
   local owner,e,v=make();local model=Instance.new("Model");model.Parent=v.model
   local fill=Instance.new("Highlight");fill.Enabled=true;fill.Parent=v.model
   v.nightGroups={body={model=model,fill=fill}};e.part.Parent=model
   assert(owner:paint(e,v,0)and e.part.Parent==v.model and model.Parent==nil and fill.Parent==nil and not v.nightGroups.body)
  end)
  test("finish profile switches independently of hue and leaves charm and face protected",function()
   local pack=source:Clone();pack.Parent=folder
   for _,name in ipairs({"BodyGloss","BodyMatte","BodyMetal"})do
    local template=pack:FindFirstChild(name)or pack.Body:Clone();template.Name=name;template:SetAttribute("MaterialProfile",name);template:SetAttribute("NativeVerified",true);template.Parent=pack
   end
   local owner,e,v=make(pack);local tint=e.color
   for _,id in ipairs({"gloss","matte","metal","standard"})do
    v.appearance={finish=id};assert(owner:paint(e,v,1))
    assert(e.materialProfile==({gloss="BodyGloss",matte="BodyMatte",metal="BodyMetal",standard="Body"})[id])
    assert(e.materialSurface.Color==tint and math.abs(e.materialSurface.EmissiveStrength-.22)<.00001 and #e.part:GetChildren()==1)
   end
   v.appearance={finish="metal"};e.role="charm";owner:paint(e,v,0);assert(e.materialProfile=="Charm"and math.abs(e.materialSurface.EmissiveStrength-.98)<.00001)
   e.role=nil;e.name="EyeL";e.colorRole="face";owner:paint(e,v,0);assert(e.materialProfile=="Eye"and e.materialSurface.EmissiveStrength==0)
  end)
  test("missing unverified and unknown finishes safely fall back while explicit QA may bind candidate",function()
   -- Build the unverified candidate from a fresh base in a private pack. This
   -- case is independent of which production finishes have passed native QA.
   local originalVerification={}
   for _,name in ipairs({"BodyGloss","BodyMatte","BodyMetal"})do
    local original=source:FindFirstChild(name)
    if original then table.insert(originalVerification,{template=original,verified=original:GetAttribute("NativeVerified")})end
   end
   local pack=Instance.new("Folder");pack.Name="_UnverifiedFinishFixture";pack.Parent=folder
   for _,name in ipairs({"Body","Eye","Charm","Catchlight"})do source[name]:Clone().Parent=pack end
   local template=source.Body:Clone();template.Name="BodyGloss";template:SetAttribute("MaterialProfile","BodyGloss");template:SetAttribute("NativeVerified",false);template.Parent=pack
   local owner,e,v=make(pack);v.appearance={finish="gloss"};assert(owner:paint(e,v,0)and e.materialProfile=="Body")
   v.allowUnverifiedFinish=true;assert(owner:paint(e,v,0)and e.materialProfile=="BodyGloss")
   v.allowUnverifiedFinish=nil;assert(owner:paint(e,v,0)and e.materialProfile=="Body")
   v.appearance.finish="future";assert(owner:paint(e,v,0)and e.materialProfile=="Body")
   template:Destroy();v.appearance.finish="gloss";assert(owner:paint(e,v,0)and e.materialProfile=="Body")
   for _,original in ipairs(originalVerification)do assert(original.template:GetAttribute("NativeVerified")==original.verified,"fixture changed production verification")end
  end)
  test("two-tone body: part keeps primary, surface carries secondary, other roles unchanged",function()
   local twoPack=assert(game.ReplicatedStorage:FindFirstChild("PetMaterialsTwoTone"),"Two-tone pack missing")
   local owner=Materials.new({templates=source,twoToneTemplates=twoPack})
   local _,e,v=make();local primary,secondary=Color3.fromHex("#FFCA00"),Color3.fromHex("#FFBAB6")
   e.color=primary;v.twoTone=true;v.secondaryColor=secondary
   assert(owner:paint(e,v,0)and e.materialProfile=="BodyTwoTone","two-tone template not chosen")
   assert(e.part.Color==primary and e.materialSurface.Color==secondary,"two-tone colours not split")
   assert(e.materialSurface.ColorMap==twoPack.BodyTwoTone.ColorMap,"gradient map not cloned")
   -- A hue change to the secondary retints the same surface once.
   local surface=e.materialSurface;v.secondaryColor=Color3.fromHex("#2F5DA8");assert(owner:paint(e,v,0)and e.materialSurface==surface and surface.Color==v.secondaryColor)
   -- Unverified finish variant falls back to the standard two-tone template.
   v.appearance={finish="gloss"};assert(owner:paint(e,v,0)and e.materialProfile=="BodyTwoTone")
   -- Turning two-tone off on the same entry swaps back to the one-colour body tinted primary.
   v.appearance=nil;v.twoTone=false;assert(owner:paint(e,v,0)and e.materialProfile=="Body"and e.materialSurface.Color==primary and e.part.Color==primary)
   -- Secondary-role parts stay one flat colour.
   local _,s,v2=make();s.colorRole="secondary";s.color=secondary;v2.twoTone=true;v2.secondaryColor=secondary
   assert(owner:paint(s,v2,0)and s.materialProfile=="Body"and s.materialSurface.Color==secondary)
   -- Rigs without the flag keep the one-colour body.
   local _,z,v3=make();assert(owner:paint(z,v3,0)and z.materialProfile=="Body"and z.materialSurface.Color==z.color)
   -- Missing two-tone pack falls back to the one-colour body.
   local bare=Materials.new({templates=source,twoToneTemplates=Instance.new("Folder")})
   local _,b,v4=make();v4.twoTone=true;v4.secondaryColor=secondary;assert(bare:paint(b,v4,0)and b.materialProfile=="Body"and b.materialSurface.Color==b.color)
  end)
  test("model destruction owns all cloned surface cleanup",function()
   local owner,e,v=make();assert(owner:paint(e,v,0));local surface=e.materialSurface
   v.model:Destroy();assert(surface.Parent==nil)
  end)
 end)
 for _,connection in ipairs(connections)do connection:Disconnect()end
 folder:Destroy();assert(ok,problem);return cases
end
