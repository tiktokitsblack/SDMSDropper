--!strict
-- Dropper - reads Settings from loader getgenv (no hardcoded Settings here)
local Settings = (getgenv and rawget(getgenv(), "Settings") or rawget(_G, "Settings")) or error("Settings not found - loader must set Settings before HttpGet")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
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
local totalDrops = deathsNeeded * Settings.AccountCount

local HOST_USER_ID = Settings.HostUserId
local isHost = HOST_USER_ID ~= nil and HOST_USER_ID == player.UserId

-- ============================================================
-- Helpers
-- ============================================================
local function comma(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if s:sub(1, 1) == "-" then sign = "-" s = s:sub(2) end
	local result = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if result:sub(1, 1) == "," then result = result:sub(2) end
	return sign .. result
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	local sec = s % 60
	if h > 0 then
		return string.format("%dh %dm %ds", h, m, sec)
	elseif m > 0 then
		return string.format("%dm %ds", m, sec)
	end
	return string.format("%ds", sec)
end

local function makeDraggable(frame: GuiObject)
	local dragging = false
	local dragStart: Vector3? = nil
	local startPos: UDim2? = nil
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)
	frame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and dragStart and startPos then
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - dragStart
				frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end
	end)
end

-- ============================================================
-- Timing constants (used for the initial estimate)
-- ============================================================
local KILL_DELAY = Settings.KillDelay or 0
local TELEPORT_SETTLE = 0.15
local POST_TELEPORT = 0.35
local KILL_ROUTINE = 0.20
local RESPAWN_ESTIMATE = 0.80
local LOOP_BREATHE = 0.25
local estimatedPerDrop = TELEPORT_SETTLE + POST_TELEPORT + KILL_DELAY + KILL_ROUTINE + RESPAWN_ESTIMATE + LOOP_BREATHE

-- ============================================================
-- Live status (per-client)
-- ============================================================
local Status = {
	phase = "Starting",
	resetsDone = 0,
	resetsTotal = deathsNeeded,
	startTime = os.clock(),
	averagePerDrop = nil :: number?,
}

-- ============================================================
-- Local UI (per-alt)
-- ============================================================
local localSetters: {[string]: (string) -> ()}? = nil
local function createLocalUI()
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "DropperLocal"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.new(0, 300, 0, 210)
	frame.Position = UDim2.new(0, 20, 0, 20)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.ClipsDescendants = true
	frame.Parent = ScreenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 120, 200)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(35, 80, 150)
	title.BorderSizePixel = 0
	title.Text = "  DROPPER — " .. player.Name .. "  (#" .. tostring(myAccountIndex) .. ")"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.Parent = frame

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -20, 1, -40)
	content.Position = UDim2.new(0, 10, 0, 34)
	content.BackgroundTransparency = 1
	content.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	local setters: {[string]: (string) -> ()} = {}
	local function addRow(key: string, prefix: string, order: number)
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 20)
		row.BackgroundTransparency = 1
		row.Text = prefix .. ": —"
		row.TextColor3 = Color3.fromRGB(220, 220, 230)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = Enum.Font.Code
		row.TextSize = 13
		row.LayoutOrder = order
		row.Parent = content
		setters[key] = function(value: string) row.Text = prefix .. ": " .. value end
	end

	addRow("phase", "Phase", 1)
	addRow("resets", "Resets", 2)
	addRow("dropOwn", "Drop (own)", 3)
	addRow("dropGlobal", "Drop (total)", 4)
	addRow("elapsed", "Elapsed", 5)
	addRow("eta", "ETA", 6)

	makeDraggable(frame)
	localSetters = setters
end

-- ============================================================
-- Host admin panel (optional)
-- ============================================================
local hostCells: {[number]: {[string]: TextLabel}}? = nil
local hostStartTime = os.clock()
local HostObs: {[number]: {deaths: number, alive: boolean, seen: boolean}} = {}

