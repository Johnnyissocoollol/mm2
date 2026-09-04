game:GetService("StarterGui"):SetCore("SendNotification",{
Title = "hi! if u get kicked",
Text = "set the tween speed lower scroll down and the slider is there enjoy", 
Duration = 5
})

setclipboard = function() end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localplayer = Players.LocalPlayer

local tweenSpeed = 15
local safe2UndergroundOffset = -6.5
local safe2PickupOffsetY = -2.5
local PAD_Y_OFFSET = -3.5

local layGyro = nil
local layVelocity = nil
local layStabilizeConnection = nil
local layUndergroundOffset = -2.9

local farmMode = nil
local autoFarm = false
local autoResetEnabled = false
local avoidMurderCoins = false
local waitInLobbyEnabled = false
local deadUntilNextRound = false
local visitedCoins = {}
local activeTween = nil
local humanoidDiedConn = nil
local waitingForNewMap = false
local farmLoopRunning = false
local noclipConnections = {}
local isSpectatingMidRound = false
local fakeFloor = nil
local padFollowConnection = nil
local antiFlingConnection = nil
local flingMurderEnabled = false
local autoShootMurderEnabled = false
local killAllEnabled = false
local flingLoopActive = false
local shootLoopActive = false

local LOBBY_POSITION = CFrame.new(-28.5, 519.6, 66.7)

