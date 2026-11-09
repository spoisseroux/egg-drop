-- Real client ScreenGui. Accepted callbacks are the same seams used by production audio.
return function(client,parent)
 local Art=require(client.DeckArt);local Focus=require(client.ControllerFocus);local Gui=game:GetService("GuiService")
 local prior=Gui.SelectedObject;local root=Instance.new("Frame");root.Name="_SemanticUI";root.Size=UDim2.fromOffset(733,307);root.BackgroundTransparency=1;root.Parent=parent
 local cases,views,heard={},{},{};local sends,settings=0,0
 local function accepted(kind)table.insert(heard,kind)end
 local function test(name,run)run();table.insert(cases,name)end
 local menu=require(client.DeckMenu).new(root,{close=function()end,daily=function()sends+=1 end,style=function()sends+=1 end})
 local picker=require(client.DeckPicker).new(root,nil,nil,function()end,function()end,function()return false end,function()settings+=1 end)
 local shop=require(client.EggHatchView).new(root,{play=function()error("legacy UI sound path")end},function()return true end,function()sends+=1 end)
 local journal=require(client.PetJournal).new(root,nil,nil,function()sends+=1 end,function()sends+=1 end,function()sends+=1 end)
 views={menu,picker,shop,journal}
 for _,v in ipairs(views)do v.onAccepted=accepted end
 local ok,err=pcall(function()
  test("opening updating layout and programmatic page selection remain silent",function()
   menu:open();menu:setPage("daily");menu:layout();menu:update({status="Ready",nectar=6,dailyAvailable=true,dailyDay="20000"},"pip");assert(#heard==0)
  end)
  test("two rapid accepted tab switches have distinct callbacks",function()
   assert(menu:activatePage("play"));assert(menu:activatePage("daily"));assert(#heard==2 and heard[1]=="tab"and heard[2]=="tab")
   assert(not menu:activatePage("daily")and not menu:activatePage("missing"));assert(#heard==2)
  end)
  test("disabled controls do not tick or submit and accepted submit ticks once",function()
   menu.dailyButton.Interactable=false;assert(not menu:activate("daily"));assert(sends==0 and #heard==2)
   menu.dailyButton.Interactable=true;assert(menu:activate("daily"));assert(sends==1 and #heard==3)
  end)
  test("X and Back share one accepted close route without forced-close echo",function()
   assert(menu:activate("close"));assert(heard[#heard]=="back");local n=#heard;menu:close();menu:close();assert(#heard==n)
  end)
  test("style tabs and settings distinguish layout from accepted activation",function()
   picker:updateClub(1,0,0,0,"On",false,false,1,true);picker:open("sherbet","none");local n=#heard
   picker:layout();picker:showTab("Settings");assert(#heard==n);assert(picker:changeSetting("music"));assert(settings==1 and #heard==n+1)
   picker:showTab("Shell");assert(not picker:activateTab("Shell"));assert(picker:activateTab("Sticker"));assert(#heard==n+2)
  end)
  test("confirmed no-op and repeat locked inspection stay silent",function()
   picker:showTab("Shell");local n=#heard;picker:activateChoice("Shell","sherbet");assert(#heard==n)
   picker:activateChoice("Shell","honey");assert(#heard==n+1);picker:activateChoice("Shell","honey");assert(#heard==n+1)
   picker:close();assert(#heard==n+1)
  end)
  test("shop selection and submit each notify once; pending and reflow do not",function()
   shop:open({status="Ready",revision=1,nectar=100,inventoryMask=1});local n=#heard
   assert(shop:selectRecipe("hue"));assert(#heard==n+1);assert(shop:selectRecipe("hue"));assert(#heard==n+1)
   shop:send("hatch","sprout");assert(#heard==n+2);shop:send("hatch","sprout");shop:layout();assert(#heard==n+2)
   shop:close("forced");assert(#heard==n+2)
  end)
  test("recap Details accepts once per activation; layout and programmatic details remain silent",function()
   local recap=require(client.RoundRecap).new(root,{play=function()end},function()return true end)
   recap.onAccepted=accepted;recap.frame.Visible=true
   game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()
   recap:update(100,2,1,nil,0,nil,0,100)
   recap:updateField({status="Saved",sequence=101,award=8,daily=0,balance=8,stage=2,success=true,recipe=require(game.ReplicatedStorage.Shared.EggCatalog).ById.meadow,
    reward={sequence=101,total=8,base=8,daily=0,family="pip",masteryPoints=0,contracts={}}})
   local n=#heard;recap:setDetails(false);recap:layoutField(200);assert(#heard==n)
   assert(recap:activateDetails());assert(#heard==n+1 and heard[#heard]=="tab")
   assert(recap:activateDetails());assert(#heard==n+2)
   recap.detailsButton.Interactable=false;assert(not recap:activateDetails());recap.detailsButton.Interactable=true
   recap.frame.Visible=false;assert(not recap:activateDetails());assert(#heard==n+2);recap.frame:Destroy()
  end)
  test("journal goals delegate once and forced lifecycle cleanup is silent",function()
   journal:open(1,0,"pip",false,nil,1,{});local n=#heard;assert(journal:openFamilyGoals());assert(#heard==n+1)
   assert(not journal:openFamilyGoals());journal:close();assert(#heard==n+1)
  end)
 end)
 for _,v in ipairs(views)do if v==shop then v:close("forced")else v:close()end end
 Gui.SelectedObject=if Focus.live(prior,nil,game.Players.LocalPlayer.PlayerGui,true)then prior else nil
 root:Destroy();assert(ok,err);return cases
end
