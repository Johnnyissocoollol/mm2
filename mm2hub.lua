setclipboard = function() end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localplayer = Players.LocalPlayer

local playerData = {}
local loopThrowInterval = 1
local loopThrowEnabled = false
local loopThrowRunning = false
local loopThrowConnection = nil

local espEnabled = false
local outlineEnabled = false
local highlightEnabled = false
local espHookedPlayers = {}

local noclipEnabled = false
local noclipConnection = nil
local infiniteJumpEnabled = false
local infiniteJumpConnection = nil

local speedGlitchEnabled = false
local speedGlitchConnection = nil
local SPEED_GLITCH_BOOST = 65
local SPEED_GLITCH_NORMAL = 16

local WeaponDB = nil
local weaponLookup = {}

local function initWeaponDB()
    if WeaponDB then return end
    pcall(function()
        local Sync = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"))
        WeaponDB = Sync.Weapons
        if WeaponDB then
            for key, info in pairs(WeaponDB) do
                if type(info) == "table" then
                    local kl = key:lower()
                    weaponLookup[kl] = weaponLookup[kl] or key
                    local dn = info.ItemName or info.DisplayName or info.Name
                    if dn then
                        dn = tostring(dn):lower()
                        weaponLookup[dn] = weaponLookup[dn] or key
                    end
                end
            end
        end
    end)
end

local function resolveWeaponInput(text)
    if not text or text == "" then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    if WeaponDB and WeaponDB[text] then return text end
    return weaponLookup[text:lower()]
end

local function spawnWeaponToInventory(name, amount)
    amount = amount or 1
    initWeaponDB()
    if not WeaponDB then return false end
    pcall(function()
        local ProfileData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ProfileData"))
        local InvDataChanged = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory"):WaitForChild("InventoryDataChanged")
        local owned = ProfileData.Weapons.Owned
        owned[name] = (owned[name] or 0) + amount
        InvDataChanged:Fire("Weapons", name, owned[name])
    end)
    return true
end

local CRATE = "Summer2026Box"
local _BC = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("BoxController")

local function spawnWeaponViaBox(name)
    pcall(function()
        local payload = {{MysteryBoxId = CRATE, RewardedItemId = name}}
        _BC:Fire(payload)
    end)
    return true
end

local function spawnWeaponCombined(name, amount)
    amount = amount or 1
    spawnWeaponToInventory(name, amount)
    for i = 1, amount do
        spawnWeaponViaBox(name)
    end
    return true
end

local function getRoleColor(player)
    if playerData and playerData[player.Name] then
        local role = playerData[player.Name].Role
        if role == "Murderer" then return Color3.fromRGB(255, 50, 50) end
        if role == "Sheriff" then return Color3.fromRGB(50, 150, 255) end
    end
    if player.Backpack:FindFirstChild("Knife") or (player.Character and player.Character:FindFirstChild("Knife")) then
        return Color3.fromRGB(255, 50, 50)
    elseif player.Backpack:FindFirstChild("Gun") or (player.Character and player.Character:FindFirstChild("Gun")) then
        return Color3.fromRGB(50, 150, 255)
    end
    return Color3.fromRGB(50, 255, 100)
end

local function removeESP(character)
    if not character then return end
    local head = character:FindFirstChild("Head")
    if head then
        local lbl = head:FindFirstChild("MM2_ESP")
        if lbl then lbl:Destroy() end
    end
end

local function applyOutline(character, color)
    if not character then return end
    color = color or Color3.fromRGB(255, 255, 255)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and not part:FindFirstChild("MM2_Outline") then
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "MM2_Outline"
            box.Adornee = part
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Size = part.Size + Vector3.new(0.06, 0.06, 0.06)
            box.Color3 = color
            box.Transparency = 0.35
            box.Parent = part
        end
    end
end

local function removeOutline(character)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local o = part:FindFirstChild("MM2_Outline")
            if o then o:Destroy() end
        end
    end
end

local function refreshOutlineColor(player)
    if not player.Character then return end
    local color = getRoleColor(player)
    for _, part in ipairs(player.Character:GetDescendants()) do
        if part:IsA("BasePart") then
            local o = part:FindFirstChild("MM2_Outline")
            if o then o.Color3 = color end
        end
    end
end

local function applyHighlight(character, color)
    if not character then return end
    color = color or Color3.fromRGB(255, 255, 255)
    local existing = character:FindFirstChild("MM2_Highlight")
    if existing then
        existing.FillColor = color
        existing.OutlineColor = color
        return
    end
    local hl = Instance.new("Highlight")
    hl.Name = "MM2_Highlight"
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = character
end

local function removeHighlight(character)
    if not character then return end
    local hl = character:FindFirstChild("MM2_Highlight")
    if hl then hl:Destroy() end
end

local function applyESPToCharacter(player, character)
    if not espEnabled and not outlineEnabled and not highlightEnabled then return end
    local head = character:WaitForChild("Head", 5)
    if not head then return end

    if espEnabled then
        local old = head:FindFirstChild("MM2_ESP")
        if old then old:Destroy() end

        local bb = Instance.new("BillboardGui")
        bb.Name = "MM2_ESP"
        bb.Size = UDim2.new(0, 120, 0, 40)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.Parent = head

        local nl = Instance.new("TextLabel")
        nl.Name = "NameLabel"
        nl.Size = UDim2.new(1, 0, 0.6, 0)
        nl.BackgroundTransparency = 1
        nl.TextColor3 = getRoleColor(player)
        nl.TextStrokeTransparency = 0
        nl.TextStrokeColor3 = Color3.new(0, 0, 0)
        nl.Font = Enum.Font.GothamBold
        nl.TextScaled = true
        nl.Text = player.Name
        nl.Parent = bb

        local dl = Instance.new("TextLabel")
        dl.Name = "DistLabel"
        dl.Size = UDim2.new(1, 0, 0.4, 0)
        dl.Position = UDim2.new(0, 0, 0.6, 0)
        dl.BackgroundTransparency = 1
        dl.TextColor3 = Color3.fromRGB(220, 220, 220)
        dl.TextStrokeTransparency = 0
        dl.TextStrokeColor3 = Color3.new(0, 0, 0)
        dl.Font = Enum.Font.Gotham
        dl.TextScaled = true
        dl.Text = "0 studs"
        dl.Parent = bb
    end

    if outlineEnabled then applyOutline(character, getRoleColor(player)) end
    if highlightEnabled then applyHighlight(character, getRoleColor(player)) end
end

