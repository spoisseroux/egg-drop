-- Deck style, Effects tab (deck juice, V3-LEVELS-BUILD-PLAN-2026-11-22 S3). Drawn into the Deck style
-- screen that FaceplateShop owns, as BallShop is, and only while Levels.on("juice"). Three rows: merge
-- pop, drop trail, start; each has Classic and two that a stat level unlocks. The pane plays the focused
-- one with the real renderers (FieldEffects, DropTrail, DeckFlourish). Nothing is sold: Use sends
-- BoardRequest "deckJuice" {kind, id}; the server checks the save and answers through the board's
-- DeckJuice attribute. Looks only, never an advantage.
local Shared=game:GetService("ReplicatedStorage").Shared
local Juice=require(Shared.DeckJuiceCatalog)
local Gate=require(Shared.LevelGate)
local Stats=require(Shared.StatCatalog)
local BallThemes=require(Shared.BallThemes)
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local Locked=require(script.Parent.LockedItem)
local Field=require(script.Parent.FieldEffects)
local RunService=game:GetService("RunService")
local Shop={}
Shop.__index=Shop
Shop.Tab=4
Shop.Columns=3
Shop.SendGap=.3 -- the server takes one choice per .25 s
Shop.PendingFor=4 -- seconds a choice shows before the board has answered
Shop.Regular={pane={24,144,328,392},grid={371,144},tile={143,92},gap=12,pitch=132}
Shop.Ink=Color3.fromHex("#142D20")

-- Pure: the nine cards in order, {kind, id, name, gate}.
function Shop.items()
 local out={}
 for _,kind in ipairs(Juice.Kinds)do
  table.insert(out,{kind=kind,id=Juice.Classic,name=UICopy.get("style.effects.classic")})
  for _,row in ipairs(Juice.ByKind[kind])do table.insert(out,{kind=kind,id=row.id,name=row.name,gate=row.gate})end
 end
 return out
end
-- Pure: the level gate of a card, in LockedItem's words and shape; nil for Classic.
function Shop.gate(item,levels)
 if not item.gate then return nil end
 local info=Locked.info(item,levels)
 if info then return info end
 -- Effects on without the shop gates: the same answer, the tab's own words.
 local p=Gate.progress(levels,item.gate)
 local words=UICopy.get("style.effects.locked",{name=UICopy.get("stats.name."..item.gate.stat),level=p.need})
 local count=tostring(math.min(p.have,p.need)).."/"..tostring(p.need)
 return{met=p.met,have=p.have,need=p.need,petId=p.petId,stat=p.stat,color=Stats.ById[p.stat].color,needs=words,short=words,
  count=count,line=words.." · "..count,ratio=math.clamp(p.have/p.need,0,1)}
end
-- Pure: what the pane says and offers. ctx = {choice = {pop, trail, start}, levels = {petId={stat=level}}}.
function Shop.status(item,ctx)
 ctx=ctx or {}
 local chosen=ctx.choice and ctx.choice[item.kind]or Juice.Classic
 if chosen==item.id then return{kind="inUse",text="",button=UICopy.get("r4.inUse"),enabled=false}end
 if Juice.unlocked(item.kind,item.id,ctx.levels)then return{kind="owned",text="",button="Use",enabled=true}end
 local gate=Shop.gate(item,ctx.levels)
 if not gate then return{kind="invalid",text="",button=nil}end
 return{kind="locked",text=gate.line,button=Locked.trainText(gate),gate=gate,enabled=true}
end
-- Pure: the card's status line and its colour role (a locked card shows its chip instead).
function Shop.tileStatus(item,ctx)
 local s=Shop.status(item,ctx)
 if s.kind=="inUse"then return "IN USE","accent"end
 if s.kind=="owned"then return(if item.gate then "Earned"else ""),"soft"end
 return "","dim"
end
function Shop.step(index,dx,dy,count)
 local cols=Shop.Columns
 local col,row=(index-1)%cols,math.floor((index-1)/cols)
 col=math.clamp(col+dx,0,cols-1);row=math.clamp(row+dy,0,math.ceil(count/cols)-1)
 return math.max(1,math.min(count,row*cols+col+1))
end

