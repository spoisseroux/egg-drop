-- Deck style, Backgrounds tab (UI-SPEC-REDESIGN-MENUS 4 and 5, mockup 05). Drawn
-- into the Deck style screen that FaceplateShop owns (same header, tab row, focus
-- ring and pane geometry). Cards: pattern swatch, name, status (IN USE / Earned /
-- the unlock rule with a lock). The pane previews the pattern on a mini screen with
-- "Use" as the primary. Backgrounds are earned, never bought; choosing one goes
-- through the same appearance intent as before (callbacks.use -> onApply("background")),
-- and the live preview through Art.setBackgroundPreview.
local Shared=game:GetService("ReplicatedStorage").Shared
local Backgrounds=require(Shared.DeckBackgrounds)
local Themes=require(Shared.DeckThemes)
local Catalog=require(Shared.AppearanceCatalog)
local Kit=require(script.Parent.DeckKit)
local Art=require(script.Parent.DeckArt)
local Shop={}
Shop.__index=Shop
-- Desktop rects in panel units: the pane matches Faceplates; 2 columns of 220x96 cards.
Shop.Regular={pane={24,144,328,392},grid={371,147},tile={220,96},gap=12,columns=2}
Shop.Short={free="Free",firstWin="Win 1 round",rankI="Reach Rank I",rankII="Reach Rank II",highRoller="High Roller trial",chain3="Triple Pop trial",trials="All Pocket Trials"}
Shop.Source={free="Yours from the start",firstWin="From your first win",rankI="From reaching Rank I",rankII="From reaching Rank II",
 highRoller="From the High Roller trial",chain3="From the Triple Pop trial",trials="From all three Pocket Trials"}
-- Pocket Trials have no page any more (QA 2026-11-13 Q5): a trial-locked background says
-- its rule and offers no button (the server still unlocks it from the saved TrialMask).

-- Pure: what the pane says and offers for one background.
-- ctx = { confirmed = id, facts = AppearanceCatalog facts, chosen = id being applied,
--         note = appearance status words for `chosen`, retry = bool }
function Shop.status(id,ctx)
 local item=Backgrounds.ById[id]
 if not item then return {kind="invalid",chip="",text="",button=nil}end
 ctx=ctx or {}
 if ctx.retry and ctx.chosen==id then return {kind="retry",chip="RETRY",text=ctx.note or "Not applied",button="Retry",enabled=true}end
 if ctx.confirmed==id then return {kind="inUse",chip="IN USE",text=if ctx.chosen==id and ctx.note then ctx.note else "In use",button=nil}end
 local requirement=Catalog.describeRequirement("background",id,ctx.facts)
 if requirement.unlocked then
  return {kind="earned",chip="EARNED",text=if ctx.chosen==id and ctx.note then ctx.note else Shop.Source[requirement.rule]or "",button="Use",enabled=true}
 end
 local text="Locked - "..requirement.text..string.format(" (%d/%d)",requirement.progress,requirement.target)
 return {kind="locked",chip="LOCKED",text=text,rule=requirement.rule,button=nil,enabled=false}
end
-- Pure: the card's status line.
function Shop.tileStatus(id,ctx)
 local s=Shop.status(id,ctx)
 if s.kind=="inUse"then return "IN USE","accent"end
 if s.kind=="earned"or s.kind=="retry"then return "Earned","soft"end
 local rule=Backgrounds.ById[id]and Backgrounds.ById[id].rule or ""
 return "🔒 "..(Shop.Short[rule]or "Locked"),"dim"
end
function Shop.step(index,dx,dy,count,columns)
 local cols=math.max(1,columns or 2)
 local col,row=(index-1)%cols,math.floor((index-1)/cols)
 local rows=math.max(1,math.ceil(count/cols))
 col=math.clamp(col+dx,0,cols-1);row=math.clamp(row+dy,0,rows-1)
 return math.max(1,math.min(count,row*cols+col+1))
end

local function colorOf(role)
 if role=="accent"or role=="selected"or role=="raised"or role=="well"or role=="panel"then return Kit.color(role)end
 return Kit.Color[role]or Kit.Color.text
end
local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end

-- owner: the Deck style screen (FaceplateShop): root, ring, visible, tab.
-- callbacks: use(id), retry()
function Shop.new(owner,callbacks)
 return setmetatable({owner=owner,callbacks=callbacks or {},index=1,tiles={},
  ctx={confirmed=Backgrounds.Default,facts={},themeId=Themes.Default}},Shop)
end
function Shop:theme()return Themes.ById[self.ctx.themeId or Themes.Default]or Themes.ById[Themes.Default]end

