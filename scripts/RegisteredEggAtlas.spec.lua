return function(client,parent)
 local Egg=require(client.EggArt);local Assets=require(client.EggArtAssets);local Stage=require(client.CompanionHatchArt)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(400,240);root.Parent=parent
 local cases={};local ok,problem=pcall(function()
  assert(Assets.Pixels==192 and Assets.SourcePixels==384)
  for index,kind in ipairs({"companion","hue","material","toy","feature"})do
   for row,section in ipairs({"whole","upper","lower"})do
    local egg=Egg.create(root,kind,UDim2.fromOffset(0,0),UDim2.fromOffset(100,100),5,nil,section)
    local image=egg.RegisteredShell.ShellImage
    assert(image.Image==Assets.Atlas and image.ImageRectSize==Vector2.new(192,192)and image.ImageRectOffset==Vector2.new((index-1)*192,(row-1)*192))
    egg:Destroy()
   end
   table.insert(cases,kind.." whole and split use correct served1024 atlas registration")
  end
  local stage=Stage.new(root,false,"toy");stage:layout(0,0,400,240,Vector2.new(200,120),160)
  stage.topArt.RegisteredShell.ShellImage.Image="";stage.bottomArt.RegisteredShell.ShellImage.Image="";stage:split(.1,true)
  local count=0;for _,n in ipairs(root:GetDescendants())do if n:IsA("GuiObject")then count+=1 end end
  assert(count<110 and stage.shell.Visible and not stage.top.Visible and not stage.bottom.Visible,"unavailable split duplicated fallback geometry")
  table.insert(cases,"unavailable atlas retains one bounded complete fallback egg")
 end)
 root:Destroy();assert(ok,problem);return cases
end
