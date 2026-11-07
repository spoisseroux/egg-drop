local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Art = require(script.Parent.DeckArt)
local Catalog = require(ReplicatedStorage.Shared.EggCatalog)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local FamilyCrest = require(script.Parent.FamilyCrest)
local Portrait = require(script.Parent.PetPortrait)
local EggArt = require(script.Parent.EggArt)
local SaveNotice=require(script.Parent.SaveNotice)
local Menu = {}
Menu.__index = Menu
local names = { pip = "Pip", puddle = "Puddle", wick = "Wick", orbit = "Orbit" }
local function text(parent,name,content,role,color)
	local node=Art.text(parent,name,content,UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),color or Art.Silver,16)
	Art.type(node,role or "Body")
	node.TextXAlignment,node.TextYAlignment=Enum.TextXAlignment.Left,Enum.TextYAlignment.Center
	return node
end
local function button(parent,name,caption,action)
	local b=Instance.new("TextButton")
	b.Name,b.Text,b.Size=name,caption,UDim2.fromOffset(100,44)
	b.BackgroundColor3,b.TextColor3,b.BorderSizePixel,b.ZIndex=Art.Raised,Art.Silver,0,parent.ZIndex+1
	b.Parent=parent;Art.button(b,10);Art.type(b,"Action")
	b.Activated:Connect(action)
	return b
end
local function typeTab(tab,key,compact,width)
	Art.type(tab,"Action",compact)
	if key~="mastery"then return end
	tab.Text="Mastery";tab:SetAttribute("AccessibleLabel","Family mastery ranks")
	local inset=tab:FindFirstChildOfClass("UIPadding")
	local available=width-(if inset then inset.PaddingLeft.Offset+inset.PaddingRight.Offset else 0)
	if Art.textWidth(tab,"Mastery")>available and Art.textWidth(tab,"Ranks")<=available then tab.Text="Ranks"end
end
local function place(node,x,y,w,h)
	node.Position,node.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
end
local function decoration(parent, name, position, size, color, radius)
	local node = Art.frame(parent, name, color, position, size, parent.ZIndex + 1)
	Art.corner(node, radius or 8)
	return node
end
local function destinationArt(host, kind)
	if kind == "eggs" then
		EggArt.create(host, "meadow", UDim2.fromScale(.10, .02), UDim2.fromScale(.80, .96), host.ZIndex + 1)
	elseif kind == "pets" then
		local portrait = Portrait.create(host, Pets.byId.pip, 4, UDim2.fromScale(.5, .5), host.ZIndex + 2)
		local scale = Instance.new("UIScale")
		scale.Name, scale.Parent = "DisplayScale", portrait
	else
		local deck = decoration(host, "Handheld", UDim2.fromScale(.03, .20), UDim2.fromScale(.94, .58), Art.Leaf, 8)
		local screen = decoration(deck, "Screen", UDim2.fromScale(.30, .14), UDim2.fromScale(.42, .72), Art.Ink, 3)
		decoration(screen, "ScreenSprout", UDim2.fromScale(.40, .32), UDim2.fromScale(.22, .42), Art.Leaf, 2)
		decoration(deck, "Rocker", UDim2.fromScale(.09, .43), UDim2.fromScale(.15, .15), Art.Canopy, 2)
		decoration(deck, "DropButton", UDim2.fromScale(.80, .37), UDim2.fromScale(.13, .24), Art.Orange, 100)
	end
end
local function contractArt(host, index)
	if index == 1 then
		FamilyCrest.create(host, "pip", 0, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), host.ZIndex + 1)
	elseif index == 2 then
		for _, x in ipairs({ .05, .43 }) do
			local ring = decoration(host, "ChainLink", UDim2.fromScale(x, .22), UDim2.fromScale(.51, .55), Art.Amber, 100)
			ring.BackgroundTransparency, ring.Rotation = 1, -28
			Art.stroke(ring, Art.Amber, 0, 2)
		end
	else
		local star = decoration(host, "ScoreDiamond", UDim2.fromScale(.24, .20), UDim2.fromScale(.52, .58), Art.Orange, 3)
		star.Rotation = 45
		decoration(host, "ScoreGlint", UDim2.fromScale(.44, .34), UDim2.fromScale(.13, .24), Art.Silver, 2)
	end