local function SkidFling(TargetPlayer)
    local Player = localplayer
    local Character = Player.Character
    if not Character then return end
    
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    if not Humanoid or not RootPart then return end
    
    local TCharacter = TargetPlayer.Character
    if not TCharacter then return end

    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    if not THumanoid then return end
    
    local TRootPart = THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")
    
    if not TRootPart and not THead and not Handle then return end
    
    if RootPart.Velocity.Magnitude < 50 then
        getgenv().OldPos = RootPart.CFrame
    end
    
    if THumanoid and THumanoid.Sit then
        return
    end
    
    if THead then
        workspace.CurrentCamera.CameraSubject = THead
    elseif Handle then
        workspace.CurrentCamera.CameraSubject = Handle
    elseif THumanoid and TRootPart then
        workspace.CurrentCamera.CameraSubject = THumanoid
    end
    
    if not TCharacter:FindFirstChildWhichIsA("BasePart") then
        return
    end
    
    local FPos = function(BasePart, Pos, Ang)
        RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
        Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
        RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end
    
    local SFBasePart = function(BasePart)
        local TimeToWait = 2
        local Time = tick()
        local Angle = 0
        repeat
            if RootPart and THumanoid then
                if BasePart.Velocity.Magnitude < 50 then
                    Angle = Angle + 100
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle),0 ,0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                else
                    FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                    task.wait()
                end
            end
        until Time + TimeToWait < tick()
    end
    
    workspace.FallenPartsDestroyHeight = 0/0
    
    local BV = Instance.new("BodyVelocity")
    BV.Parent = RootPart
    BV.Velocity = Vector3.new(0, 0, 0)
    BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    
    if TRootPart then
        SFBasePart(TRootPart)
    elseif THead then
        SFBasePart(THead)
    elseif Handle then
        SFBasePart(Handle)
    else
        BV:Destroy()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        return
    end
    
    BV:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = Humanoid
    
    if getgenv().OldPos then
        repeat
            RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
            Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
            Humanoid:ChangeState("GettingUp")
            for _, part in pairs(Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity, part.RotVelocity = Vector3.new(), Vector3.new()
                end
            end
            task.wait()
        until (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
    end
end

local function tpShootMurderer()
    local player = localplayer
    local character = player.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    local gun = nil
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == "Gun" then
            gun = tool
            break
        end
    end
    if not gun then
        for _, tool in ipairs(player.Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == "Gun" then
                gun = tool
                break
            end
        end
    end
    if not gun then return false end
    
    local murderer = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local hasKnife = false
            if p.Backpack and p.Backpack:FindFirstChild("Knife") then
                hasKnife = true
            end
            if not hasKnife and p.Character and p.Character:FindFirstChild("Knife") then
                hasKnife = true
            end
            if hasKnife then
                murderer = p
                break
            end
        end
    end
    
    if not murderer then return false end
    
    local murderChar = murderer.Character
    if not murderChar then return false end
    
    local murderHRP = murderChar:FindFirstChild("HumanoidRootPart")
    if not murderHRP then return false end
    
    local murderHumanoid = murderChar:FindFirstChildOfClass("Humanoid")
    if not murderHumanoid or murderHumanoid.Health <= 0 then return false end
    
    local savedPos = hrp.CFrame
    
    local teleportPos = murderHRP.CFrame * CFrame.new(0, 0, 3)
    hrp.CFrame = teleportPos
    task.wait(0.05)
    
    if gun.Parent ~= character then
        humanoid:EquipTool(gun)
        task.wait(0.15)
    end
    
    local success = false
    pcall(function()
        local shootEvent = gun:FindFirstChild("Shoot")
        if shootEvent then
            local velocity = murderHRP.Velocity
            local predictedPos = murderHRP.Position + (velocity * 0.12)
            
            local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
            if rightHand then
                shootEvent:FireServer(CFrame.new(rightHand.Position), CFrame.new(predictedPos))
                success = true
            else
                shootEvent:FireServer(CFrame.new(hrp.Position + Vector3.new(0, 3, 0)), CFrame.new(predictedPos))
                success = true
            end
        else
            local remote = ReplicatedStorage:FindFirstChild("Shoot") or ReplicatedStorage:FindFirstChild("Fire")
            if remote then
                remote:FireServer(CFrame.new(hrp.Position), CFrame.new(murderHRP.Position))
                success = true
            end
        end
    end)
    
    task.wait(0.1)
    hrp.CFrame = LOBBY_POSITION
    
    task.delay(0.3, function()
        pcall(function() humanoid:UnequipTools() end)
    end)
    
    return success
end

local function killEveryone()
    local plr = localplayer
    local char = plr.Character
    if not char then return end
    
    local knife = nil
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            knife = tool
            break
        end
    end
    if not knife then
        for _, tool in ipairs(plr.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                knife = tool
                break
            end
        end
        if knife then
            knife.Parent = char
            task.wait(0.2)
            knife = char:FindFirstChildOfClass("Tool")
        end
    end
    
    if not knife then
        return false
    end
    
    local killedCount = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= plr and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local targetHRP = player.Character:FindFirstChild("HumanoidRootPart")
            
            if targetHRP and humanoid and humanoid.Health > 0 then
                pcall(function()
                    knife:Activate()
                    firetouchinterest(targetHRP, knife.Handle, 0)
                    firetouchinterest(targetHRP, knife.Handle, 1)
                    killedCount = killedCount + 1
                end)
                task.wait(0.1)
            end
        end
    end
    
    return true
end

local function hasGun()
    local char = localplayer.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == "Gun" then
                return true
            end
        end
    end
    if localplayer.Backpack then
        for _, tool in ipairs(localplayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == "Gun" then
                return true
            end
        end
    end
    return false
end

local function hasKnife()
    local char = localplayer.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name == "Knife" or tool.Name:find("Knife")) then
                return true
            end
        end
    end
    if localplayer.Backpack then
        for _, tool in ipairs(localplayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name == "Knife" or tool.Name:find("Knife")) then
                return true
            end
        end
    end
    return false
end

local function flingMurdererLoop()
    if flingLoopActive then return end
    flingLoopActive = true
    
    while flingMurderEnabled and autoFarm do
        if hasGun() or hasKnife() then
            break
        end
        
        local murderer = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localplayer then
                local hasKnife = false
                if p.Backpack and p.Backpack:FindFirstChild("Knife") then
                    hasKnife = true
                end
                if not hasKnife and p.Character and p.Character:FindFirstChild("Knife") then
                    hasKnife = true
                end
                if hasKnife then
                    murderer = p
                    break
                end
            end
        end
        
        if not murderer or not murderer.Character then
            break
        end
        
        local murderHumanoid = murderer.Character:FindFirstChildOfClass("Humanoid")
        if not murderHumanoid or murderHumanoid.Health <= 0 then
            break
        end
        
        local char = localplayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local murderHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
                if murderHRP then
                    hrp.CFrame = murderHRP.CFrame * CFrame.new(0, 0, 3)
                end
            end
        end
        
        task.wait(0.1)
        
        pcall(function()
            SkidFling(murderer)
        end)
        
        task.wait(0.05)
        
        if not murderHumanoid.Parent or murderHumanoid.Health <= 0 then
            break
        end
    end
    
    flingLoopActive = false
end

local function autoShootMurdererLoop()
    if shootLoopActive then return end
    shootLoopActive = true
    
    while autoShootMurderEnabled and autoFarm do
        if not hasGun() then
            task.wait(2)
            continue
        end
        
        local murderer = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localplayer then
                local hasKnife = false
                if p.Backpack and p.Backpack:FindFirstChild("Knife") then
                    hasKnife = true
                end
                if not hasKnife and p.Character and p.Character:FindFirstChild("Knife") then
                    hasKnife = true
                end
                if hasKnife then
                    murderer = p
                    break
                end
            end
        end
        
        if not murderer then
            task.wait(2)
            continue
        end
        
        if not murderer.Character then
            task.wait(2)
            continue
        end
        
        local murderHumanoid = murderer.Character:FindFirstChildOfClass("Humanoid")
        if not murderHumanoid or murderHumanoid.Health <= 0 then
            break
        end
        
        local success = tpShootMurderer()
        
        if success then
            task.wait(0.8)
            if not murderer.Character or not murderer.Character:FindFirstChildOfClass("Humanoid") or 
               murderer.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
                break
            end
        end
        
        task.wait(3)
    end
    
    shootLoopActive = false
end

local function enableAntiFling()
    if antiFlingConnection then return end
    local speaker = localplayer
    antiFlingConnection = RunService.PreSimulation:Connect(function()
        if not autoFarm then return end
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= speaker and player.Character then
                for _, v in pairs(player.Character:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end
    end)
end

local function disableAntiFling()
    if antiFlingConnection then antiFlingConnection:Disconnect(); antiFlingConnection = nil end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localplayer and player.Character then
            for _, v in pairs(player.Character:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = true end
            end
        end
    end
end

local function enableNoclip()
    for _, conn in pairs(noclipConnections) do pcall(function() conn:Disconnect() end) end
    noclipConnections = {}
    local char = localplayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local c1 = char.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then d.CanCollide = false end
    end)
    table.insert(noclipConnections, c1)
    local c2 = RunService.PreSimulation:Connect(function()
        if char and char.Parent then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
    end)
    table.insert(noclipConnections, c2)
end

local function disableNoclip()
    for _, conn in pairs(noclipConnections) do pcall(function() conn:Disconnect() end) end
    noclipConnections = {}
    local char = localplayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = true end
    end
end

local function createFloatingPad()
    if fakeFloor and fakeFloor.Parent then fakeFloor:Destroy() end
    if padFollowConnection then padFollowConnection:Disconnect(); padFollowConnection = nil end
    local pad = Instance.new("Part")
    pad.Anchored = true; pad.CanCollide = true
    pad.Size = Vector3.new(10, 1, 10); pad.Transparency = 1
    pad.CanQuery = false; pad.CastShadow = false
    pad.Name = "FloatingPad"; pad.Parent = Workspace
    fakeFloor = pad
    padFollowConnection = RunService.PreSimulation:Connect(function()
        local char = localplayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and pad and pad.Parent then
            pad.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y + PAD_Y_OFFSET, hrp.Position.Z)
        end
    end)
end

local function removeInvisibleFloor()
    if padFollowConnection then padFollowConnection:Disconnect(); padFollowConnection = nil end
    if fakeFloor and fakeFloor.Parent then fakeFloor:Destroy() end
    fakeFloor = nil
end

local function cancelActiveTween()
    if activeTween then pcall(function() activeTween:Cancel() end); activeTween = nil end
end

local function anchorHRP(hrp, state)
    if hrp then hrp.Anchored = state end
end

local function forceServerSync(char)
    if char and char.PrimaryPart then
        char:PivotTo(CFrame.new(char.PrimaryPart.Position))
        char.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
    end
end

local function setCharacterVisibility(visible)
    local char = localplayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.LocalTransparencyModifier = visible and 0 or 1 end
    end
end

local function isCoinValid(coin)
    if not coin or not coin.Parent then return false end
    if not coin:IsDescendantOf(Workspace) then return false end
    if not coin:IsA("BasePart") then return false end
    return coin:FindFirstChild("CoinVisual") ~= nil
end

local function findActiveCoinContainer()
    for _, child in ipairs(Workspace:GetChildren()) do
        local cc = child:FindFirstChild("CoinContainer")
        if cc then return cc, child end
    end
    return nil, nil
end

local MURDERER_DANGER_RADIUS = 20
local function getMurdererHRP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == localplayer then continue end
        local char = player.Character
        if not char then continue end
        local hasKnife = char:FindFirstChild("Knife") ~= nil
        if not hasKnife then
            local bp = player:FindFirstChild("Backpack")
            if bp then hasKnife = bp:FindFirstChild("Knife") ~= nil end
        end
        if hasKnife then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then return hrp end
        end
    end
    return nil
end

local function isCoinNearMurderer(coinPos)
    if not avoidMurderCoins then return false end
    local murderHRP = getMurdererHRP()
    if not murderHRP then return false end
    return (murderHRP.Position - coinPos).Magnitude < MURDERER_DANGER_RADIUS
end

local function findNearestCoin(hrp)
    local nearest, bestDist = nil, math.huge
    local coinContainer = findActiveCoinContainer()
    if coinContainer then
        for _, coin in ipairs(coinContainer:GetChildren()) do
            if coin:IsA("BasePart") and coin.Name == "Coin_Server"
                and isCoinValid(coin) and not visitedCoins[coin]
                and not isCoinNearMurderer(coin.Position)
            then
                local dist = (hrp.Position - coin.Position).Magnitude
                if dist < bestDist then bestDist = dist; nearest = coin end
            end
        end
    end
    return nearest
end

local function isRoundActive()
    local coinContainer = findActiveCoinContainer()
    if not coinContainer then return false end
    for _, coin in ipairs(coinContainer:GetChildren()) do
        if coin:IsA("BasePart") and coin.Name == "Coin_Server" and coin:FindFirstChild("CoinVisual") then
            return true
        end
    end
    return false
end

local function allCoinsGone()
    local coinContainer = findActiveCoinContainer()
    if not coinContainer then return true end
    for _, coin in ipairs(coinContainer:GetChildren()) do
        if coin:IsA("BasePart") and coin.Name == "Coin_Server" and coin:FindFirstChild("CoinVisual") then
            return false
        end
    end
    return true
end

local function getActiveMap()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj:FindFirstChild("Spawns") and not obj.Name:lower():find("lobby") then
            return obj
        end
    end
    return nil
end

local function killCharacter()
    local char = localplayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.Health = 0 end
    end
end

local function waitForNewMapToLoad()
    waitingForNewMap = true
    local oldMap = getActiveMap()
    while getActiveMap() == oldMap and oldMap and oldMap.Parent do task.wait(0.5) end
    local timeout = tick() + 60
    while not getActiveMap() and tick() < timeout do task.wait(0.5) end
    task.wait(2)
    waitingForNewMap = false
end

local function isPlayerSpectating()
    local char = localplayer.Character
    if not char then return true end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return true end
    if hrp.Position.Y > 400 and isRoundActive() then return true end
    return false
end

local function waitIfSpectatingMidRound()
    if not isRoundActive() then return end
    if not isPlayerSpectating() then return end
    isSpectatingMidRound = true
    while autoFarm and isRoundActive() do task.wait(0.5) end
    if autoFarm then waitForNewMapToLoad() end
    isSpectatingMidRound = false
    visitedCoins = {}
end

local function doNormalFarm(hrp)
    if not hrp or not hrp.Parent or deadUntilNextRound or waitingForNewMap then return end
    local coin = findNearestCoin(hrp)
    while coin and not coin:FindFirstChild("CoinVisual") do
        visitedCoins[coin] = true; coin = findNearestCoin(hrp)
    end
    if not (coin and isCoinValid(coin)) then return end
    task.wait()
    if not isCoinValid(coin) then return end
    visitedCoins[coin] = true
    local targetPos = Vector3.new(coin.Position.X, coin.Position.Y, coin.Position.Z)
    local tweenTime = math.max((hrp.Position - targetPos).Magnitude / tweenSpeed, 0.1)
    cancelActiveTween()
    activeTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), { CFrame = CFrame.new(targetPos) })
    local coinGone = false
    local watchConn
    watchConn = RunService.Heartbeat:Connect(function()
        if not isCoinValid(coin) then
            coinGone = true; cancelActiveTween()
            if watchConn then watchConn:Disconnect(); watchConn = nil end
        end
    end)
    activeTween:Play(); activeTween.Completed:Wait(); activeTween = nil
    if watchConn then watchConn:Disconnect(); watchConn = nil end
    if not coinGone and isCoinValid(coin) then hrp.CFrame = CFrame.new(targetPos); task.wait(0.05) end
end

local function handleRoundEnd(hrp)
    cancelActiveTween(); disableNoclip(); visitedCoins = {}
    removeInvisibleFloor(); anchorHRP(hrp, false); deadUntilNextRound = true

    local coinsGone = allCoinsGone()
    local hasGunNow = hasGun()
    local hasKnifeNow = hasKnife()
    
    if killAllEnabled and coinsGone and hasKnifeNow then
        task.spawn(function()
            killEveryone()
        end)
        local char = localplayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = LOBBY_POSITION end
        end
        return
    end
    
    if autoShootMurderEnabled and coinsGone and hasGunNow then
        task.spawn(function()
            autoShootMurdererLoop()
        end)
        local char = localplayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = LOBBY_POSITION end
        end
        return
    end

    if flingMurderEnabled and coinsGone and not hasGunNow and not hasKnifeNow then
        task.spawn(function()
            flingMurdererLoop()
        end)
        local char = localplayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = LOBBY_POSITION end
        end
        return
    end
    
    if waitInLobbyEnabled then
        local char = localplayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = LOBBY_POSITION end
        end
        return
    end
    
    if autoResetEnabled then
        killCharacter()
        return
    end
end

local function normalFarmMain(hrp)
    if not hrp or waitingForNewMap then return end
    while autoFarm and not deadUntilNextRound and not waitingForNewMap and farmMode == "Normal" do
        if not isRoundActive() or allCoinsGone() then handleRoundEnd(hrp); break end
        doNormalFarm(hrp); task.wait(0.05)
    end
end

local function doSafe2Farm(hrp)
    if not hrp or not hrp.Parent or deadUntilNextRound or waitingForNewMap then return end
    local coin = findNearestCoin(hrp)
    while coin and not coin:FindFirstChild("CoinVisual") do
        visitedCoins[coin] = true; coin = findNearestCoin(hrp)
    end
    if not (coin and isCoinValid(coin)) then return end
    task.wait()
    if not isCoinValid(coin) then return end
    visitedCoins[coin] = true
    anchorHRP(hrp, false)
    local deepPos = Vector3.new(coin.Position.X, coin.Position.Y + safe2UndergroundOffset, coin.Position.Z)
    local tweenTime = math.max((hrp.Position - deepPos).Magnitude / tweenSpeed, 0.1)
    enableNoclip(); createFloatingPad(); cancelActiveTween()
    activeTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), { CFrame = CFrame.new(deepPos) })
    local coinGone = false
    local watchConn
    watchConn = RunService.Heartbeat:Connect(function()
        if not isCoinValid(coin) then
            coinGone = true; cancelActiveTween()
            if watchConn then watchConn:Disconnect(); watchConn = nil end
        end
    end)
    activeTween:Play(); activeTween.Completed:Wait(); activeTween = nil
    if watchConn then watchConn:Disconnect(); watchConn = nil end
    disableNoclip(); removeInvisibleFloor(); forceServerSync(localplayer.Character)
    if coinGone then
        anchorHRP(hrp, true)
        local next = findNearestCoin(hrp)
        if next and isCoinValid(next) then doSafe2Farm(hrp) end
        return
    end
    if not isCoinValid(coin) then anchorHRP(hrp, true); return end
    local pickupPos = Vector3.new(coin.Position.X, coin.Position.Y + safe2PickupOffsetY, coin.Position.Z)
    setCharacterVisibility(false)
    hrp.CFrame = CFrame.new(pickupPos)
    task.wait(0.001)
    setCharacterVisibility(true)
    if not isCoinValid(coin) then hrp.CFrame = CFrame.new(deepPos); anchorHRP(hrp, true); return end
    hrp.CFrame = CFrame.new(deepPos); anchorHRP(hrp, true)
