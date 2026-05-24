local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

warn("[BOOT] Server starting...")

local Cmdr = require(ServerScriptService:WaitForChild("Cmdr"))
Cmdr:RegisterDefaultCommands()

warn("[BOOT] Cmdr initialized.")

local Shared = ReplicatedStorage:WaitForChild("SharedPackages")
warn("[BOOT] SharedPackages loaded.")

-- Enforce an exact initialization order
local InitializationOrder = {
	"Webhook",
	"Censor",
	"Data",
	"Voicelines",
	"Lights",
	"Shop",
	"BankService",
	"BankNPCController"
}

local Packages = {
	Webhook    = require(ServerScriptService.WebhookService),
	Censor     = require(ServerScriptService.CensorStandalone),
	Data       = require(ServerScriptService.DataService),
	Voicelines = require(ServerScriptService.Voicelines),
	Lights     = require(ServerScriptService.Lights),
	Shop       = require(Shared:WaitForChild("ShopService")),

	-- Bank
	BankService       = require(ServerScriptService.BankService),
	BankNPCController = require(ServerScriptService.BankNPCController),
}

for _, name in ipairs(InitializationOrder) do
	local pkg = Packages[name]
	if pkg and type(pkg.Init) == "function" then
		warn("[BOOT] Initializing " .. name)
		pkg:Init()
	end
end

warn("[BOOT] Initializing Bank systems remotes")

-- Bind remotes manually (if BankService:Init() doesn't do it)
if type(Packages.BankService.BindRemote) == "function" then
	Packages.BankService:BindRemote()
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuyRemote = Remotes:WaitForChild("Buy")

-- Handle shop requests
BuyRemote.OnServerEvent:Connect(function(player, action, ...)
	local args = {...}

	if action == "Open" then
		local shopId = args[1]
		local result = Packages.Shop:Open(player, shopId)
		BuyRemote:FireClient(player, "Sync", result)

	elseif action == "Purchase" then
		local itemName = args[1]
		local shopId = args[2]
		Packages.Shop:Purchase(player, itemName, shopId)

	else
		warn("[SHOP] Unknown action:", action, player.Name)
	end
end)

local CmdrRoot = ServerScriptService:WaitForChild("Cmdr")
Cmdr:RegisterCommandsIn(CmdrRoot:WaitForChild("CustomCommands"))

local CmdrStandalone = require(CmdrRoot)

CmdrStandalone.Registry:RegisterHook("BeforeRun", function(context)
	local player = context.Executor
	local adminGroupId = 16005697
	local adminRanks = {255, 254, 253, 252, 251}

	local ok, rank = pcall(function()
		return player:GetRankInGroup(adminGroupId)
	end)

	if ok then
		for _, r in ipairs(adminRanks) do
			if rank == r then
				return nil -- Allowed to run command
			end
		end
	end

	return "You do not have permission to execute this command."
end)

warn("[BOOT] Server fully initialized.")