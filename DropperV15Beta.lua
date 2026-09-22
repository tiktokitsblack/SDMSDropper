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
	screenGui.DisplayOrder = 999
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(0, 400, 0, 180)
	frame.BackgroundColor3 = Color3.fromRGB(8, 13, 10)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.ClipsDescendants = true
	frame.Parent = screenGui
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 10)
	frameCorner.Parent = frame
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(44, 82, 60)
	frameStroke.Thickness = 1
	frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	frameStroke.Parent = frame
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 44)
	titleBar.BackgroundColor3 = Color3.fromRGB(12, 19, 15)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = frame
	local titleBarCorner = Instance.new("UICorner")
	titleBarCorner.CornerRadius = UDim.new(0, 10)
	titleBarCorner.Parent = titleBar
	local titleAccent = Instance.new("Frame")
	titleAccent.Size = UDim2.new(0, 3, 1, -20)
	titleAccent.Position = UDim2.new(0, 16, 0, 10)
	titleAccent.BackgroundColor3 = Color3.fromRGB(57, 255, 140)
	titleAccent.BorderSizePixel = 0
	titleAccent.Parent = titleBar
	local titleAccentCorner = Instance.new("UICorner")
	titleAccentCorner.CornerRadius = UDim.new(1, 0)
	titleAccentCorner.Parent = titleAccent
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -48, 1, 0)
	title.Position = UDim2.new(0, 30, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(225, 245, 230)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextScaled = false
	title.Font = Enum.Font.Code
	title.TextSize = 16
	title.Parent = titleBar
	local titleLine = Instance.new("Frame")
	titleLine.Size = UDim2.new(1, 0, 0, 1)
	titleLine.Position = UDim2.new(0, 0, 1, -1)
	titleLine.BackgroundColor3 = Color3.fromRGB(30, 52, 40)
	titleLine.BorderSizePixel = 0
	titleLine.Parent = titleBar
	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -40, 1, -66)
	body.Position = UDim2.new(0, 20, 0, 54)
	body.BackgroundTransparency = 1
	body.Text = bodyText
	body.TextColor3 = Color3.fromRGB(165, 200, 175)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Font = Enum.Font.Code
	body.TextSize = 14
	body.Parent = frame
	local cursor = Instance.new("Frame")
	cursor.Size = UDim2.new(0, 10, 0, 3)
	cursor.Position = UDim2.new(0, 20, 1, -14)
	cursor.BackgroundColor3 = Color3.fromRGB(57, 255, 140)
	cursor.BorderSizePixel = 0
	cursor.Parent = frame
	local cursorCorner = Instance.new("UICorner")
	cursorCorner.CornerRadius = UDim.new(1, 0)
	cursorCorner.Parent = cursor
	task.spawn(function()
		while cursor.Parent ~= nil do
			cursor.Visible = not cursor.Visible
			task.wait(0.5)
		end
	end)
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
	showBootPanel("> DROPPER :: WAITING", "Waiting for Settings.\nExecute Loader on this account.\nUserId: " .. tostring(player.UserId))
	while Settings == nil do
		task.wait(0.5)
		Settings = readSettings()
	end
	hideBootPanel()
	print("[Dropper] Settings received, booting.")
end

local DropPerDeath = 5_000
-- Instant respawn is enabled by default for every alt. Set this to false in
-- Settings to keep the game's normal respawn behavior.
local instantRespawnEnabled = Settings.InstantRespawn ~= false
-- Alt count is just the size of AccountUserIds. No separate AccountCount.
local effectiveAccountCount = #Settings.AccountUserIds
if effectiveAccountCount <= 0 then
	showBootPanel("> DROPPER :: NO ALTS", "AccountUserIds is empty. Add alt UserIds to Loader, then rejoin.")
	return
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
	showBootPanel("> DROPPER :: NOT IN LIST", player.Name .. " (UserId " .. tostring(player.UserId) .. ") is not in Loader AccountUserIds and is not the Host. Add this UserId to Loader, then rejoin.")
	return
end
-- Total deaths first, then split across alts. Ceil per-alt would overshoot
-- by up to (altCount - 1) extra deaths, so only the first `extraAlts`
-- alts do one more and the combined total lands exactly on target.
local totalDeathsNeeded = math.ceil(Settings.TargetDrop / DropPerDeath)
local basePerAlt = math.floor(totalDeathsNeeded / effectiveAccountCount)
local extraAlts = totalDeathsNeeded % effectiveAccountCount
local function deathsNeededFor(index: number): number
	if index <= extraAlts then return basePerAlt + 1 end
	return basePerAlt
end
local myDeathsNeeded = if myAccountIndex ~= nil then deathsNeededFor(myAccountIndex :: number) else basePerAlt
local projectedTotal = totalDeathsNeeded * DropPerDeath
local totalDrops = totalDeathsNeeded

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

local TweenService = game:GetService("TweenService")

-- ============================================================
-- Studs theme helpers
-- ============================================================
local STUD_DENSE = "rbxassetid://92521981645530"
local FONT = Enum.Font.FredokaOne

local function addPressFeedback(button)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local function scaleTo(target)
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Scale = target }):Play()
	end
	button.MouseEnter:Connect(function() scaleTo(1.06) end)
	button.MouseLeave:Connect(function() scaleTo(1) end)
	button.MouseButton1Down:Connect(function() scaleTo(0.94) end)
	button.MouseButton1Up:Connect(function() scaleTo(1.06) end)
end

local function applyStuds(parent: Instance, tileSize: number, transparency: number?, rotation: number?)
	local overlay = Instance.new("ImageLabel")
	overlay.Name = "Studs"
	overlay.BackgroundTransparency = 1
	overlay.Image = STUD_DENSE
	overlay.ImageTransparency = transparency or 0.55
	overlay.ScaleType = Enum.ScaleType.Tile
	overlay.TileSize = UDim2.fromOffset(tileSize, tileSize)
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.ZIndex = (parent :: GuiObject).ZIndex + 1
	overlay.Parent = parent
	if rotation then
		local g = Instance.new("UIGradient")
		g.Rotation = rotation
		g.Parent = overlay
	end
	return overlay
end

local function applyBevel(base: GuiObject, faceColor: Color3, faceHeight: number, flat: boolean?)
	base.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = base
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.AnchorPoint = Vector2.new(0, 0)
	face.Size = UDim2.new(1, 0, faceHeight, 0)
	face.ZIndex = base.ZIndex + 1
	face.Parent = base
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	if flat then
		grad.Color = ColorSequence.new(faceColor)
	else
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.1, faceColor:Lerp(Color3.new(1, 1, 1), 0.35)),
			ColorSequenceKeypoint.new(1, faceColor),
		})
	end
	grad.Parent = face
	return face
end

local function styleGlyph(label: TextLabel, thickness: number?)
	label.Font = FONT
	label.TextColor3 = Color3.new(1, 1, 1)
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = thickness or 2.5
	s.Parent = label
end

local function tweenFill(fill: Frame, progress: number, color: Color3?)
	local target = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
	pcall(function()
		local props: {[string]: any} = { Size = target }
		if color then props.BackgroundColor3 = color end
		TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	end)
end

local function phaseAccent(phase: string): (Color3, Color3)
	if phase == "Done" then
		return Color3.fromRGB(57, 255, 140), Color3.fromRGB(12, 40, 24)
	elseif phase == "Killing" or phase == "Dropping" then
		return Color3.fromRGB(255, 176, 0), Color3.fromRGB(48, 32, 8)
	elseif phase == "Teleporting" or phase == "Syncing" or phase == "Respawning" then
		return Color3.fromRGB(0, 255, 200), Color3.fromRGB(8, 48, 40)
	elseif phase == "Recovering" then
		return Color3.fromRGB(255, 200, 80), Color3.fromRGB(48, 36, 10)
	end
	return Color3.fromRGB(90, 140, 110), Color3.fromRGB(10, 18, 12)
end

