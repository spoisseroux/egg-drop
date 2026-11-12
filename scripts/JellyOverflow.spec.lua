-- Actual default framebuffer overlay layering; client-local pressure is restored.
return function(gui,board)
	local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local Art=require(game:GetService("Players").LocalPlayer.PlayerScripts.Client.DeckArt)
	local RunService=game:GetService("RunService")
	local b=gui.Backdrop;local overlay=b:FindFirstChild("TrayOverlay",true);local tray=b:FindFirstChild("Tray",true)
	assert(gui.Enabled and b.Visible and board:GetAttribute("Mode")=="Board","uncovered enabled Board required")
	local surface=overlay:FindFirstChild("JellyLCDSpans")or overlay:FindFirstChild("JellyLCD")
	assert(surface and surface.Visible,"run with the actual default pixel renderer")
	local line,text,track=overlay.OverflowLine,overlay.DangerText,overlay.DangerTrack
	local previous=board:GetAttribute("OverflowPressure");local danger=board:GetAttribute("DangerY")
	local cases={};local function settle()for _=1,4 do RunService.RenderStepped:Wait()end end
	local function test(name,run)run();table.insert(cases,name)end
	local ok,problem=pcall(function()
		test("idle overflow line remains above the opaque LCD at the unchanged physical threshold",function()
			board:SetAttribute("OverflowPressure",0);settle()
			local scale=tray.AbsoluteSize.X/(Config.Width+.8)
			local expected=tray.AbsoluteSize.Y/2-((danger or Config.OverflowY)-Config.Height/2)*scale
			assert(line.Visible and line.ZIndex>surface.ZIndex and line.Size.Y.Offset==2,"LCD covered or changed the overflow line")
			assert(math.abs(line.Position.Y.Offset-expected)<=1 and math.abs(line.BackgroundTransparency-.55)<.001)
			assert(not text.Visible and not track.Visible)
		end)
		test("active pressure keeps warning text and fill above the framebuffer",function()
			board:SetAttribute("OverflowPressure",.65);settle()
			assert(line.Visible and line.BackgroundTransparency>=.049 and line.BackgroundTransparency<=.351,"armed line left the red pulse range")
			assert(text.Visible and text.ZIndex>line.ZIndex and text.ZIndex>surface.ZIndex)
			assert(text.Text=="CLEAR THE LINE" and text.TextFits,"warning text="..text.Text.." label="..tostring(text.AbsoluteSize).." native="..tostring(text.TextBounds))
			assert(text.TextColor3==Art.LCDInk,"warning lost contrast on pale LCD")
			assert(text.TextSize==11 and text.Font==Art.Font.Body and text.Position.Y.Offset==3,"warning font/anchor changed")
			assert(text.AbsoluteSize.Y>=text.TextBounds.Y+2-.01 and text.AbsoluteSize.X>=text.TextBounds.X,"native warning ink escapes measured bounds")
			assert(track.Visible and track.ZIndex>line.ZIndex and track.Fill.ZIndex>=track.ZIndex and math.abs(track.Fill.Size.Y.Scale-.65)<.001)
			assert(board:GetAttribute("DangerY")==danger,"presentation changed overflow physics")
		end)
		test("armed danger pulses the line and repeats the warning blip no faster than 0.6 s",function()
			local SoundService=game:GetService("SoundService");local voice=SoundService:FindFirstChild("EggDrop_overflow")
			local group=SoundService:FindFirstChild("EggDropSFX");assert(voice,"overflow cue missing")
			board:SetAttribute("OverflowPressure",0);settle()
			local plays={};local c=voice.Played:Connect(function()table.insert(plays,os.clock())end)
			board:SetAttribute("OverflowPressure",.5)
			local started=os.clock();local low,high=1,0
			while os.clock()-started<1.6 do RunService.RenderStepped:Wait();low=math.min(low,line.BackgroundTransparency);high=math.max(high,line.BackgroundTransparency)end
			board:SetAttribute("OverflowPressure",0);local cleared=#plays;settle();task.wait(.8);c:Disconnect()
			assert(high-low>.1 and low>=.049 and high<=.351,"armed line did not pulse: "..low.."-"..high)
			assert(math.abs(line.BackgroundTransparency-.55)<.001,"line kept pulsing after danger cleared")
			if group and group.Volume>0 and voice.IsLoaded then
				assert(cleared>=1 and cleared<=3,"overflow plays="..cleared)
				for i=2,#plays do assert(plays[i]-plays[i-1]>=.59,"overflow repeated faster than 0.6 s")end
				assert(#plays==cleared,"overflow kept playing after danger cleared")
			end
		end)
	end)
	local measured={label=tostring(text.AbsoluteSize),nativeContent=tostring(text.TextBounds),textFits=text.TextFits}
	board:SetAttribute("OverflowPressure",previous);settle();assert(ok,problem)
	return{passed=#cases,cases=cases,warningText=measured,localPresentationOnly=true}
end
