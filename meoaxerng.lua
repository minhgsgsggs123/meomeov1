if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Config = {
    AutoFarm = true,
    AutoUnlock = true,
    TreeFolder = workspace:FindFirstChild("Trees") or workspace:FindFirstChild("Map") or workspace, 
    GateFolder = workspace:FindFirstChild("Gates") or workspace:FindFirstChild("Borders") or workspace,
    DistanceToCut = 3.2,
    TweenSpeed = 65
}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if PlayerGui:FindFirstChild("KaitunStatusUI") then
    PlayerGui.KaitunStatusUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KaitunStatusUI"
ScreenGui.Parent = PlayerGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 450, 0, 30)
MainFrame.Position = UDim2.new(0.5, -225, 0, 15)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BackgroundTransparency = 0.3
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 255, 127)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(0.5, -10, 1, 0)
StatusLabel.Position = UDim2.new(0, 10, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Trạng thái: Đang hoạt động"
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
StatusLabel.TextSize = 13
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = MainFrame

local TimeLabel = Instance.new("TextLabel")
TimeLabel.Name = "TimeLabel"
TimeLabel.Size = UDim2.new(0.5, -10, 1, 0)
TimeLabel.Position = UDim2.new(0.5, 0, 0, 0)
TimeLabel.BackgroundTransparency = 1
TimeLabel.Text = "Đã treo: 00:00:00"
TimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TimeLabel.TextSize = 13
TimeLabel.Font = Enum.Font.Gotham
TimeLabel.TextXAlignment = Enum.TextXAlignment.Right
TimeLabel.Parent = MainFrame

task.spawn(function()
    local startTime = os.time()
    while true do
        task.wait(1)
        local elapsedTime = os.time() - startTime
        local hours = math.floor(elapsedTime / 3600)
        local minutes = math.floor((elapsedTime % 3600) / 60)
        local seconds = elapsedTime % 60
        local timeString = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        TimeLabel.Text = "Đã treo: " .. timeString
    end
end)

LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

local function getBasePoint()
    local spawnPart = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChildOfClass("SpawnLocation")
    if spawnPart then
        return spawnPart.Position
    end
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        return character.HumanoidRootPart.Position
    end
    return Vector3.new(0, 0, 0)
end
local basePoint = getBasePoint()

local function teleportTo(targetCFrame)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = character.HumanoidRootPart
    
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local duration = distance / Config.TweenSpeed
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
    
    if character:FindFirstChildOfClass("Humanoid") then
        character:FindFirstChildOfClass("Humanoid").PlatformStand = false
    end
end

local function getMyWood()
    local success, result = pcall(function()
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats and (leaderstats:FindFirstChild("Wood") or leaderstats:FindFirstChild("Woods")) then
            return (leaderstats:FindFirstChild("Wood") or leaderstats:FindFirstChild("Woods")).Value
        end
        local playerData = LocalPlayer:FindFirstChild("PlayerData") or LocalPlayer:FindFirstChild("Data")
        if playerData and (playerData:FindFirstChild("Wood") or playerData:FindFirstChild("Woods")) then
            return (playerData:FindFirstChild("Wood") or playerData:FindFirstChild("Woods")).Value
        end
        return 0
    end)
    return success and result or 0
end

local function getLockedGate()
    if not Config.GateFolder then return nil end
    local closestGate = nil
    local shortestDistance = math.huge
    for _, gate in pairs(Config.GateFolder:GetChildren()) do
        if gate:IsA("Part") or gate:IsA("Model") then
            if gate.Name ~= "Baseplate" and gate.Name ~= "Terrain" then
                local gatePart = gate:IsA("Model") and (gate.PrimaryPart or gate:FindFirstChildOfClass("Part")) or gate
                if gatePart and gatePart:IsA("BasePart") then
                    local hasPrice = gate:FindFirstChild("Price") or gate:FindFirstChild("Cost") or gate:FindFirstChild("RequiredWood")
                    if gatePart.CanCollide == true or hasPrice then
                        local dist = (basePoint - gatePart.Position).Magnitude
                        if dist < shortestDistance then
                            shortestDistance = dist
                            closestGate = gate
                        end
                    end
                end
            end
        end
    end
    return closestGate
end

local movingForward = true

local function getBestTree()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local lockedGate = getLockedGate()
    local gatePosition = lockedGate and (lockedGate.PrimaryPart or lockedGate:FindFirstChildOfClass("Part") or lockedGate).Position
    
    local validTrees = {}
    for _, obj in pairs(Config.TreeFolder:GetChildren()) do
        if (obj:IsA("Model") or obj:IsA("Part")) and obj ~= lockedGate then
            local treePart = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("Part")) or obj
            if treePart and treePart:IsA("BasePart") then
                local distTreeToBase = (treePart.Position - basePoint).Magnitude
                if gatePosition then
                    local distGateToBase = (gatePosition - basePoint).Magnitude
                    if distTreeToBase > distGateToBase then
                        continue
                    end
                end
                
                local treeValue = 1
                local nameLower = string.lower(obj.Name)
                if string.find(nameLower, "mythic") or string.find(nameLower, "divine") then
                    treeValue = 1000
                elseif string.find(nameLower, "legendary") or string.find(nameLower, "golden") or string.find(nameLower, "diamond") then
                    treeValue = 100
                elseif string.find(nameLower, "rare") or string.find(nameLower, "crystal") then
                    treeValue = 10
                end
                
                table.insert(validTrees, {instance = obj, part = treePart, dist = distTreeToBase, value = treeValue})
            end
        end
    end
    
    if #validTrees == 0 then return nil end
    
    local currentDist = (hrp.Position - basePoint).Magnitude
    
    local targetsInDirection = {}
    for _, t in ipairs(validTrees) do
        if movingForward and t.dist > currentDist then
            table.insert(targetsInDirection, t)
        elseif not movingForward and t.dist < currentDist then
            table.insert(targetsInDirection, t)
        end
    end
    
    if #targetsInDirection == 0 then
        movingForward = not movingForward
        targetsInDirection = validTrees
    end
    
    table.sort(targetsInDirection, function(a, b)
        if a.value ~= b.value then
            return a.value > b.value
        end
        if movingForward then
            return a.dist < b.dist
        else
            return a.dist > b.dist
        end
    end)
    
    return targetsInDirection[1] and targetsInDirection[1].instance or nil
