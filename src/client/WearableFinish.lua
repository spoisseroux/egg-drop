-- Animated finishes on the Outfit Egg's sparkle picks (ROTATION-BRIEF 1 "Sparkle picks", ARCH-REVIEW-ROTATION 12;
-- Spencer: "animated textures on models for really rare ones"). A legendary row (WearableVariants: finish, finishHexes,
-- `color` = its still mid colour) moves only on a garden pet:
--   shimmer   part.Color eases between the two finishHexes on a 2.4 s sine (aurora: #6FD0F0 <-> #B58CFF)
--   rainbow   the hue turns once in 6 s at S .55, V 1 (pastel, never strobing)
--   sparkle   one ParticleEmitter on the main piece (rate 3, sparkles_main.dds, the Sparkler's recipe), colour Snow
-- Cheap: one shared stepper at 10 Hz for at most MaxParts parts, only pieces of world pets (GardenPetVisual's
-- worldContext) that are in the workspace; ViewportFrame clones (the Wardrobe, card previews, the hatch reveal) keep the
-- still colour and are never stepped (particles do not draw there anyway; cards add their own 2D sparks).
-- Reduced Motion or the game's Motion: Low: the still mid colour, and the sparkle row keeps a static sparkle (it
-- twinkles in place: no speed, no spin, no drift). Never Neon, never a Highlight (wearables never glow at night).
local Finish={}
Finish.Hz=10
Finish.MaxParts=24
Finish.ShimmerPeriod=2.4
Finish.RainbowPeriod=6
Finish.RainbowSaturation=.55
Finish.RainbowValue=1
Finish.SparkleRate=3
Finish.StillSparkleRate=1.5
Finish.SparkleColor="#F4F6FB" -- Snow
Finish.SparkleTexture="rbxasset://textures/particles/sparkles_main.dds"
Finish.Kinds=table.freeze({shimmer=true,rainbow=true,sparkle=true})

local function hex(value,fallback)
 local ok,color=pcall(Color3.fromHex,value)
 return if ok and typeof(color)=="Color3"then color else fallback
end
-- Pure: the row's finish kind, or nil for a still row (every row but the legendary ones).
function Finish.kind(row)
 local kind=type(row)=="table"and row.finish
 return if type(kind)=="string"and Finish.Kinds[kind]then kind else nil
end
-- Pure: the still colour (Reduced Motion, previews, older builds): the row's own `color`.
function Finish.still(row)return hex(type(row)=="table"and row.color,Color3.new(1,1,1))end
-- Pure: does the colour move? Only shimmer and rainbow, and never under reduced motion. Sparkle keeps its colour.
function Finish.moves(row,reduced)
 local kind=Finish.kind(row)
 return(kind=="shimmer"or kind=="rainbow")and reduced~=true
end
-- Pure: the sparkle emitter's mode for this row: "live" (rate 3, drifting), "still" (reduced: in place) or nil (none).
function Finish.sparkle(row,reduced)
 if Finish.kind(row)~="sparkle"then return nil end
 return if reduced==true then "still"else "live"
end
-- Pure: the colour at time `t` (seconds). Shimmer: 0 at a, 1 at b, a smooth sine (never a jump); rainbow: one hue turn
-- per RainbowPeriod at the pastel S and V. Reduced or a still row: the still colour.
-- Pure: the shimmer's blend toward the second hex (0..1) and the rainbow's hue (0..1) at time `t`.
function Finish.blend(t)
 t=if type(t)=="number"and t==t then t else 0
 return .5-.5*math.cos(2*math.pi*t/Finish.ShimmerPeriod)
end
function Finish.hue(t)
 t=if type(t)=="number"and t==t then t else 0
 return(t/Finish.RainbowPeriod)%1
end
function Finish.color(row,t,reduced)
 if not Finish.moves(row,reduced)then return Finish.still(row)end
 if row.finish=="shimmer"then
  local hexes=type(row.finishHexes)=="table"and row.finishHexes or {}
  local a,b=hex(hexes[1],Finish.still(row)),hex(hexes[2],Finish.still(row))
  return a:Lerp(b,Finish.blend(t))
 end
 return Color3.fromHSV(Finish.hue(t),Finish.RainbowSaturation,Finish.RainbowValue)
end
-- Pure: which tracked entries the stepper moves this tick. entry = {row, world (a garden pet's piece), live (in the
-- workspace now)}; a viewport clone (world false) never. At most `cap` (MaxParts), in the order given.
function Finish.pick(entries,cap)
 cap=cap or Finish.MaxParts
 local out={}
 for _,entry in ipairs(entries or {})do
  if #out>=cap then break end
  if entry.world==true and entry.live==true and Finish.kind(entry.row)~=nil then table.insert(out,entry)end
 end
 return out
end

-- Runtime (client). tracked: part -> {row, world, emitter?, mode?}; weak, so a destroyed rig lets go of its parts.
local tracked=setmetatable({},{__mode="k"})
local order={} -- parts in the order they were attached (the cap keeps the first ones)
local connection=nil
local carry=0
local function reducedNow()
 local GuiService=game:GetService("GuiService")
 if GuiService.ReducedMotionEnabled then return true end
 -- The game's own Motion: Low (DeckKit.setReducedEffects, kept by init.client); read lazily, client only.
 local client=script.Parent:FindFirstChild("DeckKit")
 if client then
  local ok,Kit=pcall(require,client)
  if ok and type(Kit)=="table"and Kit.reducedEffects==true then return true end
 end
 return false
end
Finish.reducedNow=reducedNow
local function setEmitter(part,info,mode)
 if info.mode==mode then return end
 info.mode=mode
 if mode==nil then
  if info.emitter then info.emitter:Destroy();info.emitter=nil end
  return
 end
 local e=info.emitter
 if not e then
  e=Instance.new("ParticleEmitter");e.Name="FinishSparkle"
  e.Texture=Finish.SparkleTexture;e.LightEmission=.6;e.LightInfluence=.4;e.ZOffset=.15
  e.Color=ColorSequence.new(hex(Finish.SparkleColor,Color3.new(1,1,1)))
  e.SpreadAngle=Vector2.new(180,180)
  info.emitter=e
 end
 local size=math.max(.05,math.min(part.Size.X,part.Size.Y,part.Size.Z)*.35)
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.3,size),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(1,1)})
 if mode=="live"then
  e.Rate=Finish.SparkleRate;e.Lifetime=NumberRange.new(.5,.9);e.Speed=NumberRange.new(size*.6,size*1.4)
  e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-90,90);e.Acceleration=Vector3.zero
 else
  -- Reduced: a sparkle that stays where it is born (no speed, no spin) and fades.
  e.Rate=Finish.StillSparkleRate;e.Lifetime=NumberRange.new(1.2,1.6);e.Speed=NumberRange.new(0,0)
  e.Rotation=NumberRange.new(0,0);e.RotSpeed=NumberRange.new(0,0);e.Acceleration=Vector3.zero
 end
 e.Enabled=true
 e.Parent=part
