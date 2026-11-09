-- Original saturated art and shell identity; animation ownership stays in Cinematic.
return function(client,parent)
 local Stage=require(client.CompanionHatchArt);local root=Instance.new("Frame");root.Size=UDim2.fromOffset(400,240);root.Parent=parent
 local art=Stage.new(root,false);local cases={};local ok,err=pcall(function()
  art:layout(4,6,190,210,Vector2.new(99,111),130)
  local gradient=art.pond:FindFirstChildOfClass("UIGradient")
  assert(gradient.Color.Keypoints[1].Value==Color3.fromHex("#2457D0")and gradient.Color.Keypoints[2].Value==Color3.fromHex("#16B7CA"))
  assert(art.shell.CompanionShell:GetAttribute("RecipeId")=="meadow"and art.shell.CompanionShell.RegisteredShell.ShellImage.ImageRectOffset==Vector2.zero)
  assert(art.topArt:GetAttribute("ShellSection")=="upper"and art.bottomArt:GetAttribute("ShellSection")=="lower");table.insert(cases,"pond gradient and patterned companion shell match the earned grid")
  for _,half in ipairs({art.top,art.bottom})do for _,node in ipairs(half:GetDescendants())do if node:IsA("GuiObject")then assert(node.ZIndex<50,"split motif covers revealed face")end end end
  art:split(.20,true);assert((art.top.Visible and art.bottom.Visible and art.top.Position.X.Offset<99 and art.bottom.Position.X.Offset>99)or art.shell.Visible)
  art:split(0,false);assert(not art.top.Visible and not art.bottom.Visible);table.insert(cases,"owned split and static/reduced final use passive retained geometry")
  for _,node in ipairs(root:GetDescendants())do if node:IsA("GuiObject")then assert(not node.Active and not node.Selectable)end;assert(not node:IsA("ParticleEmitter")and not node:IsA("Sound"))end
  table.insert(cases,"art owns no input particles sounds or separate render clock")
 end)
 root:Destroy();assert(ok,err);return cases
end
