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
    RollDelay = 0.3,
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
    UpPsychic = false,
    AutoClaimDaily = false,
    
    -- Crate Finder States
    FindCommon = false,
    FindRare = false,
    FindEpic = false,
    FindLegendary = false,
    FindMythic = false,
    FindGodly = false,
    FindSecret = false
}

-- ==========================================
-- === 3. REMOTES, PATHS & LOGIC ===
-- ==========================================
local RollRemote = ReplicatedStorage:WaitForChild("RollRaceRF")
local SaveRemote = ReplicatedStorage:WaitForChild("SaveRaceRF")
local UseSkillRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("UseSkill")
local UpgradeRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("UpgradeMultiplier")
local QuestClaimRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("TimerQuestClaim")

local mainGui = player:WaitForChild("PlayerGui"):WaitForChild("RaceRollGui"):WaitForChild("Main")
local raceLabel = mainGui:WaitForChild("CurrentRaceLabel")
local saveButton = mainGui:WaitForChild("SaveButton")

local isAutoRolling = false
local isAutoShooting = false
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
    if not success then return nil end
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
    if not success then return nil end
    return result
end

local function sendDiscordPing(webhookUrl, userId, title, description, color)
    if not webhookUrl or webhookUrl == "" then return end
    local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if not httprequest then return end
    
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

    pcall(function()
        httprequest({
            Url = webhookUrl, Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(webhookData)
        })
    end)
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
                sendDiscordPing(state.WebhookURL, "", "📊 1-Minute Current Stats", desc, 3447003)
            end
        end
    end
end)

