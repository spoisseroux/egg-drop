-- Client-only presentation fixtures. Direct showSaved is a labeled glyph fixture, not an award.
return function(client)
 local Affection=require(client.PetAffection);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_PetAffectionSpec";folder.Parent=workspace
 local cases,visuals={},{};local calls={};local fx=Affection.new(folder,function(index)table.insert(calls,index)end)
 local function test(name,run)run();table.insert(cases,name)end
 local function make(pet)
  local family=pet.family or pet.id;local module=if family=="pip"then client.PipVisual elseif family=="puddle"then client.PuddleVisual else client.BonusPetVisual
  local v=require(module).new(folder,Vector3.new(2000,4.025,0),pet,.72);table.insert(visuals,v);return v
 end
 local ok,err=pcall(function()
  local pip=make(Pets.byId.pip);fx:setPet(pip)
  test("three passive pooled petals and depth-respecting saved glyph",function()
   assert(#fx.petals==3 and not fx.award.AlwaysOnTop and fx.award.MaxDistance==30)
   for _,p in ipairs(fx.petals)do assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery and p.Transparency==1 and not p:IsDescendantOf(pip.model))end
   assert(fx.label.Text==require(game.ReplicatedStorage.Shared.UICopy).get("pet.star")and fx.label.Text:find("★",1,true)and not fx.label.Active and not fx.label.Selectable and not fx.label.TextScaled)
  end)
  test("qualified start shows pooled petals immediately with a cooldown and static reduced cheeks",function()
   local now=0;fx.clock=function()return now end;fx:begin(false);fx:step(1/60,true,false)
   assert(pip.affectionBlush>0 and fx.petals[1].Transparency<1 and not fx.award.Enabled)
   fx:clear();now=1;fx:begin(false);fx:step(1/60,true,false)
   for _,p in ipairs(fx.petals)do assert(p.Transparency==1,"rapid restart bypassed petal cooldown")end
   fx:clear();now=3;fx:begin(true);fx:step(1/60,true,true)
   assert(pip.affectionBlush>0 and pip.affectionTilt==0)
   for _,p in ipairs(fx.petals)do assert(p.Transparency==1)end
   fx:clear();fx.clock=nil
  end)
  test("continuous contact rotates bounded variations at three-to-five seconds without allocations",function()
   local count=#fx.folder:GetDescendants();pip.petting=true
   for _=1,260 do fx:step(.05,true,false);pip:update(.05);assert(math.abs(pip.affectionTilt or 0)<=.04501)end
   assert(#calls==3 and calls[1]==1 and calls[2]==2 and calls[3]==3 and #fx.folder:GetDescendants()==count)
   assert(not fx.award.Enabled,"cosmetic variation synthesized a reward glyph")
  end)
  test("ending contact clears poses and stops hidden petal motion",function()
   fx:clear();local positions={};for i,p in ipairs(fx.petals)do positions[i]=p.CFrame end
   for _=1,120 do fx:step(.05,false,false)end
   assert(pip.affectionTilt==0 and pip.affectionBlush==0 and not fx.award.Enabled)
   for i,p in ipairs(fx.petals)do assert(p.Transparency==1 and p.CFrame==positions[i])end
  end)
  test("exact saved glyph fixture floats, holds, fades then ends",function()
   assert(fx:showSaved(false));local start=fx.award.StudsOffsetWorldSpace.Y
   for _=1,5 do fx:step(.1,true,false)end
   assert(fx.award.StudsOffsetWorldSpace.Y>start and fx.award.StudsOffsetWorldSpace.Y<=start+.5 and fx.label.TextTransparency==0,"readable while it rises")
   for _=1,7 do fx:step(.1,true,false)end;assert(fx.award.Enabled and fx.label.TextTransparency>0,"fades at the end")
   for _=1,8 do fx:step(.1,true,false)end;assert(not fx.award.Enabled)
  end)
  test("QA Q2.7: letting go keeps the +1 rising to its end; the daily cap says so in words",function()
   assert(fx:showSaved(false))
   fx:clear();for _=1,3 do fx:step(.1,false,false)end
   assert(fx.award.Enabled,"release must not hide a landed Star")
   for _=1,20 do fx:step(.1,false,false)end;assert(not fx.award.Enabled)
   local UICopy=require(game.ReplicatedStorage.Shared.UICopy)
   local text=UICopy.get("pet.capped",{pet="Bear"});assert(text=="Bear's had plenty of pets today")
   assert(fx:showCapped(text,false)and fx.label.Text==text and fx.award.Enabled)
   for _=1,40 do fx:step(.1,false,false)end;assert(not fx.award.Enabled)
   assert(fx:showSaved(false)and fx.label.Text==UICopy.get("pet.star"),"the Star text comes back");fx:hideAward()
  end)
  test("reduced contact has static cheeks and glyph without moving petals",function()
   fx:clear();fx:showSaved(true);local start=fx.award.StudsOffsetWorldSpace
   for _=1,5 do fx:step(.1,true,true)end
   assert(fx.award.StudsOffsetWorldSpace==start and fx.label.TextTransparency==0 and pip.affectionTilt==0 and pip.affectionBlush>0)
   for _,p in ipairs(fx.petals)do assert(p.Transparency==1)end;fx:clear();fx:hideAward();assert(not fx.award.Enabled)
  end)
  test("all seven body bobs preserve planted feet or Puddle skirt and hatch scale stays default",function()
   for _,pet in ipairs(Pets.collection)do
    local v=make(pet);v.reducedEffects=false;v.affectionTilt=0;v.movementBob=0;v:update(0)
    local body=v.model.PrimaryPart;local before=body.Position
    local foot=v.model:FindFirstChild("Slipper")or v.model:FindFirstChild("Foot")or v.model:FindFirstChild("PuddleSkirt")
    local footAt=foot and foot.CFrame
    v.movementBob=.04;v:update(0);assert(body.Position.Y>before.Y,pet.id.." body bob missing")
    if foot then assert((foot.Position-footAt.Position).Magnitude<.0001,pet.id.." planted contact moved")end
    require(client.PetFollow).rest(v);assert(v.movementBob==0 and v.gaitWeight==0)
   end
  end)
  test("pet swap teardown and late calls never retain a glyph or revive pool",function()
   fx:showSaved();fx:setPet(make(Pets.byId.puddle));assert(not fx.award.Enabled)
   fx:destroy();fx:destroy();fx:step(.1,true,false);assert(not fx:showSaved()and fx.folder.Parent==nil and not fx.preference.Connected)
  end)
 end)
 fx:destroy();for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,err);return cases
end
