-- Soft edges on scrolling lists (Spencer 2026-11-20: "can the scrollable bar at the top with the
-- category fade out at the edges instead of an abrupt cut? Same with any other places, and
-- vertical scrolls, but very small").
-- Every ScrollingFrame in this game's ScreenGuis gets a Size px fade on each edge where there is
-- more to scroll that way (none at the start of a list, none when nothing scrolls). The fade is
-- a thin strip painted in the colour of the surface behind the list, ramping from opaque at the
-- edge to clear: no CanvasGroup, no reparenting, so layouts and input are untouched. A list
-- opts out with the attribute NoEdgeFade = true (the notification row has its own fades).
local Fades={}
Fades.Size=10
Fades.Skip=table.freeze({Chat=true,BubbleChat=true,Freecam=true,EggDropNotificationRail=true})

local tracked=setmetatable({},{__mode="k"})

-- Pure: which edges show for one axis. canvas / window: content and view length; at: scroll
-- position. Returns (start, finish).
function Fades.edges(canvas,window,at)
 if canvas<=window+1 then return false,false end
 return at>1,at<canvas-window-1
end

-- The colour of the first mostly opaque surface behind `object` (nil when none).
function Fades.surface(object)
 local node=object.Parent
 while node and not node:IsA("LayerCollector")do
  if node:IsA("GuiObject")and node.BackgroundTransparency<=.25 then return node.BackgroundColor3 end
  node=node.Parent
 end
 return nil
end

local function strip(holder,name,rotation,anchor,position,size)
 local f=Instance.new("Frame")
 f.Name=name;f.BorderSizePixel=0;f.BackgroundColor3=Color3.new(1,1,1);f.BackgroundTransparency=0
 f.AnchorPoint=anchor;f.Position=position;f.Size=size;f.Active=false;f.Visible=false;f.ZIndex=holder.ZIndex
 pcall(function()f.Interactable=false end)
 local g=Instance.new("UIGradient")
 g.Rotation=rotation
 g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
 g.Parent=f
 f.Parent=holder
 return f
end

function Fades.attach(scroll)
 if tracked[scroll]or not scroll:IsA("ScrollingFrame")or scroll:GetAttribute("NoEdgeFade")==true then return nil end
 local parent=scroll.Parent
 if not parent or not parent:IsA("GuiBase2d")then return nil end
 -- A layout in the parent would place the fade strip as one of its items.
 if parent:FindFirstChildWhichIsA("UIGridStyleLayout")then return nil end
 local gui=scroll:FindFirstAncestorWhichIsA("LayerCollector")
 if gui and Fades.Skip[gui.Name]then return nil end
 local holder=Instance.new("Frame")
 holder.Name=scroll.Name.."EdgeFade";holder.BackgroundTransparency=1;holder.BorderSizePixel=0;holder.Active=false
 pcall(function()holder.Interactable=false end)
 local n=Fades.Size
 local left=strip(holder,"Left",0,Vector2.new(0,0),UDim2.fromScale(0,0),UDim2.new(0,n,1,0))
 local right=strip(holder,"Right",180,Vector2.new(1,0),UDim2.fromScale(1,0),UDim2.new(0,n,1,0))
 local top=strip(holder,"Top",90,Vector2.new(0,0),UDim2.fromScale(0,0),UDim2.new(1,0,0,n))
 local bottom=strip(holder,"Bottom",-90,Vector2.new(0,1),UDim2.fromScale(0,1),UDim2.new(1,0,0,n))
 local record={holder=holder,links={}}
 tracked[scroll]=record
 local function place()
  holder.AnchorPoint=scroll.AnchorPoint;holder.Position=scroll.Position;holder.Size=scroll.Size
  -- +1: just over the list (Sibling ordering), never over cards a screen opens above it.
  local laidOut=scroll.Parent~=nil and scroll.Parent:FindFirstChildWhichIsA("UIGridStyleLayout")~=nil
  holder.ZIndex=scroll.ZIndex+1;holder.Visible=scroll.Visible and not laidOut;holder.Rotation=scroll.Rotation
  for _,f in ipairs({left,right,top,bottom})do f.ZIndex=holder.ZIndex end
  if holder.Parent~=scroll.Parent and not laidOut then holder.Parent=scroll.Parent end
 end
 local function paint()
  if not scroll.Parent then return end
  local color=Fades.surface(scroll)
  local canvas,window,at=scroll.AbsoluteCanvasSize,scroll.AbsoluteWindowSize,scroll.CanvasPosition
  local dir=scroll.ScrollingDirection
  local x=dir~=Enum.ScrollingDirection.Y
  local y=dir~=Enum.ScrollingDirection.X
  local l,r=false,false
  local t,b=false,false
  if x then l,r=Fades.edges(canvas.X,window.X,at.X)end
  if y then t,b=Fades.edges(canvas.Y,window.Y,at.Y)end
  if not color then l,r,t,b=false,false,false,false end
  for f,on in pairs({[left]=l,[right]=r,[top]=t,[bottom]=b})do
   f.Visible=on
   if on and f.BackgroundColor3~=color then f.BackgroundColor3=color end
  end
 end
 place();paint()
 local function link(signal,fn)table.insert(record.links,signal:Connect(fn))end
 for _,prop in ipairs({"Position","Size","AnchorPoint","Visible","ZIndex","Parent","Rotation"})do link(scroll:GetPropertyChangedSignal(prop),function()place();paint()end)end
 for _,prop in ipairs({"CanvasPosition","AbsoluteCanvasSize","AbsoluteWindowSize","ScrollingDirection"})do link(scroll:GetPropertyChangedSignal(prop),paint)end
 link(scroll.Destroying,function()
  for _,c in ipairs(record.links)do c:Disconnect()end
  tracked[scroll]=nil;holder:Destroy()
 end)
 return record
end

-- Watches a PlayerGui: every ScrollingFrame already there and every one added later.
function Fades.start(playerGui)
 for _,d in ipairs(playerGui:GetDescendants())do if d:IsA("ScrollingFrame")then Fades.attach(d)end end
 return playerGui.DescendantAdded:Connect(function(d)
  if d:IsA("ScrollingFrame")then task.defer(function()if d.Parent then Fades.attach(d)end end)end
 end)
end

return Fades
