-- G2 (CalmFirstDeck): the calm Welcome deck on a real DeckScreen GUI fixture, Studio only (it needs the engine's GUI;
-- not run offline). Per size: the Welcome round hides the panels and grows the coach card and the egg; the board rect,
-- Skip (inside the coach card) and the egg (inside its well) hold; the first field round puts every HUD card's
-- Position, Size and Visible back exactly as they were. No remote or service writes.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.CalmDeck)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
	local Screen=require(client.DeckScreen)
	local Calm=require(client.DeckCalm)
	local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
	local Copy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
	local Run=game:GetService("RunService")
	local root=Instance.new("Frame");root.Name="_CalmDeckQA";root.BackgroundTransparency=1;root.ClipsDescendants=true;root.Parent=parent
	local screen=Screen.new({parent=root,overlayParent=root,viewRoot=root})
	local deps={copy=Copy.get,skip=function()end}
	local cases={}
	local function rect(n)return{x=n.AbsolutePosition.X,y=n.AbsolutePosition.Y,w=n.AbsoluteSize.X,h=n.AbsoluteSize.Y}end
	local function inside(a,b)return a.x>=b.x-.1 and a.y>=b.y-.1 and a.x+a.w<=b.x+b.w+.1 and a.y+a.h<=b.y+b.h+.1 end
	local function record(host)
		local out={}
		for _,c in ipairs(host:GetDescendants())do
			if c:IsA("GuiObject")then out[c]={Position=c.Position,Size=c.Size,Visible=c.Visible}end
		end
		return out
	end
	local ok,problem=pcall(function()
		for index,size in ipairs({Vector2.new(1280,720),Vector2.new(812,354),Vector2.new(750,402),Vector2.new(640,360),Vector2.new(568,320)})do
			root.Size=UDim2.fromOffset(size.X,size.Y)
			local geometry=screen:layout(size,(Config.Width+.8)/(Config.Height+.8),{kx=116,kh=58});screen:setVisible(true)
			local h=screen.hud
			local board=table.clone(geometry.board)
			screen:setHud({welcome=true,score=0,message=Copy.get("onboarding.welcome.friend"),next={1,1,2},input="Touch"})
			local before=record(screen.hudRoot)
			local snapshot={generation=200+index,charge=2,threshold=6,phase="Welcome",active=true,owned=0,drops=0,skipReady=true,device="Touch",reduced=true}
			screen:setWelcome(snapshot,deps);Run.Heartbeat:Wait();screen:setWelcome(snapshot,deps)
			assert(h.calm~=nil,"calm applied at "..size.X.."x"..size.Y)
			for _,name in ipairs(Calm.Hidden)do
				local card=screen.hudRoot:FindFirstChild(name)
				assert(not card or not card.Visible,name.." hidden")
			end
			local goals=screen.hudRoot:FindFirstChild("Goals")
			assert(goals.AbsoluteSize.Y>=before[goals].Size.Y.Offset*screen.contentScale.Scale-1,"the coach card never shrinks")
			local view=screen.welcomeView
			assert(view.skip.Visible and inside(rect(view.skip),rect(h.welcomeCoach)),"Skip stays inside the coach card")
			assert(inside(rect(view.egg),rect(screen.welcomeMeterHost)),"the egg stays in its well")
			assert(geometry.board.x==board.x and geometry.board.y==board.y and geometry.board.w==board.w and geometry.board.h==board.h,"the board never moves")
			-- Beta 42 note 10 (C10): the deck feel's bob rest follows NEXT's re-centred ball (stepNext wrote the old one back).
			local ball=h.next and h.next[1]and h.next[1].ball
			local feel=screen.feel
			if ball and feel and feel.nextBase then
				assert(feel.nextBase[1]==ball.Position,"the bob rest is the calm place at "..size.X.."x"..size.Y)
				local card=screen.hudRoot:FindFirstChild("Next")
				if card and card.Visible then assert(inside(rect(ball),rect(card)),"NEXT's ball inside its cut card") end
			end
			-- The first field round: everything back.
			screen:setWelcome({generation=300+index,charge=0,threshold=6,phase="Play",active=true,owned=1,drops=0,device="Touch",reduced=true},deps)
			assert(h.calm==nil,"restored")
			if ball and feel and feel.nextBase then
				assert(feel.nextBase[1]==before[ball].Position,"the bob rest is back at "..size.X.."x"..size.Y)
			end
			for object,props in pairs(before)do
				if object.Parent and object~=h.status then
					for property,value in pairs(props)do
						assert(object[property]==value,object:GetFullName().."."..property.." restored at "..size.X.."x"..size.Y)
					end
				end
			end
			table.insert(cases,size.X.."x"..size.Y..(if geometry.phone then " "..tostring(geometry.layout)else " pc"))
		end
	end)
	screen:destroyWelcome();screen.boot:finish(false);root:Destroy()
	assert(ok,problem)
	return {passed=#cases,cases=cases}
end
