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
function Screen.resolve(root,aspect)
 local W,H=root.X,root.Y
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
 return{s=s,compact=compact,mode=if compact then "Compact"else "Regular",deck=deck,lcd=lcd,authored=authored,
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
 self.plateOverlay=image(root,"PlateOverlay",I.plateOverlay,5)
 self.wordmarkShadow=image(root,"WordmarkShadow",I.wordmark,6,{ResampleMode=Enum.ResamplerMode.Pixelated,ImageColor3=Color3.new(1,1,1),ImageTransparency=.7})
 self.wordmark=image(root,"Wordmark",I.wordmark,6,{ResampleMode=Enum.ResamplerMode.Pixelated})
 self.glass=image(root,"Glass",I.glass,7)
 self.led=image(root,"Led",I.led,11)
 -- LCD: panel glass with one white 3% to black 12% overlay gradient.
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
 -- Back arrow lives on the interactive root, never on the deck body.
 self.back=Kit.backArrow(options.viewRoot,false)
 self.back.root.Activated:Connect(function()if self.back.enabled and self.callbacks.back then self.callbacks.back()end end)
 self.toaster=Kit.toaster(options.viewRoot)
 GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(function()self:applyTransparency()end)
 return self
end

function Screen:on(name,callback)self.callbacks[name]=callback end

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
 local band=theme.bandTint or Color3.new(1,1,1)
 self.band.ImageColor3=band;for _,s in ipairs(self.shoulders)do s.ImageColor3=band end
 self.wordmark.ImageColor3=theme.engrave or Kit.Color.ink;self.wordmark.ImageTransparency=1-(theme.engraveOpacity or .42)
 local accent=theme.ui and theme.ui.accent or theme.buttons
 self.buttons.A.base.ImageColor3=accent;self.dpadArrows.ImageColor3=accent;self.led.ImageColor3=accent
 self.buttons.A.letter.TextColor3=theme.ui and theme.ui.ink or Kit.Color.ink
end

function Screen:setVisible(visible)
 self.visible=visible
 self.root.Visible=visible;self.back.root.Visible=visible and self.backVisible~=false
 self:applyTransparency()
end

-- Places every sprite and returns the resolved geometry (view px).
function Screen:layout(rootSize,aspect)
 local g=Screen.resolve(rootSize,aspect);self.geometry=g
 local s=g.s
 self.root.Position=UDim2.fromOffset(g.deck.x,g.deck.y);self.root.Size=UDim2.fromOffset(g.deck.w,g.deck.h)
 placeU(self.shadow,L.shadow,s);self.shadow.SliceScale=s
 placeU(self.shoulders[1],L.shoulderL,s);placeU(self.shoulders[2],L.shoulderR,s)
 placeU(self.band,L.band,s);placeU(self.plate,L.plate,s);placeU(self.plateOverlay,L.plate,s)
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
 self.resultsContent.Size=self.content.Size;self.resultsScale.Scale=g.contentScale
 local inset=if g.compact then 12 else 24
 self.back.setCompact(g.compact);self.back.root.Position=UDim2.new(1,-inset,0,inset)
 local b=g.boardLocal
 self.well.Position=UDim2.fromOffset(b.x,b.y);self.well.Size=UDim2.fromOffset(b.w,b.h)
 if self.builtMode~=g.mode then self:buildHud(g)end
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
 local mark=Kit.text(ball,"Strong","I",nil,{Name="Mark",Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=math.max(11,math.floor(diameter*.42))})
 Art.jellyPreview(ball,1,mark)
 return{ball=ball,mark=mark}
end
function Screen:buildHud(g)
 if self.hudRoot then self.hudRoot:Destroy()end
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
 Gamepad={{"◀▶","Aim"},{"A","Drop"},{"B","Pause and leave"},{"MENU","Menu"}},
 Keyboard={{"← →","Aim"},{"Space","Drop"},{"Bksp","Leave"},{"M","Menu"}},
 Touch={{"Drag","Drag to aim"},{"A","A or release to drop"},{"MENU","Menu"},{"←","Back arrow leaves"}},
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
return Screen
