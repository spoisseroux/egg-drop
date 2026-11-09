-- Preview-only native geometry fixture; actual authored renders are separate QA.
return function(client)
 local Eating=require(client.PetFruitEating);local Factory=require(client.PetFactory);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local world=Instance.new("WorldModel");local cases={};local eating=Eating.new();local visuals={}
 local function test(n,f)f();table.insert(cases,n)end
 local ok,problem=pcall(function()
  for _,pet in ipairs(Pets.collection)do test(pet.name.." berry approaches shrinks and restores without cumulative head or eye change",function()
   local v=Factory.new(world,Vector3.zero,pet,nil,{charmVisible=true,charmShape="ring"},{native=true});table.insert(visuals,v)
   local head,eye;for _,e in ipairs(v.pieces)do if e.name=="Head"then head=e.part elseif e.name=="EyeL"then eye=e.part end end
   local headCF,eyeSize=head.CFrame,eye.Size
   assert(eating:start(v,{id=pet.id,itemId="rose"},false));local fruit=eating.fruit;local first=fruit.Position;local diameter=fruit.Size.X
   assert(fruit.Anchored and not fruit.CanCollide and not fruit.CanQuery)
   eating:step(.23);assert(fruit.Position~=first and fruit.Size.X==diameter)
   eating:step(.17);local small=fruit.Size.X;assert(small<diameter and small>0 and eye.Size.Y<eyeSize.Y)
   for _=1,6 do eating:step(0);assert(eye.Size.Y>eyeSize.Y*.005,"overlay accumulated eye shrink")end
   eating:step(.35);assert(not eating.active and fruit.Parent==nil and (eye.Size-eyeSize).Magnitude<.00001 and head.CFrame==headCF)
   v:destroy()
  end)end
  test("reduced motion shows a brief static berry then retires it",function()
   local v=Factory.new(world,Vector3.zero,Pets.byId.pip,nil,nil,{native=true});table.insert(visuals,v)
   assert(eating:start(v,{id="reduced",itemId="tide"},true));local fruit=eating.fruit;assert(fruit.Transparency==0)
   eating:step(.21);assert(not eating.active and fruit.Parent==nil);v:destroy()
  end)
  test("reset world actors and replaced rigs cannot keep a transient berry",function()
   local v=Factory.new(world,Vector3.zero,Pets.byId.pip,nil,nil,{native=true});table.insert(visuals,v)
   assert(not eating:start(v,{id="reset",itemId="reset"},false))
   assert(eating:start(v,{id="replace",itemId="iris"},false));local fruit=eating.fruit;v.rigRevision+=1;assert(not eating:step(.01)and fruit.Parent==nil)
   v.worldContext=true;assert(not eating:start(v,{id="world",itemId="iris"},false));v:destroy()
  end)
 end)
 eating:destroy();for _,v in ipairs(visuals)do if not v.destroyed then v:destroy()end end;world:Destroy();assert(ok,problem);return cases
end
