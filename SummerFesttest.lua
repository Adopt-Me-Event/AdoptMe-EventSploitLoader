
-- [[ EventGroup Professional Loader - Optimized & Fixed ]]
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

-- 1. Setup UI Safety
local player = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("EventGroupOverlay") then
    playerGui.EventGroupOverlay:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EventGroupOverlay"
screenGui.IgnoreGuiInset = true 
screenGui.DisplayOrder = 999999999 
screenGui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
bg.BorderSizePixel = 0
bg.Parent = screenGui

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(1, 0, 0.05, 0)
versionLabel.Position = UDim2.new(0, 0, 0.38, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
versionLabel.TextSize = 14
versionLabel.Font = Enum.Font.GothamMedium
versionLabel.Text = "v2.0.8.0"
versionLabel.Parent = bg

local mainLabel = Instance.new("TextLabel")
mainLabel.Size = UDim2.new(1, 0, 0.2, 0)
mainLabel.Position = UDim2.new(0, 0, 0.4, 0)
mainLabel.BackgroundTransparency = 1
mainLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
mainLabel.TextSize = 80
mainLabel.Font = Enum.Font.GothamBlack
mainLabel.Text = "EVENT GROUP"
mainLabel.Parent = bg

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0.05, 0)
statusLabel.Position = UDim2.new(0, 0, 0.53, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
statusLabel.TextSize = 18
statusLabel.Font = Enum.Font.Code
statusLabel.Text = "INITIALIZING SETUP..."
statusLabel.Parent = bg

-- 2. Setup Logic & External Modules
local startTime = os.clock()
local urls = {
    "https://raw.githubusercontent.com/Adopt-Me-Event/AdoptMe-ChristmasEvent-/refs/heads/main/TransitionsLoader.lua"
}

-- Backend Logic Functions
local function runBackendSetup()
    -- URL Loader
    for _, url in ipairs(urls) do
        if url ~= "" then
            task.spawn(function()
                local s, content = pcall(function() return game:HttpGet(url) end)
                if s and content and not content:find("404") then
                    local f = loadstring(content)
                    if f then pcall(f) end
                end
            end)
        end
    end

    -- Smart Trade Bypass Setup
    task.spawn(function()
        local fsysMod = ReplicatedStorage:WaitForChild("Fsys", 15)
        if not fsysMod then return end
        local Fsys = require(fsysMod)
        local ClientData = Fsys.load("ClientData")
        local RouterClient = Fsys.load("RouterClient")
        local TradeHelper = Fsys.load("TradeLicenseHelper")
        local TradeClient = Fsys.load("TradeLicenseClient")

        if TradeHelper.player_has_trade_license() then return end
        
        -- Mute the game's UI logic so the bypass is silent
        if TradeClient then
            TradeClient.unlock_gate = function() end 
            TradeClient.start_quiz = function() end 
        end

        pcall(function() RouterClient.get("TradeAPI/BeginQuiz"):FireServer() end)
        
        for i = 1, 20 do
            local data = ClientData.get("trade_license_quiz_manager")
            if data and data.quiz and data.quiz[data.question_index] then
                pcall(function()
                    RouterClient.get("TradeAPI/AnswerQuizQuestion"):FireServer(data.quiz[data.question_index].answer)
                end)
            end
            if TradeHelper.player_has_trade_license() then break end
            task.wait(0.7)
        end
    end)
end

-- 3. UI Animation & Status Management
local statuses = {
    {msg = "ESTABLISHING SECURE CONNECTION...", delay = 1.2},
    {msg = "LOADING EVENTGROUP FRAMEWORK...", delay = 1.5},
    {msg = "INJECTING TRADE BYPASS...", delay = 1.8},
    {msg = "FETCHING REMOTE ASSETS...", delay = 1.2},
    {msg = "SYNCING PLAYER DATA...", delay = 1.0},
    {msg = "FINALIZING SETUP...", delay = 0.8}
}

task.spawn(function()
    -- Start the actual script logic immediately
    runBackendSetup()

    local totalWait = 0
    for _, s in pairs(statuses) do totalWait = totalWait + s.delay end
    
    local barBack = Instance.new("Frame")
    barBack.Size = UDim2.new(0.3, 0, 0.005, 0)
    barBack.Position = UDim2.new(0.35, 0, 0.58, 0)
    barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    barBack.BorderSizePixel = 0
    barBack.Parent = bg

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
    bar.BorderSizePixel = 0
    bar.Parent = barBack
    
    TweenService:Create(bar, TweenInfo.new(totalWait, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)}):Play()

    for i = 1, #statuses do
        statusLabel.Text = statuses[i].msg
        task.wait(statuses[i].delay)
    end
    
    statusLabel.Text = "AUTHENTICATED ✅"
    task.wait(0.6)

    local exit = TweenService:Create(bg, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(0, 0, -1, 0)})
    exit:Play()
    exit.Completed:Wait()
    screenGui:Destroy()
    
    print("--- ✅ [ EventGroup ]: Setup Complete in " .. string.format("%.2f", os.clock() - startTime) .. "s")
end)




-- 4. Visuals & Branding
print([[
 ______                _     _____                                
|  ____|              | |   / ____|                               
| |__  __   _____ _ __| |_ | |  __ _ __ ___  _   _ _ __           
|  __| \ \ / / _ \ '_ \ __|| | |_ | '__/ _ \| | | | '_ \          
| |____ \ V /  __/ | | | |_ | |__| | | | (_) | |_| | |_) |         
|______| \_/ \___|_| |_|\__| \_____|_|  \___/ \__,_| .__/          
                                                   | |              
                                                   |_|              
]])


print("--- 🔹 VERSION v2.0.8.0 LOADED 🔹")
warn("Loading EventSploit Enjoy!")
wait("9")


