-- v1 launch build: removes test content from the open place before a launch publish
-- (LISTING.md section 9, "No ZZSpecs or test content ships").
--
-- Launch publish steps:
--   1. Stop any `rojo serve default.project.json`; serve `launch.project.json` instead (it ignores
--      every ZZSpecs folder, so live sync never puts the specs back).
--   2. In Studio Edit, run this file (command bar, or the MCP execute_luau tool with its source)
--      with APPLY = false. It returns a report: what it would remove, and "REVIEW" lines for names
--      that look like test content but are not on the removal list.
--   3. Check the report, set APPLY = true, run it again, then save and publish.
-- Studio-only test hooks (EggDropStoreTestGrant, EggDropRoundTestHook, DeckNetEcho) are created at
-- runtime behind RunService:IsStudio() and never exist in a live server; nothing to strip.
local APPLY = false

local removed, review = {}, {}
-- Exact test containers: every ZZSpecs folder (Rojo spec copies) and the retired baseplate.
local function isTestContainer(node)
	if node.Name == "ZZSpecs" then return true end
	if node.Parent == game:GetService("ServerStorage") and node.Name == "Baseplate_RetiredByGreybox" then return true end
	-- The walkable greybox from scripts/GardenGreybox.lua (Workspace.GardenGreybox). The shipped
	-- garden lives under Workspace.EggDropLounge (LoungeGreyboxArt's Greybox* parts are part of it).
	if node.Parent == workspace and node.Name == "GardenGreybox" then return true end
	return false
end
-- Capture and spec fixtures: Studio-only GUIs and models the capture runs create. (EggDropScreenProbe
-- and EggDropClickProbe are production runtime GUIs: the "^_" probe pattern leaves them alone.)
local fixturePatterns = { "^_V%d+", "Fixture", "^_%w*Probe$", "^ZZ", "^SpecGui_", "^_Capture", "CaptureRig", "^_Thumb" }
local function looksLikeFixture(name)
	for _, pattern in ipairs(fixturePatterns) do if name:find(pattern) then return true end end
	return false
end
-- Names that look like test content but are production: reported for review, never removed.
local function looksSuspicious(name)
	local lower = name:lower()
	return lower:find("greybox") ~= nil or lower:find("test") ~= nil or lower:find("debug") ~= nil or lower:find("capture") ~= nil
end

local roots = {
	workspace, game:GetService("ServerStorage"), game:GetService("ServerScriptService"),
	game:GetService("ReplicatedStorage"), game:GetService("StarterPlayer"), game:GetService("StarterGui"),
	game:GetService("Lighting"),
}
local doomed = {}
for _, root in ipairs(roots) do
	for _, node in ipairs(root:GetDescendants()) do
		local covered = false
		for _, d in ipairs(doomed) do if node:IsDescendantOf(d) then covered = true; break end end
		if covered then continue end
		if isTestContainer(node) or looksLikeFixture(node.Name) then
			table.insert(doomed, node)
			table.insert(removed, node:GetFullName() .. " (" .. node.ClassName .. ", " .. #node:GetDescendants() .. " descendants)")
		elseif looksSuspicious(node.Name) and not node:IsA("BasePart") then
			-- Parts named Greybox* belong to the shipped garden build; scripts and folders get a look.
			table.insert(review, node:GetFullName() .. " (" .. node.ClassName .. ")")
		end
	end
end
if APPLY then for _, node in ipairs(doomed) do node:Destroy() end end
local lines = { (if APPLY then "REMOVED " else "WOULD REMOVE ") .. #removed .. ":" }
for _, line in ipairs(removed) do table.insert(lines, "  " .. line) end
table.insert(lines, "REVIEW " .. #review .. " (not removed):")
for i, line in ipairs(review) do if i <= 60 then table.insert(lines, "  " .. line) end end
if #review > 60 then table.insert(lines, "  ... " .. (#review - 60) .. " more") end
return table.concat(lines, "\n")
