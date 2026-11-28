-- The Things to do page (V3-THINGS-TO-DO-PLAN-2026-11-22), inside the Pocket menu (MachineHub): a row per game that is
-- open now, with how it stands and one button: Play (the Pocket Deck) or Show me (ThingsTrail), and a ? where the game has
-- How it works cards. The rows are read again every Refresh seconds while the page shows. MachineHub owns the header,
-- Back and the focus ring; this owns the rows and which of their buttons has the focus.
-- options: {W, H, phone, ring, things = {on(), context(), act(id), help(id), seen(id)}, shown() -> bool, gone()}
local RunService=game:GetService("RunService")
local Kit=require(script.Parent.DeckKit)
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Page={};Page.__index=Page
Page.Refresh=.5
Page.Hit=44

-- ── Beta 44 learn rows (ONBOARD-SIMPLIFY-BRIEF 4; ARCH-REVIEW-SIMPLIFY 9: ticked from a latch or a saved fact) ──────────
Page.LearnOrder=table.freeze({"customize","dress","quests","book","style"})
Page.Learn=table.freeze({
	customize=table.freeze({icon="drop",tint="companions",button="things.show"}),
	dress=table.freeze({icon="shirt",tint="companions",button="things.show"}),
	quests=table.freeze({icon="quests",tint="quests",button="things.open"}),
	book=table.freeze({icon="book",tint="book",button="things.open"}),
	style=table.freeze({icon="faceplate",tint="style",button="things.open"}),
})
-- Pure: what each learn row says and whether it is ticked, from the owner snapshot. live = {teachMask (this session's
-- latches), coachMask (the coach's, with bits sent this session)}.
--   customize  the `dress` latch (lesson A), or paint on a pet, or a pot used
--   dress      a wearable saved as equipped on a pet (the `wardrobe` latch is client-only and refused after `done`)
--   quests     the `questDone` coach bit, or a quest claim saved; the line counts today's dailies
--   book       the `book` coach bit (its first visit); the line is the book's found percent
--   style      the `style` coach bit (its first visit); the line counts the plates owned
function Page.learn(state,live)
	state=type(state)=="table"and state or {}
	live=live or {}
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Teach=require(Shared.TeachMarks)
	local Coach=require(Shared.CoachMarks)
	local teach=Teach.merge(state.teachMask,live.teachMask)
	local coach=Coach.merge(state.coachMask,live.coachMask)
	local dressed=false
	for _,row in pairs(type(state.petWearables)=="table"and state.petWearables or {})do
		if type(row)=="table"and type(row.equipped)=="table"then
			for _,item in pairs(row.equipped)do if type(item)=="string"and item~=""then dressed=true end end
		end
	end
	local done,total=0,0
	local quests=type(state.quests)=="table"and state.quests or {}
	for _,q in ipairs(type(quests.daily)=="table"and quests.daily or {})do
		if type(q)=="table"then total+=1;if q.ready==true or q.claimed==true then done+=1 end end
	end
	local percent=0
	local okBook,progress=pcall(function()return require(Shared.BookCatalog).progress(state)end)
	if okBook and type(progress)=="table"and type(progress.pages)=="table"and #progress.pages>0 then
		local sum=0
		for _,page in ipairs(progress.pages)do sum+=tonumber(page.percent)or 0 end
		percent=math.floor(sum/#progress.pages+.5)
	end
	local owned,styles=0,0
	local okThemes,Themes=pcall(function()return require(Shared.DeckThemes)end)
	if okThemes then
		local plates=type(state.faceplates)=="table"and state.faceplates or {}
		local all=Themes.listed(plates)
		for _,id in ipairs(Themes.BookOnly or {})do table.insert(all,id)end
		styles=#all
		for _,id in ipairs(all)do if table.find(plates,id)then owned+=1 end end
	end
	return{
		customize={done=Teach.has(teach,"dress")or Teach.painted(state)or Teach.potUsed(state)},
		dress={done=dressed},
		quests={done=Coach.has(coach,"questDone")or state.lastQuestClaim~=nil,count=done,total=total},
		book={done=Coach.has(coach,"book"),percent=percent},
		style={done=Coach.has(coach,"style"),owned=owned,total=styles},
	}
end
-- Pure: the learn rows from Page.learn's facts (nil: none), the undone first, each keeping its order.
function Page.learnRows(learn)
	if type(learn)~="table"then return {}end
	local undone,done={},{}
	for _,id in ipairs(Page.LearnOrder)do
		local f=learn[id]
		if type(f)=="table"then
			local spec=Page.Learn[id]
			local line=if id=="quests"then UICopy.get("things.quests.line",{done=f.count or 0,total=f.total or 0})
				elseif id=="book"then UICopy.get("things.book.line",{percent=f.percent or 0})
				elseif id=="style"then UICopy.get("things.style.line",{owned=f.owned or 0,total=f.total or 0})
				else UICopy.get("things."..id..".line")
			local row={id=id,icon=spec.icon,tint=spec.tint,name=UICopy.get("things."..id..".name"),line=line,button=UICopy.get(spec.button),tick=f.done==true}
			table.insert(if f.done==true then done else undone,row)
		end
	end
	for _,row in ipairs(done)do table.insert(undone,row)end
	return undone
end
-- Pure: the rows, in order. ctx: {den (the Play Den is open), park, playDate={count,target}, finds={waiting,count,limit}, dash={phase,count}, prizes,
-- saved={paid,limit}, new}. Nothing here says Stars unless the race prizes are on. The race stays the last row: paint()
-- marks it seen only there.
function Page.rows(ctx)
	ctx=type(ctx)=="table"and ctx or {}
	local rows={}
	-- The gift chain (GiftChain, Onboard "gifts"): a gift waiting at the egg machine is the top row; Show me starts it.
	if ctx.gift=="paint"or ctx.gift=="toy"or ctx.gift=="snack"then
		table.insert(rows,{id="gift",icon="target",tint="garden",name=UICopy.get("onbGift.row.name"),
			line=UICopy.get(if ctx.gift=="snack"then "onbGift.row.lineSnack"else "onbGift.row.line"),button=UICopy.get("things.show"),new=true})
	end
	-- The Play Den row is gone for now (beta 44 note 24: "we can remove the play den from things to do for now").
	table.insert(rows,{id="deck",icon="faceplate",tint="style",name=UICopy.get("things.deck.name"),line=UICopy.get("things.deck.line"),button=UICopy.get("things.play")})
	-- Beta 44 (ONBOARD-SIMPLIFY-BRIEF 4, notes 13 and 14): the learn rows, each with its tick; the done ones drop below the
	-- undone ones and keep their button. Only with Onboard `teach` (ctx.learn from Page.learn).
	for _,row in ipairs(Page.learnRows(ctx.learn))do table.insert(rows,row)end
	if ctx.park then
		local date=type(ctx.playDate)=="table"and ctx.playDate or {}
		local target=tonumber(date.target)or 3
		table.insert(rows,{id="park",icon="paw",tint="companions",name=UICopy.get("park.name"),help="park",
			line=UICopy.get("park.playDate",{count=math.clamp(tonumber(date.count)or 0,0,target),target=target}),button=UICopy.get("things.show")})
	end
	local finds=ctx.finds
	if type(finds)=="table"then
		local waiting=math.max(0,math.floor(tonumber(finds.waiting)or 0))
		local limit=tonumber(finds.limit)
		local line=if waiting==1 then UICopy.get("things.finds.one")
			elseif waiting>0 then UICopy.get("things.finds.waiting",{count=waiting})
			elseif limit and(tonumber(finds.count)or 0)>=limit then UICopy.get("things.finds.done")
			else UICopy.get("things.finds.later")
		-- Studio check: with nothing waiting Show me has nowhere to go, so it is dimmed (and A does nothing).
		table.insert(rows,{id="finds",icon="sparkle",tint="garden",name=UICopy.get("things.finds.name"),line=line,button=UICopy.get("things.show"),off=waiting==0})
	end
	local dash=ctx.dash
	if type(dash)=="table"then
		local saved=ctx.saved
		local line=if dash.phase=="gather"then UICopy.get("things.dash.gather",{count=dash.count or 0})
			elseif dash.phase=="live"then UICopy.get("things.dash.live")
			elseif ctx.prizes==true and type(saved)=="table"and type(saved.limit)=="number"
			then UICopy.get("things.dash.prizes",{done=saved.paid or 0,total=saved.limit})
			else UICopy.get("things.dash.idle")
		local row={id="dash",icon="trophy",tint="quests",name=UICopy.get("dash.title"),help="dash",line=line,new=ctx.new==true,button=UICopy.get("things.show")}
		-- Teach more (TEACH-MORE-BRIEF 2, `dash`): while the Dash lesson waits, its row leads the list (after a waiting gift),
		-- marked new, so "Garden Dash: Show me" is never below the fold.
		if ctx.dashLesson==true then
			row.new=true
			table.insert(rows,if rows[1]and rows[1].id=="gift"then 2 else 1,row)
		else table.insert(rows,row)end
	end
	return rows
end
-- Pure: where the rows and their parts sit on a W x H page (the hub's own panel or phone sheet). Rows that do not fit at
-- Hit + 2 px (four on the smallest phone) scroll: `scroll` = {y, h, canvas} is the window on the page, and the rows' y
-- are then in the canvas.
function Page.layout(W,H,phone,count)
	local x,y,bottom,gap=24,96,548,14
	if phone then x,y,bottom,gap=20,64,H-22,6 end
	local n=math.max(3,count)
	local h=math.floor(math.clamp((bottom-y-(n-1)*gap)/n,Page.Hit+2,if phone then 76 else 132))
	local w=W-2*x
	local pad=if phone then 10 else 20
	local disc=math.min(if phone then 36 else 64,h-10)
	local bw,bh=if phone then 112 else 190,if phone then Page.Hit else 52
	local go={x=w-pad-bw,y=math.max(0,math.floor((h-bh)/2)-2),w=bw,h=bh}
	local help={x=go.x-8-Page.Hit,y=math.floor((h-Page.Hit)/2),w=Page.Hit,h=Page.Hit}
	local tx=pad+disc+(if phone then 10 else 18)
	local nameH,lineH=if phone then 22 else 30,if phone then 18 else 24
	local ty=math.floor((h-nameH-lineH)/2)
	local rows,scroll={},nil
	local total=count*h+math.max(0,count-1)*gap
	if count>0 and y+total>bottom then scroll={y=y,h=bottom-y,canvas=total};y=0 end
	for i=1,count do rows[i]={x=x,y=y+(i-1)*(h+gap),w=w,h=h}end
	return{rows=rows,scroll=scroll,pad=pad,disc=disc,go=go,help=help,name={x=tx,y=ty,w=help.x-8-tx,h=nameH},line={x=tx,y=ty+nameH,w=help.x-8-tx,h=lineH},
		nameSize=if phone then 17 else 24,lineSize=if phone then 13 else 17}
end

-- A one-line label that shrinks instead of cutting a long translation.
local function label(parent,role,color,r,size,name)
	local t=Kit.text(parent,role,"",color,{Name=name,TextSize=size,TextScaled=true,TextTruncate=Enum.TextTruncate.AtEnd})
	t.Position=UDim2.fromOffset(r.x,r.y);t.Size=UDim2.fromOffset(r.w,r.h)
	Kit.node("UITextSizeConstraint",t,{MaxTextSize=size,MinTextSize=math.min(size,11)})
	return t
end
function Page.new(body,options)
	local self=setmetatable({body=body,o=options,row=1,col=2,views={},elapsed=0},Page)
	local root=Kit.node("Frame",body,{Name="ThingsPage",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(options.W,options.H),ZIndex=body.ZIndex+1,Active=false})
	self.root=root
	local ctx=options.things.context()
	self.fresh=ctx.new==true -- the New chip stays for this visit, though seeing the row clears it
	self:build(ctx)
	-- Onboarding part 2 (lesson C, ARCH-REVIEW-P2 1): any opening of the page is seen("page") (coach bit menuSeen).
	if options.things.seen then pcall(options.things.seen,"page")end
	self.connection=RunService.Heartbeat:Connect(function(dt)
		self.elapsed+=dt
		if self.elapsed<Page.Refresh then return end
		self.elapsed=0
		local ok,problem=pcall(self.refresh,self)
		if not ok then
			warn("[Things] page: "..tostring(problem))
			self.connection:Disconnect()
		end
	end)
	return self
end
function Page:context(ctx)
	ctx=ctx or self.o.things.context()
	ctx.new=self.fresh
	return ctx
end
function Page:build(ctx)
	self.root:ClearAllChildren()
	table.clear(self.views)
	local rows=Page.rows(self:context(ctx))
	local L=Page.layout(self.o.W,self.o.H,self.o.phone,#rows)
	local holder=self.root
	self.scroller=nil
	if L.scroll then
		holder=Kit.node("ScrollingFrame",self.root,{Name="Rows",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(0,L.scroll.y),
			Size=UDim2.fromOffset(self.o.W,L.scroll.h),CanvasSize=UDim2.fromOffset(0,L.scroll.canvas),ScrollBarThickness=4,
			ScrollingDirection=Enum.ScrollingDirection.Y,ElasticBehavior=Enum.ElasticBehavior.Never,Selectable=false,ZIndex=self.root.ZIndex})
		self.scroller=holder
	end
	local ids={}
	for index,row in ipairs(rows)do
		table.insert(ids,row.id)
		local r=L.rows[index]
		local card=Kit.card(holder,"Row_"..row.id,nil,{role="raised",radius=if self.o.phone then 12 else 16})
		card.Position=UDim2.fromOffset(r.x,r.y);card.Size=UDim2.fromOffset(r.w,r.h)
		local disc=Kit.frame(card,"IconDisc",nil,UDim2.fromOffset(L.pad,math.floor((r.h-L.disc)/2)),UDim2.fromOffset(L.disc,L.disc),999)
		disc.BackgroundTransparency=0;disc.BackgroundColor3=Kit.tintColor(row.tint)or Kit.Color.stars
		local icon=Kit.icon(disc,row.icon,math.floor(L.disc*.55),"ink");icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5)
		local view={id=row.id,card=card,help=row.help}
		-- beta 44: a learn row's tick, a green disc on the icon's corner (shown by paint)
		if row.tick~=nil then
			local size=math.max(16,math.floor(L.disc*.42))
			local tick=Kit.frame(card,"Tick",nil,UDim2.fromOffset(L.pad+L.disc-size+4,math.floor((r.h-L.disc)/2)+L.disc-size+4),UDim2.fromOffset(size,size),999)
			tick.BackgroundTransparency=0;tick.BackgroundColor3=Kit.Color.good;tick.ZIndex=disc.ZIndex+3;tick.Visible=false
			local mark=Kit.text(tick,"Name","✓","white",{TextSize=math.floor(size*.75),TextXAlignment=Enum.TextXAlignment.Center})
			mark.Size=UDim2.fromScale(1,1);mark.ZIndex=tick.ZIndex+1
			view.tick=tick
		end
		view.name=label(card,"Name","text",L.name,L.nameSize,"Name")
		view.line=label(card,"Small","soft",L.line,L.lineSize,"Line")
		local chip=Kit.chip(card,"","sticker",20)
		chip.root.Name="New";chip.root.Visible=false;chip.root.Active=false
		view.chip=chip
		if row.help then
			local ask=Kit.button(card,"Help",{variant="secondary",text="?",size=Vector2.new(L.help.w,L.help.h),textSize=if self.o.phone then 17 else 20,selectable=false})
			ask.Position=UDim2.fromOffset(L.help.x,L.help.y-2)
			ask:SetAttribute("AccessibleLabel",UICopy.get("r3.help.button")..", "..row.name)
			ask.Activated:Connect(function()self:focus(index,1);self:act()end)
			view.ask=ask
		end
		local go=Kit.button(card,"Go",{variant="primary",text=row.button,size=Vector2.new(L.go.w,L.go.h),textSize=if self.o.phone then 15 else 18,compact=self.o.phone,selectable=false})
		go.Position=UDim2.fromOffset(L.go.x,L.go.y)
		go:SetAttribute("AccessibleLabel",row.button..", "..row.name)
		go.Activated:Connect(function()self:focus(index,2);self:act()end)
		view.go=go
		self.views[index]=view
	end
	self.ids=table.concat(ids,",")
	self.layoutCache=L
	self:paint(rows)
	if not self.views[self.row]then self.row=#self.views end
end
function Page:paint(rows)
	local L=self.layoutCache
	for index,row in ipairs(rows)do
		local view=self.views[index]
		if view.name.Text~=row.name then view.name.Text=row.name end
		if view.line.Text~=row.line then view.line.Text=row.line end
		if view.off~=(row.off==true)then view.off=row.off==true;Kit.setEnabled(view.go,not view.off)end
		if view.tick and view.tick.Visible~=(row.tick==true)then view.tick.Visible=row.tick==true end
		view.card:SetAttribute("Ticked",row.tick)
		if row.new~=view.new then
			view.new=row.new
			view.chip.root.Visible=row.new==true
			local w=L.name.w
			if row.new then
				view.chip.set(UICopy.get("things.new"),"sticker",Kit.Color.stars)
				local cw=view.chip.root.Size.X.Offset
				-- Right after the name while there is room, else at the end of the name's line.
				local nw=math.min(Kit.measure(row.name,"Name",L.nameSize).X,w-cw-8)
				view.chip.root.Position=UDim2.fromOffset(L.name.x+nw+8,L.name.y+math.floor((L.name.h-20)/2))
				w=math.max(20,nw+2)
			end
			view.name.Size=UDim2.fromOffset(w,L.name.h)
		end
		view.card:SetAttribute("Line",row.line)
	end
	-- Code review: in a scrolled list the Dash row counts as seen only once it is inside the window (paint runs on the
	-- refresh timer, so scrolling to it marks it within Page.Refresh).
	if self.views[#rows]and rows[#rows].id=="dash"and self:inWindow(#rows)then self.o.things.seen("dash")end
end
function Page:inWindow(index)
	local scroller,L=self.scroller,self.layoutCache
	if not(scroller and L and L.scroll and L.rows[index])then return true end
	local r,top=L.rows[index],scroller.CanvasPosition.Y
	return r.y>=top-1 and r.y+r.h<=top+L.scroll.h+1
end
-- Read the rows again. A game that opened or closed rebuilds the list; the switch going off ends the page.
function Page:refresh()
	if self.destroyed or not self.o.shown()then return end
	if self.o.things.on()~=true then self.o.gone();return end
	local ctx=self:context()
	local rows=Page.rows(ctx)
	local ids={}
	for _,row in ipairs(rows)do table.insert(ids,row.id)end
	if table.concat(ids,",")~=self.ids then
		local id=self.views[self.row]and self.views[self.row].id
		self:build(ctx)
		for index,view in ipairs(self.views)do if view.id==id then self.row=index end end
		self:focus(self.row,self.col,true)
		return
	end
	self:paint(rows)
end
function Page:focus(row,col,instant)
	self.row=math.clamp(row or self.row,1,math.max(1,#self.views))
	self.col=col or self.col
	local view=self.views[self.row]
	if not view then return end
	if self.col==1 and not view.ask then self.col=2 end
	-- A scrolled list brings the focused row into its window.
	local scroller,L=self.scroller,self.layoutCache
	if scroller and L and L.scroll then
		local r,top=L.rows[self.row],scroller.CanvasPosition.Y
		if r.y<top then scroller.CanvasPosition=Vector2.new(0,r.y)
		elseif r.y+r.h>top+L.scroll.h then scroller.CanvasPosition=Vector2.new(0,r.y+r.h-L.scroll.h)end
	end
	local target=if self.col==1 then view.ask else view.go
	local ring=self.o.ring
	if ring and self.o.shown()then
		ring.attach(target,if self.col==1 then 12 else 14)
		if instant then ring.place(true)end
	end
end
function Page:act()
	local view=self.views[self.row]
	if not view or self.destroyed then return false end
	if self.col==1 then return self.o.things.help(view.help)==true end
	if view.off then return false end
	return self.o.things.act(view.id)==true
end
-- "left" | "right" | "up" | "down" | "open". True when something moved or opened.
function Page:input(action)
	if action=="open"then return self:act()end
	local row,col=self.row,self.col
	if action=="up"then row-=1 elseif action=="down"then row+=1
	elseif action=="left"then col=1 elseif action=="right"then col=2 else return false end
	if not self.views[row]then return false end
	if col==1 and not self.views[row].ask then
		if row==self.row then return false end
		col=2
	end
	if row==self.row and col==self.col then return false end
	self:focus(row,col)
	return true
end
function Page:destroy()
	if self.destroyed then return end
	self.destroyed=true
	self.connection:Disconnect()
	self.root:Destroy()
end
return Page