end

local function safeFarmMain(hrp)
    if not hrp or waitingForNewMap then return end
    anchorHRP(hrp, false); forceServerSync(localplayer.Character); anchorHRP(hrp, true)
    while autoFarm and not deadUntilNextRound and not waitingForNewMap and farmMode == "Underground" do
        if not isRoundActive() or allCoinsGone() then handleRoundEnd(hrp); break end
        doSafe2Farm(hrp); task.wait(0.05)
    end
    removeInvisibleFloor(); anchorHRP(hrp, false)
end

local function applyLayPhysics(hrp)
    if layGyro and layGyro.Parent then layGyro:Destroy() end
    if layVelocity and layVelocity.Parent then layVelocity:Destroy() end

    local char = localplayer.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end

    for _, v in pairs(hrp:GetChildren()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyAngularVelocity") then
            v:Destroy()
        end
    end    local layTarget = CFrame.new(hrp.Position) * CFrame.Angles(math.rad(90), 0, 0)
    hrp.CFrame = layTarget

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.D = 500
    bg.P = 100000
    bg.CFrame = layTarget
    bg.Parent = hrp
    layGyro = bg

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = hrp
    layVelocity = bv
end

local function removeLayPhysics()
    if layStabilizeConnection then
        layStabilizeConnection:Disconnect()
        layStabilizeConnection = nil
    end

    if layGyro and layGyro.Parent then layGyro:Destroy() end
    if layVelocity and layVelocity.Parent then layVelocity:Destroy() end
    layGyro = nil
    layVelocity = nil

    local char = localplayer.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end
end

local function doLayFarm(hrp)
    if not hrp or not hrp.Parent or deadUntilNextRound or waitingForNewMap then return end

    local coin = findNearestCoin(hrp)

    while coin and not coin:FindFirstChild("CoinVisual") do
        visitedCoins[coin] = true
        coin = findNearestCoin(hrp)
    end

    if not coin or not isCoinValid(coin) then
        task.wait(0.1)
        return
    end

    task.wait()
    if not isCoinValid(coin) then
        task.wait(0.1)
        return
    end

    visitedCoins[coin] = true
    anchorHRP(hrp, false)

    local deepPos = Vector3.new(coin.Position.X, coin.Position.Y + layUndergroundOffset, coin.Position.Z)
    local tweenTime = math.max((hrp.Position - deepPos).Magnitude / tweenSpeed, 0.1)

    if tweenTime > 0 then
        applyLayPhysics(hrp)

        if layStabilizeConnection then layStabilizeConnection:Disconnect() end
        layStabilizeConnection = RunService.PreSimulation:Connect(function()
            if layVelocity and layVelocity.Parent then
                layVelocity.Velocity = Vector3.new(0, 0, 0)
            end
            if layGyro and layGyro.Parent and hrp and hrp.Parent then
                layGyro.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(math.rad(90), 0, 0)
            end
        end)

        enableNoclip()
        createFloatingPad()
        cancelActiveTween()

        local targetCFrame = CFrame.new(deepPos) * CFrame.Angles(math.rad(90), 0, 0)
        activeTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), { CFrame = targetCFrame })

        local coinGone = false
        local watchConn
        watchConn = RunService.Heartbeat:Connect(function()
            if not isCoinValid(coin) then
                coinGone = true
                cancelActiveTween()
                if watchConn then watchConn:Disconnect(); watchConn = nil end
            end
        end)

        activeTween:Play()
        activeTween.Completed:Wait()
        activeTween = nil

        if watchConn then watchConn:Disconnect(); watchConn = nil end

        if layStabilizeConnection then
            layStabilizeConnection:Disconnect()
            layStabilizeConnection = nil
        end

        disableNoclip()
        removeInvisibleFloor()
        forceServerSync(localplayer.Character)

        if coinGone then
            anchorHRP(hrp, true)
            local next = findNearestCoin(hrp)
            if next and isCoinValid(next) then
                doLayFarm(hrp)
            end
            return
        end
    end

    if not isCoinValid(coin) then
        anchorHRP(hrp, true)
        return
    end

    local pickupPos = Vector3.new(coin.Position.X, coin.Position.Y, coin.Position.Z)

    setCharacterVisibility(false)
    hrp.CFrame = CFrame.new(pickupPos) * CFrame.Angles(math.rad(90), 0, 0)
    task.wait(0.001)
    setCharacterVisibility(true)

    if not isCoinValid(coin) then
        hrp.CFrame = CFrame.new(deepPos) * CFrame.Angles(math.rad(90), 0, 0)
        anchorHRP(hrp, true)
        return
    end

    hrp.CFrame = CFrame.new(deepPos) * CFrame.Angles(math.rad(90), 0, 0)
    anchorHRP(hrp, true)
