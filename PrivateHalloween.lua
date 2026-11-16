print("LOADED")

-----------------------------------------------------------
-- ULTIMATE ADOPT ME! AUTOMATION & TELEPORT HUB (WITH ANTI-AFK)
-----------------------------------------------------------
task.spawn(function()
    pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Players = game:GetService("Players")
        local Workspace = game:GetService("Workspace")
        local VirtualUser = game:GetService("VirtualUser")
        local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
        local playerGui = localPlayer:WaitForChild("PlayerGui")

        -- Anti-AFK Connection
        local antiAfkConnection = localPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
            end)
        end)

        -- Safe loading of all modules & dependencies
        local successFsys, Fsys = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Fsys", 5))
        end)
        
        if not successFsys or not Fsys then
            warn("[Module Error]: Failed to load Fsys module.")
            return
        end

        local load = Fsys.load
        local ClientData = pcall(function() return load("ClientData") end) and load("ClientData") or nil
        local RouterClient = pcall(function() return load("RouterClient") end) and load("RouterClient") or nil
        local FurnitureMannequinsHelper = pcall(function() return load("FurnitureMannequinsHelper") end) and load("FurnitureMannequinsHelper") or nil
        local UIManager = pcall(function() return load("UIManager") end) and load("UIManager") or nil

        local successLoc, DynamicLocationDB = pcall(function()
            return require(ReplicatedStorage.ClientDB.DynamicLocationDB)
        end)

        -- State Variables
        local SelectedTarget = localPlayer
        local SelectedTargetName = localPlayer.Name
        local AutoMannequinsRunning = false
        local AutoRegistersRunning = false
        local PayAmountValue = 50
        local SelectedMode = "Mannequin" -- Can be "Mannequin", "SetOnSale", or "SetOffSale"
        local LastInterceptedMsg = nil

        local function ResolvePlayer(targetName)
            if not targetName or targetName == "None" or targetName == "Loading..." or targetName == "No Players Found" then 
                return localPlayer 
            end
            local target = Players:FindFirstChild(targetName)
            if target then return target end
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower() == targetName:lower() or p.DisplayName:lower() == targetName:lower() then
                    return p
                end
            end
            return localPlayer
        end

        local function GetPlayerNames()
            local names = {}
            pcall(function()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p and p.Name then
                        table.insert(names, tostring(p.Name))
                    end
                end
            end)
            table.sort(names)
            return #names > 0 and names or {"No Players Found"}
        end

        -- Scan outfits table to find if version is already owned, and return its slot key if found
        local function FindOwnedOutfitKey(versionToCheck)
            local foundKey = nil
            pcall(function()
                if not ClientData or type(ClientData.get_data) ~= "function" then return end
                local data = ClientData.get_data()
                if not data or not data[localPlayer.Name] then return end
                
                local playerData = data[localPlayer.Name]
                local outfitsTable = playerData.outfits
                if outfitsTable then
                    for slotKey, outfitData in pairs(outfitsTable) do
                        if outfitData then
                            local v = tostring(outfitData.source_outfit_version or outfitData.version or "")
                            if v == tostring(versionToCheck) then
                                foundKey = slotKey
                                break
                            end
                        end
                    end
                end
            end)
            return foundKey
        end

        local function returnToHouse(targetOwner)
            task.spawn(function()
                pcall(function()
                    if DynamicLocationDB and DynamicLocationDB.housing then
                        DynamicLocationDB.housing.dynamic_location({
                            house_owner = targetOwner or localPlayer,
                            destination_door_id = "MainDoor"
                        })
                    end

                    local ClientStore = load("ClientStore")
                    if ClientStore and ClientStore.store then
                        ClientStore.store:dispatch({
                            ["type"] = "set_house_edit_mode",
                            ["value"] = "Disabled"
                        })
                    end
                    
                    local uiManagerInstance = load("UIManager")
                    if uiManagerInstance and uiManagerInstance.apps and uiManagerInstance.apps.HouseEditorWrapperApp then
                        uiManagerInstance.apps.HouseEditorWrapperApp:clear_drawer()
                    end
                end)
            end)
        end

        local function GetRegisterList()
            local registers = {"All Registers"}
            local seenIds = {}

            pcall(function()
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") then
                        local nameLower = obj.Name:lower()
                        if nameLower:find("register") or nameLower:find("cash") then
                            local parentPath = tostring(obj.Parent)
                            local furnId = parentPath:match("([^/]+)$")
                            
                            if furnId and not seenIds[furnId] then
                                seenIds[furnId] = true
                                local cleanName = obj.Name:gsub("Meshes/", "")
                                table.insert(registers, string.format("%s | %s", furnId, cleanName))
                            end
                        end
                    end
                end
            end)

            return #registers > 1 and registers or {"All Registers", "No Registers Found"}
        end

        local function GetOutfitVersionList()
            local versions = {"All Versions"}
            pcall(function()
                if not FurnitureMannequinsHelper or type(FurnitureMannequinsHelper.get_mannequins) ~= "function" then return end
                local mannequins = FurnitureMannequinsHelper.get_mannequins() or {}
                for _, m in pairs(mannequins) do
                    pcall(function()
                        if m and m:IsA("Instance") then
                            local version = m:GetAttribute("outfit_version")
                            if version then
                                local ownerName = "Unknown"
                                local ownerVal = m:FindFirstChild("Owner")
                                if ownerVal and ownerVal.Value and ownerVal.Value:IsA("Player") then
                                    ownerName = tostring(ownerVal.Value.Name)
                                end
                                table.insert(versions, string.format("[%s] v: %s", ownerName, tostring(version):sub(1, 8)))
                            end
                        end
                    end)
                end
            end)
            return #versions > 1 and versions or {"All Versions", "No Outfits Found"}
        end

        -- Create Native Roblox UI
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "UltimateAdoptMeHub"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui

        local mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, 310, 0, 420)
        mainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
        mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        mainFrame.BorderSizePixel = 0
        mainFrame.Active = true
        mainFrame.Draggable = true
        mainFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = mainFrame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(0.8, 0, 0, 35)
        title.Position = UDim2.new(0.05, 0, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = "Ultimate Transfer & Teleport Hub"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.Font = Enum.Font.SourceSansBold
        title.TextSize = 14
        title.Parent = mainFrame

        local closeButton = Instance.new("TextButton")
        closeButton.Size = UDim2.new(0, 25, 0, 25)
        closeButton.Position = UDim2.new(0.88, 0, 0, 5)
        closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeButton.Font = Enum.Font.SourceSansBold
        closeButton.TextSize = 14
        closeButton.Text = "X"
        closeButton.Parent = mainFrame

        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 4)
        closeCorner.Parent = closeButton

        local dropdownButton = Instance.new("TextButton")
        dropdownButton.Size = UDim2.new(0.9, 0, 0, 32)
        dropdownButton.Position = UDim2.new(0.05, 0, 0, 38)
        dropdownButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        dropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        dropdownButton.Font = Enum.Font.SourceSansBold
        dropdownButton.TextSize = 13
        dropdownButton.Text = "Target: [Click to Cycle Player]"
        dropdownButton.Parent = mainFrame

        local dropCorner = Instance.new("UICorner")
        dropCorner.CornerRadius = UDim.new(0, 6)
        dropCorner.Parent = dropdownButton

        local modeButton = Instance.new("TextButton")
        modeButton.Size = UDim2.new(0.9, 0, 0, 30)
        modeButton.Position = UDim2.new(0.05, 0, 0, 75)
        modeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        modeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        modeButton.Font = Enum.Font.SourceSansBold
        modeButton.TextSize = 12
        modeButton.Text = "Mannequin Mode: Transfer"
        modeButton.Parent = mainFrame

        local modeCorner = Instance.new("UICorner")
        modeCorner.CornerRadius = UDim.new(0, 6)
        modeCorner.Parent = modeButton

        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(0.9, 0, 0, 50)
        statusLabel.Position = UDim2.new(0.05, 0, 0, 110)
        statusLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.Font = Enum.Font.SourceSans
        statusLabel.TextSize = 11
        statusLabel.TextWrapped = true
        statusLabel.Text = "Scanning environment..."
        statusLabel.Parent = mainFrame

        local statusCorner = Instance.new("UICorner")
        statusCorner.CornerRadius = UDim.new(0, 6)
        statusCorner.Parent = statusLabel

        local teleportButton = Instance.new("TextButton")
        teleportButton.Size = UDim2.new(0.9, 0, 0, 30)
        teleportButton.Position = UDim2.new(0.05, 0, 0, 165)
        teleportButton.BackgroundColor3 = Color3.fromRGB(50, 120, 180)
        teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        teleportButton.Font = Enum.Font.SourceSansBold
        teleportButton.TextSize = 13
        teleportButton.Text = "Teleport to Target House"
        teleportButton.Parent = mainFrame

        local tpCorner = Instance.new("UICorner")
        tpCorner.CornerRadius = UDim.new(0, 6)
        tpCorner.Parent = teleportButton

        -- Auto Mannequins Toggle Button
        local mannequinsToggleBtn = Instance.new("TextButton")
        mannequinsToggleBtn.Size = UDim2.new(0.9, 0, 0, 32)
        mannequinsToggleBtn.Position = UDim2.new(0.05, 0, 0, 200)
        mannequinsToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        mannequinsToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        mannequinsToggleBtn.Font = Enum.Font.SourceSansBold
        mannequinsToggleBtn.TextSize = 13
        mannequinsToggleBtn.Text = "Auto Mannequins: OFF"
        mannequinsToggleBtn.Parent = mainFrame

        local manCorner = Instance.new("UICorner")
        manCorner.CornerRadius = UDim.new(0, 6)
        manCorner.Parent = mannequinsToggleBtn

        -- Auto Registers Toggle Button
        local registersToggleBtn = Instance.new("TextButton")
        registersToggleBtn.Size = UDim2.new(0.9, 0, 0, 32)
        registersToggleBtn.Position = UDim2.new(0.05, 0, 0, 237)
        registersToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        registersToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        registersToggleBtn.Font = Enum.Font.SourceSansBold
        registersToggleBtn.TextSize = 13
        registersToggleBtn.Text = "Auto Register: OFF"
        registersToggleBtn.Parent = mainFrame

        local regCorner = Instance.new("UICorner")
        regCorner.CornerRadius = UDim.new(0, 6)
        regCorner.Parent = registersToggleBtn

        local heavyButton = Instance.new("TextButton")
        heavyButton.Size = UDim2.new(0.9, 0, 0, 38)
        heavyButton.Position = UDim2.new(0.05, 0, 0, 274)
        heavyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 127)
        heavyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        heavyButton.Font = Enum.Font.SourceSansBold
        heavyButton.TextSize = 13
        heavyButton.Text = "Start Auto Heavy-Lift"
        heavyButton.Parent = mainFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = heavyButton

        -----------------------------------------------------------
        -- DIALOG INTERCEPTOR
        -----------------------------------------------------------
        local DialogApp = UIManager and UIManager.apps and UIManager.apps.DialogApp
        local OriginalDialogFunc = DialogApp and DialogApp.dialog

        if DialogApp and OriginalDialogFunc then
            DialogApp.dialog = function(self, dialogConfig, ...)
                if screenGui and screenGui.Parent then
                    local msg = "Dialog Blocked"
                    if type(dialogConfig) == "table" then
                        msg = tostring(dialogConfig.text or dialogConfig.title or dialogConfig.dialog_type or "Popup Dismissed")
                    end
                    
                    LastInterceptedMsg = msg
                    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                    statusLabel.Text = "[Notice]: " .. msg

                    task.delay(3, function()
                        if statusLabel and statusLabel.Parent then
                            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                            LastInterceptedMsg = nil
                        end
                    end)

                    if type(dialogConfig) == "table" and type(dialogConfig.buttons) == "table" then
                        if dialogConfig.buttons.close then return "close" end
                        if dialogConfig.buttons.cancel then return "cancel" end
                        for key, _ in pairs(dialogConfig.buttons) do
                            return key
                        end
                    end
                    return "Okay"
                end
                return OriginalDialogFunc(self, dialogConfig, ...)
            end
        end

        local currentIndex = 1
        dropdownButton.MouseButton1Click:Connect(function()
            local names = GetPlayerNames()
            currentIndex = currentIndex + 1
            if currentIndex > #names then
                currentIndex = 1
            end
            local chosenName = names[currentIndex]
            SelectedTargetName = chosenName
            SelectedTarget = ResolvePlayer(chosenName)
            dropdownButton.Text = "Target: " .. chosenName
        end)

        local initialNames = GetPlayerNames()
        if initialNames[1] then
            SelectedTargetName = initialNames[1]
            SelectedTarget = ResolvePlayer(initialNames[1])
            dropdownButton.Text = "Target: " .. initialNames[1]
        end

        teleportButton.MouseButton1Click:Connect(function()
            SelectedTarget = ResolvePlayer(SelectedTargetName)
            if SelectedTarget then
                returnToHouse(SelectedTarget)
            end
        end)

        modeButton.MouseButton1Click:Connect(function()
            if SelectedMode == "Mannequin" then
                SelectedMode = "SetOnSale"
                modeButton.Text = "Mannequin Mode: Set On Sale ($100)"
                modeButton.BackgroundColor3 = Color3.fromRGB(180, 100, 50)
            elseif SelectedMode == "SetOnSale" then
                SelectedMode = "SetOffSale"
                modeButton.Text = "Mannequin Mode: Set Off Sale"
                modeButton.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
            else
                SelectedMode = "Mannequin"
                modeButton.Text = "Mannequin Mode: Transfer"
                modeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            end
        end)

        mannequinsToggleBtn.MouseButton1Click:Connect(function()
            AutoMannequinsRunning = not AutoMannequinsRunning
            if AutoMannequinsRunning then
                mannequinsToggleBtn.Text = "Auto Mannequins: ON"
                mannequinsToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            else
                mannequinsToggleBtn.Text = "Auto Mannequins: OFF"
                mannequinsToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            end
        end)

        registersToggleBtn.MouseButton1Click:Connect(function()
            AutoRegistersRunning = not AutoRegistersRunning
            if AutoRegistersRunning then
                registersToggleBtn.Text = "Auto Register: ON"
                registersToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            else
                registersToggleBtn.Text = "Auto Register: OFF"
                registersToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            end
        end)

        closeButton.MouseButton1Click:Connect(function()
            AutoMannequinsRunning = false
            AutoRegistersRunning = false
            if antiAfkConnection then
                antiAfkConnection:Disconnect()
                antiAfkConnection = nil
            end
            if DialogApp and OriginalDialogFunc then
                DialogApp.dialog = OriginalDialogFunc
            end
            screenGui:Destroy()
        end)

        task.spawn(function()
            while screenGui.Parent do
                pcall(function()
                    local regList = GetRegisterList()
                    local outfitList = GetOutfitVersionList()

                    if not LastInterceptedMsg then
                        statusLabel.Text = string.format("Target: %s (Anti-AFK: ON)\nRegisters: %d | Outfits: %d", 
                            tostring(SelectedTargetName or "None"), 
                            math.max(0, #regList - 1), 
                            math.max(0, #outfitList - 1)
                        )
                    end
                end)
                task.wait(2)
            end
        end)

        local isFusing = false
        local function processSequentialFusions(mode)
            if isFusing then return end
            pcall(function()
                if not ClientData or type(ClientData.get_data) ~= "function" then return end
                local data = ClientData.get_data()
                if not data or not data[localPlayer.Name] then return end
                
                local inventoryData = data[localPlayer.Name].inventory
                local inventory = inventoryData and inventoryData.pets
                if not inventory then return end

                local speciesGroups = {}
                local fusionQueue = {}

                for uId, petData in pairs(inventory) do
                    local sId = petData.id 
                    local p = petData.properties or {}
                    local age = p.age or petData.age
                    local isNeon = p.neon or petData.neon or false
                    
                    local valid = false
                    if mode == "Neon" then
                        if (tostring(age) == "6" or age == 6) and not isNeon then 
                            valid = true 
                        end
                    elseif mode == "Mega" then
                        if isNeon and (tostring(age) == "6" or age == 6) then 
                            valid = true 
                        end
                    end

                    if valid then
                        if not speciesGroups[sId] then 
                            speciesGroups[sId] = {} 
                        end
                        table.insert(speciesGroups[sId], uId)
                    end
                end

                for sId, ids in pairs(speciesGroups) do
                    while #ids >= 4 do
                        local set = {ids[1], ids[2], ids[3], ids[4]}
                        table.insert(fusionQueue, {name = sId, list = set})
                        for _ = 1, 4 do 
                            table.remove(ids, 1) 
                        end
                    end
                end

                if #fusionQueue > 0 then
                    isFusing = true
                    task.spawn(function()
                        for i = 1, #fusionQueue do
                            local current = fusionQueue[i]
                            pcall(function()
                                RouterClient.get("PetAPI/DoNeonFusion"):InvokeServer(current.list)
                            end)
                            task.wait(1.5)
                        end
                        isFusing = false
                    end)
                end
            end)
        end

        local AutoRunningHeavy = false
        heavyButton.MouseButton1Click:Connect(function()
            AutoRunningHeavy = not AutoRunningHeavy
            if AutoRunningHeavy then
                heavyButton.Text = "Stop Auto Heavy-Lift"
                heavyButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            else
                heavyButton.Text = "Start Auto Heavy-Lift"
                heavyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 127)
            end
        end)

        -- Background Worker Loop: Auto Mannequins
        task.spawn(function()
            while screenGui.Parent do
                task.wait(2.5)
                if AutoMannequinsRunning then
                    pcall(function()
                        local targetPlayer = ResolvePlayer(SelectedTargetName)
                        if not targetPlayer then return end

                        if SelectedMode == "Mannequin" then
                            if FurnitureMannequinsHelper then
                                local mannequins = FurnitureMannequinsHelper.get_mannequins() or {}
                                for _, m in pairs(mannequins) do
                                    pcall(function()
                                        local parentObj = m.Parent
                                        local furnId = parentObj and parentObj:GetAttribute("furniture_unique")
                                        local version = tostring(m:GetAttribute("outfit_version"))
                                        
                                        if furnId and version and version ~= "nil" and version ~= "" then
                                            local existingSlotKey = FindOwnedOutfitKey(version)
                                            if existingSlotKey then
                                                print("[Notice]: Clearing Outfit...")
                                                print("[Notice]: Removing Outfit...")
                                                
                                                pcall(function()
                                                    RouterClient.get("AvatarAPI/DeleteOutfit"):FireServer("player", "Outfit")
                                                end)

                                                local timeout = 0
                                                while FindOwnedOutfitKey(version) and timeout < 20 do
                                                    task.wait(0.1)
                                                    timeout = timeout + 1
                                                end
                                            end

                                            RouterClient.get("AvatarAPI/BuyMannequinOutfit"):InvokeServer(targetPlayer, tostring(furnId), version, 100)
                                        end
                                    end)
                                end
                            end
                        elseif SelectedMode == "SetOnSale" then
                            if FurnitureMannequinsHelper then
                                local mannequins = FurnitureMannequinsHelper.get_mannequins() or {}
                                for _, m in pairs(mannequins) do
                                    pcall(function()
                                        local parentObj = m.Parent
                                        local furnId = parentObj and parentObj:GetAttribute("furniture_unique")
                                        if furnId then
                                            RouterClient.get("HousingAPI/ActivateFurniture"):InvokeServer(
                                                targetPlayer,
                                                furnId,
                                                "UseBlock",
                                                {
                                                    ["price"] = 100,
                                                    ["set_price"] = true
                                                },
                                                localPlayer.Character
                                            )
                                        end
                                    end)
                                end
                            end
                        elseif SelectedMode == "SetOffSale" then
                            if FurnitureMannequinsHelper then
                                local mannequins = FurnitureMannequinsHelper.get_mannequins() or {}
                                for _, m in pairs(mannequins) do
                                    pcall(function()
                                        local parentObj = m.Parent
                                        local furnId = parentObj and parentObj:GetAttribute("furniture_unique")
                                        if furnId then
                                            RouterClient.get("HousingAPI/ActivateFurniture"):InvokeServer(
                                                targetPlayer,
                                                furnId,
                                                "UseBlock",
                                                {
                                                    ["set_off_sale"] = true
                                                },
                                                localPlayer.Character
                                            )
                                        end
                                    end)
                                end
                            end
                        end
                    end)
                end
            end
        end)

        -- Background Worker Loop: Auto Registers (Independent Toggle)
        task.spawn(function()
            while screenGui.Parent do
                task.wait(2.5)
                if AutoRegistersRunning then
                    pcall(function()
                        local targetPlayer = ResolvePlayer(SelectedTargetName)
                        if not targetPlayer then return end

                        local regList = GetRegisterList()
                        for i = 2, #regList do
                            local parts = regList[i]:split(" | ")
                            local regId = parts[1]
                            local char = localPlayer.Character
                            if regId and char then
                                RouterClient.get("HousingAPI/ActivateFurniture"):InvokeServer(targetPlayer, regId, "UseBlock", PayAmountValue, char)
                            end
                        end
                    end)
                end
            end
        end)

        -- Background Worker Loop: Fusions
        task.spawn(function()
            while screenGui.Parent do
                task.wait(5)
                if AutoRunningHeavy then
                    processSequentialFusions("Neon")
                    processSequentialFusions("Mega")
                end
            end
        end)
    end)
end)
