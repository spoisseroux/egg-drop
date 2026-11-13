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
-- Compact v2, the slim frame (UI-SPEC-COMPACT-FRAME-2026-11-12, section 9 decisions):
-- one glass LCD between two shoulders, every HUD card inside the screen, the board
-- centred. Mirrors frame_geometry() in scripts/deck_art/build_compact_frame_mockups.py.
local RIM,BEZ,PAD,GAP=4,5,3,8
local function pocketGeometry(g)
 local s=g.screen;local pad=12
 local top=math.max(s.y+pad+36,g.kh+4)
 local avail=s.y+s.h-pad-top
 local cols=if 5*44+4*GAP<=avail then 1 else 2
 local rows=if cols==1 then 5 else 3
 local iw=if cols==1 then math.min(300,s.w-2*pad)else math.min(220,math.floor((s.w-2*pad-GAP)/2))
 local gx=s.x+math.floor((s.w-(iw*cols+GAP*(cols-1)))/2)
 local gy=top+math.max(0,math.floor((avail-(rows*44+(rows-1)*GAP))/2))
 local order=if cols==1 then {{0,0},{0,1},{0,2},{0,3},{0,4}}else {{0,0},{0,1},{0,2},{1,0},{1,1}}
 local items={}
 for i,cr in ipairs(order)do items[i]=rect(gx+cr[1]*(iw+GAP),gy+cr[2]*(44+GAP),iw,44)end
 local tx=if s.y+pad<g.kh then math.max(s.x+pad,g.kx+4)else s.x+pad
 return{cols=cols,items=items,title=rect(tx,s.y+pad,s.x+s.w-pad-tx,28)}