local function hookPlayerESP(player)
    if player == localplayer then return end
    if espHookedPlayers[player] then return end
    espHookedPlayers[player] = true

    if player.Character then
        task.spawn(applyESPToCharacter, player, player.Character)
    end

    player.CharacterAdded:Connect(function(character)
        task.spawn(applyESPToCharacter, player, character)
    end)

    player.AncestryChanged:Connect(function()
        if not player.Parent then
            espHookedPlayers[player] = nil
        end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayerESP(p) end
Players.PlayerAdded:Connect(hookPlayerESP)

local espUpdateCounter = 0
RunService.Heartbeat:Connect(function()
    if not espEnabled and not highlightEnabled then return end
    espUpdateCounter = espUpdateCounter + 1
    if espUpdateCounter < 6 then return end
    espUpdateCounter = 0
    local myHRP = localplayer.Character and localplayer.Character:FindFirstChild("HumanoidRootPart")
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localplayer and p.Character then
            local head = p.Character:FindFirstChild("Head")
            if head then
                if espEnabled and not head:FindFirstChild("MM2_ESP") then
                    task.spawn(applyESPToCharacter, p, p.Character)
                end
                local bb = head:FindFirstChild("MM2_ESP")
                if bb and espEnabled then
                    local nl = bb:FindFirstChild("NameLabel")
                    local dl = bb:FindFirstChild("DistLabel")
                    if nl then nl.TextColor3 = getRoleColor(p) end
                    if dl and myHRP then
                        local thHRP = p.Character:FindFirstChild("HumanoidRootPart")
                        if thHRP then
                            dl.Text = math.floor((myHRP.Position - thHRP.Position).Magnitude) .. " studs"
                        end
                    end
                end
            end
            if highlightEnabled and p.Character then
                local hl = p.Character:FindFirstChild("MM2_Highlight")
                if not hl then
                    task.spawn(applyHighlight, p.Character, getRoleColor(p))
                else
                    local c = getRoleColor(p)
                    hl.FillColor = c
                    hl.OutlineColor = c
                end
            end
        end
    end
end)

local function isMurderer()
    local char = localplayer.Character
    return char and (char:FindFirstChild("Knife") or (localplayer.Backpack and localplayer.Backpack:FindFirstChild("Knife")))
end

local function isLocalSheriff()
    local char = localplayer.Character
    if not char then return false end
    return char:FindFirstChild("Gun") or (localplayer.Backpack and localplayer.Backpack:FindFirstChild("Gun"))
end

local function findMurderer()
    if playerData then
        for playerName, data in pairs(playerData) do
            if data.Role == "Murderer" then
                local p = Players:FindFirstChild(playerName)
                if p and p.Character and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                    return p
                end
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localplayer then
            local char = p.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    if p.Backpack:FindFirstChild("Knife") or char:FindFirstChild("Knife") then
                        return p
                    end
                end
            end
        end
    end
    return nil
end

local function findSheriff()
    if playerData then
        for playerName, data in pairs(playerData) do
            if data.Role == "Sheriff" then
                local p = Players:FindFirstChild(playerName)
                if p and p.Character and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                    return p
                end
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localplayer then
            local char = p.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    if p.Backpack:FindFirstChild("Gun") or char:FindFirstChild("Gun") then
                        return p
                    end
                end
            end
        end
    end
    return nil
end

local function getClosestPlayer()
    local closest = nil
    local shortestDistance = math.huge
    local char = localplayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localplayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local distance = (hrp.Position - player.Character.HumanoidRootPart.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closest = player
                end
            end
        end
    end
    return closest
end

local function throwKnife()
    local character = localplayer.Character
    if not character then return false end
    if not isMurderer() then return false end
    local knife = character:FindFirstChild("Knife") or localplayer.Backpack:FindFirstChild("Knife")
    if not knife then return false end
    if knife.Parent ~= character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:EquipTool(knife)
            task.wait(0.2)
        end
    end
    knife = character:FindFirstChild("Knife")
    if not knife then return false end
    local target = getClosestPlayer()
    if not target or not target.Character then return false end
    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return false end
    local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if not rightHand then return false end
    local knifeEvents = knife:FindFirstChild("Events")
    if knifeEvents and knifeEvents:FindFirstChild("KnifeThrown") then
        local originCF = CFrame.new(rightHand.Position)
        local targetCF = CFrame.new(targetHRP.Position)
        pcall(function() knifeEvents.KnifeThrown:FireServer(originCF, targetCF) end)
        return true
    end
    return false
end

local function startLoopThrow()
    if loopThrowRunning then return end
    if not loopThrowEnabled then return end
    loopThrowRunning = true
    loopThrowConnection = task.spawn(function()
        while loopThrowEnabled and loopThrowRunning do
            task.wait(loopThrowInterval)
            if isMurderer() then pcall(throwKnife) end
        end
        loopThrowRunning = false
    end)
end

local function stopLoopThrow()
    loopThrowEnabled = false
    loopThrowRunning = false
    if loopThrowConnection then task.cancel(loopThrowConnection) end
    loopThrowConnection = nil
end

local function killSheriffOnce()
    if not isMurderer() then return end
    
    local char = localplayer.Character
    if not char then return end
    
    local knife = char:FindFirstChild("Knife")
    if not knife then
        knife = localplayer.Backpack:FindFirstChild("Knife")
        if knife then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(knife)
                task.wait(0.1)
            end
            knife = char:FindFirstChild("Knife")
        end
    end
    
    if not knife then return end
    
    local sheriff = findSheriff()
    if not sheriff or not sheriff.Character then return end
    
    local sheriffHRP = sheriff.Character:FindFirstChild("HumanoidRootPart")
    if not sheriffHRP then return end
    
    pcall(function()
        knife:Activate()
        firetouchinterest(sheriffHRP, knife.Handle, 0)
        firetouchinterest(sheriffHRP, knife.Handle, 1)
    end)
end

local function killSheriff()
    if not isMurderer() then return end
    
    local char = localplayer.Character
    if not char then return end
    
    local knife = char:FindFirstChild("Knife")
    if not knife then
        knife = localplayer.Backpack:FindFirstChild("Knife")
        if knife then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(knife)
                task.wait(0.1)
            end
            knife = char:FindFirstChild("Knife")
        end
    end
    
    if not knife then return end
    
    local sheriff = findSheriff()
    if not sheriff or not sheriff.Character then return end
    
    local sheriffHRP = sheriff.Character:FindFirstChild("HumanoidRootPart")
    if not sheriffHRP then return end
    
    pcall(function()
        knife:Activate()
        firetouchinterest(sheriffHRP, knife.Handle, 0)
        firetouchinterest(sheriffHRP, knife.Handle, 1)
    end)
end

local function killEveryone()
    if not isMurderer() then return end
    
    local char = localplayer.Character
    if not char then return end
    
    local knife = char:FindFirstChild("Knife")
    if not knife then
        knife = localplayer.Backpack:FindFirstChild("Knife")
        if knife then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(knife)
                task.wait(0.1)
            end
            knife = char:FindFirstChild("Knife")
        end
    end
    
    if not knife then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localplayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local hrp = player.Character.HumanoidRootPart
                pcall(function()
                    knife:Activate()
                    firetouchinterest(hrp, knife.Handle, 0)
                    firetouchinterest(hrp, knife.Handle, 1)
                end)
                task.wait(0.05)
            end
        end
    end
end

local autoKillSheriffEnabled = false
local autoKillSheriffConnection = nil

local function startAutoKillSheriff()
    if autoKillSheriffConnection then return end
    autoKillSheriffConnection = task.spawn(function()
        while autoKillSheriffEnabled do
            task.wait(0.5)
            if isMurderer() then
                pcall(killSheriff)
            end
        end
        autoKillSheriffConnection = nil
    end)
end

local function stopAutoKillSheriff()
    autoKillSheriffEnabled = false
    if autoKillSheriffConnection then
        task.cancel(autoKillSheriffConnection)
        autoKillSheriffConnection = nil
    end
end

local function SkidFling(TargetPlayer)
    if not TargetPlayer or not TargetPlayer.Character then return end
    
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
    if RootPart.Velocity.Magnitude < 50 then getgenv().OldPos = RootPart.CFrame end
    if THumanoid and THumanoid.Sit then return end
    if THead then workspace.CurrentCamera.CameraSubject = THead
    elseif Handle then workspace.CurrentCamera.CameraSubject = Handle
    elseif THumanoid and TRootPart then workspace.CurrentCamera.CameraSubject = THumanoid end
    if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end
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
    if TRootPart then SFBasePart(TRootPart)
    elseif THead then SFBasePart(THead)
    elseif Handle then SFBasePart(Handle)
    else BV:Destroy(); Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true); return end
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

local function stealGun()
    local sheriff = findSheriff()
    if not sheriff then 
        sendNotification("Error", "No sheriff found!")
        return 
    end
    task.spawn(function() SkidFling(sheriff) end)
end

local function loadPlayerData()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if remotes then
        local gameplay = remotes:WaitForChild("Gameplay", 10)
        if gameplay then
            local pdcEvent = gameplay:WaitForChild("PlayerDataChanged", 10)
            if pdcEvent then
                pdcEvent.OnClientEvent:Connect(function(data)
                    playerData = data or {}
                    if espEnabled then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= localplayer and p.Character then
                                local head = p.Character:FindFirstChild("Head")
                                if head then
                                    local bb = head:FindFirstChild("MM2_ESP")
                                    if bb then
                                        local nl = bb:FindFirstChild("NameLabel")
                                        if nl then nl.TextColor3 = getRoleColor(p) end
                                    end
                                end
                            end
                        end
                    end
                    if outlineEnabled then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= localplayer then refreshOutlineColor(p) end
                        end
                    end
                end)
            end
        end
    end
end

task.spawn(loadPlayerData)

local sg = Instance.new("ScreenGui")
sg.Name = "MM2SummerHub"; sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent = game.CoreGui

local reopenBar = Instance.new("Frame")
reopenBar.Size = UDim2.new(0, 130, 0, 26)
reopenBar.Position = UDim2.new(0.5, -65, 0, 6)
reopenBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
reopenBar.BorderSizePixel = 0
reopenBar.Visible = false
reopenBar.ZIndex = 50
reopenBar.Active = true
reopenBar.Parent = sg
Instance.new("UICorner", reopenBar).CornerRadius = UDim.new(0, 6)
local rbStroke = Instance.new("UIStroke", reopenBar)
rbStroke.Color = Color3.fromRGB(55, 55, 55); rbStroke.Thickness = 1

local reopenBtn = Instance.new("TextButton")
reopenBtn.Size = UDim2.new(1,0,1,0); reopenBtn.BackgroundTransparency = 1
reopenBtn.Text = "▼  MM2 Summer Hub"; reopenBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
reopenBtn.TextSize = 11; reopenBtn.Font = Enum.Font.GothamMedium
reopenBtn.ZIndex = 51; reopenBtn.Parent = reopenBar

local W, H = 280, 520

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

local titleH = 28
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
titleLbl.Size = UDim2.new(1, -70, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "MM2 Summer Hub"
titleLbl.TextColor3 = Color3.fromRGB(200, 200, 205)
titleLbl.TextSize = 11; titleLbl.Font = Enum.Font.GothamMedium
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 4; titleLbl.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 20, 0, 20)
closeBtn.Position = UDim2.new(1, -25, 0.5, -10)
closeBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(200, 200, 205)
closeBtn.TextSize = 11
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 5
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

local SIDEBAR_W = 55
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -titleH)
body.Position = UDim2.new(0, 0, 0, titleH)
body.BackgroundTransparency = 1
body.ClipsDescendants = true
body.Parent = main

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
sidebar.Position = UDim2.new(0, 0, 0, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
sidebar.BorderSizePixel = 0
sidebar.ClipsDescendants = true
sidebar.Parent = body

local sideCorner = Instance.new("UICorner", sidebar)
sideCorner.CornerRadius = UDim.new(0, 10)
local sideFix = Instance.new("Frame", sidebar)
sideFix.Size = UDim2.new(0.5, 0, 1, 0)
sideFix.Position = UDim2.new(0.5, 0, 0, 0)
sideFix.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
sideFix.BorderSizePixel = 0

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -SIDEBAR_W - 1, 1, -6)
content.Position = UDim2.new(0, SIDEBAR_W + 1, 0, 3)
content.BackgroundTransparency = 1
content.ClipsDescendants = true; content.Parent = body

