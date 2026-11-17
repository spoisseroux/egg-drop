-- Deck network rework, server side (artifacts/qa-2026-11-16c-v775/deck-network-plan.md).
-- The server stays the only authority for the simulation, merges, score and rewards;
-- this module only stamps and streams what it already decided.
--   S0 (DeckNetTicks): board.simTick, one integer per fixed step, never reset across
--      rounds. Merges, impact batches, item events and RoundOverTick carry it.
--   S1 (DeckNetStream): the owner gets a 30 Hz snapshot of the board on an
--      UnreliableRemoteEvent (4 Hz with the paused flag while the board is not stepping).
--   S4 (DeckNetDrop): a reliable BoardDropAck answers every drop that carried a token, and
--      a drop refused only by the 0.2 s interval or the contact gate waits up to
--      QueueSeconds (one deep) instead of being refused: jitter can bunch two taps.
--   S2 (DeckNetRender): Part.Position, which every client replicates (other players'
--      handhelds sample it at 8 Hz), is written at most 8 Hz plus once at creation.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Flags=require(ReplicatedStorage.Shared.FeatureFlags)
local Codec=require(ReplicatedStorage.Shared.BoardSnapshotCodec)

local Net={}
Net.StreamInterval=1/30
Net.PausedInterval=1/4
Net.PartInterval=1/8
Net.QueueSeconds=.8 -- one deep; covers a drop that was itself queued (measured: 1 in 10 expired at 0.15 s).
-- v890 QA: .3 refused 1-3 drops in 20 at 0.6 s lag (the ghost fades: "dropping then coming back").

function Net.ticks()return Flags.DeckNetTicks==true end
function Net.stream()return Flags.DeckNetStream==true end
function Net.render()return Flags.DeckNetRender==true and Flags.DeckNetStream==true end
function Net.drops()return Flags.DeckNetDrop==true end

function Net.setup(remotes)
 local snapshot=Instance.new("UnreliableRemoteEvent");snapshot.Name="BoardSnapshot";snapshot.Parent=remotes
 Net.remote=snapshot
 local ack=Instance.new("RemoteEvent");ack.Name="BoardDropAck";ack.Parent=remotes
 Net.ackRemote=ack
 -- Studio-only echo: the harness times a round trip through each remote kind to check
 -- what Studio's IncomingReplicationLag delays (architect review section 6).
 if RunService:IsStudio()then
  local echo=Instance.new("RemoteEvent");echo.Name="DeckNetEcho";echo.Parent=remotes
  local unreliable=Instance.new("UnreliableRemoteEvent");unreliable.Name="DeckNetEchoUnreliable";unreliable.Parent=remotes
  echo.OnServerEvent:Connect(function(player,stamp)if type(stamp)=="number"then echo:FireClient(player,stamp)end end)
  unreliable.OnServerEvent:Connect(function(player,stamp)if type(stamp)=="number"then unreliable:FireClient(player,stamp)end end)
 end
 return snapshot
end

-- A client drop token: an integer 1-65535, or nil. Never used to validate anything.
function Net.dropToken(value)
 if not Net.drops()or type(value)~="number"or value~=value or value%1~=0 or value<1 or value>65535 then return nil end
 return value
end
-- Answer a tokened drop: ok, the new ball's id and the tick it was spawned on, or a reason.
Net.AckBudget=20 -- acks per player per second (drops are 0.2 s apart; this only bounds spam)
function Net.ack(board,player,token,ok,reason)
 if not token or not Net.ackRemote then return end
 local now=os.clock()
 if not board.ackWindow or now-board.ackWindow>=1 then board.ackWindow,board.ackCount=now,0 end
 if board.ackCount>=Net.AckBudget then return end
 board.ackCount+=1
 Net.ackRemote:FireClient(player,token,ok==true,if ok then board.sim.fallingId else nil,board.simTick or 0,if ok then nil else reason)
end

-- One fixed simulation step of this board ran.
function Net.stepped(board)
 board.simTick=(board.simTick or 0)+1
end
function Net.tick(board)return board.simTick or 0 end

-- Called once per server Heartbeat per board, after syncVisuals.
function Net.publish(board,player,now)
 if not Net.stream()or not Net.remote or board.closing or board.mode~="Board"then return false end
 local tick=board.simTick or 0
 local moving=board.netSentTick~=tick
 local interval=if moving then Net.StreamInterval else Net.PausedInterval
 if board.netSentAt and now-board.netSentAt<interval-1e-3 then return false end
 local scratch=board.netScratch
 if not scratch then scratch={ids={},xs={},ys={}};board.netScratch=scratch end
 local count=0
 for _,egg in ipairs(board.sim.eggs)do
  if count>=Codec.MaxBalls then break end
  count+=1
  scratch.ids[count]=Codec.wireId(egg.id);scratch.xs[count]=egg.position.X;scratch.ys[count]=egg.position.Y
 end
 local flags=if moving then 0 else Codec.Paused
 local payload=Codec.encode(board.folder:GetAttribute("ResetId")or 0,tick,flags,scratch.ids,scratch.xs,scratch.ys,count,board.netBuffer)
 board.netBuffer=payload
 board.netSentAt,board.netSentTick=now,tick
 Net.remote:FireClient(player,payload)
 return true
end

-- syncVisuals asks before writing a Part's Position. Always for a new Part.
function Net.writePosition(board,created,now)
 if created or not Net.render()then return true end
 return board.netPartWindow==true
end
-- Opens the 8 Hz Part-position window for this Heartbeat (call before syncVisuals).
function Net.beginParts(board,now)
 if not Net.render()then board.netPartWindow=true;return end
 board.netPartWindow=not board.netPartAt or now-board.netPartAt>=Net.PartInterval-1e-3
 if board.netPartWindow then board.netPartAt=now end
end
-- Closes it again, so syncVisuals calls from request handlers only place new Parts.
function Net.endParts(board)
 board.netPartWindow=not Net.render()
end

return Net
