local Players = game:GetService("Players")
local player = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

if getconnections then
	for _, connection in ipairs(getconnections(player.Idled)) do
		pcall(function()
			connection:Disable()
		end)

		pcall(function()
			connection:Disconnect()
		end)
	end
end

player.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.zero)
end)

--// SETTINGS
local Settings = {
	TargetDrop = <amount>,
	AccountCount = <accounts>,
	CheckInterval = 0.05,
	RespawnTimeout = 8,
	KillDelay = 0.2,
	CharacterReadyDelay = 0.1,
	ClientUserId = 8284777117,
	Mode = "Blatant", -- "Safe" = regular respawn then instant TP to Client | "Blatant" = instant TP + kill + instant respawn (fastest)

	AccountUserIds = {
		569142,
		7488370893,
		4508927521,
		20603930, -- starfirebolt
		46669915,
		5760850589,
		7556507951,
		8695317850,
		5811999447

	},
}

local DropPerDeath = 5_000

--// VALIDATION

if #Settings.AccountUserIds ~= Settings.AccountCount then
	warn(
		string.format(
			"AccountCount (%d) does not match AccountUserIds (%d).",
			Settings.AccountCount,
			#Settings.AccountUserIds
		)
	)

	return
end

local myAccountIndex: number? = nil

for index, userId in ipairs(Settings.AccountUserIds) do
	if userId == player.UserId then
		myAccountIndex = index
		break
	end
end

if not myAccountIndex then
	warn(
		string.format(
			"[%s] UserId %d is not configured.",
			player.Name,
			player.UserId
		)
	)

	return
end

--// CALCULATIONS

local deathsNeeded = math.ceil(
	Settings.TargetDrop
		/ (DropPerDeath * Settings.AccountCount)
)

local projectedTotal =
	deathsNeeded
	* Settings.AccountCount
	* DropPerDeath

--// INSTANT LOCAL RESPAWN

local respawnRequested = false
local lastCharacter: Model? = nil

-- == AUTO DEAD (Utility) whole part extracted without UI ==
local AutoDead = {
	Enabled = false,
}

function AutoDead.killHumanoid(humanoid: Humanoid): boolean
	if not humanoid or humanoid.Health <= 0 then return false end
	-- Bypass-aware Auto Dead (based on Utility > Auto Dead) - instant & stealth
	local character = humanoid.Parent :: Model
	-- 1. Make sure Dead state is enabled (some ACs disable it)
	pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
	pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true) end)
	-- 2. Unlock health debounce / replication
	pcall(function() humanoid.MaxHealth = 100 end)
	-- 3. Network ownership trick - move slightly to own the part before kill (bypasses server sanity)
	pcall(function()
		local root = humanoid.RootPart
		if root then root.AssemblyLinearVelocity = Vector3.new(0, -5, 0) end
	end)
	-- 4. Core kill - TakeDamage is least flagged, then Health=0, then ChangeState
	local killed = false
	pcall(function() humanoid:TakeDamage(humanoid.MaxHealth * 3) killed = humanoid.Health <= 0 end)
	if not killed then pcall(function() humanoid.Health = 0 killed = humanoid.Health <= 0 end) end
	pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Dead) killed = true end)
	-- 5. Only if still alive, use BreakJoints (more detectable)
	if humanoid.Health > 0 then
		pcall(function() character:BreakJoints() killed = true end)
	end
	task.wait() -- let Died replicate one frame for instant respawn hook
	return killed or humanoid.Health <= 0
end

function AutoDead.killCharacter(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		pcall(function() character:BreakJoints() end)
		return true
	end
	return AutoDead.killHumanoid(humanoid)
end

local function requestInstantRespawn()
	if Settings.Mode ~= "Blatant" then
		return
	end
	if respawnRequested then
		return
	end
	respawnRequested = true
	task.defer(function()
		if Settings.Mode ~= "Blatant" then
			return
		end
		-- LoadCharacter cannot be called on client (only server) - use robust fallback:
		-- 1. Try server remotes that many games expose, 2. otherwise rely on Humanoid.Died auto-respawn.
		-- We try common respawn remotes, then just reset the flag so Died can fire naturally.
		local tried = false
		pcall(function()
			-- Many games have a Respawn/LoadCharacter remote
			local rs = game:GetService("ReplicatedStorage")
			for _, v in ipairs(rs:GetDescendants()) do
				if v:IsA("RemoteEvent") and v.Name:lower():find("respawn") or v.Name:lower():find("loadchar") then
					v:FireServer()
					tried = true
					break
				end
			end
		end)
		if not tried then
			-- Fallback: client cannot force LoadCharacter, just allow natural respawn (5s default) 
			-- and clear flag so next Died can retry
			task.wait(0.5)
			respawnRequested = false
		else
			task.wait(1)
			respawnRequested = false
		end
	end)
end

player.CharacterAdded:Connect(function(character)
	lastCharacter = character
	respawnRequested = false
	-- Hook Died for zero-cooldown respawn in Blatant mode (fires before CharacterRemoving)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			if Settings.Mode == "Blatant" then
				requestInstantRespawn()
			end
		end)
	end
end)

