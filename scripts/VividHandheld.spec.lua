-- Real LocalScript + enabled ScreenGui at Medium/Largest. Isolated UI only.
return function(client,parent)
 local Art=require(client.DeckArt);local Layout=require(client.DeckLayout)
 local Menu=require(client.DeckMenu);local Picker=require(client.DeckPicker);local Transition=require(client.DeckTransition)
 local Shared=game.ReplicatedStorage.Shared;local Stickers=require(Shared.DeckStickers);local Config=require(Shared.BoardConfig)
 local root=Instance.new("Frame");root.Name="_VividHandheld";root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(1649,971);root.Parent=parent
 local cases,metrics={},{}
 local function test(name,run)run();table.insert(cases,name)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function fit(n)assert(n.TextFits,n:GetFullName().." "..n.Text.." box="..tostring(n.AbsoluteSize).." ink="..tostring(n.TextBounds))end
 local ok,err=pcall(function()
  settle()
  test("roomy enamel keeps the exact 700px board and independent 44px controls",function()
   local l=Layout.resolve(Vector2.new(1649,971),(Config.Width+.8)/(Config.Height+.8))
   assert(l.roomy and l.shell.w/l.shell.h>=1.48 and l.shell.w/l.shell.h<=1.55)
   assert(math.abs(l.tray.h-700)<.001 and math.abs(l.tray.w-700*(Config.Width+.8)/(Config.Height+.8))<.001)
   for _,key in ipairs({"menu","lounge","dpad","drop"})do assert(l[key].w>=44 and l[key].h>=44)end
   metrics.case={width=l.shell.w,height=l.shell.h,trayWidth=l.tray.w,trayHeight=l.tray.h,grip=l.right.w}
  end)
  test("one measured wordmark supports full and compact forms without reallocating",function()
   local mark=Art.wordmark(root,4);mark:layout(315,80,30);settle()
   assert(mark.root.Visible and not mark.root:GetAttribute("CompactMark")and mark.root.Rotation==-5)
   for _,run in ipairs(mark.runs)do fit(run.face);fit(run.shadow)end
   local count=#mark.root:GetDescendants();mark:layout(60,60,24);settle()
   assert(mark.root:GetAttribute("CompactMark")and mark.root:GetAttribute("MarkInitials")and mark.root.Visible)
   for _,run in ipairs(mark.runs)do if mark.root.Visible and run.face.Visible then fit(run.face)end end
   for _=1,20 do mark:layout(60,60,24)end;assert(#mark.root:GetDescendants()==count)
   metrics.wordmark={compactWidth=mark.width,compactHeight=mark.height}
   mark.root:Destroy()
  end)
  test("standard phone landscape has a measured compact mark; shallow controls retain their seats",function()
   local mark=Art.wordmark(root,4)
   for _,size in ipairs({Vector2.new(733,307),Vector2.new(749,323),Vector2.new(568,160)})do
    local l=Layout.resolve(size,(Config.Width+.8)/(Config.Height+.8))
    local y=l.shell.y+4+(l.instrumentShiftLeft or 0)
    local w,h=mark:layout(l.left.w-8,l.wallet.y-y-8,24)
    if not l.short then assert(mark.root.Visible and mark.root:GetAttribute("CompactMark")and h<=l.wallet.y-y-8+.01,string.format("phone wordmark root=%s slot=%sx%s rendered=%sx%s raw=%sx%s chosen=%s localScale=%s Pbounds=%s Dbounds=%s",tostring(size),l.left.w-8,l.wallet.y-y-8,w,h,tostring(mark.root:GetAttribute("MarkRawWidth")),tostring(mark.root:GetAttribute("MarkRawHeight")),tostring(mark.root:GetAttribute("MarkTextSize")),tostring(mark.root:GetAttribute("MarkLocalScale")),tostring(mark.runs[1].face.TextBounds),tostring(mark.runs[3].face.TextBounds)))end
    if game:GetService("GuiService").PreferredTextSize.Name=="Medium"and not l.short then
     local text=game:GetService("TextService");local total,tall=12,0
     for i,copy in ipairs({"P","ocket","D","eck"})do
      local bounds=text:GetTextSize(copy,if i==1 or i==3 then 16 else 13,Art.Font.Heading,Vector2.new(10000,10000))
      total+=math.ceil(bounds.X);tall=math.max(tall,math.ceil(bounds.Y)+7)
     end
     if total<=l.left.w-8 and tall<=l.wallet.y-y-8 then assert(mark.root:GetAttribute("MarkShortFull")and not mark.root:GetAttribute("MarkInitials")and mark.runs[2].face.Visible and mark.runs[4].face.Visible,"normal phone discarded a full-name raw fit")end
    end
    settle();for _,run in ipairs(mark.runs)do if mark.root.Visible and run.face.Visible then fit(run.face)end end
    assert(l.drop.w>=44 and l.menu.h>=44)
   end
   mark.root:Destroy()
  end)
  test("boot uses the same passive underprint and joined lettering",function()
   local tray=Art.frame(root,"Tray",Art.Ink,UDim2.fromOffset(400,100),UDim2.fromOffset(417,700))
   local transition=Transition.new(root,tray,nil,function()return true end);settle()
   assert(transition.mark:IsA("CanvasGroup")and transition.mark:GetAttribute("AccessibleLabel")=="PocketDeck")
   assert(transition.mark.Underprint1 and transition.mark.Lettering4 and not transition.mark.Active and not transition.mark.Selectable)
   transition:hide();transition.shade:Destroy();tray:Destroy()
  end)
  -- Sticker prints are retired (faceplates replace them; FaceplatePurchase/DeckBoot specs).
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(1000,650)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle()
   test(tostring(size).." roomy menu choices and tabs use their measured larger faces",function()
    local v=Menu.new(root,{});v:update({status="Ready",nectar=1000000,inventoryMask=127,dailyAvailable=false},"pip","pip",0,0,0,"meadow");v:open();settle()
    assert(v.card.AbsoluteSize.X>=680 and v.card.AbsoluteSize.X<=740 and v.heading.TextSize==28 and v.nectar.TextSize==20)
    fit(v.heading);fit(v.nectar)
    for _,tab in pairs(v.tabs)do fit(tab);assert(tab.TextSize==20 and tab.AbsoluteSize.Y>=44)end
    for _,item in ipairs(v.destinations)do fit(item.title);fit(item.subtitle);assert(item.title.TextSize==20 and item.subtitle.TextSize==16)end
    v:close();v.shade:Destroy()
   end)
   test(tostring(size).." Style Settings Trials preserve full labels and reachable final controls",function()
    local v=Picker.new(root,nil,nil,function()end,function()end,function()end,function()end)
    v:updateClub(0,0,0,0,"On",false,false,1);v:open("sherbet","none");settle()
    assert(v.card.AbsoluteSize.X>=680 and v.card.AbsoluteSize.X<=740 and v.heading.TextSize==28)
    for _,page in ipairs({"Background","Settings","Trials"})do -- Shell is the faceplate shop screen
     v:showTab(page);settle();fit(v.heading)
     if v.choices[page]then
      for _,stroke in pairs(v.choices[page])do fit(stroke.Parent.Caption);assert(stroke.Parent.Caption.TextSize==20 and stroke.Parent.AbsoluteSize.Y>=52)end
     elseif page=="Settings"then for _,b in ipairs({v.sound,v.music,v.motion})do fit(b);assert(b.TextSize==20 and b.AbsoluteSize.Y>=44)end
     else for _,row in ipairs(v.rows)do fit(row.title);fit(row.status)end;fit(v.reward)end
     v.scroll.CanvasPosition=Vector2.new(0,math.max(0,v.scroll.CanvasSize.Y.Offset-v.scroll.AbsoluteSize.Y));settle()
     assert(v.cancel.AbsoluteSize==Vector2.new(44,44))
    end
    v:close();v.shade:Destroy()
   end)
  end
 end)
 root:Destroy();assert(ok,err)
 return{passed=#cases,cases=cases,metrics=metrics,preference=game:GetService("GuiService").PreferredTextSize.Name}
end
