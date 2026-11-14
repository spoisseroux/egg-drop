-- Studio Client. The wallet's 3D Star (WalletStar via Kit.wallet): 3D from 16 px up (QA v2 R3.3),
-- the 2D Star below and when the mesh cannot be created (injected loader), a still
-- Star under Reduced Motion, one shared clock for every wallet, no instances made
-- per frame, nothing written while hidden, and the wallet rect (capsule, number,
-- Star rect) exactly as the 2D wallet's. The live loader and settings are restored.
-- Usage: require(PlayerScripts.Client.ZZSpecs.WalletStar)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Star=require(client.WalletStar)
 local Kit=require(client.DeckKit)
 local Peek=require(client.PetPeek)
 local RunService=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local savedLoader=Star.getLoader()
 local gui=Instance.new("ScreenGui");gui.Name="_WalletStarSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function frames(n)for _=1,n do RunService.RenderStepped:Wait()end end
 local function host(name,x)
  local f=Instance.new("Frame");f.Name=name;f.BackgroundTransparency=1;f.Position=UDim2.fromOffset(x or 0,0);f.Size=UDim2.fromOffset(300,100);f.Parent=gui;return f
 end
 local template=Instance.new("Part");template.Name="StarToken";template.Size=Vector3.new(100,97,45)
 local function good(callback)callback(template)end
 local function failing(callback)task.defer(callback,nil)end
 local ok,problem=xpcall(function()
  test("pure: sway keeps the face, the turn hides it past 40 degrees, the glint lands with the turn",function()
   local yaw,glint=Star.pose(0);assert(yaw==0 and glint==0)
   for t=0,Star.SwayTime,.1 do local y=Star.pose(t);assert(Star.faceTurn(y)~=nil,"face hidden during the sway at "..t)end
   yaw=Star.pose(Star.SwayTime+(Star.Cycle-Star.SwayTime)/2);assert(math.abs(yaw-180)<1 and Star.faceTurn(yaw)==nil)
   assert(select(2,Star.pose(Star.GlintTime/2))==.5 and select(2,Star.pose(2))==nil)
   assert(Star.faceTurn(40)==40 and Star.faceTurn(-40)==-40 and Star.faceTurn(41)==nil and Star.faceTurn(355)==-5)
  end)
  test("3D Star from 16 px up, so every header capsule (44 and the 36 compact one) is 3D; 2D below 16 px",function()
   Star.setLoader(good)
   local h=host("Sizes")
   local big=Kit.wallet(h,44);local compact=Kit.wallet(h,36);local deck=Kit.wallet(h,32);local small=Kit.wallet(h,26);local other=Kit.wallet(h,20)
   assert(Star.MinSize<=Kit.WalletSpec[36].star,"the compact header Star clears MinSize")
   assert(big.star3D.state=="3D","44 high wallet is 3D")
   assert(compact.star3D.state=="3D"and compact.root:FindFirstChild("Star3D"),"36 high (phone header) wallet is 3D")
   assert(deck.star3D.state=="3D","32 high deck wallet is 3D")
   local holder=big.root:FindFirstChild("Star3D")
   assert(holder and holder:FindFirstChild("StarViewport")and holder.StarViewport:FindFirstChildOfClass("Part"),"viewport with the Star")
   assert(holder.StarViewport.CurrentCamera~=nil and holder:FindFirstChild("StarFace3D"),"camera and eyes")
   assert(holder.StarViewport:FindFirstChildOfClass("Part").Size==require(game:GetService("ReplicatedStorage").Shared.EggModels).Star.size,"size set explicitly")
   assert(not big.star.Visible,"2D icon hidden under the 3D Star")
   assert(big.star:FindFirstChild("StarEye")or big.star:FindFirstChild("StarFace"),"P3 eyes kept on the fallback icon")
   for _,w in ipairs({small,other})do
    assert(w.star3D.state=="2D"and w.root:FindFirstChild("Star3D")==nil and w.star.Visible,"under 16 px stays 2D")
   end
   for _,d in ipairs(holder:GetDescendants())do
    if d:IsA("GuiObject")then assert(not d.Active and not d.Selectable,"3D Star never takes input: "..d.Name)end
   end
   h:Destroy()
  end)
  test("mesh failure keeps the 2D Star",function()
   Star.setLoader(failing)
   local h=host("Failure")
   local w=Kit.wallet(h,44);frames(2)
   assert(w.star3D.state=="2D"and w.root:FindFirstChild("Star3D")==nil and w.star.Visible)
   Star.setLoader(function(callback)callback(Instance.new("Folder"))end) -- not a part: build fails
   local broken=Kit.wallet(h,44)
   assert(broken.star3D.state=="2D"and broken.root:FindFirstChild("Star3D")==nil and broken.star.Visible,"a failed build leaves nothing behind")
   h:Destroy()
  end)
  test("wallet rect unchanged: capsule, number and Star rect match the 2D wallet",function()
   Star.setLoader(good);local a=host("RectA",0);local wa=Kit.wallet(a,44)
   Star.setLoader(failing);local b=host("RectB",0);b.Position=UDim2.fromOffset(0,0);local wb=Kit.wallet(b,44)
   b.Visible=false
   for _,value in ipairs({0,7,128,1280,99999})do
    wa.set(value);wb.set(value);frames(1)
    assert(wa.root.Size==wb.root.Size and wa.root.AbsoluteSize==wb.root.AbsoluteSize,"capsule size at "..value)
    assert(wa.amount.Position==wb.amount.Position and wa.amount.Size==wb.amount.Size and wa.amount.AbsolutePosition==wb.amount.AbsolutePosition-b.AbsolutePosition+a.AbsolutePosition,"number at "..value)
   end
   local holder=wa.root.Star3D
   assert(holder.AbsolutePosition==wb.star.AbsolutePosition-b.AbsolutePosition+a.AbsolutePosition and holder.AbsoluteSize==wb.star.AbsoluteSize,"Star rect")
   local at,size=wa.root.AbsolutePosition,wa.root.AbsoluteSize
   frames(60)
   assert(wa.root.AbsolutePosition==at and wa.root.AbsoluteSize==size,"capsule moved while spinning")
   a:Destroy();b:Destroy()
  end)
  test("one shared clock for every wallet; it stops with the last one",function()
   Star.setLoader(good)
   local base=Star.count()
   local h=host("Clock")
   local list={Kit.wallet(h,44),Kit.wallet(h,44),Kit.wallet(h,44)}
   assert(Star.count()==base+3 and Peek.isSubscribed(Star.ClockKey),"three wallets, one subscription")
   h:Destroy();frames(1)
   assert(Star.count()==base,"destroyed wallets leave the clock")
   if base==0 then assert(not Peek.isSubscribed(Star.ClockKey),"clock stops with no 3D wallets")end
   assert(#list==3)
  end)
  test("no instances per frame over 60 frames; the turn hides the eyes and the glint sparkles",function()
   Star.setLoader(good);Star.setReduced(false)
   local h=host("Frames");local w=Kit.wallet(h,44);local rec=w.star3D.wallet
   frames(2)
   local added=0;local c=gui.DescendantAdded:Connect(function()added+=1 end)
   local moves=0;local m=rec.part:GetPropertyChangedSignal("CFrame"):Connect(function()moves+=1 end)
   frames(60)
   c:Disconnect();m:Disconnect()
   assert(added==0,"instances created per frame: "..added)
   assert(moves>0,"the shown Star never moved in 60 frames")
   Star._step(Star.SwayTime+(Star.Cycle-Star.SwayTime)/2)
   assert(not rec.face.Visible and not rec.sparkle.Visible,"mid-turn: no face, no sparkle")
   Star._step(Star.Cycle+Star.GlintTime/2)
   assert(rec.face.Visible and rec.sparkle.Visible,"turn landed: face back, sparkle on")
   h:Destroy()
  end)
  test("Reduced Motion: a still, front-facing Star with no sparkle",function()
   Star.setLoader(good);Star.setReduced(true)
   local h=host("Reduced");local w=Kit.wallet(h,44);local rec=w.star3D.wallet
   Star._step(Star.SwayTime+.8);Star._step(Star.Cycle+.1)
   assert(rec.spin==0 and rec.face.Visible and not rec.sparkle.Visible,"reduced pose")
   local writes=0;local m=rec.part:GetPropertyChangedSignal("CFrame"):Connect(function()writes+=1 end)
   frames(30);m:Disconnect()
   assert(writes==0,"reduced Star moved")
   Star.setReduced(nil);h:Destroy()
  end)
  test("a hidden wallet is skipped (nothing written)",function()
   Star.setLoader(good);Star.setReduced(false)
   local h=host("Hidden");local w=Kit.wallet(h,44);local rec=w.star3D.wallet
   h.Visible=false
   for _=1,40 do frames(1)end -- past the 0.25 s visibility recheck
   local writes=0;local m=rec.part:GetPropertyChangedSignal("CFrame"):Connect(function()writes+=1 end)
   frames(30);m:Disconnect()
   assert(writes==0,"hidden wallet kept spinning")
   Star.setReduced(nil);h:Destroy()
  end)
 end,debug.traceback)
 Star.setLoader(savedLoader);Star.setReduced(nil)
 gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