local tabBtns = {}
local tabPages = {}
local tabAccents = {}

local TAB_H = 26
local TAB_PAD = 4
local TAB_GAP = 2

local function makeTabBtn(label, idx)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, TAB_H)
    btn.Position = UDim2.new(0, 4, 0, TAB_PAD + (idx - 1) * (TAB_H + TAB_GAP))
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(90, 90, 100)
    btn.TextSize = 7; btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.TextWrapped = true
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(42, 42, 48); stroke.Thickness = 1
    local accent = Instance.new("Frame", btn)
    accent.Size = UDim2.new(0, 2, 0.5, 0)
    accent.AnchorPoint = Vector2.new(1, 0.5)
    accent.Position = UDim2.new(1, 0, 0.5, 0)
    accent.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
    accent.BorderSizePixel = 0
    accent.Visible = false
    Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)
    return btn, accent
end

local function switchTab(name)
    for n, page in pairs(tabPages) do page.Visible = (n == name) end
    for n, btn in pairs(tabBtns) do
        local active = (n == name)
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = active and Color3.fromRGB(42, 42, 48) or Color3.fromRGB(32, 32, 36),
            TextColor3 = active and Color3.fromRGB(220, 220, 230) or Color3.fromRGB(90, 90, 100),
        }):Play()
        if tabAccents[n] then tabAccents[n].Visible = active end
    end
end

local function makePage()
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
    scroll.ScrollBarImageTransparency = 0.3
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Visible = false
    scroll.Parent = content
    scroll.ScrollingEnabled = true
    scroll.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
    scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    
    local list = Instance.new("UIListLayout", scroll)
    list.FillDirection = Enum.FillDirection.Vertical
    list.Padding = UDim.new(0, 0)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    
    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.PaddingTop = UDim.new(0, 3)
    pad.PaddingBottom = UDim.new(0, 3)
    
    return scroll
end

local farmTab, farmAccent = makeTabBtn("AUTO", 1)
local combatTab, combatAccent = makeTabBtn("COMBAT", 2)
local espTab, espAccent = makeTabBtn("ESP", 3)
local miscTab, miscAccent = makeTabBtn("MISC", 4)
local spawnerTab, spawnerAccent = makeTabBtn("SPAWN", 5)
tabBtns["farm"] = farmTab; tabBtns["combat"] = combatTab; tabBtns["esp"] = espTab; tabBtns["misc"] = miscTab; tabBtns["spawner"] = spawnerTab
tabAccents["farm"] = farmAccent; tabAccents["combat"] = combatAccent; tabAccents["esp"] = espAccent; tabAccents["misc"] = miscAccent; tabAccents["spawner"] = spawnerAccent

local farmPage = makePage(); tabPages["farm"] = farmPage
local combatPage = makePage(); tabPages["combat"] = combatPage
local espPage = makePage(); tabPages["esp"] = espPage
local miscPage = makePage(); tabPages["misc"] = miscPage
local spawnerPage = makePage(); tabPages["spawner"] = spawnerPage

farmTab.MouseButton1Click:Connect(function() switchTab("farm") end)
combatTab.MouseButton1Click:Connect(function() switchTab("combat") end)
espTab.MouseButton1Click:Connect(function() switchTab("esp") end)
miscTab.MouseButton1Click:Connect(function() switchTab("misc") end)
spawnerTab.MouseButton1Click:Connect(function() switchTab("spawner") end)

local function makeSection(parent, text, order)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 16)
    wrap.BackgroundTransparency = 1; wrap.LayoutOrder = order; wrap.Parent = parent
    local lbl = Instance.new("TextLabel", wrap)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(85, 85, 95)
    lbl.TextSize = 7; lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

local function makeDivider(parent, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 1)
    f.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    f.BorderSizePixel = 0; f.LayoutOrder = order; f.Parent = parent
end

local function makeToggle(parent, label, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order; row.Parent = parent

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -42, 1, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(185, 185, 195)
    lbl.TextSize = 9; lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("TextButton", row)
    track.Size = UDim2.new(0, 34, 0, 18)
    track.Position = UDim2.new(1, -34, 0.5, -9)
    track.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    track.BorderSizePixel = 0; track.Text = ""; track.AutoButtonColor = false
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local ts = Instance.new("UIStroke", track); ts.Color = Color3.fromRGB(58, 58, 63); ts.Thickness = 1

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(100, 100, 110); knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    return track, knob
end

local function makeButton(parent, label, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order; row.Parent = parent

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(36, 36, 40)
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(185, 185, 195)
    btn.TextSize = 9; btn.Font = Enum.Font.GothamMedium
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    local bs = Instance.new("UIStroke", btn); bs.Color = Color3.fromRGB(55, 55, 60); bs.Thickness = 1
    
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(42, 42, 46) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(36, 36, 40) end)
    
    return btn
end

local function setToggle(track, knob, state)
    TweenService:Create(track, TweenInfo.new(0.14), {
        BackgroundColor3 = state and Color3.fromRGB(65, 65, 72) or Color3.fromRGB(45, 45, 50)
    }):Play()
    TweenService:Create(knob, TweenInfo.new(0.14), {
        Position = state and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7),
        BackgroundColor3 = state and Color3.fromRGB(220, 220, 230) or Color3.fromRGB(100, 100, 110)
    }):Play()
end

-- AUTO FARM TAB
makeSection(farmPage, "AUTO FARM", 1)

local runPRBtn = makeButton(farmPage, "Execute Auto Farm", 2)
runPRBtn.MouseButton1Click:Connect(function()
    pcall(function()
        loadstring(game:HttpGet("https://cdn.project-reverse.org/visual.luau"))()
    end)
end)

makeDivider(farmPage, 3)
makeSection(farmPage, "SETTINGS", 4)

local afkTrack, afkKnob = makeToggle(farmPage, "Anti AFK", 5)
local antiAfkEnabled = false
local antiAfkConnection = nil
afkTrack.MouseButton1Click:Connect(function()
    antiAfkEnabled = not antiAfkEnabled
    setToggle(afkTrack, afkKnob, antiAfkEnabled)
    if antiAfkEnabled then
        if antiAfkConnection then return end
        antiAfkConnection = localplayer.Idled:Connect(function()
            pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
        end)
        task.spawn(function()
            while antiAfkConnection do
                task.wait(60)
                if antiAfkEnabled then
                    pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
                end
            end
        end)
    else
        if antiAfkConnection then antiAfkConnection:Disconnect(); antiAfkConnection = nil end
    end
end)

-- COMBAT TAB
makeSection(combatPage, "SHERIFF", 1)

local aimlockTrack, aimlockKnob = makeToggle(combatPage, "Aimlock", 2)
local aimlockEnabled = false
local aimlockConnection = nil

local function findMurdererAimbot()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localplayer then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                if p.Backpack:FindFirstChild("Knife") or (char and char:FindFirstChild("Knife")) then
                    return p
                end
            end
        end
    end
    return nil
end

