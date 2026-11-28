-- The lessons' wiring (artifacts/qa-2026-11-27-beta42/TEACH-MORE-BRIEF.md, ARCH-REVIEW-TEACH 11): init.client sits at
-- Luau's 200 top-level-local limit, so the reset lesson's target, the deck tour (DeckTour), the all-set card's moment,
-- the Things rows' Show me pointer and Settings > Skip the tips live here. init.client's teach block makes one of these
-- and calls target(id) for the ids it does not draw itself, and step() every frame. Onboard `teach` off: nothing drawn.
-- Beta 44, onboarding shorter (artifacts/qa-2026-11-28-beta44/ONBOARD-SIMPLIFY-BRIEF.md sections 2 and 4,
-- ARCH-REVIEW-SIMPLIFY 2 to 5, 9 and 11):
--   reset     the pet screen's Dress up ("One more thing!"), then Back to white on the Colour tab (HueEggView:teachWhite)
--   tour      DeckTour with the deck's ready gate (its boot), the drop hold (deck.tourHold) and the close after it
--   all set   once the tour is latched and the board is back in the garden, free, AllSetAfter s later: "You're all set!"
--             (deps.allSet, the card with the +5 welcome gift; its showing graduates: Lessons:finish). A save whose need
--             bubbles were already over graduates silently. Once a session.
--   show me   the Things rows Customize and Dress up: the pet screen, Dress up ringed, then the Colour or Outfit tab
--             (one TeachPointer of its own, gone on the tap or after ShowFor s; asked for, so graduates get it too)
--   book, style  opened from Things to do: their coach bits, once the first-visit card had its moment (Things ticks)
-- The old lessons' targets (quests, snacks, stats, wardrobe) and the round tips are gone; their bits stay.
-- deps: lessons (TeachLessons), teach() -> on, clientUI, roomView, board, attr(name), playerGui(), text(key, vars),
--   live(node) (TeachPointer.live), pointer (a TeachPointer for the tour), showPointer (a TeachPointer for Show me),
--   picker (the Settings screen, DeckPicker), toast(key), event(name), close() (leave the deck: clientUI.leaveDeck),
--   gardenFree() (nothing up in the garden), allSet() (show the card), focused() (the window has focus)
local Tour=require(script.Parent.DeckTour)
local Wiring={};Wiring.__index=Wiring
Wiring.AllSetAfter=.6 -- s in the free garden after the tour before the card
Wiring.ShowFor=12     -- s a Show me ring waits on one target (focused time) before it goes
Wiring.ColourSeen=1.5 -- s the Colour tab is ringed while already open before Show me counts it seen
Wiring.MarkAfter=1.5  -- s after Things opened the book or Deck style before its coach bit is sent (its own card first)

-- Pure: the Show me ring's target now. kind "customize" | "dress"; view: {hueOpen, tab, wardrobe}. -> "dressUp" | "tab" |
-- "done". The Colour tab is the paint screen's first, so for Customize it is ringed a moment, then done.
function Wiring.showTarget(kind,view)
	view=view or {}
	if not view.hueOpen then return "dressUp"end
	local want=if kind=="dress"then "outfit"else "hue"
	if view.tab==want or(kind=="dress"and view.wardrobe==true)then return if kind=="dress"then "done"else "tab"end
	return "tab"
end

function Wiring.new(deps)
	local self=setmetatable({d=deps,visit=0,focused=false,allSetDone=false,freeSince=nil,show=nil},Wiring)
	local d=deps
	local ui=d.clientUI
	self.tour=Tour.new({
		facts=function()return d.lessons:read()end,
		ctx=function()return self:round()end,
		deck=function()return ui.deck end,
		latch=function(id)d.lessons:latch(id)end,
		text=function(key,vars)return d.text(key,vars)end,
		pointer=d.pointer,
		hold=function(on)if ui.deck then ui.deck.tourHold=on==true end end,
		close=function()return d.close and d.close()end,
		event=d.event,
		playerGui=d.playerGui,
	})
	self:settings()
	return self
