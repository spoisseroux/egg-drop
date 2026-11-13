-- Round danger state (UI-SPEC-REDESIGN-MENUS 6.3 with BUILD-PLAN architect change 4).
-- Inputs are the two server attributes: OverflowPressure (> 0 when the stack is
-- near or over the fill line) and OverflowGraceLeft (seconds of grace left while
-- the stack is over the line, 0 otherwise). Grace is short (1.1 s, longer on
-- trials), so there is no per-second countdown: the line itself is the timer.
--   calm: dashed white 24% line with a small "FILL LINE" tag
--   near: solid amber line, amber tag (from pressure)
--   over: amber haze above the line, chip "Stack too high / Merge to clear",
--         the line drains from both ends toward the middle by GraceLeft / grace,
--         red only in the last 0.35 s
-- One entry cue and one cleared chime; no repeating blip. Reduced Motion: no
-- pulse, no haze fade, and the line shortens in steps once per second.
-- Pure helpers (classify, drain, lineColor, hazeAlpha, chipText) are exported for specs.
local Danger={}
Danger.__index=Danger
Danger.Amber=Color3.fromHex("#FFB02E")
Danger.Red=Color3.fromHex("#FF5A6E")
Danger.White=Color3.new(1,1,1)
Danger.Chip=Color3.fromHex("#16181D")
Danger.RedWindow=.35
Danger.HazeAmber,Danger.HazeRed=.27,.43
Danger.CalmTransparency=.76 -- white 24%
Danger.HazeFade,Danger.FlashTime,Danger.SafeHold=.2,.2,.6
Danger.EnterCue,Danger.ClearCue="danger_enter","danger_clear"
Danger.Dashes=18
Danger.ChipHeight=40

function Danger.classify(pressure,graceLeft)
 if (graceLeft or 0)>0 then return "over" end
 if (pressure or 0)>0 then return "near" end
 return "calm"
end
-- Fraction of the line still lit (1 = full width). Reduced Motion steps once per second.
function Danger.drain(graceLeft,grace,reduced)
 if not grace or grace<=0 or not graceLeft or graceLeft<=0 then return 0 end
 local left=math.min(graceLeft,grace)
 if reduced then return math.min(1,math.ceil(left)/math.ceil(grace))end
 return left/grace
end
function Danger.isRed(state,graceLeft)
 return state=="over"and(graceLeft or 0)>0 and graceLeft<=Danger.RedWindow
end
function Danger.lineColor(state,graceLeft)
 if state=="over"then return if Danger.isRed(state,graceLeft)then Danger.Red else Danger.Amber end
 if state=="near"then return Danger.Amber end
 return Danger.White
end
function Danger.hazeAlpha(state,graceLeft)
 if state~="over"then return 0 end
 return if Danger.isRed(state,graceLeft)then Danger.HazeRed else Danger.HazeAmber
end
function Danger.chipText(state,graceLeft,safe)
 if safe then return "Safe","" end
 if state~="over"then return "","" end
 return "Stack too high",if Danger.isRed(state,graceLeft)then "Merge now" else "Merge to clear"
end

local function face(weight)return Font.new("rbxasset://fonts/families/BuilderSans.json",weight)end
local function frame(parent,name,z,color)
 local f=Instance.new("Frame");f.Name,f.BorderSizePixel,f.BackgroundColor3,f.ZIndex=name,0,color or Danger.White,z
 f.Active,f.Selectable=false,false;f.Parent=parent;return f
end
local function text(parent,name,z,size,weight)
 local t=Instance.new("TextLabel");t.Name,t.BackgroundTransparency,t.ZIndex=name,1,z
 t.FontFace,t.TextSize,t.TextColor3,t.Text=face(weight),size,Danger.White,""
 t.TextXAlignment=Enum.TextXAlignment.Left;t.Active,t.Selectable=false,false;t.Parent=parent;return t
end

