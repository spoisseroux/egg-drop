-- Original native egg + jar motifs, small enough to inspect at actual 44px stock size.
return function(client,parent)
 local Egg=require(client.EggArt);local Jar=require(client.HueJarArt);local cases={};local nodes={}
 local function add(n)table.insert(nodes,n);return n end
 local Assets=require(client.EggArtAssets)
 for i,id in ipairs({"meadow","hue","material","toy","feature"})do
  local egg=add(Egg.create(parent,id,UDim2.fromOffset((i-1)*60,0),UDim2.fromOffset(48,62),10))
  local registered=egg.RegisteredShell;local shell=registered.ShellImage
  local kind=if id=="meadow"then "companion"else id
  assert(shell.Image==Assets.Atlas and shell.ImageRectSize==Vector2.new(192,192)and shell.ImageRectOffset==Vector2.new(Assets.Columns[kind]*192,0)and shell.ScaleType==Enum.ScaleType.Fit and registered:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio==1)
  assert(registered.FallbackOvoid:FindFirstChild("ShellColumn24")and not registered.FallbackOvoid:FindFirstChild("Crown"))
  assert(registered.GroundShadow.Size.Y.Scale<.05)
  for _,d in ipairs(egg:GetDescendants())do if d:IsA("GuiObject")then assert(not d.Active and not d.Selectable)end end
 end
 table.insert(cases,"all five registered owned shells use square Fit with one continuous ovoid load fallback and detached shadow")
 for i,id in ipairs({"rose","tide","citrus","iris","reset"})do
  local n=add(Jar.create(parent,id,UDim2.fromOffset(i*50,80),UDim2.fromOffset(44,52),10));assert(n:FindFirstChild("Rim1")and n:FindFirstChild("Rim2")and n:FindFirstChild("ShoulderReflection")and n.Fruit)
  for _,d in ipairs(n:GetDescendants())do if d:IsA("GuiObject")then assert(not d.Active and not d.Selectable)end end
 end
 table.insert(cases,"all five jars carry readable distinct fruit silhouettes and no input")
 for _,n in ipairs(nodes)do n:Destroy()end;return cases
end
