-- Isolated actual GUI/models, no remotes or wallet changes. Run Medium/Largest.
return function(client,parent,onlySize)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent)
 local Hues=require(game.ReplicatedStorage.Shared.HueCatalog);local P=require(game.ReplicatedStorage.Shared.PetPalette)
 local Gui=game:GetService("GuiService");local Run=game:GetService("RunService")
 local previous=Gui.SelectedObject;local root=Instance.new("Frame");root.Name="_HueLayout";root.BackgroundTransparency=1;root.Parent=parent
 local sent={};local earned=0;local pendingHatches=0;local cases={};local view
 local intent=Intent.new({id=function()return "layout-operation"end,send=function(a,v,r)table.insert(sent,{action=a,value=v,revision=r})end,changed=function()if view then view:refresh()end end})
 view=View.new(root,intent,{appearance=function()return{charmVisible=true}end,earn=function()earned+=1 end,pendingHatch=function()pendingHatches+=1 end})
 local function state(balance,rev)return{status="Ready",revision=rev or 1,nectar=balance or 18,inventoryMask=3,hues={}}end
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 local function test(n,f)parent:SetAttribute("HueViewProgress",n);f();table.insert(cases,n)end
 local function visible(n)
  while n and n~=root do if n:IsA("GuiObject")and not n.Visible then return false end;n=n.Parent end;return n==root
 end
 local function fit(n)assert(n.TextFits,string.format("%s %q box=%s bounds=%s",n:GetFullName(),n.Text,tostring(n.AbsoluteSize),tostring(n.TextBounds)))end
 local function inside(n,h)local p,s,q,t=n.AbsolutePosition,n.AbsoluteSize,h.AbsolutePosition,h.AbsoluteSize;return p.X>=q.X-.1 and p.Y>=q.Y-.1 and p.X+s.X<=q.X+t.X+.1 and p.Y+s.Y<=q.Y+t.Y+.1 end
 local ok,problem=pcall(function()
  for _,size in ipairs(if onlySize then{onlySize}else{Vector2.new(1649,971),Vector2.new(749,381),Vector2.new(385,703),Vector2.new(568,160)})do
   test(tostring(size).." measured header footer choices and matched static previews",function()
    root.Size=UDim2.fromOffset(size.X,size.Y);settle();assert(view:open(state(18,1),"buy","pip"));settle()
    fit(view.title);fit(view.wallet);fit(view.action)
    assert(view.closeButton.AbsoluteSize.X>=44 and view.closeButton.AbsoluteSize.Y>=44 and inside(view.closeButton,view.card))
    assert(view.action.AbsoluteSize.Y>=44 and inside(view.action,view.card)and view.body.AbsoluteSize.Y>=44,"pinned controls/body collapsed")
    for _,n in ipairs(view.body:GetDescendants())do
     if n:IsA("TextLabel")and visible(n)then fit(n)end
     if n:IsA("TextButton")and visible(n)then assert(n.AbsoluteSize.X>=44 and n.AbsoluteSize.Y>=44,"small action "..n.Name)end
    end
    assert(view.current.camera.CFrame==view.after.camera.CFrame and view.current.viewport.Ambient==view.after.viewport.Ambient)
    assert(view.current.visual.model~=view.after.visual.model and view.current.visual.idleMotionFrozen and view.after.visual.idleMotionFrozen)
    assert(view.previewContained and view.previewBodyFraction<=.641,"unsafe/static framing")
    if size.X>=560 and size.Y>=280 and size.Y<=390 then
     assert(view.compactLandscape and view.targets[1].Position.Y==view.paletteTab.Position.Y,"phone selectors consumed two rows")
     assert(view.after.host.AbsolutePosition.Y+view.after.host.AbsoluteSize.Y<=view.body.AbsolutePosition.Y+view.body.AbsoluteSize.Y+.1,"phone initial preview hides its feet")
    end
    assert(view.current.visual.colors.body==P.resolve("pip",{body="original"}).body)
    assert(view.after.visual.colors.body==P.resolve("pip",{body="rose",bodyRank=1}).body)
    assert(view.current.visual.secondaryColor==view.after.visual.secondaryColor)
    local a,b=view.current.visual,view.after.visual;view:chooseHue("tide");view:chooseHue("rose");assert(view.current.visual==a and view.after.visual==b,"offer selection rebuilt rigs")
   end)
  end
  test("ordinary snapshots preserve target direction scroll focus and both rig identities",function()
   root.Size=UDim2.fromOffset(749,381);settle();view:open(state(18,2),"buy","puddle");view:chooseHue("tide");settle()
   local a,b=view.current.visual,view.after.visual;local selected=view.offers.tide.button;Gui.SelectedObject=selected;view:ensure(selected);settle()
   local y=view.body.CanvasPosition.Y;intent:update(state(19,3));settle()
   assert(view.petId=="puddle"and view.hue=="tide"and view.current.visual==a and view.after.visual==b)
   assert(math.abs(view.body.CanvasPosition.Y-y)<1 and Gui.SelectedObject==selected and #sent==0)
  end)
  test("shortfall uses existing earning route while max and pending never spend or navigate",function()
   view:close();view:open(state(6,4),"buy","pip");assert(view.action.Text=="Earn 2 more Stars"and view.action.Interactable)
   assert(view.action:GetAttribute("AccessibleLabel"):find("2 Stars",1,true));view:activate();assert(earned==1 and #sent==0 and not view:isOpen())
   local max=state(40,5);max.hues.pip={body="rose",secondary="default",ranks={rose=3,tide=0,citrus=0,iris=0}}
   view:open(max,"buy","pip");view:chooseHue("rose");assert(view.action.Text=="Max rank"and not view.action.Interactable);view:activate();assert(earned==1 and #sent==0)
  end)
  test("explicit free body and secondary preview independently and preserve Dot state",function()
   local s=state(18,6);s.hues.pip={body="tide",secondary="default",ranks={rose=1,tide=2,citrus=0,iris=0}}
   view:open(s,"palette","pip");view:choosePalette("body","original");assert(view.action.Text=="Equip Original body")
   assert(view.current.visual.colors.body==P.resolve("pip",{body="tide",bodyRank=2}).body and view.after.visual.colors.body==P.resolve("pip",{}).body)
   assert(view.current.visual.secondaryColor==view.after.visual.secondaryColor)
   view:choosePalette("secondary","rose");assert(view.action.Text=="Equip Rose accents"and view.action:GetAttribute("AccessibleLabel")==view.action.Text)
   assert(view.after.visual.colors.body==view.current.visual.colors.body and view.after.visual.secondaryColor==Hues.ById.rose.color)
   assert(not view:choosePalette("secondary","iris")and #sent==0)
  end)
  test("selected offer child name and grade keep composited contrast in all eight themes",function()
   local Art=require(client.DeckArt);local Themes=require(game.ReplicatedStorage.Shared.DeckThemes);local old=Art.getTheme()
   local function luminance(c)local function f(x)return if x<=.04045 then x/12.92 else((x+.055)/1.055)^2.4 end;return .2126*f(c.R)+.7152*f(c.G)+.0722*f(c.B)end
   local function ratio(a,b)local x,y=luminance(a),luminance(b);return(math.max(x,y)+.05)/(math.min(x,y)+.05)end
   local success,err=pcall(function()
    view:open(state(18,7),"buy","pip");view:chooseHue("rose")
    for _,id in ipairs(Themes.Order)do
     Art.applyTheme(Themes.ById[id]);view:refresh();local e=view.offers.rose;local gradient=e.button:FindFirstChildOfClass("UIGradient")
     for _,label in ipairs({e.title,e.rank})do
      assert(label.TextColor3==Art.paletteColor("ink"),id.." selected offer child lost dark ink")
      for _,point in ipairs(gradient.Color.Keypoints)do
       local c,b=point.Value,e.button.BackgroundColor3
       local actual=Color3.new(c.R*b.R,c.G*b.G,c.B*b.B)
       assert(ratio(label.TextColor3,actual)>=4.5,id.." selected name/grade contrast="..ratio(label.TextColor3,actual))
      end
     end
    end
   end)
   Art.applyTheme(old);assert(success,err)
  end)
  test("unsupported Journal targets fall back safely and pending hatch preempts Hue",function()
   local s=state(18,7);s.inventoryMask=7;assert(view:open(s,"palette","wick")and view.petId~="wick")
   local a,b=view.current.visual,view.after.visual
   for _=1,20 do view:close();view:open(s,"buy","pip")end
   assert(view.current.visual==a and view.after.visual==b,"open/close reallocated persistent previews")
   local last=state(18,8);last.lastHatch={id="pending-companion",petId="puddle"};intent:update(last);settle()
   assert(not view:isOpen()and pendingHatches==1 and #sent==0 and last.lastHatch.id=="pending-companion")
  end)
 end)
 view:destroy();root:Destroy();Gui.SelectedObject=previous;assert(ok,problem)
 return{passed=#cases,cases=cases,purchases=0,actualWalletMutation=false}
end
