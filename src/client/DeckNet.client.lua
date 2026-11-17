-- Deck network rework (artifacts/qa-2026-11-16c-v775/deck-network-plan.md): starts the
-- owner's snapshot stream client (S1 shadow, S2 render) when FeatureFlags.DeckNetStream is on.
-- A separate LocalScript so init.client.lua (219 column-0 locals) is untouched by S1/S2a.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Flags=require(ReplicatedStorage.Shared.FeatureFlags)
if Flags.DeckNetStream~=true then return end
local Net=require(script.Parent.BoardNetClient)
local board=ReplicatedStorage:WaitForChild("EggDropBoards"):WaitForChild(tostring(Players.LocalPlayer.UserId))
Net.start(board)
