--!strict
-- Dropper - reads Settings from loader getgenv (no hardcoded Settings here)
local Settings = (getgenv and rawget(getgenv(), "Settings") or rawget(_G, "Settings")) or error("Settings not found - loader must set Settings before HttpGet")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
player.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.zero)
end)

local DropPerDeath = 5_000
if #Settings.AccountUserIds ~= Settings.AccountCount then warn(string.format("AccountCount (%d) != AccountUserIds (%d).", Settings.AccountCount, #Settings.AccountUserIds)) return end
local myAccountIndex: number? = nil
for index, userId in ipairs(Settings.AccountUserIds) do if userId == player.UserId then myAccountIndex = index break end end
if not myAccountIndex then warn(string.format("[%s] UserId %d is not configured.", player.Name, player.UserId)) return end
local deathsNeeded = math.ceil(Settings.TargetDrop / (DropPerDeath * Settings.AccountCount))
local projectedTotal = deathsNeeded * Settings.AccountCount * DropPerDeath

-- == AUTO DEAD (legitimate client-side self-kill, no destruction, no remotes) ==
local AutoDead = {}
function AutoDead.killHumanoid(humanoid: Humanoid): boolean
	if not humanoid then
		return false
	end
	if humanoid.Health <= 0 then
		return false
	end
	-- Fastest legitimate client death: server replicates Health <= 0 for
	-- characters the client owns. No BreakJoints / TakeDamage spam / Destroy.
	pcall(function()
		humanoid.Health = 0
	end)
	return humanoid.Health <= 0
end
function AutoDead.killCharacter(character: Model): boolean
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	if not foundHumanoid then
		return false
	end
	return AutoDead.killHumanoid(foundHumanoid)
end

-- == Event-driven respawn state machine (no polling, no remote scan) ==
-- Legitimate behavior: after Health = 0 the server respawns via its own
-- CharacterAutoLoads / RespawnTime flow. Client only observes CharacterAdded.
-- If the server imposes a cooldown we simply wait for it; never circumvent.
type CycleState = "Idle" | "Preparing" | "Killing" | "WaitingForRespawn" | "Ready"
local cycleState: CycleState = "Idle"
local characterGeneration: number = 0
local activeDiedConnection: RBXScriptConnection? = nil
local characterReadyEvent: BindableEvent = Instance.new("BindableEvent")

local function setCycleState(newState: CycleState)
	cycleState = newState
end

local function isCharacterAlive(character: Model?): boolean
	if not character then
		return false
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	return humanoid.Health > 0
end

local function hookHumanoidDied(character: Model, generation: number)
	if activeDiedConnection then
		activeDiedConnection:Disconnect()
		activeDiedConnection = nil
	end
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end
	-- If character was replaced while waiting, ignore stale hook.
	if generation ~= characterGeneration then
		return
	end
	activeDiedConnection = humanoid.Died:Connect(function()
		if generation ~= characterGeneration then
			return
		end
		if cycleState == "Killing" or cycleState == "Ready" or cycleState == "Preparing" then
			setCycleState("WaitingForRespawn")
		end
	end)
	-- Already dead before hook attached (ultra-fast replacement edge).
	if humanoid.Health <= 0 and generation == characterGeneration then
		if cycleState == "Killing" or cycleState == "Ready" or cycleState == "Preparing" then
			setCycleState("WaitingForRespawn")
		end
	end
end

local function onCharacterAdded(character: Model)
	characterGeneration += 1
	local generation = characterGeneration
	setCycleState("WaitingForRespawn")
	-- Immediate verification: Humanoid alive + HumanoidRootPart exists.
	-- No artificial multi-second wait; timeout below is fallback only.
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", Settings.RespawnTimeout) :: Humanoid?
		if generation ~= characterGeneration then
			return
		end
		if not humanoid then
			return
		end
		local rootPart = character:WaitForChild("HumanoidRootPart", Settings.RespawnTimeout) :: BasePart?
		if generation ~= characterGeneration then
			return
		end
		if not rootPart then
			return
		end
		if humanoid.Health <= 0 then
			return
		end
		setCycleState("Ready")
		characterReadyEvent:Fire(character)
	end)
	hookHumanoidDied(character, generation)
end

player.CharacterAdded:Connect(onCharacterAdded)
player.CharacterRemoving:Connect(function(_removedCharacter: Model)
	-- Duplicate-safe: only transition forward, never issue a respawn request.
	if cycleState == "Killing" or cycleState == "Ready" or cycleState == "Preparing" then
		setCycleState("WaitingForRespawn")
	end
end)
player:GetPropertyChangedSignal("Character"):Connect(function()
	if player.Character == nil then
		if cycleState == "Killing" or cycleState == "Ready" or cycleState == "Preparing" then
			setCycleState("WaitingForRespawn")
		end
	end
end)
if player.Character then
	task.spawn(function()
		onCharacterAdded(player.Character :: Model)
	end)
else
	setCycleState("WaitingForRespawn")
end

local function requestLegitimateRespawn()
	-- Intentionally empty: respawn is server-authoritative. We do not call
	-- LoadCharacter (server-only), scan ReplicatedStorage, or fire remotes.
	-- We just mark that we are waiting so duplicate Died events stay idempotent.
	if cycleState == "Ready" or cycleState == "Killing" or cycleState == "Preparing" then
		setCycleState("WaitingForRespawn")
	end
