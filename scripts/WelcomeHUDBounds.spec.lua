-- Actual DeckScreen GUI fixture, no remote/service writes. Client signature:
-- require(Z.WelcomeHUDBounds)(client, PlayerGui, {keepFixture=true,width=812,height=354})
-- keepFixture leaves _WelcomeHUDQA for coordinator captures; ordinary run cleans up.
-- These are fixed-size GUI fixtures, not physical phone/emulator acceptance.
return function(client,parent,options)
	options=options or {}
	local Screen=require(client.DeckScreen)
	local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
	local Copy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
	local Http=game:GetService("HttpService")
	local Run=game:GetService("RunService")
	local root=Instance.new("Frame");root.Name="_WelcomeHUDQA";root.BackgroundColor3=Color3.fromHex("#13231E");root.BorderSizePixel=0;root.ClipsDescendants=true;root.ZIndex=100;root.Parent=parent
	local screen=Screen.new({parent=root,overlayParent=root,viewRoot=root})
	local cases=0;local bounds={};local sent=0
	local deps={copy=Copy.get,skip=function()sent+=1 end}
	local function rect(n)
		return {x=n.AbsolutePosition.X-root.AbsolutePosition.X,y=n.AbsolutePosition.Y-root.AbsolutePosition.Y,w=n.AbsoluteSize.X,h=n.AbsoluteSize.Y}
	end
	local function inside(a,b,margin)
		margin=margin or 0
		return a.x>=b.x+margin-.1 and a.y>=b.y+margin-.1 and a.x+a.w<=b.x+b.w-margin+.1 and a.y+a.h<=b.y+b.h-margin+.1
	end
	local ok,problem=pcall(function()
		for index,size in ipairs({Vector2.new(options.width or 812,options.height or 354),Vector2.new(1280,720),Vector2.new(640,360)})do
			-- Independent viewport cases begin a fresh Welcome. The forced HUD
			-- rebuild below deliberately keeps THIS generation to test no replay.
			local generation=100+index
			root.Size=UDim2.fromOffset(size.X,size.Y)
			local geometry=screen:layout(size,(Config.Width+.8)/(Config.Height+.8),{kx=116,kh=58});screen:setVisible(true)
			local h=screen.hud
			local before=table.clone(geometry.board)
			screen:setHud({welcome=true,score=0,message=Copy.get("onboarding.welcome.friend"),next={1,1,2},input="Touch"})
			local snapshot={generation=generation,charge=4,threshold=6,phase="Welcome",active=true,owned=0,drops=0,skipReady=true,device="Touch",reduced=true}
			screen:setWelcome(snapshot,deps)
			Run.Heartbeat:Wait();Run.Heartbeat:Wait()
			screen:setWelcome(snapshot,deps)
			local view=screen.welcomeView
			assert(view.egg.Visible and view.cracks[1].Visible and view.cracks[2].Visible)
			local hit,egg,well=rect(view.skip),rect(view.egg),rect(screen.welcomeMeterHost)
			local diagnostic={width=size.X,height=size.Y,visible=view.skip.Visible,active=view.active,skipReady=snapshot.skipReady,
				skip=hit,coach=rect(h.welcomeCoach),meter=well,egg=egg,skipHost=rect(screen.welcomeSkipHost),
				contentScale=screen.contentScale.Scale,geometryScale=geometry.contentScale,viewScale=view.d.scale and view.d.scale()or 1,
				authoredHit={x=view.skip.Size.X.Offset,y=view.skip.Size.Y.Offset},
				authoredHost={x=screen.welcomeSkipHost.Size.X.Offset,y=screen.welcomeSkipHost.Size.Y.Offset},
				layoutBlocked=screen.welcomeSkipHost:GetAttribute("LayoutBlocked"),phone=geometry.phone==true}
			assert(view.skip.Visible and hit.w>=72 and hit.h>=48,"physical Skip target must fit existing coach well: "..Http:JSONEncode(diagnostic))
			assert(inside(hit,rect(h.welcomeCoach)),"Skip leaves coaching card")
			assert(inside(egg,well,7.9),"mystery egg leaves 8px inset")
			assert(not view.ghost.Active and not view.glyph.Active and view.glyph.Visible,"reduced touch is a passive static arrow")
			assert(geometry.board.x==before.x and geometry.board.y==before.y and geometry.board.w==before.w and geometry.board.h==before.h,"Welcome must not move the tray")
			table.insert(bounds,diagnostic)
			view:input();view.pending=true;view.replayed=true
			local checkpoint=view:checkpoint()
			-- Force a real HUD rebuild through a geometry mode change on the next loop.
			screen.welcomeHud=nil
			screen:setWelcome(snapshot,deps)
			assert(screen.welcomeView.pending and screen.welcomeView.interacted and screen.welcomeView.replayed,"rebuild retains same-run latch and input state")
			assert(not screen.welcomeView.ghost.Visible and not screen.welcomeView.glyph.Visible,"same-run rebuild never replays guidance after manual interaction")
			assert(not screen.welcomeView:requestSkip()and sent==0)
			screen.welcomeView:setSkipPending(false)
			assert(checkpoint.progress.generation==generation)
			cases+=1
		end
		if options.keepFixture then
			local size=Vector2.new(options.width or 812,options.height or 354);root.Size=UDim2.fromOffset(size.X,size.Y)
			screen:layout(size,(Config.Width+.8)/(Config.Height+.8),{kx=116,kh=58})
			screen:setHud({welcome=true,score=0,message=Copy.get("onboarding.welcome.more"),next={1,1,2},input="Touch"})
			screen:setWelcome({generation=1000,charge=4,threshold=6,phase="Welcome",active=true,owned=0,drops=1,skipReady=true,device="Touch",reduced=true},deps)
			root:SetAttribute("CaptureEvidence","Actual fixed-size GUI fixture; not a device emulator")
		end
	end)
	if not options.keepFixture or not ok then screen:destroyWelcome();screen.boot:finish(false);root:Destroy()end
	assert(ok,problem)
	return {passed=cases,bounds=bounds,fixture=if options.keepFixture then root:GetFullName()else nil}
end
