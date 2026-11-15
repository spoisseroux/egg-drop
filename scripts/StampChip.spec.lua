-- QA v685 R10: the daily stamp chip on the Hatch eggs header (src/client/StampChip.lua).
-- Pure model and placement, then the chip built on a real Kit.header at phone and
-- desktop widths. The stamp card itself stays in Quests (StampCardView specs).
-- Run (Client): require(Client.ZZSpecs.StampChip)(Client)
return function(client,parent)
 local Chip=require(client.StampChip);local Kit=require(client.DeckKit)
 local UICopy=require(game.ReplicatedStorage.Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_StampChipSpec";gui.ResetOnSpawn=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 gui.Parent=parent or game.Players.LocalPlayer:WaitForChild("PlayerGui")
 local host=Instance.new("Frame");host.Size=UDim2.fromOffset(900,200);host.BackgroundTransparency=1;host.Parent=gui
 local ok,problem=pcall(function()
  test("the count: n/7 while today's stamp waits, a check once it is on the card",function()
   local m=Chip.model({stamps=3,dailyAvailable=true});assert(not m.done and m.count==3 and m.total==7 and m.text=="3/7",m.text)
   m=Chip.model({stamps=4,dailyAvailable=false});assert(m.done and m.count==4 and m.text=="✓ 4/7",m.text)
   -- The 7th stamp today: the card reads full until tomorrow, then starts again at 0.
   m=Chip.model({stamps=7,dailyAvailable=false});assert(m.done and m.count==7 and m.text=="✓ 7/7",m.text)
   m=Chip.model({stamps=7,dailyAvailable=true});assert(not m.done and m.count==0 and m.text=="0/7",m.text)
   m=Chip.model({stamps=0,dailyAvailable=false});assert(m.done and m.count==0 and m.text=="0/7",m.text)
   for _,bad in ipairs({false,{},{stamps=-1},{stamps="x",dailyAvailable=1}})do m=Chip.model(bad);assert(m.done and m.count==0 and m.total==7)end
   assert(UICopy.has("stampChip.done")and UICopy.has("stampChip.open")and UICopy.has("stampChip.label"))
  end)
  test("placement: left of the header's controls, or hidden when the title would not fit",function()
   for _,compact in ipairs({false,true})do
    for _,help in ipairs({true,false})do
     local g=Kit.headerGeometry(848,compact,96,24,help)
     local r=assert(Chip.place(g,64,24,140))
     local anchor=g.help or g.wallet
     assert(r.x+r.w==anchor.x-Chip.Gap and r.h==g.controlH and r.y==g.centerY-g.controlH/2)
     assert(r.x-Chip.TitleGap>=24+140)
    end
   end
   local narrow=Kit.headerGeometry(320,true,96,24,true)
   assert(Chip.place(narrow,64,24,140)==nil,"a 320 px header has no room")
  end)
  for _,case in ipairs({{848,false},{700,true}})do
   test(case[1].." px header: the chip shows, stays clear of the title and the wallet, and follows the state",function()
    local header=Kit.header(host,{title="Hatch eggs",eyebrow="Garden",tint="hatch",compact=case[2],width=case[1],left=24})
    local opened=0
    local chip=Chip.new(header,{compact=case[2],onOpen=function()opened+=1 end})
    assert(not chip.button.Visible and not chip.button.Selectable,"hidden until it has a state; never in the controller order")
    if header.wallet then header.wallet.set(12)end
    chip:set({stamps=2,dailyAvailable=true})
    local b=chip.button
    assert(b.Visible and chip.label.Text=="2/7"and chip.dot.Visible and b:GetAttribute("StampDone")==false and b:GetAttribute("StampCount")==2)
    local g=header.geometry;local anchor=g.help or g.wallet or g.back
    local x,w=b.Position.X.Offset,b.Size.X.Offset
    assert(x+w<=anchor.x-Chip.Gap+1e-3 and b.Size.Y.Offset>=36,"chip overlaps the header controls or is too small to tap")
    local title=header.title
    assert(title.Position.X.Offset+title.Size.X.Offset<=x-Chip.TitleGap+1e-3,"the title runs under the chip")
    assert(title.Size.X.Offset>=Kit.measure(title.Text,"Title",title.TextSize).X-1,"the title was squeezed")
    chip:set({stamps=3,dailyAvailable=false})
    assert(chip.label.Text=="✓ 3/7"and not chip.dot.Visible and b:GetAttribute("StampDone")==true)
    -- A wallet change re-lays the header out (the title's box resets): the chip is set after it.
    if header.wallet then header.wallet.set(123456)end
    chip:set({stamps=3,dailyAvailable=false})
    g=header.geometry;anchor=g.help or g.wallet or g.back
    assert(b.Position.X.Offset+b.Size.X.Offset<=anchor.x-Chip.Gap+1e-3 and header.title.Position.X.Offset+header.title.Size.X.Offset<=b.Position.X.Offset-Chip.TitleGap+1e-3)
    -- A long title (a save notice) takes the room back: the chip hides rather than cover it.
    header.setTitle(string.rep("Saving your garden ",6));chip:set({stamps=3,dailyAvailable=false})
    assert(not b.Visible,"the chip covered a long title")
    assert(opened==0)
    chip:destroy();header.root:Destroy()
   end)
  end
 end)
 gui:Destroy();assert(ok,problem);return cases
end