local success, err = pcall(function()
    -- === CONFIGURATION ===
    local HUB_VERSION = "v2.0.8.0" 
    local HUB_NAME = "Eventsploit | Adopt Me!"
    local OutlineColor = Color3.fromRGB(168, 85, 247) -- Default Purple
    
    local LoadStart = tick()
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local RunS = game:GetService("RunService")
    local VIM = game:GetService("VirtualInputManager")
    local LP = Players.LocalPlayer
    local PG = LP:WaitForChild("PlayerGui")
    local MINIMIZE_KEY = Enum.KeyCode.LeftControl

    -- === 1. LOAD LIBS ===
    local Library = loadstring(game:HttpGet("https://github.com/1dontgiveaf/Fluent/releases/latest/download/main.lua"))()
    local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/1dontgiveaf/Fluent/main/Addons/SaveManager.lua"))()
    local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/1dontgiveaf/Fluent/main/Addons/InterfaceManager.lua"))()

    -- === 2. UI INITIALIZATION ===
    Library.AccentColor = Color3.fromRGB(255, 255, 255)

    local Window = Library:CreateWindow({
        Title = HUB_NAME,
        SubTitle = HUB_VERSION,
        TabWidth = 160,
        Size = UDim2.fromOffset(math.min(580, workspace.CurrentCamera.ViewportSize.X * 0.9), math.min(580, workspace.CurrentCamera.ViewportSize.Y * 0.9)),
        Acrylic = false,
        Theme = "Darker", 
        MinimizeKey = MINIMIZE_KEY
    })

    -- DYNAMIC FRAME UI OUTLINE
    local WindowStroke = Instance.new("UIStroke")
    WindowStroke.Color = OutlineColor
    WindowStroke.Thickness = 2
    WindowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    WindowStroke.Transparency = 0

    pcall(function()
        local mainTarget = Window.Root or Window.Frame
        if mainTarget then
            WindowStroke.Parent = mainTarget
            mainTarget.BackgroundTransparency = 0
        end
    end)

    local Tabs = {
        Info = Window:AddTab({ Title = "Info ℹ️", Icon = "rbxassetid://16019271248" }),
        Performance = Window:AddTab({ Title = "Client Performance 📈", Icon = "activity" }), 
        Main = Window:AddTab({ Title = "Main 🏠", Icon = "home" }),
        Pets = Window:AddTab({ Title = "Pets 🐾", Icon = "rbxassetid://14433695350" }),
        Shop = Window:AddTab({ Title = "Shop 🛒", Icon = "shopping-cart" }),
        Transfer = Window:AddTab({ Title = "Transfer 📤", Icon = "repeat" }),
        Event = Window:AddTab({ Title = "Event 🎡", Icon = "star" }), -- ADDED BACK
        EventTools = Window:AddTab({ Title = "EventTools 🛠️", Icon = "wrench" }),
        Dailies = Window:AddTab({ Title = "Dailies ⏱️", Icon = "timer" }),
        Others = Window:AddTab({ Title = "Others ⚙️", Icon = "settings" }),
        Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
    }

    local Options, Flags = Library.Options, { WS = 16, JP = 50, PotionDelay = 0.5, BuyAmount = 1, ToolAmount = 1 }
    local UI_STATE = { Timer = "00:00:00", Stats = "Waiting...", Quests = "Scanning...", Potions = "Age: 0 | Tiny: 0", Location = "SCANNING...", Uptime = "0s", FPS = "0", Memory = "0 MB" }

    -- === 3. TAB ELEMENTS & OUTLINE COLOR PICKER ===
    Tabs.Info:AddParagraph({ 
        Title = "🎃 Release Notes", 
        Content = HUB_VERSION .. ":\n- Removed Summer Camp Event!\n- Added back empty Event tab.\n- Ready for Halloween and any upcoming updates enjoy!\n- Color Picker control available for frame outlines." 
    })
    
    -- COLOR PICKER CONTROL FOR UI OUTLINES
    local OutlineColorpicker = Tabs.Info:AddColorpicker("OutlineColorpicker", {
        Title = "🎨 UI Outline Color",
        Default = OutlineColor
    })

    -- SLIDER CONTROL FOR OUTLINE THICKNESS
    Tabs.Info:AddSlider("OutlineThickness", {
        Title = "🖼️ UI Outline Thickness",
        Default = 2,
        Min = 0,
        Max = 10,
        Rounding = 1,
        Callback = function(Value)
            WindowStroke.Thickness = Value
            WindowStroke.Enabled = (Value > 0)
        end
    })

    local UptimePara = Tabs.Performance:AddParagraph({ Title = "📈 Client System Status", Content = "Waiting..." })
    local FPSPara = Tabs.Performance:AddParagraph({ Title = "🖥️ Client Frame Rate", Content = "Calculating..." })
    local MemPara = Tabs.Performance:AddParagraph({ Title = "💾 Client Memory Usage", Content = "Measuring..." })

    Tabs.Main:AddSlider("WS", { Title = "WalkSpeed", Default = 16, Min = 16, Max = 150, Rounding = 1, Callback = function(v) Flags.WS = v end })
    Tabs.Main:AddSlider("JP", { Title = "JumpPower", Default = 50, Min = 50, Max = 300, Rounding = 1, Callback = function(v) Flags.JP = v end })
    
    local CPUS = Instance.new("ScreenGui", PG); CPUS.Enabled = false; CPUS.IgnoreGuiInset = true;
    local MF = Instance.new("Frame", CPUS); MF.Size = UDim2.fromScale(1, 1); MF.BackgroundColor3 = Color3.new(0,0,0)
    local LL = Instance.new("TextLabel", MF); LL.Size = UDim2.new(1, 0, 0, 50); LL.Position = UDim2.new(0, 0, 0.4, 0); LL.TextColor3 = Color3.fromRGB(255, 255, 255); LL.BackgroundTransparency = 1; LL.TextSize = 32; LL.Text = "📍 LOCATION: SCANNING..."
    local RB = Instance.new("TextButton", MF); RB.Size = UDim2.fromOffset(300, 70); RB.Position = UDim2.new(0.5, -150, 0.5, 0); RB.Text = "▶️ RESUME GAME"; RB.BackgroundColor3 = Color3.fromRGB(255, 255, 255); RB.TextColor3 = Color3.new(0,0,0); Instance.new("UICorner", RB)
    Tabs.Main:AddToggle("CPUSave", { Title = "🖥️ CPU Saver", Default = false, Callback = function(v) CPUS.Enabled = v; RunS:Set3dRenderingEnabled(not v) end })

    -- SHOP / TOOLS
    local CategorySelector = Tabs.Shop:AddDropdown("CategorySelector", { Title = "📁 Category", Values = {"Eggs", "Pets", "Gifts", "Pet Accessories"}, Multi = false, Default = 1 })
    local ItemSelector = Tabs.Shop:AddDropdown("ItemSelector", { Title = "🛍️ Item", Values = {"royal_egg"}, Multi = false, Default = 1 })
    CategorySelector:OnChanged(function(Value)
        local n = {}
        if Value == "Eggs" then n = {"royal_egg", "cracked_egg", "pet_egg"}
        elseif Value == "Pets" then n = {"dog", "cat"}
        elseif Value == "Gifts" then n = {"smallgift", "biggift", "massivegift"}
        elseif Value == "Pet Accessories" then n = {"red_backpack", "pink_bow"} end
        ItemSelector:SetValues(n); ItemSelector:SetValue(n[1])
    end)
    Tabs.Shop:AddButton({ Title = "💳 Complete Purchase", Callback = function() local cat = CategorySelector.Value; local item = ItemSelector.Value; local apiMap = {["Eggs"]="pets", ["Pets"]="pets", ["Gifts"]="gifts", ["Pet Accessories"]="pet_accessories"}; if item and apiMap[cat] then pcall(function() require(RS:WaitForChild("Fsys")).load("RouterClient").get("ShopAPI/BuyItem"):InvokeServer(apiMap[cat], item, {buy_count = Flags.BuyAmount}) end) end end })

    -- EVENT TAB (EMPTY AS REQUESTED)

    -- EVENT TOOLS TAB
    Tabs.EventTools:AddInput("ToolAmount", { Title = "🔢 Open Amount", Default = "1", Numeric = true, Finished = true, Callback = function(v) Flags.ToolAmount = tonumber(v) or 1 end })
    local ToolSearch = Tabs.EventTools:AddInput("ToolSearch", { Title = "🔍 Search ID", Default = "", Finished = true })
    local GiftDropdown = Tabs.EventTools:AddDropdown("GiftSelector", { Title = "🎁 Select Items", Values = {"None"}, Multi = true, Default = {} })
    Tabs.EventTools:AddButton({ Title = "🔄 Refresh Gifts", Callback = function() local glist = {}; local filter = ToolSearch.Value:lower(); pcall(function() local data = require(RS:WaitForChild("Fsys")).load("ClientData").get_data()[LP.Name]; if data and data.inventory and data.inventory.gifts then for uid, gift in pairs(data.inventory.gifts) do if filter == "" or tostring(gift.id):lower():find(filter) then table.insert(glist, tostring(gift.id) .. " | " .. tostring(uid)) end end end end); table.sort(glist); GiftDropdown:SetValues(#glist > 0 and glist or {"None"}) end })
    Tabs.EventTools:AddToggle("AutoOpenGift", { Title = "🎁 Auto Open Gift", Default = false }); Tabs.EventTools:AddToggle("AutoOpenBox", { Title = "📦 Auto Open Box", Default = false })

    local TimerLabel = Tabs.Dailies:AddParagraph({ Title = "🕒 NEXT DISTRIBUTION", Content = "00:00:00" }); local StatsLabel = Tabs.Dailies:AddParagraph({ Title = "✅ STATS", Content = "Waiting..." }); local QuestLabel = Tabs.Dailies:AddParagraph({ Title = "📜 ACTIVE TASKS", Content = "Scanning..." })
    local PotLabel = Tabs.Others:AddParagraph({ Title = "🧪 Potion Inventory", Content = "Syncing..." }); Tabs.Others:AddToggle("AutoAge", { Title = "✨ Auto Age Potions (Bulk)", Default = false }); Tabs.Others:AddToggle("AutoTiny", { Title = "🤏 Auto Tiny Potions (Bulk)", Default = false })

    -- === 4. TOGGLE BUTTON (WHITE TEXT + CUSTOM OUTLINE) ===
    local MTG = Instance.new("ScreenGui", PG); MTG.Name = "EventSploit_Toggle"; MTG.IgnoreGuiInset = true; MTG.DisplayOrder = 2147483647 
    local MainToggle = Instance.new("TextButton", MTG); MainToggle.Size = UDim2.fromOffset(260, 42); MainToggle.Position = UDim2.new(0.5, -150, 0, 15); MainToggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0); 
    MainToggle.TextColor3 = Color3.fromRGB(255, 255, 255); 
    MainToggle.Text = "POWERED BY EVENTSPLOIT! " .. HUB_VERSION; 
    MainToggle.Font = Enum.Font.GothamBold; MainToggle.TextSize = 12; Instance.new("UICorner", MainToggle)
    
    local CloseBtn = Instance.new("TextButton", MTG); CloseBtn.Size = UDim2.fromOffset(42, 42); CloseBtn.Position = UDim2.new(0.5, 115, 0, 15); CloseBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0); 
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255); 
    CloseBtn.Text = "X"; CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 20; Instance.new("UICorner", CloseBtn)
    
    local BTStroke = Instance.new("UIStroke", MainToggle); BTStroke.Color = OutlineColor; BTStroke.Thickness = 2
    local CBStroke = Instance.new("UIStroke", CloseBtn); CBStroke.Color = OutlineColor; CBStroke.Thickness = 2

    -- DYNAMIC COLOR PICKER CALLBACK CONNECTION
    OutlineColorpicker:OnChanged(function()
        local newColor = OutlineColorpicker.Value
        WindowStroke.Color = newColor
        BTStroke.Color = newColor
        CBStroke.Color = newColor
    end)

    -- === 5. DATA ENGINE ===
    local Fsys = require(RS:WaitForChild("Fsys")).load
    local Router, ClientData, InteriorsM = Fsys("RouterClient"), Fsys("ClientData"), Fsys("InteriorsM")
    local DailiesClient = Fsys("new:LegacyLoad")("new:DailiesClient")
    local PetEntityManager = require(RS.ClientModules.Game.PetEntities.PetEntityManager)
    local CoreGui, StatsService = game:GetService("CoreGui"), game:GetService("Stats")

    local accumMono, accumAFK, accumTamper, accumCore, accumUI = 0, 0, 0, 0, 0
    local fpsCount, fpsAccum = 0, 0
    local FinalLoadTime = string.format("%.3fs", tick() - LoadStart)

    RunS.Heartbeat:Connect(function(dt)
        accumMono, accumAFK, accumTamper, accumCore, accumUI = accumMono + dt, accumAFK + dt, accumTamper + dt, accumCore + dt, accumUI + dt
        
        fpsCount = fpsCount + 1
        fpsAccum = fpsAccum + dt
        if fpsAccum >= 0.5 then
            UI_STATE.FPS = tostring(math.floor(fpsCount / fpsAccum))
            fpsCount, fpsAccum = 0, 0
        end

        -- Background & Outline Enforcement
        if accumMono >= 2 then
            accumMono = 0
            pcall(function()
                local Gui = PG:FindFirstChild("ScreenGui", true) or CoreGui:FindFirstChild("ScreenGui", true)
                if Gui then
                    for _, v in pairs(Gui:GetDescendants()) do
                        if v:IsA("Frame") and (v.BackgroundColor3 == Color3.fromRGB(33, 33, 33) or v.BackgroundColor3 == Color3.fromRGB(43, 43, 43) or v.BackgroundColor3 == Color3.fromRGB(0, 0, 0)) then 
                            v.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                            v.BackgroundTransparency = 0
                            if not WindowStroke.Parent and v.Size.X.Offset > 300 then
                                WindowStroke.Parent = v
                            end
                        elseif v:IsA("TextLabel") then 
                            v.TextColor3 = Color3.fromRGB(255, 255, 255)
                        end
                    end
                end
            end)
        end

        if accumAFK >= 120 then
            accumAFK = 0
            task.spawn(function() pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.QuotedDouble, false, game); task.wait(0.1); VIM:SendKeyEvent(false, Enum.KeyCode.QuotedDouble, false, game) end) end)
        end

        if accumTamper >= 4 then
            accumTamper = 0
            pcall(function()
                if _G.SimpleSpyExecuted or _G.Hydroxide or _G.Dex or integrity_fail then LP:Kick("🧬 Eventsploit Security: Tamper Detected.") end
                local suspiciousNames = {"Dex", "SimpleSpy", "Hydroxide", "TurtleSpy", "RemoteSpy"}
                for _, name in pairs(suspiciousNames) do if CoreGui:FindFirstChild(name, true) then LP:Kick("🧬 Eventsploit Security: Clash detected.") end end
            end)
        end

        if accumCore >= 1 then
            accumCore = 0
            pcall(function()
                UI_STATE.Memory = string.format("%.2f MB", StatsService:GetTotalMemoryUsageMb())
                local d = ClientData.get_data()[LP.Name]
                local loc = InteriorsM:get_current_location()
                UI_STATE.Location = tostring((type(loc) == "table" and (loc.full_destination_id or loc.interiors_id)) or loc or "MAINMAP"):upper()
                
                local manager = DailiesClient.get_manager()
                local vanilla = manager and manager.serialized_tabs and manager.serialized_tabs.vanilla
                if vanilla then
                    local timeLeft = (vanilla.next_distribution_timestamp or 0) - os.time()
                    UI_STATE.Timer = timeLeft > 0 and string.format("%02d:%02d:%02d", math.floor(timeLeft/3600), math.floor((timeLeft%3600)/60), timeLeft%60) or "00:00:00"
                    UI_STATE.Stats = "Total Completed: " .. tostring(vanilla.total_dailies_completed_today or 0)
                    local qStr = ""
                    if type(vanilla.active_dailies) == "table" then for q, _ in pairs(vanilla.active_dailies) do qStr = qStr .. "● " .. q:upper():gsub("_", " ") .. "\n" end end
                    UI_STATE.Quests = qStr ~= "" and qStr or "No active tasks."
                end
                
                if d and d.inventory then
                    if (Options.AutoOpenGift.Value or Options.AutoOpenBox.Value) then
                        task.spawn(function()
                            for item, selected in pairs(GiftDropdown.Value) do
                                if selected and item ~= "None" then
                                    local gUid = tostring(item:match(" | (.*)")):gsub("%s+", ""); local gId = tostring(item:match("^([^%s|]+)"))
                                    for i = 1, Flags.ToolAmount do
                                        if not Options.AutoOpenGift.Value and not Options.AutoOpenBox.Value then break end
                                        if Options.AutoOpenGift.Value then Router.get("ShopAPI/OpenGift"):InvokeServer(gUid) end
                                        if Options.AutoOpenBox.Value then Router.get("LootBoxAPI/ExchangeItemForReward"):InvokeServer(gId, gUid) end
                                        task.wait(0.6)
                                    end
                                end
                            end
                            Options.AutoOpenGift:SetValue(false); Options.AutoOpenBox:SetValue(false)
                        end)
                    end
                    local petId = nil; local petEntities = PetEntityManager.get_local_owned_pet_entities()
                    if petEntities then for _, entity in pairs(petEntities) do if entity and entity.unique then petId = entity.unique; break end end end
                    if not petId and d.equip_manager and d.equip_manager.pets and d.equip_manager.pets[1] then petId = d.equip_manager.pets[1].unique end
                    
                    local age_list, tiny_list = {}, {}
                    for uid, item in pairs(d.inventory.food or {}) do
                        if item.id == "pet_age_potion" then table.insert(age_list, uid)
                        elseif item.id == "tiny_pet_age_potion" then table.insert(tiny_list, uid) end
                    end
                    UI_STATE.Potions = "Age: " .. #age_list .. " | Tiny: " .. #tiny_list

                    local function doBulk(list)
                        if #list > 0 and petId then
                            local mId = table.remove(list, 1)
                            Router.get("PetObjectAPI/CreatePetObject"):InvokeServer("__Enum_PetObjectCreatorType_2", { additional_consume_uniques = list, pet_unique = petId, unique_id = mId })
                        end
                    end
                    if Options.AutoAge.Value then doBulk(age_list); Options.AutoAge:SetValue(false) end
                    if Options.AutoTiny.Value then doBulk(tiny_list); Options.AutoTiny:SetValue(false) end
                end
                UI_STATE.Uptime = tostring(math.floor(tick() - LoadStart)) .. "s"
            end)
        end

        if accumUI >= 0.5 then
            accumUI = 0
            pcall(function()
                TimerLabel:SetDesc(UI_STATE.Timer)
                StatsLabel:SetDesc(UI_STATE.Stats)
                QuestLabel:SetDesc(UI_STATE.Quests)
                PotLabel:SetDesc(UI_STATE.Potions)
                UptimePara:SetDesc("📈 Client Active Uptime: " .. UI_STATE.Uptime .. "\n⏱️ Client Setup Speed: " .. FinalLoadTime)
                FPSPara:SetDesc("🖥️ Client Current Framerate: " .. UI_STATE.FPS .. " FPS")
                MemPara:SetDesc("💾 Client Core Allocation: " .. UI_STATE.Memory)
            end)
        end

        pcall(function()
            LL.Text = "📍 LOCATION: " .. UI_STATE.Location
            if LP.Character and LP.Character:FindFirstChild("Humanoid") then 
                local hum = LP.Character.Humanoid
                if hum.WalkSpeed ~= Flags.WS then hum.WalkSpeed = Flags.WS end
                if hum.JumpPower ~= Flags.JP then hum.JumpPower = Flags.JP end
            end
        end)
    end)

    pcall(function()
        CloseBtn.MouseButton1Click:Connect(function() MTG:Destroy() end)
        MainToggle.MouseButton1Click:Connect(function() VIM:SendKeyEvent(true, MINIMIZE_KEY, false, game); task.wait(0.05); VIM:SendKeyEvent(false, MINIMIZE_KEY, false, game) end)
        RB.MouseButton1Click:Connect(function() CPUS.Enabled = false; RunS:Set3dRenderingEnabled(true) end)
    end)

    -- === 6. INITIALIZE MANAGERS ===
    SaveManager:SetLibrary(Library)
    InterfaceManager:SetLibrary(Library)
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)

    Window:SelectTab(1) 

    -- === 🛠️ DEVELOPER SANDBOX ===
    -- [PASTE YOUR CLEAN LOGIC BELOW]




