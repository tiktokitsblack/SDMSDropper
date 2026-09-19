--!strict
-- Dropper - reads Settings from Loader (_G.Settings). Execution order
-- never kills the script: it waits for Settings instead of timing out,
-- and no alt ever idles silently (a boot panel always states why).
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

-- Always-visible boot panel so an idle alt states its reason on screen.
local function showBootPanel(titleText: string, bodyText: string)
	local guiParent: Instance? = nil
	pcall(function()
		guiParent = player:WaitForChild("PlayerGui", 30)
	end)
	if guiParent == nil then return end
	pcall(function()
		local old = (guiParent :: Instance):FindFirstChild("DropperBoot")
		if old then old:Destroy() end
	end)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DropperBoot"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(0, 340, 0, 130)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	frame.BorderSizePixel = 0
	frame.Active = true
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 8)
	frameCorner.Parent = frame
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
	title.BorderSizePixel = 0
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.Parent = frame
	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -20, 1, -36)
	body.Position = UDim2.new(0, 10, 0, 32)
	body.BackgroundTransparency = 1
	body.Text = bodyText
	body.TextColor3 = Color3.fromRGB(220, 220, 230)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Font = Enum.Font.Code
	body.TextSize = 13
	body.Parent = frame
	frame.Parent = screenGui
	screenGui.Parent = guiParent
end
local function hideBootPanel()
	pcall(function()
		local guiParent = player:FindFirstChildOfClass("PlayerGui")
		if guiParent then
			local old = (guiParent :: Instance):FindFirstChild("DropperBoot")
			if old then old:Destroy() end
		end
	end)
end
local function readSettings(): any
	local found: any = rawget(_G, "Settings")
	if found ~= nil then return found end
	pcall(function()
		local gg = (getgenv :: any)()
		if gg then found = rawget(gg, "Settings") end
	end)
	return found
end
local Settings: any = readSettings()
if Settings == nil then
	warn("[Dropper] No Settings yet - waiting for Loader (never times out).")
	showBootPanel("  DROPPER — WAITING", "Waiting for Settings.\nExecute Loader on this account.\nUserId: " .. tostring(player.UserId))
	while Settings == nil do
		task.wait(0.5)
		Settings = readSettings()
	end
	hideBootPanel()
	print("[Dropper] Settings received, booting.")
end

