--[[
	Animated Poster/Decal Manager
	
	Features:
	- Frame-rate adaptive animation speed
	- Distance-based culling (pauses when far away)
	- Automatic cleanup on decal destruction
	- Handles character respawns
	- Efficient FPS tracking
]]

local Manager = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Player references
local Player = Players.LocalPlayer
local Root: BasePart? = nil

-- Configuration
local Config = {
	MaxRenderDistance = 200,      -- Studs before animation pauses
	DistanceCheckInterval = 0.5,  -- Seconds between distance checks (optimization)
	TargetFPS = 60,               -- Cap FPS tracking at this value
	MinAnimationSpeed = 0.05,     -- Minimum seconds per frame
	MaxAnimationSpeed = 0.5,      -- Maximum seconds per frame (when low FPS)
	DefaultFrameRate = 12,        -- Frames per second for animations
}

-- FPS tracking state
local FPSData = {
	Frames = {},
	Current = 60,
	Runtime = 0,
}

-- Active animation tracking for cleanup
local ActiveAnimations: {[Decal]: thread} = {}

-- Decal animation definitions
-- Format: [DecalName] = { frames = {textures}, fps = framesPerSecond }
Manager.DecalInformation = {
	["aliensign_animated"] = {
		frames = {
			"rbxassetid://15900982298",
			"rbxassetid://15900982087",
			"rbxassetid://15900981878",
			"rbxassetid://15900981676",
			"rbxassetid://15900981336",
			"rbxassetid://15900981106",
		},
		fps = 12, -- Animation plays at 12 FPS
	}
}

local function updateRootReference()
	local character = Player.Character
	if character then
		Root = character:FindFirstChild("HumanoidRootPart")
	else
		Root = nil
	end
end

local function getDistanceToDecal(decal: Decal): number
	if not Root then return math.huge end
	
	local parent = decal.Parent
	if not parent or not parent:IsA("BasePart") then return math.huge end
	
	return (parent.Position - Root.Position).Magnitude
end

function Manager:UpdateFPS()
	local now = os.clock()
	local frames = FPSData.Frames
	
	-- Add current frame timestamp
	table.insert(frames, now)
	
	-- Remove frames older than 1 second (more efficient than backwards iteration)
	local cutoff = now - 1
	while frames[1] and frames[1] < cutoff do
		table.remove(frames, 1)
	end
	
	-- Calculate FPS
	local elapsed = now - FPSData.Runtime
	if elapsed >= 1 then
		FPSData.Current = math.clamp(#frames, 1, Config.TargetFPS)
	else
		FPSData.Current = math.clamp(math.floor(#frames / math.max(elapsed, 0.001)), 1, Config.TargetFPS)
	end
end

function Manager:StopAnimation(decal: Decal)
	local thread = ActiveAnimations[decal]
	if thread then
		task.cancel(thread)
		ActiveAnimations[decal] = nil
	end
end

function Manager:UpdateFrames(decal: Decal)
	-- Stop any existing animation for this decal
	self:StopAnimation(decal)
	
	local decalInfo = self.DecalInformation[decal.Name]
	if not decalInfo then return end
	
	local frames = decalInfo.frames
	local animationFPS = decalInfo.fps or Config.DefaultFrameRate
	local frameCount = #frames
	
	if frameCount == 0 then return end
	
	local thread = task.spawn(function()
		local index = 1
		local inRange = false
		local lastDistanceCheck = 0
		
		while decal and decal.Parent do
			local now = os.clock()
			if now - lastDistanceCheck >= Config.DistanceCheckInterval then
				lastDistanceCheck = now
				inRange = getDistanceToDecal(decal) <= Config.MaxRenderDistance
			end
			
			if inRange then
				-- Update texture
				decal.Texture = frames[index]
				index = index % frameCount + 1
				
				-- Calculate frame delay based on client FPS
				-- Scale animation speed to maintain consistent perceived speed
				local fpsRatio = FPSData.Current / Config.TargetFPS
				local baseDelay = 1 / animationFPS
				local adjustedDelay = math.clamp(baseDelay / fpsRatio, Config.MinAnimationSpeed, Config.MaxAnimationSpeed)
				
				task.wait(adjustedDelay)
			else
				-- When out of range, check less frequently
				task.wait(Config.DistanceCheckInterval)
			end
		end
		
		-- Cleanup when decal is destroyed
		ActiveAnimations[decal] = nil
	end)
	
	ActiveAnimations[decal] = thread
	
	-- Cleanup when decal is destroyed
	decal.Destroying:Once(function()
		self:StopAnimation(decal)
	end)
end

function Manager:AddDecal(decal: Decal)
	if not self.DecalInformation[decal.Name] then return end
	if ActiveAnimations[decal] then return end -- Already animating
	
	self:UpdateFrames(decal)
end

function Manager:RemoveDecal(decal: Decal)
	self:StopAnimation(decal)
end

function Manager:GetActiveCount(): number
	local count = 0
	for _ in ActiveAnimations do
		count += 1
	end
	return count
end

function Manager:Init(worldDecals: {Decal})
	-- Setup character tracking
	updateRootReference()
	
	Player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		updateRootReference()
	end)
	
	Player.CharacterRemoving:Connect(function()
		Root = nil
	end)
	
	-- Initialize FPS tracking
	FPSData.Runtime = os.clock()
	
	RunService.PreSimulation:Connect(function()
		self:UpdateFPS()
	end)
	
	-- Start animations for provided decals
	for _, decal in worldDecals do
		self:UpdateFrames(decal)
	end
	
	-- Watch for new decals being added to workspace
	game.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Decal") and self.DecalInformation[descendant.Name] then
			task.defer(function()
				self:AddDecal(descendant)
			end)
		end
	end)
end

return Manager