local function makeDraggableFrom(handle: GuiObject, frame: Frame)
	local dragging = false
	local dragStart: Vector3? = nil
	local startPos: UDim2? = nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)
	handle.InputEnded:Connect(function(input)
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

local function addToggleKey(gui: ScreenGui, frame: Frame, key: Enum.KeyCode)
	pcall(function()
		UIS.InputBegan:Connect(function(input, processed)
			if processed then return end
			if input.KeyCode == key then
				frame.Visible = not frame.Visible
			end
		end)
	end)
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
	resetsTotal = myDeathsNeeded,
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
local localAltDot: Frame? = nil
local localProgressFill: Frame? = nil
local localProgressLabel: TextLabel? = nil
local localHeaderSub: TextLabel? = nil
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

	-- Hacker terminal card: near-black shell, phosphor accents, crisp hierarchy.
	local COL_BG = Color3.fromRGB(8, 13, 10)
	local COL_HEADER = Color3.fromRGB(12, 19, 15)
	local COL_ROW = Color3.fromRGB(13, 20, 16)
	local COL_TRACK = Color3.fromRGB(16, 26, 20)
	local COL_BORDER = Color3.fromRGB(44, 82, 60)
	local COL_ACCENT = Color3.fromRGB(57, 255, 140)
	local COL_TEXT = Color3.fromRGB(228, 246, 233)
	local COL_DIM = Color3.fromRGB(130, 160, 140)
	local COL_MUTED = Color3.fromRGB(98, 128, 108)

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.new(0, 360, 0, 404)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundColor3 = COL_BG
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.ClipsDescendants = true
	frame.Parent = ScreenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COL_BORDER
	stroke.Thickness = 1
	stroke.Transparency = 0
	stroke.Parent = frame

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 64)
	header.BackgroundColor3 = COL_HEADER
	header.BorderSizePixel = 0
	header.Parent = frame
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 10)
	headerCorner.Parent = header
	local headerLine = Instance.new("Frame")
	headerLine.Size = UDim2.new(1, 0, 0, 1)
	headerLine.Position = UDim2.new(0, 0, 1, -1)
	headerLine.BackgroundColor3 = Color3.fromRGB(30, 52, 40)
	headerLine.BorderSizePixel = 0
	headerLine.Parent = header

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Size = UDim2.new(0, 40, 0, 40)
	avatar.Position = UDim2.new(0, 14, 0, 12)
	avatar.BackgroundColor3 = COL_TRACK
	avatar.BorderSizePixel = 0
	avatar.Image = ""
	avatar.Parent = header
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0, 8)
	avatarCorner.Parent = avatar
	local avatarRing = Instance.new("UIStroke")
	avatarRing.Color = COL_BORDER
	avatarRing.Thickness = 1.5
	avatarRing.Transparency = 0
	avatarRing.Parent = avatar

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -160, 0, 18)
	nameLabel.Position = UDim2.new(0, 66, 0, 11)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name
	nameLabel.TextColor3 = COL_TEXT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Font = Enum.Font.Code
	nameLabel.TextSize = 16
	nameLabel.Parent = header

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -160, 0, 14)
	subLabel.Position = UDim2.new(0, 66, 0, 32)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = string.format("alt #%s  |  %s  |  %s alts", tostring(myAccountIndex or "?"), tostring(Settings.Mode), tostring(effectiveAccountCount))
	subLabel.TextColor3 = COL_DIM
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.TextTruncate = Enum.TextTruncate.AtEnd
	subLabel.Font = Enum.Font.Code
	subLabel.TextSize = 12
	subLabel.Parent = header
	localHeaderSub = subLabel

	local minimize = Instance.new("TextButton")
	minimize.Name = "Minimize"
	minimize.AnchorPoint = Vector2.new(1, 0)
	minimize.Position = UDim2.new(1, -12, 0, 10)
	minimize.Size = UDim2.new(0, 22, 0, 22)
	minimize.BackgroundColor3 = COL_ROW
	minimize.Text = "–"
	minimize.TextColor3 = COL_DIM
	minimize.Font = Enum.Font.Code
	minimize.TextSize = 14
	minimize.BorderSizePixel = 0
	minimize.AutoButtonColor = true
	minimize.Parent = header
	local minimizeCorner = Instance.new("UICorner")
	minimizeCorner.CornerRadius = UDim.new(0, 6)
	minimizeCorner.Parent = minimize
	local minimizeStroke = Instance.new("UIStroke")
	minimizeStroke.Color = COL_BORDER
	minimizeStroke.Thickness = 1
	minimizeStroke.Transparency = 0.2
	minimizeStroke.Parent = minimize

	local pill = Instance.new("Frame")
	pill.Name = "PhasePill"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -14, 0, 42)
	pill.Size = UDim2.new(0, 8, 0, 8)
	pill.BackgroundColor3 = COL_MUTED
	pill.BorderSizePixel = 0
	pill.Parent = header
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = pill
	localAltDot = pill

	local phaseDotLabel = Instance.new("TextLabel")
	phaseDotLabel.Name = "PhaseWord"
	phaseDotLabel.AnchorPoint = Vector2.new(1, 0)
	phaseDotLabel.Position = UDim2.new(1, -30, 0, 39)
	phaseDotLabel.Size = UDim2.new(0, 140, 0, 14)
	phaseDotLabel.BackgroundTransparency = 1
	phaseDotLabel.Text = "STARTING"
	phaseDotLabel.TextXAlignment = Enum.TextXAlignment.Right
	phaseDotLabel.TextColor3 = COL_DIM
	phaseDotLabel.Font = Enum.Font.Code
	phaseDotLabel.TextSize = 11
	phaseDotLabel.Parent = header

	local progressTitle = Instance.new("TextLabel")
	progressTitle.Size = UDim2.new(1, -140, 0, 14)
	progressTitle.Position = UDim2.new(0, 14, 0, 76)
	progressTitle.BackgroundTransparency = 1
	progressTitle.Text = "PROGRESS"
	progressTitle.TextXAlignment = Enum.TextXAlignment.Left
	progressTitle.TextColor3 = COL_MUTED
	progressTitle.Font = Enum.Font.Code
	progressTitle.TextSize = 11
	progressTitle.Parent = frame

	local progressCount = Instance.new("TextLabel")
	progressCount.Name = "ProgressCount"
	progressCount.AnchorPoint = Vector2.new(1, 0)
	progressCount.Position = UDim2.new(1, -14, 0, 75)
	progressCount.Size = UDim2.new(0, 200, 0, 16)
	progressCount.BackgroundTransparency = 1
	progressCount.Text = "0 / 0"
	progressCount.TextXAlignment = Enum.TextXAlignment.Right
	progressCount.TextColor3 = COL_TEXT
	progressCount.Font = Enum.Font.Code
	progressCount.TextSize = 13
	progressCount.Parent = frame
	localProgressLabel = progressCount

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -28, 0, 10)
	track.Position = UDim2.new(0, 14, 0, 98)
	track.BackgroundColor3 = COL_TRACK
	track.BorderSizePixel = 0
	track.Parent = frame
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 5)
	trackCorner.Parent = track
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = COL_BORDER
	trackStroke.Thickness = 1
	trackStroke.Transparency = 0.4
	trackStroke.Parent = track
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = COL_ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fill
	local fillGrad = Instance.new("UIGradient")
	fillGrad.Rotation = 0
	fillGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 255, 190)),
		ColorSequenceKeypoint.new(1, COL_ACCENT),
	})
	fillGrad.Parent = fill
	localProgressFill = fill

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -28, 0, 224)
	content.Position = UDim2.new(0, 14, 0, 120)
	content.BackgroundTransparency = 1
	content.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	local setters: {[string]: (string) -> ()} = {}
	local phaseWord: TextLabel? = header:FindFirstChild("PhaseWord") :: TextLabel?
	local function addRow(key: string, prefix: string, order: number)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundColor3 = COL_ROW
		row.BorderSizePixel = 0
		row.LayoutOrder = order
		row.Parent = content
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row
		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.new(0, 100, 1, 0)
		keyLabel.Position = UDim2.new(0, 12, 0, 0)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Text = prefix:upper()
		keyLabel.TextColor3 = COL_MUTED
		keyLabel.TextXAlignment = Enum.TextXAlignment.Left
		keyLabel.Font = Enum.Font.Code
		keyLabel.TextSize = 11
		keyLabel.Parent = row
		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(1, -124, 1, 0)
		valueLabel.Position = UDim2.new(0, 112, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = "--"
		valueLabel.TextColor3 = COL_TEXT
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
		valueLabel.Font = Enum.Font.Code
		valueLabel.TextSize = 13
		valueLabel.Parent = row
		setters[key] = function(value: string)
			valueLabel.Text = value
			if key == "phase" and phaseWord then
				phaseWord.Text = value:upper()
			end
		end
	end

	addRow("phase", "phase", 1)
	addRow("resets", "resets", 2)
	addRow("dropOwn", "drop_own", 3)
	addRow("dropGlobal", "drop_total", 4)
	addRow("elapsed", "elapsed", 5)
	addRow("eta", "eta", 6)
	addRow("last", "last", 7)

	local footer = Instance.new("TextLabel")
	footer.Size = UDim2.new(1, -28, 0, 14)
	footer.Position = UDim2.new(0, 14, 1, -22)
	footer.BackgroundTransparency = 1
	footer.Text = "auto-drop running_"
	footer.TextColor3 = COL_MUTED
	footer.Font = Enum.Font.Code
	footer.TextSize = 11
	footer.TextXAlignment = Enum.TextXAlignment.Center
	footer.Parent = frame

	local minimize = Instance.new("TextButton")
	minimize.Name = "Minimize"
	minimize.AnchorPoint = Vector2.new(1, 0)
	minimize.Position = UDim2.new(1, -8, 0, 8)
	minimize.Size = UDim2.new(0, 22, 0, 22)
	minimize.BackgroundColor3 = Color3.fromRGB(4, 12, 8)
	minimize.Text = "-"
	minimize.TextColor3 = Color3.fromRGB(57, 255, 140)
	minimize.Font = Enum.Font.Code
	minimize.TextSize = 14
	minimize.BorderSizePixel = 0
	minimize.AutoButtonColor = true
	minimize.Parent = header
	local minimizeCorner = Instance.new("UICorner")
	minimizeCorner.CornerRadius = UDim.new(0, 2)
	minimizeCorner.Parent = minimize
	local minimizeStroke = Instance.new("UIStroke")
	minimizeStroke.Color = Color3.fromRGB(57, 255, 140)
	minimizeStroke.Thickness = 1
	minimizeStroke.Transparency = 0.4
	minimizeStroke.Parent = minimize

	task.spawn(function()
		local thumb: string? = nil
		pcall(function()
			thumb = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if thumb ~= nil and avatar.Parent ~= nil then avatar.Image = (thumb :: string) end
	end)

	task.spawn(function()
		local on = true
		while frame.Parent ~= nil do
			pcall(function()
				footer.Text = if on then "> auto-drop running_" else "> auto-drop running "
			end)
			on = not on
			task.wait(0.5)
		end
	end)

	makeDraggableFrom(header, frame)
	addToggleKey(ScreenGui, frame, Enum.KeyCode.RightShift)
	pcall(function()
		local scale = Instance.new("UIScale")
		scale.Scale = 0.92
		scale.Parent = frame
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	local collapsed = false
	local fullSize = UDim2.new(0, 360, 0, 404)
	minimize.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		minimize.Text = if collapsed then "+" else "–"
		progressTitle.Visible = not collapsed
		progressCount.Visible = not collapsed
		track.Visible = not collapsed
		content.Visible = not collapsed
		footer.Visible = not collapsed
		pill.Visible = not collapsed
		phaseDotLabel.Visible = not collapsed
		pcall(function()
			TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = if collapsed then UDim2.new(0, 360, 0, 64) else fullSize,
			}):Play()
		end)
	end)
	localSetters = setters
end

-- ============================================================
-- Host admin panel (optional)
-- ============================================================
local hostCells: {[number]: {[string]: TextLabel}}? = nil
local hostBars: {[number]: Frame}? = nil
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
local hostAvatars: {[number]: ImageLabel}? = nil
local hostAvatarRings: {[number]: UIStroke}? = nil
local hostOverallFill: Frame? = nil
local hostOverallLabel: TextLabel? = nil
local hostOnlineLabel: TextLabel? = nil
local hostRateLabel: TextLabel? = nil
local hostRowFrames: {[number]: Frame}? = nil
local hostSearchQuery: string = ""
local clientCashStart: number? = nil
local clientCashNow: number? = nil
local clientCachedName: string? = nil

-- ============================================================
-- Control (host buttons) + Streamer Mode shared state.
-- Same process via _G; across clients the host also broadcasts
-- a chat command (private server recommended, it is visible).
-- ============================================================
local CONTROL_CMD_PREFIX = "[DROPPER_CMD]"
local CONTROL_VALID: {[string]: boolean} = {
	AUTO = true, STOP = true,
	TP_HOST = true, CIRCLE_HOST = true,
	TP_CLIENT = true, CIRCLE_CLIENT = true,
}
-- CLIENT-ONLY: no server involved. Each client keeps its own mode in _G.
-- Host button stages a user-typed chat command (button alone cannot reach
-- other clients: code-sent chat never delivers). Host presses Enter once
-- and every alt applies it via setupControlListener below.
local function readControlModeRaw(): string?
	local found: string? = nil
	pcall(function()
		local g = _G :: any
		local c = g.DropperControl
		if type(c) == "table" and type(c.Mode) == "string" then
			found = c.Mode
		end
	end)
	return found
end
local function getControlMode(): string
	-- Controls removed: alts always run AUTO.
	return "AUTO"
end
local function writeControlMode(mode: string)
	pcall(function()
		local g = _G :: any
		g.DropperControl = { Mode = mode, At = os.clock() }
	end)
end
local function prefillChatBoxForManualSend(commandText: string)
	pcall(function()
		local tcs = game:GetService("TextChatService")
		local config = tcs:FindFirstChildOfClass("ChatInputBarConfiguration")
		local box: TextBox? = nil
		if config then
			pcall(function() box = (config :: any).TextBox end)
		end
		if box and (box :: TextBox).Parent ~= nil then
			(box :: TextBox).Text = commandText
			pcall(function() (box :: TextBox):CaptureFocus() end)
		end
	end)
	pcall(function()
		local g = (_G :: any)
		local clipboardFn = rawget(g, "setclipboard") or rawget(g, "toclipboard")
		if type(clipboardFn) == "function" then (clipboardFn :: any)(commandText) end
		pcall(function()
			local gg = (getgenv :: any)()
			local fn = gg and (rawget(gg, "setclipboard") or rawget(gg, "toclipboard"))
			if type(fn) == "function" then fn(commandText) end
		end)
	end)
end
local function broadcastControlMode(mode: string)
	writeControlMode(mode)
	-- CLIENT-ONLY: no auto SendAsync (code-sent chat never reaches other
	-- clients and would only spam the host's own chat window). Stage the
	-- command in the host's chat box + clipboard: host presses Enter once
	-- and every alt picks it up via setupControlListener.
	prefillChatBoxForManualSend(CONTROL_CMD_PREFIX .. mode)
	print("[Dropper] Control mode -> " .. mode .. " (press Enter in chat to sync alts)")
end
local controlListenerStarted = false
local function setupControlListener()
	if controlListenerStarted then return end
	controlListenerStarted = true
	local function onCommandText(msg: string, fromUserId: number?)
		local mode = string.match(msg, "%[DROPPER_CMD%](%S+)")
		if mode == nil then return end
		if not CONTROL_VALID[mode] then return end
		if fromUserId ~= nil and HOST_USER_ID ~= nil and fromUserId ~= HOST_USER_ID then return end
		writeControlMode(mode)
		print("[Dropper] Control cmd from host: " .. mode)
	end
	pcall(function()
		local tcs: any = game:GetService("TextChatService")
		tcs.MessageReceived:Connect(function(textMsg)
			local txt: string? = nil
			local uid: number? = nil
			pcall(function() txt = textMsg.Text end)
			pcall(function()
				local src = textMsg.TextSource
				if src ~= nil then uid = src.UserId end
			end)
			if txt ~= nil then onCommandText(txt, uid) end
		end)
	end)
	pcall(function()
		if HOST_USER_ID ~= nil then
			local hostPlayer = Players:GetPlayerByUserId(HOST_USER_ID)
			if hostPlayer then
				hostPlayer.Chatted:Connect(function(msg)
					onCommandText(msg, hostPlayer.UserId)
				end)
			end
		end
		Players.PlayerAdded:Connect(function(p)
			if HOST_USER_ID ~= nil and p.UserId == HOST_USER_ID then
				p.Chatted:Connect(function(msg)
					onCommandText(msg, p.UserId)
				end)
			end
		end)
	end)
end
-- ============================================================
-- Fake chat (CLIENT-ONLY, no server): white bubble above a head like
-- real chat, but local to this client. Host types text, sees it above
-- its own head; clicking that bubble (or SEND) pops the same text above
-- every alt head as seen on this client. Nothing enters real chat.
-- ============================================================
local FAKE_CHAT_DURATION = 6
local function findHeadForBubble(character: Model?): BasePart?
	if not character then return nil end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end
local function showFakeBubble(character: Model?, text: string, clickable: boolean?, onClicked: (() -> ())?)
	if not character then return end
	local adornee = findHeadForBubble(character)
	if not adornee then return end
	local clean = string.gsub(text, "^%s+", "")
	clean = string.gsub(clean, "%s+$", "")
	if #clean == 0 or #clean > 120 then return end
	pcall(function()
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BillboardGui") and d.Name == "DropperFakeChat" then d:Destroy() end
		end
	end)
	local gui = Instance.new("BillboardGui")
	gui.Name = "DropperFakeChat"
	gui.Adornee = adornee
	gui.Size = UDim2.new(0, 220, 0, 64)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local bubble: GuiObject
	if clickable then
		local btn = Instance.new("TextButton")
		btn.Text = ""
		btn.AutoButtonColor = true
		btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		btn.BorderSizePixel = 0
		btn.Size = UDim2.new(1, 0, 0, 44)
		btn.Parent = gui
		bubble = btn
		btn.MouseButton1Click:Connect(function()
			print("[Dropper] Fake bubble clicked, re-showing on alts: " .. clean)
			if onClicked then pcall(onClicked) end
		end)
	else
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, 0, 0, 44)
		frame.Parent = gui
		bubble = frame
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(30, 30, 30)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.15
	stroke.Parent = bubble
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Position = UDim2.new(0, 8, 0, 4)
	label.Text = clean
	label.TextColor3 = Color3.fromRGB(20, 20, 20)
	label.TextSize = 14
	label.TextWrapped = true
	label.Font = Enum.Font.Gotham
	label.Parent = bubble
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0)
	tail.Position = UDim2.new(0.5, 0, 0, 42)
	tail.Size = UDim2.new(0, 14, 0, 14)
	tail.Rotation = 45
	tail.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tail.BorderSizePixel = 0
	tail.Parent = gui
	local tailStroke = Instance.new("UIStroke")
	tailStroke.Color = Color3.fromRGB(30, 30, 30)
	tailStroke.Thickness = 1.5
	tailStroke.Transparency = 0.15
	tailStroke.Parent = tail
	gui.Parent = character
	print("[Dropper] Fake chat: \"" .. clean .. "\"")
	task.delay(FAKE_CHAT_DURATION, function()
		pcall(function() gui:Destroy() end)
	end)
