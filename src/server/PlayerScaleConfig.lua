-- Player scale, server (artifacts/player-scale-2026-11-26/PLAN.md, revised after the architect review): reads
-- ConfigService `player_scale` (a number; refreshed when the config updates), keeps the owner's `/scale` override (this
-- server only), publishes the resolved number as the workspace attribute PlayerScale, and keeps every character at
-- that scale (Model:ScaleTo, which sets an absolute scale). Each scaled character carries the attribute AppliedScale
-- (what PlayerScale.of reads). With the build ceiling off nothing starts: no attribute, no ConfigService call, no
-- character touched.
-- Architect review: spawn is never held (a character is scaled in place once its appearance has loaded); the humanoid's
-- automatic scaling is turned off first (a late appearance would otherwise resize parts from their stored sizes); an
-- accessory that arrives after the scale is scaled on its own (re-scaling the whole character cannot fix it); an
-- anchored root (Board mode) is lowered so the feet stay on the ground.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Scale=require(game:GetService("ReplicatedStorage").Shared.PlayerScale)
local Config={}
Config.StudioAppearanceWait=4 -- Studio often never fires CharacterAppearanceLoaded for a test player
Config.AppearanceWait=30 -- live servers: a slow phone may take a while; scale when it arrives

local configValue,override,started=nil,nil,false
local lastPublished=nil
local watched={} -- character -> connections

local function current()return Scale.resolve(configValue,override,Scale.ceiling())end
local function lift(character)
	local humanoid=character:FindFirstChildOfClass("Humanoid")
	local root=character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return nil end
	-- R6 has HipHeight 0: its legs carry it (as Lounge.spawnFrame; code review)
	local leg=if humanoid.RigType==Enum.HumanoidRigType.R6 then character:FindFirstChild("Left Leg")else nil
	return humanoid.HipHeight+root.Size.Y/2+(if leg and leg:IsA("BasePart")then leg.Size.Y else 0),root
end
-- Scale one character to `target` (absolute; a no-op when it is already there).
function Config.apply(character,target)
	target=target or current()
	if typeof(character)~="Instance"or not character.Parent then return false end
	local okScale,now=pcall(function()return character:GetScale()end) -- the server's true scale
	if not okScale or type(now)~="number"then now=Scale.of(character)end
	if math.abs(now-target)<Scale.Epsilon then character:SetAttribute(Scale.AppliedAttribute,target);return true end
	local humanoid=character:FindFirstChildOfClass("Humanoid")
	if humanoid then pcall(function()humanoid.AutomaticScalingEnabled=false end)end
	local before,root=lift(character)
	local ok,problem=pcall(function()character:ScaleTo(target)end)
	if not ok then warn("[PlayerScale] "..tostring(problem));return false end
	character:SetAttribute(Scale.AppliedAttribute,target)
	-- accessories ScaleTo just scaled are at the target (a late one is scaled alone, from this mark)
	for _,child in ipairs(character:GetChildren())do if child:IsA("Accessory")then child:SetAttribute("ScaledAt",target)end end
	-- ScaleTo shrinks about the root's centre, so the feet rise: an anchored root (Board mode) is lowered to keep them on
	-- the ground (a free one just drops back).
	local after=lift(character)
	if root and root.Anchored and before and after then
		pcall(function()character:PivotTo(character:GetPivot()-Vector3.new(0,before-after,0))end)
	end
	return true
end
-- An accessory that arrives after the scale (late appearance) comes full size on a scaled body: scale it alone, from
-- the scale it was last given (ScaledAt; never twice), then rebuild its weld from its own scaled attachment and the
-- body's attachment of the same name (already scaled by ScaleTo; code review: scaling C1 again made it s squared).
local function scaleAccessory(character,accessory,s)
	local handle=accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart")then return end
	local was=accessory:GetAttribute("ScaledAt")
	local k=s/(if type(was)=="number"and was>0 then was else 1)
	if math.abs(k-1)<Scale.Epsilon then return end
	handle.Size=handle.Size*k
	local handleAttachment
	for _,child in ipairs(handle:GetChildren())do
		if child:IsA("Attachment")then
			child.Position=child.Position*k
			handleAttachment=handleAttachment or child
		elseif child:IsA("SpecialMesh")then child.Scale=child.Scale*k end
	end
	accessory:SetAttribute("ScaledAt",s)
	local weld=handle:FindFirstChild("AccessoryWeld")or handle:FindFirstChildWhichIsA("JointInstance")
	if weld and weld:IsA("JointInstance")and handleAttachment then
		local bodyAttachment
		for _,part in ipairs(character:GetChildren())do
			if part:IsA("BasePart")then
				local a=part:FindFirstChild(handleAttachment.Name)
				if a and a:IsA("Attachment")then bodyAttachment=a;break end
			end
		end
		weld.C0=handleAttachment.CFrame
		if bodyAttachment then weld.C1=bodyAttachment.CFrame end
	end
