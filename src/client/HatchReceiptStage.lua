-- Receipt chrome borrowing one Cinematic-owned Scene. No render connection,
-- reward mutation, asset loader or second pet rig lives here.
local GuiService=game:GetService("GuiService")
local Input=game:GetService("UserInputService")
local Copy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Stage={};Stage.__index=Stage
local function node(class,parent,props)local o=Instance.new(class);for k,v in pairs(props or {})do o[k]=v end;o.Parent=parent;return o end
local cream=Color3.fromHex("#FFF0D2");local mint=Color3.fromHex("#94DFB7");local ink=Color3.fromHex("#132F31")
local function text(parent,name,value,size)
 return node("TextLabel",parent,{Name=name,Text=value or "",TextSize=size,Font=Enum.Font.GothamMedium,TextColor3=cream,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,TextWrapped=true,ZIndex=60})
end
local function place(o,x,y,w,h)o.Position=UDim2.fromOffset(x,y);o.Size=UDim2.fromOffset(math.max(1,w),math.max(1,h))end
function Stage.receiptLabel(options)
 local result=options.result or {}
 if result.duplicate or options.tag=="owned"then
  local refund=if type(result.refund)=="number"and result.refund==result.refund then math.max(0,math.floor(result.refund))else 0
  return if refund>0 then Copy.get("hatch.display.refund",{count=refund})else Copy.get("hatch.display.owned")
 end
 return Copy.get(if result.starter then "hatch.display.firstFriend"else "hatch.display.friend")
end
function Stage.show(parent,options)
 assert(options.scene and options.externalClock,"Native receipt requires one externally clocked scene")
 local self=setmetatable({options=options,scene=options.scene,buttons={},connections={},focus=1,age=0,clock=0,renderMode="NativeSharedScene",loaded=options.scene.ready},Stage)
 self.root=node("Frame",parent,{Name="RevealStage",BackgroundColor3=ink,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ClipsDescendants=true,Active=true,ZIndex=50})
 self.seat=node("Frame",self.root,{Name="NativeSceneSeat",BackgroundTransparency=1,ZIndex=51})
 self.borrowToken=self.scene:borrow(self.seat)
 self.skip=node("TextButton",self.root,{Name="SkipReveal",Text="",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=55,Active=true})
 self.skip:SetAttribute("AccessibleLabel",Copy.get("r1.hatchHints.hatch"))
 self.panel=node("CanvasGroup",self.root,{Name="NativeReceipt",BackgroundTransparency=1,GroupTransparency=1,ZIndex=60})
 self.heading=text(self.panel,"PetName",options.name or(options.pet and options.pet.name)or "",32)
 self.heading.AutoLocalize=false
 self.description=text(self.panel,"Description",options.description or "",18)
 self.intro=text(self.root,"Anticipation",Copy.get("hatch.display.line"),25)
 self.label=text(self.root,"SurpriseLabel",Copy.get("hatch.display.wait"),14);self.label.TextColor3=Color3.fromHex("#F0B6A1")
 for index,raw in ipairs(options.buttons or {})do
  local button=node("TextButton",self.panel,{Name=raw.id,Text=raw.text or raw.id,Font=Enum.Font.GothamBold,TextSize=19,
   BackgroundColor3=if raw.primary then mint else Color3.fromHex("#2D504C"),TextColor3=if raw.primary then ink else cream,BorderSizePixel=0,ZIndex=65,Selectable=false})
  node("UICorner",button,{CornerRadius=UDim.new(0,12)})
  local entry={id=raw.id,node=button,primary=raw.primary==true,enabled=true};table.insert(self.buttons,entry)
  if entry.primary then self.focus=index end
  table.insert(self.connections,button.Activated:Connect(function()self:activate(index,true)end))
 end
 table.insert(self.connections,self.skip.Activated:Connect(function()if self:owned()and not self:isSettled()then self:settle()end end))
 table.insert(self.connections,self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:layout()end))
 table.insert(self.connections,Input.InputBegan:Connect(function(input,processed)
  if not self:owned()or(self.options.consumeSkipInput and self.options.consumeSkipInput())then return end
  local key=input.KeyCode
  if key==Enum.KeyCode.Return or key==Enum.KeyCode.KeypadEnter or key==Enum.KeyCode.ButtonA or key==Enum.KeyCode.Space then
   if not self:isSettled()then self:settle();return end
   if key==Enum.KeyCode.Space or(key==Enum.KeyCode.ButtonA and self:ownsSelection())or processed then return end
   self:confirm()
  elseif not processed then
   if key==Enum.KeyCode.Left or key==Enum.KeyCode.Up or key==Enum.KeyCode.DPadLeft or key==Enum.KeyCode.DPadUp then self:move(-1)
   elseif key==Enum.KeyCode.Right or key==Enum.KeyCode.Down or key==Enum.KeyCode.DPadRight or key==Enum.KeyCode.DPadDown then self:move(1)end
  end
 end))
 self:layout();return self