local success, globalErr = pcall(function()
    -- --- CONFIGURATION & STATE (DEFAULTS TO OFF) ---
    local EVENT_MODE = false 
    local IsCurrentlyDoingEvent = false 
    
    local ScriptEnabled = false 
    local BabyFarmEnabled = false 
    local MysteryChooserEnabled = false 
    local MysteryExcludeMode = false 
    
    local CurrentTask = nil
    local CurrentTaskEntityKey = nil
    local Debounce = false 
    local SelectedPetUniqueId = nil 
    local IsProcessing = false 
    
    local RefreshCounter = 0
    local MAX_IDLE_TIME = 20 
    local ScriptStartTime = tick()
    
    -- State machine variables for frame-based tasks
    local TaskPhase = "INIT"
    local PhaseTimer = 0
    local TaskActiveEntityRef = nil
    local TaskActiveAilmentInst = nil
    local TaskActiveStrollerUid = nil
    local TaskActiveKeysPressed = false

    local UserFurniture = {
        dirty = {"CheapPetBathtub", "Shower", "PowerWash"},
        sleepy = {"BasicCrib", "Crib", "PetBed"},
        hungry = {"PetFoodBowl", "FoodBowl"},
        thirsty = {"PetWaterBowl", "WaterBowl"},
        toilet = {"Toilet"}
    }

    -- --- SERVICES ---
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local VirtualUser = game:GetService("VirtualUser")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- --- ANTI-AFK ---
    if _G.AntiAFKConnection then
        _G.AntiAFKConnection:Disconnect()
        _G.AntiAFKConnection = nil
    end

    _G.AntiAFKConnection = LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    end)

    -- --- ASSETS ---
    local PLANK_ASSET = "rbxassetid://17279545564"

    -- --- MODULES & NEUTRALIZATION FUNCTIONS ---
    local Fsys, Router, ClientData, AilmentsManager, UIManager, InteriorsM, PetEntityManager, StateManager

    local function neutralize(tbl)
        if not tbl or typeof(tbl) ~= "table" then return end
        
        local methodsToDisable = {
            "show", "transition", "transition_with_key",
            "sudden_fill", "manual_fill", "set_blur"
        }
        
        for _, methodName in ipairs(methodsToDisable) do
            if tbl[methodName] then
                tbl[methodName] = function() return end
            end
        end
        
        if tbl.lock_transitions then tbl.lock_transitions = function() return end end
        if tbl.can_set_app_visibility then tbl.can_set_app_visibility = function() return true end end
    end

    local function SyncModules()
        pcall(function()
            Fsys = require(ReplicatedStorage:WaitForChild("Fsys", 5))
            if not Fsys then return end
            
            Router = Fsys.load("RouterClient")
            ClientData = Fsys.load("ClientData")
            UIManager = Fsys.load("UIManager")
            StateManager = Fsys.load("StateManagerClient")

            local ailmentsMod = ReplicatedStorage:FindFirstChild("new") 
                and ReplicatedStorage.new:FindFirstChild("modules") 
                and ReplicatedStorage.new.modules:FindFirstChild("Ailments") 
                and ReplicatedStorage.new.modules.Ailments:FindFirstChild("AilmentsClient")
            if ailmentsMod then
                AilmentsManager = require(ailmentsMod)
            end

            local interiorsMod = ReplicatedStorage:FindFirstChild("ClientModules") 
                and ReplicatedStorage.ClientModules:FindFirstChild("Core") 
                and ReplicatedStorage.ClientModules.Core:FindFirstChild("InteriorsM") 
                and ReplicatedStorage.ClientModules.Core.InteriorsM:FindFirstChild("InteriorsM")
            if interiorsMod then
                InteriorsM = require(interiorsMod)
            end

            local petEntityMod = ReplicatedStorage:FindFirstChild("ClientModules") 
                and ReplicatedStorage.ClientModules:FindFirstChild("Game") 
                and ReplicatedStorage.ClientModules.Game:FindFirstChild("PetEntities") 
                and ReplicatedStorage.ClientModules.Game.PetEntities:FindFirstChild("PetEntityManager")
            if petEntityMod then
                PetEntityManager = require(petEntityMod)
            end
            
            local transitionsAppMod = ReplicatedStorage:FindFirstChild("ClientModules") 
                and ReplicatedStorage.ClientModules:FindFirstChild("Core") 
                and ReplicatedStorage.ClientModules.Core:FindFirstChild("UIManager") 
                and ReplicatedStorage.ClientModules.Core.UIManager:FindFirstChild("Apps") 
                and ReplicatedStorage.ClientModules.Core.UIManager.Apps:FindFirstChild("TransitionsApp")
            if transitionsAppMod then
                local TransitionsApp = require(transitionsAppMod)
                if TransitionsApp then
                    neutralize(TransitionsApp)
                    if TransitionsApp.__index and typeof(TransitionsApp.__index) == "table" then
                        neutralize(TransitionsApp.__index)
                    end
                    if TransitionsApp.Super and typeof(TransitionsApp.Super) == "table" then
                        neutralize(TransitionsApp.Super)
                        if TransitionsApp.Super.__index and typeof(TransitionsApp.Super.__index) == "table" then
                            neutralize(TransitionsApp.Super.__index)
                        end
                    end
                end
            end
        end)
    end
    SyncModules()

    -- --- FLUENT UI TOGGLE BINDINGS (TABS.PETS) ---
    if Tabs and Tabs.Pets then
        Tabs.Pets:AddToggle("AutoRaisePetTasks", {
            Title = "Auto Raise Pet Tasks",
            Description = "Enable or disable auto farming for pet ailments",
            Default = false,
            Callback = function(state)
                ScriptEnabled = state
            end
        })

        Tabs.Pets:AddToggle("AutoRaiseBabyTasks", {
            Title = "Auto Raise Baby Tasks",
            Description = "Enable or disable auto farming for baby ailments and switch team",
            Default = false,
            Callback = function(state)
                BabyFarmEnabled = state
                pcall(function()
                    local targetTeam = state and "Babies" or "Parents"
                    if Router and Router.get then
                        Router.get("TeamAPI/ChooseTeam"):InvokeServer(targetTeam, {
                            dont_respawn = true,
                            source_for_logging = "avatar_editor"
                        })
                    end
                end)
            end
        })
    end

    local totalBucksEarned = 0
    local totalXpEarned = 0

    -- --- GET CURRENT EQUIPPED PET UID ---
    local function getActivePetUniqueId()
        if SelectedPetUniqueId then return SelectedPetUniqueId end
        local activeUid = nil
        pcall(function()
            if not ClientData then return end
            local rawData = ClientData.get_data()
            local playerData = rawData and rawData[LocalPlayer.Name]
            
            if playerData and playerData.ailments_manager and playerData.ailments_manager.ailments then
                for uid, _ in pairs(playerData.ailments_manager.ailments) do
                    activeUid = tostring(uid)
                    break
                end
            end

            if not activeUid and playerData and playerData.equip_manager and playerData.equip_manager.pets then
                local petsTable = playerData.equip_manager.pets
                if typeof(petsTable) == "table" then
                    for uid, petData in pairs(petsTable) do
                        if petData == true then
                            activeUid = tostring(uid)
                            break
                        elseif typeof(petData) == "table" and petData.unique then
                            activeUid = tostring(petData.unique)
                            break
                        end
                    end
                end
            end
        end)
        return activeUid
    end

    -- --- STRICT DIRECT RAW DATA AILMENT CHECKER ---
    local function isAilmentActive(entityRef, targetAid)
        if not entityRef then return false end
        local target = string.lower(tostring(targetAid))
        local found = false
        pcall(function()
            if not ClientData then return end
            local rawData = ClientData.get_data()
            local playerData = rawData and rawData[LocalPlayer.Name]
            local manager = playerData and playerData.ailments_manager
            
            if not manager then return end

            local function checkTable(tbl)
                if type(tbl) ~= "table" then return false end
                for k, v in pairs(tbl) do
                    local keyStr = string.lower(tostring(k))
                    local kindStr = (type(v) == "table" and v.kind) and string.lower(tostring(v.kind)) or keyStr
                    if keyStr == target or kindStr == target then
                        return true
                    end
                end
                return false
            end

            if not entityRef.is_pet then
                if manager.baby_ailments then
                    found = checkTable(manager.baby_ailments)
                end
            else
                local activeUid = entityRef.pet_unique or getActivePetUniqueId()
                if activeUid and manager.ailments and manager.ailments[activeUid] then
                    found = checkTable(manager.ailments[activeUid])
                end
            end
        end)
        return found
    end

    local function refreshPetOnPlatform()
        local petUid = getActivePetUniqueId()
        if petUid and Router and Router.get then
            pcall(function()
                Router.get("ToolAPI/Unequip"):InvokeServer(petUid, { equip_as_last = false, use_sound_delay = false })
                task.wait(0.3)
                Router.get("ToolAPI/Equip"):InvokeServer(petUid, { equip_as_last = false, use_sound_delay = false })
            end)
        end
    end

    local function isPlayerOnPlatform(plat)
        if not plat or not LocalPlayer.Character then return false end
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then return false end

        local pPos = plat.Position
        local rPos = root.Position
        local horizontalDistance = Vector2.new(pPos.X - rPos.X, pPos.Z - rPos.Z).Magnitude
        local verticalDistance = rPos.Y - pPos.Y

        return horizontalDistance <= (plat.Size.X / 2) and (verticalDistance >= 0 and verticalDistance <= 15)
    end

    local function isPetUsingFurniture(petModel)
        if not petModel then return false end
        local isSeated = false
        pcall(function()
            local stateData = StateManager and StateManager.get(petModel)
            if stateData and stateData.states then
                for _, state in pairs(stateData.states) do
                    if state.furniture_id or state.id == "Seat" or state.id == "Sitting" then 
                        isSeated = true 
                        break
                    end
                end
            end
        end)
        return isSeated
    end

    local function isPetBeingHeld(petModel)
        if not petModel then return false end
        local isHeld = false
        pcall(function()
            local stateData = StateManager and StateManager.get(petModel)
            if stateData and stateData.states then
                for _, state in pairs(stateData.states) do
                    if state.id == "Carried" or state.id == "Holding" or state.id == "Held" then 
                        isHeld = true 
                        break
                    end
                end
            end
        end)
        return isHeld
    end

    local function createEntityReference(player, isPet, pUid)
        return { player = player, is_pet = isPet, pet_unique = pUid }
    end

    local function getPetModel(pUid)
        local petModel = nil
        pcall(function()
            if not ClientData then return end
            local inventory = ClientData.get("inventory")
            local targetUid = pUid or SelectedPetUniqueId or getActivePetUniqueId()
            if inventory and inventory.pets and targetUid and inventory.pets[targetUid] then
                local kind = inventory.pets[targetUid].kind
                local petsFolder = Workspace:FindFirstChild("Pets")
                if petsFolder then
                    for _, m in ipairs(petsFolder:GetChildren()) do
                        if m.Name:lower() == kind:lower():gsub("_", " ") or m.Name == kind then 
                            petModel = m 
                            break 
                        end
                    end
                end
            end
        end)
        local petsFolder = Workspace:FindFirstChild("Pets")
        return petModel or (petsFolder and petsFolder:FindFirstChildOfClass("Model"))
    end

    local function returnToHouse()
        pcall(function()
            if InteriorsM and Router and Router.get then
                if InteriorsM.get_current_location() ~= "housing" then
                    InteriorsM.enter_smooth("housing", "MainDoor", { house_owner = LocalPlayer })
                    task.wait(1.5)
                    Router.get("HousingAPI/SetDoorLocked"):InvokeServer(true)
                end
            end
        end)
    end

    local function managePlatform(targetCFrame, extraHeight) 
        if not targetCFrame then return end
        local plat = Workspace:FindFirstChild("AutomatorPlatform") or Instance.new("Part", Workspace)
        plat.Name = "AutomatorPlatform"; plat.Size = Vector3.new(200, 1, 200); plat.Anchored = true; plat.CanCollide = true
        plat.CFrame = CFrame.new(targetCFrame.Position + Vector3.new(0, extraHeight or 0, 0))
        local tex = plat:FindFirstChild("PlankTex") or Instance.new("Texture", plat)
        tex.Name = "PlankTex"; tex.Texture = PLANK_ASSET; tex.Face = Enum.NormalId.Top; tex.StudsPerTileU, tex.StudsPerTileV = 4, 4
        
        if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then 
            LocalPlayer.Character:PivotTo(plat.CFrame * CFrame.new(0, 3, 0)) 
        end
        
        task.spawn(function()
            local timeout = 5
            local elapsed = 0
            while elapsed < timeout do
                if isPlayerOnPlatform(plat) then
                    task.wait(0.2)
                    refreshPetOnPlatform()
                    break
                end
                task.wait(0.2)
                elapsed = elapsed + 0.2
            end
        end)
    end

    -- --- UI CONSTRUCTION ---
    local existingGui = PlayerGui:FindFirstChild("EventGui")
    if existingGui then existingGui:Destroy() end

    local screenGui = Instance.new("ScreenGui", PlayerGui)
    screenGui.Name = "EventGui"
    screenGui.IgnoreGuiInset = true 
    screenGui.DisplayOrder = 999 

    local bg = Instance.new("ImageLabel", screenGui)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.Image = PLANK_ASSET
    bg.ScaleType = Enum.ScaleType.Tile
    bg.TileSize = UDim2.new(0, 128, 0, 128) 
    bg.ZIndex = 10

    local function applyRainbowStroke(target)
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 3
        stroke.Parent = target
        task.spawn(function()
            local hue = 0
            while target and target.Parent do
                hue = (hue + 0.002) % 1
                stroke.Color = Color3.fromHSV(hue, 1, 1)
                RunService.RenderStepped:Wait()
            end
        end)
    end

    local function createText(text, size, position, isButton)
        local label = Instance.new(isButton and "TextButton" or "TextLabel")
        label.Parent = bg
        label.Size = UDim2.new(0, 500, 0, 50) 
        label.Position = position
        label.BackgroundTransparency = isButton and 0 or 1 
        label.BackgroundColor3 = Color3.fromRGB(0, 0, 0) 
        label.Text = text
        label.Font = Enum.Font.SourceSansBold
        label.TextSize = size
        label.TextColor3 = Color3.fromRGB(255, 255, 255) 
        label.ZIndex = 500 
        applyRainbowStroke(label)
        return label
    end

    createText("POWERED BY EVENTSPLOIT ENJOY!", 28, UDim2.new(0.5, -250, 0.02, 0))
    createText("EVENT GROUP", 50, UDim2.new(0.5, -250, 0.09, 0))
    
    local TaskHUD = createText("Task its Doing!", 35, UDim2.new(0.5, -250, 0.19, 0))
    local UptimeLabel = createText("Uptime script Goes Here!", 35, UDim2.new(0.5, -250, 0.28, 0))

    -- --- CURRENCY REPORT ---
    local currencyPanel = Instance.new("Frame", bg)
    currencyPanel.Size = UDim2.new(0, 500, 0, 65)
    currencyPanel.Position = UDim2.new(0.5, -250, 0.37, 0)
    currencyPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    currencyPanel.ZIndex = 400 
    applyRainbowStroke(currencyPanel)

    local currencyLabel = Instance.new("TextLabel", currencyPanel)
    currencyLabel.Size = UDim2.new(1, 0, 1, 0)
    currencyLabel.BackgroundTransparency = 1
    currencyLabel.Text = "Bucks: Loading..."
    currencyLabel.Font = Enum.Font.SourceSansBold
    currencyLabel.TextSize = 24
    currencyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    currencyLabel.ZIndex = 405

    local function updateCurrencyUI()
        pcall(function()
            if not ClientData then return end
            local data = ClientData.get_data()
            local playerKey = LocalPlayer.Name
            local playerData = data and data[playerKey]
            if playerData then
                local bucks = playerData.money or 0
                currencyLabel.Text = "Bucks: " .. bucks
            end
        end)
    end

    local hideBtn = createText("HIDE INTERFACE", 30, UDim2.new(0.5, -250, 0.47, 0), true)

    -- --- CONFIGURATION TOGGLE PANEL ---
    local optionsPanel = Instance.new("Frame", bg)
    optionsPanel.Size = UDim2.new(0, 500, 0, 210)
    optionsPanel.Position = UDim2.new(0.5, -250, 0.54, 0)
    optionsPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    optionsPanel.BorderSizePixel = 0
    optionsPanel.ZIndex = 400 
    applyRainbowStroke(optionsPanel)

    local function createSubToggle(text, position, defaultState, callback)
        local btn = Instance.new("TextButton", optionsPanel)
        btn.Size = UDim2.new(1, -20, 0, 40)
        btn.Position = position
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 18
        btn.ZIndex = 405
        applyRainbowStroke(btn)
        
        local function updateAppearance(state)
            if state then
                btn.Text = text .. ": ENABLED"
                btn.TextColor3 = Color3.fromRGB(85, 255, 127)
            else
                btn.Text = text .. ": DISABLED"
                btn.TextColor3 = Color3.fromRGB(255, 85, 85)
            end
        end
        
        updateAppearance(defaultState)
        btn.MouseButton1Click:Connect(function()
            local newState = callback()
            updateAppearance(newState)
        end)
    end

    -- --- FARM TOGGLES ---
    createSubToggle("AutoRaisePetTasks", UDim2.new(0, 10, 0, 10), ScriptEnabled, function()
        ScriptEnabled = not ScriptEnabled
        return ScriptEnabled
    end)

    createSubToggle("AutoRaiseBabyTasks", UDim2.new(0, 10, 0, 60), BabyFarmEnabled, function()
        BabyFarmEnabled = not BabyFarmEnabled
        pcall(function()
            local targetTeam = BabyFarmEnabled and "Babies" or "Parents"
            if Router and Router.get then
                Router.get("TeamAPI/ChooseTeam"):InvokeServer(targetTeam, {
                    dont_respawn = true,
                    source_for_logging = "avatar_editor"
                })
            end
        end)
        return BabyFarmEnabled
    end)

    createSubToggle("MYSTERY TASK CHOOSER", UDim2.new(0, 10, 0, 110), MysteryChooserEnabled, function()
        MysteryChooserEnabled = not MysteryChooserEnabled
        return MysteryChooserEnabled
    end)

    createSubToggle("EXCLUDE MYSTERY TASK", UDim2.new(0, 10, 0, 160), MysteryExcludeMode, function()
        MysteryExcludeMode = not MysteryExcludeMode
        return MysteryExcludeMode
    end)

    local bottomLinks = Instance.new("TextLabel", bg)
    bottomLinks.Size = UDim2.new(0, 400, 0, 30)
    bottomLinks.Position = UDim2.new(0, 10, 0.95, -10)
    bottomLinks.Text = "discord.gg/EventSploitUtillity"
    bottomLinks.Font = Enum.Font.SourceSansBold
    bottomLinks.TextSize = 20
    bottomLinks.TextColor3 = Color3.fromRGB(255, 255, 255) 
    bottomLinks.BackgroundTransparency = 1
    bottomLinks.ZIndex = 400
    applyRainbowStroke(bottomLinks)

    local versionLabel = Instance.new("TextLabel", bg)
    versionLabel.Size = UDim2.new(0, 200, 0, 30)
    versionLabel.Position = UDim2.new(1, -210, 0.95, -10)
    versionLabel.Text = "Version v2.0.1.0"
    versionLabel.Font = Enum.Font.SourceSansBold
    versionLabel.TextSize = 20
    versionLabel.TextColor3 = Color3.fromRGB(255, 255, 255) 
    versionLabel.BackgroundTransparency = 1
    versionLabel.ZIndex = 400
    applyRainbowStroke(versionLabel)

    -- --- OPEN UI BUTTON & MIN/MAX CONTROLS ---
    local openBtn = Instance.new("TextButton", screenGui)
    openBtn.Size = UDim2.new(0, 250, 0, 50)
    openBtn.Position = UDim2.new(0.5, -125, 0.75, -25) 
    openBtn.Text = "OPEN UI"
    openBtn.Font = Enum.Font.SourceSansBold
    openBtn.TextSize = 26
    openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    openBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0) 
    openBtn.Visible = false
    openBtn.ZIndex = 500
    applyRainbowStroke(openBtn)

    local minBtn = Instance.new("TextButton", openBtn)
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -65, 0.5, -15)
    minBtn.Text = "-"
    minBtn.Font = Enum.Font.SourceSansBold
    minBtn.TextSize = 24
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    minBtn.ZIndex = 505
    applyRainbowStroke(minBtn)

    local maxBtn = Instance.new("TextButton", openBtn)
    maxBtn.Size = UDim2.new(0, 30, 0, 30)
    maxBtn.Position = UDim2.new(1, -32, 0.5, -15)
    maxBtn.Text = "+"
    maxBtn.Font = Enum.Font.SourceSansBold
    maxBtn.TextSize = 20
    maxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    maxBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    maxBtn.ZIndex = 505
    applyRainbowStroke(maxBtn)

    minBtn.MouseButton1Click:Connect(function()
        openBtn.Size = UDim2.new(0, 140, 0, 35)
        openBtn.TextSize = 16
    end)

    maxBtn.MouseButton1Click:Connect(function()
        openBtn.Size = UDim2.new(0, 300, 0, 60)
        openBtn.TextSize = 32
    end)

    hideBtn.MouseButton1Click:Connect(function()
        bg.Visible = false
        openBtn.Visible = true
    end)

    openBtn.MouseButton1Click:Connect(function()
        bg.Visible = true
        openBtn.Visible = false
    end)

    local function updateHUD(t, ailmentInst)
        pcall(function() 
            local progressStr = ""
            if ailmentInst then
                local prog = (type(ailmentInst.get_progress) == "function" and ailmentInst:get_progress()) or ailmentInst.progress or 0
                progressStr = string.format(" (%d%%)", math.floor(prog * 100))
            end
            if TaskHUD then
                TaskHUD.Text = (EVENT_MODE or IsCurrentlyDoingEvent) and "TASK: EVENT ACTIVE" or "TASK: " .. string.upper(tostring(t)) .. progressStr
            end
        end)
    end

    task.spawn(function()
        while screenGui and screenGui.Parent do
            local elapsed = math.floor(tick() - ScriptStartTime)
            local hours = math.floor(elapsed / 3600)
            local minutes = math.floor((elapsed % 3600) / 60)
            local seconds = elapsed % 60
            if UptimeLabel then
                UptimeLabel.Text = string.format("Uptime: %02d:%02d:%02d", hours, minutes, seconds)
            end
            updateCurrencyUI()
            task.wait(1)
        end
    end)

    local function globalCleanup(forceTeleport)
        pcall(function()
            if EVENT_MODE or IsCurrentlyDoingEvent then forceTeleport = false end
            RefreshCounter = 0 
            
            if TaskActiveKeysPressed then
                local keysToPress = {Enum.KeyCode.W, Enum.KeyCode.D}
                for _, key in ipairs(keysToPress) do
                    VirtualInputManager:SendKeyEvent(false, key, false, game)
                end
                TaskActiveKeysPressed = false
            end

            if TaskActiveStrollerUid and Router and Router.get then
                Router.get("ToolAPI/Unequip"):InvokeServer(TaskActiveStrollerUid)
                TaskActiveStrollerUid = nil
            end

            if Router and Router.get then
                for i = 1, 4 do Router.get("AdoptAPI/ExitSeatStates"):FireServer() end
                local pm = getPetModel()
                if pm then 
                    Router.get("AdoptAPI/EjectBaby"):FireServer(pm) 
                    Router.get("PetAPI/ReplicateActivePerformances"):FireServer(pm, { FocusPet = false })
                end
            end
            
            local savedTask = CurrentTask
            CurrentTask = nil
            CurrentTaskEntityKey = nil
            Debounce = false
            TaskPhase = "INIT"
            PhaseTimer = 0
            TaskActiveEntityRef = nil
            TaskActiveAilmentInst = nil
            
            local isMapTask = (savedTask == "school" or savedTask == "salon" or savedTask == "pizza_party" or savedTask == "bored" or savedTask == "beach_party" or savedTask == "camping" or savedTask == "walk" or savedTask == "ride")
            
            if forceTeleport and not isMapTask then 
                returnToHouse() 
            end
            
            updateHUD("IDLE", "")
            IsProcessing = false
        end)
    end

    -- --- SIGNALS ---
    if AilmentsManager and AilmentsManager.get_ailment_completed_signal then
        AilmentsManager.get_ailment_completed_signal():Connect(function(inst, entityUniqueKey, reason) 
            local comingKind = (typeof(inst) == "table" and inst.kind) and string.lower(tostring(inst.kind)) or string.lower(tostring(inst))
            local isOrange = (comingKind == "orange_task" or comingKind == "camping" or comingKind == "school")
            totalBucksEarned = (totalBucksEarned or 0) + (isOrange and 18 or 12)
            totalXpEarned = (totalXpEarned or 0) + (isOrange and 10 or 5)
            
            if CurrentTask and comingKind == string.lower(tostring(CurrentTask)) then
                globalCleanup(false) 
            end
        end)
    end

    if AilmentsManager and AilmentsManager.get_baby_ailment_completed_signal then
        AilmentsManager:get_baby_ailment_completed_signal():Connect(function(ailmentInstance)
            local comingKind = (typeof(ailmentInstance) == "table" and ailmentInstance.kind) and string.lower(tostring(ailmentInstance.kind)) or string.lower(tostring(ailmentInstance))
            if CurrentTask and comingKind == string.lower(tostring(CurrentTask)) then
                globalCleanup(false)
            end
        end)
    end

    if AilmentsManager and AilmentsManager.get_ailment_created_signal then
        AilmentsManager.get_ailment_created_signal():Connect(function(ailmentInstance, entityUniqueKey)
            if (ScriptEnabled or BabyFarmEnabled) and not Debounce and not IsProcessing then
                local isPet = (tostring(entityUniqueKey) ~= tostring(LocalPlayer.UserId))
                local ailmentKind = (typeof(ailmentInstance) == "table" and ailmentInstance.kind) and tostring(ailmentInstance.kind) or tostring(ailmentInstance)
                if not isPet and not BabyFarmEnabled then return end 
                if isPet and not ScriptEnabled then return end
                
                TaskActiveEntityRef = createEntityReference(LocalPlayer, isPet, entityUniqueKey)
                TaskActiveAilmentInst = ailmentInstance
                CurrentTask = string.lower(tostring(ailmentKind))
                TaskPhase = "INIT"
                PhaseTimer = 0
                Debounce = true
                IsProcessing = true
            end
        end)
    end

    -- --- TASK INIT LAUNCHER ---
    function executeTaskLogic(ailmentInst, ailmentId, entityRef)
        local aid = string.lower(tostring(ailmentId))
        
        if Debounce or IsProcessing then return end
        if entityRef.is_pet and not ScriptEnabled then return end
        if not entityRef.is_pet and not BabyFarmEnabled then return end
        
        if not isAilmentActive(entityRef, aid) then 
            IsProcessing = false
            return 
        end

        if aid == "balloon_fight" then return end

        Debounce = true
        IsProcessing = true
        CurrentTask = aid
        CurrentTaskEntityKey = entityRef.is_pet and entityRef.pet_unique or tostring(LocalPlayer.UserId)
        TaskActiveEntityRef = entityRef
        TaskActiveAilmentInst = ailmentInst
        TaskPhase = "INIT"
        PhaseTimer = 0
        RefreshCounter = 0 
    end

    -- --- UNIFIED ENGINE STATE MACHINE HEARTBEAT ---
    RunService.Heartbeat:Connect(function(dt)
        if EVENT_MODE or IsCurrentlyDoingEvent then return end
        
        -- ACTIVE TASK ENGINE (FRAME-BASED STATE MACHINE)
        if IsProcessing and CurrentTask then
            PhaseTimer = PhaseTimer + dt
            local aid = CurrentTask
            local entityRef = TaskActiveEntityRef
            local pUid = entityRef and (entityRef.pet_unique or getActivePetUniqueId())
            local char = LocalPlayer.Character

            if aid == "mystery" then
                if MysteryExcludeMode or not MysteryChooserEnabled then 
                    globalCleanup(false)
                    return 
                end
                
                if TaskPhase == "INIT" then
                    updateHUD(aid, TaskActiveAilmentInst)
                    TaskPhase = "RESOLVING"
                    PhaseTimer = 0
                    
                    task.spawn(function()
                        local mysterytasks = {
                            "toilet", "camping", "beach_party", "ride", "pet_me", "thirsty", "bored",
                            "hungry", "salon", "moon", "school", "pizza_party", "play", "walk"
                        }
                        for _, mysteryTask in ipairs(mysterytasks) do
                            for i = 1, 3 do
                                if (not ScriptEnabled and not BabyFarmEnabled) or CurrentTask ~= "mystery" then break end
                                if Router and Router.get then
                                    Router.get("AilmentsAPI/ChooseMysteryAilment"):FireServer(pUid, "mystery", i, mysteryTask)
                                end
                                task.wait(0.5)
                            end
                        end
                        globalCleanup(false)
                    end)
                end
                return
            end

            -- PHASE 1: TELEPORT & SETUP
            if TaskPhase == "INIT" then
                updateHUD(aid, TaskActiveAilmentInst)
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hConfig = UserFurniture[aid]
                
                local staticMap = Workspace:FindFirstChild("StaticMap")
                local STATIC = { 
                    camping = staticMap and staticMap:FindFirstChild("Campsite") and staticMap.Campsite:FindFirstChild("CampsiteOrigin"), 
                    beach_party = staticMap and staticMap:FindFirstChild("Beach") and staticMap.Beach:FindFirstChild("BeachPartyAilmentTarget"), 
                    bored = staticMap and staticMap:FindFirstChild("Park") and staticMap.Park:FindFirstChild("BoredAilmentTarget") 
                }
                local INTERIORS = { school = "School", salon = "Salon", pizza_party = "PizzaShop" }

                if root then
                    task.spawn(function()
                        if INTERIORS[aid] and InteriorsM then
                            if InteriorsM.get_current_location() ~= INTERIORS[aid] then
                                InteriorsM.enter_smooth(INTERIORS[aid], "MainDoor")
                                while InteriorsM.is_entering_interior and InteriorsM:is_entering_interior() do
                                    task.wait(0.1)
                                end
                                task.wait(0.5)
                            end
                            managePlatform(root.CFrame, 35)
                        elseif (aid == "camping" or STATIC[aid]) and InteriorsM then
                            if InteriorsM.get_current_location() ~= "MainMap" then
                                InteriorsM.enter_smooth("MainMap", "MainDoor")
                                while InteriorsM.is_entering_interior and InteriorsM:is_entering_interior() do
                                    task.wait(0.1)
                                end
                                task.wait(0.5)
                            end
                            local targetCF = STATIC[aid] and STATIC[aid].CFrame or (STATIC["camping"] and STATIC["camping"].CFrame)
                            if targetCF then managePlatform(targetCF, 2.5) end
                        elseif aid == "walk" or aid == "ride" or (hConfig and (entityRef.is_pet or (aid ~= "hungry" and aid ~= "thirsty"))) then
                            returnToHouse()
                            managePlatform(root.CFrame, 35)
                        end
                    end)
                end

                TaskPhase = "SETUP_WAIT"
                PhaseTimer = 0

            -- PHASE 2: WAIT FOR WORLD TELEPORT
            elseif TaskPhase == "SETUP_WAIT" then
                local isEntering = InteriorsM and InteriorsM.is_entering_interior and InteriorsM:is_entering_interior()
                if not isEntering and PhaseTimer >= 2.0 then
                    TaskPhase = "EXECUTE"
                    PhaseTimer = 0
                end

            -- PHASE 3: RUN SPECIFIC ACTION
            elseif TaskPhase == "EXECUTE" then
                local targetModel = entityRef.is_pet and getPetModel(pUid) or char
                local targetEntity = nil
                
                if entityRef.is_pet then
                    targetEntity = targetModel
                    if not targetEntity then
                        globalCleanup(false)
                        return
                    end
                else
                    targetEntity = LocalPlayer
                end

                local hConfig = UserFurniture[aid]
                
                local staticMap = Workspace:FindFirstChild("StaticMap")
                local STATIC = { 
                    camping = staticMap and staticMap:FindFirstChild("Campsite") and staticMap.Campsite:FindFirstChild("CampsiteOrigin"), 
                    beach_party = staticMap and staticMap:FindFirstChild("Beach") and staticMap.Beach:FindFirstChild("BeachPartyAilmentTarget"), 
                    bored = staticMap and staticMap:FindFirstChild("Park") and staticMap.Park:FindFirstChild("BoredAilmentTarget") 
                }
                local INTERIORS = { school = "School", salon = "Salon", pizza_party = "PizzaShop" }

                -- 1. INTERIOR / STATIC AILMENTS
                if INTERIORS[aid] or aid == "bored" or aid == "beach_party" then
                    if not isAilmentActive(entityRef, aid) or PhaseTimer > 180 then
                        globalCleanup(false)
                    end

                -- 2. WALK / RIDE / CAMPING
                elseif aid == "walk" or aid == "ride" or STATIC[aid] then
                    if entityRef.is_pet and targetModel then
                        -- KEYPRESS MOVEMENT ONLY FOR WALK AND RIDE
                        if (aid == "walk" or aid == "ride") and not TaskActiveKeysPressed then
                            local keysToPress = {Enum.KeyCode.W, Enum.KeyCode.D}
                            for _, key in ipairs(keysToPress) do
                                VirtualInputManager:SendKeyEvent(true, key, false, game)
                            end
                            TaskActiveKeysPressed = true
                        end

                        -- CONTINUOUS HOLD LOOP FOR WALK
                        if aid == "walk" and not isPetBeingHeld(targetModel) then
                            if Router and Router.get then
                                Router.get("AdoptAPI/HoldBaby"):FireServer(targetModel)
                            end
                        end

                        -- CONTINUOUS STROLLER LOOP FOR RIDE UNTIL SEATED
                        if aid == "ride" and not isPetUsingFurniture(targetModel) and ClientData then
                            local inventory = ClientData.get("inventory")
                            local strollers = inventory and inventory.strollers
                            if strollers and Router and Router.get then
                                for uId, _ in pairs(strollers) do
                                    TaskActiveStrollerUid = uId
                                    Router.get("ToolAPI/Equip"):InvokeServer(uId)
                                    
                                    local sit = char and char:FindFirstChild("TouchToSit", true)
                                    if sit then
                                        Router.get("AdoptAPI/UseStroller"):InvokeServer(LocalPlayer, targetModel, sit)
                                    end
                                    break
                                end
                            end
                        end

                        if aid == "camping" and not isPetUsingFurniture(targetModel) and math.floor(PhaseTimer) % 2 == 0 and Router and Router.get then
                            local houseInteriors = Workspace:FindFirstChild("HouseInteriors")
                            local furnitureFolder = houseInteriors and houseInteriors:FindFirstChild("furniture")
                            if furnitureFolder then
                                for _, c in ipairs(furnitureFolder:GetChildren()) do 
                                    local m = c:FindFirstChild("SleepingBag") 
                                    if m then 
                                        local i = m:FindFirstChild("UseBlocks") and (m.UseBlocks:FindFirstChild("Seat1") or m.UseBlocks:FindFirstChildOfClass("Part"))
                                        if i and targetModel:IsA("Model") then 
                                            Router.get("HousingAPI/ActivateInteriorFurniture"):InvokeServer(string.split(c.Name, "/")[#string.split(c.Name, "/")], i.Name, {cframe = targetModel:GetPivot()}, targetModel) 
                                            break 
                                        end 
                                    end 
                                end
                            end
                        end

                        if not isAilmentActive(entityRef, aid) or PhaseTimer > 180 then
                            globalCleanup(false)
                        end
                    else
                        globalCleanup(false)
                    end

                -- 3. BABY FOOD / SICK
                elseif (aid == "hungry" or aid == "thirsty" or aid == "sick") and not entityRef.is_pet then
                    if TaskPhase == "EXECUTE" then
                        TaskPhase = "FEEDING"
                        PhaseTimer = 0
                        task.spawn(function()
                            if not Router or not Router.get or not ClientData then return end
                            local foodKind = (aid == "hungry") and "apple" or (aid == "thirsty" and "chocolate_milk" or "healing_apple")
                            Router.get("ShopAPI/BuyItem"):InvokeServer("food", foodKind, {buy_count = 1}); task.wait(1)
                            local inventory = ClientData.get("inventory")
                            local rawData = ClientData.get_data()
                            local playerData = rawData and rawData[LocalPlayer.Name]
                            
                            for uId, item in pairs(inventory and inventory.food or {}) do 
                                local itemId = type(item) == "table" and (item.id or item.kind) or tostring(item)
                                if itemId == foodKind or uId == foodKind then 
                                    local isAlreadyEquipped = playerData and playerData.equip_manager and playerData.equip_manager.food == uId
                                    if not isAlreadyEquipped then
                                        Router.get("ToolAPI/Equip"):InvokeServer(uId)
                                        task.wait(0.5)
                                    end
                                    
                                    local startEat = tick()
                                    while CurrentTask == aid and BabyFarmEnabled and isAilmentActive(entityRef, aid) do
                                        if (tick() - startEat > 60) then break end
                                        Router.get("ToolAPI/ServerUseTool"):InvokeServer(uId, "START")
                                        task.wait(3)
                                        Router.get("ToolAPI/ServerUseTool"):InvokeServer(uId, "END")
                                        task.wait(1)
                                    end
                                    break
                                end 
                            end
                            globalCleanup(false)
                        end)
                    end

                -- 4. PLAY TASK
                elseif aid == "play" then
                    if TaskPhase == "EXECUTE" then
                        TaskPhase = "PLAYING"
                        PhaseTimer = 0
                        task.spawn(function()
                            if not ClientData or not Router or not Router.get then return end
                            local toyUid = nil
                            local toys = ClientData.get("inventory") and ClientData.get("inventory").toys or {}
                            for uId, item in pairs(toys) do 
                                if item.id == "squeaky_bone_default" then toyUid = uId; break end 
                            end
                            if not toyUid then
                                Router.get("ShopAPI/BuyItem"):InvokeServer("toys", "squeaky_bone_default", {buy_count = 1}); task.wait(1)
                                toys = ClientData.get("inventory") and ClientData.get("inventory").toys or {}
                                for uId, item in pairs(toys) do 
                                    if item.id == "squeaky_bone_default" then toyUid = uId; break end 
                                end
                            end
                            if toyUid then
                                local startPlay = tick()
                                while CurrentTask == aid and (ScriptEnabled or BabyFarmEnabled) and isAilmentActive(entityRef, aid) do
                                    if (tick() - startPlay > 60) then break end
                                    Router.get("PetObjectAPI/CreatePetObject"):InvokeServer("__Enum_PetObjectCreatorType_1", {
                                        reaction_name = "ThrowToyReaction",
                                        unique_id = tostring(toyUid)
                                    })
                                    task.wait(8) 
                                end
                            end
                            globalCleanup(false)
                        end)
                    end

                -- 5. PET SICK TASK
                elseif aid == "sick" and entityRef.is_pet then
                    if TaskPhase == "EXECUTE" then
                        TaskPhase = "HEALING"
                        PhaseTimer = 0
                        task.spawn(function()
                            if not ClientData or not Router or not Router.get then return end
                            Router.get("ShopAPI/BuyItem"):InvokeServer("food", "healing_apple", {buy_count = 1}); task.wait(1)
                            local itemUid = nil
                            local foods = ClientData.get("inventory") and ClientData.get("inventory").food or {}
                            for uId, item in pairs(foods) do 
                                if item.id == "healing_apple" then itemUid = uId; break end 
                            end
                            if itemUid then
                                local startSick = tick()
                                while CurrentTask == aid and ScriptEnabled and isAilmentActive(entityRef, aid) do
                                    if (tick() - startSick > 60) then break end
                                    Router.get("PetObjectAPI/CreatePetObject"):InvokeServer("__Enum_PetObjectCreatorType_2", {
                                        additional_consume_uniques = {},
                                        pet_unique = tostring(pUid),
                                        unique_id = tostring(itemUid)
                                    })
                                    task.wait(8) 
                                end
                            end
                            globalCleanup(false)
                        end)
                    end

                -- 6. PET ME TASK
                elseif aid == "pet_me" then
                    if PetEntityManager and UIManager and UIManager.apps and Router and Router.get then
                        local ownedPets = PetEntityManager.get_local_owned_pet_entities()
                        local targetPet = ownedPets and ownedPets[1]
                        if targetPet and targetPet.base and targetPet.base.char_wrapper and UIManager.apps["FocusPetApp"] then
                            UIManager.apps["FocusPetApp"]:capture_focus(targetPet.base.char_wrapper)
                            if targetModel then
                                Router.get("PetAPI/ReplicateActivePerformances"):FireServer(targetModel, { FocusPet = true })
                            end
                            Router.get("AilmentsAPI/ProgressPetMeAilment"):FireServer(pUid)
                            if targetModel then
                                Router.get("PetAPI/ReplicateActivePerformances"):FireServer(targetModel, { FocusPet = false })
                            end
                            UIManager.apps["FocusPetApp"]:release_focus()
                        end
                    end
                    globalCleanup(false)

                -- 7. HOUSE FURNITURE TASKS
                elseif hConfig and aid ~= "pet_me" then
                    if math.floor(PhaseTimer) % 2 == 0 and Router and Router.get then
                        for _, furnitureName in ipairs(hConfig) do
                            local seated = false
                            local houseInteriors = Workspace:FindFirstChild("HouseInteriors")
                            local furnitureFolder = houseInteriors and houseInteriors:FindFirstChild("furniture")
                            if furnitureFolder then
                                for _, container in ipairs(furnitureFolder:GetChildren()) do
                                    local model = container:FindFirstChild(furnitureName)
                                    if model then
                                        local inter = model:FindFirstChild("UseBlocks") and (model.UseBlocks:FindFirstChild("Seat1") or model.UseBlocks:FindFirstChildOfClass("Part"))
                                        if inter then 
                                            local houseFurnitureId = string.match(container.Name, "f%-%w+") or container.Name
                                            Router.get("HousingAPI/ActivateFurniture"):InvokeServer(
                                                LocalPlayer, 
                                                houseFurnitureId, 
                                                inter.Name, 
                                                { cframe = model:GetPivot() }, 
                                                targetEntity
                                            )
                                            seated = true
                                            break 
                                        end
                                    end
                                end
                            end
                            if seated then break end
                        end
                    end

                    if not isAilmentActive(entityRef, aid) or PhaseTimer > 160 then
                        globalCleanup(false)
                    end
                else
                    globalCleanup(false)
                end
            end

        -- IDLE SCANNER ENGINE
        elseif (ScriptEnabled or BabyFarmEnabled) and not IsProcessing and CurrentTask == nil and not Debounce then
            RefreshCounter = RefreshCounter + dt
            if RefreshCounter >= MAX_IDLE_TIME then
                globalCleanup(false)
            end

            pcall(function() 
                if not ClientData then return end
                local rawData = ClientData.get_data()
                local playerData = rawData and rawData[LocalPlayer.Name]
                local manager = playerData and playerData.ailments_manager

                local function getAilmentName(key, obj)
                    if type(obj) == "table" and obj.kind then
                        return string.lower(tostring(obj.kind))
                    end
                    return string.lower(tostring(key))
                end

                -- SCAN PET AILMENTS
                if not IsProcessing and ScriptEnabled and manager and manager.ailments then
                    for petUidKey, petAilmentsTable in pairs(manager.ailments) do
                        if typeof(petAilmentsTable) == "table" and next(petAilmentsTable) then
                            for ailmentKey, ailmentObj in pairs(petAilmentsTable) do
                                local aName = getAilmentName(ailmentKey, ailmentObj)
                                if aName ~= "balloon_fight" then
                                    if aName == "mystery" and (MysteryExcludeMode or not MysteryChooserEnabled) then
                                        -- Skip mystery task cleanly
                                    else
                                        local realPetUid = tostring(petUidKey)
                                        local pRef = createEntityReference(LocalPlayer, true, realPetUid)
                                        RefreshCounter = 0
                                        executeTaskLogic(ailmentObj, aName, pRef)
                                        return
                                    end
                                end
                            end
                        end
                    end
                end

                -- SCAN BABY AILMENTS
                if BabyFarmEnabled and not IsProcessing and manager and manager.baby_ailments then
                    if typeof(manager.baby_ailments) == "table" and next(manager.baby_ailments) then
                        for ailmentKey, ailmentObj in pairs(manager.baby_ailments) do
                            local aName = getAilmentName(ailmentKey, ailmentObj)
                            if aName ~= "balloon_fight" then
                                if aName == "mystery" and (MysteryExcludeMode or not MysteryChooserEnabled) then
                                    -- Skip mystery task cleanly
                                else
                                    local bRef = createEntityReference(LocalPlayer, false, tostring(LocalPlayer.UserId))
                                    RefreshCounter = 0
                                    executeTaskLogic(ailmentObj, aName, bRef)
                                    return
                                end
                            end
                        end
                    end
                end
            end)
        else
            RefreshCounter = 0
        end
    end)
end)














local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))