end

local function layFarmMain(hrp)
    if not hrp or waitingForNewMap then return end

    while autoFarm and not deadUntilNextRound and not waitingForNewMap and farmMode == "Lay" do
        if not isRoundActive() or allCoinsGone() then
            handleRoundEnd(hrp)
            break
        end

        doLayFarm(hrp)
        task.wait()
    end

    removeLayPhysics()
    removeInvisibleFloor()
    anchorHRP(hrp, false)
end

local function customDeathHandler()
    deadUntilNextRound = true; cancelActiveTween(); disableNoclip()
    visitedCoins = {}; removeInvisibleFloor(); removeLayPhysics(); disableAntiFling()
    if localplayer.Character and localplayer.Character:FindFirstChild("HumanoidRootPart") then
        localplayer.Character.HumanoidRootPart.Anchored = false
    end
end

local function startFarmLoop()
    if farmLoopRunning then return end
    farmLoopRunning = true
    enableAntiFling()
    task.spawn(function()
        waitIfSpectatingMidRound()
        if not autoFarm then farmLoopRunning = false; return end
        while autoFarm do
            if deadUntilNextRound then
                local char = localplayer.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then
                    localplayer.CharacterAdded:Wait(); task.wait(0.5)
                end
                waitForNewMapToLoad(); deadUntilNextRound = false; visitedCoins = {}
                task.wait(1); task.wait(0.3); continue
            end
            local char = localplayer.Character
            if not char then task.wait(0.5); continue end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid then
                if humanoidDiedConn then pcall(function() humanoidDiedConn:Disconnect() end) end
                humanoidDiedConn = humanoid.Died:Connect(customDeathHandler)
            end
            if not hrp or not humanoid or humanoid.Health <= 0 or deadUntilNextRound or waitingForNewMap then
                task.wait(0.5); continue
            end
            local waitStart = tick()
            while autoFarm and not isRoundActive() and not deadUntilNextRound do
                task.wait(0.1)
                if tick() - waitStart > 90 then break end
            end
            if not autoFarm or deadUntilNextRound then task.wait(0.2); continue end
            char = localplayer.Character
            if not char then task.wait(0.5); continue end
            hrp = char:FindFirstChild("HumanoidRootPart")
            humanoid = char:FindFirstChild("Humanoid")
            if not hrp or not humanoid or humanoid.Health <= 0 then task.wait(0.5); continue end
            local coin = findNearestCoin(hrp)
            if farmMode == "Underground" and coin and isCoinValid(coin) then
                hrp.CFrame = CFrame.new(coin.Position.X, coin.Position.Y + safe2UndergroundOffset, coin.Position.Z)
                forceServerSync(char); task.wait(0.1)
            end
            if farmMode == "Underground" then 
                safeFarmMain(hrp) 
            elseif farmMode == "Lay" then
                layFarmMain(hrp)
            else 
                normalFarmMain(hrp) 
            end
        end
        farmLoopRunning = false; disableAntiFling()
    end)