local function runAimbot()
    if not aimlockEnabled then return end
    if not isLocalSheriff() then return end
    local murderer = findMurdererAimbot()
    if not murderer or not murderer.Character then return end
    local head = murderer.Character:FindFirstChild("Head")
    if not head then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, head.Position)
end

local function startAimbot()
    if aimlockConnection then return end
    aimlockConnection = RunService.RenderStepped:Connect(runAimbot)
end

local function stopAimbot()
    if aimlockConnection then
        aimlockConnection:Disconnect()
        aimlockConnection = nil
    end
end

aimlockTrack.MouseButton1Click:Connect(function()
    aimlockEnabled = not aimlockEnabled
    setToggle(aimlockTrack, aimlockKnob, aimlockEnabled)
    if aimlockEnabled then
        startAimbot()
    else
        stopAimbot()
    end
end)

makeButton(combatPage, "TP Shoot Murderer", 3).MouseButton1Click:Connect(function()
    local function tpShootMurderer()
        if not isLocalSheriff() then return end
        local char = localplayer.Character if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart") if not hrp then return end
        local savedPos = hrp.CFrame
        local murderer = findMurderer() if not murderer then return end
        local murderHRP = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") if not murderHRP then return end
        local teleportPos = murderHRP.CFrame * CFrame.new(0, 0, 3)
        hrp.CFrame = teleportPos
        task.wait(0.1)
        local humanoid = char:FindFirstChildOfClass("Humanoid") if not humanoid then return end
        local gun = char:FindFirstChild("Gun") or localplayer.Backpack:FindFirstChild("Gun") if not gun then return end
        if gun.Parent ~= char then humanoid:EquipTool(gun); task.wait(0.1) end
        local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") if not rightHand then return end
        local args = { CFrame.new(rightHand.Position), CFrame.new(murderHRP.Position) }
        if gun:FindFirstChild("Shoot") then pcall(function() gun.Shoot:FireServer(unpack(args)) end) end
        hrp.CFrame = savedPos
        task.delay(0.4, function() pcall(function() humanoid:UnequipTools() end) end)
    end
    pcall(tpShootMurderer)
end)

makeButton(combatPage, "Shoot Murderer", 4).MouseButton1Click:Connect(function()
    local function shootMurdererSimple()
        local murderer = findMurderer() if not murderer then return end
        local char = localplayer.Character if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid") if not humanoid then return end
        local gun = char:FindFirstChild("Gun") or localplayer.Backpack:FindFirstChild("Gun") if not gun then return end
        if gun.Parent ~= char then humanoid:EquipTool(gun); task.wait(0.15) end
        local hrp = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") if not hrp then return end
        local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") if not rightHand then return end
        local args = { CFrame.new(rightHand.Position), CFrame.new(hrp.Position) }
        if gun:FindFirstChild("Shoot") then pcall(function() gun.Shoot:FireServer(unpack(args)) end) end
        task.wait(0.1); humanoid:UnequipTools()
    end
    pcall(shootMurdererSimple)
end)

makeButton(combatPage, "Teleport to Dropped Gun", 5).MouseButton1Click:Connect(function()
    local function findGunDrop()
        for _, v in pairs(Workspace:GetDescendants()) do
            if v.Name == "GunDrop" and v:IsA("BasePart") then return v end
        end
        return nil
    end
    local gunDrop = findGunDrop() if not gunDrop then return end
    local char = localplayer.Character if not char then return end
    local prev = char:GetPivot()
    char:PivotTo(gunDrop:GetPivot())
    local timeout = tick() + 3
    while not localplayer.Backpack:FindFirstChild("Gun") and tick() < timeout do task.wait(0.1) end
    char:PivotTo(prev)
end)

local shootBtnTrack, shootBtnKnob = makeToggle(combatPage, "Shoot Murder Button", 6)
local shootButtonEnabled = false
local shootButtonGui = nil
local shootButton = nil

local function createShootButton()
    if shootButtonGui then return end
    shootButtonGui = Instance.new("ScreenGui")
    shootButtonGui.Name = "ShootMurdererCircle"
    shootButtonGui.ResetOnSpawn = false
    shootButtonGui.Parent = game.CoreGui
    shootButton = Instance.new("TextButton")
    shootButton.Size = UDim2.new(0, 70, 0, 70)
    shootButton.Position = UDim2.new(0.85, 0, 0.65, 0)
    shootButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shootButton.BackgroundTransparency = 0.5
    shootButton.Text = "SHOOT"
    shootButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    shootButton.TextScaled = true
    shootButton.Font = Enum.Font.GothamBold
    shootButton.BorderSizePixel = 0
    shootButton.AutoButtonColor = true
    shootButton.Parent = shootButtonGui
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent = shootButton
    
    local dragData = {active = false, startPos = nil, startMouse = nil, startOffset = nil}
    local function startDrag(input)
        dragData.active = true
        dragData.startPos = shootButton.Position
        dragData.startMouse = input.Position
        local absPos = shootButton.AbsolutePosition
        dragData.startOffset = Vector2.new(input.Position.X - absPos.X, input.Position.Y - absPos.Y)
    end
    local function updateDrag(input)
        if not dragData.active then return end
        local delta = input.Position - dragData.startMouse
        local newX = dragData.startPos.X.Scale + (dragData.startPos.X.Offset + delta.X) / workspace.CurrentCamera.ViewportSize.X
        local newY = dragData.startPos.Y.Scale + (dragData.startPos.Y.Offset + delta.Y) / workspace.CurrentCamera.ViewportSize.Y
        shootButton.Position = UDim2.new(newX, 0, newY, 0)
    end
    local function endDrag()
        dragData.active = false
    end
    
    shootButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
    shootButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end)
    shootButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
    
    shootButton.MouseButton1Click:Connect(function()
        if isLocalSheriff() then
            local function shootMurdererSimple()
                local murderer = findMurderer() if not murderer then return end
                local char = localplayer.Character if not char then return end
                local humanoid = char:FindFirstChildOfClass("Humanoid") if not humanoid then return end
                local gun = char:FindFirstChild("Gun") or localplayer.Backpack:FindFirstChild("Gun") if not gun then return end
                if gun.Parent ~= char then humanoid:EquipTool(gun); task.wait(0.15) end
                local hrp = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") if not hrp then return end
                local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") if not rightHand then return end
                local args = { CFrame.new(rightHand.Position), CFrame.new(hrp.Position) }
                if gun:FindFirstChild("Shoot") then pcall(function() gun.Shoot:FireServer(unpack(args)) end) end
                task.wait(0.1); humanoid:UnequipTools()
            end
            pcall(shootMurdererSimple)
        else
            shootButton.TextColor3 = Color3.fromRGB(255, 50, 50)
            task.delay(0.3, function() if shootButton then shootButton.TextColor3 = Color3.fromRGB(255, 255, 255) end end)
        end
    end)
end

local function removeShootButton()
    if shootButtonGui then shootButtonGui:Destroy(); shootButtonGui = nil; shootButton = nil end
    shootButtonEnabled = false
end

shootBtnTrack.MouseButton1Click:Connect(function()
    shootButtonEnabled = not shootButtonEnabled
    setToggle(shootBtnTrack, shootBtnKnob, shootButtonEnabled)
    if shootButtonEnabled then createShootButton() else removeShootButton() end
end)

local tpShootBtnTrack, tpShootBtnKnob = makeToggle(combatPage, "TP Shoot Button", 7)
local tpShootButtonEnabled = false
local tpShootButtonGui = nil
local tpShootButton = nil