local DropPerDeath = 5_000
-- Use actual alt list size as source of truth so per-alt debug stays
-- like before (e.g. ~280 resets for 10M split across alts).
-- If Settings.AccountCount mismatches, auto-correct instead of dying.
local effectiveAccountCount = #Settings.AccountUserIds
if Settings.AccountCount ~= effectiveAccountCount then
	warn(string.format("AccountCount (%d) != AccountUserIds (%d). Using %d.", Settings.AccountCount, #Settings.AccountUserIds, effectiveAccountCount))
end
local HOST_USER_ID = Settings.HostUserId
local isHost = HOST_USER_ID ~= nil and HOST_USER_ID == player.UserId
local myAccountIndex: number? = nil
for index, userId in ipairs(Settings.AccountUserIds) do if userId == player.UserId then myAccountIndex = index break end end
local isAlt = myAccountIndex ~= nil
-- Host is NOT in the drop rotation, but must still get the full panel.
-- Only quit for accounts that are neither host nor alt.
if not isAlt and not isHost then
	warn(string.format("[%s] UserId %d is not configured in Loader AccountUserIds.", player.Name, player.UserId))
	showBootPanel("  DROPPER — NOT IN LIST", player.Name .. " (UserId " .. tostring(player.UserId) .. ") is not in Loader AccountUserIds and is not the Host. Add this UserId to Loader, then rejoin.")
	return
end
local deathsNeeded = math.ceil(Settings.TargetDrop / (DropPerDeath * effectiveAccountCount))
local projectedTotal = deathsNeeded * effectiveAccountCount * DropPerDeath
local totalDrops = deathsNeeded * effectiveAccountCount

-- Re-execute reset: new run id stops old background loops, old panels
-- are wiped so this run starts from zero.
local runId: number = 0
pcall(function()
	local g = _G :: any
	g.DropperRunId = ((g.DropperRunId :: any) or 0) + 1
	runId = g.DropperRunId :: number
end)
if runId == 0 then
	runId = os.clock()
end
pcall(function()
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if pg then
		local oldLocal = pg:FindFirstChild("DropperLocal")
		if oldLocal then oldLocal:Destroy() end
		local oldHost = pg:FindFirstChild("DropperHost")
		if oldHost then oldHost:Destroy() end
	end
end)

-- ============================================================
-- DropperControl: host pause/resume relay (alts actually listen).
-- Enabled=true -> dropping, Enabled=false -> paused, resume keeps
-- the same deathsCompleted on each alt (never reset).
-- Elapsed timers exclude paused time so ETA does not drift.
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local controlFolder: Instance? = nil
local controlEnabled: BoolValue? = nil
local controlToggle: RemoteEvent? = nil
pcall(function()
	controlFolder = ReplicatedStorage:WaitForChild("DropperControl", 5)
end)
if controlFolder then
	pcall(function()
		controlEnabled = (controlFolder :: Folder):WaitForChild("Enabled", 5) :: BoolValue
	end)
	pcall(function()
		controlToggle = (controlFolder :: Folder):WaitForChild("Toggle", 5) :: RemoteEvent
	end)
end
if not controlEnabled then
	warn("[DropperControl] No server relay found, pause runs local-only.")
	local fallback = Instance.new("BoolValue")
	fallback.Name = "EnabledFallback"
	fallback.Value = true
	controlEnabled = fallback
end
local droppingEnabled: boolean = true
pcall(function()
	if controlEnabled then droppingEnabled = (controlEnabled :: BoolValue).Value end
end)
local totalPausedTime: number = 0
local pauseStart: number? = nil
local function activeElapsedSince(startTime: number): number
	local now = os.clock()
	if pauseStart ~= nil then
		return (pauseStart :: number) - startTime - totalPausedTime
	end
	return now - startTime - totalPausedTime
end
-- Changed wiring + toggle + pause-wait are attached after Status and
-- updateLocalUI/updateHostUI exist (see CONTROL WIRING below).

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
	last = "",
	resetsDone = 0,
	resetsTotal = deathsNeeded,
	startTime = os.clock(),
	averagePerDrop = nil :: number?,
	finished = false,
	finishTime = nil :: number?,
	finishActive = nil :: number?,
}

-- ============================================================
-- Local UI (per-alt)
-- ============================================================
local localSetters: {[string]: (string) -> ()}? = nil
local function createLocalUI()
	local playerGui = player:WaitForChild("PlayerGui", 30)
	if not playerGui then warn("[Dropper] PlayerGui not found for alt UI.") return end
	local old = playerGui:FindFirstChild("DropperLocal")
	if old then old:Destroy() end
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "DropperLocal"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.new(0, 300, 0, 236)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
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
	title.Text = "  DROPPER — " .. player.Name .. "  (#" .. tostring(myAccountIndex or "?") .. ")"
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
	addRow("last", "Last", 7)

	makeDraggable(frame)
	localSetters = setters
end

-- ============================================================
-- Host admin panel (optional)
-- ============================================================
local hostCells: {[number]: {[string]: TextLabel}}? = nil
local hostTimeLabels: {[string]: TextLabel}? = nil
local pauseButton: TextButton? = nil
local hostStartTime = os.clock()
local hostFinished = false
local hostFinishTime: number? = nil
local hostFinishActive: number? = nil
local HostObs: {[number]: {deaths: number, alive: boolean, seen: boolean}} = {}

local observedPlayers: {[Player]: boolean} = {}
local function setupHostObservation()
	-- Reload-safe: never wipe existing death counts.
	for _, uid in ipairs(Settings.AccountUserIds) do
		if HostObs[uid] == nil then
			HostObs[uid] = { deaths = 0, alive = false, seen = false }
		end
	end

	-- Deaths are counted ONLY from CharacterAdded: one new spawn = one
	-- completed reset. Died is never used for counting, so a death can
	-- never be counted twice and fast Blatant cycles are still caught.
	local function hookCharacter(userId: number, char: Model)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			hum = char:WaitForChild("Humanoid", 5)
		end
		if not hum then return end
		local obs = HostObs[userId]
		if not obs then return end
		obs.alive = hum.Health > 0
		obs.seen = true
		hum.HealthChanged:Connect(function(h)
			if HostObs[userId] and h > 0 then
				HostObs[userId].alive = true
			end
		end)
	end

	local function observe(p: Player)
		if observedPlayers[p] then return end
		observedPlayers[p] = true
		local userId = p.UserId
		if not HostObs[userId] then return end
		if p.Character then task.spawn(hookCharacter, userId, p.Character) end
		-- The character seen here is NOT a death. Every later spawn is.
		p.CharacterAdded:Connect(function(c)
			if HostObs[userId] then
				HostObs[userId].deaths += 1
			end
			hookCharacter(userId, c)
		end)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if HostObs[p.UserId] then observe(p) end
	end
	for _, uid in ipairs(Settings.AccountUserIds) do
		local p = Players:GetPlayerByUserId(uid)
		if p then observe(p) end
	end
	Players.PlayerAdded:Connect(function(p)
		if HostObs[p.UserId] then observe(p) end
	end)
end

-- Alive/seen status is re-read from the live character every tick, so a
-- missed event can never freeze a row on the wrong status. Death COUNTS
-- still come only from CharacterAdded above (never touched here).
local function pollAltStatus()
	for _, uid in ipairs(Settings.AccountUserIds) do
		local obs = HostObs[uid]
		if not obs then continue end
		local p = Players:GetPlayerByUserId(uid)
		local char = p and p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local aliveNow = hum ~= nil and hum.Health > 0
		if aliveNow then
			obs.seen = true
		end
		obs.alive = aliveNow
	end
end

local function createHostUI()
	local playerGui = player:WaitForChild("PlayerGui", 30)
	if not playerGui then warn("[Dropper] PlayerGui not found for host UI.") return end
	local oldGui = playerGui:FindFirstChild("DropperHost")
	if oldGui then oldGui:Destroy() end
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "DropperHost"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.new(0, 620, 0, 320)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
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

	-- Tabs: Alts page + Time page (Time shows estimate + live remaining).
	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(1, -20, 0, 26)
	tabBar.Position = UDim2.new(0, 10, 0, 30)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = frame

	local function makeTab(text: string, xPos: number): TextButton
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 90, 1, 0)
		b.Position = UDim2.new(0, xPos, 0, 0)
		b.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
		b.Text = text
		b.TextColor3 = Color3.fromRGB(220, 220, 230)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.BorderSizePixel = 0
		b.Parent = tabBar
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = b
		return b
	end
	local altsTab = makeTab("Alts", 0)
	local timeTab = makeTab("Time", 96)
	-- Pause/Resume dropping for all alts. Click is wired after
	-- requestToggleDropping exists (see UI creation section).
	local pauseBtn = Instance.new("TextButton")
	pauseBtn.Name = "PauseButton"
	pauseBtn.Size = UDim2.new(0, 200, 1, 0)
	pauseBtn.Position = UDim2.new(1, -200, 0, 0)
	if droppingEnabled then
		pauseBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
		pauseBtn.Text = "PAUSE DROPPING"
	else
		pauseBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 70)
		pauseBtn.Text = "RESUME DROPPING"
	end
	pauseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	pauseBtn.Font = Enum.Font.GothamBold
	pauseBtn.TextSize = 13
	pauseBtn.BorderSizePixel = 0
	pauseBtn.Parent = tabBar
	local pauseCorner = Instance.new("UICorner")
	pauseCorner.CornerRadius = UDim.new(0, 4)
	pauseCorner.Parent = pauseBtn
	pauseButton = pauseBtn

	local altsPage = Instance.new("Frame")
	altsPage.Name = "AltsPage"
	altsPage.Size = UDim2.new(1, -20, 1, -72)
	altsPage.Position = UDim2.new(0, 10, 0, 62)
	altsPage.BackgroundTransparency = 1
	altsPage.Parent = frame

	local timePage = Instance.new("Frame")
	timePage.Name = "TimePage"
	timePage.Size = UDim2.new(1, -20, 1, -72)
	timePage.Position = UDim2.new(0, 10, 0, 62)
	timePage.BackgroundTransparency = 1
	timePage.Visible = false
	timePage.Parent = frame

	local function selectTab(which: string)
		local altsOn = which == "Alts"
		altsPage.Visible = altsOn
		timePage.Visible = not altsOn
		altsTab.BackgroundColor3 = altsOn and Color3.fromRGB(150, 40, 40) or Color3.fromRGB(30, 30, 42)
		timeTab.BackgroundColor3 = (not altsOn) and Color3.fromRGB(150, 40, 40) or Color3.fromRGB(30, 30, 42)
	end
	altsTab.MouseButton1Click:Connect(function() selectTab("Alts") end)
	timeTab.MouseButton1Click:Connect(function() selectTab("Time") end)

	local COLS = {
		{key = "idx",    label = "#",       x = 0,   w = 34},
		{key = "name",   label = "Account", x = 34,  w = 130},
		{key = "status", label = "Status",  x = 164, w = 90},
		{key = "resets", label = "Resets",  x = 254, w = 110},
		{key = "drop",   label = "Drop",    x = 364, w = 130},
		{key = "eta",    label = "ETA",     x = 494, w = 120},
	}

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 22)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	header.BorderSizePixel = 0
	header.Parent = altsPage

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
	rowsFrame.Size = UDim2.new(1, 0, 1, -26)
	rowsFrame.Position = UDim2.new(0, 0, 0, 26)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.Parent = altsPage

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

	-- Time page: estimated total on top, live remaining under it (real-time).
	local timeLayout = Instance.new("UIListLayout")
	timeLayout.Padding = UDim.new(0, 6)
	timeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	timeLayout.Parent = timePage
	local timeLabels: {[string]: TextLabel} = {}
	local function addTimeRow(key: string, prefix: string, order: number)
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 24)
		row.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
		row.BorderSizePixel = 0
		row.Text = prefix .. ": —"
		row.TextColor3 = Color3.fromRGB(220, 220, 230)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = Enum.Font.Code
		row.TextSize = 14
		row.LayoutOrder = order
		row.Parent = timePage
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.Parent = row
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 4)
		rc.Parent = row
		timeLabels[key] = row
	end
	addTimeRow("estTotal", "Estimated total", 1)
	addTimeRow("elapsed", "Elapsed", 2)
	addTimeRow("remaining", "Time left", 3)
	addTimeRow("resets", "Resets (global)", 4)
	addTimeRow("drop", "Cash dropped", 5)
	addTimeRow("avg", "Avg / reset", 6)

	makeDraggable(frame)
	hostCells = cells
	hostTimeLabels = timeLabels