local function setupHostObservation()
	for _, uid in ipairs(Settings.AccountUserIds) do
		HostObs[uid] = { deaths = 0, alive = false, seen = false }
	end

	local function hookCharacter(userId: number, char: Model)
		local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
		if not hum then return end
		local obs = HostObs[userId]
		if not obs then return end
		obs.alive = hum.Health > 0
		obs.seen = true
		hum.Died:Connect(function()
			if HostObs[userId] then
				HostObs[userId].deaths += 1
				HostObs[userId].alive = false
			end
		end)
		hum.HealthChanged:Connect(function(h)
			if HostObs[userId] and h > 0 then
				HostObs[userId].alive = true
			end
		end)
	end

	local function observe(userId: number)
		local p = Players:GetPlayerByUserId(userId)
		if not p then return end
		if p.Character then hookCharacter(userId, p.Character) end
		p.CharacterAdded:Connect(function(c) hookCharacter(userId, c) end)
	end

	for _, uid in ipairs(Settings.AccountUserIds) do observe(uid) end

	Players.PlayerAdded:Connect(function(p)
		if HostObs[p.UserId] then observe(p.UserId) end
	end)
end

local function createHostUI()
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "DropperHost"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.new(0, 620, 0, 240)
	frame.Position = UDim2.new(0.5, -310, 0, 20)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.ClipsDescendants = true
	frame.Parent = ScreenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 60, 60)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
	title.BorderSizePixel = 0
	title.Text = "  DROPPER — HOST ADMIN PANEL"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.Parent = frame

	local COLS = {
		{key = "idx",    label = "#",       x = 0,   w = 34},
		{key = "name",   label = "Account", x = 34,  w = 130},
		{key = "status", label = "Status",  x = 164, w = 90},
		{key = "resets", label = "Resets",  x = 254, w = 110},
		{key = "drop",   label = "Drop",    x = 364, w = 130},
		{key = "eta",    label = "ETA",     x = 494, w = 120},
	}

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, -20, 0, 22)
	header.Position = UDim2.new(0, 10, 0, 34)
	header.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	header.BorderSizePixel = 0
	header.Parent = frame

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 4)
	hCorner.Parent = header

	for _, col in ipairs(COLS) do
		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, col.x + 6, 0, 0)
		lbl.Size = UDim2.new(0, col.w - 6, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = col.label
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.fromRGB(180, 200, 220)
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 13
		lbl.Parent = header
	end

	local rowsFrame = Instance.new("Frame")
	rowsFrame.Size = UDim2.new(1, -20, 1, -64)
	rowsFrame.Position = UDim2.new(0, 10, 0, 60)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.Parent = frame

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.Padding = UDim.new(0, 2)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = rowsFrame

	local cells: {[number]: {[string]: TextLabel}} = {}

	for i, uid in ipairs(Settings.AccountUserIds) do
		local rowFrame = Instance.new("Frame")
		rowFrame.Size = UDim2.new(1, 0, 0, 22)
		rowFrame.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(24, 24, 32) or Color3.fromRGB(20, 20, 26)
		rowFrame.BorderSizePixel = 0
		rowFrame.LayoutOrder = i
		rowFrame.Parent = rowsFrame

		cells[uid] = {}
		for _, col in ipairs(COLS) do
			local lbl = Instance.new("TextLabel")
			lbl.Position = UDim2.new(0, col.x + 6, 0, 0)
			lbl.Size = UDim2.new(0, col.w - 6, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = "—"
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
			lbl.Font = Enum.Font.Code
			lbl.TextSize = 13
			lbl.Parent = rowFrame
			cells[uid][col.key] = lbl
		end
	end

	makeDraggable(frame)
	hostCells = cells
end

-- ============================================================
-- UI update loop
-- ============================================================
local function updateLocalUI()
	if not localSetters then return end
	local s = Status

	local elapsed = os.clock() - s.startTime
	local remaining = s.resetsTotal - s.resetsDone
	local avg = s.averagePerDrop or estimatedPerDrop
	local eta = remaining * avg

	local dropOwn = s.resetsDone * DropPerDeath
	local dropOwnTotal = s.resetsTotal * DropPerDeath
	local dropGlobal = s.resetsDone * Settings.AccountCount * DropPerDeath
	local dropGlobalTotal = Settings.TargetDrop

	localSetters.phase(s.phase)
	localSetters.resets(string.format("%s / %s", comma(s.resetsDone), comma(s.resetsTotal)))
	localSetters.dropOwn(string.format("%s / %s", comma(dropOwn), comma(dropOwnTotal)))
	localSetters.dropGlobal(string.format("%s / %s", comma(dropGlobal), comma(dropGlobalTotal)))
	localSetters.elapsed(formatTime(elapsed))
	localSetters.eta(formatTime(eta))
end

local function updateHostUI()
	if not hostCells then return end
	local elapsed = os.clock() - hostStartTime

	for _, uid in ipairs(Settings.AccountUserIds) do
		local cells = hostCells[uid]
		if not cells then continue end
		local obs = HostObs[uid]
		local p = Players:GetPlayerByUserId(uid)

		cells.idx.Text = tostring(({table.unpack(Settings.AccountUserIds)})[1] and 0 or 0) -- placeholder, set below
		-- Find index
		for i, v in ipairs(Settings.AccountUserIds) do
			if v == uid then cells.idx.Text = tostring(i) break end
		end

		if not p then
			cells.name.Text = "userid " .. tostring(uid)
			cells.status.Text = "Not in server"
			cells.status.TextColor3 = Color3.fromRGB(150, 150, 150)
			cells.resets.Text = "—"
			cells.drop.Text = "—"
			cells.eta.Text = "—"
		else
			cells.name.Text = p.Name
			if obs.alive then
				cells.status.Text = "Alive"
				cells.status.TextColor3 = Color3.fromRGB(120, 220, 140)
			else
				cells.status.Text = "Dead"
				cells.status.TextColor3 = Color3.fromRGB(230, 120, 120)
			end

			local d = obs.deaths
			cells.resets.Text = string.format("%s / %s", comma(d), comma(deathsNeeded))
			cells.drop.Text = string.format("%s / %s", comma(d * Settings.AccountCount * DropPerDeath), comma(Settings.TargetDrop))

			-- ETA based on observed average
			local avgPerDeath = (d > 0) and (elapsed / d) or estimatedPerDrop
			local remaining = deathsNeeded - d
			local eta = remaining * avgPerDeath
			cells.eta.Text = formatTime(eta)
		end
	end
end

-- ============================================================
-- Startup banner
-- ============================================================
print("========================================")
print("       SEQUENTIAL AUTO DROP")
print("========================================")
print(string.format("Account: %s (UserId: %d)", player.Name, player.UserId))
print(string.format("Account Order: %d / %d", myAccountIndex, Settings.AccountCount))
print(string.format("Client UserId: %d", Settings.ClientUserId))
print(string.format("Host UserId: %s", HOST_USER_ID and tostring(HOST_USER_ID) or "(none)"))
print(string.format("Mode: %s", Settings.Mode))
print(string.format("Drop Per Death: %s", comma(DropPerDeath)))
print(string.format("Deaths Needed (per account): %s", comma(deathsNeeded)))
print(string.format("Total Resets (all accounts): %s", comma(totalDrops)))
print(string.format("Projected Total Drop: %s / %s", comma(projectedTotal), comma(Settings.TargetDrop)))
print("----------------------------------------")
print(string.format("Estimated per-drop time: %.2fs", estimatedPerDrop))
print(string.format("Estimated total time: %s", formatTime(estimatedPerDrop * totalDrops)))
print("========================================")

-- ============================================================
-- AUTO DEAD
-- ============================================================
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

-- ============================================================
-- Respawn logic
-- ============================================================
local respawnRequested = false
local respawnDebounce = 0
local function fireRespawnRemotes()
	pcall(function()
		for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
			if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
				local n = v.Name:lower()
				if n:find("respawn") or n:find("loadchar") or n:find("spawn") or n:find("reset") or n:find("revive") or n:find("respaw") then
					pcall(function() if v:IsA("RemoteEvent") then v:FireServer() else v:InvokeServer() end end)
				end
			end
		end
	end)
	pcall(function()
		for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
			if v:IsA("RemoteEvent") and v.Parent and v.Parent.Name:lower():find("remote") then
				pcall(function() v:FireServer("Respawn") end)
				pcall(function() v:FireServer("LoadCharacter") end)
				pcall(function() v:FireServer("Reset") end)
			end
		end
	end)
	pcall(function() game:GetService("StarterGui"):SetCore("DevEnableagd", true) end)
end
local function requestInstantRespawn()
	if Settings.Mode ~= "Blatant" then return end
	if os.clock() - respawnDebounce < 0.3 then return end
	respawnDebounce = os.clock()
	if respawnRequested then return end
	respawnRequested = true
	task.spawn(function()
		local start = os.clock()
		local oldChar = player.Character
		while Settings.Mode == "Blatant" and os.clock() - start < 6 do
			local cur = player.Character
			local hum = cur and cur:FindFirstChildOfClass("Humanoid")
			if cur and cur ~= oldChar and hum and hum.Health > 0 and cur:FindFirstChild("HumanoidRootPart") then break end
			task.wait(0.18)
			fireRespawnRemotes()
			task.wait(0.12)
		end
		respawnRequested = false
	end)
end
player.CharacterAdded:Connect(function(character)
	respawnRequested = false
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then humanoid.Died:Connect(function() if Settings.Mode == "Blatant" then requestInstantRespawn() end end) end
end)
player.CharacterRemoving:Connect(function(character) if Settings.Mode ~= "Blatant" then return end requestInstantRespawn() end)
if player.Character then local hum = player.Character:FindFirstChildOfClass("Humanoid") if hum then hum.Died:Connect(function() if Settings.Mode == "Blatant" then requestInstantRespawn() end end) end end
player:GetPropertyChangedSignal("Character"):Connect(function() if Settings.Mode == "Blatant" and player.Character == nil then requestInstantRespawn() end end)

-- ============================================================
-- Shared utility functions
-- ============================================================
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
		if character and getRoot(character) then
			local humanoid = getHumanoid(character)
			if humanoid and humanoid.Health > 0 then return character end
		end
		task.wait(Settings.CheckInterval)
	end
	warn(string.format("[%s] Character timeout.", player.Name)) return nil
end
local function waitForNewCharacter(oldCharacter: Model): Model?
	local startTime = os.clock()
	while os.clock() - startTime < Settings.RespawnTimeout do
		local character = player.Character
		if character and character ~= oldCharacter and getRoot(character) then
			local humanoid = getHumanoid(character)
			if humanoid and humanoid.Health > 0 then
				if Settings.Mode ~= "Blatant" and Settings.CharacterReadyDelay > 0 then task.wait(Settings.CharacterReadyDelay) end
				return character
			end
		end
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
	task.wait(0.15)
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
	Status.phase = "Waiting for character"
	local character = waitForCharacter() if not character then return false end
	local characterToKill = character
	if not getClient() then return false end
	Status.phase = "Teleporting"
	local teleported = teleportToClient(characterToKill) if not teleported then warn(string.format("[%s] Teleport failed.", player.Name)) return false end
	task.wait(0.35)
	task.wait(Settings.KillDelay)
	if player.Character ~= characterToKill then warn(string.format("[%s] Character changed before kill.", player.Name)) return false end
	Status.phase = "Killing"
	local killed = selfKill(characterToKill) if not killed then return false end
	Status.phase = "Respawning"
	local newCharacter = waitForNewCharacter(characterToKill) if not newCharacter then return false end
	return true
end

-- ============================================================
-- Create UIs and start UI update loop
-- ============================================================
createLocalUI()
if isHost then
	setupHostObservation()
	createHostUI()
end

task.spawn(function()
	while true do
		task.wait(0.25)
		pcall(updateLocalUI)
		if isHost then pcall(updateHostUI) end
	end
end)

-- ============================================================
-- Main loop
-- ============================================================
Status.phase = "Starting"
local initialCharacter = waitForCharacter() if not initialCharacter then return end

local deathsCompleted = 0
local runStartTime = os.clock()

while deathsCompleted < deathsNeeded do
	Status.phase = "Waiting for prev account"
	local previousReady = waitForPreviousAccount()
	if not previousReady then
		warn(string.format("[%s] Could not synchronize with previous account.", player.Name))
		task.wait(Settings.CheckInterval)
		continue
	end

	Status.phase = "Ready"
	local character = waitForCharacter()
	if not character then task.wait(Settings.CheckInterval) continue end

	Status.phase = "Dropping"
	local success = performDrop()
	if not success then
		warn(string.format("[%s] Drop failed. Retrying same drop.", player.Name))
		task.wait(Settings.CheckInterval)
		continue
	end

	deathsCompleted += 1
	Status.resetsDone = deathsCompleted
	local elapsed = os.clock() - runStartTime
	Status.averagePerDrop = elapsed / deathsCompleted

	Status.phase = "Complete"

	task.wait(LOOP_BREATHE)
end

Status.phase = "Done"
local finalElapsed = os.clock() - runStartTime
print("========================================")
print("         AUTO DROP COMPLETE")
print("========================================")
print(string.format("Account: %s", player.Name))
print(string.format("Deaths completed (this account): %s / %s", comma(deathsCompleted), comma(deathsNeeded)))
print(string.format("Combined Drop: %s / %s", comma(deathsCompleted * Settings.AccountCount * DropPerDeath), comma(Settings.TargetDrop)))
print(string.format("Total time: %s", formatTime(finalElapsed)))
