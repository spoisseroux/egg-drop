-- Pocket Deck Slim: the 2D sprite shell, the wide glass LCD and the round HUD
-- that lives inside it (UI-SPEC-2026-11-12 sections 1, 4, 5.1 and 7).
-- Geometry is pure (DeckScreen.resolve); the instance tree is built once and
-- re-placed on every layout. Input is reported through callbacks; the board
-- renderer and the server rules stay with the caller.
local GuiService=game:GetService("GuiService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Art=require(script.Parent.DeckArt)
local Kit=require(script.Parent.DeckKit)
local Assets=require(script.Parent.DeckAssets)
local Boot=require(script.Parent.DeckBoot)
local Config=require(Shared.BoardConfig)
local JellyPalette=require(Shared.JellyPalette)
local L=Assets.Layout
local Screen={}
Screen.__index=Screen
Screen.Regular=Vector2.new(848,608)
Screen.Compact=Vector2.new(417,299)

local function rect(x,y,w,h)return{x=x,y=y,w=w,h=h}end
-- Section 1. `root` is the inset interactive root in view px; `aspect` is the
-- simulation's (Width + .8) / (Height + .8). The deck never grows past 1:1 so
-- the 1920x1080 reference keeps the mockup's s = 1.0.
-- Compact (phone landscape, UI-SPEC-COMPACT-2026-11-12 sections 1, 4 and 5):
-- no deck body and no UIScale; every rect is in root px. `kx, kh` is the
-- Roblox-controls keep-out at the top left (116 x 58 when unknown).
function Screen.resolveCompact(W,H,aspect,kx,kh)
 kx=kx or 116;kh=kh or 58
 local bh=H-16;local bw=math.floor(bh*aspect+.5)
 local bx=math.floor((W-bw)/2)
 local board=rect(bx,8,bw,bh)
 local L0,L1=12,bx-14;local R0,R1=bx+bw+14,W-12
 local D=if H>=380 then 104 elseif H>=340 then 96 else 88
 -- 4.2 top strip, left wing.
 local x0=math.max(kx+8,L0);local wing=L1-x0
 local score,chain;local scoreWide,chainInGoals,goalsTop=false,false,60
 if wing>=154 then
  local sw=math.min(132,wing-70);chain=rect(L1-64,8,64,44);score=rect(L1-64-6-sw,8,sw,44)
 elseif wing>=84 then
  local sw=math.min(132,wing);score=rect(L1-sw,8,sw,44);chainInGoals=true
 else score=rect(L0,60,L1-L0,44);scoreWide,chainInGoals,goalsTop=true,true,112 end
 -- Right wing (the back arrow owns the last 56).
 local wr=W-64-R0;local eggsW=if wr<150 then 58 else 88
 local nw=math.min(140,wr-eggsW-6)
 -- Eggs sits 6 px after Next (flush with the back arrow's gutter unless Next is capped at 140).
 local eggs=rect(R0+nw+6,8,eggsW,44)
 local m=if H<340 then 8 else 12
 local hx=16+D+12
 local a=Vector2.new(W-16-D/2,H-16-D/2)
 return{s=1,compact=false,phone=true,mode="Compact",W=W,H=H,kx=kx,kh=kh,aspect=aspect,
  deck=rect(0,0,W,H),lcd=board,board=board,boardLocal=rect(0,0,bw,bh),authored=Vector2.new(bw,bh),contentScale=1,pad=0,column=L1-L0,
  L0=L0,L1=L1,R0=R0,R1=R1,D=D,
  score=score,chain=chain,scoreWide=scoreWide,chainInGoals=chainInGoals,goalsTop=goalsTop,goalPitch=if H<340 then 26 else 34,
  eggs=eggs,next=rect(R0,8,nw,44),eggsCompact=eggsW<88,
  difficulty=rect(R0,60,R1-R0,44),winPays=rect(R0,112,R1-R0,44),
  dpad=rect(16,H-m-D,D,D),handle=rect(hx,H-56,math.max(44,L1-hx),44),drawer=rect(L0,60,L1-L0,H-72),
  a=a,b=Vector2.new(a.X-D/2-42,H-44),back=rect(W-56,8,44,44),
  -- 5 menu sheet.
  sheet=rect(8,8,W-16,H-16),hx=math.max(kx+12,24),cw=math.floor((W-60)/3),ch=H-140,actionY=H-66}
end

function Screen.resolve(root,aspect,keep)
 local W,H=root.X,root.Y
 if W>=H*1.2 and(H<500 or W<1000)then
  return Screen.resolveCompact(W,H,aspect,keep and keep.kx,keep and keep.kh)
 end
 local s=math.min((W-48)/1600,(H-48-12)/800,1)
 local compact=s<.75
 if compact then s=(H-8)/608 end
 local deck=rect((W-1600*s)/2,(H-800*s)/2+(if compact then 0 else 10),1600*s,800*s)
 local lcd=rect(deck.x+L.lcd[1]*s,deck.y+L.lcd[2]*s,L.lcd[3]*s,L.lcd[4]*s)
 local authored=if compact then Screen.Compact else Screen.Regular
 local scale=lcd.h/authored.Y
 -- Board: height fixed by padding, width solved from the simulation aspect, centred.
 local pad=if compact then 6 else 12
 local bh=authored.Y-pad*2;local bw=math.floor(bh*aspect+.5)
 local board=rect(math.floor((authored.X-bw)/2+.5),pad,bw,bh)
 local column=math.floor((authored.X-pad*4-bw)/2)
 return{s=s,compact=compact,mode=if compact then "Small"else "Regular",deck=deck,lcd=lcd,authored=authored,
  contentScale=scale,pad=pad,column=column,boardLocal=board,
  board=rect(lcd.x+board.x*scale,lcd.y+board.y*scale,board.w*scale,board.h*scale)}
end

local function image(parent,name,id,z,props)
 local i=Kit.node("ImageLabel",parent,{Name=name,BackgroundTransparency=1,Image=id,ZIndex=z,Active=false,ScaleType=Enum.ScaleType.Stretch})
 if props then for k,v in pairs(props)do i[k]=v end end
 return i
end
local function placeU(node,r,s)node.Position=UDim2.fromOffset(r[1]*s,r[2]*s);node.Size=UDim2.fromOffset(r[3]*s,r[4]*s)end

function Screen.new(options)
 local self=setmetatable({options=options,callbacks={},hud={},held={}},Screen)
 local parent=options.parent
 local root=Kit.node("Frame",parent,{Name="PocketDeck",BackgroundTransparency=1,ZIndex=0,Active=false,Size=UDim2.fromOffset(1600,800)})
 self.root=root
 local I=Assets.Image
 self.shadow=image(root,"Shadow",I.shadow,1,{ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(189,189,191,191)})
 self.shoulders={image(root,"ShoulderL",I.shoulder,2),image(root,"ShoulderR",I.shoulder,2)}
 self.band=image(root,"Band",I.band,3)
 self.plate=image(root,"Faceplate",Assets.Faceplate.sherbet,4)
 -- Finish overlay (gloss, water, aurora, sparkle) sits between the plate and plate-overlay.
 self.finish=image(root,"FinishOverlay","",5,{ImageTransparency=1,Visible=false})
 self.plateOverlay=image(root,"PlateOverlay",I.plateOverlay,5)
 self.wordmarkShadow=image(root,"WordmarkShadow",I.wordmark,6,{ResampleMode=Enum.ResamplerMode.Pixelated,ImageColor3=Color3.new(1,1,1),ImageTransparency=.7})
 self.wordmark=image(root,"Wordmark",I.wordmark,6,{ResampleMode=Enum.ResamplerMode.Pixelated})
 self.glass=image(root,"Glass",I.glass,7)
 self.led=image(root,"Led",I.led,11)
 -- LCD: panel glass with one white 3% to black 12% overlay gradient.
 -- Compact: the board island's bezel (the LCD frame becomes the board island).
 self.boardBezel=Kit.frame(root,"BoardBezel",nil,UDim2.new(),UDim2.new(),18);self.boardBezel.ZIndex=7
 self.boardBezel.BackgroundTransparency=0;self.boardBezel.BackgroundColor3=Color3.fromHex("#090A0C");self.boardBezel.Visible=false
 Kit.stroke(self.boardBezel,nil,1,.82)
 self.rims={}
 local lcd=Kit.frame(root,"LCD","panel",UDim2.new(),UDim2.fromOffset(848,608),30);lcd.ZIndex=8;lcd.ClipsDescendants=true
 local tint=Kit.frame(lcd,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));tint.BackgroundTransparency=0;tint.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",tint,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 self.lcd=lcd
 local content=Kit.frame(lcd,"Content",nil,UDim2.new(),UDim2.fromOffset(848,608));content.ZIndex=lcd.ZIndex+2
 self.contentScale=Kit.node("UIScale",content,{Scale=1});self.content=content
 -- Hardware: d-pad disc with four hit quadrants, Menu pill, A and B.
 self.dpad=image(root,"DPad",I.dpadDisc,9)
 self.dpadArrows=image(self.dpad,"Arrows",I.dpadArrows,10,{Size=UDim2.fromScale(1,1)})
 self.dpadPress=image(self.dpad,"Press",I.dpadPress,11,{Size=UDim2.fromScale(1,1),Visible=false})
 self.quadrants={}
 for _,dir in ipairs({"Left","Right","Up","Down"})do
  local q=Kit.node("TextButton",root,{Name="DPad"..dir,Text="",BackgroundTransparency=1,AutoButtonColor=false,ZIndex=12,Selectable=false})
  q:SetAttribute("AccessibleLabel","D-pad "..string.lower(dir))
  self.quadrants[dir]=q
  q.InputBegan:Connect(function(input)
   local t=input.UserInputType
   if t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.Touch then
    self:pressDpad(dir,true)
    if self.callbacks.dpad then self.callbacks.dpad(dir,input)end
   end
  end)
  q.InputEnded:Connect(function(input)
   local t=input.UserInputType
   if t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.Touch then self:pressDpad(dir,false)end
  end)
 end
 self.menu=Kit.node("ImageButton",root,{Name="MenuPill",Image=I.menuPill,BackgroundTransparency=1,ZIndex=10,AutoButtonColor=false,
  ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(44,43,204,45),Selectable=false})
 self.menu:SetAttribute("AccessibleLabel","Menu")
 self.menuLabel=Kit.text(self.menu,"Strong","MENU",nil,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextColor3=Color3.fromHex("#E6E9EE")})
 self.menuHit=Kit.node("TextButton",self.menu,{Name="Hit",Text="",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),ZIndex=12,Selectable=false})
 self.menuHit.Activated:Connect(function()if self.callbacks.menu then self.callbacks.menu()end end)
 self.buttons={}
 for _,id in ipairs({"A","B"})do
  local holder=Kit.node("Frame",root,{Name="Button"..id,BackgroundTransparency=1,ZIndex=10})
  local base=image(holder,"Base",I.buttonBase,10,{Size=UDim2.fromScale(1,1)})
  local gloss=image(holder,"Gloss",I.buttonGloss,11,{Size=UDim2.fromScale(1,1)})
  local letter=Kit.text(holder,"Title",id,nil,{Name="Letter",ZIndex=12,AnchorPoint=Vector2.new(.5,.5),TextXAlignment=Enum.TextXAlignment.Center,
   FontFace=Font.new("rbxasset://fonts/families/BuilderSans.json",Enum.FontWeight.ExtraBold)})
  letter.TextColor3=if id=="A"then Kit.Color.ink else Kit.Color.soft
  if id=="B"then base.ImageColor3=Color3.fromHex("#3A3E47")end
  local hit=Kit.node("TextButton",holder,{Name="Hit",Text="",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),ZIndex=13,Selectable=false})
  hit:SetAttribute("AccessibleLabel",if id=="A"then "A: drop or confirm"else "B: back")
  self.buttons[id]={holder=holder,base=base,gloss=gloss,letter=letter,hit=hit}
  hit.InputBegan:Connect(function(input)
   local t=input.UserInputType
   if t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.Touch then self:pressButton(id,true)end
  end)
  hit.InputEnded:Connect(function(input)
   local t=input.UserInputType
   if t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.Touch then self:pressButton(id,false)end
  end)
  hit.Activated:Connect(function()local cb=self.callbacks[id];if cb then cb()end end)
 end
 -- Board well behind the board renderer.
 self.well=Kit.frame(content,"BoardWell","well",UDim2.new(),UDim2.new(),14);Kit.stroke(self.well)
 -- The glare floats above every LCD layer, including the board and results.
 -- The overlay parent uses Global ZIndex (board renderer at 1 to 8, its corner mask at 100).
 self.glare=image(options.overlayParent or parent,"LCDGlare",I.glare,120,{ImageTransparency=.15})
 -- The results screen is its own layer at the LCD rect, above the board.
 local results=Kit.frame(options.overlayParent or parent,"DeckResults","panel",UDim2.new(),UDim2.fromOffset(848,608),30)
 results.ZIndex=30;results.ClipsDescendants=true;results.Visible=false;results.Active=true
 local rtint=Kit.frame(results,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));rtint.BackgroundTransparency=0;rtint.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",rtint,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 local rcontent=Kit.frame(results,"Content",nil,UDim2.new(),UDim2.fromOffset(848,608));rcontent.ZIndex=results.ZIndex+2
 self.resultsScale=Kit.node("UIScale",rcontent,{Scale=1})
 self.results,self.resultsContent=results,rcontent
 self.resultsLayer={layer=results,tint=rtint,rim=self:rim(results)}
 self.overlays={}
 -- Boot (section 6): above every LCD layer, below the glare.
 local bootHost=Kit.frame(options.overlayParent or parent,"DeckBoot",nil,UDim2.new(),UDim2.fromOffset(848,608),30)
 bootHost.ZIndex=110;bootHost.ClipsDescendants=true;bootHost.Active=false
 self.bootHost=bootHost;self.boot=Boot.new(bootHost,{audio=options.audio})
 -- Back arrow lives on the interactive root, never on the deck body.
 self.back=Kit.backArrow(options.viewRoot,false)
 self.back.root.Activated:Connect(function()if self.back.enabled and self.callbacks.back then self.callbacks.back()end end)
 self.toaster=Kit.toaster(options.viewRoot)
 GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(function()self:applyTransparency()end)
 return self
