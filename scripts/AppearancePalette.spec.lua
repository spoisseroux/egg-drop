-- Actual widgets in a real LocalScript/ScreenGui. Optional root limits native deadline.
return function(client,parent,onlySize)
 local Art=require(client.DeckArt);local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
 local Menu=require(client.DeckMenu);local Picker=require(client.DeckPicker);local Journal=require(client.PetJournal)
 local Shop=require(client.EggHatchView);local Recap=require(client.RoundRecap);local Focus=require(client.PetFocusUI)
 local old=Art.getTheme();local defaults={Art.Surface,Art.Ink,Art.Silver,Art.Focus};local cases,cleanup={},{}
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent
 local audio={play=function()end};local writes=0
 local function outgoing()writes+=1 end
 local function test(n,f)f();table.insert(cases,n)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function fit(n)assert(n.TextFits,n:GetFullName().." "..n.Text.." "..tostring(n.AbsoluteSize).." "..tostring(n.TextBounds))end
 local function channel(c)local function v(x)return if x<=.04045 then x/12.92 else ((x+.055)/1.055)^2.4 end;return .2126*v(c.R)+.7152*v(c.G)+.0722*v(c.B)end
 local function contrast(a,b)a,b=channel(a),channel(b);return(math.max(a,b)+.05)/(math.min(a,b)+.05)end
 local function result(seq)return{sequence=seq,status="Saved",success=true,stage=2,reason="Completed",award=8,daily=0,balance=10,recipe=game.ReplicatedStorage.Shared.EggCatalog and require(game.ReplicatedStorage.Shared.EggCatalog).ById.meadow,reward={sequence=seq,total=8,base=8,daily=0,family="pip",masteryPoints=1,promotedTo=0,contracts={}}}end
 local ok,err=pcall(function()
 test("all8 palettes keep body supporting and LCD ink readable",function()
  for _,id in ipairs(Themes.Order)do local t=Themes.ById[id]
   for _,role in ipairs({"panel","raised","inset","selected"})do assert(contrast(t.ui.text,t.ui[role])>=4.5,id.." text contrast "..role)end
   assert(contrast(t.ui.muted,t.ui.raised)>=4.5 and contrast(Art.LCDInk,t.lcd.base)>=4.5,id.." supporting/LCD contrast")
  end
 end)
 for _,size in ipairs(if onlySize then {onlySize}else {Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
  root.Size=UDim2.fromOffset(size.X,size.Y);settle()
  local menu=Menu.new(root,{});local picker=Picker.new(root,nil,nil,outgoing,outgoing,outgoing,outgoing)
  local journal=Journal.new(root,nil,nil,outgoing,outgoing,outgoing);local shop=Shop.new(root,audio,function()return true end,outgoing)
  local recap=Recap.new(root,audio,true);local focus=Focus.new(parent,{})
  for _,v in ipairs({menu,picker,journal,shop})do table.insert(cleanup,function()v:close();v.shade:Destroy()end)end
  table.insert(cleanup,function()recap.frame:Destroy()end);table.insert(cleanup,function()focus:destroy()end)
  menu:update({status="Ready",nectar=24,inventoryMask=1,dailyAvailable=false},"pip","pip",0,0,0,"meadow");menu:open();menu:setPage("mastery")
  picker:updateClub(1,0,0,0,"On",false,false,1,true,0,{pip=0});picker:open("sherbet","none")
  journal:open(1,0,"pip",false,nil,1,{pip=0});shop:open({status="Ready",revision=4,nectar=24,inventoryMask=1});shop:selectRecipe("sprout")
  recap.frame.Visible=true;recap.layoutWidth=size.X;recap:updateField(result(9))
  focus.panel.Visible=true;focus.back.Visible=true;focus.helper.Visible=true
  test(tostring(size).." open sheets adopt each palette without identity/focus/receipt changes",function()
   local recipe=shop.body.EggColumn.Recipe_sprout;local pending=shop.pending;local receipt=recap.receiptSignature
   local amber=shop.nectar.TextColor3
   for _,id in ipairs(Themes.Order)do
    local t=Themes.ById[id];Art.applyTheme(t);settle()
    assert(menu.card.BackgroundColor3==t.ui.panel and menu.tabs.mastery.BackgroundColor3==t.ui.selected and menu.tabs.mastery.TextColor3==t.ui.text)
    assert(picker.card.BackgroundColor3==t.ui.panel and picker.tabs.Shell.BackgroundColor3==t.ui.selected)
    assert(journal.card.BackgroundColor3==t.ui.panel and journal.cards[1].BackgroundColor3==t.ui.raised and journal.cards[1].Species.TextColor3==t.ui.text)
    assert(shop.card.BackgroundColor3==t.ui.panel and recipe.BackgroundColor3==t.ui.selected and recipe.RecipeName.TextColor3==t.ui.text)
    assert(recap.eggPanel.BackgroundColor3==t.ui.inset and recap.detailsButton.TextColor3==t.ui.text and recap.receiptSignature==receipt)
    assert(focus.back.BackgroundColor3==t.ui.panel and focus.helper.BackgroundColor3==t.ui.panel and focus.helper.TextColor3==t.ui.text)
    assert(shop.selected=="sprout"and shop.pending==pending and shop.body.EggColumn.Recipe_sprout==recipe and shop.nectar.TextColor3==amber)
    assert(Art.Surface==defaults[1]and Art.Ink==defaults[2]and Art.Silver==defaults[3]and Art.Focus==defaults[4],"public art constants changed")
   end
  end)
  test(tostring(size).." newly rebuilt recipe and receipt rows inherit active palette",function()
   local t=Themes.ById.copperleaf;Art.applyTheme(t);local recipe=shop.body.EggColumn.Recipe_sprout
   local before=shop.body.CanvasPosition;shop:layout();shop:renderBody();recap:updateField(result(10));settle()
   assert(shop.body.EggColumn.Recipe_sprout==recipe and recipe.RecipeName.TextColor3==t.ui.text and shop.selected=="sprout")
   for _,row in ipairs(recap.receiptRows)do if not row.Text:find("unlocked!",1,true)then assert(row.TextColor3==t.ui.text)end end
   for _,tab in pairs(picker.tabs)do assert(tab.AbsoluteSize.Y>=44);fit(tab)end
   assert(picker.tabs.Background:GetAttribute("AccessibleLabel")=="Background patterns")
   assert(not Art.applyTheme(t),"unchanged confirmed theme reapplied registry")
  end)
 end
 end)
 for _,close in ipairs(cleanup)do close()end;root:Destroy();Art.applyTheme(old or Themes.ById[Themes.Default])
 -- onClose callbacks are intentionally counted, not mistaken for appearance requests.
 assert(ok,err);return{passed=#cases,cases=cases}
end