end

localplayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    local char = localplayer.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then
        if humanoidDiedConn then humanoidDiedConn:Disconnect() end
        humanoidDiedConn = humanoid.Died:Connect(customDeathHandler)
    end
end)

Workspace.ChildAdded:Connect(function(child)
    if not autoFarm or deadUntilNextRound then return end
    if child:IsA("Model") and not child.Name:lower():find("lobby") and child:FindFirstChild("Spawns") then
        task.spawn(function()
            task.wait(2)
            if autoFarm and not deadUntilNextRound and not waitingForNewMap then
                local char = localplayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local mapModel = getActiveMap()
                if hrp and mapModel then
                    local spawnsFolder = mapModel:FindFirstChild("Spawns")
                    if spawnsFolder then
                        local pts = spawnsFolder:GetChildren()
                        if #pts > 0 then
                            hrp.CFrame = CFrame.new(pts[math.random(1, #pts)].Position + Vector3.new(0, 3, 0))
                            forceServerSync(char)
                        end
                    end
                end
            end
        end)
    end
end)

-- =============================================
-- UI CREATION (FIXED TOGGLES)
-- =============================================

local sg = Instance.new("ScreenGui")
sg.Name = "MM2Farm"; sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent = game.CoreGui

local W, H = 280, 380

local main = Instance.new("Frame")
main.Size = UDim2.new(0, W, 0, H)
main.Position = UDim2.new(0.5, -W/2, 0.08, 0)
main.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
main.BorderSizePixel = 0
main.Active = true
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local mainStroke = Instance.new("UIStroke", main)
mainStroke.Color = Color3.fromRGB(50, 50, 55); mainStroke.Thickness = 1

local titleH = 32
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, titleH)
titleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 3
titleBar.Parent = main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0.5, 0)
titleFix.Position = UDim2.new(0, 0, 0.5, 0)
titleFix.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
titleFix.BorderSizePixel = 0; titleFix.Parent = titleBar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -100, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "Summer Hub Auto Farm"
titleLbl.TextColor3 = Color3.fromRGB(200, 200, 205)
titleLbl.TextSize = 12
titleLbl.Font = Enum.Font.GothamMedium
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 4
titleLbl.Parent = titleBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 22, 0, 22)
minBtn.Position = UDim2.new(1, -55, 0.5, -11)
minBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
minBtn.BorderSizePixel = 0
minBtn.Text = "−"
minBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
minBtn.TextSize = 14
minBtn.Font = Enum.Font.GothamBold
minBtn.ZIndex = 5
minBtn.Parent = titleBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -30, 0.5, -11)
closeBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
closeBtn.TextSize = 12
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 5
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -titleH)
body.Position = UDim2.new(0, 0, 0, titleH)
body.BackgroundTransparency = 1
body.ClipsDescendants = true
body.Parent = main

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -10, 1, -8)
content.Position = UDim2.new(0, 5, 0, 4)
content.BackgroundTransparency = 1
content.ClipsDescendants = true
content.Parent = body

