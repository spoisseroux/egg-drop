-- Alive step-down: the frame p75 over 5 s windows. Over 40 ms twice: level 1; once more: level 2; it
-- never comes back up that session. Ignored: the first 20 s, refocus, stalls, deck rounds and Studio.
-- level() is safe from anywhere (0 until measured); the sampler starts with the first call.
local Budget={}
Budget.Limit=40
Budget.Window=5
Budget.Warmup=20
Budget.MinSamples=10
Budget.Stall=1000 -- one frame this long is a stall, not a frame rate
Budget.MaxLevel=2

-- Pure: samples in ms, state {level, slow}; returns the next state.
function Budget.step(samples,state)
 local level,slow=state and state.level or 0,state and state.slow or 0
 if level<Budget.MaxLevel and #samples>=Budget.MinSamples then
  local sorted=table.clone(samples);table.sort(sorted)
  if sorted[#sorted]<Budget.Stall and sorted[math.ceil(#sorted*.75)]>Budget.Limit then
   slow+=1;level=math.max(level,math.clamp(slow-1,0,Budget.MaxLevel))
  end
 end
 return{level=level,slow=slow}
end
-- Pure: one frame into `sampler` {state, samples, span, quietUntil}. `ignore` drops the window.
function Budget.frame(sampler,now,dt,ignore)
 if ignore or now<sampler.quietUntil then table.clear(sampler.samples);sampler.span=0;return sampler.state end
 table.insert(sampler.samples,dt*1000);sampler.span+=dt
 if sampler.span>=Budget.Window then
  sampler.state=Budget.step(sampler.samples,sampler.state)
  table.clear(sampler.samples);sampler.span=0
 end
 return sampler.state
end

local sampler,link={state={level=0,slow=0},samples={},span=0,quietUntil=math.huge},nil
local started=false
local function start()
 if started then return end
 started=true
 local Run=game:GetService("RunService")
 if not Run:IsClient()or Run:IsStudio()or not Run:IsRunning()then return end
 local Alive=require(game:GetService("ReplicatedStorage").Shared.Alive)
 local wanted=false
 for _,feature in ipairs(Alive.Features)do wanted=wanted or Alive.ceiling(feature)end
 if not wanted then return end
 local Input=game:GetService("UserInputService")
 local player=game:GetService("Players").LocalPlayer
 sampler.quietUntil=os.clock()+Budget.Warmup
 local focused=true
 Input.WindowFocusReleased:Connect(function()focused=false end)
 Input.WindowFocused:Connect(function()focused=true;sampler.quietUntil=math.max(sampler.quietUntil,os.clock()+Budget.Window)end)
 local boards,board
 link=Run.RenderStepped:Connect(function(dt)
  if not(board and board.Parent)then
   boards=boards or game:GetService("ReplicatedStorage"):FindFirstChild("EggDropBoards")
   board=boards and player and boards:FindFirstChild(tostring(player.UserId))
  end
  local state=Budget.frame(sampler,os.clock(),dt,not focused or not board or board:GetAttribute("Mode")~="Room")
  if state.level>=Budget.MaxLevel then link:Disconnect();link=nil end
 end)
end
function Budget.level()
 if not started then start()end
 return sampler.state.level
end
return Budget