-- Toy Shell: a role read on `object`'s own surface (ink on cream tiles, white on trays).
local function colorOf(role,object,property)return Kit.roleOn(object,role,property)end
local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
-- A drawn piece of a card's picture, in units of the strip's height from its centre.
local function piece(strip,h,x,y,w,ph,color,radius,turn)
 local f=Kit.frame(strip,"Piece",nil,UDim2.new(.5,math.floor(x*h+.5),.5,math.floor(y*h+.5)),UDim2.fromOffset(math.max(3,math.floor(w*h+.5)),math.max(3,math.floor(ph*h+.5))),radius or 999)
 f.AnchorPoint=Vector2.new(.5,.5);f.BackgroundTransparency=0;f.BackgroundColor3=color;f.Rotation=turn or 0;f.ZIndex=strip.ZIndex+2
 local s=Instance.new("UIStroke");s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Thickness=1;s.Color=Shop.Ink;s.Parent=f
 return f
end
local Cream,Sky,Lemon=Color3.fromHex("#F4F8E9"),Color3.fromHex("#58B8FF"),Color3.fromHex("#FFD84A")
-- The card's picture: chunky shapes, no art needed.
function Shop.art(strip,h,kind,id)
 if kind=="pop"then
  piece(strip,h,0,.06,.4,.4,Sky)
  if id=="confetti"then
   for j=1,6 do local a=j*math.pi/3+.35;piece(strip,h,math.cos(a)*.62,math.sin(a)*.32,.2,.13,Field.Confetti[j],2,j*47)end
  elseif id=="fizz"then
   for j,p in ipairs({{-.42,.1,.2},{-.26,-.28,.14},{.04,-.34,.2},{.3,-.22,.16},{.46,.08,.22}})do piece(strip,h,p[1],p[2],p[3],p[3],if j%2==0 then Cream else Color3.fromHex("#BFE4FF"))end
  else for j=1,4 do local a=j*math.pi/2+.78;piece(strip,h,math.cos(a)*.42,math.sin(a)*.36,.1,.1,if j%2==0 then Cream else Sky)end end
 elseif kind=="trail"then
  piece(strip,h,0,.24,.36,.36,Sky)
  if id=="bubble"then
   for j,p in ipairs({{-.12,-.04,.18},{.12,-.16,.14},{-.06,-.3,.2},{.16,-.38,.1}})do piece(strip,h,p[1],p[2],p[3],p[3],if j%2==0 then Cream else Color3.fromHex("#A9E8FF"))end
  elseif id=="comet"then
   for j,p in ipairs({{-.02,.3,"#FF8FB4"},{-.16,.24,"#FFC23D"},{-.28,.17,"#FFF3B0"},{-.38,.1,"#FFF3B0"}})do piece(strip,h,0,p[1],p[2],p[2],Color3.fromHex(p[3]))end
  end
 elseif id=="ready"then
  piece(strip,h,0,0,1.3,.44,Color3.fromHex("#FFD35C"),8)
  for j=1,3 do piece(strip,h,(j-2)*.36,0,.24,.24,if j==3 then Color3.fromHex("#5FE39A")else Color3.fromHex("#FFF1A8"))end
 elseif id=="lightning"then
  piece(strip,h,-.42,0,.5,.44,Color3.fromHex("#4F7BFF"),8);piece(strip,h,.42,0,.5,.44,Color3.fromHex("#4F7BFF"),8)
  piece(strip,h,.04,-.24,.12,.36,Lemon,3,24);piece(strip,h,0,0,.12,.36,Lemon,3,-38);piece(strip,h,.02,.24,.12,.36,Lemon,3,20)
 else piece(strip,h,0,0,1.1,.2,Color3.fromHex("#8FA39A"),6)end
end

