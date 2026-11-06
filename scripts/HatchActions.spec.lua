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
	local function fixture(hatch, transport, reduced)
		local sent, completed = {}, {}
		local view
		view = View.new(root, { play = function() end }, function() return reduced ~= false end, function(command, value, revision)
			table.insert(sent, { command = command, value = value, revision = revision })
			if transport then transport(view, command, value, revision) end
		end)
		table.insert(views, view)
		view.onClosed = function(reason, choice)
			assert(view.ackIntent == nil, "intent must be dequeued before navigation")
			table.insert(completed, { reason = reason, choice = choice })
		end
		view:open(state(10, hatch or result()))
		return view, sent, completed
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
		test("Actions remain locked during an unfinished cinematic", function()
			local view, sent = fixture(result("animating"), nil, false)
			view:chooseResult("meet"); assert(#sent == 0 and not view.meetButton.Interactable and not view.action.Interactable)
			view.cinematic:finishStatic(); view:chooseResult("meet"); assert(#sent == 1)
		end)
		test("Duplicate caption uses copied mastery progress and retains both choices", function()
			local hatch = result("duplicate")
			hatch.duplicate, hatch.mastery = true, 18
			local view = fixture(hatch)
			view:close()
			local snapshot = state(10, hatch)
			snapshot.masteryDetails = { wick = { rank = 2, points = 18, nextPoints = 25, challenges = 1, challengeGoal = 3 } }
			view:open(snapshot)
			assert(hatch.masteryHint == nil and view.cinematic.result.masteryHint:find("18/25", 1, true))
			assert(view.cinematic.result.masteryHint:find("1/3 challenges", 1, true))
			assert(view.meetButton.Interactable and view.action.Interactable)
			hatch.promotedTo = 2
			view:close(); view:open(snapshot)
			local caption = view.cinematic.frame:FindFirstChild("Mastery", true)
			assert(caption and caption.Text:find("rank II unlocked!", 1, true), "promotion must take precedence over progress hint")
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
