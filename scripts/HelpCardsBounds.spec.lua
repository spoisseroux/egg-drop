return function(client,playerGui)
 local How=require(client.HowItWorks);local Copy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
 local RunService=game:GetService("RunService");local passed=0
 How.close("fixture")
 local original,pseudo= nil,Copy.pseudoEnabled()
 local ok,problem=xpcall(function()
  for _,viewport in ipairs({Vector2.new(812,354),Vector2.new(640,360),Vector2.new(390,700)})do
   for _,locale in ipairs({false,true})do
    Copy.setPseudo(locale)
    for _,id in ipairs(How.Order)do
     assert(How.open(id));local root=How.panel().Parent;original=original or root.Size
     root.Size=UDim2.fromOffset(viewport.X,viewport.Y);RunService.RenderStepped:Wait();How.build();task.wait(.19);RunService.RenderStepped:Wait()
     local panel=How.panel();local body=panel:FindFirstChild("Cards");local footer=panel:FindFirstChild("GotIt")
     local detail=id.." "..tostring(viewport).." pseudo="..tostring(locale)
     assert(panel.AbsoluteSize.Y<=viewport.Y and footer.AbsolutePosition.Y+footer.AbsoluteSize.Y<=root.AbsolutePosition.Y+viewport.Y,detail.." footer fits")
     assert(body.AbsolutePosition.Y+body.AbsoluteSize.Y<=footer.AbsolutePosition.Y,detail.." body clears footer")
     for _,card in ipairs(body:GetChildren())do if card:IsA("Frame")then
      for _,name in ipairs({"CardTitle","CardLine"})do
       local label=card:FindFirstChild(name)
       assert(label and label.TextWrapped and label.TextTruncate==Enum.TextTruncate.None,detail.." full text "..name)
       assert(label.TextSize>=12 and label.TextBounds.Y<=label.AbsoluteSize.Y+2,detail.." text height "..name.." bounds="..tostring(label.TextBounds).." size="..tostring(label.AbsoluteSize))
      end
      assert(card.Position.Y.Offset+card.Size.Y.Offset<=body.CanvasSize.Y.Offset+1,detail.." reachable by scroll")
     end end
     for _=1,30 do assert(How.scroll(1))end
     assert(body.CanvasPosition.Y>=math.max(0,body.CanvasSize.Y.Offset-body.AbsoluteSize.Y)-1,detail.." controller reaches final card")
     for _=1,30 do assert(How.scroll(-1))end
     assert(body.CanvasPosition.Y==0,detail.." controller returns to top")
     passed+=1;How.close("fixture")
    end
   end
  end
 end,debug.traceback)
 How.close("fixture");Copy.setPseudo(pseudo)
 local gui=playerGui:FindFirstChild("EggDropHowItWorks");if gui and original then gui.Root.Size=original end
 assert(ok,problem)
 return{passed=passed}
end
