-- Teach more's wiring (artifacts/qa-2026-11-27-beta42/TEACH-MORE-BRIEF.md, ARCH-REVIEW-TEACH 11): init.client sits at
-- Luau's 200 top-level-local limit, so the new lessons' targets, their "done" facts read from the screens, the first
-- field round's tour (DeckTour) and Settings > Skip the tips live here. init.client's teach block makes one of these and
-- calls target(id) for the ids it does not draw itself, and step() every frame. Onboard `teach` off: nothing drawn.
--   reset     the pet screen's Dress up ("One more thing!"), then Back to white on the Colour tab (HueEggView:teachWhite)
--   quests    the deck's quest handle (or the Daily quests card) at the round-two opener; done when the log is open
--   snacks    the pet screen's Snacks ("Snack time!"), then the picked snack ("Feed {pet}!"); done when one was fed
--   stats     the pet screen's Stats ("See {pet} grow!"); done when the panel is open
--   wardrobe  Dress up ("Dress up!"), then the Outfit tab ("Outfits!"); done when the Wardrobe is open
-- deps: lessons (TeachLessons), teach() -> on, clientUI, roomView, board, attr(name), playerGui(), text(key, vars),
--   send(request) (the teachMark remote), live(node) (TeachPointer.live), pointer (a TeachPointer for the tour), picker
--   (the Settings screen, DeckPicker), toast(key), event(name)
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Teach=require(Shared:WaitForChild("TeachMarks"))
local Tour=require(script.Parent.DeckTour)
local Wiring={};Wiring.__index=Wiring

function Wiring.new(deps)
	local self=setmetatable({d=deps,visit=0,focused=false,pouch=nil},Wiring)
	local d=deps
	local ui=d.clientUI
	self.tour=Tour.new({
		facts=function()return d.lessons:read()end,
		ctx=function()return self:round()end,
		deck=function()return ui.deck end,
		latch=function(id)d.lessons:latch(id)end,
		text=function(key,vars)return d.text(key,vars)end,
		pointer=d.pointer,
		picked=function()return ui.stepperPick end,
		rail=function(id,text)
			local host=ui.coach and ui.coach.host
			if not host then return false end
			local ok=pcall(function()
				require(script.Parent.NotificationRail).enqueue(host,"teach:"..id,{text=text,priority=-1,icon="?"})
			end)
			return ok
		end,
		railEmpty=function()
			local ok,empty=pcall(function()return require(script.Parent.NotificationRail).empty()end)
			return not ok or empty==true
		end,
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
	local goalsDone=0
	local ok,goals=pcall(function()return ui.deckGoals(ui.fieldView)end)
	if ok and type(goals)=="table"then for _,g in ipairs(goals)do if g.done then goalsDone+=1 end end end
	local overlay=false
	pcall(function()overlay=ui.deckOverlayOpen()==true or(ui.anyModalOpen~=nil and ui.anyModalOpen()==true)end)
	return{mode=board:GetAttribute("Mode"),phase=if board:GetAttribute("HatchActive")==true then d.attr("FieldPhase")else nil,
		guided=board:GetAttribute("HeatGuided")==true,drops=d.attr("Drops")or 0,over=ui.roundOver(),overlay=overlay,
		chain=d.attr("Chain")or 0,goalsDone=goalsDone}
end
-- The Garden Dash's Things row (TEACH-MORE-BRIEF 2): leads the list while the lesson is still to do.
function Wiring:dashOpen()
	if not self:on()then return false end
	local Lessons=require(script.Parent.TeachLessons)
	local f=self.d.lessons:read()
	return f.on and not f.graduated and Lessons.ready("dash",f)and not Lessons.done("dash",f)
end
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

-- The new lessons' targets: -> GuiObject, words key; or nil.
function Wiring:target(id,f)
	local d=self.d
	local ui=d.clientUI
	local room=d.roomView
	local live=d.live
	local focus=room.focusing==true and room.focusUI or nil
	local hue=ui.hueView
	local hueOpen=hue~=nil and hue.shade.Visible and ui.hueReturn=="focus"
	if id=="reset"or id=="wardrobe"then
		if hueOpen then
			if id=="reset"then
				local card=hue.teachWhite and hue:teachWhite()
				return if live(card)then card else nil,"reset"
			end
			local tab=hue.editorTabs and hue.editorTabs.outfit
			return if live(tab)then tab else nil,"outfits"
		end
		local button=focus and focus.dressUpButton
		-- the reset waits for lesson A's wipe (Lessons.ready) and any card on the pet screen
		return if live(button)then button else nil,if id=="reset"then "more"else "dress"
	elseif id=="snacks"then
		if not focus then return nil end
		if focus.snacksOpen and focus:snacksOpen()then
			local tray=focus.tray
			local tile=tray and tray.tiles and tray.tiles[tray.index or 1]
			local button=tile and tile.button
			return if live(button)then button else nil,"feed"
		end
		local button=focus.snacksButton
		return if live(button)then button else nil,"snack"
	elseif id=="stats"then
		if not focus or(focus.snacksOpen and focus:snacksOpen())then return nil end
		local button=focus.statsButton
		return if live(button)then button else nil,"stats"
	elseif id=="quests"then
		-- the round-two opener only (never mid-round), and never beside the tour
		if self.tour:touring()or not Tour.opener(self:round())then return nil end
		local host=ui.deck and ui.deck.hudRoot
		local card=host and(host:FindFirstChild("QuestHandle")or host:FindFirstChild("DailyQuests"))
		return if live(card)then card else nil,"quests"
	end
	return nil
end

-- Every frame: the screens' own "done" facts, the pet screen's visits, the tour.
function Wiring:step(now,dt)
	local d=self.d
	if not self:on()then
		-- off (or switched off mid-tour): put everything away once, then a look each frame
		if not self.off then self.off=true;self.tour.active=nil;self.tour:hide()end
		return
	end
	self.off=false
	local ui=d.clientUI
	local room=d.roomView
	local lessons=d.lessons
	-- the pet screen's opening number (the Wardrobe waits for the visit after the one Stats was learned in)
	local focusing=room.focusing==true
	if focusing and not self.focused then self.visit+=1 end
	self.focused=focusing
	local f=lessons:read()
	if f.on and not f.graduated then
		if ui.questLog and ui.questLog.visible then lessons:latch("quests")end
		local okStats,statsOpen=pcall(function()return ui.stats~=nil and ui.stats.isOpen()end)
		if okStats and statsOpen then lessons:latch("stats")end
		local okWard,wardOpen=pcall(function()return ui.wardrobe~=nil and ui.wardrobe:isOpen()end)
		if okWard and wardOpen then lessons:latch("wardrobe")end
		-- a snack fed on the pet screen: the pouch shrinks (the server latches `snacks` in the same write as the boost)
		local pouch=f.pouch or 0
		if self.pouch and pouch<self.pouch and focusing then lessons:latch("snacks")end
		self.pouch=pouch
	end
	local ok,why=pcall(self.tour.step,self.tour,now,dt)
	if not ok then warn("[DeckTour] "..tostring(why))end
end
function Wiring:destroy()self.tour:destroy()end
return Wiring