end

function Menu.new(parent,callbacks)
	local shade=Art.frame(parent,"DeckMenu",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),28)
	shade.BackgroundTransparency,shade.Active,shade.Visible=1,true,false
	local card=Art.frame(shade,"Card",Art.Surface,UDim2.fromScale(.5,.5),UDim2.fromOffset(680,430),29)
	card.AnchorPoint=Vector2.new(.5,0);Art.panel(card,18)
	local self=setmetatable({shade=shade,card=card,parent=parent,callbacks=callbacks,pages={},tabs={},destinations={},daily={},dailyCards={},families={},familyCards={},familyText={},familyHints={},page="play",state={}},Menu)
	self.heading=text(card,"Heading","Pocket menu","Heading")
	self.wallet=decoration(card,"Wallet",UDim2.fromOffset(0,0),UDim2.fromOffset(180,28),Art.Inset,8)
	EggArt.nectar(self.wallet,UDim2.fromOffset(6,4),UDim2.fromOffset(18,20),self.wallet.ZIndex+1)
	self.nectar=text(self.wallet,"Nectar","0 nectar","Body",Art.Amber)
	self.closeButton=Art.bareClose(button(card,"Close","×",function()self:activate("close")end))
	self.resumeButton=button(card,"Deck","Resume",function()self:activate("play")end)
	self.resumeButton.BackgroundColor3,self.resumeButton.TextColor3=Art.Leaf,Art.Ink
	self.dailyButton=button(card,"DailyBonus","Gift +6",function()self:activate("daily")end)
	local body=Instance.new("ScrollingFrame")
	body.Name,body.BackgroundTransparency,body.BorderSizePixel,body.ZIndex="Body",1,0,30
	body.ScrollBarThickness,body.ScrollBarImageColor3=4,Art.Leaf
	body.ScrollingDirection,body.ElasticBehavior,body.Parent=Enum.ScrollingDirection.Y,Enum.ElasticBehavior.Never,card
	self.body=body
	self.moreCue=text(card,"MoreBelow","","Action",Art.Leaf)
	self.moreCue.TextXAlignment=Enum.TextXAlignment.Center;self.moreCue.ZIndex=40
	for _,entry in ipairs({{3,45},{7,-45}}) do
		local bar=Art.frame(self.moreCue,"Chevron",Art.Leaf,UDim2.fromOffset(entry[1],8),UDim2.fromOffset(7,2),41)
		bar.Rotation=entry[2]
	end
	for _,key in ipairs({"play","daily","mastery"}) do
		local page=Art.frame(body,key,Art.Surface,UDim2.fromOffset(0,0),UDim2.fromOffset(100,100),31)
		page.BackgroundTransparency=1;self.pages[key]=page
		self.tabs[key]=button(card,"Tab_"..key,if key=="play" then "Play" elseif key=="daily" then "Daily" else "Mastery",function()self:setPage(key)end)
	end
	for _,entry in ipairs({{"Eggs","Hatch eggs","eggs","View eggs and odds"},{"Pets","Pet journal","pets","Meet your collection"},{"Style","Deck style","style","Make it yours"}}) do
		local b=button(self.pages.play,entry[1],"",function()self:activate(entry[3])end)
		local illustration=Art.frame(b,"Illustration",Art.Ink,UDim2.fromOffset(0,0),UDim2.fromOffset(64,64),b.ZIndex+1)
		illustration.BackgroundTransparency=1;destinationArt(illustration,entry[3])
		local title=text(b,"Title",entry[2],"Action")
		local subtitle=text(b,"Subtitle",entry[4],"Supporting",Art.Muted)
		table.insert(self.destinations,{button=b,art=illustration,title=title,subtitle=subtitle,kind=entry[3]})
	end
	self.recipePanel=decoration(self.pages.play,"EggGoalPanel",UDim2.fromOffset(0,0),UDim2.fromOffset(100,64),Art.Inset,10)
	EggArt.create(self.recipePanel,"meadow",UDim2.fromOffset(10,9),UDim2.fromOffset(34,44),self.recipePanel.ZIndex+1)
	self.recipe=text(self.recipePanel,"EggGoal","Mixed Meadow · 0/18 nectar","Body")
	self.playHint=text(self.pages.play,"NectarPurpose","Complete LEFT and RIGHT to earn nectar. Keep the pile low for +2.","Supporting",Art.Muted)
	for index=1,3 do
		local panel=decoration(self.pages.daily,"Contract"..index,UDim2.fromOffset(0,0),UDim2.fromOffset(100,164),Art.Raised,12)
		local icon=Art.frame(panel,"Illustration",Art.Ink,UDim2.fromOffset(0,0),UDim2.fromOffset(32,32),panel.ZIndex+1)
		icon.BackgroundColor3,icon.BackgroundTransparency=Art.Inset,0;Art.corner(icon,10);contractArt(icon,index)
		local title=text(panel,"Title","Loading…","Action")
		local count=text(panel,"Count","0/1","Heading")
		local reward=text(panel,"Reward","+0 nectar","Supporting",Art.Amber)
		local track=decoration(panel,"Track",UDim2.fromOffset(0,0),UDim2.fromOffset(100,5),Art.Ink,3)
		local fill=decoration(track,"Fill",UDim2.fromOffset(0,0),UDim2.fromScale(0,1),Art.Leaf,3)
		self.daily[index]=title;self.dailyCards[index]={panel=panel,art=icon,title=title,count=count,reward=reward,fill=fill,complete=false,amount=0}
	end
	self.dailyHint=text(self.pages.daily,"GiftExplanation","Contracts pay automatically after a round. The daily gift above is separate.","Supporting",Art.Muted)
	self.familyNote=text(self.pages.mastery,"FamilyNote","Pick a family for your next round.","Body",Art.Muted)
	for _,family in ipairs(Catalog.Families) do
		local panel=decoration(self.pages.mastery,"Card_"..family,UDim2.fromOffset(0,0),UDim2.fromOffset(100,120),Art.Raised,12)
		local b=button(panel,"Family_"..family,"",function()self:activate("family",family)end)
		b.BackgroundTransparency=1;b.TextTransparency=1
		local border=b:FindFirstChildOfClass("UIStroke");if border then border.Transparency=.65 end
		FamilyCrest.create(b,family,0,UDim2.fromOffset(10,8),UDim2.fromOffset(30,30),b.ZIndex+2,true)
		local caption=text(b,"FamilyName",names[family],"Action")
		self.families[family],self.familyCards[family]=b,panel
		self.familyText[family]=text(panel,"Progress_"..family,"Not discovered","Supporting")
		self.familyHints[family]=text(panel,"Reward_"..family,"Hatch a member of this family to begin mastery.","Body",Art.Muted)
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:layout()end)
	body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:refreshScrollCue()end)
	body:GetPropertyChangedSignal("CanvasPosition"):Connect(function()self:refreshScrollCue()end)
	Art.watchTextPreference(shade,function()return shade.Visible end,function()self.safeTop=nil;self:layout()end)
	self:setPage("play");self:layout()
	return self