-- owner: the Deck style screen (FaceplateShop): root, ring, visible, tab, balls, callbacks.train.
-- callbacks: send(kind, id) and board() (optional; defaults BoardRequest and the owner's board folder).
function Shop.new(owner,callbacks)
 return setmetatable({owner=owner,callbacks=callbacks or {},index=1,tiles={},list=Shop.items(),server={},pending={},queue={},ctx={choice={}},sentAt=-math.huge},Shop)
end
function Shop:build(parent,view,grid)
 self:stopDemo()
 if self.body then self.body:Destroy()end
 self.view=view;self.tiles={};self.demo=nil
 local body=Kit.frame(parent,"Effects",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=parent.ZIndex+1;body.Visible=false
 self.body=body
 if view then
  local W=view.W;local pw,ph=grid.pw,grid.paneH
  local pane=Kit.card(body,"Preview",nil,{pad=12,seam=false});pane.Position=UDim2.fromOffset(W-20-pw,64);pane.Size=UDim2.fromOffset(pw,ph)
  self.pane=pane
  local buttonY=ph-60;local lineY=buttonY-12-20;local nameY=lineY-24
  self:buildWell(pane,12,10,pw-24,math.max(40,nameY-6-10))
  self.name=txt(pane,"Title","","text",12,nameY,pw-24,24,{TextSize=18,TextTruncate=Enum.TextTruncate.AtEnd})
  self.pitch=nil
  self.statusLabel=txt(pane,"Small","","soft",12,lineY,pw-24,20,{TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd})
  self.bar=Locked.bar(pane,12,buttonY-10,pw-24,5)
  local action,state=Kit.button(pane,"Action",{variant="primary",text="Use",glyph="A",size=Vector2.new(pw-24,48),textSize=16,selectable=false})
  action.Position=UDim2.fromOffset(12,buttonY);self.action,self.actionState=action,state
  local list=Kit.node("ScrollingFrame",body,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,112),
   Size=UDim2.fromOffset(grid.gw,grid.gridH),ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
   ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
  self.grid=list
  local tileW=math.floor((grid.gw-8-16)/Shop.Columns)
  self:buildRows(list,3,0,tileW-6,80,8+6,112,true)
  local bleed=Kit.scrollBleed(list,4)
  list.CanvasSize=UDim2.fromOffset(0,#Juice.Kinds*112-8+bleed*2)
 else
  local R=Shop.Regular
  local pane=Kit.card(body,"Preview",nil,{pad=20,seam=true});pane.Position=UDim2.fromOffset(R.pane[1],R.pane[2]);pane.Size=UDim2.fromOffset(R.pane[3],R.pane[4])
  self.pane=pane
  self:buildWell(pane,16,16,296,172)
  self.name=txt(pane,"Title","","text",20,196,288,30,{TextTruncate=Enum.TextTruncate.AtEnd})
  self.pitch=txt(pane,"Small",UICopy.get("style.effects.promise"),"soft",20,230,288,20,{TextSize=15,TextTruncate=Enum.TextTruncate.AtEnd})
  self.statusLabel=txt(pane,"Small","","text",20,254,288,20,{TextSize=15,TextTruncate=Enum.TextTruncate.AtEnd})
  self.bar=Locked.bar(pane,20,280,288,6)
  local action,state=Kit.button(pane,"Action",{variant="primary",text="Use",glyph="A",size=Vector2.new(288,56),selectable=false})
  action.Position=UDim2.fromOffset(20,R.pane[4]-16-56);self.action,self.actionState=action,state
  self.grid=nil
  self:buildRows(body,R.grid[1],R.grid[2],R.tile[1],R.tile[2],R.gap,R.pitch,false)
 end
 self.action.Activated:Connect(function()self:act()end)
 self.index=math.clamp(self.index,1,#self.tiles)
 return body
end
function Shop:buildRows(parent,x0,y0,w,h,gap,pitch,compact)
 for row,kind in ipairs(Juice.Kinds)do
  txt(parent,"Strong",UICopy.get("style.effects."..kind),"text",x0+2,y0+(row-1)*pitch,w*2,18,{Name="Row_"..kind,TextSize=if compact then 14 else 15})
 end
 for index,item in ipairs(self.list)do
  local col,row=(index-1)%Shop.Columns,math.floor((index-1)/Shop.Columns)
  self:buildTile(parent,index,item,x0+col*(w+gap),y0+row*pitch+20,w,h,compact)
 end
end
function Shop:buildTile(parent,index,item,x,y,w,h,compact)
 local tile,tileState=Kit.tile(parent,"Tile_"..item.kind.."_"..item.id,{selectable=false,radius=12,compact=compact,position=UDim2.fromOffset(x,y),size=UDim2.fromOffset(w,h)})
 tile:SetAttribute("EffectKind",item.kind);tile:SetAttribute("EffectId",item.id)
 local stripH=h-48
 local strip=Kit.frame(tile,"Strip","well",UDim2.fromOffset(6,6),UDim2.fromOffset(w-12,stripH),10);strip.ClipsDescendants=true
 Kit.dotGrid(strip)
 Shop.art(strip,stripH,item.kind,item.id)
 local name=txt(tile,"Name",item.name,"text",8,stripH+8,w-16,18,{TextSize=if compact then 13 else 15,TextTruncate=Enum.TextTruncate.AtEnd})
 local status=txt(tile,"Counter","","soft",8,stripH+26,w-16,18,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd,AutoLocalize=true})
 local entry={item=item,button=tile,status=status,name=name,stroke=tileState.stroke}
 if item.gate then
  -- Art review: the picture at 45%, a 16 px lock.
  entry.lock=Locked.mark(strip,23,.45)
  entry.chip=Locked.chip(tile,18);entry.chip.root.Position=UDim2.fromOffset(6,stripH+26);entry.chipRoom=w-12
 end
 self.tiles[index]=entry
 tile.Activated:Connect(function()if self.index==index then self:act()else self:focus(index);Kit.boing(tile)end end)
end

-- ── The pane's demo ───────────────────────────────────────────────────────
function Shop:buildWell(pane,x,y,w,h)
 local _,well=Kit.previewWell(pane,"MiniBoard",UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),12)
 Kit.dotGrid(well)
 self.well={node=well,w=w-4,h=h-4}
end
-- Made the first time the tab shows: one ball, one effects layer, and a stand-in for the board's views.
function Shop:makeDemo()
 local well=self.well
 if self.demo or not well then return self.demo end
 local px=if self.view then 1.5 else 2.5
 local themeId=self.owner.balls and self.owner.balls.ctx.equipped or BallThemes.Default
 if not BallThemes.ById[themeId]then themeId=BallThemes.Default end
 local look=require(script.Parent.JellyLCD).ballRuns(themeId,3,"merged",0,false)
 local d=math.floor(look.size*px+.5)
 local holder=Kit.frame(well.node,"Ball",nil,UDim2.fromOffset(0,0),UDim2.fromOffset(d,d));holder.AnchorPoint=Vector2.new(.5,.5)
 require(script.Parent.JellySprite).preview(holder).set(themeId,3,"merged",0,false)
 local host=Kit.frame(well.node,"Effects",nil,UDim2.new(),UDim2.fromScale(1,1));host.ZIndex=holder.ZIndex+4
 local source={Position=Vector3.new(well.w/2,well.h,0),Size=Vector3.new(d,d,d)}
 local fx=Field.new(host)
 local at=Vector2.zero
 fx.juice={views={[source]={tier=3}},launchY=well.h,lidHeight=.46,project=function(p)at=Vector2.new(p.X,well.h-p.Y);return at,1 end}
 fx:setOwner(true,1,false)
 self.demo={fx=fx,holder=holder,source=source,d=d,color=BallThemes.color(3,themeId),base=0,loop=-1}
 return self.demo
end
Shop.Loop={pop=1.5,trail=1.7,start=2.2}
-- One frame of the focused card's demo. Public for the specs.
function Shop:stepDemo(now)
 local demo,well=self.demo,self.well
 local item=self.list[self.index]
 if not demo or not item then return end
 local key=item.kind..item.id
 if demo.key~=key then
  demo.key=key;demo.base,demo.loop=now,-1
  demo.fx:clear()
  demo.fx:setJuice(if item.kind=="pop"then item.id else nil,if item.kind=="trail"then item.id else nil,if item.kind=="start"then item.id else nil)
 end
 local age=now-demo.base;local period=Shop.Loop[item.kind]
 local loop=math.floor(age/period);local t=age-loop*period
 local began=loop~=demo.loop;demo.loop=loop
 local x,y=well.w/2,well.h-demo.d/2-6
 if item.kind=="pop"then
  y=well.h*.56
  if began then demo.fx:emit("merge",Vector2.new(x,y),demo.d/2,demo.color,3,1,1,now,nil,false,nil)end
 elseif item.kind=="trail"then
  local u=math.clamp(t/.6,0,1)
  local rest=y;y=rest*u*u
  demo.source.Position=Vector3.new(x,well.h-y,0)
  if began and demo.fx.trail then demo.fx.trail:added(demo.source,now)end
 elseif began and demo.fx.flourish then demo.fx.flourish:play(now)end
 local position=UDim2.fromOffset(x,y)
 if demo.holder.Position~=position then demo.holder.Position=position end
 demo.fx:update(now)
end
function Shop:startDemo()
 if self.demoLink then return end
 local demo=self:makeDemo()
 if not demo then return end
 demo.holder.Position=UDim2.fromOffset(self.well.w/2,self.well.h*.56)
 if Kit.patternStill()then return end -- the cards' pictures stand still too
 self.demoLink=RunService.RenderStepped:Connect(function()
  if not self:active()or Kit.patternStill()then self:stopDemo();return end
  self:stepDemo(os.clock())
 end)
end
function Shop:stopDemo()
 if self.demoLink then self.demoLink:Disconnect();self.demoLink=nil end
 if self.demo then self.demo.key=nil;self.demo.fx:clear()end
end

-- ── The choice ────────────────────────────────────────────────────────────
function Shop:board()
 if self.callbacks.board then return self.callbacks.board()end
 local player=game:GetService("Players").LocalPlayer
 local boards=player and game:GetService("ReplicatedStorage"):FindFirstChild("EggDropBoards")
 return boards and boards:FindFirstChild(tostring(player.UserId))or nil
end
-- Follow the board's attribute (the server's word), once.
function Shop:watch()
 local board=self:board()
 if not board or self.link then return end
 self.link=board:GetAttributeChangedSignal(Juice.Attribute):Connect(function()self:syncChoice()end)
 self:syncChoice()
end
function Shop:syncChoice()
 local board=self:board()
 local pop,trail,start=Field.readJuice(board and board:GetAttribute(Juice.Attribute))
 self.server={pop=pop,trail=trail,start=start}
 for kind,wanted in pairs(self.pending)do
  if(self.server[kind]or Juice.Classic)==wanted.id then self.pending[kind]=nil end
 end
 self:showChoice()
end
-- The server's choice, with one still on its way shown as in use.
function Shop:showChoice()
 local choice={}
 for _,kind in ipairs(Juice.Kinds)do choice[kind]=self.pending[kind]and self.pending[kind].id or self.server[kind]or Juice.Classic end
 self.ctx.choice=choice
 if self.body then self:refresh()end
end
function Shop:choose(kind,id)
 local wanted={id=id}
 self.pending[kind]=wanted;self.queue[kind]=id
 self:showChoice();self:flush()
 -- No answer (refused, or nothing changed): the server's word shows again.
 task.delay(Shop.PendingFor,function()
  if self.pending[kind]==wanted and not self.released then self.pending[kind]=nil;self:showChoice()end
 end)
end
-- One send at a time, SendGap apart, the last choice of each kind winning.
function Shop:flush()
 if self.flushing or self.released then return end
 local kind,id=next(self.queue)
 if not kind then return end
 local wait=Shop.SendGap-(os.clock()-self.sentAt)
 if wait<=0 then
  self.queue[kind]=nil;self.sentAt=os.clock()
  self:send(kind,id)
  if next(self.queue)==nil then return end
  wait=Shop.SendGap
 end
 self.flushing=true
 task.delay(wait,function()self.flushing=false;self:flush()end)
end
function Shop:send(kind,id)
 if self.callbacks.send then return self.callbacks.send(kind,id)end
 local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
 local remote=remotes and remotes:FindFirstChild("BoardRequest")
 if remote then remote:FireServer("deckJuice",{kind=kind,id=id})end
end
-- ctx.levels (specs) pins the levels; without it the owner's latest snapshot decides.
function Shop:setContext(ctx)
 if ctx.levels then self.pinned=ctx.levels end
 if self.body then self:refresh()end
end
function Shop:focusedItem()return self.list[self.index]end
function Shop:active()return self.owner.visible==true and self.owner.tab==Shop.Tab and self.body~=nil and self.body.Visible end

function Shop:refresh()
 self.ctx.levels=self.pinned or Locked.levels()
 for index,tile in ipairs(self.tiles)do
  local text,role=Shop.tileStatus(tile.item,self.ctx)
  local s=Shop.status(tile.item,self.ctx)
  if self.view and role=="dim"then role="soft"end
  tile.status.Text=text
  -- 12 px, or 11 where a long word needs it.
  tile.status.TextSize=if Kit.measure(text,"Counter",12).X*(if Kit.translating then 1.35 else 1)<=tile.status.Size.X.Offset then 12 else 11
  tile.status.FontFace=if role=="accent"then Kit.Type.Label[3]else Kit.Type.Counter[3]
  Kit.paint(tile.status,"TextColor3",function()return colorOf(role,tile.status,"TextColor3")end)
  if tile.chip then
   tile.chip.set(s.gate,tile.chipRoom);tile.lock.set(s.kind=="locked")
  end
  tile.button:SetAttribute("AccessibleLabel",UICopy.get("style.effects."..tile.item.kind)..": "..tile.item.name..(if s.gate then ", "..s.gate.needs else ""))
  local focused=index==self.index
  Kit.paint(tile.button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised",tile.button,"BackgroundColor3")end)
  tile.stroke.Thickness=if focused then 2 else 1;tile.stroke.Transparency=if focused then 0 else .86
  Kit.paint(tile.stroke,"Color",function()return Kit.color("ink")end)
  tile.button:SetAttribute("TileState",s.kind)
 end
 self:paintPane()
end
function Shop:paintPane()
 local item=self:focusedItem();if not item or not self.name then return end
 local s=Shop.status(item,self.ctx)
 local kindName=UICopy.get("style.effects."..item.kind)
 self.name.Text=item.name
 if s.gate then Kit.fitText(self.statusLabel,{s.gate.line,s.gate.needs})else self.statusLabel.Text=kindName end
 self.bar.set(s.gate)
 self.action.Visible=s.button~=nil
 if s.button then
  Kit.setText(self.action,s.button)
  Kit.setEnabled(self.action,s.enabled==true and(s.kind~="locked"or self:canTrain()))
 end
 self.owner.root:SetAttribute("FocusedEffect",item.kind.."."..item.id);self.owner.root:SetAttribute("EffectPaneState",s.kind)
end
function Shop:canTrain()local callbacks=self.owner.callbacks;return callbacks~=nil and callbacks.train~=nil end

function Shop:scrollTo(index)
 local list=self.grid;local tile=self.tiles[index];if not list or not tile then return end
 -- Its row's caption comes along.
 local top=tile.button.Position.Y.Offset-20;local bottom=tile.button.Position.Y.Offset+tile.button.Size.Y.Offset
 local view=list.AbsoluteWindowSize.Y;if view<=0 then view=list.Size.Y.Offset end
 local y=list.CanvasPosition.Y
 if top-4<y then y=top-4 elseif bottom+8>y+view then y=bottom+8-view end
 list.CanvasPosition=Vector2.new(0,math.clamp(y,0,math.max(0,list.CanvasSize.Y.Offset-view)))
end
function Shop:focus(index,instant)
 if #self.tiles==0 then return end
 self.index=math.clamp(index,1,#self.tiles);self:refresh();self:scrollTo(self.index)
 local ring=self.owner.ring
 if ring and self:active()then
  ring.attach(self.tiles[self.index].button,12)
  if instant then ring.root.Visible=self.owner.visible and ring.root.Visible end
 end
 if self.view and self.action then Kit.setGlyphVisible(self.action,not Kit.lastInputTouch())end
end
function Shop:focusId(kind,id)
 for index,item in ipairs(self.list)do if item.kind==kind and item.id==id then self:focus(index,true);return true end end
 return false
end
function Shop:move(dx,dy)
 local nextIndex=Shop.step(self.index,dx,dy,#self.tiles)
 if nextIndex==self.index then return false end
 self:focus(nextIndex);return true
end
-- A / Enter / the pane button: Use applies at once; a locked card leads to its training.
function Shop:act()
 local item=self:focusedItem();if not item then return false end
 local s=Shop.status(item,self.ctx)
 if s.kind=="owned"then
  self:choose(item.kind,item.id)
  require(script.Parent.UIClick).play("equip")
  return true
 elseif s.kind=="locked"and self:canTrain()then
  self.owner.callbacks.train(Locked.route(s.gate));return true
 end
 return false
end
-- Shown when the Effects tab is selected; lands on the merge pop in use.
function Shop:show(visible,landOnUsed)
 if not self.body then return end
 self.body.Visible=visible==true
 if not visible then self:stopDemo();return end
 self:watch()
 if landOnUsed then
  self.index=1
  for index,item in ipairs(self.list)do if item.kind=="pop"and item.id==(self.ctx.choice.pop or Juice.Classic)then self.index=index end end
 end
 self:focus(self.index,true);self:startDemo()
end
function Shop:release()
 self.released=true
 self:stopDemo()
 if self.link then self.link:Disconnect();self.link=nil end
 if self.body then self.body:Destroy();self.body=nil end
end
return Shop
