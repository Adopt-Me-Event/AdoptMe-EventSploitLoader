print("LOADING")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local virtualUser = game:GetService("VirtualUser")
local workspace = game:GetService("Workspace")

local player = players.LocalPlayer or players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

getgenv().MasterAutoFarmerActive = true

getgenv().FarmerToggles = {
	LureActive = true,
	PetPenActive = true,
	CommitPenActive = true,
	BottlesActive = false,
	CauldronActive = false,
	SelectedBait = "cake"
}

local ToggleStates = {
	LureActive = true,
	PetPenActive = true,
	CommitPenActive = true,
	BottlesActive = false,
	CauldronActive = false,
}

local labels = {}
local tabPages = {}
local tabButtons = {}
local activeTab = "Status"
local hasEnteredDimension = false

local function scriptError(context, err)
	warn("[MasterAutoFarmer Error @ " .. tostring(context) .. "]: " .. tostring(err))
end

local function safeCall(context, func, ...)
	local success, result = pcall(func, ...)
	if not success then
		scriptError(context, result)
		return false, nil
	end
	return true, result
end

coroutine.wrap(function()
	safeCall("AntiAfk", function()
		player.Idled:Connect(function()
			if not getgenv().MasterAutoFarmerActive then return end
			safeCall("AntiAfkAction", function()
				virtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
				task.wait(1)
				virtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
			end)
		end)
	end)
end)()

local Fsys = nil
for i = 1, 10 do
	local ok, res = pcall(function()
		return require(replicatedStorage:WaitForChild("Fsys", 2))
	end)
	if ok and res then
		Fsys = res
		break
	end
	task.wait(1)
end

if not Fsys then
	scriptError("FrameworkLoader", "Fsys module could not be loaded!")
	return
end

local okCD, ClientDataModule = pcall(function() return Fsys.load("ClientData") end)
local okRC, RouterClient = pcall(function() return Fsys.load("RouterClient") end)
local okLoc, Location = pcall(function() return Fsys.load("Location") end)
local okFurn, FurnitureUniqueFinder = pcall(function() return Fsys.load("FurnitureUniqueFinder") end)
local okInteriors, InteriorsM = pcall(function() return Fsys.load("InteriorsM") end)
local UIManager = nil
pcall(function() UIManager = Fsys.load("UIManager") end)

local okDB, InventoryDB = pcall(function()
	return Fsys.load("InventoryDB")
end)

local LuresNet = nil
pcall(function()
	local modulesFolder = replicatedStorage:WaitForChild("new", 5) and replicatedStorage.new:WaitForChild("modules", 5)
	if modulesFolder then
		local luresFolder = modulesFolder:WaitForChild("Lures", 5)
		if luresFolder then
			local netModule = luresFolder:WaitForChild("LuresNet", 5)
			if netModule and netModule:IsA("ModuleScript") then
				LuresNet = require(netModule)
			end
		end
	end
end)

local gameFolder = replicatedStorage.SharedModules.ContentPacks.Slushie2026.Game
local SlushieMachineNet = require(gameFolder.SlushieMachineNet)
local SlushieRecipes = require(gameFolder.SlushieRecipes)

local CUP_KIND = "slushie_2026_cup"

local TIMING = {
	AFTER_BUY = 0.35,
	AFTER_PLACE = 0.4,
	BETWEEN_POURS = 0.35,
	BEFORE_TAKE = 0.4,
	TAKE_RETRY_DELAY = 0.35,
	CYCLE_COOLDOWN = 0.5
}

local COLOR_NAMES = {
	B = "Blue",
	G = "Green",
	O = "Orange",
	R = "Red"
}

local isRunning = false
local automationThread = nil
local recipeStatuses = {}
local recipeEntries = {}

local function getValidMixSequences()
	local sequences = {}
	if SlushieRecipes.MIX_ORDER and #SlushieRecipes.MIX_ORDER > 0 then
		for _, mixKey in ipairs(SlushieRecipes.MIX_ORDER) do
			local flavors = {}
			for i = 1, #mixKey do
				local letter = string.sub(mixKey, i, i)
				table.insert(flavors, COLOR_NAMES[letter] or letter)
			end
			
			local recipeInfo = (SlushieRecipes.RECIPES and SlushieRecipes.RECIPES[mixKey])
				or (SlushieRecipes.get and SlushieRecipes.get(mixKey))
			local displayName = typeof(recipeInfo) == "table" and (recipeInfo.name or recipeInfo.title or recipeInfo.kind) or mixKey

			table.insert(sequences, {
				mixKey = mixKey,
				flavors = flavors,
				displayName = displayName
			})
		end
	else
		table.insert(sequences, {
			mixKey = "BGOR",
			flavors = { "Blue", "Green", "Orange", "Red" },
			displayName = "Default Mix"
		})
	end
	return sequences
end

recipeEntries = getValidMixSequences()

local function fireRemote(remoteName, ...)
	local ok, remote = pcall(function()
		return RouterClient.get(remoteName)
	end)
	if ok and remote then
		remote:FireServer(...)
	end
end

local function invokeRemote(remote, data)
	local success, result = pcall(function()
		return if data ~= nil then remote:invoke_server_async(data) else remote:invoke_server_async()
	end)

	if not success then
		return false
	end

	if type(result) == "table" and type(result.await) == "function" then
		local ok, resolved = result:await()
		return ok, resolved
	end

	return true, result
end

local function updateRecipeStatus(index, statusText, color)
	local label = recipeStatuses[index]
	if label then
		label.Text = statusText
		label.TextColor3 = color
	end
end

local function safeTeleport(rootPart, targetCFrame)
	safeCall("SafeTeleport", function()
		if not rootPart or not rootPart.Parent then return end
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		rootPart.CFrame = targetCFrame
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)
end

local function teleportAndVerify()
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not rootPart then return false end

	local interiors = workspace:WaitForChild("Interiors", 15)
	local mainMapFolder = nil

	local startTime = tick()
	while not mainMapFolder and isRunning do
		for _, child in ipairs(interiors:GetChildren()) do
			if child.Name == "MainMap!Default" or child.Name:find("MainMap") then
				mainMapFolder = child
				break
			end
		end

		if not mainMapFolder then
			local destination = "MainMap"
			local subDestination = "MainDoor"

			fireRemote("AdoptAPI/SendPassiveDoorEnter", destination, subDestination, {})
			pcall(function()
				local locationObj = Location.new(destination, subDestination, {})
				if locationObj then
					fireRemote("LocationAPI/SetLocation", locationObj.destination_id, locationObj.house_owner, locationObj.sub_destination_id)
				else
					fireRemote("LocationAPI/SetLocation", destination, nil, subDestination)
				end
			end)

			if InteriorsM and type(InteriorsM.enter) == "function" then
				pcall(function()
					InteriorsM.enter(destination, subDestination, {})
				end)
			end
		end

		task.wait(0.5)
		if tick() - startTime > 25 then
			break
		end
	end

	if not mainMapFolder or not isRunning then return false end

	local blocker = mainMapFolder:WaitForChild("SlushieVehicleBlocker", 15)
	if not blocker or not isRunning then
		blocker = mainMapFolder:FindFirstChild("SlushieVehicleBlocker")
		if not blocker then return false end
	end

	pcall(function()
		safeTeleport(rootPart, blocker.CFrame + Vector3.new(0, 3, 0))
	end)

	task.wait(0.5)
	return true