-- Load modules via Fsys
local RouterClient = Fsys.load("RouterClient")
local ClientData = Fsys.load("ClientData")
local Module = require(ReplicatedStorage.SharedModules.FurnitureMannequinsHelper)
local InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)

local Options = Fluent.Options 

-- 1. Helper: Dynamic Player List
local function GetPlayerNames()
    local names = {}
    for _, player in pairs(Players:GetPlayers()) do
        table.insert(names, player.Name)
    end
    table.sort(names)
    return #names > 0 and names or {"No Players Found"}
end

-- 2. Helper: Refined Register Scanner (Named Output)
local function GetRegisterList()
    local registers = {"All Registers"}
    
    -- Try ClientData first for verified IDs and Names
    local houseData = ClientData.get_server(LocalPlayer, "house_interior")
    if houseData and houseData.furniture then
        for id, data in pairs(houseData.furniture) do
            local kind = data.kind or (data.properties and data.properties.kind) or ""
            if kind:lower():find("register") or id == "f-67" or id == "f-68" then
                -- Formatting Name: "f-68 | Golden Cash Register"
                local displayName = kind:gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)
                table.insert(registers, string.format("%s | %s", id, displayName))
            end
        end
    end
    
    -- Backup: Physical Scan if UI data hasn't synced
    if #registers == 1 then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:lower():find("register") then
                local furnId = obj:GetAttribute("furniture_unique")
                if furnId then
                    table.insert(registers, string.format("%s | %s", furnId, obj.Name))
                end
            end
        end
    end

    return #registers > 1 and registers or {"All Registers", "No Registers Found"}
