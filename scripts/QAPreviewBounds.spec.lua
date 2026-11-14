-- Actual native GUI preview mask + Moonpond fixture. Does not buy, save or upload.
return function(client,playerGui,options)
 options=options or {}
 local Kit=require(client.DeckKit);local Moonpond=require(client.MoonpondBackdrop)
 local backgrounds=require(game:GetService("ReplicatedStorage").Shared.DeckBackgrounds)
 local gui=Instance.new("ScreenGui");gui.Name="_QAPreviewBounds";gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.DisplayOrder=60;gui.Parent=playerGui
 local root=Instance.new("Frame");root.Name="Fixture";root.Size=UDim2.fromOffset(812,296);root.BackgroundColor3=Color3.fromHex("#152525");root.BorderSizePixel=0;root.Parent=gui
 local outer,clip=Kit.previewWell(root,"RoundedPreview",UDim2.fromOffset(12,12),UDim2.fromOffset(300,180),12)
 local sentinel=Instance.new("Frame");sentinel.Name="CornerSentinel";sentinel.BackgroundColor3=Color3.fromHex("#FF8090");sentinel.Size=UDim2.fromScale(1,1);sentinel.BorderSizePixel=0;sentinel.ZIndex=clip.ZIndex+1;sentinel.Parent=clip
 assert(clip:IsA("CanvasGroup")and clip.ClipsDescendants and clip:FindFirstChildOfClass("UICorner"),"true rounded descendant mask")
 assert(outer:FindFirstChildOfClass("UIStroke")and not clip:FindFirstChildOfClass("UIStroke"),"single intact outer border")
 assert(sentinel.ZIndex>clip.ZIndex and clip.ZIndex>outer.ZIndex,"sentinel renders above opaque well")
 for _,well in ipairs(playerGui:GetDescendants())do
  if well.Name=="RoundedContent"and well:IsA("CanvasGroup")then
   local owner=well:FindFirstAncestorWhichIsA("LayerCollector")
   assert(owner and owner.ZIndexBehavior==Enum.ZIndexBehavior.Sibling,"rounded preview requires Sibling owner: "..well:GetFullName())
   for _,child in ipairs(well:GetDescendants())do if child:IsA("GuiObject")then
    assert(child.ZIndex>=well.ZIndex,"preview child behind well: "..child:GetFullName().." Z="..child.ZIndex.." clipZ="..well.ZIndex)
   end end
  end
 end
 local field=Instance.new("Frame");field.Name="MoonpondField";field.Position=UDim2.fromOffset(330,12);field.Size=UDim2.fromOffset(200,272);field.BorderSizePixel=0;field.Parent=root
 local renderer=Moonpond.new(field,{field=true})
 game:GetService("RunService").RenderStepped:Wait()
 renderer:resize(Vector2.new(200,272))
 for _,dot in ipairs(renderer.dots)do assert(not dot.root.Visible,"no bright field dots")end
 local created=renderer.stats.created;local writes=renderer.stats.writes
 for _=1,200 do renderer:step(.1,true,false)end
 assert(renderer.stats.created==created and renderer.stats.writes==writes,"static field no frame churn")
 assert(#Moonpond.Spec.arcs==6 and #Moonpond.Spec.dots==5,"bounded Astra motif ledger")
 local exterior=Instance.new("Frame");exterior.Name="MoonpondExterior";exterior.Position=UDim2.fromOffset(548,12);exterior.Size=UDim2.fromOffset(252,272);exterior.Parent=root
 local e=Moonpond.new(exterior)
 e:resize(Vector2.new(252,272),Rect.new(0,0,252,272))
 for _,arc in ipairs(e.arcs)do assert(not arc.root.Visible,"case excludes arc")end
 for _,dot in ipairs(e.dots)do assert(not dot.root.Visible,"case excludes dot")end
 assert(not e.reflection.Visible,"case excludes reflection")
 assert(backgrounds.Order[#backgrounds.Order]=="moonpond"and backgrounds.Default=="canopy"and backgrounds.ById.moonpond.rule=="free","append-only free background")
 e:resize(Vector2.new(252,272),Rect.new(70,60,180,220))
 for _,arc in ipairs(e.arcs)do if arc.root.Visible then
  local b=arc.bounds
  assert(b.x+b.w<=70 or b.x>=180 or b.y+b.h<=60 or b.y>=220,"actual padded segment cannot cross case")
  assert(b.x<252 and b.x+b.w>0 and b.y<272 and b.y+b.h>0,"visible arc intersects viewport")
 end end
 local text=Instance.new("TextLabel");text.Name="Evidence";text.Text="ACTUAL GUI FIXTURE · rounded mask / static Moonpond · no purchase";text.TextSize=12;text.TextColor3=Color3.new(1,1,1);text.BackgroundTransparency=1;text.Position=UDim2.fromOffset(12,245);text.Size=UDim2.fromOffset(300,40);text.TextWrapped=true;text.Parent=root
 if not options.keepFixture then renderer:destroy();e:destroy();gui:Destroy()end
 return{passed=7,created=created,kept=options.keepFixture==true}
end