end
local function step()
 local reduced=reducedNow()
 local now=os.clock()
 local entries,alive={},{}
 for _,part in ipairs(order)do
  local info=tracked[part]
  if info and part.Parent~=nil then
   table.insert(alive,part)
   table.insert(entries,{part=part,info=info,row=info.row,world=info.world,live=part:IsDescendantOf(workspace)})
  end
 end
 order=alive
 if #order==0 and connection then connection:Disconnect();connection=nil;return end
 for _,entry in ipairs(Finish.pick(entries,Finish.MaxParts))do
  local part,info=entry.part,entry.info
  if Finish.moves(info.row,reduced)then
   part.Color=Finish.color(info.row,now,false);info.still=false
  elseif not info.still then
   part.Color=Finish.still(info.row);info.still=true
  end
  setEmitter(part,info,Finish.sparkle(info.row,reduced))
 end
end
local function ensure()
 if connection then return end
 local RunService=game:GetService("RunService")
 if not RunService:IsClient()then return end
 carry=0
 connection=RunService.Heartbeat:Connect(function(dt)
  carry+=dt
  if carry<1/Finish.Hz then return end
  carry=0
  step()
 end)
end
-- PetAttachments.build: one main piece of a finish row was made. `world`: the visual is a garden pet (worldContext).
-- A viewport clone is left at its still colour and never tracked.
function Finish.attach(part,row,world)
 if typeof(part)~="Instance"or Finish.kind(row)==nil then return false end
 part.Color=Finish.still(row)
 if world~=true then return false end
 if tracked[part]==nil then table.insert(order,part)end
 tracked[part]={row=row,world=true,still=true}
 ensure()
 return true
end
function Finish.count()return #order end
Finish.step=step
return Finish