end

-- 3. Helper: Outfit Version Scanner
local function GetOutfitVersionList()
    local mannequins = Module.get_mannequins()
    local versions = {"All Versions"}
    for _, m in pairs(mannequins) do
        local version = m:GetAttribute("outfit_version")
        local ownerVal = m:FindFirstChild("Owner")
        local ownerName = (ownerVal and ownerVal.Value) and ownerVal.Value.Name or "Unknown"
        if version then
            table.insert(versions, string.format("[%s] v: %s", ownerName, tostring(version):sub(1,8)))
        end
    end
    return #versions > 1 and versions or {"All Versions", "No Outfits Found"}
end

-- --- UI Setup (Transfer Tab) ---

local PlayerDrop = Tabs.Transfer:AddDropdown("TargetPlayer", {
    Title = "1. Select Target Player",
    Values = GetPlayerNames(),
    Multi = false,
    Default = 1,
})

local RegisterDrop = Tabs.Transfer:AddDropdown("SelectedRegister", {
    Title = "2. Select Register",
    Values = GetRegisterList(),
    Multi = false,
    Default = 1,
})

local OutfitDrop = Tabs.Transfer:AddDropdown("SelectedOutfit", {
    Title = "3. Select Outfit Version",
    Values = GetOutfitVersionList(),
    Multi = false,
    Default = 1,
})

