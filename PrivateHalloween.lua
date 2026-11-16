if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

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
while not (ClientData and Router) do
    pcall(function()
        if Fsys and Fsys.load then
            ClientData = ClientData or Fsys.load("ClientData")
            Router = Router or Fsys.load("RouterClient")
            StateManager = Fsys.load("StateManagerClient")
            AilmentsManager = AilmentsManager or Fsys.load("new:AilmentsClient")
            
            local successPetEnt, petEntMod = pcall(function() return Fsys.load("PetEntityManager") end)
            if successPetEnt and petEntMod then
                PetEntityManager = petEntMod
            end
        end
    end)
    if not (ClientData and Router) then task.wait(1) end
end

-- --- DATA STORAGE & TOGGLES ---
local activeAilmentUIs = {}
local impendingAilmentUIs = {}
local runningTasks = {}
local SelectedPetUniqueId = nil
local CurrentTask = nil
local ScriptEnabled = true

local AutoAilmentsRunning = false
local AutoMannequinsRunning = false
local AutoRegistersRunning = false
local AutoHeavyLiftRunning = false
local SelectedMode = "Mannequin"
local SelectedTargetName = LocalPlayer.Name
local SelectedTarget = LocalPlayer
local LastInterceptedMsg = nil

-- --- HELPER FUNCTIONS ---

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

local function getAilmentIdFromInstance(ailmentInstance)
    if not ailmentInstance then
        return "unknown_instance"
    end
    if type(ailmentInstance) == "string" then
        return ailmentInstance:lower()
    end
    if type(ailmentInstance) == "table" then
        local kind = ailmentInstance.kind or ailmentInstance.id or ""
        return tostring(kind):lower()
    end
    return tostring(ailmentInstance):lower()
end

local function formatAilmentDetails(ailmentInstance)
    local details = {}
    if ailmentInstance and type(ailmentInstance) == "table" then
        if type(ailmentInstance.get_progress) == "function" then
            table.insert(details, "Progress: " .. string.format("%.2f", ailmentInstance:get_progress()))
        elseif ailmentInstance.progress then
            table.insert(details, "Progress: " .. string.format("%.2f", ailmentInstance.progress))
        end
    end
    if #details > 0 then
        return " (" .. table.concat(details, ", ") .. ")"
    else
        return ""
    end
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

local function formatTimeRemaining(seconds)
    if not seconds or seconds < 0 then return "N/A" end
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    if minutes > 0 then
        return string.format("%dm %02ds", minutes, remainingSeconds)
    else
        return string.format("%ds", remainingSeconds)
    end
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

-- --- DYNAMIC BLUEPRINT HOUSE OWNER RESOLVER ---
local function getLoadedHouseOwner()
    local ownerPlayer = LocalPlayer
    pcall(function()
        local blueprintFolder = Workspace:FindFirstChild("HouseInteriors") and Workspace.HouseInteriors:FindFirstChild("blueprint")
        if blueprintFolder then
            for _, child in ipairs(blueprintFolder:GetChildren()) do
                if child:IsA("Model") or child:IsA("Folder") then
                    local foundPlayer = Players:FindFirstChild(child.Name)
                    if foundPlayer then
                        ownerPlayer = foundPlayer
                        break
                    end
                end
            end
        end
    end)
    return ownerPlayer
end

-- --- USER INTERFACE (GUI) SETUP FIRST SO STATUSLABEL EXISTS ---
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
title.Text = "Ultimate Hub (v5.3 Activation Force Fix)"
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
statusLabel.Text = "Hub active and ready."
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
heavyButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
heavyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
heavyButton.Font = Enum.Font.SourceSansBold
heavyButton.TextSize = 13
heavyButton.Text = "Start Auto Heavy-Lift: OFF"
heavyButton.Parent = mainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = heavyButton

-- --- DIALOG INTERCEPTOR HOOK (YOUR EXACT REQUESTED LOGIC) ---
task.spawn(function()
    pcall(function()
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
    end)
end)

-- --- FURNITURE AUTOMATION LOGIC ---

