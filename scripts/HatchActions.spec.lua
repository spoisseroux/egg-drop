-- Studio Client UI fixtures. No inventory grants, remote calls, or persistent writes.
return function(client, parent)
	local View = require(client.EggHatchView)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_HatchActionsSpec", UDim2.fromOffset(360, 580), 1, parent
	local cases, views = {}, {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function result(id, petId)
		return { id = id or "fixture-reveal", petId = petId or "foxfire_wick", rare = true, family = "wick" }
	end
	local function state(revision, hatch, status)
		return { status = status or "Ready", revision = revision, lastHatch = hatch, nectar = 24, inventoryMask = 32 }
	end
	local function fixture(hatch, transport, reduced, beforeOpen)
		local sent, completed, sounds = {}, {}, {}
		local view
		view = View.new(root, { play = function(_, cue) table.insert(sounds, cue) end }, function() return reduced ~= false end, function(command, value, revision)
			table.insert(sent, { command = command, value = value, revision = revision })
			if transport then transport(view, command, value, revision) end
		end)
		table.insert(views, view)
		view.onClosed = function(reason, choice)
			assert(view.ackIntent == nil, "intent must be dequeued before navigation")
			table.insert(completed, { reason = reason, choice = choice })
		end
		local openingState = if beforeOpen then beforeOpen(view) else nil
		view:open(openingState or state(10, hatch or result()))
		return view, sent, completed, sounds
	end
	local ok, problem = pcall(function()
		test("Meet acknowledges exact rare-only result and waits for advanced Ready", function()
			local view, sent, completed = fixture()
			view:chooseResult("meet"); view:chooseResult("play")
			assert(#sent == 1 and sent[1].command == "ack" and sent[1].value == "fixture-reveal" and sent[1].revision == 10)
			view:update(state(10, nil)); assert(#completed == 0 and view:isOpen())
			view:update(state(11, nil, "Busy")); assert(#completed == 0)
			view:update(state(11, nil)); view:update(state(12, nil))
			assert(#completed == 1 and completed[1].reason == "meet" and completed[1].choice.petId == "foxfire_wick")
			assert(completed[1].choice.intent == "meet" and completed[1].choice.sourceRevision == 10)
		end)
		test("Replay never purchases and synchronous confirmation fires once", function()
			local view, sent, completed = fixture(result("sync", "pip"), function(instance)
				instance:update(state(11, nil))
			end)
			view:chooseResult("play"); view:update(state(12, nil))
			assert(#sent == 1 and sent[1].command == "ack")
			assert(#completed == 1 and completed[1].reason == "afterHatch" and completed[1].choice.intent == "play")
		end)
		test("Retry and same-ID updates retain immutable choice", function()
			local hatch = result("retry")
			local view, sent, completed = fixture(hatch)
			view:chooseResult("meet")
			local intent = view.ackIntent
			view:update(state(10, hatch, "Retrying")); view:setError("Saving progress · retrying")
			view:chooseResult("play"); assert(view.ackIntent == intent and #sent == 1)
			view:update(state(11, hatch)); assert(view.ackIntent == intent and #completed == 0)
			view:update(state(12, nil)); assert(#completed == 1 and completed[1].reason == "meet")
		end)
		test("Pending feedback preserves choice before state catches up", function()
			local view, sent, completed = fixture()
			view:chooseResult("play")
			view:setError("Retry the previous action while it saves.")
			assert(view.ackIntent and view.pending and #sent == 1)
			view:update(state(11, nil)); assert(#completed == 1 and completed[1].reason == "afterHatch")
		end)
		test("Throttle, lock, and network feedback cannot erase an in-flight choice", function()
			local view, sent, completed = fixture()
			view:chooseResult("meet")
			local intent = view.ackIntent
			for _, message in ipairs({ "One moment…", "Finishing your last save…", "Network timeout", "Saving is delayed. Your result will stay the same when retried." }) do
				view:setError(message)
				assert(view.ackIntent == intent and view.pending and #sent == 1)
			end
			view:update(state(11, nil)); assert(#completed == 1 and completed[1].reason == "meet")
		end)
		test("Pre-dispatch throttle retries the same acknowledgement and confirms once", function()
			local attempts = 0
			local view, sent, completed = fixture(result("throttled"), function(instance, command, value, revision)
				attempts += 1
				assert(command == "ack" and value == "throttled" and revision == 10)
				if attempts == 1 then instance:setError("One moment…") else instance:update(state(11, nil)) end
			end)
			view:chooseResult("meet"); task.wait(0.75)
			assert(#sent == 2 and #completed == 1 and completed[1].reason == "meet")
		end)
		test("Close cancels a scheduled pre-dispatch retry", function()
			local view, sent, completed = fixture(result("lock"), function(instance) instance:setError("Finishing your last save…") end)
			view:chooseResult("meet"); view:close("close"); task.wait(0.75)
			assert(#sent == 1 and #completed == 1 and completed[1].reason == "close")
		end)
		test("Busy feedback queues a retry until Ready for the same result", function()
			for _, message in ipairs({ "Finishing your last save…", "Finishing your last hatch action…" }) do
				local hatch, attempts = result("busy-feedback-" .. message), 0
				local view, sent, completed = fixture(hatch, function(instance)
					attempts += 1
					if attempts == 1 then
						instance:update(state(10, hatch, "Busy")); instance:setError(message)
					else instance:update(state(11, nil)) end
				end)
				view:chooseResult("meet")
				assert(view.ackRetryNeededToken and #sent == 1)
				view:update(state(10, hatch)); task.wait(0.75)
				assert(#sent == 2 and #completed == 1 and completed[1].reason == "meet")
			end
		end)
		test("A retry timer encountering Busy retains its work until Ready", function()
			local hatch, attempts = result("busy-timer"), 0
			local view, sent, completed = fixture(hatch, function(instance)
				attempts += 1
				if attempts == 2 then instance:update(state(11, nil)) end
			end)
			view:chooseResult("play"); view:setError("One moment…")
			view:update(state(10, hatch, "Busy")); task.wait(0.75)
			assert(#sent == 1 and view.ackRetryNeededToken)
			view:update(state(10, hatch)); task.wait(0.75)
			assert(#sent == 2 and #completed == 1 and completed[1].reason == "afterHatch")
		end)
		test("Another pending transaction releases the captured ack on Ready", function()
			local hatch, attempts = result("other-pending"), 0
			local view, sent, completed = fixture(hatch, function(instance)
				attempts += 1
				if attempts == 1 then
					instance:update(state(10, hatch, "Pending")); instance:setError("Retry the previous action while it saves.")
				else
					-- The intervening transaction advances revision; rejection enables a new explicit choice.
					instance:setError("Your hatch progress updated. Try again.")
				end
			end)
			view:chooseResult("meet"); assert(view.ackRetryNeededToken and #sent == 1)
			view:update(state(11, hatch)); task.wait(0.75)
			assert(#sent == 2 and sent[2].value == hatch.id and sent[2].revision == 10)
			assert(view.ackIntent == nil and view.meetButton.Interactable and #completed == 0)
			view:chooseResult("play"); assert(#sent == 3 and sent[3].revision == 11)
			view:close()
		end)
		test("Repeated pre-dispatch locks are bounded and expose a user retry", function()
			local view, sent, completed = fixture(result("bounded"), function(instance) instance:setError("One moment…") end)
			view:chooseResult("play"); task.wait(2.1)
			assert(#sent == 4 and #completed == 0 and not view.pending and view.ackIntent == nil)
			assert(view.action.Interactable and view.action.Text == "Try again")
			view:close()
		end)
		test("A changed result revokes old navigation", function()
			local view, _, completed = fixture(result("old"))
			view:chooseResult("meet"); view:update(state(11, result("new", "pip")))
			assert(view.ackIntent == nil and not view.pending)
			view:update(state(12, nil)); assert(#completed == 0 and view:isOpen())
		end)
		test("Close during retry cancels navigation without a second acknowledgement", function()
			local hatch = result("cancel")
			local view, sent, completed = fixture(hatch)
			view:chooseResult("meet"); view:update(state(10, hatch, "Retrying")); view:close("close")
			view:update(state(11, nil)); assert(#sent == 1 and #completed == 1 and completed[1].reason == "close")
			view:open(state(11, nil)); view:update(state(12, nil)); assert(#completed == 1)
		end)
		test("Definitive rejection permits changing the action", function()
			local view, sent, completed = fixture()
			view:chooseResult("meet"); view:setError("Your hatch progress updated. Try again.")
			assert(not view.pending and view.ackIntent == nil)
			view:chooseResult("play"); assert(#sent == 2 and sent[2].command == "ack")
			view:update(state(11, nil)); assert(#completed == 1 and completed[1].reason == "afterHatch")
		end)
		test("First result action skips unfinished cinematic without acknowledging; fresh action confirms", function()
			local view, sent = fixture(result("animating"), nil, false)
			assert(not view:chooseResult("meet")); assert(#sent == 0 and not view.cinematic.active and view.meetButton.Interactable and view.action.Interactable)
			view:chooseResult("meet"); assert(#sent == 1)
		end)
		test("Legacy duplicate receipt retains both choices without reviving removed mastery rewards", function()
			local hatch = result("duplicate")
			hatch.duplicate, hatch.mastery = true, 18
			local view, sent, completed = fixture(hatch)
			view:close()
			local snapshot = state(10, hatch)
			snapshot.masteryDetails = { wick = { rank = 2, points = 18, nextPoints = 25, challenges = 1, challengeGoal = 3 } }
			view:open(snapshot)
			assert(hatch.masteryHint == nil and view.cinematic.result.masteryHint == nil)
			assert(not view.cinematic.frame:FindFirstChild("Mastery", true))
			local caption = view.cinematic.frame:FindFirstChild("CollectionStatus", true)
			assert(caption and caption.Text == "Already owned · no additional reward")
			assert(view.meetButton.Interactable and view.action.Interactable)
			hatch.promotedTo = 2
			view:close(); view:open(snapshot)
			assert(not view.cinematic.frame:FindFirstChild("Mastery", true), "legacy promotion revived a removed reward")
			assert(view.cinematic.frame:FindFirstChild("CollectionStatus", true).Text == "Already owned · no additional reward")
			assert(hatch.mastery == 18 and hatch.promotedTo == 2 and snapshot.masteryDetails.wick.points == 18, "presentation mutated historical receipt data")
			assert(view.meetButton.Interactable and view.action.Interactable and #sent == 0)
			view:chooseResult("meet");assert(#sent == 1 and sent[1].command == "ack" and sent[1].value == hatch.id and sent[1].revision == 10)
			view:update(state(11, nil));assert(completed[#completed].reason == "meet" and completed[#completed].choice.petId == hatch.petId)
		end)
		test("corner X dismisses and reopens the same committed result without acknowledgment",function()
			local hatch=result("retained-x");local view,sent,completed=fixture(hatch)
			assert(view.closeButton.Text=="×" and view.closeButton:GetAttribute("AccessibleLabel")=="Close")
			view:close("close");view:open(state(10,hatch))
			assert(#sent==0 and #completed==1 and view.state.lastHatch.id=="retained-x")
			assert(view.closeButton.AbsoluteSize==Vector2.new(44,44))
		end)
		test("Mid-crack X and two reopens retain the result and show the quiet final scene", function()
			local hatch = result("mid-crack-retained")
			local view, sent, completed, sounds = fixture(hatch, nil, false)
			-- Native suite load can exceed the .25s frame-stall gate, which
			-- intentionally settles the scene. Drive ordinary frames explicitly
			-- to test X during the actual rare shell split rather than wall time.
			view.cinematic:disconnectClock()
			for _ = 1, 67 do view.cinematic:step(1/60) end
			assert(view.cinematic.active and view.cinematic.age >= .95 and view.cinematic.age < 1.26 and view.cinematic.duration==1.7)
			assert(view.cinematic.resultRoot.Visible and view.lastPresentedId == hatch.id and not view.ackReady)
			view:close("close")
			local heard = #sounds
			for _ = 1, 2 do
				view:open(state(10, hatch))
				assert(view.lastPresentedId == hatch.id and view.playingId == hatch.id and view.ackReady)
				assert(not view.cinematic.active and view.meetButton.Interactable and view.action.Interactable)
				assert(#sent == 0 and #sounds == heard, "reopen replayed a cue or acknowledged without a choice")
				view:close("close")
			end
			assert(#completed == 3 and view.lastPresentedId == hatch.id)
		end)
		test("A stalled intro settles quietly without acknowledging or replaying its retained result", function()
			local hatch = result("stalled-intro-retained")
			local view, sent, _, sounds = fixture(hatch, nil, false)
			view.cinematic:disconnectClock();assert(view.cinematic.active and not view.ackReady)
			view.cinematic:step(.26)
			assert(not view.cinematic.active and view.ackReady and view.lastPresentedId == hatch.id and #sent == 0)
			assert(view.meetButton.Interactable and view.action.Interactable)
			view:close("close");local heard = #sounds;view:open(state(10, hatch))
			assert(view.ackReady and not view.cinematic.active and #sounds == heard and #sent == 0)
			view:close()
		end)
		test("Hidden snapshots and a covered first paint do not reserve the presentation marker", function()
			local hatch = result("unseen")
			local owner = false
			local view, sent = fixture(hatch, nil, false, function(instance)
				instance.ownsPresentation = function() return owner end
				instance:update(state(10, hatch))
				assert(instance.lastPresentedId == nil and instance.playingId == nil)
			end)
			assert(view.lastPresentedId == nil and #sent == 0)
   assert(not view:chooseResult("meet")and view.cinematic.active and not view.ackReady and view.lastPresentedId==nil and #sent==0,"covered stale action settled or acknowledged unseen result")
			view:close("close")
			owner = true
			view:open(state(10, hatch))
			assert(view.lastPresentedId == hatch.id and view.cinematic.active and not view.ackReady)
   assert(not view:chooseResult("meet")and view.ackReady and not view.cinematic.active and #sent==0,"visible first action must skip without acknowledgment")
   view:chooseResult("meet");assert(#sent==1,"fresh visible action did not acknowledge exact saved result")
			view:close()
		end)
		test("A stale same-ID completion cannot unlock or steal focus after reopen", function()
			local plays, selections = {}, 0
			local hatch = result("same-id-generation")
			local view, sent = fixture(hatch, nil, true, function(instance)
				instance.cinematic:cancel()
				instance.cinematic = {
					cancel = function() end,
					play = function(_, _, complete, options)
						table.insert(plays, {complete=complete, options=options})
						options.onPresented()
						if options.skipIntro then complete(); complete() end
					end,
				}
				instance.selectResultAction = function() selections += 1 end
			end)
			assert(not view.ackReady and not plays[1].options.skipIntro)
			view:close(); view:open(state(10, hatch))
			assert(plays[2].options.skipIntro and view.ackReady and selections == 1)
			plays[1].complete(); plays[2].complete()
			assert(selections == 1 and #sent == 0, "cancelled or duplicate completion reclaimed selection")
			view:update(state(11, result("replacement", "pip")))
			assert(not view.ackReady and view.lastPresentedId == "replacement")
			plays[2].options.onPresented(); plays[2].complete()
			assert(not view.ackReady and view.lastPresentedId == "replacement" and selections == 1)
			plays[3].complete(); assert(view.ackReady and selections == 2)
		end)
		test("Fresh controller focus waits for Meet while a deliberate X remains selected", function()
			local GuiService = game:GetService("GuiService")
			local previous = GuiService.SelectedObject
			local hatch = result("controller-intro")
			local view = fixture(hatch, nil, false)
			assert(view:openingFocusTarget() == nil, "fresh intro must not automatically pin X")
			view.cinematic:finishStatic()
			assert(view:openingFocusTarget() == view.meetButton and view.meetButton.Interactable)
			GuiService.SelectedObject = view.closeButton
			view:selectResultAction()
			assert(GuiService.SelectedObject == view.closeButton, "finishing must retain a deliberately focused X")
			view:update(state(10, hatch, "Retrying"))
			assert(view:openingFocusTarget() == view.closeButton, "settled disabled actions fall back to X")
			GuiService.SelectedObject = previous
		end)
		test("A covered intro completes without reclaiming the covering owner's focus", function()
			local owned, selections = true, 0
			local hatch = result("covered-mid-intro")
			local view, sent = fixture(hatch, nil, false, function(instance)
				instance.ownsPresentation = function() return owned end
				instance.selectResultAction = function() selections += 1 end
			end)
			assert(view.lastPresentedId == hatch.id and view.cinematic.active)
			owned = false
			view.cinematic:finishStatic()
			assert(view.ackReady and selections == 0 and #sent == 0)
			view:close(); owned = true; view:open(state(10, hatch))
			assert(view.ackReady and not view.cinematic.active and selections == 1 and #sent == 0)
		end)
		test("Same-ID save recovery preserves generation, hero and presentation history", function()
			local Notice = require(client.SaveNotice)
			local hatch = result("save-reconcile")
			local view, sent = fixture(hatch)
			local epoch, hero, generation = view.cinematic.epoch, view.cinematic.heroViewport, view.presentationGeneration
			local selected = view.selected
			view:update(state(10, hatch, "Retrying"))
			view:setSaveNotice(Notice.resolve(nil, "Retrying"))
			assert(view.revealHost.Parent == view.body and view.cinematic.heroViewport == hero and hero.Parent)
			assert(view.cinematic.epoch == epoch and view.presentationGeneration == generation and view.lastPresentedId == hatch.id)
			assert(not view.meetButton.Interactable and #sent == 0)
			view:update(state(11, hatch)); view:setSaveNotice(nil)
			assert(view.cinematic.epoch == epoch and view.cinematic.heroViewport == hero and view.selected == selected)
			assert(view.ackReady and view.meetButton.Interactable and view.action.Interactable and #sent == 0)
		end)
		test("Confirmed Ember themes the result shell and peach Meet action", function()
			local Art = require(client.DeckArt)
			local Themes = require(game.ReplicatedStorage.Shared.DeckThemes)
			local previous = Art.getTheme()
			local view = fixture(result("ember-result"))
			Art.applyTheme(Themes.ById.brick)
			local themed, reason = pcall(function()
				assert(view.card:GetAttribute("ContentSurface") == true)
				assert(view.card.BackgroundColor3 == Themes.ById.brick.ui.contentPanel)
				assert(view.revealHost.BackgroundColor3 == Themes.ById.brick.ui.contentInset)
				assert(not view.card:FindFirstChild("Accent")and not view.card:FindFirstChild("MoldHighlight")and not view.card:FindFirstChild("UpperSheen"))
				assert(view.meetButton.BackgroundColor3 == Themes.ById.brick.buttons and view.meetButton.TextColor3 == Themes.ById.brick.ui.ink)
				assert(view.heading.TextColor3 == Themes.ById.brick.ui.contentText and view.note.TextColor3 == Themes.ById.brick.ui.contentMuted)
			end)
			Art.applyTheme(previous)
			assert(themed, reason)
		end)
		test("Result layout measurement is independent of the previously painted text size", function()
			local Notice=require(client.SaveNotice)
			root.Size=UDim2.fromOffset(733,307)
			for _=1,3 do game:GetService("RunService").Heartbeat:Wait() end
			local hatch=result("canonical-measurement")
			local view=fixture(hatch)
			local normalH=math.max(1,view.card.Size.Y.Offset-80)
			local trialW=math.max(1,view.card.Size.X.Offset-20)
			local minimum=view.cinematic:minimumHeightForWidth(trialW,normalH)
			local stage,epoch,hero=view.revealHost.Size,view.cinematic.epoch,view.cinematic.heroViewport
			local expectedParent=if minimum>normalH then view.body else view.card
			-- Simulate typography left over from another candidate; measuring must
			-- use the proposed canonical role, rather than these painted properties.
			view.cinematic.heading.TextSize=10;view.cinematic.caption.TextSize=10;view.cinematic.tag.TextSize=10
			assert(view.cinematic:minimumHeightForWidth(trialW,normalH)==minimum)
			view:layout();view.cinematic:layout();view:layout()
			assert(view.revealHost.Size==stage and view.revealHost.Parent==expectedParent)
			for _,notice in ipairs({"Retrying","Unavailable"})do
				view:setSaveNotice(Notice.resolve(nil,notice));view:layout();view:setSaveNotice(nil);view:layout()
				assert(view.revealHost.Size==stage and view.revealHost.Parent==expectedParent)
				assert(view.cinematic.epoch==epoch and view.cinematic.heroViewport==hero and view.ackReady)
			end
			view:close();root.Size=UDim2.fromOffset(360,580)
			for _=1,3 do game:GetService("RunService").Heartbeat:Wait() end
		end)
		test("Short animated same-ID layout and notice reparent retain active ownership", function()
			local Notice = require(client.SaveNotice)
			root.Size=UDim2.fromOffset(360,166)
			for _=1,3 do game:GetService("RunService").Heartbeat:Wait() end
			local hatch=result("short-active-owner")
			local view, sent, _, sounds=fixture(hatch,nil,false)
			assert(view.resultScrollable and view.cinematic.active)
			local epoch,age,hero,heard=view.cinematic.epoch,view.cinematic.age,view.cinematic.heroViewport,#sounds
			view:update(state(10,hatch));view:layout()
			view:setSaveNotice(Notice.resolve(nil,"Retrying"));view:update(state(10,hatch));view:layout()
			view:setSaveNotice(nil);view:layout()
			assert(view.cinematic.active and view.cinematic.epoch==epoch and view.cinematic.age==age)
			assert(view.cinematic.heroViewport==hero and #sounds==heard and #sent==0, "benign layout interrupted or replayed the intro")
			view:close();root.Size=UDim2.fromOffset(360,580)
			for _=1,3 do game:GetService("RunService").Heartbeat:Wait() end
		end)
		test("Short result captions remain reachable in the single body without covering X", function()
			local function settle() for _=1,3 do game:GetService("RunService").Heartbeat:Wait() end end
			local function visibleOverlap(a,b)
				local p,s,bp,bs=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
				return p.X<bp.X+bs.X and bp.X<p.X+s.X and p.Y<bp.Y+bs.Y and bp.Y<p.Y+s.Y
			end
			for _,height in ipairs({128,166,198}) do
				root.Size = UDim2.fromOffset(360,height); settle()
				local hatch = result("truthful-short-"..height)
				hatch.duplicate = true
				local view = fixture(hatch,nil,true,function(instance)
					local snapshot=state(10,hatch)
					snapshot.masteryDetails={wick={rank=2,points=18,nextPoints=25,challenges=1,challengeGoal=3}}
					return snapshot
				end)
				local snapshot=state(10,hatch)
				snapshot.masteryDetails={wick={rank=2,points=18,nextPoints=25,challenges=1,challengeGoal=3}}
				view:update(snapshot);settle()
				local epoch,hero=view.cinematic.epoch,view.cinematic.heroViewport
				assert(view.resultScrollable and view.revealHost.Parent==view.body and view.body.AbsoluteSize.Y>=44)
				assert(not visibleOverlap(view.body,view.closeButton) and not visibleOverlap(view.body,view.action))
				for _,name in ipairs({"PetName","CollectionStatus"}) do
					local label=view.cinematic.frame:FindFirstChild(name,true)
					assert(label and label.TextFits,name.." must retain complete truthful text at "..height)
					local top=label.AbsolutePosition.Y-view.body.AbsolutePosition.Y+view.body.CanvasPosition.Y
					local maximum=math.max(0,view.body.CanvasSize.Y.Offset-view.body.AbsoluteSize.Y)
					for _,target in ipairs({top,top+label.AbsoluteSize.Y-view.body.AbsoluteSize.Y}) do
						view.body.CanvasPosition=Vector2.new(0,math.clamp(target,0,maximum));settle()
						assert(label.AbsolutePosition.Y<view.body.AbsolutePosition.Y+view.body.AbsoluteSize.Y and label.AbsolutePosition.Y+label.AbsoluteSize.Y>view.body.AbsolutePosition.Y,name.." cannot be reached")
					end
				end
				local caption=view.cinematic.frame:FindFirstChild("CollectionStatus",true)
				assert(caption.Text == "Already owned · no additional reward" and not view.cinematic.frame:FindFirstChild("Mastery",true))
				local offset=view.body.CanvasPosition
				view:update(snapshot)
				assert(view.cinematic.epoch==epoch and view.cinematic.heroViewport==hero and view.body.CanvasPosition==offset)
				view:close()
			end
			root.Size=UDim2.fromOffset(360,580);settle()
		end)
		test("44px result actions fit short landscape safe areas and long names", function()
			for _, height in ipairs({ 128, 166, 198, 580 }) do
				root.Size = UDim2.fromOffset(360, height)
				local view = fixture(result("layout-" .. height))
				task.wait(0.08)
				for _, node in ipairs({ view.meetButton, view.action, view.closeButton }) do
					assert(node.AbsoluteSize.Y == 44 and node.TextFits, node.Name .. " must fit at " .. height)
					assert(node.AbsolutePosition.Y >= root.AbsolutePosition.Y)
					assert(node.AbsolutePosition.Y + 44 <= root.AbsolutePosition.Y + height)
				end
				assert(view.closeButton.AbsolutePosition.Y + 44 <= view.meetButton.AbsolutePosition.Y, "Close must not overlap footer")
				view:close()
			end
		end)
	end)
	for _, view in ipairs(views) do view:close(); view.shade:Destroy() end
	root:Destroy()
	assert(ok, problem)
	return { passed = #cases, cases = cases }
end