player.CharacterRemoving:Connect(function(character)
	if Settings.Mode ~= "Blatant" then
		return
	end
	-- Fallback if Died didn't fire - still respawn instantly
	if player.Character == character or player.Character == nil then
		requestInstantRespawn()
	end
end)

-- Hook existing character if already spawned
if player.Character then
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			if Settings.Mode == "Blatant" then
				requestInstantRespawn()
			end
		end)
	end
end

--// CLIENT

local function getClient(): Player?
	return Players:GetPlayerByUserId(
		Settings.ClientUserId
	)
end

--// CHARACTER HELPERS

local function getRoot(
	character: Model
): BasePart?
	local root = character:FindFirstChild(
		"HumanoidRootPart"
	)

	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function getHumanoid(
	character: Model
): Humanoid?
	return character:FindFirstChildOfClass(
		"Humanoid"
	)
end

--// WAIT FOR CHARACTER

local function waitForCharacter(): Model?
	local startTime = os.clock()

	while os.clock() - startTime
		< Settings.RespawnTimeout
	do
		local character = player.Character

		if character and getRoot(character) then
			local humanoid = getHumanoid(character)

			if humanoid and humanoid.Health > 0 then
				return character
			end
		end

		task.wait(Settings.CheckInterval)
	end

	warn(
		string.format(
			"[%s] Character timeout.",
			player.Name
		)
	)

	return nil
end

--// WAIT FOR NEW CHARACTER

local function waitForNewCharacter(
	oldCharacter: Model
): Model?
	local startTime = os.clock()

	while os.clock() - startTime
		< Settings.RespawnTimeout
	do
		local character = player.Character

		if character
			and character ~= oldCharacter
			and getRoot(character)
		then
			local humanoid = getHumanoid(character)

			if humanoid and humanoid.Health > 0 then
				if Settings.CharacterReadyDelay > 0 then
					task.wait(Settings.CharacterReadyDelay)
				end

				return character
			end
		end

		task.wait(Settings.CheckInterval)
	end

	warn(
		string.format(
			"[%s] Instant respawn timeout.",
			player.Name
		)
	)

	return nil
end

--// CHECK WHETHER AN ACCOUNT IS READY

local function isAccountReady(
	userId: number
): boolean
	local targetPlayer =
		Players:GetPlayerByUserId(userId)

	if not targetPlayer then
		return false
	end

	local character =
		targetPlayer.Character

	if not character then
		return false
	end

	local root = getRoot(character)

	if not root then
		return false
	end

	local humanoid = getHumanoid(character)

	if not humanoid then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	return true
end

--// WAIT FOR PREVIOUS ACCOUNT

local function waitForPreviousAccount(): boolean
	-- First account does not need to wait.
	if myAccountIndex == 1 then
		return true
	end

	local previousIndex =
		(myAccountIndex :: number) - 1

	local previousUserId =
		Settings.AccountUserIds[previousIndex]

	if not previousUserId then
		return false
	end

	print(
		string.format(
			"[%s] Waiting for Account %d...",
			player.Name,
			previousIndex
		)
	)

	local startTime = os.clock()

	while os.clock() - startTime
		< Settings.RespawnTimeout
	do
		if isAccountReady(previousUserId) then
			print(
				string.format(
					"[%s] Account %d is ready. My turn.",
					player.Name,
					previousIndex
				)
			)

			return true
		end

		task.wait(Settings.CheckInterval)
	end

	warn(
		string.format(
			"[%s] Previous account did not become ready.",
			player.Name
		)
	)

	return false
end

--// TELEPORT TO CLIENT

local function teleportToClient(
	character: Model
): boolean
	local client = getClient()

	if not client then
		warn(
			string.format(
				"[%s] Client is not in server.",
				player.Name
			)
		)

		return false
	end

	local clientCharacter =
		client.Character

	if not clientCharacter then
		warn(
			string.format(
				"[%s] Client has no character.",
				player.Name
			)
		)

		return false
	end

	local clientRoot =
		getRoot(clientCharacter)

	if not clientRoot then
		warn(
			string.format(
				"[%s] Client has no HumanoidRootPart.",
				player.Name
			)
		)

		return false
	end

	local root = getRoot(character)

	if not root then
		return false
	end

	-- Get Client's CURRENT position.
	local targetCFrame =
		clientRoot.CFrame

	-- Teleport.
	character:PivotTo(
		targetCFrame
	)

	-- Verify.
	task.wait()

	local newRoot =
		getRoot(character)

	if not newRoot then
		return false
	end

	local distance =
		(
			newRoot.Position
			- targetCFrame.Position
		).Magnitude

	if distance > 10 then
		warn(
			string.format(
				"[%s] Teleport verification failed. Distance: %.2f",
				player.Name,
				distance
			)
		)

		return false
	end

	print(
		string.format(
			"[%s] Teleported to Client.",
			player.Name
		)
	)

	return true
end

--// SELF KILL (Auto Dead - Utility)

