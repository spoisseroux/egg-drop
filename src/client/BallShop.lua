-- Deck style, Balls tab (batch 2026-11-13 R1; scope C1, mockup 05). Drawn into the
-- Deck style screen that FaceplateShop owns (same header, tab row, focus ring and
-- pane geometry). Cards show the theme's five sizes as they really draw on the
-- board, the name and IN USE / Owned / the Star price. The pane shows the theme on
-- a small board, its tier chip, one line, and the five colour circles it puts in
-- goals. Buy and Use go to the server (HatchRequest "ballThemeBuy" /
-- "ballThemeEquip"; hatching v11, fixed prices, idempotent by operation id); the
-- reply rides FaceplateResult with kind = "ballTheme". Looks only, never an advantage.
local Shared=game:GetService("ReplicatedStorage").Shared
local Themes=require(Shared.BallThemes)
local Kit=require(script.Parent.DeckKit)
local UICopy=require(Shared.UICopy)
local Sprite=require(script.Parent.JellySprite)
local Shop={}
Shop.__index=Shop
Shop.ConfirmSeconds=3
-- Desktop rects in panel units: the pane matches Faceplates; 2 columns of 222x122 cards.
Shop.Regular={pane={24,144,328,392},grid={371,147},tile={222,122},gap=12,columns=2}
Shop.TierChip={starter={"STARTER",Color3.fromHex("#C3C8D0")},common={"COMMON",Color3.fromHex("#9BE3A8")},
 rare={"RARE",Color3.fromHex("#8CC8FF")},showcase={"SHOWCASE",Color3.fromHex("#E6B3FF")}}
Shop.Reasons={NeedStars=UICopy.get("shop.reason.needStars"),Busy=UICopy.get("shop.reason.busy"),Throttled=UICopy.get("shop.reason.throttled"),
 PriceChanged=UICopy.get("shop.reason.priceChanged"),Unowned=UICopy.get("shop.reason.unowned")}
-- The pane's small board: {tier, x, bottom} in pane-board units (0..1 across, px up from the floor).
Shop.Pile={{4,.22,0},{3,.5,0},{5,.8,0},{2,.36,40},{1,.12,44},{2,.62,52},{1,.9,64}}

-- Pure: what the pane says and offers for one theme.
-- ctx = { owned = saved purchase list, equipped = id, wallet = n }
function Shop.status(id,ctx)
 local entry=Themes.ById[id]
 if not entry then return{kind="invalid",text="",button=nil}end
 ctx=ctx or {}
 if(ctx.equipped or Themes.Default)==id then return{kind="inUse",text="In use",button=nil}end
 if Themes.owns(ctx.owned,id)then return{kind="owned",text="Owned",button="Use",enabled=true}end
 local price=entry.price;local wallet=ctx.wallet or 0
 if wallet>=price then return{kind="buy",text="You have enough Stars",button="★ Buy "..price,price=price,enabled=true}end
 return{kind="short",text=(price-wallet).." more Stars needed",button="★ Buy "..price,price=price,enabled=false}
end
-- Pure: the card's status line and its colour role.
function Shop.tileStatus(id,ctx)
 local s=Shop.status(id,ctx)
 if s.kind=="inUse"then return "IN USE","accent"end
 if s.kind=="owned"then return "✓ Owned","soft"end
 if s.kind=="buy"then return "★ "..s.price,"stars"end
 if s.kind=="short"then return "★ "..s.price,"dim"end
 return "","dim"
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
-- One ball preview of a tier at `px` screen pixels per LCD pixel, bottom-centred at (x, bottom).
local function ballAt(parent,themeId,tier,px,x,bottom)
 local look=require(script.Parent.JellyLCD).ballRuns(themeId,tier,"idle",0,false)
 local d=look.size*px
 local holder=Kit.frame(parent,"Ball"..tier,nil,UDim2.fromOffset(x-d/2,bottom-d),UDim2.fromOffset(d,d))
 local preview=Sprite.preview(holder);preview.set(themeId,tier,"idle",0,false)
 return holder,preview
