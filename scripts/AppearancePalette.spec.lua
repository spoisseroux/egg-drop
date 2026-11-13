-- Actual widgets in a real LocalScript/ScreenGui. Optional root limits native deadline.
return function(client,parent,onlySize)
 local Art=require(client.DeckArt);local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
 local Menu=require(client.DeckMenu);local Picker=require(client.DeckPicker);local Journal=require(client.PetJournal)
 local Shop=require(client.EggHatchView);local Results=require(client.DeckResults);local Focus=require(client.PetFocusUI)
 local old=Art.getTheme();local defaults={Art.Surface,Art.Ink,Art.Silver,Art.Focus};local cases,cleanup={},{}
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent
 local audio={play=function()end};local writes=0
 local function outgoing()writes+=1 end
 local function test(n,f)f();table.insert(cases,n)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function fit(n)assert(n.TextFits,n:GetFullName().." "..n.Text.." "..tostring(n.AbsoluteSize).." "..tostring(n.TextBounds))end
 local function channel(c)local function v(x)return if x<=.04045 then x/12.92 else ((x+.055)/1.055)^2.4 end;return .2126*v(c.R)+.7152*v(c.G)+.0722*v(c.B)end
 local function contrast(a,b)a,b=channel(a),channel(b);return(math.max(a,b)+.05)/(math.min(a,b)+.05)end
 local function shade(c,f)return Color3.new(c.R*f,c.G*f,c.B*f)end
 local function result(seq)return{sequence=seq,status="Saved",success=true,stage=2,reason="Completed",award=8,daily=0,balance=10,recipe=game.ReplicatedStorage.Shared.EggCatalog and require(game.ReplicatedStorage.Shared.EggCatalog).ById.meadow,reward={sequence=seq,total=8,base=8,daily=0,family="pip",masteryPoints=1,promotedTo=0,contracts={}}}end
 local ok,err=pcall(function()
 test("all8 palettes keep body supporting and LCD ink readable",function()
  for _,id in ipairs(Themes.Order)do local t=Themes.ById[id]
   for _,role in ipairs({"contentPanel","contentRaised","contentInset","contentSelected"})do assert(contrast(t.ui.contentText,t.ui[role])>=4.5 and contrast(t.ui.contentMuted,t.ui[role])>=4.5,id.." light content contrast "..role)end
   assert(contrast(t.ui.tabInk,t.ui.tab)>=4.5,id.." active jewel tab contrast")
   for _,role in ipairs({"panel","raised","inset","selected"})do assert(contrast(t.ui.text,t.ui[role])>=4.5,id.." text contrast "..role)end
   -- Dark-well board: light text and the danger word read on the well.
   assert(contrast(t.ui.muted,t.ui.raised)>=4.5 and contrast(t.ui.text,t.lcd.base)>=4.5 and contrast(Color3.fromHex("#FF5A6E"),t.lcd.base)>=4.5,id.." supporting/LCD contrast")
   -- Gradients are neutral multipliers over the role color. Check both authored
   -- ends, including the TextButton foreground when its own gradient is applied.
   for _,sample in ipairs({{"panel",.96},{"raised",.97},{"inset",.96},{"selected",.97}})do
    for _,factor in ipairs({1,sample[2]})do
     local background=shade(t.ui[sample[1]],factor)
     assert(contrast(t.ui.text,background)>=4.5 and contrast(shade(t.ui.muted,factor),background)>=4.5,id.." composited functional copy "..sample[1])
    end
   end
   for _,factor in ipairs({1,.96})do
    assert(contrast(shade(t.ui.ink,factor),shade(t.ui.accent,factor))>=4.5,id.." composited primary ink")
    assert(contrast(t.ui.ink,shade(t.ui.accent,factor))>=3,id.." primary dark boundary")
   end
   assert(contrast(t.ui.ink,t.highlight)>=4.5,id.." backed shell title ink")
   assert(#t.shellGradient.Keypoints==3 and t.shellGradient.Keypoints[1].Value==t.highlight and t.shellGradient.Keypoints[3].Value==t.shell,id.." authored finish stops")
  end
 end)
 for _,size in ipairs(if onlySize then {onlySize}else {Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
  root.Size=UDim2.fromOffset(size.X,size.Y);settle()
  local menu=Menu.new(root,{});local picker=Picker.new(root,nil,nil,outgoing,outgoing,outgoing,outgoing)
  local journal=Journal.new(root,nil,nil,outgoing,outgoing,outgoing);local shop=Shop.new(root,audio,function()return true end,outgoing)
  local resultsHost=Instance.new("Frame");resultsHost.Size=UDim2.fromOffset(848,608);resultsHost.BackgroundTransparency=1;resultsHost.Parent=root
  local recap=Results.new(Instance.new("Frame",resultsHost),{});recap.host.Size=UDim2.fromOffset(848,608);local focus=Focus.new(parent,{})
  for _,v in ipairs({menu,picker,journal,shop})do table.insert(cleanup,function()v:close();v.shade:Destroy()end)end
  table.insert(cleanup,function()resultsHost:Destroy()end);table.insert(cleanup,function()focus:destroy()end)
  menu:update({status="Ready",nectar=24,inventoryMask=1,dailyAvailable=false},"pip","pip",0,0,0,"meadow");menu:open();menu:setPage("daily")
  picker:updateClub(1,0,0,0,"On",false,false,1,true,0,{pip=0});picker:open("sherbet","none")
  journal:open(1,0,"pip",false,nil,1,{pip=0});shop:open({status="Ready",revision=4,nectar=24,inventoryMask=1});shop:selectRecipe("hue")
  local function resultsData(sequence)return{outcome="clear",title="Bank pair",rows={{name="Round win",amount=8},{name="Daily quests",amount=6}},total=14,earned=14,balance=20,goals={{text="Goal",done=true}}}end
  recap:show(resultsData(9),false)
  focus.panel.Visible=true;focus.back.Visible=true;focus.helper.Visible=true
  test(tostring(size).." open sheets keep the house palette under every faceplate (the plate tints only the deck and its background)",function()
   local recipe=shop.body.EggColumn.Recipe_hue;local pending=shop.pending
   local amber=shop.nectar.TextColor3
   for _,id in ipairs(Themes.Order)do
    local plate=Themes.ById[id];Art.applyTheme(plate);settle()
    -- Batch 2026-11-13: menus never take the plate's glass; the hardware still reads the plate.
    local t=Art.uiTheme();assert(Art.getTheme()==plate and t==Themes.ById[Themes.Default])
    assert(menu.card.BackgroundColor3==t.ui.contentPanel and menu.tabs.daily.BackgroundColor3==t.ui.tab and menu.tabs.daily.TextColor3==t.ui.tabInk)
    assert(shop.action.BackgroundColor3==t.ui.accent and shop.action.TextColor3==t.ui.ink,"actual refreshed shop CTA retained fixed reward color")
    assert(menu.card:FindFirstChildOfClass("UIGradient").Rotation==100 and menu.nectar.Font==Art.Font.Counter)
    -- The Deck style screen and the Settings / Trials card are Kit panels (plate glass).
    assert(picker.card.BackgroundColor3==t.ui.panel and picker.shop.root.BackgroundColor3==t.ui.panel)
    assert(journal.card.BackgroundColor3==t.ui.contentPanel and journal.cards[1].BackgroundColor3==t.ui.contentRaised and journal.cards[1].Species.TextColor3==t.ui.contentText)
    -- Redesign 3: Hatch eggs is a Kit panel; the selected row takes the plate's `selected` glass, its text stays neutral.
    local Kit=require(client.DeckKit)
    assert(shop.card.BackgroundColor3==t.ui.contentPanel and recipe.BackgroundColor3==Kit.color("selected")and recipe.RecipeName.TextColor3==Kit.Color.text and shop.shopPanel.BackgroundColor3==Kit.color("panel"),"egg shop (EggHatchView) card/recipe palette: card="..tostring(shop.card.BackgroundColor3).." recipe="..tostring(recipe.BackgroundColor3))
    assert(recap.payout.BackgroundColor3==t.ui.raised and recap.wallet.root.BackgroundColor3==t.ui.inset and recap.rows[1].name.TextColor3~=t.ui.accent,"results glass stays house; text stays neutral")
    assert(focus.back.BackgroundColor3==t.ui.panel and focus.helper.BackgroundColor3==t.ui.panel and focus.helper.TextColor3==t.ui.text)
    assert(shop.selected=="hue"and shop.pending==pending and shop.body.EggColumn.Recipe_hue==recipe and shop.nectar.TextColor3==amber)
    assert(Art.Surface==defaults[1]and Art.Ink==defaults[2]and Art.Silver==defaults[3]and Art.Focus==defaults[4],"public art constants changed")
   end
  end)
  test(tostring(size).." newly rebuilt recipe and receipt rows inherit active palette",function()
   local plate=Themes.ById.copperleaf;Art.applyTheme(plate);local t=Art.uiTheme();local recipe=shop.body.EggColumn.Recipe_hue
   local before=shop.body.CanvasPosition;shop:layout();shop:renderBody();recap:show(resultsData(10),false);settle()
   assert(shop.body.EggColumn.Recipe_hue==recipe and (recipe.RecipeName.TextColor3==t.ui.ink or recipe.RecipeName.TextColor3==t.ui.text)and shop.selected=="hue",
    "recipe name colour "..tostring(recipe.RecipeName.TextColor3).." vs ink "..tostring(t.ui.ink).." / text "..tostring(t.ui.text))
   assert(recap.payout.BackgroundColor3==t.ui.raised)
   -- Deck style tab hit frames are 44 in panel units; the regular screen scales as a whole (UIScale).
   for _,tab in pairs(picker.tabs)do assert(tab.Size.Y.Offset>=44);fit(tab)end
   assert(picker.tabs.Background:GetAttribute("AccessibleLabel")=="Background patterns")
   assert(not Art.applyTheme(plate),"unchanged confirmed theme reapplied registry")
  end)
 end
 end)
 for _,close in ipairs(cleanup)do close()end;root:Destroy();Art.applyTheme(old or Themes.ById[Themes.Default])
 -- onClose callbacks are intentionally counted, not mistaken for appearance requests.
 assert(ok,err);return{passed=#cases,cases=cases}
end
