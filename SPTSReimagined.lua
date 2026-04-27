local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

-- ==========================================
-- === 1. LOAD RAYFIELD LIBRARY ===
-- ==========================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ==========================================
-- === 2. LIVE STATE VARIABLES ===
-- ==========================================
local state = {
    TargetRace = "Bob",
    WebhookURL = "",
    UserID = "",
    WebhookEnabled = false,
    StatWebhookEnabled = false,
    UpgradeWebhookEnabled = false,
    AntiAFK = true,
    UpFist = false,
    UpBody = false,
    UpSpeed = false,
    UpJump = false,
    UpPsychic = false
}

-- ==========================================
-- === 3. REMOTES, PATHS & LOGIC ===
-- ==========================================
local RollRemote = ReplicatedStorage:WaitForChild("RollRaceRF")
local SaveRemote = ReplicatedStorage:WaitForChild("SaveRaceRF")
local UseSkillRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("UseSkill")
local UpgradeRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("UpgradeMultiplier")

local mainGui = player:WaitForChild("PlayerGui"):WaitForChild("RaceRollGui"):WaitForChild("Main")
local raceLabel = mainGui:WaitForChild("CurrentRaceLabel")
local saveButton = mainGui:WaitForChild("SaveButton")

local isAutoRolling = false
local isAutoShooting = false
local isAutoUpgrading = false
local currentSavedRace = "Elf"

local raceTiers = {
    ["Elf"] = 1, ["Angel"] = 2, ["Goblin"] = 3, ["Guardian"] = 4, ["Champion"] = 5,
    ["Unobtainable"] = 6, ["Insanity"] = 7, ["Crazed"] = 8, ["Abyssal"] = 9,
    ["Celestial"] = 10, ["Voidborn"] = 11, ["Ascended"] = 12, ["Omniversal"] = 13,
    ["Oblivion"] = 14, ["Archangel"] = 15, ["Radioactive"] = 16, ["Bob"] = 17
}
local sortedRaces = {
    "Bob", "Radioactive", "Archangel", "Oblivion", "Omniversal", "Ascended", 
    "Voidborn", "Celestial", "Abyssal", "Crazed", "Insanity", "Unobtainable", 
    "Champion", "Guardian", "Goblin", "Angel", "Elf"
}

local function getStartingSavedRace()
    local savedText = saveButton.Text
    for _, raceName in ipairs(sortedRaces) do
        if string.find(savedText, raceName) then return raceName end
    end
    return "Elf"
end

local function getClosestNPC()
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = character.HumanoidRootPart.Position
    local closest, shortestDist = nil, 1000
    
    for _, obj in workspace:GetChildren() do 
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
            if obj.Humanoid.Health > 0 and not Players:GetPlayerFromCharacter(obj) then
                local dist = (myPos - obj.HumanoidRootPart.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    closest = obj
                end
            end
        end
    end
    return closest
end

local function getStats()
    local success, result = pcall(function()
        local ts = player.PlayerGui.MainGui.MenuFrame.InfoFrame.TrainingStats
        return {
            FS = ts.FistStrength.StatLabel.Text,
            BT = ts.BodyToughness.StatLabel.Text,
            MS = ts.MovementSpeed.StatLabel.Text,
            JF = ts.JumpForce.StatLabel.Text,
            PP = ts.PsychicPower.StatLabel.Text
        }
    end)
    if not success then warn("AIO Hub: Could not read StatLabels from UI.") return nil end
    return result
end

local function getMultipliers()
    local success, result = pcall(function()
        local ts = player.PlayerGui.MainGui.MenuFrame.InfoFrame.TrainingStats
        return {
            FS = ts.FistStrength.StatMultiplier.Text,
            BT = ts.BodyToughness.StatMultiplier.Text,
            MS = ts.MovementSpeed.StatMultiplier.Text,
            JF = ts.JumpForce.StatMultiplier.Text,
            PP = ts.PsychicPower.StatMultiplier.Text
        }
    end)
    if not success then warn("AIO Hub: Could not read StatMultipliers from UI.") return nil end
    return result
end

local function sendDiscordPing(webhookUrl, userId, title, description, color)
    if not webhookUrl or webhookUrl == "" then 
        warn("AIO Hub: Webhook URL is empty!")
        return 
    end
    
    local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if not httprequest then 
        warn("AIO Hub: Your executor does not support HTTP requests!")
        return 
    end
    
    local pingText = (userId and userId ~= "") and ("<@" .. userId .. "> ") or ""

    local webhookData = {
        ["content"] = pingText .. "🔔 **AIO Hub Update!**",
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = description,
            ["color"] = color or 65280,
            ["footer"] = { ["text"] = "Ultimate AIO Hub" }
        }}
    }

    local success, err = pcall(function()
        local response = httprequest({
            Url = webhookUrl, Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(webhookData)
        })
        if response and response.StatusCode and response.StatusCode >= 400 then
            warn("AIO Hub Webhook Error: Discord responded with Code", response.StatusCode)
            warn("Discord Message:", response.Body)
        else
            print("AIO Hub: Webhook sent successfully! (" .. title .. ")")
        end
    end)
    
    if not success then warn("AIO Hub Webhook Crash:", err) end
