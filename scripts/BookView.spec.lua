-- Studio Client. Collection book (play-forever F2, BookView): pure page / milestone /
-- Records rules, then the built screen at 1920 x 1080 and the 812 x 354 phone sheet
-- from fake snapshots with five pages (Bear only) and six (Pets joined): every page
-- opens, the list and pane fit (phones: under y 60), no text under 12 px, nothing
-- Selectable, the claim states (reached, claimed, not reached, pending, Retrying, the
-- Retrying timeout, a saved claim), the Records rows and the controller routes
-- (LB / RB pages, right onto the milestones, A claims, B backs out). No remote fires:
-- `send` is a recorder. The live peek source is saved and put back.
-- Usage: require(PlayerScripts.Client.ZZSpecs.BookView)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local View=require(client.BookView)
 local Peek=require(client.PetPeek)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Book=require(Shared.BookCatalog)
 local UICopy=require(Shared.UICopy)
 local Run=game:GetService("RunService")
 local K=Enum.KeyCode
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_BookViewSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local savedSource=Peek.getSource()
 local savedTimeout=View.PendingTimeout
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end

 -- Fake snapshot pages. claimed: {[pct] = true}.
 local function page(id,percent,claimed,ownedCount)
  local items=Book.Pages[id]and Book.Pages[id].items or {}
  local ownedIds={}
  for i=1,math.min(ownedCount or 0,#items)do table.insert(ownedIds,items[i].id)end
  local ms={}
  for _,pct in ipairs(Book.Steps)do
   table.insert(ms,{id=id.."."..pct,percent=pct,reward=Book.Rewards[pct],claimed=(claimed or {})[pct]==true,reached=percent>=pct})
  end
  return{id=id,name=({balls="Balls",faceplates="Faceplates",wardrobe="Wardrobe",toys="Toys",pets="Pets",discoveries="Discoveries"})[id],
   owned=#ownedIds,total=#items,percent=percent,ownedIds=ownedIds,milestones=ms}
 end
 local function snapshot(withPets)
  local pages={page("balls",50,{[25]=true},2),page("faceplates",100,{[25]=true,[50]=true,[75]=true,[100]=true},8),page("wardrobe",0,nil,0),
   page("toys",75,{[25]=true,[50]=true},3)}
  if withPets then table.insert(pages,page("pets",100,nil,2))end
  table.insert(pages,page("discoveries",30,nil,4))
  local claimed,claimable={},{}
  for _,p in ipairs(pages)do for _,m in ipairs(p.milestones)do
   if m.claimed then table.insert(claimed,m.id)elseif m.reached then table.insert(claimable,m.id)end
  end end
  return{book={pages=pages,claimed=claimed,claimable=claimable,found=0,faceplate="bookworm",faceplateEarned=false},
   stats={rounds=42,winsEasy=10,winsMedium=7,winsHard=2,tidyWins=5,merges=1200,bestChain=6,tierFive=3,itemsUsed=9,pets=1,starsEarned=1280,starsSpent=300,mystery=4},
   stamps=12,wallet=128,revision=7}
 end
 local function visibleIn(object,root)
  local node=object
  while node and node~=root do
   if node:IsA("GuiObject")and not node.Visible then return false end
   if node:IsA("ScreenGui")then break end
   node=node.Parent
  end
  return true
 end
 local function inside(a,b,slack)
  slack=slack or 1
  local ap,as,bp,bs=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
  return ap.X>=bp.X-slack and ap.Y>=bp.Y-slack and ap.X+as.X<=bp.X+bs.X+slack and ap.Y+as.Y<=bp.Y+bs.Y+slack
 end
 local function audit(view,label)
  for _,node in ipairs(view.root:GetDescendants())do
   if node:IsA("GuiObject")then
    assert(not node.Selectable,label..": Selectable leak "..node:GetFullName())
    if(node:IsA("TextLabel")or node:IsA("TextButton"))and node.Text~=""and visibleIn(node,view.root)then
     assert(node.TextSize>=12,label..": text under 12 px "..node:GetFullName().." ("..node.TextSize..")")
    end
   end
  end
 end

 local ok,problem=xpcall(function()
  Peek.setSource(nil)
  test("pure: entries follow the snapshot (5 or 6 pages) and end with Records",function()
   local five=View.pageEntries(snapshot(false).book);local six=View.pageEntries(snapshot(true).book)
   assert(#five==6 and five[6].id==View.RecordsId and five[6].records)
   assert(#six==7 and six[5].id=="pets"and six[7].id==View.RecordsId)
   assert(#View.pageEntries(nil)==1,"no book yet: Records only")
  end)
  test("pure: milestone states and looks (claimed, claim, locked, pending, retrying, failed)",function()
   local m={id="balls.50",percent=50,reward=5,reached=true,claimed=false}
   assert(View.milestoneState(m)=="claim")
   assert(View.milestoneState({id="x",percent=75,reached=false})=="locked")
   assert(View.milestoneState({id="x",percent=25,reached=true,claimed=true})=="claimed")
   assert(View.milestoneState(m,nil,nil,{["balls.50"]=true})=="claimed","a saved claim counts before the snapshot")
   assert(View.milestoneState(m,{milestoneId="balls.50"})=="pending")
   assert(View.milestoneState(m,{milestoneId="balls.50",retrying=true})=="retrying")
   assert(View.milestoneState(m,nil,{["balls.50"]="x"})=="failed")
   assert(View.milestoneLook(m,"claim").text==UICopy.get("book.claim",{reward=5})and View.milestoneLook(m,"claim").enabled)
   assert(not View.milestoneLook(m,"pending").enabled and View.milestoneLook(m,"retrying").text==UICopy.get("book.retrying"))
   assert(View.milestoneLook(m,"locked").kind=="chip"and View.milestoneLook(m,"claimed").kind=="chip")
   assert(View.claimableCount(snapshot(false).book.pages[1])==1 and View.claimableCount(snapshot(false).book.pages[1],{["balls.50"]=true})==0)
  end)
  test("pure: Records rows in order, unknown keys and parkGames left out, stamps last",function()
   local rows=View.statsRows({rounds=3,parkGames=9,mystery=1,starsEarned=1280},12)
   assert(#rows==3 and rows[1].key=="rounds"and rows[2].key=="starsEarned"and rows[2].value=="1,280"and rows[3].key=="stamps")
   assert(rows[1].label==UICopy.get("book.stats.rounds"))
   assert(#View.statsRows(nil,nil)==0)
  end)
  test("pure: Bookworm counts pages claimed at 100%; items mark what is owned",function()
   assert(View.bookworm({claimed={"balls.100","toys.100","toys.50"}}).count==2)
   local w=View.bookworm({claimed={"balls.100","toys.100","faceplates.100"},faceplateEarned=true});assert(w.count==3 and w.earned)
   local items=View.items("balls",{Book.Pages.balls.items[1].id})
   assert(#items==#Book.Pages.balls.items and items[1].owned and(items[2]==nil or not items[2].owned))
   assert(View.stepPage(1,-1,6)==1 and View.stepPage(6,1,6)==6 and View.stepPage(2,1,6)==3)
  end)
  for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354)})do
   for _,withPets in ipairs({false,true})do
    test(tostring(size)..(if withPets then " six pages"else " five pages")..": every page opens, fits, 12 px floor, nothing Selectable",function()
     local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
     local view=View.new(host,{send=function()end})
     local snap=snapshot(withPets)
     assert(view:open(snap));settle()
     local phone=view.view~=nil
     assert(phone==(size.X<1000),"phone layout at 812 x 354 only")
     local entries=View.pageEntries(snap.book)
     assert(#view.tiles==#entries,"one tile per page plus Records")
     assert(view.root:GetAttribute("OpenPage")=="balls","opens on the first page with a claim waiting")
     for index,entry in ipairs(entries)do
      view:openPage(index,true);settle()
      assert(view.root:GetAttribute("OpenPage")==entry.id)
      assert(inside(view.pane,view.root),"pane outside the panel on "..entry.id)
      if not phone then for _,tile in ipairs(view.tiles)do assert(inside(tile.button,view.root),"tile outside the panel")end end
      if phone then
       local top=view.root.AbsolutePosition.Y
       assert(view.pane.AbsolutePosition.Y>=top+60 and view.pageList.AbsolutePosition.Y>=top+60,"phone sheet content above y 60")
       for _,cell in ipairs(view.cells)do if cell.holder.Visible then assert(cell.holder.AbsoluteSize.Y>=44,"phone cell under 44 px")end end
       for _,tile in ipairs(view.tiles)do assert(tile.button.AbsoluteSize.Y>=44,"page tile under 44 px")end
      end
      if not entry.records then
       for _,cell in ipairs(view.cells)do assert(cell.holder.Visible and inside(cell.holder,view.pane),"milestone cell outside the pane")end
       assert(#view.grid:GetChildren()>0 or entry.total==0,"no items on "..entry.id)
      else
       assert(view.root:GetAttribute("RecordRows")==13,"Records shows the 12 counters and stamps")
       assert(view.grid:FindFirstChild("Stat_rounds")and not view.grid:FindFirstChild("Stat_mystery")and not view.grid:FindFirstChild("Stat_parkGames"))
      end
      audit(view,tostring(size).." "..entry.id)
     end
     view:destroy();host:Destroy()
    end)
   end
  end
  test("claim states: reached, claimed, not reached, pending, Retrying, timeout, saved",function()
   View.PendingTimeout=.25
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(1920,1080);host.Parent=gui
   local sent,claimed={},{}
   local view=View.new(host,{send=function(action,payload)table.insert(sent,{action,payload})end,claimed=function(message)table.insert(claimed,message)end})
   assert(view:open(snapshot(false),{page="balls"}));settle()
   local function cellState(i)return view.cells[i].holder:GetAttribute("State")end
   assert(cellState(1)=="claimed"and cellState(2)=="claim"and cellState(3)=="locked"and cellState(4)=="locked")
   assert(view.cells[2].button.Visible and view.cells[2].button.Interactable and not view.cells[3].button.Visible)
   -- Right lands on the first claim waiting; A claims it with the shown reward.
   view:input(K.Right);assert(view.root:GetAttribute("Zone")=="milestones"and view.root:GetAttribute("FocusedMilestone")==2)
   view:input(K.ButtonA)
   assert(#sent==1 and sent[1][1]=="bookClaim"and sent[1][2].milestoneId=="balls.50"and sent[1][2].reward==5 and type(sent[1][2].id)=="string")
   assert(cellState(2)=="pending"and not view.cells[2].button.Interactable)
   view:input(K.ButtonA);assert(#sent==1,"one claim in flight at a time")
   assert(not view:result({kind="book",id="someone-else",status="Saved"}),"a stranger's reply is ignored")
   assert(view:result({kind="book",id=sent[1][2].id,status="Retrying"}));assert(cellState(2)=="retrying"and view.status.Visible)
   task.wait(.4)
   assert(cellState(2)=="failed"and view.cells[2].button.Interactable and view.status.Text==UICopy.get("book.timeout"),"a Retrying claim times out and can be tried again")
   view:input(K.ButtonA);assert(#sent==2 and sent[2][2].id~=sent[1][2].id,"a retry is a new op id")
   assert(view:result({kind="book",id=sent[2][2].id,status="Saved",reward=5}))
   assert(cellState(2)=="claimed"and #claimed==1 and claimed[1].reward==5)
   assert(view.tiles[1].button:GetAttribute("Claimable")==0,"the page tile drops its sticker after the claim")
   -- A rejected claim says why and keeps the button.
   view:openPage(4,true);settle()
   view:input(K.Left);view:input(K.Left);assert(view.root:GetAttribute("Zone")=="pages")
   view:input(K.ButtonA);assert(#sent==3 and sent[3][2].milestoneId=="toys.75")
   assert(view:result({kind="book",id=sent[3][2].id,status="Rejected",reason="Busy"}))
   assert(view.cells[3].holder:GetAttribute("State")=="failed"and view.status.Text==UICopy.get("shop.reason.busy"))
   -- A snapshot that shows the claim keeps it claimed and clears the local mark.
   local after=snapshot(false);after.book.pages[1].milestones[2].claimed=true;table.insert(after.book.claimed,"balls.50")
   view:setContext(after);assert(view.localClaimed["balls.50"]==nil)
   view:destroy();host:Destroy()
   View.PendingTimeout=savedTimeout
  end)
  test("controller: LB / RB and up / down change page, left returns to the list, B backs out",function()
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(1920,1080);host.Parent=gui
   local backs=0
   local view=View.new(host,{send=function()end,back=function()backs+=1 end})
   view:open(snapshot(true),{page="balls"});settle()
   view:input(K.ButtonR1);assert(view.root:GetAttribute("OpenPage")=="faceplates")
   assert(view.footer.Visible and view.root:GetAttribute("Bookworm")==1,"faceplates footer counts finished pages toward Bookworm")
   view:input(K.E);view:input(K.S);assert(view.root:GetAttribute("OpenPage")=="toys")
   view:input(K.ButtonL1);assert(view.root:GetAttribute("OpenPage")=="wardrobe")
   view:input(K.D);assert(view.root:GetAttribute("Zone")=="milestones")
   view:input(K.Left);assert(view.root:GetAttribute("Zone")=="pages")
   for _=1,10 do view:input(K.DPadDown)end
   assert(view.root:GetAttribute("OpenPage")==View.RecordsId,"down clamps on Records")
   view:input(K.Right);assert(view.root:GetAttribute("Zone")=="pages","Records has no milestones")
   assert(not view:act(),"A on Records does nothing")
   view:input(K.ButtonB);assert(not view:isOpen()and backs==1)
   view:destroy();host:Destroy()
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 View.PendingTimeout=savedTimeout
 Peek.setSource(savedSource)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