end

-- ============================================================
-- UI update loop
-- ============================================================
local function updateLocalUI()
	if not localSetters then return end
	local s = Status

	local elapsed: number
	if s.finished and s.finishActive ~= nil then
		elapsed = (s.finishActive :: number)
	else
		elapsed = activeElapsedSince(s.startTime)
	end
	if elapsed < 0 then elapsed = 0 end
	local remaining = s.resetsTotal - s.resetsDone
	if remaining < 0 then remaining = 0 end
	local avg = s.averagePerDrop or estimatedPerDrop
	local eta = 0
	if not s.finished then
		eta = remaining * avg
	end

	local dropOwn = s.resetsDone * DropPerDeath
	local dropOwnTotal = s.resetsTotal * DropPerDeath
	local dropGlobal = s.resetsDone * effectiveAccountCount * DropPerDeath
	local dropGlobalTotal = Settings.TargetDrop

	if not s.finished and not droppingEnabled then
		localSetters.phase("Paused")
	else
		localSetters.phase(s.phase)
	end
	localSetters.resets(string.format("%s / %s", comma(s.resetsDone), comma(s.resetsTotal)))
	localSetters.dropOwn(string.format("%s / %s", comma(dropOwn), comma(dropOwnTotal)))
	localSetters.dropGlobal(string.format("%s / %s", comma(dropGlobal), comma(dropGlobalTotal)))
	localSetters.elapsed(formatTime(elapsed))
	if s.finished then
		localSetters.eta("Done")
	elseif not droppingEnabled then
		localSetters.eta("Paused")
	else
		localSetters.eta(formatTime(eta))
	end
	localSetters.last(s.last)
