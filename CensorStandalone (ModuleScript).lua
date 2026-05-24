--// CENSOR v8.0 (Corrected)

local Censor = {}

----------------------------------------------------
-- Services
----------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

----------------------------------------------------
-- Soft Dependencies
----------------------------------------------------

local Webhook, Config

pcall(function() Webhook = require(script.Parent.WebhookService) end)
pcall(function() Config = require(script.Configuration) end)

Config = Config or {
	WebhookEnabled = false,
	ConfidenceEnabled = true,
	ConfidenceDecayInterval = 60,
	ConfidenceDecayRate = 5,
	TimeBetweenFlags = 2,
	ConfidenceThreshold = 75,
	PingTolerationDistance = 8,
	AutoFlagWeight = 10,
	JumpSpamWeight = 8,
	AirborneWeight = 12,
	PunishmentType = "Kick",
	TempBanDuration = 86400,
	AdminExclusionEnabled = true,
	AdminGroupId = 16005697,
	AdminRanks = {255,254}
}

----------------------------------------------------
-- Datastores (Fail-Safe)
----------------------------------------------------

local BanStore, ModFlagStore

pcall(function()
	BanStore = DataStoreService:GetDataStore("CensorBans_v2")
	ModFlagStore = DataStoreService:GetDataStore("CensorModeratorFlags_v2")
end)

----------------------------------------------------
-- Runtime
----------------------------------------------------

Censor.Sessions = {}

----------------------------------------------------
-- Utilities
----------------------------------------------------

local function now() return os.time() end

local function alive(p)
	return p and p.Parent and Censor.Sessions[p.UserId]
end

local function isAdmin(p)
	if not Config.AdminExclusionEnabled then return false end
	local ok, inGroup = pcall(function() return p:IsInGroup(Config.AdminGroupId) end)
	if not ok or not inGroup then return false end
	local rank = p:GetRankInGroup(Config.AdminGroupId)
	for _, r in ipairs(Config.AdminRanks) do
		if rank == r then return true end
	end
	return false
end

local function isModerator(p)
	local ok, inGroup = pcall(function() return p:IsInGroup(Config.ModeratorGroupId or Config.AdminGroupId) end)
	if not ok or not inGroup then return false end
	local rank = p:GetRankInGroup(Config.ModeratorGroupId or Config.AdminGroupId)
	for _, r in ipairs(Config.ModeratorRanks or Config.AdminRanks) do
		if rank == r then return true end
	end
	return false
end

----------------------------------------------------
-- Persistence
----------------------------------------------------

function Censor:LoadModeratorFlags(uid)
	if not ModFlagStore then return {} end
	local data
	pcall(function() data = ModFlagStore:GetAsync(uid) end)
	return typeof(data) == "table" and data or {}
end

function Censor:SaveModeratorFlags(uid, flags)
	if not ModFlagStore then return end
	pcall(function() ModFlagStore:SetAsync(uid, flags) end)
end

function Censor:CheckBan(p)
	if not BanStore then return false end
	local banned
	pcall(function() banned = BanStore:GetAsync(p.UserId) end)

	if banned == true then
		p:Kick("CENSOR: You are permanently banned.")
		return true
	elseif type(banned) == "number" then
		if banned > now() then
			p:Kick("CENSOR: You are temporarily banned.")
			return true
		else
			-- Ban expired, clean up
			pcall(function() BanStore:RemoveAsync(p.UserId) end)
		end
	end
	return false
end

----------------------------------------------------
-- Sessions
----------------------------------------------------

function Censor:CreateSession(p)
	self.Sessions[p.UserId] = {
		Confidence = 0,
		SystemFlags = 0,
		ModeratorFlags = self:LoadModeratorFlags(p.UserId),
		LastSystemFlagTime = 0,

		LastPos = nil,
		SpeedBuffer = 0,
		JumpBuffer = {},

		FallStartTime = nil,
		FallStartHeight = nil,

		Heartbeat = nil
	}
end

----------------------------------------------------
-- Webhook
----------------------------------------------------

function Censor:Emit(p, reason, confidence, alertType)
	if not (Config.WebhookEnabled and Webhook and Webhook.Send) then return end
	if alertType and Config.WebhookAlertTypes and not Config.WebhookAlertTypes[alertType] then return end

	pcall(function()
		Webhook:Send(p.Name, reason, confidence or 0, "CENSOR")
	end)
end

----------------------------------------------------
-- Confidence Engine
----------------------------------------------------

function Censor:DecayLoop()
	task.spawn(function()
		while true do
			task.wait(Config.ConfidenceDecayInterval)
			for _, s in pairs(self.Sessions) do
				s.Confidence = math.max(0, s.Confidence - Config.ConfidenceDecayRate)
			end
		end
	end)
end

function Censor:ApplySystemFlag(p, weight, reason)
	local s = self.Sessions[p.UserId]
	if not s or isAdmin(p) then return end

	if now() - s.LastSystemFlagTime < Config.TimeBetweenFlags then return end

	s.LastSystemFlagTime = now()
	s.SystemFlags += 1

	if Config.ConfidenceEnabled then
		s.Confidence = math.min(100, s.Confidence + weight)
		self:Emit(p, "[FLAG] " .. reason, s.Confidence, "Flag")

		if s.Confidence >= Config.ConfidenceThreshold then
			self:Punish(p, "Confidence threshold exceeded: " .. reason)
		end
	else
		-- If confidence is disabled, punish immediately
		self:Punish(p, reason)
	end
