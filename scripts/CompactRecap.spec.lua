-- Actual LocalScript + ScreenGui at Medium/Largest. Production Recap component;
-- isolated measured chrome/actions stand in for init's existing outcome/footer owner.
return function(client,parent)
 assert(parent:IsA("ScreenGui"),"real ScreenGui required")
 local Art=require(client.DeckArt);local Recap=require(client.RoundRecap);local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog)
 local Gui=game:GetService("GuiService");local previous=Gui.SelectedObject
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent
 local cases,views={},{}
 local function test(name,run)run();table.insert(cases,name)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function inside(n,h)local p,s,q,t=n.AbsolutePosition,n.AbsoluteSize,h.AbsolutePosition,h.AbsoluteSize;return p.X>=q.X-.1 and p.Y>=q.Y-.1 and p.X+s.X<=q.X+t.X+.1 and p.Y+s.Y<=q.Y+t.Y+.1 end
 local function effectivelyVisible(n)
  local ancestor=n
  while ancestor do
   if ancestor:IsA("GuiObject")and not ancestor.Visible then return false end
   if ancestor:IsA("ScreenGui")and not ancestor.Enabled then return false end
   ancestor=ancestor.Parent
  end
  return n:IsDescendantOf(parent)
 end
 local function fit(n)assert(n.TextFits,n.Name.." text="..n.Text.." size="..tostring(n.AbsoluteSize).." bounds="..tostring(n.TextBounds));assert(not n.TextScaled)end
 local function result(sequence,total,daily,balance,promoted)
  return{sequence=sequence,status="Saved",success=total>0,stage=if total>0 then 2 else 0,reason=if total>0 then "Completed"else "Incomplete",award=total,daily=daily,balance=balance,recipe=Catalog.ById.meadow,
   reward=table.freeze({sequence=sequence,total=total,base=total-daily,daily=daily,family="pip",masteryPoints=if total>0 then 1 else 0,promotedTo=promoted or 0,contracts={}})}
 end
 local function action(text)
  local b=Instance.new("TextButton");b.Text,b.Parent,b.ZIndex=text,root,30;Art.button(b,8)
  local p=Instance.new("UIPadding");p.PaddingLeft,p.PaddingRight=UDim.new(0,6),UDim.new(0,6);p.Parent=b;return b
 end
 local ok,problem=pcall(function()
  for index,size in ipairs({Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
   root.Size=UDim2.fromOffset(math.min(600,size.X-16),math.min(400,size.Y-16));settle()
   local v=Recap.new(root,nil,true);table.insert(views,v);v.frame.Visible=true;v:update(630,4,2,nil,0,nil,0,700)
   local title=Art.text(root,"Outcome","",UDim2.fromOffset(12,2),UDim2.new(1,-24,0,30),Art.Silver,20);title.ZIndex=30
   local retry,eggs=action("Try again"),action("Hatch eggs");local shallow=size.Y<220
   local function show(value)
    v:updateField(value);title.Text=v.fieldHeading;Art.type(title,if shallow then "Body"else "Heading",true)
    local th=Art.textHeight(title,root.Size.X.Offset-24,22);title.Size=UDim2.new(1,-24,0,th)
    Art.type(retry,if shallow then "Body"else "Action",true);Art.type(eggs,if shallow then "Body"else "Action",true)
    local width=(root.Size.X.Offset-36)/2;local footer=math.max(Art.actionHeight(retry,width),Art.actionHeight(eggs,width))
    retry.Position,retry.Size=UDim2.new(0,12,1,-footer-6),UDim2.fromOffset(width,footer)
    eggs.Position,eggs.Size=UDim2.new(.5,6,1,-footer-6),UDim2.fromOffset(width,footer)
    v.headerInset,v.footerInset=th+6,footer+10;v.layoutWidth=root.Size.X.Offset;v:layoutField(root.Size.Y.Offset);settle()
   end
   test(tostring(size).." outcome earned nonzero breakdown and promotion preserve first view",function()
    local value=result(100+index,8,0,10,2);show(value)
    assert(title.Text=="Round complete"and v.promotionLabel.Text=="Pip reached Grove · Rank II")
    fit(title);fit(v.earnedGraphic);fit(v.promotionLabel);fit(v.eggGoal);fit(v.shortfall)
    assert(v.eggGoal.Parent==v.eggPanel and effectivelyVisible(v.eggGoal)and inside(v.eggGoal,v.eggPanel)and v.eggGoal.ZIndex>v.eggPanel.ZIndex,"selected egg name/balance escaped its visible panel")
    assert(#v.chips==5 and v.detailsButton.Size.Y.Offset>=44 and v.detailsButton.Size.X.Offset<v.goal.Size.X.Offset*.65)
    if v.twoColumn then
     local a,b=v.summaryLayout.earned,v.summaryLayout.egg
     assert(a.y==b.y and b.x-a.x-a.w==12 and a.w<b.w,"wide receipt lost measured 45/55 factual groups")
    end
    assert(inside(title,root)and inside(v.earnedGraphic,v.fieldBody),"outcome/earned firstview clipped at"..tostring(size))
    assert(v.componentLabels[1].Visible and effectivelyVisible(v.componentLabels[1])and v.componentLabels[1].Parent==v.goal and inside(v.componentLabels[1],v.goal)and not v.componentLabels[2].Visible and v.receiptLines[2]=="Daily contracts total +0")
    assert(v.eggGoal.Text=="Meadow · 10/18"and v.shortfall.Text=="8 more to hatch"and v.eggPanel.Size.Y.Offset<116)
    for _,b in ipairs({retry,eggs})do fit(b);assert(b.AbsoluteSize.Y>=44 and inside(b,root))end
    assert(v.fieldBody.AbsoluteSize.Y>=44 and v.fieldBody.AbsolutePosition.Y+v.fieldBody.AbsoluteSize.Y<=retry.AbsolutePosition.Y-.1)
    show(result(110+index,14,6,20,2))
    for _,label in ipairs(v.componentLabels)do
     fit(label);assert(label.Parent==v.goal and effectivelyVisible(label)and inside(label,v.goal),"breakdown hidden or misplaced: "..label.Text.." absolute="..tostring(label.AbsolutePosition))
     local y=label.AbsolutePosition.Y-v.fieldBody.AbsolutePosition.Y+v.fieldBody.CanvasPosition.Y
     v.fieldBody.CanvasPosition=Vector2.new(0,math.clamp(y,0,math.max(0,v.fieldBody.CanvasSize.Y.Offset-v.fieldBody.AbsoluteSize.Y)));settle()
     assert(inside(label,v.fieldBody),"visible breakdown cannot be reached: "..label.Text)
    end
    v.fieldBody.CanvasPosition=Vector2.zero;show(value)
   end)
   test(tostring(size).." details retain zeros history and both footer focuses after spend",function()
    for _,b in ipairs({retry,eggs})do
     Gui.SelectedObject=b;v:setDetails(true);settle();local loops=0
     while v:scrollReceipt(1)do loops+=1;assert(loops<100)end;settle()
     assert(Gui.SelectedObject==b and v.receiptSignature:find("Personal best 700",1,true)and v.receiptSignature:find("Longest chain ×4",1,true))
     assert(v.detailsContent.Visible and v.detailsContent.Parent==v.fieldBody and not v.receiptScroll.Visible)
     if Gui.PreferredTextSize.Name=="Medium"and v.detailsContent.Size.X.Offset>=500 then
      assert(v.detailCards[1].frame.Size.Y.Offset<=40 and v.detailCards[3].frame.Size.Y.Offset<=40,"short metrics retained empty vertical cards")
      assert(v.detailCards[1].frame.Position.Y.Offset==v.detailCards[2].frame.Position.Y.Offset and v.detailCards[3].frame.Position.Y.Offset==v.detailCards[4].frame.Position.Y.Offset,"metric pairs were lost")
     end
     for _,line in ipairs(v.receiptRows)do fit(line);assert(line.AbsolutePosition.X>=v.fieldBody.AbsolutePosition.X+8-.1,"Details lost left gutter")end
     local last=v.receiptRows[#v.receiptRows];assert(last.AbsolutePosition.Y+last.AbsoluteSize.Y<=v.fieldBody.AbsolutePosition.Y+v.fieldBody.AbsoluteSize.Y+1)
    end
    local starts=v.feedback.starts;local offset=v.fieldBody.CanvasPosition.Y;local selected=Gui.SelectedObject
    local value=result(100+index,8,0,2,2);show(value)
    assert(v.detailsOpen and Gui.SelectedObject==selected and v.fieldBody.CanvasPosition.Y==math.min(offset,math.max(0,v.fieldBody.CanvasSize.Y.Offset-v.fieldBody.Size.Y.Offset)),"same Saved sequence spending reset detail state")
    assert(value.reward.total==8 and v.displayReward==8 and v.earnedGraphic.Text=="+8 nectar"and v.eggGoal.Text=="Meadow · 2/18"and v.feedback.starts==starts)
    v:setDetails(false);show(result(200+index,0,0,2))
    assert(v.hasReceipt and v.earnedGraphic.Text=="+0 nectar"and not v.componentLabels[1].Visible and not v.componentLabels[2].Visible)
    assert(v.receiptLines[1]=="Quest nectar +0"and v.receiptLines[2]=="Daily contracts total +0")
    local stale=result(300+index,8,0,2,2);stale.reward=table.freeze({sequence=299+index,total=8,base=8,daily=0,family="pip",promotedTo=2});show(stale)
    assert(not v.hasReceipt and not v.promotionLabel.Visible and not v.earnedGraphic.Visible and #v.receiptRows==0)
   end)
   title:Destroy();retry:Destroy();eggs:Destroy();v.frame:Destroy()
  end
  test("Details and rotation refit canonical chrome once without feedback replay or empty tail",function()
   local card=Instance.new("Frame");card.Size=UDim2.fromOffset(600,307);card.Parent=root;settle()
   local v=Recap.new(card,nil,true);table.insert(views,v);v.frame.Visible=true;v.compactLayout=true;v.layoutWidth=600;v.headerInset,v.footerInset=30,56
   v:update(630,4,2,nil,0,nil,0,700);v:updateField(result(900,8,0,10));settle()
   local fits=0
   local function fitChrome()
    fits+=1;local height=math.min(307,math.max(130,v.bodyContentHeight+v.headerInset+v.footerInset))
    card.Size=UDim2.fromOffset(v.layoutWidth,height);v:layoutField(height)
   end
   v.onContentLayout=fitChrome;fitChrome();settle()
   local serial,starts=v.feedback.serial,v.feedback.starts
   v:setDetails(true);settle();v:setDetails(false);settle()
   assert(card.Size.Y.Offset<=307 and v.fieldBody.AbsoluteSize.Y-v.bodyContentHeight<=12,"collapsed chrome retained empty stretch")
   v.layoutWidth=369;card.Size=UDim2.fromOffset(369,307);v:layoutField(307);settle()
   assert(v.fieldBody.AbsoluteSize.Y-v.bodyContentHeight<=12,"rotation retained expanded parent")
   local before=fits;for _=1,4 do v:layoutField(card.Size.Y.Offset)end;settle();assert(fits==before,"same canonical layout queued redundant fits")
   assert(v.feedback.serial==serial and v.feedback.starts==starts,"chrome refit restarted feedback")
   v:setDetails(true);v.frame:Destroy();local destroyedFits=fits;settle();assert(fits==destroyedFits,"late detached callback fitted chrome")
   card:Destroy()
  end)
 end)
 Gui.SelectedObject=nil;for _,v in ipairs(views)do v.frame:Destroy()end;root:Destroy()
 if require(client.ControllerFocus).live(previous,nil,game.Players.LocalPlayer.PlayerGui,true)then Gui.SelectedObject=previous end
 assert(ok,problem);return{passed=#cases,cases=cases,preference=Gui.PreferredTextSize.Name}
end