local function createTpShootButton()
    if tpShootButtonGui then return end
    tpShootButtonGui = Instance.new("ScreenGui")
    tpShootButtonGui.Name = "TpShootMurdererCircle"
    tpShootButtonGui.ResetOnSpawn = false
    tpShootButtonGui.Parent = game.CoreGui
    tpShootButton = Instance.new("TextButton")
    tpShootButton.Size = UDim2.new(0, 70, 0, 70)
    tpShootButton.Position = UDim2.new(0.85, 0, 0.80, 0)
    tpShootButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    tpShootButton.BackgroundTransparency = 0.5
    tpShootButton.Text = "TP\nSHOOT"
    tpShootButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    tpShootButton.TextScaled = true
    tpShootButton.Font = Enum.Font.GothamBold
    tpShootButton.BorderSizePixel = 0
    tpShootButton.AutoButtonColor = true
    tpShootButton.Parent = tpShootButtonGui
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent = tpShootButton
    
    local dragData = {active = false, startPos = nil, startMouse = nil, startOffset = nil}
    local function startDrag(input)
        dragData.active = true
        dragData.startPos = tpShootButton.Position
        dragData.startMouse = input.Position
        local absPos = tpShootButton.AbsolutePosition
        dragData.startOffset = Vector2.new(input.Position.X - absPos.X, input.Position.Y - absPos.Y)
    end
    local function updateDrag(input)
        if not dragData.active then return end
        local delta = input.Position - dragData.startMouse
        local newX = dragData.startPos.X.Scale + (dragData.startPos.X.Offset + delta.X) / workspace.CurrentCamera.ViewportSize.X
        local newY = dragData.startPos.Y.Scale + (dragData.startPos.Y.Offset + delta.Y) / workspace.CurrentCamera.ViewportSize.Y
        tpShootButton.Position = UDim2.new(newX, 0, newY, 0)
    end
    local function endDrag()
        dragData.active = false
    end
    
    tpShootButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
    tpShootButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end)
    tpShootButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
    
    tpShootButton.MouseButton1Click:Connect(function()
        if isLocalSheriff() then
            local function tpShootMurderer()
                if not isLocalSheriff() then return end
                local char = localplayer.Character if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart") if not hrp then return end
                local savedPos = hrp.CFrame
                local murderer = findMurderer() if not murderer then return end
                local murderHRP = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") if not murderHRP then return end
                local teleportPos = murderHRP.CFrame * CFrame.new(0, 0, 3)
                hrp.CFrame = teleportPos
                task.wait(0.1)
                local humanoid = char:FindFirstChildOfClass("Humanoid") if not humanoid then return end
                local gun = char:FindFirstChild("Gun") or localplayer.Backpack:FindFirstChild("Gun") if not gun then return end
                if gun.Parent ~= char then humanoid:EquipTool(gun); task.wait(0.1) end
                local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") if not rightHand then return end
                local args = { CFrame.new(rightHand.Position), CFrame.new(murderHRP.Position) }
                if gun:FindFirstChild("Shoot") then pcall(function() gun.Shoot:FireServer(unpack(args)) end) end
                hrp.CFrame = savedPos
                task.delay(0.4, function() pcall(function() humanoid:UnequipTools() end) end)
            end
            pcall(tpShootMurderer)
        else
            tpShootButton.TextColor3 = Color3.fromRGB(255, 50, 50)
            task.delay(0.3, function() if tpShootButton then tpShootButton.TextColor3 = Color3.fromRGB(255, 255, 255) end end)
        end
    end)
end

local function removeTpShootButton()
    if tpShootButtonGui then tpShootButtonGui:Destroy(); tpShootButtonGui = nil; tpShootButton = nil end
    tpShootButtonEnabled = false
end

tpShootBtnTrack.MouseButton1Click:Connect(function()
    tpShootButtonEnabled = not tpShootButtonEnabled
    setToggle(tpShootBtnTrack, tpShootBtnKnob, tpShootButtonEnabled)
    if tpShootButtonEnabled then createTpShootButton() else removeTpShootButton() end
end)

local teleportGunTrack, teleportGunKnob = makeToggle(combatPage, "Teleport to Gun Button", 8)
local teleportGunButtonEnabled = false
local teleportGunButtonGui = nil
local teleportGunButton = nil

local function createTeleportGunButton()
    if teleportGunButtonGui then return end
    teleportGunButtonGui = Instance.new("ScreenGui")
    teleportGunButtonGui.Name = "TeleportGunCircle"
    teleportGunButtonGui.ResetOnSpawn = false
    teleportGunButtonGui.Parent = game.CoreGui
    teleportGunButton = Instance.new("TextButton")
    teleportGunButton.Size = UDim2.new(0, 70, 0, 70)
    teleportGunButton.Position = UDim2.new(0.85, 0, 0.90, 0)
    teleportGunButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    teleportGunButton.BackgroundTransparency = 0.5
    teleportGunButton.Text = "TP\nGUN"
    teleportGunButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    teleportGunButton.TextScaled = true
    teleportGunButton.Font = Enum.Font.GothamBold
    teleportGunButton.BorderSizePixel = 0
    teleportGunButton.AutoButtonColor = true
    teleportGunButton.Parent = teleportGunButtonGui
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent = teleportGunButton
    
    local dragData = {active = false, startPos = nil, startMouse = nil, startOffset = nil}
    local function startDrag(input)
        dragData.active = true
        dragData.startPos = teleportGunButton.Position
        dragData.startMouse = input.Position
        local absPos = teleportGunButton.AbsolutePosition
        dragData.startOffset = Vector2.new(input.Position.X - absPos.X, input.Position.Y - absPos.Y)
    end
    local function updateDrag(input)
        if not dragData.active then return end
        local delta = input.Position - dragData.startMouse
        local newX = dragData.startPos.X.Scale + (dragData.startPos.X.Offset + delta.X) / workspace.CurrentCamera.ViewportSize.X
        local newY = dragData.startPos.Y.Scale + (dragData.startPos.Y.Offset + delta.Y) / workspace.CurrentCamera.ViewportSize.Y
        teleportGunButton.Position = UDim2.new(newX, 0, newY, 0)
    end
    local function endDrag()
        dragData.active = false
    end
    
    teleportGunButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
    teleportGunButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end)
    teleportGunButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)

teleportGunButton.MouseButton1Click:Connect(function()
        local function findGunDrop()
            for _, v in pairs(Workspace:GetDescendants()) do
                if v.Name == "GunDrop" and v:IsA("BasePart") then return v end
            end
            return nil
        end
        local gunDrop = findGunDrop()
        if not gunDrop then
            sendNotification("Error", "No dropped gun found!")
            return
        end
        local char = localplayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        hrp.CFrame = gunDrop.CFrame + Vector3.new(0, 3, 0)
    end)
end

local function removeTeleportGunButton()
    if teleportGunButtonGui then teleportGunButtonGui:Destroy(); teleportGunButtonGui = nil; teleportGunButton = nil end
    teleportGunButtonEnabled = false
end

teleportGunTrack.MouseButton1Click:Connect(function()
    teleportGunButtonEnabled = not teleportGunButtonEnabled
    setToggle(teleportGunTrack, teleportGunKnob, teleportGunButtonEnabled)
    if teleportGunButtonEnabled then createTeleportGunButton() else removeTeleportGunButton() end
end)

makeDivider(combatPage, 9)
makeSection(combatPage, "MURDERER", 10)

makeButton(combatPage, "Kill Sheriff", 11).MouseButton1Click:Connect(function()
    if isMurderer() then
        pcall(killSheriffOnce)
    end
end)

local autoKillTrack, autoKillKnob = makeToggle(combatPage, "Auto Kill Sheriff", 12)
autoKillTrack.MouseButton1Click:Connect(function()
    autoKillSheriffEnabled = not autoKillSheriffEnabled
    setToggle(autoKillTrack, autoKillKnob, autoKillSheriffEnabled)
    if autoKillSheriffEnabled then
        startAutoKillSheriff()
    else
        stopAutoKillSheriff()
    end
end)

makeButton(combatPage, "Kill Everyone", 13).MouseButton1Click:Connect(function()
    if isMurderer() then
        pcall(killEveryone)
    end
end)

makeDivider(combatPage, 14)
makeSection(combatPage, "THROW KNIFE", 15)

local throwBtn = makeButton(combatPage, "Throw Knife", 16)
throwBtn.MouseButton1Click:Connect(function()
    if isMurderer() then
        pcall(throwKnife)
    end
end)

local throwTrack, throwKnob = makeToggle(combatPage, "Loop Throw", 17)
throwTrack.MouseButton1Click:Connect(function()
    loopThrowEnabled = not loopThrowEnabled
    setToggle(throwTrack, throwKnob, loopThrowEnabled)
    if loopThrowEnabled then
        startLoopThrow()
    else
        stopLoopThrow()
    end
end)

local throwIntervalRow = Instance.new("Frame")
throwIntervalRow.Size = UDim2.new(1, 0, 0, 36)
throwIntervalRow.BackgroundTransparency = 1; throwIntervalRow.LayoutOrder = 18; throwIntervalRow.Parent = combatPage

local throwIntervalLbl = Instance.new("TextLabel", throwIntervalRow)
throwIntervalLbl.Size = UDim2.new(0.6, 0, 0.5, 0)
throwIntervalLbl.BackgroundTransparency = 1; throwIntervalLbl.Text = "Interval"
throwIntervalLbl.TextColor3 = Color3.fromRGB(175, 175, 185)
throwIntervalLbl.TextSize = 9; throwIntervalLbl.Font = Enum.Font.Gotham
throwIntervalLbl.TextXAlignment = Enum.TextXAlignment.Left

