--!strict
-- Dropper - reads Settings from loader getgenv (no hardcoded Settings here)
local Settings = (getgenv and rawget(getgenv(), "Settings") or rawget(_G, "Settings")) or error("Settings not found - loader must set Settings before HttpGet")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
if getconnections then
	for _, connection in ipairs(getconnections(player.Idled)) do
		pcall(function() connection:Disable() end)
		pcall(function() connection:Disconnect() end)
	end
end
player.Idled:Connect(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.zero) end)

local DropPerDeath = 5_000
if #Settings.AccountUserIds ~= Settings.AccountCount then warn(string.format("AccountCount (%d) != AccountUserIds (%d).", Settings.AccountCount, #Settings.AccountUserIds)) return end
local myAccountIndex: number? = nil
for index, userId in ipairs(Settings.AccountUserIds) do if userId == player.UserId then myAccountIndex = index break end end
if not myAccountIndex then warn(string.format("[%s] UserId %d is not configured.", player.Name, player.UserId)) return end
local deathsNeeded = math.ceil(Settings.TargetDrop / (DropPerDeath * Settings.AccountCount))
local projectedTotal = deathsNeeded * Settings.AccountCount * DropPerDeath

-- == AUTO DEAD whole part from LocalScript > Utility (no UI) ==
local AutoDead = {}
function AutoDead.killHumanoid(humanoid: Humanoid): boolean
	if not humanoid or humanoid.Health <= 0 then return false end
	local character = humanoid.Parent :: Model
	pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
	pcall(function() character:BreakJoints() end)
	pcall(function() humanoid.Health = 0 end)
	pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Dead) end)
	if humanoid.Health > 0 then pcall(function() humanoid:TakeDamage(1e9) end) end
	if humanoid.Health > 0 and humanoid.RootPart then pcall(function() humanoid.RootPart:Destroy() end) end
	return humanoid.Health <= 0
end
function AutoDead.killCharacter(character: Model): boolean
	local h = character:FindFirstChildOfClass("Humanoid")
	if not h then pcall(function() character:BreakJoints() end) return true end
	return AutoDead.killHumanoid(h)
end

