-- One shared click helper (QA v775 note 12, "every button gets click audio").
--
-- Every GuiButton under PlayerGui is bound here, whoever builds it, and every sound a
-- button or a keyboard / gamepad action makes goes through Click.play. So a new button
-- cannot be silent, and no screen wires its own click.
--
--   Click.start(audio, playerGui)   once, from init.client.lua
--   Click.play(kind)                an action's own sound: "confirm" | "tab" | "back" |
--                                   "equip" | "unequip" (Use / Wear / Follow, and taking off)
--   button:SetAttribute("ClickSound", kind)   a button's default kind ("none" = silent)
--
-- Why a press is queued and flushed, not played at once:
--   * A button's owner often knows better than "confirm" (a tab, Back, Wear). Its
--     Click.play in the same press wins by priority, and only one sound plays.
--   * Some owners rebuild their screen inside Activated (the Companions "Pets" row),
--     which destroys the button and disconnects every handler connected before theirs
--     runs. The helper connects one deferred step after the button is added, so with
--     Roblox's newest-first signal order it runs first, and the queued sound survives
--     the rebuild. That was the silent Pets row.
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Click={}
Click.Bound="EggDropClickBound"
Click.Kind="ClickSound"
-- Higher wins when one press asks for more than one sound.
Click.Priority=table.freeze({confirm=1,tab=2,back=2,equip=3,unequip=3})
Click.Window=.06 -- one sound per press: later requests inside this window are dropped
-- PlayerGui attributes, for specs and QA. Count / Last: the cues this helper asked the
-- game's audio for. Heard: those the audio really played (it plays nothing while the
-- sound is muted or the window is in the background).
Click.Count="EggDropClickCount"
Click.Last="EggDropClickLast"
Click.Heard="EggDropClickHeard"

local state={audio=nil,root=nil,sequence=0,lastAt=-math.huge,pending=nil,flushing=false,links={}}

-- Pure: the kind a button plays by default. nil = stay silent.
function Click.kindOf(attribute)
 if attribute=="none"then return nil end
 if type(attribute)=="string"and Click.Priority[attribute]then return attribute end
 return "confirm"
end
-- Pure: of two requested kinds, the one to play.
function Click.pick(a,b)
 if not a then return b end
 if not b then return a end
 return if(Click.Priority[b]or 0)>(Click.Priority[a]or 0)then b else a
end
-- Pure: does a button in this state click? (A disabled or hidden button stays silent.)
function Click.live(interactable,active,visible)
 return interactable==true and active==true and visible==true
end

local function blocked()
 return GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()~=nil
end
local function flush()
 state.flushing=false
 local kind=state.pending;state.pending=nil
 if not kind or not state.audio or blocked()then return false end
 local now=os.clock()
 if now-state.lastAt<Click.Window then return false end
 state.lastAt=now;state.sequence+=1
 local played=state.audio:ui(kind,state.sequence)==true
 if state.root then
  state.root:SetAttribute(Click.Last,kind)
  state.root:SetAttribute(Click.Count,(state.root:GetAttribute(Click.Count)or 0)+1)
  if played then state.root:SetAttribute(Click.Heard,(state.root:GetAttribute(Click.Heard)or 0)+1)end
 end
 return played
end
-- Ask for a sound. Several requests in one step make one sound (the highest priority).
function Click.play(kind)
 if not Click.Priority[kind]or not state.audio then return false end
 state.pending=Click.pick(state.pending,kind)
 if not state.flushing then state.flushing=true;task.defer(flush)end
 return true
end
-- The same as a press on `node` (also the spec's probe): true when a sound was asked for.
function Click.press(node)
 if not(node and node:IsA("GuiButton"))then return false end
 if not Click.live(node.Interactable,node.Active,node.Visible)then return false end
 local kind=Click.kindOf(node:GetAttribute(Click.Kind))
 if not kind then return false end
 return Click.play(kind)
end
local function connect(node)
 if node:GetAttribute(Click.Bound)==true or not node:IsDescendantOf(game)then return end
 node:SetAttribute(Click.Bound,true)
 node.Activated:Connect(function()Click.press(node)end)
end
-- Bind one button. `now` connects at once (buttons that already exist when the helper
-- starts); otherwise one deferred step later, after the owner's own handlers.
function Click.bind(node,now)
 if not node:IsA("GuiButton")or node:GetAttribute(Click.Bound)==true then return false end
 if now then connect(node)else task.defer(connect,node)end
 return true
end
function Click.started()return state.audio~=nil end

-- audio: BoardAudio (needs :ui(kind, token)). root: PlayerGui.
function Click.start(audio,root)
 assert(audio and type(audio.ui)=="function","UIClick needs the game's audio")
 for _,link in ipairs(state.links)do link:Disconnect()end
 table.clear(state.links)
 state.audio,state.root,state.pending,state.flushing=audio,root,nil,false
 root:SetAttribute(Click.Count,root:GetAttribute(Click.Count)or 0)
 root:SetAttribute(Click.Heard,root:GetAttribute(Click.Heard)or 0)
 for _,node in ipairs(root:GetDescendants())do if node:IsA("GuiButton")then Click.bind(node,true)end end
 table.insert(state.links,root.DescendantAdded:Connect(function(node)if node:IsA("GuiButton")then Click.bind(node,false)end end))
 -- Studio: specs live in another module cache, so they reach this helper through the
 -- gui. Invoke("press", button) is Click.press; it returns whether the helper asked the
 -- audio for a cue, which kind, and whether the audio played it. Invoke("audible") says
 -- whether the audio can play at all right now (not muted, window in front, cue loaded).
 if game:GetService("RunService"):IsStudio()then
  local probe=root:FindFirstChild("EggDropClickProbe")or Instance.new("BindableFunction")
  probe.Name="EggDropClickProbe"
  probe.OnInvoke=function(action,node)
   if action=="press"then
    local before=root:GetAttribute(Click.Count)or 0
    local heardBefore=root:GetAttribute(Click.Heard)or 0
    state.lastAt=-math.huge -- a spec presses many buttons in one frame
    if not Click.press(node)then return false,"silent"end
    -- The queued sound plays at the engine's next deferred step: within a frame or two.
    local after=before
    for _=1,6 do
     task.wait()
     after=root:GetAttribute(Click.Count)or 0
     if after>before then break end
    end
    return after>before,root:GetAttribute(Click.Last),(root:GetAttribute(Click.Heard)or 0)>heardBefore
   elseif action=="audible"then
    local voices=type(audio.voices)=="table"and audio.voices.menu
    return audio.destroyed~=true and audio.deviceActive~=false and audio.group~=nil and audio.group.Volume>0
     and voices~=nil and voices[1]~=nil and voices[1].IsLoaded~=false
   elseif action=="kind"then
    return Click.kindOf(node and node:GetAttribute(Click.Kind))
   end
   return nil
  end
  probe.Parent=root
 end
 return Click
end
return Click
