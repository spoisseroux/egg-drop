-- The first open after loading (DECK-FEEL-BRIEF 1; Spencer beta 40 note 9: "the very first transition to the pocket
-- deck on first start from the loading screens needs to be smoother"). One handoff: the loading screen keeps its sky
-- up until the deck's content is ready, cross-fades the sky to the deck's shade colour (.30 s) while its pals and title
-- fade (.20 s), and the handheld rises straight out of it. The garden is never shown in between and no frame is fully
-- transparent. Behind Alive "deckfeel" (the loading screen in ReplicatedFirst reads the workspace attribute itself).
--
-- The two sides talk through PlayerGui attributes (ReplicatedFirst cannot require this module):
--   DeckFirstRoute    "Board" or "Room": where the client's first presentation goes (set before it starts).
--   DeckFeelHandoff   true when the switch is on for this client.
--   DeckShadeColor    the shade's Color3 (DeckTransition.shadeColor) the sky fades to.
--   DeckContentReady  the first Board presentation has its board content: the loading screen may hand off now.
--   LoadingHandedOff  the loading screen has faded to the shade colour and is gone.
local Handoff={}
Handoff.Screen="EggDropLoading"
Handoff.Wait=30 -- seconds the deck waits for the loading screen at most (its own MaxSeconds is 25)

function Handoff.announce(playerGui,mode,shadeColor,on)
 if not playerGui then return end
 playerGui:SetAttribute("DeckShadeColor",shadeColor)
 playerGui:SetAttribute("DeckFeelHandoff",on==true)
 playerGui:SetAttribute("DeckFirstRoute",if mode=="Board"then "Board"else "Room")
end
-- Pure: may the deck rise now? (No loading screen left, or it has handed off.)
function Handoff.clear(screenPresent,handedOff)return not screenPresent or handedOff==true end
-- RoomView's first Board reveal (beforeFirstReveal): tells the loading screen the content is ready and waits for it.
function Handoff.waitLoading(playerGui,limit)
 if not playerGui then return true end
 playerGui:SetAttribute("DeckContentReady",true)
 local started=os.clock()
 while os.clock()-started<(limit or Handoff.Wait)do
  if Handoff.clear(playerGui:FindFirstChild(Handoff.Screen)~=nil,playerGui:GetAttribute("LoadingHandedOff"))then return true end
  task.wait()
 end
 return false
end
-- init.client, just before the first presentation: says where it goes and, under the switch, makes RoomView's first
-- Board reveal wait for the loading screen's handoff.
function Handoff.install(roomView,playerGui,mode,on)
 local ok,color=pcall(function()return require(script.Parent.DeckTransition).shadeColor()end)
 Handoff.announce(playerGui,mode,if ok then color else nil,on)
 if on then roomView.beforeFirstReveal=function()roomView.beforeFirstReveal=nil;Handoff.waitLoading(playerGui)end end
end
return Handoff