end

local function updateHostUI()
	if not hostCells then return end
	pollAltStatus()
	local totalDeaths = 0
	for _, uid in ipairs(Settings.AccountUserIds) do
		local obs = HostObs[uid]
		if obs then totalDeaths += obs.deaths end
	end
	if not hostFinished and totalDeaths >= totalDrops and totalDrops > 0 then
		hostFinished = true
		hostFinishTime = os.clock()
		hostFinishActive = activeElapsedSince(hostStartTime)
	end
	local elapsed: number
	if hostFinished and hostFinishActive ~= nil then
		elapsed = (hostFinishActive :: number)
	else
		elapsed = activeElapsedSince(hostStartTime)
	end
	if elapsed < 0 then elapsed = 0 end

	for i, uid in ipairs(Settings.AccountUserIds) do
		local cells = hostCells[uid]
		if not cells then continue end
		local obs = HostObs[uid]
		local p = Players:GetPlayerByUserId(uid)

		cells.idx.Text = tostring(i)

		if not p then
			cells.name.Text = "userid " .. tostring(uid)
			cells.status.Text = "Not in server"
			cells.status.TextColor3 = Color3.fromRGB(150, 150, 150)
			cells.resets.Text = "—"
			cells.drop.Text = "—"
			cells.eta.Text = "—"
		else
			cells.name.Text = p.Name
			if obs and obs.alive then
				cells.status.Text = "Alive"
				cells.status.TextColor3 = Color3.fromRGB(120, 220, 140)
			else
				cells.status.Text = "Dead"
				cells.status.TextColor3 = Color3.fromRGB(230, 120, 120)
			end

			local d = (obs and obs.deaths) or 0
			cells.resets.Text = string.format("%s / %s", comma(d), comma(deathsNeeded))
			cells.drop.Text = string.format("%s / %s", comma(d * DropPerDeath), comma(deathsNeeded * DropPerDeath))

			-- ETA based on observed average, frozen at Done when finished.
			if hostFinished then
				cells.eta.Text = "Done"
			elseif not droppingEnabled then
				cells.eta.Text = "Paused"
			else
				local avgPerDeath = (d > 0) and (elapsed / d) or estimatedPerDrop
				local remaining = math.max(0, deathsNeeded - d)
				local eta = remaining * avgPerDeath
				cells.eta.Text = formatTime(eta)
			end
		end
	end

	-- Time page: estimate on top, live remaining under it, frozen when done.
	if hostTimeLabels then
		local dropDone = totalDeaths * DropPerDeath
		local resetsRemaining = math.max(0, totalDrops - totalDeaths)
		local avgPerReset = (totalDeaths > 0) and (elapsed / totalDeaths) or estimatedPerDrop
		local estTotal = estimatedPerDrop * totalDrops
		hostTimeLabels.estTotal.Text = "Estimated total: " .. formatTime(estTotal) .. string.format(" (%s resets)", comma(totalDrops))
		if not droppingEnabled and not hostFinished then
			hostTimeLabels.elapsed.Text = "Elapsed: " .. formatTime(elapsed) .. " (Paused)"
		else
			hostTimeLabels.elapsed.Text = "Elapsed: " .. formatTime(elapsed)
		end
		if hostFinished then
			hostTimeLabels.remaining.Text = "Time left: Done (0 left)"
		elseif not droppingEnabled then
			hostTimeLabels.remaining.Text = "Time left: Paused (" .. comma(resetsRemaining) .. " left)"
		else
			local liveRemaining = resetsRemaining * avgPerReset
			hostTimeLabels.remaining.Text = "Time left: " .. formatTime(liveRemaining) .. string.format(" (%s left)", comma(resetsRemaining))
		end
		hostTimeLabels.resets.Text = string.format("Resets (global): %s / %s", comma(totalDeaths), comma(totalDrops))
		hostTimeLabels.drop.Text = string.format("Cash dropped: %s / %s", comma(dropDone), comma(Settings.TargetDrop))
		hostTimeLabels.avg.Text = "Avg / reset: " .. string.format("%.2fs", avgPerReset)
	end
end

-- ============================================================
-- CONTROL WIRING (after Status + UI fns exist)
-- ============================================================
local function refreshPauseButton()
	if pauseButton then
		if droppingEnabled then
			pauseButton.Text = "PAUSE DROPPING"
			pauseButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
		else
			pauseButton.Text = "RESUME DROPPING"
			pauseButton.BackgroundColor3 = Color3.fromRGB(40, 150, 70)
		end
	end
end
local function requestToggleDropping()
	if controlToggle then
		pcall(function()
			(controlToggle :: RemoteEvent):FireServer()
		end)
	else
		local nextValue = not droppingEnabled
		droppingEnabled = nextValue
		pcall(function()
			(controlEnabled :: BoolValue).Value = nextValue
		end)
		print("[DropperControl] Local-only toggle -> " .. tostring(nextValue))
	end
