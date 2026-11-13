-- Studio Client. Shared header (UI-SPEC-REDESIGN-MENUS-2026-11-12 0.1) and icon tabs
-- (0.2): the back circle and the Stars capsule share one height and centre line
-- (44 regular; 36 drawn with a 44x44 hit on compact), back sits at the right edge
-- (W-24 / W-20) with the capsule 8 px left of it, and the title never runs under the
-- capsule whatever the balance. Pure geometry first, then built instances, then the
-- Wardrobe and Deck style headers and the icon tab row.
-- Usage: require(PlayerScripts.Client.ZZSpecs.DeckHeader)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Kit=require(client.DeckKit)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_DeckHeaderSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function near(a,b)return math.abs(a-b)<=.51 end
 local function centreY(n)return n.AbsolutePosition.Y+n.AbsoluteSize.Y/2 end
 local ok,problem=xpcall(function()
  test("geometry: equal heights, shared centre, right edge and 8 px gap",function()
   for _,case in ipairs({{848,false,44,44,824},{812,true,36,34,792},{568,true,36,34,548},{720,false,44,44,696}})do
    local W,compact,h,cy,right=case[1],case[2],case[3],case[4],case[5]
    for _,walletW in ipairs({64,97,140,260})do
     local g=Kit.headerGeometry(W,compact,walletW,24)
     assert(g.back.h==h and g.wallet.h==h and g.back.w==h,"control heights "..W)
     assert(g.back.y+h/2==cy and g.wallet.y+h/2==cy,"shared centre line "..W)
     assert(g.back.x+g.back.w==right,"back right edge "..W)
     assert(g.wallet.x+g.wallet.w==g.back.x-8,"capsule 8 px left of back "..W)
     assert(g.title.x+g.title.w<=g.wallet.x-12,"title runs under the capsule "..W.." "..walletW)
     assert(g.backHit.w==44 and g.backHit.h==44 and g.backHit.x+22==g.back.x+h/2 and g.backHit.y+22==cy,"44 hit centred on the circle")
     assert(g.backHit.x>=g.wallet.x+g.wallet.w,"hit frame overlaps the capsule")
     assert((g.eyebrow==nil)==compact and g.height==(if compact then 60 else 84))
    end
    local none=Kit.headerGeometry(W,compact,nil,24)
    assert(none.wallet==nil and none.title.x+none.title.w<=none.back.x-12,"no capsule: title stops before back")
   end
   local d,h=Kit.backArrowSizes(true,true);assert(d==36 and h==44)
   d,h=Kit.backArrowSizes(false,true);assert(d==44 and h==44)
   d,h=Kit.backArrowSizes(true,false);assert(d==44 and h==44,"deck back arrow unchanged")
   d,h=Kit.backArrowSizes(false,false);assert(d==56 and h==56,"deck back arrow unchanged")
   assert(Kit.formatStars(1280)=="1,280"and Kit.formatStars(128)=="128"and Kit.formatStars(1000000)=="1,000,000"and Kit.formatStars(0)=="0")
  end)
  test("built header: capsule and circle equal and centred at every balance",function()
   for _,case in ipairs({{848,false,44},{812,true,36}})do
    local W,compact,h=case[1],case[2],case[3]
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(W,100);host.Parent=gui
    local header=Kit.header(host,{title="A long title that keeps going and going",eyebrow="Pocket deck",compact=compact,width=W})
    for _,value in ipairs({0,6,128,1280,99999,1234567})do
     header.wallet.set(value);settle()
     local wallet,disc,hit,title=header.wallet.root,header.back.disc,header.back.root,header.title
     assert(wallet.AbsoluteSize.Y==h and disc.AbsoluteSize.Y==h and disc.AbsoluteSize.X==h,W.." equal heights at "..value)
     assert(near(centreY(wallet),centreY(disc)),W.." shared centre at "..value)
     assert(hit.AbsoluteSize==Vector2.new(44,44),W.." 44 hit")
     assert(near(disc.AbsolutePosition.X+h,host.AbsolutePosition.X+W-(if compact then 20 else 24)),W.." back right edge")
     assert(near(wallet.AbsolutePosition.X+wallet.AbsoluteSize.X,disc.AbsolutePosition.X-8),W.." 8 px gap at "..value)
     assert(title.AbsolutePosition.X+title.AbsoluteSize.X<=wallet.AbsolutePosition.X-12+.5,W.." title under capsule at "..value)
     assert(title.TextTruncate==Enum.TextTruncate.AtEnd and title.TextSize==(if compact then 20 else 26))
     assert(header.wallet.amount.Text==Kit.formatStars(value)and wallet:GetAttribute("AccessibleLabel")==tostring(value).." Stars")
    end
    assert(header.eyebrow.Visible==not compact,"eyebrow on regular only")
    host:Destroy()
   end
  end)
  test("icon tabs: icon plus label, dropped together when a segment is too narrow",function()
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(900,200);host.Parent=gui
   local wide=Kit.tabs(host,{"Faceplates","Backgrounds"},800,44,16,{"faceplate","pattern"});settle()
   assert(wide.hasIcons and wide.icons[1]and wide.icons[2],"icons drawn")
   for i=1,2 do
    local icon,label,button=wide.icons[i],wide.labels[i],wide.buttons[i]
    assert(icon.AbsoluteSize.X==20 and label.TextFits,"icon is label size + 4")
    assert(near(label.AbsolutePosition.X-(icon.AbsolutePosition.X+icon.AbsoluteSize.X),7),"7 px apart")
    local left=icon.AbsolutePosition.X-button.AbsolutePosition.X;local right=button.AbsolutePosition.X+button.AbsoluteSize.X-(label.AbsolutePosition.X+label.TextBounds.X)
    assert(math.abs(left-right)<=3,"centred in the segment")
    assert(button.AbsoluteSize.Y>=44)
   end
   wide.select(2);assert(wide.root:GetAttribute("Selected")==2)
   local narrow=Kit.tabs(host,{"Faceplates","Backgrounds"},160,36,14,{"faceplate","pattern"});settle()
   assert(not narrow.hasIcons and #narrow.icons==0 and narrow.labels[1].Text=="Faceplates"and narrow.labels[2].Text=="Backgrounds","narrow row keeps labels, drops icons")
   for _,b in ipairs(narrow.buttons)do assert(b.AbsoluteSize.Y>=44)end
   for _,name in ipairs({"paw","shirt","wand","drop","sparkle","sphere","ball","none","pattern","chevron"})do
    local icon=Kit.icon(host,name,24,"soft");assert(icon.AbsoluteSize==Vector2.new(24,24)and #icon:GetDescendants()>0,name)
    Kit.tintIcon(icon,"accent")
   end
   host:Destroy()
  end)
  test("Wardrobe and Deck style use the shared header, regular and compact",function()
   local Wardrobe=require(client.WardrobeShop);local Shop=require(client.FaceplateShop)
   for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354)})do
    local compact=Kit.compactRule(size.X,size.Y);local h=if compact then 36 else 44
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local wardrobe=Wardrobe.new(host,{});wardrobe:fit(size);wardrobe.wallet.set(128);settle()
    assert(wardrobe.header and wardrobe.header.compact==compact and wardrobe.title.Text=="Wardrobe",tostring(size).." wardrobe header")
    assert(wardrobe.wallet.root.Size.Y.Offset==h and wardrobe.backArrow.disc.Size.Y.Offset==h,tostring(size).." wardrobe heights")
    assert(not wardrobe.root:FindFirstChild("BackArrow",true)or wardrobe.root:FindFirstChild("BackArrow",true)==wardrobe.backArrow.root,"one back control")
    if not compact then assert(wardrobe.header.eyebrow.Text=="COMPANIONS")end
    wardrobe:destroy()
    local deck=Shop.new(host,{});deck:fit(size);deck:setContext({equipped="sherbet",wallet=1280,facts={faceplates={}}});deck:open("sherbet");settle()
    assert(deck.title.Text=="Deck style"and deck.header.compact==compact,tostring(size).." deck style header")
    assert(deck.wallet.root.Size.Y.Offset==h and deck.backArrow.disc.Size.Y.Offset==h and deck.wallet.amount.Text=="1,280")
    -- The old ghost "Backgrounds" button in the header is now the second tab.
    assert(deck.tabs.labels[2].Text=="Backgrounds"and deck.tabs.buttons[2].AbsoluteSize.Y>=44)
    for _,node in ipairs(deck.root:GetDescendants())do assert(not(node:IsA("TextButton")and node.Name=="Backgrounds"),"ghost Backgrounds button remains")end
    if not compact then assert(deck.header.eyebrow.Text=="POCKET DECK")end
    deck:close();host:Destroy()
   end
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
