-- Client fixture. Includes the actual CoreGui free topbar rectangle in diagnostics.
return function(client,playerGui)
 local Kit=require(client.DeckKit);local Rail=require(client.NotificationRail)
 local GuiService=game:GetService("GuiService");local RunService=game:GetService("RunService")
 local host=Instance.new("Frame");host.Name="_GlobalUIQA";host.Parent=playerGui
 local handle=Rail.enqueue(host,"fixture",{text="Ready to play",duration=30})
 RunService.RenderStepped:Wait();RunService.RenderStepped:Wait()
 local gui,pill=Rail.view()
 local inset=GuiService.TopbarInset
 local guiInset=GuiService:GetGuiInset()
 local physical=if pill then pill.AbsolutePosition+guiInset else nil
 local diagnostic="topbar="..tostring(inset).." guiInset="..tostring(guiInset).." guiRail="..tostring(pill and pill.AbsolutePosition).." physicalRail="..tostring(physical).." size="..tostring(pill and pill.AbsoluteSize)
 assert(pill and pill.Visible,"rail visible: "..diagnostic)
 assert(physical.X>=inset.Min.X+7 and physical.X+pill.AbsoluteSize.X<=inset.Max.X-11,"safe physical horizontal rail: "..diagnostic)
 assert(physical.Y>=inset.Min.Y-1 and physical.Y+pill.AbsoluteSize.Y<=inset.Max.Y+1,"physical topbar row: "..diagnostic)
 assert(pill.AbsoluteSize.Y>=39.9 and pill.AbsoluteSize.X<=300.1,"40px/max300 capsule: "..diagnostic)
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
 assert(a~=b and queue:step(0,fits)==a and queue:step(4,fits)==b,"two equal-valued awards remain two presentations")
 queue:cancelOwner(host)
 local c,d=adapter.show("Saved",1,"operation:one"),adapter.show("Saved",1,"operation:one")
 assert(c==d and #queue.items==1,"explicit immutable event identity dedupes")
 local Copy=require(game.ReplicatedStorage.Shared.UICopy);local Items=require(game.ReplicatedStorage.Shared.RoundItems)
 local TextService=game:GetService("TextService")
 local messages={Copy.get("items.note.empty"),Copy.get("items.note.full")}
 for _,id in ipairs({"busy","dry","closer","changed","ended","saving","retry"})do table.insert(messages,Copy.get("care.notice."..id))end
 for _,id in ipairs(Items.Order)do table.insert(messages,"+ "..Items.ById[id].name.." · From a star ball")end
 for _,text in ipairs(messages)do
  local width=TextService:GetTextSize(text,14,Enum.Font.BuilderSansMedium,Vector2.new(10000,40)).X
  assert(not text:find("\n",1,true)and Rail.geometry(320,58,width).fits,"feedback cannot fit approved one-line rail: "..text)
 end
 handle:cancel();host:Destroy()
 return{passed=11,rail=diagnostic}
end