-- The mini screen: three side panels each side and the board well in the middle,
-- where the pattern really shows (section 5). `host` borrows the live renderer.
function Shop:buildPreview(pane,x,y,w,h)
 local screen=Kit.frame(pane,"MiniScreen","well",UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),12);Kit.stroke(screen)
 Kit.dotGrid(screen) -- T7 LCD dot grid under the mini screen (nothing until the asset id lands)
 local inset=math.max(6,math.floor(h*.045))
 local boardW=math.floor(w*.37);local sideW=math.floor((w-boardW-inset*4)/2)
 local fractions={{0,.2},{.24,.62},{.66,1}}
 for side=0,1 do
  local sx=if side==0 then inset else w-inset-sideW
  for i,f in ipairs(fractions)do
   local top=inset+math.floor((h-inset*2)*f[1]);local bottom=inset+math.floor((h-inset*2)*f[2])
   local box=Kit.frame(screen,"Side"..side..i,"raised",UDim2.fromOffset(sx,top),UDim2.fromOffset(sideW,math.max(6,bottom-top-(if i<3 then 4 else 0))),6)
   box.BackgroundTransparency=.2
  end
 end
 local board=Kit.frame(screen,"BoardWell",nil,UDim2.fromOffset(math.floor((w-boardW)/2),inset),UDim2.fromOffset(boardW,h-inset*2),8)
 board.BackgroundTransparency=0;board.BackgroundColor3=Color3.fromHex("#0B1012");board.ClipsDescendants=true
 self.previewHost=board
 -- A small stack of eggs over the pattern (decoration only).
 local eggs=Kit.frame(screen,"PreviewEggs",nil,board.Position,board.Size);eggs.ZIndex=board.ZIndex+20
 local colors={"#3D8BFF","#FF8A1F","#3DDC6A","#FF4FA3","#2FB4FF"}
 local r=math.max(4,math.floor(boardW*.075))
 local layout={{.2,0,1},{.36,0,2},{.52,0,4},{.68,0,2},{.84,0,1},{.28,1,5},{.44,1,3},{.6,1,1},{.76,1,2},{.4,2,4},{.56,2,2}}
 for i,e in ipairs(layout)do
  local d=if i==3 then math.floor(r*2.6)else r*2
  local egg=Kit.frame(eggs,"Egg"..i,nil,UDim2.new(e[1],-d/2,1,-d-2-math.floor(e[2]*r*1.7)),UDim2.fromOffset(d,d),999)
  egg.BackgroundTransparency=0;egg.BackgroundColor3=Color3.fromHex(colors[e[3]]);egg.ZIndex=eggs.ZIndex+1
 end
 return screen
end

