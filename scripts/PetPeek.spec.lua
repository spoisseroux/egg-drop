-- Studio Client. UI personality T4 pet peek (PetPeek) and the T9 / T12 rules that
-- ride on it: the clip never overlaps a wallet, nothing is focusable, phones get
-- no peek, one cached ViewportFrame moves between hosts, a shown peek creates no
-- instances per frame, a slot under 64 px hides it, no pet means no peek, the
-- Star face hides past 40 degrees of yaw, and the empty-state lines fill the pet.
-- The live session's peek source is saved and put back at the end.
-- Usage: require(PlayerScripts.Client.ZZSpecs.PetPeek)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Peek=require(client.PetPeek)
 local Kit=require(client.DeckKit)
 local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
 local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
 local RunService=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local savedSource=Peek.getSource()
 local gui=Instance.new("ScreenGui");gui.Name="_PetPeekSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local petId=Pets.collection[1].id
 local function frames(n)for _=1,n do RunService.RenderStepped:Wait()end end
 local function host(name,w,h)
  local f=Instance.new("Frame");f.Name=name;f.BackgroundTransparency=1;f.Size=UDim2.fromOffset(w,h);f.Parent=gui;return f
 end
 local function absRect(object)
  return{x=object.AbsolutePosition.X,y=object.AbsolutePosition.Y,w=object.AbsoluteSize.X,h=object.AbsoluteSize.Y}
 end
 local ok,problem=xpcall(function()
  Peek._reset()
  Peek.setSource(function()return petId,{}end)
  test("pure: the clip never overlaps a wallet rect (cut right, left or top; the edge stays)",function()
   local wallet={x=300,y=10,w=110,h=44}
   local rng=Random.new(7)
   for _=1,400 do
    local slot={x=rng:NextInteger(150,420),y=rng:NextInteger(0,60),w=rng:NextInteger(40,220),h=rng:NextInteger(40,120)}
    local r=Peek.clip(slot,{wallet},6)
    if r.w>0 and r.h>0 then
     assert(not Peek.overlaps(r,{x=wallet.x-6,y=wallet.y-6,w=wallet.w+12,h=wallet.h+12}),"clip overlaps the wallet")
     assert(r.y+r.h==slot.y+slot.h,"the bottom edge (the edge the pet peeks over) never moves")
     assert(r.x>=slot.x and r.x+r.w<=slot.x+slot.w and r.y>=slot.y,"the clip stays inside the slot")
    end
   end
   local DeckResults=require(client.DeckResults);local style=require(client.FaceplateShop)
   local g=Kit.headerGeometry(848,false,140,24)
   assert(not Peek.overlaps(Peek.clip(style.PeekSlot,{g.wallet},6),g.wallet),"Deck style slot clears the header wallet")
   local resultsWallet={x=824-140,y=16,w=140,h=40}
   assert(not Peek.overlaps(Peek.clip(DeckResults.PeekSlot,{resultsWallet},6),resultsWallet),"results slot clears the wallet")
   assert(not Peek.overlaps(Peek.clip(DeckResults.PeekSlotMiss,{resultsWallet},6),resultsWallet),"results miss slot clears the wallet")
   assert(Peek.fits(Peek.clip(DeckResults.PeekSlotMiss,{resultsWallet},6)),"a 5 digit wallet still leaves the miss peek room")
  end)
  test("live: the shown clip keeps clear of a real Kit.wallet beside it",function()
   local h=host("WalletHost",400,120)
   local wallet=Kit.wallet(h,44);wallet.set(12345);wallet.root.Position=UDim2.fromOffset(200,4)
   frames(2)
   local w={x=200,y=4,w=wallet.root.Size.X.Offset,h=44}
   assert(Peek.show(h,{rect={x=120,y=0,w=200,h=110},avoid={w},align="right"}),"shown")
   frames(2)
   local clip=Peek.state.clip
   assert(not Peek.overlaps(absRect(clip),absRect(wallet.root)),"the clip covers the wallet")
   Peek.hide(h);h:Destroy()
  end)
  test("never focusable: no Selectable, Active or Interactable GuiObject in the peek",function()
   local h=host("FocusHost",300,140)
   assert(Peek.show(h,{rect={x=0,y=0,w=200,h=120}}))
   local clip=Peek.state.clip
   for _,object in ipairs(clip:GetDescendants())do
    if object:IsA("GuiObject")then assert(not object.Selectable and not object.Active and not object.Interactable,object:GetFullName())end
   end
   assert(not clip.Selectable and not clip.Active and not clip.Interactable,"clip")
   Peek.hide(h);h:Destroy()
  end)
  test("phones and compact layouts get no peek (812 x 354 is compact)",function()
   assert(Kit.compactRule(812,354),"812 x 354 follows the compact rule")
   local h=host("PhoneHost",300,140)
   assert(Peek.show(h,{rect={x=0,y=0,w=200,h=120},compact=true})==false,"compact shows nothing")
   assert(not Peek.isShown()and(Peek.state.clip==nil or Peek.state.clip.Parent~=h),"clip not in the compact host")
   h:Destroy()
  end)
  test("one cached ViewportFrame moves between two hosts, never rebuilt",function()
   local a,b=host("HostA",300,140),host("HostB",300,140)
   assert(Peek.show(a,{rect={x=0,y=0,w=200,h=120}}))
   local viewport,builds=Peek.state.viewport,Peek.state.builds
   assert(viewport and viewport:IsDescendantOf(a))
   Peek.hide(a)
   assert(viewport.Parent and not viewport:IsDescendantOf(a),"hidden: out of the host")
   assert(Peek.show(b,{rect={x=40,y=10,w=180,h=110}}))
   assert(Peek.state.viewport==viewport and Peek.state.builds==builds,"same viewport, no rebuild")
   assert(viewport:IsDescendantOf(b)and not viewport:IsDescendantOf(a))
   assert(Peek.show(a,{rect={x=0,y=0,w=200,h=120}})and Peek.state.viewport==viewport and viewport:IsDescendantOf(a),"and back again")
   local count=0;for _,child in ipairs(gui:GetDescendants())do if child:GetAttribute("PetPeek")then count+=1 end end
   assert(count==1,"one peek per screen, found "..count)
   Peek.hide(a);a:Destroy();b:Destroy()
  end)
  test("a shown peek creates no instances per frame (60 frames) and pauses when hidden",function()
   local h=host("FrameHost",300,140)
   assert(Peek.show(h,{rect={x=0,y=0,w=200,h=120}}))
   assert(Peek.isSubscribed("PetPeek")==not game:GetService("GuiService").ReducedMotionEnabled,"the peek runs on the shared clock")
   -- Let the rig settle (an authored mesh may finish loading), then count.
   local last,stable=-1,0
   for _=1,300 do
    frames(1);local n=#h:GetDescendants()
    if n==last then stable+=1 else stable=0;last=n end
    if stable>=30 then break end
   end
   local before=#h:GetDescendants()
   frames(60)
   assert(#h:GetDescendants()==before,string.format("instances changed over 60 frames: %d -> %d",before,#h:GetDescendants()))
   Peek.hide(h)
   assert(not Peek.isSubscribed("PetPeek"),"hidden: off the clock")
   h:Destroy()
  end)
  test("hidden when the slot is under 64 px (alone or after the wallet cut)",function()
   local h=host("SlotHost",300,140)
   assert(Peek.show(h,{rect={x=0,y=0,w=200,h=63}})==false and not Peek.isShown(),"63 px hides")
   assert(Peek.show(h,{rect={x=0,y=0,w=200,h=64}})==true,"64 px shows")
   assert(Peek.show(h,{rect={x=0,y=0,w=200,h=100},avoid={{x=0,y=0,w=200,h=40}}})==false,"a wallet cut to 54 px hides it")
   assert(Peek.fits({w=48,h=64})and not Peek.fits({w=47,h=64})and not Peek.fits(nil))
   Peek.hide(h);h:Destroy()
  end)
  test("no pet (fresh save): no peek and the empty-state lines drop the pet",function()
   local h=host("NoPetHost",300,140)
   Peek.setSource(function()return nil end)
   assert(Peek.show(h,{rect={x=0,y=0,w=200,h=120}})==false and Peek.petName()==nil)
   Peek.setSource(nil)
   assert(Peek.show(h,{rect={x=0,y=0,w=200,h=120}})==false)
   local Wardrobe=require(client.WardrobeShop)
   assert(Wardrobe.emptyText("no_such_pet")==UICopy.get("wardrobe.emptySolo"))
   assert(Wardrobe.emptyText(petId)==UICopy.get("wardrobe.empty",{pet=Pets.byId[petId].name}))
   assert(Wardrobe.ownsNothing({owned={}})and Wardrobe.ownsNothing(nil)and not Wardrobe.ownsNothing({owned={"x"}}))
   assert(not string.find(UICopy.get("quests.allDone",{pet="Bear"}),"{",1,true))
   Peek.setSource(function()return petId,{}end)
   h:Destroy()
  end)
  test("Star face: hidden past 40 degrees of yaw, follows the front; plain wallet Star under 20 px",function()
   local Results=require(client.DeckResults)
   assert(Results.faceTurn(0)==0 and Results.faceTurn(40)==40 and Results.faceTurn(-40)==-40)
   assert(Results.faceTurn(41)==nil and Results.faceTurn(180)==nil and Results.faceTurn(-90)==nil)
   assert(Results.faceTurn(720+10)==10 and Results.faceTurn(355)==-5)
   local h=host("WalletFace",300,100)
   local big=Kit.wallet(h,44);local small=Kit.wallet(h,36)
   local function face(w)
    local star=w.root:FindFirstChild("Icon_star")
    return star and(star:FindFirstChild("StarEye")~=nil or star:FindFirstChild("StarFace")~=nil)
   end
   assert(face(big),"44 high wallet (22 px Star) has eyes")
   assert(not face(small),"36 high wallet (18 px Star) stays plain")
   local Assets=require(client.DeckAssets)
   if not Assets.Personality.starFace then
    for _,d in ipairs(h:GetDescendants())do assert(not(d:IsA("ImageLabel")and d.Name=="StarFace"),"a missing face id creates no ImageLabel")end
   end
   h:Destroy()
  end)
  test("a destroyed host takes nothing with it; session end stops everything",function()
   local h=host("DyingHost",300,140)
   assert(Peek.show(h,{rect={x=0,y=0,w=200,h=120}}))
   h:Destroy();frames(1)
   local other=host("NextHost",300,140)
   assert(Peek.show(other,{rect={x=0,y=0,w=200,h=120}}),"shows again after a host was destroyed")
   Peek.destroy()
   assert(not Peek.isSubscribed("PetPeek")and Peek.state.clip==nil)
   assert(Peek.show(other,{rect={x=0,y=0,w=200,h=120}})==false,"dead after session end")
   other:Destroy()
  end)
 end,debug.traceback)
 Peek._reset();Peek.setSource(savedSource)
 gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
