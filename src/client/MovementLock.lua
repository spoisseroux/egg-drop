-- One movement lock for the avatar (QA v2 R2.1 / R2.2). Any number of owners hold it by
-- reason ("modal", "deck", "focus"); while at least one does, the PlayerModule controls
-- are disabled (WASD, arrows, thumbstick, touch thumbstick and jump) and the walk that
-- was held when the lock closed is cleared at once (Humanoid:Move zero, horizontal
-- velocity zero). The last release enables the controls again, only when this lock was
-- the one that disabled them. Controls only: WalkSpeed stays with PetFocusUI.lockHumanoid.
-- Menu keys are ContextActionService bindings of their own and keep working.
-- Everything Roblox-facing is injected so the counting runs in a spec.
local Lock={}
Lock.__index=Lock

-- options: controls() -> PlayerModule controls (or nil), stop() clears the held walk.
function Lock.new(options)
 options=options or {}
 return setmetatable({reasons={},held=0,getControls=options.controls,stopWalk=options.stop,disabledByUs=false,stops=0},Lock)
end

local function enabledOf(controls)
 if type(controls.controlsEnabled)=="boolean"then return controls.controlsEnabled end
 if type(controls.enabled)=="boolean"then return controls.enabled end
 return true
end

function Lock:controls()
 if not self.getControls then return nil end
 local ok,controls=pcall(self.getControls)
 return if ok then controls else nil
end

function Lock:count()return self.held end
function Lock:isLocked()return self.held>0 end
function Lock:holds(reason)return self.reasons[reason]==true end

-- Takes the lock for `reason` (idempotent per reason). True when this call closed it.
function Lock:acquire(reason)
 assert(type(reason)=="string","MovementLock reason")
 if self.reasons[reason]then return false end
 self.reasons[reason]=true;self.held+=1
 if self.held==1 then self:close()return true end
 -- Someone may have enabled the controls behind our back (e.g. a respawn path).
 self:enforce()
 return false
end

-- Drops `reason` (idempotent). True when this call opened the lock.
function Lock:release(reason)
 if not self.reasons[reason]then return false end
 self.reasons[reason]=nil;self.held-=1
 if self.held==0 then self:open()return true end
 return false
end

function Lock:set(reason,on)
 if on then return self:acquire(reason)end
 return self:release(reason)
end

function Lock:close()
 local controls=self:controls()
 if controls and enabledOf(controls)then
  pcall(function()controls:Disable()end)
  self.disabledByUs=true
 end
 self:stop()
end

function Lock:open()
 local controls=self:controls()
 if controls and self.disabledByUs then pcall(function()controls:Enable()end)end
 self.disabledByUs=false
end

-- Re-disables controls another script enabled while the lock is held.
function Lock:enforce()
 if self.held==0 then return false end
 local controls=self:controls()
 if controls and enabledOf(controls)then
  pcall(function()controls:Disable()end)
  self.disabledByUs=true
  self:stop()
  return true
 end
 return false
end

function Lock:stop()
 self.stops+=1
 if self.stopWalk then pcall(self.stopWalk)end
end

-- The client's lock: real PlayerModule controls, the local character's walk cleared.
local shared
function Lock.shared()
 if shared then return shared end
 local Players=game:GetService("Players")
 local cached
 shared=Lock.new({
  controls=function()
   if cached then return cached end
   local scripts=Players.LocalPlayer:FindFirstChild("PlayerScripts")
   local module=scripts and scripts:FindFirstChild("PlayerModule")
   if not module then return nil end
   cached=require(module):GetControls()
   return cached
  end,
  stop=function()
   local character=Players.LocalPlayer.Character
   local humanoid=character and character:FindFirstChildOfClass("Humanoid")
   if humanoid then humanoid:Move(Vector3.zero)end
   local root=character and character:FindFirstChild("HumanoidRootPart")
   if root and not root.Anchored then
    local v=root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity=Vector3.new(0,math.min(v.Y,0),0)
   end
  end,
 })
 return shared
end

return Lock
