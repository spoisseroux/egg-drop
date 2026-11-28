-- Does the game window have focus? (beta 44 note 13, DIAGNOSIS "shared root suspicion"; ARCH-REVIEW-SIMPLIFY 10). Spencer
-- alt-tabs to type notes: the lessons' ignore clock, the gift bubbles' nudge and park clocks and the Show me ring count
-- only focused time, so nothing is parked or skipped while he is away. WindowFocusReleased sets it false; WindowFocused,
-- or any input at all (the focused event may never come), sets it true again. One shared state; started on first use.
local Focus={}
Focus.state=true
Focus.lostAt=nil -- os.clock() when focus was last lost (nil while focused)
-- Pure: the state after an event ("lost", "gained", "input").
function Focus.after(state,event)
	if event=="lost"then return false end
	if event=="gained"or event=="input"then return true end
	return state
end
function Focus.set(event)
	local before=Focus.state
	Focus.state=Focus.after(Focus.state,event)
	if before and not Focus.state then Focus.lostAt=os.clock()elseif Focus.state then Focus.lostAt=nil end
end
function Focus.start()
	if Focus.started then return end
	Focus.started=true
	local ok,UIS=pcall(function()return game:GetService("UserInputService")end)
	if not ok or not UIS then return end
	pcall(function()
		UIS.WindowFocusReleased:Connect(function()Focus.set("lost")end)
		UIS.WindowFocused:Connect(function()Focus.set("gained")end)
		UIS.InputBegan:Connect(function()Focus.set("input")end)
	end)
end
function Focus.focused()
	if not Focus.started then Focus.start()end
	return Focus.state
end
return Focus