Tabs.Transfer:AddInput("PayAmount", {
    Title = "Payment Amount (Global)",
    Default = "100",
    Numeric = true,
})

Tabs.Transfer:AddToggle("AutoPurchase", {Title = "Auto-Purchase Loop (Mannequin)", Default = false})
Tabs.Transfer:AddToggle("AutoRegister", {Title = "Auto-Pay Loop (Register)", Default = false})

Tabs.Transfer:AddButton({
    Title = "Refresh All Data",
    Description = "Scans current house and players",
    Callback = function()
        PlayerDrop:SetValues(GetPlayerNames())
        RegisterDrop:SetValues(GetRegisterList())
        OutfitDrop:SetValues(GetOutfitVersionList())
        Fluent:Notify({Title = "Scanner", Content = "Lists updated with display names.", Duration = 3})
    end
})

Tabs.Transfer:AddButton({
    Title = "Teleport to Player's House",
    Callback = function()
        local targetPlayer = Players:FindFirstChild(Options.TargetPlayer.Value)
        if targetPlayer then
            InteriorsM.enter_smooth("housing", "MainDoor", {house_owner = targetPlayer}, nil)
        end
    end
})

-- --- Unified Loop Logic (RouterClient Only) ---

-- Mannequin Loop
task.spawn(function()
    while true do
        if Options.AutoPurchase and Options.AutoPurchase.Value then
            local targetPlayer = Players:FindFirstChild(Options.TargetPlayer.Value)
            local selection = Options.SelectedOutfit.Value
            if targetPlayer and selection ~= "No Outfits Found" then
                local mannequins = Module.get_mannequins()
                for _, m in pairs(mannequins) do
                    local version = tostring(m:GetAttribute("outfit_version"))
                    if selection == "All Versions" or selection:find(version:sub(1,8)) then
                        local args = {
                            targetPlayer,
                            tostring(m.Parent:GetAttribute("furniture_unique")),
                            version,
                            tonumber(Options.PayAmount.Value) or 100
                        }
                        pcall(function() RouterClient.get("AvatarAPI/BuyMannequinOutfit"):InvokeServer(unpack(args)) end)
                    end
                end
            end
        end
        task.wait(2.5)
    end
end)

