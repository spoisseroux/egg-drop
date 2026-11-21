-- Client fixture. Includes the actual CoreGui free topbar rectangle in diagnostics.
return function(client,playerGui)
 local Kit=require(client.DeckKit);local Rail=require(client.NotificationRail)
 local GuiService=game:GetService("GuiService");local RunService=game:GetService("RunService")
 local host=Instance.new("Frame");host.Name="_GlobalUIQA";host.Parent=playerGui
 local handle=Rail.enqueue(host,"fixture",{text="Ready to play",duration=30})
 -- v2 tickets: wait for the fixture's ticket (admissions are 0.4 s apart) and its entrance.
 local ticket
 local deadline=os.clock()+3
 repeat
  RunService.RenderStepped:Wait()
  ticket=nil
  for _,entry in ipairs(Rail.shown())do if entry.text=="Ready to play"then ticket=entry end end
  local scale=ticket and ticket.ticket:FindFirstChildOfClass("UIScale")
 until(scale and scale.Scale==1)or os.clock()>deadline
 local gui,_,row=Rail.view()
 local pill=ticket and ticket.card
 local inset=GuiService.TopbarInset
 local guiInset=GuiService:GetGuiInset()
 local physical=if pill then pill.AbsolutePosition+guiInset else nil
 local physicalRow=if row then row.AbsolutePosition+guiInset else nil
 local diagnostic="topbar="..tostring(inset).." guiInset="..tostring(guiInset).." guiTicket="..tostring(pill and pill.AbsolutePosition).." physicalTicket="..tostring(physical).." size="..tostring(pill and pill.AbsoluteSize)
  .." physicalRow="..tostring(physicalRow).." rowSize="..tostring(row and row.AbsoluteSize)
 assert(gui and pill and row and row.Visible,"rail ticket visible: "..diagnostic)
 -- The row: x 8 inside the free bar, at most its width less 16 (1 px slack).
 assert(physicalRow.X>=inset.Min.X+7 and physicalRow.X+row.AbsoluteSize.X<=inset.Max.X-7,"safe physical horizontal row: "..diagnostic)
 assert(physical.Y>=inset.Min.Y-1 and physical.Y+pill.AbsoluteSize.Y<=inset.Max.Y+1,"physical topbar row: "..diagnostic)
 local cardH=require(client.NotificationRail).size(inset.Height).card
 assert(math.abs(pill.AbsoluteSize.Y-cardH)<.2 and pill.AbsoluteSize.X>=95.9 and pill.AbsoluteSize.X<=260.1,"40 (32) px ticket, 96..260 wide: "..diagnostic)
 local button,state=Kit.button(host,"DisabledBuy",{text="Buy  ★ 12",variant="primary"})
 Kit.setEnabled(button,false)
 assert(not button.Interactable and not button.Active,"disabled hit is inert")
 -- Toy Shell 3.4: a grey-lilac face and lip with 3.4:1 text (the reason line stays at full contrast).
 assert(state.fill.BackgroundTransparency==0 and state.fill.BackgroundColor3==Kit.Disabled.face,"disabled face stays visible")
 assert(state.edge.Visible and state.edge.BackgroundColor3==Kit.Disabled.lip and state.stroke.Enabled,"disabled lip and border")
 assert(state.label.TextTransparency==0 and state.label.TextColor3==Kit.Disabled.text,"disabled price retains readable label")
 Kit.pulse(button);assert(not state.pressed,"programmatic disabled pulse inert")
 local Art=require(client.DeckArt)
 local native=Instance.new("TextButton");native.Name="NativeDisabledBuy";native.Text="Hatch · 8 Stars";native.Parent=host
 Art.button(native,12);Art.control(native,true,false)
 assert(not native.Interactable and not native.Active and native.BackgroundTransparency==0,"native disabled action inert/visible")
 assert(native.BackgroundColor3==Art.ToyDisabled.face and native.TextColor3==Art.ToyDisabled.text,"native disabled palette")
 local lip=native:FindFirstChild("DisabledLip");local border=native:FindFirstChildOfClass("UIStroke")
 assert(lip and lip.Visible and border and border.Color==Art.ToyDisabled.lip,"native lip/border retained")
 local queue=require(client.NotificationQueue).new()
 local adapter=Kit.toaster(host,{enqueue=function(owner,key,data)return queue:add(owner,key,data)end})
 local a,b=adapter.show("Same award",1),adapter.show("Same award",1)
 local fits=function()return true end
 local first=queue:step(0,fits)[1];local both=queue:step(.5,fits)
 assert(a~=b and first==a and both[1]==a and both[2]==b,"two equal-valued awards remain two presentations (side by side)")
 queue:cancelOwner(host)
 local c,d=adapter.show("Saved",1,"operation:one"),adapter.show("Saved",1,"operation:one")
 assert(c==d and #queue.items==1,"explicit immutable event identity dedupes")
 local Copy=require(game.ReplicatedStorage.Shared.UICopy);local Items=require(game.ReplicatedStorage.Shared.RoundItems)
 local TextService=game:GetService("TextService")
 local messages={Copy.get("items.note.empty"),Copy.get("items.note.full")}
 for _,id in ipairs({"busy","dry","closer","changed","ended","saving","retry"})do table.insert(messages,Copy.get("care.notice."..id))end
 for _,id in ipairs(Items.Order)do table.insert(messages,"+ "..Items.ById[id].name.." · From a star ball")end
 -- One line each, drawable on a phone and a desktop bar; a longer line truncates at the end
 -- of its ticket (spec 1: max 260, 220 under a 600 px bar), listed for the visual pass.
 local truncated={}
 for _,text in ipairs(messages)do
  local width=TextService:GetTextSize(text,14,Enum.Font.BuilderSansMedium,Vector2.new(10000,40)).X
  assert(not text:find("\n",1,true)and Rail.geometry(320,58,width).fits and Rail.geometry(1280,58,width).fits,"feedback cannot show on the one-line rail: "..text)
  if not Rail.geometry(1280,58,width).full then table.insert(truncated,text)end
 end
 handle:cancel();host:Destroy()
 return{passed=11,rail=diagnostic,truncatedOnDesktop=table.concat(truncated," | ")}
end
