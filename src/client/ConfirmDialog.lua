-- One confirm dialog for big spends and actions that can't be undone (round 3, Spencer
-- 2026-11-20: "don't do press again to adopt for 400 for the bunny, open a confirmation
-- dialog, for anything really expensive like that, or anything we need to confirm").
-- A small Toy Shell card over a shade, above every menu: a title, one line, Cancel and the
-- confirm key. Enter / A / Space confirm; Esc / B / Backspace or a tap on the shade cancel.
-- Presentation only: the caller keeps its own pending and send logic and re-checks its own
-- state in onConfirm (the screen under it may have changed while the dialog was up).
--
--   Confirm.ask({title, line, confirm = "Adopt for ★ 400", cancel = "Cancel", tone = "spend" |
--     "danger", onConfirm(), onCancel(reason), onClosed(confirmed)}) -> handle, or nil when it
--     cannot show. handle.cancel() closes it if it is still this ask (call it from the caller's
--     own close(), so a screen that closes underneath never leaves the dialog up).
--   Confirm.isOpen(), Confirm.close(reason) (cancels), Confirm.panel() (specs)
--   Optional `alt` (Stars store access, 2026-11-21): {text, onSelect(), after = seconds the key is ignored} turns the left key into
--   a second choice (X / ButtonX) and adds a round close key top right; B / Esc / the shade
--   still cancel.
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local Kit=require(script.Parent.DeckKit)
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Confirm={}
Confirm.DisplayOrder=45 -- above every menu (9 to 16), the How it works cards (40), under the rail (100)
Confirm.Action="EggDropConfirmDialog"
-- Above every menu (785 to 835), the Stat/Names reveals (830/835) and the bug sheet (820);
-- under How it works (+2000).
Confirm.Priority=Enum.ContextActionPriority.High.Value+1000
local state={open=false}
local owner={} -- the shade stack key

local function make(class,parent,props)
	local object=Instance.new(class)
	for key,value in pairs(props or {})do object[key]=value end
	object.Parent=parent;return object
end

local function ensureGui()
	if state.gui and state.gui.Parent then return state.gui end
	local player=Players.LocalPlayer
	local playerGui=player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return nil end
	local gui=make("ScreenGui",playerGui,{Name="EggDropConfirm",ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder=Confirm.DisplayOrder,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ClipToDeviceSafeArea=false,Enabled=true})
	local root=make("Frame",gui,{Name="Root",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Active=false})
	state.gui,state.root=gui,root
	state.shade=Kit.modalShade(root,"ConfirmShade",10)
	state.shade.InputBegan:Connect(function(input)
		if not state.open then return end
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then Confirm.close("outside")end
	end)
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if state.open then Confirm.build()end end)
	return gui
end

-- Pure: the card's geometry for a W x H screen and the line's measured height.
function Confirm.layout(W,H,lineH)
	local compact=H<=430 or W<=700
	local pad=if compact then 16 else 22
	local w=math.min(if compact then 380 else 440,W-32)
	local titleH=if compact then 26 else 30
	local bh=if compact then 44 else 48
	local h=pad+titleH+8+lineH+(if compact then 16 else 22)+bh+pad
	return{compact=compact,pad=pad,w=w,h=h,titleH=titleH,bh=bh,lineW=w-pad*2,
		buttonW=math.floor((w-pad*2-12)/2)}
end

