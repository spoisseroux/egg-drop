-- v2 pet names: the naming screen (V2-CUTE-ICONS-AND-NAMES-2026-11-20 2.6, mockup
-- artifacts/v2-cute-icons-names-2026-11-20/04-naming-screen-844x390@2x.png). Companions → pet → Name.
-- Same frame as the stats panel (shade, 848x608 panel or the phone sheet, shared header).
--   Left: the pet in its well with its name tag as it will float over it (updates as you pick),
--         the species chip, and where the name shows.
--   Right: the two slots (lemon = filled) with Swap and Clear; tabs All / Starter / Names Egg /
--         Stats / Book with owned / total; a grid of cream keys, one per piece, each with the mark
--         of where it came from. Locked pieces show grey with what they need; a tap says how to
--         get it (an egg piece opens the egg card, never a surprise purchase).
--   Bottom: "Names Egg · 8 Stars" (the egg card: the real odds, or the fixed next piece, shown
--         before any spend) and Save name (the one green primary). Back keeps the old name.
-- No typing anywhere: the server stores piece ids; the text comes from NameCatalog.
local GuiService=game:GetService("GuiService")
local HttpService=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Names=require(Shared.NameCatalog)
local Stats=require(Shared.StatCatalog)
local Pets=require(Shared.PetCatalog)
local UICopy=require(Shared.UICopy)
local OddsText=require(Shared.OddsText)
local Kit=require(script.Parent.DeckKit)
local Hub=require(script.Parent.CompanionsHub)
local StatsPanel=require(script.Parent.StatsPanel)
local NameText=require(script.Parent.PetNameText)
local Screen={}
Screen.__index=Screen
Screen.Tabs=table.freeze({"all","starter","egg","stat","book"})
Screen.Pink=Color3.fromHex("#FF86C8")
Screen.Locked=Color3.fromHex("#BDB7D6")

-- ── Pure rules (scripts/NameScreen.spec.lua) ────────────────────────────────
function Screen.ownedSet(names)return Names.ownedSet(type(names)=="table"and names.owned or nil)end
-- Which tab a piece sits on ("stat" holds the keeper tiers too).
function Screen.tabOf(piece)return if piece.lane=="keeper"then "stat"else piece.lane end
-- {[tab] = {owned, total}} over the live catalogue.
function Screen.counts(names)
	local set=Screen.ownedSet(names)
	local out={}
	for _,tab in ipairs(Screen.Tabs)do out[tab]={owned=0,total=0}end
	for _,piece in ipairs(Names.Pieces)do
		if not(piece.retired and not set[piece.id])then
			local tab=Screen.tabOf(piece)
			for _,key in ipairs({"all",tab})do
				out[key].total+=1
				if set[piece.id]then out[key].owned+=1 end
			end
		end
	end
	return out
end
-- The locked line on a key ("SPEED 25", "TOTAL 60", "ANY STAT 99", "BOOK 10", "NAMES EGG").
function Screen.lockText(piece)
	if piece.lane=="stat"then return UICopy.get("names.lock.stat",{stat=string.upper(UICopy.get("stats.name."..piece.stat)),level=piece.level})end
	if piece.lane=="keeper"then
		if piece.anyLevel then return UICopy.get("names.lock.anyLevel",{level=piece.anyLevel})end
		return UICopy.get("names.lock.total",{count=piece.total})
	end
	if piece.lane=="book"then return UICopy.get("names.lock.book",{count=piece.claimed})end
	if piece.lane=="egg"then return UICopy.get("names.lock.egg")end
	return ""
end
-- How to get a locked piece (one line).
function Screen.hint(piece)
	if piece.lane=="stat"then return UICopy.get("names.hint.stat",{stat=UICopy.get("stats.name."..piece.stat),level=piece.level})end
	if piece.lane=="keeper"then
		if piece.anyLevel then return UICopy.get("names.hint.anyLevel",{level=piece.anyLevel})end
		return UICopy.get("names.hint.total",{count=piece.total})
	end
	if piece.lane=="book"then return UICopy.get("names.hint.book",{count=piece.claimed})end
	if piece.lane=="egg"then return UICopy.get("names.hint.egg")end
	return ""
end
-- The keys on a tab: owned first in catalogue order, then locked (retired and unowned: hidden).
function Screen.tiles(names,tab,slots)
	local set=Screen.ownedSet(names)
	local owned,locked={},{}
	for _,piece in ipairs(Names.Pieces)do
		if(tab=="all"or Screen.tabOf(piece)==tab)and not(piece.retired and not set[piece.id])then
			local entry={id=piece.id,text=piece.text,lane=piece.lane,stat=piece.stat,owned=set[piece.id]==true,
				slot=if slots then table.find(slots,piece.id)else nil,lock=if set[piece.id]then nil else Screen.lockText(piece)}
			table.insert(if entry.owned then owned else locked,entry)
		end
	end
	for _,entry in ipairs(locked)do table.insert(owned,entry)end
	return owned
end
-- A tap on an owned piece: in the slots → out; else into the next free slot (two full: the
-- second slot is replaced). Returns the new slots.
function Screen.toggle(slots,id)
	local out=table.clone(slots or {})
	local at=table.find(out,id)
	if at then table.remove(out,at);return out end
	if #out<Names.MaxPieces then table.insert(out,id)else out[Names.MaxPieces]=id end
	return out
end
function Screen.swap(slots)
	if #slots<2 then return table.clone(slots)end
	return {slots[2],slots[1]}
end
function Screen.same(a,b)
	a,b=a or {},b or {}
	if #a~=#b then return false end
	for i,v in ipairs(a)do if b[i]~=v then return false end end
	return true
