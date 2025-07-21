--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// Constants
local TARGET = workspace:WaitForChild("Farm"):WaitForChild("Farm")
    :WaitForChild("Important"):WaitForChild("Plants_Physical")

local SCAN_INTERVAL = 2
local AUTO_MINIMIZE = 5
local STORAGE_KEY = "PlantPromptPrefs"

--// State
local promptGroups = {} -- [plantName] = {prompts = {}, models = {}, enabled = true, hidden = false}
local guiEntries = {}
local dragging, dragOffset

--// GUI Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlantToggleGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 400)
mainFrame.Position = UDim2.new(0, 20, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.AnchorPoint = Vector2.new(0, 0)
mainFrame.Active = true
mainFrame.Draggable = false
mainFrame.Parent = screenGui

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -10, 0, 30)
searchBox.Position = UDim2.new(0, 5, 0, 5)
searchBox.PlaceholderText = "Search plants..."
searchBox.Text = ""
searchBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
searchBox.TextColor3 = Color3.new(1, 1, 1)
searchBox.ClearTextOnFocus = false
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 14
searchBox.Parent = mainFrame

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -10, 1, -45)
scroll.Position = UDim2.new(0, 5, 0, 40)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 6
scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
scroll.BorderSizePixel = 0
scroll.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.Name
layout.Parent = scroll

--// LocalStorage
local function loadPreferences()
	local prefs = player:FindFirstChild("PrefsStorage")
	if prefs then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(prefs.Value)
		end)
		return ok and data or {}
	end
	return {}
end

local function savePreferences()
	local prefsData = {}
	for name, data in pairs(promptGroups) do
		prefsData[name] = {
			enabled = data.enabled,
			hidden = data.hidden,
		}
	end
	local prefs = player:FindFirstChild("PrefsStorage") or Instance.new("StringValue")
	prefs.Name = "PrefsStorage"
	prefs.Value = HttpService:JSONEncode(prefsData)
	prefs.Parent = player
end

--// Helpers
local function updateCanvas()
	scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end

local function scanPrompts()
	for _, model in ipairs(TARGET:GetChildren()) do
		local base = model:FindFirstChild("Base")
		if base then
			local prompt = base:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				local name = model.Name
				promptGroups[name] = promptGroups[name] or {prompts = {}, models = {}, enabled = true, hidden = false}

				if not table.find(promptGroups[name].prompts, prompt) then
					table.insert(promptGroups[name].prompts, prompt)
					table.insert(promptGroups[name].models, model)
				end
			end
		end
	end
end

local function applyPreferences(prefs)
	for name, settings in pairs(prefs) do
		if promptGroups[name] then
			promptGroups[name].enabled = settings.enabled
			promptGroups[name].hidden = settings.hidden
		end
	end
end

local function addToggleEntry(name, data)
	if guiEntries[name] then return end

	local entry = Instance.new("Frame")
	entry.Size = UDim2.new(1, 0, 0, 30)
	entry.BackgroundTransparency = 1
	entry.Name = name
	entry.Parent = scroll
	guiEntries[name] = entry

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.4, 0, 1, 0)
	label.Text = name
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.Parent = entry

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.new(0.3, 0, 1, 0)
	toggle.Position = UDim2.new(0.4, 0, 0, 0)
	toggle.Text = data.enabled and "Disable" or "Enable"
	toggle.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Font = Enum.Font.Gotham
	toggle.TextSize = 14
	toggle.Parent = entry

	toggle.MouseButton1Click:Connect(function()
		data.enabled = not data.enabled
		toggle.Text = data.enabled and "Disable" or "Enable"
		for _, prompt in ipairs(data.prompts) do
			prompt.Enabled = data.enabled
		end
		savePreferences()
	end)

	local hideBtn = Instance.new("TextButton")
	hideBtn.Size = UDim2.new(0.3, 0, 1, 0)
	hideBtn.Position = UDim2.new(0.7, 0, 0, 0)
	hideBtn.Text = data.hidden and "Show" or "Hide"
	hideBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	hideBtn.TextColor3 = Color3.new(1, 1, 1)
	hideBtn.Font = Enum.Font.Gotham
	hideBtn.TextSize = 14
	hideBtn.Parent = entry

	hideBtn.MouseButton1Click:Connect(function()
		data.hidden = not data.hidden
		hideBtn.Text = data.hidden and "Show" or "Hide"
		for _, model in ipairs(data.models) do
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = data.hidden and 1 or 0
					part.CanCollide = not data.hidden
				end
			end
		end
		savePreferences()
	end)

	updateCanvas()
end

--// Search Filtering
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local search = searchBox.Text:lower()
	for name, entry in pairs(guiEntries) do
		entry.Visible = name:lower():find(search) ~= nil
	end
	updateCanvas()
end)

--// Auto Minimize
local hideTimer = 0
RunService.RenderStepped:Connect(function(dt)
	hideTimer += dt
	if hideTimer >= AUTO_MINIMIZE then
		mainFrame.Visible = false
	end
end)

screenGui.InputBegan:Connect(function()
	mainFrame.Visible = true
	hideTimer = 0
end)

--// Draggable GUI Support (mobile-friendly)
mainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragOffset = input.Position - mainFrame.Position.Position
	end
end)

mainFrame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		mainFrame.Position = UDim2.new(0, input.Position.X - dragOffset.X, 0, input.Position.Y - dragOffset.Y)
	end
end)

--// Initialization
local prefs = loadPreferences()
scanPrompts()
applyPreferences(prefs)

for name, data in pairs(promptGroups) do
	addToggleEntry(name, data)
end

--// Rescan Loop
task.spawn(function()
	while true do
		scanPrompts()
		for name, data in pairs(promptGroups) do
			if not guiEntries[name] then
				addToggleEntry(name, data)
			end
		end
		task.wait(SCAN_INTERVAL)
	end
end)
