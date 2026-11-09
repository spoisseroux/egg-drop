-- Local modifier ownership without using or moving a real player character.
return function(client)
 local Visibility=require(client.FocusCharacterVisibility)
 local folder=Instance.new("Folder");folder.Name="_FocusCharacterVisibility";folder.Parent=workspace
 local Run=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function make()
  local character=Instance.new("Model");character.Parent=folder
  local part=Instance.new("Part");part.Anchored=true;part.Transparency=.2;part.LocalTransparencyModifier=.35;part.Parent=character
  local decal=Instance.new("Decal");decal.Transparency=.15;decal.Parent=part
  return character,part,decal
 end
 local ok,problem=pcall(function()
  test("local focus scope hides owner parts and restores exact prior modifiers",function()
   local character,part,decal=make();local before=part.LocalTransparencyModifier
   local decalSupported,decalBefore=pcall(function()return decal.LocalTransparencyModifier end)
   local scope=Visibility.acquire(character)
   assert(part.LocalTransparencyModifier==1 and math.abs(part.Transparency-.2)<.000001)
   if decalSupported then assert(decal.LocalTransparencyModifier==1)end
   part.LocalTransparencyModifier=0;Run.RenderStepped:Wait();Run.RenderStepped:Wait();assert(part.LocalTransparencyModifier==1,"camera transparency controller escaped scope")
   scope:release();scope:release()
   assert(part.LocalTransparencyModifier==before and next(scope.records)==nil)
   if decalSupported then assert(decal.LocalTransparencyModifier==decalBefore)end
   assert(math.abs(decal.Transparency-.15)<.000001)
   character:Destroy()
  end)
  test("new accessories inherit the scope and removal restores their own previous value",function()
   local character=make();local scope=Visibility.acquire(character)
   local accessory=Instance.new("Part");accessory.LocalTransparencyModifier=.6;local before=accessory.LocalTransparencyModifier;accessory.Parent=character;Run.Heartbeat:Wait()
   assert(accessory.LocalTransparencyModifier==1)
   accessory.Parent=folder;Run.Heartbeat:Wait();assert(accessory.LocalTransparencyModifier==before)
   scope:release();assert(accessory.LocalTransparencyModifier==before)
   accessory:Destroy();character:Destroy()
  end)
  test("releasing the old character never repaints a replacement or observer avatar",function()
   local old,oldPart=make();local replacement,replacementPart=make();local observer,observerPart=make()
   local before=replacementPart.LocalTransparencyModifier;local observerBefore=observerPart.LocalTransparencyModifier
   local scope=Visibility.acquire(old);assert(oldPart.LocalTransparencyModifier==1)
   scope:release();local nextScope=Visibility.acquire(replacement);scope:release()
   assert(replacementPart.LocalTransparencyModifier==1 and observerPart.LocalTransparencyModifier==observerBefore)
   nextScope:release();assert(replacementPart.LocalTransparencyModifier==before)
   old:Destroy();replacement:Destroy();observer:Destroy()
  end)
 end)
 folder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