local throwIntervalVal = Instance.new("TextLabel", throwIntervalRow)
throwIntervalVal.Size = UDim2.new(0.4, 0, 0.5, 0)
throwIntervalVal.Position = UDim2.new(0.6, 0, 0, 0)
throwIntervalVal.BackgroundTransparency = 1; throwIntervalVal.Text = "1.0s"
throwIntervalVal.TextColor3 = Color3.fromRGB(200, 200, 210)
throwIntervalVal.TextSize = 9; throwIntervalVal.Font = Enum.Font.GothamMedium
throwIntervalVal.TextXAlignment = Enum.TextXAlignment.Right

local sliderContainer = Instance.new("Frame", throwIntervalRow)
sliderContainer.Size = UDim2.new(1, 0, 0, 14)
sliderContainer.Position = UDim2.new(0, 0, 0.5, 2)
sliderContainer.BackgroundTransparency = 1

local tTrack = Instance.new("Frame", sliderContainer)
tTrack.Size = UDim2.new(1, 0, 0, 3)
tTrack.Position = UDim2.new(0, 0, 0.5, -1.5)
tTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 50); tTrack.BorderSizePixel = 0
Instance.new("UICorner", tTrack).CornerRadius = UDim.new(1, 0)

local tFill = Instance.new("Frame", tTrack)
tFill.Size = UDim2.new(loopThrowInterval/5, 0, 1, 0)
tFill.BackgroundColor3 = Color3.fromRGB(120, 120, 130); tFill.BorderSizePixel = 0
Instance.new("UICorner", tFill).CornerRadius = UDim.new(1, 0)

local tKnob = Instance.new("Frame", sliderContainer)
tKnob.Size = UDim2.new(0, 14, 0, 14)
tKnob.AnchorPoint = Vector2.new(0.5, 0.5)
tKnob.Position = UDim2.new(loopThrowInterval/5, 0, 0.5, 0)
tKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 210); tKnob.BorderSizePixel = 0
Instance.new("UICorner", tKnob).CornerRadius = UDim.new(1, 0)

local sliderHit = Instance.new("TextButton", sliderContainer)
sliderHit.Size = UDim2.new(1, 0, 1, 0)
sliderHit.BackgroundTransparency = 1
sliderHit.Text = ""

local tSliding = false
local sliderTouch = nil

local function updateThrowSlider(inputPos)
    local containerPos = sliderContainer.AbsolutePosition
    local containerSize = sliderContainer.AbsoluteSize
    local rel = math.clamp((inputPos.X - containerPos.X) / containerSize.X, 0, 1)
    local val = math.max(math.round(rel * 10) / 2, 0.1)
    loopThrowInterval = val
    throwIntervalVal.Text = string.format("%.1fs", val)
    tFill.Size = UDim2.new(rel, 0, 1, 0)
    tKnob.Position = UDim2.new(rel, 0, 0.5, 0)
end

sliderHit.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        tSliding = true
        sliderTouch = input
        updateThrowSlider(input.Position)
    end
end)

sliderHit.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        tSliding = false
        sliderTouch = nil
    end
end)

sliderHit.InputChanged:Connect(function(input)
    if tSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateThrowSlider(input.Position)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if tSliding and sliderTouch and input.UserInputType == sliderTouch.UserInputType then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateThrowSlider(input.Position)
        end
    end
end)

-- ESP TAB
makeSection(espPage, "VISUALS", 1)

local espTrack, espKnob = makeToggle(espPage, "Name ESP", 2)
espTrack.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    setToggle(espTrack, espKnob, espEnabled)
    if espEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localplayer and p.Character then
                task.spawn(applyESPToCharacter, p, p.Character)
            end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then removeESP(p.Character) end end
    end
end)

local outlineTrack, outlineKnob = makeToggle(espPage, "Body Outlines", 3)
outlineTrack.MouseButton1Click:Connect(function()
    outlineEnabled = not outlineEnabled
    setToggle(outlineTrack, outlineKnob, outlineEnabled)
    if outlineEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localplayer and p.Character then applyOutline(p.Character, getRoleColor(p)) end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then removeOutline(p.Character) end end
    end
end)

local highlightTrack, highlightKnob = makeToggle(espPage, "Highlight Players", 4)
highlightTrack.MouseButton1Click:Connect(function()
    highlightEnabled = not highlightEnabled
    setToggle(highlightTrack, highlightKnob, highlightEnabled)
    if highlightEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localplayer and p.Character then applyHighlight(p.Character, getRoleColor(p)) end
            p.CharacterAdded:Connect(function(char) if highlightEnabled then applyHighlight(char, getRoleColor(p)) end end)
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then removeHighlight(p.Character) end end
    end
end)

local colorInfo = Instance.new("TextLabel")
colorInfo.Size = UDim2.new(1, 0, 0, 20)
colorInfo.BackgroundTransparency = 1
colorInfo.Text = "Red=Murd Blue=Sheriff Green=Innocent"
colorInfo.TextColor3 = Color3.fromRGB(150, 150, 160)
colorInfo.TextSize = 7
colorInfo.Font = Enum.Font.Gotham
colorInfo.TextWrapped = true
colorInfo.LayoutOrder = 5
colorInfo.Parent = espPage

-- MISC TAB
makeSection(miscPage, "AUTO GRAB GUN", 1)
local autoGrabGunEnabled = false
local autoGrabConnection = nil

local function findMurdererForGrab()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localplayer then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                if p.Backpack:FindFirstChild("Knife") or (char and char:FindFirstChild("Knife")) then
                    return p
                end
            end
        end
    end
    return nil
end

local function isMurdererNearGun(gunDrop)
    local murderer = findMurdererForGrab()
    if not murderer or not murderer.Character then return false end
    local murderHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
    if not murderHRP then return false end
    return (murderHRP.Position - gunDrop.Position).Magnitude < 20
end

local function grabDroppedGun(gunDrop)
    if not autoGrabGunEnabled then return end
    local character = localplayer.Character
    if not character then return end
    while isMurdererNearGun(gunDrop) and autoGrabGunEnabled do task.wait(0.5) end
    if not autoGrabGunEnabled then return end
    character = localplayer.Character
    if not character then return end
    if not gunDrop or not gunDrop.Parent then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local previousPosition = hrp.CFrame
    hrp.CFrame = gunDrop.CFrame + Vector3.new(0, 3, 0)
    task.wait(0.3)
    hrp.CFrame = previousPosition
end

local function enableAutoGunGrab()
    if autoGrabConnection then return end
    autoGrabConnection = Workspace.DescendantAdded:Connect(function(child)
        if child.Name == "GunDrop" and autoGrabGunEnabled then
            task.wait(0.5)
            task.spawn(grabDroppedGun, child)
        end
    end)
end

local function disableAutoGunGrab()
    if autoGrabConnection then autoGrabConnection:Disconnect(); autoGrabConnection = nil end
    autoGrabGunEnabled = false
end

local autoGrabTrack, autoGrabKnob = makeToggle(miscPage, "Auto Grab Gun", 2)
autoGrabTrack.MouseButton1Click:Connect(function()
    autoGrabGunEnabled = not autoGrabGunEnabled
    setToggle(autoGrabTrack, autoGrabKnob, autoGrabGunEnabled)
    if autoGrabGunEnabled then enableAutoGunGrab() else disableAutoGunGrab() end
end)

makeDivider(miscPage, 3)
makeSection(miscPage, "FLING", 4)

makeButton(miscPage, "Fling Murderer", 5).MouseButton1Click:Connect(function()
    local murderer = findMurderer()
    if murderer then
        task.spawn(function() SkidFling(murderer) end)
    else
        sendNotification("Error", "No murderer found!")
    end
end)

makeButton(miscPage, "Fling Sheriff", 6).MouseButton1Click:Connect(function()
    local sheriff = findSheriff()
    if sheriff then
        task.spawn(function() SkidFling(sheriff) end)
    else
        sendNotification("Error", "No sheriff found!")
    end
end)

makeButton(miscPage, "Steal Gun", 7).MouseButton1Click:Connect(function()
    stealGun()
end)

makeDivider(miscPage, 8)

local stealBtnTrack, stealBtnKnob = makeToggle(miscPage, "Steal Gun Button", 9)
local stealButtonEnabled = false
local stealButtonGui = nil
local stealButton = nil

