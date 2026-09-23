local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

local WeaponDB = nil
local weaponLookup = {}
local allWeaponKeys = {}

local function initWeaponDB()
    if WeaponDB then return end
    pcall(function()
        local Sync = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"))
        WeaponDB = Sync.Weapons
        if WeaponDB then
            for key, info in pairs(WeaponDB) do
                if type(info) == "table" then
                    table.insert(allWeaponKeys, key)
                    local kl = key:lower()
                    weaponLookup[kl] = weaponLookup[kl] or key
                    local dn = info.ItemName or info.DisplayName or info.Name
                    if dn then
                        dn = tostring(dn):lower()
                        weaponLookup[dn] = weaponLookup[dn] or key
                    end
                end
            end
            table.sort(allWeaponKeys)
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

local function searchWeapons(query, maxResults)
    maxResults = maxResults or 40
    if not query or query == "" then return {} end
    query = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return {} end

    local results = {}
    local seen = {}

    for _, key in ipairs(allWeaponKeys) do
        local kl = key:lower()
        if kl:sub(1, #query) == query then
            if not seen[key] then
                seen[key] = true
                table.insert(results, key)
            end
        end
    end

    if #results < maxResults then
        for _, key in ipairs(allWeaponKeys) do
            if #results >= maxResults then break end
            local kl = key:lower()
            if not seen[key] and kl:find(query, 1, true) then
                seen[key] = true
                table.insert(results, key)
            end
        end
    end

    return results
end

local function spawnWeaponToInventory(name)
    pcall(function()
        local ProfileData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ProfileData"))
        local InvDataChanged = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory"):WaitForChild("InventoryDataChanged")
        local owned = ProfileData.Weapons.Owned
        owned[name] = (owned[name] or 0) + 1
        InvDataChanged:Fire("Weapons", name, owned[name])
    end)
    return true
end

local CRATE = "KnifeBox1"
local _BC = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("BoxController")

local function spawnWeaponViaBox(name)
    pcall(function()
        local payload = {{MysteryBoxId = CRATE, RewardedItemId = name}}
        _BC:Fire(payload)
    end)
    return true
end

local function spawnWeaponCombined(name)
    spawnWeaponToInventory(name)
    spawnWeaponViaBox(name)
    return true
end

local Theme = {
    Bg          = Color3.fromRGB(28, 28, 30),
    Bg2         = Color3.fromRGB(38, 38, 40),
    Panel       = Color3.fromRGB(45, 45, 48),
    PanelHover  = Color3.fromRGB(58, 58, 62),
    RowBg       = Color3.fromRGB(52, 52, 56),
    RowHover    = Color3.fromRGB(68, 68, 74),
    RowPress    = Color3.fromRGB(82, 82, 90),
    Stroke      = Color3.fromRGB(70, 70, 74),
    Text        = Color3.fromRGB(240, 240, 240),
    SubText     = Color3.fromRGB(160, 160, 165),
    Accent      = Color3.fromRGB(90, 90, 95),
    AccentHi    = Color3.fromRGB(130, 130, 140),
    Success     = Color3.fromRGB(120, 200, 140),
    Error       = Color3.fromRGB(230, 100, 100),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MM2WeaponSpawner"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 320, 0, 210)
main.Position = UDim2.new(0.5, -160, 0.5, -105)
main.BackgroundColor3 = Theme.Bg
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = false
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Theme.Stroke
mainStroke.Thickness = 1
mainStroke.Transparency = 0.3
mainStroke.Parent = main

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = Theme.Bg2
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local headerMask = Instance.new("Frame")
headerMask.Size = UDim2.new(1, 0, 0, 12)
headerMask.Position = UDim2.new(0, 0, 1, -12)
headerMask.BackgroundColor3 = Theme.Bg2
headerMask.BorderSizePixel = 0
headerMask.Parent = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 16, 0, 0)
title.Size = UDim2.new(1, -60, 1, 0)
title.Font = Enum.Font.GothamBold
title.Text = "MM2 Weapon Spawner"
title.TextColor3 = Theme.Text
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -34, 0.5, -13)
closeBtn.BackgroundColor3 = Theme.Panel
closeBtn.Text = "×"
closeBtn.TextColor3 = Theme.Text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 17
closeBtn.AutoButtonColor = false
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Error}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Panel}):Play()
end)
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

