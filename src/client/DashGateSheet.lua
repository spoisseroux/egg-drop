-- Garden Dash mode picker (DASH-DECK-UI-LOOK U3): a centred sheet on DashCard's shell. The player's pet runs on the
-- spot on a lit pedestal at the left (DashStage); its Speed, Energy and Jump, then the three race tiles at the right.
-- The stats follow the focused or hovered tile: Stats On in full colour, Just for Fun and Time Trial dimmed under
-- "All pets equal in this race". A tap on a tile starts that race (DashCard:press). Gamepad: the tiles only, left and
-- right, no wrap; A starts, B closes. Reduced Motion: an idle pet, no spring, fades only.
-- card.options.gate = {pet, appearance, name, band (text or nil), levels = {speed, energy, jump} or nil, prizes (text or
-- nil), best (text or nil)}; card.options.buttons = the three tiles {name = "Fun" | "Stats" | "Trial", text, sub, act,
-- primary}; card.options.selected = the green tile.
local GuiService=game:GetService("GuiService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Catalog=require(Shared.StatCatalog)
local Kit=require(script.Parent.DeckKit)
local Layout=require(script.Parent.DashSheetLayout)
local Stage=require(script.Parent.DashStage)
local Sheet={}
Sheet.Ink=Color3.fromHex("#15143A")
Sheet.InkSoft=Color3.fromHex("#4A4972")
Sheet.Cream=Color3.fromHex("#FFF4DC")
Sheet.Puff=Color3.fromHex("#B9B6C9")
Sheet.Rows=table.freeze({"speed","energy","jump"})
Sheet.Fade=.15

local function tween(object,seconds,goal,style)
	pcall(function()TweenService:Create(object,TweenInfo.new(seconds,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal):Play()end)
end
local function text(parent,role,value,color,box,props)
	local label=Kit.text(parent,role,value,color,props)
	label.Position=UDim2.fromOffset(box.x,box.y);label.Size=UDim2.fromOffset(box.w,box.h)
	return label
end
-- The stat tray for a race: Stats On counts the levels; the other two run every pet the same.
function Sheet.counts(name)return name=="Stats"end

function Sheet.build(card,W,H)
	local o=card.options
	local data=o.gate or {}
	local g=Layout.gate(W,H)
	local reduced=card:reduced()
	local panel=Kit.frame(card.root,"DashCard","panel",UDim2.fromOffset(g.card.x+g.w*g.scale/2,g.card.y+g.h*g.scale/2),UDim2.fromOffset(g.w,g.h),22)
	panel.AnchorPoint=Vector2.new(.5,.5);panel.Active=true;panel.ZIndex=20
	Kit.stroke(panel,Sheet.Ink,3)
	local scale=Instance.new("UIScale");scale.Scale=g.scale;scale.Parent=panel
	card.panel=panel
	-- The stage.
	local stage=Stage.new(panel,g.stage,{kind="pedestal",pet=data.pet,appearance=data.appearance,pedestal=g.pedestal,z=panel.ZIndex+1})
	card.stage=stage
	local top=stage.root.ZIndex+8
	local name=text(stage.root,"Title",data.name or"","text",g.name,{TextSize=16,TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
	name.TextColor3=Color3.new(1,1,1);name.ZIndex=top;Kit.fixedText(name)
	if g.band and data.band then
		local band=text(stage.root,"Small",data.band,"soft",g.band,{TextSize=11,TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
		band.ZIndex=top
	end
	-- Title, close key, line.
	text(panel,"Title",UICopy.get("dash.title"),"text",g.title,{TextSize=24,TextTruncate=Enum.TextTruncate.AtEnd}).ZIndex=panel.ZIndex+2
	local close=Kit.closeKey(panel,"Close",32,UICopy.get("confirm.cancel"))
	close.Position=UDim2.fromOffset(g.close.x,g.close.y);close.ZIndex=panel.ZIndex+2;close.Selectable=false
	close.Activated:Connect(function()card:back()end)
	if g.line then text(panel,"Body",UICopy.get("dash.gate.line"),"soft",g.line,{TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd}).ZIndex=panel.ZIndex+2 end
	-- The stats tray: three rows in a canvas group (so they dim together), and the "all equal" pill over them.
	local tray=Kit.frame(panel,"Stats","raised",UDim2.fromOffset(g.stats.x,g.stats.y),UDim2.fromOffset(g.stats.w,g.stats.h),10)
	tray.ZIndex=panel.ZIndex+2
	local rows=Instance.new("CanvasGroup")
	rows.Name="Rows";rows.BackgroundTransparency=1;rows.Size=UDim2.fromScale(1,1);rows.ZIndex=tray.ZIndex+1;rows.Parent=tray
	local barX,barW=92,g.stats.w-92-80
	local fills,levels={},{}
	local Panel=require(script.Parent.StatsPanel)
	for index,id in ipairs(Sheet.Rows)do
		local y=g.statTop+(index-1)*g.statPitch
		local stat=Catalog.ById[id]
		local icon=Panel.icon(rows,id,14);icon.Position=UDim2.fromOffset(10,y+(16-14)/2);icon.ImageColor3=stat.color
		local label=text(rows,"Strong",Panel.statName(id),"text",{x=30,y=y,w=barX-34,h=16},{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
		label.TextColor3=Color3.new(1,1,1)
		local track=Kit.frame(rows,"Track_"..id,"well",UDim2.fromOffset(barX,y+4),UDim2.fromOffset(barW,8),4)
		local level=data.levels and data.levels[id]or 1
		local fill=Kit.frame(track,"Fill",nil,UDim2.new(),UDim2.fromOffset(math.max(8,math.floor(barW*level/Catalog.MaxLevel)),8),4)
		fill.BackgroundTransparency=0;fill.BackgroundColor3=stat.color
		fills[id]={fill=fill,color=stat.color}
		local lv=text(rows,"Strong",UICopy.get("bond.short",{count=level}),"text",{x=g.stats.w-10-60,y=y,w=60,h=16},
			{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
		lv.TextColor3=Color3.new(1,1,1);Kit.fixedText(lv) -- a number per value: never captured for translation
		levels[id]=lv
	end
	local equalText=UICopy.get("dash.equal")
	local pillW=math.ceil(Kit.measure(equalText,"Title",12).X)+20
	local pill=Kit.frame(tray,"Equal",nil,UDim2.fromScale(.5,.5),UDim2.fromOffset(pillW,22),999)
	pill.AnchorPoint=Vector2.new(.5,.5);pill.BackgroundTransparency=0;pill.BackgroundColor3=Sheet.Cream;pill.ZIndex=rows.ZIndex+4
	Kit.stroke(pill,Sheet.Ink,1.5)
	local pillText=Kit.text(pill,"Title",equalText,"text",{Size=UDim2.fromScale(1,1),TextSize=12,TextXAlignment=Enum.TextXAlignment.Center})
	pillText.TextColor3=Sheet.Ink;pillText.ZIndex=pill.ZIndex+1
	-- The race tiles.
	local tiles={}
	for index,spec in ipairs(o.buttons)do
		local box=g.tiles[index]
		local button,state=Kit.button(panel,spec.name,{variant=if index==o.selected then "primary"else "secondary",text=spec.text,size=Vector2.new(box.w,box.h),lip=4,compact=false})
		button.Position=UDim2.fromOffset(box.x,box.y);button.ZIndex=panel.ZIndex+3
		state.label.Visible=false
		local words=Instance.new("Frame")
		words.Name="Words";words.BackgroundTransparency=1;words.Size=UDim2.fromOffset(box.w,box.h);words.ZIndex=state.content.ZIndex+1;words.Parent=state.content
		local title=Kit.text(words,"Title",spec.text,"text",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,if g.tileSub then -10 else 0),
			Size=UDim2.new(1,-8,0,20),TextSize=15,TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
		title.TextColor3=Sheet.Ink;title.ZIndex=words.ZIndex+1
		if g.tileSub and spec.sub then
			local sub=Kit.text(words,"BodyMedium",spec.sub,"soft",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,11),Size=UDim2.new(1,-8,0,16),
				TextSize=11,TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
			sub.TextColor3=Sheet.InkSoft;sub.ZIndex=words.ZIndex+1
		end
		button:SetAttribute("AccessibleLabel",spec.text..(if spec.sub then ". "..spec.sub else ""))
		button.Activated:Connect(function()card:press(index)end)
		tiles[index]=button
	end
	for index,button in ipairs(tiles)do
		button.NextSelectionLeft=tiles[index-1]or button
		button.NextSelectionRight=tiles[index+1]or button
		button.NextSelectionUp,button.NextSelectionDown=button,button
	end
	card.buttons=tiles
	-- The stats follow the focused or hovered tile.
	local shown=nil
	local function show(index,instant)
		local spec=o.buttons[index]
		if not spec or shown==spec.name then return end
		shown=spec.name
		local counts=Sheet.counts(spec.name)and data.levels~=nil
		local seconds=if instant then 0 else Sheet.Fade
		local function set(object,goal)
			if seconds<=0 then for key,value in pairs(goal)do object[key]=value end else tween(object,seconds,goal)end
		end
		set(rows,{GroupTransparency=if counts then 0 else .55})
		pill.Visible=true
		set(pill,{BackgroundTransparency=if counts then 1 else 0})
		set(pillText,{TextTransparency=if counts then 1 else 0})
		local stroke=pill:FindFirstChild("KitStroke")
		if stroke then set(stroke,{Transparency=if counts then 1 else 0})end
		for id,entry in pairs(fills)do
			entry.fill.BackgroundColor3=if counts then entry.color else Sheet.Puff
			entry.fill.BackgroundTransparency=if counts then 0 else .5
		end
		for _,lv in pairs(levels)do lv.Visible=counts end
	end
	card.showStats=show
	local touch=UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled
	for index,button in ipairs(tiles)do
		button.SelectionGained:Connect(function()o.selected=index;show(index)end)
		if not touch then
			button.MouseEnter:Connect(function()show(index)end)
			button.MouseLeave:Connect(function()show(o.selected or 1)end)
		end
	end
	show(o.selected or 1,true)
	-- The foot: today's Stars races (prizes on) and the best Time Trial.
	if data.prizes then
		local star=Kit.icon(panel,"star",14,"stars");star.Position=UDim2.fromOffset(g.foot.x,g.foot.y+4);star.ZIndex=panel.ZIndex+2
		text(panel,"BodyMedium",data.prizes,"soft",{x=g.foot.x+18,y=g.foot.y,w=g.foot.w*.62,h=g.foot.h},{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd}).ZIndex=panel.ZIndex+2
	end
	if data.best then
		local best=text(panel,"Strong",data.best,"soft",{x=g.foot.x+g.foot.w*.62,y=g.foot.y,w=g.foot.w*.38,h=g.foot.h},{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
		best.ZIndex=panel.ZIndex+2
	end
	-- In: the card springs, the light comes on.
	if not card.entered then
		card.entered=true
		if not reduced then
			scale.Scale=g.scale*.92
			tween(scale,.22,{Scale=g.scale},Enum.EasingStyle.Back)
			for _,slice in ipairs(stage.light:GetChildren())do
				slice.BackgroundTransparency=1
				pcall(function()TweenService:Create(slice,TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,.1),{BackgroundTransparency=.9}):Play()end)
			end
		end
	end
	card.sheetStep=function(dt)stage:step(dt,card:reduced())end
	if string.sub(UserInputService:GetLastInputType().Name,1,7)=="Gamepad"then GuiService.SelectedObject=tiles[o.selected or 1]end
end
return Sheet