function Danger.new(parent,options)
 options=options or {}
 local self=setmetatable({audio=options.audio,state="calm",shown={},published=0,anchorLeft=0,anchorTime=0,
  grace=0,left=0,hazeAlpha=0,safeUntil=0,flashUntil=0,lastNow=nil,width=0,lineY=0,stats={writes=0,entered=0,cleared=0}},Danger)
 -- Haze: amber (or red) from 0% at the top of the well to the full alpha at the line.
 local haze=frame(parent,"DangerHaze",5,Danger.Amber);haze.BackgroundTransparency=1;haze.Visible=false
 local fade=Instance.new("UIGradient");fade.Rotation=90
 fade.Transparency=NumberSequence.new(1,0);fade.Parent=haze
 -- Fill line: dashes (calm), a glow and a bar that drains toward the middle.
 local line=frame(parent,"FillLine",6);line.BackgroundTransparency=1;line.AnchorPoint=Vector2.new(0,.5)
 local dashes=frame(line,"Dashes",6);dashes.BackgroundTransparency=1;dashes.AnchorPoint=Vector2.new(0,.5)
 dashes.Position,dashes.Size=UDim2.fromScale(0,.5),UDim2.new(1,0,0,2)
 for index=1,Danger.Dashes do
  local dash=frame(dashes,"Dash",6);dash.BackgroundTransparency=Danger.CalmTransparency
  dash.Position,dash.Size=UDim2.fromScale((index-1)/Danger.Dashes,0),UDim2.fromScale(.55/Danger.Dashes,1)
 end
 local glow=frame(line,"Glow",6,Danger.Amber);glow.AnchorPoint=Vector2.new(.5,.5);glow.Position=UDim2.fromScale(.5,.5)
 glow.Size=UDim2.new(1,0,0,10);glow.BackgroundTransparency=.78;glow.Visible=false
 local glowCorner=Instance.new("UICorner");glowCorner.CornerRadius=UDim.new(.5,0);glowCorner.Parent=glow
 local bar=frame(line,"Bar",7,Danger.Amber);bar.AnchorPoint=Vector2.new(.5,.5);bar.Position=UDim2.fromScale(.5,.5)
 bar.Size=UDim2.new(1,0,0,4);bar.Visible=false
 -- The tag names the line at its right end.
 local tag=text(line,"Tag",7,12,Enum.FontWeight.Bold);tag.Text="FILL LINE";tag.AnchorPoint=Vector2.new(1,1)
 tag.Position=UDim2.new(1,-4,.5,-4);tag.Size=UDim2.fromOffset(0,16);tag.AutomaticSize=Enum.AutomaticSize.X
 tag.TextXAlignment=Enum.TextXAlignment.Right;tag.BackgroundColor3=Danger.Chip;tag.BackgroundTransparency=.35;tag.TextTransparency=.35
 local tagPad=Instance.new("UIPadding");tagPad.PaddingLeft,tagPad.PaddingRight=UDim.new(0,5),UDim.new(0,5);tagPad.Parent=tag
 local tagCorner=Instance.new("UICorner");tagCorner.CornerRadius=UDim.new(0,4);tagCorner.Parent=tag
 -- The chip straddles the line, centred: what is wrong, and what to do.
 local chip=frame(parent,"DangerChip",8,Danger.Chip);chip.AnchorPoint=Vector2.new(.5,.5);chip.BackgroundTransparency=.08;chip.Visible=false
 local chipCorner=Instance.new("UICorner");chipCorner.CornerRadius=UDim.new(0,10);chipCorner.Parent=chip
 local chipStroke=Instance.new("UIStroke");chipStroke.Color=Danger.Amber;chipStroke.Thickness=1.5;chipStroke.Parent=chip
 local title=text(chip,"Title",9,13,Enum.FontWeight.Bold);title.Position,title.Size=UDim2.fromOffset(12,4),UDim2.new(1,-20,0,17)
 local detail=text(chip,"Detail",9,12,Enum.FontWeight.Medium);detail.Position,detail.Size=UDim2.fromOffset(12,20),UDim2.new(1,-20,0,16)
 detail.TextColor3=Danger.Amber
 self.haze,self.fade,self.line,self.dashes,self.glow,self.bar,self.tag,self.chip,self.chipStroke,self.title,self.detail=
  haze,fade,line,dashes,glow,bar,tag,chip,chipStroke,title,detail
 return self
end

-- Writes a property only when it changes (render-loop safe).
function Danger:set(node,property,value)
 local cache=self.shown[node];if not cache then cache={};self.shown[node]=cache end
 if cache[property]==value then return end
 cache[property]=value;node[property]=value;self.stats.writes+=1
end

-- Board-local geometry: the fill line's left edge and width, and its y.
function Danger:place(left,width,lineY)
 self.width,self.lineY=width,lineY
 self.line.Position=UDim2.fromOffset(left,lineY);self.line.Size=UDim2.fromOffset(width,12)
 self.haze.Position=UDim2.fromOffset(left,0);self.haze.Size=UDim2.fromOffset(width,math.max(0,lineY))
 local chipWidth=math.max(96,math.min(156,width-12))
 self.chip.Position=UDim2.fromOffset(left+width/2,lineY-Danger.ChipHeight/2+6)
 self.chip.Size=UDim2.fromOffset(chipWidth,Danger.ChipHeight)