end

function Screen:on(name,callback)self.callbacks[name]=callback end

-- A full-LCD screen layer above the board (difficulty picker, quest log),
-- placed exactly like the results layer. Content is authored at 848x608 and
-- scaled to the LCD (compact LCDs scale the same layout down).
function Screen:addOverlay(name,z)
 local layer=Kit.frame(self.options.overlayParent or self.options.parent,name,"panel",UDim2.new(),UDim2.fromOffset(848,608),30)
 layer.ZIndex=z or 32;layer.ClipsDescendants=true;layer.Visible=false;layer.Active=true
 local tint=Kit.frame(layer,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));tint.BackgroundTransparency=0;tint.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",tint,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 local content=Kit.frame(layer,"Content",nil,UDim2.new(),UDim2.fromOffset(848,608));content.ZIndex=layer.ZIndex+2
 local scale=Kit.node("UIScale",content,{Scale=1})
 local overlay={layer=layer,content=content,scale=scale,tint=tint,rim=self:rim(layer)}
 table.insert(self.overlays,overlay)
 if self.geometry then self:placeOverlay(overlay)end
 return overlay
end
function Screen:placeOverlay(overlay)
 local g=self.geometry;if not g then return end
 if g.phone then
  -- Compact: the layer covers the whole root at scale 1; the screen draws its own sheet.
  overlay.layer.Position=UDim2.new();overlay.layer.Size=UDim2.fromOffset(g.W,g.H);Kit.corner(overlay.layer,0)
  overlay.content.Size=UDim2.fromOffset(g.W,g.H);overlay.scale.Scale=1
 else
  overlay.layer.Position=UDim2.fromOffset(g.lcd.x,g.lcd.y);overlay.layer.Size=UDim2.fromOffset(g.lcd.w,g.lcd.h)
  Kit.corner(overlay.layer,math.floor(L.lcdRadius*g.s))
  overlay.content.Size=UDim2.fromOffset(848,608);overlay.scale.Scale=g.lcd.w/848
 end
 self:dress(overlay,g.phone)
 if overlay.onLayout then overlay.onLayout(self:view())end