local body = Instance.new("Frame")
body.Name = "Body"
body.Position = UDim2.new(0, 14, 0, 54)
body.Size = UDim2.new(1, -28, 1, -68)
body.BackgroundTransparency = 1
body.Parent = main

local inputRow = Instance.new("Frame")
inputRow.Position = UDim2.new(0, 0, 0, 0)
inputRow.Size = UDim2.new(1, 0, 0, 40)
inputRow.BackgroundColor3 = Theme.Panel
inputRow.BorderSizePixel = 0
inputRow.Parent = body

local inputRowCorner = Instance.new("UICorner")
inputRowCorner.CornerRadius = UDim.new(0, 8)
inputRowCorner.Parent = inputRow

local inputRowStroke = Instance.new("UIStroke")
inputRowStroke.Color = Theme.Stroke
inputRowStroke.Thickness = 1
inputRowStroke.Transparency = 0.4
inputRowStroke.Parent = inputRow

local itemTextBox = Instance.new("TextBox")
itemTextBox.BackgroundTransparency = 1
itemTextBox.Position = UDim2.new(0, 12, 0, 0)
itemTextBox.Size = UDim2.new(1, -24, 1, 0)
itemTextBox.PlaceholderText = "Type weapon name..."
itemTextBox.PlaceholderColor3 = Theme.SubText
itemTextBox.Text = ""
itemTextBox.TextColor3 = Theme.Text
itemTextBox.Font = Enum.Font.Gotham
itemTextBox.TextSize = 14
itemTextBox.TextXAlignment = Enum.TextXAlignment.Left
itemTextBox.ClearTextOnFocus = false
itemTextBox.Parent = inputRow

local filterButton = Instance.new("TextButton")
filterButton.Position = UDim2.new(0, 0, 0, 50)
filterButton.Size = UDim2.new(1, 0, 0, 34)
filterButton.BackgroundColor3 = Theme.Panel
filterButton.Text = "Filter Database"
filterButton.TextColor3 = Theme.Text
filterButton.Font = Enum.Font.GothamMedium
filterButton.TextSize = 13
filterButton.AutoButtonColor = false
filterButton.Parent = body

local filterCorner = Instance.new("UICorner")
filterCorner.CornerRadius = UDim.new(0, 8)
filterCorner.Parent = filterButton

local filterStroke = Instance.new("UIStroke")
filterStroke.Color = Theme.Stroke
filterStroke.Thickness = 1
filterStroke.Transparency = 0.4
filterStroke.Parent = filterButton

filterButton.MouseEnter:Connect(function()
    TweenService:Create(filterButton, TweenInfo.new(0.15), {BackgroundColor3 = Theme.PanelHover}):Play()
end)
filterButton.MouseLeave:Connect(function()
    TweenService:Create(filterButton, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Panel}):Play()
end)

local spawnButton = Instance.new("TextButton")
spawnButton.Position = UDim2.new(0, 0, 0, 92)
spawnButton.Size = UDim2.new(1, 0, 0, 40)
spawnButton.BackgroundColor3 = Theme.Panel
spawnButton.Text = "Spawn Weapon"
spawnButton.TextColor3 = Theme.Text
spawnButton.Font = Enum.Font.GothamMedium
spawnButton.TextSize = 13
spawnButton.AutoButtonColor = false
spawnButton.Parent = body

local spawnCorner = Instance.new("UICorner")
spawnCorner.CornerRadius = UDim.new(0, 8)
spawnCorner.Parent = spawnButton

local spawnStroke = Instance.new("UIStroke")
spawnStroke.Color = Theme.Stroke
spawnStroke.Thickness = 1
spawnStroke.Transparency = 0.4
spawnStroke.Parent = spawnButton

spawnButton.MouseEnter:Connect(function()
    TweenService:Create(spawnButton, TweenInfo.new(0.15), {BackgroundColor3 = Theme.PanelHover}):Play()
end)
spawnButton.MouseLeave:Connect(function()
    TweenService:Create(spawnButton, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Panel}):Play()
end)

local MAX_RESULTS = 40
local MAX_VISIBLE = 5
local ROW_HEIGHT = 32
local HEADER_H = 22
local SCROLLBAR_W = 6

local dropdown = Instance.new("Frame")
dropdown.Name = "SearchDropdown"
dropdown.BackgroundColor3 = Theme.Bg2
dropdown.BorderSizePixel = 0
dropdown.Visible = false
dropdown.ZIndex = 10
dropdown.ClipsDescendants = true
dropdown.Parent = screenGui

