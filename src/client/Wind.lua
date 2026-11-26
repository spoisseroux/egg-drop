-- The wind lives in Shared now (GARDEN-PLAY-BRIEF-2 section 5: the server checks a fruit claim against the same gusts
-- the clients draw). Client modules keep requiring script.Parent.Wind; this is the one copy.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Wind"))