end
local function showFakeOnAlts(text: string)
	pcall(function()
		for _, uid in ipairs(Settings.AccountUserIds) do
			local altPlayer = Players:GetPlayerByUserId(uid)
			local altChar = altPlayer and altPlayer.Character
			if altChar and altChar ~= player.Character then
				showFakeBubble(altChar, text, false, nil)
			end
		end
	end)
end
local function broadcastFakeChat(text: string)
	local clean = string.gsub(text, "^%s+", "")
	clean = string.gsub(clean, "%s+$", "")
	if #clean == 0 then return end
	if #clean > 120 then clean = string.sub(clean, 1, 120) end
	-- CLIENT-ONLY: bubble above my own head (clickable) + same text above
	-- every alt head as seen on THIS client. Clicking my bubble re-pops
	-- the alt bubbles. Nothing is sent anywhere.
	showFakeOnAlts(clean)
	if player.Character then
		showFakeBubble(player.Character, clean, true, function()
			showFakeOnAlts(clean)
		end)
	end
end
-- Inline root readers (self-contained: getRoot is defined later).
local function controlGetHostRoot(): BasePart?
	if HOST_USER_ID == nil then return nil end
	local h = Players:GetPlayerByUserId(HOST_USER_ID)
	local ch = h and h.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then return r end
	return nil
end
local function controlGetClientRoot(): BasePart?
	local cId: any = Settings.ClientUserId
	if type(cId) ~= "number" then return nil end
	local c = Players:GetPlayerByUserId(cId)
	local ch = c and c.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then return r end
	return nil
end
local function controlSnapTo(character: Model, target: CFrame): boolean
	local ok = pcall(function()
		character:PivotTo(target)
		local maybeRoot: Instance? = character:FindFirstChild("HumanoidRootPart")
		if maybeRoot and maybeRoot:IsA("BasePart") then
			maybeRoot.AssemblyLinearVelocity = Vector3.zero
			maybeRoot.AssemblyAngularVelocity = Vector3.zero
		end
	end)
	return ok
end
-- Streamer Mode flags (host-local hiding, _G-backed so reloads keep them).
local function isStreamerOn(): boolean
	local on = false
	pcall(function()
		on = ((_G :: any).DropperStreamerOn == true)
	end)
	return on
end
local function isHideClientNameOn(): boolean
	local on = false
	pcall(function()
		on = ((_G :: any).DropperHideClientOn == true)
	end)
	return on
end
local function resolveClientName(): string?
	if clientCachedName ~= nil then return clientCachedName end
	local nm: string? = nil
	pcall(function()
		local cp = Players:GetPlayerByUserId(Settings.ClientUserId)
		if cp then nm = cp.Name end
	end)
	if nm == nil then
		pcall(function()
			nm = Players:GetNameFromUserIdAsync(Settings.ClientUserId)
		end)
	end
	if nm ~= nil then clientCachedName = nm end
	return nm
end
local function setNametagsForCharacter(character: Model, visible: boolean)
	pcall(function()
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BillboardGui") then
				local n = string.lower(d.Name)
				if string.find(n, "nametag", 1, true) or string.find(n, "name", 1, true) or string.find(n, "overhead", 1, true) then
					(d :: BillboardGui).Enabled = visible
				end
			end
		end
	end)
end
local function applyStreamerNametags()
	local hide = isStreamerOn()
	for _, uid in ipairs(Settings.AccountUserIds) do
		local p = Players:GetPlayerByUserId(uid)
		local ch = p and p.Character
		if ch then setNametagsForCharacter(ch, not hide) end
	end
	if HOST_USER_ID ~= nil then
		local h = Players:GetPlayerByUserId(HOST_USER_ID)
		local ch = h and h.Character
		if ch then setNametagsForCharacter(ch, not hide) end
	end
end
local function findLeaderboardScroll(): ScrollingFrame?
	local found: ScrollingFrame? = nil
	pcall(function()
		local pg = player:FindFirstChildOfClass("PlayerGui")
		if not pg then return end
		local lb = pg:FindFirstChild("LeaderboardGui", true)
		if not lb then return end
		local fr = lb:FindFirstChild("Frame", true)
		local scope: Instance = fr or lb
		local sc = scope:FindFirstChild("ScrollingFrame", true)
		if sc and sc:IsA("ScrollingFrame") then found = sc end
	end)
	return found
end
local function isClientTemplate(t: Instance, clientName: string?): boolean
	if clientName == nil or clientName == "" then return false end
	local lowerClient = string.lower(clientName)
	local tn = string.lower(t.Name)
	if string.find(tn, lowerClient, 1, true) then return true end
	if string.find(tn, "player_", 1, true) then
		return string.find(tn, "player_" .. lowerClient, 1, true) ~= nil
	end
	local hit = false
	pcall(function()
		for _, d in ipairs(t:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				local txt = string.lower((d :: TextLabel).Text)
				if string.find(txt, lowerClient, 1, true) then hit = true break end
			end
		end
	end)
	return hit
end
local savedVisible: {[Instance]: boolean} = {}
local savedNameVisible: {[Instance]: boolean} = {}
local function applyLeaderboardPass()
	local sc = findLeaderboardScroll()
	if sc == nil then return end
	local scroll: ScrollingFrame = sc
	local hide = isStreamerOn()
	local cname = resolveClientName()
	pcall(function()
		for _, row in ipairs(scroll:GetChildren()) do
			if row:IsA("GuiObject") then
				if savedVisible[row] == nil then savedVisible[row] = (row :: GuiObject).Visible end
				if hide then
					(row :: GuiObject).Visible = isClientTemplate(row, cname)
				else
					local orig = savedVisible[row]
					if orig == nil then
						(row :: GuiObject).Visible = true
					else
						(row :: GuiObject).Visible = orig
					end
				end
			end
		end
	end)
end
local function findClientNameLabel(clientTemplate: Instance): GuiObject?
	local found: GuiObject? = nil
	pcall(function()
		local fr = clientTemplate:FindFirstChild("Frame", false)
		local scope: Instance = fr or clientTemplate
		local dn = scope:FindFirstChild("DisplayName", true)
		if dn and dn:IsA("GuiObject") then found = dn :: GuiObject end
	end)
	return found
end
local function applyHideClientNamePass()
	local hide = isHideClientNameOn()
	-- Overhead nametag first (same hiding as alts): never blocked by
	-- leaderboard lookup, so it works even when the leaderboard is absent.
	pcall(function()
		local cId: any = Settings.ClientUserId
		if type(cId) == "number" then
			local cp = Players:GetPlayerByUserId(cId)
			local ch = cp and cp.Character
			if ch then setNametagsForCharacter(ch, not hide) end
		end
	end)
	local sc = findLeaderboardScroll()
	if sc == nil then return end
	local scroll: ScrollingFrame = sc
	local cname = resolveClientName()
	pcall(function()
		for _, row in ipairs(scroll:GetChildren()) do
			if row:IsA("GuiObject") and isClientTemplate(row, cname) then
				local lbl = findClientNameLabel(row)
				if lbl then
					if savedNameVisible[lbl] == nil then savedNameVisible[lbl] = (lbl :: GuiObject).Visible end
					if hide then
						(lbl :: GuiObject).Visible = false
					else
						local orig = savedNameVisible[lbl]
						if orig == nil then
							(lbl :: GuiObject).Visible = true
						else
							(lbl :: GuiObject).Visible = orig
						end
					end
				end
			end
		end
	end)
end
local function setStreamerMode(on: boolean)
	pcall(function() (_G :: any).DropperStreamerOn = on end)
	if not on then
		pcall(function()
			for inst, v in pairs(savedVisible) do
				pcall(function() (inst :: GuiObject).Visible = v end)
			end
		end)
	end
	applyStreamerNametags()
	applyLeaderboardPass()
	print("[Dropper] Streamer Mode " .. (if on then "ON" else "OFF"))
end
local function setHideClientName(on: boolean)
	pcall(function() (_G :: any).DropperHideClientOn = on end)
	if not on then
		pcall(function()
			for inst, v in pairs(savedNameVisible) do
				pcall(function() (inst :: GuiObject).Visible = v end)
			end
		end)
		pcall(function()
			local cId: any = Settings.ClientUserId
			if type(cId) == "number" then
				local cp = Players:GetPlayerByUserId(cId)
				local ch = cp and cp.Character
				-- Only restore when Streamer Mode is not also hiding.
				-- Client is not alt/host so no overlap, restore unconditionally.
				if ch then setNametagsForCharacter(ch, true) end
			end
		end)
	end
	applyHideClientNamePass()
	print("[Dropper] Hide Client Name " .. (if on then "ON" else "OFF"))
end
local streamerEnforcerStarted = false
local function ensureStreamerEnforcer()
	if streamerEnforcerStarted then return end
	streamerEnforcerStarted = true
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok = pcall(function()
				if isStreamerOn() then
					applyStreamerNametags()
					applyLeaderboardPass()
				end
				if isHideClientNameOn() then
					applyHideClientNamePass()
				end
			end)
			if not ok then task.wait(1) end
		end
	end)
	pcall(function()
		for _, uid in ipairs(Settings.AccountUserIds) do
			local p = Players:GetPlayerByUserId(uid)
			if p then
				p.CharacterAdded:Connect(function(ch: Model)
					task.wait(1)
					if isStreamerOn() then setNametagsForCharacter(ch, false) end
				end)
			end
		end
		local cId: any = Settings.ClientUserId
		if type(cId) == "number" then
			local cp = Players:GetPlayerByUserId(cId)
			if cp then
				cp.CharacterAdded:Connect(function(ch: Model)
					task.wait(1)
					if isHideClientNameOn() then setNametagsForCharacter(ch, false) end
				end)
			end
		end
		Players.PlayerAdded:Connect(function(p: Player)
			local watched = false
			for _, uid in ipairs(Settings.AccountUserIds) do if uid == p.UserId then watched = true break end end
			if HOST_USER_ID ~= nil and p.UserId == HOST_USER_ID then watched = true end
			if watched then
				p.CharacterAdded:Connect(function(ch: Model)
					task.wait(1)
					if isStreamerOn() then setNametagsForCharacter(ch, false) end
				end)
			end
			if type(Settings.ClientUserId) == "number" and p.UserId == (Settings.ClientUserId :: number) then
				p.CharacterAdded:Connect(function(ch: Model)
					task.wait(1)
					if isHideClientNameOn() then setNametagsForCharacter(ch, false) end
				end)
			end
		end)
	end)