end

-- owner: the Deck style screen (FaceplateShop): root, ring, visible, tab.
-- callbacks: send(action, payload) (optional; default fires Remotes.HatchRequest), bought(id), equipped(id)
function Shop.new(owner,callbacks)
 return setmetatable({owner=owner,callbacks=callbacks or {},index=1,tiles={},ctx={owned={},equipped=Themes.Default,wallet=0,revision=0},
  pending=nil,confirmId=nil,confirmUntil=0},Shop)
end

-- view: nil (desktop panel units) or the compact view; grid geometry from the owner.
function Shop:build(parent,view,grid)
 if self.body then self.body:Destroy()end
 self.view=view;self.tiles={};self.board=nil
 local body=Kit.frame(parent,"Balls",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=parent.ZIndex+1;body.Visible=false
 self.body=body
 if view then
  local W=view.W;local g=grid
  local pw,ph=g.pw,g.paneH
  local pane=Kit.card(body,"Preview",nil,{pad=12,seam=true});pane.Position=UDim2.fromOffset(W-20-pw,64);pane.Size=UDim2.fromOffset(pw,ph)
  self.pane=pane
  local buttonY=ph-60
  local circlesY=buttonY-8-20
  local nameY=circlesY-6-24
  self:buildBoard(pane,12,10,pw-24,math.max(40,nameY-6-10),2)
  self.name=txt(pane,"Title","","text",12,nameY,pw-24-90,24,{TextSize=18,TextTruncate=Enum.TextTruncate.AtEnd})
  self.chip=Kit.chip(pane,"RARE","sticker",22);self.chip.label.TextSize=12;self.chip.root.AnchorPoint=Vector2.new(1,.5);self.chip.root.Position=UDim2.fromOffset(pw-12,nameY+12)
  self:buildCircles(pane,12,circlesY,16,"in goals")
  self.pitch,self.statusLabel=nil,nil
  local action,state=Kit.button(pane,"Action",{variant="primary",text="Use",glyph="A",size=Vector2.new(pw-24,48),textSize=16,selectable=false})
  action.Position=UDim2.fromOffset(12,buttonY);self.action,self.actionState=action,state
  action.Activated:Connect(function()self:act()end)
  local list=Kit.node("ScrollingFrame",body,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,112),
   Size=UDim2.fromOffset(g.gw,g.gridH),ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
   ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
  self.grid=list
  local cols=g.cols or 3
  self.columns=cols
  local tileW=math.floor((g.gw-8-(cols-1)*8)/cols)
  for index,id in ipairs(Themes.Order)do
   local col,row=(index-1)%cols,math.floor((index-1)/cols)
   self:buildTile(list,index,id,3+col*(tileW+2),3+row*76,tileW-6,68,true)
  end
  list.CanvasSize=UDim2.fromOffset(0,math.ceil(#Themes.Order/cols)*76-8+6)
 else
  local R=Shop.Regular
  local pane=Kit.card(body,"Preview",nil,{pad=20,seam=true});pane.Position=UDim2.fromOffset(R.pane[1],R.pane[2]);pane.Size=UDim2.fromOffset(R.pane[3],R.pane[4])
  self.pane=pane
  self:buildBoard(pane,16,16,296,172,3)
  self.name=txt(pane,"Title","","text",20,196,200,30,{TextTruncate=Enum.TextTruncate.AtEnd})
  self.chip=Kit.chip(pane,"RARE","sticker",26);self.chip.root.AnchorPoint=Vector2.new(1,.5);self.chip.root.Position=UDim2.fromOffset(308,211)
  self.pitch=txt(pane,"Small","","text",20,230,288,20,{TextSize=15,TextTruncate=Enum.TextTruncate.AtEnd})
  self.statusLabel=txt(pane,"Small",UICopy.get("style.balls.pitch"),"soft",20,252,288,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  self:buildCircles(pane,20,282,22,"in goals and quests")
  local action,state=Kit.button(pane,"Action",{variant="primary",text="Use",glyph="A",size=Vector2.new(288,56),selectable=false})
  action.Position=UDim2.fromOffset(20,R.pane[4]-16-56);self.action,self.actionState=action,state
  action.Activated:Connect(function()self:act()end)
  self.grid=nil;self.columns=R.columns
  for index,id in ipairs(Themes.Order)do
   local col,row=(index-1)%R.columns,math.floor((index-1)/R.columns)
   self:buildTile(body,index,id,R.grid[1]+col*(R.tile[1]+R.gap),R.grid[2]+row*(R.tile[2]+R.gap),R.tile[1],R.tile[2],false)
  end
 end
 self.index=math.clamp(self.index,1,#self.tiles)
 return body
end

-- The pane's small board: a dark well with a pile of the theme's balls (faces on).
function Shop:buildBoard(pane,x,y,w,h,px)
 local well=Kit.frame(pane,"MiniBoard","well",UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),12);Kit.stroke(well);well.ClipsDescendants=true
 Kit.dotGrid(well) -- T7 LCD dot grid under the pile
 self.board={well=well,w=w,h=h,px=px,balls={}}
end
function Shop:paintBoard(themeId)
 local b=self.board;if not b or b.themeId==themeId then return end
 b.themeId=themeId
 for _,ball in ipairs(b.balls)do ball:Destroy()end;table.clear(b.balls)
 local floorY=b.h-4
 for _,p in ipairs(Shop.Pile)do
  local holder=ballAt(b.well,themeId,p[1],b.px,p[2]*b.w,floorY-p[3]*(b.px/3))
  table.insert(b.balls,holder)
 end
end
-- Five colour circles (the goal icons this theme gives), stepped in size.
function Shop:buildCircles(pane,x,y,slot,caption)
 local row=Kit.frame(pane,"Circles",nil,UDim2.fromOffset(x,y),UDim2.fromOffset(slot*5+8*4+160,slot))
 self.circles={}
 for tier=1,5 do
  local holder=Kit.frame(row,"Circle"..tier,nil,UDim2.fromOffset((tier-1)*(slot+8),0),UDim2.fromOffset(slot,slot))
  local scale=Themes.CircleScale[tier]
  local circle=Kit.frame(holder,"Dot",nil,UDim2.fromScale(.5,.5),UDim2.fromScale(scale,scale),999);circle.AnchorPoint=Vector2.new(.5,.5);circle.BackgroundTransparency=0
  local ring=Instance.new("UIStroke");ring.Thickness=1;ring.Transparency=.35;ring.Parent=circle
  self.circles[tier]={circle=circle,ring=ring}
 end
 txt(row,"Small",caption,"soft",5*(slot+8)+2,0,160,slot,{TextSize=if slot<20 then 12 else 14})
end

function Shop:buildTile(parent,index,id,x,y,w,h,compact)
 local entry=Themes.ById[id]
 -- T2: pressable tile with a lip (4 px in the 12 px desktop gap, 3 px in the 8 px phone gap).
 local tile,tileState=Kit.tile(parent,"Tile_"..id,{selectable=false,radius=12,compact=compact,position=UDim2.fromOffset(x,y),size=UDim2.fromOffset(w,h)})
 local stroke=tileState.stroke
 tile:SetAttribute("AccessibleLabel",entry.name);tile:SetAttribute("BallThemeId",id)
 -- The five sizes in a row, as they draw on the board (smaller scale on phones).
 local stripH=if compact then 30 else 66
 local strip=Kit.frame(tile,"Strip","well",UDim2.fromOffset(6,6),UDim2.fromOffset(w-12,stripH),10)
 Kit.dotGrid(strip) -- T7: a row of balls reads as a small screen
 local px=if compact then 1 else 2
 local xs={.06,.19,.36,.59,.84}
 for tier=1,5 do ballAt(strip,id,tier,px,xs[tier]*(w-12),stripH-3)end
 local nameY=if compact then stripH+10 else stripH+14
 local nameLabel=txt(tile,"Name",entry.name,"text",10,nameY,w-20-(if compact then 70 else 90),20,{TextSize=if compact then 13 else 16,TextTruncate=Enum.TextTruncate.AtEnd})
 local status=txt(tile,"Counter","","soft",w-10-(if compact then 70 else 90),nameY,if compact then 70 else 90,20,{TextSize=13,TextXAlignment=Enum.TextXAlignment.Right,AutoLocalize=true})
 self.tiles[index]={id=id,button=tile,status=status,name=nameLabel,stroke=stroke}
 tile.Activated:Connect(function()if self.index==index then self:act()else self:focus(index);Kit.boing(tile)end end)
end

-- ctx keys: owned (list), equipped (id), wallet (n), revision (n). Absent keys keep their value.
function Shop:setContext(ctx)
 for key,value in pairs(ctx)do self.ctx[key]=value end
 -- QA Q2.4: while an optimistic equip is in flight a snapshot cannot flip it back;
 -- the server's word arrives as the result (Saved keeps it, a refusal rolls back).
 local p=self.pending
 if p and p.action=="ballThemeEquip"then self.serverEquipped=self.ctx.equipped;self.ctx.equipped=p.themeId end
 if self.body then self:refresh()end
end
function Shop:focusedId()local tile=self.tiles[self.index];return tile and tile.id end
function Shop:active()return self.owner.visible==true and self.owner.tab==3 and self.body~=nil and self.body.Visible end

function Shop:refresh()
 for index,tile in ipairs(self.tiles)do
  local text,role=Shop.tileStatus(tile.id,self.ctx)
  if self.view and role=="dim"then role="soft"end
  tile.status.Text=text
  tile.status.FontFace=if role=="accent"then Kit.Type.Label[3]else Kit.Type.Counter[3]
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
 local entry=Themes.ById[id]
 local s=Shop.status(id,self.ctx)
 self.name.Text=entry.name
 local chip=Shop.TierChip[entry.tier]or Shop.TierChip.starter
 self.chip.set(chip[1],"sticker",chip[2]) -- T6: the tier is the detail card's sticker (ink on the tier colour)
 if self.pitch then self.pitch.Text=entry.pitch end
 for tier,c in ipairs(self.circles or {})do
  local r=entry.ramps[tier];c.circle.BackgroundColor3=Color3.fromHex(r.body);c.ring.Color=Color3.fromHex(r.light)
 end
 self:paintBoard(id)
 local pending=self.pending and self.pending.themeId==id and self.pending.action=="ballThemeBuy"
 local confirming=self.confirmId==id and os.clock()<self.confirmUntil
 local note=if pending then "Buying…"
  elseif self.errorId==id and self.errorText then self.errorText else nil
 if self.statusLabel then
  self.statusLabel.Text=note or(if s.kind=="short"then s.text else UICopy.get("style.balls.pitch"))
  if not pending and self.errorId==id and self.errorFit then Kit.fitText(self.statusLabel,self.errorFit)end
 end
 self.action.Visible=s.button~=nil
 if s.button then
  Kit.setText(self.action,if pending then "…"elseif confirming then "Confirm ★ "..s.price else s.button)
  Kit.setEnabled(self.action,s.enabled==true and not pending)
 end
 self.owner.root:SetAttribute("FocusedBallTheme",id);self.owner.root:SetAttribute("BallPaneState",s.kind)
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
 if index~=self.index then self.confirmId=nil;self.errorId=nil end
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

function Shop:send(action,payload)
 if self.callbacks.send then return self.callbacks.send(action,payload)end
 local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
 local remote=remotes and remotes:FindFirstChild("HatchRequest")
 if remote then remote:FireServer(action,payload,self.ctx.revision or 0)end
end
-- A / Enter / the pane button. Use applies at once; buying needs one confirmation within 3 s.
function Shop:act()
 local id=self:focusedId();if not id then return false end
 -- An equip in flight never blocks the next choice; a buy does.
 if self.pending and self.pending.action~="ballThemeEquip"then return false end
 local s=Shop.status(id,self.ctx)
 local http=game:GetService("HttpService")
 if s.kind=="owned"then
  -- QA Q2.4: optimistic. The theme is in use at once; the save runs in the background
  -- and only a refusal puts the previous theme back (with a toast).
  local previous=if self.pending then self.pending.previous else(self.ctx.equipped or Themes.Default)
  self.pending={id=http:GenerateGUID(false),themeId=id,action="ballThemeEquip",previous=previous}
  self.ctx.equipped=id;self.errorId,self.errorText=nil,nil
  self:send("ballThemeEquip",{id=self.pending.id,themeId=id})
  if self.callbacks.equipped then self.callbacks.equipped(id)end
  self:refresh();return true
 elseif s.kind=="buy"then
  if self.pending then return false end -- let an equip's save land first
  if self.confirmId==id and os.clock()<self.confirmUntil then
   self.confirmId=nil
   self.pending={id=http:GenerateGUID(false),themeId=id,action="ballThemeBuy",price=s.price}
   self:send("ballThemeBuy",{id=self.pending.id,themeId=id,price=s.price,equip=true})
   self:paintPane();return true
  end
  self.confirmId,self.confirmUntil=id,os.clock()+Shop.ConfirmSeconds
  local token=self.confirmUntil
  task.delay(Shop.ConfirmSeconds,function()if self.confirmUntil==token then self.confirmId=nil;if self.body then self:paintPane()end end end)
  self:paintPane();return true
 end
 return false
end
-- Server reply (FaceplateResult, kind = "ballTheme").
function Shop:result(message)
 if not self.pending or type(message)~="table"or message.id~=self.pending.id then return false end
 if message.status=="Retrying"then return false end
 local done=self.pending;self.pending=nil
 if message.status~="Saved"and done.action=="ballThemeEquip"then
  -- Roll back the optimistic equip (the server's last word, else what was worn before).
  local back=self.serverEquipped or done.previous or Themes.Default
  self.serverEquipped=nil;self.ctx.equipped=back
  self.errorId,self.errorText,self.errorFit=done.themeId,Shop.Reasons[message.reason]or UICopy.get("shop.failed.applied"),nil
  if self.callbacks.equipped then self.callbacks.equipped(back)end
  if self.callbacks.rolledBack then self.callbacks.rolledBack(done.themeId)
  elseif self.owner and self.owner.root then self.toaster=self.toaster or Kit.toaster(self.owner.root);self.toaster.show(UICopy.get("shop.rolledBack"))end
  self:refresh();return true
 end
 self.serverEquipped=nil
 if message.status~="Saved"then
  self.errorId,self.errorText,self.errorFit=done.themeId,Shop.Reasons[message.reason]or UICopy.get(if done.action=="ballThemeBuy"then "shop.failed.bought"else "shop.failed.applied"),nil
  if message.reason=="NeedStars"and done.action=="ballThemeBuy"then
   local entry=Themes.ById[done.themeId]
   self.errorFit=UICopy.starsShort(if entry and entry.price then entry.price-(self.ctx.wallet or 0)else nil);self.errorText=self.errorFit[1]
  end
 else
  self.errorId,self.errorText=nil,nil
  -- Optimistic until the next nursery snapshot confirms it.
  local owned=table.clone(self.ctx.owned or {})
  if done.action=="ballThemeBuy"and not table.find(owned,done.themeId)then table.insert(owned,done.themeId)end
  self.ctx.owned,self.ctx.equipped=owned,done.themeId
  if done.action=="ballThemeBuy"and self.callbacks.bought then self.callbacks.bought(done.themeId)end
  if done.action=="ballThemeBuy"and self.callbacks.equipped then self.callbacks.equipped(done.themeId)end
 end
 self:refresh();return true
end
-- Shown when the Balls tab is selected; lands on the theme in use.
function Shop:show(visible,landOnEquipped)
 if not self.body then return end
 self.body.Visible=visible==true
 if visible then
  if landOnEquipped then self.index=table.find(Themes.Order,self.ctx.equipped or Themes.Default)or 1 end
  self:focus(self.index,true)
 else self.confirmId=nil end
end
return Shop