-- view: nil (desktop panel units) or the compact view; geometry from the owner.
-- parent: the owner's content frame. Returns the tab's body frame.
function Shop:build(parent,view,grid)
 self:releasePreview()
 if self.body then self.body:Destroy()end
 self.view=view;self.tiles={};self.previewHost=nil
 local body=Kit.frame(parent,"Backgrounds",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=parent.ZIndex+1;body.Visible=false
 self.body=body
 local items=Backgrounds.Order
 if view then
  local W=view.W;local g=grid
  local pw,ph=g.pw,g.paneH
  local pane=Kit.card(body,"Preview",nil,{pad=12,seam=true});pane.Position=UDim2.fromOffset(W-20-pw,64);pane.Size=UDim2.fromOffset(pw,ph)
  self.pane=pane
  local buttonY=ph-60
  local nameY=buttonY-6-18-24
  self:buildPreview(pane,12,10,pw-24,math.max(36,nameY-6-10))
  self.name=txt(pane,"Title","","text",12,nameY,pw-24-90,24,{TextSize=18,TextTruncate=Enum.TextTruncate.AtEnd})
  self.chip=Kit.chip(pane,"EARNED",nil,22);self.chip.label.TextSize=12;self.chip.root.AnchorPoint=Vector2.new(1,.5);self.chip.root.Position=UDim2.fromOffset(pw-12,nameY+12)
  self.desc=txt(pane,"Small","Behind the board, on every device","soft",12,nameY+24,pw-24,18,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
  self.source=nil
  self.status=self.desc
  local action,state=Kit.button(pane,"Action",{variant="primary",text="Use",glyph="A",size=Vector2.new(pw-24,48),textSize=16,selectable=false})
  action.Position=UDim2.fromOffset(12,buttonY);self.action,self.actionState=action,state
  action.Activated:Connect(function()self:act()end)
  local list=Kit.node("ScrollingFrame",body,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,112),
   Size=UDim2.fromOffset(g.gw,g.gridH),ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
   ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
  self.grid=list
  local cols=if g.gw>=420 then 2 else 1
  self.columns=cols
  local tileW=math.floor((g.gw-8-(cols-1)*8)/cols)
  for index,id in ipairs(items)do
   local col,row=(index-1)%cols,math.floor((index-1)/cols)
   -- 3 px in from the scroll edges so the selected outline is never clipped.
   self:buildTile(list,index,id,3+col*(tileW+2),3+row*72,tileW-6,64,true)
  end
  list.CanvasSize=UDim2.fromOffset(0,math.ceil(#items/cols)*72-8+6)
 else
  local R=Shop.Regular
  local pane=Kit.card(body,"Preview",nil,{pad=20,seam=true});pane.Position=UDim2.fromOffset(R.pane[1],R.pane[2]);pane.Size=UDim2.fromOffset(R.pane[3],R.pane[4])
  self.pane=pane
  self:buildPreview(pane,16,16,296,184)
  self.name=txt(pane,"Title","","text",20,212,200,30,{TextTruncate=Enum.TextTruncate.AtEnd})
  self.chip=Kit.chip(pane,"EARNED",nil,26);self.chip.root.AnchorPoint=Vector2.new(1,.5);self.chip.root.Position=UDim2.fromOffset(308,227)
  self.desc=txt(pane,"Small","A pattern on the screen, behind the board","soft",20,246,288,20,{TextSize=15,TextTruncate=Enum.TextTruncate.AtEnd})
  self.status=txt(pane,"Small","","soft",20,270,288,20,{TextSize=15,TextTruncate=Enum.TextTruncate.AtEnd})
  local action,state=Kit.button(pane,"Action",{variant="primary",text="Use",glyph="A",size=Vector2.new(288,56),selectable=false})
  action.Position=UDim2.fromOffset(20,R.pane[4]-16-56);self.action,self.actionState=action,state
  action.Activated:Connect(function()self:act()end)
  self.grid=nil;self.columns=R.columns
  for index,id in ipairs(items)do
   local col,row=(index-1)%R.columns,math.floor((index-1)/R.columns)
   self:buildTile(body,index,id,R.grid[1]+col*(R.tile[1]+R.gap),R.grid[2]+row*(R.tile[2]+R.gap),R.tile[1],R.tile[2],false)
  end
  local rows=math.ceil(#items/R.columns)
  local infoY=R.grid[2]+rows*(R.tile[2]+R.gap)-R.gap+20
  local info=Kit.card(body,"Info",nil,{role="well"});info.Position=UDim2.fromOffset(R.grid[1],infoY);info.Size=UDim2.fromOffset(452,72)
  local icon=Kit.icon(info,"pattern",24,"accent");icon.Position=UDim2.fromOffset(22,24)
  txt(info,"Small","Shows on every device, phone included.","text",62,14,376,22,{TextSize=15})
  txt(info,"Small","Earned by playing. Never sold.","soft",62,36,376,22,{TextSize=15})
 end
 self.index=math.clamp(self.index,1,#self.tiles)
 return body
end

function Shop:buildTile(parent,index,id,x,y,w,h,compact)
 local item=Backgrounds.ById[id]
 -- T2: pressable tile with a lip (4 px in the 12 px desktop gap, 3 px in the 8 px phone gap).
 local tile,tileState=Kit.tile(parent,"Tile_"..id,{selectable=false,radius=12,compact=compact,position=UDim2.fromOffset(x,y),size=UDim2.fromOffset(w,h)})
 local stroke=tileState.stroke
 tile:SetAttribute("AccessibleLabel",item.name);tile:SetAttribute("BackgroundId",id)
 local side=if compact then 44 else 76
 local swatch=Kit.frame(tile,"Swatch",nil,UDim2.fromOffset(10,(h-side)/2),UDim2.fromOffset(side,side),10);swatch.ClipsDescendants=true
 Kit.stroke(swatch)
 Art.backgroundThumbnail(swatch,id,self:theme())
 local tx=10+side+12
 local nameLabel=txt(tile,"Name",item.name,"text",tx,if compact then 12 else h/2-22,w-tx-8,20,{TextSize=if compact then 14 else 16,TextTruncate=Enum.TextTruncate.AtEnd})
 local status=txt(tile,"Small","","soft",tx,if compact then 34 else h/2+2,w-tx-8,18,{TextSize=if compact then 13 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
 self.tiles[index]={id=id,button=tile,status=status,name=nameLabel,stroke=stroke,swatch=swatch}
 tile.Activated:Connect(function()if self.index==index then self:act()else self:focus(index);Kit.boing(tile)end end)
end

function Shop:setContext(ctx)
 -- Absent keys keep their value; pass false to clear (note, retry, chosen).
 for key,value in pairs(ctx)do self.ctx[key]=value end
 if self.body then self:refresh()end
end
function Shop:focusedId()local tile=self.tiles[self.index];return tile and tile.id end
function Shop:active()return self.owner.visible==true and self.owner.tab==2 and self.body~=nil and self.body.Visible end

function Shop:refresh()
 local theme=self:theme()
 for index,tile in ipairs(self.tiles)do
  Art.backgroundThumbnail(tile.swatch,tile.id,theme)
  local text,role=Shop.tileStatus(tile.id,self.ctx)
  if self.view and role=="dim"then role="soft"end
  tile.status.Text=text
  tile.status.FontFace=if role=="accent"then Kit.Type.Label[3]else Kit.Type.Small[3]
  Kit.paint(tile.status,"TextColor3",function()return colorOf(role)end)
  local focused=index==self.index
  Kit.paint(tile.button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised")end)
  tile.stroke.Thickness=if focused then 2 else 1;tile.stroke.Transparency=if focused then 0 else .86
  Kit.paint(tile.stroke,"Color",function()return if focused then Kit.color("accent")else Color3.new(1,1,1)end)
  tile.button:SetAttribute("TileState",Shop.status(tile.id,self.ctx).kind)
 end
 self:paintPane()
end

function Shop:paintPane()
 local id=self:focusedId();if not id or not self.name then return end
 local item=Backgrounds.ById[id]
 local s=Shop.status(id,self.ctx)
 self.name.Text=item.name
 self.chip.set(s.chip)
 self.chip.label.TextColor3=if s.kind=="inUse"or s.kind=="earned"then Kit.color("accent")elseif s.kind=="retry"then Kit.Color.dangerText else Kit.Color.soft
 if self.view then
  -- One line on the phone: the status when there is one to say, else the promise.
  self.desc.Text=if s.kind=="locked"or s.kind=="retry"or(self.ctx.chosen==id and self.ctx.note)then s.text else "Behind the board, on every device"
 else
  self.status.Text=s.text
 end
 local tone=if s.kind=="retry"then "dangerText"elseif s.kind=="inUse"then "accent"else "soft"
 Kit.paint(self.status,"TextColor3",function()return colorOf(tone)end)
 self.action.Visible=s.button~=nil
 if s.button then Kit.setText(self.action,s.button);Kit.setEnabled(self.action,s.enabled==true)end
 self.owner.root:SetAttribute("FocusedBackground",id);self.owner.root:SetAttribute("BackgroundPaneState",s.kind)
 self:refreshPreview()
end
-- The live pattern in the pane's board well follows the focused card.
function Shop:refreshPreview()
 if not self.previewHost then return end
 local active=self:active()
 Art.setBackgroundPreview(self.previewHost,if active then self:focusedId()else nil,if active then self:theme()else nil,active)
end
function Shop:releasePreview()
 if self.previewHost then Art.setBackgroundPreview(self.previewHost,nil,nil,false)end
end

function Shop:scrollTo(index)
 local list=self.grid;local tile=self.tiles[index];if not list or not tile then return end
 local top=tile.button.Position.Y.Offset;local bottom=top+tile.button.Size.Y.Offset
 local view=list.AbsoluteWindowSize.Y;if view<=0 then view=list.Size.Y.Offset end
 local y=list.CanvasPosition.Y
 if top-8<y then y=top-8 elseif bottom+8>y+view then y=bottom+8-view end
 list.CanvasPosition=Vector2.new(0,math.clamp(y,0,math.max(0,list.CanvasSize.Y.Offset-view)))
end
function Shop:focus(index,instant)
 if #self.tiles==0 then return end
 index=math.clamp(index,1,#self.tiles)
 self.index=index;self:refresh();self:scrollTo(index)
 local ring=self.owner.ring
 if ring and self:active()then
  ring.attach(self.tiles[index].button,12)
  if instant then ring.root.Visible=self.owner.visible and ring.root.Visible end
 end
 if self.view and self.action then Kit.setGlyphVisible(self.action,not Kit.lastInputTouch())end
end
function Shop:focusId(id)
 for index,tile in ipairs(self.tiles)do if tile.id==id then self:focus(index,true);return true end end
 return false
end
function Shop:move(dx,dy)
 local nextIndex=Shop.step(self.index,dx,dy,#self.tiles,self.columns)
 if nextIndex==self.index then return false end
 self:focus(nextIndex);return true
end
-- A / Enter / the pane button. Use applies at once (earned, never bought).
function Shop:act()
 local id=self:focusedId();if not id then return false end
 local s=Shop.status(id,self.ctx)
 if s.kind=="retry"then if self.callbacks.retry then self.callbacks.retry()end;return true end
 if s.kind=="earned"then if self.callbacks.use then self.callbacks.use(id)end;return true end
 return false
end
-- Shown when the Backgrounds tab is selected; lands on the background in use.
function Shop:show(visible,landOnConfirmed)
 if not self.body then return end
 self.body.Visible=visible==true
 if visible then
  if landOnConfirmed then
   local landing=table.find(Backgrounds.Order,self.ctx.confirmed or Backgrounds.Default)or 1
   self.index=landing
  end
  self:focus(self.index,true)
 else self:releasePreview()end
end
return Shop