local farmPage = Instance.new("ScrollingFrame")
farmPage.Size = UDim2.new(1, 0, 1, 0)
farmPage.BackgroundTransparency = 1
farmPage.BorderSizePixel = 0
farmPage.ScrollBarThickness = 2
farmPage.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
farmPage.CanvasSize = UDim2.new(0, 0, 0, 0)
farmPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
farmPage.Visible = true
farmPage.Parent = content
local list = Instance.new("UIListLayout", farmPage)
list.FillDirection = Enum.FillDirection.Vertical
list.Padding = UDim.new(0, 0)
list.SortOrder = Enum.SortOrder.LayoutOrder
local pad = Instance.new("UIPadding", farmPage)
pad.PaddingLeft = UDim.new(0, 5)
pad.PaddingRight = UDim.new(0, 5)
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingBottom = UDim.new(0, 4)

local function makeSection(parent, text, order)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 18)
    wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = order
    wrap.Parent = parent
    local lbl = Instance.new("TextLabel", wrap)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(85, 85, 95)
    lbl.TextSize = 8
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

local function makeDivider(parent, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 1)
    f.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.Parent = parent
end

-- FIXED TOGGLE CREATION - now buttons are clickable
local function makeToggle(parent, label, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -48, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(185, 185, 195)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("TextButton", row)
    track.Size = UDim2.new(0, 38, 0, 20)
    track.Position = UDim2.new(1, -40, 0.5, -10)
    track.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.ZIndex = 10
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local ts = Instance.new("UIStroke", track)
    ts.Color = Color3.fromRGB(58, 58, 63)
    ts.Thickness = 1

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(100, 100, 110)
    knob.BorderSizePixel = 0
    knob.ZIndex = 11
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    -- Add a larger invisible click area for easier clicking
    local hitbox = Instance.new("TextButton", row)
    hitbox.Size = UDim2.new(0, 50, 0, 30)
    hitbox.Position = UDim2.new(1, -50, 0.5, -15)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.ZIndex = 5
    hitbox.AutoButtonColor = false
    
    -- Forward clicks from hitbox to track
    hitbox.MouseButton1Click:Connect(function()
        track:Click()
    end)

    return track, knob
end

local function setToggle(track, knob, state)
    TweenService:Create(track, TweenInfo.new(0.14), {
        BackgroundColor3 = state and Color3.fromRGB(65, 65, 72) or Color3.fromRGB(45, 45, 50)
    }):Play()
    TweenService:Create(knob, TweenInfo.new(0.14), {
        Position = state and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7),
        BackgroundColor3 = state and Color3.fromRGB(220, 220, 230) or Color3.fromRGB(100, 100, 110)
    }):Play()
end

makeSection(farmPage, "AUTO FARM", 1)
local farmTrack, farmKnob = makeToggle(farmPage, "Auto Farm", 2)

local modeRow = Instance.new("Frame")
modeRow.Size = UDim2.new(1, 0, 0, 32)
modeRow.BackgroundTransparency = 1
modeRow.LayoutOrder = 3
modeRow.Parent = farmPage