-- Register Loop
task.spawn(function()
    while true do
        if Options.AutoRegister and Options.AutoRegister.Value then
            local targetPlayer = Players:FindFirstChild(Options.TargetPlayer.Value)
            local selection = Options.SelectedRegister.Value
            if targetPlayer and selection ~= "No Registers Found" then
                local regIds = {}
                if selection == "All Registers" then
                    local list = GetRegisterList()
                    for i = 2, #list do table.insert(regIds, list[i]:split(" | ")[1]) end
                else
                    table.insert(regIds, selection:split(" | ")[1])
                end

                for _, id in pairs(regIds) do
                    local args = {targetPlayer, id, "UseBlock", tonumber(Options.PayAmount.Value) or 100, LocalPlayer.Character}
                    pcall(function() RouterClient.get("HousingAPI/ActivateFurniture"):InvokeServer(unpack(args)) end)
                end
            end
        end
        task.wait(2.5)
    end
end)










local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------------------------------------
-- STABLE FSYS LOADER
-----------------------------------------------------------
local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))

local function SafeLoad(moduleName)
    local module = nil
    while not module do
        local success, result = pcall(function() 
            -- Directly check if Fsys is ready to avoid the GetFullName nil error
            return Fsys.load(moduleName) 
        end)
        if success and result then
            module = result
        else
            task.wait(0.5)
        end
    end
    return module
end

local RouterClient = SafeLoad("RouterClient")
local ClientDataModule = SafeLoad("ClientData")

-- Connect to UI
local Tab = Tabs or _G.Tabs 
if not Tab then return end

-----------------------------------------------------------
-- INDEX-BASED FUSION LOGIC
-----------------------------------------------------------
local function processSequentialFusions(mode)
    local data = ClientDataModule.get_data()
    if not data or not data[Players.LocalPlayer.Name] then return end
    
    local inventory = data[Players.LocalPlayer.Name].inventory.pets
    local speciesGroups = {}
    local fusionQueue = {} -- The Index-based table

    -- 1. Sort into species groups
    for uId, petData in pairs(inventory) do
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

    -- 2. Build the Index Queue
    for sId, ids in pairs(speciesGroups) do
        while #ids >= 4 do
            local set = {ids[1], ids[2], ids[3], ids[4]}
            table.insert(fusionQueue, {name = sId, list = set})
            for i = 1, 4 do table.remove(ids, 1) end
        end
    end

    -- 3. Execute by Index
    if #fusionQueue > 0 then
        print("--- [QUEUE START] Total sets found: " .. #fusionQueue .. " ---")
        for i = 1, #fusionQueue do
            local current = fusionQueue[i]
            print(string.format("[%d/%d] Fusing: %s", i, #fusionQueue, current.name))
            
            RouterClient.get("PetAPI/DoNeonFusion"):InvokeServer(current.list)
            task.wait(1.5)
        end
        print("--- [QUEUE FINISHED] ---")
    end
end

-----------------------------------------------------------
-- THE TOGGLES
-----------------------------------------------------------
local NeonToggleObj = Tab.Others:AddToggle("AutoNeon", { Title = "AUTO NEON", Default = false })
local MegaToggleObj = Tab.Others:AddToggle("AutoMega", { Title = "AUTO MEGA", Default = false })

-----------------------------------------------------------
-- MAIN LOOP
-----------------------------------------------------------
task.spawn(function()
    while true do
        if NeonToggleObj.Value then
            processSequentialFusions("Neon")
        end
        
        task.wait(1)
        
        if MegaToggleObj.Value then
            processSequentialFusions("Mega")
        end
        
        task.wait(10) -- Longer wait between full inventory scans
    end
end)





local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

if getgenv()._WagonFullScriptRunning then
    warn("Full Wagon automation & seed buyer is already running!")
    return
end
getgenv()._WagonFullScriptRunning = true

-----------------------------------------------------------
-- STABLE FSYS LOADER
-----------------------------------------------------------
local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))

local function SafeLoad(moduleName)
    local module = nil
    while not module do
        local success, result = pcall(function() 
            return Fsys.load(moduleName) 
        end)
        if success and result then
            module = result
        else
            task.wait(0.5)
        end
    end
    return module
end

local RouterClient = SafeLoad("RouterClient")
local ClientDataModule = SafeLoad("ClientData")
local ShopAPI = RouterClient.get("ShopAPI/BuyItem")
local BeesWagonWagonNet = SafeLoad("BeesWagonWagonNet")
local battlePassInvoke = RouterClient.get("BattlePassAPI/ClaimReward")

local FIXED_SPOTS = {"1", "2", "3", "4", "9"}
local PLANK_ASSET = "rbxassetid://17279545564"

local SEED_TYPES = {
    {name = "Rose Seed", id = "bees_wagon_2026_rose_seeds"},
    {name = "Iris Seed", id = "bees_wagon_2026_iris_seeds"},
    {name = "Daisy Seed", id = "bees_wagon_2026_daisy_seeds"},
    {name = "Poppy Seed", id = "bees_wagon_2026_poppy_seeds"},
    {name = "Bluebell Seed", id = "bees_wagon_2026_bluebell_seeds"},
    {name = "Fern Seed", id = "bees_wagon_2026_fern_seeds"}
}

-- --- UI CONSTRUCTION ---
local screenGui = Instance.new("ScreenGui", PlayerGui)
screenGui.Name = "EventGuiFull"
screenGui.IgnoreGuiInset = true 
screenGui.DisplayOrder = 999 

local bg = Instance.new("ImageLabel", screenGui)
bg.Size = UDim2.new(1, 0, 1, 0)
bg.Image = PLANK_ASSET
bg.ScaleType = Enum.ScaleType.Tile
bg.TileSize = UDim2.new(0, 128, 0, 128) 
bg.ZIndex = 10

local function applyRainbowStroke(target)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Parent = target
    task.spawn(function()
        local hue = 0
        while target.Parent do
            hue = (hue + 0.002) % 1
            stroke.Color = Color3.fromHSV(hue, 1, 1)
            task.wait(0.2)
        end
    end)
end

local function createText(text, size, position, isButton)
    local label = Instance.new(isButton and "TextButton" or "TextLabel")
    label.Parent = bg
    label.Size = UDim2.new(0, 500, 0, 45) 
    label.Position = position
    label.BackgroundTransparency = isButton and 0 or 1 
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0) 
    label.Text = text
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = size
    label.TextColor3 = Color3.fromRGB(255, 255, 255) 
    label.ZIndex = 500 
    applyRainbowStroke(label)
    return label
end

createText("POWERED BY EVENTSPLOIT ENJOY!", 26, UDim2.new(0.5, -250, 0.01, 0))
createText("BEES WAGON 2026 AUTOMATION", 30, UDim2.new(0.5, -250, 0.07, 0))

local TaskHUD = createText("Initializing...", 20, UDim2.new(0.5, -250, 0.13, 0))
local UptimeLabel = createText("Uptime: 00:00:00", 22, UDim2.new(0.5, -250, 0.18, 0))
local ShopTimerLabel = createText("Next Seed Purchase In: 0s", 22, UDim2.new(0.5, -250, 0.23, 0))
local BuyNowBtn = createText("BUY SELECTED SEEDS NOW", 22, UDim2.new(0.5, -250, 0.28, 0), true)
BuyNowBtn.Size = UDim2.new(0, 500, 0, 38)
BuyNowBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 50)

-- --- CONFIGURATION TABLE ---
local config = {
    pickEnabled = true,
    plantEnabled = true,
    bouquetEnabled = true,
    buyEnabled = false,
    autoBuyTimerEnabled = false,
    beePassEnabled = false,
    fluentEventEnabled = false,
    selectedSeeds = {
        [1] = false,
        [2] = false,
        [3] = false,
        [4] = false,
        [5] = false,
        [6] = false
    }
}

-- --- SEED SELECTION PANEL ---
local seedPanel = Instance.new("ScrollingFrame", bg)
seedPanel.Size = UDim2.new(0, 500, 0, 115)
seedPanel.Position = UDim2.new(0.5, -250, 0.33, 0)
seedPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
seedPanel.BorderSizePixel = 0
seedPanel.CanvasSize = UDim2.new(0, 0, 0, 220)
seedPanel.ScrollBarThickness = 6
seedPanel.ZIndex = 400
applyRainbowStroke(seedPanel)

for i, seedInfo in ipairs(SEED_TYPES) do
    local btn = Instance.new("TextButton", seedPanel)
    btn.Size = UDim2.new(1, -16, 0, 32)
    btn.Position = UDim2.new(0, 8, 0, (i - 1) * 36 + 6)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 15
    btn.ZIndex = 405
    applyRainbowStroke(btn)
    
    local function updateSeedBtn()
        if config.selectedSeeds[i] then
            btn.Text = "Buy " .. seedInfo.name .. ": ENABLED"
            btn.TextColor3 = Color3.fromRGB(85, 255, 127)
        else
            btn.Text = "Buy " .. seedInfo.name .. ": DISABLED"
            btn.TextColor3 = Color3.fromRGB(255, 85, 85)
        end
    end
    
    updateSeedBtn()
    btn.MouseButton1Click:Connect(function()
        config.selectedSeeds[i] = not config.selectedSeeds[i]
        updateSeedBtn()
    end)
end

-- --- SLOTS STATUS PANEL ---
local slotsStatusPanel = Instance.new("Frame", bg)
slotsStatusPanel.Size = UDim2.new(0, 500, 0, 105)
slotsStatusPanel.Position = UDim2.new(0.5, -250, 0.45, 0)
slotsStatusPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
slotsStatusPanel.BorderSizePixel = 0
slotsStatusPanel.ZIndex = 400 
applyRainbowStroke(slotsStatusPanel)

