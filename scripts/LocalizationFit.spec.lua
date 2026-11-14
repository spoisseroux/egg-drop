-- Studio Client. v1 track C, translations: text fit under a pseudo locale.
-- Roblox automatic translation swaps a label's rendered text without the screen laying
-- itself out again, so a label whose translation runs longer than English clips. This
-- spec builds the main screens at 1920 x 1080 and 812 x 354, replaces the text of every
-- translatable label (AutoLocalize on, itself and its ancestors) with UICopy.pseudo
-- (about 35% longer, accented, in [brackets]) and reports each label that does not fit:
--   clip     TextFits false, no TextScaled and no TextTruncate (the end is cut off)
--   grows    an auto-sized label that now runs past its parent
--   handled  TextFits false but truncated with an ellipsis or scaled down (counted, fine)
--   english  already clips in English (a layout bug, not a translation one)
-- Labels with AutoLocalize off (numbers, pet names, key caps, rich text built from
-- parts) are skipped: they are never translated. Screens are built as a translated
-- client builds them (Kit.setTranslating(true): the Kit text-fit guard truncates or
-- wraps labels sized for their English, and caps button labels), so `handled` rows are
-- where a long translation shows an ellipsis; they are listed as TRUNC in the report. Screens: deck HUD, results, machine
-- hub, pause menu, Deck style (3 tabs + Settings), Companions (hub + Pets), Wardrobe,
-- Collection book (a page + Records), stamp card, quest log (daily + weekly), Hatch eggs,
-- item carousel, Pet Park chip. A screen that fails to build is reported, not fatal.
-- Also checks the translation rules (Kit counters, key caps and rich text off, words
-- on) and the pseudo locale itself. Nothing is sent.
-- Usage: require(PlayerScripts.Client.ZZSpecs.LocalizationFit)(PlayerScripts.Client, PlayerGui, {strict=false})
--   returns {passed, cases, clips, handled, english, report}. strict=true also fails on any clip.
return function(client,parent,options)
 options=options or {}
 local RS=game:GetService("ReplicatedStorage")
 local Run=game:GetService("RunService")
 local UICopy=require(RS.Shared.UICopy)
 local Kit=require(client.DeckKit)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function settle(n)for _=1,n or 3 do Run.Heartbeat:Wait()end end
 local aspect=(11+.8)/(19+.8)
 local sizes={Vector2.new(1920,1080),Vector2.new(812,354)}
 local results={clips={},handled={},english={},grows={},failed={}}
 local report={}
 local guis={}

 local function screenGui(name)
  local gui=Instance.new("ScreenGui");gui.Name=name;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.IgnoreGuiInset=true
  gui.ResetOnSpawn=false;gui.DisplayOrder=50;gui.Parent=parent;table.insert(guis,gui)
  return gui
 end
 local function host(gui,size)
  local frame=Instance.new("Frame");frame.Name="Host";frame.BackgroundTransparency=1;frame.Size=UDim2.fromOffset(size.X,size.Y);frame.Parent=gui
  return frame
 end
 -- Translatable: AutoLocalize on for the label and every GuiBase2d above it.
 local function translatable(label)
  local node=label
  while node and node~=parent do
   if node:IsA("GuiBase2d")and not node.AutoLocalize then return false end
   node=node.Parent
  end
  return true
 end
 local function shown(label,root)
  local node=label
  while node and node~=root do
   if node:IsA("GuiObject")and not node.Visible then return false end
   if node:IsA("ScreenGui")and not node.Enabled then return false end
   node=node.Parent
  end
  return true
 end
 local function path(label,root)
  local parts,node={},label
  while node and node~=root and node~=parent do table.insert(parts,1,node.Name);node=node.Parent end
  return table.concat(parts,".")
 end
 local function overflows(label)
  local p=label.Parent
  if not(p and p:IsA("GuiObject"))then return false end
  local a,b=label.AbsolutePosition,label.AbsoluteSize
  local c,d=p.AbsolutePosition,p.AbsoluteSize
  return a.X<c.X-1 or a.X+b.X>c.X+d.X+1
 end
 -- Does the label's text run past its box? TextFits, and for one-line Kit labels the
 -- measured width too (a truncated label may report TextFits either way), compared in
 -- the label's own units when a UIScale sits above it.
 local function overflowing(label)
  if not label.TextFits then return true end
  local role=label:GetAttribute("KitRole")
  if label.TextWrapped or label.TextScaled or not role then return false end
  local scale=if label.Size.X.Scale==0 and label.Size.X.Offset>0 then label.AbsoluteSize.X/label.Size.X.Offset else 1
  return Kit.measure(label.Text,role,label.TextSize).X*scale>label.AbsoluteSize.X+1
 end
 -- Pseudo-translate every shown, translatable label under `roots` and record the misfits.
 local function check(screen,size,roots)
  local labels={}
  for _,root in ipairs(roots)do
   for _,node in ipairs(root:GetDescendants())do
    if(node:IsA("TextLabel")or node:IsA("TextButton")or node:IsA("TextBox"))and node.Text~=""and string.find(node.Text,"%a")
     and node.AbsoluteSize.X>=2 and shown(node,root)and translatable(node)then
     table.insert(labels,{label=node,root=root,english=node.Text,englishFits=not overflowing(node)})
    end
   end
  end
  -- KitEnglish: the Kit guard keeps judging the box against the English source.
  for _,entry in ipairs(labels)do entry.label:SetAttribute("KitEnglish",entry.english);entry.label.Text=UICopy.pseudo(entry.english)end
  settle(3)
  local counts={labels=#labels,clip=0,handled=0}
  for _,entry in ipairs(labels)do
   local label=entry.label
   local where=string.format("%s %dx%d %s",screen,size.X,size.Y,path(label,entry.root))
   local row={screen=screen,size=size,path=path(label,entry.root),text=entry.english,role=label:GetAttribute("KitRole"),
    width=label.AbsoluteSize.X,need=label.TextBounds.X}
   if not entry.englishFits and not label.TextScaled and label.TextTruncate==Enum.TextTruncate.None then
    table.insert(results.english,row);table.insert(report,"ENGLISH  "..where.."  '"..entry.english.."'")
   elseif overflowing(label)then
    if label.TextScaled or label.TextTruncate~=Enum.TextTruncate.None then
     table.insert(results.handled,row);counts.handled+=1
     table.insert(report,string.format("TRUNC    %s  '%s' (%d px box)",where,entry.english,row.width))
    else
     table.insert(results.clips,row);counts.clip+=1
     table.insert(report,string.format("CLIP     %s  '%s' (%d px box, %s)",where,entry.english,row.width,tostring(row.role)))
    end
   elseif label.AutomaticSize~=Enum.AutomaticSize.None and overflows(label)then
    table.insert(results.grows,row)
    table.insert(report,string.format("GROWS    %s  '%s'",where,entry.english))
   end
  end
  table.insert(report,string.format("-- %s %dx%d: %d labels, %d clip, %d truncated/scaled",screen,size.X,size.Y,counts.labels,counts.clip,counts.handled))
 end
 -- Build one screen in its own gui, check it, close it and clean up whatever happens.
 local function screen(name,size,build)
  local gui=screenGui("_LocalizationFit_"..name)
  local ok,problem=xpcall(function()
   local view,roots,closer=build(gui,host(gui,size),size)
   task.wait(.45) -- slide-ins and count-ups settle
   check(name,size,roots or {gui})
   if closer then pcall(closer)elseif view then
    for _,method in ipairs({"close","hide"})do if type(view[method])=="function"then pcall(view[method],view)break end end
   end
  end,debug.traceback)
  if not ok then
   table.insert(results.failed,{screen=name,size=size,problem=problem})
   table.insert(report,string.format("FAILED   %s %dx%d: %s",name,size.X,size.Y,tostring(problem)))
  end
  gui:Destroy()
 end

 local wasTranslating=Kit.translating
 Kit.setTranslating(true)
 local ok,problem=xpcall(function()
  test("pseudo locale: ~35% longer, accented, bracketed; placeholders and tags survive",function()
   local english=UICopy.get("results.leave.wide")
   local p=UICopy.pseudo(english)
   assert(string.sub(p,1,1)=="["and string.sub(p,-1)=="]","bracketed: "..p)
   assert(utf8.len(p)>=math.floor(utf8.len(english)*1.3),"at least 30% longer: "..p)
   assert(p~=english and not string.find(p,"garden",1,true),"letters accented: "..p)
   local t=UICopy.pseudo("{count} Stars short")
   assert(string.find(t,"{count}",1,true),"placeholder kept: "..t)
   assert(string.find(UICopy.pseudo('<font size="12">Win</font> now'),'<font size="12">',1,true),"tags kept")
   assert(UICopy.pseudo("")==""and UICopy.pseudo(nil)==nil)
   -- Studio: the switch for UICopy.get (FeatureFlags.PseudoLocale sets it at load).
   local was=UICopy.pseudoEnabled()
   UICopy.setPseudo(true)
   assert(UICopy.pseudoEnabled(),"Studio turns the pseudo locale on")
   local filled=UICopy.get("shop.short.many",{count=12})
   assert(string.sub(filled,1,1)=="["and string.find(filled,"12",1,true),"get pseudo-translates and fills: "..filled)
   UICopy.setPseudo(was)
   assert(UICopy.get("results.leave.wide")==english or was,"switched back")
  end)
  test("translation rules: counters, key caps, pet names and rich text off; words on",function()
   local gui=screenGui("_LocalizationRules");local frame=host(gui,Vector2.new(400,200))
   assert(Kit.text(frame,"Body","Back to the garden").AutoLocalize,"words translate")
   assert(not Kit.text(frame,"Counter","128").AutoLocalize and not Kit.text(frame,"CounterL","2340").AutoLocalize,"counters stay as they are")
   assert(Kit.text(frame,"Counter","IN USE","soft",{AutoLocalize=true}).AutoLocalize,"a counter with words opts in")
   local chip=Kit.glyph(frame,"LB",false,26,true)
   for _,node in ipairs(chip:GetDescendants())do if node:IsA("TextLabel")then assert(not node.AutoLocalize,"key caps stay as they are")end end
   local label=Kit.text(frame,"Body","");label.RichText=true
   label.Text='Make <font size="14">●</font> on LEFT';Kit.localizeRich(label);assert(not label.AutoLocalize,"rich text with markup stays")
   label.Text="Win 2 rounds";Kit.localizeRich(label);assert(label.AutoLocalize,"plain quest titles translate")
   assert(not Kit.fixedText(Kit.text(frame,"Title","Bear")).AutoLocalize)
   -- The text-fit guard: a box sized for its English truncates (and wraps with room for two
   -- lines); English drawn past its box on purpose is left alone; buttons cap their label.
   local fits=Kit.text(frame,"Body","Back to the garden","text",{Size=UDim2.fromOffset(200,20)})
   local tall=Kit.text(frame,"Body","Back to the garden","text",{Size=UDim2.fromOffset(200,48)})
   local over=Kit.text(frame,"Body","Back to the garden","text",{Size=UDim2.fromOffset(10,20)})
   local button,state=Kit.button(frame,"B",{text="Leave",size=Vector2.new(120,44)})
   settle(3)
   assert(fits.TextTruncate==Enum.TextTruncate.AtEnd and not fits.TextWrapped,"single line box truncates")
   assert(tall.TextTruncate==Enum.TextTruncate.AtEnd and tall.TextWrapped,"two-line box wraps")
   assert(over.TextTruncate==Enum.TextTruncate.None,"overflow on purpose is left alone")
   assert(state.cap and state.cap.MaxSize.X<=120-16 and state.label.TextTruncate==Enum.TextTruncate.AtEnd,"button label capped")
   fits:SetAttribute("KitEnglish",fits.Text);fits.Text=UICopy.pseudo(fits.Text);settle(2)
   assert(fits.TextTruncate==Enum.TextTruncate.AtEnd,"a long translation keeps its ellipsis (the guard judges the English)")
   gui:Destroy()
  end)

  -- Fixtures shared by the screens.
  local Pets=require(RS.Shared.PetCatalog)
  local hubSnapshot={nectar=128,dailyAvailable=true,quests={daily={{ready=true},{ready=false}},weekly={{ready=true}},bonusReady=false},
   book={claimable={"balls.25"}}}
  local function resultData(changes)
   local value={outcome="clear",title="Creek crossing",difficulty="Medium",total=12,earned=12,balance=140,
    rows={{name="Round win",amount=6},{name="Daily quests",amount=6}},
    goals={{text="Match I + I in CENTER",short="II centre",done=true},{text="Make III or higher on RIGHT",short="III RIGHT",done=false}},
    score=2340,best=2210,chain=4,newBest=true,strip="Chain 3 merges ★+3",stripRight="You can hatch an egg",eggName="Toy Egg",eggCost=8,
    quest={scope="daily",title="Win 2 rounds",count=1,target=2,moved=1},todayEarned=19,petName="Bear",
    result={status="Saved",receiptPending=false,sequence=1,reward={sequence=1,total=12,base=6,daily=6,contracts={}}}}
   for key,item in pairs(changes or {})do value[key]=item end
   return value
  end
  local quests={day="1",week="1",rerollLeft=1,
   daily={{slot=1,id="d_win_medium",title="Win on Medium or higher",sub="Medium or Hard",progress=0,target=1,reward=4},
    {slot=2,id="d_goals_hard",title="Complete 3 goals on Hard",sub="Across Hard rounds",progress=1,target=3,reward=4},
    {slot=3,id="d_templates3",title="Play 3 goal types",sub="Finish rounds with different goals",progress=3,target=3,ready=true,reward=4}},
   weekly={{slot=1,id="w_heats3",title="Play all three difficulties",progress=1,target=3,reward=10},
    {slot=2,id="w_goals_hard12",title="Complete 12 goals on Hard",sub="Hard rounds",progress=4,target=12,reward=10},
    {slot=3,id="w_templates6",title="Play all 6 goal types",sub="Finish rounds with each goal",progress=2,target=6,reward=10}},history={}}
  local wardrobePet
  local Wear=require(RS.Shared.WearableCatalog)
  for _,pet in ipairs(Pets.collection)do if Wear.hasItems(pet.id)then wardrobePet=pet.id;break end end
  local audio={group={Volume=1},deviceActive=true,deviceEpoch=0}
  function audio:play()return true end
  function audio:stopOwner()end

  for _,size in ipairs(sizes)do
   local phone=size.X<1000
   local keep=if phone then {kx=116,kh=58}else nil
   local Screen=require(client.DeckScreen)
   screen("DeckHUD",size,function(gui,root)
    local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(size,aspect,keep);s:setVisible(true)
    s:setHud({score=2340,best=2210,chain=7,goals={{text="Match I + I in CENTER",done=true,progress=1,target=1},{text="Make III on RIGHT",done=false,progress=0,target=1}},
     daily={{title="Win 2 rounds",progress=1,target=2},{title="Play two difficulties",progress=0,target=2}},next={2,1,3},eggsLeft=14,budget=24,input="Gamepad"})
    s:setItems(2)
    return nil,{root}
   end)
   screen("Results",size,function(gui,root)
    local Results=require(client.DeckResults)
    local inner=Instance.new("Frame");inner.BackgroundTransparency=1;inner.Parent=root
    local view=Results.new(inner,{audio=audio,reduce=function()return true end})
    if phone then
     -- The 812 x 354 phone sheet (DeckResults spec geometry).
     inner.Size=UDim2.fromOffset(748,294)
     view:show(resultData({canHatch=true}),{phone=true,W=748,H=294,kx=0,kh=0,hx=26,cw=229,ch=154,actionY=228,off=32,mg=38,top=60})
    else
     inner.Size=UDim2.fromOffset(848,608)
     view:show(resultData({canHatch=true}),false)
    end
    if view.feedback and view.feedback.connection then view.feedback.connection:Disconnect();view.feedback.connection=nil end
    if view.feedback then for _=1,600 do view.feedback:step(.01)end end
    return view,{root}
   end)
   screen("ResultsMissed",size,function(gui,root)
    local Results=require(client.DeckResults)
    local inner=Instance.new("Frame");inner.BackgroundTransparency=1;inner.Parent=root
    local view=Results.new(inner,{audio=audio,reduce=function()return true end})
    local data=resultData({outcome="overflow",loss=true,rows={},total=0,earned=0,result={status="Saved",receiptPending=false,sequence=2,reward={sequence=2,total=0,base=0,daily=0,contracts={}}}})
    if phone then inner.Size=UDim2.fromOffset(748,294);view:show(data,{phone=true,W=748,H=294,kx=0,kh=0,hx=26,cw=229,ch=154,actionY=228,off=32,mg=38,top=60})
    else inner.Size=UDim2.fromOffset(848,608);view:show(data,false)end
    if view.feedback and view.feedback.connection then view.feedback.connection:Disconnect();view.feedback.connection=nil end
    if view.feedback then for _=1,600 do view.feedback:step(.01)end end
    return view,{root}
   end)
   screen("MachineHub",size,function(gui,root)
    local Hub=require(client.MachineHub)
    local hub=Hub.new(root,{open=function()return true end,locked=function()end,closed=function()end})
    hub:open({owned=1,wallet=128,state=hubSnapshot})
    return hub,{root},function()hub:close("back")end
   end)
   screen("MachineHubLocked",size,function(gui,root)
    local Hub=require(client.MachineHub)
    local hub=Hub.new(root,{open=function()return true end,locked=function()end,closed=function()end})
    hub:open({owned=0,wallet=0,state={}})
    return hub,{root},function()hub:close("back")end
   end)
   screen("PauseMenu",size,function(gui,root)
    local Pocket=require(client.PocketMenu)
    local s=Screen.new({parent=root,overlayParent=root,viewRoot=root})
    local menu=Pocket.new(s:addOverlay("Pocket",36,{lcd=true}),{resume=function()end,restart=function()end,quit=function()end,settings=function()end})
    s:layout(size,aspect,keep);s:setVisible(true)
    menu:open({empty=false,canRestart=true,canQuit=true,canSettings=true})
    return menu,{root},function()menu:close(true)end
   end)
   for _,tab in ipairs({"Faceplates","Background","Balls","Settings"})do
    screen("DeckStyle_"..tab,size,function(gui,root)
     local Picker=require(client.DeckPicker)
     local v=Picker.new(root,nil,nil,function()end,function()end,function()end,function()end)
     v:updateClub(1,0,0,0,"On",false,false,1,true,0,{pip=0});v:setShopState(128,{})
     v.customizationEntry=tab~="Settings"
     if tab=="Faceplates"then v:open("sherbet","none")else v:open("sherbet","none",tab)end
     return v,{root},function()v:close("back")end
    end)
   end
   screen("Companions",size,function(gui,root)
    local Hub=require(client.CompanionsHub)
    local hub=Hub.new(root,{appearance=function()return{charmVisible=true}end,open=function()return true end,follow=function()return true end,back=function()end})
    hub:open({wallet=128,state={inventoryMask=127,nectar=128,pendingToyResult={id="t"},petWearables={}},activeId=Pets.collection[1].id})
    return hub,{root},function()hub:close("back")end
   end)
   screen("CompanionsPets",size,function(gui,root)
    local Hub=require(client.CompanionsHub)
    local hub=Hub.new(root,{appearance=function()return{charmVisible=true}end,open=function()return true end,follow=function()return true end,back=function()end})
    hub:open({wallet=128,state={inventoryMask=127,nectar=128,petWearables={}},activeId=Pets.collection[1].id},{page="pets"})
    return hub,{root},function()hub:close("back")end
   end)
   if wardrobePet then
    screen("Wardrobe",size,function(gui,root)
     local Wardrobe=require(client.WardrobeShop)
     local shop=Wardrobe.new(root,{appearance=function()return{}end})
     shop:open(wardrobePet,{wallet=40,row={owned={},equipped={}}})
     return shop,{root},function()shop:close()end
    end)
   end
   for _,page in ipairs({"balls","records"})do
    screen("Book_"..page,size,function(gui,root)
     local Book=require(client.BookView);local Catalog=require(RS.Shared.BookCatalog)
     local pages={}
     for _,id in ipairs(Catalog.PageOrder)do
      local items=Catalog.Pages[id]and Catalog.Pages[id].items or {}
      local ms={}
      for _,pct in ipairs(Catalog.Steps)do table.insert(ms,{id=id.."."..pct,percent=pct,reward=Catalog.Rewards[pct],claimed=pct==25,reached=pct<=50})end
      table.insert(pages,{id=id,name=string.upper(string.sub(id,1,1))..string.sub(id,2),owned=math.min(2,#items),total=#items,percent=50,ownedIds={},milestones=ms})
     end
     local view=Book.new(root,{send=function()end})
     view:open({book={pages=pages,claimed={},claimable={},found=0,faceplate="bookworm",faceplateEarned=false},
      stats={rounds=42,winsEasy=10,winsMedium=7,winsHard=2,tidyWins=5,merges=1200,bestChain=6,tierFive=3,itemsUsed=9,pets=1,starsEarned=1280,starsSpent=300},
      stamps=12,wallet=128,revision=7},{page=page})
     return view,{root},function()view:close("back")end
    end)
   end
   screen("StampCard",size,function(gui,root)
    local View=require(client.StampCardView);local Stamp=require(RS.Shared.StampCard)
    local card=View.new(root)
    card:layout(if phone then 226 else 320,phone)
    card:set({stamps=6,dailyAvailable=true,dailyBonus=Stamp.reward(6),stampCard={rewards=table.clone(Stamp.Rewards),onCard=Stamp.onCard(6),next=Stamp.position(6)}})
    return card,{root}
   end)
   for _,tab in ipairs({"daily","weekly"})do
    screen("QuestLog_"..tab,size,function(gui,root)
     local QuestHost=require(client.QuestLogHost);local Log=require(client.QuestLog)
     local qhost=QuestHost.new(root)
     local log=Log.new(qhost.overlay,{claim=function()end})
     log:show(quests,128,tab)
     return log,{root},function()log:hide();qhost:destroy()end
    end)
   end
   screen("HatchEggs",size,function(gui,root)
    local Shop=require(client.EggHatchView)
    local view=Shop.new(root,{play=function()end,stopOwner=function()end},function()return true end,function()end)
    view:open({status="Ready",revision=1,nectar=128,toyUnlocks={},materialUnlocks={},materialAvailable=true,dailyAvailable=true,stamps=2})
    return view,{root}
   end)
   screen("ItemCarousel",size,function(gui,root)
    local Carousel=require(client.ItemCarousel)
    local c=Carousel.new(root)
    if phone then c:place(UDim2.fromOffset(20,0),UDim2.fromOffset(240,300),true)else c:place(UDim2.fromOffset(20,0),UDim2.fromOffset(330,580),false)end
    c:setBelt({"bomb","magnet","swap"});c:open()
    return c,{root},function()c:close(true);c:destroy()end
   end)
   screen("ParkChip",size,function(gui,root)
    local Park=require(client.ParkClient)
    -- The chip makes its own ScreenGui (EggDropPark) under guiParent.
    local fake={guiParent=parent}
    assert(Park.makeChip(fake),"park chip built")
    fake.chip.Enabled=true;fake.chipCount.Text=UICopy.get("park.playDate",{count=1,target=3})
    table.insert(guis,fake.chip)
    return nil,{fake.chip},function()fake.chip:Destroy()end
   end)
  end

  test("every screen built at both sizes",function()
   local names={}
   for _,f in ipairs(results.failed)do table.insert(names,f.screen.." "..tostring(f.size))end
   assert(#results.failed==0,"screens that did not build: "..table.concat(names,", "))
  end)
  if options.strict then
   test("no translatable label clips under the pseudo locale",function()
    assert(#results.clips==0,#results.clips.." clipped labels (see report)")
   end)
  end
 end,debug.traceback)
 Kit.setTranslating(wasTranslating)
 for _,gui in ipairs(guis)do if gui.Parent then gui:Destroy()end end
 table.insert(report,1,string.format("LocalizationFit: %d clip, %d grow past parent, %d truncated/scaled, %d already clip in English, %d screens failed",
  #results.clips,#results.grows,#results.handled,#results.english,#results.failed))
 print(table.concat(report,"\n"))
 assert(ok,problem)
 return{passed=#cases,cases=cases,clips=results.clips,grows=results.grows,handled=#results.handled,english=results.english,
  failed=results.failed,report=table.concat(report,"\n")}
end
