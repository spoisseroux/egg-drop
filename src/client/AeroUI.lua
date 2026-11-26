-- The deck's UI reactivity (AERO-JUICE-BRIEF 2 P5, "more digital, more reactive, more moving textures"). Presentation
-- only, on the Toy Shell cards and keys; every effect sits under text at 10% alpha or less, or on a border. Behind the
-- same switch as AeroJuice (Alive "deckjuice") and its AliveBudget / Reduced Motion rules:
--   counters  score and Stars roll up (never down) digit by digit: 250 ms a change, 600 ms at most, a count_blip every
--             60 ms at most. The label keeps the real value in Text (screen readers, specs and layout read it at
--             once); a child twin shows the rolling digits while the label's own text is hidden.
--   caustics  one tiling light-net (scripts/deck_art/build_aero_caustics.py; 512 px = 2 x 2 of the 256 px tile)
--             scrolling 8 px/s at 6% alpha on cards and the well, 3 scrolling at most. EMPTY SLOT until uploaded:
--             CausticsImage = "" makes nothing.
--   glint     a 45-degree white sweep (300 ms, 10% alpha) over a key's face on release, and on a primary key when it
--             appears and every 6 s while it is shown.
--   press     0.94 in 60 ms, back through 1.04 (Kit.pressScale's spring), the menu click 2 semitones up on release.
--   chips     a goal's count pops 1.0, 1.25, 1.0 with a tick when it moves forward.
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local GuiService=game:GetService("GuiService")
local Juice=require(script.Parent.AeroJuice)
local Budget=require(script.Parent.AliveBudget)

local UI={}
UI.Roll=table.freeze({per=.25,max=.6,blip=.06})
UI.Pop=table.freeze({scale=1.25,up=.08,down=.16})
UI.Glint=table.freeze({seconds=.3,alpha=.9,every=6,check=.25})
UI.Press=table.freeze({scale=.94,top=1.04,frequency=6.5,damping=.42,limit=.6})
UI.MenuLift=2^(2/12)
UI.CausticsImage="" -- TODO(upload): rbxassetid of assets/ui/aero-caustics-512.png
UI.Caustics=table.freeze({tile=256,speed=8,alpha=.94,scrolling=3})

local reducedOf=function()return false end
local audio=nil
function UI.reduced()
 local ok,r=pcall(reducedOf)
 return GuiService.ReducedMotionEnabled or(ok and r==true)
end
function UI.allows(feature)return Juice.switch()and Juice.allows(feature,Budget.level(),UI.reduced())end
-- The deck's start (init.client): the menu lift and the counters' blip.
function UI.start(options)
 options=options or {}
 audio=options.audio
 if options.reduced then reducedOf=options.reduced end
 local Audio=require(script.Parent.BoardAudio)
 Audio.MenuLift=function()return if UI.allows("body")then UI.MenuLift else 1 end
end

-- Pure: the rolled value `t` seconds into a roll from `from` to `to` lasting `duration` (ease-out, whole numbers).
function UI.rollValue(from,to,t,duration)
 local u=math.clamp(t/math.max(duration,1e-6),0,1);u=1-(1-u)^3
 return math.floor(from+(to-from)*u+.5)
end
-- Pure: a roll's length when a change lands with `left` seconds of the last still to go.
function UI.rollDuration(left)return math.min(UI.Roll.max,math.max(0,left or 0)+UI.Roll.per)end
-- Pure: does a new value roll (up only, from a known value) or jump?
function UI.rolls(from,to)return type(from)=="number"and type(to)=="number"and to>from end

-- ── Counters ────────────────────────────────────────────────────────────────────────────────────────────────────
local rolls=setmetatable({},{__mode="k"})
local rollLink=nil
local TEXT={"Font","TextSize","TextColor3","TextXAlignment","TextYAlignment","TextStrokeColor3","TextStrokeTransparency","TextScaled","TextWrapped","LineHeight"}
local function twinOf(label,s)
 if s.twin and s.twin.Parent==label then return s.twin end
 local twin=Instance.new("TextLabel");twin.Name="RollDigits";twin.BackgroundTransparency=1;twin.BorderSizePixel=0
 twin.Size=UDim2.fromScale(1,1);twin.Position=UDim2.new();twin.Active=false;twin.Selectable=false;twin.AutoLocalize=false
 twin.Visible=false;twin.Parent=label
 for _,child in ipairs(label:GetChildren())do if child:IsA("UIStroke")then child:Clone().Parent=twin end end
 s.twin=twin
 return twin
end
local function finish(label,s)
 s.active=false;s.shown=s.to
 if s.twin then s.twin.Visible=false end
 if label.TextTransparency==1 then label.TextTransparency=s.restore or 0 end
end
local function stepRolls()
 local now=os.clock();local busy=false
 for label,s in pairs(rolls)do if s.active then
  if not label.Parent then s.active=false
  else
   local t=now-s.start
   local v=UI.rollValue(s.from,s.to,t,s.duration)
   if v~=s.shown then
    s.shown=v;s.twin.Text=s.format(v)
    if audio and now-(s.blipAt or -1)>=UI.Roll.blip then s.blipAt=now;audio:play("count_blip",1.15,.12)end
   end
   if t>=s.duration then finish(label,s)else busy=true end
  end
 end end
 if not busy and rollLink then rollLink:Disconnect();rollLink=nil end
end
-- Call right after `label.Text = format(value)`. The first value is only remembered.
function UI.roll(label,value,format)
 if typeof(label)~="Instance"or type(value)~="number"then return false end
 local s=rolls[label]
 if not s then rolls[label]={last=value,shown=value,active=false,format=format or tostring};return false end
 s.format=format or s.format
 local from=if s.active then s.shown else s.last
 s.last=value
 if not(UI.rolls(from,value)and UI.allows("counters")and label.Parent)then
  if s.active then s.to=value;finish(label,s)end
  return false
 end
 local twin=twinOf(label,s)
 for _,key in ipairs(TEXT)do pcall(function()twin[key]=label[key]end)end
 pcall(function()twin.FontFace=label.FontFace end)
 twin.ZIndex=label.ZIndex
 local left=if s.active then s.duration-(os.clock()-s.start)else 0
 if not s.active then s.restore=label.TextTransparency end
 s.from,s.to,s.start,s.duration,s.active=from,value,os.clock(),UI.rollDuration(left),true
 s.shown=from;twin.Text=s.format(from);twin.TextTransparency=s.restore or 0;twin.Visible=true
 label.TextTransparency=1
 if not rollLink then rollLink=RunService.Heartbeat:Connect(stepRolls)end
 return true
end

-- ── Goal chips ──────────────────────────────────────────────────────────────────────────────────────────────────
-- Pops `node` 1.0 -> 1.25 -> 1.0 (a UIScale named AeroPop; never beside another UIScale) and ticks.
function UI.pop(node)
 if typeof(node)~="Instance"or not node.Parent or not UI.allows("chips")then return false end
 local scale=node:FindFirstChild("AeroPop")
 if not scale then
  if node:FindFirstChildOfClass("UIScale")then return false end
  scale=Instance.new("UIScale");scale.Name="AeroPop";scale.Parent=node
 end
 scale.Scale=1
 local up=TweenService:Create(scale,TweenInfo.new(UI.Pop.up,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=UI.Pop.scale})
 up.Completed:Once(function()TweenService:Create(scale,TweenInfo.new(UI.Pop.down,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1}):Play()end)
 up:Play()
 if audio then audio:play("goal_tick",1.25,.28)end
 return true
end

-- ── Glints ──────────────────────────────────────────────────────────────────────────────────────────────────────
local function sweepOf(face)
 local sweep=face:FindFirstChild("AeroSweep")
 if sweep then return sweep end
 sweep=Instance.new("Frame");sweep.Name="AeroSweep";sweep.BackgroundColor3=Color3.new(1,1,1);sweep.BackgroundTransparency=0
 sweep.BorderSizePixel=0;sweep.Size=UDim2.fromScale(1,1);sweep.Active=false;sweep.Selectable=false;sweep.Visible=false
 sweep.ZIndex=face.ZIndex
 local corner=face:FindFirstChildOfClass("UICorner");if corner then corner:Clone().Parent=sweep end
 local band=Instance.new("UIGradient");band.Name="Band";band.Rotation=45
 band.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.42,1),
  NumberSequenceKeypoint.new(.5,UI.Glint.alpha),NumberSequenceKeypoint.new(.58,1),NumberSequenceKeypoint.new(1,1)})
 band.Offset=Vector2.new(-1,0);band.Parent=sweep
 sweep.Parent=face
 return sweep