local dropdownCorner = Instance.new("UICorner")
dropdownCorner.CornerRadius = UDim.new(0, 10)
dropdownCorner.Parent = dropdown

local dropdownStroke = Instance.new("UIStroke")
dropdownStroke.Color = Theme.Stroke
dropdownStroke.Thickness = 1
dropdownStroke.Transparency = 0.1
dropdownStroke.Parent = dropdown

local dropdownHeader = Instance.new("TextLabel")
dropdownHeader.BackgroundTransparency = 1
dropdownHeader.Position = UDim2.new(0, 12, 0, 0)
dropdownHeader.Size = UDim2.new(1, -24, 0, HEADER_H)
dropdownHeader.Font = Enum.Font.GothamBold
dropdownHeader.Text = "RESULTS"
dropdownHeader.TextColor3 = Theme.SubText
dropdownHeader.TextSize = 10
dropdownHeader.TextXAlignment = Enum.TextXAlignment.Left
dropdownHeader.ZIndex = 11
dropdownHeader.Parent = dropdown

local headerDivider = Instance.new("Frame")
headerDivider.BackgroundColor3 = Theme.Stroke
headerDivider.BorderSizePixel = 0
headerDivider.Position = UDim2.new(0, 0, 0, HEADER_H)
headerDivider.Size = UDim2.new(1, 0, 0, 1)
headerDivider.ZIndex = 11
headerDivider.Parent = dropdown

local scroller = Instance.new("ScrollingFrame")
scroller.Name = "Scroller"
scroller.BackgroundTransparency = 1
scroller.Position = UDim2.new(0, 0, 0, HEADER_H + 1)
scroller.Size = UDim2.new(1, 0, 1, -HEADER_H - 1)
scroller.BorderSizePixel = 0
scroller.ScrollBarThickness = SCROLLBAR_W
scroller.ScrollBarImageColor3 = Theme.AccentHi
scroller.ScrollBarImageTransparency = 0.3
scroller.ScrollingDirection = Enum.ScrollingDirection.Y
scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
scroller.AutomaticCanvasSize = Enum.AutomaticSize.None
scroller.ElasticBehavior = Enum.ElasticBehavior.Never
scroller.ZIndex = 11
scroller.ClipsDescendants = true
scroller.Parent = dropdown

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 0)
layout.Parent = scroller

local function syncDropdownPosition()
    local absPos = inputRow.AbsolutePosition
    local absSize = inputRow.AbsoluteSize
    dropdown.Position = UDim2.fromOffset(absPos.X, absPos.Y + absSize.Y + 6)
    dropdown.Size = UDim2.fromOffset(absSize.X, dropdown.Size.Y.Offset)
end

local rowPool = {}
local currentResults = {}
local selectedIndex = 0

local function getRow(index)
    if rowPool[index] then return rowPool[index] end

    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = Theme.RowBg
    btn.BorderSizePixel = 0
    btn.Size = UDim2.new(1, -SCROLLBAR_W - 2, 0, ROW_HEIGHT)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 12
    btn.LayoutOrder = index
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = scroller

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 0)
    btnCorner.Parent = btn

    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.BackgroundColor3 = Theme.Stroke
    divider.BackgroundTransparency = 0.4
    divider.BorderSizePixel = 0
    divider.Position = UDim2.new(0, 0, 1, -1)
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.ZIndex = 13
    divider.Parent = btn

    local btnLabel = Instance.new("TextLabel")
    btnLabel.BackgroundTransparency = 1
    btnLabel.Position = UDim2.new(0, 14, 0, 0)
    btnLabel.Size = UDim2.new(1, -28, 1, 0)
    btnLabel.Font = Enum.Font.GothamMedium
    btnLabel.Text = ""
    btnLabel.TextColor3 = Theme.Text
    btnLabel.TextSize = 13
    btnLabel.TextXAlignment = Enum.TextXAlignment.Left
    btnLabel.ZIndex = 14
    btnLabel.Parent = btn

    btn.MouseEnter:Connect(function()
        if btn:GetAttribute("isSelected") ~= true then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Theme.RowHover}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if btn:GetAttribute("isSelected") ~= true then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Theme.RowBg}):Play()
        end
    end)

    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = Theme.RowPress}):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        if btn:GetAttribute("isSelected") ~= true then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Theme.RowHover}):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function()
        local idx = btn:GetAttribute("resultIndex")
        if idx and currentResults[idx] then
            itemTextBox.Text = currentResults[idx]
            itemTextBox.CursorPosition = #itemTextBox.Text + 1
            hideDropdown()
        end
    end)

    btn:SetAttribute("isSelected", false)
    rowPool[index] = btn
    return btn
