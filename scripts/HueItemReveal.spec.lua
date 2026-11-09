-- Receipt FX cannot replay, delay an action, or repaint a later generation.
return function(client,parent)
 local Reveal=require(client.HueItemReveal);local root=Instance.new("Frame");root.Size=UDim2.fromOffset(140,160);root.Parent=parent
 local queue={};local plays,stops=0,0;local reduced=false
 local reveal=Reveal.new(root,{delay=function(at,run)table.insert(queue,{at=at,run=run})end,reduceEffects=function()return reduced end,audio={play=function(_,name)assert(name=="hatch");plays+=1 end,stopOwner=function()stops+=1 end}})
 local cases={};local function result(id,item)return{id=id,itemId=item or "rose",revision=1}end
 local ok,err=pcall(function()
  assert(reveal:show(result("new"),true)and reveal.active and reveal.whole.Visible and not reveal.jar.Visible)
  queue[1].run();assert(plays==1 and reveal.top.Visible and reveal.bottom.Visible);queue[2].run();assert(reveal.jar.Visible);queue[3].run();assert(not reveal.active and reveal.jar.Visible)
  assert(not reveal:show(result("new"),true)and plays==1);table.insert(cases,"new paid result splits once and settles; same receipt does not replay")
  queue={};assert(reveal:show(result("cancel"),true));local old=queue;reveal:cancel();assert(reveal.jar.Visible and not reveal.active)
  reveal:show(result("later","tide"),false);for _,pending in ipairs(old)do pending.run()end
  assert(reveal.resultId=="later"and not reveal.active and reveal.jar:GetAttribute("ItemId")=="tide"and plays==1);table.insert(cases,"action/close cancellation owns audio and invalidates deferred callbacks")
  reduced=true;queue={};assert(not reveal:show(result("reduced","iris"),true));assert(reveal.jar.Visible and not reveal.active and #queue==0 and plays==1)
  reduced=false;assert(not reveal:show(result("joined","reset"),false));assert(reveal.jar.Visible and not reveal.active and plays==1);table.insert(cases,"reduced motion and reopened/joined pending receipts are static")
  local oldJar=reveal.jar;reveal:clear();assert(oldJar.Parent==nil and #root:GetChildren()==0 and not reveal.resultId and not reveal.active)
  assert(not reveal:show(result("joined","reset"),true)and reveal.jar.Visible and plays==1)
  table.insert(cases,"retiring receipt art unmounts its jar and same-receipt rebuild remains silent")
  local materialRoot=Instance.new("Frame");materialRoot.Parent=root;local materialQueue={};local materialPlays=0
  local material=Reveal.new(materialRoot,{recipeId="material",delay=function(at,run)assert(at<=.6);table.insert(materialQueue,run)end,
   reduceEffects=function()return reduced end,audio={play=function()materialPlays+=1 end,stopOwner=function()end},
   resultBuilder=function(parent,result,position,size,z)local node=Instance.new("Frame");node.Name=result.finishId;node.Position,node.Size,node.ZIndex,node.Parent=position,size,z,parent;return node end})
  assert(material:show({id="material-new",finishId="gloss"},true)and material.whole:GetAttribute("RecipeId")=="material"and material.topArt:GetAttribute("RecipeId")=="material"and material.bottomArt:GetAttribute("RecipeId")=="material")
  materialQueue[1]();assert(materialPlays==1);material:clear();for _,run in ipairs(materialQueue)do run()end
  assert(not material:show({id="material-new",finishId="gloss"},true)and material.jar.Visible and materialPlays==1)
  reduced=true;assert(not material:show({id="material-reduced",finishId="metal"},true)and material.jar.Visible and materialPlays==1)
  material:destroy();materialRoot:Destroy();reduced=false;table.insert(cases,"Material uses the same bounded registered split once and reduced or reopened results stay silent")
 end)
 reveal:destroy();root:Destroy();assert(ok,err);return cases
end