local function createStealButton()
    if stealButtonGui then return end
    stealButtonGui = Instance.new("ScreenGui")
    stealButtonGui.Name = "StealGunCircle"
    stealButtonGui.ResetOnSpawn = false
    stealButtonGui.Parent = game.CoreGui
    stealButton = Instance.new("TextButton")
    stealButton.Size = UDim2.new(0, 70, 0, 70)
    stealButton.Position = UDim2.new(0.85, 0, 0.50, 0)
    stealButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    stealButton.BackgroundTransparency = 0.5
    stealButton.Text = "STEAL"
    stealButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    stealButton.TextScaled = true
    stealButton.Font = Enum.Font.GothamBold
    stealButton.BorderSizePixel = 0
    stealButton.AutoButtonColor = true
    stealButton.Parent = stealButtonGui
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent = stealButton
    
    local dragData = {active = false, startPos = nil, startMouse = nil, startOffset = nil}
    local function startDrag(input)
        dragData.active = true
        dragData.startPos = stealButton.Position
        dragData.startMouse = input.Position
        local absPos = stealButton.AbsolutePosition
        dragData.startOffset = Vector2.new(input.Position.X - absPos.X, input.Position.Y - absPos.Y)
    end
    local function updateDrag(input)
        if not dragData.active then return end
        local delta = input.Position - dragData.startMouse
        local newX = dragData.startPos.X.Scale + (dragData.startPos.X.Offset + delta.X) / workspace.CurrentCamera.ViewportSize.X
        local newY = dragData.startPos.Y.Scale + (dragData.startPos.Y.Offset + delta.Y) / workspace.CurrentCamera.ViewportSize.Y
        stealButton.Position = UDim2.new(newX, 0, newY, 0)
    end
    local function endDrag()
        dragData.active = false
    end
    
    stealButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
    stealButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end)
    stealButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
    
    stealButton.MouseButton1Click:Connect(function()
        stealGun()
    end)
end

local function removeStealButton()
    if stealButtonGui then stealButtonGui:Destroy(); stealButtonGui = nil; stealButton = nil end
    stealButtonEnabled = false
end

stealBtnTrack.MouseButton1Click:Connect(function()
    stealButtonEnabled = not stealButtonEnabled
    setToggle(stealBtnTrack, stealBtnKnob, stealButtonEnabled)
    if stealButtonEnabled then createStealButton() else removeStealButton() end
end)

-- NOCLIP & INFINITE JUMP & SPEED GLITCH
makeDivider(miscPage, 10)
makeSection(miscPage, "MOVEMENT", 11)

local noclipTrack, noclipKnob = makeToggle(miscPage, "Noclip", 12)
noclipTrack.MouseButton1Click:Connect(function()
    noclipEnabled = not noclipEnabled
    setToggle(noclipTrack, noclipKnob, noclipEnabled)
    
    if noclipEnabled then
        if noclipConnection then return end
        noclipConnection = RunService.Stepped:Connect(function()
            if not noclipEnabled then return end
            local char = localplayer.Character
            if not char then return end
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end)
        local function setupNoclip(char)
            if not char then return end
            char:WaitForChild("HumanoidRootPart")
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
        if localplayer.Character then
            setupNoclip(localplayer.Character)
        end
        localplayer.CharacterAdded:Connect(setupNoclip)
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
        local char = localplayer.Character
        if char then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = true
                end
            end
        end
    end
end)

local jumpTrack, jumpKnob = makeToggle(miscPage, "Infinite Jump", 13)
jumpTrack.MouseButton1Click:Connect(function()
    infiniteJumpEnabled = not infiniteJumpEnabled
    setToggle(jumpTrack, jumpKnob, infiniteJumpEnabled)
    
    if infiniteJumpEnabled then
        if infiniteJumpConnection then return end
        local function setupJump(char)
            if not char then return end
            local hum = char:WaitForChild("Humanoid")
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        end
        infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
            if infiniteJumpEnabled and localplayer.Character then
                local hum = localplayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
        if localplayer.Character then
            setupJump(localplayer.Character)
        end
        localplayer.CharacterAdded:Connect(setupJump)
    else
        if infiniteJumpConnection then
            infiniteJumpConnection:Disconnect()
            infiniteJumpConnection = nil
        end
    end
end)

local speedTrack, speedKnob = makeToggle(miscPage, "Speed Glitch", 14)
speedTrack.MouseButton1Click:Connect(function()
    speedGlitchEnabled = not speedGlitchEnabled
    setToggle(speedTrack, speedKnob, speedGlitchEnabled)
    
    if speedGlitchEnabled then
        if speedGlitchConnection then return end
        speedGlitchConnection = RunService.Heartbeat:Connect(function()
            if not speedGlitchEnabled then return end
            local char = localplayer.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local state = hum:GetState()
            local inAir = state == Enum.HumanoidStateType.Jumping
                or state == Enum.HumanoidStateType.Freefall
                or state == Enum.HumanoidStateType.FallingDown
            local moving = hum.MoveDirection.Magnitude > 0
            if inAir and moving then
                hum.WalkSpeed = SPEED_GLITCH_BOOST
            else
                hum.WalkSpeed = SPEED_GLITCH_NORMAL
            end
        end)
    else
        if speedGlitchConnection then
            speedGlitchConnection:Disconnect()
            speedGlitchConnection = nil
        end
        local char = localplayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = SPEED_GLITCH_NORMAL end
        end
    end
end)

-- EMOTES SECTION
makeDivider(miscPage, 15)
makeSection(miscPage, "EMOTES", 16)

local emoteContainer = Instance.new("Frame")
emoteContainer.Size = UDim2.new(1, 0, 0, 120)
emoteContainer.BackgroundTransparency = 1
emoteContainer.ClipsDescendants = true
emoteContainer.LayoutOrder = 17
emoteContainer.Parent = miscPage

local emoteScroll = Instance.new("ScrollingFrame")
emoteScroll.Size = UDim2.new(1, 0, 1, 0)
emoteScroll.BackgroundTransparency = 1
emoteScroll.BorderSizePixel = 0
emoteScroll.ScrollBarThickness = 4
emoteScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
emoteScroll.ScrollBarImageTransparency = 0.3
emoteScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
emoteScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
emoteScroll.ScrollingEnabled = true
emoteScroll.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
emoteScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
emoteScroll.Parent = emoteContainer

local emoteList = Instance.new("UIListLayout", emoteScroll)
emoteList.FillDirection = Enum.FillDirection.Vertical
emoteList.Padding = UDim.new(0, 1)
emoteList.SortOrder = Enum.SortOrder.LayoutOrder

local emotePad = Instance.new("UIPadding", emoteScroll)
emotePad.PaddingLeft = UDim.new(0, 3)
emotePad.PaddingRight = UDim.new(0, 3)

local PlayCustomEmote = function(name, id)
    local Character = localplayer.Character or localplayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local Desc = Humanoid:FindFirstChildOfClass("HumanoidDescription")
    if not Desc then
        Desc = Instance.new("HumanoidDescription")
        Desc.Parent = Humanoid
    end
    local success = pcall(function()
        Humanoid:PlayEmoteAndGetAnimTrackById(id)
    end)
    if not success then
        Desc:AddEmote(name, id)
        Humanoid:PlayEmoteAndGetAnimTrackById(id)
    end
end

local emotes = {
    {Name = "Sit", ID = 116909481264292},
    {Name = "Floss", ID = 123783175775850},
    {Name = "Zen", ID = 76095183942765},
    {Name = "Dab", ID = 124450033904654},
    {Name = "Ninja Rest", ID = 98307289830370},
    {Name = "Headless", ID = 70396352755636},
    {Name = "Laugh", ID = 63053773550486},
}

for i, emote in ipairs(emotes) do
    local emoteBtn = Instance.new("TextButton")
    emoteBtn.Size = UDim2.new(1, 0, 0, 24)
    emoteBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 40)
    emoteBtn.BorderSizePixel = 0
    emoteBtn.Text = emote.Name
    emoteBtn.TextColor3 = Color3.fromRGB(185, 185, 195)
    emoteBtn.TextSize = 9
    emoteBtn.Font = Enum.Font.GothamMedium
    emoteBtn.AutoButtonColor = false
    emoteBtn.LayoutOrder = i
    emoteBtn.Parent = emoteScroll
    
    Instance.new("UICorner", emoteBtn).CornerRadius = UDim.new(0, 4)
    local bs = Instance.new("UIStroke", emoteBtn)
    bs.Color = Color3.fromRGB(55, 55, 60)
    bs.Thickness = 1
    
    emoteBtn.MouseEnter:Connect(function()
        emoteBtn.BackgroundColor3 = Color3.fromRGB(42, 42, 46)
    end)
    emoteBtn.MouseLeave:Connect(function()
        emoteBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 40)
    end)
    
    emoteBtn.MouseButton1Click:Connect(function()
        PlayCustomEmote(emote.Name, emote.ID)
    end)