end
Screen.pocketGeometry=pocketGeometry
-- Plate grip either side of a phone menu sheet (UI-SPEC-COMPACT-FRAME 4).
function Screen.gripMargin(W)return if W>=800 then 40 elseif W>=700 then 24 else 6 end
function Screen.resolveCompact(W,H,aspect,kx,kh)
 kx=kx or 116;kh=kh or 58
 local tier=if H>=380 then 0 elseif H>=340 then 1 else 2
 -- QA 2026-11-12: the glass starts under the Roblox controls (`top`), never behind them,
 -- and the shoulders are 18 px wider so the screen reads less wide.
 local SW=({124,112,98})[tier+1];local D=({88,80,68})[tier+1];local A=({92,82,70})[tier+1]
 local top=kh+2
 local g={s=1,compact=false,phone=true,mode="Compact",W=W,H=H,kx=kx,kh=kh,aspect=aspect,tier=tier,SW=SW,D=D,A=A,
  deck=rect(0,0,W,H),contentScale=1,pad=0}
 g.top=top
 g.glass=rect(SW,top,W-2*SW,H-top-RIM)
 g.screen=rect(SW+BEZ,top+BEZ,W-2*SW-2*BEZ,H-top-RIM-2*BEZ)
 local x0,y0=SW+BEZ+PAD,top+BEZ+PAD
 local x1,y1=W-x0,H-(RIM+BEZ+PAD)
 local LW,LH=x1-x0,y1-y0
 g.x0,g.y0,g.x1,g.y1,g.LW,g.LH=x0,y0,x1,y1,LW,LH
 -- Board: full screen height unless the side columns would drop under 96.
 local full=math.floor(LH*aspect+.5)
 local bw=math.min(full,LW-2*GAP-2*96)
 local bh=if bw==full then LH else math.floor(bw/aspect+.5)
 local c2=math.floor((LW-bw-2*GAP)/2)
 local layout=if c2>=144 then "wide"elseif c2>=96 then "narrow"else "one"
 if layout=="one"then bw=math.min(full,LW-GAP-160);bh=if bw==full then LH else math.floor(bw/aspect+.5)end
 g.layout=layout;g.columns=if layout=="one"then 1 else 2
 local by=y0+math.floor((LH-bh)/2)
 local p=if H>=340 then 34 else 26
 g.goalPitch=p
 local t0=if y0<kh then math.max(x0,kx+4)else x0
 g.t0=t0
 local bx
 if layout~="one"then
  bx=x0+math.floor((LW-bw)/2)
  local L0,L1,R0,R1=x0,bx-GAP,bx+bw+GAP,x1
  local c,rc=L1-L0,R1-R0
  g.L0,g.L1,g.R0,g.R1,g.column,g.columnR=L0,L1,R0,R1,c,rc
  local tw=L1-t0
  local gy
  if layout=="wide"then
   if tw>=154 then g.chain=rect(L1-64,y0,64,44);g.score=rect(t0,y0,tw-64-GAP,44);g.chainIn="pill"
   else g.score=rect(t0,y0,tw,44);g.chainIn=if tw>=130 then "score"else "goals"end
   gy=y0+52
  else
   -- Narrow (decision 5): Chain in the first row beside the Roblox controls, Score under it.
   if tw>=64 then g.chain=rect(t0,y0,tw,44);g.chainIn="pill"else g.chainIn="goals"end
   g.score=rect(L0,y0+52,c,44);gy=y0+104
  end
  g.goalsTop=gy;g.goals=rect(L0,gy,c,24+3*p+6)
  local qp=if H>=380 then 36 else 34;local qh=24+3*qp+8
  if layout=="wide"and y1-qh>=gy+24+3*p+6+GAP then g.quests=rect(L0,y1-qh,c,qh);g.questPitch=qp
  else g.handle=rect(L0,y1-44,c,44)end
  local nh=if H>=340 then 64 else 44
  g.next=rect(R0,y0,rc,nh)
  g.eggs=rect(R0,y0+nh+GAP,rc,44);g.difficulty=rect(R0,y0+nh+GAP+52,rc,44);g.winPays=rect(R0,y0+nh+GAP+104,rc,44)
  local top=y0+nh+GAP+156
  local rows=math.min(3,math.floor((y1-top-30)/28))
  if rows>=2 then g.controls=rect(R0,y1-(30+rows*28),rc,30+rows*28);g.controlRows=rows else g.controlRows=0 end
  g.toast=Vector2.new(R0+math.floor(rc/2),y1-48)
 else
  bx=x1-bw
  local L0,L1=x0,bx-GAP;local c=L1-L0
  g.L0,g.L1,g.column,g.columnR=L0,L1,c,0
  local tw=L1-t0
  g.next=rect(L1-76,y0,76,44)
  if tw>=76+GAP+64+GAP+84 then g.chain=rect(L1-76-GAP-64,y0,64,44);g.score=rect(t0,y0,tw-76-64-2*GAP,44);g.chainIn="pill"
  else g.score=rect(t0,y0,tw-76-GAP,44);g.chainIn="goals"end
  local gh=24+3*p+6
  g.goalsTop=y0+52;g.goals=rect(L0,y0+52,c,gh)
  local ry=y0+52+gh+GAP;local ew=if c>=200 then 88 else 58
  g.eggs=rect(L0,ry,ew,44);g.difficulty=rect(L0+ew+GAP,ry,c-ew-GAP,44)
  local wy=ry+52
  g.winPays=rect(L0,wy,c,if wy+44<=y1-52 then 44 else y1-52-wy)
  g.handle=rect(L0,y1-44,c,44);g.controlRows=0
  g.toast=Vector2.new(L0+math.floor(c/2),y1-44-48)
 end
 g.chainInGoals=g.chainIn=="goals"
 g.board=rect(bx,by,bw,bh);g.lcd=g.board;g.boardLocal=rect(0,0,bw,bh);g.authored=Vector2.new(bw,bh)
 -- Shoulders: d-pad (two 44+ halves), MENU, wordmark; A on the right at mid height. No B (decision 4).
 local dcy=kh+math.floor((H-kh-52)/2);local cx=math.floor(SW/2)
 g.dpad=rect(cx-math.floor(D/2),dcy-math.floor(D/2),D,D)
 local hw,hh=math.max(44,math.floor(D/2)),math.max(44,D);local shift=math.max(0,hw-cx)
 g.dpadLeft=rect(cx-hw+shift,dcy-math.floor(hh/2),hw,hh);g.dpadRight=rect(cx+shift,dcy-math.floor(hh/2),hw,hh)
 local mw,mh=math.min(72,SW-16),math.min(84,SW-8)
 g.menuHit=rect(cx-math.floor(mh/2),H-52,mh,44);g.menu=rect(cx-math.floor(mw/2),H-44,mw,28)
 local ww=SW-28
 g.wordmark=if ww>=64 then rect(14,kh+6,ww,math.floor(ww*16/41+.5))else nil
 g.back=rect(W-56,8,44,44)
 g.a=Vector2.new(W-cx,math.floor(H*.49+.5))
 g.aHit=rect(W-cx-math.floor((A+8)/2),g.a.Y-math.floor((A+8)/2),A+8,A+8)
 -- Menu sheet (section 4): plate grips `mg` either side; v1 rules shift in by mg - 6.
 local mg=Screen.gripMargin(W)
 g.mg=mg;g.off=mg-6
 -- Sheets also sit under the Roblox controls: their content is padded down by `top`
 -- (Screen:placeOverlay), so in sheet coordinates there is no keep-out.
 local SH=H-top
 g.sheet=rect(mg+2,top,W-2*mg-4,SH-8);g.hx=mg+18
 g.cw=math.floor((W-2*mg-48)/3);g.ch=SH-140;g.actionY=SH-66
 g.pocket=pocketGeometry(g)
 return g
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
 -- Compact v2: the plate lip and shade, one glass (bezel) between the shoulders and the lit screen in it.
 self.phoneNodes={}
 local function phoneNode(node)node.Visible=false;table.insert(self.phoneNodes,node);return node end
 self.plateLip=phoneNode(Kit.frame(root,"PlateLip",nil,UDim2.new(),UDim2.new(1,0,.3,0)));self.plateLip.ZIndex=5
 self.plateLip.BackgroundTransparency=0;self.plateLip.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",self.plateLip,{Rotation=90,Transparency=NumberSequence.new(.75,1)})
 self.plateShade=phoneNode(Kit.frame(root,"PlateShade",nil,UDim2.fromScale(0,.62),UDim2.fromScale(1,.38)));self.plateShade.ZIndex=5
 self.plateShade.BackgroundTransparency=0;self.plateShade.BackgroundColor3=Color3.new(0,0,0)
 Kit.node("UIGradient",self.plateShade,{Rotation=90,Transparency=NumberSequence.new(1,.71)})
 self.glassLip=phoneNode(Kit.frame(root,"GlassLip",nil,UDim2.new(),UDim2.new(),18));self.glassLip.ZIndex=5
 Kit.stroke(self.glassLip,nil,1.5,.76)
 self.boardBezel=phoneNode(Kit.frame(root,"Glass",nil,UDim2.new(),UDim2.new(),16));self.boardBezel.ZIndex=6
 self.boardBezel.BackgroundTransparency=0;self.boardBezel.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",self.boardBezel,{Rotation=90,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHex("#16181D")),ColorSequenceKeypoint.new(.5,Color3.fromHex("#08090B")),ColorSequenceKeypoint.new(1,Color3.fromHex("#020203"))})})
 Kit.stroke(self.boardBezel,nil,1,.82)
 local screenPanel=phoneNode(Kit.frame(root,"Screen","panel",UDim2.new(),UDim2.new(),11));screenPanel.ZIndex=7
 local stint=Kit.frame(screenPanel,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1),11);stint.BackgroundTransparency=0;stint.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",stint,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 Kit.stroke(screenPanel,nil,1,.91)
 self.screenPanel=screenPanel
 -- Dark wells the d-pad and A sit in (diameter + 10), as on desktop.
 self.wells={}
 for _,id in ipairs({"DPad","A"})do
  local w=phoneNode(Kit.frame(root,id.."Well",nil,UDim2.new(),UDim2.new(),999));w.ZIndex=8
  w.BackgroundTransparency=.66;w.BackgroundColor3=Color3.new(0,0,0);Kit.stroke(w,nil,1.5,.7)
  self.wells[id]=w
 end
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
 -- Board well behind the board renderer. No border (UI-SPEC-REDESIGN-MENUS 6.1):
 -- the well reads as a recess from the LCD gradient, not from a stroke.
 self.well=Kit.frame(content,"BoardWell","well",UDim2.new(),UDim2.new(),14)
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
 results:GetPropertyChangedSignal("Visible"):Connect(function()self:applyTransparency()end)
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
-- options.lcd (the Pocket Menu): on a phone the layer sits in the lit screen
-- rect between the shoulders instead of becoming a full sheet.
function Screen:addOverlay(name,z,options)
 local layer=Kit.frame(self.options.overlayParent or self.options.parent,name,"panel",UDim2.new(),UDim2.fromOffset(848,608),30)
 layer.ZIndex=z or 32;layer.ClipsDescendants=true;layer.Visible=false;layer.Active=true
 local tint=Kit.frame(layer,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));tint.BackgroundTransparency=0;tint.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",tint,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 local content=Kit.frame(layer,"Content",nil,UDim2.new(),UDim2.fromOffset(848,608));content.ZIndex=layer.ZIndex+2
 local scale=Kit.node("UIScale",content,{Scale=1})
 local overlay={layer=layer,content=content,scale=scale,tint=tint,lcd=options and options.lcd==true,rim=self:rim(layer)}
 table.insert(self.overlays,overlay)
 layer:GetPropertyChangedSignal("Visible"):Connect(function()self:applyTransparency()end)
 if self.geometry then self:placeOverlay(overlay)end
 return overlay