end
-- A phone layer is transparent with the plate as its rim; regular layers are LCD glass.
function Screen:dress(layer,phone)
 layer.layer.BackgroundTransparency=if phone then 1 else 0
 layer.layer.ClipsDescendants=not phone
 layer.tint.Visible=not phone;layer.rim.Visible=phone==true
end
-- The plate texture cropped to its middle 80% x 76% (UI-SPEC-COMPACT 3).
local PlateCrop={offset=Vector2.new(102,60),size=Vector2.new(819,379)}
function Screen:rim(parent)
 local i=image(parent,"Rim",Assets.Faceplate.sherbet,parent.ZIndex+1,{Size=UDim2.fromScale(1,1),Visible=false,
  ImageRectOffset=PlateCrop.offset,ImageRectSize=PlateCrop.size})
 table.insert(self.rims,i);return i
end
-- What a screen needs to lay itself out: nil (regular / small LCD) or the compact root.
function Screen:view()
 local g=self.geometry
 if not(g and g.phone)then return nil end
 return{phone=true,W=g.W,H=g.H,kx=g.kx,kh=g.kh,hx=g.hx,cw=g.cw,ch=g.ch,actionY=g.actionY}
end

function Screen:pressDpad(dir,down)
 self.dpadPress.Visible=down
 self.dpadPress.Rotation=({Up=0,Right=90,Down=180,Left=270})[dir]or 0
end
function Screen:pressButton(id,down)
 local b=self.buttons[id];if not b then return end
 b.base.Image=if down then Assets.Image.buttonBasePressed else Assets.Image.buttonBase
 b.gloss.Image=if down then Assets.Image.buttonGlossPressed else Assets.Image.buttonGloss
 local drop=if down then b.diameter*.07 else 0
 b.letter.Position=UDim2.new(.5,0,0,b.diameter/2+drop)
end
-- Keyboard or gamepad presses show on the hardware too.
function Screen:flash(id)
 if id=="A"or id=="B"then self:pressButton(id,true);task.delay(.1,function()self:pressButton(id,false)end)
 else self:pressDpad(id,true);task.delay(.1,function()self:pressDpad(id,false)end)end
end

function Screen:applyTransparency()
 -- Reduce transparency: the glare could cost contrast, so it goes.
 self.glare.Visible=self.visible==true and GuiService.PreferredTransparency>.5
end

function Screen:setTheme(id,theme)
 self.plate.Image=Assets.Faceplate[id]or Assets.Faceplate.sherbet
 for _,r in ipairs(self.rims)do r.Image=self.plate.Image end
 local band=theme.bandTint or Color3.new(1,1,1)
 self.band.ImageColor3=band;for _,s in ipairs(self.shoulders)do s.ImageColor3=band end
 self.wordmark.ImageColor3=theme.engrave or Kit.Color.ink;self.wordmark.ImageTransparency=1-(theme.engraveOpacity or .42)
 local accent=theme.ui and theme.ui.accent or theme.buttons
 self.buttons.A.base.ImageColor3=accent;self.dpadArrows.ImageColor3=accent;self.led.ImageColor3=accent
 self.buttons.A.letter.TextColor3=theme.ui and theme.ui.ink or Kit.Color.ink
 self.accent=accent;self.boot:setAccent(accent)
 self:setFinish(theme.overlay)
end

