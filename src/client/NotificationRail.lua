-- One spatial owner above game menus. TopbarSafeInsets already maps Roblox's
-- unoccupied topbar rectangle; offsets below are local to that area, exactly once.
local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local TextService=game:GetService("TextService")
local Queue=require(script.Parent.NotificationQueue)
local Rail={};local queue=Queue.new(24);local stopped=false;local connection
local gui,root,pill,label,icon,shown,more
-- QA v735 H5: a line that opens something on a tap (its own `activate`, or a notice card
-- named by `detail`, see NoticeCards) shows a small chevron at its end, MoreWidth wide.
Rail.MoreWidth=14
function Rail.tappable(data)return type(data)=="table"and(data.activate~=nil or type(data.detail)=="table")end
-- A tap on the line: its own action, else its notice card. True when something opened.
function Rail.activate(data)
 if type(data)~="table"then return false end
 if data.activate then data.activate();return true end
 local detail=data.detail
 if type(detail)~="table"then return false end
 return require(script.Parent.HowItWorks).openNotice(detail.id,{vars=detail.vars,run=detail.run})==true
end
local owners=setmetatable({},{__mode="k"})
local font=Font.new("rbxasset://fonts/families/BuilderSans.json",Enum.FontWeight.Medium)
local function node(class,parent,props)
 local object=Instance.new(class);for k,v in pairs(props)do object[k]=v end;object.Parent=parent;return object
end
-- QA v685 U1: Roblox's top-bar buttons are 44 px tall with a 12 px top margin in the 58 px bar,
-- so their centre line is 24 px above the bar's bottom edge, not the middle of the inset.
-- The capsule centres on that line (older, shorter bars keep the plain middle).
function Rail.geometry(width,height,textWidth,tappable)
 local desired=math.ceil(textWidth)+52+(if tappable then Rail.MoreWidth else 0)
 local available=math.min(300,width-20)
 return{fits=height>=40 and desired<=available,width=math.max(0,math.min(desired,available)),height=40,x=8,y=if height>=56 then height-44 else math.max(0,(height-40)/2)}
end
local function measure(data)
 local text=tostring(data.text or "")..(if data.amount~=nil then "  ★ +"..tostring(data.amount)else "")
 return text,TextService:GetTextSize(text,14,Enum.Font.BuilderSansMedium,Vector2.new(10000,40)).X
end
local function ensure()
 if stopped then return false end
 if gui and gui.Parent then return true end
 local p=Players.LocalPlayer;local pg=p and p:FindFirstChildOfClass("PlayerGui")
 if not pg then return false end
 gui=node("ScreenGui",pg,{Name="EggDropNotificationRail",ResetOnSpawn=false,DisplayOrder=100,
  ScreenInsets=Enum.ScreenInsets.TopbarSafeInsets,ClipToDeviceSafeArea=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 root=node("Frame",gui,{Name="FreeTopbarArea",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false})
 pill=node("CanvasGroup",root,{Name="Capsule",Visible=false,BackgroundColor3=Color3.fromHex("#152525"),BackgroundTransparency=.06,
  BorderSizePixel=0,Size=UDim2.fromOffset(300,40),GroupTransparency=1})
 node("UICorner",pill,{CornerRadius=UDim.new(0,12)})
 node("UIStroke",pill,{Color=Color3.fromHex("#8DBEAC"),Transparency=.45,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 icon=node("TextLabel",pill,{Name="Icon",BackgroundTransparency=1,Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(20,20),
  Text="✓",FontFace=font,TextSize=18,TextColor3=Color3.fromHex("#76F6B0"),Active=false})
 label=node("TextLabel",pill,{Name="Message",BackgroundTransparency=1,Position=UDim2.fromOffset(40,0),Size=UDim2.new(1,-50,1,0),
  Text="",FontFace=font,TextSize=14,TextColor3=Color3.fromHex("#F3F4F6"),TextWrapped=false,TextTruncate=Enum.TextTruncate.None,
  TextXAlignment=Enum.TextXAlignment.Left,Active=false})
 more=node("TextLabel",pill,{Name="More",BackgroundTransparency=1,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,0),Size=UDim2.fromOffset(Rail.MoreWidth,40),
  Text="›",FontFace=font,TextSize=20,TextColor3=Color3.fromHex("#8DBEAC"),Visible=false,Active=false})
 pill.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
   local item=queue.current;if item then Rail.activate(item.data)end
  end
 end)
 return true
end
local function watch(owner)
 if typeof(owner)=="Instance"and not owners[owner]then
  owners[owner]=owner.Destroying:Connect(function()queue:cancelOwner(owner);local c=owners[owner];owners[owner]=nil;if c then c:Disconnect()end end)
 end
end
local function add(owner,key,data,persistent)
 if stopped then return{update=function()end,cancel=function()end,isVisible=function()return false end}end
 watch(owner);ensure()
 local item=queue:add(owner,key,data,persistent)
 local handle={}
 function handle:update(values)
  if not item or item.cancelled then return end
  local nextData=table.clone(item.data);for k,v in pairs(values)do nextData[k]=v end;item.data=nextData
 end
 function handle:cancel()queue:cancel(item)end
 function handle:isVisible()return item~=nil and queue.current==item and pill~=nil and pill.Visible end
 return handle
end
function Rail.enqueue(owner,key,data)return add(owner,key,data,false)end
function Rail.status(owner,key,data)return add(owner,key,data,true)end
function Rail.cancelOwner(owner)queue:cancelOwner(owner)end
-- A cloned spec module can release its singleton; its destroyed GUI must not
-- leave a RenderStepped callback that recreates identically named empty rails.
function Rail.view()return gui,pill end
function Rail.destroy()
 if stopped then return end;stopped=true
 if connection then connection:Disconnect();connection=nil end
 for owner,c in pairs(owners)do c:Disconnect();owners[owner]=nil end
 queue.items={};queue.providers={};queue.current=nil
 if gui then gui:Destroy();gui,root,pill,label,icon,more=nil,nil,nil,nil,nil,nil end
end
script.Destroying:Connect(Rail.destroy)
connection=RunService.RenderStepped:Connect(function(dt)
 if not ensure()then return end
 -- AbsolutePosition is in Roblox's GUI coordinate basis; TopbarInset is physical.
 -- Convert through the measured GUI inset, then through this root's local origin.
 local inset=GuiService.TopbarInset
 local size=Vector2.new(inset.Width,inset.Height)
 local item=queue:step(dt,function(data)local _,w=measure(data);return Rail.geometry(size.X,size.Y,w,Rail.tappable(data)).fits end)
 if not item then pill.Visible=false;shown=nil;return end
 local tappable=Rail.tappable(item.data)
 local text,width=measure(item.data);local g=Rail.geometry(size.X,size.Y,width,tappable)
 local origin=root.AbsolutePosition
 local guiInset=GuiService:GetGuiInset()
 pill.Position=UDim2.fromOffset(inset.Min.X-guiInset.X-origin.X+g.x,inset.Min.Y-guiInset.Y-origin.Y+g.y);pill.Size=UDim2.fromOffset(g.width,g.height)
 label.Text=text;icon.Text=item.data.icon or(if item.data.amount~=nil then "★"else "✓")
 label.Size=UDim2.new(1,-50-(if tappable then Rail.MoreWidth else 0),1,0);more.Visible=tappable
 pill.Active=tappable;pill.Visible=true
 local age=item.age;local duration=item.data.duration or 3.5
 pill.GroupTransparency=if item.persistent then 0 else 1-math.clamp(math.min(age/.18,(duration+.36-age)/.18),0,1)
 shown=item
end)
return Rail
