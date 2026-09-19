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

-- No pause/resume: once started, alts always run. Elapsed is plain os.clock().

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
local hostStartTime = os.clock()
local hostFinished = false
local hostFinishTime: number? = nil
local hostFinishActive: number? = nil
local HostObs: {[number]: {deaths: number, alive: boolean, seen: boolean}} = {}
-- Client cash tracking (host only). Baseline is the first successful
-- cash read, taken before drops pile up, so Received = Now - Start.
local hostClientLabels: {[string]: TextLabel}? = nil
local hostClientAvatar: ImageLabel? = nil
local clientCashStart: number? = nil
local clientCashNow: number? = nil
local clientCachedName: string? = nil

-- Reads cash exactly like the game stores it: ReplicatedStats > Money
-- (StringValue) > RawValue attribute. Falls back to Money.Value text.
local function readPlayerCash(targetPlayer: Player): number?
	if not targetPlayer then return nil end
	local ok, result = pcall(function(): number?
		local stats = targetPlayer:FindFirstChild("ReplicatedStats")
		if not stats then return nil end
		local money = stats:FindFirstChild("Money")
		if not money then return nil end
		local raw: any = nil
		pcall(function() raw = (money :: Instance):GetAttribute("RawValue") end)
		if typeof(raw) == "number" then return raw end
		if typeof(raw) == "string" then
			local cleaned = (raw :: string):gsub("[^%d%-%.]", "")
			local n = tonumber(cleaned)
			if n then return n end
		end
		if money:IsA("StringValue") then
			local cleaned = ((money :: StringValue).Value):gsub("[^%d%-%.]", "")
			local n = tonumber(cleaned)
			if n then return n end
		elseif money:IsA("IntValue") then
			return (money :: IntValue).Value
		elseif money:IsA("NumberValue") then
			return (money :: NumberValue).Value
		end
		return nil
	end)
	if ok then return result end
	return nil
