-- Client: require(PlayerScripts.Client.ZZSpecs.DeckQuests)(PlayerScripts.Client)
-- Difficulty picker and quest log focus order, claim/reroll routing and the
-- results payout rows (QUESTS-DIFFICULTY-PLAN section 8, "Client").
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

	test("results payout rows: difficulty share, signs and the pass line", function()
		local host = overlay()
		local results = Results.new(host.content, {})
		results:show({ outcome = "clear", title = "Bank pair", difficulty = "Easy", earned = 11, total = 11, balance = 17,
			rows = { { name = "Round win", amount = 6 }, { name = "Easy ×0.8", amount = -1 }, { name = "Pass bonus", amount = 6 } },
			goals = {}, score = 0, best = 0, chain = 0 }, false)
		assert(results.rows[1].amount.Text == "6" and results.rows[2].amount.Text == "−1" and results.rows[3].amount.Text == "+6")
		assert(results.subline.Text:find("Easy") and results.hintRight.Text == "Replay keeps Easy.")
		results:hide()
	end)

	gui:Destroy()
	return { passed = #passed, cases = passed }
end
