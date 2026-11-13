-- Run from an actual LocalScript with an enabled ScreenGui under LocalPlayer.PlayerGui.
-- Optional rootSize runs two bounded geometry cases; full matrix adds four focus/dock cases (12 total).
return function(client,parent,rootSize)
 local Gui=game:GetService("GuiService");local Players=game:GetService("Players")
 local playerGui=Players.LocalPlayer.PlayerGui
 assert(parent:IsA("ScreenGui") and parent:IsDescendantOf(playerGui) and parent.Enabled,"live ScreenGui required")
 local Art=require(client.DeckArt);local Menu=require(client.DeckMenu);local Shop=require(client.EggHatchView)
 local Notice=require(client.SaveNotice);local Focus=require(client.ControllerFocus)
 local previous=Gui.SelectedObject;local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Name="_SharedHeaders";root.Parent=parent
 local cases,views={},{};local sends=0
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function test(name,run)parent:SetAttribute("SharedHeaderProgress",name);run();table.insert(cases,name)end
 local function fit(n)assert(n.TextFits,string.format("%s text=%q box=%s bounds=%s",n:GetFullName(),n.Text,tostring(n.AbsoluteSize),tostring(n.TextBounds)))end
 local function inside(n,h)local p,s,q,t=n.AbsolutePosition,n.AbsoluteSize,h.AbsolutePosition,h.AbsoluteSize;return p.X>=q.X-1 and p.Y>=q.Y-1 and p.X+s.X<=q.X+t.X+1 and p.Y+s.Y<=q.Y+t.Y+1 end
 local function overlap(a,b)local p,s,q,t=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize;return p.X<q.X+t.X-.1 and q.X<p.X+s.X-.1 and p.Y<q.Y+t.Y-.1 and q.Y<p.Y+s.Y-.1 end
 local function state(amount,available)return{status="Ready",revision=12,nectar=amount,inventoryMask=127,dailyAvailable=available==true,dailyBonus=6,dailyDay="20000",mastery={pip=3,wick=3}}end
 local function header(v,amount)
  fit(v.heading);fit(v.nectar);fit(v.closeButton)
  assert(v.nectar.Font==Art.Font.Counter and v.nectar:GetAttribute("TypeRole")=="Counter","wallet lost exact-counter face")
  assert(v.heading.Font==(if v.heading:GetAttribute("TypeRole")=="Heading"then Art.SheetFont.Heading else Art.SheetFont.Body),"heading role face differs")
  assert(v.nectar.Visible and v.nectar.Text==tostring(amount) and v.nectar:GetAttribute("AccessibleLabel")==tostring(amount).." Stars")
  assert(v.wallet.BackgroundTransparency==1 and inside(v.wallet,v.card) and inside(v.closeButton,v.card))
  assert(v.closeButton.AbsoluteSize==Vector2.new(44,44) and v.closeButton:GetAttribute("BareClose"))
  assert(not overlap(v.wallet,v.heading) and not overlap(v.heading,v.closeButton) and not overlap(v.wallet,v.closeButton),"shared header overlaps")
 end
 -- Hatch eggs uses the shared Kit header (redesign 0.1): title, Stars capsule, back circle.
 local Kit=require(client.DeckKit)
 local function shopHeader(v,amount)
  local h=v.shopHeader;fit(h.title);fit(h.wallet.amount)
  assert(h.wallet.amount.Text==Kit.formatStars(amount),"capsule shows the exact balance")
  assert(h.back.root.AbsoluteSize.X>=43.9 or v.shopScale.Scale<1,"back hit frame")
  assert(not overlap(h.title,h.wallet.root)and not overlap(h.wallet.root,h.back.disc),"shared header overlaps")
  assert(h.wallet.root.AbsoluteSize.Y==h.back.disc.AbsoluteSize.Y,"capsule and back circle share one height")
 end
 local function shop(amount,available)local v=Shop.new(root,{play=function()end},function()return true end,function()sends+=1 end);table.insert(views,v);v:open(state(amount,available));settle();return v end
 local function resize(size)root.Size=UDim2.fromOffset(size.X,size.Y);settle()end
 local ok,problem=pcall(function()
  for _,size in ipairs(if rootSize then {rootSize}else{Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(812,354),Vector2.new(568,160)})do
   resize(size)
   test(tostring(size).." exact menu wallet and stable bare-X header",function()
    local v=Menu.new(root,{});table.insert(views,v)
    for _,amount in ipairs({0,24,1000000})do
     v:update(state(amount),"pip","wick",0,0,0,"sprout");v:open();settle();header(v,amount)
     local tabY=v.tabs.play.AbsolutePosition.Y
     for _,page in ipairs({"daily","play"})do v:setPage(page);settle();header(v,amount);assert(v.tabs.play.AbsolutePosition.Y==tabY);for _,t in pairs(v.tabs)do fit(t);assert(t.AbsoluteSize.Y>=44)end end
     assert(v.body.CanvasPosition.Y==0 and not v.resumeButton and not v.card:FindFirstChild("Deck",true),"redundant Resume survived")
     v:close()
    end
   end)
   test(tostring(size).." recipe prices and status stay independent of exact balance",function()
    local v=shop(0)
    for _,amount in ipairs({0,24,1000000})do v:update(state(amount));settle();shopHeader(v,amount)
     assert(not overlap(v.body,v.hatchButton),"list overlaps the Hatch button at "..tostring(size))
     -- A 160 px tall emulator leaves a 100 px sheet: the list scrolls but cannot hold a full row.
     if size.Y>=200 then assert(v.body.AbsoluteSize.Y>=44,"list window under 44 px at "..tostring(size))end
    end
    v:update(state(6));v:selectRecipe("hue");settle()
    for _,id in ipairs({"toy","hue"})do local r=v.body.EggColumn["Recipe_"..id];fit(r.RecipeName);fit(r.Cost)end
    local price=v.body.EggColumn.Recipe_hue.Cost
    assert(price.Text:find("8",1,true)and v.action.Text:find("8",1,true)and v.needLine.Text=="2 more Stars needed","selected cost/shortfall missing CTA="..v.action.Text)
    assert(v.nectar.Text=="6"and sends==0)
    v:setError("Your hatch progress updated. Try again.");settle();shopHeader(v,6);assert(v.needLine.Visible and v.needLine.Text==v.errorMessage)
    local n=Notice.resolve("Retrying",{status="Ready"});v:setSaveNotice(n);settle();shopHeader(v,6);assert(v.needLine.Text==n.detail)
    v:setSaveNotice(nil);v:update(state(6));settle();assert(v.selected=="hue"and sends==0);v:close()
   end)
  end
  if not rootSize then
   resize(Vector2.new(733,307))
   test("focused recipe row survives rebuild; focus selects it without a purchase",function()
    local v=shop(24,true);local old=v.body.EggColumn.Recipe_hue;Gui.SelectedObject=old;settle()
    assert(v.selected=="hue","gamepad focus moves the preview (redesign 3)")
    v:layout();v:renderBody();settle();local fresh=v.body.EggColumn.Recipe_hue
    assert(Gui.SelectedObject==fresh and fresh==old,"focused recipe replaced on reflow")
    assert(inside(fresh.RecipeName,v.body)and sends==0)
    v:selectRecipe("hue");settle();assert(Gui.SelectedObject==v.body.EggColumn.Recipe_hue and sends==0);v:close()
   end)
   test("focused daily falls back to the header back circle when the gift is claimed",function()
    resize(Vector2.new(733,307));local v=shop(24,true);Gui.SelectedObject=v.body.EggColumn.DailyNectar;settle()
    v:layout();settle();assert(Gui.SelectedObject==v.body.EggColumn.DailyNectar)
    v:update(state(24,false));settle();assert(Gui.SelectedObject==v.shopBackButton and sends==0)
    v:layout();settle();assert(Gui.SelectedObject==v.shopBackButton and sends==0);v:close()
   end)
   test("back circle and Hatch survive rebuild and detached GUI cannot reclaim focus",function()
    local v=shop(24,true)
    for _,target in ipairs({v.shopBackButton,v.hatchButton})do Gui.SelectedObject=target;v:renderBody();settle();assert(Gui.SelectedObject==target and sends==0)end
    Gui.SelectedObject=v.body.EggColumn.Recipe_hue;local detached=Instance.new("ScreenGui");v.shade.Parent=detached;Gui.SelectedObject=nil;v:renderBody();settle()
    assert(Gui.SelectedObject==nil,"detached sheet reclaimed selection")
    Gui.SelectedObject=nil;v.shade.Parent=root;detached:Destroy();v:close()
   end)
   test("two independent circle controls retain native names and preferred transparency",function()
    local dock=Art.frame(root,"Dock",Art.Surface,UDim2.fromOffset(8,8),UDim2.fromOffset(104,48));dock.BackgroundTransparency=1
    for i,kind in ipairs({"menu","deck"})do local b=Instance.new("TextButton");b.Name=if i==1 then "Menu"else "OpenHandheld";b.Size=UDim2.fromOffset(48,48);b.Position=UDim2.fromOffset((i-1)*56,0);b.Parent=dock;Art.button(b,24);Art.dockCircle(b,kind);assert(b.Text==(if i==1 then "Menu"else "Open deck") and b.TextTransparency==1 and b:GetAttribute("AccessibleLabel") and b:FindFirstChild("DockGlyph"))end
    settle();assert(dock.BackgroundTransparency==1 and inside(dock.Menu,dock) and inside(dock.OpenHandheld,dock) and dock.OpenHandheld.AbsolutePosition.X-dock.Menu.AbsolutePosition.X==56)
    assert(Art.dockTransparency(0)==0 and math.abs(Art.dockTransparency(1)-.18)<.00001);dock:Destroy()
   end)
  end
 end)
 Gui.SelectedObject=nil;for _,v in ipairs(views)do v:close();v.shade:Destroy()end;root:Destroy()
 if Focus.live(previous,nil,playerGui,true)then Gui.SelectedObject=previous end
 assert(ok,problem);return{passed=#cases,cases=cases,preference=Gui.PreferredTextSize.Name}
end