end
function Menu:activate(key,value)
	if not self.shade.Visible then return false end
	if key=="daily" and not self.dailyButton.Interactable then return false end
	if key=="family" and (not self.families[value] or not self.families[value].Interactable) then return false end
	local callback=self.callbacks[key];if not callback then return false end
	callback(value);return true
end
function Menu:layout()
	if self.layingOut then return end
	self.layingOut=true
	local size=self.parent.AbsoluteSize
	local width=math.max(1,math.min(680,size.X-24))
	self.shallow=size.Y>=280 and size.Y<440
	self.compact=size.Y<280 or self.shallow
	self.width,self.pad=width,if self.compact then 8 else 12
	local pad=self.pad;local usable=math.max(1,width-pad*2)
	self.wallet.Parent,self.nectar.Parent=self.card,self.wallet
	local notice=self.saveNotice
	self.headerTitle=if notice then notice.short else "Pocket menu"
	self.headerPlan=Art.sheetHeader(width,self.heading,self.wallet,self.nectar,self.wallet.NectarDrop,self.closeButton,{
		pad=pad,top=if self.compact then 0 else 8,amount=self.state.nectar or 0,title=self.headerTitle,
		shortTitle=if notice then notice.narrow else "Menu",accessibleTitle=if notice then notice.detail else "Pocket menu",status=notice~=nil,secondary=self.resumeButton})
	self.resumeInBody=not self.headerPlan.secondaryHeader
	self.resumeButton.Parent=if self.resumeInBody then self.pages.play else self.card
	self.resumeButton.BackgroundColor3,self.resumeButton.TextColor3=Art.Raised,Art.Silver
	local tabH=44
	for key,tab in pairs(self.tabs)do typeTab(tab,key,true,(usable-12)/3);tabH=math.max(tabH,Art.actionHeight(tab,(usable-12)/3))end
	local tabY=self.headerPlan.height+(if self.compact then 4 else 8)
	self.headerHeight=tabY+tabH+(if self.compact then 4 else 8)
	local maximum=math.max(1,size.Y-(if self.compact then 8 else 24));local bottom=if self.compact then 4 else 8
	self.bodyBudget=math.max(44,maximum-self.headerHeight-bottom)
	self.scrollChrome,self.scrollChromeHeight=false,0
	self:layoutContents()
	local height=math.min(maximum,self.headerHeight+(self.pageHeights[self.page]or 0)+bottom)
	if self.layoutRootSize~=size or self.safeTop==nil then
		local tallest=0;for _,h in pairs(self.pageHeights)do tallest=math.max(tallest,h)end
		self.safeTop=math.max(0,(size.Y-math.min(maximum,self.headerHeight+tallest+bottom))/2);self.layoutRootSize=size
	end
	self.card.Position,self.card.Size=UDim2.new(.5,0,0,self.safeTop),UDim2.fromOffset(width,height)
	for index,key in ipairs({"play","daily","mastery"})do place(self.tabs[key],pad+(index-1)*usable/3,tabY,usable/3-4,tabH)end
	place(self.body,pad,self.headerHeight,usable,math.max(44,height-self.headerHeight-bottom))
	place(self.moreCue,width-18,height-26,16,20)
	self.body.CanvasPosition=Vector2.new(0,math.clamp(self.body.CanvasPosition.Y,0,math.max(0,self.body.CanvasSize.Y.Offset-self.body.Size.Y.Offset)))
	self.headerLayoutKey=table.concat({self.headerTitle,self.nectar.Text,self.dailyButton.Text},"|")
	self:refreshScrollCue();self.layingOut=false
