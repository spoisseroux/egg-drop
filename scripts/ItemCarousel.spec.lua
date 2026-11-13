-- Studio Client. Round items UI (BUILD-PLAN 2026-11-13 items 4 and 6): carousel
-- keys, the one pause flag with the carousel as its third owner, browsing, the
-- phone item button under A and the "You have no items" note that fades.
-- Usage: require(PlayerScripts.Client.ZZSpecs.ItemCarousel)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Carousel=require(client.ItemCarousel);local Screen=require(client.DeckScreen)
 local Items=require(game.ReplicatedStorage.Shared.RoundItems)
 local K=Enum.KeyCode
 local aspect=(11+.8)/(19+.8)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_ItemCarouselSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local ok,problem=pcall(function()
  test("closed: B, gamepad B and X open; Backspace, A and arrows pass through",function()
   for _,key in ipairs({K.B,K.ButtonB,K.ButtonX})do assert(Carousel.keyAction(key,false)=="open",key.Name)end
   for _,key in ipairs({K.Backspace,K.Left,K.A,K.Space,K.ButtonA,K.M})do assert(Carousel.keyAction(key,false)==nil,key.Name)end
  end)
  test("open: Left/Right browse, A/Space/Enter use, B/X/Backspace close, the rest is swallowed",function()
   for _,key in ipairs({K.Left,K.A,K.DPadLeft})do assert(Carousel.keyAction(key,true)=="left")end
   for _,key in ipairs({K.Right,K.D,K.DPadRight})do assert(Carousel.keyAction(key,true)=="right")end
   for _,key in ipairs({K.Space,K.Return,K.KeypadEnter,K.ButtonA})do assert(Carousel.keyAction(key,true)=="use")end
   for _,key in ipairs({K.B,K.ButtonB,K.ButtonX,K.Backspace})do assert(Carousel.keyAction(key,true)=="close")end
   for _,key in ipairs({K.Up,K.DPadDown,K.W})do assert(Carousel.keyAction(key,true)=="sink")end
   -- Every key it acts on is bound.
   for _,key in ipairs({K.B,K.ButtonB,K.ButtonX,K.Backspace,K.Left,K.Right,K.Space,K.ButtonA,K.DPadUp})do assert(table.find(Carousel.Keys,key),key.Name)end
  end)
  test("pause: the carousel is a third owner; a finished round never pauses; a modal always does",function()
   local P=Carousel.pauseWanted
   assert(P({carousel=true})==true and P({questLog=true})==true and P({pocketMenu=true})==true)
   assert(P({})==false and P({carousel=true,roundOver=true})==false)
   assert(P({modal=true,roundOver=true})==true)
   assert(P({carousel=false,questLog=false,pocketMenu=false,modal=false,roundOver=false})==false)
  end)
  test("wrap and neighbours: one item alone, two show the other, three show both sides",function()
   assert(Carousel.wrap(1,-1,3)==3 and Carousel.wrap(3,1,3)==1 and Carousel.wrap(2,1,3)==3 and Carousel.wrap(1,1,0)==0)
   local l,r=Carousel.neighbours(1,1);assert(l==nil and r==nil)
   l,r=Carousel.neighbours(1,2);assert(l==nil and r==2)
   l,r=Carousel.neighbours(1,3);assert(l==3 and r==2)
  end)
  test("empty belt: open() refuses and shows 'You have no items', which fades out in ~1.5-2 s",function()
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(400,600);host.BackgroundTransparency=1;host.Parent=gui
   local c=Carousel.new(host);c:place(UDim2.fromOffset(20,0),UDim2.fromOffset(330,580),false)
   assert(not c:open()and not c.isOpen,"empty belt does not open")
   assert(c.note.Visible and c.noteText.Text==Carousel.EmptyNote and c.lastNote=="You have no items")
   assert(not c.panel.Visible and not c.dim.Visible,"the round is not frozen")
   task.wait(Carousel.NoteHold+Carousel.NoteFade+.25)
   assert(not c.note.Visible,"note gone after the fade")
   c:destroy();host:Destroy()
  end)
  test("browse, use and close: selection wraps, follows the belt, closes when the belt empties",function()
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(400,600);host.BackgroundTransparency=1;host.Parent=gui
   local c=Carousel.new(host);c:place(UDim2.fromOffset(20,0),UDim2.fromOffset(330,580),false)
   c:setBelt({"swap","pop","bomb"})
   assert(c:selected()==nil,"nothing selected while closed")
   assert(c:open()and c.isOpen and c.panel.Visible and c.dim.Visible)
   assert(c:selected()=="swap"and c.name.Text=="Swap"and c.count.Text=="1 OF 3")
   assert(c:move(-1)and c:selected()=="bomb","wraps left")
   assert(c:move(1)and c:move(1)and c:selected()=="pop")
   assert(c.caps.left.root.Visible and c.caps.right.root.Visible)
   -- The panel stays in the top 45% of the board (above the fill line).
   task.wait()
   assert(c.panel.AbsoluteSize.Y<=580*.45+1 and c.panel.AbsolutePosition.Y-host.AbsolutePosition.Y<20,"panel above the fill line")
   c:setBelt({"pop","bomb"});assert(c:selected()=="pop","selection follows the item")
   c:setBelt({});assert(not c.isOpen,"an emptied belt closes the carousel")
   assert(not c:close(),"close is idempotent")
   c:destroy();host:Destroy()
  end)
  test("phone: the item button is always under A (44+ target, no overlap), hidden on desktop",function()
   for _,size in ipairs({Vector2.new(568,320),Vector2.new(740,360),Vector2.new(844,390),Vector2.new(932,430)})do
    local root=Instance.new("Frame");root.Size=UDim2.fromOffset(size.X,size.Y);root.BackgroundTransparency=1;root.Parent=gui
    local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true)
    local presses=0;s:on("item",function()presses+=1 end)
    s:setItems(0)
    task.wait()
    local g=s.geometry;local ib=s.itemButton;local label=tostring(size)
    assert(ib.holder.Visible,label.." button shown with an empty belt")
    assert(ib.hit.AbsoluteSize.X>=44 and ib.hit.AbsoluteSize.Y>=44,label.." hit 44+")
    local a=s.buttons.A.hit;local top=ib.hit.AbsolutePosition.Y
    assert(top>=a.AbsolutePosition.Y+a.AbsoluteSize.Y,label.." below A's hit area")
    assert(math.abs((ib.hit.AbsolutePosition.X+ib.hit.AbsoluteSize.X/2)-(a.AbsolutePosition.X+a.AbsoluteSize.X/2))<=1,label.." centred under A")
    assert(ib.hit.AbsolutePosition.Y+ib.hit.AbsoluteSize.Y<=root.AbsolutePosition.Y+size.Y,label.." on screen")
    assert(ib.glyph.Text=="B"and not ib.badge.Visible,label.." empty state")
    s:setItems(2,Items.ById.pop.glyph,Items.ById.pop.color)
    assert(ib.badge.Visible and ib.count.Text=="2"and ib.glyph.Text==Items.ById.pop.glyph,label.." count and front item")
    s.callbacks.item();assert(presses==1)
    root:Destroy()
   end
   local root=Instance.new("Frame");root.Size=UDim2.fromOffset(1920,1080);root.BackgroundTransparency=1;root.Parent=gui
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(Vector2.new(1920,1080),aspect);s:setVisible(true)
   assert(not s.itemButton.holder.Visible,"desktop uses B, not the shoulder button")
   root:Destroy()
  end)
  test("controls cards: B reads Items (leaving is MENU or the back arrow)",function()
   for _,input in ipairs({"Gamepad","Keyboard"})do
    local found=false
    for _,row in ipairs(Screen.compactControlRows[input])do if row[1]=="B"then found=row[2]=="Items"end end
    assert(found,input)
   end
  end)
 end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
