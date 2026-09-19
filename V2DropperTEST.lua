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

-- == Time estimate helpers ==
local function formatTime(seconds: number): string
	local s = math.floor(seconds)
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	local sec = s % 60
	if h > 0 then
		return string.format("%dh %dm %ds", h, m, sec)
	elseif m > 0 then
		return string.format("%dm %ds", m, sec)
	else
		return string.format("%ds", sec)
	end
end

-- Per-drop time estimate broken into its phases (seconds)
local KILL_DELAY = Settings.KillDelay or 0
local TELEPORT_SETTLE = 0.15     -- wait inside teleportToClient
local POST_TELEPORT = 0.35       -- gap between teleport and kill
local KILL_ROUTINE = 0.20        -- AutoDead escalation waits (~0.05 x 4)
local RESPAWN_ESTIMATE = 0.80    -- typical time to see a fresh alive character
local LOOP_BREATHE = 0.25        -- end-of-loop task.wait

local estimatedPerDrop = TELEPORT_SETTLE + POST_TELEPORT + KILL_DELAY + KILL_ROUTINE + RESPAWN_ESTIMATE + LOOP_BREATHE
local totalDrops = deathsNeeded * Settings.AccountCount
local estimatedTotalSeconds = estimatedPerDrop * totalDrops

-- == AUTO DEAD whole part from LocalScript > Utility (no UI) ==
local AutoDead = {}
function AutoDead.killHumanoid(humanoid: Humanoid): boolean
	if not humanoid or humanoid.Health <= 0 then return false end
	local character = humanoid.Parent :: Model

	pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
	pcall(function() character:BreakJoints() end)
	task.wait(0.05)
	pcall(function() humanoid.Health = 0 end)
	task.wait(0.05)
	pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Dead) end)

	if humanoid.Health > 0 then
		task.wait(0.05)
		pcall(function() humanoid:TakeDamage(1e9) end)
	end
	if humanoid.Health > 0 and humanoid.RootPart then
		task.wait(0.05)
		pcall(function() humanoid.RootPart:Destroy() end)
	end
	return humanoid.Health <= 0
end
function AutoDead.killCharacter(character: Model): boolean
	local h = character:FindFirstChildOfClass("Humanoid")
	if not h then pcall(function() character:BreakJoints() end) return true end
	return AutoDead.killHumanoid(h)
end

local respawnRequested = false
local respawnDebounce = 0
local function fireRespawnRemotes()
	-- Bypass game anticheat / 5s cooldown: spam every possible respawn path client can trigger
	pcall(function()
		for _,v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
			if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
				local n = v.Name:lower()
				if n:find("respawn") or n:find("loadchar") or n:find("spawn") or n:find("reset") or n:find("revive") or n:find("respaw") then
					pcall(function() if v:IsA("RemoteEvent") then v:FireServer() else v:InvokeServer() end end)
				end
			end
		end
	end)
	pcall(function()
		for _,v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
			if v:IsA("RemoteEvent") and v.Parent and v.Parent.Name:lower():find("remote") then
				-- second pass: try generic remotes that accept "Respawn" arg (common bypass)
				pcall(function() v:FireServer("Respawn") end)
				pcall(function() v:FireServer("LoadCharacter") end)
				pcall(function() v:FireServer("Reset") end)
			end
		end
	end)
	-- Roblox core reset signal (some games listen to this)
	pcall(function() game:GetService("StarterGui"):SetCore("DevEnableagd", true) end)
end
local function requestInstantRespawn()
	if Settings.Mode ~= "Blatant" then return end
	-- Slower debounce so back-to-back respawns can't happen faster than ~0.3s
	if os.clock() - respawnDebounce < 0.3 then return end
	respawnDebounce = os.clock()
	if respawnRequested then return end
	respawnRequested = true
	task.spawn(function()
		local start = os.clock()
		local oldChar = player.Character
		-- Spam until new alive character appears or 6s timeout (no cooldown wait)
		while Settings.Mode == "Blatant" and os.clock() - start < 6 do
			local cur = player.Character
			local hum = cur and cur:FindFirstChildOfClass("Humanoid")
			if cur and cur ~= oldChar and hum and hum.Health > 0 and cur:FindFirstChild("HumanoidRootPart") then break end
			-- human-like gap instead of machine-gun spam
			task.wait(0.18)
			fireRespawnRemotes()
			task.wait(0.12)
		end
		respawnRequested = false
	end)
