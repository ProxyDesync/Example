local Config = {

	----------------------------------------------------
	-- Enforcement
	----------------------------------------------------

	PunishmentType = "Kick",       -- Kick | TempBan | Ban
	TempBanDuration = 86400,       -- seconds

	----------------------------------------------------
	-- Confidence Engine
	----------------------------------------------------

	ConfidenceEnabled = true,
	ConfidenceThreshold = 75,

	ConfidenceDecayRate = 5,       -- points per interval
	ConfidenceDecayInterval = 60,  -- seconds

	TimeBetweenFlags = 2,          -- anti-spam window (seconds)

	----------------------------------------------------
	-- Flag Weights (System Only)
	----------------------------------------------------

	AutoFlagWeight = 10,
	JumpSpamWeight = 8,
	AirborneWeight = 12,
	AirTimeWeight = 10,
	TeleportWeight = 20,

	----------------------------------------------------
	-- Movement & Physics Sensors
	----------------------------------------------------

	CheckWalkSpeed = true,
	CheckTeleportation = true,

	PingTolerationDistance = 8,

	MaxDisplacement = 25,      -- studs per frame
	MaxAirborneSpeed = 28,     -- studs/s (horizontal)
	MaxAirtime = 2.3,          -- seconds

	JumpSpamWindow = 0.8,      -- seconds

	----------------------------------------------------
	-- Unimplemented Specs (Temporarily Disabled)
	----------------------------------------------------

	-- Character Integrity Firewall
	-- BlockedAnimations = { "rbxassetid://148840371" },

	-- Memory & Exploit Pattern Monitoring
	-- MemoryMonitoringEnabled = true,
	-- MemorySpikeThreshold = 50,

	-- Server Hop Detection
	-- ServerHopTrackingEnabled = true,
	-- ServerHopBanEnabled = true,

	----------------------------------------------------
	-- Moderator Governance
	----------------------------------------------------

	ModeratorGroupId = 16005697,
	ModeratorRanks = { 255 },

	-- Admin Exclusion
	AdminExclusionEnabled = true,
	AdminGroupId = 16005697,
	AdminRanks = { 255, 254, 253, 252, 251 },

	----------------------------------------------------
	-- Telemetry & Webhooks
	----------------------------------------------------

	WebhookEnabled = true,

	WebhookAlertTypes = {
		Flag = true,
		Punish = true,
		ModeratorAction = true,
		Suspicious = true
	}
}

return Config