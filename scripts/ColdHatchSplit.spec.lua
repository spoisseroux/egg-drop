return function(client,parent)
 local Stage=require(client.CompanionHatchArt);local Cine=require(client.HatchCinematic)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(500,360);root.Parent=parent
 local cases={};local ok,err=pcall(function()
  for _,recipe in ipairs({"meadow","hue","material","toy","feature"})do
   local art=Stage.new(root,false,recipe);art:layout(0,0,400,300,Vector2.new(200,150),160)
   for _,image in ipairs({art.shell.CompanionShell.RegisteredShell.ShellImage,art.topArt.RegisteredShell.ShellImage,art.bottomArt.RegisteredShell.ShellImage})do image.Image=""end
   art:split(.11,true);assert(not art.shell.Visible and art.top.Visible and art.bottom.Visible)
   assert(art.top:GetAttribute("ArtRight")<art.bottom:GetAttribute("ArtLeft"),"registered halves must leave a clear central opening before hero")
   art:split(.16,true)
   for _,half in ipairs({art.top,art.bottom})do
    assert(half:GetAttribute("ArtLeft")>=3.99 and half:GetAttribute("ArtRight")<=396.01 and half:GetAttribute("ArtTop")>=3.99 and half:GetAttribute("ArtBottom")<=296.01,"rotated half escapes pond clearance")
   end
   local splitCount=0
   for _,half in ipairs({art.top,art.bottom})do
    for _,node in ipairs(half:GetDescendants())do if node:IsA("GuiObject")then splitCount+=1;assert(not node.Active and not node.Selectable and node.ZIndex<50)end end
   end
   assert(splitCount<=130,"native split passive geometry budget: "..splitCount)
   local upper,lower=art.topArt.RegisteredShell.FallbackOvoid,art.bottomArt.RegisteredShell.FallbackOvoid
   for _,a in ipairs(upper:GetChildren())do if a.Name:match("^ShellColumn")then
    local b=lower:FindFirstChild(a.Name)
    if b then
     assert(math.abs(a.Position.Y.Scale+a.Size.Y.Scale-b.Position.Y.Scale)<.00001,"native jagged halves overlap or gap")
     local ag,bg=a.UIGradient.Color.Keypoints,b.UIGradient.Color.Keypoints
     assert((Vector3.new(ag[2].Value.R,ag[2].Value.G,ag[2].Value.B)-Vector3.new(bg[1].Value.R,bg[1].Value.G,bg[1].Value.B)).Magnitude<.00001,"canonical shade changes at native seam")
     local whole=art.shell.CompanionShell.RegisteredShell.FallbackOvoid:FindFirstChild(a.Name)
     local wg=whole.UIGradient.Color.Keypoints;local t=(a.Position.Y.Scale+a.Size.Y.Scale-whole.Position.Y.Scale)/whole.Size.Y.Scale
     local expected=wg[1].Value:Lerp(wg[2].Value,t)
     assert((Vector3.new(expected.R,expected.G,expected.B)-Vector3.new(ag[2].Value.R,ag[2].Value.G,ag[2].Value.B)).Magnitude<.00001,"split shade differs from same whole-shell coordinate")
    end
   end end
   local count=#root:GetDescendants();for _=1,20 do art:split(.2,true)end;assert(#root:GetDescendants()==count)
   art:split(0,false);assert(not art.top.Visible and not art.bottom.Visible and not art.shell.Visible)
   for _,node in ipairs(root:GetChildren())do node:Destroy()end
   table.insert(cases,recipe.." cold complementary native halves stay behind revealed face within passive budget")
  end
  local cine=Cine.new(root,nil,function()return false end,function()return true end)
  cine:play({id="cold-split-"..game:GetService("HttpService"):GenerateGUID(false),petId="pip"},nil,{recipeId="meadow"})
  cine:disconnectClock();for _,n in ipairs(root:GetDescendants())do if n:IsA("ImageLabel")then n.Image=""end end
  cine.age=cine.splitAt+.11;cine:paint();assert(not cine.resultRoot.Visible and not cine.shell.Visible and cine.discoveryArt.top.Visible and cine.discoveryArt.bottom.Visible and cine.liveBits==0,"first110ms must read as two split shells alone")
  cine.age=cine.splitAt+.12;cine:paint();assert(cine.resultRoot.Visible and math.abs(cine.heroScale.Scale-.82)<.00001)
  cine.age=cine.splitAt+.16;cine:paint();assert(cine.resultRoot.Visible and not cine.shell.Visible and cine.discoveryArt.top.Visible and cine.discoveryArt.bottom.Visible)
  cine:finishStatic();assert(cine.resultRoot.Visible and not cine.shell.Visible and not cine.discoveryArt.top.Visible and not cine.discoveryArt.bottom.Visible and not cine.connection)
  cine:destroy();table.insert(cases,"cold first reveal and settled static never put whole shell over hero")
 end)
 root:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