end

----------------------------------------------------
-- Moderator System
----------------------------------------------------

function Censor:ModeratorFlag(target, mod, reason)
	local s = self.Sessions[target.UserId]
	if not s then return "No session." end
	if not isModerator(mod) then return "Unauthorized." end

	table.insert(s.ModeratorFlags, {
		Time = now(),
		Moderator = mod.Name,
		Reason = tostring(reason)
	})

	self:SaveModeratorFlags(target.UserId, s.ModeratorFlags)
	self:Emit(target, "[MOD FLAG] "..reason, s.Confidence, "ModeratorAction")

	return "Moderator flag added."
end

----------------------------------------------------
-- Punishment
----------------------------------------------------

function Censor:Punish(p, reason)
	self:Emit(p, "[ENFORCE] "..reason, 100, "Punish")

	if Config.PunishmentType == "Kick" or not BanStore then
		p:Kick("CENSOR: "..reason)
		return
	end

	if Config.PunishmentType == "TempBan" then
		pcall(function() BanStore:SetAsync(p.UserId, now() + Config.TempBanDuration) end)
	end

	if Config.PunishmentType == "Ban" then
		pcall(function() BanStore:SetAsync(p.UserId, true) end)
	end

	p:Kick("CENSOR: "..reason)
end

----------------------------------------------------
-- Monitoring Core
----------------------------------------------------

function Censor:StartMonitoring(p)
	local s = self.Sessions[p.UserId]
	if not s then return end

	if s.Heartbeat then s.Heartbeat:Disconnect() end

	local char = p.Character or p.CharacterAdded:Wait()
	local hum = char:WaitForChild("Humanoid")
	local root = char:WaitForChild("HumanoidRootPart")

	s.LastPos = root.Position
	s.SpeedBuffer = 0
	table.clear(s.JumpBuffer)

	s.Heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not alive(p) or hum.Health <= 0 then return end

		local pos = root.Position
		local dist = (pos - s.LastPos).Magnitude
		local horizontalDist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(s.LastPos.X, 0, s.LastPos.Z)).Magnitude

		-- Teleportation Check
		if Config.CheckTeleportation and dist > (Config.MaxDisplacement or 25) then
			self:ApplySystemFlag(p, Config.TeleportWeight or 20, "Teleportation anomaly")
		end

		-- WalkSpeed Check
		if Config.CheckWalkSpeed and dist > 0.1 then
			local speed = dist / dt
			local maxAllowed = hum.WalkSpeed + 12 + Config.PingTolerationDistance

			if speed > maxAllowed then
				s.SpeedBuffer += dt
			else
				s.SpeedBuffer = math.max(0, s.SpeedBuffer - dt * 2)
			end

			if s.SpeedBuffer > 0.6 then
				self:ApplySystemFlag(p, Config.AutoFlagWeight, "Speed anomaly")
				s.SpeedBuffer = 0
			end
		end

		-- Jump Spam Check
		if hum:GetState() == Enum.HumanoidStateType.Jumping then
			local t = tick()
			table.insert(s.JumpBuffer, t)
			while #s.JumpBuffer > 10 do table.remove(s.JumpBuffer, 1) end

			if #s.JumpBuffer >= 8 and (s.JumpBuffer[#s.JumpBuffer] - s.JumpBuffer[1]) < (Config.JumpSpamWindow or 2) then
				self:ApplySystemFlag(p, Config.JumpSpamWeight, "Jump spam")
				table.clear(s.JumpBuffer)
			end
		end

		-- Flight Check
		if hum:GetState() == Enum.HumanoidStateType.Freefall then
			if Config.CheckWalkSpeed and horizontalDist > 0.1 then
				local hSpeed = horizontalDist / dt
				if hSpeed > (Config.MaxAirborneSpeed or 28) + Config.PingTolerationDistance then
					self:ApplySystemFlag(p, Config.AirborneWeight, "Airborne speed anomaly")
				end
			end

			if not s.FallStartTime then
				s.FallStartTime = tick()
				s.FallStartHeight = pos.Y
			else
				if tick() - s.FallStartTime > (Config.MaxAirtime or 3) and (s.FallStartHeight - pos.Y) < 10 then
					self:ApplySystemFlag(p, Config.AirTimeWeight or 12, "Suspicious flight")
					s.FallStartTime = tick()
				end
			end
		else
			s.FallStartTime = nil
			s.FallStartHeight = nil
		end

		s.LastPos = pos
	end)
end

----------------------------------------------------
-- Init
----------------------------------------------------

function Censor:Init()
	if Webhook and Webhook.Init then
		pcall(function() Webhook:Init() end)
	end

	self:DecayLoop()

	local function onPlayerJoin(p)
		if self:CheckBan(p) then return end
		self:CreateSession(p)
		if p.Character then self:StartMonitoring(p) end
		p.CharacterAdded:Connect(function() self:StartMonitoring(p) end)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerJoin, p)
	end

	Players.PlayerAdded:Connect(onPlayerJoin)

	Players.PlayerRemoving:Connect(function(p)
		local s = self.Sessions[p.UserId]
		if s then
			if s.Heartbeat then s.Heartbeat:Disconnect() end
			self:SaveModeratorFlags(p.UserId, s.ModeratorFlags)
		end
		self.Sessions[p.UserId] = nil
	end)

	warn("CENSOR v8.0 — OMEGA BUILD ONLINE")
end

return Censor