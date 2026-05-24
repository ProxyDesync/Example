--[[
	Animated Poster Effects System
	
	Automatically finds and animates all decals that have
	animation data defined in Manager.DecalInformation
]]

local ContentProvider = game:GetService("ContentProvider")
local Manager = require(script.Manager)

-- Configuration
local PRELOAD_ASSETS = true  -- Whether to preload textures
local BATCH_SIZE = 10        -- Decals to process per batch

-- Collect all animated decals
local function collectAnimatedDecals(): {Decal}
	local decals = {}
	
	for _, descendant in game:GetDescendants() do
		if descendant:IsA("Decal") and Manager.DecalInformation[descendant.Name] then
			table.insert(decals, descendant)
		end
	end
	
	return decals
end

-- Preload all animation frames
local function preloadDecalAssets(decals: {Decal})
	if not PRELOAD_ASSETS then return end
	
	local assetsToLoad = {}
	local loadedNames = {}
	
	for _, decal in decals do
		local info = Manager.DecalInformation[decal.Name]
		if info and info.frames and not loadedNames[decal.Name] then
			loadedNames[decal.Name] = true
			
			for _, textureId in info.frames do
				table.insert(assetsToLoad, textureId)
			end
		end
	end
	
	-- Preload in background
	if #assetsToLoad > 0 then
		task.spawn(function()
			ContentProvider:PreloadAsync(assetsToLoad)
		end)
	end
end

-- Initialize system
local decals = collectAnimatedDecals()

if #decals > 0 then
	preloadDecalAssets(decals)
	Manager:Init(decals)
end