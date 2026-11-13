-- Your pet peeks in (UI personality T4, UI-PERSONALITY-SCOPE-2026-11-13). The
-- equipped pet, in 3D with its hue, charm and wearables (the viewport pet of
-- CompanionsHub / WardrobeShop, not the PetPortrait sprite), looks over one edge
-- per screen: up into the egg preview (Hatch eggs), over the tab bar (Deck style),
-- over the come-back strip (results: a hop when the Star count lands, a droop then
-- a perk up on a miss), and beside the empty-state lines (T12).
--
-- One clip frame and one ViewportFrame for the whole session, reparented between
-- hosts and never rebuilt per open (only if a host destroyed it while shown). The
-- clip is cut away from every rect a host asks it to avoid (wallet, text) and the
-- peek hides when its slot is under 64 px. Never focusable, never takes input.
-- Off on phones (hosts pass compact=true) and with no pet (fresh save). Reduced
-- Motion: a still pet (posed once, no blink, hop or droop).
--
-- The shared clock: one RenderStepped connection, only while something subscribes
-- (the shown peek, the results Star face). Subscribers live in a fixed array, so a
-- tick allocates nothing; the pet's own blink (every 3.2 to 5.4 s, PetIdleMotion)
-- and the Star blink both run on it.
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Pets=require(Shared.PetCatalog)

local Peek={}
Peek.MinSlot=64 -- hidden when the slot (after clipping) is under 64 px tall
Peek.MinWidth=48
Peek.Gap=6 -- clearance kept from every avoided rect
Peek.Shown=.6 -- share of the pet's viewport above the edge
Peek.Headroom=.85 -- the shown part fills at most 85% of the slot height (hop room)
Peek.MaxSize=124
Peek.HopTime=.45
Peek.DroopIn,Peek.DroopHold,Peek.DroopOut=.25,.9,.4

-- ── Shared clock ─────────────────────────────────────────────────────────────
local subscribers,subscriberKeys={},{}
local clockConnection=nil
local lastTick=0
local function tick()
 local now=os.clock()
 local dt=math.min(.1,now-lastTick);lastTick=now
 for index=#subscribers,1,-1 do
  local fn=subscribers[index]
  if fn then fn(now,dt)end
 end
end
-- Run `fn(now, dt)` every frame until Peek.unsubscribe(key).
function Peek.subscribe(key,fn)
 if subscriberKeys[key]then Peek.unsubscribe(key)end
 table.insert(subscribers,fn);subscriberKeys[key]=fn
 if not clockConnection then lastTick=os.clock();clockConnection=RunService.RenderStepped:Connect(tick)end
end
function Peek.unsubscribe(key)
 local fn=subscriberKeys[key];if not fn then return end
 subscriberKeys[key]=nil
 local at=table.find(subscribers,fn);if at then table.remove(subscribers,at)end
 if #subscribers==0 and clockConnection then clockConnection:Disconnect();clockConnection=nil end
end
function Peek.clockRunning()return clockConnection~=nil end
function Peek.isSubscribed(key)return subscriberKeys[key]~=nil end

-- ── Pure geometry (scripts/PetPeek.spec.lua) ────────────────────────────────
local function overlaps(a,b)
 return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
end
Peek.overlaps=overlaps
-- The slot {x,y,w,h} cut away from every rect in `avoid` (plus `gap`). For each rect
-- it overlaps, one cut: from the right, the left or the top (the bottom is the edge
-- the pet peeks over, so it never moves); a cut that still fits a peek wins, then
-- the one that keeps the most area.
function Peek.clip(slot,avoid,gap)
 gap=gap or Peek.Gap
 local r={x=slot.x,y=slot.y,w=slot.w,h=slot.h}
 for _,a in ipairs(avoid or {})do
  local grown={x=a.x-gap,y=a.y-gap,w=a.w+gap*2,h=a.h+gap*2}
  if r.w>0 and r.h>0 and overlaps(r,grown)then
   local right=grown.x-r.x -- keep [r.x, grown.x)
   local left=r.x+r.w-(grown.x+grown.w) -- keep [grown.x+grown.w, r.x+r.w)
   local top=r.y+r.h-(grown.y+grown.h) -- keep [grown.y+grown.h, r.y+r.h)
   -- A cut that still fits a peek beats a bigger one that does not.
   local function score(w,h)
    if w<=0 or h<=0 then return 0 end
    return w*h+(if h>=Peek.MinSlot and w>=Peek.MinWidth then 1e9 else 0)
   end
   local best,kind=score(right,r.h),"right"
   if score(left,r.h)>best then best,kind=score(left,r.h),"left"end
   if score(r.w,top)>best then best,kind=score(r.w,top),"top"end
   if best<=0 then r.w,r.h=0,0
   elseif kind=="right"then r.w=right
   elseif kind=="left"then r.x,r.w=grown.x+grown.w,left
   else r.y,r.h=grown.y+grown.h,top end
  end
 end
 return r
