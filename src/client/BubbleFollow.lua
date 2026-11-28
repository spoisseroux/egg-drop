-- A bubble's place over a moving pet (beta 40 note 1, Spencer: "the onboarding label above the pet ... its all jittery").
-- The word bubbles hung on the pet's Body (NeedBubble's pinned mode): that part carries the walk's waddle (6 degrees of
-- roll, .06 studs across), its lean, bob and boop squash, so the billboard shook with every step; the icon bubbles
-- chased a spring with a 2-stud dead zone that read as stop-and-go, stepped on Heartbeat while the pet moved on
-- RenderStepped. Now every bubble hangs on its own anchor part, placed each rendered frame (bind: after the camera) at
-- the pet's un-animated origin (GardenPetVisual's visual.origin, the paws' point the walk is planned along) plus its
-- measured top and the lift: X and Z exactly (no dead zone, no trailing), only the height lightly smoothed (a step up a
-- kerb or a hop's landing never jolts the words). A jump over Snap studs (a poof, a teleport) snaps. Reduced Motion:
-- no smoothing at all. Pure but for bind/unbind; NeedBubble uses it, and GiftBubble can (Follow.step + Follow.bind).
local Follow={}
Follow.Rate=14        -- the height's smoothing: about 1 - e^(-Rate dt) of the way each frame (a ~.07 s time constant)
Follow.Snap=30        -- studs: further than this is a teleport, the bubble snaps
Follow.Settle=.002    -- studs: the height is there

-- Pure: a fresh follow state (the caller keeps it; `at` nil places the next frame exactly).
function Follow.new()return {at=nil}end

-- Pure: the anchor's place this frame toward `target` (the point over the pet). X and Z exact, Y smoothed.
function Follow.toward(state,target,dt,reduced)
	if typeof(target)~="Vector3"then return state.at end
	local at=state.at
	if typeof(at)~="Vector3"or reduced or(target-at).Magnitude>=Follow.Snap then state.at=target;return target end
	local k=1-math.exp(-Follow.Rate*math.max(0,tonumber(dt)or 0))
	local y=at.Y+(target.Y-at.Y)*k
	if math.abs(target.Y-y)<=Follow.Settle then y=target.Y end
	state.at=Vector3.new(target.X,y,target.Z)
	return state.at
end

-- Pure: the anchor's place this frame, `height` studs over the pet's un-animated `origin`.
function Follow.step(state,origin,height,dt,reduced)
	if typeof(origin)~="Vector3"then return state.at end
	return Follow.toward(state,origin+Vector3.new(0,tonumber(height)or 0,0),dt,reduced)
end

-- The top of `part`'s pet over `origin` (studs), measured once when the pet changes: the model's bounding box (its
-- animated pose then, a hundredth of a stud or so off), else the part's own. No origin: half the model's height over the
-- part (the nest's anchor, a static part in its own model). `fallback` when nothing can be read.
function Follow.top(part,origin,fallback)
	fallback=fallback or 1.5
	if part==nil then return fallback end
	local model=part.FindFirstAncestorWhichIsA and part:FindFirstAncestorWhichIsA("Model")or nil
	if typeof(origin)=="Vector3"then
		local ok,top=pcall(function()
			if model then local cf,size=model:GetBoundingBox();return cf.Position.Y+size.Y*.5 end
			return part.Position.Y+part.Size.Y*.5
		end)
		if ok and type(top)=="number"and top==top then return math.max(0,top-origin.Y)end
		return fallback
	end
	local ok,size=pcall(function()return if model then model:GetExtentsSize()else part.Size end)
	return if ok and typeof(size)=="Vector3"then size.Y*.5 else fallback
end

-- Step `fn(dt)` every rendered frame after the camera (and after the pets' own RenderStepped pose), or nil where the
-- engine has no render step (offline specs: the caller steps it itself). Returns the unbind function.
local bound=0
function Follow.bind(name,fn)
	local okRun,Run=pcall(function()return game:GetService("RunService")end)
	if not okRun or type(Run)~="table"and typeof(Run)~="Instance"then return nil end
	local okHas,has=pcall(function()return Run.BindToRenderStep end)
	if not okHas or has==nil then return nil end
	bound+=1
	local action=tostring(name or "EggDropBubbleFollow").."_"..bound
	local warned=false
	local ok=pcall(function()
		Run:BindToRenderStep(action,Enum.RenderPriority.Camera.Value+1,function(dt)
			local good,why=pcall(fn,dt)
			if not good and not warned then warned=true;warn("[BubbleFollow] "..tostring(why))end
		end)
	end)
	if not ok then return nil end
	return function()pcall(function()Run:UnbindFromRenderStep(action)end)end
end

return table.freeze(Follow)