end
function Menu:layoutContents(wanted)
	if not self.width then return end
	self.layoutPasses=(self.layoutPasses or 0)+1
	self.pageHeights=self.pageHeights or {}
	self.renderedSignatures=self.renderedSignatures or {}
	local width=self.width-self.pad*2-8
	local inset=if self.compact then 4 else 12
	local usable=width-inset*2
	local short=self.compact
	local list=usable<480
	if short and not list then
		local column=(usable-24)/3;local tallest=44
		for _,item in ipairs(self.destinations)do
			Art.type(item.title,"Action",true)
			tallest=math.max(tallest,Art.textHeight(item.title,column-(if self.shallow then 58 else 46)-8,24)+8)
		end
		if tallest+inset*2>(self.bodyBudget or math.huge)then list=true end
	end

	local start=inset+(self.scrollChromeHeight or 0)
	local y=start
	if not wanted or wanted=="play" then
	local destinationHeight=if short then (if self.shallow then 56 else 44) elseif list then 88 else 168
	for _,item in ipairs(self.destinations) do
		Art.type(item.title,"Action",short);Art.type(item.subtitle,"Supporting",short)
		local w=if list then usable else (usable-24)/3
		local tx=if short then (if self.shallow then 58 else 46) elseif list then 78 else 8
		local titleH=Art.textHeight(item.title,w-tx-8,if short then 24 else 26)
		local subH=Art.textHeight(item.subtitle,w-tx-8,24)
		item.titleH,item.subH=titleH,subH
		destinationHeight=math.max(destinationHeight,if short then titleH+8 elseif list then titleH+subH+36 else 12+72+12+titleH+subH+20)
	end
	for index,item in ipairs(self.destinations) do
		local w=if list then usable else (usable-24)/3
		local x=inset+(if list then 0 else (index-1)*(w+12))
		local top=y+(if list then (index-1)*(destinationHeight+8) else 0)
		place(item.button,x,top,w,destinationHeight)
		local horizontal=short or list;local artSize=if short then (if self.shallow then 36 else 24) elseif list then 56 else 72
		place(item.art,if horizontal then 10 else (w-artSize)/2,if horizontal then (destinationHeight-artSize)/2 else 12,artSize,artSize)
		if item.kind=="pets" then item.art.Portrait.DisplayScale.Scale=artSize/64 end
		local tx=if horizontal then artSize+22 else 8
		local ty=if short then (destinationHeight-item.titleH)/2 elseif list then 14 else 96
		place(item.title,tx,ty,w-tx-8,item.titleH)
		item.title.TextXAlignment=if horizontal then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
		item.subtitle.Visible=not short;place(item.subtitle,tx,ty+item.titleH+6,w-tx-8,item.subH);item.subtitle.TextXAlignment=item.title.TextXAlignment
	end
	y+=if list then #self.destinations*(destinationHeight+8)-8 else destinationHeight
	if self.resumeInBody then
		self.resumeButton.Parent=self.pages.play;y+=8
		place(self.resumeButton,inset,y,math.min(usable,self.headerPlan.secondaryWidth),self.headerPlan.secondaryHeight)
		y+=self.headerPlan.secondaryHeight
	end
	local recipeH=math.max(64,Art.textHeight(self.recipe,usable-64,48)+16)
	y+=12;place(self.recipePanel,inset,y,usable,recipeH);place(self.recipe,54,8,usable-64,recipeH-16)
	y+=recipeH+12;local hintH=Art.textHeight(self.playHint,usable,40);place(self.playHint,inset,y,usable,hintH)
	self.pageHeights.play=y+hintH+inset
	end
	if not wanted or wanted=="daily" then
	y=start
	Art.type(self.dailyButton,"Action",true)
	self.dailyButton.Parent=self.pages.daily
	local giftW=math.min(usable,math.max(44,Art.textWidth(self.dailyButton)+16))
	local giftH=Art.actionHeight(self.dailyButton,giftW)
	if self.state.dailyAvailable then place(self.dailyButton,inset,y,giftW,giftH);y+=giftH+8 end
	local dailyH=if short then 44 elseif list then 96 else 176
	for _,row in ipairs(self.dailyCards) do
		local w=if list then usable else (usable-24)/3
		Art.type(row.title,"Action",short);Art.type(row.count,"Heading",short);Art.type(row.reward,"Supporting",short)
		if short then row.title.TextSize=12;row.count.TextSize=14 end
		row.reward.Text=if row.complete then "Earned" else (if short then "+"..row.amount else "+"..row.amount.." nectar")
		local tw=if list and not short then w-72 else w-12
		row.titleH=Art.textHeight(row.title,tw,if short then 18 else 28)
		row.countH=Art.textHeight(row.count,if short then w*.5-28 else tw,if short then 20 else 30)
		row.rewardH=Art.textHeight(row.reward,if short then w*.5-6 else tw,20)
		dailyH=math.max(dailyH,if short then row.titleH+math.max(row.countH,row.rewardH)+8 elseif list then row.titleH+row.countH+row.rewardH+32 else 64+row.titleH+row.countH+row.rewardH+24)
	end
	for index,row in ipairs(self.dailyCards) do
		local w=if list then usable else (usable-24)/3
		place(row.panel,inset+(if list then 0 else (index-1)*(w+12)),y+(if list then (index-1)*(dailyH+8) else 0),w,dailyH)
		local horizontal=list and not short
		place(row.art,if horizontal then 12 elseif short then 6 else (w-44)/2,if short then row.titleH+2 elseif horizontal then 24 else 8,if short then 18 else 44,if short then 18 else 44)
		local tx=if horizontal then 60 else 6;local ty=if short then 1 elseif horizontal then 12 else 64
		place(row.title,tx,ty,w-tx-6,row.titleH);row.title.TextXAlignment=if horizontal then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
		local cy=ty+row.titleH+(if short then 2 else 4)
		place(row.count,if horizontal then 60 elseif short then 28 else 6,cy,if short then w*.5-28 else w-tx-6,row.countH)
		row.count.TextXAlignment=row.title.TextXAlignment
		place(row.reward,if short then w*.5 else tx,if short then cy else cy+row.countH+4,if short then w*.5-6 else w-tx-6,row.rewardH)
		row.reward.TextXAlignment=row.title.TextXAlignment
		place(row.fill.Parent,6,dailyH-7,w-12,if short then 3 else 5)
	end
	y+=if list then #self.dailyCards*(dailyH+8)-8 else dailyH
	if not self.state.dailyAvailable then y+=8;place(self.dailyButton,inset,y,giftW,giftH);y+=giftH end
	y+=12;local hintH2=Art.textHeight(self.dailyHint,usable,44);place(self.dailyHint,inset,y,usable,hintH2)
	self.pageHeights.daily=y+hintH2+inset
	end
	if not wanted or wanted=="mastery" then
	y=if short then inset else start
	local noteH=Art.textHeight(self.familyNote,usable,44)
	if not short then place(self.familyNote,inset,y,usable,noteH);y+=noteH+12 end
	local familyOrder=table.clone(Catalog.Families)
	if short and self.selectedFamily then
		local selected=table.find(familyOrder,self.selectedFamily)
		if selected then table.remove(familyOrder,selected);table.insert(familyOrder,1,self.selectedFamily)end
	end
	for _,family in ipairs(familyOrder) do
		local panel,b,hint=self.familyCards[family],self.families[family],self.familyHints[family]
		Art.type(hint,"Body",short)
		local owned=b:GetAttribute("FamilyOwned")==true
		Art.type(b.FamilyName,"Action",short);Art.type(self.familyText[family],"Supporting",short)
		local buttonH=math.max(44,Art.textHeight(b.FamilyName,usable-62,0)+12)
		local rankH=Art.textHeight(self.familyText[family],usable-24,24)
		local hintY=buttonH+(if owned then rankH+8 else 8)
		local hintH=Art.textHeight(hint,usable-24,if owned then 36 else 24)
		local cardH=hintY+hintH+12
		place(panel,inset,y,usable,cardH);place(b,0,0,usable,buttonH)
		place(b.FamilyName,50,0,usable-62,buttonH)
		self.familyText[family].Visible=owned
		place(self.familyText[family],12,buttonH+4,usable-24,rankH)
		place(hint,12,hintY,usable-24,hintH)
		y+=cardH+12
	end
	if short then place(self.familyNote,inset,y,usable,noteH);y+=noteH+12 end
	self.pageHeights.mastery=y+(if short then self.scrollChromeHeight or 0 else 0)
	end
	for key,page in pairs(self.pages) do
		if not wanted or key==wanted then
			page.Size=UDim2.fromOffset(width,self.pageHeights[key] or 0)
			self.renderedSignatures[key]=self.contentSignatures and self.contentSignatures[key] or ""
		end
	end
	self.body.CanvasSize=UDim2.fromOffset(0,self.pageHeights[self.page] or 0)
	self:refreshScrollCue()