local respawnRequested = false
local function requestInstantRespawn()
	if Settings.Mode ~= "Blatant" then return end
	if respawnRequested then return end
	respawnRequested = true
	task.defer(function()
		if Settings.Mode ~= "Blatant" then return end
		-- Instant respawn: try all known server remotes/LoadCharacter tricks, then fall back to 0-delay
		local done = false
		pcall(function()
			-- Try common respawn remotes (bypass 5s cooldown)
			for _,v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
				if v:IsA("RemoteEvent") and (v.Name:lower():find("respawn") or v.Name:lower():find("loadchar") or v.Name:lower():find("reset") or v.Name:lower():find("spawn")) then
					v:FireServer() done=true break
				end
			end
		end)
		if not done then pcall(function() game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") end) end
		-- Also try StarterGui Reset bindable
		pcall(function() game:GetService("StarterGui"):SetCore("DevEnableagd", true) end)
		task.wait(0.1)
		respawnRequested = false
	end)
end
player.CharacterAdded:Connect(function(character)
	respawnRequested = false
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then humanoid.Died:Connect(function() if Settings.Mode == "Blatant" then requestInstantRespawn() end end) end
end)
player.CharacterRemoving:Connect(function(character) if Settings.Mode ~= "Blatant" then return end if player.Character == character or player.Character == nil then requestInstantRespawn() end end)
if player.Character then local hum = player.Character:FindFirstChildOfClass("Humanoid") if hum then hum.Died:Connect(function() if Settings.Mode == "Blatant" then requestInstantRespawn() end end) end end
local function getClient(): Player? return Players:GetPlayerByUserId(Settings.ClientUserId) end
local function getRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end
local function getHumanoid(character: Model): Humanoid? return character:FindFirstChildOfClass("Humanoid") end
local function waitForCharacter(): Model?
	local startTime = os.clock()
	while os.clock() - startTime < Settings.RespawnTimeout do
		local character = player.Character
		if character and getRoot(character) then local humanoid = getHumanoid(character) if humanoid and humanoid.Health > 0 then return character end end
		task.wait(Settings.CheckInterval)
	end
	warn(string.format("[%s] Character timeout.", player.Name)) return nil
end
local function waitForNewCharacter(oldCharacter: Model): Model?
	local startTime = os.clock()
	while os.clock() - startTime < Settings.RespawnTimeout do
		local character = player.Character
		if character and character ~= oldCharacter and getRoot(character) then local humanoid = getHumanoid(character) if humanoid and humanoid.Health > 0 then if Settings.CharacterReadyDelay > 0 then task.wait(Settings.CharacterReadyDelay) end return character end end
		task.wait(Settings.CheckInterval)
	end
	warn(string.format("[%s] Instant respawn timeout.", player.Name)) return nil
end
local function isAccountReady(userId: number): boolean
	local targetPlayer = Players:GetPlayerByUserId(userId) if not targetPlayer then return false end
	local character = targetPlayer.Character if not character then return false end
	local root = getRoot(character) if not root then return false end
	local humanoid = getHumanoid(character) if not humanoid then return false end
	if humanoid.Health <= 0 then return false end
	return true
end
local function waitForPreviousAccount(): boolean
	if myAccountIndex == 1 then return true end
	local previousIndex = (myAccountIndex :: number) - 1
	local previousUserId = Settings.AccountUserIds[previousIndex]
	if not previousUserId then return false end
	print(string.format("[%s] Waiting for Account %d...", player.Name, previousIndex))
	local startTime = os.clock()
	while os.clock() - startTime < Settings.RespawnTimeout do
		if isAccountReady(previousUserId) then print(string.format("[%s] Account %d is ready. My turn.", player.Name, previousIndex)) return true end
		task.wait(Settings.CheckInterval)
	end
	warn(string.format("[%s] Previous account did not become ready.", player.Name)) return false
end
local function teleportToClient(character: Model): boolean
	local client = getClient() if not client then warn(string.format("[%s] Client is not in server.", player.Name)) return false end
	local clientCharacter = client.Character if not clientCharacter then warn(string.format("[%s] Client has no character.", player.Name)) return false end
	local clientRoot = getRoot(clientCharacter) if not clientRoot then warn(string.format("[%s] Client has no HumanoidRootPart.", player.Name)) return false end
	local root = getRoot(character) if not root then return false end
	local targetCFrame = clientRoot.CFrame
	character:PivotTo(targetCFrame) task.wait()
	local newRoot = getRoot(character) if not newRoot then return false end
	local distance = (newRoot.Position - targetCFrame.Position).Magnitude
	if distance > 10 then warn(string.format("[%s] Teleport verification failed. Distance: %.2f", player.Name, distance)) return false end
	print(string.format("[%s] Teleported to Client.", player.Name)) return true
end
local function selfKill(character: Model): boolean
	local humanoid = getHumanoid(character)
	if not humanoid then warn(string.format("[%s] Humanoid not found.", player.Name)) return false end
	if humanoid.Health <= 0 then return false end
	if Settings.Mode == "Blatant" then
		local killed = AutoDead.killHumanoid(humanoid)
		if killed then print(string.format("[%s] AutoDead (Blatant) killed. Requesting instant respawn...", player.Name)) return true end
		return false
	end
	humanoid.Health = 0 print(string.format("[%s] Self-killed. Requesting instant respawn...", player.Name)) return true
end
local function performDrop(): boolean
	local character = waitForCharacter() if not character then return false end
	local characterToKill = character
	if not getClient() then return false end
	local teleported = teleportToClient(characterToKill) if not teleported then warn(string.format("[%s] Teleport failed.", player.Name)) return false end
	task.wait(Settings.KillDelay)
	if player.Character ~= characterToKill then warn(string.format("[%s] Character changed before kill.", player.Name)) return false end
	local killed = selfKill(characterToKill) if not killed then return false end
	local newCharacter = waitForNewCharacter(characterToKill) if not newCharacter then return false end
	print(string.format("[%s] Instantly respawned and ready.", player.Name)) return true
end
print("========================================") print("       SEQUENTIAL AUTO DROP") print("========================================")
print("Account:", player.Name) print("UserId:", player.UserId) print("Account Order:", myAccountIndex) print("Account Count:", Settings.AccountCount)
print("Client:", Settings.ClientUserId) print("Drop Per Death:", DropPerDeath) print("Deaths Needed:", deathsNeeded) print("Projected Total:", projectedTotal)
print("Kill Delay:", Settings.KillDelay) print("Mode:", Settings.Mode)
local initialCharacter = waitForCharacter() if not initialCharacter then return end
local deathsCompleted = 0
while deathsCompleted < deathsNeeded do
	local previousReady = waitForPreviousAccount()
	if not previousReady then warn(string.format("[%s] Could not synchronize with previous account.", player.Name)) task.wait(Settings.CheckInterval) continue end
	local character = waitForCharacter() if not character then task.wait(Settings.CheckInterval) continue end
	print(string.format("[%s] READY | Drop %d/%d", player.Name, deathsCompleted + 1, deathsNeeded))
	local success = performDrop()
	if not success then warn(string.format("[%s] Drop failed. Retrying same drop.", player.Name)) task.wait(Settings.CheckInterval) continue end
	deathsCompleted += 1
	local personalDrop = deathsCompleted * DropPerDeath
	local combinedDrop = deathsCompleted * Settings.AccountCount * DropPerDeath
	print(string.format("[%s] COMPLETE | %d/%d | Personal: %d | Combined: %d", player.Name, deathsCompleted, deathsNeeded, personalDrop, combinedDrop))
end
local finalPersonal = deathsCompleted * DropPerDeath
local finalCombined = deathsCompleted * Settings.AccountCount * DropPerDeath
print("========================================") print("         AUTO DROP COMPLETE") print("========================================")
print("Account:", player.Name) print("Deaths:", deathsCompleted) print("Personal Drop:", finalPersonal) print("Combined Drop:", finalCombined) print("Target:", Settings.TargetDrop)
if finalCombined >= Settings.TargetDrop then print("Status: TARGET REACHED") else print("Remaining:", Settings.TargetDrop - finalCombined) end
