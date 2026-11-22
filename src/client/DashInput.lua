-- Garden Dash buttons (V3-DASH-BUILD-PLAN-2026-11-22, slice S7). Core is pure: which fingers and keys hold Dash, and
-- one event each for Jump and the stones. mount() connects the device:
--   phone     right half of the screen Jump, left half Dash (held), one id per touch; the stones key above Jump
--   keyboard  Space jumps (or a click), Shift or the right mouse button dashes, W / Up takes the stones
--   gamepad   A jumps, RT or X dashes, Y takes the stones, B asks to leave
-- Nothing is bound before GO, so only a fresh press counts. Every way a hold can be lost (window focus, the Roblox
-- menu, a text box, a cancelled touch, a pulled controller, a respawn, the end) lets Dash go.
local Input={}
local Core={};Core.__index=Core
Input.Core=Core
Input.Action="EggDropDash"
-- press(kind) -> true when it counted; blocked() -> true while nothing new may start (a menu, a text box).
function Core.new(options)
	return setmetatable({press=options.press,blocked=options.blocked,holds={},held=0,down=false,open=false},Core)
end
function Core:setOpen(open)
	if self.open==open then return end
	if not open then self:loseAll()end
	self.open=open
end
-- id: one touch, key or button. action: "jump", "dash", "stones".
function Core:begin(id,action)
	if not self.open or(self.blocked and self.blocked())then return false end
	if action~="dash"then return self.press(action)==true end
	if self.holds[id]then return false end
	self.holds[id]=true;self.held+=1
	self:sync()
	return true
end
function Core:finish(id)
	if id==nil or not self.holds[id]then return end
	self.holds[id]=nil;self.held-=1
	self:sync()
end
-- The server-side button follows the fingers. A press that was paced out or refused is tried again while it is
-- still held (step); a let go always goes out.
function Core:sync()
	local want=self.held>0
	if want==self.down then return end
	if want then
		if self.press("dashDown")==true then self.down=true end
	else
		self.down=false
		self.press("dashUp")
	end
end
function Core:step()
	if self.open then self:sync()end
end
function Core:loseAll()
	if self.held>0 then table.clear(self.holds);self.held=0 end
	if self.down then self.down=false;self.press("dashUp")end
end

-- Which part of the screen a touch at x is for.
function Input.zone(x,width)return if x>=width/2 then "jump"else "dash"end

-- options: core, zones (GuiObjects: {jump, dash}), stones (GuiButton), leave(), services (specs: stand-ins by name)
function Input.mount(options)
	local function service(name)return options.services and options.services[name]or game:GetService(name)end
	local UserInputService,ContextActionService=service("UserInputService"),service("ContextActionService")
	local GuiService,Players=service("GuiService"),service("Players")
	local Keys=Enum.KeyCode
	local core=options.core
	local api={bound=false}
	local connections={}
	local function on(signal,fn)table.insert(connections,signal:Connect(fn))end
	local actions={[Keys.Space]="jump",[Keys.ButtonA]="jump",[Keys.LeftShift]="dash",[Keys.RightShift]="dash",[Keys.ButtonR2]="dash",[Keys.ButtonX]="dash",
		[Keys.W]="stones",[Keys.Up]="stones",[Keys.ButtonY]="stones"}
	local function lose()core:loseAll()end
	local function handle(_,state,input)
		local key=input.KeyCode
		if key==Keys.ButtonB or key==Keys.Backspace then
			if state==Enum.UserInputState.Begin and not(core.blocked and core.blocked())then options.leave()end
			return Enum.ContextActionResult.Sink
		end
		local action=actions[key]
		if not action then return Enum.ContextActionResult.Pass end
		-- Change (a trigger squeezed further, or eased) is neither a press nor a let go.
		if state==Enum.UserInputState.Begin then core:begin(key,action)
		elseif state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then core:finish(key)end
		return Enum.ContextActionResult.Sink
	end
	local function touch(zone,action)
		on(zone.InputBegan,function(input)
			-- A finger that slides in from the other half begins here too, as Change: only a fresh touch counts.
			if not api.bound or input.UserInputState~=Enum.UserInputState.Begin then return end
			if input.UserInputType==Enum.UserInputType.Touch then core:begin(input,action)
			-- A mouse on a touch screen lands on the zone too: click jumps, right button dashes, on either half.
			elseif input.UserInputType==Enum.UserInputType.MouseButton1 then core:begin("mouse1","jump")
			elseif input.UserInputType==Enum.UserInputType.MouseButton2 then core:begin("mouse2","dash")end
		end)
	end
	touch(options.zones.jump,"jump");touch(options.zones.dash,"dash")
	if options.stones then on(options.stones.Activated,function()if api.bound then core:begin("stonesKey","stones")end end)end
	on(UserInputService.InputBegan,function(input,processed)
		if not api.bound or processed then return end
		if input.UserInputType==Enum.UserInputType.MouseButton1 then core:begin("mouse1","jump")
		elseif input.UserInputType==Enum.UserInputType.MouseButton2 then core:begin("mouse2","dash")end
	end)
	on(UserInputService.InputEnded,function(input)
		if input.UserInputType==Enum.UserInputType.Touch then core:finish(input)
		elseif input.UserInputType==Enum.UserInputType.MouseButton2 then core:finish("mouse2")
		else core:finish(input.KeyCode)end -- a key let go while a menu swallowed the action
	end)
	on(UserInputService.WindowFocusReleased,lose)
	on(UserInputService.TextBoxFocused,lose)
	on(UserInputService.GamepadDisconnected,lose)
	on(GuiService.MenuOpened,lose)
	on(Players.LocalPlayer.CharacterRemoving,lose)
	function api.open()
		if api.bound then return end
		api.bound=true
		ContextActionService:BindActionAtPriority(Input.Action,handle,false,Enum.ContextActionPriority.High.Value+500,
			Keys.Space,Keys.LeftShift,Keys.RightShift,Keys.W,Keys.Up,Keys.Backspace,Keys.ButtonA,Keys.ButtonB,Keys.ButtonX,Keys.ButtonY,Keys.ButtonR2)
		core:setOpen(true)
	end
	function api.close()
		core:setOpen(false)
		if not api.bound then return end
		api.bound=false
		ContextActionService:UnbindAction(Input.Action)
	end
	function api.destroy()
		api.close()
		for _,connection in ipairs(connections)do connection:Disconnect()end
		table.clear(connections)
	end
	return api
end
return Input
