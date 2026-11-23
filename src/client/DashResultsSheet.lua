-- Garden Dash results (DASH-DECK-UI-LOOK U6): one sheet on DashCard's shell with a pet moment, the place, the time,
-- what was earned, the field and one green next step. The pet hops on a podium step (DashStage) under its medal;
-- confetti for 1st to 3rd and a cup. No close key: Race again or Done (B / Backspace is Done).
-- card.options.model = DashResults.model(...); card:update(model) when the saved receipt lands (the Stars count runs
-- from then). card.options.strip: the See you tomorrow strip's model, or nil. card.options.buttons = {Again, Done}.
-- Order of events from the card opening (s): 0 card, 0.15 pet and medal, 0.30 headline (input from here), 0.55 the
-- time counts up, 1.05 the Stars count up and the pips fill, confetti, 1.25 the field pops, 1.70 the strip, 1.90 Race
-- again pulses, then every 6 s. Reduced Motion: everything at its final state at once, no confetti, no pulse.
local GuiService=game:GetService("GuiService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Pets=require(Shared.PetCatalog)
local Kit=require(script.Parent.DeckKit)
local Layout=require(script.Parent.DashSheetLayout)
local Stage=require(script.Parent.DashStage)
local Sheet={}
Sheet.Ink=Color3.fromHex("#15143A")
Sheet.Stars=Color3.fromHex("#FFC14D")
Sheet.Lemon=Color3.fromHex("#FFE14D")
Sheet.Shadow=Color3.fromHex("#B8791A")
Sheet.Confetti=table.freeze({Color3.fromHex("#FFC14D"),Color3.fromHex("#FF86A8"),Color3.fromHex("#6CCBFF"),Color3.fromHex("#B9EE5A"),Color3.new(1,1,1)})
Sheet.Pieces=24
Sheet.At=table.freeze({pet=.15,headline=.30,time=.55,stars=1.05,field=1.25,strip=1.70,pulse=1.90})
Sheet.TimeCount=.5
Sheet.StarsCount=.6
Sheet.ConfettiSeconds=1.2
Sheet.PulseEvery=6
Sheet.Pips=5

local function tween(object,seconds,goal,style,delay)
	pcall(function()TweenService:Create(object,TweenInfo.new(seconds,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,delay or 0),goal):Play()end)
end
local function text(parent,role,value,color,box,props)
	local label=Kit.text(parent,role,value,color,props)
	label.Position=UDim2.fromOffset(box.x,box.y);label.Size=UDim2.fromOffset(box.w,box.h)
	return label
end
-- An icon at some see-through (Kit.icon is an image, or a frame-drawn vector before its atlas cell).
local function dim(icon,value)
	if icon:IsA("ImageLabel")then icon.ImageTransparency=value
	else for _,part in ipairs(icon:GetDescendants())do if part:IsA("Frame")then part.BackgroundTransparency=value end end end
end
local function hex(value)return if typeof(value)=="Color3"then value else Color3.fromHex(value or"#FFF4DC")end
-- Pure: a count-up's value at `t` s after its start (0 before, `to` after `seconds`), eased.
function Sheet.count(t,to,seconds)
	if t<=0 then return 0 end
	if t>=seconds then return to end
	local x=t/seconds
	return to*(1-(1-x)^3)
end

function Sheet.build(card,W,H)
	local o=card.options
	local m=o.model or {}
	local g=Layout.results(W,H,{earned=m.earned~=nil,field=m.field~=nil and #m.field>0,strip=o.strip~=nil})
	local panel=Kit.frame(card.root,"DashCard","panel",UDim2.fromOffset(g.card.x+g.w*g.scale/2,g.card.y+g.h*g.scale/2),UDim2.fromOffset(g.w,g.h),22)
	panel.AnchorPoint=Vector2.new(.5,.5);panel.Active=true;panel.ZIndex=20
	Kit.stroke(panel,Sheet.Ink,3)
	local scale=Instance.new("UIScale");scale.Scale=g.scale;scale.Parent=panel
	card.panel,card.layout=panel,g
	local z=panel.ZIndex+2
	-- The stage: podium, pet, medal, confetti.
	local pet=o.pet or Pets.byId.pip
	local stage=Stage.new(panel,g.stage,{kind="podium",pet=pet,appearance=o.appearance,pedestal=g.podium,frame=g.pet,place=if m.trial then(if m.medal and m.medal.cup then 1 else 4)else(o.place or 4),z=panel.ZIndex+1})
	card.stage=stage
	local medal=Kit.frame(stage.root,"Medal",nil,UDim2.fromOffset(g.medal.x+g.medal.w/2,g.medal.y+g.medal.h/2),UDim2.fromOffset(g.medal.w,g.medal.h),999)
	medal.AnchorPoint=Vector2.new(.5,.5);medal.BackgroundTransparency=0;medal.BackgroundColor3=hex(m.medal and m.medal.color);medal.ZIndex=stage.root.ZIndex+9
	Kit.stroke(medal,Sheet.Ink,2)
	local medalScale=Instance.new("UIScale");medalScale.Parent=medal
	local medalWord=if m.medal and m.medal.ordinal then m.medal.ordinal elseif m.medal and m.medal.cup then "★"else "⏱"
	local medalText=Kit.text(medal,"Title",medalWord,"text",{Size=UDim2.fromScale(1,1),TextSize=16,TextXAlignment=Enum.TextXAlignment.Center})
	medalText.TextColor3=Sheet.Ink;medalText.ZIndex=medal.ZIndex+1
	if not(m.medal and m.medal.ordinal)then Kit.fixedText(medalText)end
	local confetti={}
	if m.celebrate then
		for i=1,Sheet.Pieces do
			local piece=Instance.new("Frame")
			piece.Name="Confetti";piece.BorderSizePixel=0;piece.Size=UDim2.fromOffset(3,8);piece.Visible=false;piece.ZIndex=stage.root.ZIndex+10
			piece.BackgroundColor3=Sheet.Confetti[(i-1)%#Sheet.Confetti+1];piece.Parent=stage.root
			confetti[i]={frame=piece,x=((i*37)%100)/100,speed=110+(i*53)%70,sway=(i%5)-2,spin=(i*29)%360,delay=((i*17)%10)/30}
		end
	end
	-- Headline: the display words with a gold drop.
	local head=Kit.frame(panel,"Headline",nil,UDim2.fromOffset(g.headline.x+g.headline.w/2,g.headline.y+g.headline.h/2),UDim2.fromOffset(g.headline.w,g.headline.h))
	head.AnchorPoint=Vector2.new(.5,.5);head.ZIndex=z
	local headScale=Instance.new("UIScale");headScale.Parent=head
	for index,spec in ipairs({{Sheet.Shadow,2},{Color3.new(1,1,1),0}})do
		local line=Kit.text(head,"Title",m.headline or"","text",{Name=if index==1 then "Shadow"else "Line",Position=UDim2.fromOffset(spec[2],spec[2]),Size=UDim2.fromScale(1,1),
			TextSize=28,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
		line.TextColor3=spec[1];line.ZIndex=z+index
		if index==2 then card.title=line end
	end
	-- Time row.
	local function tray(name,b)local t=Kit.frame(panel,name,"raised",UDim2.fromOffset(b.x,b.y),UDim2.fromOffset(b.w,b.h),10);t.ZIndex=z;return t end
	local timeTray=tray("Time",g.time)
	text(timeTray,"Label",UICopy.get("dash.label.time"),"soft",{x=12,y=0,w=40,h=g.time.h},{TextSize=11})
	local timeValue=text(timeTray,"Title",if m.time then m.time.." s"else UICopy.get("dash.result.home"),"text",{x=48,y=0,w=110,h=g.time.h},{TextSize=22})
	timeValue.TextColor3=Color3.new(1,1,1);if m.time then Kit.fixedText(timeValue)end
	if m.best then
		text(timeTray,"Label",UICopy.get("dash.label.best"),"soft",{x=166,y=0,w=40,h=g.time.h},{TextSize=11})
		local best=text(timeTray,"Strong",m.best.." s","text",{x=202,y=0,w=80,h=g.time.h},{TextSize=16})
		best.TextColor3=Color3.new(1,1,1);Kit.fixedText(best)
	end
	local newBest=nil
	if m.newBest then
		newBest=Kit.frame(timeTray,"NewBest",nil,UDim2.new(1,-10-72,.5,-11),UDim2.fromOffset(72,22),999)
		newBest.BackgroundTransparency=0;newBest.BackgroundColor3=Sheet.Stars
		local word=Kit.text(newBest,"Title",UICopy.get("dash.result.newBest"),"text",{Size=UDim2.fromScale(1,1),TextSize=11,TextXAlignment=Enum.TextXAlignment.Center})
		word.TextColor3=Sheet.Ink;word.ZIndex=newBest.ZIndex+1
	end
	-- Earned row.
	local earned={}
	if g.earned then
		local t=tray("Earned",g.earned)
		earned.tray=t
		earned.star=Kit.icon(t,"star",24,"stars");earned.star.Position=UDim2.fromOffset(12,(g.earned.h-24)/2)
		earned.label=text(t,"Title","","stars",{x=44,y=0,w=g.earned.w*.5,h=g.earned.h},{TextSize=20,TextTruncate=Enum.TextTruncate.AtEnd})
		earned.today=text(t,"BodyMedium","","soft",{x=g.earned.w-12-110,y=0,w=110,h=g.earned.h},{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
		earned.pips={}
		for i=1,Sheet.Pips do
			local pip=Kit.frame(t,"Pip"..i,nil,UDim2.fromOffset(g.earned.w-12-110-8-(Sheet.Pips-i+1)*14,(g.earned.h-10)/2),UDim2.fromOffset(10,10),999)
			pip.BackgroundTransparency=0;Kit.stroke(pip,Sheet.Ink,1)
			earned.pips[i]=pip
		end
	end
	card.earned=earned
	-- Field row: up to four chips, yours lemon.
	local chips={}
	if g.field then
		local list=m.field
		local gap=6
		local cw=math.floor((g.field.w-gap*(#list-1))/#list)
		for index,entry in ipairs(list)do
			local chip=Kit.frame(panel,"Field"..index,if entry.mine then nil else "well",UDim2.fromOffset(g.field.x+(index-1)*(cw+gap),g.field.y),UDim2.fromOffset(cw,g.field.h),10)
			chip.ZIndex=z
			if entry.mine then chip.BackgroundTransparency=0;chip.BackgroundColor3=Sheet.Lemon end
			Kit.stroke(chip,Sheet.Ink,2)
			local disc=Kit.frame(chip,"Place",nil,UDim2.fromOffset(6,(g.field.h-16)/2),UDim2.fromOffset(16,16),999)
			disc.BackgroundTransparency=0;disc.BackgroundColor3=hex(entry.color);Kit.stroke(disc,Sheet.Ink,1)
			local n=Kit.text(disc,"Title",tostring(entry.place),"text",{Size=UDim2.fromScale(1,1),TextSize=10,TextXAlignment=Enum.TextXAlignment.Center})
			n.TextColor3=Sheet.Ink;n.ZIndex=disc.ZIndex+1;Kit.fixedText(n)
			local color=if entry.mine then Sheet.Ink else Color3.new(1,1,1)
			local name=text(chip,"Strong",entry.name or"","text",{x=26,y=4,w=cw-30,h=16},{TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd})
			name.TextColor3=color;Kit.fixedText(name)
			if entry.time then
				local time=text(chip,"BodyMedium",entry.time.." s","soft",{x=26,y=20,w=cw-30,h=14},{TextSize=11})
				Kit.fixedText(time)
				if entry.mine then time.TextColor3=Sheet.Ink end
			end
			chips[index]=chip
		end
	end
	-- The See you tomorrow strip (v2).
	local strip=nil
	if g.strip and o.strip then
		local ok,problem=pcall(function()
			local Strip=require(script.Parent.TomorrowStrip)
			strip=Strip.new(panel,{phone=true,z=z,source=o.stripSource,reduced=o.reduced})
			strip.root.Position=UDim2.fromOffset(g.strip.x,g.strip.y)
			strip:set(o.strip,g.strip.w)
		end)
		if not ok then warn("[Dash] strip: "..tostring(problem));strip=nil end
	end
	card.strip=strip
	-- Race again (two thirds) and Done.
	local buttons={}
	for index,spec in ipairs(o.buttons)do
		local b=if index==1 then g.again else g.done
		local button=Kit.button(panel,spec.name,{variant=if spec.primary then "primary"else "secondary",text=spec.text,size=Vector2.new(b.w,b.h),
			textSize=17,compact=false})
		button.Position=UDim2.fromOffset(b.x,b.y);button.ZIndex=z+1
		button.Activated:Connect(function()card:press(index)end)
		buttons[index]=button
	end
	for index,button in ipairs(buttons)do
		button.NextSelectionLeft=buttons[index-1]or button
		button.NextSelectionRight=buttons[index+1]or button
		button.NextSelectionUp,button.NextSelectionDown=button,button
		button.SelectionGained:Connect(function()o.selected=index end)
	end
	card.buttons=buttons
	-- The timeline. A rebuild (a resize) lands at the end state at once.
	local reduced=card:reduced()
	local fresh=not card.entered
	card.entered=true
	card.openedAt=card.openedAt or os.clock()
	card.inputAt=if fresh and not reduced then card.openedAt+Sheet.At.headline else 0
	local fired={}
	local function at(name)return reduced or not fresh or os.clock()-card.openedAt>=Sheet.At[name]end
	if fresh and not reduced then
		scale.Scale=g.scale*.92;tween(scale,.22,{Scale=g.scale},Enum.EasingStyle.Back)
		medalScale.Scale=0;headScale.Scale=0
		for _,chip in ipairs(chips)do chip.Visible=false end
		if strip then strip.root.Visible=false end
	end
	local function paintEarned(t)
		local e=card.options.model and card.options.model.earned
		if not earned.tray or not e then return end
		local filled=e.done or 0
		if e.state=="paid"then
			local since=t-math.max(Sheet.At.stars,card.paidAt or 0)
			local n=if reduced then e.stars else math.floor(Sheet.count(since,e.stars,Sheet.StarsCount)+.5)
			earned.label.Text=UICopy.get("dash.result.starsShort",{reward=n})
			earned.label.TextColor3=Sheet.Stars;dim(earned.star,0)
			filled=if reduced or since>=Sheet.StarsCount then e.done else math.max(0,(e.done or 0)-1)+(if since>Sheet.StarsCount*.5 then 1 else 0)
			earned.today.Text=UICopy.get("dash.result.today",{done=e.done,total=e.total})
		elseif e.state=="saving"then
			earned.label.Text=e.text;earned.label.TextColor3=Color3.fromHex("#DCE5FF");dim(earned.star,.6)
			earned.today.Text=""
		elseif e.state=="cup"or e.state=="noCup"then
			earned.label.Text=e.text;earned.label.TextSize=if e.state=="cup"then 18 else 14
			earned.label.TextColor3=if e.state=="cup"then Sheet.Stars else Color3.fromHex("#DCE5FF")
			earned.today.Text=""
			for _,pip in ipairs(earned.pips)do pip.Visible=false end
			return
		else
			earned.label.Text=if e.state=="usedUp"then e.text else UICopy.get("dash.result.today",{done=e.done,total=e.total})
			earned.label.TextSize=14;earned.label.TextColor3=Color3.fromHex("#DCE5FF")
			earned.today.Text=""
		end
		for i,pip in ipairs(earned.pips)do
			pip.Visible=i<=(e.total or Sheet.Pips)
			pip.BackgroundColor3=if i<=filled then Sheet.Stars else Kit.color("well")
		end
	end
	card.paintEarned=paintEarned
	card.sheetStep=function(dt)
		local t=os.clock()-card.openedAt
		-- The pet on its own: a rig that throws stops its pose, never the timeline (medal, headline, chips, strip).
		if not card.stageFailed then
			local ok,problem=pcall(stage.step,stage,dt,reduced)
			if not ok then card.stageFailed=true;warn("[Dash] stage: "..tostring(problem))end
		end
		if at("pet")and not fired.pet then
			fired.pet=true
			if fresh and not reduced then stage:dropIn(false);tween(medalScale,.25,{Scale=1},Enum.EasingStyle.Back)else medalScale.Scale=1 end
		end
		if at("headline")and not fired.headline then
			fired.headline=true
			if fresh and not reduced then headScale.Scale=1.5;tween(headScale,.32,{Scale=1},Enum.EasingStyle.Back)else headScale.Scale=1 end
		end
		if m.time then
			local value=if reduced or not fresh then nil else Sheet.count(t-Sheet.At.time,tonumber(m.time)or 0,Sheet.TimeCount)
			local shown=if value then string.format("%.1f s",value)else m.time.." s"
			if timeValue.Text~=shown then timeValue.Text=shown end
		end
		if newBest then newBest.Visible=at("stars")end
		paintEarned(if at("stars")and not(fresh and not reduced)then math.huge else t)
		if not at("stars")and earned.label then earned.label.Text="";for _,pip in ipairs(earned.pips)do pip.BackgroundColor3=Kit.color("well")end end
		-- Confetti: inside the stage for ConfettiSeconds from the Stars.
		if #confetti>0 and fresh and not reduced then
			local since=t-Sheet.At.stars
			for _,piece in ipairs(confetti)do
				local u=since-piece.delay
				local on=u>=0 and u<Sheet.ConfettiSeconds
				if piece.frame.Visible~=on then piece.frame.Visible=on end
				if on then
					piece.frame.Position=UDim2.fromOffset(g.stage.w*piece.x+math.sin(u*6+piece.sway)*8,-10+u*piece.speed)
					piece.frame.Rotation=piece.spin+u*240
				end
			end
		end
		if at("field")and not fired.field then
			fired.field=true
			for index,chip in ipairs(chips)do
				if fresh and not reduced then
					task.delay((index-1)*.06,function()
						if chip.Parent then chip.Visible=true;local s=Instance.new("UIScale");s.Scale=.6;s.Parent=chip;tween(s,.18,{Scale=1},Enum.EasingStyle.Back)end
					end)
				else chip.Visible=true end
			end
		end
		if at("strip")and not fired.strip then
			fired.strip=true
			if strip then strip.root.Visible=true;if fresh then strip:enter(0,reduced)end end
		end
		if not reduced and t>=Sheet.At.pulse and buttons[1]then
			local beat=math.floor((t-Sheet.At.pulse)/Sheet.PulseEvery)
			if fired.beat~=beat then fired.beat=beat;Kit.pulse(buttons[1])end
		end
	end
	if string.sub(UserInputService:GetLastInputType().Name,1,7)=="Gamepad"then GuiService.SelectedObject=buttons[o.selected or 1]end
end
-- A newer model (the saved receipt): the Earned row and the best take it; the Stars count runs from now.
function Sheet.update(card,model)
	local old=card.options.model
	card.options.model=model
	if old and old.earned and model.earned and old.earned.state~="paid"and model.earned.state=="paid"then card.paidAt=os.clock()-card.openedAt end
	-- A row that comes or goes (prizes switched, a best saved) needs the full card: rebuild at the end state.
	local rows=function(x)return(x.earned~=nil)and 1 or 0 end
	if old and(rows(old)~=rows(model)or(old.best==nil)~=(model.best==nil)or old.newBest~=model.newBest)then card:rebuild()end
end
return Sheet