end
local function getClient(): Player? return Players:GetPlayerByUserId(Settings.ClientUserId) end
local function getRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end
local function getHumanoid(character: Model): Humanoid? return character:FindFirstChildOfClass("Humanoid") end
local function waitForCharacter(): Model?
	-- Fast path: already ready, return instantly with zero waits.
	local currentCharacter = player.Character
	if currentCharacter and isCharacterAlive(currentCharacter) then
		setCycleState("Ready")
		return currentCharacter
	end
	setCycleState("WaitingForRespawn")
	-- Event-driven wait: CharacterAdded verification fires characterReadyEvent
	-- the instant Humanoid + HumanoidRootPart are valid. Timeout only unblocks.
	local timeout = Settings.RespawnTimeout
	local startTime = os.clock()
	local finished = false
	task.delay(timeout, function()
		if finished then
			return
		end
		finished = true
		pcall(function()
			characterReadyEvent:Fire(nil :: any)
		end)
	end)
	while not finished and os.clock() - startTime < timeout + 0.5 do
		local latest = player.Character
		if latest and isCharacterAlive(latest) then
			finished = true
			setCycleState("Ready")
			return latest
		end
		local fired: any = characterReadyEvent.Event:Wait()
		if finished and fired == nil then
			break
		end
		if typeof(fired) == "Instance" and (fired :: Instance):IsA("Model") and isCharacterAlive(fired :: Model) then
			finished = true
			setCycleState("Ready")
			return fired :: Model
		end
	end
	finished = true
	warn(string.format("[%s] Character timeout.", player.Name))
	return nil
end
local function waitForNewCharacter(oldCharacter: Model): Model?
	-- If server already replaced the character (very fast respawn), return now.
	local currentCharacter = player.Character
	if currentCharacter and currentCharacter ~= oldCharacter and isCharacterAlive(currentCharacter) then
		if Settings.Mode ~= "Blatant" and Settings.CharacterReadyDelay > 0 then
			task.wait(Settings.CharacterReadyDelay)
		end
		setCycleState("Ready")
		return currentCharacter
	end
	setCycleState("WaitingForRespawn")
	local timeout = Settings.RespawnTimeout
	local startTime = os.clock()
	local finished = false
	task.delay(timeout, function()
		if finished then
			return
		end
		finished = true
		pcall(function()
			characterReadyEvent:Fire(nil :: any)
		end)
	end)
	while not finished and os.clock() - startTime < timeout + 0.5 do
		local latest = player.Character
		if latest and latest ~= oldCharacter and isCharacterAlive(latest) then
			finished = true
			if Settings.Mode ~= "Blatant" and Settings.CharacterReadyDelay > 0 then
				task.wait(Settings.CharacterReadyDelay)
			end
			setCycleState("Ready")
			return latest
		end
		-- Normal path resolves the instant CharacterAdded verification fires.
		local fired: any = characterReadyEvent.Event:Wait()
		if finished and fired == nil then
			break
		end
		if typeof(fired) == "Instance" and (fired :: Instance):IsA("Model") then
			local firedModel = fired :: Model
			if firedModel ~= oldCharacter and isCharacterAlive(firedModel) then
				finished = true
				if Settings.Mode ~= "Blatant" and Settings.CharacterReadyDelay > 0 then
					task.wait(Settings.CharacterReadyDelay)
				end
				setCycleState("Ready")
				return firedModel
			end
		end
	end
	finished = true
	warn(string.format("[%s] Instant respawn timeout.", player.Name))
	return nil
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
	-- No artificial yield: PivotTo applies instantly, verify immediately.
	character:PivotTo(targetCFrame)
	local newRoot = getRoot(character) if not newRoot then return false end
	local distance = (newRoot.Position - targetCFrame.Position).Magnitude
	if distance > 10 then warn(string.format("[%s] Teleport verification failed. Distance: %.2f", player.Name, distance)) return false end
	print(string.format("[%s] Teleported to Client.", player.Name)) return true
end
local function selfKill(character: Model): boolean
	if player.Character ~= character then
		return false
	end
	local humanoid = getHumanoid(character)
	if not humanoid then warn(string.format("[%s] Humanoid not found.", player.Name)) return false end
	if humanoid.Health <= 0 then return false end
	setCycleState("Killing")
	-- Single legitimate Health = 0 write, no spam, no destruction.
	local killed = AutoDead.killHumanoid(humanoid)
	if killed then
		print(string.format("[%s] Self-killed. Waiting for server respawn...", player.Name))
		requestLegitimateRespawn()
		return true
	end
	setCycleState("Ready")
	return false
end
local function performDrop(): boolean
	setCycleState("Preparing")
	local character = waitForCharacter() if not character then setCycleState("Idle") return false end
	local characterToKill = character
	if not getClient() then setCycleState("Ready") return false end
	local teleported = teleportToClient(characterToKill) if not teleported then warn(string.format("[%s] Teleport failed.", player.Name)) setCycleState("Ready") return false end
	-- Kill immediately when ready. Respect configured KillDelay only if > 0.
	if Settings.KillDelay > 0 then
		task.wait(Settings.KillDelay)
	end
	if player.Character ~= characterToKill then warn(string.format("[%s] Character changed before kill.", player.Name)) setCycleState("WaitingForRespawn") return false end
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
