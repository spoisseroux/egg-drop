-- Deck network rework (artifacts/qa-2026-11-16c-v775/deck-network-plan.md): starts the
-- owner's snapshot stream client (S1 shadow, S2 render) when FeatureFlags.DeckNetStream is on.
-- A separate LocalScript so init.client.lua (219 column-0 locals) is untouched by S1/S2a.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Flags=require(ReplicatedStorage.Shared.FeatureFlags)
if Flags.DeckNetStream~=true then return end
local Net=require(script.Parent.BoardNetClient)
local trays=ReplicatedStorage:WaitForChild("EggDropBoards",30)
local board=trays and trays:WaitForChild(tostring(Players.LocalPlayer.UserId),30)
if not board then warn("DeckNet: no board folder; the deck draws replicated Parts");return end
Net.start(board)