end

task.spawn(function()
    while Config.AutoFarm do
        task.wait(0.001)
        
        if Config.AutoUnlock then
            local lockedGate = getLockedGate()
            if lockedGate then
                local priceValue = lockedGate:FindFirstChild("Price") or lockedGate:FindFirstChild("Cost") or lockedGate:FindFirstChild("RequiredWood")
                if priceValue and getMyWood() >= priceValue.Value then
                    StatusLabel.Text = "Trạng thái: Mở khóa khu vực mới"
                    local gatePart = lockedGate.PrimaryPart or lockedGate:FindFirstChildOfClass("Part") or lockedGate
                    teleportTo(gatePart.CFrame)
                    task.wait(0.5)
                    StatusLabel.Text = "Trạng thái: Đang hoạt động"
                    continue
                end
            end
        end
        
        local targetTree = getBestTree()
        if targetTree then
            local targetPart = targetTree:IsA("Model") and (targetTree.PrimaryPart or targetTree:FindFirstChildOfClass("Part")) or targetTree
            if targetPart and targetPart:IsA("BasePart") then
                StatusLabel.Text = "Trạng thái: Tuần tra tuyến đường thẳng"
                local targetPos = targetPart.CFrame * CFrame.new(0, 0, Config.DistanceToCut)
                teleportTo(targetPos)
            end
        else
            StatusLabel.Text = "Trạng thái: Đợi cây xuất hiện..."
            task.wait(0.05)
        end
    end
end)