end

-- === ANTI-AFK ===
player.Idled:Connect(function()
    if state.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- === 60-SECOND ACTUAL STAT WEBHOOK LOOP ===
task.spawn(function()
    while true do
        task.wait(60) 
        if state.StatWebhookEnabled and state.WebhookEnabled and state.WebhookURL ~= "" then
            local stats = getStats()
            if stats then
                local desc = string.format(
                    "💪 **Fist Strength:** %s\n🛡️ **Body Toughness:** %s\n⚡ **Movement Speed:** %s\n🦘 **Jump Force:** %s\n🧠 **Psychic Power:** %s",
                    stats.FS, stats.BT, stats.MS, stats.JF, stats.PP
                )
                -- We pass an empty string instead of state.UserID to prevent the ping!
                sendDiscordPing(state.WebhookURL, "", "📊 1-Minute Current Stats", desc, 3447003)
            end
        end
    end
end)

-- ==========================================
-- === 4. BUILD THE RAYFIELD UI ===
-- ==========================================
local Window = Rayfield:CreateWindow({
    Name = "Ultimate AIO Hub",
    LoadingTitle = "AIO Hub Booting...",
    LoadingSubtitle = "by You",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "UltimateAIO", 
        FileName = "HubSettings"
    },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- ==========================================
-- === WEBHOOKS TAB ===
-- ==========================================
local WebhookTab = Window:CreateTab("Webhooks", 4483345998)

WebhookTab:CreateSection("Global Settings")

WebhookTab:CreateToggle({
    Name = "Enable Webhooks",
    CurrentValue = false,
    Flag = "ToggleGlobalWebhooks",
    Callback = function(Value) state.WebhookEnabled = Value end,
})

WebhookTab:CreateInput({
    Name = "Webhook URL (PRESS ENTER)",
    PlaceholderText = "Paste URL and Press Enter...",
    RemoveTextAfterFocusLost = false,
    Flag = "WebhookURLInput",
    Callback = function(Text) 
        state.WebhookURL = Text 
        print("AIO Hub: Webhook URL internally updated!")
    end,
})

WebhookTab:CreateInput({
    Name = "Discord User ID (PRESS ENTER)",
    PlaceholderText = "Paste ID and Press Enter...",
    RemoveTextAfterFocusLost = false,
    Flag = "UserIDInput",
    Callback = function(Text) state.UserID = Text end,
})

WebhookTab:CreateButton({
    Name = "Test Webhook Ping",
    Callback = function()
        if state.WebhookURL ~= "" then
            task.spawn(function()
                sendDiscordPing(state.WebhookURL, state.UserID, "🧪 Webhook Test", "Config Loaded & Tested successfully!", 65280)
                Rayfield:Notify({
                    Title = "Webhook Fired!",
                    Content = "Check your Discord. If nothing appeared, press F9 to read the error.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end)
        else
            Rayfield:Notify({
                Title = "Missing URL",
                Content = "You must paste a URL and press ENTER on your keyboard first.",
                Duration = 4,
                Image = 4483362458,
            })
        end
    end,
})

WebhookTab:CreateSection("Events")

WebhookTab:CreateToggle({
    Name = "Send Current Stats Every Minute",
    CurrentValue = false,
    Flag = "ToggleStatWebhook",
    Callback = function(Value) state.StatWebhookEnabled = Value end,
})

WebhookTab:CreateToggle({
    Name = "Ping on Successful Upgrade",
    CurrentValue = false,
    Flag = "ToggleUpgradeWebhook",
    Callback = function(Value) state.UpgradeWebhookEnabled = Value end,
})

-- ==========================================
-- === AUTO-ROLL TAB ===
-- ==========================================
local RollTab = Window:CreateTab("Auto-Roll", 4483345998) 

RollTab:CreateInput({
    Name = "Target Race Goal (PRESS ENTER)",
    PlaceholderText = "Enter Race (e.g. Bob) and Press Enter",
    RemoveTextAfterFocusLost = false,
    Flag = "TargetRaceInput", 
    Callback = function(Text)
        state.TargetRace = Text
    end,
})

local RollStatus = RollTab:CreateLabel("Status: Idle")

RollTab:CreateToggle({
    Name = "Start Auto-Roll",
    CurrentValue = false,
    Flag = "ToggleAutoRoll", 
    Callback = function(Value)
        isAutoRolling = Value
        if isAutoRolling then
            currentSavedRace = getStartingSavedRace()
            local stopAtRace = state.TargetRace
            if not raceTiers[stopAtRace] then
                RollStatus:Set("Status: Invalid Target! Defaulting to Bob.")
                stopAtRace = "Bob"
            else
                RollStatus:Set("Status: Running... Target: " .. stopAtRace)
            end
            
            task.spawn(function()
                while isAutoRolling do
                    local oldText = raceLabel.Text
                    RollRemote:InvokeServer()
                    
                    local timeout = os.clock() + 0.05
                    while raceLabel.Text == oldText and os.clock() < timeout do task.wait() end
                    
                    local currentText = raceLabel.Text
                    local rolledRace = string.match(currentText, "Current Race:%s*(.-)%s*|")
                    
                    if rolledRace then
                        local rolledTier = raceTiers[rolledRace] or 0
                        local currentTier = raceTiers[currentSavedRace] or 0
                        local stopTier = raceTiers[stopAtRace] or 17
                        
                        if rolledTier > currentTier then
                            SaveRemote:InvokeServer()
                            currentSavedRace = rolledRace
                            RollStatus:Set("Status: 💾 Saved Upgrade (" .. rolledRace .. ")")
                            
                            if state.WebhookEnabled and state.WebhookURL ~= "" then
                                task.spawn(function()
                                    sendDiscordPing(state.WebhookURL, state.UserID, "🎉 New Best Race Saved!", "Successfully saved: **" .. rolledRace .. "**\nTier Level: " .. rolledTier .. "/17", 65280)
                                end)
                            end
                            task.wait(0.2) 
                        end
                        
                        if rolledTier >= stopTier then
                            RollStatus:Set("Status: 🎉 GOAL OBTAINED! Stopped.")
                            isAutoRolling = false
                            Rayfield.Flags["ToggleAutoRoll"]:Set(false)
                            break
                        end
                    end
                end
            end)
        else
            RollStatus:Set("Status: Idle")
        end
    end,
})

-- ==========================================
-- === UPGRADES TAB ===
-- ==========================================
local StatsTab = Window:CreateTab("Upgrades", 4483345998)

StatsTab:CreateSection("Select Stats to Auto-Upgrade")

StatsTab:CreateToggle({
    Name = "Fist Strength",
    CurrentValue = false,
    Flag = "ToggleUpFist",
    Callback = function(Value) state.UpFist = Value end,
})
StatsTab:CreateToggle({
    Name = "Body Toughness",
    CurrentValue = false,
    Flag = "ToggleUpBody",
    Callback = function(Value) state.UpBody = Value end,
})
StatsTab:CreateToggle({
    Name = "Movement Speed",
    CurrentValue = false,
    Flag = "ToggleUpSpeed",
    Callback = function(Value) state.UpSpeed = Value end,
})
StatsTab:CreateToggle({
    Name = "Jump Force",
    CurrentValue = false,
    Flag = "ToggleUpJump",
    Callback = function(Value) state.UpJump = Value end,
})
StatsTab:CreateToggle({
    Name = "Psychic Power",
    CurrentValue = false,
    Flag = "ToggleUpPsychic",
    Callback = function(Value) state.UpPsychic = Value end,
})

StatsTab:CreateSection("Master Control")

StatsTab:CreateToggle({
    Name = "Start Auto-Upgrade",
    CurrentValue = false,
    Flag = "ToggleAutoUpgrade",
    Callback = function(Value)
        isAutoUpgrading = Value
        if isAutoUpgrading then
            task.spawn(function()
                while isAutoUpgrading do
                    local prevMults = getMultipliers()
                    
                    if state.UpFist then UpgradeRemote:FireServer("FistStrengthMultiplier") end
                    if state.UpBody then UpgradeRemote:FireServer("BodyToughnessMultiplier") end
                    if state.UpSpeed then UpgradeRemote:FireServer("MovementSpeedMultiplier") end
                    if state.UpJump then UpgradeRemote:FireServer("JumpForceMultiplier") end
                    if state.UpPsychic then UpgradeRemote:FireServer("PsychicPowerMultiplier") end
                    
                    task.wait(1) 
                    
                    if state.WebhookEnabled and state.UpgradeWebhookEnabled and state.WebhookURL ~= "" then
                        local newMults = getMultipliers()
                        if prevMults and newMults then
                            local upgradesStr = ""
                            if state.UpFist and prevMults.FS ~= newMults.FS then upgradesStr = upgradesStr .. "Fist Strength: **" .. newMults.FS .. "**\n" end
                            if state.UpBody and prevMults.BT ~= newMults.BT then upgradesStr = upgradesStr .. "Body Toughness: **" .. newMults.BT .. "**\n" end
                            if state.UpSpeed and prevMults.MS ~= newMults.MS then upgradesStr = upgradesStr .. "Movement Speed: **" .. newMults.MS .. "**\n" end
                            if state.UpJump and prevMults.JF ~= newMults.JF then upgradesStr = upgradesStr .. "Jump Force: **" .. newMults.JF .. "**\n" end
                            if state.UpPsychic and prevMults.PP ~= newMults.PP then upgradesStr = upgradesStr .. "Psychic Power: **" .. newMults.PP .. "**\n" end
                            
                            if upgradesStr ~= "" then
                                task.spawn(function()
                                    sendDiscordPing(state.WebhookURL, state.UserID, "⭐ Successful Upgrade!", upgradesStr, 16753920)
                                end)
                            end
                        end
                    end
                end
            end)
        end
    end,
})

-- ==========================================
-- === COMBAT TAB ===
-- ==========================================
local CombatTab = Window:CreateTab("Combat & Misc", 4483345998)

CombatTab:CreateSection("Combat")

CombatTab:CreateToggle({
    Name = "Auto Shoot NPCs",
    CurrentValue = false,
    Flag = "ToggleAutoShoot",
    Callback = function(Value)
        isAutoShooting = Value
        if isAutoShooting then
            task.spawn(function()
                while isAutoShooting do
                    local targetNPC = getClosestNPC()
                    if targetNPC then
                        local targetPos = targetNPC.HumanoidRootPart.Position
                        UseSkillRemote:FireServer("EnergySphere", vector.create(targetPos.X, targetPos.Y, targetPos.Z))
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

CombatTab:CreateSection("Utilities")

CombatTab:CreateToggle({
    Name = "Anti-AFK Protection",
    CurrentValue = true,
    Flag = "ToggleAntiAFK",
    Callback = function(Value)
        state.AntiAFK = Value
    end,
})

-- ==========================================
-- === SETTINGS TAB ===
-- ==========================================
local SettingsTab = Window:CreateTab("Settings", 4483345998)

SettingsTab:CreateSection("Hub Controls")

SettingsTab:CreateButton({
    Name = "Destroy Hub",
    Callback = function()
        isAutoRolling = false
        isAutoShooting = false
        isAutoUpgrading = false
        Rayfield:Destroy()
    end,
})

-- 🔥 LOAD SAVED SETTINGS
Rayfield:LoadConfiguration()