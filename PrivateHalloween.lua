print("WORKS")

-----------------------------------------------------------
-- ULTIMATE ADOPT ME! AUTOMATION & TELEPORT HUB (v2.7 STRICT 1-AT-A-TIME)
-----------------------------------------------------------
task.spawn(function()
    pcall(function()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Workspace = game:GetService("Workspace")
        local RunService = game:GetService("RunService")
        local VirtualUser = game:GetService("VirtualUser")
        local StarterGui = game:GetService("StarterGui")
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")

        -- Anti-AFK Connection
        local antiAfkConnection = LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
            end)
        end)

        -- --- REQUIRED MODULES ---
        local Fsys = nil
        while not Fsys do
            local success, result = pcall(function()
                return ReplicatedStorage:WaitForChild("Fsys", 2)
            end)
            if success and result then
                local reqSuccess, reqModule = pcall(function() return require(result) end)
                if reqSuccess and reqModule then Fsys = reqModule end
            end
            if not Fsys then task.wait(1) end
        end

        local ClientData, Router, StateManager, AilmentsManager, PetEntityManager = nil, nil, nil, nil, nil
        while not (ClientData and Router and AilmentsManager) do
            pcall(function()
                if Fsys and Fsys.load then
                    ClientData = ClientData or Fsys.load("ClientData")
                    Router = Router or Fsys.load("RouterClient")
                    StateManager = StateManager or Fsys.load("StateManagerClient")
                    AilmentsManager = AilmentsManager or Fsys.load("new:AilmentsClient")
                    
                    local successPetEnt, petEntMod = pcall(function() return Fsys.load("PetEntityManager") end)
                    if successPetEnt and petEntMod then
                        PetEntityManager = petEntMod
                    end
                end
            end)
            if not (ClientData and Router and AilmentsManager) then task.wait(1) end
        end

        -- --- STATE & 1-AT-A-TIME VARIABLES ---
        local ScriptEnabled = true
        local AutoAilmentsRunning = false
        local AutoMannequinsRunning = false
        local AutoRegistersRunning = false
        
        local IsProcessing = false
        local CurrentTask = nil
        local SelectedPetUniqueId = nil

        local SelectedTargetName = LocalPlayer.Name
        local SelectedTarget = LocalPlayer
        local SelectedMode = "Mannequin"
        local PayAmountValue = 50
        local LastInterceptedMsg = nil

        -- --- HELPER FUNCTIONS ---
        local function getAilmentIdFromInstance(ailmentInstance)
            if not ailmentInstance or type(ailmentInstance) ~= "table" then
                return "UNKNOWN_INSTANCE"
            end
            if ailmentInstance.kind then
                return tostring(ailmentInstance.kind)
            end
            return "UNKNOWN_AILMENT_NAME_FALLBACK"
        end

        local function getInventoryCategory(categoryName)
            local success, result = pcall(function()
                if ClientData and ClientData.get then
                    local inv = ClientData.get("inventory")
                    if inv and inv[categoryName] then
                        return inv[categoryName]
                    end
                end
            end)
            return success and result or {}
        end

        local function getEntityDisplayInfo(entityRef)
            if not entityRef then return "Unknown Entity", "N/A" end
            if not entityRef.is_pet then
                return LocalPlayer.Name .. "'s Baby", tostring(LocalPlayer.UserId)
            else
                local pets = getInventoryCategory("pets")
                if pets and pets[entityRef.pet_unique] then
                    return tostring(pets[entityRef.pet_unique].id or pets[entityRef.pet_unique].kind), tostring(entityRef.pet_unique)
                end
                return "Pet (Unknown Name)", tostring(entityRef.pet_unique)
            end
        end

        local function createEntityReference(player, isPet, petUniqueId)
            return {
                player = player,
                is_pet = isPet,
                pet_unique = petUniqueId
            }
        end

        local function ResolvePlayer(targetName)
            if not targetName or targetName == "None" or targetName == "Loading..." or targetName == "No Players Found" then 
                return LocalPlayer 
            end
            local target = Players:FindFirstChild(targetName)
            if target then return target end
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower() == targetName:lower() or p.DisplayName:lower() == targetName:lower() then
                    return p
                end
            end
            return LocalPlayer
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

        local function FindOwnedOutfitKey(versionToCheck)
            local foundKey = nil
            pcall(function()
                if not ClientData or type(ClientData.get) ~= "function" then return end
                local data = ClientData.get("outfits")
                if data then
                    for slotKey, outfitData in pairs(data) do
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
                    local DynamicLocationDB = require(ReplicatedStorage.ClientDB.DynamicLocationDB)
                    if DynamicLocationDB and DynamicLocationDB.housing then
                        DynamicLocationDB.housing.dynamic_location({
                            house_owner = targetOwner or LocalPlayer,
                            destination_door_id = "MainDoor"
                        })
                    end

                    local ClientStore = Fsys.load("ClientStore")
                    if ClientStore and ClientStore.store then
                        ClientStore.store:dispatch({
                            ["type"] = "set_house_edit_mode",
                            ["value"] = "Disabled"
                        })
                    end
                    
                    local UIManager = Fsys.load("UIManager")
                    if UIManager and UIManager.apps and UIManager.apps.HouseEditorWrapperApp then
                        UIManager.apps.HouseEditorWrapperApp:clear_drawer()
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
                local FurnitureMannequinsHelper = Fsys.load("FurnitureMannequinsHelper")
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

        -- --- FURNITURE AUTOMATION MAPPING ---
        local UserFurniture = {
            dirty = { "ModernShower", "CheapPetBathtub", "Shower", "PowerWash", "CampingShower" },
            sleepy = { "ThreeFurn2025ComfyPetBed" },
            thirsty = { "ModernPetBowls", block = "UseBlock2" },
            hungry = { "ModernPetBowls", block = "UseBlock" },
            toilet = { "Toilet" },
            bored = { "Piano" }
        }

        local function isPetUsingFurniture(petModel)
            if not petModel or typeof(petModel) ~= "Instance" then return false end
            local stateData = StateManager and StateManager.get(petModel)
            if stateData and stateData.states then
                for _, state in pairs(stateData.states or {}) do
                    if type(state) == "table" and state.furniture_id then return true end
                end
            end
            return false
        end

        local function getPetModel(pUid)
            local petModel = nil
            pcall(function()
                if PetEntityManager and type(PetEntityManager.get_pet_model) == "function" then
                    petModel = PetEntityManager.get_pet_model(pUid)
                    if petModel then return end
                end

                local pets = getInventoryCategory("pets")
                local kind = nil
                if pUid and pets[pUid] and (pets[pUid].id or pets[pUid].kind) then
                    kind = pets[pUid].id or pets[pUid].kind
                end

                if kind then
                    for _, m in ipairs(Workspace.Pets:GetChildren()) do
                        if m.Name:lower() == kind:lower():gsub("_", " ") or m.Name == kind then 
                            petModel = m 
                            break 
                        end
                    end
                end
                
                if not petModel then
                    for _, m in ipairs(Workspace.Pets:GetChildren()) do
                        if m:IsA("Model") then
                            petModel = m
                            break
                        end
                    end
                end
            end)
            return petModel or Workspace.Pets:FindFirstChildOfClass("Model")
        end

        -- --- 1-AT-A-TIME EXECUTION LOGIC ---
        local function executeTaskLogic(aid, entityRef)
            local furnitureNames = UserFurniture[aid]
            if not furnitureNames or not entityRef.is_pet then 
                IsProcessing = false
                CurrentTask = nil
                return 
            end

            CurrentTask = aid
            SelectedPetUniqueId = entityRef.pet_unique
            local specificBlock = furnitureNames.block

            print(string.format("[Step 2] Executing task for ailment: %s on pet: %s", aid, tostring(entityRef.pet_unique)))

            task.spawn(function()
                local startTime = tick()
                while ScriptEnabled and AutoAilmentsRunning and IsProcessing do
                    if tick() - startTime > 150 then 
                        print("[Step 2] Task timed out:", aid)
                        break 
                    end

                    -- Check if ailment was already fulfilled/cleared
                    local ailments = AilmentsManager.get_ailments_for_pet(entityRef)
                    local stillActive = false
                    if ailments then
                        for _, inst in pairs(ailments) do
                            if getAilmentIdFromInstance(inst) == aid then
                                stillActive = true
                                break
                            end
                        end
                    end
                    if not stillActive then break end

                    local currentPetModel = getPetModel(entityRef.pet_unique)
                    if currentPetModel and currentPetModel.PrimaryPart then
                        if not isPetUsingFurniture(currentPetModel) then
                            local furnitureFolder = Workspace:FindFirstChild("HouseInteriors") and Workspace.HouseInteriors:FindFirstChild("furniture")
                            if furnitureFolder then
                                local activated = false
                                for _, container in ipairs(furnitureFolder:GetChildren()) do
                                    for _, fName in ipairs(furnitureNames) do
                                        if type(fName) == "string" then
                                            local model = container:FindFirstChild(fName)
                                            if model then
                                                local fId = string.match(container.Name, "f%-%w+") or container.Name
                                                local useBlocks = model:FindFirstChild("UseBlocks")
                                                local inter = useBlocks and (
                                                    (specificBlock and useBlocks:FindFirstChild(specificBlock))
                                                    or useBlocks:FindFirstChild("Seat1")
                                                    or useBlocks:FindFirstChildOfClass("Part")
                                                )
                                                
                                                if inter and Router then
                                                    print(string.format("[Step 2 Action] Activating furniture (%s) for ailment: %s", fName, aid))
                                                    local args = { LocalPlayer, fId, inter.Name, {cframe = inter:GetPivot()}, currentPetModel }
                                                    Router.get("HousingAPI/ActivateFurniture"):InvokeServer(unpack(args))
                                                    activated = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    if activated then break end
                                end
                            end
                        end
                    end
                    task.wait(3)
                end

                -- Safety release if signal hasn't fired yet
                if CurrentTask == aid then
                    IsProcessing = false
                    CurrentTask = nil
                end
            end)
        end

        local function handleAilmentCreation(ailmentInstance, entityUniqueKey)
            if not AutoAilmentsRunning then return end

            -- Step 1: The Trigger & State Lock Check
            if IsProcessing then
                return -- Already busy executing a task, ignore new triggers until unlocked
            end

            IsProcessing = true
            local isPet = string.len(tostring(entityUniqueKey)) > 10
            local entityRef = createEntityReference(LocalPlayer, isPet, entityUniqueKey)
            local aid = getAilmentIdFromInstance(ailmentInstance)

            print(string.format("[Step 1] Trigger locked. Processing ailment: %s", aid))
            executeTaskLogic(aid, entityRef)
        end

        local function handleAilmentCompletion(ailmentInstance, entityUniqueKey, completionReason)
            local aid = getAilmentIdFromInstance(ailmentInstance)
            local isPet = string.len(tostring(entityUniqueKey)) > 10
            local entityRef = createEntityReference(LocalPlayer, isPet, entityUniqueKey)
            local entityDisplayName, entityUniqueIdForDisplay = getEntityDisplayInfo(entityRef)

            print(string.format("[Step 3] Ailment COMPLETED for %s ('%s'): '%s' (Reason: %s)",
                entityDisplayName,
                entityUniqueIdForDisplay,
                aid,
                tostring(completionReason)
            ))

            -- Step 3: Unlock processor so the next ailment can be picked up
            if CurrentTask == aid or IsProcessing then
                IsProcessing = false
                CurrentTask = nil
                print("[Step 3] Processor unlocked. Ready for next ailment.")
            end
        end

        -- Connect signals
        pcall(function()
            AilmentsManager.get_ailment_created_signal():Connect(handleAilmentCreation)
            AilmentsManager.get_ailment_completed_signal():Connect(handleAilmentCompletion)
        end)

        -- Fallback polling loop to catch un-triggered existing ailments if toggled on mid-game
        task.spawn(function()
            while ScriptEnabled do
                if AutoAilmentsRunning and not IsProcessing then
                    pcall(function()
                        local myInventory = getInventoryCategory("pets")
                        if myInventory then
                            for petUniqueId, _ in pairs(myInventory) do
                                local petEntityRef = createEntityReference(LocalPlayer, true, petUniqueId)
                                local petAilments = AilmentsManager.get_ailments_for_pet(petEntityRef)
                                if petAilments then
                                    for _, ailmentInstance in pairs(petAilments) do
                                        if not IsProcessing then
                                            handleAilmentCreation(ailmentInstance, petUniqueId)
                                            break
                                        end
                                    end
                                end
                                if IsProcessing then break end
                            end
                        end
                    end)
                end
                task.wait(2)
            end
        end)

        -- --- USER INTERFACE (GUI) ---
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "UltimateAdoptMeHub"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui

        local mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, 310, 0, 495)
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
        title.Text = "Ultimate Hub (v2.7)"
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
        statusLabel.Size = UDim2.new(0.9, 0, 0, 55)
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
        teleportButton.Position = UDim2.new(0.05, 0, 0, 170)
        teleportButton.BackgroundColor3 = Color3.fromRGB(50, 120, 180)
        teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        teleportButton.Font = Enum.Font.SourceSansBold
        teleportButton.TextSize = 13
        teleportButton.Text = "Teleport to Target House"
        teleportButton.Parent = mainFrame

        local tpCorner = Instance.new("UICorner")
        tpCorner.CornerRadius = UDim.new(0, 6)
        tpCorner.Parent = teleportButton

        local consoleButton = Instance.new("TextButton")
        consoleButton.Size = UDim2.new(0.9, 0, 0, 30)
        consoleButton.Position = UDim2.new(0.05, 0, 0, 205)
        consoleButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        consoleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        consoleButton.Font = Enum.Font.SourceSansBold
        consoleButton.TextSize = 13
        consoleButton.Text = "Open Roblox Console"
        consoleButton.Parent = mainFrame

        local consoleCorner = Instance.new("UICorner")
        consoleCorner.CornerRadius = UDim.new(0, 6)
        consoleCorner.Parent = consoleButton

        local mannequinsToggleBtn = Instance.new("TextButton")
        mannequinsToggleBtn.Size = UDim2.new(0.9, 0, 0, 30)
        mannequinsToggleBtn.Position = UDim2.new(0.05, 0, 0, 240)
        mannequinsToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        mannequinsToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        mannequinsToggleBtn.Font = Enum.Font.SourceSansBold
        mannequinsToggleBtn.TextSize = 13
        mannequinsToggleBtn.Text = "Auto Mannequins: OFF"
        mannequinsToggleBtn.Parent = mainFrame

        local manCorner = Instance.new("UICorner")
        manCorner.CornerRadius = UDim.new(0, 6)
        manCorner.Parent = mannequinsToggleBtn

        local registersToggleBtn = Instance.new("TextButton")
        registersToggleBtn.Size = UDim2.new(0.9, 0, 0, 30)
        registersToggleBtn.Position = UDim2.new(0.05, 0, 0, 275)
        registersToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        registersToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        registersToggleBtn.Font = Enum.Font.SourceSansBold
        registersToggleBtn.TextSize = 13
        registersToggleBtn.Text = "Auto Register: OFF"
        registersToggleBtn.Parent = mainFrame

        local regCorner = Instance.new("UICorner")
        regCorner.CornerRadius = UDim.new(0, 6)
        regCorner.Parent = registersToggleBtn

        local ailmentsToggleBtn = Instance.new("TextButton")
        ailmentsToggleBtn.Size = UDim2.new(0.9, 0, 0, 30)
        ailmentsToggleBtn.Position = UDim2.new(0.05, 0, 0, 310)
        ailmentsToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        ailmentsToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ailmentsToggleBtn.Font = Enum.Font.SourceSansBold
        ailmentsToggleBtn.TextSize = 13
        ailmentsToggleBtn.Text = "Auto Ailments: OFF"
        ailmentsToggleBtn.Parent = mainFrame

        local ailCorner = Instance.new("UICorner")
        ailCorner.CornerRadius = UDim.new(0, 6)
        ailCorner.Parent = ailmentsToggleBtn

        local heavyButton = Instance.new("TextButton")
        heavyButton.Size = UDim2.new(0.9, 0, 0, 38)
        heavyButton.Position = UDim2.new(0.05, 0, 0, 345)
        heavyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 127)
        heavyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        heavyButton.Font = Enum.Font.SourceSansBold
        heavyButton.TextSize = 13
        heavyButton.Text = "Start Auto Heavy-Lift"
        heavyButton.Parent = mainFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = heavyButton

        -- --- DIALOG INTERCEPTOR ---
        local UIManager = Fsys.load("UIManager")
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
            if currentIndex > #names then currentIndex = 1 end
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
            if SelectedTarget then returnToHouse(SelectedTarget) end
        end)

        consoleButton.MouseButton1Click:Connect(function()
            pcall(function()
                StarterGui:SetCore("DevConsoleVisible", true)
            end)
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

        ailmentsToggleBtn.MouseButton1Click:Connect(function()
            AutoAilmentsRunning = not AutoAilmentsRunning
            if AutoAilmentsRunning then
                ailmentsToggleBtn.Text = "Auto Ailments: ON"
                ailmentsToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                print("[Hub] Auto Ailments turned ON (1-at-a-time mode active).")
            else
                ailmentsToggleBtn.Text = "Auto Ailments: OFF"
                ailmentsToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                IsProcessing = false
                CurrentTask = nil
                print("[Hub] Auto Ailments turned OFF.")
            end
        end)

        closeButton.MouseButton1Click:Connect(function()
            AutoMannequinsRunning = false
            AutoRegistersRunning = false
            AutoAilmentsRunning = false
            ScriptEnabled = false
            if antiAfkConnection then
                antiAfkConnection:Disconnect()
                antiAfkConnection = nil
            end
            if DialogApp and OriginalDialogFunc then
                DialogApp.dialog = OriginalDialogFunc
            end
            screenGui:Destroy()
        end)

        -- Status Loop
        task.spawn(function()
            while screenGui.Parent do
                pcall(function()
                    local regList = GetRegisterList()
                    local outfitList = GetOutfitVersionList()

                    if not LastInterceptedMsg then
                        local taskStatus = IsProcessing and ("Processing: " .. tostring(CurrentTask)) or "Idle (Ready)"
                        statusLabel.Text = string.format("Target: %s (v2.7)\n%s", 
                            tostring(SelectedTargetName or "None"), 
                            taskStatus
                        )
                    end
                end)
                task.wait(1)
            end
        end)

        local isFusing = false
        local function processSequentialFusions(mode)
            if isFusing then return end
            pcall(function()
                if not ClientData or type(ClientData.get) ~= "function" then return end
                local inventory = ClientData.get("inventory")
                local petsInventory = inventory and inventory.pets
                if not petsInventory then return end

                local speciesGroups = {}
                local fusionQueue = {}

                for uId, petData in pairs(petsInventory) do
                    local sId = petData.id 
                    local p = petData.properties or {}
                    local age = p.age or petData.age
                    local isNeon = p.neon or petData.neon or false
                    
                    local valid = false
                    if mode == "Neon" then
                        if (tostring(age) == "6" or age == 6) and not isNeon then valid = true end
                    elseif mode == "Mega" then
                        if isNeon and (tostring(age) == "6" or age == 6) then valid = true end
                    end

                    if valid then
                        if not speciesGroups[sId] then speciesGroups[sId] = {} end
                        table.insert(speciesGroups[sId], uId)
                    end
                end

                for sId, ids in pairs(speciesGroups) do
                    while #ids >= 4 do
                        local set = {ids[1], ids[2], ids[3], ids[4]}
                        table.insert(fusionQueue, {name = sId, list = set})
                        for _ = 1, 4 do table.remove(ids, 1) end
                    end
                end

                if #fusionQueue > 0 then
                    isFusing = true
                    task.spawn(function()
                        for i = 1, #fusionQueue do
                            local current = fusionQueue[i]
                            pcall(function()
                                Router.get("PetAPI/DoNeonFusion"):InvokeServer(current.list)
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

        -- Background Worker Loops: Mannequins, Registers, Fusions
        task.spawn(function()
            while screenGui.Parent do
                task.wait(2.5)
                if AutoMannequinsRunning then
                    pcall(function()
                        local targetPlayer = ResolvePlayer(SelectedTargetName)
                        if not targetPlayer then return end

                        local FurnitureMannequinsHelper = Fsys.load("FurnitureMannequinsHelper")
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
                                                pcall(function()
                                                    Router.get("AvatarAPI/DeleteOutfit"):FireServer("player", "Outfit")
                                                end)

                                                local timeout = 0
                                                while FindOwnedOutfitKey(version) and timeout < 20 do
                                                    task.wait(0.1)
                                                    timeout = timeout + 1
                                                end
                                            end

                                            Router.get("AvatarAPI/BuyMannequinOutfit"):InvokeServer(targetPlayer, tostring(furnId), version, 100)
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
                                            Router.get("HousingAPI/ActivateFurniture"):InvokeServer(
                                                targetPlayer, furnId, "UseBlock",
                                                { ["price"] = 100, ["set_price"] = true },
                                                LocalPlayer.Character
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
                                            Router.get("HousingAPI/ActivateFurniture"):InvokeServer(
                                                targetPlayer, furnId, "UseBlock",
                                                { ["set_off_sale"] = true },
                                                LocalPlayer.Character
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
                            local char = LocalPlayer.Character
                            if regId and char then
                                Router.get("HousingAPI/ActivateFurniture"):InvokeServer(targetPlayer, regId, "UseBlock", PayAmountValue, char)
                            end
                        end
                    end)
                end
            end
        end)

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