end
function Stage:owned()return not self.destroyed and self.root.Parent~=nil and self.root.Visible and(not self.options.owns or self.options.owns())end
function Stage:layout()
 if self.destroyed then return end
 local size=self.root.AbsoluteSize;local w,h=math.max(1,size.X),math.max(1,size.Y)
 local wide=w/h>=1.5;local x,y,pw,ph
 if wide then
  place(self.seat,0,math.min(58,h*.16),w*.58,h-math.min(58,h*.16));x,y,pw,ph=w*.615,math.max(12,h*.24),w*.365,h*.70
 else
  place(self.seat,0,0,w,h*.58);x,y,pw,ph=16,h*.59,w-32,h*.39
 end
 place(self.panel,x,y,pw,ph);place(self.label,x,math.max(8,y-30),pw,24);place(self.intro,x,y+15,pw,100)
 place(self.heading,0,0,pw,48);place(self.description,0,58,pw,math.max(28,ph-126))
 local gap=10;local bw=(pw-gap*math.max(0,#self.buttons-1))/math.max(1,#self.buttons)
 for index,entry in ipairs(self.buttons)do place(entry.node,(index-1)*(bw+gap),math.max(106,ph-48),bw,48)end
 self.scene:layout()
end
function Stage:updateExternal(age,sample)
 if self.destroyed then return end
 self.age,self.clock,self.sample=age,age,sample;self.loaded=self.scene.ready
 self.panel.GroupTransparency=1-sample.receiptAlpha;self.intro.Visible=sample.receiptAlpha<=0;self.label.Visible=true
 self.label.Text=if sample.receiptAlpha>0 then Stage.receiptLabel(self.options)else Copy.get("hatch.display.wait")
 self.label.TextTransparency=if sample.receiptAlpha>0 then 1-sample.receiptAlpha else 0
 self.skip.Visible=sample.inputLocked;self.skip.Active=sample.inputLocked
 self.root:SetAttribute("InputLocked",sample.inputLocked);self.root:SetAttribute("ReceiptReady",sample.receiptReady)
 for _,entry in ipairs(self.buttons)do entry.node.Active=sample.receiptReady and entry.enabled;entry.node.Selectable=sample.receiptReady and entry.enabled end
end
function Stage:isSettled()return self.sample~=nil and self.sample.receiptReady==true end
function Stage:settle(quiet)if self.options.onSkip then self.options.onSkip(quiet)end end
function Stage:ownsSelection()for _,e in ipairs(self.buttons)do if GuiService.SelectedObject==e.node then return true end end;return false end
function Stage:primaryButton()for _,e in ipairs(self.buttons)do if e.primary then return e.node end end;return self.buttons[1]and self.buttons[1].node end
function Stage:move(direction)
 if not self:isSettled()then return false end
 self.focus=math.clamp(self.focus+direction,1,math.max(1,#self.buttons));local e=self.buttons[self.focus]
 if e then GuiService.SelectedObject=e.node;return true end;return false
end
function Stage:activate(index)
 if not self:owned()or(self.options.consumeSkipInput and self.options.consumeSkipInput())then return false end
 if not self:isSettled()then self:settle();return false end
 local e=self.buttons[index];if not e or not e.enabled then return false end
 if self.options.onButton then self.options.onButton(e.id)end;return true
end
function Stage:confirm()return self:activate(self.focus)end
function Stage:back()
 if not self:isSettled()then self:settle();return true end
 for i,e in ipairs(self.buttons)do if not e.primary then return self:activate(i)end end;return false
end
function Stage:setButtons(states)
 for _,e in ipairs(self.buttons)do local s=states[e.id];if s then
  if s.text then e.node.Text=s.text end;if s.enabled~=nil then e.enabled=s.enabled==true end
 end end
 if self.sample then self:updateExternal(self.age,self.sample)end
end
function Stage:exit(kind)self.exiting={kind=kind,at=self.clock}end
function Stage:restore()self.exiting=nil end
function Stage:getStats()return {age=self.age,settled=self:isSettled(),renderMode=self.renderMode,loaded=self.loaded,sharedScene=self.scene~=nil,externalClock=true,clock=false}end
function Stage:destroy()
 if self.destroyed then return end;self.destroyed=true
 for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
 if self:ownsSelection()then GuiService.SelectedObject=nil end
 if self.scene then self.scene:release(self.borrowToken);self.scene=nil end
 self.root:Destroy()
end
return Stage