end
-- One white sweep across `face` (a key's Fill), under its label.
function UI.sweep(face)
 if typeof(face)~="Instance"or not face.Parent or not UI.allows("glint")then return false end
 local sweep=sweepOf(face);local band=sweep.Band
 band.Offset=Vector2.new(-1,0);sweep.Visible=true
 local tween=TweenService:Create(band,TweenInfo.new(UI.Glint.seconds,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Offset=Vector2.new(1,0)})
 tween.Completed:Once(function()if sweep.Parent then sweep.Visible=false end end)
 tween:Play()
 return true
end
local primaries=setmetatable({},{__mode="k"})
local glintLink,glintAt=nil,0
local function shown(node)
 local n=node
 while n do
  if n:IsA("GuiObject")and not n.Visible then return false end
  if n:IsA("LayerCollector")then return n.Enabled end
  n=n.Parent
 end
 return false
end
local function stepGlints()
 local now=os.clock()
 if now-glintAt<UI.Glint.check then return end
 glintAt=now
 if not UI.allows("glint")then return end
 for button,s in pairs(primaries)do
  if button.Parent then
   local on=shown(button)
   if on and(not s.shown or now-s.at>=UI.Glint.every)then s.at=now;UI.sweep(s.face)end
   s.shown=on
  end
 end
end
-- A primary key sweeps when it appears and every 6 s while it is shown (one shared check, 4 a second).
function UI.watchPrimary(button,face)
 if typeof(button)~="Instance"or typeof(face)~="Instance"then return end
 primaries[button]={face=face,shown=false,at=0}
 if not glintLink then glintLink=RunService.Heartbeat:Connect(stepGlints)end
end
-- The press spec for a key (Kit.pressScale): the aero press while on, else `spec`.
function UI.pressSpec(spec)
 if not UI.allows("press")then return spec end
 return{scale=UI.Press.scale,top=UI.Press.top,frequency=UI.Press.frequency,damping=UI.Press.damping,limit=spec and spec.limit or UI.Press.limit}
end

-- ── Caustics ────────────────────────────────────────────────────────────────────────────────────────────────────
local caustics=setmetatable({},{__mode="k"})
local causticLink=nil
local function stepCaustics(dt)
 local scrolling=0
 local on=UI.allows("caustics")
 for label in pairs(caustics)do
  if label.Parent then
   local visible=on and shown(label)
   label.Visible=on
   if visible and scrolling<UI.Caustics.scrolling then
    scrolling+=1
    local o=(label.ImageRectOffset.X+UI.Caustics.speed*dt)%UI.Caustics.tile
    label.ImageRectOffset=Vector2.new(o,o)
   end
  end
 end
end
-- A light-net on `frame` (a card back or the well), under its text. Nothing while the image slot is empty.
function UI.caustics(frame)
 if UI.CausticsImage==""or typeof(frame)~="Instance"or frame:FindFirstChild("AeroCaustics")then return nil end
 local label=Instance.new("ImageLabel");label.Name="AeroCaustics";label.BackgroundTransparency=1;label.BorderSizePixel=0
 label.Image=UI.CausticsImage;label.ScaleType=Enum.ScaleType.Tile;label.TileSize=UDim2.fromOffset(UI.Caustics.tile,UI.Caustics.tile)
 label.ImageRectSize=Vector2.new(UI.Caustics.tile,UI.Caustics.tile);label.ImageTransparency=UI.Caustics.alpha
 label.Size=UDim2.fromScale(1,1);label.Active=false;label.Selectable=false;label.ZIndex=frame.ZIndex
 local corner=frame:FindFirstChildOfClass("UICorner");if corner then corner:Clone().Parent=label end
 label.Visible=UI.allows("caustics");label.Parent=frame
 caustics[label]=true
 if not causticLink then causticLink=RunService.Heartbeat:Connect(stepCaustics)end
 return label
end
return UI