end
function Wiring:on()return self.d.teach()==true end
-- The round as the tour reads it.
function Wiring:round()
	local d=self.d
	local ui=d.clientUI
	local board=d.board
	local overlay=false
	pcall(function()overlay=ui.deckOverlayOpen()==true or(ui.anyModalOpen~=nil and ui.anyModalOpen()==true)end)
	local over=false
	pcall(function()over=ui.roundOver()==true end)
	return{mode=board:GetAttribute("Mode"),phase=if board:GetAttribute("HatchActive")==true then d.attr("FieldPhase")else nil,
		guided=board:GetAttribute("HeatGuided")==true,drops=d.attr("Drops")or 0,over=over,overlay=overlay}
end
-- The Garden Dash lesson is a Things row now (beta 44): the row never leads the list for it.
function Wiring:dashOpen()return false end
-- Settings > Skip the tips (graduation rule 2): one confirm; the row shows only while there is something to skip.
function Wiring:settings()
	local picker=self.d.picker
	if not picker then return end
	picker.skipTipsShown=function()
		local f=self.d.lessons:read()
		return self:on()and f.on and not f.graduated
	end
	picker.onSkipTips=function()
		local Confirm=require(script.Parent.ConfirmDialog)
		local handle=Confirm.ask({title=self.d.text("teach.skipTitle"),line=self.d.text("teach.skipLine"),confirm=self.d.text("teach.skipYes"),
			onConfirm=function()
				if self.d.lessons:skipAll()then
					self.tour:destroy()
					if self.d.toast then pcall(self.d.toast,"teach.skipDone")end
					if picker.skipTipsButton then picker.skipTipsButton.Visible=false;pcall(picker.layout,picker)end
				end
			end})
		return handle~=nil
	end
end

-- The reset lesson's target: -> GuiObject, words key; or nil.
function Wiring:target(id,f)
	local d=self.d
	local ui=d.clientUI
	local room=d.roomView
	local live=d.live
	if id~="reset"then return nil end
	local focus=room.focusing==true and room.focusUI or nil
	local hue=ui.hueView
	if hue~=nil and hue.shade.Visible and ui.hueReturn=="focus"then
		local card=hue.teachWhite and hue:teachWhite()
		return if live(card)then card else nil,"reset"
	end
	local button=focus and focus.dressUpButton
	-- the reset waits for lesson A's wipe (Lessons.ready) and any card on the pet screen
	return if live(button)then button else nil,"more"
end

