
-- [[ CONFIGURATION / CÀI ĐẶT ]]
local Config = {
    AutoFarm = true,
    AutoUnlock = true, -- Tự động chạy tới mở khóa khu vực mới khi đủ gỗ
    TreeFolder = workspace:FindFirstChild("Trees") or workspace, -- Folder chứa cây trong game
    GateFolder = workspace:FindFirstChild("Gates") or workspace, -- Folder chứa các bức tường/cổng khóa khu vực
    DistanceToCut = 4, -- Khoảng cách áp sát cây để game tự nhận diện chặt
    TweenSpeed = 45 -- Tốc độ di chuyển (Cân bằng để tránh bị Kick)
}

-- [[ SERVICES ]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

-- ====================================================================
-- [[ GIAO DIỆN UI TRẠNG THÁI CHÍNH GIỮA MÀN HÌNH ]]
-- ====================================================================

-- Xóa UI cũ nếu có tránh trùng lặp
if CoreGui:FindFirstChild("KaitunStatusUI") then
    CoreGui.KaitunStatusUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KaitunStatusUI"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 110)
MainFrame.Position = UDim2.new(0.5, -140, 0.4, -55) -- Nằm chính giữa màn hình
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BackgroundTransparency = 0.2
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 255, 127) -- Viền xanh dạ quang sáng đẹp
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(1, 0, 0, 40)
StatusLabel.Position = UDim2.new(0, 0, 0, 15)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "kaitun đang hoạt động"
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
StatusLabel.TextSize = 20
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.Parent = MainFrame

local TimeLabel = Instance.new("TextLabel")
TimeLabel.Name = "TimeLabel"
TimeLabel.Size = UDim2.new(1, 0, 0, 30)
TimeLabel.Position = UDim2.new(0, 0, 0, 55)
TimeLabel.BackgroundTransparency = 1
TimeLabel.Text = "đã treo :"
TimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TimeLabel.TextSize = 16
TimeLabel.Font = Enum.Font.Gotham
TimeLabel.Parent = MainFrame

-- [[ VÒNG LẶP ĐẾM THỜI GIAN TREO ]]
task.spawn(function()
    local startTime = os.time()
    while true do
        task.wait(1)
        local elapsedTime = os.time() - startTime
        local hours = math.floor(elapsedTime / 3600)
        local minutes = math.floor((elapsedTime % 3600) / 60)
        local seconds = elapsedTime % 60
        local timeString = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        TimeLabel.Text = "đã treo : " .. timeString
    end
end)

-- ====================================================================
-- [[ HỆ THỐNG ANTI-AFK CHỐNG KICK ]]
-- ====================================================================
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- ====================================================================
-- [[ CORE FUNCTIONS / CHỨC NĂNG CHÍNH ]]
-- ====================================================================

-- Hàm di chuyển mượt mà (Tween)
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
end

-- Hàm lấy số gỗ hiện tại của người chơi
local function getMyWood()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats and leaderstats:FindFirstChild("Wood") then
        return leaderstats.Wood.Value
    end
    -- Dự phòng nếu game ghi là "Wood" hoặc "Gỗ" trong folder khác
    local playerData = LocalPlayer:FindFirstChild("PlayerData")
    if playerData and playerData:FindFirstChild("Wood") then
        return playerData.Wood.Value
    end
    return 0
end

-- Hàm tìm bức tường/cổng khóa gần nhất trước mặt (Để làm ranh giới khu vực)
local function getNextGate()
    if not Config.GateFolder then return nil end
    
    local closestGate = nil
    local shortestDistance = math.huge
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    for _, gate in pairs(Config.GateFolder:GetChildren()) do
        if gate:IsA("Part") or gate:IsA("Model") then
            local gatePart = gate:IsA("Model") and gate.PrimaryPart or gate
            if gatePart then
                local dist = (hrp.Position - gatePart.Position).Magnitude
                if dist < shortestDistance then
                    shortestDistance = dist
                    closestGate = gate
                end
            end
        end
    end
    return closestGate
end

