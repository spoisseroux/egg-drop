-- Robux store: game passes, Stars products and ProcessReceipt.
-- Prompts are always server-initiated so the paid-random-items gate and the
-- once-per-player starter pack are enforced here, not trusted to the client.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.StoreCatalog)
local Economy = require(script.Parent.EconomyAnalytics)
local Policy = require(script.Parent.PaidRandomPolicy)

local Store = {}
local api -- { board(player), nursery, publish(board), onGrant(board, product, stars, balance) }
local stateRemote, resultRemote, requestRemote

local function policyAllowsPacks(player)
	-- Stars buy eggs, so every Stars product makes eggs paid random items.
	-- Fail closed: if the policy can't be read, packs stay hidden (PaidRandomPolicy,
	-- one cached read shared with the restricted-egg rule).
	return not Policy.resolve(player)
end

local function ownsPass(player, pass)
	if not Catalog.configured(pass) then return false end
	for attempt = 1, 3 do
		local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
		if ok then return owned == true end
		task.wait(attempt)
	end
	return false
end

function Store.snapshot(board)
	local passes, products = {}, {}
	local public = if board.nursery and board.nursery.state then api.nursery.public(board.nursery) else {}
	for _, pass in ipairs(Catalog.Passes) do
		table.insert(passes, { key = pass.key, name = pass.name, blurb = pass.blurb, price = pass.price,
			owned = board.passes[pass.key] == true, available = Catalog.configured(pass) })
	end
	for _, product in ipairs(Catalog.Products) do
		local claimed = product.once and public.starterClaimed == true
		table.insert(products, { key = product.key, name = product.name, blurb = product.blurb, price = product.price,
			stars = product.stars, once = product.once == true, claimed = claimed,
			available = Catalog.configured(product) and board.packsAllowed == true and not claimed })
	end
	return { passes = passes, products = products, packsAllowed = board.packsAllowed == true, ready = board.storeReady == true }
end

function Store.publish(board)
	if board.player.Parent ~= Players then return end
	stateRemote:FireClient(board.player, Store.snapshot(board))
	board.folder:SetAttribute("StorePasses", (if board.passes.doubleStars then "2x" else "") .. (if board.passes.supporter then "+S" else ""))
end

function Store.boost(board)
	return Catalog.boost(board.passes)
end

function Store.join(board)
	board.passes = board.passes or {}
	board.packsAllowed = false
	task.spawn(function()
		local player = board.player
		for _, pass in ipairs(Catalog.Passes) do board.passes[pass.key] = ownsPass(player, pass) end
		board.packsAllowed = policyAllowsPacks(player)
		board.storeReady = true
		if api.board(player) == board then Store.publish(board) end
	end)
end

-- Grants one product purchase. Waits briefly for the economy record to be free;
-- returns false so Roblox retries the receipt later when it can't finish.
function Store.grant(player, product, purchaseId)
	local deadline = os.clock() + 15
	while os.clock() < deadline do
		local board = api.board(player)
		if not board or board.closing then return false end
		local status = board.nursery.status
		if (status == "Ready" or status == "Retrying") and not board.nurseryBusy and not board.nursery.busy then
			board.nurseryBusy = true
			local ok, reason = api.nursery.grantPurchase(board.nursery, purchaseId, product.stars, product.once)
			board.nurseryBusy = false
			if api.board(player) == board then api.publish(board) end
			if ok then
				if reason ~= "AlreadyGranted" then
					local balance = api.nursery.public(board.nursery).nectar
					Economy.source(player, product.stars, balance, "IAP", "StarsPack_" .. product.key)
					Economy.event(player, "RobuxPurchase", 1, { product.key })
					if api.onGrant then api.onGrant(board, product, product.stars, balance) end
					resultRemote:FireClient(player, { kind = "product", key = product.key, stars = product.stars, balance = balance })
				end
				Store.publish(board)
				return true
			end
			if reason ~= "Busy" and reason ~= "Pending" and reason ~= "RevisionChanged" and reason ~= "Retrying" then
				warn("Egg Drop purchase not granted yet:", reason)
			end
		end
		task.wait(0.5)
	end
	return false
end

function Store.processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local product = Catalog.ProductById[info.ProductId]
	if not player or not product then
		if not product then warn("Egg Drop receipt for unknown product", info.ProductId) end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = Store.grant(player, product, tostring(info.PurchaseId))
	return if ok then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

local lastPrompt = {}
local function prompt(player, key)
	local board = api.board(player)
	if not board or board.closing or type(key) ~= "string" then return "Unavailable" end
	if os.clock() - (lastPrompt[player] or -math.huge) < 1 then return "Throttled" end
	lastPrompt[player] = os.clock()
	local pass = Catalog.PassByKey[key]
	if pass then
		if not Catalog.configured(pass) then return "NotConfigured" end
		if board.passes[pass.key] then return "Owned" end
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
		return "Prompted"
	end
	local product = Catalog.ProductByKey[key]
	if not product then return "Unknown" end
	if not Catalog.configured(product) then return "NotConfigured" end
	if not board.storeReady then return "Loading" end
	if not board.packsAllowed then return "Restricted" end
	if product.once and api.nursery.public(board.nursery).starterClaimed then return "AlreadyClaimed" end
	MarketplaceService:PromptProductPurchase(player, product.id)
	return "Prompted"
end

function Store.start(options)
	api = options
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local function remote(name)
		local existing = remotes:FindFirstChild(name)
		if existing then return existing end
		local made = Instance.new("RemoteEvent"); made.Name = name; made.Parent = remotes; return made
	end
	stateRemote, resultRemote, requestRemote = remote("StoreState"), remote("StoreResult"), remote("StoreRequest")
	requestRemote.OnServerEvent:Connect(function(player, action, key)
		if action == "open" then
			local board = api.board(player)
			if board then Store.publish(board); Economy.event(player, "StoreOpened") end
		elseif action == "prompt" then
			local status = prompt(player, key)
			if status ~= "Prompted" then resultRemote:FireClient(player, { kind = "rejected", key = key, reason = status }) end
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Catalog.PassById[passId]
		local board = api.board(player)
		if not pass or not board or not purchased then return end
		board.passes[pass.key] = true
		Economy.event(player, "PassPurchased_" .. pass.key)
		if api.onPass then api.onPass(board, pass) end
		resultRemote:FireClient(player, { kind = "pass", key = pass.key })
		Store.publish(board)
	end)
	Players.PlayerRemoving:Connect(function(player) lastPrompt[player] = nil; Policy.forget(player) end)
	MarketplaceService.ProcessReceipt = Store.processReceipt
	-- Studio-only test hook: simulate a granted receipt without real product ids.
	if game:GetService("RunService"):IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "EggDropStoreTestGrant"
		hook.OnInvoke = function(player, key, purchaseId)
			local product = Catalog.ProductByKey[key]
			if not product then return false end
			local ok = Store.grant(player, product, purchaseId)
			local board = api.board(player)
			return ok, board and api.nursery.public(board.nursery).nectar, board and board.packsAllowed
		end
		hook.Parent = game:GetService("ServerStorage")
	end
end

return Store