end

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

	local COL_BG = Color3.fromRGB(8, 13, 10)
	local COL_HEADER = Color3.fromRGB(12, 19, 15)
	local COL_ROW = Color3.fromRGB(13, 20, 16)
	local COL_ROW_ALT = Color3.fromRGB(11, 17, 14)
	local COL_TRACK = Color3.fromRGB(16, 26, 20)
	local COL_BORDER = Color3.fromRGB(44, 82, 60)
	local COL_ACCENT = Color3.fromRGB(57, 255, 140)
	local COL_TEXT = Color3.fromRGB(228, 246, 233)
	local COL_DIM = Color3.fromRGB(130, 160, 140)
	local COL_MUTED = Color3.fromRGB(98, 128, 108)
	local COL_DARKTEXT = Color3.fromRGB(6, 20, 12)

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.new(0, 740, 0, 500)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundColor3 = COL_BG
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.ClipsDescendants = true
	frame.Parent = ScreenGui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 10)
	frameCorner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COL_BORDER
	stroke.Thickness = 1
	stroke.Transparency = 0
	stroke.Parent = frame

	local title = Instance.new("Frame")
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundColor3 = COL_HEADER
	title.BorderSizePixel = 0
	title.Parent = frame
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 10)
	titleCorner.Parent = title
	local titleAccent = Instance.new("Frame")
	titleAccent.Size = UDim2.new(0, 3, 1, -20)
	titleAccent.Position = UDim2.new(0, 14, 0, 10)
	titleAccent.BackgroundColor3 = COL_ACCENT
	titleAccent.BorderSizePixel = 0
	titleAccent.Parent = title
	local titleAccentCorner = Instance.new("UICorner")
	titleAccentCorner.CornerRadius = UDim.new(1, 0)
	titleAccentCorner.Parent = titleAccent
	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(1, -280, 1, 0)
	titleText.Position = UDim2.new(0, 28, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.Text = "DROPPER // HOST CONSOLE"
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.TextColor3 = COL_TEXT
	titleText.Font = Enum.Font.Code
	titleText.TextSize = 15
	titleText.Parent = title
	local titleLine = Instance.new("Frame")
	titleLine.Size = UDim2.new(1, 0, 0, 1)
	titleLine.Position = UDim2.new(0, 0, 1, -1)
	titleLine.BackgroundColor3 = Color3.fromRGB(30, 52, 40)
	titleLine.BorderSizePixel = 0
	titleLine.Parent = title
	local versionBadge = Instance.new("TextLabel")
	versionBadge.AnchorPoint = Vector2.new(1, 0.5)
	versionBadge.Position = UDim2.new(1, -106, 0, 24)
	versionBadge.Size = UDim2.new(0, 46, 0, 20)
	versionBadge.BackgroundColor3 = COL_ROW
	versionBadge.BackgroundTransparency = 0
	versionBadge.Text = "SDMS"
	versionBadge.TextColor3 = COL_DIM
	versionBadge.Font = Enum.Font.Code
	versionBadge.TextSize = 11
	versionBadge.BorderSizePixel = 0
	versionBadge.Parent = frame
	local versionCorner = Instance.new("UICorner")
	versionCorner.CornerRadius = UDim.new(0, 6)
	versionCorner.Parent = versionBadge
	local versionStroke = Instance.new("UIStroke")
	versionStroke.Color = COL_BORDER
	versionStroke.Thickness = 1
	versionStroke.Transparency = 0.2
	versionStroke.Parent = versionBadge
	local liveDot = Instance.new("Frame")
	liveDot.AnchorPoint = Vector2.new(1, 0.5)
	liveDot.Position = UDim2.new(1, -166, 0, 24)
	liveDot.Size = UDim2.new(0, 8, 0, 8)
	liveDot.BackgroundColor3 = COL_ACCENT
	liveDot.BorderSizePixel = 0
	liveDot.Parent = frame
	local liveDotCorner = Instance.new("UICorner")
	liveDotCorner.CornerRadius = UDim.new(1, 0)
	liveDotCorner.Parent = liveDot
	local minimizeBtn = Instance.new("TextButton")
	minimizeBtn.Name = "HostMinimize"
	minimizeBtn.AnchorPoint = Vector2.new(1, 0.5)
	minimizeBtn.Position = UDim2.new(1, -46, 0, 24)
	minimizeBtn.Size = UDim2.new(0, 24, 0, 24)
	minimizeBtn.BackgroundColor3 = COL_ROW
	minimizeBtn.BackgroundTransparency = 0
	minimizeBtn.Text = "–"
	minimizeBtn.TextColor3 = COL_DIM
	minimizeBtn.Font = Enum.Font.Code
	minimizeBtn.TextSize = 14
	minimizeBtn.BorderSizePixel = 0
	minimizeBtn.AutoButtonColor = true
	minimizeBtn.Parent = frame
	local minimizeBtnCorner = Instance.new("UICorner")
	minimizeBtnCorner.CornerRadius = UDim.new(0, 6)
	minimizeBtnCorner.Parent = minimizeBtn
	local minimizeBtnStroke = Instance.new("UIStroke")
	minimizeBtnStroke.Color = COL_BORDER
	minimizeBtnStroke.Thickness = 1
	minimizeBtnStroke.Transparency = 0.2
	minimizeBtnStroke.Parent = minimizeBtn
	local hideBtn = Instance.new("TextButton")
	hideBtn.Name = "HostHide"
	hideBtn.AnchorPoint = Vector2.new(1, 0.5)
	hideBtn.Position = UDim2.new(1, -14, 0, 24)
	hideBtn.Size = UDim2.new(0, 24, 0, 24)
	hideBtn.BackgroundColor3 = COL_ROW
	hideBtn.BackgroundTransparency = 0
	hideBtn.Text = "x"
	hideBtn.TextColor3 = COL_DIM
	hideBtn.Font = Enum.Font.Code
	hideBtn.TextSize = 14
	hideBtn.BorderSizePixel = 0
	hideBtn.AutoButtonColor = true
	hideBtn.Parent = frame
	local hideBtnCorner = Instance.new("UICorner")
	hideBtnCorner.CornerRadius = UDim.new(0, 6)
	hideBtnCorner.Parent = hideBtn
	local hideBtnStroke = Instance.new("UIStroke")
	hideBtnStroke.Color = COL_BORDER
	hideBtnStroke.Thickness = 1
	hideBtnStroke.Transparency = 0.2
	hideBtnStroke.Parent = hideBtn
	local showPill = Instance.new("TextButton")
	showPill.Name = "HostShow"
	showPill.AnchorPoint = Vector2.new(1, 0)
	showPill.Position = UDim2.new(1, -12, 0, 12)
	showPill.Size = UDim2.new(0, 170, 0, 32)
	showPill.BackgroundColor3 = COL_BG
	showPill.Text = "[ DROPPER :: SHOW ]"
	showPill.TextColor3 = COL_TEXT
	showPill.Font = Enum.Font.Code
	showPill.TextSize = 12
	showPill.BorderSizePixel = 0
	showPill.Visible = false
	showPill.AutoButtonColor = true
	showPill.Parent = ScreenGui
	local showPillCorner = Instance.new("UICorner")
	showPillCorner.CornerRadius = UDim.new(0, 8)
	showPillCorner.Parent = showPill
	local showPillStroke = Instance.new("UIStroke")
	showPillStroke.Color = COL_BORDER
	showPillStroke.Thickness = 1
	showPillStroke.Transparency = 0.1
	showPillStroke.Parent = showPill
	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -32, 0, 16)
	subtitle.Position = UDim2.new(0, 16, 0, 56)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = string.format("mode: %s   |   target: %s   |   alts: %s   |   [RightShift = hide]", tostring(Settings.Mode), comma(Settings.TargetDrop), comma(#Settings.AccountUserIds))
	subtitle.TextColor3 = COL_DIM
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Font = Enum.Font.Code
	subtitle.TextSize = 12
	subtitle.Parent = frame

	local function makeStatCard(xPos: number, width: number): (Frame, TextLabel, TextLabel)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, width, 0, 64)
		card.Position = UDim2.new(0, xPos, 0, 0)
		card.BackgroundColor3 = COL_ROW
		card.BorderSizePixel = 0
		card.Parent = frame
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card
		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = COL_BORDER
		cardStroke.Thickness = 1
		cardStroke.Transparency = 0.3
		cardStroke.Parent = card
		local micro = Instance.new("TextLabel")
		micro.Size = UDim2.new(1, -24, 0, 12)
		micro.Position = UDim2.new(0, 12, 0, 8)
		micro.BackgroundTransparency = 1
		micro.Text = "STAT"
		micro.TextXAlignment = Enum.TextXAlignment.Left
		micro.TextColor3 = COL_MUTED
		micro.Font = Enum.Font.Code
		micro.TextSize = 10
		micro.Parent = card
		local main = Instance.new("TextLabel")
		main.Size = UDim2.new(1, -24, 0, 20)
		main.Position = UDim2.new(0, 12, 0, 26)
		main.BackgroundTransparency = 1
		main.Text = "—"
		main.TextXAlignment = Enum.TextXAlignment.Left
		main.TextTruncate = Enum.TextTruncate.AtEnd
		main.TextColor3 = COL_TEXT
		main.Font = Enum.Font.Code
		main.TextSize = 15
		main.Parent = card
		return card, micro, main
	end
	local summary = Instance.new("Frame")
	summary.Size = UDim2.new(1, -32, 0, 64)
	summary.Position = UDim2.new(0, 16, 0, 80)
	summary.BackgroundTransparency = 1
	summary.BorderSizePixel = 0
	summary.Parent = frame
	local progressCard, progressMicro, progressMain = makeStatCard(0, 352)
	progressCard.Parent = summary
	progressMicro.Text = "OVERALL"
	progressMain.Text = "0%"
	hostOverallLabel = progressMain
	local overallTrack = Instance.new("Frame")
	overallTrack.Size = UDim2.new(1, -24, 0, 7)
	overallTrack.Position = UDim2.new(0, 12, 0, 49)
	overallTrack.BackgroundColor3 = COL_TRACK
	overallTrack.BorderSizePixel = 0
	overallTrack.Parent = progressCard
	local overallTrackCorner = Instance.new("UICorner")
	overallTrackCorner.CornerRadius = UDim.new(1, 0)
	overallTrackCorner.Parent = overallTrack
	local overallFill = Instance.new("Frame")
	overallFill.Size = UDim2.new(0, 0, 1, 0)
	overallFill.BackgroundColor3 = COL_ACCENT
	overallFill.BorderSizePixel = 0
	overallFill.Parent = overallTrack
	local overallFillCorner = Instance.new("UICorner")
	overallFillCorner.CornerRadius = UDim.new(1, 0)
	overallFillCorner.Parent = overallFill
	local overallFillGrad = Instance.new("UIGradient")
	overallFillGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 255, 190)),
		ColorSequenceKeypoint.new(1, COL_ACCENT),
	})
	overallFillGrad.Parent = overallFill
	hostOverallFill = overallFill
	local onlineCard, onlineMicro, onlineMain = makeStatCard(362, 156)
	onlineCard.Parent = summary
	onlineMicro.Text = "ONLINE"
	onlineMain.Text = "0/0"
	hostOnlineLabel = onlineMain
	local rateCard, rateMicro, rateMain = makeStatCard(528, 180)
	rateCard.Parent = summary
	rateMicro.Text = "PACE / ETA"
	rateMain.Font = Enum.Font.Code
	rateMain.TextSize = 13
	rateMain.Text = "—"
	hostRateLabel = rateMain
	-- Tabs: Alts + Time + Client.
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -32, 0, 32)
	tabBar.Position = UDim2.new(0, 16, 0, 154)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = frame

	local function makeTab(text: string, xPos: number): TextButton
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 110, 1, 0)
		b.Position = UDim2.new(0, xPos, 0, 0)
		b.BackgroundColor3 = COL_ROW
		b.Text = text
		b.TextColor3 = COL_DIM
		b.Font = Enum.Font.Code
		b.TextSize = 12
		b.BorderSizePixel = 0
		b.AutoButtonColor = true
		b.Parent = tabBar
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		local s = Instance.new("UIStroke")
		s.Color = COL_BORDER
		s.Thickness = 1
		s.Transparency = 0.3
		s.Parent = b
		return b
	end
	local altsTab = makeTab("ALTS", 0)
	altsTab.Name = "AltsTab"
	local timeTab = makeTab("TIME", 118)
	timeTab.Name = "TimeTab"
	local clientTab = makeTab("CLIENT", 236)
	clientTab.Name = "ClientTab"
	local settingsTab = makeTab("SETTINGS", 480)
	settingsTab.Name = "SettingsTab"
	local controlTab = makeTab("CONTROL", 598)
	controlTab.Name = "ControlTab"

	local altsPage = Instance.new("Frame")
	altsPage.Name = "AltsPage"
	altsPage.Size = UDim2.new(1, -32, 1, -212)
	altsPage.Position = UDim2.new(0, 16, 0, 196)
	altsPage.BackgroundTransparency = 1
	altsPage.Parent = frame

	local timePage = Instance.new("Frame")
	timePage.Name = "TimePage"
	timePage.Size = UDim2.new(1, -32, 1, -212)
	timePage.Position = UDim2.new(0, 16, 0, 196)
	timePage.BackgroundTransparency = 1
	timePage.Visible = false
	timePage.Parent = frame

	local clientPage = Instance.new("Frame")
	clientPage.Name = "ClientPage"
	clientPage.Size = UDim2.new(1, -32, 1, -212)
	clientPage.Position = UDim2.new(0, 16, 0, 196)
	clientPage.BackgroundTransparency = 1
	clientPage.Visible = false
	clientPage.Parent = frame

	local settingsPage = Instance.new("Frame")
	settingsPage.Name = "SettingsPage"
	settingsPage.Size = UDim2.new(1, -32, 1, -212)
	settingsPage.Position = UDim2.new(0, 16, 0, 196)
	settingsPage.BackgroundTransparency = 1
	settingsPage.Visible = false
	settingsPage.Parent = frame

	local controlPage = Instance.new("ScrollingFrame")
	controlPage.Name = "ControlPage"
	controlPage.Size = UDim2.new(1, -32, 1, -212)
	controlPage.Position = UDim2.new(0, 16, 0, 196)
	controlPage.BackgroundTransparency = 1
	controlPage.BorderSizePixel = 0
	controlPage.ScrollBarThickness = 3
	controlPage.ScrollBarImageColor3 = COL_ACCENT
	controlPage.CanvasSize = UDim2.new()
	controlPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
	controlPage.ScrollingDirection = Enum.ScrollingDirection.Y
	controlPage.Visible = false
	controlPage.Parent = frame

	local selectedTab = "Alts"
	local function selectTab(which: string)
		selectedTab = which
		altsPage.Visible = which == "Alts"
		timePage.Visible = which == "Time"
		clientPage.Visible = which == "Client"
		settingsPage.Visible = which == "Settings"
		controlPage.Visible = which == "Control"
		altsTab.BackgroundColor3 = (which == "Alts") and COL_ACCENT or COL_ROW
		timeTab.BackgroundColor3 = (which == "Time") and COL_ACCENT or COL_ROW
		clientTab.BackgroundColor3 = (which == "Client") and COL_ACCENT or COL_ROW
		settingsTab.BackgroundColor3 = (which == "Settings") and COL_ACCENT or COL_ROW
		controlTab.BackgroundColor3 = (which == "Control") and COL_ACCENT or COL_ROW
		altsTab.TextColor3 = (which == "Alts") and COL_DARKTEXT or COL_DIM
		timeTab.TextColor3 = (which == "Time") and COL_DARKTEXT or COL_DIM
		clientTab.TextColor3 = (which == "Client") and COL_DARKTEXT or COL_DIM
		settingsTab.TextColor3 = (which == "Settings") and COL_DARKTEXT or COL_DIM
		controlTab.TextColor3 = (which == "Control") and COL_DARKTEXT or COL_DIM
	end
	altsTab.MouseButton1Click:Connect(function() selectTab("Alts") end)
	timeTab.MouseButton1Click:Connect(function() selectTab("Time") end)
	clientTab.MouseButton1Click:Connect(function() selectTab("Client") end)
	settingsTab.MouseButton1Click:Connect(function() selectTab("Settings") end)
	controlTab.MouseButton1Click:Connect(function() selectTab("Control") end)
	selectTab("Alts")

	local COLS = {
		{key = "avatar", label = "",        x = 0,   w = 42},
		{key = "idx",    label = "#",       x = 42,  w = 30},
		{key = "name",   label = "Account", x = 72,  w = 138},
		{key = "status", label = "Status",  x = 210, w = 86},
		{key = "resets", label = "Resets",  x = 296, w = 104},
		{key = "drop",   label = "Drop",    x = 400, w = 140},
		{key = "eta",    label = "ETA",     x = 540, w = 130},
	}

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "Search"
	searchBox.Size = UDim2.new(1, 0, 0, 30)
	searchBox.Position = UDim2.new(0, 0, 0, 0)
	searchBox.BackgroundColor3 = COL_ROW
	searchBox.Text = ""
	searchBox.PlaceholderText = "filter alts_"
	searchBox.PlaceholderColor3 = COL_MUTED
	searchBox.TextColor3 = COL_TEXT
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.Font = Enum.Font.Code
	searchBox.TextSize = 13
	searchBox.BorderSizePixel = 0
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = altsPage
	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 8)
	searchCorner.Parent = searchBox
	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = COL_BORDER
	searchStroke.Thickness = 1
	searchStroke.Transparency = 0.3
	searchStroke.Parent = searchBox
	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 12)
	searchPad.PaddingRight = UDim.new(0, 12)
	searchPad.Parent = searchBox

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 26)
	header.Position = UDim2.new(0, 0, 0, 38)
	header.BackgroundColor3 = COL_HEADER
	header.BorderSizePixel = 0
	header.Parent = altsPage

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 8)
	hCorner.Parent = header

	local hStroke = Instance.new("UIStroke")
	hStroke.Color = COL_BORDER
	hStroke.Thickness = 1
	hStroke.Transparency = 0.3
	hStroke.Parent = header

	for _, col in ipairs(COLS) do
		if col.key == "avatar" then continue end
		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, col.x + 12, 0, 0)
		lbl.Size = UDim2.new(0, col.w - 12, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = col.label:upper()
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = COL_MUTED
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 10
		lbl.Parent = header
	end

	local rowsFrame = Instance.new("ScrollingFrame")
	rowsFrame.Size = UDim2.new(1, 0, 1, -72)
	rowsFrame.Position = UDim2.new(0, 0, 0, 72)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.BorderSizePixel = 0
	rowsFrame.ScrollBarThickness = 3
	rowsFrame.ScrollBarImageColor3 = COL_ACCENT
	rowsFrame.CanvasSize = UDim2.new()
	rowsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rowsFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	rowsFrame.Parent = altsPage

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.Padding = UDim.new(0, 4)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = rowsFrame

	local cells: {[number]: {[string]: TextLabel}} = {}
	local bars: {[number]: Frame} = {}
	local avatars: {[number]: ImageLabel} = {}
	local rings: {[number]: UIStroke} = {}
	local rowFrames: {[number]: Frame} = {}

	for i, uid in ipairs(Settings.AccountUserIds) do
		local rowFrame = Instance.new("Frame")
		rowFrame.Name = "Row_" .. tostring(uid)
		rowFrame.Size = UDim2.new(1, -4, 0, 44)
		rowFrame.BackgroundColor3 = (i % 2 == 0) and COL_ROW or COL_ROW_ALT
		rowFrame.BorderSizePixel = 0
		rowFrame.LayoutOrder = i
		rowFrame.Parent = rowsFrame
		rowFrame.ClipsDescendants = true
		local baseColor = rowFrame.BackgroundColor3
		rowFrame.MouseEnter:Connect(function()
			rowFrame.BackgroundColor3 = Color3.fromRGB(20, 32, 25)
		end)
		rowFrame.MouseLeave:Connect(function()
			rowFrame.BackgroundColor3 = baseColor
		end)
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = rowFrame
		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = COL_BORDER
		rowStroke.Thickness = 1
		rowStroke.Transparency = 0.55
		rowStroke.Parent = rowFrame
		rowFrames[uid] = rowFrame

		local altAvatar = Instance.new("ImageLabel")
		altAvatar.Size = UDim2.new(0, 28, 0, 28)
		altAvatar.Position = UDim2.new(0, 8, 0.5, -14)
		altAvatar.BackgroundColor3 = COL_TRACK
		altAvatar.BorderSizePixel = 0
		altAvatar.Image = ""
		altAvatar.Parent = rowFrame
		local altCorner = Instance.new("UICorner")
		altCorner.CornerRadius = UDim.new(0, 8)
		altCorner.Parent = altAvatar
		local altRing = Instance.new("UIStroke")
		altRing.Color = COL_BORDER
		altRing.Thickness = 1.5
		altRing.Transparency = 0.2
		altRing.Parent = altAvatar
		avatars[uid] = altAvatar
		rings[uid] = altRing
		local capturedAvatar = altAvatar
		local capturedUid = uid
		task.spawn(function()
			local thumb: string? = nil
			pcall(function()
				thumb = Players:GetUserThumbnailAsync(capturedUid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if thumb ~= nil and capturedAvatar.Parent ~= nil then capturedAvatar.Image = (thumb :: string) end
			if clientCachedName == nil then
				pcall(function()
					Players:GetNameFromUserIdAsync(capturedUid)
				end)
			end
		end)

		cells[uid] = {}
		for _, col in ipairs(COLS) do
			if col.key == "avatar" then continue end
			local lbl = Instance.new("TextLabel")
			lbl.Position = UDim2.new(0, col.x + 12, 0, 5)
			lbl.Size = UDim2.new(0, col.w - 12, 0, 22)
			lbl.Text = "—"
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextColor3 = COL_TEXT
			lbl.Font = Enum.Font.Code
			lbl.TextSize = 13
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.Parent = rowFrame
			if col.key == "status" then
				lbl.BackgroundColor3 = COL_TRACK
				lbl.BorderSizePixel = 0
				lbl.Font = Enum.Font.Code
				lbl.TextSize = 11
				lbl.TextXAlignment = Enum.TextXAlignment.Center
				local pillStroke = Instance.new("UIStroke")
				pillStroke.Color = COL_BORDER
				pillStroke.Thickness = 1
				pillStroke.Transparency = 0.35
				pillStroke.Parent = lbl
				local pillCorner = Instance.new("UICorner")
				pillCorner.CornerRadius = UDim.new(1, 0)
				pillCorner.Parent = lbl
				local pillPad = Instance.new("UIPadding")
				pillPad.PaddingLeft = UDim.new(0, 6)
				pillPad.PaddingRight = UDim.new(0, 6)
				pillPad.Parent = lbl
			else
				lbl.BackgroundTransparency = 1
			end
			cells[uid][col.key] = lbl
		end
		local track = Instance.new("Frame")
		track.AnchorPoint = Vector2.new(0, 1)
		track.Position = UDim2.new(0, 44, 1, -6)
		track.Size = UDim2.new(1, -54, 0, 3)
		track.BackgroundColor3 = COL_TRACK
		track.BorderSizePixel = 0
		track.Parent = rowFrame
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = COL_ACCENT
		fill.BorderSizePixel = 0
		fill.Parent = track
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill
		bars[uid] = fill
	end
	hostRowFrames = rowFrames
	local function applySearch()
		local query = string.lower(string.gsub(searchBox.Text, "^%s+", ""))
		hostSearchQuery = query
		for _, uid in ipairs(Settings.AccountUserIds) do
			local row = rowFrames[uid]
			if not row then continue end
			if query == "" then
				row.Visible = true
				continue
			end
			local name = ""
			pcall(function()
				local cell = cells[uid] and cells[uid].name
				if cell then name = string.lower(cell.Text) end
			end)
			local idText = tostring(uid)
			row.Visible = (string.find(name, query, 1, true) ~= nil) or (string.find(idText, query, 1, true) ~= nil)
		end
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(applySearch)

	-- Time page: estimated total on top, live remaining under it (real-time).
	local timeLayout = Instance.new("UIListLayout")
	timeLayout.Padding = UDim.new(0, 6)
	timeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	timeLayout.Parent = timePage
	local timeLabels: {[string]: TextLabel} = {}
	local function addTimeRow(key: string, prefix: string, order: number)
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundColor3 = COL_ROW
		row.BorderSizePixel = 0
		row.Text = "> " .. prefix .. ": —"
		row.TextColor3 = COL_TEXT
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.Font = Enum.Font.Code
		row.TextSize = 13
		row.LayoutOrder = order
		row.Parent = timePage
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = row
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = row
		local stroke = Instance.new("UIStroke")
		stroke.Color = COL_BORDER
		stroke.Thickness = 1
		stroke.Transparency = 0.4
		stroke.Parent = row
		local accent = Instance.new("Frame")
		accent.Size = UDim2.new(0, 3, 1, -14)
		accent.Position = UDim2.new(0, 8, 0, 7)
		accent.BackgroundColor3 = COL_ACCENT
		accent.BorderSizePixel = 0
		accent.Parent = row
		local accentCorner = Instance.new("UICorner")
		accentCorner.CornerRadius = UDim.new(1, 0)
		accentCorner.Parent = accent
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
	headerRow.Size = UDim2.new(1, 0, 0, 84)
	headerRow.BackgroundColor3 = COL_HEADER
	headerRow.BorderSizePixel = 0
	headerRow.Parent = clientPage
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = headerRow
	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = COL_BORDER
	headerStroke.Thickness = 1
	headerStroke.Transparency = 0.3
	headerStroke.Parent = headerRow
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Size = UDim2.new(0, 64, 0, 64)
	avatar.Position = UDim2.new(0, 10, 0, 10)
	avatar.BackgroundColor3 = COL_TRACK
	avatar.BorderSizePixel = 0
	avatar.Image = ""
	avatar.Parent = headerRow
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0, 8)
	avatarCorner.Parent = avatar
	local avatarRing = Instance.new("UIStroke")
	avatarRing.Color = COL_BORDER
	avatarRing.Thickness = 1.5
	avatarRing.Transparency = 0.2
	avatarRing.Parent = avatar
	local function addClientHeaderLabel(key: string, y: number, bold: boolean, size: number, color: Color3)
		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 86, 0, y)
		lbl.Size = UDim2.new(1, -96, 0, 22)
		lbl.BackgroundTransparency = 1
		lbl.Text = "—"
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = color
		lbl.Font = Enum.Font.Code
		lbl.TextSize = size
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.Parent = headerRow
		clientLabels[key] = lbl
	end
	addClientHeaderLabel("username", 10, true, 16, COL_TEXT)
	addClientHeaderLabel("display", 34, false, 13, COL_DIM)
	addClientHeaderLabel("userid", 56, false, 12, COL_MUTED)
	local function addClientRow(key: string, prefix: string, color: Color3)
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundColor3 = COL_ROW
		row.BorderSizePixel = 0
		row.Text = "> " .. prefix .. ": —"
		row.TextColor3 = color
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = Enum.Font.Code
		row.TextSize = 13
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.Parent = clientPage
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = row
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = row
		local stroke = Instance.new("UIStroke")
		stroke.Color = COL_BORDER
		stroke.Thickness = 1
		stroke.Transparency = 0.4
		stroke.Parent = row
		clientLabels[key] = row
	end
	-- Spacer puts cash rows below the 72px header inside a list layout.
	local clientLayout = Instance.new("UIListLayout")
	clientLayout.Padding = UDim.new(0, 4)
	clientLayout.SortOrder = Enum.SortOrder.LayoutOrder
	clientLayout.Parent = clientPage
	headerRow.LayoutOrder = 1
	addClientRow("presence", "Presence", Color3.fromRGB(170, 255, 195))
	clientLabels["presence"].LayoutOrder = 2
	addClientRow("start", "Started with", Color3.fromRGB(255, 200, 80))
	clientLabels["start"].LayoutOrder = 3
	addClientRow("now", "Cash now", Color3.fromRGB(170, 255, 195))
	clientLabels["now"].LayoutOrder = 4
	addClientRow("gained", "Received", Color3.fromRGB(57, 255, 140))
	clientLabels["gained"].LayoutOrder = 5
	addClientRow("expected", "Expected", Color3.fromRGB(90, 180, 120))
	clientLabels["expected"].LayoutOrder = 6
	-- Static expected target, never needs a live read.
	clientLabels["expected"].Text = "> Expected: " .. comma(Settings.TargetDrop)
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

	-- Settings page: Visuals category.
	local settingsLayout = Instance.new("UIListLayout")
	settingsLayout.Padding = UDim.new(0, 6)
	settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	settingsLayout.Parent = settingsPage
	local function addSettingsHeader(text: string, order: number)
		local h = Instance.new("TextLabel")
		h.Size = UDim2.new(1, 0, 0, 20)
		h.BackgroundTransparency = 1
		h.Text = "> " .. text
		h.TextColor3 = COL_MUTED
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.Font = Enum.Font.Code
		h.TextSize = 11
		h.LayoutOrder = order
		h.Parent = settingsPage
	end
	local function makeToggleRow(titleText: string, descText: string, initialOn: boolean, order: number, onChanged): TextButton
		local row = Instance.new("Frame")
		row.Name = "ToggleRow_" .. string.gsub(titleText, " ", "")
		row.Size = UDim2.new(1, 0, 0, 54)
		row.BackgroundColor3 = COL_ROW
		row.BorderSizePixel = 0
		row.LayoutOrder = order
		row.Parent = settingsPage
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row
		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = COL_BORDER
		rowStroke.Thickness = 1
		rowStroke.Transparency = 0.4
		rowStroke.Parent = row
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Position = UDim2.new(0, 14, 0, 6)
		titleLbl.Size = UDim2.new(1, -110, 0, 20)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = "> " .. titleText
		titleLbl.TextColor3 = COL_TEXT
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Font = Enum.Font.Code
		titleLbl.TextSize = 13
		titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
		titleLbl.Parent = row
		local descLbl = Instance.new("TextLabel")
		descLbl.Position = UDim2.new(0, 14, 0, 27)
		descLbl.Size = UDim2.new(1, -110, 0, 20)
		descLbl.BackgroundTransparency = 1
		descLbl.Text = descText
		descLbl.TextColor3 = COL_MUTED
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.Font = Enum.Font.Code
		descLbl.TextSize = 11
		descLbl.TextTruncate = Enum.TextTruncate.AtEnd
		descLbl.Parent = row
		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -12, 0.5, 0)
		btn.Size = UDim2.new(0, 70, 0, 30)
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.Code
		btn.TextSize = 12
		btn.AutoButtonColor = true
		btn.Parent = row
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = COL_BORDER
		btnStroke.Thickness = 1
		btnStroke.Transparency = 0.3
		btnStroke.Parent = btn
		local state = initialOn
		local function paint()
			if state then
				btn.Text = "[ON]"
				btn.BackgroundColor3 = COL_ACCENT
				btn.TextColor3 = COL_DARKTEXT
			else
				btn.Text = "[OFF]"
				btn.BackgroundColor3 = COL_TRACK
				btn.TextColor3 = COL_DIM
			end
		end
		paint()
		btn.MouseButton1Click:Connect(function()
			state = not state
			paint()
			onChanged(state)
		end)
		return btn
	end
	addSettingsHeader("VISUALS", 1)
	local streamerToggle = makeToggleRow("Streamer Mode", "Hide alt+host nametags, leaderboard rows", isStreamerOn(), 2, function(on)
		setStreamerMode(on)
	end)
	streamerToggle.Name = "StreamerToggle"
	local hideClientToggle = makeToggleRow("Hide Client Name", "Hide client nametag + leaderboard name", isHideClientNameOn(), 3, function(on)
		setHideClientName(on)
	end)
	hideClientToggle.Name = "HideClientToggle"
	-- Discord promo with fake typing effect.
	local promoRow = Instance.new("Frame")
	promoRow.Size = UDim2.new(1, 0, 0, 40)
	promoRow.BackgroundColor3 = COL_ROW
	promoRow.BorderSizePixel = 0
	promoRow.LayoutOrder = 4
	promoRow.Parent = settingsPage
	local promoCorner = Instance.new("UICorner")
	promoCorner.CornerRadius = UDim.new(0, 8)
	promoCorner.Parent = promoRow
	local promoStroke = Instance.new("UIStroke")
	promoStroke.Color = COL_BORDER
	promoStroke.Thickness = 1
	promoStroke.Transparency = 0.4
	promoStroke.Parent = promoRow
	local promoLbl = Instance.new("TextLabel")
	promoLbl.Size = UDim2.new(1, -28, 1, 0)
	promoLbl.Position = UDim2.new(0, 14, 0, 0)
	promoLbl.BackgroundTransparency = 1
	promoLbl.Text = ""
	promoLbl.TextColor3 = COL_ACCENT
	promoLbl.TextXAlignment = Enum.TextXAlignment.Left
	promoLbl.Font = Enum.Font.Code
	promoLbl.TextSize = 13
	promoLbl.TextTruncate = Enum.TextTruncate.AtEnd
	promoLbl.Parent = promoRow
	task.spawn(function()
		local full = "כנסו לשרת דיסקורד שלנו discord.gg/S9Ynvk2GuR"
		local chars: {string} = {}
		for ch in string.gmatch(full, "[%z\1-\127\194-\244][\128-\191]*") do
			table.insert(chars, ch)
		end
		while promoLbl.Parent ~= nil do
			for i = 1, #chars do
				if promoLbl.Parent == nil then break end
				promoLbl.Text = table.concat(chars, "", 1, i) .. "_"
				task.wait(0.06)
			end
			if promoLbl.Parent == nil then break end
			promoLbl.Text = table.concat(chars)
			task.wait(2.5)
		end
	end)
	-- Control page: host drives the alts.
	local controlLayout = Instance.new("UIListLayout")
	controlLayout.Padding = UDim.new(0, 6)
	controlLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlLayout.Parent = controlPage
	local controlStatus = Instance.new("TextLabel")
	controlStatus.Name = "ControlStatus"
	controlStatus.Size = UDim2.new(1, 0, 0, 28)
	controlStatus.BackgroundColor3 = COL_ROW
	controlStatus.BorderSizePixel = 0
	controlStatus.Text = "> MODE: " .. getControlMode()
	controlStatus.TextColor3 = COL_ACCENT
	controlStatus.TextXAlignment = Enum.TextXAlignment.Left
	controlStatus.Font = Enum.Font.Code
	controlStatus.TextSize = 13
	controlStatus.LayoutOrder = 1
	controlStatus.Parent = controlPage
	local controlStatusCorner = Instance.new("UICorner")
	controlStatusCorner.CornerRadius = UDim.new(0, 8)
	controlStatusCorner.Parent = controlStatus
	local controlStatusStroke = Instance.new("UIStroke")
	controlStatusStroke.Color = COL_BORDER
	controlStatusStroke.Thickness = 1
	controlStatusStroke.Transparency = 0.4
	controlStatusStroke.Parent = controlStatus
	local controlStatusPad = Instance.new("UIPadding")
	controlStatusPad.PaddingLeft = UDim.new(0, 14)
	controlStatusPad.Parent = controlStatus
	local function makeControlButton(text: string, mode: string, order: number, accent: boolean)
		local b = Instance.new("TextButton")
		b.Name = "Control_" .. mode
		b.Size = UDim2.new(1, 0, 0, 34)
		if accent then
			b.BackgroundColor3 = COL_ACCENT
			b.TextColor3 = COL_DARKTEXT
		else
			b.BackgroundColor3 = COL_ROW
			b.TextColor3 = COL_TEXT
		end
		b.Text = text
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Font = Enum.Font.Code
		b.TextSize = 13
		b.BorderSizePixel = 0
		b.AutoButtonColor = true
		b.LayoutOrder = order
		b.Parent = controlPage
		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 8)
		bCorner.Parent = b
		local bStroke = Instance.new("UIStroke")
		bStroke.Color = COL_BORDER
		bStroke.Thickness = 1
		bStroke.Transparency = 0.4
		bStroke.Parent = b
		local bPad = Instance.new("UIPadding")
		bPad.PaddingLeft = UDim.new(0, 14)
		bPad.Parent = b
		b.MouseButton1Click:Connect(function()
			broadcastControlMode(mode)
			controlStatus.Text = "> MODE: " .. mode .. " (press Enter in chat!)"
		end)
	end
	makeControlButton("> STOP ALTS (hold, no drops)", "STOP", 2, false)
	makeControlButton("> TP ALTS TO ME (follow host)", "TP_HOST", 3, false)
	makeControlButton("> CIRCLE AROUND ME", "CIRCLE_HOST", 4, false)
	makeControlButton("> TP ALTS TO CLIENT (hold)", "TP_CLIENT", 5, false)
	makeControlButton("> CIRCLE AROUND CLIENT", "CIRCLE_CLIENT", 6, false)
	makeControlButton("> RESUME DROPS (auto)", "AUTO", 7, true)
	-- CLIENT-ONLY: button stages the command locally + in the chat box.
	-- Host presses Enter once in chat and every alt syncs. Refresh label
	-- from local _G so it never shows a stale mode.
	task.spawn(function()
		while controlStatus.Parent ~= nil do
			task.wait(1)
			pcall(function()
				controlStatus.Text = "> MODE: " .. getControlMode() .. " (btn = stage, Enter in chat = sync)"
			end)
		end
	end)
	-- Fake chat: looks like a real bubble above the head, but local.
	-- Type here, SEND shows it above you. Click that bubble and the
	-- same text pops above every alt's head.
	local fakeHeader = Instance.new("TextLabel")
	fakeHeader.Size = UDim2.new(1, 0, 0, 20)
	fakeHeader.BackgroundTransparency = 1
	fakeHeader.Text = "> FAKE CHAT (local only, click yours = pop on alts)"
	fakeHeader.TextColor3 = COL_MUTED
	fakeHeader.TextXAlignment = Enum.TextXAlignment.Left
	fakeHeader.Font = Enum.Font.Code
	fakeHeader.TextSize = 11
	fakeHeader.LayoutOrder = 8
	fakeHeader.Parent = controlPage
	local fakeBox = Instance.new("TextBox")
	fakeBox.Name = "FakeChatBox"
	fakeBox.Size = UDim2.new(1, 0, 0, 32)
	fakeBox.BackgroundColor3 = COL_ROW
	fakeBox.Text = ""
	fakeBox.PlaceholderText = "type fake message_"
	fakeBox.PlaceholderColor3 = COL_MUTED
	fakeBox.TextColor3 = COL_TEXT
	fakeBox.TextXAlignment = Enum.TextXAlignment.Left
	fakeBox.Font = Enum.Font.Code
	fakeBox.TextSize = 13
	fakeBox.BorderSizePixel = 0
	fakeBox.ClearTextOnFocus = false
	fakeBox.LayoutOrder = 9
	fakeBox.Parent = controlPage
	local fakeBoxCorner = Instance.new("UICorner")
	fakeBoxCorner.CornerRadius = UDim.new(0, 8)
	fakeBoxCorner.Parent = fakeBox
	local fakeBoxStroke = Instance.new("UIStroke")
	fakeBoxStroke.Color = COL_BORDER
	fakeBoxStroke.Thickness = 1
	fakeBoxStroke.Transparency = 0.3
	fakeBoxStroke.Parent = fakeBox
	local fakeBoxPad = Instance.new("UIPadding")
	fakeBoxPad.PaddingLeft = UDim.new(0, 12)
	fakeBoxPad.PaddingRight = UDim.new(0, 12)
	fakeBoxPad.Parent = fakeBox
	local fakeSend = Instance.new("TextButton")
	fakeSend.Name = "FakeChatSend"
	fakeSend.Size = UDim2.new(1, 0, 0, 34)
	fakeSend.BackgroundColor3 = COL_ROW
	fakeSend.TextColor3 = COL_TEXT
	fakeSend.Text = "> SEND FAKE CHAT (above me, click bubble = alts)"
	fakeSend.TextXAlignment = Enum.TextXAlignment.Left
	fakeSend.Font = Enum.Font.Code
	fakeSend.TextSize = 13
	fakeSend.BorderSizePixel = 0
	fakeSend.AutoButtonColor = true
	fakeSend.LayoutOrder = 10
	fakeSend.Parent = controlPage
	local fakeSendCorner = Instance.new("UICorner")
	fakeSendCorner.CornerRadius = UDim.new(0, 8)
	fakeSendCorner.Parent = fakeSend
	local fakeSendStroke = Instance.new("UIStroke")
	fakeSendStroke.Color = COL_BORDER
	fakeSendStroke.Thickness = 1
	fakeSendStroke.Transparency = 0.4
	fakeSendStroke.Parent = fakeSend
	local fakeSendPad = Instance.new("UIPadding")
	fakeSendPad.PaddingLeft = UDim.new(0, 14)
	fakeSendPad.Parent = fakeSend
	fakeSend.MouseButton1Click:Connect(function()
		broadcastFakeChat(fakeBox.Text)
	end)
	fakeBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then broadcastFakeChat(fakeBox.Text) end
	end)
	ensureStreamerEnforcer()
	if isStreamerOn() then
		applyStreamerNametags()
		applyLeaderboardPass()
	end
	if isHideClientNameOn() then
		applyHideClientNamePass()
	end

	makeDraggableFrom(title, frame)
	hostCells = cells
	hostBars = bars
	hostAvatars = avatars
	hostAvatarRings = rings
	hostTimeLabels = timeLabels
	hostClientLabels = clientLabels
	hostClientAvatar = avatar
	pcall(function()
		local scale = Instance.new("UIScale")
		scale.Scale = 0.94
		scale.Parent = frame
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	local bodyVisible = true
	local fullPanelSize = UDim2.new(0, 740, 0, 500)
	local function setBodyVisible(visible: boolean)
		bodyVisible = visible
		minimizeBtn.Text = if visible then "–" else "+"
		summary.Visible = visible
		tabBar.Visible = visible
		altsPage.Visible = visible and selectedTab == "Alts"
		timePage.Visible = visible and selectedTab == "Time"
		clientPage.Visible = visible and selectedTab == "Client"
		settingsPage.Visible = visible and selectedTab == "Settings"
		controlPage.Visible = visible and selectedTab == "Control"
		pcall(function()
			TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = if visible then fullPanelSize else UDim2.new(0, 740, 0, 48),
			}):Play()
		end)
	end
	minimizeBtn.MouseButton1Click:Connect(function()
		setBodyVisible(not bodyVisible)
	end)
	local function setPanelHidden(hidden: boolean)
		frame.Visible = not hidden
		showPill.Visible = hidden
	end
	hideBtn.MouseButton1Click:Connect(function()
		setPanelHidden(true)
	end)
	showPill.MouseButton1Click:Connect(function()
		setPanelHidden(false)
	end)
	pcall(function()
		UIS.InputBegan:Connect(function(input, processed)
			if processed then return end
			if input.KeyCode == Enum.KeyCode.RightShift then
				if frame.Visible then
					setPanelHidden(true)
				else
					setPanelHidden(false)
				end
			end
		end)
	end)
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
	local dotColor, _ = phaseAccent(s.phase)
	if localAltDot then
		localAltDot.BackgroundColor3 = dotColor
	end
	localSetters.resets(string.format("%s / %s", comma(s.resetsDone), comma(s.resetsTotal)))
	if localProgressFill then
		local progress = 0
		if s.resetsTotal > 0 then progress = math.clamp(s.resetsDone / s.resetsTotal, 0, 1) end
		local fillColor = if s.finished then Color3.fromRGB(57, 255, 140) else Color3.fromRGB(0, 255, 200)
		tweenFill(localProgressFill, progress, fillColor)
	end
	if localProgressLabel then
		local percent = 0
		if s.resetsTotal > 0 then percent = math.floor(s.resetsDone / s.resetsTotal * 100 + 0.5) end
		localProgressLabel.Text = string.format("%s / %s :: %d%%", comma(s.resetsDone), comma(s.resetsTotal), percent)
	end
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
		local ring = hostAvatarRings and hostAvatarRings[uid]

		if not p then
			cells.name.Text = "userid " .. tostring(uid)
			cells.status.Text = "[OFFLINE]"
			cells.status.TextColor3 = Color3.fromRGB(90, 180, 120)
			cells.status.BackgroundColor3 = Color3.fromRGB(6, 20, 12)
			cells.resets.Text = "—"
			cells.drop.Text = "—"
			cells.eta.Text = "—"
			if ring then ring.Color = Color3.fromRGB(90, 180, 120) end
		else
			cells.name.Text = p.Name
			if obs and obs.alive then
				cells.status.Text = "[LIVE]"
				cells.status.TextColor3 = Color3.fromRGB(57, 255, 140)
				cells.status.BackgroundColor3 = Color3.fromRGB(6, 30, 16)
				if ring then ring.Color = Color3.fromRGB(57, 255, 140) end
			else
				cells.status.Text = "[DEAD]"
				cells.status.TextColor3 = Color3.fromRGB(255, 120, 110)
				cells.status.BackgroundColor3 = Color3.fromRGB(30, 8, 8)
				if ring then ring.Color = Color3.fromRGB(255, 120, 110) end
			end

			local d = (obs and obs.deaths) or 0
			local need = deathsNeededFor(i)
			cells.resets.Text = string.format("%s / %s", comma(d), comma(need))
			cells.drop.Text = string.format("%s / %s", comma(d * DropPerDeath), comma(need * DropPerDeath))

			-- ETA based on observed average, frozen at Done when finished.
			if hostFinished then
				cells.eta.Text = "Done"
			else
				local avgPerDeath = (d > 0) and (elapsed / d) or estimatedPerDrop
				local remaining = math.max(0, need - d)
				local eta = remaining * avgPerDeath
				cells.eta.Text = formatTime(eta)
			end
		end
		local bar = hostBars and hostBars[uid]
		if bar then
			local obsDeaths = HostObs[uid]
			local doneCount = (obsDeaths and obsDeaths.deaths) or 0
			local needCount = deathsNeededFor(i)
			local progress = 0
			if needCount > 0 then progress = math.clamp(doneCount / needCount, 0, 1) end
			tweenFill(bar, progress)
		end
	end

	local onlineCount = 0
	for _, uid in ipairs(Settings.AccountUserIds) do
		if Players:GetPlayerByUserId(uid) then onlineCount += 1 end
	end
	local overallProgress = 0
	if totalDrops > 0 then overallProgress = math.clamp(totalDeaths / totalDrops, 0, 1) end
	if hostOverallFill then
		tweenFill(hostOverallFill, overallProgress)
	end
	if hostOverallLabel then
		local percent = math.floor(overallProgress * 100 + 0.5)
		hostOverallLabel.Text = string.format("%d%% :: %s/%s", percent, comma(totalDeaths), comma(totalDrops))
	end
	if hostOnlineLabel then
		hostOnlineLabel.Text = string.format("%d/%d online", onlineCount, #Settings.AccountUserIds)
	end
	if hostRateLabel then
		if hostFinished then
			hostRateLabel.Text = "Done"
		elseif elapsed > 5 and totalDeaths > 0 then
			local perMin = totalDeaths / (elapsed / 60)
			local remaining = math.max(0, totalDrops - totalDeaths)
			local etaSec = if perMin > 0 then (remaining / perMin) * 60 else 0
			hostRateLabel.Text = string.format("%.1f/m :: %s left", perMin, formatTime(etaSec))
		else
			hostRateLabel.Text = "warming up_"
		end
	end

	-- Time page: estimate on top, live remaining under it, frozen when done.
	if hostTimeLabels then
		local dropDone = totalDeaths * DropPerDeath
		local resetsRemaining = math.max(0, totalDrops - totalDeaths)
		local avgPerReset = (totalDeaths > 0) and (elapsed / totalDeaths) or estimatedPerDrop
		local estTotal = estimatedPerDrop * totalDrops
		hostTimeLabels.estTotal.Text = "> Estimated total: " .. formatTime(estTotal) .. string.format(" (%s resets)", comma(totalDrops))
		hostTimeLabels.elapsed.Text = "> Elapsed: " .. formatTime(elapsed)
		if hostFinished then
			hostTimeLabels.remaining.Text = "> Time left: Done (0 left)"
		else
			local liveRemaining = resetsRemaining * avgPerReset
			hostTimeLabels.remaining.Text = "> Time left: " .. formatTime(liveRemaining) .. string.format(" (%s left)", comma(resetsRemaining))
		end
		hostTimeLabels.resets.Text = string.format("> Resets (global): %s / %s", comma(totalDeaths), comma(totalDrops))
		hostTimeLabels.drop.Text = string.format("> Cash dropped: %s / %s", comma(dropDone), comma(Settings.TargetDrop))
		hostTimeLabels.avg.Text = "> Avg / reset: " .. string.format("%.2fs", avgPerReset)
	end

	-- Client page: identity + cash baseline vs live, so missing cash is visible.
	if hostClientLabels then
		local clientPlayer = Players:GetPlayerByUserId(Settings.ClientUserId)
		if clientPlayer then
			if clientCachedName == nil then clientCachedName = clientPlayer.Name end
			hostClientLabels.username.Text = "@" .. clientPlayer.Name
			hostClientLabels.display.Text = clientPlayer.DisplayName
			hostClientLabels.userid.Text = "ID: " .. tostring(clientPlayer.UserId)
			hostClientLabels.presence.Text = "> Presence: In server"
			hostClientLabels.presence.TextColor3 = Color3.fromRGB(57, 255, 140)
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
			hostClientLabels.presence.Text = "> Presence: Not in server"
			hostClientLabels.presence.TextColor3 = Color3.fromRGB(90, 180, 120)
		end
		if clientCashStart ~= nil then
			hostClientLabels.start.Text = "> Started with: " .. comma(clientCashStart :: number)
		else
			hostClientLabels.start.Text = "> Started with: waiting for client cash_"
		end
		if clientCashNow ~= nil then
			local suffix = hostFinished and " (final)" or ""
			hostClientLabels.now.Text = "> Cash now: " .. comma(clientCashNow :: number) .. suffix
		else
			hostClientLabels.now.Text = "> Cash now: —"
		end
		if clientCashStart ~= nil and clientCashNow ~= nil then
			local gained = (clientCashNow :: number) - (clientCashStart :: number)
			local suffix = hostFinished and " (final)" or ""
			hostClientLabels.gained.Text = "> Received: " .. comma(gained) .. suffix
		else
			hostClientLabels.gained.Text = "> Received: —"
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
if extraAlts > 0 then
	print(string.format("Deaths Needed (per account): %s (first %s alts do %s)", comma(basePerAlt), comma(extraAlts), comma(basePerAlt + 1)))
else
	print(string.format("Deaths Needed (per account): %s", comma(basePerAlt)))
end
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
-- ULTRA-FAST INSTANT RESPAWN SYSTEM.
-- Goal: new alive character in under 1 second, every death.
-- Method: Died fires -> LoadCharacter SAME FRAME (no waits),
-- then tight 0.05s retry spam until server returns a new character.
local respawnRequested = false
local respawnGeneration = 0
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
	if Status.finished then return end
	if not instantRespawnEnabled then return end
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
		if not instantRespawnEnabled then return end
		if myGeneration ~= respawnGeneration then return end
		if isAliveCharacter(player.Character) and player.Character ~= capturedOld then return end
		tryLoadCharacterNow()
	end)
	-- Tight retry spam: LoadCharacter every 0.05s until new alive char.
	-- This covers server throttle / race where first calls are dropped.
	task.spawn(function()
		local start = os.clock()
		while instantRespawnEnabled and myGeneration == respawnGeneration do
			local cur = player.Character
			if cur and cur ~= capturedOld and isAliveCharacter(cur) then
				break
			end
			if os.clock() - start > 3 then
				break
			end
			tryLoadCharacterNow()
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
		if instantRespawnEnabled then
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
	if not instantRespawnEnabled then return end
	requestInstantRespawn(character)
end)
if player.Character then
	hookInstantRespawn(player.Character)