end

-- SPAWNER TAB
makeSection(spawnerPage, "WEAPON SPAWNER", 1)

local spawnerInfo = Instance.new("TextLabel")
spawnerInfo.Size = UDim2.new(1, 0, 0, 20)
spawnerInfo.BackgroundTransparency = 1
spawnerInfo.Text = "spawn any weapon"
spawnerInfo.TextColor3 = Color3.fromRGB(150, 150, 160)
spawnerInfo.TextSize = 8
spawnerInfo.Font = Enum.Font.Gotham
spawnerInfo.TextWrapped = true
spawnerInfo.LayoutOrder = 2
spawnerInfo.Parent = spawnerPage

local spawnerInput = Instance.new("TextBox")
spawnerInput.Size = UDim2.new(1, 0, 0, 22)
spawnerInput.BackgroundColor3 = Color3.fromRGB(38, 38, 43)
spawnerInput.BorderSizePixel = 0
spawnerInput.Text = ""
spawnerInput.PlaceholderText = "weapon name"
spawnerInput.TextColor3 = Color3.fromRGB(210, 210, 220)
spawnerInput.PlaceholderColor3 = Color3.fromRGB(100, 100, 110)
spawnerInput.Font = Enum.Font.Gotham
spawnerInput.TextSize = 9
spawnerInput.ClearTextOnFocus = false
spawnerInput.LayoutOrder = 3
spawnerInput.Parent = spawnerPage

local spawnerInputCorner = Instance.new("UICorner")
spawnerInputCorner.CornerRadius = UDim.new(0, 3)
spawnerInputCorner.Parent = spawnerInput

local spawnerInputBorder = Instance.new("UIStroke")
spawnerInputBorder.Color = Color3.fromRGB(50, 50, 55)
spawnerInputBorder.Thickness = 1
spawnerInputBorder.Parent = spawnerInput

local spawnerAmountRow = Instance.new("Frame")
spawnerAmountRow.Size = UDim2.new(1, 0, 0, 28)
spawnerAmountRow.BackgroundTransparency = 1
spawnerAmountRow.LayoutOrder = 4
spawnerAmountRow.Parent = spawnerPage

local spawnerAmountBox = Instance.new("TextBox")
spawnerAmountBox.Size = UDim2.new(0.25, 0, 1, 0)
spawnerAmountBox.BackgroundColor3 = Color3.fromRGB(38, 38, 43)
spawnerAmountBox.BorderSizePixel = 0
spawnerAmountBox.Text = "1"
spawnerAmountBox.TextColor3 = Color3.fromRGB(210, 210, 220)
spawnerAmountBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 110)
spawnerAmountBox.Font = Enum.Font.Gotham
spawnerAmountBox.TextSize = 9
spawnerAmountBox.ClearTextOnFocus = false
spawnerAmountBox.Parent = spawnerAmountRow

local spawnerAmountCorner = Instance.new("UICorner")
spawnerAmountCorner.CornerRadius = UDim.new(0, 3)
spawnerAmountCorner.Parent = spawnerAmountBox

local spawnerAmountBorder = Instance.new("UIStroke")
spawnerAmountBorder.Color = Color3.fromRGB(50, 50, 55)
spawnerAmountBorder.Thickness = 1
spawnerAmountBorder.Parent = spawnerAmountBox

local spawnerSpawnBtn = Instance.new("TextButton")
spawnerSpawnBtn.Size = UDim2.new(0.72, 0, 1, 0)
spawnerSpawnBtn.Position = UDim2.new(0.28, 0, 0, 0)
spawnerSpawnBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
spawnerSpawnBtn.BorderSizePixel = 0
spawnerSpawnBtn.Text = "SPAWN"
spawnerSpawnBtn.TextColor3 = Color3.fromRGB(210, 210, 220)
spawnerSpawnBtn.Font = Enum.Font.GothamBold
spawnerSpawnBtn.TextSize = 9
spawnerSpawnBtn.AutoButtonColor = false
spawnerSpawnBtn.Parent = spawnerAmountRow

local spawnerSpawnCorner = Instance.new("UICorner")
spawnerSpawnCorner.CornerRadius = UDim.new(0, 3)
spawnerSpawnCorner.Parent = spawnerSpawnBtn

local spawnerSpawnBorder = Instance.new("UIStroke")
spawnerSpawnBorder.Color = Color3.fromRGB(60, 60, 67)
spawnerSpawnBorder.Thickness = 1
spawnerSpawnBorder.Parent = spawnerSpawnBtn

local spawnerStatus = Instance.new("TextLabel")
spawnerStatus.Size = UDim2.new(1, 0, 0, 16)
spawnerStatus.BackgroundTransparency = 1
spawnerStatus.Text = "ready"
spawnerStatus.TextColor3 = Color3.fromRGB(120, 120, 130)
spawnerStatus.Font = Enum.Font.Gotham
spawnerStatus.TextSize = 8
spawnerStatus.TextXAlignment = Enum.TextXAlignment.Left
spawnerStatus.LayoutOrder = 5
spawnerStatus.Parent = spawnerPage

initWeaponDB()

spawnerSpawnBtn.MouseButton1Click:Connect(function()
    local weaponName = spawnerInput.Text
    if weaponName == "" then
        spawnerStatus.Text = "enter a weapon name"
        spawnerStatus.TextColor3 = Color3.fromRGB(200, 130, 130)
        return
    end
    
    local amount = tonumber(spawnerAmountBox.Text)
    if not amount or amount < 1 then
        amount = 1
        spawnerAmountBox.Text = "1"
    end
    
    local resolvedKey = resolveWeaponInput(weaponName)
    if not resolvedKey then
        spawnerStatus.Text = "unknown weapon"
        spawnerStatus.TextColor3 = Color3.fromRGB(200, 130, 130)
        return
    end
    
    spawnWeaponCombined(resolvedKey, amount)
    spawnerStatus.Text = "spawned " .. resolvedKey:lower() .. " x" .. amount
    spawnerStatus.TextColor3 = Color3.fromRGB(130, 200, 130)
    
    task.spawn(function()
        task.wait(2)
        spawnerStatus.Text = "ready"
        spawnerStatus.TextColor3 = Color3.fromRGB(120, 120, 130)
    end)
end)

spawnerInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        spawnerSpawnBtn.MouseButton1Click:Fire()
    end
end)

spawnerAmountBox.FocusLost:Connect(function()
    local num = tonumber(spawnerAmountBox.Text)
    if not num or num < 1 then
        spawnerAmountBox.Text = "1"
    end
end)

-- CLOSE / REOPEN
closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false; reopenBar.Visible = true
end)
reopenBtn.MouseButton1Click:Connect(function()
    reopenBar.Visible = false; main.Visible = true
end)

-- MOBILE DRAGGING FOR MAIN GUI
local function makeDraggableMobile(handle, target)
    local dragData = {active = false, startPos = nil, startMouse = nil, startOffset = nil}
    local function startDrag(input)
        dragData.active = true
        dragData.startPos = target.Position
        dragData.startMouse = input.Position
        local absPos = target.AbsolutePosition
        dragData.startOffset = Vector2.new(input.Position.X - absPos.X, input.Position.Y - absPos.Y)
    end
    local function updateDrag(input)
        if not dragData.active then return end
        local delta = input.Position - dragData.startMouse
        local vp = workspace.CurrentCamera.ViewportSize
        local newX = dragData.startPos.X.Scale + (dragData.startPos.X.Offset + delta.X) / vp.X
        local newY = dragData.startPos.Y.Scale + (dragData.startPos.Y.Offset + delta.Y) / vp.Y
        target.Position = UDim2.new(newX, 0, newY, 0)
    end
    local function endDrag()
        dragData.active = false
    end
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end)
    
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
end

makeDraggableMobile(titleBar, main)
makeDraggableMobile(reopenBar, reopenBar)

switchTab("farm")

local players, plr = game:GetService("Players"), game:GetService("Players").LocalPlayer

pcall(function()
    local char = plr.Character or plr.CharacterAdded:Wait()
    local knife = char:FindFirstChildOfClass("Tool") or plr.Backpack:FindFirstChildOfClass("Tool")
    if knife and knife.Parent == plr.Backpack then knife.Parent = char end
    if knife then
        for _, player in ipairs(players:GetPlayers()) do
            if player ~= plr and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                task.spawn(function()
                    knife:Activate()
                    firetouchinterest(player.Character.HumanoidRootPart, knife.Handle, 0)
                    firetouchinterest(player.Character.HumanoidRootPart, knife.Handle, 1)
                end)
                wait(0.2)
            end
        end
    end
end)
