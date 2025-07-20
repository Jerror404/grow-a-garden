--// 📦 Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

--// 🎯 Target Folder Path
local plantsFolder = workspace:FindFirstChild("Farm") 
    and workspace.Farm:FindFirstChild("Farm") 
    and workspace.Farm.Farm:FindFirstChild("Important") 
    and workspace.Farm.Farm.Important:FindFirstChild("Plants_Physical")

if not plantsFolder then
    warn("⚠️ Plants folder not found!")
    return
end

--// 🖼 GUI Setup
local gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
gui.Name = "PromptControlGui"
gui.ResetOnSpawn = false

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 360)
main.Position = UDim2.new(1, -270, 0.2, 0)
main.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
main.BorderSizePixel = 0
main.Active = false
main.Draggable = true
main.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
title.Text = "🌱 Prompt Control"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.Parent = main

local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 28, 0, 28)
hideBtn.Position = UDim2.new(1, -30, 0, 2)
hideBtn.Text = "-"
hideBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
hideBtn.TextColor3 = Color3.new(1, 1, 1)
hideBtn.Font = Enum.Font.SourceSansBold
hideBtn.TextSize = 18
hideBtn.Parent = main

local searchBar = Instance.new("TextBox")
searchBar.Size = UDim2.new(1, -10, 0, 25)
searchBar.Position = UDim2.new(0, 5, 0, 35)
searchBar.PlaceholderText = "🔍 Search plants..."
searchBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
searchBar.TextColor3 = Color3.new(1, 1, 1)
searchBar.TextSize = 16
searchBar.Font = Enum.Font.SourceSans
searchBar.ClearTextOnFocus = false
searchBar.Parent = main

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -10, 1, -110)
list.Position = UDim2.new(0, 5, 0, 65)
list.BackgroundTransparency = 1
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = main

local toggleAll = Instance.new("TextButton")
toggleAll.Size = UDim2.new(1, -10, 0, 30)
toggleAll.Position = UDim2.new(0, 5, 1, -40)
toggleAll.Text = "☐ Disable All Prompts"
toggleAll.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
toggleAll.TextColor3 = Color3.new(1, 1, 1)
toggleAll.Font = Enum.Font.SourceSans
toggleAll.TextSize = 16
toggleAll.Parent = main

--// 🧠 Logic
local modelButtons = {}
local promptsEnabled = true
local lastInteraction = tick()

local function togglePrompts(model, state)
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            obj.Enabled = state
        end
    end
end

local function addButton(model)
    if modelButtons[model] then return end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 16
    btn.Text = "☑ " .. model.Name
    btn.Parent = list

    local isEnabled = promptsEnabled
    togglePrompts(model, isEnabled)

    btn.MouseButton1Click:Connect(function()
        isEnabled = not isEnabled
        modelButtons[model].enabled = isEnabled
        btn.Text = (isEnabled and "☑ " or "☐ ") .. model.Name
        togglePrompts(model, isEnabled)
        lastInteraction = tick()
    end)

    modelButtons[model] = {
        button = btn,
        enabled = isEnabled
    }
end

local function refreshButtons()
    for _, data in pairs(modelButtons) do
        if data.button then data.button:Destroy() end
    end
    table.clear(modelButtons)

    local children = {}
    for _, child in ipairs(plantsFolder:GetChildren()) do
        if child:IsA("Model") then
            table.insert(children, child)
        end
    end

    table.sort(children, function(a, b)
        return a.Name:lower() < b.Name:lower())
    end
end

    for _, model in ipairs(children) do
        if searchBar.Text == "" or model.Name:lower():find(searchBar.Text:lower()) then
            addButton(model)
        end
    end
end

-- Initial build
refreshButtons()

toggleAll.MouseButton1Click:Connect(function()
    promptsEnabled = not promptsEnabled
    toggleAll.Text = (promptsEnabled and "☑ Enable All Prompts" or "☐ Disable All Prompts")

    for model, data in pairs(modelButtons) do
        data.enabled = promptsEnabled
        togglePrompts(model, promptsEnabled)
        if data.button then
            data.button.Text = (promptsEnabled and "☑ " or "☐ ") .. model.Name
        end
    end
    lastInteraction = tick()
end)

searchBar:GetPropertyChangedSignal("Text"):Connect(function()
    refreshButtons()
    lastInteraction = tick()
end)

RunService.RenderStepped:Connect(function()
    if tick() - lastInteraction >= 10 then
        main.Visible = false
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.UserInputType == Enum.UserInputType.Touch then
        main.Visible = true
        lastInteraction = tick()
    end
end)

hideBtn.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
    lastInteraction = tick()
end)

plantsFolder.ChildAdded:Connect(function(child)
    if child:IsA("Model") then
        task.wait(0.1)
        refreshButtons()
    end
end)

plantsFolder.ChildRemoved:Connect(function()
    refreshButtons()
end)
