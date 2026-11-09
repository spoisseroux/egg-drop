-- Always-open production receipt under native preferred text sizes.
return function(client,parent)
 assert(parent:IsA("ScreenGui"),"real ScreenGui required")
 local Art=require(client.DeckArt);local Recap=require(client.RoundRecap);local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog)
 local Run=game:GetService("RunService");local Gui=game:GetService("GuiService");local cases={};local previous=Gui.SelectedObject
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 local function test(name,run)run();table.insert(cases,name)end
 local function fit(node)assert(node.TextFits and not node.TextScaled,node.Name.." clipped: "..node.Text.." "..tostring(node.AbsoluteSize))end
 local function result(seq,total,daily,balance)
  return{sequence=seq,status="Saved",success=total>0,stage=if total>0 then 2 else 0,reason=if total>0 then "Completed"else "Incomplete",award=total,daily=daily,balance=balance,recipe=Catalog.ById.meadow,
   reward={sequence=seq,total=total,base=total-daily,daily=daily,family="pip",masteryPoints=1,promotedTo=0,contracts={}}}
 end
 local ok,problem=pcall(function()
  for index,size in ipairs({Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
   root.Size=UDim2.fromOffset(math.min(600,size.X-16),math.min(400,size.Y-16));settle()
   local view=Recap.new(root,nil,true);view.frame.Visible=true;view.headerInset=30;view.footerInset=54;view.layoutWidth=root.Size.X.Offset
   view:update(630,4,2,nil,0,nil,0,700);view:updateField(result(index,14,6,20));view:layoutField(root.Size.Y.Offset);settle()
   test(tostring(size).." exact Stars and all run details are available without Details",function()
    assert(view.earnedGraphic.Text=="+14 Stars"and view.componentLabels[1].Text=="Quest +8"and view.componentLabels[2].Text=="Daily +6")
    assert(view.detailsContent.Visible and not view.detailsButton.Visible and not view.eggPanel.Visible and not view.fill.Parent.Visible and not view.transfer.Visible)
    assert(#view.detailCards>=6 and view.fieldBody.ScrollingEnabled==(view.bodyContentHeight>view.fieldBody.Size.Y.Offset)and view.detailsContent.Parent==view.fieldBody and not view.receiptScroll.Visible)
    assert(view.receiptSignature:find("Personal best 700",1,true)and view.receiptSignature:find("Longest chain ×4",1,true))
    fit(view.earnedGraphic);for _,node in ipairs(view.componentLabels)do fit(node)end
    for _,node in ipairs(view.receiptRows)do fit(node);assert(node.TextColor3==Color3.fromHex("#173D36"))end
    assert(view.earnedGraphic.TextColor3==Color3.fromHex("#173D36")and view.fieldBody.Position.Y.Offset+view.fieldBody.Size.Y.Offset<=root.Size.Y.Offset-54)
   end)
   test(tostring(size).." scroll and repeated saved receipt cannot replay or erase zero credit",function()
    local starts=view.feedback.starts;local signature=view.receiptSignature
    local loops=0;while view:scrollReceipt(1)do loops+=1;assert(loops<100)end;settle()
    local last=view.receiptRows[#view.receiptRows];assert(last.AbsolutePosition.Y+last.AbsoluteSize.Y<=view.fieldBody.AbsolutePosition.Y+view.fieldBody.AbsoluteSize.Y+1)
    local offset=view.fieldBody.CanvasPosition.Y;view:updateField(result(index,14,6,2));settle()
    assert(view.feedback.starts==starts and view.displayReward==14 and view.displayBalance==2 and view.receiptSignature~=signature and view.fieldBody.CanvasPosition.Y==offset)
    view:updateField(result(100+index,0,0,2));settle()
    assert(view.earnedGraphic.Text=="+0 Stars"and view.componentLabels[1].Visible and view.componentLabels[2].Visible)
    assert(view.componentLabels[1].Text=="Quest +0"and view.componentLabels[2].Text=="Daily +0")
    local stale=result(200+index,14,6,2);stale.reward.sequence=199+index;view:updateField(stale)
    assert(not view.hasReceipt and not view.detailsContent.Visible and not view.earnedGraphic.Visible and #view.receiptRows==0)
   end)
   view.frame:Destroy()
  end
  test("pending failed-save overflow and recovered receipt keep exact payout ownership",function()
   root.Size=UDim2.fromOffset(600,300);local view=Recap.new(root,nil,true);view.frame.Visible=true
   local value=result(500,12,4,18);value.reason="Overflow";view:updateField(value);local starts=view.feedback.starts
   for _,status in ipairs({"Saving","Save delayed"})do value.status=status;view:updateField(value);assert(not view.hasReceipt and not view.earnedGraphic.Visible and not view.fill.Parent.Visible)end
   value.status="Saved";value.receiptPending=true;view:updateField(value);assert(not view.hasReceipt)
   value.receiptPending=false;view:updateField(value);assert(view.hasReceipt and view.earnedGraphic.Text=="+12 Stars"and view.feedback.starts==starts)
   view.frame:Destroy()
  end)
 end)
 Gui.SelectedObject=previous;root:Destroy();assert(ok,problem);return{passed=#cases,cases=cases,preference=Gui.PreferredTextSize.Name}
end