-- Hàm tìm cây xịn nhất nằm TRONG khu vực đã mở khóa
local function getBestTree()
    local bestTree = nil
    local highestValue = -1
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    -- Lấy vị trí cổng chặn phía trước để làm ranh giới giới hạn
    local nextGate = getNextGate()
    local gatePosition = nextGate and (nextGate.PrimaryPart or nextGate).Position
    
    for _, obj in pairs(Config.TreeFolder:GetChildren()) do
        if obj:IsA("Model") and (obj:FindFirstChild("Part") or obj.PrimaryPart) then
            local treePart = obj:FindFirstChild("Part") or obj.PrimaryPart
            
            -- KIỂM TRA RANH GIỚI MAP ĐƯỜNG THẲNG:
            -- Nếu khoảng cách từ bạn đến cây lớn hơn khoảng cách từ bạn đến cổng chưa mở => Cây này ở zone bị khóa. Bỏ qua!
            if gatePosition then
                local distToTree = (hrp.Position - treePart.Position).Magnitude
                local distToGate = (hrp.Position - gatePosition).Magnitude
                if distToTree > distToGate then
                    continue
                end
            end
            
            -- Logic lọc cây xịn bằng cách nhận diện chữ trong tên cây
            local treeValue = 1
            local nameLower = string.lower(obj.Name)
            if string.find(nameLower, "mythic") or string.find(nameLower, "divine") then
                treeValue = 1000
            elseif string.find(nameLower, "legendary") or string.find(nameLower, "golden") then
                treeValue = 100
            elseif string.find(nameLower, "rare") then
                treeValue = 10
            end
            
            if treeValue > highestValue then
                highestValue = treeValue
                bestTree = obj
            end
        end
    end
    return bestTree
end

-- ====================================================================
-- [[ MAIN LOOP / VÒNG LẶP CHẠY CHÍNH ]]
-- ====================================================================
task.spawn(function()
    while Config.AutoFarm do
        task.wait(0.2)
        
        -- BƯỚC 1: KIỂM TRA ĐỦ GỖ ĐỂ TỰ ĐỘNG MỞ ZONE MỚI CHƯA
        if Config.AutoUnlock then
            local nextGate = getNextGate()
            if nextGate then
                -- Tìm thuộc tính giá tiền của cổng (Thường tên là Price, Cost, hoặc Req)
                local priceValue = nextGate:FindFirstChild("Price") or nextGate:FindFirstChild("Cost") or nextGate:FindFirstChild("RequiredWood")
                
                if priceValue and getMyWood() >= priceValue.Value then
                    StatusLabel.Text = "Kaitun: Đang đi mở khóa khu vực mới!"
                    local gatePart = nextGate.PrimaryPart or nextGate
                    teleportTo(gatePart.CFrame)
                    task.wait(1.5) -- Đứng đợi game cộng điểm/mở cửa
                    StatusLabel.Text = "kaitun đang hoạt động"
                    continue
                end
            end
        end
        
        -- BƯỚC 2: TÌM CÂY VÀ TIẾN HÀNH AUTO CHẶT
        local targetTree = getBestTree()
        if targetTree then
            local targetPart = targetTree:FindFirstChild("Part") or targetTree:PrimaryPart or targetTree:FindFirstChildOfClass("Part")
            if targetPart then
                -- Vòng lặp bám lấy cây cho đến khi cây bị phá hủy hoàn toàn
                while Config.AutoFarm and targetTree and targetTree.Parent == Config.TreeFolder do
                    -- Áp sát vào cạnh cây theo khoảng cách thiết lập
                    local targetPos = targetPart.CFrame * CFrame.new(0, 0, Config.DistanceToCut)
                    teleportTo(targetPos)
                    task.wait(0.3) -- Đứng im chờ cơ chế tự chặt của game hoạt động
                    
                    if not targetTree or not targetTree.Parent then
                        break
                    end
                end
            end
        else
            -- Nếu tạm thời không tìm thấy cây nào hợp lệ trong khu vực
            StatusLabel.Text = "Kaitun: Đang đợi cây xuất hiện..."
            task.wait(0.5)
            StatusLabel.Text = "kaitun đang hoạt động"
        end
    end
end)
