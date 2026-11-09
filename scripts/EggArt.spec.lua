-- Original native egg + jar motifs, small enough to inspect at actual 44px stock size.
return function(client,parent)
 local Egg=require(client.EggArt);local Jar=require(client.HueJarArt);local cases={};local nodes={}
 local function add(n)table.insert(nodes,n);return n end
 local companion=add(Egg.create(parent,"meadow",UDim2.fromOffset(0,0),UDim2.fromOffset(48,62),10))
 local hue=add(Egg.create(parent,"hue",UDim2.fromOffset(60,0),UDim2.fromOffset(48,62),10))
 assert(companion.Pattern:FindFirstChild("CobaltRainSeed1")and companion.Pattern:FindFirstChild("CitronHalfBelt"));assert(hue.Pattern:FindFirstChild("Scallop0")and hue.Pattern:FindFirstChild("ShoulderDrop4"));table.insert(cases,"Companion and Hue use distinct original large motifs")
 for i,id in ipairs({"rose","tide","citrus","iris","reset"})do
  local n=add(Jar.create(parent,id,UDim2.fromOffset(i*50,80),UDim2.fromOffset(44,52),10));assert(n:FindFirstChild("Rim1")and n:FindFirstChild("Rim2")and n:FindFirstChild("ShoulderReflection")and n.Fruit)
  for _,d in ipairs(n:GetDescendants())do if d:IsA("GuiObject")then assert(not d.Active and not d.Selectable)end end
 end
 table.insert(cases,"all five jars carry readable distinct fruit silhouettes and no input")
 for _,n in ipairs(nodes)do n:Destroy()end;return cases
end