end

local function applyRowStyle(row, selected)
    row:SetAttribute("isSelected", selected)
    row.BackgroundColor3 = selected and Theme.AccentHi or Theme.RowBg
end

local function highlightRow(index)
    for i, row in ipairs(rowPool) do
        applyRowStyle(row, i == index)
    end
    if index > 0 and rowPool[index] then
        local rowTop = (index - 1) * ROW_HEIGHT
        local rowBottom = rowTop + ROW_HEIGHT
        local viewTop = scroller.CanvasPosition.Y
        local viewBottom = viewTop + scroller.AbsoluteWindowSize.Y
        if rowTop < viewTop then
            scroller.CanvasPosition = Vector2.new(0, rowTop)
        elseif rowBottom > viewBottom then
            scroller.CanvasPosition = Vector2.new(0, rowBottom - scroller.AbsoluteWindowSize.Y)
        end
    end
end

local function updateRowDividers()
    local lastVisible = nil
    for i = #rowPool, 1, -1 do
        if rowPool[i] and rowPool[i].Visible then
            lastVisible = i
            break
        end
    end
    for i, row in ipairs(rowPool) do
        local d = row:FindFirstChild("Divider")
        if d then
            d.Visible = row.Visible and i ~= lastVisible
        end
    end
end

function hideDropdown()
    dropdown.Visible = false
    selectedIndex = 0
    currentResults = {}
    scroller.CanvasPosition = Vector2.new(0, 0)
    for _, row in ipairs(rowPool) do
        row.Visible = false
        row:SetAttribute("isSelected", false)
    end
end

