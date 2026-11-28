-- A forgiving click/tap target for the local player's own garden pet (Spencer
-- 2026-11-13: "make it easier to click the pet"). One invisible box around the
-- whole rig (its pose bounds x Margin, at least MinSize studs a side) carries the
-- pet's ClickDetector with a longer reach than the ProximityPrompt. The box lives
-- inside the pet's model, so it goes when the pet goes; it is anchored and moved
-- with the pose bounds (writes only on change), never collides or touches, and
-- every garden/path raycast either excludes the pet model or respects CanCollide.
-- The pose bounds come from the rig pieces only, so the box never feeds back into
-- framing. Only RoomView's own pet gets one: visitor pets are never pettable.
local Bounds=require(script.Parent.PetRigBounds)
local Target={}
Target.Name="PetClickTarget"
Target.Margin=1.3
Target.MinSize=3
Target.Reach=16
Target.Quantum=.05 -- studs: smaller moves are not written

function Target.attach(pet)
 local part=Instance.new("Part")
 part.Name=Target.Name;part.Transparency=1;part.CastShadow=false
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=true;part.Massless=true
 part.Locked=true;part.Material=Enum.Material.SmoothPlastic
 part:SetAttribute("PetClickTarget",true)
 local click=Instance.new("ClickDetector")
 click.Name="PetClick";click.MaxActivationDistance=0;click.Parent=part
 local handle={part=part,click=click,pet=pet}
 Target.sync(handle)
 part.Parent=pet.model
 return handle
end

-- QA v685 W1: a forgiving screen-space tap. The box above is still hard to hit at low
-- angles and from far away, so a tap or click that lands within a radius of the pet's
-- projected centre counts too. The radius is the box's on-screen size plus a margin,
-- between TapMin and TapMax px. It follows the ClickDetector's gate: when the detector
-- is off (MaxActivationDistance 0) or the avatar is out of its reach, nothing happens.
Target.TapMin=56
Target.TapMax=140
Target.TapMargin=1.25
-- Pure: the tap radius in px for a box that projects to `px` px of radius.
function Target.tapRadius(px)return math.clamp((px or 0)*Target.TapMargin,Target.TapMin,Target.TapMax)end
-- Pure: does a tap at `tap` (Vector2) hit a pet projected at `centre` (Vector2)?
function Target.tapHits(tap,centre,px)return(tap-centre).Magnitude<=Target.tapRadius(px)end
-- Pure (beta 44 note 18): is a GUI object drawn at all (a fill, an image or text one can see)? A clear frame or button
-- "handles" a click without anyone seeing it. Unreadable: drawn (the safe side).
function Target.drawn(object)
 local ok,result=pcall(function()
  if object.Visible==false then return false end
  if object:IsA("ViewportFrame")or object:IsA("VideoFrame")then return true end
  if object.BackgroundTransparency<1 then return true end
  if(object:IsA("ImageLabel")or object:IsA("ImageButton"))and object.Image~=""and object.ImageTransparency<1 then return true end
  if(object:IsA("TextLabel")or object:IsA("TextButton")or object:IsA("TextBox"))and object.Text~=""and object.TextTransparency<1 then return true end
  return false
 end)
 return not ok or result==true
end
-- Pure (beta 44 note 18): a tap the engine says a GUI took (`processed`) still reaches the pet when every one of the
-- player's screen GUI objects under it (`objects`) is see-through. None at all means a world GUI (a bubble's
-- billboard) or the core GUI took it: that tap is theirs.
function Target.passThrough(processed,objects)
 if not processed then return true end
 if type(objects)~="table"or #objects==0 then return false end
 for _,object in ipairs(objects)do if Target.drawn(object)then return false end end
 return true
end
-- `onRefused(gate)` (optional): a tap on the pet that was refused, by gate name (RoomView's Studio PetClickRefused).
function Target.watch(handle,onTap,onRefused)
 local UserInputService=game:GetService("UserInputService")
 local function refuse(gate)if onRefused then pcall(onRefused,gate)end end
 local function guiAt(x,y)
  local player=game:GetService("Players").LocalPlayer
  local gui=player and player:FindFirstChildOfClass("PlayerGui")
  if not gui then return {}end
  local ok,list=pcall(gui.GetGuiObjectsAtPosition,gui,x,y)
  return if ok and type(list)=="table"then list else {}
 end
 local function try(x,y,processed,gx,gy)
  if not handle.part.Parent then return end
  local camera=workspace.CurrentCamera
  local player=game:GetService("Players").LocalPlayer
  local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local centre=handle.part.Position
  if not camera or not root then return end
  local point,onScreen=camera:WorldToViewportPoint(centre)
  if not onScreen or point.Z<=0 then return end
  local px=handle.part.Size.Magnitude/2/point.Z*(camera.ViewportSize.Y/2)/math.tan(math.rad(camera.FieldOfView/2))
  if not Target.tapHits(Vector2.new(x,y),Vector2.new(point.X,point.Y),px)then return end
  -- On the pet from here on: every refusal is named.
  if processed and not Target.passThrough(true,guiAt(gx,gy))then return refuse("GuiOnTop")end
  if handle.click.MaxActivationDistance<=0 then return refuse("ClickOff")end
  if(root.Position-centre).Magnitude>handle.click.MaxActivationDistance then return refuse("TooFar")end
  onTap()
 end
 local touch=UserInputService.TouchTapInWorld:Connect(function(position,processed)try(position.X,position.Y,processed,position.X,position.Y)end)
 local mouse=UserInputService.InputBegan:Connect(function(input,processed)
  if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
  local at=UserInputService:GetMouseLocation()
  -- GUI space for the GUI query (the mouse location less the top bar inset), viewport space for the projection.
  local inset=game:GetService("GuiService"):GetGuiInset()
  try(at.X,at.Y,processed,at.X-inset.X,at.Y-inset.Y)
 end)
 handle.part.Destroying:Connect(function()touch:Disconnect();mouse:Disconnect()end)
end

local function snap(value)return math.floor(value/Target.Quantum+.5)*Target.Quantum end
-- Pure: the box size for rig bounds of `size`.
function Target.boxSize(size)
 return Vector3.new(math.max(Target.MinSize,size.X*Target.Margin),math.max(Target.MinSize,size.Y*Target.Margin),math.max(Target.MinSize,size.Z*Target.Margin))
end
-- Follows the pet's current pose bounds; writes CFrame/Size only when they changed.
function Target.sync(handle)
 local pet=handle.pet
 if not pet or pet.destroyed or not handle.part.Parent and handle.synced then return end
 local frame,size=Bounds.get(pet)
 if not frame or not size then return end
 local p=frame.Position
 local x,y,z=snap(p.X),snap(p.Y),snap(p.Z)
 local sx,sy,sz=snap(size.X),snap(size.Y),snap(size.Z)
 if handle.x~=x or handle.y~=y or handle.z~=z then
  handle.x,handle.y,handle.z=x,y,z
  handle.part.CFrame=CFrame.new(x,y,z)
 end
 if handle.sx~=sx or handle.sy~=sy or handle.sz~=sz then
  handle.sx,handle.sy,handle.sz=sx,sy,sz
  handle.part.Size=Target.boxSize(Vector3.new(sx,sy,sz))
 end
 handle.synced=true
end
function Target.destroy(handle)
 if handle and handle.part then handle.part:Destroy()end
end
return Target