end
player:GetPropertyChangedSignal("Character"):Connect(function()
	if instantRespawnEnabled and player.Character == nil then
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
	local isInstantRespawn = instantRespawnEnabled
	while os.clock() - startTime < Settings.RespawnTimeout do
		local character = player.Character
		if character and getRoot(character) then
			local humanoid = getHumanoid(character)
			if humanoid and humanoid.Health > 0 then return character end
		end
		if isInstantRespawn then
			task.wait()
		else
			task.wait(Settings.CheckInterval)
		end
	end
	warn(string.format("[%s] Character timeout.", player.Name)) return nil
end
local function waitForNewCharacter(oldCharacter: Model): Model?
	local startTime = os.clock()
	local isInstantRespawn = instantRespawnEnabled
	while os.clock() - startTime < Settings.RespawnTimeout do
		local character = player.Character
		if character and character ~= oldCharacter and getRoot(character) then
			local humanoid = getHumanoid(character)
			if humanoid and humanoid.Health > 0 then
				if not isInstantRespawn and Settings.CharacterReadyDelay > 0 then task.wait(Settings.CharacterReadyDelay) end
				return character
			end
		end
		if isInstantRespawn then
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
	if instantRespawnEnabled then return true end
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
	if Status.finished then return false end
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
	pcall(function()
		local r = getRoot(character)
		if r then
			r.AssemblyLinearVelocity = Vector3.zero
			r.AssemblyAngularVelocity = Vector3.zero
		end
	end)
	-- Let the teleport REPLICATE before killing. Killing on the same
	-- frame makes the server register the death at the OLD position,
	-- so the cash drops at spawn instead of at the client.
	if instantRespawnEnabled then
		task.wait(0.25)
	else
		task.wait(0.3)
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
			-- Double-confirm: settle physics, give the server one more
			-- moment, then re-read. A flung-back character fails here
			-- instead of dying at spawn.
			pcall(function()
				nowRoot.AssemblyLinearVelocity = Vector3.zero
				nowRoot.AssemblyAngularVelocity = Vector3.zero
			end)
			task.wait(0.1)
			local confirmRoot = getRoot(character)
			local confirmClient = getClientRoot()
			if confirmRoot and confirmClient and (confirmRoot.Position - confirmClient.Position).Magnitude <= limit then
				Status.last = string.format("TP ok (%.1f)", distance)
				print(string.format("[%s] TP to client confirmed (dist %.1f).", player.Name, distance))
				return true
			end
			continue
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
	if Status.finished then return false end
	local humanoid = getHumanoid(character)
	if not humanoid then warn(string.format("[%s] Humanoid not found.", player.Name)) return false end
	if humanoid.Health <= 0 then return false end
	if instantRespawnEnabled then
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
	if Status.finished then return false end
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
	-- Blatant kills immediately. Settle physics + one last position
	-- re-check right before the kill so a drifted character re-TPs
	-- instead of dying at spawn.
	do
		local settleRoot = getRoot(characterToKill)
		if settleRoot then
			pcall(function()
				settleRoot.AssemblyLinearVelocity = Vector3.zero
				settleRoot.AssemblyAngularVelocity = Vector3.zero
			end)
		end
	end
	if Settings.Mode == "Blatant" then
		task.wait(0.3)
	else
		task.wait(0.35)
		task.wait(Settings.KillDelay)
	end
	do
		local killRoot = getRoot(characterToKill)
		local killClient = getClientRoot()
		if not killRoot or not killClient or (killRoot.Position - killClient.Position).Magnitude > READY_RADIUS + 3 then
			Status.last = "Moved, re-TP"
			warn(string.format("[%s] Moved before kill, retrying drop without counting.", player.Name))
			return false
		end
	end
	if player.Character ~= characterToKill then warn(string.format("[%s] Character changed before kill.", player.Name)) return false end
	Status.phase = "Killing"
	local killed = selfKill(characterToKill) if not killed then return false end
	-- Fire respawn request immediately, do not wait for Died propagation.
	if Settings.Mode == "Blatant" then
		requestInstantRespawn(characterToKill)
	end
	-- Count on the CONFIRMED kill. A slow respawn must only make the next
	-- loop wait for a live character, never cause an extra uncounted kill.
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
-- Controls removed: no control listener, alts always run AUTO.
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
-- Progress survives re-executions (which used to restart the count from
-- zero and look like endless resetting). Stored in _G AND mirrored to
-- player attributes, so an executor _G wipe cannot lose it either. A real
-- target change resets both stores for a fresh run.
pcall(function()
	local g = _G :: any
	if type(g.DropperProgress) ~= "table" then g.DropperProgress = {} end
	if type(g.DropperTarget) ~= "table" then g.DropperTarget = {} end
	if type(g.DropperFinished) ~= "table" then g.DropperFinished = {} end
	local attrTarget: number? = nil
	local attrProgress: number? = nil
	local attrFinished = false
	pcall(function()
		local t = player:GetAttribute("DropperTarget")
		if type(t) == "number" then attrTarget = t end
		local p = player:GetAttribute("DropperProgress")
		if type(p) == "number" then attrProgress = p end
		attrFinished = player:GetAttribute("DropperFinished") == true
	end)
	local targetChanged = false
	if g.DropperTarget[player.UserId] ~= nil and g.DropperTarget[player.UserId] ~= myDeathsNeeded then
		targetChanged = true
	end
	if attrTarget ~= nil and attrTarget ~= myDeathsNeeded then
		targetChanged = true
	end
	if targetChanged then
		g.DropperTarget[player.UserId] = myDeathsNeeded
		g.DropperProgress[player.UserId] = 0
		g.DropperFinished[player.UserId] = nil
		pcall(function()
			player:SetAttribute("DropperTarget", myDeathsNeeded)
			player:SetAttribute("DropperProgress", 0)
			player:SetAttribute("DropperFinished", false)
		end)
	else
		local best = 0
		local saved = g.DropperProgress[player.UserId]
		if type(saved) == "number" and saved > best then best = math.floor(saved) end
		if attrProgress ~= nil and attrProgress > best then best = math.floor(attrProgress) end
		deathsCompleted = math.min(best, myDeathsNeeded)
		if g.DropperFinished[player.UserId] == true or attrFinished then
			deathsCompleted = myDeathsNeeded
		end
		g.DropperTarget[player.UserId] = myDeathsNeeded
		g.DropperProgress[player.UserId] = deathsCompleted
		pcall(function()
			player:SetAttribute("DropperTarget", myDeathsNeeded)
			player:SetAttribute("DropperProgress", deathsCompleted)
		end)
	end
end)
Status.resetsDone = deathsCompleted
if deathsCompleted >= myDeathsNeeded and myDeathsNeeded > 0 then
	instantRespawnEnabled = false
	respawnGeneration += 1
	respawnRequested = false
	Status.phase = "Done"
	Status.finished = true
	pcall(updateLocalUI)
	print(string.format("[STOPPED] %s already at target (%s resets). Staying stopped.", player.Name, comma(deathsCompleted)))
	return
end

-- Client cash baseline for the global cash-goal stop. No blocking waits:
-- if unreadable now, the loop top keeps trying until it sticks.
local clientCashBaseline: number? = nil
pcall(function()
	local cp = getClient()
	if cp then
		local c = readPlayerCash(cp)
		if c ~= nil then clientCashBaseline = c end
	end
end)
if clientCashBaseline ~= nil then
	print(string.format("[%s] Client cash baseline: %s (stopping at +%s).", player.Name, comma(clientCashBaseline), comma(Settings.TargetDrop)))
end

while deathsCompleted < myDeathsNeeded do
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
	-- Cross-copy progress sync + global cash-goal stop, checked every drop.
	-- A duplicate execution adopts the highest known count instead of each
	-- copy doing a full target, and every alt stops once the client really
	-- gained the target cash, even if the reset count says otherwise.
	pcall(function()
		local g = _G :: any
		if type(g.DropperProgress) == "table" then
			local saved = g.DropperProgress[player.UserId]
			if type(saved) == "number" and saved > deathsCompleted then
				deathsCompleted = math.min(math.floor(saved), myDeathsNeeded)
				Status.resetsDone = deathsCompleted
			end
		end
	end)
	pcall(function()
		local ap = player:GetAttribute("DropperProgress")
		if type(ap) == "number" and ap > deathsCompleted then
			deathsCompleted = math.min(math.floor(ap), myDeathsNeeded)
			Status.resetsDone = deathsCompleted
		end
	end)
	if deathsCompleted >= myDeathsNeeded then
		break
	end
	if clientCashBaseline == nil then
		pcall(function()
			local cp = getClient()
			if cp then
				local c = readPlayerCash(cp)
				if c ~= nil then clientCashBaseline = c end
			end
		end)
	else
		local baseline: number = clientCashBaseline
		local gainReached = false
		pcall(function()
			local cp = getClient()
			if cp then
				local now = readPlayerCash(cp)
				if now ~= nil and (now - baseline) >= Settings.TargetDrop then
					gainReached = true
				end
			end
		end)
		if gainReached then
			print(string.format("[%s] CASH TARGET REACHED on client (+%s). Stopping.", player.Name, comma(Settings.TargetDrop)))
			break
		end
	end
	-- Controls removed: alts always run AUTO straight into drops.
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
		-- Teleport stuck 3 drops in a row: request a fresh character WITHOUT
		-- killing in place (killing here would drop cash at spawn).
		-- A new spawn retries the drop from scratch next iteration.
		if teleportFailStreak >= 3 then
			teleportFailStreak = 0
			Status.phase = "Recovering"
			Status.last = "Stuck, fresh respawn"
			warn(string.format("[%s] Teleport stuck 3x, requesting fresh respawn (no kill).", player.Name))
			local stuckCharacter = player.Character
			tryLoadCharacterNow()
			if stuckCharacter then
				local fresh = waitForNewCharacter(stuckCharacter)
				if not fresh and not waitForCharacter() then task.wait(1) end
			elseif not waitForCharacter() then
				task.wait(1)
			end
			continue
		end
		warn(string.format("[%s] Drop failed. Retrying same drop.", player.Name))
		task.wait(Settings.CheckInterval)
		continue
	end

	deathsCompleted += 1
	Status.resetsDone = deathsCompleted
	pcall(function()
		local g = _G :: any
		if type(g.DropperProgress) ~= "table" then g.DropperProgress = {} end
		g.DropperProgress[player.UserId] = deathsCompleted
	end)
	pcall(function()
		player:SetAttribute("DropperProgress", deathsCompleted)
	end)
	local elapsed = os.clock() - runStartTime
	if elapsed < 0 then elapsed = 0 end
	Status.averagePerDrop = elapsed / deathsCompleted

	-- Old-style per-alt debug like before (e.g. 45/286 resets for 10M).
	-- Own progress uses myDeathsNeeded (per-alt), global estimate uses totalDrops.
	local personalDrop = deathsCompleted * DropPerDeath
	local personalTotal = myDeathsNeeded * DropPerDeath
	local globalEst = deathsCompleted * effectiveAccountCount * DropPerDeath
	print(string.format("[%s] COMPLETE | %s/%s resets (own) | Personal: %s/%s | Global est: %s/%s", player.Name, comma(deathsCompleted), comma(myDeathsNeeded), comma(personalDrop), comma(personalTotal), comma(globalEst), comma(Settings.TargetDrop)))

	Status.phase = "Complete"

	if Settings.Mode ~= "Blatant" then
		task.wait(LOOP_BREATHE)
	end
end

-- The drop loop is complete for this alt. Disable its respawn hooks too,
-- otherwise a later death can start another character cycle after the target.
instantRespawnEnabled = false
respawnGeneration += 1
respawnRequested = false
Status.phase = "Done"
Status.finished = true
pcall(function()
	local g = _G :: any
	if type(g.DropperFinished) ~= "table" then g.DropperFinished = {} end
	g.DropperFinished[player.UserId] = true
end)
pcall(function()
	player:SetAttribute("DropperFinished", true)
end)
print(string.format("[STOPPED] %s reached target (%s resets). No more teleporting or resetting.", player.Name, comma(deathsCompleted)))
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
print(string.format("Deaths completed (this account): %s / %s", comma(deathsCompleted), comma(myDeathsNeeded)))
print(string.format("Personal Drop: %s / %s", comma(deathsCompleted * DropPerDeath), comma(myDeathsNeeded * DropPerDeath)))
print(string.format("Total time: %s (timer stopped)", formatTime(finalElapsed)))