local function showDropdown(results)
    currentResults = results
    selectedIndex = 0
    scroller.CanvasPosition = Vector2.new(0, 0)

    if #results == 0 then
        hideDropdown()
        return
    end

    for i = 1, #results do
        local row = getRow(i)
        row.Visible = true
        row:SetAttribute("resultIndex", i)
        row:SetAttribute("isSelected", false)
        row.BackgroundColor3 = Theme.RowBg
        local label = row:FindFirstChildOfClass("TextLabel")
        if label then label.Text = results[i] end
    end
    for i = #results + 1, #rowPool do
        rowPool[i].Visible = false
    end

    updateRowDividers()

    dropdownHeader.Text = string.format("RESULTS  ·  %d", #results)

    local visibleRows = math.min(#results, MAX_VISIBLE)
    local height = (HEADER_H + 1) + (visibleRows * ROW_HEIGHT)
    dropdown.Size = UDim2.fromOffset(inputRow.AbsoluteSize.X, height)

    scroller.CanvasSize = UDim2.new(0, 0, 0, #results * ROW_HEIGHT)

    local absPos = inputRow.AbsolutePosition
    local absSize = inputRow.AbsoluteSize
    dropdown.Position = UDim2.fromOffset(absPos.X, absPos.Y + absSize.Y + 6)

    dropdown.Visible = true
end

task.spawn(function()
    while screenGui.Parent do
        if dropdown.Visible then
            syncDropdownPosition()
        end
        task.wait()
    end
end)

local function filterDatabase()
    if not WeaponDB then
        showNotification("Database not loaded yet", true)
        return
    end
    local text = itemTextBox.Text
    if text == "" then
        showNotification("Type something to filter", true)
        return
    end
    local results = searchWeapons(text, MAX_RESULTS)
    if #results == 0 then
        showNotification("No matches for: " .. text, true)
        hideDropdown()
        return
    end
    showDropdown(results)
end

filterButton.MouseButton1Click:Connect(function()
    task.defer(filterDatabase)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
        if itemTextBox:IsFocused() then
            task.defer(filterDatabase)
        elseif dropdown.Visible and selectedIndex > 0 and currentResults[selectedIndex] then
            itemTextBox.Text = currentResults[selectedIndex]
            hideDropdown()
        end
        return
    end

    if not dropdown.Visible then return end

    if input.KeyCode == Enum.KeyCode.Down then
        if #currentResults > 0 then
            selectedIndex = selectedIndex + 1
            if selectedIndex > #currentResults then selectedIndex = 1 end
            highlightRow(selectedIndex)
        end
    elseif input.KeyCode == Enum.KeyCode.Up then
        if #currentResults > 0 then
            selectedIndex = selectedIndex - 1
            if selectedIndex < 1 then selectedIndex = #currentResults end
            highlightRow(selectedIndex)
        end
    elseif input.KeyCode == Enum.KeyCode.Escape then
        hideDropdown()
    end
end)

local footerText = Instance.new("TextLabel")
footerText.BackgroundTransparency = 1
footerText.Position = UDim2.new(0, 0, 1, -22)
footerText.Size = UDim2.new(1, 0, 0, 16)
footerText.Font = Enum.Font.Gotham
footerText.Text = "made by unknowuser238183 in tiktok"
footerText.TextColor3 = Theme.SubText
footerText.TextSize = 10
footerText.Parent = main

local notif = Instance.new("Frame")
notif.Size = UDim2.new(0, 260, 0, 38)
notif.Position = UDim2.new(0.5, -130, 0.5, 100)
notif.BackgroundColor3 = Theme.Panel
notif.BorderSizePixel = 0
notif.BackgroundTransparency = 1
notif.Visible = false
notif.ZIndex = 20
notif.Parent = screenGui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 8)
notifCorner.Parent = notif

local notifStroke = Instance.new("UIStroke")
notifStroke.Color = Theme.Stroke
notifStroke.Thickness = 1
notifStroke.Transparency = 1
notifStroke.Parent = notif

local notifBar = Instance.new("Frame")
notifBar.Size = UDim2.new(0, 4, 1, -12)
notifBar.Position = UDim2.new(0, 6, 0, 6)
notifBar.BackgroundColor3 = Theme.AccentHi
notifBar.BorderSizePixel = 0
notifBar.Parent = notif

local notifBarCorner = Instance.new("UICorner")
notifBarCorner.CornerRadius = UDim.new(0, 2)
notifBarCorner.Parent = notifBar

local notifText = Instance.new("TextLabel")
notifText.BackgroundTransparency = 1
notifText.Position = UDim2.new(0, 18, 0, 0)
notifText.Size = UDim2.new(1, -26, 1, 0)
notifText.Font = Enum.Font.GothamMedium
notifText.Text = ""
notifText.TextColor3 = Theme.Text
notifText.TextSize = 11
notifText.TextXAlignment = Enum.TextXAlignment.Left
notifText.ZIndex = 21
notifText.Parent = notif

local notifTweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local hideTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

local notifBusy = false

function showNotification(message, isError)
    notifText.Text = message
    notifBar.BackgroundColor3 = isError and Theme.Error or Theme.Success

    if notifBusy then return end
    notifBusy = true

    notif.Visible = true
    notif.Position = UDim2.new(0.5, -130, 0.5, 100)
    notif.BackgroundTransparency = 1
    notifText.TextTransparency = 1
    notifStroke.Transparency = 1
    notifBar.BackgroundTransparency = 0

    TweenService:Create(notif, notifTweenInfo, {
        Position = UDim2.new(0.5, -130, 0.5, 105),
        BackgroundTransparency = 0,
    }):Play()
    TweenService:Create(notifText, notifTweenInfo, {TextTransparency = 0}):Play()
    TweenService:Create(notifStroke, notifTweenInfo, {Transparency = 0}):Play()

    task.delay(2.5, function()
        TweenService:Create(notif, hideTweenInfo, {
            Position = UDim2.new(0.5, -130, 0.5, 100),
            BackgroundTransparency = 1,
        }):Play()
        TweenService:Create(notifText, hideTweenInfo, {TextTransparency = 1}):Play()
        TweenService:Create(notifStroke, hideTweenInfo, {Transparency = 1}):Play()
        task.wait(0.3)
        notif.Visible = false
        notifBusy = false
    end)
end

initWeaponDB()

local function doSpawn()
    local itemName = itemTextBox.Text
    if itemName == "" then
        showNotification("Enter a weapon name", true)
        return
    end

    local resolvedKey = resolveWeaponInput(itemName)
    if not resolvedKey then
        showNotification("Item not found: " .. itemName, true)
        return
    end

    spawnWeaponCombined(resolvedKey)
    showNotification("Spawned: " .. resolvedKey, false)
end

spawnButton.MouseButton1Click:Connect(function()
    hideDropdown()
    doSpawn()
end)

local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    main.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
    if dropdown.Visible then
        syncDropdownPosition()
    end
end

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)