local UserFurniture = {
    dirty = { "CheapPetBathtub", "Shower", "PowerWash", "CampingShower" },
    sleepy = { "ThreeFurn2025ComfyPetBed", "ThreeFurn2025BigComfyBed", "ThreeFurn2025ComfyBed" },
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

-- ROBUST PET MODEL RESOLUTION: Falls back safely without hard PrimaryPart checks
local function getPetModelForUnique(targetUid)
    local petModel = nil
    pcall(function()
        if PetEntityManager and PetEntityManager.get_pet_model then
            petModel = PetEntityManager.get_pet_model(targetUid)
        end
        
        if not petModel then
            local pets = getInventoryCategory("pets")
            local kind = nil
            if targetUid and pets[targetUid] and pets[targetUid].kind then
                kind = pets[targetUid].kind
            end

            if kind and Workspace:FindFirstChild("Pets") then
                for _, m in ipairs(Workspace.Pets:GetChildren()) do
                    if m.Name:lower() == kind:lower() or m.Name:lower() == kind:lower():gsub("_", " ") then
                        petModel = m 
                        break 
                    end
                end
            end
        end

        if not petModel and Workspace:FindFirstChild("Pets") then
            petModel = Workspace.Pets:FindFirstChildOfClass("Model")
        end
    end)
    return petModel
end

local function runFurnitureTask(hConfig, aid, entityRef, startTime)
    local furnitureNames = hConfig
    local specificBlock = hConfig and hConfig.block
    local taskKey = tostring(entityRef.pet_unique) .. "_" .. aid

    if not furnitureNames then return end

    while ScriptEnabled and AutoAilmentsRunning do
        if tick() - startTime > 160 then break end

        local uniqueKeyStr = tostring(entityRef.pet_unique)
        if not (activeAilmentUIs[uniqueKeyStr] and activeAilmentUIs[uniqueKeyStr][aid]) then
            break
        end

        local currentPetModel = getPetModelForUnique(entityRef.pet_unique)

        if currentPetModel and typeof(currentPetModel) == "Instance" then
            if not isPetUsingFurniture(currentPetModel) then
                local furnitureFolder = Workspace:FindFirstChild("HouseInteriors") and Workspace.HouseInteriors:FindFirstChild("furniture")
                if furnitureFolder then
                    local activated = false
                    for _, container in ipairs(furnitureFolder:GetChildren()) do
                        for _, fName in ipairs(furnitureNames) do
                            if type(fName) == "string" then
                                local model = container:FindFirstChild(fName, true)
                                if model then
                                    local fId = string.match(container.Name, "f%-%w+") or container.Name
                                    local useBlocks = model:FindFirstChild("UseBlocks", true) or model:FindFirstChild("UseBlocks")
                                    local inter = useBlocks and (
                                        (specificBlock and useBlocks:FindFirstChild(specificBlock, true))
                                        or useBlocks:FindFirstChild("Seat1", true)
                                        or useBlocks:FindFirstChild("UseBlock", true)
                                        or useBlocks:FindFirstChildOfClass("Part")
                                    )
                                    
                                    if inter and Router then
                                        local houseOwnerPlayer = getLoadedHouseOwner()
                                        print(string.format("[Activation Stage] Activating %s (ID: %s) for Pet %s", fName, tostring(fId), tostring(entityRef.pet_unique)))
                                        
                                        local pivotCFrame = pcall(function() return inter:GetPivot() end) and inter:GetPivot() or CFrame.new(0,0,0)
                                        local args = { houseOwnerPlayer, fId, inter.Name, {cframe = pivotCFrame}, currentPetModel }
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

    runningTasks[taskKey] = nil
end

-- --- CONSOLE TRACKING & TASK TRIGGERING ---

local function addAilmentToConsole(ailmentInstance, entityUniqueKey, entityRef)
    if not AutoAilmentsRunning then return end
    local ailmentId = getAilmentIdFromInstance(ailmentInstance)
    local entityDisplayName, entityUniqueIdForDisplay = getEntityDisplayInfo(entityRef)

    if not activeAilmentUIs[entityUniqueKey] then
        activeAilmentUIs[entityUniqueKey] = {}
    end

    if not activeAilmentUIs[entityUniqueKey][ailmentId] then
        activeAilmentUIs[entityUniqueKey][ailmentId] = {
            AilmentInstance = ailmentInstance,
            EntityRef = entityRef,
            StoredAilmentId = ailmentId
        }
        print(string.format("[Console Add] Active Ailment Added: %s | Details: %s (%s) - %s%s", ailmentId, entityDisplayName, entityUniqueIdForDisplay, ailmentId, formatAilmentDetails(ailmentInstance)))
    else
        activeAilmentUIs[entityUniqueKey][ailmentId].AilmentInstance = ailmentInstance
    end

    local hConfig = UserFurniture[ailmentId]
    local taskKey = tostring(entityRef.pet_unique) .. "_" .. ailmentId
    if hConfig and entityRef.is_pet and not runningTasks[taskKey] and AutoAilmentsRunning then
        runningTasks[taskKey] = true
        task.spawn(function()
            print(string.format("[Ailment Trigger] Queuing furniture task for %s on pet %s", ailmentId, entityUniqueKey))
            runFurnitureTask(hConfig, ailmentId, entityRef, tick())
        end)
    end
end

local function removeAilmentFromUI(ailmentInstance, entityUniqueKey, entityRef)
    local keyStr = tostring(entityUniqueKey)
    local keysToClear = {}
    
    if type(ailmentInstance) == "string" then
        table.insert(keysToClear, ailmentInstance:lower())
    elseif type(ailmentInstance) == "table" then
        table.insert(keysToClear, getAilmentIdFromInstance(ailmentInstance))
        if ailmentInstance.kind then table.insert(keysToClear, tostring(ailmentInstance.kind):lower()) end
        if ailmentInstance.id then table.insert(keysToClear, tostring(ailmentInstance.id):lower()) end
    end

    if activeAilmentUIs[keyStr] then
        if #keysToClear > 0 then
            for _, k in ipairs(keysToClear) do
                if activeAilmentUIs[keyStr][k] then
                    activeAilmentUIs[keyStr][k] = nil
                    print(string.format("[Ailment Cleared]: %s for Entity: %s", k, keyStr))
                end
            end
        else
            for aid, _ in pairs(activeAilmentUIs[keyStr]) do
                activeAilmentUIs[keyStr][aid] = nil
                print(string.format("[Ailment Cleared]: %s for Entity: %s", aid, keyStr))
            end
        end

        if next(activeAilmentUIs[keyStr]) == nil then
            activeAilmentUIs[keyStr] = nil
        end
    end

    if #keysToClear > 0 then
        for _, k in ipairs(keysToClear) do
            local taskKey = keyStr .. "_" .. k
            runningTasks[taskKey] = nil
        end
    else
        for tKey, _ in pairs(runningTasks) do
            if tKey:sub(1, #keyStr) == keyStr then
                runningTasks[tKey] = nil
            end
        end
    end

    if impendingAilmentUIs[keyStr] then
        for _, k in ipairs(keysToClear) do
            impendingAilmentUIs[keyStr][k] = nil
        end
        if next(impendingAilmentUIs[keyStr]) == nil then
            impendingAilmentUIs[keyStr] = nil
        end
    end
end

-- --- CONTINUOUS SCANNING LOOP & EVENT CONNECTIONS ---

local function scanActiveAilments()
    if not AutoAilmentsRunning then return end
    local currentPassKeys = {}

    local localPlayerKey = tostring(LocalPlayer.UserId)
    local localPlayerEntity = createEntityReference(LocalPlayer, false, nil)
    local localPlayerAilments = AilmentsManager.get_ailments_for_pet(localPlayerEntity)
    if localPlayerAilments then
        currentPassKeys[localPlayerKey] = {}
        for _, ailmentInstance in pairs(localPlayerAilments) do
            local aid = getAilmentIdFromInstance(ailmentInstance)
            currentPassKeys[localPlayerKey][aid] = true
            addAilmentToConsole(ailmentInstance, localPlayerKey, localPlayerEntity)
        end
    end

    local em = ClientData.get("equip_manager")
    local petsTable = em and em.pets or {}
    for _, petData in pairs(petsTable) do
        if type(petData) == "table" and petData.unique then
            local realUnique = tostring(petData.unique)
            local petEntityRef = createEntityReference(LocalPlayer, true, realUnique)
            local petAilments = AilmentsManager.get_ailments_for_pet(petEntityRef)
            if petAilments then
                currentPassKeys[realUnique] = {}
                for _, ailmentInstance in pairs(petAilments) do
                    local aid = getAilmentIdFromInstance(ailmentInstance)
                    currentPassKeys[realUnique][aid] = true
                    addAilmentToConsole(ailmentInstance, realUnique, petEntityRef)
                end
            end
        end
    end

    for entityKey, ailmentMap in pairs(activeAilmentUIs) do
        for aid, entry in pairs(ailmentMap) do
            if not (currentPassKeys[entityKey] and currentPassKeys[entityKey][aid]) then
                removeAilmentFromUI(entry.AilmentInstance, entityKey, entry.EntityRef)
            end
        end
    end
end

task.spawn(function()
    print("Ailments Manager Console: Script started.")
    task.wait(3)
    print("Ailments Manager Console: Starting continuous scanning loop.")
    while ScriptEnabled do
        if AutoAilmentsRunning then
            pcall(scanActiveAilments)
        end
        task.wait(2)
    end
end)

-- --- EVENT CONNECTIONS ---

pcall(function()
    AilmentsManager.get_ailment_created_signal():Connect(function(ailmentInstance, entityUniqueKey)
        if not AutoAilmentsRunning then return end
        local keyStr = tostring(entityUniqueKey)
        local isPet = string.len(keyStr) > 10
        local entityRef = createEntityReference(LocalPlayer, isPet, keyStr)
        addAilmentToConsole(ailmentInstance, keyStr, entityRef)
    end)
end)

pcall(function()
    AilmentsManager.get_ailment_completed_signal():Connect(function(ailmentInstance, entityUniqueKey, completionReason)
        local keyStr = tostring(entityUniqueKey)
        local isPet = string.len(keyStr) > 10
        local entityRef = createEntityReference(LocalPlayer, isPet, keyStr)
        removeAilmentFromUI(ailmentInstance, keyStr, entityRef)

        local entityDisplayName, entityUniqueIdForDisplay = getEntityDisplayInfo(entityRef)
        print(string.format("[Event] Ailment COMPLETED for %s ('%s'): '%s' (Reason: %s)",
            entityDisplayName,
            entityUniqueIdForDisplay,
            getAilmentIdFromInstance(ailmentInstance),
            tostring(completionReason)
        ))
    end)
end)

local lastUpdateTime = 0
local WARNING_THRESHOLD_SECONDS = 120

RunService.Heartbeat:Connect(function()
    if os.time() - lastUpdateTime < 1 then return end
    lastUpdateTime = os.time()

    for entityUniqueKey, ailmentMap in pairs(activeAilmentUIs) do
        for ailmentId, entry in pairs(ailmentMap) do
            local ailmentInstance = entry.AilmentInstance
            local entityRef = entry.EntityRef

            pcall(function()
                local rateFinishedTimestamp = ailmentInstance:get_rate_finished_timestamp()
                if rateFinishedTimestamp then
                    local timeLeftSeconds = rateFinishedTimestamp - workspace:GetServerTimeNow()
                    if timeLeftSeconds > 0 and timeLeftSeconds <= WARNING_THRESHOLD_SECONDS then
                        if not impendingAilmentUIs[entityUniqueKey] then
                            impendingAilmentUIs[entityUniqueKey] = {}
                        end

                        if not impendingAilmentUIs[entityUniqueKey][ailmentId] then
                            impendingAilmentUIs[entityUniqueKey][ailmentId] = true
                            local entityDisplayName, entityUniqueIdForDisplay = getEntityDisplayInfo(entityRef)
                            local warningText = ""
                            if entityRef.is_pet then
                                warningText = string.format("[Warning] %s (%s) - %s in %s", entityDisplayName, entityUniqueIdForDisplay, ailmentId, formatTimeRemaining(timeLeftSeconds))
                            else
                                warningText = string.format("[Warning] %s - %s in %s", entityDisplayName, ailmentId, formatTimeRemaining(timeLeftSeconds))
                            end
                            print(warningText)
                        end
                    end
                end
            end)
        end
    end
end)

-- --- UI CONNECTIONS ---
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
    pcall(function() StarterGui:SetCore("DevConsoleVisible", true) end)
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
    mannequinsToggleBtn.Text = AutoMannequinsRunning and "Auto Mannequins: ON" or "Auto Mannequins: OFF"
    mannequinsToggleBtn.BackgroundColor3 = AutoMannequinsRunning and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(70, 70, 70)
end)

registersToggleBtn.MouseButton1Click:Connect(function()
    AutoRegistersRunning = not AutoRegistersRunning
    registersToggleBtn.Text = AutoRegistersRunning and "Auto Register: ON" or "Auto Register: OFF"
    registersToggleBtn.BackgroundColor3 = AutoRegistersRunning and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(70, 70, 70)
end)

ailmentsToggleBtn.MouseButton1Click:Connect(function()
    AutoAilmentsRunning = not AutoAilmentsRunning
    ailmentsToggleBtn.Text = AutoAilmentsRunning and "Auto Ailments: ON" or "Auto Ailments: OFF"
    ailmentsToggleBtn.BackgroundColor3 = AutoAilmentsRunning and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(70, 70, 70)
    if not AutoAilmentsRunning then runningTasks = {} end
end)

heavyButton.MouseButton1Click:Connect(function()
    AutoHeavyLiftRunning = not AutoHeavyLiftRunning
    heavyButton.Text = AutoHeavyLiftRunning and "Start Auto Heavy-Lift: ON" or "Start Auto Heavy-Lift: OFF"
    heavyButton.BackgroundColor3 = AutoHeavyLiftRunning and Color3.fromRGB(0, 170, 127) or Color3.fromRGB(70, 70, 70)
end)

closeButton.MouseButton1Click:Connect(function()
    ScriptEnabled = false
    AutoAilmentsRunning = false
    AutoMannequinsRunning = false
    AutoRegistersRunning = false
    AutoHeavyLiftRunning = false
    screenGui:Destroy()
end)

-- --- BACKGROUND WORKER (MANNEQUINS) ---
task.spawn(function()
    while ScriptEnabled do
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
