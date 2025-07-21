-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local starterGui = player:WaitForChild("PlayerGui")

-- Configuration
local TARGET = workspace:WaitForChild("Farm"):WaitForChild("Farm")
    :WaitForChild("Important"):WaitForChild("Plants_Physical")
local SCAN_INTERVAL = 2
local AUTO_MINIMIZE = 5

-- State
local promptGroups = {}  -- { [plantName] = {prompts = {}, containers = {models}} }

-- GUI Setup
local screenGui = Instance.new("ScreenGui", starterGui)
screenGui.Name = "PlantToggleGUI"

local mainFrame = Instance.new("Frame", screenGui)
-- [Set frame size, layout, style...]

local searchBox = Instance.new("TextBox", mainFrame)
searchBox.PlaceholderText = "Search plants..."
-- [Set size/style...]

local scroll = Instance.new("ScrollingFrame", mainFrame)
-- [Set size, UIListLayout inside]

-- Auto-hide timer
local hideTimer = 0
mainFrame.Visible = true

-- Functions

local function scanPrompts()
    for _, model in ipairs(TARGET:GetChildren()) do
        local base = model:FindFirstChild("Base")
        if base then
            local prompt = base:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                local name = model.Name
                promptGroups[name] = promptGroups[name] or {prompts = {}, models = {}}
                if not table.find(promptGroups[name].prompts, prompt) then
                    table.insert(promptGroups[name].prompts, prompt)
                    table.insert(promptGroups[name].models, model)
                end
            end
        end
    end
end

local function addToggleEntry(name, data)
    local entry = Instance.new("Frame", scroll)
    local label = Instance.new("TextLabel", entry)
    label.Text = name
    local toggle = Instance.new("TextButton", entry)
    toggle.Text = data.enabled and "Disable" or "Enable"
    toggle.MouseButton1Click:Connect(function()
        data.enabled = not data.enabled
        toggle.Text = data.enabled and "Disable" or "Enable"
        for _, p in ipairs(data.prompts) do
            p.Enabled = data.enabled
        end
    end)

    local hideBtn = Instance.new("TextButton", entry)
    hideBtn.Text = "Hide"
    hideBtn.MouseButton1Click:Connect(function()
        local show = not data.hidden
        data.hidden = show
        hideBtn.Text = show and "Show" or "Hide"
        for _, m in ipairs(data.models) do
            m.PrimaryPart.Transparency = show and 1 or 0
        end
    end)
end

-- Build GUI entries initially
scanPrompts()
for name, data in pairs(promptGroups) do
    data.enabled = true
    data.hidden = false
    addToggleEntry(name, data)
end

-- Search/filter
searchBox.Changed:Connect(function()
    local query = searchBox.Text:lower()
    for _, entry in ipairs(scroll:GetChildren()) do
        if entry:IsA("Frame") then
            local lbl = entry:FindFirstChildOfClass("TextLabel")
            entry.Visible = lbl.Text:lower():find(query) ~= nil
        end
    end
end)

-- Auto-minimize logic
RunService.RenderStepped:Connect(function(delta)
    if screenGui:IsDescendantOf(game) and mainFrame.Visible then
        hideTimer = hideTimer + delta
        if hideTimer >= AUTO_MINIMIZE then
            mainFrame.Visible = false
        end
    end
end)
screenGui.InputBegan:Connect(function()
    mainFrame.Visible = true
    hideTimer = 0
end)

-- Re-scan loop
while true do
    scanPrompts()
    wait(SCAN_INTERVAL)
end
