-- World feel on the client (beta 14 QA W4; Shared.WorldFeel). mount() answers nil with the build ceiling off.
--   feel: LocalPlayer.CameraMaxZoomDistance capped at WorldFeel.MaxZoom (the Custom camera only; the race, focus and
--         Deck cameras are scripted). Off again: the place's own value back. The arrival camera (RoomView) and the
--         haze (HollowClock -> GardenHour) read WorldFeel themselves.
--   walk: the character's WalkSpeed WorldFeel.Walk, written as each character arrives (and on a switch flip only while
--         it still has the speed this module last gave it: a locked humanoid, WalkSpeed 0 under PetFocusUI or a
--         movement lock, is never touched, so nothing here can unlock it).
-- Off writes nothing: a switch that was never on leaves every value as the place has it.
-- deps: player (LocalPlayer), starter (StarterPlayer), step=false for specs (they call :apply()).
local Feel=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WorldFeel"))
local PlayerScale=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PlayerScale"))
local Client={};Client.__index=Client

-- Pure: the WalkSpeed to write for a humanoid at `current`, or nil to leave it. `given` is what this module last
-- wrote (nil: nothing yet), `base` the place's speed, `fresh` a character that just arrived.
function Client.walkTarget(current,on,given,base,fresh)
	if type(current)~="number"or current<=0 then return nil end -- locked: never touched
	if on then
		if fresh or current==base or current==given then return if current~=Feel.Walk then Feel.Walk else nil end
		return nil
	end
	if given~=nil and current==given and current~=base then return base end
	return nil
end
-- Pure: the zoom cap to write, or nil. factor: the player scale's zoom factor (PlayerScale.zoomFactor; 1 = as before).
function Client.zoomTarget(current,on,base,capped,factor)
	if on then
		local want=math.min(base,Feel.MaxZoom*(factor or 1))
		return if current~=want then want else nil
	end
	if capped and current~=base then return base end
	return nil
end

function Client.mount(deps)
	if not Feel.ceiling()then return nil end
	deps=deps or {}
	local player=deps.player or game:GetService("Players").LocalPlayer
	local starter=deps.starter or game:GetService("StarterPlayer")
	local self=setmetatable({player=player,connections={},zoomBase=starter.CameraMaxZoomDistance,walkBase=starter.CharacterWalkSpeed},Client)
	local function on(signal,fn)table.insert(self.connections,signal:Connect(fn))end
	if deps.step~=false then
		on(Feel.changed("feel"),function()self:apply(false)end)
		on(Feel.changed("walk"),function()self:apply(false)end)
		on(PlayerScale.changed(),function()self:apply(false)end)
		local function watch(humanoid)
			-- A lock (PetFocusUI) that lets go writes back the speed it saved: with the switch off by then, the place's
			-- speed goes back instead of the 14 it held.
			if self.walkConn then self.walkConn:Disconnect()end
			self.walkConn=humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()self:walk(humanoid,false)end)
		end
		on(player.CharacterAdded,function(character)
			local humanoid=character:WaitForChild("Humanoid",10)
			if humanoid then self:walk(humanoid,true);watch(humanoid)end
		end)
		local character=player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then watch(humanoid)end
	end
	self:apply(true)
	return self
end
function Client:walk(humanoid,fresh)
	local want=Client.walkTarget(humanoid.WalkSpeed,Feel.on("walk"),self.given,self.walkBase,fresh)
	if want then humanoid.WalkSpeed=want;self.given=if want==self.walkBase then nil else want end
end
function Client:apply(fresh)
	local player=self.player
	local zoom=Client.zoomTarget(player.CameraMaxZoomDistance,Feel.on("feel"),self.zoomBase,self.capped,PlayerScale.zoomFactor(PlayerScale.value()))
	if zoom then player.CameraMaxZoomDistance=zoom;self.capped=zoom~=self.zoomBase end
	local character=player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then self:walk(humanoid,fresh)end
end
function Client:destroy()
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	table.clear(self.connections)
	if self.walkConn then self.walkConn:Disconnect();self.walkConn=nil end
end
return Client
