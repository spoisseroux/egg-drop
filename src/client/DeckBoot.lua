-- The Pocket Deck boot (UI-SPEC-2026-11-12 section 6, assets/deck/boot/boot-timing.json).
-- Two sprite sheets share every frame rect: the fixed art underneath and the
-- ink layer tinted with the plate accent. One clock drives the frames so a slow
-- frame cannot stretch the boot. Any input from 150 ms skips to the end.
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Assets=require(script.Parent.DeckAssets)
local Boot={}
Boot.__index=Boot

Boot.TotalMs=1670
Boot.SkipFromMs=150
Boot.FrameSize=Vector2.new(212,152)
Boot.Columns=4
-- Frame start times (ms), frames 0..23.
Boot.Starts={0,80,130,180,230,280,330,390,450,510,580,640,710,760,810,870,920,980,1050,1120,1190,1260,1510,1590}
Boot.Sounds={{cue="deck_boot",atMs=810}}
Boot.Reduced={frame=21,holdMs=400}

-- Pure: the frame index (0-based) showing at `ms`, or nil once the boot is over.
function Boot.frameAt(ms)
 if ms<0 or ms>=Boot.TotalMs then return nil end
 local index=0
 for i,start in ipairs(Boot.Starts)do if ms>=start then index=i-1 else break end end
 return index
end
function Boot.rect(index)
 local size=Boot.FrameSize
 return Vector2.new((index%Boot.Columns)*size.X,math.floor(index/Boot.Columns)*size.Y),size
end
-- Pure: may this input skip a boot that has run for `ms`?
function Boot.canSkip(ms)return ms>=Boot.SkipFromMs end

local skipInputs={[Enum.UserInputType.Keyboard]=true,[Enum.UserInputType.MouseButton1]=true,[Enum.UserInputType.MouseButton2]=true,
 [Enum.UserInputType.Touch]=true,[Enum.UserInputType.Gamepad1]=true,[Enum.UserInputType.Gamepad2]=true,[Enum.UserInputType.Gamepad3]=true,[Enum.UserInputType.Gamepad4]=true}
local sticks={[Enum.KeyCode.Thumbstick1]=true,[Enum.KeyCode.Thumbstick2]=true}

-- host: a clipping Frame at the LCD rect, above every LCD layer and below the glare.
function Boot.new(host,options)
 options=options or {}
 local self=setmetatable({host=host,audio=options.audio,clock=options.clock or os.clock,playing=false,epoch=0,accent=Color3.fromHex("#76F6B0")},Boot)
 local function sheet(name,image,z)
  local label=Instance.new("ImageLabel")
  label.Name,label.Image,label.BackgroundTransparency,label.Size,label.ZIndex=name,image,1,UDim2.fromScale(1,1),z
  label.ResampleMode=Enum.ResamplerMode.Pixelated;label.ImageRectSize=Boot.FrameSize;label.Active=false
  label.Parent=host;return label
 end
 host.BackgroundColor3=Color3.new(0,0,0);host.BackgroundTransparency=0;host.Visible=false
 self.fixed=sheet("BootFixed",Assets.Boot.fixed,host.ZIndex+1)
 self.ink=sheet("BootInk",Assets.Boot.ink,host.ZIndex+2)
 host:SetAttribute("BootFrame",-1)
 return self
end

function Boot:setAccent(color)self.accent=color;self.ink.ImageColor3=color end

function Boot:show(index)
 local offset,size=Boot.rect(index)
 self.fixed.ImageRectOffset,self.fixed.ImageRectSize=offset,size
 self.ink.ImageRectOffset,self.ink.ImageRectSize=offset,size
 self.host:SetAttribute("BootFrame",index)
end

function Boot:elapsedMs()return if self.startedAt then (self.clock()-self.startedAt)*1000 else 0 end

function Boot:cue(name)
 if self.audio and self.audio.play then self.audio:play(name,1,.72)end
end

-- Ends the boot now. `skipped` fades deck_boot out over 60 ms. `ended` is the boot
-- reaching its own end: with the `linger` play option the last frame then stays up for
-- Boot:fade to take over (QA v735 D2).
function Boot:finish(skipped,ended)
 if not self.playing then return false end
 self.playing=false;self.epoch+=1
 if self.connection then self.connection:Disconnect();self.connection=nil end
 if self.inputConnection then self.inputConnection:Disconnect();self.inputConnection=nil end
 if skipped and self.audio and self.audio.fadeCue then self.audio:fadeCue("deck_boot",.06)end
 self.skipped=skipped==true
 self.host.Visible=ended==true and self.linger==true;self.host:SetAttribute("BootFrame",-1)
 self.host:SetAttribute("BootSkipped",skipped==true)
 local done=self.done;self.done=nil
 if done then done(skipped==true)end
 return true