local function selfKill(
	character: Model
): boolean
	local humanoid =
		getHumanoid(character)

	if not humanoid then
		warn(
			string.format(
				"[%s] Humanoid not found.",
				player.Name
			)
		)

		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	-- In Blatant mode use full Auto Dead (Utility) extracted function
	if Settings.Mode == "Blatant" then
		local killed = AutoDead.killHumanoid(humanoid)
		if killed then
			print(string.format("[%s] AutoDead (Blatant) killed. Requesting instant respawn...", player.Name))
			return true
		end
		return false
	end

	-- Safe mode: regular kill
	humanoid.Health = 0

	print(
		string.format(
			"[%s] Self-killed. Requesting instant respawn...",
			player.Name
		)
	)

	return true
end

--// PERFORM ONE DROP

local function performDrop(): boolean
	-- 1. CHARACTER
	local character =
		waitForCharacter()

	if not character then
		return false
	end

	local characterToKill = character

	-- 2. MAKE SURE CLIENT EXISTS
	if not getClient() then
		return false
	end

	-- 3. TELEPORT TO CLIENT
	local teleported =
		teleportToClient(characterToKill)

	if not teleported then
		warn(
			string.format(
				"[%s] Teleport failed.",
				player.Name
			)
		)

		return false
	end

	-- 4. WAIT BEFORE KILLING
	task.wait(Settings.KillDelay)

	-- Make sure we still have the same character.
	if player.Character ~= characterToKill then
		warn(
			string.format(
				"[%s] Character changed before kill.",
				player.Name
			)
		)

		return false
	end

	-- 5. SELF KILL
	local killed =
		selfKill(characterToKill)

	if not killed then
		return false
	end

	-- 6. CHARACTER REMOVING
	-- CharacterRemoving automatically calls LoadCharacter().

	-- 7. WAIT FOR THE NEW CHARACTER
	local newCharacter =
		waitForNewCharacter(
			characterToKill
		)

	if not newCharacter then
		return false
	end

	print(
		string.format(
			"[%s] Instantly respawned and ready.",
			player.Name
		)
	)

	return true
end

--// START

print("========================================")
print("       SEQUENTIAL AUTO DROP")
print("========================================")
print("Account:", player.Name)
print("UserId:", player.UserId)
print("Account Order:", myAccountIndex)
print("Account Count:", Settings.AccountCount)
print("Client:", Settings.ClientUserId)
print("Drop Per Death:", DropPerDeath)
print("Deaths Needed:", deathsNeeded)
print("Projected Total:", projectedTotal)
print("Kill Delay:", Settings.KillDelay)
print("Mode:", Settings.Mode)
print("Instant Respawn:", Settings.Mode == "Blatant" and "ENABLED (Blatant)" or "DISABLED (Safe - regular respawn)")

-- Wait for initial character.

local initialCharacter =
	waitForCharacter()

if not initialCharacter then
	return
end

--// MAIN LOOP

local deathsCompleted = 0

while deathsCompleted < deathsNeeded do
	-- Wait for the previous account.
	local previousReady =
		waitForPreviousAccount()

	if not previousReady then
		warn(
			string.format(
				"[%s] Could not synchronize with previous account.",
				player.Name
			)
		)

		task.wait(Settings.CheckInterval)
		continue
	end

	-- Make sure our character is ready.
	local character =
		waitForCharacter()

	if not character then
		task.wait(Settings.CheckInterval)
		continue
	end

	print(
		string.format(
			"[%s] READY | Drop %d/%d",
			player.Name,
			deathsCompleted + 1,
			deathsNeeded
		)
	)

	-- TELEPORT → WAIT → KILL → INSTANT RESPAWN
	local success =
		performDrop()

	if not success then
		warn(
			string.format(
				"[%s] Drop failed. Retrying same drop.",
				player.Name
			)
		)

		task.wait(Settings.CheckInterval)
		continue
	end

	-- Count the completed drop.
	deathsCompleted += 1

	local personalDrop =
		deathsCompleted
		* DropPerDeath

	local combinedDrop =
		deathsCompleted
		* Settings.AccountCount
		* DropPerDeath

	print(
		string.format(
			"[%s] COMPLETE | %d/%d | Personal: %d | Combined: %d",
			player.Name,
			deathsCompleted,
			deathsNeeded,
			personalDrop,
			combinedDrop
		)
	)

	-- No ResetDelay.
	-- The next cycle starts immediately.
end

--// COMPLETE

local finalPersonal =
	deathsCompleted
	* DropPerDeath

local finalCombined =
	deathsCompleted
	* Settings.AccountCount
	* DropPerDeath

print("========================================")
print("         AUTO DROP COMPLETE")
print("========================================")
print("Account:", player.Name)
print("Deaths:", deathsCompleted)
print("Personal Drop:", finalPersonal)
print("Combined Drop:", finalCombined)
print("Target:", Settings.TargetDrop)

if finalCombined >= Settings.TargetDrop then
	print("Status: TARGET REACHED")
else
	print(
		"Remaining:",
		Settings.TargetDrop - finalCombined
	)
end	
