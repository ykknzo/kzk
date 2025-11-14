--[[
 __                  __       
|  \                |  \      
| $$   __  ________ | $$   __ 
| $$  /  \|        \| $$  /  \
| $$_/  $$ \$$$$$$$$| $$_/  $$
| $$   $$   /    $$ | $$   $$ 
| $$$$$$\  /  $$$$_ | $$$$$$\ 
| $$  \$$\|  $$    \| $$  \$$\
 \$$   \$$ \$$$$$$$$ \$$   \$$
------------------------------
discord.gg/WuhJwUUbTE
]]--

local Players           = game:GetService("Players")
local Lighting          = game:GetService("Lighting")
local StarterGui        = game:GetService("StarterGui")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")

local LocalPlayer       = Players.LocalPlayer

-- FIX: Wait for LocalPlayer to exist before proceeding
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

task.wait(0.5) 
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")
local sunsetEnabled, noclipEnabled, invis_on = false, false, false
local originalLighting, originalAtmosphere = nil, nil
local noclipConnection = nil
local buttonY = 50
local invis_transparency = 0.75
local voidLevelYThreshold = -50 
local seatTeleportPosition = Vector3.new(-25.95, 400, 3537.55) 

-- FIX: Added pcall for robustness in case StarterGui is restricted
local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "KZK Scripts",
            Text = msg,
            Duration = 2
        })
    end)
end

-- =========================================================================
-- LOGIC FUNCTIONS
-- =========================================================================

local function toggleSunset(btn)
    if not originalLighting then
        originalLighting = {
            ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
            ColorShift_Top = Lighting.ColorShift_Top, ColorShift_Bottom = Lighting.ColorShift_Bottom,
            Brightness = Lighting.Brightness, FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd
        }
        local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmos then
            originalAtmosphere = { Haze = atmos.Haze, Density = atmos.Density, Color = atmos.Color }
        end
    end

    sunsetEnabled = not sunsetEnabled
    if sunsetEnabled then
        Lighting.ClockTime = 17.75
        Lighting.Ambient = Color3.fromRGB(128, 60, 0)
        Lighting.OutdoorAmbient = Color3.fromRGB(190, 100, 50)
        Lighting.ColorShift_Top = Color3.fromRGB(255, 150, 50)
        Lighting.ColorShift_Bottom = Color3.fromRGB(100, 50, 150)
        Lighting.Brightness = 1.5
        Lighting.FogColor = Color3.fromRGB(150, 100, 80)
        Lighting.FogEnd = 2500

        local atmos = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
        atmos.Haze = 1; atmos.Density = 0.3; atmos.Color = Color3.fromRGB(190, 120, 80)
        btn.Text = "Sunset: ON"
        notify("Sunset applied")
    else
        for k, v in pairs(originalLighting) do Lighting[k] = v end
        local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmos and originalAtmosphere then
            for k, v in pairs(originalAtmosphere) do atmos[k] = v end
        elseif atmos then atmos:Destroy() end
        btn.Text = "Sunset: OFF"
        notify("Sunset removed")
    end
end

local function toggleNoclip(btn)
    noclipEnabled = not noclipEnabled
    if noclipEnabled then
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end)
        btn.Text = "Noclip: ON"
        notify("Noclip enabled")
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
        local char = LocalPlayer.Character
        if char then
            -- Only set CanCollide back to true for parts that were BaseParts
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true 
                end
            end
        end
        btn.Text = "Noclip: OFF"
        notify("Noclip disabled")
    end
end

local function setCharacterTransparency(transparency)
    local character = LocalPlayer.Character
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = transparency
            end
            -- FIX: Also handle accessories (e.g., hats, hair)
            if part:IsA("Accessory") then
                local handle = part:FindFirstChild("Handle")
                if handle then handle.Transparency = transparency end
            end
        end
    end
end