end

-- Any button, key or tap from 150 ms. Returns true when it ended the boot.
function Boot:skip()
 if not self.playing or not Boot.canSkip(self:elapsedMs())then return false end
 return self:finish(true)
end

-- QA v735 D2: the dark screen before the power-on (the handheld is still rising).
function Boot:hold(color)
 if self.playing then return end
 self.fadeEpoch=(self.fadeEpoch or 0)+1
 self.host.BackgroundColor3=color or Color3.new(0,0,0)
 self.host.BackgroundTransparency=0;self.fixed.ImageTransparency=1;self.ink.ImageTransparency=1
 self.held=true;self.host.Visible=true
end
function Boot:release()
 if not self.held then return end
 self.held=false;self.fixed.ImageTransparency=0;self.ink.ImageTransparency=0
 self.host.BackgroundColor3=Color3.new(0,0,0)
 if not self.playing then self.host.Visible=false end
end
-- After the last frame: the black screen fades off the lit HUD instead of cutting to it.
-- Yields for `seconds`; a new play, a hold or `owns() == false` ends it at once.
function Boot:fade(seconds,owns)
 if self.playing then return false end
 self.fadeEpoch=(self.fadeEpoch or 0)+1;local epoch=self.fadeEpoch
 local host=self.host
 -- The last frame and the black behind it fade together.
 host.BackgroundTransparency=0;host.Visible=true
 local started=self.clock()
 while self.fadeEpoch==epoch and not self.playing and(not owns or owns())do
  local t=math.clamp((self.clock()-started)/seconds,0,1)
  local e=t*t*(3-2*t)
  host.BackgroundTransparency=e;self.fixed.ImageTransparency=e;self.ink.ImageTransparency=e
  if t>=1 then break end
  RunService.Heartbeat:Wait()
 end
 if self.fadeEpoch~=epoch then return false end
 if not self.playing then host.Visible=false end
 host.BackgroundTransparency=0;self.fixed.ImageTransparency=0;self.ink.ImageTransparency=0
 return true
end

-- options: reduced (bool), owns() -> bool (route ownership), done(skipped),
-- noSkip (bool): inputs do not end it (the deck's own power-on, QA v735 D2).
function Boot:play(options)
 options=options or {}
 if self.playing then self:finish(false)end
 self.fadeEpoch=(self.fadeEpoch or 0)+1;self.held=false;self.linger=options.linger==true
 self.host.BackgroundColor3=Color3.new(0,0,0);self.host.BackgroundTransparency=0;self.fixed.ImageTransparency=0;self.ink.ImageTransparency=0
 self.playing=true;self.epoch+=1;local epoch=self.epoch
 self.done=options.done;self.startedAt=self.clock();self.skipped=false
 local maxMs=if type(options.maxMs)=="number"then math.clamp(options.maxMs,400,Boot.TotalMs)elseif self.maxMs then self.maxMs else Boot.TotalMs
 self.host.Visible=true
 self.host:SetAttribute("Boots",(self.host:GetAttribute("Boots")or 0)+1)
 local reduced=options.reduced==true
 local fired={}
 if not options.noSkip then
  self.inputConnection=UserInputService.InputBegan:Connect(function(input)
   if skipInputs[input.UserInputType]and not sticks[input.KeyCode]then self:skip()end
  end)
 end
 if reduced then
  -- Reduced Motion: the finished logo for 0.4 s; deck_boot at 0 ms.
  self:show(Boot.Reduced.frame);self:cue("deck_boot")
 else
  self:show(0)
 end
 self.connection=RunService.Heartbeat:Connect(function()
  if self.epoch~=epoch then return end
  if options.owns and not options.owns()then self:finish(false);return end
  local ms=self:elapsedMs()
  if ms>=maxMs then self:finish(false,true);return end
  if reduced then
   if ms>=Boot.Reduced.holdMs then self:finish(false)end
   return
  end
  local index=Boot.frameAt(ms)
  if not index then self:finish(false,true);return end
  if self.host:GetAttribute("BootFrame")~=index then self:show(index)end
  for i,sound in ipairs(Boot.Sounds)do
   if not fired[i]and ms>=sound.atMs then fired[i]=true;self:cue(sound.cue)end
  end
 end)
end

-- Yields until the boot ends; returns whether it was skipped.
function Boot:wait()
 while self.playing do RunService.Heartbeat:Wait()end
 return self.skipped
end

return Boot