end
local function waitWhilePaused(): boolean
	while not droppingEnabled do
		if Status.finished then return false end
		local stillMine = true
		pcall(function()
			local g = _G :: any
			stillMine = (g.DropperRunId :: any) == runId
		end)
		if not stillMine then return false end
		Status.phase = "Paused"
		task.wait(0.25)
	end
	return true
end
if controlEnabled and controlEnabled:IsA("BoolValue") then
	(controlEnabled :: BoolValue).Changed:Connect(function(newValue: boolean)
		droppingEnabled = newValue
		if not newValue then
			pauseStart = os.clock()
			print("[DropperControl] Paused by host. Alts hold position, counts kept.")
		else
			if pauseStart ~= nil then
				totalPausedTime += os.clock() - (pauseStart :: number)
				pauseStart = nil
			end
			print("[DropperControl] Resumed by host. Alts continue from same count.")
		end
		refreshPauseButton()
		pcall(updateLocalUI)
		pcall(updateHostUI)
	end)
end

-- ============================================================
-- Startup banner
-- ============================================================
print("========================================")
print("       SEQUENTIAL AUTO DROP")
print("========================================")
print(string.format("Account: %s (UserId: %d)", player.Name, player.UserId))
if isAlt then
	print(string.format("Account Order: %d / %d", myAccountIndex, effectiveAccountCount))
else
	print(string.format("Role: HOST (monitoring %d alts)", effectiveAccountCount))
end
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
	if not humanoid then return false end
	if humanoid.Health <= 0 then return false end
	local character = humanoid.Parent :: Model

	-- BLATANT ULTRA-FAST PATH: zero waits, strongest method first.
	if Settings.Mode == "Blatant" then
		-- 1. Instant kill - no wait before this, this is the fastest replication.
		pcall(function() humanoid.Health = 0 end)
		if humanoid.Health <= 0 then return true end
		-- 2. Instant backups, same frame, no waits between.
		pcall(function() humanoid:TakeDamage(1e9) end)
		if humanoid.Health <= 0 then return true end
		pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Dead) end)
		if humanoid.Health <= 0 then return true end
		pcall(function() character:BreakJoints() end)
		if humanoid.Health <= 0 then return true end
		-- 3. Last resort async destruction (does not block caller).
		task.spawn(function()
			pcall(function()
				local root = humanoid.RootPart
				if root then root:Destroy() end
			end)
			pcall(function()
				local head = character:FindFirstChild("Head")
				if head then head:Destroy() end
			end)
			pcall(function() character:BreakJoints() end)
		end)
		return humanoid.Health <= 0
	end

	-- Safe mode: single clean kill.
	pcall(function() humanoid.Health = 0 end)
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
-- ULTRA-FAST INSTANT RESPAWN SYSTEM (Blatant only).
-- Goal: new alive character in under 1 second, every death.
-- Method: Died fires -> LoadCharacter SAME FRAME (no waits),
-- then tight 0.05s retry spam until server returns a new character.
-- Safe mode never touches this, regular Roblox respawn is used.
local respawnRequested = false
local respawnGeneration = 0
local cachedRespawnRemotes: {Instance} = {}
local remotesCached = false
local function cacheRespawnRemotes()
	if remotesCached then return end
	remotesCached = true
	pcall(function()
		for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
			if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
				local n = v.Name:lower()
				if n:find("respawn") or n:find("loadchar") or n:find("spawn") or n:find("reset") or n:find("revive") then
					table.insert(cachedRespawnRemotes, v)
				end
			end
		end
	end)
end
local function fireRespawnRemotes()
	if #cachedRespawnRemotes == 0 then return end
	for _, v in ipairs(cachedRespawnRemotes) do
		pcall(function()
			if v:IsA("RemoteEvent") then
				(v :: RemoteEvent):FireServer()
			else
				(v :: RemoteFunction):InvokeServer()
			end
		end)
	end
end
local function tryLoadCharacterNow(): boolean
	local ok = pcall(function()
		player:LoadCharacter()
	end)
	return ok
end
local function isAliveCharacter(char: Model?): boolean
	if not char then return false end
	if char.Parent == nil then return false end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	if hum.Health <= 0 then return false end
	return true
end
local function requestInstantRespawn(oldChar: Model?)
	if Settings.Mode ~= "Blatant" then return end
	-- If a spam loop is already running, still fire one extra
	-- immediate attempt so this death never waits for the loop tick.
	if respawnRequested then
		tryLoadCharacterNow()
		return
	end
	respawnRequested = true
	respawnGeneration += 1
	local myGeneration = respawnGeneration
	local capturedOld: Model? = oldChar or player.Character
	-- SAME-FRAME attempt 1: synchronous, no yield.
	tryLoadCharacterNow()
	-- SAME-FRAME attempt 2: deferred to next resumption so it runs
	-- even if the server still held the old character on attempt 1.
	task.defer(function()
		if Settings.Mode ~= "Blatant" then return end
		if myGeneration ~= respawnGeneration then return end
		if isAliveCharacter(player.Character) and player.Character ~= capturedOld then return end
		tryLoadCharacterNow()
	end)
	-- Tight retry spam: LoadCharacter every 0.05s until new alive char.
	-- This covers server throttle / race where first calls are dropped.
	task.spawn(function()
		cacheRespawnRemotes()
		local start = os.clock()
		while Settings.Mode == "Blatant" and myGeneration == respawnGeneration do
			local cur = player.Character
			if cur and cur ~= capturedOld and isAliveCharacter(cur) then
				break
			end
			if os.clock() - start > 3 then
				break
			end
			tryLoadCharacterNow()
			fireRespawnRemotes()
			task.wait(0.05)
		end
		if myGeneration == respawnGeneration then
			respawnRequested = false
		end
	end)
