-- Deck network rework, server side (artifacts/qa-2026-11-16c-v775/deck-network-plan.md).
-- The server stays the only authority for the simulation, merges, score and rewards;
-- this module only stamps and streams what it already decided.
--   S0 (DeckNetTicks): board.simTick, one integer per fixed step, never reset across
--      rounds. Merges, impact batches, item events and RoundOverTick carry it.
--   S1 (DeckNetStream): the owner gets a 30 Hz snapshot of the board on an
--      UnreliableRemoteEvent (4 Hz with the paused flag while the board is not stepping).
--   S2 (DeckNetRender): Part.Position, which every client replicates (other players'
--      handhelds sample it at 8 Hz), is written at most 8 Hz plus once at creation.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Flags=require(ReplicatedStorage.Shared.FeatureFlags)

local Net={}
Net.StreamInterval=1/30
Net.PausedInterval=1/4
Net.PartInterval=1/8

function Net.ticks()return Flags.DeckNetTicks==true end
function Net.stream()return Flags.DeckNetStream==true end
function Net.render()return Flags.DeckNetRender==true and Flags.DeckNetStream==true end

function Net.setup(remotes)
 -- Studio-only echo: the harness times a round trip through each remote kind to check
 -- what Studio's IncomingReplicationLag delays (architect review section 6).
 if RunService:IsStudio()then
  local echo=Instance.new("RemoteEvent");echo.Name="DeckNetEcho";echo.Parent=remotes
  local unreliable=Instance.new("UnreliableRemoteEvent");unreliable.Name="DeckNetEchoUnreliable";unreliable.Parent=remotes
  echo.OnServerEvent:Connect(function(player,stamp)if type(stamp)=="number"then echo:FireClient(player,stamp)end end)
  unreliable.OnServerEvent:Connect(function(player,stamp)if type(stamp)=="number"then unreliable:FireClient(player,stamp)end end)
 end
 return nil
end

-- One fixed simulation step of this board ran.
function Net.stepped(board)
 board.simTick=(board.simTick or 0)+1
end
function Net.tick(board)return board.simTick or 0 end

return Net
