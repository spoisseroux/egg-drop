-- Pocket Menu (UI-SPEC-COMPACT-FRAME section 9, decision 6): the pause menu on the
-- deck screen, opened by the MENU pill (and M / Y / Start) during a round: Resume,
-- Restart round, Quit to garden and Settings (QA 2026-11-13 Q5: outside rounds the
-- Pocket menu is the garden machine hub, MachineHub.lua, so Hatch eggs, Customize and
-- the Collection book left this list). Restart and Quit act at once on an empty board
-- and ask for one more tap mid-round.
-- Presentation only: every action goes back through `callbacks`; the caller owns
-- pausing, the round and the garden routes.
local Kit=require(script.Parent.DeckKit)
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Menu={}
Menu.__index=Menu
Menu.Items={
 {id="resume",text="Resume",variant="primary"},
 {id="restart",text="Restart round",armed="Tap again to restart"},
 {id="quit",text="Quit to garden",armed="Tap again to quit"},
 {id="settings",text=UICopy.get("pause.settings")},
}
Menu.Count=#Menu.Items
Menu.OpenTime,Menu.CloseTime,Menu.ArmTime=.16,.12,3

-- Pure: the regular (desktop LCD, authored 848x608) layout, one column.
function Menu.regularGeometry()
 local items={}
 for i=1,Menu.Count do items[i]={x=244,y=136+(i-1)*70,w=360,h=60}end
 return{cols=1,items=items,title={x=40,y=36,w=768,h=34}}
end
-- Pure: the next focus index from `index` moving (dx, dy) on a `cols` grid
-- (two columns fill the left column first), skipping disabled items; stays put at
-- an edge. `count` defaults to the menu's item count.
function Menu.step(index,dx,dy,cols,enabled,count)
 count=count or Menu.Count
 local rows=if cols==1 then count else math.ceil(count/2)
 local function pos(i)
  if cols==1 or i<=rows then return 0,i-1 end
  return 1,i-rows-1
 end
 local function at(c,r)
  if r<0 or r>=rows then return nil end
  local i=if c==0 then r+1 elseif c==1 and cols==2 then rows+r+1 else nil
  return if i and i<=count then i else nil
 end
 local c,r=pos(index)
 for _=1,rows do
  c+=dx;r+=dy
  -- Into a shorter right column: land on its last row.
  if cols==2 and dx~=0 and c==1 and rows+r+1>count then r=count-rows-1 end
  local i=at(c,r);if not i then return index end
  if enabled[i]~=false then return i end
 end
 return index
end

function Menu.new(overlay,callbacks)
 local self=setmetatable({overlay=overlay,callbacks=callbacks or {},visible=false,focusIndex=1,enabled={},state={},token=0,buttons={}},Menu)
 -- Two panel shutters wipe the screen open from the middle (a CRT-style reveal).
 local layer=overlay.layer
 self.shutters={}
 for i,anchor in ipairs({0,1})do
  local s=Kit.frame(layer,if i==1 then "ShutterTop"else "ShutterBottom","panel",UDim2.fromScale(0,anchor),UDim2.fromScale(1,0))
  s.AnchorPoint=Vector2.new(0,anchor);s.ZIndex=layer.ZIndex+40;s.Visible=false
  local edge=Kit.frame(s,"Edge",nil,UDim2.fromScale(0,if anchor==0 then 1 else 0),UDim2.new(1,0,0,1));edge.AnchorPoint=Vector2.new(0,if anchor==0 then 1 else 0)
  edge.BackgroundTransparency=.7;edge.BackgroundColor3=Color3.new(1,1,1);edge.ZIndex=s.ZIndex+1
  self.shutters[i]=s
 end
 overlay.onLayout=function(view)
  local key=if view then string.format("%dx%d:%d:%d",view.W,view.H,view.kx,view.kh)else "regular"
  if key==self.key then return end
  self:build(view)
  if self.visible then self:paint();self:focus(self.focusIndex,true)end
 end
 self:build(nil)
 return self
end

function Menu:build(view)
 self.key=if view then string.format("%dx%d:%d:%d",view.W,view.H,view.kx,view.kh)else "regular"
 if self.ring then self.ring.hide();self.ring.root:Destroy()end
 local content=self.overlay.content
 for _,child in ipairs(content:GetChildren())do if not(child:IsA("UIScale")or child:IsA("UIPadding"))then child:Destroy()end end
 local phone=view~=nil
 local geo=if phone then view.pocket else Menu.regularGeometry()
 self.cols=geo.cols;self.phone=phone
 local t=geo.title
 local titleSize=if phone then 20 else 26
 self.title=Kit.text(content,"Title","Pocket menu","text",{Name="Title",Position=UDim2.fromOffset(t.x,t.y),Size=UDim2.fromOffset(t.w,t.h),TextSize=titleSize})
 self.subtitle=Kit.text(content,"Body",UICopy.get("menu.subtitle.paused"),"soft",{Name="Subtitle",Position=UDim2.fromOffset(t.x,t.y),Size=UDim2.fromOffset(t.w,t.h),
  TextSize=if phone then 14 else 16,TextXAlignment=Enum.TextXAlignment.Right})
 -- Keep the subtitle clear of the title; drop it when the row is too narrow.
 local tw=Kit.measure(self.title.Text,"Title",titleSize).X
 local sw=0
 for _,key in ipairs({"menu.subtitle.empty","menu.subtitle.locked"})do
  sw=math.max(sw,Kit.measure(UICopy.get(key),"Body",self.subtitle.TextSize).X)
 end
 self.subtitle.Visible=tw+16+sw<=t.w
 self.buttons={}
 for i,item in ipairs(Menu.Items)do
  local r=geo.items[i]
  local button=Kit.button(content,"Item_"..item.id,{variant=item.variant or "secondary",text=item.text,size=Vector2.new(r.w,r.h),textSize=if phone then 16 else 20,selectable=false})
  button.Position=UDim2.fromOffset(r.x,r.y)
  button.Activated:Connect(function()self:activate(i,true)end)
  button.MouseEnter:Connect(function()if self.visible then self:focus(i)end end)
  self.buttons[i]=button
 end
 self.ring=Kit.focusRing(self.overlay.layer)