end
function Peek.fits(rect)return rect~=nil and rect.h>=Peek.MinSlot and rect.w>=Peek.MinWidth end
-- The pet's square viewport inside a clip of w x h: the top `Shown` share sits
-- above the bottom edge. align: "right" (default), "left" or "center".
function Peek.place(w,h,align)
 local size=math.floor(math.min(w,Peek.MaxSize,h*Peek.Headroom/Peek.Shown))
 local x=if align=="left"then 0 elseif align=="center"then math.floor((w-size)/2)else w-size
 return x,math.floor(h-size*Peek.Shown),size
end

-- ── Source (init.client.lua): returns petId, appearance, or nil for no pet ──
local source=nil
function Peek.setSource(fn)source=fn end
function Peek.getSource()return source end
function Peek.current()
 if not source then return nil end
 local ok,petId,appearance=pcall(source)
 if not ok or type(petId)~="string"or not Pets.byId[petId]then return nil end
 if type(appearance)~="table"then appearance={}end
 return petId,appearance
end
-- The equipped pet's name for the empty-state lines, or nil (no pet).
function Peek.petName()
 local petId=Peek.current()
 local pet=petId and Pets.byId[petId]
 return pet and pet.name or nil
end

-- ── The one cached peek ───────────────────────────────────────────────────────
local state={host=nil,shown=false,dead=false}
Peek.state=state

local function reduced()return GuiService.ReducedMotionEnabled end

local function build()
 local clip=Instance.new("Frame")
 clip.Name="PetPeek";clip.BackgroundTransparency=1;clip.BorderSizePixel=0;clip.ClipsDescendants=true
 clip.Active=false;clip.Selectable=false;clip.Interactable=false;clip.Visible=false
 clip:SetAttribute("PetPeek",true)
 local viewport=Instance.new("ViewportFrame")
 viewport.Name="PeekViewport";viewport.BackgroundTransparency=1;viewport.BorderSizePixel=0
 viewport.Active=false;viewport.Selectable=false;viewport.Interactable=false
 viewport.Ambient=Color3.fromRGB(175,184,183);viewport.LightColor=Color3.fromRGB(255,250,231);viewport.LightDirection=Vector3.new(-1,-1.4,-3)
 viewport.Parent=clip
 local world=Instance.new("WorldModel");world.Parent=viewport
 local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport
 viewport.CurrentCamera=camera
 -- Fires for the clip itself or any ancestor being destroyed: the next show rebuilds.
 clip.Destroying:Connect(function()if state.clip==clip then state.clipDead=true end end)
 if state.visual and not state.visual.destroyed then pcall(function()state.visual:destroy()end)end
 state.visual,state.visualPet=nil,nil
 state.clip,state.viewport,state.world,state.camera,state.clipDead=clip,viewport,world,camera,false
 state.cameraKey=nil
 state.builds=(state.builds or 0)+1
end
local function alive()return state.clip~=nil and not state.clipDead end

local function fitCamera()
 local v=state.visual;if not v or v.destroyed then return end
 local key=state.size*1000+(v.rigRevision or 0)
 if state.cameraKey==key then return end
 state.cameraKey=key
 local Bounds=require(script.Parent.PetRigBounds)
 local box,size=Bounds.get(v)
 local half=math.tan(math.rad(state.camera.FieldOfView/2))
 local distance=math.max(size.Y*.5/half,size.X*.5/half)+size.Z*.5+.25
 local centre=box.Position
 state.camera.CFrame=CFrame.lookAt(centre+Vector3.new(0,size.Y*.08,distance*1.05),centre)
end

local function setOffset(dy)
 dy=math.floor(dy+.5)
 if state.offset==dy then return end
 state.offset=dy
 state.viewport.Position=UDim2.fromOffset(state.baseX,state.baseY+dy)
end

local function step(now,dt)
 if not state.shown then return end
 local v=state.visual
 if not v or v.destroyed then return end
 v.reducedEffects=reduced()
 v.cosmeticTime=now;v:update(dt)
 if v.rigRevision~=state.rigRevision then state.rigRevision=v.rigRevision;fitCamera()end
 -- 2D hop (count landed) and droop-then-perk-up (a miss), on the viewport offset.
 local dy=0
 if state.hopAt then
  local age=now-state.hopAt
  if age<Peek.HopTime then dy=-math.sin(age/Peek.HopTime*math.pi)*state.size*.12 else state.hopAt=nil end
 elseif state.droopAt then
  local age=now-state.droopAt;local depth=state.size*.2
  if age<Peek.DroopIn then dy=depth*(age/Peek.DroopIn)
  elseif age<Peek.DroopIn+Peek.DroopHold then dy=depth
  elseif age<Peek.DroopIn+Peek.DroopHold+Peek.DroopOut then
   local t=(age-Peek.DroopIn-Peek.DroopHold)/Peek.DroopOut
   dy=depth*(1-t)-math.sin(t*math.pi)*state.size*.05
  else state.droopAt=nil end
 end
 setOffset(dy)
