-- Studio Client presentation fixtures. No remotes or progression writes.
return function(client, parent)
	local Recap = require(client.RoundRecap)
	local Catalog = require(game:GetService("ReplicatedStorage").Shared.EggCatalog)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_RecapFeedbackSpec", UDim2.fromOffset(360, 236), 1, parent
	local reduced, sounds = false, {}
	local audio = { group = { Volume = 1 } }
	function audio:play(name, speed, volume)
		if self.group.Volume ~= 0 then table.insert(sounds, { name, speed, volume }) end
	end
	local recap = Recap.new(root, audio, function() return reduced end)
	recap.frame.Visible = true
	local cases = {}
	local function fitDiagnostic(...)
		local rows={}
		for _,node in ipairs({...})do
			table.insert(rows,string.format("%s text=%q size=%s bounds=%s position=%s fontSize=%s visible=%s fits=%s",
				node:GetFullName(),node.Text,tostring(node.AbsoluteSize),tostring(node.TextBounds),tostring(node.AbsolutePosition),
				tostring(node.TextSize),tostring(node.Visible),tostring(node.TextFits)))
		end
		return table.concat(rows," | ")
	end
	local function test(name, run) run(); table.insert(cases, name) end
	local function result(sequence, changes)
		local value = { sequence = sequence, status = "Saved", success = true, stage = 2, reason = "Completed",
			award = 14, daily = 6, balance = 20, recipe = Catalog.ById.meadow,
			reward = { sequence = sequence, total = 14, base = 8, daily = 6, family = "pip", masteryPoints = 2, contracts = { "chain", "score" } } }
		for key, item in pairs(changes or {}) do value[key] = item end
		return value
	end
	local function show(value)
		recap:update(630, 4, 2, nil, 0, nil, 0, 700)
		recap:updateField(value)
		-- Advance deterministically without waiting for native rendering frames.
		if recap.feedback.connection then recap.feedback.connection:Disconnect(); recap.feedback.connection = nil end
	end
	local ok, problem = pcall(function()
		test("matching committed receipt starts once and retains count through HUD refresh", function()
			local value = result(1)
			show(value)
			assert(recap.feedback.active and recap.feedback.starts == 1 and recap.values[1].Text == "0")
			recap.feedback:step(.2)
			local count = recap.values[1].Text
			show(value)
			assert(recap.feedback.starts == 1 and recap.values[1].Text == count)
			assert(recap.bankGraphic.Text == "Nectar saved: 20" and value.balance == 20 and value.reward.total == 14)
		end)
		test("count up lands on exact score chain clears and earned nectar", function()
			recap.feedback:step(.66)
			assert(recap.values[1].Text == "630" and recap.values[2].Text == "×4" and recap.values[3].Text == "2")
			assert(recap.transfer.Visible and recap.bankGraphic.Text == "Nectar saved: 20")
			recap.feedback:step(.8)
			assert(not recap.feedback.active and not recap.transfer.Visible)
			assert(recap.earnedGraphic.Text == "+14 nectar" and recap.scales[1].Scale == 1)
			assert(#sounds > 0 and recap.feedback.connection == nil)
		end)
		test("hide cancels immediately and reopening the same receipt cannot replay", function()
			show(result(2)); recap.feedback:step(.1)
			recap.frame.Visible = false
			assert(not recap.feedback.active and recap.values[1].Text == "630" and recap.feedback.connection == nil)
			local count, starts = #sounds, recap.feedback.starts
			recap.frame.Visible = true; show(result(2))
			assert(not recap.feedback.active and #sounds == count and recap.feedback.starts == starts)
		end)
		test("hidden ancestor cancels and does not consume a future receipt", function()
			root.Visible = false; show(result(3))
			assert(not recap.feedback.active)
			root.Visible = true; show(result(3)); assert(recap.feedback.active)
			root.Visible = false; assert(not recap.feedback.active and not recap.transfer.Visible)
			root.Visible = true
		end)
		test("Saving delayed and pending states suppress old receipt and currency transfer", function()
			for index, change in ipairs({ { status = "Saving" }, { status = "Save delayed" }, { receiptPending = true } }) do
				show(result(10 + index, change))
				assert(not recap.feedback.active and not recap.hasReceipt and not recap.transfer.Visible)
				assert(not recap.earnedGraphic.Visible and not recap.bankGraphic.Visible and not recap.fill.Parent.Visible)
				assert(recap.receiptLines == nil and not recap.title.Text:find("20/18", 1, true))
			end
		end)
		test("stale sequence cannot announce the previous reward", function()
			local value = result(20); value.reward.sequence = 19
			show(value)
			assert(not recap.hasReceipt and not recap.feedback.active and recap.title.Text == "Loading receipt…")
			value.reward.sequence = 20; show(value); assert(recap.feedback.active)
		end)
		test("new receipt cancels the old animation and reinitializes every counter", function()
			recap.feedback:step(.4); show(result(21))
			assert(recap.feedback.active and recap.feedback.age == 0 and recap.values[1].Text == "0")
			recap.feedback:step(2); assert(recap.values[1].Text == "630")
		end)
		test("daily only failure retains missed side quest zero and exact total", function()
			local value = result(22, { success = false, stage = 1, award = 6, daily = 6, balance = 12 })
			value.reward.total, value.reward.base, value.reward.masteryPoints = 6, 0, 0
			show(value); recap.feedback:step(2)
			assert(recap.fieldHeading == "RIGHT goal missed" and recap.earnedGraphic.Text == "+6 nectar")
			assert(recap.receiptLines[1] == "Quest nectar +0" and recap.bankGraphic.Text == "Nectar saved: 12")
		end)
		test("zero earned never invents nectar drops or transfer sounds", function()
			local value = result(23, { success = false, stage = 0, award = 0, daily = 0, balance = 6 })
			value.reward.total, value.reward.base, value.reward.daily, value.reward.masteryPoints = 0, 0, 0, 0
			value.reward.contracts = {}
			show(value); recap.feedback:step(.85)
			local count = #sounds
			assert(recap.earnedGraphic.Text == "+0 nectar" and not recap.transfer.Visible)
			recap.feedback:step(.6)
			assert(#sounds == count and recap.fieldHeading == "LEFT goal missed")
		end)
		test("reduced effects shows final static values with no recap cues", function()
			reduced = true
			local count = #sounds
			show(result(24))
			assert(not recap.feedback.active and recap.earnedGraphic.Text == "+14 nectar" and #sounds == count)
			reduced = false; show(result(25)); reduced = true; recap.feedback:step(.01)
			assert(not recap.feedback.active and recap.values[1].Text == "630")
			reduced = false
		end)
		test("audio remains routed through the muted shared audio group", function()
			audio.group.Volume = 0
			local count = #sounds
			show(result(26)); recap.feedback:step(2)
			assert(#sounds == count and recap.earnedGraphic.Text == "+14 nectar")
		end)
		test("short recap scrolls readable center while excluding pinned footer",function()
			reduced=true
			for _,height in ipairs({128,166,198,236}) do
				root.Size=UDim2.fromOffset(360,height);task.wait(.06);show(result(30+height));task.wait(.06)
				assert(recap.fieldBody.Position.Y.Offset+recap.fieldBody.Size.Y.Offset<=height-60)
				assert(recap.earnedGraphic.TextFits and recap.bankGraphic.TextFits and recap.eggGoal.TextFits,fitDiagnostic(recap.earnedGraphic,recap.bankGraphic,recap.eggGoal))
				assert(not recap.earnedGraphic.TextScaled and recap.earnedGraphic.TextSize>=26)
				assert(recap.detailsButton.Visible and not recap.receiptScroll.Visible)
				recap:setDetails(true)
				game:GetService("RunService").RenderStepped:Wait();game:GetService("RunService").RenderStepped:Wait()
				for _,row in ipairs(recap.receiptRows) do assert(row.TextFits and row.TextSize>=14 and not row.TextScaled,fitDiagnostic(row)) end
			end
		end)
		test("roomy recap follows reward egg metrics details and keeps saved values",function()
			root.Size=UDim2.fromOffset(600,500);task.wait(.06);show(result(450));task.wait(.06)
			assert(recap.detailsButton.Visible and recap.detailsButton.AbsoluteSize.Y>=44 and recap.detailsButton.TextFits,fitDiagnostic(recap.detailsButton))
			assert(not recap.receiptScroll.Visible and recap.stats.Visible)
			assert(recap.earnedGraphic.Position.Y.Offset<recap.eggPanel.Position.Y.Offset and recap.eggPanel.Position.Y.Offset<recap.stats.Position.Y.Offset)
			assert(recap.values[1].Text=="630" and recap.bestValue.Text=="700" and recap.values[2].Parent.Label.Text=="Longest chain")
			assert(recap.componentLabels[1].Text=="Quest +8" and recap.componentLabels[2].Text=="Daily +6")
			assert(recap:scrollReceipt(1) and recap.detailsOpen and recap.receiptScroll.Visible)
			local signature=recap.receiptSignature;show(result(450));assert(recap.detailsOpen and recap.receiptSignature==signature)
			recap:setDetails(false);assert(not recap.receiptScroll.Visible)
			show(result(451));assert(not recap.detailsOpen and recap.shortfall.Text=="Ready to hatch")
		end)
		test("selected egg progress draws above its panel and retains partial or full saved balance",function()
			reduced=true
			for _,balance in ipairs({9,18,25}) do
				show(result(600+balance,{balance=balance}))
				assert(recap.fill.Parent.ZIndex>recap.eggPanel.ZIndex and recap.fill.ZIndex>recap.fill.Parent.ZIndex)
				assert(math.abs(recap.fill.Size.X.Scale-math.clamp(balance/18,0,1))<.00001)
				assert(recap.bankGraphic.Text=="Nectar saved: "..balance)
				for _,label in ipairs({recap.eggGoal,recap.bankGraphic,recap.shortfall}) do assert(label.TextXAlignment==Enum.TextXAlignment.Left) end
			end
		end)
		test("first Saved receipt survives synchronous resize during publication",function()
			local isolated=Recap.new(root,nil,true);isolated.frame.Visible=true
			local title=isolated.title;local calls=0
			-- Force the same callback path synchronously from the first title write,
			-- independent of Studio's Immediate/Deferred signal setting.
			isolated.title=setmetatable({},{
				__index=function(_,key)
					local value=title[key]
					if type(value)=="function" then return function(_,...)return value(title,...)end end
					return value
				end,
				__newindex=function(_,key,value)
					title[key]=value
					if key=="Text" and isolated.updatingField then
						calls+=1
						assert(isolated.displayRecipe==Catalog.ById.meadow and isolated.displayCost==18 and isolated.displayBalance==20 and isolated.displayReward==14,"partial canonical presentation exposed")
						isolated.frame.Size=UDim2.fromOffset(600,500)
						isolated:layoutField(500)
					end
				end,
			})
			local passed,problem=pcall(function()isolated:updateField(result(701))end)
			isolated.title=title
			assert(passed,problem);assert(calls>0 and isolated.hasReceipt and isolated.updatingField==false)
			isolated:layoutField(500)
			assert(isolated.eggGoal.Text:find("18 nectar",1,true) and isolated.bankGraphic.Text=="Nectar saved: 20")
			isolated.frame:Destroy()
		end)
		test("destroying the component removes its animation connection", function()
			reduced = false; show(result(500))
			assert(recap.feedback.active)
			recap.frame:Destroy()
			assert(not recap.feedback.active and recap.feedback.connection == nil)
		end)
	end)
	root:Destroy()
	assert(ok, problem)
	return { passed = #cases, cases = cases }
end
