-- QA v735 H4: the Companions "How it works" set has a 4th card about Hatch eggs
-- (src/client/HowItWorks.lua, UICopy r3.help.companions.d). Pure copy and layout, then
-- the real overlay at phone and desktop sizes.
-- Run (Client): require(Client.ZZSpecs.CompanionsHatchCard)(Client)
return function(client)
 local How=require(client.HowItWorks);local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
 local RunService=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 How.close("fixture");local original
 local ok,problem=pcall(function()
  test("four cards; the last is Hatch eggs with the egg picture",function()
   local cards=How.cards("companions");assert(#cards==4,"cards "..#cards)
   local last=cards[4];assert(last.key=="d"and last.icon=="egg")
   assert(last.title==UICopy.get("r3.help.companions.d.title")and last.title==UICopy.get("r3.help.hatch.title"),"named like the machine")
   for _,word in ipairs({"Toys","finishes","colour","features","eggs"})do assert(string.find(last.line,word,1,true),"line names "..word)end
   assert(cards[1].key=="a"and cards[2].key=="b"and cards[3].key=="c","the first three cards are unchanged")
  end)
  test("layout: four across on a landscape phone and on desktop, inside the screen",function()
   local cards=How.cards("companions")
   for _,size in ipairs({Vector2.new(812,354),Vector2.new(844,390),Vector2.new(1280,720)})do
    local g=How.layout(size.X,size.Y,cards)
    assert(g.columns==4 and g.panelW<=size.X and g.panelH<=size.Y,tostring(size))
    assert(g.pad*2+g.cardW*4+g.gap*3<=g.panelW,"cards fit the panel "..tostring(size))
    assert(g.inner>=140,"readable card width "..g.inner)
    assert(g.cardH<=g.viewportH,"no scrolling needed at "..tostring(size).." card "..g.cardH.." viewport "..g.viewportH)
   end
   assert(How.layout(390,700,cards).columns==1,"portrait phones stack")
   -- Three-card sets keep their width.
   assert(How.layout(1280,720,How.cards("hatch")).panelW==820)
  end)
  test("the overlay shows Card_d with its full text at 812 x 354",function()
   assert(How.open("companions"));local root=How.panel().Parent;original=root.Size
   root.Size=UDim2.fromOffset(812,354);RunService.RenderStepped:Wait();How.build();task.wait(.2);RunService.RenderStepped:Wait()
   local panel=How.panel();local body=panel:FindFirstChild("Cards");local card=assert(body:FindFirstChild("Card_d"),"Card_d")
   local footer=panel:FindFirstChild("GotIt")
   assert(card.AbsolutePosition.Y+card.AbsoluteSize.Y<=footer.AbsolutePosition.Y,"the card clears the footer")
   assert(card.AbsolutePosition.X+card.AbsoluteSize.X<=panel.AbsolutePosition.X+panel.AbsoluteSize.X,"inside the panel")
   for _,name in ipairs({"CardTitle","CardLine"})do
    local label=assert(card:FindFirstChild(name),name)
    assert(label.TextSize>=12 and label.TextTruncate==Enum.TextTruncate.None and label.TextBounds.Y<=label.AbsoluteSize.Y+2,name.." fits")
   end
   assert(card:FindFirstChild("Picture"),"the egg picture")
   How.close("fixture")
  end)
 end)
 How.close("fixture")
 local gui=game.Players.LocalPlayer.PlayerGui:FindFirstChild("EggDropHowItWorks");if gui and original then gui.Root.Size=original end
 assert(ok,problem);return cases
end
