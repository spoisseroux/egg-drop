-- Client: require(PlayerScripts.Client.ZZSpecs.DeckQuests)(PlayerScripts.Client)
-- Difficulty picker and quest log focus order, claim/reroll routing and the
-- results payout rows (QUESTS-DIFFICULTY-PLAN section 8, "Client"). QA v2 R3: the
-- shared header (back arrow, 3D wallet, ? circle), status words and reward chips,
-- the claim celebration and the stamp card on the daily tab.
return function(client)
	local Picker = require(client.DifficultyPicker)
	local Log = require(client.QuestLog)
	local Results = require(client.DeckResults)
	local passed = {}
	local function test(name, fn) fn(); table.insert(passed, name) end
	local gui = Instance.new("ScreenGui"); gui.Name = "_DeckQuestsSpec"; gui.Parent = game.Players.LocalPlayer.PlayerGui
	local function overlay()
		local layer = Instance.new("Frame"); layer.Size = UDim2.fromOffset(848, 608); layer.Parent = gui
		local content = Instance.new("Frame"); content.Size = UDim2.fromOffset(848, 608); content.Parent = layer
		return { layer = layer, content = content, scale = Instance.new("UIScale", content) }
	end
	local function row(slot, over)
		local r = { slot = slot, id = "d_wins2", title = "Win 2 rounds", sub = "Any difficulty", pool = "play", progress = 0, target = 2,
			reward = 4, claimed = false, ready = false, canReroll = true }
		for k, v in pairs(over or {}) do r[k] = v end
		return r
	end
	local function quests(daily)
		return { day = "20404", week = "2915", daily = daily, weekly = { row(1, { canReroll = false }), row(2, { canReroll = false }), row(3, { canReroll = false }) },
			history = { { d = "20404", id = "d_wins2", title = "Win 2 rounds", s = 4, a = false, weekly = false } },
			rerollLeft = 1, bonus = { reward = 5, claimed = false, ready = false }, bonusReady = false, resetIn = 3600 * 7 + 60 * 12, weekResetIn = 86400 * 3 + 3600 * 7 }
	end

	test("picker: no wrap, Medium first, server numbers only", function()
		assert(Picker.step(1, -1) == 1 and Picker.step(3, 1) == 3 and Picker.step(2, 1) == 3)
		assert(Picker.paysText({ hard = { 9, 12 } }, "hard") == "Win pays 9 to 12" and Picker.paysText({}, "hard") == nil)
		local started, selected
		local p = Picker.new(overlay(), { start = function(k) started = k end, select = function(k) selected = k end })
		p:show({ selected = "medium", pays = { easy = { 5, 6 }, medium = { 6, 8 }, hard = { 9, 12 } }, wallet = 128, goal = "Creek crossing" })
		assert(p:selected() == "medium" and p.cards[3].pays.Text == "Win pays 9 to 12" and p.cards[1].pays.Text == "Win pays 5 to 6")
		p:move(1); assert(selected == "hard"); p:move(1); assert(p:selected() == "hard")
		p:confirm(); assert(started == "hard")
		-- Touch: tapping another card selects it; tapping it again starts.
		p:focus(1); assert(p:selected() == "easy")
		p:hide(); assert(not p.visible and not p:confirm())
	end)

	test("log: focus lands on the first Ready claim, then a reroll, then row 1", function()
		assert(Log.initialFocus({ row(1), row(2, { ready = true }), row(3) }) == 2)
		assert(Log.initialFocus({ row(1, { canReroll = false }), row(2, { canReroll = false }), row(3) }) == 3)
		assert(Log.initialFocus({ row(1, { canReroll = false }) }) == 1)
		assert(Log.initialFocus({ row(1, { canReroll = false }) }, true) == 4, "weekly bonus claim")
		assert(Log.action(row(1, { ready = true })) == "claim" and Log.action(row(1), 1) == "reroll" and Log.action(row(1), 0) == nil)
		assert(Log.action(row(1, { progress = 1, canReroll = false }), 1) == nil)
		assert(Log.resetText(3600 * 7 + 60 * 12) == "New in 7 h 12 m" and Log.resetText(86400 * 3 + 3600 * 7) == "New in 3 d 7 h")
	end)

	test("log: claim and reroll go to the server once, tabs switch with L/R", function()
		local claims, rerolls = {}, {}
		local log = Log.new(overlay(), { claim = function(s, slot, period) table.insert(claims, s .. slot .. period) end,
			reroll = function(slot, day) table.insert(rerolls, slot .. day) end })
		log:show(quests({ row(1, { progress = 2, ready = true, canReroll = false }), row(2), row(3, { progress = 1, canReroll = false }) }), 50)
		assert(log.tab == "daily" and log.focusIndex == 1)
		assert(log:act() and claims[1] == "daily120404")
		assert(not log:act(), "a pending claim is not sent twice")
		log:result({ action = "questClaim", scope = "daily", slot = 1, status = "Saved" })
		log:move(1); assert(log.focusIndex == 2)
		assert(log:act() and rerolls[1] == "220404")
		log:move(1); assert(log.focusIndex == 3 and not log:act(), "a started quest has no action")
		log:move(1); assert(log.focusIndex == 3, "focus never wraps")
		assert(log:cycleTab(1) and log.tab == "weekly" and log.title.Text == "This week")
		assert(log:cycleTab(1) and log.tab == "history" and log.history.Visible)
		assert(not log:cycleTab(1) and log.tab == "history")
		log:hide()
	end)

	test("log: weekly bonus is the fourth focus target once all three are claimed", function()
		local claims = {}
		local log = Log.new(overlay(), { claim = function(s, slot, period) table.insert(claims, s .. slot .. period) end })
		local q = quests({ row(1), row(2), row(3) })
		for _, r in ipairs(q.weekly) do r.claimed = true; r.progress = r.target end
		q.bonusReady, q.bonus.ready = true, true
		log:show(q, 50, "weekly")
		assert(log.focusIndex == 4 and log.bonusClaim.Visible)
		assert(log:act() and claims[1] == "weekly02915")
		log:hide()
	end)

	test("log R3: shared header with back, wallet and the Quests ? circle; status words and reward chips", function()
		local backs = 0
		local log = Log.new(overlay(), { back = function() backs += 1 end })
		assert(log.header and log.header.back and log.header.wallet, "shared header with back arrow and wallet")
		assert(log.header.help and log.header.help.root:GetAttribute("HelpId") == "quests", "? opens the Quests cards")
		local g = log.header.geometry
		assert(g.help and g.help.x + g.help.w <= g.wallet.x - 8 + 0.5 and g.title.x + g.title.w <= g.help.x - 12, "? sits left of the capsule, the title stops before it")
		local helped
		local Kit = require(client.DeckKit)
		local savedHelp = Kit.onHelp; Kit.onHelp = function(id) helped = id; return true end
		Kit.openHelp(log.header.help.root:GetAttribute("HelpId")); Kit.onHelp = savedHelp
		assert(helped == "quests")
		log:show(quests({ row(1, { progress = 2, ready = true, canReroll = false }), row(2, { progress = 1, target = 4, canReroll = false }), row(3) }), 50)
		assert(Log.status(row(1)) == "Not started" and Log.status(row(1, { progress = 1, target = 4 })) == "3 to go")
		assert(select(2, Log.status(row(1, { ready = true }))) == "stars" and Log.status(row(1, { claimed = true })) == "Claimed")
		assert(log.rows[1].row:GetAttribute("Status") == Log.status(row(1, { ready = true })), "ready row says so")
		assert(log.rows[2].row:GetAttribute("Status") == "3 to go" and log.rows[3].row:GetAttribute("Status") == "Not started")
		assert(log.rows[1].reward.Text == "+4" and log.rows[1].rewardChip:GetAttribute("Reward") == 4, "reward chip with the Star")
		assert(log.rows[1].rewardChip.Rotation ~= 0 and log.rows[2].rewardChip.Rotation == 0, "the ready chip is a tilted gold sticker")
		assert(log.rows[1].sub.Text == "Any difficulty", "the what-to-do line")
		log:hide()
	end)

	test("log R3: a saved claim celebrates (pop, then gone); the stamp card sits on the daily tab and stamps once", function()
		local stamps, claims = {}, {}
		local snapshot = { stamps = 3, dailyAvailable = true, dailyDay = "20404", stampCard = nil }
		local host = overlay()
		local log = Log.new(host, { claim = function(s, slot) table.insert(claims, s .. slot) end,
			stampState = function() return snapshot end, stamp = function(day) table.insert(stamps, day) end })
		log:show(quests({ row(1, { progress = 2, ready = true, canReroll = false }), row(2), row(3) }), 50)
		assert(log.panel and log.panel.Visible and log.stampButton.Visible, "stamp card on the daily tab")
		assert(log.stampView.root:GetAttribute("Filled") == 3, "three stamps on the card")
		assert(log:act() and claims[1] == "daily1")
		log:result({ action = "questClaim", scope = "daily", slot = 1, status = "Saved", stars = 4 })
		assert(host.content:GetAttribute("LastCelebration") == 4 and host.content:FindFirstChild("ClaimPop"), "the claim pops +4")
		task.wait(Log.CelebrateSeconds + 0.5)
		assert(not host.content:FindFirstChild("ClaimPop") and not host.content:FindFirstChild("ClaimBurst"), "the celebration cleans up")
		-- Focus walks down to the stamp (index 5) and A stamps today, once.
		log.focusIndex = 3; log:move(1); assert(log.focusIndex == Log.StampFocus, "down from the last row reaches the stamp")
		assert(log:act() and stamps[1] == "20404"); assert(not log:act(), "a stamp in flight is not sent twice")
		snapshot = { stamps = 4, dailyAvailable = false, dailyDay = "20404" }
		log:refreshStamp()
		assert(not log.stampButton.Visible and log.stampDone.Visible, "stamped for today")
		log:setTab("weekly"); assert(not log.panel.Visible, "the stamp card is daily only")
		log:hide()
	end)

	test("results payout rows: difficulty share, signs and the pass line", function()
		local host = overlay()
		local results = Results.new(host.content, {})
		results:show({ outcome = "clear", title = "Bank pair", difficulty = "Easy", earned = 11, total = 11, balance = 17,
			rows = { { name = "Round win", amount = 6 }, { name = "Easy ×0.8", amount = -1 }, { name = "Pass bonus", amount = 6 } },
			goals = {}, score = 0, best = 0, chain = 0 }, false)
		assert(results.rows[1].amount.Text == "6" and results.rows[2].amount.Text == "−1" and results.rows[3].amount.Text == "+6")
		assert(results.subline.Text:find("Easy") and results.hintRight.Text:find("Replay keeps Easy.", 1, true))
		results:hide()
	end)

	gui:Destroy()
	return { passed = #passed, cases = passed }
end