end
-- The Names Egg card's odds block (the figures the server rolls with): random = one equal share
-- of the pool for each piece; restricted (or unknown policy) = the fixed next piece.
-- {rows={{id,name,value,label?,info?}}, per, restricted, note, empty, each}
function Screen.eggOdds(names)
	local per=UICopy.get("names.egg.per")
	if type(names)~="table"then return {rows={},per=per,empty=UICopy.get("names.egg.notReady")}end
	local remaining=names.remaining or {}
	if #remaining==0 then return {rows={},per=per,empty=UICopy.get("names.egg.all")}end
	if names.mode~="random"then
		local nextId=names.next or remaining[1]
		return {rows={{id=nextId,name=UICopy.get("names.egg.next",{piece=Names.text(nextId)or "?"}),value=UICopy.get("names.egg.nextValue")},
			{id="order",name=UICopy.get("names.egg.order"),value="",info=true}},per=per,restricted=true,note=UICopy.get("names.egg.fixedLine")}
	end
	local each,rounded=OddsText.equalShare(#remaining)
	local rows={}
	for _,id in ipairs(remaining)do table.insert(rows,{id=id,name=Names.text(id)or id,value=each})end
	table.insert(rows,{id="each",name=UICopy.get("names.egg.each",{count=#remaining,each=each}),value="",info=true})
	if rounded then table.insert(rows,{id="rounded",name=UICopy.get("hatch.odds.rounded"),value="",info=true})end
	return {rows=rows,per=per,note=UICopy.get("names.egg.randomLine"),each=each,rounded=rounded==true}
end
-- The egg card's button: {text, enabled, need}.
function Screen.eggAction(names,wallet)
	if type(names)~="table"then return {text=UICopy.get("names.egg.notReady"),enabled=false}end
	if #(names.remaining or {})==0 then return {text=UICopy.get("names.egg.all"),enabled=false}end
	local price=names.price or Names.Price
	if(wallet or 0)<price then return {text=UICopy.get("qa.shortfall",{count=price-(wallet or 0)}),enabled=false,need=price-(wallet or 0)}end
	return {text=UICopy.get("names.egg.buy",{price=price}),enabled=true}
end
function Screen.reasonText(reason)
	local key="names.reason."..tostring(reason)
	return if UICopy.has(key)then UICopy.get(key)else UICopy.get("names.reason.default")
end

-- ── The panel ────────────────────────────────────────────────────────────────
-- host: a full-screen Frame. callbacks: appearance(petId), back(from), closed(reason, from),
-- save(petId, ids) -> opId|nil, buyEgg(quoteKey) -> opId|nil.
function Screen.new(host,callbacks)
	local self=setmetatable({host=host,callbacks=callbacks or {},visible=false,ctx={wallet=0,state={}},slots={},tab="all",index=1},Screen)
	self.shade=Kit.modalShade(host,"NamesShade",30)
	local root=Kit.frame(host,"NamePanel","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),30)
	root.AnchorPoint=Vector2.new(.5,.5);root.Active=true;root.ClipsDescendants=true;root.ZIndex=31;root.Visible=false;self.rootStroke=Kit.stroke(root)
	self.root=root
	self.scale=Kit.node("UIScale",root,{Scale=1})
	return self
end
Screen.buildWell=Hub.buildWell
Screen.paintPreview=Hub.paintPreview
Screen.appearanceOf=Hub.appearanceOf
function Screen:names()local s=self.ctx.state;return type(s)=="table"and type(s.names)=="table"and s.names or nil end
function Screen:savedIds()return NameText.ownIds(self.ctx.state,self.petId)or {}end

local function txt(parent,role,content,color,x,y,w,h,props)
	local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
-- The mark for where a piece comes from.
function Screen.mark(parent,entry,size)
	if entry.lane=="stat"then return StatsPanel.icon(parent,entry.stat,size)end
	local icon,color
	if entry.lane=="starter"then icon,color="sparkle","go"
	elseif entry.lane=="egg"then icon,color="egg",Screen.Pink
	elseif entry.lane=="keeper"then icon,color="trophy","stars"
	else icon,color="book","accent"end
	local i=Kit.icon(parent,icon,size,"text")
	Kit.tintIcon(i,color)
	return i
end

function Screen:geometry(view)
	if view then
		local W,H=view.W,view.H
		local leftW=if W>=760 then 176 else 150
		local rx=20+leftW+12
		local rw=W-20-rx
		return {phone=true,W=W,H=H,left={x=20,y=64,w=leftW,h=H-84},rx=rx,rw=rw,trayY=64,trayH=52,tabsY=124,tabsH=36,
			gridY=166,gridH=H-166-66,cols=if rw>=520 then 4 else 3,keyH=40,bottomY=H-58,bottomH=40}
	end
	return {phone=false,W=848,H=608,left={x=24,y=84,w=272,h=452},rx=312,rw=512,trayY=84,trayH=84,tabsY=180,tabsH=40,
		gridY=232,gridH=244,cols=3,keyH=50,bottomY=488,bottomH=48}
end

-- The waiting-slot pulses loop forever: stop them before their strokes go.
function Screen:stopPulses()
	for _,s in ipairs(self.slotKeys or {})do if s.pulse then s.pulse:Cancel();s.pulse=nil end end
end
function Screen:build(view)
	self:stopPulses()
	if self.content then self.content:Destroy()end
	if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
	if self.visual then self.visual:destroy();self.visual=nil end
	self.world=nil
	self.view=view;self.key=if view then string.format("%dx%d",view.W,view.H)else "regular"
	local root=self.root;local phone=view~=nil
	root.BackgroundTransparency=if phone then 1 else 0;self.rootStroke.Enabled=not phone;root.ClipsDescendants=not phone
	Kit.setShadeAlpha(self.shade,Kit.ShadeAlpha)
	local g=self:geometry(view);self.g=g
	local content=Kit.frame(root,"Content",nil,UDim2.new(),UDim2.fromOffset(g.W,g.H));content.ZIndex=root.ZIndex+2
	self.content=content
	Kit.halftone(content,"companions",phone)
	local body=content
	if phone then
		local sheet=Kit.sheet(content,g.W,g.H)
		body=Kit.frame(content,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
	end
	self.body=body
	self.header=Kit.header(body,{title=UICopy.get("names.title",{pet=NameText.species(self.petId)}),eyebrow=UICopy.get("names.eyebrow"),tint="companions",
		compact=phone,width=g.W,left=if phone then view.hx else 24,onBack=function()self:back()end})
	self.header.root.Name="NamesHeader"
	if self.header.wallet then self.header.wallet.set(self.ctx.wallet or 0)end
	self:buildLeft(body,g)
	self:buildSlots(body,g)
	self:buildTabs(body,g)
	self:buildGrid(body,g)
	self:buildBottom(body,g)
	self:buildEggCard(body,g)
	self.ring=Kit.focusRing(self.root)
	self:paint()
end

function Screen:buildLeft(body,g)
	local L=g.left
	local pane=Kit.card(body,"PetPane",nil,{pad=12,seam=not g.phone})
	pane.Position=UDim2.fromOffset(L.x,L.y);pane.Size=UDim2.fromOffset(L.w,L.h)
	local pad=if g.phone then 10 else 16
	local wellH=if g.phone then math.max(80,L.h-pad*2-(if L.h>200 then 64 else 0))else 300
	local well=self:buildWell(pane,pad,pad,L.w-pad*2,wellH)
	self.previewWell=well
	-- The tag as it floats over the pet.
	local tag=Kit.frame(well,"NameTag","cream",UDim2.new(.5,0,0,8),UDim2.fromOffset(120,if g.phone then 26 else 32),999)
	tag.AnchorPoint=Vector2.new(.5,0);tag.BackgroundTransparency=0;Kit.stroke(tag,Kit.Color.ink,2);tag.ZIndex=well.ZIndex+6
	Kit.setSurface(tag,"light")
	self.tagLabel=Kit.text(tag,"Strong","",Kit.Color.ink,{Name="TagText",Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,
		TextSize=if g.phone then 14 else 18,AutoLocalize=false})
	self.tagLabel.ZIndex=tag.ZIndex+1
	self.tag=tag
	local chip=Kit.chip(well,string.upper(NameText.species(self.petId)),nil,if g.phone then 22 else 26)
	chip.root.AnchorPoint=Vector2.new(.5,1);chip.root.Position=UDim2.new(.5,0,1,-8);chip.root.ZIndex=well.ZIndex+6;chip.label.ZIndex=chip.root.ZIndex+1
	chip.label.AutoLocalize=false
	self.speciesChip=chip
	if not g.phone or L.h>200 then
		local y=pad+wellH+(if g.phone then 6 else 14)
		txt(pane,"Label",UICopy.get("names.shows.title"),"dim",pad,y,L.w-pad*2,16,{TextSize=if g.phone then 11 else 13})
		txt(pane,"Body",UICopy.get("names.shows.where"),"text",pad,y+18,L.w-pad*2,if g.phone then 32 else 44,
			{TextWrapped=true,TextSize=if g.phone then 12 else 15,TextYAlignment=Enum.TextYAlignment.Top})
		if not g.phone then
			txt(pane,"Small",UICopy.get("names.shows.own"),"soft",pad,y+68,L.w-pad*2,20,{TextSize=13})
		end
	end
end

-- A slot: a key that shows the piece (lemon) or "Pick a piece" (cream, empty).
function Screen:buildSlots(body,g)
	local tray=Kit.frame(body,"SlotTray","shellLip",UDim2.fromOffset(g.rx,g.trayY),UDim2.fromOffset(g.rw,g.trayH),14)
	Kit.stroke(tray);Kit.setSurface(tray,"dark");Kit.sink(tray,4)
	local h=if g.phone then 40 else 48
	local swapW=if g.phone then 64 else 76
	local clearW=if g.phone then 64 else 80
	local gap=if g.phone then 6 else 8
	local slotW=math.floor((g.rw-16-swapW-clearW-gap*3)/2)
	self.slotKeys={}
	local x=8
	for i=1,2 do
		local key,state=Kit.tile(tray,"Slot"..i,{selectable=false,radius=12,compact=g.phone,position=UDim2.fromOffset(x,6),size=UDim2.fromOffset(slotW,h)})
		local label=Kit.text(key,"Strong","","text",{Name="Piece",Position=UDim2.fromOffset(if g.phone then 32 else 40,0),Size=UDim2.new(1,-(if g.phone then 62 else 76),1,0),
			TextSize=if g.phone then 15 else 18,AutoLocalize=false,TextTruncate=Enum.TextTruncate.AtEnd})
		local number=Kit.frame(key,"Number","ink",UDim2.new(1,-(if g.phone then 26 else 32),.5,-(if g.phone then 10 else 12)),UDim2.fromOffset(if g.phone then 20 else 24,if g.phone then 20 else 24),999)
		number.BackgroundTransparency=0;Kit.setSurface(number,"dark")
		Kit.text(number,"Counter",tostring(i),"text",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=13})
		key.Activated:Connect(function()self:tapSlot(i)end)
		-- Spencer 2026-11-20: show which slot the next piece goes into. A lemon ring around the
		-- slot waiting for a pick (pulsing; still under Reduced Motion).
		local ring=Kit.frame(tray,"Pending"..i,nil,UDim2.fromOffset(x-4,2),UDim2.fromOffset(slotW+8,h+8),14)
		ring.BackgroundTransparency=1;ring.ZIndex=key.ZIndex+6;ring.Visible=false
		local ringStroke=Kit.node("UIStroke",ring,{Name="Ring",Thickness=3,Color=Kit.color("selected"),ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		self.slotKeys[i]={key=key,state=state,label=label,number=number,ring=ring,ringStroke=ringStroke}
		x+=slotW+gap
		if i==1 then
			local swap=Kit.button(tray,"Swap",{text=UICopy.get("names.swap"),size=Vector2.new(swapW,h),textSize=if g.phone then 14 else 16,selectable=false})
			swap.Position=UDim2.fromOffset(x,6);swap.Activated:Connect(function()self:swapSlots()end)
			self.swapButton=swap
			x+=swapW+gap
		end
	end
	local clear=Kit.button(tray,"Clear",{text=UICopy.get("names.clear"),size=Vector2.new(clearW,h),textSize=if g.phone then 14 else 16,selectable=false})
	clear.Position=UDim2.fromOffset(x,6);clear.Activated:Connect(function()self:clear()end)
	self.clearButton=clear
	if not g.phone then
		self.trayHint=txt(tray,"Small",UICopy.get("names.slots.hint"),"soft",12,6+h+6,g.rw-24,20,{Name="Hint",TextSize=13})
	end
end

function Screen:buildTabs(body,g)
	local labels={}
	for _,tab in ipairs(Screen.Tabs)do table.insert(labels,UICopy.get("names.tab."..tab))end
	local tabs=Kit.tabs(body,labels,g.rw,g.tabsH,if g.phone then 13 else 15)
	tabs.root.Position=UDim2.fromOffset(g.rx,g.tabsY);tabs.root.Name="NameTabs"
	tabs.changed=function(index)self:setTab(Screen.Tabs[index])end
	self.tabs=tabs
end

function Screen:buildGrid(body,g)
	local scroll=Kit.node("ScrollingFrame",body,{Name="PieceGrid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(g.rx,g.gridY),
		Size=UDim2.fromOffset(g.rw,g.gridH),ScrollBarThickness=6,ScrollingDirection=Enum.ScrollingDirection.Y,CanvasSize=UDim2.new(),
		AutomaticCanvasSize=Enum.AutomaticSize.None,ZIndex=body.ZIndex+1,ScrollBarImageColor3=Kit.Color.cream,Selectable=false})
	self.grid=scroll
	-- A rebuilt screen (reopen, resize) has a new, empty grid: forget the old signature, or
	-- paintGrid skips the rebuild and indexes keys that do not exist (Spencer 2026-11-20: the
	-- second open stopped before the pet preview was drawn).
	self.keys={};self.gridSignature=nil
end

function Screen:buildBottom(body,g)
	local eggW=if g.phone then 170 else 220
	local egg=Kit.button(body,"NamesEggKey",{text=UICopy.get("names.egg.key",{price=Names.Price}),size=Vector2.new(eggW,g.bottomH),textSize=if g.phone then 15 else 17,selectable=false})
	egg.Position=UDim2.fromOffset(g.rx,g.bottomY);egg.Activated:Connect(function()self:openEgg()end)
	self.eggKey=egg
	local saveW=if g.phone then 150 else 200
	local save=Kit.button(body,"SaveName",{variant="primary",text=UICopy.get("names.save"),size=Vector2.new(saveW,g.bottomH),textSize=if g.phone then 16 else 18,selectable=false})
	save.Position=UDim2.fromOffset(g.rx+g.rw-saveW,g.bottomY);save.Activated:Connect(function()self:save()end)
	self.saveButton=save
	local statusW=g.rw-eggW-saveW-24
	self.status=txt(body,"Small","","soft",g.rx+eggW+12,g.bottomY,statusW,g.bottomH,
		{Name="Status",TextWrapped=true,TextSize=if g.phone then 12 else 14,TextXAlignment=Enum.TextXAlignment.Center})
	if not g.phone then
		txt(body,"Strong",UICopy.get("names.footer.free"),"text",24,552,520,22,{Name="FooterFree",TextSize=15})
		txt(body,"Small",UICopy.get("names.footer.account"),"soft",24,574,520,20,{Name="FooterAccount",TextSize=13})
	end
end

-- The Names Egg card: over the right column, before any spend.
function Screen:buildEggCard(body,g)
	local card=Kit.card(body,"NamesEggCard",nil,{pad=16,role="raised"})
	local w=math.min(g.rw,if g.phone then g.rw else 512)
	local top=g.trayY
	local h=(g.bottomY+g.bottomH)-top
	card.Position=UDim2.fromOffset(g.rx+g.rw-w,top);card.Size=UDim2.fromOffset(w,h);card.ZIndex=body.ZIndex+20;card.Visible=false
	local pad=if g.phone then 10 else 16
	local title=txt(card,"Heading",UICopy.get("names.egg.title"),"text",pad,pad-2,w-pad*2-50,if g.phone then 24 else 30,{TextSize=if g.phone then 18 else 22})
	local _=title
	local close=Kit.button(card,"CloseEgg",{text=UICopy.get("names.egg.close"),size=Vector2.new(if g.phone then 70 else 90,if g.phone then 32 else 36),textSize=14,selectable=false})
	close.AnchorPoint=Vector2.new(1,0);close.Position=UDim2.new(1,-pad,0,pad-4);close.Activated:Connect(function()self:closeEgg()end)
	local lineY=pad+(if g.phone then 24 else 32)
	self.eggLine=txt(card,"Small",UICopy.get("names.egg.line"),"soft",pad,lineY,w-pad*2,18,{TextSize=if g.phone then 12 else 14})
	local listY=lineY+22
	local buyH=if g.phone then 40 else 48
	local list=Kit.node("ScrollingFrame",card,{Name="Odds",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(pad,listY),
		Size=UDim2.fromOffset(w-pad*2,h-listY-buyH-pad*2-18),ScrollBarThickness=6,CanvasSize=UDim2.new(),ZIndex=card.ZIndex+1,Selectable=false})
	self.eggList=list
	self.eggNote=txt(card,"Small","","dim",pad,h-buyH-pad-22,w-pad*2,18,{Name="Note",TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
	local buy=Kit.button(card,"BuyNameEgg",{variant="primary",text="",size=Vector2.new(w-pad*2,buyH),textSize=if g.phone then 16 else 18,selectable=false})
	buy.Position=UDim2.fromOffset(pad,h-buyH-pad);buy.Activated:Connect(function()self:buyEgg()end)
	self.eggBuy=buy
	self.eggCard=card
end
function Screen:paintEgg()
	if not self.eggCard then return end
	local names=self:names()
	local odds=Screen.eggOdds(names)
	for _,child in ipairs(self.eggList:GetChildren())do if child:IsA("GuiObject")then child:Destroy()end end
	local w=self.eggList.AbsoluteSize.X>0 and self.eggList.Size.X.Offset or 300
	local y=0
	local rowH=if self.g.phone then 26 else 30
	if odds.empty then
		txt(self.eggList,"Body",odds.empty,"text",0,0,w-10,rowH,{TextSize=15})
		y=rowH
	end
	for _,row in ipairs(odds.rows)do
		local line=Kit.frame(self.eggList,"Row_"..row.id,if row.info then nil else "cream",UDim2.fromOffset(0,y),UDim2.fromOffset(w-10,rowH-4),8)
		if not row.info then line.BackgroundTransparency=0;Kit.stroke(line,Kit.Color.ink,1);Kit.setSurface(line,"light")end
		local name=Kit.text(line,if row.info then "Small"else "Strong",row.name,if row.info then "soft"else "text",{Name="Name",Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-90,1,0),
			TextSize=if row.info then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd,TextWrapped=row.info==true})
		-- Piece names are proper names; the info lines translate.
		name.AutoLocalize=row.info==true or odds.restricted==true
		if row.value~=""then
			Kit.text(line,"Counter",row.value,"text",{Name="Value",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,0),Size=UDim2.fromOffset(80,rowH-4),
				TextXAlignment=Enum.TextXAlignment.Right,TextSize=13})
		end
		y+=rowH
	end
	self.eggList.CanvasSize=UDim2.fromOffset(0,y)
	self.eggNote.Text=odds.note or odds.per or ""
	local action=Screen.eggAction(names,self.ctx.wallet)
	if self.pendingEgg then action={text=UICopy.get("names.egg.hatching"),enabled=false}
	elseif self.retryEgg then action={text=UICopy.get("names.egg.retry"),enabled=true}end
	Kit.setText(self.eggBuy,action.text);Kit.setEnabled(self.eggBuy,action.enabled)
	Kit.setTappable(self.eggBuy,action.need~=nil and not self.pendingEgg and not self.retryEgg)
end

function Screen:setTab(tab)
	if not table.find(Screen.Tabs,tab)then tab="all"end
	self.tab=tab;self.index=1
	if self.tabs then self.tabs.select(table.find(Screen.Tabs,tab))end
	self:paintGrid(true)
end
function Screen:paintGrid(rebuild)
	if not self.grid then return end
	local g=self.g
	local entries=Screen.tiles(self:names(),self.tab,self.slots)
	self.entries=entries
	-- Rebuilt when the tab or any key's id / ownership changes (a hatched or earned piece unlocks).
	local parts={}
	for _,entry in ipairs(entries)do table.insert(parts,entry.id..(if entry.owned then "1"else "0"))end
	local signature=self.tab..":"..table.concat(parts,",")
	if rebuild or signature~=self.gridSignature then
		self.gridSignature=signature
		for _,k in ipairs(self.keys)do k.key:Destroy()end
		self.keys={}
		local gap=8
		local colW=math.floor((g.rw-8-gap*(g.cols-1))/g.cols)
		for i,entry in ipairs(entries)do
			local col,row=(i-1)%g.cols,math.floor((i-1)/g.cols)
			local key,state=Kit.tile(self.grid,"Piece_"..entry.id,{selectable=false,radius=12,compact=g.phone,
				position=UDim2.fromOffset(col*(colW+gap),row*(g.keyH+gap)),size=UDim2.fromOffset(colW,g.keyH)})
			local markSize=if g.phone then 20 else 26
			local mark=Screen.mark(key,entry,markSize);mark.AnchorPoint=Vector2.new(0,.5);mark.Position=UDim2.new(0,if g.phone then 8 else 10,.5,0)
			local tx=(if g.phone then 8 else 10)+markSize+6
			local label=Kit.text(key,"Strong",entry.text,"text",{Name="Piece",Position=UDim2.fromOffset(tx,if entry.lock then 2 else 0),
				Size=UDim2.new(1,-tx-34,if entry.lock then .6 else 1,0),TextSize=if g.phone then 14 else 17,AutoLocalize=false,TextTruncate=Enum.TextTruncate.AtEnd})
			local lock
			if entry.lock then
				lock=Kit.text(key,"Counter",entry.lock,"text",{Name="Lock",Position=UDim2.new(0,tx,.55,0),Size=UDim2.new(1,-tx-6,.4,0),TextSize=if g.phone then 10 else 11,
					TextTruncate=Enum.TextTruncate.AtEnd,AutoLocalize=true})
			end
			local number=Kit.frame(key,"Number","ink",UDim2.new(1,-(if g.phone then 24 else 30),.5,-(if g.phone then 9 else 11)),UDim2.fromOffset(if g.phone then 18 else 22,if g.phone then 18 else 22),999)
			number.BackgroundTransparency=0;Kit.setSurface(number,"dark")
			local n=Kit.text(number,"Counter","","text",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=12})
			key:SetAttribute("PieceId",entry.id)
			key.Activated:Connect(function()self:tapPiece(entry.id,i)end)
			self.keys[i]={key=key,state=state,label=label,lock=lock,number=number,numberText=n,mark=mark}
		end
		local rows=math.ceil(#entries/g.cols)
		self.grid.CanvasSize=UDim2.fromOffset(0,rows*(g.keyH+gap))
	end
	for i,entry in ipairs(entries)do
		local k=self.keys[i]
		local slot=table.find(self.slots,entry.id)
		k.state.setSelected(slot~=nil)
		if not entry.owned then
			k.key.BackgroundColor3=Screen.Locked
			k.label.TextTransparency=.25;if k.lock then k.lock.TextTransparency=.15 end
		end
		k.number.Visible=slot~=nil;k.numberText.Text=if slot then tostring(slot)else ""
		k.key:SetAttribute("Owned",entry.owned);k.key:SetAttribute("Slot",slot or 0)
		k.key:SetAttribute("AccessibleLabel",entry.text..(if entry.lock then ", "..entry.lock else ""))
	end
	self:paintFocus()
end
function Screen:paintFocus()
	if not self.ring then return end
	local k=self.keys and self.keys[self.index]
	if k and Kit.lastInputGamepad()then self.ring.attach(k.key,12)else self.ring.hide()end
end
function Screen:paint()
	if not self.slotKeys then return end
	local display=Names.display(self.slots,nil)
	local species=NameText.species(self.petId)
	self.tagLabel.Text=display or species
	local tw=math.ceil(Kit.measure(self.tagLabel.Text,"Strong",self.tagLabel.TextSize).X)+28
	self.tag.Size=UDim2.fromOffset(math.min(tw,self.previewWell.Size.X.Offset-12),self.tag.Size.Y.Offset)
	local nextSlot=if #self.slots<Names.MaxPieces then #self.slots+1 else nil
	for i,s in ipairs(self.slotKeys)do
		local id=self.slots[i]
		s.state.setSelected(id~=nil)
		local waiting=i==nextSlot
		s.label.Text=if id then Names.text(id)or "?"elseif waiting then UICopy.get("names.slots.empty")else UICopy.get("names.slots.optional")
		Kit.paint(s.label,"TextColor3",if id or waiting then "text"else "soft")
		s.key:SetAttribute("Waiting",waiting)
		if s.ring then
			s.ring.Visible=waiting
			if waiting and not s.pulse and not Kit.reduced()then
				s.ringStroke.Transparency=0
				s.pulse=game:GetService("TweenService"):Create(s.ringStroke,TweenInfo.new(.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=.65})
				s.pulse:Play()
			elseif not waiting and s.pulse then s.pulse:Cancel();s.pulse=nil;s.ringStroke.Transparency=0 end
		end
		s.label.AutoLocalize=id==nil
		s.number.Visible=id~=nil
		if s.mark then s.mark:Destroy();s.mark=nil end
		if id and Names.ById[id]then
			local p=Names.ById[id]
			local m=Screen.mark(s.key,{lane=p.lane,stat=p.stat},if self.g.phone then 20 else 26)
			m.AnchorPoint=Vector2.new(0,.5);m.Position=UDim2.new(0,if self.g.phone then 8 else 10,.5,0);s.mark=m
		end
	end
	Kit.setEnabled(self.swapButton,#self.slots==2)
	Kit.setEnabled(self.clearButton,#self.slots>0)
	local changed=not Screen.same(self.slots,self:savedIds())
	Kit.setEnabled(self.saveButton,changed and not self.pendingSave)
	Kit.setText(self.saveButton,if self.pendingSave then UICopy.get("names.saving")else UICopy.get("names.save"))
	local counts=Screen.counts(self:names())
	if self.tabs then
		for i,tab in ipairs(Screen.Tabs)do
			local c=counts[tab]
			local label=self.tabs.labels[i]
			if label then label.Text=UICopy.get("names.tab."..tab).." "..c.owned.."/"..c.total end
		end
	end
	if self.header and self.header.wallet then self.header.wallet.set(self.ctx.wallet or 0)end
	local names=self:names()
	local remaining=names and names.remaining or {}
	Kit.setEnabled(self.eggKey,names~=nil)
	Kit.setText(self.eggKey,if names and #remaining==0 then UICopy.get("names.egg.allShort")else UICopy.get("names.egg.key",{price=Names.Price}))
	self.root:SetAttribute("NameText",display or "");self.root:SetAttribute("PetId",self.petId)
	self.root:SetAttribute("Slots",table.concat(self.slots,"+"))
	self:paintGrid(false)
	if self.eggCard and self.eggCard.Visible then self:paintEgg()end
end
function Screen:say(text)
	if self.status then self.status.Text=text or "" end
	self.sayAt=os.clock()
end

-- ── Actions ──────────────────────────────────────────────────────────────────
function Screen:tapPiece(id,index)
	if index then self.index=index end
	local piece=Names.ById[id];if not piece then return end
	local set=Screen.ownedSet(self:names())
	if not set[id]then
		self:say(Screen.hint(piece))
		if piece.lane=="egg"then self:openEgg()end
		return
	end
	self.slots=Screen.toggle(self.slots,id)
	self:say("")
	self:paint()
	local k=self.keys[index or 0];if k then Kit.boing(k.key)end
end
function Screen:tapSlot(i)
	if self.slots[i]then table.remove(self.slots,i);self:paint()end
end
function Screen:swapSlots()
	if #self.slots<2 then return end
	self.slots=Screen.swap(self.slots);self:paint()
end
function Screen:clear()
	if #self.slots==0 then return end
	self.slots={};self:paint()
end
function Screen:save()
	if self.pendingSave or Screen.same(self.slots,self:savedIds())then return false end
	local op=self.callbacks.save and self.callbacks.save(self.petId,table.clone(self.slots))
	if not op then return false end
	self.pendingSave=op;self:say(UICopy.get("names.saving"));self:paint()
	task.delay(12,function()if self.pendingSave==op then self.pendingSave=nil;self:say(Screen.reasonText("Timeout"));self:paint()end end)
	return true
end
function Screen:openEgg()
	if not self.eggCard then return end
	self.eggCard.Visible=true;self:paintEgg();Kit.boing(self.eggCard)
	self.root:SetAttribute("EggCard",true)
end
function Screen:closeEgg()
	if not self.eggCard then return end
	self.eggCard.Visible=false;self.root:SetAttribute("EggCard",false)
end
-- Code review: an egg whose save is still retrying keeps its op id and quote, and the next tap
-- sends the same request again, so a committed egg replays its receipt (and its reveal) instead of
-- a second purchase or a silent debit.
function Screen:buyEgg()
	local names=self:names()
	if self.pendingEgg or not names then return false end
	local retry=self.retryEgg
	local action=if retry then nil else Screen.eggAction(names,self.ctx.wallet)
	if action and not action.enabled then
		-- Stars store access: short of Stars opens the "need more Stars" card.
		if action.need then return require(script.Parent.StarsShort).ask({price=names.price or Names.Price,wallet=self.ctx.wallet,item=UICopy.get("names.egg.title"),from="names"},self)end
		return false
	end
	if not retry then self.lastOdds=Screen.eggOdds(names)end
	local quote=if retry then retry.quote else names.quoteKey
	local op=self.callbacks.buyEgg and self.callbacks.buyEgg(quote,retry and retry.op)
	if not op then return false end
	self.pendingEgg=op;self.sentQuote=quote;self:paintEgg()
	task.delay(12,function()
		if self.pendingEgg==op then
			self.pendingEgg=nil;self.retryEgg={op=op,quote=quote}
			self:say(Screen.reasonText("Timeout"));self:paintEgg()
		end
	end)
	return true
end
-- A reply from the server (NameResult).
function Screen:onResult(message)
	if type(message)~="table"then return end
	if message.action=="petName"and message.id==self.pendingSave then
		self.pendingSave=nil
		if message.status=="Saved"then self:say(UICopy.get("names.saved"))
		else self:say(Screen.reasonText(message.reason))end
		self:paint()
	elseif message.action=="nameEggBuy"and(message.id==self.pendingEgg or(self.retryEgg~=nil and message.id==self.retryEgg.op))then
		local quote=if self.retryEgg and message.id==self.retryEgg.op then self.retryEgg.quote else self.sentQuote
		self.pendingEgg=nil
		self.retryEgg=if message.status=="Retrying"then {op=message.id,quote=quote}else nil
		if message.status=="Saved"and type(message.receipt)=="table"then
			self:closeEgg()
			if self.callbacks.reveal then self.callbacks.reveal(message.receipt,self.lastOdds)end
		else
			self:say(Screen.reasonText(message.reason))
			if self.eggCard and self.eggCard.Visible then self:paintEgg()end
		end
	end
end
-- After a reveal's "Use it": the piece goes into the next free slot.
function Screen:usePiece(id)
	if not self.visible or not Names.ById[id]then return end
	if not table.find(self.slots,id)then self.slots=Screen.toggle(self.slots,id)end
	self:say("")
	self:paint()
end

function Screen:fit(size)
	if Kit.compactRule(size.X,size.Y)then
		local _,kh=Kit.keepOut();local top=kh+2
		local view={phone=true,W=math.floor(size.X),H=math.floor(size.Y)-top,hx=24}
		self.root.AnchorPoint=Vector2.zero;self.root.Position=UDim2.fromOffset(0,top);self.root.Size=UDim2.fromOffset(view.W,view.H);self.scale.Scale=1
		if self.key~=string.format("%dx%d",view.W,view.H)then self:build(view);self:paintPreview(self.petId)end
		return
	end
	self.root.AnchorPoint=Vector2.new(.5,.5);self.root.Size=UDim2.fromOffset(848,608)
	if self.key~="regular"then self:build(nil);self:paintPreview(self.petId)end
	self.root.Position=UDim2.fromScale(.5,.5)
	self.scale.Scale=math.max(.1,math.min(1.2,(size.X-24)/848,(size.Y-24)/608))
end
function Screen:setContext(ctx)
	if ctx.wallet then self.ctx.wallet=ctx.wallet end
	if ctx.state then self.ctx.state=ctx.state end
	if self.visible then self:paint()end
end
function Screen:back()
	if self.eggCard and self.eggCard.Visible then self:closeEgg();return "egg"end
	local from=self.from
	Kit.depart(self.root)
	self:close("back")
	if self.callbacks.back then self.callbacks.back(from)end
	return "close"
end
function Screen:move(dx,dy)
	local cols=self.g and self.g.cols or 3
	local n=#(self.keys or {})
	if n==0 then return end
	local i=self.index+dx+dy*cols
	if i>=1 and i<=n then self.index=i end
	self:paintFocus()
	local k=self.keys[self.index]
	if k and self.grid then
		local top=k.key.Position.Y.Offset;local h=self.grid.AbsoluteSize.Y
		local y=self.grid.CanvasPosition.Y
		if top<y then self.grid.CanvasPosition=Vector2.new(0,top)elseif top+k.key.Size.Y.Offset>y+h then self.grid.CanvasPosition=Vector2.new(0,top+k.key.Size.Y.Offset-h)end
	end
end
function Screen:input(key)
	local K=Enum.KeyCode
	if self.eggCard and self.eggCard.Visible then
		if key==K.ButtonB or key==K.Backspace or key==K.Escape then self:closeEgg()
		elseif key==K.ButtonA or key==K.Return or key==K.KeypadEnter then self:buyEgg()end
		return
	end
	if key==K.Left or key==K.A or key==K.DPadLeft then self:move(-1,0)
	elseif key==K.Right or key==K.D or key==K.DPadRight then self:move(1,0)
	elseif key==K.Up or key==K.W or key==K.DPadUp then self:move(0,-1)
	elseif key==K.Down or key==K.S or key==K.DPadDown then self:move(0,1)
	elseif key==K.ButtonL1 or key==K.Q then
		local i=table.find(Screen.Tabs,self.tab)or 1;self:setTab(Screen.Tabs[math.max(1,i-1)])
	elseif key==K.ButtonR1 or key==K.E then
		local i=table.find(Screen.Tabs,self.tab)or 1;self:setTab(Screen.Tabs[math.min(#Screen.Tabs,i+1)])
	elseif key==K.ButtonX or key==K.X then self:swapSlots()
	elseif key==K.ButtonY or key==K.Y then self:openEgg()
	elseif key==K.ButtonStart then self:save()
	elseif key==K.ButtonB or key==K.Backspace or key==K.Escape then self:back()
	elseif key==K.ButtonA or key==K.Return or key==K.KeypadEnter or key==K.Space then
		local entry=self.entries and self.entries[self.index];if entry then self:tapPiece(entry.id,self.index)end
	end
end
function Screen:isOpen()return self.visible end
-- options: petId, from ("hub" | ...), tab.
function Screen:open(ctx,options)
	options=options or {}
	if ctx then
		if ctx.wallet then self.ctx.wallet=ctx.wallet end
		if ctx.state then self.ctx.state=ctx.state end
	end
	self.petId=options.petId or Hub.firstOwned(self.ctx.state)
	if not self.petId then return false end
	self.from=options.from
	self.slots=table.clone(self:savedIds())
	self.tab=options.tab or "all";self.index=1
	self.pendingSave=nil
	self.visible=true;self.root.Visible=true;self.key=nil
	Kit.shadeOpen(self,self.shade,function(covered)if self.visible then self.root.Visible=not covered end end)
	self:fit(self.host.AbsoluteSize)
	self:setTab(self.tab)
	self:say("")
	self:paint()
	self:paintPreview(self.petId)
	if options.slideFrom and self.body then Kit.slideIn(self.body,options.slideFrom,Kit.headerSkip(self.header))
	elseif self.view and not Kit.reduced()then
		-- Beta 14 B1: a phone rises from its fitted spot (rise only); springs off: nothing, as before.
		Kit.arrive(self.root,self.root.Position)
	elseif not self.view and not Kit.reduced()then
		if not Kit.arrive(self.root)then self.root.Position=UDim2.new(.5,0,.5,8);Kit.tween(self.root,Kit.Motion.screen,{Position=UDim2.fromScale(.5,.5)}) end
	end
	if self.clock then self.clock:Disconnect()end
	self.clock=RunService.RenderStepped:Connect(function(dt)
		if not self.visible then return end
		local v=self.visual
		if v and not v.destroyed and not GuiService.ReducedMotionEnabled then v.cosmeticTime=os.clock();v:update(math.min(dt,.1))end
	end)
	self.sizeConnection=self.sizeConnection or self.host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self.visible then self:fit(self.host.AbsoluteSize)end
	end)
	return true
end
function Screen:close(reason)
	if not self.visible then return false end
	require(script.Parent.ConfirmDialog).cancelFor(self) -- a "need more Stars" card this screen raised
	self.visible=false;self.root.Visible=false;Kit.shadeClose(self);if self.ring then self.ring.hide()end
	self:stopPulses()
	self:closeEgg()
	if self.clock then self.clock:Disconnect();self.clock=nil end
	if self.visual then self.visual:destroy();self.visual=nil end
	if self.callbacks.closed then self.callbacks.closed(reason,self.from)end
	return true
end
function Screen:destroy()self:close("destroy");if self.sizeConnection then self.sizeConnection:Disconnect()end;self.root:Destroy();self.shade:Destroy()end

-- ── Host: own ScreenGui, the remote and the reveal (init.client.lua mounts it) ────
-- deps: parent (PlayerGui), insetProbe, remotes, audio, state() -> nursery snapshot,
--   appearance(petId), canOpen(), prepare(), reopenHub(), closed(reason, from), notify(text).
function Screen.mount(deps)
	local ContextActionService=game:GetService("ContextActionService")
	local UserInputService=game:GetService("UserInputService")
	local Reveal=require(script.Parent.NameEggReveal)
	local gui=Instance.new("ScreenGui")
	gui.Name="EggDropNames";gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=13
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ClipToDeviceSafeArea=false;gui.Parent=deps.parent
	local host=Instance.new("Frame");host.Name="NamesHost";host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui
	local function syncInsets()
		local wanted=Kit.compactInsets(deps.insetProbe.AbsoluteSize)
		if gui.ScreenInsets~=wanted then gui.ScreenInsets=wanted end
	end
	local connections={deps.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncInsets)}
	local request=deps.remotes:WaitForChild("HatchRequest")
	local function context()
		local state=deps.state()
		return {wallet=state and state.nectar or 0,state=state or {}}
	end
	local api={}
	local reveal=Reveal.new(deps.parent,deps.audio)
	api.reveal=reveal
	local screen
	local function buy(quoteKey,retryOp)
		if type(quoteKey)~="string"then return nil end
		local op=if type(retryOp)=="string"then retryOp else HttpService:GenerateGUID(false)
		request:FireServer("nameEggBuy",{id=op,quote=quoteKey})
		return op
	end
	local function showReveal(receipt,odds)
		-- The won piece leads the tray, so its lemon cell is always shown (the tray keeps 8 cells).
		if type(odds)=="table"and type(odds.rows)=="table"then
			local rows=table.clone(odds.rows)
			for i,row in ipairs(rows)do if row.id==receipt.piece then table.remove(rows,i);table.insert(rows,1,row);break end end
			odds=table.clone(odds);odds.rows=rows
		end
		reveal:show(receipt,{
			odds=function()return odds end,
			pity=function()
				local names=context().state.names
				local left=type(names)=="table"and #(names.remaining or {})or 0
				return {line=UICopy.get("names.egg.left",{count=left}),sub=UICopy.get("names.reveal.yours")}
			end,
			again=function()
				local c=context();local names=c.state.names
				local action=Screen.eggAction(names,c.wallet)
				return {text=UICopy.get("names.egg.again",{price=Names.Price}),enabled=action.enabled and screen.pendingEgg==nil,reason=if action.enabled then nil else action.text,
					pending=screen.pendingEgg~=nil,act=function()return screen:buyEgg()end}
			end},
			{use=function(r)screen:usePiece(r.piece)end,done=function()end})
	end
	screen=Screen.new(host,{
		appearance=function(petId)return deps.appearance(petId)end,
		back=function(from)if from=="hub"and deps.reopenHub then deps.reopenHub()end end,
		closed=function(reason,from)if deps.closed then deps.closed(reason,from)end end,
		save=function(petId,ids)
			local op=HttpService:GenerateGUID(false)
			request:FireServer("petName",{id=op,petId=petId,pieces=ids})
			return op
		end,
		buyEgg=buy,
		reveal=showReveal})
	api.screen=screen
	table.insert(connections,deps.remotes:WaitForChild("NameResult").OnClientEvent:Connect(function(message)screen:onResult(message)end))
	function api.open(options)
		if screen:isOpen()or not deps.state()or not deps.canOpen()then return false end
		deps.prepare()
		if GuiService.SelectedObject then GuiService.SelectedObject=nil end
		syncInsets()
		return screen:open(context(),options)
	end
	function api.isOpen()return screen:isOpen()or reveal:isOpen()end
	-- The store route reopens this screen as it was (nil while only the reveal shows).
	function api.current()return if screen:isOpen()then{petId=screen.petId,from=if screen.from=="hub"then "hub"else nil,tab=screen.tab}else nil end
	function api.close(reason)reveal:close(reason or "close");return screen:close(reason or "close")end
	-- New pieces since the last snapshot (earned ones too): one rail line each.
	local known
	function api.sync(state)
		if type(state)~="table"then return end
		local names=state.names
		if type(names)=="table"and type(names.owned)=="table"then
			local set=Names.ownedSet(names.owned)
			if known then
				for _,piece in ipairs(Names.Pieces)do
					if set[piece.id]and not known[piece.id]and piece.lane~="starter"and piece.lane~="egg"and deps.notify then
						deps.notify(UICopy.get("names.unlocked",{piece=piece.text}))
					end
				end
			end
			known=set
		end
		if screen:isOpen()then screen:setContext(context())end
	end
	local K=Enum.KeyCode
	local keys={K.Left,K.Right,K.Up,K.Down,K.A,K.D,K.W,K.S,K.Q,K.E,K.X,K.Y,K.ButtonX,K.ButtonY,K.ButtonL1,K.ButtonR1,K.DPadLeft,K.DPadRight,K.DPadUp,K.DPadDown,
		K.Space,K.Return,K.KeypadEnter,K.ButtonA,K.ButtonB,K.Backspace,K.Escape,K.ButtonStart}
	ContextActionService:BindActionAtPriority("EggDropNames",function(_,state,input)
		if not screen:isOpen()or reveal:isOpen()or UserInputService:GetFocusedTextBox()or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
		if state==Enum.UserInputState.Begin then screen:input(input.KeyCode)end
		return Enum.ContextActionResult.Sink
	end,false,Enum.ContextActionPriority.High.Value+806,table.unpack(keys))
	syncInsets()
	function api.destroy()
		ContextActionService:UnbindAction("EggDropNames")
		for _,c in ipairs(connections)do c:Disconnect()end
		reveal:destroy();screen:destroy();gui:Destroy()
	end
	return api
end

return Screen
