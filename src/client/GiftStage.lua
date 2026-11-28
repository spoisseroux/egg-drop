-- The free egg's reveal on the regular full-screen hatch stage (beta 42 note 5: "why arent we using the regular hatch
-- screen when doing the free egg hatch? ... just use the fullscreen regular egg hatch anim/screen"; DIAGNOSIS A5;
-- Onboard "gifts"). The paid Paint Egg's path, unchanged: HueItemReveal -> HatchCinematic -> HatchItemStage (the lid,
-- the iris, the burst, the tier's well, the name and its line), in its own full-screen ScreenGui. The Toy gift is the
-- Toy Egg's own reveal (the same adapter, recipe "toy", RewardItemArt). The Snack gift already plays the Stat Egg's
-- reveal (SnackHost), so it never comes here.
-- What makes it the gift: the stage's sticker reads "A gift from {pet}!" (in place of the tier word), the line under the
-- name is the gift's own odds ("Each colour: 1 in 4"), and the two keys are the card's: "Paint {pet}!" (or "Play!") and
-- "Later" (the corner x is Later too). No odds tray, no Hatch another, no price.
-- The callbacks are GiftReveal's, unchanged, so init's present() wires both the same way: act(record) at the primary
-- press (lesson A's hand-off), then, once the stage's iris has shut, landed(record) (a primary only), seen(record) and
-- closed() (the machine's camera back, GiftChain's reveal phase over). Each runs once. A stage that is torn down any
-- other way (replaced, its gui gone) before a choice still calls closed() (never seen(): it replays on the next join);
-- after a choice (a key pressed, its iris still shutting) it finishes as chosen: landed, seen, closed. closed(how) says
-- "replaced" when a newer gift's stage is taking over (that stage's shot owns the camera: closed must not hand it back
-- or open the pet screen), "lost" when its gui went, nil otherwise.
-- show(playerGui, record, options) -> true when the stage opened; false (nothing left behind): the caller shows
-- GiftReveal, the fallback card. options = GiftReveal's (text, pet, petId, itemName, poolSize, deeper, act, landed,
-- seen, closed, reduced) plus audio (BoardAudio, the cinematic's sounds) and reduceEffects.
-- Pure parts first (spec-checked: GiftStage.spec); the services and the stage are required only when it shows.
local Stage={}
Stage.IrisShut=.30     -- s after a key: HatchItemStage's iris is shut (Stage.leaveSample), the callbacks run under it
Stage.ReducedShut=.15
Stage.Teardown=.70     -- s after a key: the stage has left (LeaveTime .56), its gui goes
Stage.DisplayOrder=40  -- GiftReveal's card's
Stage.Action="EggDropGiftStage"
local current=nil -- the open stage's entry

function Stage.isOpen()return current~=nil end
-- Pure: the hatch result the stage plays for a gift record, and its recipe ("hue" | "toy"); nil for any other gift.
function Stage.result(record)
	if type(record)~="table"or type(record.item)~="string"or record.item==""then return nil end
	local id="gift:"..(if record.id~=nil then tostring(record.id)else tostring(record.kind)..":"..record.item)
	if record.kind=="paint"then return {id=id,itemId=record.item},"hue"end
	if record.kind=="toy"then return {id=id,toyId=record.item},"toy"end
	return nil
end
-- Pure: the stage's words. -> {sticker, name, detail, primary, secondary}
function Stage.words(record,options)
	local text=options.text
	local w={sticker=text("onbGift.card.from",{pet=options.pet}),secondary=text("onbGift.card.later")}
	if record.kind=="paint"then
		local name=options.itemName or record.item
		w.name=if options.deeper then text("onbGift.card.deeper",{name=name})else text("onbGift.card.pot",{name=name})
		w.detail=text("onbGift.card.potOdds")
		w.primary=text("onbGift.card.paint",{pet=options.pet})
	else
		w.name=options.itemName or record.item
		w.detail=text("onbGift.card.toyOdds",{count=options.poolSize or 1})
		w.primary=text("onbGift.card.play")
	end
	return w
end
-- Pure: one choice, the callbacks once and in order. leave(acted) dismisses the stage and later calls f.finish().
--   f.choose(acted)   the primary (true) or Later / x (false); a second choice is ignored. -> true when taken
--   f.finish(how)     the stage is gone: nil (after a choice: landed if acted, seen, closed), "lost" (closed only)
--   f.lose(why)       torn down early ("replaced" | "lost"): chosen, it finishes as chosen; unchosen, closed only.
--                     closed hears `why` either way
function Stage.flow(record,options,leave)
	local f={chosen=nil,done=false}
	local function call(name,...)
		local fn=options[name]
		if fn then local ok,problem=pcall(fn,...);if not ok then warn("[GiftStage] "..name..": "..tostring(problem))end end
	end
	function f.choose(acted)
		if f.chosen~=nil or f.done then return false end
		f.chosen=acted==true
		if f.chosen then call("act",record)end
		leave(f.chosen)
		return true
	end
	local function finish(how,why)
		if f.done then return end
		f.done=true
		if how=="lost"or f.chosen==nil then call("closed",why);return end
		if f.chosen then call("landed",record)end
		call("seen",record)
		call("closed",why)
	end
	function f.finish(how)finish(how,if how=="lost"then "lost"else nil)end
	-- Code review (beta 43): a press already chosen is never thrown away by a newer gift within the iris's .3 s
	function f.lose(why)
		why=if why=="replaced"then "replaced"else "lost"
		finish(if f.chosen~=nil then nil else "lost",why)
	end
	return f
end

-- ── The stage ─────────────────────────────────────────────────────────────────────────────────────────────────────
local function node(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props)do n[k]=v end
	n.Parent=parent
	return n
end
function Stage.show(playerGui,record,options)
	local result,recipe=Stage.result(record)
	if not result or typeof(playerGui)~="Instance"then return false end
	if current then current.lose("replaced")end -- the old one finishes first (chosen or not), then this one takes over
	local entry={}
	local gui,reveal,unregisterCursor
	local ContextActionService=game:GetService("ContextActionService")
	local function reduced()return options.reduced~=nil and options.reduced()==true end
	local function teardown()
		pcall(function()ContextActionService:UnbindAction(Stage.Action)end)
		if unregisterCursor then pcall(unregisterCursor);unregisterCursor=nil end
		if reveal then pcall(reveal.destroy,reveal);reveal=nil end
		if gui then gui:Destroy();gui=nil end
	end
	local flow
	local function leave()
		pcall(function()ContextActionService:UnbindAction(Stage.Action)end)
		-- the stage leaves by its iris and lid (HatchItemStage:dismiss); the callbacks run once the iris is shut, so the
		-- camera's hand-back and the pet screen happen under it
		if reveal then pcall(reveal.clear,reveal)end
		task.delay(if reduced()then Stage.ReducedShut else Stage.IrisShut,function()
			if current==entry then current=nil end
			flow.finish()
		end)
		task.delay(Stage.Teardown,teardown)
	end
	flow=Stage.flow(record,options,leave)
	entry.flow=flow
	-- replaced by a newer gift ("replaced"), or its gui gone ("lost"): unchosen, closed (the chain) and never seen;
	-- chosen, finished as chosen. The iris's delayed finish is then nothing (done).
	function entry.lose(why)
		if current==entry then current=nil end
		teardown()
		flow.lose(why)
	end
	local words=Stage.words(record,options)
	local ok,problem=pcall(function()
		local ItemReveal=require(script.Parent:WaitForChild("HueItemReveal"))
		gui=node("ScreenGui",playerGui,{Name="EggDropGiftStage",ResetOnSpawn=false,IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.None,
			DisplayOrder=Stage.DisplayOrder,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
		local host=node("Frame",gui,{Name="StageHost",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=2})
		-- the cinematic's own frame, under the stage (its scene is borrowed by the stage, which covers it and takes the taps)
		local art=node("Frame",gui,{Name="GiftArt",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
			Size=UDim2.fromOffset(140,140),ZIndex=1})
		local function owns()return current==entry and gui~=nil and gui.Parent~=nil and gui.Enabled end
		local builder=nil
		if recipe=="toy"then
			local ItemArt=require(script.Parent:WaitForChild("RewardItemArt"))
			builder=function(parent,r,position,size,z)return ItemArt.create(parent,r,position,size,z)end
		end
		reveal=ItemReveal.new(art,{audio=options.audio,reduceEffects=options.reduceEffects or reduced,recipeId=recipe,resultBuilder=builder,owns=owns})
		reveal.options.stage={parent=host,owns=owns,zIndex=20,
			name=function()return words.name end,detail=function()return words.detail end,sticker=function()return words.sticker end,
			actions=function()return {{text=words.secondary,primary=false,act=function()flow.choose(false)end},
				{text=words.primary,primary=true,act=function()flow.choose(true)end}}end,
			close=function()flow.choose(false)end,gone=function()end}
		current=entry
		reveal:show(result,true)
		if not reveal.stage then error("the stage did not open")end
		gui:SetAttribute("GiftKind",record.kind);gui:SetAttribute("GiftItem",record.item)
		unregisterCursor=require(script.Parent:WaitForChild("ModalCursor")).register(entry,function()return current==entry end)
		-- keys: A / Enter the primary, B / Esc Later, once the card has settled; before that they skip (the stage's rule)
		ContextActionService:BindActionAtPriority(Stage.Action,function(_,state,input)
			if current~=entry or game:GetService("GuiService").MenuIsOpen then return Enum.ContextActionResult.Pass end
			if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
			local k=input.KeyCode
			local stage=reveal and reveal.stage
			local settled=stage~=nil and stage:inputOpen()
			local primary=k==Enum.KeyCode.ButtonA or k==Enum.KeyCode.Return or k==Enum.KeyCode.KeypadEnter or k==Enum.KeyCode.Space
			if not settled then if reveal then reveal:skip()end;return Enum.ContextActionResult.Sink end
			if reveal and reveal:consumeSkipInput()then return Enum.ContextActionResult.Sink end
			flow.choose(primary)
			return Enum.ContextActionResult.Sink
		end,false,Enum.ContextActionPriority.High.Value+830,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,Enum.KeyCode.Return,
			Enum.KeyCode.KeypadEnter,Enum.KeyCode.Space,Enum.KeyCode.Escape,Enum.KeyCode.Backspace)
		gui.AncestryChanged:Connect(function()
			if gui and gui.Parent==nil and current==entry then entry.lose("lost")end
		end)
	end)
	if not ok then
		warn("[GiftStage] not opened (the gift card instead): "..tostring(problem))
		if current==entry then current=nil end
		flow.done=true -- the fallback card owns the callbacks now
		teardown()
		return false
	end
	return true
end
return Stage