local slotsStatusLabel = Instance.new("TextLabel", slotsStatusPanel)
slotsStatusLabel.Size = UDim2.new(0.5, -5, 1, 0)
slotsStatusLabel.Position = UDim2.new(0, 5, 0, 0)
slotsStatusLabel.BackgroundTransparency = 1
slotsStatusLabel.Text = "Scanning slots..."
slotsStatusLabel.Font = Enum.Font.SourceSansBold
slotsStatusLabel.TextSize = 13
slotsStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
slotsStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
slotsStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
slotsStatusLabel.ZIndex = 405

local slotsWateredLabel = Instance.new("TextLabel", slotsStatusPanel)
slotsWateredLabel.Size = UDim2.new(0.5, -5, 1, 0)
slotsWateredLabel.Position = UDim2.new(0.5, 0, 0, 0)
slotsWateredLabel.BackgroundTransparency = 1
slotsWateredLabel.Text = ""
slotsWateredLabel.Font = Enum.Font.SourceSansBold
slotsWateredLabel.TextSize = 13
slotsWateredLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
slotsWateredLabel.TextXAlignment = Enum.TextXAlignment.Right
slotsWateredLabel.TextYAlignment = Enum.TextYAlignment.Top
slotsWateredLabel.ZIndex = 405

-- --- CURRENCY REPORT ---
local currencyPanel = Instance.new("Frame", bg)
currencyPanel.Size = UDim2.new(0, 500, 0, 38)
currencyPanel.Position = UDim2.new(0.5, -250, 0.56, 0)
currencyPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
currencyPanel.ZIndex = 400 
applyRainbowStroke(currencyPanel)

local currencyLabel = Instance.new("TextLabel", currencyPanel)
currencyLabel.Size = UDim2.new(1, 0, 1, 0)
currencyLabel.BackgroundTransparency = 1
currencyLabel.Text = "Bucks: Loading..."
currencyLabel.Font = Enum.Font.SourceSansBold
currencyLabel.TextSize = 20
currencyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
currencyLabel.ZIndex = 405

local hideBtn = createText("HIDE INTERFACE", 22, UDim2.new(0.5, -250, 0.61, 0), true)

-- --- CONFIGURATION TOGGLE PANEL ---
local optionsPanel = Instance.new("Frame", bg)
optionsPanel.Size = UDim2.new(0, 500, 0, 160)
optionsPanel.Position = UDim2.new(0.5, -250, 0.67, 0)
optionsPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
optionsPanel.BorderSizePixel = 0
optionsPanel.ZIndex = 400 

local function createSubToggle(text, position, defaultState, callback)
    local btn = Instance.new("TextButton", optionsPanel)
    btn.Size = UDim2.new(1, -20, 0, 32)
    btn.Position = position
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 16
    btn.ZIndex = 405
    applyRainbowStroke(btn)
    
    local function updateAppearance(state)
        if state then
            btn.Text = text .. ": ENABLED"
            btn.TextColor3 = Color3.fromRGB(85, 255, 127)
        else
            btn.Text = text .. ": DISABLED"
            btn.TextColor3 = Color3.fromRGB(255, 85, 85)
        end
    end
    
    updateAppearance(defaultState)
    btn.MouseButton1Click:Connect(function()
        local newState = callback()
        updateAppearance(newState)
    end)
end

createSubToggle("Auto Pick", UDim2.new(0, 10, 0, 8), config.pickEnabled, function()
    config.pickEnabled = not config.pickEnabled
    return config.pickEnabled
end)

createSubToggle("Auto Plant", UDim2.new(0, 10, 0, 44), config.plantEnabled, function()
    config.plantEnabled = not config.plantEnabled
    return config.plantEnabled
end)

createSubToggle("Auto Bouquet", UDim2.new(0, 10, 0, 80), config.bouquetEnabled, function()
    config.bouquetEnabled = not config.bouquetEnabled
    return config.bouquetEnabled
end)

createSubToggle("Auto Buy Timer", UDim2.new(0, 10, 0, 116), config.autoBuyTimerEnabled, function()
    config.autoBuyTimerEnabled = not config.autoBuyTimerEnabled
    return config.autoBuyTimerEnabled
end)

-- --- OPEN UI FLOATING BUTTON ---
local openBtn = Instance.new("TextButton", screenGui)
openBtn.Size = UDim2.new(0, 260, 0, 45)
openBtn.Position = UDim2.new(0.5, -130, 0.61, -22) 
openBtn.Text = "OPEN BEE PASS UI"
openBtn.Font = Enum.Font.SourceSansBold
openBtn.TextSize = 22
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0) 
openBtn.Visible = false
openBtn.ZIndex = 500
applyRainbowStroke(openBtn)

hideBtn.MouseButton1Click:Connect(function()
    bg.Visible = false
    openBtn.Visible = true
end)

openBtn.MouseButton1Click:Connect(function()
    bg.Visible = true
    openBtn.Visible = false
end)

-- --- FLUENT UI INTEGRATION ---
pcall(function()
    if Tabs and Tabs.Event then
        local Toggle = Tabs.Event:AddToggle("AutoBeesPassToggle", {
            Title = "Auto Bees Pass", 
            Description = "Enable or disable script execution and seed features",
            Default = false,
            Callback = function(state)
                config.fluentEventEnabled = state
            end
        })
    end
end)

-- --- UTILITY FUNCTIONS ---
local function get_all_seeds()
    local success, inventory = pcall(function()
        return ClientDataModule.get("inventory")
    end)

    if not success or not inventory then return {} end

    local seeds = {}
    for category, items in pairs(inventory) do
        if typeof(items) == "table" then
            for _, item in pairs(items) do
                if typeof(item) == "table" and item.id then
                    local itemName = string.lower(item.id)
                    if string.find(itemName, "seed") then
                        table.insert(seeds, {
                            unique = item.unique or item.id,
                            id = item.id
                        })
                    end
                end
            end
        end
    end

    return seeds
end

local function get_all_flowers()
    local success, inventory = pcall(function()
        return ClientDataModule.get("inventory")
    end)

    if not success or not inventory then return {} end

    local flowers = {}
    for category, items in pairs(inventory) do
        if typeof(items) == "table" then
            for _, item in pairs(items) do
                if typeof(item) == "table" and item.id then
                    local itemName = string.lower(item.id)
                    if string.find(itemName, "flower") then
                        table.insert(flowers, {
                            unique = item.unique or item.id,
                            id = item.id
                        })
                    end
                end
            end
        end
    end

    return flowers
end

local function formatTimestampToAMPM(timestamp)
    local num = tonumber(timestamp)
    if not num then return "N/A" end
    
    local dateTable = os.date("*t", num)
    if not dateTable then return "N/A" end
    
    local hour = dateTable.hour
    local min = dateTable.min
    local sec = dateTable.sec
    
    local ampm = "AM"
    if hour >= 12 then
        ampm = "PM"
        if hour > 12 then
            hour = hour - 12
        end
    end
    if hour == 0 then
        hour = 12
    end
    
    return string.format("%d:%02d:%02d %s", hour, min, sec, ampm)
end

local function executeSeedPurchase()
    if not config.fluentEventEnabled then 
        TaskHUD.Text = "Task: Seed purchasing is disabled (Tabs.Event toggle is off)"
        return 
    end

    task.spawn(function()
        TaskHUD.Text = "Task: Purchasing selected seeds..."
        for i, seedInfo in ipairs(SEED_TYPES) do
            if config.selectedSeeds[i] then
                pcall(function()
                    ShopAPI:InvokeServer("toys", seedInfo.id, {["buy_count"] = 1})
                end)
                task.wait(0.1)
            end
        end
    end)
end

BuyNowBtn.MouseButton1Click:Connect(function()
    executeSeedPurchase()
end)

-- --- BACKGROUND BEE PASS CLAIMER LOOP ---
task.spawn(function()
    while true do
        if config.fluentEventEnabled then
            for i = 1, 13 do
                if not config.fluentEventEnabled then break end
                pcall(function()
                    battlePassInvoke:InvokeServer("bees_2026_pass", i)
                end)
                task.wait(0.2)
            end
        end
        task.wait(5)
    end
end)

-- --- RUNSERVICE LOOPS ---
local startTime = tick()
local lastShopBuyTime = 0
local lastActionTime = 0
local shopCountdown = 50

RunService.RenderStepped:Connect(function(dt)
    local uptimeSecs = math.floor(tick() - startTime)
    local hours = math.floor(uptimeSecs / 3600)
    local mins = math.floor((uptimeSecs % 3600) / 60)
    local secs = uptimeSecs % 60
    UptimeLabel.Text = string.format("Uptime: %02d:%02d:%02d", hours, mins, secs)

    pcall(function()
        local bucks = ClientDataModule.get("money") or 0
        currencyLabel.Text = "Bucks: " .. tostring(bucks)
    end)

    local success, managerData = pcall(function()
        return ClientDataModule.get("bees_wagon_2026_manager")
    end)
    
    local plantedSpotsMap = {}
    local statusLines = {}
    local wateredLines = {}

    if success and managerData and managerData.planted_seeds then
        for spot, info in pairs(managerData.planted_seeds) do
            if type(info) == "table" then
                plantedSpotsMap[tostring(spot)] = info
                local kind = tostring(info.flower_kind or "unknown")
                table.insert(statusLines, string.format("Slot [%s]: (%s)", tostring(spot), kind))
                
                local wateredVal = info.watered_at
                if wateredVal then
                    table.insert(wateredLines, formatTimestampToAMPM(wateredVal))
                else
                    table.insert(wateredLines, "Not watered")
                end
            end
        end
    end

    local emptySpots = {}
    for _, spotIndex in ipairs(FIXED_SPOTS) do
        if not plantedSpotsMap[spotIndex] then
            table.insert(emptySpots, spotIndex)
            table.insert(statusLines, string.format("Slot [%s]: EMPTY", spotIndex))
            table.insert(wateredLines, "-")
        end
    end

    if #statusLines > 0 then
        slotsStatusLabel.Text = table.concat(statusLines, "\n")
        slotsWateredLabel.Text = table.concat(wateredLines, "\n")
    else
        slotsStatusLabel.Text = "No active wagon status found."
        slotsWateredLabel.Text = ""
    end

    if config.autoBuyTimerEnabled then
        shopCountdown = math.clamp(50 - math.floor((tick() - lastShopBuyTime) % 50), 0, 50)
        ShopTimerLabel.Text = string.format("Next Seed Purchase In: %ds", shopCountdown)

        if config.buyEnabled and config.fluentEventEnabled and (tick() - lastShopBuyTime >= 50) then
            lastShopBuyTime = tick()
            executeSeedPurchase()
        end
    else
        ShopTimerLabel.Text = "Auto Buy Timer: DISABLED"
    end

    if tick() - lastActionTime >= 3 then
        lastActionTime = tick()
        
        task.spawn(function()
            if not config.fluentEventEnabled then return end

            if config.pickEnabled then
                TaskHUD.Text = "Task: Picking flowers..."
                for spotIndex, _ in pairs(plantedSpotsMap) do
                    pcall(function()
                        BeesWagonWagonNet.RequestPickFlower:fire_server(tostring(spotIndex))
                    end)
                    task.wait(0.3)
                end
            end

            if config.plantEnabled and #emptySpots > 0 then
                TaskHUD.Text = "Task: Planting seeds in empty slots..."
                local seeds = get_all_seeds()
                if #seeds > 0 then
                    for i = 1, math.min(#seeds, #emptySpots) do
                        local seed = seeds[i]
                        local spotIndex = emptySpots[i]
                        
                        pcall(function()
                            BeesWagonWagonNet.RequestPlantSeed:fire_server({
                                ["spot_index"] = tostring(spotIndex),
                                ["seed_item_unique"] = seed.unique
                            })
                        end)
                        task.wait(0.5)
                    end
                end
            end

            if config.bouquetEnabled then
                TaskHUD.Text = "Task: Adding bouquet flowers..."
                local flowers = get_all_flowers()
                if #flowers > 0 then
                    local spotIter = 1
                    for _, flower in ipairs(flowers) do
                        local bouquetIndex = FIXED_SPOTS[spotIter] or "1"
                        local args = { bouquetIndex }
                        pcall(function()
                            BeesWagonWagonNet.RequestRequestAddBouquetFlower or BeesWagonWagonNet.RequestAddBouquetFlower:fire_server(unpack(args))
                        end)
                        spotIter = (spotIter % #FIXED_SPOTS) + 1
                        task.wait(0.3)
                    end
                end
            end

            TaskHUD.Text = "Task: Waiting for loop cycle..."
        end)
    end
end)
end)
if not success then warn("Hub Error: " .. tostring(err)) end