end

local function setActive(on)
 if on and not reduced()then Peek.subscribe("PetPeek",step)else Peek.unsubscribe("PetPeek")end
end

local function releaseHostWatch()
 if state.hostWatch then state.hostWatch:Disconnect();state.hostWatch=nil end
end

-- Show the peek in `host` (a GuiObject). options: rect {x,y,w,h} in the host's
-- offset units (the slot; its bottom is the edge the pet peeks over), avoid {rects}
-- (wallet, text) in the same units, align, z (ZIndex, default host.ZIndex+2),
-- compact (true on phones: no peek). Returns true when the peek is shown.
function Peek.show(host,options)
 options=options or {}
 if state.dead or not host then return false end
 local petId,appearance=Peek.current()
 local rect=options.rect and Peek.clip(options.rect,options.avoid,options.gap)
 if options.compact or not petId or not Peek.fits(rect)then Peek.hide(host);return false end
 if not alive()then build()end
 local clip,viewport=state.clip,state.viewport
 if state.host~=host then
  if state.host then Peek.hide(state.host)end
  releaseHostWatch()
  state.host=host;state.hopAt,state.droopAt=nil,nil
  -- If the host is destroyed while shown, take the clip out first (reparenting can
  -- fail mid-destroy; the next show rebuilds then).
  state.hostWatch=host.Destroying:Connect(function()
   if state.host==host then pcall(function()clip.Parent=nil end);state.host=nil;state.shown=false;setActive(false)end
  end)
 end
 clip.Position=UDim2.fromOffset(rect.x,rect.y);clip.Size=UDim2.fromOffset(rect.w,rect.h)
 clip.ZIndex=options.z or host.ZIndex+2;viewport.ZIndex=clip.ZIndex+1
 local x,y,size=Peek.place(rect.w,rect.h,options.align)
 state.baseX,state.baseY,state.size,state.offset=x,y,size,0
 viewport.Size=UDim2.fromOffset(size,size);viewport.Position=UDim2.fromOffset(x,y)
 clip:SetAttribute("PeekHost",options.key or host.Name)
 clip.Parent=host;clip.Visible=true
 -- The pet: rebuilt only when the equipped pet changes; otherwise re-dressed.
 local v=state.visual
 if not v or v.destroyed or state.visualPet~=petId then
  if v and not v.destroyed then v:destroy()end
  v=require(script.Parent.PetFactory).new(state.world,Vector3.zero,Pets.byId[petId],nil,appearance)
  state.visual,state.visualPet,state.cameraKey=v,petId,nil
 elseif v.applyAppearance and appearance then v:applyAppearance(appearance)end
 v.yaw=-.12;v.reducedEffects=reduced();v.cosmeticTime=os.clock()
 v.poseDirty=true;v:update(0)
 state.rigRevision=v.rigRevision
 fitCamera()
 state.shown=true
 setActive(true)
 return true
end
-- Hide (and take the clip out of) `host`; nil hides wherever it is.
function Peek.hide(host)
 if host~=nil and state.host~=host then return end
 state.shown=false;state.hopAt,state.droopAt=nil,nil
 setActive(false)
 releaseHostWatch()
 if state.clip then pcall(function()state.clip.Visible=false;state.clip.Parent=nil end)end
 if state.visual and not state.visual.destroyed then require(script.Parent.PetReactions).clear(state.visual)end
 state.host=nil
end
function Peek.isShown(host)return state.shown and(host==nil or state.host==host)end
-- Results: the Star count landed. A happy hop (cut under Reduced Motion).
function Peek.hop()
 if not state.shown or reduced()then return false end
 state.droopAt=nil;state.hopAt=os.clock()
 local v=state.visual;if v and not v.destroyed then require(script.Parent.PetReactions).trigger(v,"cheer",os.clock())end
 return true
end
-- Results: a miss. Droops, then perks back up (cut under Reduced Motion).
function Peek.droop()
 if not state.shown or reduced()then return false end
 state.hopAt=nil;state.droopAt=os.clock()
 local v=state.visual;if v and not v.destroyed then require(script.Parent.PetReactions).trigger(v,"loss",os.clock())end
 return true
end
-- Session end: everything goes, the clock stops and later shows do nothing.
function Peek.destroy()
 Peek.hide(nil)
 if state.visual and not state.visual.destroyed then state.visual:destroy()end
 if state.clip then pcall(function()state.clip:Destroy()end)end
 state.visual,state.clip,state.viewport,state.world,state.camera=nil,nil,nil,nil,nil
 state.dead=true
 for key in pairs(subscriberKeys)do Peek.unsubscribe(key)end
end
-- Specs only: start over (a fresh cache, a live module).
function Peek._reset()
 Peek.destroy()
 state.dead=false;state.builds=0;source=nil
end
return Peek