end
local function watch(character)
	if watched[character]then return end
	local links={}
	table.insert(links,character.ChildAdded:Connect(function(child)
		if not child:IsA("Accessory")then return end
		local s=character:GetAttribute(Scale.AppliedAttribute)
		if type(s)~="number"or math.abs(s-1)<Scale.Epsilon then return end
		-- once it is welded (the next frame)
		task.defer(function()if child.Parent==character then pcall(scaleAccessory,character,child,s)end end)
	end))
	local function forget()
		for _,link in ipairs(links)do link:Disconnect()end
		watched[character]=nil
	end
	table.insert(links,character.AncestryChanged:Connect(function(_,parent)if not parent then forget()end end))
	table.insert(links,character.Destroying:Connect(forget))
	watched[character]=links
end
-- Called from the spawn handler (never blocks it): once the appearance has loaded (bounded), scale in place.
function Config.prepare(player,character)
	if not Scale.ceiling()then return end
	task.spawn(function()
		-- CharacterAdded fires before the character is parented: wait for it to be in the world first (as Lounge.spawn).
		local placed=os.clock()+10
		while player.Character==character and not character:IsDescendantOf(workspace)and os.clock()<placed do task.wait()end
		if player.Character~=character or not character:IsDescendantOf(workspace)then return end
		local ok,loaded=pcall(function()return player:HasAppearanceLoaded()end)
		if ok and not loaded then
			local done=false
			local link=player.CharacterAppearanceLoaded:Connect(function()done=true end)
			local deadline=os.clock()+(if RunService:IsStudio()then Config.StudioAppearanceWait else Config.AppearanceWait)
			while not done and os.clock()<deadline and player.Character==character and character:IsDescendantOf(workspace)do task.wait(.1)end
			link:Disconnect()
		end
		if player.Character~=character or not character:IsDescendantOf(workspace)then return end
		character:WaitForChild("HumanoidRootPart",5)
		Config.apply(character,current())
		watch(character)
	end)
end
-- Publish the resolved scale and bring every character to it (only when it changed: repeated relative noise is avoided).
function Config.publish()
	if not Scale.ceiling()then return end
	local value=current()
	workspace:SetAttribute(Scale.Attribute,value)
	if lastPublished~=value then
		print(string.format("[PlayerScale] %.3f (override %s, config %s)",value,tostring(override),tostring(configValue)))
		lastPublished=value
	end
	for _,player in ipairs(Players:GetPlayers())do
		local character=player.Character
		if character and character:GetAttribute(Scale.AppliedAttribute)~=nil then Config.apply(character,value)end
	end
end
local function read(snapshot)
	local ok,value=pcall(function()return snapshot:GetValue(Scale.Key)end)
	if ok then configValue=value end
	Config.publish()
end
function Config.start()
	if started or not Scale.ceiling()then return end
	started=true
	Config.publish()
	task.spawn(function()
		local tries=0
		while true do
			local ok,snapshot=pcall(function()return game:GetService("ConfigService"):GetConfigAsync()end)
			if ok and snapshot then
				read(snapshot)
				pcall(function()
					snapshot.UpdateAvailable:Connect(function()
						task.spawn(function()
							local refreshed=pcall(function()snapshot:Refresh()end)
							if refreshed then read(snapshot)end
						end)
					end)
				end)
				return
			end
			tries+=1
			if tries>6 then return end -- no config service: the default (or an override) stays
			task.wait(math.min(60,5*tries))
		end
	end)
end
-- Owner chat (beta and Studio): "/scale 0.75" (0.6 to 1.2) or "/scale clear". This server only.
function Config.command(message)
	local command=Scale.parse(message)
	if not command or not Scale.ceiling()then return false end
	override=command.value
	Config.publish()
	return true
end
-- Specs: the current resolved value.
function Config.current()return current()end
return Config