end
-- Plate grips: a sheet's content is padded in by `off` px left and right, so the
-- screens' v1 edge rules (20, W - 20) land at mg + 14. Padding, not Position:
-- the screens animate their content's Position when they open.
local function inset(content,off,top)
 local pad=content:FindFirstChild("GripInset")or Kit.node("UIPadding",content,{Name="GripInset"})
 pad.PaddingLeft=UDim.new(0,off);pad.PaddingRight=UDim.new(0,off);pad.PaddingTop=UDim.new(0,top or 0)
end
Screen.inset=inset
function Screen:placeOverlay(overlay)
 local g=self.geometry;if not g then return end
 if g.phone and overlay.lcd then
  -- In the lit screen: opaque panel, clipped, scale 1 in screen px.
  local r=g.screen
  overlay.layer.Position=UDim2.fromOffset(r.x,r.y);overlay.layer.Size=UDim2.fromOffset(r.w,r.h);Kit.corner(overlay.layer,11)
  overlay.content.Size=UDim2.fromOffset(r.w,r.h);overlay.scale.Scale=1;inset(overlay.content,0)
  self:dress(overlay,false)
 elseif g.phone then
  -- Compact: the layer covers the whole root at scale 1; the screen draws its own sheet,
  -- moved in by the plate grips (content offset mg - 6, so v1's edge rules hold).
  overlay.layer.Position=UDim2.new();overlay.layer.Size=UDim2.fromOffset(g.W,g.H);Kit.corner(overlay.layer,0)
  overlay.content.Size=UDim2.fromOffset(g.W,g.H);overlay.scale.Scale=1;inset(overlay.content,g.off,g.top)
  self:dress(overlay,true)
 else
  overlay.layer.Position=UDim2.fromOffset(g.lcd.x,g.lcd.y);overlay.layer.Size=UDim2.fromOffset(g.lcd.w,g.lcd.h)
  Kit.corner(overlay.layer,math.floor(L.lcdRadius*g.s))
  overlay.content.Size=UDim2.fromOffset(848,608);overlay.scale.Scale=g.lcd.w/848;inset(overlay.content,0)
  self:dress(overlay,false)
 end
 if overlay.onLayout then overlay.onLayout(self:view(overlay))end
end
-- A phone layer is transparent with the plate as its rim; regular layers are LCD glass.
function Screen:dress(layer,phone)
 layer.layer.BackgroundTransparency=if phone then 1 else 0
 layer.layer.ClipsDescendants=not phone
 layer.tint.Visible=not phone;layer.rim.Visible=phone==true
 if phone then self:placeGrips(layer.rim)end
end
-- The plate texture cropped to its middle 80% x 76% (UI-SPEC-COMPACT 3), with
-- the plate lip and shade and, on grips 24 px or wider, five thumb ridges a side.
local PlateCrop={offset=Vector2.new(102,60),size=Vector2.new(819,379)}
function Screen:rim(parent)
 local i=image(parent,"Rim",Assets.Faceplate.sherbet,parent.ZIndex+1,{Size=UDim2.fromScale(1,1),Visible=false,
  ImageRectOffset=PlateCrop.offset,ImageRectSize=PlateCrop.size})
 local lip=Kit.frame(i,"PlateLip",nil,UDim2.new(),UDim2.new(1,0,.3,0));lip.BackgroundTransparency=0;lip.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",lip,{Rotation=90,Transparency=NumberSequence.new(.75,1)})
 local shade=Kit.frame(i,"PlateShade",nil,UDim2.fromScale(0,.62),UDim2.fromScale(1,.38));shade.BackgroundTransparency=0;shade.BackgroundColor3=Color3.new(0,0,0)
 Kit.node("UIGradient",shade,{Rotation=90,Transparency=NumberSequence.new(1,.71)})
 local grips=Kit.frame(i,"Grips",nil,UDim2.new(),UDim2.fromScale(1,1))
 for side=1,2 do for k=1,5 do
  local ridge=Kit.frame(grips,"Ridge",nil,UDim2.new(),UDim2.new(),2);ridge.BackgroundTransparency=.7;ridge.BackgroundColor3=Color3.new(0,0,0)
  ridge:SetAttribute("Side",side);ridge:SetAttribute("Index",k)
  local edge=Kit.frame(ridge,"Edge",nil,UDim2.new(0,1,1,0),UDim2.new(1,-2,0,1));edge.BackgroundTransparency=.76;edge.BackgroundColor3=Color3.new(1,1,1)
 end end
 table.insert(self.rims,i);return i
end
function Screen:placeGrips(rim)
 local g=self.geometry;local grips=rim:FindFirstChild("Grips")
 if not(g and g.phone and grips)then return end
 grips.Visible=g.mg>=24
 for _,ridge in ipairs(grips:GetChildren())do
  local cx=if ridge:GetAttribute("Side")==1 then g.mg/2 else g.W-g.mg/2
  local w=math.floor(g.mg*.52)
  ridge.Position=UDim2.fromOffset(math.floor(cx-w/2),math.floor(g.H/2+(ridge:GetAttribute("Index")-3)*11-2));ridge.Size=UDim2.fromOffset(w,4)
 end
end
-- What a screen needs to lay itself out: nil (regular / small LCD) or the compact
-- root. Sheet coordinates start `off` px in (the plate grips), so W, kx and hx are
-- given in the sheet's own coordinates. An lcd overlay gets the screen rect instead.
function Screen:view(overlay)
 local g=self.geometry
 if not(g and g.phone)then return nil end
 if overlay and overlay.lcd then
  local r=g.screen;local pg=g.pocket
  local items={}
  for i,it in ipairs(pg.items)do items[i]=rect(it.x-r.x,it.y-r.y,it.w,it.h)end
  return{phone=true,lcd=true,W=r.w,H=r.h,kx=g.kx-r.x,kh=g.kh-r.y,
   pocket={cols=pg.cols,items=items,title=rect(pg.title.x-r.x,pg.title.y-r.y,pg.title.w,pg.title.h)}}
 end
 local off=g.off
 -- The sheet starts below the Roblox controls (content padded by g.top): no keep-out inside it.
 return{phone=true,W=g.W-2*off,H=g.H-g.top,kx=0,kh=0,hx=g.hx-off,cw=g.cw,ch=g.ch,actionY=g.actionY,off=off,mg=g.mg,top=g.top}
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
 -- Phone: the glare sits on the board only and never over text, so any sheet or
 -- the Pocket Menu hides it (desktop keeps it over every LCD layer).
 local covered=false
 if self.geometry and self.geometry.phone then
  covered=self.results.Visible
  for _,o in ipairs(self.overlays or {})do if o.layer.Visible then covered=true end end
 end
 self.glare.Visible=self.visible==true and GuiService.PreferredTransparency>.5 and not covered
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
 self:applyTransparency()
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
 placeU(self.menu,L.menu,s);self.menu.SliceScale=s;self.menu.Active=true
 self.menuLabel.TextSize=math.max(11,math.floor(19*s))
 self.menuHit.Size=UDim2.new(1,0,0,math.max(44,L.menu[4]*s));self.menuHit.Position=UDim2.fromScale(.5,.5)
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
 self.resultsContent.Size=self.content.Size;self.resultsScale.Scale=g.contentScale;inset(self.resultsContent,0)
 for _,overlay in ipairs(self.overlays)do self:placeOverlay(overlay)end
 local inset=if g.compact then 12 else 24
 self.back.setCompact(g.compact);self.back.root.Position=UDim2.new(1,-inset,0,inset)
 local b=g.boardLocal
 self.well.Position=UDim2.fromOffset(b.x,b.y);self.well.Size=UDim2.fromOffset(b.w,b.h)
 self:dress(self.resultsLayer,false)
 if self.builtMode~=g.mode then self:buildHud(g)end
 return g
end

-- Shell sprites the compact phone does not draw (UI-SPEC-COMPACT 3), and the
-- Compact v2 frame pieces only the phone draws.
function Screen:showShell(on)
 for _,node in ipairs({self.shadow,self.shoulders[1],self.shoulders[2],self.band,self.plateOverlay,self.wordmarkShadow,self.glass,self.led})do node.Visible=on end
 for _,node in ipairs(self.phoneNodes)do node.Visible=not on end
 self.menu.Visible=true
 self.quadrants.Up.Visible=on;self.quadrants.Down.Visible=on
 -- Decision 4: B is unassigned on the phone HUD (keyboard / gamepad back still work).
 self.buttons.B.holder.Visible=on
 if on then self.wordmark.Visible=true;Kit.corner(self.well,14)end
 self.plate.ImageRectOffset=if on then Vector2.zero else PlateCrop.offset
 self.plate.ImageRectSize=if on then Vector2.zero else PlateCrop.size
 self.plate.ScaleType=Enum.ScaleType.Stretch
end

-- Compact v2: plate fills the root, one glass LCD between two shoulders, the HUD
-- cards inside the lit screen (UI-SPEC-COMPACT-FRAME section 9).
local function place(node,r)node.Position=UDim2.fromOffset(r.x,r.y);node.Size=UDim2.fromOffset(r.w,r.h)end
function Screen:layoutCompact(g)
 local W,H=g.W,g.H
 self.root.Position=UDim2.new();self.root.Size=UDim2.fromOffset(W,H)
 local bleed=48
 for _,node in ipairs({self.plate,self.finish})do
  node.Position=UDim2.fromOffset(-bleed,-bleed);node.Size=UDim2.fromOffset(W+bleed*2,H+bleed*2)
 end
 local gl=g.glass
 place(self.boardBezel,gl);place(self.glassLip,rect(gl.x-2,gl.y-2,gl.w+4,gl.h+4))
 place(self.screenPanel,g.screen)
 local b=g.board
 place(self.lcd,b);Kit.corner(self.lcd,8)
 self.content.Size=UDim2.fromOffset(b.w,b.h);self.contentScale.Scale=1
 self.well.Position=UDim2.new();self.well.Size=UDim2.fromOffset(b.w,b.h);Kit.corner(self.well,8)
 -- Left shoulder: d-pad (the left and right halves are the round's hit areas), MENU, wordmark.
 local d=g.dpad
 place(self.dpad,d);place(self.wells.DPad,rect(d.x-5,d.y-5,d.w+10,d.h+10))
 place(self.quadrants.Left,g.dpadLeft);place(self.quadrants.Right,g.dpadRight)
 place(self.menu,g.menu);self.menu.SliceScale=.32
 -- The drawn pill is 28 high; its 44 px Hit child is the target.
 self.menu.Active=false
 self.menuLabel.TextSize=12
 self.menuHit.Size=UDim2.fromOffset(g.menuHit.w,g.menuHit.h)
 self.menuHit.Position=UDim2.new(.5,0,0,g.menuHit.y+g.menuHit.h/2-g.menu.y)
 if g.wordmark then place(self.wordmark,g.wordmark)end
 self.wordmark.Visible=g.wordmark~=nil
 -- Right shoulder: A at mid height; B stays hidden (decision 4).
 local A=self.buttons.A;local dia=g.A;A.diameter=dia
 A.holder.Position=UDim2.fromOffset(g.a.X-dia/2,g.a.Y-dia/2);A.holder.Size=UDim2.fromOffset(dia,dia*1.07)
 A.letter.TextSize=math.floor(.46*dia);A.letter.Size=UDim2.fromOffset(dia,dia);A.letter.Position=UDim2.new(.5,0,0,dia/2)
 A.hit.Size=UDim2.fromOffset(g.aHit.w,g.aHit.h);A.hit.Position=UDim2.new(.5,0,0,dia/2)
 place(self.wells.A,rect(g.a.X-dia/2-5,g.a.Y-dia/2-3,dia+10,dia+10))
 -- Glare on the board only; results and sheets cover the root; the boot plays in the screen.
 place(self.glare,b)
 self.results.Position=UDim2.new();self.results.Size=UDim2.fromOffset(W,H);Kit.corner(self.results,0)
 self.resultsContent.Size=UDim2.fromOffset(W,H);self.resultsScale.Scale=1;inset(self.resultsContent,g.off,g.top)
 self:dress(self.resultsLayer,true)
 place(self.bootHost,g.screen);Kit.corner(self.bootHost,11)
 for _,overlay in ipairs(self.overlays)do self:placeOverlay(overlay)end
 self.back.setCompact(true);self.back.root.Position=UDim2.new(1,-12,0,8)
 local key=string.format("Compact2:%dx%d:%d:%d",W,H,g.kx,g.kh)
 if self.builtMode~=key then self:buildHud(g);self.builtMode=key end
 -- Toasts: over the Controls card (wide) or the Win pays row on the HUD, at the top of a sheet otherwise.
 self.toaster.placement=function()
  local gg=self.geometry
  if not(gg and gg.phone)then return nil,30,false end
  local sheet,lcd=self.results.Visible,false
  for _,o in ipairs(self.overlays)do if o.layer.Visible then if o.lcd then lcd=true else sheet=true end end end
  -- Sheets start at gg.top (under the Roblox controls): below their header row.
  if sheet then return gg.W/2,gg.top+66,true end
  -- The Pocket Menu lives in the screen: toast at its foot, clear of the title row.
  if lcd then return gg.W/2,gg.screen.y+gg.screen.h-36,true end
  return gg.toast.X,gg.toast.Y,true
 end
 return g
end

-- Portrait keeps the stacked case; results then use the compact screen fitted
-- over the case rect.
function Screen:placeResults(r)
 local scale=math.min(r.w/Screen.Compact.X,r.h/Screen.Compact.Y)
 local w,h=Screen.Compact.X*scale,Screen.Compact.Y*scale
 self.results.Position=UDim2.fromOffset(r.x+(r.w-w)/2,r.y+(r.h-h)/2);self.results.Size=UDim2.fromOffset(w,h)
 self.resultsContent.Size=UDim2.fromOffset(Screen.Compact.X,Screen.Compact.Y);self.resultsScale.Scale=scale;inset(self.resultsContent,0)
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

-- Compact v2 round HUD (UI-SPEC-COMPACT-FRAME 3 and section 9): cards inside the
-- lit screen. Wide (two text columns), narrow (decision 5: board centred,
-- icon-only goals) and the one-column fallback share the card builders below.
local function screenCard(parent,name,r,role,radius)
 local c=Kit.frame(parent,name,role or "raised",UDim2.fromOffset(r.x,r.y),UDim2.fromOffset(r.w,r.h),radius or 10);Kit.stroke(c)
 return c
end
Screen.screenCard=screenCard
-- Zone glyph: a mini tray split in thirds with the goal's third lit (18 x 12).
local function zoneGlyph(parent,x,y)
 local tray=Kit.frame(parent,"Zone",nil,UDim2.fromOffset(x,y),UDim2.fromOffset(18,12),3)
 Kit.stroke(tray,"soft",1.2)
 local lit=Kit.frame(tray,"Lit","soft",UDim2.fromOffset(1.5,1.5),UDim2.fromOffset(5,9),2)
 return{root=tray,lit=lit}
end
function Screen:buildCompactHud(g)
 local host=Kit.frame(self.root,"CompactHUD",nil,UDim2.new(),UDim2.fromScale(1,1));host.ZIndex=14;self.hudRoot=host
 local h={phone=true,geometry=g,layout=g.layout};self.hud=h
 local TextService=game:GetService("TextService")
 local narrow=g.layout=="narrow"
 local function txt(parent,role,content,color,x,y,w,hh,size,props)
  local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,hh);t.TextSize=size;return t
 end
 local right={TextXAlignment=Enum.TextXAlignment.Right}
 local function hit(parent,name,label,callback)
  local b=Kit.node("TextButton",parent,{Name=name,Text="",BackgroundTransparency=1,AutoButtonColor=false,Size=UDim2.fromScale(1,1),ZIndex=parent.ZIndex+6,Selectable=false})
  b:SetAttribute("AccessibleLabel",label);b.Activated:Connect(callback);return b
 end
 local function openQuests()if self.callbacks.quests then self.callbacks.quests()end end
 -- Score (label over a Counter 18); Chain shares it when the row is 130..153 wide.
 local sr=g.score
 local score=screenCard(host,"Score",sr)
 txt(score,"Label","SCORE","dim",10,5,sr.w-20,14,12)
 h.score=txt(score,"Counter","0","text",10,21,sr.w-20,22,18)
 if g.chainIn=="score"then
  txt(score,"Label","CHAIN","dim",10,5,sr.w-20,14,12,right)
  h.chain=txt(score,"Counter","×0","text",10,21,sr.w-20,22,18,right)
 elseif g.chain then
  local cr=g.chain;local chain=screenCard(host,"Chain",cr)
  txt(chain,"Label","CHAIN","dim",10,5,cr.w-20,14,12)
  h.chain=txt(chain,"Counter","×0","text",10,21,cr.w-20,22,18)
 end
 -- Next: tall (labels over the eggs) or the 44 high pill.
 local nr=g.next
 local nextCard=screenCard(host,"Next",nr)
 h.next={}
 if nr.h>=64 then
  txt(nextCard,"Label","NEXT","dim",12,5,50,14,12)
  h.next[1]=egg(nextCard,36);h.next[1].ball.Position=UDim2.fromOffset(12,22)
  txt(nextCard,"Label","THEN","dim",70,5,60,14,12)
  h.next[2]=egg(nextCard,24);h.next[2].ball.Position=UDim2.fromOffset(70,30)
  if nr.w>=150 then h.next[3]=egg(nextCard,24);h.next[3].ball.Position=UDim2.fromOffset(98,30)end
 else
  local items={}
  if nr.w>=124 then
   local label=txt(nextCard,"Label","NEXT","dim",0,0,34,nr.h,12);table.insert(items,{node=label,w=TextService:GetTextSize("NEXT",12,Enum.Font.BuilderSansBold,Vector2.new(200,40)).X})
  end
  h.next[1]=egg(nextCard,32);table.insert(items,{node=h.next[1].ball,w=32,egg=true})
  if nr.w>=70 then h.next[2]=egg(nextCard,22);table.insert(items,{node=h.next[2].ball,w=22,egg=true})end
  local total=-8;for _,item in ipairs(items)do total+=item.w+8 end
  local x=math.floor((nr.w-total)/2)
  for _,item in ipairs(items)do
   local hh=if item.egg then item.w else nr.h
   item.node.Position=UDim2.fromOffset(x,math.floor((nr.h-hh)/2));if not item.egg then item.node.Size=UDim2.fromOffset(item.w,nr.h)end
   x+=item.w+8
  end
 end
 -- Eggs left: one row in a wide column, label over value otherwise.
 local er=g.eggs
 local eggs=screenCard(host,"EggsLeft",er)
 if g.layout=="wide"then
  txt(eggs,"Label","EGGS LEFT","dim",12,0,100,er.h,12)
  h.budget=txt(eggs,"Counter","/24","soft",er.w-12-40,1,40,er.h,13,right)
  h.eggs=txt(eggs,"Counter","0","text",er.w-12-40-4-60,0,60,er.h,18,right);h.eggsRow=true
 else
  txt(eggs,"Label",if narrow then "EGGS LEFT"else "EGGS","dim",10,5,er.w-20,14,12)
  h.eggs=txt(eggs,"Counter","0","text",10,21,40,22,18)
  if er.w>=88 then h.budget=txt(eggs,"Counter","/24","soft",40,24,40,20,13)end
 end
 -- Difficulty: bars and the name; the multiplier chip on a 170+ column.
 local dr=g.difficulty
 local diff=screenCard(host,"Difficulty",dr)
 local tight=dr.w<120
 h.diffBars={}
 for index,bh in ipairs({10,16,22})do h.diffBars[index]=Kit.frame(diff,"Bar"..index,"stars",UDim2.fromOffset((if tight then 9 else 12)+(index-1)*9,33-bh),UDim2.fromOffset(6,bh),2)end
 h.diffName=txt(diff,"Strong","Medium","text",if tight then 40 else 46,0,dr.w-(if tight then 46 else 52),dr.h,if tight then 14 else 15)
 if dr.w>=170 and g.layout~="one"then
  h.diffChip=Kit.chip(diff,"★ ×1","gold",22);h.diffChip.label.TextSize=12;h.diffChip.set("★ ×1","gold")
  h.diffChip.root.AnchorPoint=Vector2.new(1,.5);h.diffChip.root.Position=UDim2.new(1,-10,.5,0)
  h.diffName.Size=UDim2.fromOffset(80,dr.h)
 end
 -- Win pays: one line, or label over value in a narrow column.
 local pr=g.winPays
 local pays=screenCard(host,"WinPays",pr)
 local vs=if pr.w<160 then 15 else 17
 local pair
 if narrow then
  txt(pays,"Label","WIN PAYS","dim",10,5,pr.w-20,14,12)
  pair=Kit.frame(pays,"Amount",nil,UDim2.fromOffset(10,20),UDim2.fromOffset(0,22))
 else
  local pad=if pr.w<160 then 10 else 12
  txt(pays,"Label","WIN PAYS","dim",pad,0,100,pr.h,12)
  pair=Kit.frame(pays,"Amount",nil,UDim2.new(1,-pad,.5,0),UDim2.fromOffset(0,24));pair.AnchorPoint=Vector2.new(1,.5)
 end
 pair.AutomaticSize=Enum.AutomaticSize.X
 Kit.node("UIListLayout",pair,{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
 local star=Kit.icon(pair,"star",vs);star.LayoutOrder=1
 h.pays=Kit.text(pair,"Counter","6–8","stars",{TextSize=vs,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,22),LayoutOrder=2})
 -- Goals: text rows (wide / one column) or icon rows (narrow).
 local gr=g.goals;local p=g.goalPitch
 local goals=screenCard(host,"Goals",gr)
 h.goalsCard=goals
 local gw=gr.w
 h.goalsEyebrow=txt(goals,"Label","GOALS","dim",if narrow then 10 else 12,4,gw-24,20,12)
 h.goalsCount=txt(goals,"Counter","","dim",12,4,gw-24,20,12,right)
 if g.chainIn=="goals"then h.chain=txt(goals,if narrow then "Counter"else "Label",if narrow then "×0"else "CHAIN ×0",if narrow then "text"else "soft",10,4,gw-20,20,if narrow then 13 else 12,right);h.chainInGoals=true end
 h.status=txt(goals,"Body","","soft",10,26,gw-20,3*p,14,{TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,Visible=false})
 h.goals={}
 for index=1,3 do
  local row=Kit.frame(goals,"Goal"..index,nil,UDim2.fromOffset(0,24+(index-1)*p),UDim2.fromOffset(gw,p))
  if narrow then
   local mark=egg(row,22);mark.ball.Position=UDim2.fromOffset(8,math.floor((p-22)/2))
   local glyph=Kit.icon(row,"chain",20,"text");glyph.Position=UDim2.fromOffset(9,math.floor((p-20)/2));glyph.Visible=false
   local plus=txt(row,"Strong","+","text",33,math.floor(p/2)-12,8,16,12)
   local zone=zoneGlyph(row,42,math.floor((p-12)/2))
   local count=txt(row,"Counter","","soft",gw-10-40,0,40,p,13,right)
   local check=Kit.check(row,20);check.root.Position=UDim2.fromOffset(gw-30,math.floor((p-20)/2))
   h.goals[index]={row=row,egg=mark,glyph=glyph,plus=plus,zone=zone,count=count,check=check,icon=true}
  else
   local check=Kit.check(row,20);check.root.Position=UDim2.fromOffset(8,math.floor((p-20)/2))
   local text=txt(row,"BodyMedium","","text",34,0,gw-34-50,p,14,{TextTruncate=Enum.TextTruncate.AtEnd})
   local count=txt(row,"Counter","","soft",gw-10-40,0,40,p,13,right)
   h.goals[index]={row=row,check=check,text=text,count=count}
  end
 end
 h.goalPitch=p
 -- Daily quests card (wide, when it clears three goals) or the quest handle. Both open the quest log.
 local function readyDot(parent,x,y)
  local dot=Kit.frame(parent,"ReadyDot","stars",UDim2.fromOffset(x,y),UDim2.fromOffset(8,8),999);dot.Visible=false;return dot
 end
 local function chevronRight(parent,x,y)
  local c=Kit.chevron(parent,14,"up","soft");c.Position=UDim2.fromOffset(x,y);c.Rotation=90;return c
 end
 if g.quests then
  local qr=g.quests;local qp=g.questPitch
  local quests=screenCard(host,"DailyQuests",qr)
  local roomy=qr.w>=170
  local title=if roomy then "DAILY QUESTS"else "QUESTS"
  txt(quests,"Label",title,"dim",12,4,qr.w-24,20,12)
  h.questDot=readyDot(quests,12+math.ceil(TextService:GetTextSize(title,12,Enum.Font.BuilderSansBold,Vector2.new(400,40)).X)+6,10)
  h.questCount=txt(quests,"Counter","","soft",qr.w-26-50,4,50,20,13,right)
  chevronRight(quests,qr.w-24,7)
  h.daily={}
  for index=1,3 do
   local y=24+(index-1)*qp
   local name,count,bar
   if roomy then
    name=txt(quests,"Body","","text",12,y,qr.w-24-50,qp-12,14,{TextTruncate=Enum.TextTruncate.AtEnd})
    count=txt(quests,"Counter","","soft",qr.w-12-46,y,46,qp-12,13,right)
    bar=Kit.progress(quests,4);bar.root.Position=UDim2.fromOffset(12,y+qp-10);bar.root.Size=UDim2.fromOffset(qr.w-24,4)
   else
    name=txt(quests,"Body","","text",12,y,qr.w-24,18,14,{TextTruncate=Enum.TextTruncate.AtEnd})
    count=txt(quests,"Counter","","soft",qr.w-12-40,y+16,40,18,13,right)
    bar=Kit.progress(quests,4);bar.root.Position=UDim2.fromOffset(12,y+23);bar.root.Size=UDim2.fromOffset(qr.w-24-46,4)
   end
   h.daily[index]={name=name,count=count,bar=bar}
  end
  h.questsHit=hit(quests,"Hit","Daily quests",openQuests)
 else
  local hr=g.handle
  local handle=screenCard(host,"QuestHandle",hr,"well",12)
  local icon=Kit.icon(handle,"quests",18,"text");icon.Position=UDim2.fromOffset(13,13)
  h.questDot=readyDot(icon,12,-3)
  if hr.w>=130 then txt(handle,"Strong","Quests","text",38,0,70,hr.h,14)end
  h.questCount=txt(handle,"Counter","","soft",hr.w-26-50,0,50,hr.h,13,right)
  chevronRight(handle,hr.w-24,15)
  h.handle=handle
  h.questsHit=hit(handle,"Hit","Daily quests",openQuests)
  h.daily={}
 end
 -- Controls: rows for the last input; the card follows the rows shown, bottom-anchored.
 if g.controls then
  local cr=g.controls
  local controls=screenCard(host,"Controls",cr)
  txt(controls,"Label","CONTROLS","dim",12,6,cr.w-24,16,12)
  h.controls={}
  for index=1,g.controlRows do
   local y=24+(index-1)*28
   local holder=Kit.frame(controls,"Hint"..index,nil,UDim2.fromOffset(12,y+2),UDim2.fromOffset(40,24))
   local text=txt(controls,"Body","","text",60,y,cr.w-60-8,28,14)
   h.controls[index]={holder=holder,text=text}
  end
  h.controlsCard=controls
 end
 self.lastHud=nil;self.controlsKey=nil
end

-- v2 has no quest drawer: the quests card and handle open the quest log.
function Screen:closeDrawer()return false end

function Screen:buildHud(g)
 if self.hudRoot then self.hudRoot:Destroy()end
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
  -- The card opens the quest log (MENU opens the Pocket Menu now).
  local qhit=Kit.node("TextButton",daily,{Name="Hit",Text="",BackgroundTransparency=1,AutoButtonColor=false,Size=UDim2.fromScale(1,1),ZIndex=daily.ZIndex+6,Selectable=false})
  qhit:SetAttribute("AccessibleLabel","Daily quests");h.questsHit=qhit
  qhit.Activated:Connect(function()if self.callbacks.quests then self.callbacks.quests()end end)
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
 Gamepad={{"◀▶","Aim"},{"A","Drop"},{"B","Pause and leave"},{"MENU","Pocket menu"}},
 Keyboard={{"← →","Aim"},{"Space","Drop"},{"Bksp","Leave"},{"M","Pocket menu"}},
 Touch={{"Drag","Drag to aim"},{"A","A or release to drop"},{"MENU","Pocket menu"},{"←","Back arrow leaves"}},
}
local function eggPaint(slot,tier)
 tier=math.clamp(tier or 1,1,#Config.Tiers)
 Art.jellyPreview(slot.ball,tier,slot.mark);slot.mark.Text=Config.Tiers[tier].mark
 -- White mark with a deep shadow, as on the board (UI-SPEC-REDESIGN-MENUS 6.2).
 local roles=JellyPalette.byTier[tier];slot.mark.TextColor3=roles.mark;slot.mark.TextStrokeColor3=roles.markShadow;slot.mark.TextStrokeTransparency=.45
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

-- Compact HUD paint: same data contract as setHud. Goals may carry
-- icon={kind,tier,plus,zone} for the narrow icon rows.
local compactRows={
 Gamepad={{"◀▶","Aim"},{"A","Drop"},{"B","Leave"}},
 Keyboard={{"← →","Aim"},{"Space","Drop"},{"Bksp","Leave"}},
 -- Decision 4: B is unassigned on touch, so no "B: Leave" row.
 Touch={{"Drag","Aim"},{"A","Drop"}},
}
Screen.compactControlRows=compactRows
local zoneThird={left=0,center=1,right=2}
local function paintIconGoal(slot,goal)
 local icon=goal.icon or {}
 local kind=icon.kind or "merge"
 local tier=math.clamp(icon.tier or 1,1,#Config.Tiers)
 local isMerge=kind=="merge"
 slot.egg.ball.Visible=isMerge;slot.glyph.Visible=not isMerge
 if isMerge then eggPaint(slot.egg,tier)
 else
  slot.glyph.ImageRectOffset=Assets.Icon[if kind=="chain"then "chain"else "egg"]or Vector2.zero
 end
 slot.plus.Visible=isMerge and icon.plus==true
 local third=zoneThird[icon.zone or "any"]
 slot.zone.root.Visible=third~=nil
 if third then
  slot.zone.root.Position=UDim2.fromOffset(if slot.plus.Visible then 42 else 34,slot.zone.root.Position.Y.Offset)
  slot.zone.lit.Position=UDim2.fromOffset(1.5+third*5,1.5)
 end
 slot.row:SetAttribute("AccessibleLabel",goal.text or goal.short or "")
end
function Screen:setCompactHud(data)
 local h=self.hud;local g=h.geometry
 h.score.Text=commas(data.score)
 if h.chain then h.chain.Text=(if h.chainInGoals and h.layout~="narrow"then "CHAIN ×"else "×")..tostring(data.chain or 0)end
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
   local count=if goal.done then string.format("%d/%d",goal.target or 1,goal.target or 1)else string.format("%d/%d",goal.progress or 0,goal.target or 1)
   if slot.icon then
    paintIconGoal(slot,goal)
    -- Done: the check takes the count's place and the row dims.
    slot.check.root.Visible=goal.done==true;slot.check.set(true)
    slot.count.Visible=not goal.done;slot.count.Text=count
    slot.egg.ball.BackgroundTransparency=if goal.done then .45 else 0
   else
    slot.check.set(goal.done)
    slot.text.Text=goal.short or goal.text
    slot.text.TextColor3=if goal.done then Kit.Color.soft else Kit.Color.text
    slot.count.Text=count
   end
  end
 end
 h.goalsCount.Text=""
 if data.statusLabel and data.statusLabel~=""then h.goalsEyebrow.Text=string.upper(data.statusLabel);h.goalsEyebrow.TextColor3=Kit.Color.stars
 else h.goalsEyebrow.Text=if #goals>0 and not h.status.Visible then string.format("GOALS %d/%d",done,#goals)else "GOALS";h.goalsEyebrow.TextColor3=Kit.Color.dim end
 -- Card height follows the goal count (a status message gets two rows, three in a narrow column).
 local n=if h.status.Visible then(if h.layout=="narrow"then 3 else 2)else math.max(1,#goals)
 local cardH=24+n*h.goalPitch+6
 if h.cardH~=cardH then
  h.cardH=cardH
  h.goalsCard.Size=UDim2.fromOffset(h.goalsCard.Size.X.Offset,cardH)
  h.status.Size=UDim2.fromOffset(h.status.Size.X.Offset,n*h.goalPitch)
 end
 -- Daily quests card rows, the handle count and the ready dot.
 local daily=data.daily or {}
 local claimed,ready=0,false
 for index=1,#daily do
  local q=daily[index]
  if q.done then claimed+=1 end
  if q.ready then ready=true end
 end
 for index,slot in ipairs(h.daily)do
  local q=daily[index]
  slot.name.Visible,slot.count.Visible,slot.bar.root.Visible=q~=nil,q~=nil,q~=nil
  if q then
   slot.name.Text=q.title;slot.count.Text=string.format("%d/%d",math.min(q.progress,q.target),q.target)
   slot.count.TextColor3=if q.done then Kit.Color.stars else Kit.Color.soft
   slot.bar.set(q.progress,q.target,q.done,true)
  end
 end
 if h.questCount then h.questCount.Text=string.format("%d/%d",claimed,#daily)end
 h.questDot.Visible=ready
 for index,slot in ipairs(h.next)do eggPaint(slot,data.next and data.next[index])end
 h.eggs.Text=tostring(data.eggsLeft or 0)
 if h.budget then
  h.budget.Text="/"..tostring(data.budget or 24)
  if not h.eggsRow then
   local digits=game:GetService("TextService"):GetTextSize(h.eggs.Text,18,Enum.Font.RobotoMono,Vector2.new(500,80)).X
   h.budget.Position=UDim2.fromOffset(10+digits+4,24)
  else
   local bw=game:GetService("TextService"):GetTextSize(h.budget.Text,13,Enum.Font.RobotoMono,Vector2.new(500,80)).X
   local x=h.budget.Position.X.Offset+h.budget.Size.X.Offset-bw-2
   h.eggs.Position=UDim2.fromOffset(x-h.eggs.Size.X.Offset,h.eggs.Position.Y.Offset)
  end
 end
 local level=({Easy=1,Medium=2,Hard=3})[data.difficulty or "Medium"]or 2
 local tone=if level==1 then Kit.Color.good elseif level==3 then Kit.Color.danger else Kit.Color.stars
 for index,bar in ipairs(h.diffBars)do bar.BackgroundColor3=tone;bar.BackgroundTransparency=if index<=level then 0 else .75 end
 h.diffName.Text=data.difficulty or "Medium"
 if h.diffChip then h.diffChip.set("★ "..(data.multiplier or "×1"),"gold");h.diffChip.label.TextSize=12 end
 h.pays.Text=data.winPays or "6–8"
 if h.controls then
  local key=data.input or "Keyboard"
  if self.controlsKey~=key then
   self.controlsKey=key
   local rows=compactRows[key]or compactRows.Keyboard
   local shown=math.min(#h.controls,#rows)
   local cr=g.controls;local ch=30+shown*28
   h.controlsCard.Position=UDim2.fromOffset(cr.x,cr.y+cr.h-ch);h.controlsCard.Size=UDim2.fromOffset(cr.w,ch)
   for index,slot in ipairs(h.controls)do
    slot.holder:ClearAllChildren()
    local row=if index<=shown then rows[index]else nil
    slot.text.Text=row and row[2]or ""
    slot.holder.Visible=row~=nil
    if row then
     if row[1]=="Drag"then
      local chip=Kit.frame(slot.holder,"DragChip","well",UDim2.fromOffset(0,1),UDim2.fromOffset(38,20),999);Kit.stroke(chip)
      local arrow=Kit.text(chip,"Strong","↔","soft",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=14})
      local _=arrow
     else
      local glyph=Kit.glyph(slot.holder,row[1],false,24)
      if row[1]=="A"then glyph.BackgroundColor3=self.accent or Kit.color("accent");glyph.BackgroundTransparency=0;local t=glyph:FindFirstChildWhichIsA("TextLabel");if t then t.TextColor3=Kit.Color.ink end end
     end
    end
   end
   -- A wide glyph (Space, Bksp) pushes its label right.
   for _,slot in ipairs(h.controls)do
    local glyph=slot.holder:FindFirstChild("Glyph")
    local w=if glyph then glyph.Size.X.Offset else 38
    slot.text.Position=UDim2.fromOffset(math.max(60,12+w+8),slot.text.Position.Y.Offset)
    slot.text.Size=UDim2.fromOffset(cr.w-slot.text.Position.X.Offset-8,28)
   end
  end
 end
end
return Screen