local function toggleInvisibility(btn)
    invis_on = not invis_on
    btn.Text = "Invisibility: " .. (invis_on and "ON" or "OFF")
    btn.BackgroundColor3 = invis_on and Color3.fromRGB(150, 0, 255) or Color3.fromRGB(70, 0, 120)

    local function cleanupAndFail(msg)
        invis_on = false
        setCharacterTransparency(0)
        btn.Text = "Invisibility: OFF"
        btn.BackgroundColor3 = Color3.fromRGB(70, 0, 120)
        local inv = workspace:FindFirstChild('invischair')
        if inv then pcall(function() inv:Destroy() end) end
        notify("Invisibility failed – " .. msg)
    end

    if invis_on then
        setCharacterTransparency(invis_transparency)
        local character = LocalPlayer.Character
        if not character then return cleanupAndFail("character missing") end

        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") 
        if not humanoidRootPart or not torso then return cleanupAndFail("parts missing") end

        local savedpos = humanoidRootPart.CFrame
        task.wait(0.05)

        pcall(function() character:MoveTo(seatTeleportPosition) end)
        task.wait(0.1)

        if not character:FindFirstChild("HumanoidRootPart") or
           character.HumanoidRootPart.Position.Y < voidLevelYThreshold then
            pcall(function() character:MoveTo(savedpos.p) end)
            return cleanupAndFail("fell into void or failed teleport")
        end

        -- FIX: Use a normal Part and Motor6D for modern, reliable invisibility
        local InvisPart = Instance.new('Part') 
        InvisPart.Parent = workspace
        InvisPart.Anchored = true
        InvisPart.CanCollide = false
        InvisPart.Name = 'invischair'
        InvisPart.Transparency = 1
        InvisPart.CFrame = savedpos
        
        local Weld = Instance.new("Motor6D") -- Using Motor6D is generally better than Weld
        Weld.Part0 = InvisPart
        Weld.Part1 = torso
        Weld.C0 = torso.CFrame:Inverse() * InvisPart.CFrame
        Weld.Parent = InvisPart
        
        pcall(function() humanoidRootPart.CFrame = savedpos end)
        notify("Invisibility ENABLED")

    else 
        setCharacterTransparency(0)
        notify("Invisibility DISABLED")
        task.spawn(function()
            local inv = workspace:FindFirstChild('invischair')
            if inv then pcall(function() inv:Destroy() end) end
        end)
    end
end

local function createButton(name, yOffset, bg, text, txtColor, callback)
    local gui = PlayerGui:FindFirstChild("KZKGui") or Instance.new("ScreenGui", PlayerGui)
    gui.Name = "KZKGui"
    gui.ResetOnSpawn = false

    local btn = Instance.new("TextButton", gui)
    btn.Name = name
    btn.Size = UDim2.new(0, 150, 0, 40)
    btn.Position = UDim2.new(0, 10, 1, -yOffset)
    btn.BackgroundColor3 = bg
    btn.Text = text
    btn.TextColor3 = txtColor
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.ZIndex = 10

    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 10)

    btn.MouseButton1Click:Connect(function() callback(btn) end)
    return btn
end

-- =========================================================================
-- MAIN EXECUTION
-- =========================================================================

local success, message = pcall(function()

    createButton("InvisToggle", buttonY * 1, Color3.fromRGB(70, 0, 120), "Invisibility: OFF", Color3.fromRGB(200, 150, 255), toggleInvisibility)

    createButton("SunsetToggle", buttonY * 2, Color3.fromRGB(15, 30, 50), "Sunset: OFF", Color3.fromRGB(255, 180, 120), toggleSunset)

    createButton("RejoinButton", buttonY * 3, Color3.fromRGB(50, 15, 15), "Rejoin Server", Color3.fromRGB(255, 150, 150), function(btn)
        local originalText = btn.Text
        btn.Text = "Rejoining..."
        notify("Rejoining current server...")
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        task.wait(2) -- Wait for teleport before resetting text (unlikely to run, but good practice)
        btn.Text = originalText
    end)

    createButton("NoclipToggle", buttonY * 4, Color3.fromRGB(15, 50, 30), "Noclip: OFF", Color3.fromRGB(150, 255, 150), toggleNoclip)

    -- Teleport Tool Initialization
    local mouse = LocalPlayer:GetMouse()
    local tool = Instance.new("Tool", LocalPlayer.Backpack)
    tool.RequiresHandle = false
    tool.Name = "KZK Tp Tool"
    tool.Activated:Connect(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and mouse.Hit then 
            hrp.CFrame = CFrame.new(mouse.Hit.p + Vector3.new(0, 2.5, 0)) 
        end
    end)

    -- External Scripts Loader (Kept as is, but wrapped in pcall/httpget for best effort)
    local function loadExternalScripts()
        local urls = {
            "https://pastefy.app/w96hAwTH/raw",
            "https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua",
            "https://pastefy.app/JBtJnxqE/raw",
            "https://pastefy.app/LmM1glQO/raw?part=addon.lua",
            "https://akadmin-bzk.pages.dev/kikorewind.lua",
            "https://akadmin-bzk.pages.dev/kikoslip.lua",
            "https://pastebin.com/raw/RfFGyXEX",
            "https://pastefy.app/9GzeSa5j/raw"
        }
        for _, url in ipairs(urls) do
            pcall(function() 
                local scriptCode = game:HttpGet(url, true)
                if scriptCode then 
                    loadstring(scriptCode)()
                end
            end)
        end
    end

    loadExternalScripts()
    notify("KZK Scripts Loaded Successfully")

end)