-- Section 8: animate ImageTransparency only, ping-pong between 1 - max and
-- 1 - min over the period; Reduced Motion holds the low opacity.
function Screen:setFinish(overlay)
 self.finishToken=(self.finishToken or 0)+1;local token=self.finishToken
 if self.finishTween then self.finishTween:Cancel();self.finishTween=nil end
 self.finish.Visible=overlay~=nil
 if not overlay then return end
 self.finish.Image=overlay.image
 local low,high=1-overlay.min,1-overlay.max
 self.finish.ImageTransparency=low
 if Kit.reduced()then return end
 local tween=game:GetService("TweenService"):Create(self.finish,TweenInfo.new(overlay.period/2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{ImageTransparency=high})
 self.finishTween=tween
 task.defer(function()if self.finishToken==token then tween:Play()end end)
end

function Screen:setVisible(visible)
 self.visible=visible
 self.root.Visible=visible;self.back.root.Visible=visible and self.backVisible~=false
 self:applyTransparency()
end

-- Places every sprite and returns the resolved geometry (view px).
function Screen:layout(rootSize,aspect,keep)
 local g=Screen.resolve(rootSize,aspect,keep);self.geometry=g
 Kit.touchHidesFocus=g.phone==true
 self:showShell(not g.phone)
 if g.phone then return self:layoutCompact(g)end
 local s=g.s
 self.root.Position=UDim2.fromOffset(g.deck.x,g.deck.y);self.root.Size=UDim2.fromOffset(g.deck.w,g.deck.h)
 placeU(self.shadow,L.shadow,s);self.shadow.SliceScale=s
 placeU(self.shoulders[1],L.shoulderL,s);placeU(self.shoulders[2],L.shoulderR,s)
 placeU(self.band,L.band,s);placeU(self.plate,L.plate,s);placeU(self.plateOverlay,L.plate,s);placeU(self.finish,L.plate,s)
 placeU(self.wordmark,L.wordmark,s)
 self.wordmarkShadow.Position=UDim2.fromOffset((L.wordmark[1]+1.6)*s,(L.wordmark[2]+2)*s);self.wordmarkShadow.Size=self.wordmark.Size
 placeU(self.glass,L.glass,s);placeU(self.led,L.led,s)
 placeU(self.lcd,L.lcd,s);Kit.corner(self.lcd,math.floor(L.lcdRadius*s))
 self.content.Size=UDim2.fromOffset(g.authored.X,g.authored.Y);self.contentScale.Scale=g.contentScale
 local d=L.dpad.diameter*s;local c=L.dpad.center*s
 self.dpad.Position=UDim2.fromOffset(c.X-d/2,c.Y-d/2);self.dpad.Size=UDim2.fromOffset(d,d)
 local q=math.max(44,96*s)
 local quads={Left=Vector2.new(c.X-d/2,c.Y-q/2),Right=Vector2.new(c.X+d/2-q,c.Y-q/2),Up=Vector2.new(c.X-q/2,c.Y-d/2),Down=Vector2.new(c.X-q/2,c.Y+d/2-q)}
 for dir,p in pairs(quads)do self.quadrants[dir].Position=UDim2.fromOffset(p.X,p.Y);self.quadrants[dir].Size=UDim2.fromOffset(q,q)end
 placeU(self.menu,L.menu,s);self.menu.SliceScale=s
 self.menuLabel.TextSize=math.max(11,math.floor(19*s))
 self.menuHit.Size=UDim2.new(1,0,0,math.max(44,L.menu[4]*s))
 for id,b in pairs(self.buttons)do
  local spec=if id=="A"then L.a else L.b
  local dia=spec.diameter*s;b.diameter=dia
  b.holder.Position=UDim2.fromOffset(spec.center.X*s-dia/2,spec.center.Y*s-dia/2);b.holder.Size=UDim2.fromOffset(dia,dia*1.07)
  b.letter.TextSize=math.floor(.46*dia);b.letter.Size=UDim2.fromOffset(dia,dia)
  b.letter.Position=UDim2.new(.5,0,0,dia/2)
  local hit=math.max(44,dia+16*s)
  b.hit.Size=UDim2.fromOffset(hit,hit);b.hit.Position=UDim2.new(.5,0,0,dia/2)
 end
 -- Overlay layers live in the parent's coordinates.
 local lcdR=g.lcd
 self.glare.Position=UDim2.fromOffset(lcdR.x,lcdR.y);self.glare.Size=UDim2.fromOffset(lcdR.w,lcdR.h)
 self.results.Position=self.glare.Position;self.results.Size=self.glare.Size;Kit.corner(self.results,math.floor(L.lcdRadius*s))
 self.bootHost.Position=self.glare.Position;self.bootHost.Size=self.glare.Size;Kit.corner(self.bootHost,math.floor(L.lcdRadius*s))
 self.resultsContent.Size=self.content.Size;self.resultsScale.Scale=g.contentScale
 for _,overlay in ipairs(self.overlays)do self:placeOverlay(overlay)end
 local inset=if g.compact then 12 else 24
 self.back.setCompact(g.compact);self.back.root.Position=UDim2.new(1,-inset,0,inset)
 local b=g.boardLocal
 self.well.Position=UDim2.fromOffset(b.x,b.y);self.well.Size=UDim2.fromOffset(b.w,b.h)
 self:dress(self.resultsLayer,false)
 if self.builtMode~=g.mode then self:buildHud(g)end
 return g
end

-- Shell sprites the compact phone does not draw (UI-SPEC-COMPACT 3).
function Screen:showShell(on)
 for _,node in ipairs({self.shadow,self.shoulders[1],self.shoulders[2],self.band,self.plateOverlay,self.wordmarkShadow,self.glass,self.led,self.menu})do node.Visible=on end
 self.quadrants.Up.Visible=on;self.quadrants.Down.Visible=on
 self.boardBezel.Visible=not on
 if on then self.wordmark.Visible=true;Kit.corner(self.well,14)end
 self.plate.ImageRectOffset=if on then Vector2.zero else PlateCrop.offset
 self.plate.ImageRectSize=if on then Vector2.zero else PlateCrop.size
 self.plate.ScaleType=Enum.ScaleType.Stretch
end

-- Compact: the phone is the deck. Plate fills the root, the LCD frame becomes
-- the board island, the hardware sits under the thumbs, and the HUD is built as
-- islands on the root (section 4).
function Screen:layoutCompact(g)
 local W,H=g.W,g.H
 self.root.Position=UDim2.new();self.root.Size=UDim2.fromOffset(W,H)
 local bleed=48
 for _,node in ipairs({self.plate,self.finish})do
  node.Position=UDim2.fromOffset(-bleed,-bleed);node.Size=UDim2.fromOffset(W+bleed*2,H+bleed*2)
 end
 local b=g.board
 self.lcd.Position=UDim2.fromOffset(b.x,b.y);self.lcd.Size=UDim2.fromOffset(b.w,b.h);Kit.corner(self.lcd,12)
 self.boardBezel.Position=UDim2.fromOffset(b.x-6,b.y-6);self.boardBezel.Size=UDim2.fromOffset(b.w+12,b.h+12)
 self.content.Size=UDim2.fromOffset(b.w,b.h);self.contentScale.Scale=1
 self.well.Position=UDim2.new();self.well.Size=UDim2.fromOffset(b.w,b.h);Kit.corner(self.well,12)
 -- D-pad: during a round the left and right halves are the hit areas.
 local d=g.dpad
 self.dpad.Position=UDim2.fromOffset(d.x,d.y);self.dpad.Size=UDim2.fromOffset(d.w,d.h)
 self.quadrants.Left.Position=UDim2.fromOffset(d.x,d.y);self.quadrants.Left.Size=UDim2.fromOffset(d.w/2,d.h)
 self.quadrants.Right.Position=UDim2.fromOffset(d.x+d.w/2,d.y);self.quadrants.Right.Size=UDim2.fromOffset(d.w/2,d.h)
 for id,btn in pairs(self.buttons)do
  local dia=if id=="A"then g.D else 56;btn.diameter=dia
  local c=if id=="A"then g.a else g.b
  btn.holder.Position=UDim2.fromOffset(c.X-dia/2,c.Y-dia/2);btn.holder.Size=UDim2.fromOffset(dia,dia*1.07)
  btn.letter.TextSize=math.floor(.46*dia);btn.letter.Size=UDim2.fromOffset(dia,dia);btn.letter.Position=UDim2.new(.5,0,0,dia/2)
  local hit=if id=="A"then dia+8 else 56
  btn.hit.Size=UDim2.fromOffset(hit,hit);btn.hit.Position=UDim2.new(.5,0,0,dia/2)
 end
 -- Glare on the board island only; the results, boot and sheets cover the root.
 self.glare.Position=UDim2.fromOffset(b.x,b.y);self.glare.Size=UDim2.fromOffset(b.w,b.h)
 self.results.Position=UDim2.new();self.results.Size=UDim2.fromOffset(W,H);Kit.corner(self.results,0)
 self.resultsContent.Size=UDim2.fromOffset(W,H);self.resultsScale.Scale=1
 self:dress(self.resultsLayer,true)
 local sh=g.sheet
 self.bootHost.Position=UDim2.fromOffset(sh.x,sh.y);self.bootHost.Size=UDim2.fromOffset(sh.w,sh.h);Kit.corner(self.bootHost,16)
 for _,overlay in ipairs(self.overlays)do self:placeOverlay(overlay)end
 self.back.setCompact(true);self.back.root.Position=UDim2.new(1,-12,0,8)
 local key=string.format("Compact:%dx%d:%d",W,H,g.kx)
 if self.builtMode~=key then self:buildHud(g);self.builtMode=key end
 -- Toasts: in the right column on the HUD, at the top of a sheet otherwise.
 self.toaster.placement=function()
  local gg=self.geometry
  if not(gg and gg.phone)then return nil,30,false end
  local sheet=self.results.Visible
  for _,o in ipairs(self.overlays)do if o.layer.Visible then sheet=true end end
  if sheet then return gg.W/2,66,true end
  return (gg.R0+gg.R1)/2,164,true
 end
 return g
end

-- Portrait keeps the stacked case; results then use the compact screen fitted
-- over the case rect.
function Screen:placeResults(r)
 local scale=math.min(r.w/Screen.Compact.X,r.h/Screen.Compact.Y)
 local w,h=Screen.Compact.X*scale,Screen.Compact.Y*scale
 self.results.Position=UDim2.fromOffset(r.x+(r.w-w)/2,r.y+(r.h-h)/2);self.results.Size=UDim2.fromOffset(w,h)
 self.resultsContent.Size=UDim2.fromOffset(Screen.Compact.X,Screen.Compact.Y);self.resultsScale.Scale=scale
 Kit.corner(self.results,14)
 self.back.setCompact(true);self.back.root.Position=UDim2.new(1,-12,0,12)
 return scale
end

-- ── Round HUD (5.1 regular, 7 compact) ──────────────────────────────────────
local function card(parent,name,r,label,pad)
 local c,eyebrow=Kit.card(parent,name,label,{pad=pad,labelY=pad==14 and 12 or 6})
 c.Position,c.Size=UDim2.fromOffset(r[1],r[2]),UDim2.fromOffset(r[3],r[4])
 return c,eyebrow
end
local function egg(parent,diameter)
 local ball=Kit.frame(parent,"Egg",nil,UDim2.new(),UDim2.fromOffset(diameter,diameter),999);ball.BackgroundTransparency=0
 local mark=Kit.text(ball,"Strong","I",nil,{Name="Mark",Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=math.max(12,math.floor(diameter*.42))})
 Art.jellyPreview(ball,1,mark)
 return{ball=ball,mark=mark}
end
local function commas(n)
 local s=tostring(math.floor(n or 0));local out=s:reverse():gsub("(%d%d%d)","%1,"):reverse()
 return(out:gsub("^,",""))
end
Screen.commas=commas

-- Compact round HUD (UI-SPEC-COMPACT 4): islands on the root around the board.
function Screen:buildCompactHud(g)
 local host=Kit.frame(self.root,"CompactHUD",nil,UDim2.new(),UDim2.fromScale(1,1));host.ZIndex=14;self.hudRoot=host
 local h={phone=true};self.hud=h
 local TextService=game:GetService("TextService")
 local function txt(parent,role,content,color,x,y,w,hh,size,props)
  local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,hh);t.TextSize=size;return t
 end
 local right={TextXAlignment=Enum.TextXAlignment.Right}
 -- 4.2 strip.
 local sr=g.score
 local score=Kit.island(host,"Score",sr,12)
 if g.scoreWide then
  txt(score,"Label","SCORE","dim",12,0,80,sr.h,12)
  h.score=txt(score,"Counter","0","text",12,0,sr.w-24,sr.h,18,right)
 else
  txt(score,"Label","SCORE","dim",12,6,sr.w-24,14,12)
  h.score=txt(score,"Counter","0","text",12,21,sr.w-24,22,18)
 end
 if g.chain then
  local chain=Kit.island(host,"Chain",g.chain,12)
  txt(chain,"Label","CHAIN","dim",10,6,g.chain.w-20,14,12)
  h.chain=txt(chain,"Counter","×0","text",10,21,g.chain.w-20,22,18)
 end
 local nr=g.next
 local nextCard=Kit.island(host,"Next",nr,12)
 local items={}
 if nr.w>=124 then
  local label=txt(nextCard,"Label","NEXT","dim",0,0,34,nr.h,12);table.insert(items,{node=label,w=TextService:GetTextSize("NEXT",12,Enum.Font.BuilderSansBold,Vector2.new(200,40)).X})
 end
 h.next={egg(nextCard,32)};table.insert(items,{node=h.next[1].ball,w=32,egg=true})
 if nr.w>=80 then h.next[2]=egg(nextCard,22);table.insert(items,{node=h.next[2].ball,w=22,egg=true})end
 local total=-8;for _,item in ipairs(items)do total+=item.w+8 end
 local x=math.floor((nr.w-total)/2)
 for _,item in ipairs(items)do
  local hh=if item.egg then item.w else nr.h
  item.node.Position=UDim2.fromOffset(x,math.floor((nr.h-hh)/2));if not item.egg then item.node.Size=UDim2.fromOffset(item.w,nr.h)end
  x+=item.w+8
 end
 local er=g.eggs
 local eggs=Kit.island(host,"EggsLeft",er,12)
 txt(eggs,"Label","EGGS","dim",12,6,er.w-20,14,12)
 h.eggs=txt(eggs,"Counter","0","text",12,21,40,22,18)
 if not g.eggsCompact then h.budget=txt(eggs,"Counter","/24","soft",40,24,40,20,13)end
 -- 4.3 left column.
 local goals=Kit.island(host,"Goals",{x=g.L0,y=g.goalsTop,w=g.L1-g.L0,h=24+3*g.goalPitch+6},12)
 h.goalsCard=goals;h.goalsBezel=goals.Parent
 local gw=g.L1-g.L0
 h.goalsEyebrow=txt(goals,"Label","GOALS","dim",12,4,gw-24,20,12)
 h.goalsCount=txt(goals,"Counter","","dim",12,4,gw-24,20,12,right)
 if g.chainInGoals then h.chain=txt(goals,"Label","CHAIN ×0","soft",12,4,gw-24,20,12,right);h.chainInGoals=true end
 h.status=txt(goals,"Body","","soft",12,26,gw-24,3*g.goalPitch,14,{TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,Visible=false})
 h.goals={}
 local p=g.goalPitch
 for index=1,3 do
  local row=Kit.frame(goals,"Goal"..index,nil,UDim2.fromOffset(0,24+(index-1)*p),UDim2.fromOffset(gw,p))
  local check=Kit.check(row,20);check.root.Position=UDim2.fromOffset(12,math.floor((p-20)/2))
  local text=txt(row,"BodyMedium","","text",40,0,gw-40-56,p,14,{TextTruncate=Enum.TextTruncate.AtEnd})
  local count=txt(row,"Counter","","soft",gw-56,0,44,p,13,right)
  h.goals[index]={row=row,check=check,text=text,count=count}
 end
 h.goalPitch=p;h.geometry=g
 -- Quest handle.
 local hr=g.handle
 local handle,handleBezel=Kit.island(host,"QuestHandle",hr,22,"well")
 local hit=Kit.node("TextButton",handle,{Name="Hit",Text="",BackgroundTransparency=1,AutoButtonColor=false,Size=UDim2.fromScale(1,1),ZIndex=handle.ZIndex+5,Selectable=false})
 hit:SetAttribute("AccessibleLabel","Daily quests")
 local icon=Kit.icon(handle,"quests",18,"text");icon.Position=UDim2.fromOffset(13,13)
 h.questDot=Kit.frame(icon,"ReadyDot","stars",UDim2.fromOffset(12,-3),UDim2.fromOffset(8,8),999);h.questDot.Visible=false
 if hr.w>=110 then txt(handle,"Strong","Quests","text",40,0,70,hr.h,14)end
 if hr.w>=150 then h.questCount=txt(handle,"Counter","","text",hr.w-92,0,56,hr.h,13,right)
 elseif hr.w>=84 and hr.w<110 then h.questCount=txt(handle,"Counter","","text",40,0,40,hr.h,13)end
 local chev=Kit.chevron(handle,14,"up","text");chev.Position=UDim2.fromOffset(hr.w-30,15)
 h.handle,h.handleBezel=handle,handleBezel
 hit.Activated:Connect(function()self:setDrawer(not self.drawerOpen)end)
 -- 4.5 right column.
 local dr=g.difficulty
 local diff=Kit.island(host,"Difficulty",dr,12)
 h.diffBars={}
 for index,bh in ipairs({10,16,22})do h.diffBars[index]=Kit.frame(diff,"Bar"..index,"stars",UDim2.fromOffset(12+(index-1)*9,33-bh),UDim2.fromOffset(6,bh),2)end
 h.diffName=txt(diff,"Strong","Medium","text",46,0,120,dr.h,15)
 if dr.w>=190 then
  h.diffChip=Kit.chip(diff,"★ ×1","gold",22);h.diffChip.label.TextSize=12;h.diffChip.set("★ ×1","gold")
  h.diffChip.root.AnchorPoint=Vector2.new(1,.5);h.diffChip.root.Position=UDim2.new(1,-10,.5,0)
 end
 local pr=g.winPays
 local pays=Kit.island(host,"WinPays",pr,12)
 txt(pays,"Label","WIN PAYS","dim",12,0,100,pr.h,12)
 local pair=Kit.frame(pays,"Amount",nil,UDim2.new(1,-12,.5,0),UDim2.fromOffset(0,24));pair.AnchorPoint=Vector2.new(1,.5);pair.AutomaticSize=Enum.AutomaticSize.X
 Kit.node("UIListLayout",pair,{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
 local star=Kit.icon(pair,"star",17);star.LayoutOrder=1
 h.pays=Kit.text(pair,"Counter","6–8","stars",{TextSize=17,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,24),LayoutOrder=2})
 -- 4.4 quest drawer (built hidden; covers the Goals card, d-pad and handle).
 local wr=g.drawer
 local drawer,drawerBezel=Kit.island(host,"QuestDrawer",wr,14)
 drawerBezel.ZIndex=host.ZIndex+20;drawer.Active=true;drawerBezel.Visible=false
 for _,node in ipairs(drawerBezel:GetDescendants())do if node:IsA("GuiObject")then node.ZIndex+=20 end end
 local function dz(node)node.ZIndex=drawer.ZIndex+1;return node end
 dz(txt(drawer,"Label","DAILY QUESTS","dim",12,16,wr.w-60,14,12))
 local close=Kit.node("TextButton",drawer,{Name="Close",Text="",BackgroundTransparency=1,AutoButtonColor=false,Position=UDim2.fromOffset(wr.w-44,0),Size=UDim2.fromOffset(44,44),ZIndex=drawer.ZIndex+3,Selectable=false})
 close:SetAttribute("AccessibleLabel","Close daily quests")
 local cchev=Kit.chevron(close,14,"down","text");cchev.Position=UDim2.fromOffset(15,15)
 for _,node in ipairs(cchev:GetDescendants())do if node:IsA("GuiObject")then node.ZIndex=close.ZIndex+1 end end;cchev.ZIndex=close.ZIndex+1
 close.Activated:Connect(function()self:setDrawer(false)end)
 h.daily={}
 for index=1,3 do
  local y=46+(index-1)*44
  local name=dz(txt(drawer,"Body","","text",12,y,wr.w-24-56,20,14,{TextTruncate=Enum.TextTruncate.AtEnd}))
  local count=dz(txt(drawer,"Counter","","soft",wr.w-68,y,56,20,13,right))
  local bar=Kit.progress(drawer,4);bar.root.Position=UDim2.fromOffset(12,y+28);bar.root.Size=UDim2.fromOffset(wr.w-24,4)
  bar.root.ZIndex=drawer.ZIndex+1;for _,node in ipairs(bar.root:GetDescendants())do if node:IsA("GuiObject")then node.ZIndex=drawer.ZIndex+2 end end
  h.daily[index]={name=name,count=count,bar=bar}
 end
 local open=Kit.button(drawer,"OpenQuestLog",{text="Open quest log",size=Vector2.new(wr.w-24,44),textSize=15,selectable=false})
 open.Position=UDim2.fromOffset(12,wr.h-12-44)
 open.Activated:Connect(function()self:setDrawer(false);if self.callbacks.menu then self.callbacks.menu()end end)
 h.drawer,h.drawerBezel=drawer,drawerBezel
 drawer.InputBegan:Connect(function()self.drawerTouched=os.clock()end)
 self.drawerOpen=false
 -- Wordmark: decoration that leaves first (placed by setHud once the goal count is known).
 self.wordmark.Visible=false
 self.lastHud=nil;self.controlsKey=nil
end

-- Drawer open / close (UI-SPEC-COMPACT 4.4). Returns true when it changed.
function Screen:setDrawer(open)
 local h=self.hud;if not(h and h.drawerBezel)then return false end
 open=open==true
 if open==self.drawerOpen then return false end
 self.drawerOpen=open;self.drawerTouched=os.clock()
 local bezel=h.drawerBezel;local home=bezel.Position
 self.root:SetAttribute("QuestDrawerOpen",open)
 if open then
  bezel.Visible=true
  if not Kit.reduced()then
   bezel.Position=home+UDim2.fromOffset(0,24);Kit.tween(bezel,.14,{Position=home})
  end
  local token=self.drawerTouched
  task.spawn(function()
   while self.drawerOpen do
    task.wait(.5)
    if self.drawerOpen and os.clock()-(self.drawerTouched or 0)>=6 then self:setDrawer(false)end
   end
   local _=token
  end)
  if not self.outsideTap then
   local UIS=game:GetService("UserInputService")
   self.outsideTap=UIS.InputBegan:Connect(function(input)
    if not self.drawerOpen then return end
    local t=input.UserInputType
    if t~=Enum.UserInputType.MouseButton1 and t~=Enum.UserInputType.Touch then return end
    local hh=self.hud;if not(hh and hh.drawerBezel)then return end
    local p=input.Position
    local gui=hh.drawerBezel:FindFirstAncestorWhichIsA("PlayerGui")
    local inside=false
    if gui then
     for _,node in ipairs(gui:GetGuiObjectsAtPosition(p.X,p.Y))do
      if node==hh.drawerBezel or node:IsDescendantOf(hh.drawerBezel)or node==hh.handleBezel or node:IsDescendantOf(hh.handleBezel)then inside=true;break end
     end
    end
    if inside then self.drawerTouched=os.clock()else self:setDrawer(false)end
   end)
  end
 else
  bezel.Visible=false
 end
 return true
end
-- Back (B, Backspace, the back arrow) closes an open drawer first.
function Screen:closeDrawer()return self:setDrawer(false)end

function Screen:buildHud(g)
 if self.hudRoot then self.hudRoot:Destroy()end
 self.drawerOpen=false
 if g.phone then return self:buildCompactHud(g)end
 self.builtMode=g.mode;local compact=g.compact
 local host=Kit.frame(self.content,"HUD",nil,UDim2.new(),UDim2.fromScale(1,1));self.hudRoot=host
 local h={};self.hud=h
 local pad=if compact then 8 else 14
 local col=g.column;local leftX=g.pad;local rightX=g.boardLocal.x+g.boardLocal.w+g.pad
 local function txt(parent,role,content,color,x,y,w,hh,props)
  local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,hh)
  if not(props and props.TextSize)then Kit.setCompact(t,compact)end;return t
 end
 if not compact then
  -- Left panel.
  local score=card(host,"Score",{leftX,12,col,96},"SCORE",pad)
  h.score=txt(score,"CounterL","0","text",14,31,col-28,40)
  h.best=txt(score,"Counter","BEST 0","dim",14,72,col-28,16,{TextSize=13})
  local chain=card(host,"Chain",{leftX,116,col,64},"CHAIN",pad)
  h.chain=txt(chain,"Counter","×0","text",14,30,60,24,{TextSize=22})
  h.chainBar=Kit.progress(chain,10,5);h.chainBar.root.Position=UDim2.fromOffset(84,36);h.chainBar.layout(116,4)
  local goals,eyebrow=card(host,"Goals",{leftX,188,col,244},"GOALS",pad);h.goalsEyebrow=eyebrow
  h.goalsCount=txt(goals,"Counter","0/2","dim",col-74,10,60,20,{TextSize=13,TextXAlignment=Enum.TextXAlignment.Right})
  h.status=txt(goals,"Small","","soft",14,40,col-28,190,{TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,Visible=false})
  h.goals={}
  for index=1,3 do
   local y=38+(index-1)*68
   local row=Kit.frame(goals,"Goal"..index,nil,UDim2.fromOffset(0,y),UDim2.fromOffset(col,64))
   local check=Kit.check(row,22);check.root.Position=UDim2.fromOffset(14,4)
   local text=txt(row,"BodyMedium","","text",46,0,col-60,40,{TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
   local bar=Kit.progress(row,6);bar.root.Position=UDim2.fromOffset(46,44);bar.root.Size=UDim2.fromOffset(math.min(130,col-104),6)
   local count=txt(row,"Counter","","soft",col-62,37,48,20,{TextSize=13,TextXAlignment=Enum.TextXAlignment.Right})
   h.goals[index]={row=row,check=check,text=text,bar=bar,count=count}
  end
  local daily=card(host,"DailyQuests",{leftX,440,col,156},"DAILY QUESTS",pad)
  h.daily={}
  for index=1,3 do
   local y=38+(index-1)*38
   local name=txt(daily,"Small","","text",14,y,col-80,18)
   local count=txt(daily,"Counter","","soft",col-74,y,60,18,{TextSize=13,TextXAlignment=Enum.TextXAlignment.Right})
   local bar=Kit.progress(daily,4);bar.root.Position=UDim2.fromOffset(14,y+22);bar.root.Size=UDim2.fromOffset(col-28,4)
   h.daily[index]={name=name,count=count,bar=bar}
  end
  -- Right panel.
  local nextCard=card(host,"Next",{rightX,12,col,140},"NEXT",pad)
  h.next={egg(nextCard,68)};h.next[1].ball.Position=UDim2.fromOffset(62-34,82-34)
  txt(nextCard,"Label","THEN","dim",132,42,60,16)
  h.next[2]=egg(nextCard,40);h.next[2].ball.Position=UDim2.fromOffset(150-20,92-20)
  h.next[3]=egg(nextCard,40);h.next[3].ball.Position=UDim2.fromOffset(math.min(col-46,196-20),92-20)
  local eggs=card(host,"EggsLeft",{rightX,160,col,96},"EGGS LEFT",pad)
  h.eggs=txt(eggs,"CounterL","0","text",14,30,70,40);h.eggs.AutomaticSize=Enum.AutomaticSize.X
  h.budget=txt(eggs,"Counter","/24","dim",70,40,80,24)
  h.eggBar=Kit.progress(eggs,6);h.eggBar.root.Position=UDim2.fromOffset(14,76);h.eggBar.root.Size=UDim2.fromOffset(col-28,6)
  local diff=card(host,"Difficulty",{rightX,264,col,72},nil,pad)
  h.diffBars={}
  for index,bh in ipairs({10,16,22})do
   local bar=Kit.frame(diff,"Bar"..index,"stars",UDim2.fromOffset(16+(index-1)*9,25+22-bh),UDim2.fromOffset(6,bh),2);h.diffBars[index]=bar
  end
  h.diffName=txt(diff,"Heading","Medium","text",52,0,100,72)
  h.diffChip=Kit.chip(diff,"★ ×1","gold",26);h.diffChip.root.AnchorPoint=Vector2.new(1,.5);h.diffChip.root.Position=UDim2.new(1,-14,.5,0)
  local pays=card(host,"WinPays",{rightX,344,col,84},"WIN PAYS",pad)
  local star=Kit.icon(pays,"star",26);star.Position=UDim2.fromOffset(14,31)
  h.pays=txt(pays,"Counter","6–8","stars",46,30,col-60,28,{TextSize=26})
  h.paysCaption=txt(pays,"Small","Higher with a tidy stack","dim",14,60,col-28,18,{TextSize=13})
  local controls=card(host,"Controls",{rightX,436,col,160},"CONTROLS",pad)
  h.controls={}
  for index=1,4 do
   local y=42+(index-1)*30
   local holder=Kit.frame(controls,"Hint"..index,nil,UDim2.fromOffset(14,y),UDim2.fromOffset(56,22))
   local textLabel=txt(controls,"Small","","text",76,y,col-90,22)
   h.controls[index]={holder=holder,text=textLabel}
  end
 else
  -- Compact (7): authored at 417x299, padding 6.
  local score=card(host,"Score",{leftX,6,col,54},"SCORE",pad)
  h.score=txt(score,"CounterL","0","text",8,22,col-16,28)
  local goals,eyebrow=card(host,"Goals",{leftX,66,col,136},"GOALS",pad);h.goalsEyebrow=eyebrow
  h.goalsCount=txt(goals,"Counter","","dim",col-50,4,42,16,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
  h.status=txt(goals,"Small","","soft",8,24,col-16,108,{TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,Visible=false})
  h.goals={}
  for index=1,3 do
   local row=Kit.frame(goals,"Goal"..index,nil,UDim2.fromOffset(0,26+(index-1)*34),UDim2.fromOffset(col,32))
   local check=Kit.check(row,20);check.root.Position=UDim2.fromOffset(8,4)
   local text=txt(row,"BodyMedium","","text",34,0,col-40,28,{TextWrapped=true})
   h.goals[index]={row=row,check=check,text=text}
  end
  local chain=card(host,"Chain",{leftX,208,col,85},"CHAIN",pad)
  h.chain=txt(chain,"Counter","×0","text",8,26,col-16,26)
  h.chainBar=Kit.progress(chain,8,5);h.chainBar.root.Position=UDim2.fromOffset(8,62);h.chainBar.layout(col-24,4)
  local nextCard=card(host,"Next",{rightX,6,col,84},"NEXT",pad)
  h.next={egg(nextCard,40),egg(nextCard,24)}
  h.next[1].ball.Position=UDim2.fromOffset(12,30);h.next[2].ball.Position=UDim2.fromOffset(66,42)
  local eggs=card(host,"EggsLeft",{rightX,96,col,64},"EGGS LEFT",pad)
  h.eggs=txt(eggs,"CounterL","0","text",8,22,50,26);h.budget=txt(eggs,"Counter","/24","dim",50,26,56,20,{TextSize=15})
  h.eggBar=Kit.progress(eggs,5);h.eggBar.root.Position=UDim2.fromOffset(8,52);h.eggBar.root.Size=UDim2.fromOffset(col-16,5)
  local diff=card(host,"Difficulty",{rightX,166,col,60},nil,pad)
  h.diffBars={}
  for index,bh in ipairs({8,12,16})do h.diffBars[index]=Kit.frame(diff,"Bar"..index,"stars",UDim2.fromOffset(8+(index-1)*7,10+16-bh),UDim2.fromOffset(5,bh),2)end
  h.diffName=txt(diff,"Strong","Medium","text",34,6,col-40,22,{TextSize=15})
  h.diffChip=Kit.chip(diff,"★ ×1","gold",20);h.diffChip.root.Position=UDim2.fromOffset(8,32)
  local pays=card(host,"WinPays",{rightX,232,col,61},"WIN PAYS",pad)
  local star=Kit.icon(pays,"star",18);star.Position=UDim2.fromOffset(8,30)
  h.pays=txt(pays,"Counter","6–8","stars",30,26,col-36,26,{TextSize=17})
 end
 -- A rebuilt HUD has empty control rows; repaint them on the next setHud.
 self.lastHud=nil;self.controlsKey=nil
end

local controlRows={
 Gamepad={{"◀▶","Aim"},{"A","Drop"},{"B","Pause and leave"},{"MENU","Quest log"}},
 Keyboard={{"← →","Aim"},{"Space","Drop"},{"Bksp","Leave"},{"M","Quest log"}},
 Touch={{"Drag","Drag to aim"},{"A","A or release to drop"},{"MENU","Quest log"},{"←","Back arrow leaves"}},
}
local function eggPaint(slot,tier)
 tier=math.clamp(tier or 1,1,#Config.Tiers)
 Art.jellyPreview(slot.ball,tier,slot.mark);slot.mark.Text=Config.Tiers[tier].mark
 slot.mark.TextColor3=JellyPalette.Ink or Kit.Color.ink
end
-- data: score,best,chain,goals{text,short,done,progress,target},status,daily{title,progress,target},
-- next{t1,t2,t3},eggsLeft,budget,difficulty,multiplier,winPays,input("Gamepad"|"Keyboard"|"Touch")
function Screen:setHud(data)
 local h=self.hud;if not h.score then return end
 if h.phone then return self:setCompactHud(data)end
 local compact=self.geometry and self.geometry.compact
 h.score.Text=tostring(data.score or 0)
 if h.best then h.best.Text="BEST "..tostring(data.best or 0)end
 h.chain.Text="×"..tostring(data.chain or 0);h.chainBar.set(math.min(5,data.chain or 0))
 local goals=data.goals or {}
 local status=data.message
 h.status.Visible=status~=nil and status~=""
 if h.status.Visible then h.status.Text=status end
 local done=0
 for index,slot in ipairs(h.goals)do
  local goal=goals[index]
  slot.row.Visible=goal~=nil and not h.status.Visible
  if goal then
   if goal.done then done+=1 end
   slot.check.set(goal.done)
   slot.text.Text=if compact then goal.short or goal.text else goal.text
   slot.text.TextColor3=if goal.done then Kit.Color.soft else Kit.Color.text
   if slot.bar then slot.bar.set(if goal.done then 1 else goal.progress or 0,if goal.done then 1 else math.max(1,goal.target or 1),false,true)end
   if slot.count then slot.count.Text=if goal.done then string.format("%d/%d",goal.target or 1,goal.target or 1)else string.format("%d/%d",goal.progress or 0,goal.target or 1)end
  end
 end
 h.goalsCount.Text=if #goals>0 and not h.status.Visible then string.format("%d/%d",done,#goals)else ""
 if compact then h.goalsEyebrow.Text=if #goals>0 and not h.status.Visible then string.format("GOALS %d/%d",done,#goals)else "GOALS";h.goalsCount.Text=""end
 -- Status lines ("Falling", "Settling", save waits) replace the Goals label row.
 if data.statusLabel and data.statusLabel~="" then h.goalsEyebrow.Text=string.upper(data.statusLabel);h.goalsEyebrow.TextColor3=Kit.Color.stars;h.goalsCount.Text=""
 elseif not compact then h.goalsEyebrow.Text="GOALS";h.goalsEyebrow.TextColor3=Kit.Color.dim
 else h.goalsEyebrow.TextColor3=Kit.Color.dim end
 if h.daily then
  for index,slot in ipairs(h.daily)do
   local q=data.daily and data.daily[index]
   slot.name.Visible,slot.count.Visible,slot.bar.root.Visible=q~=nil,q~=nil,q~=nil
   if q then slot.name.Text=q.title;slot.count.Text=string.format("%d/%d",math.min(q.progress,q.target),q.target);slot.bar.set(q.progress,q.target,q.done,true)end
  end
 end
 for index,slot in ipairs(h.next)do eggPaint(slot,data.next and data.next[index])end
 h.eggs.Text=tostring(data.eggsLeft or 0);h.budget.Text="/"..tostring(data.budget or 24)
 local digits=game:GetService("TextService"):GetTextSize(h.eggs.Text,h.eggs.TextSize,Enum.Font.RobotoMono,Vector2.new(500,80)).X
 h.budget.Position=UDim2.fromOffset(h.eggs.Position.X.Offset+digits+6,h.budget.Position.Y.Offset)
 h.eggBar.set(data.eggsLeft or 0,data.budget or 24,false,true)
 local level=({Easy=1,Medium=2,Hard=3})[data.difficulty or "Medium"]or 2
 local tone=if level==1 then Kit.Color.good elseif level==3 then Kit.Color.danger else Kit.Color.stars
 for index,bar in ipairs(h.diffBars)do bar.BackgroundColor3=tone;bar.BackgroundTransparency=if index<=level then 0 else .75 end
 h.diffName.Text=data.difficulty or "Medium";h.diffChip.set("★ "..(data.multiplier or "×1"),"gold")
 h.pays.Text=data.winPays or "6–8"
 if h.controls then
  local rows=controlRows[data.input or "Keyboard"]or controlRows.Keyboard
  local key=data.input or "Keyboard"
  if self.controlsKey~=key then
   self.controlsKey=key
   for index,slot in ipairs(h.controls)do
    slot.holder:ClearAllChildren()
    local row=rows[index]
    slot.text.Text=row and row[2]or ""
    if row then Kit.glyph(slot.holder,row[1],false,22)end
   end
  end
 end
end

-- Compact HUD paint: same data contract as setHud.
function Screen:setCompactHud(data)
 local h=self.hud;local g=h.geometry
 h.score.Text=commas(data.score)
 h.chain.Text=(if h.chainInGoals then "CHAIN ×"else "×")..tostring(data.chain or 0)
 local goals=data.goals or {}
 local status=data.message
 h.status.Visible=status~=nil and status~=""
 if h.status.Visible then h.status.Text=status end
 local done=0
 for index,slot in ipairs(h.goals)do
  local goal=goals[index]
  slot.row.Visible=goal~=nil and not h.status.Visible
  if goal then
   if goal.done then done+=1 end
   slot.check.set(goal.done)
   slot.text.Text=goal.short or goal.text
   slot.text.TextColor3=if goal.done then Kit.Color.soft else Kit.Color.text
   slot.count.Text=if goal.done then string.format("%d/%d",goal.target or 1,goal.target or 1)else string.format("%d/%d",goal.progress or 0,goal.target or 1)
  end
 end
 h.goalsCount.Text=""
 if data.statusLabel and data.statusLabel~=""then h.goalsEyebrow.Text=string.upper(data.statusLabel);h.goalsEyebrow.TextColor3=Kit.Color.stars
 else h.goalsEyebrow.Text=if #goals>0 and not h.status.Visible then string.format("GOALS %d/%d",done,#goals)else "GOALS";h.goalsEyebrow.TextColor3=Kit.Color.dim end
 -- Card height follows the goal count (two rows for a status message).
 local n=if h.status.Visible then 2 else math.max(1,#goals)
 local cardH=24+n*h.goalPitch+6
 if h.cardH~=cardH then
  h.cardH=cardH
  h.goalsCard.Size=UDim2.fromOffset(h.goalsCard.Size.X.Offset,cardH);h.goalsBezel.Size=UDim2.fromOffset(h.goalsBezel.Size.X.Offset,cardH+6)
  h.status.Size=UDim2.fromOffset(h.status.Size.X.Offset,n*h.goalPitch)
  self:placeCompactWordmark(g.goalsTop+cardH)
 end
 -- Drawer rows and the handle.
 local daily=data.daily or {}
 local claimed,ready=0,false
 for index,slot in ipairs(h.daily)do
  local q=daily[index]
  slot.name.Visible,slot.count.Visible,slot.bar.root.Visible=q~=nil,q~=nil,q~=nil
  if q then
   slot.name.Text=q.title;slot.count.Text=string.format("%d/%d",math.min(q.progress,q.target),q.target)
   slot.count.TextColor3=if q.done then Kit.Color.stars else Kit.Color.soft
   slot.bar.set(q.progress,q.target,q.done,true)
   if q.done then claimed+=1 end
   if q.ready then ready=true end
  end
 end
 if h.questCount then h.questCount.Text=string.format("%d/%d",claimed,#daily)end
 h.questDot.Visible=ready
 for index,slot in ipairs(h.next)do eggPaint(slot,data.next and data.next[index])end
 h.eggs.Text=tostring(data.eggsLeft or 0)
 if h.budget then
  h.budget.Text="/"..tostring(data.budget or 24)
  local digits=game:GetService("TextService"):GetTextSize(h.eggs.Text,18,Enum.Font.RobotoMono,Vector2.new(500,80)).X
  h.budget.Position=UDim2.fromOffset(12+digits+4,24)
 end
 local level=({Easy=1,Medium=2,Hard=3})[data.difficulty or "Medium"]or 2
 local tone=if level==1 then Kit.Color.good elseif level==3 then Kit.Color.danger else Kit.Color.stars
 for index,bar in ipairs(h.diffBars)do bar.BackgroundColor3=tone;bar.BackgroundTransparency=if index<=level then 0 else .75 end
 h.diffName.Text=data.difficulty or "Medium"
 if h.diffChip then h.diffChip.set("★ "..(data.multiplier or "×1"),"gold");h.diffChip.label.TextSize=12 end
 h.pays.Text=data.winPays or "6–8"
end

-- The wordmark sits between the Goals card and the handle, right of the d-pad,
-- only when that gap is 100+ wide and tall enough with 10 px to spare.
function Screen:placeCompactWordmark(goalsBottom)
 local g=self.geometry;if not(g and g.phone)then return end
 local x0,x1=g.handle.x,g.L1;local y0,y1=goalsBottom,g.handle.y
 local w=math.min(123,x1-x0);local hh=w*16/41
 local fits=(x1-x0)>=100 and(y1-y0)>=hh+20
 self.wordmark.Visible=fits
 if fits then
  self.wordmark.Position=UDim2.fromOffset(math.floor(x0+(x1-x0-w)/2),math.floor(y0+(y1-y0-hh)/2))
  self.wordmark.Size=UDim2.fromOffset(w,hh)
 end
end
return Screen