end
function Menu:refreshScrollCue()
	local overflow=self.body.CanvasSize.Y.Offset>self.body.AbsoluteSize.Y+1
	self.body.ScrollingEnabled=overflow;self.body.ScrollBarImageTransparency=if overflow then 0 else 1
	self.moreCue.Visible=overflow and self.body.CanvasPosition.Y+self.body.AbsoluteSize.Y<self.body.CanvasSize.Y.Offset-1
end
function Menu:update(state, selected, runFamily, score, chain, best, recipeId)
	state = state or {}; self.state = state;self.selectedFamily=selected;self.runFamily=runFamily;self.recipeId=recipeId
	self.nectar.Text = tostring(state.nectar or 0)
	local recipe = Catalog.ById[recipeId] or Catalog.ById.meadow
	self.recipe.Text = recipe.name .. " · " .. (state.nectar or 0) .. "/" .. recipe.cost .. " nectar"
	local egg = self.recipePanel:FindFirstChild("Egg")
	if egg and egg:GetAttribute("RecipeId") ~= (recipeId or "meadow") then
		egg:Destroy(); EggArt.create(self.recipePanel, recipeId or "meadow", UDim2.fromOffset(10, 9), UDim2.fromOffset(34, 44), self.recipePanel.ZIndex + 1)
	end
	self.dailyButton.Text = if state.dailyAvailable then "Gift +" .. (state.dailyBonus or 6) else "Gift claimed"
	self.dailyButton.Interactable = state.dailyAvailable == true and state.status == "Ready"
	self.dailyButton.Selectable=self.dailyButton.Interactable
	self.dailyButton.BackgroundColor3 = if self.dailyButton.Interactable then Art.Amber else Art.Raised
	self.dailyButton.TextColor3 = if self.dailyButton.Interactable then Art.Ink else Art.Muted
	self.dailyHint.Text = if state.dailyAvailable then "Claim your separate daily gift above. Contracts pay automatically after a round."
		else "Daily gift claimed. Finish rounds to complete these contracts; fresh goals arrive tomorrow."
	for index, row in ipairs(self.dailyCards) do
		local contract = state.contracts and state.contracts[index]
		local progress, target = if contract then contract.progress or 0 else 0, if contract then contract.target or 1 else 1
		row.title.Text = if contract then contract.name or contract.title or contract.id else "First pet unlocks"
		row.count.Text = string.format("%d/%d", math.min(progress, target), target)
		row.complete, row.amount = contract and (contract.claimed or contract.complete) == true or false, if contract then contract.reward or 0 else 0
		row.fill.Size = UDim2.fromScale(math.clamp(progress / math.max(1, target), 0, 1), 1)
		row.fill.BackgroundColor3 = if row.complete then Art.Amber else Art.Leaf
		row.reward.Text=if row.complete then "Earned" else (if self.compact then "+"..row.amount else "+"..row.amount.." nectar")
	end
	for family, b in pairs(self.families) do
		local owned = false
		for _, pet in ipairs(Pets.collection) do if (pet.family or pet.id) == family and Catalog.isOwned(state.inventoryMask, pet.id) then owned = true end end
		local points = state.mastery and state.mastery[family] or 0
		local detail = state.masteryDetails and state.masteryDetails[family]
		local rank = if detail then detail.rank else (state.masteryRanks and state.masteryRanks[family] or 0)
		local missing = detail and detail.missingChallenges
		self.familyHints[family].Text = if not owned then "Hatch a member of this family to begin mastery."
			elseif rank >= 3 then "Family mastered\nBloom family effect unlocked"
			elseif detail and detail.nextGoal then detail.nextGoal
				.. (if rank == 2 and missing and #missing > 0 then "\nStill needed: " .. table.concat(missing, " · ") else "")
				.. (if detail.rewardHint then "\n" .. detail.rewardHint:gsub("^Next: ","Unlocks ") else "")
			else "Win rounds or hatch duplicates for family marks."
		b.Interactable = owned and state.status == "Ready"
		b.Selectable=owned;b:SetAttribute("FamilyOwned",owned)
		b:FindFirstChildOfClass("UIStroke").Transparency=if owned then .22 else 1
		self.familyCards[family].BackgroundColor3=if selected==family then Art.Inset else Art.Raised
		FamilyCrest.update(b.FamilyCrest, family, rank, not owned)
		b.FamilyName.Text = names[family] .. (if selected == family then " · Next round ✓" elseif not owned then " · Locked" else " · Choose")
		self.familyText[family].Text = if not owned then "Discover a family member in eggs"
			elseif rank >= 3 then string.format("Rank III · mastered · %d total marks", points)
			else string.format("Rank %s · %d/%d marks", ({ [0] = "—", "I", "II", "III" })[rank] or "III", points, if rank == 0 then 3 elseif rank == 1 then 10 else 25)
	end
	self.familyNote.Text = "Next round: " .. (names[selected] or "Pip") .. (if runFamily and runFamily ~= selected then " · Current run: " .. (names[runFamily] or "Pip") else "") .. "\nWins +1 mark · low-pile wins +2 · duplicates +1"
	self.headerTitle=if self.saveNotice then self.saveNotice.short else "Pocket menu"
	if not self.shade.Visible then self.heading.Text=self.headerTitle end
	self.playHint.Text="Complete LEFT and RIGHT to earn nectar. Keep the pile low for +2."
	if self.saveNotice then
		self.playHint.Text=self.saveNotice.detail.."\n"..self.playHint.Text
		self.dailyHint.Text=self.saveNotice.detail.."\n"..self.dailyHint.Text
		self.familyNote.Text=self.saveNotice.detail.."\n"..self.familyNote.Text
	end
	self.card:SetAttribute("RunScore", score or 0); self.card:SetAttribute("RunChain", chain or 0); self.card:SetAttribute("PersonalBest", best or 0)
	local dailySignature={self.dailyHint.Text}
	for _,row in ipairs(self.dailyCards) do table.insert(dailySignature,row.title.Text) end
	local familySignature={self.familyNote.Text}
	for _,family in ipairs(Catalog.Families) do
		table.insert(familySignature,self.familyHints[family].Text..tostring(self.families[family]:GetAttribute("FamilyOwned")))
	end
	self.contentSignatures={play=self.recipe.Text..self.playHint.Text,daily=table.concat(dailySignature,"|"),mastery=table.concat(familySignature,"|")}
	if self.shade.Visible then
		local headerKey=table.concat({self.headerTitle,self.nectar.Text,self.dailyButton.Text},"|")
		if self.headerLayoutKey~=headerKey then self:layout()
		elseif self.renderedSignatures and self.renderedSignatures[self.page]~=self.contentSignatures[self.page]then self:layoutContents(self.page)end
	end
end

function Menu:setSaveNotice(notice)
	if SaveNotice.key(self.saveNotice)==SaveNotice.key(notice)then return false end
	self.saveNotice=notice
	self:update(self.state,self.selectedFamily,self.runFamily,self.card:GetAttribute("RunScore"),self.card:GetAttribute("RunChain"),self.card:GetAttribute("PersonalBest"),self.recipeId)
	self:layout();return true
end
function Menu:setPage(key)
	if not self.pages[key] then return end
	self.page=key
	for name,page in pairs(self.pages) do page.Visible=name==key end
	for name,tab in pairs(self.tabs) do tab.BackgroundColor3=if name==key then Art.Inset else Art.Raised;tab.TextColor3=if name==key then Art.Leaf else Art.Silver end
	self.resumeButton.Visible,self.dailyButton.Visible=key=="play",key=="daily"
	self.body.CanvasPosition=Vector2.zero;self:layout()
end
function Menu:bumpControllerEpoch()
	self.shade:SetAttribute("ControllerEpoch",(self.shade:GetAttribute("ControllerEpoch")or 0)+1)
end
function Menu:getControllerFocus()
	if not self.shade.Visible then return nil end
	return{root=self.shade,epoch=self.shade:GetAttribute("ControllerEpoch")or 0,
		target=function()return self.tabs[self.page]or self.closeButton end,fallback=self.closeButton}
end
function Menu:open()
	self:bumpControllerEpoch()
	self.previousSelection=GuiService.SelectedObject
	self.body.CanvasPosition=Vector2.zero
	self.safeTop=nil
	self.shade.Visible=true;self:layout()
	if string.match(game:GetService("UserInputService"):GetLastInputType().Name,"^Gamepad") then GuiService.SelectedObject=self.closeButton end
end
function Menu:close()
	if self.shade.Visible then self:bumpControllerEpoch()end
	self.shade.Visible=false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade) then
		local previous=self.previousSelection
		GuiService.SelectedObject=if previous and previous.Parent and previous.Visible then previous else nil
	end
end
return Menu