end

local function buyCup()
	local ok, res = pcall(function()
		return RouterClient.get("ShopAPI/BuyItem"):InvokeServer("food", CUP_KIND, {
			buy_count = 1
		})
	end)
	return ok, res
end

local function placeCup()
	return invokeRemote(SlushieMachineNet.Place)
end

local function pourFlavor(flavorName)
	local firstLetter = string.sub(flavorName, 1, 1)
	return invokeRemote(SlushieMachineNet.Pour, {
		["color"] = firstLetter
	})
end

local function takeCup(maxAttempts)
	local attempts = maxAttempts or 3
	for _ = 1, attempts do
		if not isRunning then return false end
		local ok, res = invokeRemote(SlushieMachineNet.Take)
		if ok then
			return true, res
		end
		task.wait(TIMING.TAKE_RETRY_DELAY)
	end
	return false
end

local function startAutomation()
	if not teleportAndVerify() then
		isRunning = false
		return
	end

	local recipeIndex = 1

	while isRunning do
		if recipeIndex == 1 then
			for i = 1, #recipeEntries do
				updateRecipeStatus(i, "Pending", Color3.fromRGB(150, 150, 150))
			end
		end

		local currentRecipe = recipeEntries[recipeIndex]
		updateRecipeStatus(recipeIndex, "In Progress...", Color3.fromRGB(255, 200, 100))

		local bought = buyCup()
		if not bought or not isRunning then
			task.wait(1)
			continue
		end

		task.wait(TIMING.AFTER_BUY)
		if not isRunning then break end

		if not placeCup() or not isRunning then
			task.wait(0.5)
			continue
		end

		task.wait(TIMING.AFTER_PLACE)
		if not isRunning then break end

		local pourSuccess = true
		for _, flavor in ipairs(currentRecipe.flavors) do
			if not isRunning then break end
			if not pourFlavor(flavor) then
				pourSuccess = false
				break
			end
			task.wait(TIMING.BETWEEN_POURS)
		end

		if not isRunning then break end
		if not pourSuccess then
			updateRecipeStatus(recipeIndex, "Failed", Color3.fromRGB(255, 100, 100))
			task.wait(0.5)
			recipeIndex = (recipeIndex % #recipeEntries) + 1
			continue
		end

		task.wait(TIMING.BEFORE_TAKE)
		if takeCup(3) then
			updateRecipeStatus(recipeIndex, "Completed", Color3.fromRGB(100, 255, 100))
		else
			updateRecipeStatus(recipeIndex, "Failed (Take)", Color3.fromRGB(255, 100, 100))
		end

		recipeIndex = (recipeIndex % #recipeEntries) + 1
		task.wait(TIMING.CYCLE_COOLDOWN)
	end
end

local processedPositions = {}
local totalRewardsClaimed = 0
local isManagingLure = false
local lureLockTimestamp = 0

local CONFIG = {
	CooldownBetweenActions = 0.35,
	WaitTimeForCharge = 2.5,
	TeleportOffset = Vector3.new(0, 3, 0),
	ForkedBottleKind = "lightning_dimension_2026_forked_bottle",
	CapturedLightningKind = "lightning_dimension_2026_captured_lightning",
	DefaultBaitDuration = 7200,
	MaxPetStage = 6,
	PenSlotCount = 4,
	Baits = {
		cookie = { kind = "lightning_dimension_2026_cookie_bait", category = "food" },
		cake = { kind = "lightning_dimension_2026_cake_bait", category = "food" }
	}
}

local DailiesNetService = nil
pcall(function()
	DailiesNetService = require(replicatedStorage.new.modules.Dailies.DailiesNetService)
end)

local lightningNet = nil
pcall(function()
	local lightningDimPath = replicatedStorage:WaitForChild("SharedModules"):WaitForChild("ContentPacks"):WaitForChild("LightningDimension2026", 5)
	if lightningDimPath then
		lightningNet = require(lightningDimPath:WaitForChild("Game", 3):WaitForChild("LightningDimensionNet", 3))
	end
end)

coroutine.wrap(function()
	while getgenv().MasterAutoFarmerActive do
		safeCall("PlaytimePayouts", function()
			if ClientDataModule and RouterClient then
				local payoutData = ClientDataModule.get("playtime_payouts_manager")
				if type(payoutData) == "table" and payoutData.last_amount and payoutData.last_amount > 0 then
					fireRemote("PayAPI/Collect")
					if UIManager and UIManager.set_app_visibility then
						UIManager.set_app_visibility("PlaytimePayoutsApp", false)
					end
				end
			end
		end)
		task.wait(10.0)
	end
end)()

coroutine.wrap(function()
	while getgenv().MasterAutoFarmerActive do
		safeCall("DailiesAutoClaim", function()
			if DailiesNetService and ClientDataModule then
				local dailiesData = ClientDataModule.get("dailies_manager")
				if type(dailiesData) == "table" and type(dailiesData.serialized_tabs) == "table" then
					for tabKey, tabData in pairs(dailiesData.serialized_tabs) do
						local categoryId = tabKey
						if type(tabData) == "table" and tabData.tab_id then
							categoryId = tabData.tab_id
						elseif type(tabData) == "table" and tabData.id then
							categoryId = tabData.id
						end
						if type(categoryId) == "string" then
							pcall(function() DailiesNetService.try_to_claim_tab_reward(categoryId) end)
							task.wait(1.5)
							pcall(function() DailiesNetService.try_to_claim_daily_rewards(categoryId) end)
							task.wait(1)
						end
					end
				end
			end
		end)
		task.wait(10)
	end
end)()

local function safeTakeBottle()
	safeCall("SafeTakeBottle", function()
		if lightningNet and type(lightningNet.TakeBottle) == "table" and type(lightningNet.TakeBottle.invoke_server_async) == "function" then
			pcall(function() lightningNet.TakeBottle:invoke_server_async() end)
		end
	end)
end

local function enterLightningDimension()
	if hasEnteredDimension then return end
	hasEnteredDimension = true

	safeCall("EnterLightningDimension", function()
		fireRemote("AdoptAPI/SendPassiveDoorEnter", "LightningDimension", "MainDoor", {})
		task.wait(0.2)

		local locationObj = Location.new("LightningDimension", "MainDoor", {})
		if locationObj then
			fireRemote("LocationAPI/SetLocation", locationObj.destination_id, locationObj.house_owner, locationObj.sub_destination_id)
		end

		task.wait(1.5)
		if not getgenv().MasterAutoFarmerActive then return end

		local interiors = workspace:WaitForChild("Interiors", 5)
		local lightningDim = interiors and interiors:WaitForChild("LightningDimension", 5)
		
		while not lightningDim and task.wait(0.5) do
			interiors = workspace:FindFirstChild("Interiors")
			lightningDim = interiors and interiors:FindFirstChild("LightningDimension")
		end

		if lightningDim then
			local mapModel = lightningDim:FindFirstChild("Map")
			if mapModel then mapModel:Destroy() end

			for _, child in ipairs(lightningDim:GetChildren()) do
				if child.Name:find("LightningPortal_") then
					child:Destroy()
				end
			end

			coroutine.wrap(function()
				safeCall("DimensionPlatformTexture", function()
					local RESOLVED_PLANK_TEXTURE = "rbxassetid://95725392917317"
					pcall(function()
						local objects = game:GetObjects("rbxassetid://95725392917317")
						if objects and objects[1] and objects[1]:IsA("Decal") then
							RESOLVED_PLANK_TEXTURE = objects[1].Texture
						end
					end)

					local visualFolder = lightningDim:WaitForChild("Visual", 5)
					local groundStandIn = visualFolder and visualFolder:WaitForChild("GroundStandIn", 5)
					if groundStandIn and groundStandIn:IsA("BasePart") then
						for _, child in ipairs(groundStandIn:GetChildren()) do
							if child:IsA("Decal") or child:IsA("Texture") then
								child:Destroy()
							end
						end

						local gridTexture = Instance.new("Texture")
						gridTexture.Name = "CustomGridTexture"
						gridTexture.Face = Enum.NormalId.Top
						gridTexture.Texture = RESOLVED_PLANK_TEXTURE
						gridTexture.StudsPerTileU = 10
						gridTexture.StudsPerTileV = 10
						gridTexture.Parent = groundStandIn
					end
				end)
			end)()

			local gameFolder = lightningDim:FindFirstChild("Game")
			if not gameFolder then
				gameFolder = Instance.new("Folder")
				gameFolder.Name = "Game"
				gameFolder.Parent = lightningDim
			end

			local existing = gameFolder:FindFirstChild("ManualSafetyPlatform")
			if existing then existing:Destroy() end

			local char = player.Character or player.CharacterAdded:Wait()
			local rootPart = char:WaitForChild("HumanoidRootPart", 5)

			if rootPart then
				local platform = Instance.new("Part")
				platform.Name = "ManualSafetyPlatform"
				platform.Size = Vector3.new(200, 2, 200)
				platform.Anchored = true
				platform.CanCollide = true
				platform.Position = Vector3.new(9000, 7000, -2900)
				platform.Material = Enum.Material.SmoothPlastic
				platform.Color = Color3.fromRGB(35, 35, 45)
				platform.Parent = gameFolder
				
				safeTeleport(rootPart, platform.CFrame + Vector3.new(0, 4.0, 0))
				task.wait(0.5)
				safeTakeBottle()
			end
		end
	end)
end

local function makeWholeUIDraggable(targetFrame)
	local dragging = false
	local dragStart = Vector2.new(0, 0)
	local startPos = UDim2.new(0, 0, 0, 0)

	local function stopDragging()
		dragging = false
	end

	userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stopDragging()
		end
	end)

	local function attachDrag(guiObject)
		guiObject.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = targetFrame.Position
			end
		end)
	end

	attachDrag(targetFrame)
	for _, desc in ipairs(targetFrame:GetDescendants()) do
		if desc:IsA("GuiObject") then
			attachDrag(desc)
		end
	end
	targetFrame.DescendantAdded:Connect(function(desc)
		if desc:IsA("GuiObject") then
			attachDrag(desc)
		end
	end)

	userInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			targetFrame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local function getRainbowColor(offset)
	local t = os.clock() * 0.5 + offset
	local r = math.sin(t) * 0.5 + 0.5
	local g = math.sin(t + math.pi * 2 / 3) * 0.5 + 0.5
	local b = math.sin(t + math.pi * 4 / 3) * 0.5 + 0.5
	return Color3.new(r, g, b)