end

-- state: {empty, locked, canRestart, canQuit, canSettings}
function Menu:paint()
 local s=self.state
 self.enabled={true,s.canRestart~=false,s.canQuit~=false,s.canSettings~=false}
 for i,button in ipairs(self.buttons)do
  local item=Menu.Items[i]
  local armed=self.armed==item.id
  Kit.setText(button,if armed then item.armed else item.text)
  local st=Kit.buttonState(button)
  if st and item.armed then st.variant=if armed then "destructive"else "secondary"end
  Kit.setEnabled(button,self.enabled[i])
  -- A locked row still takes focus and taps (QA 2026-11-12: a fresh save looked frozen);
  -- activating it says why it is locked instead of doing nothing.
  button.Active,button.Interactable=true,true
 end
 self.subtitle.Text=UICopy.get(if s.locked then "menu.subtitle.locked"elseif s.empty then "menu.subtitle.empty"else "menu.subtitle.paused")
end

function Menu:focus(index,instant)
 self.focusIndex=index
 if self.armed and Menu.Items[index].id~=self.armed then self:disarm()end
 local button=self.buttons[index]
 if not(self.visible and button)then self.ring.hide();return end
 self.ring.attach(button,12)
end

-- focusId (optional): the row to focus, e.g. "settings" when Back returns from Settings.
function Menu:open(state,focusId)
 self.state=state or {};self.armed=nil
 self.visible=true
 self:paint()
 local layer=self.overlay.layer
 layer.Visible=true
 self.token+=1;local token=self.token
 local top,bottom=self.shutters[1],self.shutters[2]
 if Kit.reduced()then
  top.Visible,bottom.Visible=false,false
 else
  top.Visible,bottom.Visible=true,true
  top.Size,bottom.Size=UDim2.fromScale(1,.46),UDim2.fromScale(1,.46)
  local info=TweenInfo.new(Menu.OpenTime,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
  local TweenService=game:GetService("TweenService")
  TweenService:Create(top,info,{Size=UDim2.fromScale(1,0)}):Play()
  local last=TweenService:Create(bottom,info,{Size=UDim2.fromScale(1,0)})
  last.Completed:Connect(function()if self.token==token then top.Visible,bottom.Visible=false,false end end)
  last:Play()
 end
 local first=1
 for i,item in ipairs(Menu.Items)do if item.id==focusId then first=i end end
 self:focus(first,true)
end

-- Instant when Reduced Motion is on or `instant` (round end, mode change).
function Menu:close(instant)
 if not self.visible then return false end
 self.visible=false;self.armed=nil
 self.ring.hide()
 self.token+=1;local token=self.token
 local layer=self.overlay.layer
 local top,bottom=self.shutters[1],self.shutters[2]
 if instant or Kit.reduced()then
  layer.Visible=false;top.Visible,bottom.Visible=false,false
 else
  top.Visible,bottom.Visible=true,true
  top.Size,bottom.Size=UDim2.fromScale(1,0),UDim2.fromScale(1,0)
  local info=TweenInfo.new(Menu.CloseTime,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
  local TweenService=game:GetService("TweenService")
  TweenService:Create(top,info,{Size=UDim2.fromScale(1,.5)}):Play()
  local last=TweenService:Create(bottom,info,{Size=UDim2.fromScale(1,.5)})
  last.Completed:Connect(function()
   if self.token==token then layer.Visible=false;top.Visible,bottom.Visible=false,false end
  end)
  last:Play()
 end
 if self.callbacks.closed then self.callbacks.closed()end
 return true
end

function Menu:move(dx,dy)
 if not self.visible then return end
 local nextIndex=Menu.step(self.focusIndex,dx,dy,self.cols,{})
 if nextIndex~=self.focusIndex then self:focus(nextIndex)end
end
function Menu:confirm()if self.visible then self:activate(self.focusIndex)end end

function Menu:disarm()
 if not self.armed then return end
 self.armed=nil;self.armToken=(self.armToken or 0)+1
 if self.visible then self:paint()end
end

-- One press acts; Restart and Quit mid-round need a second press within 3 s.
function Menu:activate(index,pointer)
 if not self.visible then return false end
 if pointer and self.focusIndex~=index then self.focusIndex=index;if self.ring then self.ring.attach(self.buttons[index],12)end end
 local item=Menu.Items[index]
 if self.enabled[index]==false then
  if self.callbacks.locked then self.callbacks.locked(item.id,self.state)end
  return false
 end
 if item.armed and not self.state.empty and self.armed~=item.id then
  self.armed=item.id;self.armToken=(self.armToken or 0)+1;local token=self.armToken
  self:paint()
  if self.callbacks.armed then self.callbacks.armed(item.id)end
  task.delay(Menu.ArmTime,function()if self.armToken==token and self.armed==item.id then self:disarm()end end)
  return true
 end
 self.armed=nil
 local callback=self.callbacks[item.id]
 if callback then callback()end
 return true
end

return Menu