local modeLbl = Instance.new("TextLabel", modeRow)
modeLbl.Size = UDim2.new(0.45, 0, 1, 0)
modeLbl.BackgroundTransparency = 1
modeLbl.Text = "Mode"
modeLbl.TextColor3 = Color3.fromRGB(185, 185, 195)
modeLbl.TextSize = 11
modeLbl.Font = Enum.Font.Gotham
modeLbl.TextXAlignment = Enum.TextXAlignment.Left

local modeBtn = Instance.new("TextButton", modeRow)
modeBtn.Size = UDim2.new(0, 90, 0, 22)
modeBtn.Position = UDim2.new(1, -92, 0.5, -11)
modeBtn.BackgroundColor3 = Color3.fromRGB(34, 34, 38)
modeBtn.BorderSizePixel = 0
modeBtn.Text = "Select  ▾"
modeBtn.TextColor3 = Color3.fromRGB(175, 175, 185)
modeBtn.TextSize = 10
modeBtn.Font = Enum.Font.GothamMedium
modeBtn.AutoButtonColor = false
Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 5)
local mbs = Instance.new("UIStroke", modeBtn)
mbs.Color = Color3.fromRGB(55, 55, 60)
mbs.Thickness = 1

local modeDrop = Instance.new("Frame")
modeDrop.Size = UDim2.new(0, 92, 0, 78)
modeDrop.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
modeDrop.BorderSizePixel = 0
modeDrop.Visible = false
modeDrop.ZIndex = 30
modeDrop.Parent = main
Instance.new("UICorner", modeDrop).CornerRadius = UDim.new(0, 7)
local mds = Instance.new("UIStroke", modeDrop)
mds.Color = Color3.fromRGB(55, 55, 60)
mds.Thickness = 1

for i, opt in ipairs({"Normal","Underground","Lay"}) do
    local b = Instance.new("TextButton", modeDrop)
    b.Size = UDim2.new(1, 0, 0, 26)
    b.Position = UDim2.new(0, 0, 0, (i-1)*26)
    b.BackgroundTransparency = 1
    b.Text = opt
    b.TextColor3 = Color3.fromRGB(185, 185, 195)
    b.TextSize = 10
    b.Font = Enum.Font.Gotham
    b.ZIndex = 31
    b.TextXAlignment = Enum.TextXAlignment.Left
    local bp = Instance.new("UIPadding", b)
    bp.PaddingLeft = UDim.new(0, 8)
    b.MouseEnter:Connect(function() b.BackgroundTransparency = 0; b.BackgroundColor3 = Color3.fromRGB(40, 40, 45) end)
    b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
    b.MouseButton1Click:Connect(function()
        farmMode = opt
        modeBtn.Text = opt .. "  ▾"
        modeDrop.Visible = false
        if autoFarm then
            cancelActiveTween()
            disableNoclip()
            removeInvisibleFloor()
            removeLayPhysics()
            local char = localplayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = false end
            end
        end
    end)
end

modeBtn.MouseButton1Click:Connect(function()
    modeDrop.Visible = not modeDrop.Visible
    if modeDrop.Visible then
        local ap = modeBtn.AbsolutePosition
        local mp = main.AbsolutePosition
        modeDrop.Position = UDim2.new(0, ap.X - mp.X, 0, ap.Y - mp.Y + 26)
    end
end)

makeDivider(farmPage, 4)
makeSection(farmPage, "WHEN COIN BAG FULL", 5)
local resetTrack, resetKnob = makeToggle(farmPage, "Auto Reset", 6)
local killAllTrack, killAllKnob = makeToggle(farmPage, "Kill All (Knife)", 7)
local shootTrack, shootKnob = makeToggle(farmPage, "Auto Shoot Murder", 8)
local flingTrack, flingKnob = makeToggle(farmPage, "Fling Murderer", 9)
local lobbyTrack, lobbyKnob = makeToggle(farmPage, "Wait in Lobby", 10)

makeDivider(farmPage, 11)
makeSection(farmPage, "SETTINGS", 12)
local avoidTrack, avoidKnob = makeToggle(farmPage, "Avoid Murderer Coins", 13)

local speedWrap = Instance.new("Frame")
speedWrap.Size = UDim2.new(1, 0, 0, 44)
speedWrap.BackgroundTransparency = 1
speedWrap.LayoutOrder = 14
speedWrap.Parent = farmPage

local speedLbl = Instance.new("TextLabel", speedWrap)
speedLbl.Size = UDim2.new(0.65, 0, 0, 16)
speedLbl.BackgroundTransparency = 1
speedLbl.Text = "Tween Speed"
speedLbl.TextColor3 = Color3.fromRGB(175, 175, 185)
speedLbl.TextSize = 10
speedLbl.Font = Enum.Font.Gotham
speedLbl.TextXAlignment = Enum.TextXAlignment.Left

local speedVal = Instance.new("TextLabel", speedWrap)
speedVal.Size = UDim2.new(0.35, 0, 0, 16)
speedVal.Position = UDim2.new(0.65, 0, 0, 0)
speedVal.BackgroundTransparency = 1
speedVal.Text = tostring(tweenSpeed)
speedVal.TextColor3 = Color3.fromRGB(200, 200, 210)
speedVal.TextSize = 10
speedVal.Font = Enum.Font.GothamMedium
speedVal.TextXAlignment = Enum.TextXAlignment.Right

local sTrack = Instance.new("Frame", speedWrap)
sTrack.Size = UDim2.new(1, 0, 0, 3)
sTrack.Position = UDim2.new(0, 0, 0, 26)
sTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
sTrack.BorderSizePixel = 0
Instance.new("UICorner", sTrack).CornerRadius = UDim.new(1, 0)