end
player.CharacterAdded:Connect(function(character)
	respawnRequested = false
	-- instant hook no delay
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then humanoid.Died:Connect(function() if Settings.Mode == "Blatant" then requestInstantRespawn() end end) end
end)
player.CharacterRemoving:Connect(function(character) if Settings.Mode ~= "Blatant" then return end requestInstantRespawn() end)
if player.Character then local hum = player.Character:FindFirstChildOfClass("Humanoid") if hum then hum.Died:Connect(function() if Settings.Mode == "Blatant" then requestInstantRespawn() end end) end end
-- Also catch Health->0 instantly without waiting for Died signal (anticheat bypass)
player:GetPropertyChangedSignal("Character"):Connect(function() if Settings.Mode == "Blatant" and player.Character == nil then requestInstantRespawn() end end)
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
		if character and character ~= oldCharacter and getRoot(character) then local humanoid = getHumanoid(character) if humanoid and humanoid.Health > 0 then if Settings.Mode ~= "Blatant" and Settings.CharacterReadyDelay > 0 then task.wait(Settings.CharacterReadyDelay) end return character end end
		task.wait(Settings.Mode == "Blatant" and 0.03 or Settings.CheckInterval)
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
	local startTime = os.clock()
	while os.clock() - startTime < Settings.RespawnTimeout do
		if isAccountReady(previousUserId) then return true end
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
	character:PivotTo(targetCFrame)
	task.wait(0.15) -- let replication catch up before we measure/return
	local newRoot = getRoot(character) if not newRoot then return false end
	local distance = (newRoot.Position - targetCFrame.Position).Magnitude
	if distance > 10 then warn(string.format("[%s] Teleport verification failed. Distance: %.2f", player.Name, distance)) return false end
	return true
end
local function selfKill(character: Model): boolean
	local humanoid = getHumanoid(character)
	if not humanoid then warn(string.format("[%s] Humanoid not found.", player.Name)) return false end
	if humanoid.Health <= 0 then return false end
	if Settings.Mode == "Blatant" then
		return AutoDead.killHumanoid(humanoid)
	end
	humanoid.Health = 0 return true
end
local function performDrop(): boolean
	local character = waitForCharacter() if not character then return false end
	local characterToKill = character
	if not getClient() then return false end
	local teleported = teleportToClient(characterToKill) if not teleported then warn(string.format("[%s] Teleport failed.", player.Name)) return false end
	-- small gap so teleport and death don't land on the same frame (anticheat)
	task.wait(0.35)
	task.wait(Settings.KillDelay)
	if player.Character ~= characterToKill then warn(string.format("[%s] Character changed before kill.", player.Name)) return false end
	local killed = selfKill(characterToKill) if not killed then return false end
	local newCharacter = waitForNewCharacter(characterToKill) if not newCharacter then return false end
	return true
end

-- == Startup banner ==
print("========================================")
print("       SEQUENTIAL AUTO DROP")
print("========================================")
print(string.format("Account: %s (UserId: %d)", player.Name, player.UserId))
print(string.format("Account Order: %d / %d", myAccountIndex, Settings.AccountCount))
print(string.format("Client UserId: %d", Settings.ClientUserId))
print(string.format("Mode: %s", Settings.Mode))
print(string.format("Drop Per Death: %d", DropPerDeath))
print(string.format("Deaths Needed (per account): %d", deathsNeeded))
print(string.format("Total Resets (all accounts): %d", totalDrops))
print(string.format("Projected Total Drop: %d / %d", projectedTotal, Settings.TargetDrop))
print("----------------------------------------")
print(string.format("Estimated per-drop time: %.2fs", estimatedPerDrop))
print(string.format("Estimated total time: %s", formatTime(estimatedTotalSeconds)))
print("========================================")

local initialCharacter = waitForCharacter() if not initialCharacter then return end
local deathsCompleted = 0
while deathsCompleted < deathsNeeded do
	local previousReady = waitForPreviousAccount()
	if not previousReady then warn(string.format("[%s] Could not synchronize with previous account.", player.Name)) task.wait(Settings.CheckInterval) continue end
	local character = waitForCharacter() if not character then task.wait(Settings.CheckInterval) continue end
	local success = performDrop()
	if not success then warn(string.format("[%s] Drop failed. Retrying same drop.", player.Name)) task.wait(Settings.CheckInterval) continue end
	deathsCompleted += 1

	-- Progress print every 10 resets (or on final reset)
	if deathsCompleted % 10 == 0 or deathsCompleted >= deathsNeeded then
		local globalDone = ((myAccountIndex :: number) - 1) * deathsNeeded + deathsCompleted
		local globalRemaining = totalDrops - globalDone
		local dropRemaining = Settings.TargetDrop - (globalDone * DropPerDeath)
		print(string.format("[%s] Progress: %d/%d resets (global) | %d resets remaining | %d drop remaining",
			player.Name, globalDone, totalDrops, globalRemaining, math.max(dropRemaining, 0)))
	end

	task.wait(0.25) -- breathe between drops
end

print("========================================")
print("         AUTO DROP COMPLETE")
print("========================================")
print(string.format("Account: %s", player.Name))
print(string.format("Deaths completed (this account): %d / %d", deathsCompleted, deathsNeeded))
print(string.format("Combined Drop: %d / %d", deathsCompleted * Settings.AccountCount * DropPerDeath, Settings.TargetDrop))
