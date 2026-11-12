-- Execute from real LocalScript/ScreenGui under each native PreferredTextSize.
-- Reports actual family/glyph bounds; screenshots still judge glyph identity.
return function(client,parent)
 local Art=require(client.DeckArt);local Gui=game:GetService("GuiService")
 assert(parent:IsA("ScreenGui")or parent:FindFirstAncestorOfClass("ScreenGui"))
 local host=Art.frame(parent,"_PlayfulType",Art.Ink,UDim2.fromOffset(0,0),UDim2.fromOffset(420,260),70)
 host.BackgroundTransparency=1;local rows={}
 local ok,problem=pcall(function()
  for index,role in ipairs({"Body","Action","Supporting","Heading","Counter"})do
   local label=Art.text(host,role,"Zivvi Ovelle Nuum Tikket · 0/5 ✓ ×",UDim2.fromOffset(4,(index-1)*48),UDim2.fromOffset(412,44),Art.Silver,16)
   Art.type(label,role,false)
   local measured=Art.measureText(label.Text,label.TextSize,label.Font,412)
   label.Size=UDim2.fromOffset(412,math.max(44,Art.textHeight(label,412,0)))
   assert(measured.X>0 and measured.Y>0)
   -- UI-SPEC-2026-11-12 2.2: Builder Sans for words, Roboto Mono for counters.
   local expected=if role=="Heading"or role=="Action"then Enum.Font.BuilderSansBold elseif role=="Counter"then Enum.Font.RobotoMono else Enum.Font.BuilderSans
   assert(label.Font==expected)
   table.insert(rows,{role=role,family=label.FontFace.Family,font=label.Font.Name,width=measured.X,height=measured.Y})
  end
  local button=Instance.new("TextButton");button.Name="Carry";button.Size=UDim2.fromOffset(44,44);button:SetAttribute("AccessibleLabel","Lower carried pet");button.Parent=host
  local icon=Art.carryArrow(button,"up");assert(icon.Size==UDim2.fromOffset(22,24)and icon.Rotation==0 and icon.Stem.Size.X.Offset==4 and icon.Head8.Size.X.Offset==16)
  Art.carryArrow(button,"down");assert(icon.Rotation==180 and #button:GetChildren()==1 and button:GetAttribute("AccessibleLabel")=="Lower carried pet")
  for _,node in ipairs(icon:GetDescendants())do if node:IsA("GuiObject")then assert(not node.Active and not node.Selectable)end end
 end)
 host:Destroy();assert(ok,problem)
 return{passed=6,rows=rows,preference=Gui.PreferredTextSize.Name,evidence="native family/glyph measurement; visual glyph judgment remains separate"}
end