-- === CRATE TRACKER BACKGROUND LOOP ===
local trackedCrates = {} 
task.spawn(function()
    while true do
        task.wait(3) 
        if state.WebhookEnabled and state.WebhookURL ~= "" then
            
            if state.FindCommon or state.FindRare or state.FindEpic or state.FindLegendary or state.FindMythic or state.FindGodly or state.FindSecret then
                for _, obj in ipairs(workspace:GetChildren()) do
                    local isTargetCrate = false
                    local crateType = ""
                    local embedColor = 16777215 
                    
                    if state.FindCommon and obj.Name == "CommonCrate" then
                        isTargetCrate = true; crateType = "Common"; embedColor = 14540253 -- Off-White
                    elseif state.FindRare and obj.Name == "RareCrate" then
                        isTargetCrate = true; crateType = "Rare"; embedColor = 5294335 -- Light Blue
                    elseif state.FindEpic and obj.Name == "EpicCrate" then
                        isTargetCrate = true; crateType = "Epic"; embedColor = 16724991 -- Magenta
                    elseif state.FindLegendary and obj.Name == "LegendaryCrate" then
                        isTargetCrate = true; crateType = "Legendary"; embedColor = 16776960 -- Yellow
                    elseif state.FindMythic and obj.Name == "MythicCrate" then
                        isTargetCrate = true; crateType = "Mythic"; embedColor = 16711680 -- Red
                    elseif state.FindGodly and obj.Name == "GodlyCrate" then
                        isTargetCrate = true; crateType = "Godly"; embedColor = 65280 -- Green
                    elseif state.FindSecret and obj.Name == "SecretCrate" then
                        isTargetCrate = true; crateType = "Secret"; embedColor = 3289650 -- Dark Grey
                    end
                    
                    if isTargetCrate and not trackedCrates[obj] then
                        trackedCrates[obj] = os.clock()
                        
                        local desc = string.format("A **%s Crate** has spawned in the workspace! Quick, go find it before it despawns.", crateType)
                        sendDiscordPing(state.WebhookURL, state.UserID, "📦 " .. crateType .. " Crate Detected!", desc, embedColor)
                    end
                end
            end
            
            for crateObj, timeFound in pairs(trackedCrates) do
                if os.clock() - timeFound > 240 or not crateObj.Parent then
                    trackedCrates[crateObj] = nil
                end
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

RollTab:CreateInput({
    Name = "Roll Timeout Delay (Seconds)",
    PlaceholderText = "Default is 0.3. Press Enter to save.",
    RemoveTextAfterFocusLost = false,
    Flag = "RollDelayInput", 
    Callback = function(Text)
        local num = tonumber(Text)
        if num then
            state.RollDelay = num
        else
            state.RollDelay = 0.3
        end
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
                    
                    local timeout = os.clock() + (tonumber(state.RollDelay) or 0.3)
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

StatsTab:CreateSection("Auto-Upgrade Multipliers")

local function createUpgradeToggle(name, stateKey, remoteArg, multKey, emoji)
    StatsTab:CreateToggle({
        Name = "Auto " .. name,
        CurrentValue = false,
        Flag = "Toggle" .. stateKey,
        Callback = function(Value)
            state[stateKey] = Value
            if Value then
                task.spawn(function()
                    while state[stateKey] do
                        local prevMults = getMultipliers()
                        UpgradeRemote:FireServer(remoteArg)
                        task.wait(1)
                        
                        if state.WebhookEnabled and state.UpgradeWebhookEnabled and state.WebhookURL ~= "" then
                            local newMults = getMultipliers()
                            if prevMults and newMults and prevMults[multKey] ~= newMults[multKey] then
                                local updatesStr = emoji .. " " .. name .. ": **" .. newMults[multKey] .. "**"
                                sendDiscordPing(state.WebhookURL, state.UserID, "⭐ Successful Upgrade!", updatesStr, 16753920)
                            end
                        end
                    end
                end)
            end
        end,
    })
end

createUpgradeToggle("Fist Strength", "UpFist", "FistStrengthMultiplier", "FS", "💪")
createUpgradeToggle("Body Toughness", "UpBody", "BodyToughnessMultiplier", "BT", "🛡️")
createUpgradeToggle("Movement Speed", "UpSpeed", "MovementSpeedMultiplier", "MS", "⚡")
createUpgradeToggle("Jump Force", "UpJump", "JumpForceMultiplier", "JF", "🦘")
createUpgradeToggle("Psychic Power", "UpPsychic", "PsychicPowerMultiplier", "PP", "🧠")


-- ==========================================
-- === AUTO CLAIM TAB ===
-- ==========================================
local ClaimTab = Window:CreateTab("Auto Claim", 4483345998)

ClaimTab:CreateSection("Daily Quests")

local dailyStats = {"FistStrength", "BodyToughness", "MovementSpeed", "JumpForce", "PsychicPower"}

ClaimTab:CreateToggle({
    Name = "Auto Collect Daily Missions",
    CurrentValue = false,
    Flag = "ToggleAutoClaimDaily",
    Callback = function(Value)
        state.AutoClaimDaily = Value
        if state.AutoClaimDaily then
            task.spawn(function()
                while state.AutoClaimDaily do
                    for tier = 1, 9 do
                        for _, statName in ipairs(dailyStats) do
                            
                            local isValid = true
                            if (tier == 5 or tier == 8 or tier == 9) and (statName == "MovementSpeed" or statName == "JumpForce") then
                                isValid = false
                            end
                            
                            if isValid then
                                QuestClaimRemote:FireServer(tier, statName, "Daily")
                                task.wait(0.05) 
                            end
                            
                        end
                    end
                    task.wait(30) 
                end
            end)
        end
    end,
})

-- ==========================================
-- === CRATE TRACKER TAB ===
-- ==========================================
local CrateTab = Window:CreateTab("Crates", 4483345998)

CrateTab:CreateSection("Workspace Crate Radar")

CrateTab:CreateToggle({
    Name = "Detect Common Crates",
    CurrentValue = false,
    Flag = "ToggleFindCommon",
    Callback = function(Value) state.FindCommon = Value end,
})

CrateTab:CreateToggle({
    Name = "Detect Rare Crates",
    CurrentValue = false,
    Flag = "ToggleFindRare",
    Callback = function(Value) state.FindRare = Value end,
})

CrateTab:CreateToggle({
    Name = "Detect Epic Crates",
    CurrentValue = false,
    Flag = "ToggleFindEpic",
    Callback = function(Value) state.FindEpic = Value end,
})

CrateTab:CreateToggle({
    Name = "Detect Legendary Crates",
    CurrentValue = false,
    Flag = "ToggleFindLegendary",
    Callback = function(Value) state.FindLegendary = Value end,
})

CrateTab:CreateToggle({
    Name = "Detect Mythic Crates",
    CurrentValue = false,
    Flag = "ToggleFindMythic",
    Callback = function(Value) state.FindMythic = Value end,
})

CrateTab:CreateToggle({
    Name = "Detect Godly Crates",
    CurrentValue = false,
    Flag = "ToggleFindGodly",
    Callback = function(Value) state.FindGodly = Value end,
})

CrateTab:CreateToggle({
    Name = "Detect Secret Crates",
    CurrentValue = false,
    Flag = "ToggleFindSecret",
    Callback = function(Value) state.FindSecret = Value end,
})

-- ==========================================
-- === COMBAT & MISC TAB ===
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
    Callback = function(Text) state.WebhookURL = Text end,
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
                    Content = "Check your Discord for the ping.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end)
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
-- === SETTINGS TAB ===
-- ==========================================
local SettingsTab = Window:CreateTab("Settings", 4483345998)

SettingsTab:CreateSection("Hub Controls")

SettingsTab:CreateButton({
    Name = "Destroy Hub",
    Callback = function()
        isAutoRolling = false
        isAutoShooting = false
        state.UpFist = false
        state.UpBody = false
        state.UpSpeed = false
        state.UpJump = false
        state.UpPsychic = false
        state.AutoClaimDaily = false
        Rayfield:Destroy()
    end,
})

-- 🔥 LOAD SAVED SETTINGS
Rayfield:LoadConfiguration()