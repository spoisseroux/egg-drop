-- Studio Client. Stamp card (play-forever F2, StampCardView): the pure card model
-- (stamps on this card, the slot the next stamp lands in with its reward, the 7th the
-- bigger gift, a card finished today stays full until tomorrow), the built card at a
-- regular and a compact width (seven slots inside, 12 px text floor, nothing
-- Selectable) and the landing (boing + "+N Stars" pop; Reduced Motion cuts the boing
-- and the pop's rise). No remote fires: the card only reads snapshots.
-- Usage: require(PlayerScripts.Client.ZZSpecs.StampCardView)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local View=require(client.StampCardView)
 local Kit=require(client.DeckKit)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Stamp=require(Shared.StampCard)
 local UICopy=require(Shared.UICopy)
 local Run=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_StampCardViewSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local realReduced=Kit.reduced
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 -- A snapshot as the server publishes it (HatchProgress.public).
 local function snap(stamps,available)
  return{stamps=stamps,dailyAvailable=available,dailyBonus=Stamp.reward(stamps),
   stampCard={rewards=table.clone(Stamp.Rewards),onCard=Stamp.onCard(stamps),next=Stamp.position(stamps)}}
 end
 local function inside(a,b)
  local ap,as,bp,bs=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
  return ap.X>=bp.X-1 and ap.Y>=bp.Y-1 and ap.X+as.X<=bp.X+bs.X+1 and ap.Y+as.Y<=bp.Y+bs.Y+1
 end
 local ok,problem=xpcall(function()
  test("pure: stamps on the card, the next slot and its reward, the 7th is the bigger gift",function()
   local m=View.model(snap(0,true));assert(m.filled==0 and m.nextIndex==1 and m.reward==4 and m.available and not m.full)
   m=View.model(snap(6,true));assert(m.filled==6 and m.nextIndex==7 and m.reward==12)
   local slots=View.slots(m)
   assert(#slots==7 and slots[7].big and slots[7].today and slots[7].reward==12 and slots[6].filled and not slots[7].filled)
   for i=1,6 do assert(not slots[i].big)end
   m=View.model(snap(3,false));assert(m.filled==3 and m.nextIndex==4 and not View.slots(m)[4].today and View.slots(m)[4].next)
   assert(View.line(m)==UICopy.get("stamp.tomorrow",{reward=5}))
   assert(View.line(View.model(snap(2,true)))==UICopy.get("stamp.next",{reward=5}))
  end)
  test("pure: today's stamp finishing the card keeps it full until tomorrow; then a fresh card",function()
   local m=View.model(snap(7,false));assert(m.full and m.filled==7 and View.line(m)==UICopy.get("stamp.full"))
   m=View.model(snap(7,true));assert(not m.full and m.filled==0 and m.nextIndex==1 and m.reward==4)
   m=View.model(snap(0,false));assert(not m.full and m.filled==0,"a fresh save whose load day counts as claimed has an empty card")
   assert(View.buttonText(snap(6,true))==UICopy.get("stamp.button",{reward=12})and View.buttonText(snap(6,false))==UICopy.get("stamp.done"))
   -- Fallbacks: a snapshot without stampCard still reads from the stamp count.
   m=View.model({stamps=9,dailyAvailable=true});assert(m.filled==2 and m.reward==5)
   assert(View.model(nil).filled==0)
  end)
  for _,case in ipairs({{320,false},{226,true},{520,false}})do
   test(string.format("built at %d px (%s): seven slots inside, text floor, nothing Selectable",case[1],if case[2]then "compact"else "regular"),function()
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(600,200);host.Parent=gui
    local card=View.new(host)
    local h=card:layout(case[1],case[2]);card:set(snap(6,true));settle()
    assert(h==View.height(case[2])and card.root.AbsoluteSize.Y==h and card.root.AbsoluteSize.X==case[1])
    for i,slot in ipairs(card.slotViews)do
     assert(inside(slot.frame,card.root),"slot "..i.." outside the card")
     assert(slot.frame:GetAttribute("Filled")==(i<=6))
    end
    assert(card.slotViews[7].frame:GetAttribute("Big")and card.slotViews[7].frame:GetAttribute("Today")and card.slotViews[7].stroke.Color==Kit.Color.stars)
    assert(card.slotViews[7].reward.Text=="+12"and card.slotViews[7].reward.TextColor3==Kit.Color.stars)
    assert(card.slotViews[1].mark.Visible and not card.slotViews[1].reward.Visible)
    for _,node in ipairs(card.root:GetDescendants())do
     if node:IsA("GuiObject")then assert(not node.Selectable,"Selectable "..node:GetFullName())end
     if node:IsA("TextLabel")and node.Visible and node.Text~=""then assert(node.TextSize>=12,"text under 12 px: "..node:GetFullName())end
    end
    -- The promise shows only when it fits whole.
    if card.promise.Visible then assert(Kit.measure(card.promise.Text,"Small",card.promise.TextSize).X<=card.promise.Size.X.Offset+1)end
    card:destroy();host:Destroy()
   end)
  end
  test("a claim lands the stamp: boing and a +N Stars pop",function()
   Kit.reduced=function()return false end
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(400,200);host.Parent=gui
   local card=View.new(host);card:layout(320,false)
   assert(not card:set(snap(2,true)),"the first snapshot never lands a stamp")
   assert(card:set(snap(3,false)),"one more stamp lands")
   assert(card.root:GetAttribute("LandedSlot")==3 and card.pop.Visible and card.pop.Text==UICopy.get("stamp.landed",{reward=5}))
   assert(card.slotViews[3].frame:FindFirstChild("BoingScale"),"the landed slot boings")
   assert(not card:set(snap(3,false)),"the same count again does not land twice")
   -- The 7th: the card shows full and the 12 Star gift pops.
   card:set(snap(6,true));assert(card:set(snap(7,false))and card.root:GetAttribute("LandedSlot")==7 and card.pop.Text==UICopy.get("stamp.landed",{reward=12}))
   task.wait(View.PopSeconds+.5);assert(not card.pop.Visible,"the pop goes away")
   card:destroy();host:Destroy()
   Kit.reduced=realReduced
  end)
  test("Reduced Motion: no boing, the pop shows in place and hides",function()
   Kit.reduced=function()return true end
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(400,200);host.Parent=gui
   local card=View.new(host);card:layout(320,false)
   card:set(snap(4,true));assert(card:set(snap(5,false)))
   assert(card.slotViews[5].frame:FindFirstChild("BoingScale")==nil,"no boing under Reduced Motion")
   local at=card.pop.Position;settle();assert(card.pop.Visible and card.pop.Position==at,"the pop does not rise")
   task.wait(View.PopSeconds+.2);assert(not card.pop.Visible)
   card:destroy();host:Destroy()
   Kit.reduced=realReduced
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 Kit.reduced=realReduced
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
