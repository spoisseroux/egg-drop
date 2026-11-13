-- Actual default framebuffer overlay layering for the redesigned danger state
-- (UI-SPEC-REDESIGN-MENUS 6.3): fill line, tag, haze and chip above the LCD at the
-- unchanged physical threshold; one entry cue, no repeating blip. Client-local
-- attribute writes only; the previous values are restored.
return function(gui,board)
	local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local RunService=game:GetService("RunService")
	local b=gui.Backdrop;local overlay=b:FindFirstChild("TrayOverlay",true);local tray=b:FindFirstChild("Tray",true)
	assert(gui.Enabled and b.Visible and board:GetAttribute("Mode")=="Board","uncovered enabled Board required")
	local surface=overlay:FindFirstChild("JellyLCDSpans")or overlay:FindFirstChild("JellyLCD")
	assert(surface and surface.Visible,"run with the actual default pixel renderer")
	local line,chip,haze=overlay.FillLine,overlay.DangerChip,overlay.DangerHaze
	for _,name in ipairs({"OverflowLine","DangerText","DangerTrack","MatchHint"})do assert(not overlay:FindFirstChild(name),name.." should be gone") end
	local previous,previousLeft=board:GetAttribute("OverflowPressure"),board:GetAttribute("OverflowGraceLeft");local danger=board:GetAttribute("DangerY")
	local cases={};local function settle()for _=1,4 do RunService.RenderStepped:Wait()end end
	local function test(name,run)run();table.insert(cases,name)end
	local function set(p,g)board:SetAttribute("OverflowPressure",p);board:SetAttribute("OverflowGraceLeft",g)end
	local ok,problem=pcall(function()
		test("calm fill line sits above the opaque LCD at the unchanged physical threshold",function()
			set(0,0);settle()
			local scale=tray.AbsoluteSize.X/(Config.Width+.8)
			local expected=tray.AbsoluteSize.Y/2-((danger or Config.OverflowY)-Config.Height/2)*scale
			assert(line.Visible and line.ZIndex>surface.ZIndex and line.Dashes.Visible and not line.Bar.Visible,"calm line")
			assert(math.abs(line.Position.Y.Offset-expected)<=1,"line moved off the threshold")
			assert(line.Tag.Visible and line.Tag.Text=="FILL LINE"and line.Tag.TextFits,"tag")
			assert(not chip.Visible and not haze.Visible)
		end)
		test("over the line: chip and haze above the framebuffer, amber, line drains",function()
			set(.6,1.1);settle()
			assert(chip.Visible and chip.ZIndex>line.ZIndex and haze.ZIndex>surface.ZIndex,"chip/haze layering")
			assert(chip.Title.Text=="Stack too high"and chip.Detail.Text=="Merge to clear"and chip.Title.TextFits and chip.Detail.TextFits)
			assert(chip.AbsoluteSize.X<=tray.AbsoluteSize.X,"chip wider than the board")
			assert(line.Bar.Visible and line.Bar.BackgroundColor3==Color3.fromHex("#FFB02E")and line.Bar.Size.X.Scale<=1)
			assert(board:GetAttribute("DangerY")==danger,"presentation changed overflow physics")
		end)
		test("last 0.35 s is red",function()
			set(.9,.3);settle()
			assert(line.Bar.BackgroundColor3==Color3.fromHex("#FF5A6E")and chip.Detail.Text=="Merge now")
		end)
		test("the overflow blip is gone; the entry cue never repeats",function()
			local SoundService=game:GetService("SoundService")
			assert(not SoundService:FindFirstChild("EggDrop_overflow"),"repeating overflow voice still registered")
			local voice=SoundService:FindFirstChild("EggDrop_danger_enter")
			set(0,0);settle()
			if voice then
				local plays=0;local c=voice.Played:Connect(function()plays+=1 end)
				set(.6,1.1);local started=os.clock()
				while os.clock()-started<1.2 do RunService.RenderStepped:Wait()end
				c:Disconnect();assert(plays<=1,"entry cue repeated: "..plays)
			end
			set(0,0);settle()
		end)
	end)
	board:SetAttribute("OverflowPressure",previous);board:SetAttribute("OverflowGraceLeft",previousLeft);settle();assert(ok,problem)
	return{passed=#cases,cases=cases,localPresentationOnly=true}
end
