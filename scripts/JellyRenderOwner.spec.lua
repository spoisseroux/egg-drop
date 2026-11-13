-- Actual game renderer owner gate. Adds one LOCAL anchored visual probe only;
-- never sends input/remotes or changes profile/receipts. Optional teardown must run last in Play.
return function(gui,board,options)
	options=options or {}
	local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local RunService=game:GetService("RunService")
	local GuiService=game:GetService("GuiService")
	local probeStarted=os.clock();local observedFrames=0;local lastFrameDt=0;local context="initial"
	-- The tray moved under Backdrop.DevicePresentation before this redesign; find it by name.
	local b=gui.Backdrop;local trayOverlay,trayView=b:FindFirstChild("TrayOverlay",true),b:FindFirstChild("Tray",true);local overlays=gui.Parent:WaitForChild("EggDropOverlays").SafeContent
	assert(gui.Enabled and b.Visible and board:GetAttribute("Mode")=="Board","settled enabled Board required")
	-- QA Q5: the garden menu is the machine hub (its own ScreenGui); DeckMenu is retired.
	local hubShade=gui.Parent:WaitForChild("EggDropMachineHub"):WaitForChild("MachineHubHost"):WaitForChild("MachineHubShade")
	local covers={hubShade,overlays.DeckPicker,overlays.PetJournal,overlays.EggHatchView,overlays.RoundCard,overlays.DeckHandoff}
	for _,cover in ipairs(covers)do assert(not cover.Visible,"close presentation owners first: "..cover.Name)end
	local existing={};for _,node in ipairs(trayOverlay:GetChildren())do existing[node]=true end
	local source=Instance.new("Part");source.Name="_LocalRendererProbe";source.Anchored=true;source.CanCollide=false;source.CanQuery=false;source.CanTouch=false
	source.Size=Vector3.one*Config.Tiers[1].radius*2;source.Color=Config.Tiers[1].color;source.Position=Vector3.new(0,8,0)
	source:SetAttribute("Tier",1);source:SetAttribute("EggId",-100000001);source:SetAttribute("BoardSerial",board:GetAttribute("ResetId"));source.Parent=board
	local cases={};local function test(name,run)context=name;run();table.insert(cases,name)end
	local function settle()for _=1,6 do lastFrameDt=RunService.RenderStepped:Wait();observedFrames+=1 end end
	local mark;local n=0
	local function diagnostic(expected,phase)
		local flags={};for _,cover in ipairs(covers)do table.insert(flags,cover.Name.."="..tostring(cover.Visible))end
		local surface=trayOverlay:FindFirstChild("JellyLCDSpans")or trayOverlay:FindFirstChild("JellyLCD")
		local body=trayOverlay.Sprites:FindFirstChild(source.Name)
		local scale=trayView.AbsoluteSize.X/(Config.Width+.8)
		local physical=Vector2.new(trayView.AbsoluteSize.X/2+source.Position.X*scale,trayView.AbsoluteSize.Y/2-(source.Position.Y-Config.Height/2)*scale)
		return string.format("context=%s phase=%s frames=%d elapsed=%.4fs lastDt=%.5f source=%s mark=%s expectedXY=%s physicalProjection=%s markAbs=%s/%s tray=%s overlay=%s guiEnabled=%s backdropVisible=%s coreMenu=%s mode=%s field=%s/%s surface=%s spritesVisible=%s cheapBody=%s covers[%s]; gel axis/age are private (elapsed is fixture wall clock)",
			context,phase or "",observedFrames,os.clock()-probeStarted,lastFrameDt,tostring(source.Position),tostring(mark and mark.Position),tostring(expected),tostring(physical),tostring(mark and mark.AbsolutePosition),tostring(mark and mark.AbsoluteSize),tostring(trayView.AbsoluteSize),tostring(trayOverlay.AbsoluteSize),tostring(gui.Enabled),tostring(b.Visible),tostring(GuiService.MenuIsOpen),tostring(board:GetAttribute("Mode")),tostring(board:GetAttribute("FieldReady")),tostring(board:GetAttribute("FieldPhase")),if surface then surface.Name..":"..tostring(surface.Visible)else "none",tostring(trayOverlay.Sprites.Visible),if body then tostring(body.Position).."/"..tostring(body.Size)else "none",table.concat(flags,","))
	end
	local function expectCurrent(phase)
		-- Tier marks only show at radius >= 12 px (redesign 6.2); a hidden mark still tracks.
		local markRadius=Config.Tiers[1].radius*trayView.AbsoluteSize.X/(Config.Width+.8)
		settle();assert(mark and(mark.Visible or markRadius<12)and mark.Rotation==0,"upright mark missing")
		local expected=Vector2.new(trayView.AbsoluteSize.X*(.5+source.Position.X/(Config.Width+.8)),trayView.AbsoluteSize.Y*(.5-(source.Position.Y-Config.Height/2)/(Config.Height+.8)))
		assert(math.abs(mark.Position.X.Offset-expected.X)<2 and math.abs(mark.Position.Y.Offset-expected.Y)<2,"uncovered renderer retained an old position: "..diagnostic(expected,phase))
	end
	local ok,problem=pcall(function()
		settle();for _,node in ipairs(trayOverlay:GetChildren())do if node:IsA("TextLabel")and node.Name=="Mark"and not existing[node]then assert(not mark,"ambiguous live mark creation");mark=node end end
		assert(mark,"local visual probe did not create its separate mark")
		-- A newly created gel has an intentional spring offset from its physical
		-- center. Let that presentation settle once before testing owner handoffs.
		while os.clock()-probeStarted<1.5 do lastFrameDt=RunService.RenderStepped:Wait();observedFrames+=1 end
		for _,cover in ipairs(covers)do
			test(cover.Name.." pauses sampling then resumes current projection",function()
				expectCurrent("before cover");cover.Visible=true;settle();local before=mark.Position
				n+=1;source.Position=Vector3.new(if n%2==0 then -1.5 else 1.5,8,0);settle()
				assert(mark.Position==before,"covered renderer sampled moving probe: "..diagnostic(Vector2.new(before.X.Offset,before.Y.Offset),"during cover"))
				cover.Visible=false;expectCurrent("after cover")
			end)
		end
		test("hidden and disabled GUI owners stop sampling without rebuilding surfaces",function()
			local surface=trayOverlay:FindFirstChild("JellyLCDSpans")or trayOverlay:FindFirstChild("JellyLCD")
			for _,owner in ipairs({b,gui})do
				expectCurrent("before "..owner.Name);if owner==gui then gui.Enabled=false else b.Visible=false end;settle();local before=mark.Position
				source.Position=Vector3.new(-source.Position.X,8,0);settle();assert(mark.Position==before,"hidden/disabled renderer sampled probe: "..diagnostic(Vector2.new(before.X.Offset,before.Y.Offset),"during "..owner.Name))
				if owner==gui then gui.Enabled=true else b.Visible=true end;expectCurrent("after "..owner.Name)
				if surface then assert(surface.Parent==trayOverlay,"owner handoff reallocated renderer")end
			end
		end)
		if options.teardown then
			test("teardown revokes board-child callbacks and render connection",function()
				local overlay=trayOverlay;gui:Destroy();local before=#overlay:GetChildren()
				local late=source:Clone();late.Name="_LateLocalRendererProbe";late:SetAttribute("EggId",-100000002);late.Parent=board;settle()
				assert(#overlay:GetChildren()==before,"destroyed renderer accepted a later board child")
				late:Destroy()
			end)
		end
	end)
	source:Destroy()
	if gui.Parent then for _,cover in ipairs(covers)do cover.Visible=false end;gui.Enabled=true;b.Visible=true;settle()end
	assert(ok,problem)
	return{passed=#cases,cases=cases,localProbeOnly=true,teardown=options.teardown==true}
end