end

-- Local grace estimate between the server's 0.1 s publishes.
function Danger:graceLeft(published,now)
 if published<=0 then self.published=0;self.grace=0;return 0 end
 if published~=self.published then self.published=published;self.anchorLeft=published;self.anchorTime=now end
 self.grace=math.max(self.grace,published)
 return math.max(0,self.anchorLeft-(now-self.anchorTime))
end

-- Once per rendered frame. `audible` gates the cues (presented board only);
-- `roundOver` stops a lost round from reading as cleared.
function Danger:update(pressure,published,now,reduced,audible,roundOver)
 local left=self:graceLeft(published or 0,now)
 -- The state follows the server; the local estimate only drains the line.
 local state=Danger.classify(pressure,published)
 local shownLeft=if state=="over"then math.max(left,.001)else 0
 local previous=self.state
 if state~=previous then
  if state=="over"then
   self.stats.entered+=1;self.safeUntil=0
   if audible and self.audio then self.audio:play(Danger.EnterCue,1,.55)end
  elseif previous=="over"and not roundOver then
   self.stats.cleared+=1;self.safeUntil=now+Danger.SafeHold;self.flashUntil=now+Danger.FlashTime
   if audible and self.audio then self.audio:play(Danger.ClearCue,1,.6)end
  end
  self.state=state
 end
 if roundOver then self.safeUntil=0;self.flashUntil=0 end
 self.left=shownLeft
 local safe=now<self.safeUntil
 local flashing=now<self.flashUntil
 local color=Danger.lineColor(state,shownLeft)
 local red=Danger.isRed(state,shownLeft)
 -- Line.
 self:set(self.dashes,"Visible",state=="calm"and not flashing)
 self:set(self.bar,"Visible",state~="calm"or flashing)
 self:set(self.bar,"BackgroundColor3",if flashing then Danger.White else color)
 local fraction=if state=="over"then Danger.drain(shownLeft,self.grace,reduced)else 1
 local thickness=if state=="over"then 4 else 3
 if self.fraction~=fraction or self.thickness~=thickness then
  self.fraction,self.thickness=fraction,thickness
  self.bar.Size=UDim2.new(fraction,0,0,thickness);self.glow.Size=UDim2.new(fraction,0,0,thickness+8)
 end
 self:set(self.glow,"Visible",state=="over")
 self:set(self.glow,"BackgroundColor3",color)
 if state=="over"then
  self:set(self.glow,"BackgroundTransparency",if reduced then .72 else .72+.12*math.sin(now*math.pi*3))
 end
 -- Tag.
 self:set(self.tag,"Visible",state~="over"and not safe)
 self:set(self.tag,"TextColor3",if state=="near"then Danger.Amber else Danger.White)
 self:set(self.tag,"TextTransparency",if state=="near"then 0 else .35)
 -- Haze: fades in and out over 0.2 s (instant under Reduced Motion).
 local target=Danger.hazeAlpha(state,shownLeft)
 local dt=if self.lastNow then math.clamp(now-self.lastNow,0,.1)else 0;self.lastNow=now
 if reduced then self.hazeAlpha=target
 elseif self.hazeAlpha<target then self.hazeAlpha=math.min(target,self.hazeAlpha+dt*Danger.HazeAmber/Danger.HazeFade)
 elseif self.hazeAlpha>target then self.hazeAlpha=math.max(target,self.hazeAlpha-dt*Danger.HazeRed/Danger.HazeFade)end
 self:set(self.haze,"Visible",self.hazeAlpha>.001)
 self:set(self.haze,"BackgroundColor3",if red then Danger.Red else Danger.Amber)
 self:set(self.haze,"BackgroundTransparency",1-math.floor(self.hazeAlpha*100+.5)/100)
 -- Chip.
 local title,detail=Danger.chipText(state,shownLeft,safe)
 self:set(self.chip,"Visible",state=="over"or safe)
 self:set(self.chipStroke,"Color",if safe then Danger.White else color)
 self:set(self.title,"Text",title)
 self:set(self.detail,"Text",detail)
 self:set(self.detail,"TextColor3",if red then Danger.Red else Danger.Amber)
 return state
end

function Danger:destroy()
 for _,node in ipairs({self.haze,self.line,self.chip})do node:Destroy()end
 table.clear(self.shown)
end

return Danger