end

local function createUI()
	local existingUi = playerGui:FindFirstChild("MasterAutoFarmerUI")
	if existingUi then existingUi:Destroy() end

	local UI_WIDTH = 380
	local UI_HEIGHT = 500
	local HEADER_HEIGHT = 44

	local gui = Instance.new("ScreenGui")
	gui.Name = "MasterAutoFarmerUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT)
	mainFrame.Position = UDim2.new(0, 50, 0, 50)
	mainFrame.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Parent = gui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 6)
	mainCorner.Parent = mainFrame

	local showBtn = Instance.new("TextButton")
	showBtn.Size = UDim2.new(0, 70, 0, 20)
	showBtn.AnchorPoint = Vector2.new(0.5, 1)
	showBtn.Position = UDim2.new(0.2, 0, 1, -190)
	showBtn.Text = "Open UI"
	showBtn.TextSize = 14
	showBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	showBtn.Visible = false
	showBtn.Parent = gui
	local showCorner = Instance.new("UICorner")
	showCorner.CornerRadius = UDim.new(0, 5)
	showCorner.Parent = showBtn

	showBtn.Activated:Connect(function()
		mainFrame.Visible = true
		showBtn.Visible = false
	end)

	local minBtn = Instance.new("TextButton")
	minBtn.Size = UDim2.new(0, 26, 0, 26)
	minBtn.Position = UDim2.new(1, -62, 0, 9)
	minBtn.BackgroundColor3 = Color3.fromRGB(65, 65, 55)
	minBtn.BorderSizePixel = 0
	minBtn.Text = "-"
	minBtn.Font = Enum.Font.SourceSansBold
	minBtn.TextSize = 18
	minBtn.TextColor3 = Color3.fromRGB(220, 120, 120)
	minBtn.Parent = mainFrame
	local minCorner = Instance.new("UICorner")
	minCorner.CornerRadius = UDim.new(1, 0)
	minCorner.Parent = minBtn

	minBtn.Activated:Connect(function()
		mainFrame.Visible = false
		showBtn.Visible = true
	end)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 26, 0, 26)
	closeBtn.Position = UDim2.new(1, -31, 0, 9)
	closeBtn.BackgroundColor3 = Color3.fromRGB(85, 45, 50)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.TextSize = 14
	closeBtn.TextColor3 = Color3.fromRGB(200, 100, 220)
	closeBtn.Parent = mainFrame
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn

	local heartbeatConn
	heartbeatConn = runService.Heartbeat:Connect(function()
		minBtn.TextColor3 = getRainbowColor(0.5)
		closeBtn.TextColor3 = getRainbowColor(0)
		if showBtn and mainFrame and not mainFrame.Visible then
			showBtn.TextColor3 = getRainbowColor(1)
		end
	end)

	closeBtn.Activated:Connect(function()
		if heartbeatConn then
			heartbeatConn:Disconnect()
		end
		getgenv().MasterAutoFarmerActive = false
		gui:Destroy()
	end)

	local function switchTab(tabName)
		activeTab = tabName
		for name, page in pairs(tabPages) do
			page.Visible = (name == tabName)
		end
		for name, btnData in pairs(tabButtons) do
			if name == tabName then
				btnData.button.BackgroundColor3 = btnData.activeColor
				btnData.button.TextColor3 = Color3.fromRGB(15, 15, 15)
			else
				btnData.button.BackgroundColor3 = btnData.inactiveColor
				btnData.button.TextColor3 = Color3.fromRGB(230, 230, 230)
			end
		end
	end

	local function createTabButton(name, labelText, xPos, width, activeCol, inactiveCol)
		local btn = Instance.new("TextButton")
		btn.Name = name .. "TabBtn"
		btn.Size = UDim2.new(0, width, 0, 32)
		btn.Position = UDim2.new(0, xPos, 0, 6)
		btn.BackgroundColor3 = activeCol
		btn.BorderSizePixel = 0
		btn.Text = labelText
		btn.Font = Enum.Font.SourceSansBold
		btn.TextSize = 13
		btn.TextColor3 = Color3.fromRGB(15, 15, 15)
		btn.Parent = mainFrame

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = btn

		tabButtons[name] = {
			button = btn,
			activeColor = activeCol,
			inactiveColor = inactiveCol,
		}

		btn.MouseButton1Click:Connect(function()
			switchTab(name)
		end)
	end

	createTabButton("Status", "STATUS", 10, 74, Color3.fromRGB(0, 185, 0), Color3.fromRGB(0, 95, 0))
	createTabButton("Toggles", "TOGGLES", 88, 78, Color3.fromRGB(215, 25, 15), Color3.fromRGB(110, 20, 15))
	createTabButton("Slushie", "SLUSHIE", 170, 78, Color3.fromRGB(200, 140, 0), Color3.fromRGB(110, 75, 0))
	createTabButton("Extra", "EXTRA", 252, 64, Color3.fromRGB(15, 150, 240), Color3.fromRGB(15, 75, 125))

	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, -16, 1, -(HEADER_HEIGHT + 24))
	contentArea.Position = UDim2.new(0, 8, 0, HEADER_HEIGHT + 4)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = mainFrame

	local function createTabPage(name)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = name .. "Page"
		scroll.Size = UDim2.new(1, 0, 1, 0)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 4
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.Visible = false
		scroll.Parent = contentArea

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.Padding = UDim.new(0, 8)
		layout.Parent = scroll

		tabPages[name] = scroll
		return scroll
	end

	local statusPage = createTabPage("Status")

	local function addStatusRow(key, text, color, textSize, isBold, centerAlign)
		local lbl = Instance.new("TextLabel")
		lbl.Name = key
		lbl.Size = UDim2.new(1, -6, 0, 20)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = color
		lbl.Font = isBold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
		lbl.TextSize = textSize or 16
		lbl.TextXAlignment = centerAlign and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
		lbl.Parent = statusPage
		labels[key] = lbl
		return lbl
	end

	addStatusRow("envCheck", "Environment Check: All OK ✅", Color3.fromRGB(40, 230, 40), 16)
	addStatusRow("lureTimerStatus", "Lure Timer: Checking...", Color3.fromRGB(100, 255, 150), 16, true)
	addStatusRow("eventStatus", "Master Status: Running smoothly", Color3.fromRGB(235, 235, 235), 15)
	addStatusRow("gbCache", "TOTAL CLAIMED REWARDS: 0", Color3.fromRGB(60, 210, 235), 16, true)
	addStatusRow("location", "Location: Checking...", Color3.fromRGB(130, 225, 235), 16)
	addStatusRow("tpMode", "SYSTEM MODE: AUTOMATED", Color3.fromRGB(255, 255, 255), 18, true, true)

	local resultsHeader = addStatusRow("resultsHeader", "ACTIVITY & REWARDS LOG:", Color3.fromRGB(255, 215, 0), 14, true)
	resultsHeader.Size = UDim2.new(1, -6, 0, 16)

	local resultsContainer = Instance.new("ScrollingFrame")
	resultsContainer.Name = "ResultsContainer"
	resultsContainer.Size = UDim2.new(1, -6, 0, 140)
	resultsContainer.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
	resultsContainer.BorderSizePixel = 0
	resultsContainer.ScrollBarThickness = 3
	resultsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	resultsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	resultsContainer.Parent = statusPage

	local resCorner = Instance.new("UICorner")
	resCorner.CornerRadius = UDim.new(0, 4)
	resCorner.Parent = resultsContainer

	local resPadding = Instance.new("UIPadding")
	resPadding.PaddingLeft = UDim.new(0, 6)
	resPadding.PaddingTop = UDim.new(0, 4)
	resPadding.Parent = resultsContainer

	Instance.new("UIListLayout", resultsContainer).Padding = UDim.new(0, 2)
	labels["results_container"] = resultsContainer

	local togglesPage = createTabPage("Toggles")
	local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function addSwitchToggle(stateKey, displayName, description, onChange)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 46)
		row.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
		row.BorderSizePixel = 0
		row.Parent = togglesPage

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		local title = Instance.new("TextLabel")
		title.Name = "TitleLabel"
		title.Size = UDim2.new(1, -76, 0, 22)
		title.Position = UDim2.new(0, 10, 0, 5)
		title.BackgroundTransparency = 1
		title.Text = displayName
		title.TextColor3 = Color3.fromRGB(245, 245, 245)
		title.Font = Enum.Font.SourceSansBold
		title.TextSize = 15
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = row

		local sub = Instance.new("TextLabel")
		sub.Name = "SubLabel"
		sub.Size = UDim2.new(1, -76, 0, 16)
		sub.Position = UDim2.new(0, 10, 0, 25)
		sub.BackgroundTransparency = 1
		sub.Text = description
		sub.TextColor3 = Color3.fromRGB(170, 170, 170)
		sub.Font = Enum.Font.SourceSans
		sub.TextSize = 12
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Parent = row

		labels[stateKey .. "_sub"] = sub

		local switchTrack = Instance.new("TextButton")
		switchTrack.Name = "SwitchTrack"
		switchTrack.Size = UDim2.new(0, 48, 0, 24)
		switchTrack.AnchorPoint = Vector2.new(1, 0.5)
		switchTrack.Position = UDim2.new(1, -12, 0.5, 0)
		switchTrack.Text = ""
		switchTrack.AutoButtonColor = false
		switchTrack.BorderSizePixel = 0
		switchTrack.Parent = row

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = switchTrack

		local knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.Size = UDim2.new(0, 18, 0, 18)
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
		knob.BorderSizePixel = 0
		knob.Parent = switchTrack

		local knobCorner = Instance.new("UICorner")
		knobCorner.CornerRadius = UDim.new(1, 0)
		knobCorner.Parent = knob

		local function refreshSwitch(instant)
			local isOn = ToggleStates[stateKey]
			local targetColor = isOn and Color3.fromRGB(0, 195, 75) or Color3.fromRGB(90, 90, 95)
			local targetPos = isOn and UDim2.new(0, 27, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)

			if instant then
				switchTrack.BackgroundColor3 = targetColor
				knob.Position = targetPos
			else
				tweenService:Create(switchTrack, tweenInfo, { BackgroundColor3 = targetColor }):Play()
				tweenService:Create(knob, tweenInfo, { Position = targetPos }):Play()
			end
		end

		refreshSwitch(true)

		switchTrack.MouseButton1Click:Connect(function()
			ToggleStates[stateKey] = not ToggleStates[stateKey]
			refreshSwitch(false)
			if onChange then
				onChange(ToggleStates[stateKey])
			end
		end)
	end

	addSwitchToggle("LureActive", "🎁 Lure Manager", "Time Left: Checking...", function(val)
		getgenv().FarmerToggles.LureActive = val
		if not val and labels["LureActive_sub"] then
			labels["LureActive_sub"].Text = "Status: Paused (Lures OFF)"
			labels["LureActive_sub"].TextColor3 = Color3.fromRGB(170, 170, 170)
		end
	end)

	local baitRow = Instance.new("TextButton")
	baitRow.Name = "BaitSelectorRow"
	baitRow.Size = UDim2.new(1, -6, 0, 34)
	baitRow.BackgroundColor3 = Color3.fromRGB(180, 50, 120)
	baitRow.BorderSizePixel = 0
	baitRow.Text = "🍰 Selected Bait: CAKE (Click to Cycle)"
	baitRow.Font = Enum.Font.SourceSansBold
	baitRow.TextSize = 14
	baitRow.TextColor3 = Color3.fromRGB(255, 255, 255)
	baitRow.Parent = togglesPage

	local baitCorner = Instance.new("UICorner")
	baitCorner.CornerRadius = UDim.new(0, 6)
	baitCorner.Parent = baitRow

	baitRow.MouseButton1Click:Connect(function()
		if getgenv().FarmerToggles.SelectedBait == "cake" then
			getgenv().FarmerToggles.SelectedBait = "cookie"
			baitRow.Text = "🍪 Selected Bait: COOKIE (Click to Cycle)"
			baitRow.BackgroundColor3 = Color3.fromRGB(180, 110, 30)
		elseif getgenv().FarmerToggles.SelectedBait == "cookie" then
			getgenv().FarmerToggles.SelectedBait = "all"
			baitRow.Text = "🔄 Selected Bait: ANY AVAILABLE (Click to Cycle)"
			baitRow.BackgroundColor3 = Color3.fromRGB(70, 70, 180)
		else
			getgenv().FarmerToggles.SelectedBait = "cake"
			baitRow.Text = "🍰 Selected Bait: CAKE (Click to Cycle)"
			baitRow.BackgroundColor3 = Color3.fromRGB(180, 50, 120)
		end
	end)

	addSwitchToggle("PetPenActive", "🐾 Pet Pen Manager", "Manage active growing pets (excludes eggs/practice dogs)", function(val)
		getgenv().FarmerToggles.PetPenActive = val
	end)

	addSwitchToggle("CommitPenActive", "⚡ Commit Pen Progression", "Auto-commit full grown progression chunks", function(val)
		getgenv().FarmerToggles.CommitPenActive = val
	end)

	addSwitchToggle("BottlesActive", "⚡ Lightning Bottler", "Auto-collect & place lightning bottles", function(val)
		getgenv().FarmerToggles.BottlesActive = val
		if val then
			task.spawn(enterLightningDimension)
		end
	end)

	addSwitchToggle("CauldronActive", "🧪 Cauldron Crafting", "Craft baits using captured lightning automatically", function(val)
		getgenv().FarmerToggles.CauldronActive = val
	end)

	-- Slushie Tab Page
	local slushiePage = createTabPage("Slushie")

	local mainFrameSlushie = Instance.new("Frame")
	mainFrameSlushie.Size = UDim2.new(1, -6, 0, 390)
	mainFrameSlushie.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	mainFrameSlushie.BorderSizePixel = 0
	mainFrameSlushie.Parent = slushiePage

	local cornerSlushie = Instance.new("UICorner")
	cornerSlushie.CornerRadius = UDim.new(0, 8)
	cornerSlushie.Parent = mainFrameSlushie

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Slushie Recipe Status Monitor"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 15
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = mainFrameSlushie

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0.46, 0, 0, 35)
	toggleBtn.Position = UDim2.new(0.03, 0, 0, 45)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	toggleBtn.BorderSizePixel = 0
	toggleBtn.Text = "Status: OFF"
	toggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	toggleBtn.TextSize = 13
	toggleBtn.Font = Enum.Font.GothamMedium
	toggleBtn.Parent = mainFrameSlushie

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 6)
	toggleCorner.Parent = toggleBtn

	toggleBtn.MouseButton1Click:Connect(function()
		isRunning = not isRunning

		if isRunning then
			toggleBtn.Text = "Status: ON"
			toggleBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
			toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 50)

			if automationThread then
				task.cancel(automationThread)
			end
			automationThread = task.spawn(startAutomation)
		else
			toggleBtn.Text = "Status: OFF"
			toggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
			toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)

			if automationThread then
				task.cancel(automationThread)
				automationThread = nil
			end
		end
	end)

	local closeBtnSlushie = Instance.new("TextButton")
	closeBtnSlushie.Size = UDim2.new(0.46, 0, 0, 35)
	closeBtnSlushie.Position = UDim2.new(0.51, 0, 0, 45)
	closeBtnSlushie.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
	closeBtnSlushie.BorderSizePixel = 0
	closeBtnSlushie.Text = "Stop Bot"
	closeBtnSlushie.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtnSlushie.TextSize = 13
	closeBtnSlushie.Font = Enum.Font.GothamMedium
	closeBtnSlushie.Parent = mainFrameSlushie

	local closeCornerSlushie = Instance.new("UICorner")
	closeCornerSlushie.CornerRadius = UDim.new(0, 6)
	closeCornerSlushie.Parent = closeBtnSlushie

	closeBtnSlushie.MouseButton1Click:Connect(function()
		isRunning = false
		toggleBtn.Text = "Status: OFF"
		toggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
		toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		if automationThread then
			task.cancel(automationThread)
			automationThread = nil
		end
	end)

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(0.94, 0, 0, 290)
	scrollFrame.Position = UDim2.new(0.03, 0, 0, 88)
	scrollFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	scrollFrame.BorderSizePixel = 0
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #recipeEntries * 32)
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.Parent = mainFrameSlushie

	local scrollCorner = Instance.new("UICorner")
	scrollCorner.CornerRadius = UDim.new(0, 6)
	scrollCorner.Parent = scrollFrame

	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiListLayout.Padding = UDim.new(0, 4)
	uiListLayout.Parent = scrollFrame

	for i, recipe in ipairs(recipeEntries) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
		row.BorderSizePixel = 0
		row.Parent = scrollFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 4)
		rowCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.65, 0, 1, 0)
		nameLabel.Position = UDim2.new(0.03, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = string.format("[%s] %s", recipe.mixKey, recipe.displayName)
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		nameLabel.TextSize = 11
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.new(0.3, 0, 1, 0)
		statusLabel.Position = UDim2.new(0.68, 0, 0, 0)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = "Pending"
		statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		statusLabel.TextSize = 11
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.TextXAlignment = Enum.TextXAlignment.Right
		statusLabel.Parent = row

		recipeStatuses[i] = statusLabel
	end

	local extraPage = createTabPage("Extra")

	local function addActionButton(text, color, callback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -6, 0, 36)
		btn.BackgroundColor3 = color
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.Font = Enum.Font.SourceSansBold
		btn.TextSize = 16
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Parent = extraPage

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = btn

		btn.MouseButton1Click:Connect(callback)
	end

	addActionButton("Force Enter Lightning Dimension", Color3.fromRGB(15, 140, 230), function()
		enterLightningDimension()
	end)

	addActionButton("Reset Claim Counter", Color3.fromRGB(90, 90, 90), function()
		totalRewardsClaimed = 0
		if labels.gbCache then
			labels.gbCache.Text = "TOTAL CLAIMED REWARDS: 0"
		end
	end)

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size = UDim2.new(1, -10, 0, 14)
	versionLabel.AnchorPoint = Vector2.new(0, 1)
	versionLabel.Position = UDim2.new(0, 5, 1, -3)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text = "Version: Master Auto-Farm v3.25"
	versionLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
	versionLabel.Font = Enum.Font.SourceSans
	versionLabel.TextSize = 11
	versionLabel.TextXAlignment = Enum.TextXAlignment.Right
	versionLabel.Parent = mainFrame

	makeWholeUIDraggable(mainFrame)
	switchTab("Status")
end

createUI()

local function updateLureUI(statusText, timeText, highlightColor)
	pcall(function()
		local subLabel = labels["LureActive_sub"]
		if subLabel then
			subLabel.Text = tostring(statusText) .. " | Time Left: " .. tostring(timeText)
			subLabel.TextColor3 = highlightColor or Color3.fromRGB(100, 255, 150)
		end
		if labels.lureTimerStatus then
			labels.lureTimerStatus.Text = "Lure: " .. tostring(statusText) .. " (" .. tostring(timeText) .. ")"
		end
	end)
end

local function formatDuration(seconds)
	if not seconds or seconds <= 0 then return "0s (Ready!)" end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	
	if hours > 0 then
		return string.format("%dh %02dm %02ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, secs)
	else
		return string.format("%ds", secs)
	end
end

local function addLogEntry(txt, color)
	local container = labels["results_container"]
	if not container then return end
	local l = Instance.new("TextLabel", container)
	l.Size = UDim2.new(1, 0, 0, 16)
	l.BackgroundTransparency = 1
	l.Text = txt
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Font = Enum.Font.SourceSansBold
	l.TextSize = 12
	l.TextXAlignment = Enum.TextXAlignment.Left

	totalRewardsClaimed = totalRewardsClaimed + 1
	if labels.gbCache then
		labels.gbCache.Text = "TOTAL CLAIMED REWARDS: " .. tostring(totalRewardsClaimed)
	end
end

task.spawn(function()
	while true do
		pcall(function()
			if labels.location and InteriorsM and InteriorsM.get_current_location then
				local ok, loc = pcall(function()
					return InteriorsM.get_current_location()
				end)
				if ok and type(loc) == "table" and loc.full_destination_id then
					labels.location.Text = "Location: " .. tostring(loc.full_destination_id)
				elseif ok and type(loc) == "string" then
					labels.location.Text = "Location: " .. loc
				else
					labels.location.Text = "Location: Unknown"
				end
			end
		end)
		task.wait(1.5)
	end
end)

local function waitForData()
	local success, data = pcall(function()
		return ClientDataModule.get_data()
	end)
	while (not success or not data) and getgenv().MasterAutoFarmerActive do
		task.wait(0.5)
		success, data = pcall(function()
			return ClientDataModule.get_data()
		end)
	end
	if type(data) == "table" then return data end
	return nil
end

local function getInventory()
	local ok, inv = pcall(function()
		return ClientDataModule.get("inventory")
	end)
	if ok and type(inv) == "table" then return inv end

	local serverData = waitForData()
	if not serverData or type(serverData) ~= "table" then return nil end
	for _, dataEntry in pairs(serverData) do
		if type(dataEntry) == "table" and type(dataEntry.inventory) == "table" then
			return dataEntry.inventory
		end
	end
	return nil
end

local function equipToolSilent(itemUniqueId)
	if not getgenv().MasterAutoFarmerActive then return false end
	local invokeSuccess = invokeRemote(RouterClient.get("ToolAPI/Equip"), {itemUniqueId, { use_sound_delay = false, equip_as_last = false }})
	return invokeSuccess ~= nil
end

local function findConfiguredBait()
	local ok, inventory = pcall(getInventory)
	if not ok or not inventory or type(inventory) ~= "table" or type(inventory.food) ~= "table" then return nil, nil end

	local selectedMode = getgenv().FarmerToggles.SelectedBait

	if selectedMode == "cake" or selectedMode == "cookie" then
		local targetKind = CONFIG.Baits[selectedMode].kind
		for uniqueId, itemData in pairs(inventory.food) do
			if type(itemData) == "table" then
				local kind = tostring(itemData.kind or itemData.id or "")
				if kind == targetKind or kind:find(selectedMode) then
					return tostring(uniqueId), kind
				end
			end
		end
	else
		for baitKey, baitConfig in pairs(CONFIG.Baits) do
			for uniqueId, itemData in pairs(inventory.food) do
				if type(itemData) == "table" then
					local kind = tostring(itemData.kind or itemData.id or "")
					if kind == baitConfig.kind or kind:find("bait") then
						return tostring(uniqueId), kind
					end
				end
			end
		end
	end

	return nil, nil
end

local function getCauldronUniqueId()
	local ok, matches = pcall(function()
		if type(FurnitureUniqueFinder) == "table" and type(FurnitureUniqueFinder.filter) == "function" then
			return FurnitureUniqueFinder.filter(function(furnitureUnique, furnitureData)
				if type(furnitureData) ~= "table" then return false end
				local id = tostring(furnitureData.id or ""):lower()
				return id:find("cauldron") or id:find("lightning") or id:find("craft")
			end)
		end
	end)
	if ok and type(matches) == "table" and #matches > 0 then
		return matches[1]
	end
	return "f-2"
end

local function getCapturedLightningUniques()
	local inventory = getInventory()
	local uniques = {}
	if inventory and type(inventory) == "table" and type(inventory.toys) == "table" then
		for uniqueId, itemData in pairs(inventory.toys) do
			if type(itemData) == "table" then
				local kind = itemData.kind or itemData.id
				if kind == CONFIG.CapturedLightningKind then
					table.insert(uniques, uniqueId)
				end
			end
		end
	end
	return uniques
end

local function processCauldronCrafting()
	if not getgenv().FarmerToggles.CauldronActive then return end

	safeCall("CauldronCrafting", function()
		local capturedUniques = getCapturedLightningUniques()
		while getgenv().MasterAutoFarmerActive and getgenv().FarmerToggles.CauldronActive and type(capturedUniques) == "table" and #capturedUniques >= 3 do
			local furnitureId = getCauldronUniqueId()
			if not furnitureId then break end

			local recipeKey = (getgenv().FarmerToggles.SelectedBait == "cookie") and "cookie" or "cake"

			fireRemote("HousingAPI/ActivateInteriorFurniture", furnitureId, "UseBlock", {
				["key"] = recipeKey,
				["item_list"] = {
					["r_1"] = capturedUniques[1],
					["r_2"] = capturedUniques[2],
					["r_3"] = capturedUniques[3]
				}
			})
			
			task.wait(1.5)
			capturedUniques = getCapturedLightningUniques()
		end
	end)
end

local function getLuresMap()
	local success, data = pcall(function()
		return ClientDataModule.get_data()
	end)
	if not success or type(data) ~= "table" then return nil end

	local playerProfile = data[player.Name]
	if type(playerProfile) == "table" then
		local lureMgr = playerProfile.lures_2023_lure_manager
		if type(lureMgr) == "table" and type(lureMgr.lures_map) == "table" then
			return lureMgr.lures_map
		end
	end

	for _, rootValue in pairs(data) do
		if type(rootValue) == "table" then
			local lureMgr = rootValue.lures_2023_lure_manager
			if type(lureMgr) == "table" and type(lureMgr.lures_map) == "table" then
				return lureMgr.lures_map
			end
		end
	end
	return nil
end

local function handleLureMaintenance(rawLureKey, lureData, isReadyToClaim, needsBait)
	if not getgenv().FarmerToggles.LureActive then return end

	if isManagingLure then
		if tick() - lureLockTimestamp > 8 then
			isManagingLure = false
		else
			return
		end
	end

	isManagingLure = true
	lureLockTimestamp = tick()

	task.spawn(function()
		safeCall("LureMaintenance", function()
			if not getgenv().FarmerToggles.LureActive then return end

			if isReadyToClaim then
				updateLureUI("🎁 Claiming...", "0s", Color3.fromRGB(255, 215, 0))
				pcall(function()
					if LuresNet and type(LuresNet.ClaimLure) == "table" and type(LuresNet.ClaimLure.invoke_server_async) == "function" then
						LuresNet.ClaimLure:invoke_server_async(rawLureKey)
					end
				end)
				addLogEntry("🎁 Claimed Lure Reward!", Color3.new(1, 0.8, 0))
				task.wait(2.0)
			end

			if needsBait and getgenv().FarmerToggles.LureActive then
				updateLureUI("🍪 Equipping Bait...", "0s", Color3.fromRGB(100, 200, 255))
				local baitUniqueId, foundKind = findConfiguredBait()
				if baitUniqueId then
					equipToolSilent(baitUniqueId)
					task.wait(0.5)

					pcall(function()
						if LuresNet and type(LuresNet.BaitLure) == "table" and type(LuresNet.BaitLure.fire_server) == "function" then
							LuresNet.BaitLure:fire_server({
								["lure_type"] = rawLureKey,
								["bait_unique"] = baitUniqueId
							})
						end
					end)
					addLogEntry("🍪 Baited Lure with " .. tostring(foundKind), Color3.new(0.4, 1, 0.4))
					task.wait(1.5)
				end
			end
		end)

		isManagingLure = false
	end)
end

local function processBackgroundLure()
	if not getgenv().FarmerToggles.LureActive then
		updateLureUI("Paused (OFF)", "--:--:--", Color3.fromRGB(170, 170, 170))
		return
	end

	if isManagingLure and tick() - lureLockTimestamp < 8 then return end

	safeCall("ProcessBackgroundLure", function()
		local luresMap = getLuresMap()
		if not luresMap or type(luresMap) ~= "table" then 
			updateLureUI("⏳ Active", "Running...", Color3.fromRGB(100, 255, 150))
			return 
		end

		local lureKey, lureData = next(luresMap)
		if not lureKey or type(lureData) ~= "table" then 
			updateLureUI("🪹 Empty", "Setting Bait", Color3.fromRGB(255, 180, 50))
			handleLureMaintenance("BasicLure", nil, false, true)
			return
		end

		local currentTime = workspace:GetServerTimeNow()
		local startTimestamp = lureData.lure_start_timestamp
		local finished = lureData.finished
		local baitKind = lureData.bait_kind
		local remainingSeconds = nil

		if startTimestamp and type(startTimestamp) == "number" then
			local expirationTime = startTimestamp + CONFIG.DefaultBaitDuration
			remainingSeconds = expirationTime - currentTime
		end

		local isFinishedState = (finished == true) or (lureData.reward ~= nil) or (remainingSeconds and remainingSeconds <= 0)

		if isFinishedState then
			updateLureUI("🎁 Ready!", "0s", Color3.fromRGB(255, 220, 60))
			handleLureMaintenance(lureKey, lureData, true, true)
		elseif baitKind and type(baitKind) == "string" and baitKind ~= "" then
			if remainingSeconds and remainingSeconds > 0 then
				updateLureUI("⏳ Running", formatDuration(remainingSeconds), Color3.fromRGB(100, 255, 150))
			else
				updateLureUI("🎁 Ready!", "0s", Color3.fromRGB(255, 220, 60))
				handleLureMaintenance(lureKey, lureData, true, true)
			end
		else
			updateLureUI("🪹 Empty", "Needs Bait", Color3.fromRGB(255, 180, 50))
			handleLureMaintenance(lureKey, lureData, false, true)
		end
	end)
end

local function getInventoryBottleStatus()
	local playerData = getInventory()
	local forkedBottles = {}
	local capturedCount = 0

	if playerData and type(playerData) == "table" and type(playerData.toys) == "table" then
		for uniqueId, itemData in pairs(playerData.toys) do
			if type(itemData) == "table" then
				local itemId = tostring(itemData.kind or itemData.id or "")
				if itemId == CONFIG.ForkedBottleKind or itemId:find("forked_bottle") then
					table.insert(forkedBottles, uniqueId)
				elseif itemId == CONFIG.CapturedLightningKind or itemId:find("captured_lightning") then
					capturedCount = capturedCount + 1
				end
			end
		end
	end
	return forkedBottles, capturedCount
end

local function getBottlePilePart()
	local interiors = workspace:FindFirstChild("Interiors")
	if interiors then
		local lightningDim = interiors:FindFirstChild("LightningDimension")
		if lightningDim then
			local gameFolder = lightningDim:FindFirstChild("Game")
			if gameFolder then
				local pile = gameFolder:FindFirstChild("BottlePile")
				if pile then
					return pile:FindFirstChild("Part") or pile.PrimaryPart or pile:FindFirstChildWhichIsA("BasePart")
				end
			end
		end
	end
	return nil
end

local function performRefillRun()
	safeCall("RefillRun", function()
		local char = player.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		local pilePart = getBottlePilePart()
		
		if rootPart and pilePart then
			safeTeleport(rootPart, CFrame.new(pilePart.Position + CONFIG.TeleportOffset))
			task.wait(0.5)
			for i = 1, 3 do
				safeTakeBottle()
				task.wait(0.25)
			end
		end
	end)
end

local function triggerBottlePlacement(strikePos)
	safeCall("TriggerBottlePlacement", function()
		if not getgenv().MasterAutoFarmerActive or not getgenv().FarmerToggles.BottlesActive then return end
		if not strikePos then return end

		local currentTime = tick()

		for pos, timestamp in pairs(processedPositions) do
			if currentTime - timestamp > 4.0 then
				processedPositions[pos] = nil
			end
		end

		for pos, _ in pairs(processedPositions) do
			if (pos - strikePos).Magnitude < 10 then
				return
			end
		end

		processedPositions[strikePos] = currentTime

		local availableBottles, _ = getInventoryBottleStatus()
		if #availableBottles == 0 then
			performRefillRun()
			task.wait(0.5)
			availableBottles, _ = getInventoryBottleStatus()
			if #availableBottles == 0 then return end
		end

		local char = player.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart.Parent then
			safeTeleport(rootPart, CFrame.new(strikePos + CONFIG.TeleportOffset))
			task.wait(0.12)
		end

		local bottleUniqueId = availableBottles[1]
		if not bottleUniqueId then return end

		equipToolSilent(bottleUniqueId)
		task.wait(0.15)

		if lightningNet and type(lightningNet.PlaceBottle) == "table" then
			pcall(function()
				if type(lightningNet.PlaceBottle.invoke_server_async) == "function" then
					lightningNet.PlaceBottle:invoke_server_async({
						["unique"] = bottleUniqueId,
						["position"] = strikePos
					})
				elseif type(lightningNet.PlaceBottle.InvokeServer) == "function" then
					lightningNet.PlaceBottle:InvokeServer({
						["unique"] = bottleUniqueId,
						["position"] = strikePos
					})
				end
			end)
		end

		task.wait(CONFIG.WaitTimeForCharge)
	end)
end

task.spawn(function()
	safeCall("LightningListeners", function()
		if lightningNet and type(lightningNet.Strike) == "table" and type(lightningNet.Strike.on_client_event) == "function" then
			lightningNet.Strike:on_client_event(function(data)
				local strikePos = type(data) == "table" and data.position or nil
				if strikePos then
					triggerBottlePlacement(strikePos)
				end
			end)
		end

		if lightningNet and type(lightningNet.StrikeWarning) == "table" and type(lightningNet.StrikeWarning.on_client_event) == "function" then
			lightningNet.StrikeWarning:on_client_event(function(data)
				local strikePos = type(data) == "table" and data.position or nil
				if strikePos then
					triggerBottlePlacement(strikePos)
				end
			end)
		end
	end)

	local lastLureCheck = 0
	local lastCraftCheck = 0

	while getgenv().MasterAutoFarmerActive do
		task.wait(0.25)

		if not getgenv().MasterAutoFarmerActive then break end

		if tick() - lastLureCheck > 1.0 then
			lastLureCheck = tick()
			safeCall("BackgroundLureRunner", processBackgroundLure)
		end

		if tick() - lastCraftCheck > 3.0 then
			lastCraftCheck = tick()
			safeCall("CauldronCraftingRunner", processCauldronCrafting)
		end

		if not getgenv().FarmerToggles.BottlesActive then
			continue
		end

		safeCall("WorkspaceStrikeScan", function()
			local interiors = workspace:FindFirstChild("Interiors")
			local lightningDim = interiors and interiors:FindFirstChild("LightningDimension")
			if lightningDim then
				for _, obj in ipairs(lightningDim:GetDescendants()) do
					if not getgenv().MasterAutoFarmerActive or not getgenv().FarmerToggles.BottlesActive then break end

					if obj:IsA("BasePart") and (obj.Name == "LightningDimension2026StrikeWarning" or obj.Name == "LightningDimension2026Strike") then
						local exactCenterPos = obj.CFrame.Position
						triggerBottlePlacement(exactCenterPos)
					end
				end
			end
		end)
	end
end)