function Confirm.build()
	local root,o=state.root,state.options
	if not root or not o then return nil end
	if state.panel then state.panel:Destroy();state.panel=nil end
	local size=root.AbsoluteSize
	local W,H=math.max(320,size.X),math.max(240,size.Y)
	local probe=Confirm.layout(W,H,20)
	local lineSize=if probe.compact then 15 else 17
	local lineH=math.max(20,math.ceil(Kit.measure(o.line or "","Body",lineSize,probe.lineW).Y)+4)
	local g=Confirm.layout(W,H,lineH)
	local panel=Kit.frame(root,"ConfirmDialog","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(g.w,g.h),if g.compact then 16 else 22)
	panel.AnchorPoint=Vector2.new(.5,.5);panel.Active=true;panel.ZIndex=20;Kit.stroke(panel)
	panel:SetAttribute("Tone",o.tone or "spend")
	state.panel=panel
	local y=g.pad
	Kit.text(panel,"Title",o.title or "","text",{Name="Title",Position=UDim2.fromOffset(g.pad,y),Size=UDim2.fromOffset(g.lineW,g.titleH),
		TextSize=if g.compact then 20 else 24,TextTruncate=Enum.TextTruncate.AtEnd})
	if o.alt then
		-- Touch needs a way out that isn't one of the two choices.
		local closeSize=if g.compact then 30 else 34
		local x=Kit.closeKey(panel,"Close",closeSize,o.cancel or UICopy.get("confirm.cancel"))
		x.AnchorPoint=Vector2.new(1,0);x.Position=UDim2.fromOffset(g.w-g.pad+6,g.pad-6);x.ZIndex=panel.ZIndex+2
		x.Activated:Connect(function()Confirm.close("cancel")end)
		panel.Title.Size=UDim2.fromOffset(g.lineW-closeSize-6,g.titleH)
		state.x=x
	end
	y+=g.titleH+8
	Kit.text(panel,"Body",o.line or "","soft",{Name="Line",Position=UDim2.fromOffset(g.pad,y),Size=UDim2.fromOffset(g.lineW,lineH),
		TextSize=lineSize,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
	local by=g.h-g.pad-g.bh
	local cancel=Kit.button(panel,if o.alt then "Alt" else "Cancel",{variant="secondary",text=if o.alt then o.alt.text else(o.cancel or UICopy.get("confirm.cancel")),
		glyph=if o.alt then "X" else "B",size=Vector2.new(g.buttonW,g.bh),textSize=if g.compact then 15 else 17})
	cancel.Position=UDim2.fromOffset(g.pad,by);cancel.ZIndex=panel.ZIndex+2
	cancel.Activated:Connect(function()if o.alt then Confirm.chooseAlt()else Confirm.close("cancel")end end)
	local yes=Kit.button(panel,"Confirm",{variant="primary",text=o.confirm or UICopy.get("confirm.yes"),glyph="A",
		size=Vector2.new(g.buttonW,g.bh),textSize=if g.compact then 15 else 17})
	yes.Position=UDim2.fromOffset(g.w-g.pad-g.buttonW,by);yes.ZIndex=panel.ZIndex+2
	yes.Activated:Connect(function()Confirm.accept()end)
	state.yes,state.cancel=yes,cancel
	if not Kit.reduced()then
		local scale=make("UIScale",panel,{Scale=.94})
		Kit.tween(scale,Kit.Motion.screen,{Scale=1})
	end
	return panel
end

local function gamepad()return string.match(UserInputService:GetLastInputType().Name,"^Gamepad")~=nil end

local function bind()
	ContextActionService:BindActionAtPriority(Confirm.Action,function(_,inputState,input)
		if not state.open then return Enum.ContextActionResult.Pass end
		if inputState~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		local key=input.KeyCode
		if key==Enum.KeyCode.ButtonB or key==Enum.KeyCode.Backspace or key==Enum.KeyCode.Escape then Confirm.close("back")
		elseif key==Enum.KeyCode.Return or key==Enum.KeyCode.KeypadEnter or key==Enum.KeyCode.ButtonA then Confirm.accept()
		elseif key==Enum.KeyCode.Space then Confirm.accept()
		elseif(key==Enum.KeyCode.ButtonX or key==Enum.KeyCode.X)and state.options and state.options.alt then Confirm.chooseAlt()end
		return Enum.ContextActionResult.Sink
	end,false,Confirm.Priority,
		Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace,Enum.KeyCode.Escape,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,Enum.KeyCode.ButtonA,Enum.KeyCode.Space,
		-- Every other key a menu listens for is swallowed while the dialog is up.
		Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,
		Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.A,Enum.KeyCode.D,
		Enum.KeyCode.W,Enum.KeyCode.S,Enum.KeyCode.ButtonX,Enum.KeyCode.ButtonY,Enum.KeyCode.M,Enum.KeyCode.H,Enum.KeyCode.X,Enum.KeyCode.Tab)
end

local function finish(confirmed,reason,alt)
	if not state.open then return false end
	state.open=false
	ContextActionService:UnbindAction(Confirm.Action)
	Kit.shadeClose(owner)
	if state.panel then state.panel:Destroy();state.panel=nil end
	state.yes,state.cancel,state.x=nil,nil,nil
	local previous=state.previous;state.previous=nil
	if previous and previous.Parent and gamepad()then GuiService.SelectedObject=previous end
	local o=state.options;state.options=nil
	if o then
		-- After the close, so a screen the action opens is not under this shade or its keys.
		if confirmed then
			if o.onConfirm then task.spawn(o.onConfirm)end
		elseif alt then
			if o.alt and o.alt.onSelect then task.spawn(o.alt.onSelect)end
		elseif o.onCancel then task.spawn(o.onCancel,reason or "cancel")end
		if o.onClosed then task.spawn(o.onClosed,confirmed)end
	end
	return true
end

function Confirm.accept()return finish(true,"confirm")end
function Confirm.chooseAlt()
	if not(state.open and state.options and state.options.alt)then return false end
	-- alt.after (seconds, beta 14 F2): the alt key is ignored this long after the ask, so the press that opened the
	-- dialog (a prompt on the same X / ButtonX) cannot also choose it.
	if state.altAt and os.clock()<state.altAt then return false end
	return finish(false,"alt",true)
end
function Confirm.close(reason)return finish(false,reason or "close")end

function Confirm.ask(options)
	if type(options)~="table"then return nil end
	if not ensureGui()then return nil end
	-- A second ask replaces the first (which cancels).
	if state.open then finish(false,"replaced")end
	state.options=options
	state.open=true
	state.altAt=if options.alt and type(options.alt.after)=="number"then os.clock()+options.alt.after else nil
	state.previous=GuiService.SelectedObject
	bind()
	Confirm.build()
	state.gui.Enabled=true
	Kit.shadeOpen(owner,state.shade,nil,{overlay=true})
	if gamepad()and state.yes then GuiService.SelectedObject=state.yes elseif state.previous then GuiService.SelectedObject=nil end
	pcall(function()require(script.Parent.UIClick).play("open")end)
	local handle={}
	function handle.cancel(reason)if state.open and state.options==options then return Confirm.close(reason or "owner")end;return false end
	function handle.isOpen()return state.open and state.options==options end
	return handle
end

-- A Star purchase in a shop whose buy path runs when owner.confirmId is the item and
-- owner.confirmUntil is still ahead (the old "press again" window). The yes opens that window
-- and runs act() again, so the shop re-checks everything (selection, price, pending, wallet).
-- isCurrent() says the shop is still open on that item. Stores the handle in owner.confirmHandle.
function Confirm.purchase(owner,id,name,price,isCurrent,act)
	local vars={item=name or "",price=price or 0}
	owner.confirmHandle=Confirm.ask({tone="spend",title=UICopy.get("confirm.buyTitle",vars),line=UICopy.get("confirm.buyLine",vars),
		confirm=UICopy.get("confirm.buyYes",vars),
		onConfirm=function()
			owner.confirmHandle=nil
			if not isCurrent()then return end
			owner.confirmId,owner.confirmUntil=id,os.clock()+3
			act()
			-- Code review: act() may stop early (a save in flight); never leave the window open.
			owner.confirmId=nil
		end,onCancel=function()owner.confirmHandle=nil end})
	return owner.confirmHandle
end
function Confirm.cancelFor(owner)
	if owner.confirmHandle then owner.confirmHandle.cancel("owner");owner.confirmHandle=nil end
end
function Confirm.isOpen()return state.open end
-- Beta (17) U2: an open dialog frees the PC cursor (ModalCursor's registry).
require(script.Parent.ModalCursor).register("ConfirmDialog",Confirm.isOpen)
function Confirm.panel()return state.panel end
return Confirm
