-- All item kinds share one timeline and retire its exact owner on exit.
return function(client,parent)
 local Reveal=require(client.HueItemReveal);local Run=game:GetService("RunService")
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(140,160);root.Parent=parent
 local cases={};local reduced=false;local sounds={};local serial=tostring(os.clock())
 local audio={play=function(_,name,pitch,gain,owner)table.insert(sounds,{name=name,owner=owner})end,stopOwner=function()end}
 local reveal=Reveal.new(root,{reduceEffects=function()return reduced end,audio=audio})
 local function settle()Run.Heartbeat:Wait();Run.Heartbeat:Wait()end
 local function advance(c,t)c:disconnectClock();while t>.000001 do local dt=math.min(t,1/60);c:step(dt);t-=dt end end
 local function test(n,f)f();table.insert(cases,n)end
 local function result(id,item)return{id=serial..id,itemId=item or "rose",revision=1}end
 local ok,err=pcall(function()
  settle()
  test("new paid jar uses shared1.5s timeline and same receipt never replays",function()
   assert(reveal:show(result("new"),true)and reveal.active and reveal.cinematic.active)
   advance(reveal.cinematic,.80);assert(reveal.cinematic.resultRoot.Visible and reveal.cinematic.age>=.75)
   advance(reveal.cinematic,1);assert(not reveal.active and not reveal.cinematic.connection and reveal.cinematic.liveBits==0)
   local count=#sounds;assert(not reveal:show(result("new"),true)and #sounds==count)
  end)
  test("clear destroys transient scene and reopen stays static and silent",function()
   local old=reveal.jar;local count=#sounds
   local preceding=Instance.new("Frame");preceding.Name="PrecedingShopEgg";preceding.Parent=root
   reveal:clear();assert(old.Parent==nil and #root:GetChildren()==0 and not reveal.resultId)
   assert(not reveal:show(result("new"),true)and reveal.cinematic.resultRoot.Visible and not reveal.cinematic.connection and #sounds==count)
  end)
  test("reduced motion or saved joined result owns no animation clock",function()
   reduced=true;local count=#sounds;assert(not reveal:show(result("reduced","iris"),true)and not reveal.cinematic.connection and #sounds==count)
   reduced=false;assert(not reveal:show(result("joined","reset"),false)and not reveal.cinematic.connection and #sounds==count)
  end)
  test("skip settles but never performs a purchase store use or acknowledgment",function()
   assert(reveal:show(result("skip"),true));local generation=reveal.generation
   assert(reveal:skip()and not reveal:skip()and not reveal.active and not reveal.cinematic.connection and reveal.generation==generation)
  end)
  test("Material Toy and Feature adapters use the same registered kind and one owner clock",function()
   for _,entry in ipairs({{"material","finishId","gloss"},{"toy","toyId","ball"},{"feature","featureId","wings"}})do
    local host=Instance.new("Frame");host.Size=UDim2.fromOffset(140,160);host.Parent=root
    local r=Reveal.new(host,{recipeId=entry[1],audio=audio,resultBuilder=function(p,value,pos,size,z)local n=Instance.new("Frame");n.Name="Hero";n.Position,n.Size,n.ZIndex,n.Parent=pos,size,z,p;return n end})
    local packet={id=serial..entry[1]};packet[entry[2]]=entry[3];assert(r:show(packet,true))
    assert(r.cinematic.kind==entry[1]and r.topArt:GetAttribute("RecipeId")==entry[1]and r.bottomArt:GetAttribute("ShellSection")=="lower")
    assert(r.cinematic.duration==(if entry[1]=="feature"then 1.7 else 1.5));r:destroy();assert(#host:GetChildren()==0);host:Destroy()
   end
  end)
 end)
 reveal:destroy();root:Destroy();assert(ok,err);return cases
end