local sFill = Instance.new("Frame", sTrack)
sFill.Size = UDim2.new(tweenSpeed/30, 0, 1, 0)
sFill.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
sFill.BorderSizePixel = 0
Instance.new("UICorner", sFill).CornerRadius = UDim.new(1, 0)

local sKnob = Instance.new("Frame", sTrack)
sKnob.Size = UDim2.new(0, 12, 0, 12)
sKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sKnob.Position = UDim2.new(tweenSpeed/30, 0, 0.5, 0)
sKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
sKnob.BorderSizePixel = 0
Instance.new("UICorner", sKnob).CornerRadius = UDim.new(1, 0)

local sHit = Instance.new("TextButton", sTrack)
sHit.Size = UDim2.new(1, 0, 0, 20)
sHit.Position = UDim2.new(0,0,0.5,-10)
sHit.BackgroundTransparency = 1
sHit.Text = ""

local sliding = false
local function updateSlider(x)
    local rel = math.clamp((x - sTrack.AbsolutePosition.X) / sTrack.AbsoluteSize.X, 0, 1)
    local spd = math.max(math.round(rel * 30), 1)
    tweenSpeed = spd
    speedVal.Text = tostring(spd)
    sFill.Size = UDim2.new(rel, 0, 1, 0)
    sKnob.Position = UDim2.new(rel, 0, 0.5, 0)
end

sHit.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        sliding = true
        updateSlider(i.Position.X)
    end
end)
sHit.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        sliding = false
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        updateSlider(i.Position.X)
    end
end)

-- FIXED: Proper toggle click handlers
farmTrack.MouseButton1Click:Connect(function()
    if not farmMode then 
        game:GetService("StarterGui"):SetCore("SendNotification",{
            Title = "Error",
            Text = "Select a farm mode first!",
            Duration = 3
        })
        return 
    end
    autoFarm = not autoFarm
    setToggle(farmTrack, farmKnob, autoFarm)
    if autoFarm then
        deadUntilNextRound = false
        visitedCoins = {}
        startFarmLoop()
    else
        cancelActiveTween()
        disableNoclip()
        removeInvisibleFloor()
        removeLayPhysics()
        disableAntiFling()
        flingLoopActive = false
        shootLoopActive = false
        local char = localplayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
    end
end)

resetTrack.MouseButton1Click:Connect(function()
    autoResetEnabled = not autoResetEnabled
    setToggle(resetTrack, resetKnob, autoResetEnabled)
end)

killAllTrack.MouseButton1Click:Connect(function()
    killAllEnabled = not killAllEnabled
    setToggle(killAllTrack, killAllKnob, killAllEnabled)
end)

shootTrack.MouseButton1Click:Connect(function()
    autoShootMurderEnabled = not autoShootMurderEnabled
    setToggle(shootTrack, shootKnob, autoShootMurderEnabled)
    if not autoShootMurderEnabled then
        shootLoopActive = false
    end
end)

flingTrack.MouseButton1Click:Connect(function()
    flingMurderEnabled = not flingMurderEnabled
    setToggle(flingTrack, flingKnob, flingMurderEnabled)
    if not flingMurderEnabled then
        flingLoopActive = false
    end
end)

lobbyTrack.MouseButton1Click:Connect(function()
    waitInLobbyEnabled = not waitInLobbyEnabled
    setToggle(lobbyTrack, lobbyKnob, waitInLobbyEnabled)
end)

avoidTrack.MouseButton1Click:Connect(function()
    avoidMurderCoins = not avoidMurderCoins
    setToggle(avoidTrack, avoidKnob, avoidMurderCoins)
end)

local minimized = false
local savedPosition = main.Position

minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        savedPosition = main.Position
        main.Size = UDim2.new(0, 280, 0, 32)
        body.Visible = false
        mainStroke.Visible = false
        minBtn.Text = "+"
    else
        main.Size = UDim2.new(0, 280, 0, 380)
        body.Visible = true
        mainStroke.Visible = true
        minBtn.Text = "−"
        main.Position = savedPosition
    end
end)

local function stopAllFarming()
    autoFarm = false
    farmLoopRunning = false
    cancelActiveTween()
    disableNoclip()
    removeInvisibleFloor()
    removeLayPhysics()
    disableAntiFling()
    flingLoopActive = false
    shootLoopActive = false
    local char = localplayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = false end
    end
end

closeBtn.MouseButton1Click:Connect(function()
    stopAllFarming()
    main:Destroy()
    sg:Destroy()
end)

local function makeDraggableMobile(handle, target)
    local dragData = {active = false, startPos = nil, startMouse = nil, startOffset = nil}
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragData.active = true
            dragData.startPos = target.Position
            dragData.startMouse = input.Position
            local absPos = target.AbsolutePosition
            dragData.startOffset = Vector2.new(input.Position.X - absPos.X, 
                                               input.Position.Y - absPos.Y)
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if not dragData.active then return end
        local delta = input.Position - dragData.startMouse
        local vp = workspace.CurrentCamera.ViewportSize
        local newX = dragData.startPos.X.Scale + (dragData.startPos.X.Offset + delta.X) / vp.X
        local newY = dragData.startPos.Y.Scale + (dragData.startPos.Y.Offset + delta.Y) / vp.Y
        target.Position = UDim2.new(newX, 0, newY, 0)
    end)
    
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragData.active = false
        end
    end)
end

makeDraggableMobile(titleBar, main)

UserInputService.InputBegan:Connect(function(inp)
    if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local mp = inp.Position
    local function out(f)
        local p, s = f.AbsolutePosition, f.AbsoluteSize
        return not (mp.X >= p.X and mp.X <= p.X+s.X and mp.Y >= p.Y and mp.Y <= p.Y+s.Y)
    end
    if modeDrop.Visible and out(modeDrop) and out(modeBtn) then modeDrop.Visible = false end
end)