end

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
	local clientTab = makeTab("Client", 192)

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

	local clientPage = Instance.new("Frame")
	clientPage.Name = "ClientPage"
	clientPage.Size = UDim2.new(1, -20, 1, -72)
	clientPage.Position = UDim2.new(0, 10, 0, 62)
	clientPage.BackgroundTransparency = 1
	clientPage.Visible = false
	clientPage.Parent = frame

	local function selectTab(which: string)
		altsPage.Visible = which == "Alts"
		timePage.Visible = which == "Time"
		clientPage.Visible = which == "Client"
		altsTab.BackgroundColor3 = (which == "Alts") and Color3.fromRGB(150, 40, 40) or Color3.fromRGB(30, 30, 42)
		timeTab.BackgroundColor3 = (which == "Time") and Color3.fromRGB(150, 40, 40) or Color3.fromRGB(30, 30, 42)
		clientTab.BackgroundColor3 = (which == "Client") and Color3.fromRGB(150, 40, 40) or Color3.fromRGB(30, 30, 42)
	end
	altsTab.MouseButton1Click:Connect(function() selectTab("Alts") end)
	timeTab.MouseButton1Click:Connect(function() selectTab("Time") end)
	clientTab.MouseButton1Click:Connect(function() selectTab("Client") end)

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

	-- Client page: identity header + live cash tracking.
	local clientLabels: {[string]: TextLabel} = {}
	local headerRow = Instance.new("Frame")
	headerRow.Size = UDim2.new(1, 0, 0, 72)
	headerRow.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	headerRow.BorderSizePixel = 0
	headerRow.Parent = clientPage
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 4)
	headerCorner.Parent = headerRow
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Size = UDim2.new(0, 56, 0, 56)
	avatar.Position = UDim2.new(0, 8, 0, 8)
	avatar.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	avatar.BorderSizePixel = 0
	avatar.Image = ""
	avatar.Parent = headerRow
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0, 28)
	avatarCorner.Parent = avatar
	local function addClientHeaderLabel(key: string, y: number)
		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 72, 0, y)
		lbl.Size = UDim2.new(1, -80, 0, 20)
		lbl.BackgroundTransparency = 1
		lbl.Text = "—"
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 13
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.Parent = headerRow
		clientLabels[key] = lbl
	end
	addClientHeaderLabel("username", 4)
	addClientHeaderLabel("display", 24)
	addClientHeaderLabel("userid", 44)
	local function addClientRow(key: string, prefix: string)
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
		row.BorderSizePixel = 0
		row.Text = prefix .. ": —"
		row.TextColor3 = Color3.fromRGB(220, 220, 230)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = Enum.Font.Code
		row.TextSize = 13
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.Parent = clientPage
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.Parent = row
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 4)
		rc.Parent = row
		clientLabels[key] = row
	end
	-- Spacer puts cash rows below the 72px header inside a list layout.
	local clientLayout = Instance.new("UIListLayout")
	clientLayout.Padding = UDim.new(0, 4)
	clientLayout.SortOrder = Enum.SortOrder.LayoutOrder
	clientLayout.Parent = clientPage
	headerRow.LayoutOrder = 1
	addClientRow("presence", "Presence")
	clientLabels["presence"].LayoutOrder = 2
	addClientRow("start", "Started with")
	clientLabels["start"].LayoutOrder = 3
	addClientRow("now", "Cash now")
	clientLabels["now"].LayoutOrder = 4
	addClientRow("gained", "Received")
	clientLabels["gained"].LayoutOrder = 5
	addClientRow("expected", "Expected")
	clientLabels["expected"].LayoutOrder = 6
	-- Static expected target, never needs a live read.
	clientLabels["expected"].Text = "Expected: " .. comma(Settings.TargetDrop)
	-- Fill avatar + offline username once; live names overwrite each tick.
	local clientUserId: number = Settings.ClientUserId
	task.spawn(function()
		pcall(function()
			local thumb: string? = nil
			pcall(function()
				thumb = Players:GetUserThumbnailAsync(clientUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if thumb ~= nil and avatar.Parent ~= nil then avatar.Image = (thumb :: string) end
		end)
		if clientCachedName == nil then
			pcall(function()
				clientCachedName = Players:GetNameFromUserIdAsync(clientUserId)
			end)
		end
	end)

	makeDraggable(frame)
	hostCells = cells
	hostTimeLabels = timeLabels
	hostClientLabels = clientLabels
	hostClientAvatar = avatar
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
		elapsed = os.clock() - s.startTime
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

	localSetters.phase(s.phase)
	localSetters.resets(string.format("%s / %s", comma(s.resetsDone), comma(s.resetsTotal)))
	localSetters.dropOwn(string.format("%s / %s", comma(dropOwn), comma(dropOwnTotal)))
	localSetters.dropGlobal(string.format("%s / %s", comma(dropGlobal), comma(dropGlobalTotal)))
	localSetters.elapsed(formatTime(elapsed))
	if s.finished then
		localSetters.eta("Done")
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
		hostFinishActive = os.clock() - hostStartTime
	end
	local elapsed: number
	if hostFinished and hostFinishActive ~= nil then
		elapsed = (hostFinishActive :: number)
	else
		elapsed = os.clock() - hostStartTime
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
		hostTimeLabels.elapsed.Text = "Elapsed: " .. formatTime(elapsed)
		if hostFinished then
			hostTimeLabels.remaining.Text = "Time left: Done (0 left)"
		else
			local liveRemaining = resetsRemaining * avgPerReset
			hostTimeLabels.remaining.Text = "Time left: " .. formatTime(liveRemaining) .. string.format(" (%s left)", comma(resetsRemaining))
		end
		hostTimeLabels.resets.Text = string.format("Resets (global): %s / %s", comma(totalDeaths), comma(totalDrops))
		hostTimeLabels.drop.Text = string.format("Cash dropped: %s / %s", comma(dropDone), comma(Settings.TargetDrop))
		hostTimeLabels.avg.Text = "Avg / reset: " .. string.format("%.2fs", avgPerReset)
	end

	-- Client page: identity + cash baseline vs live, so missing cash is visible.
	if hostClientLabels then
		local clientPlayer = Players:GetPlayerByUserId(Settings.ClientUserId)
		if clientPlayer then
			if clientCachedName == nil then clientCachedName = clientPlayer.Name end
			hostClientLabels.username.Text = "@" .. clientPlayer.Name
			hostClientLabels.display.Text = clientPlayer.DisplayName
			hostClientLabels.userid.Text = "ID: " .. tostring(clientPlayer.UserId)
			hostClientLabels.presence.Text = "Presence: In server"
			hostClientLabels.presence.TextColor3 = Color3.fromRGB(120, 220, 140)
			local cash = readPlayerCash(clientPlayer)
			if cash ~= nil then
				clientCashNow = cash
				if clientCashStart == nil then
					clientCashStart = cash
					print(string.format("[HOST] Client start cash: %s", comma(cash)))
				end
			end
		else
			local offlineName: string? = clientCachedName
			if offlineName == nil then
				pcall(function()
					offlineName = Players:GetNameFromUserIdAsync(Settings.ClientUserId)
					clientCachedName = offlineName
				end)
			end
			hostClientLabels.username.Text = "@" .. (offlineName or ("userid " .. tostring(Settings.ClientUserId)))
			if hostClientLabels.display.Text == "—" then
				hostClientLabels.display.Text = offlineName or "—"
			end
			hostClientLabels.userid.Text = "ID: " .. tostring(Settings.ClientUserId)
			hostClientLabels.presence.Text = "Presence: Not in server"
			hostClientLabels.presence.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
		if clientCashStart ~= nil then
			hostClientLabels.start.Text = "Started with: " .. comma(clientCashStart :: number)
		else
			hostClientLabels.start.Text = "Started with: waiting for client cash…"
		end
		if clientCashNow ~= nil then
			local suffix = hostFinished and " (final)" or ""
			hostClientLabels.now.Text = "Cash now: " .. comma(clientCashNow :: number) .. suffix
		else
			hostClientLabels.now.Text = "Cash now: —"
		end
		if clientCashStart ~= nil and clientCashNow ~= nil then
			local gained = (clientCashNow :: number) - (clientCashStart :: number)
			local suffix = hostFinished and " (final)" or ""
			hostClientLabels.gained.Text = "Received: " .. comma(gained) .. suffix
		else
			hostClientLabels.gained.Text = "Received: —"
		end
	end
end

-- No control wiring: no pause/resume, alts run straight through.

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
	-- All alts stack on the client's EXACT position, then self-kill there.
	character:PivotTo(clientRoot.CFrame)
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
	for _ = 1, 4 do
		local nowRoot = getRoot(character)
		local freshClient = getClientRoot()
		if not nowRoot or not freshClient then
			Status.last = "TP lost char"
			warn(string.format("[%s] Teleport lost character.", player.Name))
			return false
		end
		local want = freshClient.CFrame
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
	local lastDist = (lastRoot and lastClient) and (lastRoot.Position - lastClient.Position).Magnitude or -1
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
local teleportFailStreak = 0
-- Wave sync (client-only, pure reads). An alt counts as ready when its
-- character is ACTUALLY standing at the client. Every client in the
-- server can see every other player's character, so this needs no
-- remote writes at all - nothing to fail, nothing to go stale.
-- Nobody resets until every alt in the server is at the client, so
-- all drops in a wave land on the client together.
local READY_RADIUS = 15
local function presentAltUserIds(): {number}
	local present: {number} = {}
	for _, accountUserId in ipairs(Settings.AccountUserIds) do
		if Players:GetPlayerByUserId(accountUserId) then
			table.insert(present, accountUserId)
		end
	end
	return present
end
local function countAltsAtClient(clientRoot: BasePart): (number, number)
	local present = presentAltUserIds()
	local readyCount = 0
	for _, accountUserId in ipairs(present) do
		local targetPlayer = Players:GetPlayerByUserId(accountUserId)
		local targetCharacter = targetPlayer and targetPlayer.Character
		local targetRoot = targetCharacter and getRoot(targetCharacter)
		if targetRoot and (targetRoot.Position - clientRoot.Position).Magnitude <= READY_RADIUS then
			readyCount += 1
		end
	end
	return readyCount, #present
end
local function waitForAllReady(): boolean
	Status.phase = "Syncing"
	Status.last = "Waiting for alts"
	local timeout = 15
	if Settings.Mode ~= "Blatant" then
		timeout = 20
	end
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if Status.finished then return false end
		local clientRoot = getClientRoot()
		if clientRoot then
			local readyCount, totalCount = countAltsAtClient(clientRoot)
			Status.last = string.format("At client %d/%d", readyCount, totalCount)
			if totalCount > 0 and readyCount >= totalCount then
				return true
			end
		else
			Status.last = "No client"
		end
		task.wait(0.1)
	end
	-- One alt is stuck. Still reset only if I am at the client myself,
	-- so my own drop can never land back at my spawn.
	local myCharacter = player.Character
	local myRoot = myCharacter and getRoot(myCharacter)
	local clientRoot = getClientRoot()
	if myRoot and clientRoot and (myRoot.Position - clientRoot.Position).Magnitude <= READY_RADIUS then
		Status.last = "Sync timeout (at client)"
		warn(string.format("[%s] Sync timeout, resetting at client anyway.", player.Name))
		return true
	end
	Status.last = "Sync timeout (lost)"
	warn(string.format("[%s] Sync timeout and not at client, retrying drop.", player.Name))
	return false
end
local function performDrop(): boolean
	Status.phase = "Waiting for character"
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
	local teleported = teleportToClient(characterToKill)
	if not teleported then
		teleportFailStreak += 1
		warn(string.format("[%s] Teleport failed.", player.Name))
		return false
	end
	teleportFailStreak = 0
	Status.last = "Ready, syncing"
	-- Character may have changed during the teleport yields, so re-confirm
	-- position (client may have moved) before killing at the client.
	if player.Character ~= characterToKill then warn(string.format("[%s] Character changed during teleport.", player.Name)) return false end
	do
		local nowRoot = getRoot(characterToKill)
		local freshClient = getClientRoot()
		if nowRoot and freshClient and (nowRoot.Position - freshClient.Position).Magnitude > 12 then
			local reTeleported = teleportToClient(characterToKill)
			if not reTeleported then teleportFailStreak += 1 warn(string.format("[%s] Re-teleport failed.", player.Name)) return false end
		end
	end
	-- Wave sync: nobody resets until every alt in the server is standing
	-- at the client. A timeout falls back so one stuck alt cannot freeze
	-- the rest, and it still refuses to kill away from the client.
	if not waitForAllReady() then return false end
	-- Final gate: kill only while standing at the client's CURRENT spot,
	-- so the reset can never happen back at my own spawn.
	do
		local myRoot = getRoot(characterToKill)
		local clientRoot = getClientRoot()
		if not myRoot or not clientRoot or (myRoot.Position - clientRoot.Position).Magnitude > READY_RADIUS + 3 then
			Status.last = "Drifted, re-TP"
			local reTeleported = teleportToClient(characterToKill)
			if not reTeleported then teleportFailStreak += 1 warn(string.format("[%s] Pre-kill re-teleport failed.", player.Name)) return false end
		end
	end
	-- teleportToClient already waited for replication + verified position.
	-- Safe adds its extra KillDelay on top. Blatant kills immediately.
	if Settings.Mode ~= "Blatant" then
		task.wait(0.35)
		task.wait(Settings.KillDelay)
	end
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
	-- Paint rows immediately so the host never stares at "—".
	local okPaint, errPaint = pcall(updateHostUI)
	if not okPaint then warn("[Dropper] host UI first paint: " .. tostring(errPaint)) end
end

-- Executor reload entry points. Host runs ONE line to bring the panel
-- back without resetting counts or restarting drops:
--   _G.Dropper.ReloadHostPanel()
-- Alt equivalent: _G.Dropper.ReloadAltUI().
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
-- Never give up here: an alt whose character is slow to spawn must keep
-- waiting, not silently "finish" with zero drops.
local initialCharacter: Model? = nil
while initialCharacter == nil do
	local stillMine = true
	pcall(function()
		local g = _G :: any
		stillMine = (g.DropperRunId :: any) == runId
	end)
	if not stillMine then return end
	initialCharacter = waitForCharacter()
	if initialCharacter == nil then
		Status.last = "Waiting for spawn"
		task.wait(1)
	end
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
	-- pcall so one unexpected error retries the drop instead of silently
	-- killing this alt's whole loop (which would look like "never drops").
	local okDrop, success = pcall(performDrop)
	if not okDrop then
		warn(string.format("[%s] Drop error: %s", player.Name, tostring(success)))
		task.wait(Settings.CheckInterval)
		continue
	end
	if not success then
		if Status.finished then
			break
		end
		-- Teleport stuck 3 drops in a row: force a fresh respawn to clear
		-- bad physics (seated, welded, flung somewhere odd), then retry.
		if teleportFailStreak >= 3 then
			teleportFailStreak = 0
			Status.phase = "Recovering"
			Status.last = "Stuck, fresh respawn"
			warn(string.format("[%s] Teleport stuck 3x, forcing fresh respawn.", player.Name))
			local stuckCharacter = player.Character
			if stuckCharacter then pcall(selfKill, stuckCharacter) end
			if not waitForCharacter() then task.wait(1) end
			continue
		end
		warn(string.format("[%s] Drop failed. Retrying same drop.", player.Name))
		task.wait(Settings.CheckInterval)
		continue
	end

	deathsCompleted += 1
	Status.resetsDone = deathsCompleted
	local elapsed = os.clock() - runStartTime
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
Status.finishActive = os.clock() - Status.startTime
local activeRun = os.clock() - runStartTime
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