-- ── Show me (ARCH-REVIEW-SIMPLIFY 11: its own pointer; the lessons' hides itself every frame) ───────────────────────
-- Customize or Dress up from Things to do: the pet screen is opened by the caller; this rings the way through it.
function Wiring:showMe(kind)
	if kind~="customize"and kind~="dress"then return false end
	self.show={kind=kind,stage=nil,shownFor=0,colourFor=0}
	return true
end
function Wiring:stepShow(dt)
	local s=self.show
	local pointer=self.d.showPointer
	if not s then return end
	local d=self.d
	local ui=d.clientUI
	local room=d.roomView
	local hue=ui.hueView
	local hueOpen=hue~=nil and hue.shade.Visible and ui.hueReturn=="focus"
	local okWard,wardOpen=pcall(function()return ui.wardrobe~=nil and ui.wardrobe:isOpen()end)
	local stage=Wiring.showTarget(s.kind,{hueOpen=hueOpen,tab=hueOpen and hue.tab or nil,wardrobe=okWard and wardOpen==true})
	local node,words=nil,nil
	if stage=="dressUp"then
		local focus=room.focusing==true and room.focusUI or nil
		node,words=focus and focus.dressUpButton,"teach.dress"
		-- the pet screen closed (or never opened) and no paint screen: Show me is over
		if not focus and room.focusTransitioning~=true and s.stage=="dressUp"and s.shownFor>1 then self:endShow();return end
	elseif stage=="tab"then
		local tab=hue.editorTabs and hue.editorTabs[if s.kind=="dress"then "outfit"else "hue"]
		node,words=tab,if s.kind=="dress"then "teach.outfits"else "teach.colour"
		if s.kind=="customize"and hue.tab=="hue"then
			s.colourFor+=require(script.Parent.TeachLessons).tick(dt,self:focusedNow())
			if s.colourFor>=Wiring.ColourSeen then self:endShow();return end
		end
	else self:endShow();return end
	if stage~=s.stage then s.stage=stage;s.shownFor=0 end
	s.shownFor+=require(script.Parent.TeachLessons).tick(dt,self:focusedNow())
	if s.shownFor>=Wiring.ShowFor then self:endShow();return end
	if pointer then
		if node and d.live(node)then pointer:show(node,d.text(words),{})else pointer:hide()end
		pointer:step(dt or 0)
	end
end
function Wiring:endShow()
	self.show=nil
	if self.d.showPointer then self.d.showPointer:hide()end
end
function Wiring:focusedNow()return self.d.focused==nil or self.d.focused()~=false end
-- Book and Deck style opened from Things to do (ARCH-REVIEW-SIMPLIFY 9): the coach bit that ticks their row, sent once
-- the screen's own first-visit card had its moment (it sets the same bit when it shows).
function Wiring:opened(id)
	if id~="book"and id~="style"then return end
	local coach=self.d.clientUI.coach
	task.delay(Wiring.MarkAfter,function()
		local Coach=require(game:GetService("ReplicatedStorage").Shared.CoachMarks)
		if coach and not Coach.has(coach.mask,id)then pcall(coach.mark,coach,id)end
	end)
end

-- ── The all-set card (ONBOARD-SIMPLIFY-BRIEF 4, ARCH-REVIEW-SIMPLIFY 5) ─────────────────────────────────────────────
function Wiring:stepAllSet(now)
	if self.allSetDone then return end
	local d=self.d
	local Lessons=require(script.Parent.TeachLessons)
	local owed=Lessons.allSet(d.lessons:read())
	if not owed then self.freeSince=nil;return end
	if owed=="silent"then self.allSetDone=true;d.lessons:finish();return end
	local free=not self.tour:busy()and d.board:GetAttribute("Mode")=="Room"and(d.gardenFree==nil or d.gardenFree()==true)
	if not free then self.freeSince=nil;return end
	self.freeSince=self.freeSince or now
	if now-self.freeSince<Wiring.AllSetAfter then return end
	self.allSetDone=true
	-- the card graduates as it shows; no card (it could not open): graduate anyway, the gift's own retry pays later
	local ok,shown=pcall(function()return d.allSet and d.allSet()end)
	if not(ok and shown==true)then d.lessons:finish()end
end

-- Every frame: the pet screen's visits, the tour, the all-set card, Show me.
function Wiring:step(now,dt)
	local d=self.d
	local okShow,why=pcall(self.stepShow,self,dt)
	if not okShow then self.show=nil;warn("[Teach] show me: "..tostring(why))end
	if not self:on()then
		-- off (or switched off mid-tour): put everything away once, then a look each frame
		if not self.off then self.off=true;self.tour:destroy()end
		return
	end
	self.off=false
	local room=d.roomView
	local focusing=room.focusing==true
	if focusing and not self.focused then self.visit+=1 end
	self.focused=focusing
	local ok,tourWhy=pcall(self.tour.step,self.tour,now,dt)
	if not ok then warn("[DeckTour] "..tostring(tourWhy))end
	local okSet,setWhy=pcall(self.stepAllSet,self,now)
	if not okSet then self.allSetDone=true;warn("[Teach] all set: "..tostring(setWhy))end
end
function Wiring:destroy()
	self.tour:destroy()
	self:endShow()
end
return Wiring