end
local function hookInstantRespawn(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid then return end
	humanoid.Died:Connect(function()
		if Settings.Mode == "Blatant" then
			requestInstantRespawn(character)
		end
	end)
end
player.CharacterAdded:Connect(function(character)
	respawnRequested = false
	respawnGeneration += 1
	hookInstantRespawn(character)
end)
player.CharacterRemoving:Connect(function(character)
	if Settings.Mode ~= "Blatant" then return end
	requestInstantRespawn(character)
end)
if player.Character then
	hookInstantRespawn(player.Character)
end
player:GetPropertyChangedSignal("Character"):Connect(function()
	if Settings.Mode == "Blatant" and player.Character == nil then
		requestInstantRespawn(nil)
	end
end)

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
	local isBlatant = Settings.Mode == "Blatant"
	while os.clock() - startTime < Settings.RespawnTimeout do
		local character = player.Character
		if character and getRoot(character) then
			local humanoid = getHumanoid(character)
			if humanoid and humanoid.Health > 0 then return character end
		end
		if isBlatant then
			task.wait()
		else
			task.wait(Settings.CheckInterval)
		end
	end
	warn(string.format("[%s] Character timeout.", player.Name)) return nil
end
local function waitForNewCharacter(oldCharacter: Model): Model?
	local startTime = os.clock()
	local isBlatant = Settings.Mode == "Blatant"
	while os.clock() - startTime < Settings.RespawnTimeout do
		local character = player.Character
		if character and character ~= oldCharacter and getRoot(character) then
			local humanoid = getHumanoid(character)
			if humanoid and humanoid.Health > 0 then
				if not isBlatant and Settings.CharacterReadyDelay > 0 then task.wait(Settings.CharacterReadyDelay) end
				return character
			end
		end
		if isBlatant then
			task.wait()
		else
			task.wait(Settings.CheckInterval)
		end
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
	-- Blatant runs all alts in parallel for max speed. Waiting for the
	-- previous alt would deadlock because the previous alt is dead
	-- (mid-drop) most of the time. Safe keeps the sequential order.
	if Settings.Mode == "Blatant" then return true end
	if myAccountIndex == nil then return true end
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
-- Reads the client's CURRENT root (fresh every call, client may move).
local function getClientRoot(): BasePart?
	local client = getClient()
	if not client then return nil end
	local clientCharacter = client.Character
	if not clientCharacter then return nil end
	return getRoot(clientCharacter)
end
local function teleportToClient(character: Model): boolean
	local client = getClient()
	if not client then warn(string.format("[%s] Client is not in server.", player.Name)) return false end
	local clientCharacter = client.Character
	if not clientCharacter then warn(string.format("[%s] Client has no character.", player.Name)) return false end
	local clientRoot = getRoot(clientCharacter)
	if not clientRoot then warn(string.format("[%s] Client has no HumanoidRootPart.", player.Name)) return false end
	local root = getRoot(character)
	if not root then return false end
	-- Each alt lands on its own ring slot around the client. Stacking all
	-- alts on one CFrame flings them apart, so some never verify.
	local function slotCFrame(base: CFrame): CFrame
		if myAccountIndex ~= nil and effectiveAccountCount > 1 then
			local angle = (((myAccountIndex :: number) - 1) / effectiveAccountCount) * math.pi * 2
			return base + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
		end
		return base
	end
	-- Kill leftover momentum so physics does not fling us back.
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
	character:PivotTo(slotCFrame(clientRoot.CFrame))
	-- Let the teleport REPLICATE before killing. Killing on the same
	-- frame makes the server register the death at the OLD position,
	-- so the cash drops at spawn instead of at the client.
	if Settings.Mode == "Blatant" then
		task.wait(0.12)
	else
		task.wait(0.2)
	end
	-- Verify against the client's FRESH position and correct drift.
	-- A failed teleport returns false so this drop is retried WITHOUT
	-- counting a reset (no wasted/misplaced drop).
	local limit = Settings.Mode == "Blatant" and 12 or 10
	for _ = 1, 3 do
		local nowRoot = getRoot(character)
		local freshClient = getClientRoot()
		if not nowRoot or not freshClient then
			Status.last = "TP lost char"
			warn(string.format("[%s] Teleport lost character.", player.Name))
			return false
		end
		local want = slotCFrame(freshClient.CFrame)
		local distance = (nowRoot.Position - want.Position).Magnitude
		if distance <= limit then
			Status.last = string.format("TP ok (%.1f)", distance)
			print(string.format("[%s] TP to client confirmed (dist %.1f).", player.Name, distance))
			return true
		end
		character:PivotTo(want)
		pcall(function()
			nowRoot.AssemblyLinearVelocity = Vector3.zero
			nowRoot.AssemblyAngularVelocity = Vector3.zero
		end)
		task.wait(0.08)
	end
	local lastRoot = getRoot(character)
	local lastClient = getClientRoot()
	local lastDist = (lastRoot and lastClient) and (lastRoot.Position - slotCFrame(lastClient.CFrame).Position).Magnitude or -1
	Status.last = string.format("TP fail (%.1f)", lastDist)
	warn(string.format("[%s] Teleport verification failed. Distance: %.2f Alt: %s Client: %s", player.Name, lastDist, tostring(lastRoot and lastRoot.Position), tostring(lastClient and lastClient.Position)))
	return false
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
local lastNoClientWarnAt: number = 0
local function performDrop(): boolean
	Status.phase = "Waiting for character"
	if not waitWhilePaused() then return false end
	local character = waitForCharacter() if not character then return false end
	local characterToKill = character
	if not getClient() then
		Status.last = "No client"
		if os.clock() - lastNoClientWarnAt > 5 then
			lastNoClientWarnAt = os.clock()
			warn(string.format("[%s] Client UserId %s not in server, waiting...", player.Name, tostring(Settings.ClientUserId)))
		end
		return false
	end
	Status.phase = "Teleporting"
	local teleported = teleportToClient(characterToKill) if not teleported then warn(string.format("[%s] Teleport failed.", player.Name)) return false end
	-- Paused after TP: hold at client, do NOT kill. On resume re-confirm
	-- position (client may have moved) so the drop never lands elsewhere.
	if not waitWhilePaused() then return false end
	if player.Character ~= characterToKill then warn(string.format("[%s] Character changed while paused.", player.Name)) return false end
	do
		local nowRoot = getRoot(characterToKill)
		local freshClient = getClientRoot()
		if nowRoot and freshClient and (nowRoot.Position - freshClient.Position).Magnitude > 12 then
			local reTeleported = teleportToClient(characterToKill)
			if not reTeleported then warn(string.format("[%s] Re-teleport after pause failed.", player.Name)) return false end
			if not waitWhilePaused() then return false end
		end
	end
	-- teleportToClient already waited for replication + verified position.
	-- Safe adds its extra KillDelay on top. Blatant kills immediately.
	if Settings.Mode ~= "Blatant" then
		task.wait(0.35)
		task.wait(Settings.KillDelay)
	end
	if not droppingEnabled then return false end
	if player.Character ~= characterToKill then warn(string.format("[%s] Character changed before kill.", player.Name)) return false end
	Status.phase = "Killing"
	local killed = selfKill(characterToKill) if not killed then return false end
	-- Fire respawn request immediately, do not wait for Died propagation.
	if Settings.Mode == "Blatant" then
		requestInstantRespawn(characterToKill)
	end
	Status.phase = "Respawning"
	local newCharacter = waitForNewCharacter(characterToKill) if not newCharacter then return false end
	return true
end

-- ============================================================
-- Create UIs and start UI update loop
-- ============================================================
-- Alt gets ONLY the small draggable status. Host gets ONLY the full panel.
-- pcall so a UI error never kills TP/kill loop. Old copies removed first
-- (respawn can otherwise stack duplicate panels).
if isAlt then
	local ok, err = pcall(createLocalUI)
	if not ok then warn("[Dropper] alt UI failed: " .. tostring(err)) end
end
if isHost then
	local okObs, errObs = pcall(setupHostObservation)
	if not okObs then warn("[Dropper] host observation failed: " .. tostring(errObs)) end
	local okUI, errUI = pcall(createHostUI)
	if not okUI then warn("[Dropper] host UI failed: " .. tostring(errUI)) end
	-- Wire Pause/Resume now that both the button and toggle exist.
	if pauseButton then
		pcall(function()
			(pauseButton :: TextButton).MouseButton1Click:Connect(function()
				requestToggleDropping()
			end)
		end)
		pcall(refreshPauseButton)
	end
	-- Paint rows immediately so the host never stares at "—".
	local okPaint, errPaint = pcall(updateHostUI)
	if not okPaint then warn("[Dropper] host UI first paint: " .. tostring(errPaint)) end
end

-- Executor reload entry points. Host runs ONE line to bring the panel
-- back without resetting counts or restarting drops:
--   _G.Dropper.ReloadHostPanel()
-- Alt equivalent: _G.Dropper.ReloadAltUI(). Toggle: _G.Dropper.Toggle().
pcall(function()
	local g = _G :: any
	local api = g.Dropper
	if type(api) ~= "table" then
		api = {}
		g.Dropper = api
	end
	api.ReloadHostPanel = function()
		if not isHost then warn("[Dropper] ReloadHostPanel is host-only.") return end
		local ok, err = pcall(createHostUI)
		if not ok then warn("[Dropper] host UI reload failed: " .. tostring(err)) return end
		if pauseButton then
			pcall(function()
				(pauseButton :: TextButton).MouseButton1Click:Connect(function()
					requestToggleDropping()
				end)
			end)
		end
		pcall(refreshPauseButton)
		pcall(updateHostUI)
		print("[Dropper] Host panel reloaded. Counts kept.")
	end
	api.ReloadAltUI = function()
		if not isAlt then warn("[Dropper] ReloadAltUI is alt-only.") return end
		local ok, err = pcall(createLocalUI)
		if not ok then warn("[Dropper] alt UI reload failed: " .. tostring(err)) return end
		pcall(updateLocalUI)
		print("[Dropper] Alt panel reloaded.")
	end
	api.Toggle = function()
		requestToggleDropping()
	end
	api.IsPaused = function()
		return not droppingEnabled
	end
end)

task.spawn(function()
	local myRun = runId
	while true do
		task.wait(0.25)
		local alive: boolean = true
		pcall(function()
			local g = _G :: any
			alive = (g.DropperRunId :: any) == myRun
		end)
		if not alive then break end
		if isAlt then
			local ok, err = pcall(updateLocalUI)
			if not ok then warn("[Dropper] alt UI update: " .. tostring(err)) end
		end
		if isHost then
			local ok, err = pcall(updateHostUI)
			if not ok then warn("[Dropper] host UI update: " .. tostring(err)) end
		end
		-- Stop timers when everything is done: alt finished, host all-done.
		if isAlt and not isHost and Status.finished then
			break
		end
		if isHost and not isAlt and hostFinished then
			break
		end
		if isAlt and isHost and Status.finished and hostFinished then
			break
		end
	end
end)

-- Host true global progress (sums actual deaths across all alts).
-- This is the only correct global number when alts desync. Stops when done.
if isHost then
	task.spawn(function()
		local myRun = runId
		while true do
			task.wait(10)
			local stillMine = true
			pcall(function()
				local g = _G :: any
				stillMine = (g.DropperRunId :: any) == myRun
			end)
			if not stillMine then break end
			if hostFinished then
				print("[HOST] All alts finished. Timer stopped.")
				break
			end
			local totalDeaths = 0
			for _, uid in ipairs(Settings.AccountUserIds) do
				local obs = HostObs[uid]
				if obs then
					totalDeaths += obs.deaths
				end
			end
			local remaining = math.max(0, totalDrops - totalDeaths)
			local dropDone = totalDeaths * DropPerDeath
			local dropRemaining = math.max(0, Settings.TargetDrop - dropDone)
			print(string.format("[HOST] Progress: %s/%s resets (global) | %s resets remaining | %s drop remaining", comma(totalDeaths), comma(totalDrops), comma(remaining), comma(dropRemaining)))
		end
	end)
end

-- Host does NOT drop. Panel + observation only, stop here.
if isHost and not isAlt then
	Status.phase = "Host monitoring"
	print(string.format("[Dropper] Host %s monitoring %d alts. No dropping on host.", player.Name, effectiveAccountCount))
	return
end

-- ============================================================
-- Main loop (alts only)
-- ============================================================
Status.phase = "Starting"
local initialCharacter = waitForCharacter()
if not initialCharacter then
	Status.phase = "Done"
	Status.finished = true
	Status.finishTime = os.clock()
	Status.finishActive = activeElapsedSince(Status.startTime)
	pcall(updateLocalUI)
	return
end

local deathsCompleted = 0
local runStartTime = os.clock()

while deathsCompleted < deathsNeeded do
	local superseded = false
	pcall(function()
		local g = _G :: any
		superseded = (g.DropperRunId :: any) ~= runId
	end)
	if superseded then
		print(string.format("[%s] New run started, stopping old loop.", player.Name))
		break
	end
	-- Paused: hold here, keep deathsCompleted so resume continues same count.
	if not waitWhilePaused() then
		break
	end
	if Status.finished then
		break
	end
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
		if Status.finished then
			break
		end
		if not droppingEnabled then
			task.wait(0.25)
			continue
		end
		warn(string.format("[%s] Drop failed. Retrying same drop.", player.Name))
		task.wait(Settings.CheckInterval)
		continue
	end

	deathsCompleted += 1
	Status.resetsDone = deathsCompleted
	local elapsed = activeElapsedSince(runStartTime)
	if elapsed < 0 then elapsed = 0 end
	Status.averagePerDrop = elapsed / deathsCompleted

	-- Old-style per-alt debug like before (e.g. 45/286 resets for 10M).
	-- Own progress uses deathsNeeded (per-alt), global estimate uses totalDrops.
	local personalDrop = deathsCompleted * DropPerDeath
	local personalTotal = deathsNeeded * DropPerDeath
	local globalEst = deathsCompleted * effectiveAccountCount * DropPerDeath
	print(string.format("[%s] COMPLETE | %s/%s resets (own) | Personal: %s/%s | Global est: %s/%s", player.Name, comma(deathsCompleted), comma(deathsNeeded), comma(personalDrop), comma(personalTotal), comma(globalEst), comma(Settings.TargetDrop)))

	Status.phase = "Complete"

	if Settings.Mode ~= "Blatant" then
		task.wait(LOOP_BREATHE)
	end
end

Status.phase = "Done"
Status.finished = true
Status.finishTime = os.clock()
Status.finishActive = activeElapsedSince(Status.startTime)
local activeRun = activeElapsedSince(runStartTime)
if activeRun < 0 then activeRun = 0 end
Status.averagePerDrop = if deathsCompleted > 0 then activeRun / deathsCompleted else Status.averagePerDrop
pcall(updateLocalUI)
local finalElapsed = activeRun
print("========================================")
print("         AUTO DROP COMPLETE")
print("========================================")
print(string.format("Account: %s", player.Name))
print(string.format("Deaths completed (this account): %s / %s", comma(deathsCompleted), comma(deathsNeeded)))
print(string.format("Combined Drop: %s / %s", comma(deathsCompleted * effectiveAccountCount * DropPerDeath), comma(Settings.TargetDrop)))
print(string.format("Total time: %s (timer stopped)", formatTime(finalElapsed)))
