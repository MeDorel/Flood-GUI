getgenv().debugmode = false

local REPO_BASE = "https://raw.githubusercontent.com/MeDorel/Flood-GUI/refs/heads/main/"
getgenv().FloodRepoBase = REPO_BASE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local CONFIG = {
    SCRIPT_VERSION_NAME = "Flood GUI v3",
    LATEST_BUILD = 65,
    DISCORD_INVITE = "https://discord.gg/8N2M9fHJqa",
    SETTINGS_FILE = "Flood-GUI/settings.json",
    DEFAULT_WALKSPEED = 20,
    DEFAULT_JUMPPOWER = 50,
}

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players.LocalPlayerAdded:Wait()
    LocalPlayer = Players.LocalPlayer
end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local Multiplayer = workspace:WaitForChild("Multiplayer")

if isfolder and not isfolder("Flood-GUI") then pcall(makefolder, "Flood-GUI") end

local State = {
    Maps = {},
    HighlightOnlyMaps = {},
    WalkSpeed = CONFIG.DEFAULT_WALKSPEED,
    JumpPower = CONFIG.DEFAULT_JUMPPOWER,
    GodModeEnabled = false,
    NoclipEnabled = false,
    AirJumpEnabled = false,
    AutoPlayEnabled = false,
    AutoCollectEnabled = false,
    SwimEnabled = false,
    AutoLeaveEnabled = false,
    FE2Library = nil,
}
getgenv().State = function() return State end

if getgenv().FloodGUI_Loaded and getgenv().FloodGUI_Destroy then
    pcall(getgenv().FloodGUI_Destroy)
end
getgenv().FloodGUI_Loaded = true

local Connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

local Settings = {
    skip = { [1] = false, [2] = false, [3] = false, [4] = false, [5] = true, [6] = true },
    skipUnknown = false,
    webhook = { url = "", complete = true, death = true, failed = true, skipped = false },
}

local function loadSettings()
    if not (isfile and readfile and isfile(CONFIG.SETTINGS_FILE)) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG.SETTINGS_FILE)) end)
    if not ok or type(data) ~= "table" then return end
    if type(data.skip) == "table" then
        for dif = 1, 6 do
            local v = data.skip[tostring(dif)]
            if v == nil then v = data.skip[dif] end
            if v ~= nil then Settings.skip[dif] = v == true end
        end
    end
    Settings.skipUnknown = data.skipUnknown == true
    if type(data.webhook) == "table" then
        Settings.webhook.url = tostring(data.webhook.url or "")
        for _, key in ipairs({ "complete", "death", "failed", "skipped" }) do
            if data.webhook[key] ~= nil then Settings.webhook[key] = data.webhook[key] == true end
        end
    end
end

local saveQueued = false
local function saveSettings()
    getgenv().FloodSettings = Settings
    if saveQueued or not writefile then return end
    saveQueued = true
    task.delay(0.4, function()
        saveQueued = false
        local out = { skip = {}, skipUnknown = Settings.skipUnknown, webhook = Settings.webhook }
        for dif, on in pairs(Settings.skip) do out.skip[tostring(dif)] = on end
        pcall(writefile, CONFIG.SETTINGS_FILE, HttpService:JSONEncode(out))
    end)
end

loadSettings()
getgenv().FloodSettings = Settings

local FloodUI
do
    local ok, lib = pcall(function() return loadstring(game:HttpGet(REPO_BASE .. "UI/FloodUI.luau"))() end)
    if not ok or type(lib) ~= "table" then
        warn("Flood GUI: could not load the UI library.", lib)
        getgenv().FloodGUI_Loaded = false
        return
    end
    FloodUI = lib
end

local UI = FloodUI.new({ Title = "Flood GUI", Subtitle = "Flood Escape 2  •  v3", ToggleKey = Enum.KeyCode.J })
local Theme = FloodUI.Theme

local function notify(title, text, color, duration)
    UI:Notify(title, text, color, duration)
end

local function loadFE2Library()
    local ok, library = pcall(function() return require(ReplicatedStorage:FindFirstChild("FE2Library", true)) end)
    if ok and type(library) == "table" then
        State.FE2Library = library
        return true
    end
    warn("FE2Library require failed:", library)
    return false
end

local function populateMaps()
    if not State.FE2Library then return end
    local official = State.FE2Library.getOfficialMapData and State.FE2Library.getOfficialMapData() or {}
    for _, mapData in pairs(official) do
        if mapData.mapName and not table.find(State.Maps, mapData.mapName) then
            table.insert(State.Maps, mapData.mapName)
        end
    end

    local container = PlayerGui:FindFirstChild("MenuGui", true)
    container = container and container:FindFirstChild("Goals", true)
    container = container and container:FindFirstChild("Window", true)
    container = container and container:FindFirstChild("Content", true)
    container = container and container:FindFirstChild("Pages", true)
    container = container and container:FindFirstChild("Highlights", true)
    container = container and container:FindFirstChild("Maps", true)
    if container then
        for _, frame in pairs(container:GetChildren()) do
            if frame:IsA("Frame") and frame.Name == "HighlightFrame" and frame:FindFirstChild("MapName") then
                local name = string.match(frame.MapName.Text, "%[(.+)%]")
                if name then
                    name = name:gsub("%s*$", "")
                    if not table.find(State.Maps, name) then
                        table.insert(State.Maps, name)
                        table.insert(State.HighlightOnlyMaps, name)
                    end
                end
            end
        end
    end
    table.sort(State.Maps)
end

local function checkBuildVersion()
    local configInstance = ReplicatedStorage:FindFirstChild("Config")
    local build = configInstance and tonumber(configInstance:GetAttribute("BuildVersion"))
    if build and CONFIG.LATEST_BUILD < build then
        notify("Game updated", ("%s is %d version(s) behind. Report issues on the Discord."):format(CONFIG.SCRIPT_VERSION_NAME, build - CONFIG.LATEST_BUILD), Theme.Warn, 6)
    else
        notify("Loaded", CONFIG.SCRIPT_VERSION_NAME .. " is ready.", Theme.Good, 3)
    end
end

local function setupAntiIdle()
    connect(LocalPlayer.Idled, function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

local function disableAntiExploit()
    for _, scriptName in ipairs({ "CL_AntiExploit", "FE2_AntiExploit", "ClientAntiCheat" }) do
        local anti = game:FindFirstChild(scriptName, true)
        if anti then pcall(function() anti.Disabled = true end) end
    end
end

local function getRemoteKey()
    local remote = ReplicatedStorage:FindFirstChild("Remote")
    local req = remote and remote:FindFirstChild("ReqPasskey")
    if req and req:IsA("RemoteFunction") then
        local ok, key = pcall(req.InvokeServer, req)
        if ok then State.RemoteKey = -key end
    end
end

local function Touch(Character, Part)
    local root = Character.HumanoidRootPart
    local original = root.CFrame
    root.CFrame = CFrame.new(Part.Position)
    task.wait()
    root.CFrame = original
end

local function updateMovement()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.WalkSpeed ~= State.WalkSpeed then hum.WalkSpeed = State.WalkSpeed end
        if hum.JumpPower ~= State.JumpPower then hum.JumpPower = State.JumpPower end
    end
end

local function applyGodMode()
    if not State.GodModeEnabled then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health < 100 then hum.Health = 100 end
end

local function applyNoclip()
    local char = LocalPlayer.Character
    if not char then return end
    local shouldCollide = not State.NoclipEnabled
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") or part:IsA("UnionOperation") then
            if part.Name == "HumanoidRootPart" or part.Name == "Torso" or part:IsA("UnionOperation") or (part.CanCollide and part.Mass > 0.1) then
                part.CanCollide = shouldCollide
            end
        end
    end
end

local function sendTestWebhook()
    local url = Settings.webhook.url
    if url == "" then
        notify("Webhook", "Paste your webhook URL first.", Theme.Warn)
        return
    end
    local sender = request or http_request or (syn and syn.request)
    if not sender then
        notify("Webhook", "Your executor has no request function.", Theme.Bad)
        return
    end
    local icon = getgenv().FloodHeadshot
    if not icon then
        local ok, body = pcall(game.HttpGet, game, ("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=420x420&format=Png&isCircular=false"):format(LocalPlayer.UserId))
        if ok then
            local okJson, data = pcall(HttpService.JSONDecode, HttpService, body)
            icon = okJson and data and data.data and data.data[1] and data.data[1].imageUrl
        end
    end
    local ok, response = pcall(sender, {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            username = "Flood Tracker",
            avatar_url = icon,
            embeds = { {
                title = "✅  Webhook connected",
                description = "Flood GUI will send map results, deaths and load failures here.",
                color = 0x38A0FF,
                author = { name = ("%s (@%s)"):format(LocalPlayer.DisplayName, LocalPlayer.Name), icon_url = icon },
                thumbnail = { url = icon },
                footer = { text = "Flood Escape 2  •  Flood Tracker" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            } },
        }),
    })
    local status = ok and response and tonumber(response.StatusCode or response.Status)
    if status and status >= 200 and status < 300 then
        notify("Webhook", "Test message sent.", Theme.Good)
    else
        notify("Webhook", "Discord rejected it (status " .. tostring(status) .. "). Check the URL.", Theme.Bad, 6)
    end
end

local function difficultyColors()
    local colors = {
        Color3.fromRGB(85, 255, 127), Color3.fromRGB(255, 255, 127), Color3.fromRGB(255, 85, 127),
        Color3.fromRGB(170, 85, 255), Color3.fromRGB(230, 126, 34), Color3.fromRGB(211, 84, 0),
    }
    local ok, info = pcall(function() return State.FE2Library.getDifInfo(1) end)
    if ok and type(info) == "table" then
        for i = 1, 6 do
            if info[i] and typeof(info[i].Color) == "Color3" then colors[i] = info[i].Color end
        end
    end
    return colors
end

local function buildUI()

    local tabAuto = UI:Tab("Auto", "▶")
    local secAuto = tabAuto:Section("Autoplay")
    secAuto:Toggle({
        Name = "Auto-Play",
        Description = "Plays a recorded run for every map and queues the next one.",
        Callback = function(on)
            State.AutoPlayEnabled = on
            notify("Auto-Play", on and "Enabled. Step into the lift to begin." or "Disabled.", on and Theme.Good or Theme.Muted)
        end,
    })
    secAuto:Toggle({
        Name = "Auto Collect",
        Description = "Grabs the Escapee and the Lost Page when a map loads.",
        Callback = function(on)
            State.AutoCollectEnabled = on
            notify("Auto Collect", on and "Enabled." or "Disabled.", on and Theme.Good or Theme.Muted)
        end,
    })
    local secSession = tabAuto:Section("This session")
    local sessionLabel = secSession:Label("No maps played yet.")
    task.spawn(function()
        while UI.Gui and UI.Gui.Parent do
            local s = getgenv().FloodSession
            local line = State.AutoPlayEnabled and "Auto-Play on" or "Auto-Play off"
            if s then
                sessionLabel:Set(("<b>%d</b> maps  •  <b>%d</b> skipped  •  <b>%d</b> deaths  •  <b>%d</b> failed\n+<b>%d</b> coins  •  +<b>%d</b> gems  •  +<b>%d</b> XP  •  <b>%d</b> min"):format(
                    s.maps, s.skipped, s.deaths, s.failed, s.coins, s.gems, s.xp, math.floor((os.time() - s.start) / 60)), Theme.Text)
                line = ("%s\n%d maps  •  %d XP"):format(line, s.maps, s.xp)
            end
            UI:SetStatus(line, State.AutoPlayEnabled and Theme.Good or Theme.Muted)
            task.wait(1)
        end
    end)

    local tabSkip = UI:Tab("Skip", "⏭")
    local secSkip = tabSkip:Section("Avoid these difficulties")
    secSkip:Label("Maps on a ticked difficulty are skipped: your character resets and you re-queue for the next map.")
    local colors = difficultyColors()
    local items = {}
    for i, name in ipairs({ "Easy", "Normal (Medium)", "Hard", "Insane", "Crazy", "Crazy+" }) do
        items[i] = { Label = name, Value = i, Color = colors[i] }
    end
    local defaults = {}
    for dif = 1, 6 do if Settings.skip[dif] then table.insert(defaults, dif) end end
    local chips = secSkip:Chips({
        Name = "Skip list",
        Items = items,
        Default = defaults,
        Callback = function(values)
            for dif = 1, 6 do Settings.skip[dif] = values[dif] == true end
            saveSettings()
        end,
    })
    local secSkipMore = tabSkip:Section("More")
    local unknownToggle = secSkipMore:Toggle({
        Name = "Skip maps with unknown difficulty",
        Description = "Highlight and community maps are not in the game's difficulty list.",
        Default = Settings.skipUnknown,
        Callback = function(on) Settings.skipUnknown = on saveSettings() end,
    })
    secSkipMore:Button({
        Name = "Reset to Crazy + Crazy+",
        Color = Theme.Stroke,
        Callback = function()
            for dif = 1, 6 do
                chips:Set(dif, dif >= 5, true)
                Settings.skip[dif] = dif >= 5
            end
            unknownToggle:Set(false, true)
            Settings.skipUnknown = false
            saveSettings()
            notify("Skip list", "Reset to the defaults.", Theme.Accent)
        end,
    })

    local tabHook = UI:Tab("Webhook", "🔔")
    local secUrl = tabHook:Section("Discord")
    secUrl:Input({
        Name = "Webhook URL",
        Placeholder = "https://discord.com/api/webhooks/...",
        Password = true,
        Default = Settings.webhook.url,
        Callback = function(value)
            Settings.webhook.url = (value:gsub("%s+", ""))
            saveSettings()
        end,
    })
    secUrl:Button({ Name = "Send test message", Callback = sendTestWebhook })
    local secEvents = tabHook:Section("Send a message when")
    local function hookToggle(name, description, key)
        secEvents:Toggle({
            Name = name,
            Description = description,
            Default = Settings.webhook[key],
            Callback = function(on) Settings.webhook[key] = on saveSettings() end,
        })
    end
    hookToggle("A map is completed", "Stats, gains, XP bar and your session summary.", "complete")
    hookToggle("You die", "Which map and how far through the run.", "death")
    hookToggle("A map fails to load", "Missing run file, no spawn, or the map never loads.", "failed")
    hookToggle("A map is skipped", "Off by default so it does not get noisy.", "skipped")
    tabHook:Section("Notes"):Label("Your URL is only stored in Flood-GUI/settings.json on this computer. Never share it: anyone with it can post in your channel.")

    local tabPlayer = UI:Tab("Player", "🏃")
    local secMove = tabPlayer:Section("Movement")
    secMove:Slider({
        Name = "Walkspeed", Min = 1, Max = 100, Default = CONFIG.DEFAULT_WALKSPEED,
        Callback = function(v) State.WalkSpeed = math.max(1, v) end,
    })
    secMove:Slider({
        Name = "Jump power", Min = 0, Max = 200, Default = CONFIG.DEFAULT_JUMPPOWER,
        Callback = function(v) State.JumpPower = math.max(0, v) end,
    })

    local tabBlatant = UI:Tab("Blatant", "⚡")
    local secBlatant = tabBlatant:Section("Toggles and keybinds")
    local function blatant(name, description, default, stateKey, after)
        local toggle
        toggle = secBlatant:Toggle({
            Name = name,
            Description = description,
            Callback = function(on)
                State[stateKey] = on
                if after then after() end
            end,
        })
        secBlatant:Keybind({
            Name = name .. " key",
            Default = default,
            Callback = function() toggle:Set(not toggle.Value) end,
        })
    end
    blatant("Infinite Air", "Stops you from drowning.", Enum.KeyCode.R, "GodModeEnabled")
    blatant("Noclip", "Walk through walls.", Enum.KeyCode.G, "NoclipEnabled", applyNoclip)
    blatant("Air Jump", "Jump again while in the air.", Enum.KeyCode.M, "AirJumpEnabled")
    blatant("TAS Swim Mode", "For TAS recording: pretends you are in lobby water.", Enum.KeyCode.T, "SwimEnabled")

    local tabTools = UI:Tab("Tools", "🛠")
    local secTools = tabTools:Section("Utilities")
    secTools:Toggle({
        Name = "Auto-Leave",
        Description = "Leaves the game if another player joins.",
        Callback = function(on) State.AutoLeaveEnabled = on end,
    })
    secTools:Button({
        Name = "Rejoin server",
        Callback = function()
            notify("Rejoin", "Teleporting to a new server...", Theme.Accent)
            pcall(TeleportService.Teleport, TeleportService, game.PlaceId, LocalPlayer)
        end,
    })
    secTools:Button({
        Name = "Create TAS recording",
        Color = Theme.Stroke,
        Callback = function()
            loadstring(game:HttpGet(REPO_BASE .. "TAS/CREATOR/creator.luau"))()
        end,
    })
    secTools:Button({
        Name = "Load Infinite Yield",
        Color = Theme.Stroke,
        Callback = function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/edgeiy/infiniteyield/master/source"))()
        end,
    })

    local tabCredits = UI:Tab("Credits", "♥")
    local secCredits = tabCredits:Section("Made by")
    secCredits:Label("TAS record and playback: <b>Voiz</b>\nReverse engineering and base GUI: <b>tomato.txt</b>\nStat tracker concept and misc: <b>Moz</b>\nInterface, skip list and webhooks: this version")
    secCredits:Button({
        Name = "Copy Discord invite",
        Callback = function()
            if setclipboard then
                pcall(setclipboard, CONFIG.DISCORD_INVITE)
                notify("Discord", "Invite copied to your clipboard.", Theme.Good)
            else
                notify("Discord", CONFIG.DISCORD_INVITE, Theme.Accent, 8)
            end
        end,
    })
end

local function setupEventHandlers()
    connect(RunService.Heartbeat, function()
        pcall(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                updateMovement()
                applyGodMode()
            end
        end)
    end)

    connect(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if State.AirJumpEnabled and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum:GetState() == Enum.HumanoidStateType.Freefall then
                hrp.Velocity = Vector3.new(hrp.Velocity.X, State.JumpPower * 0.8, hrp.Velocity.Z)
            end
        end
    end)

    connect(Players.PlayerAdded, function(player)
        if State.AutoLeaveEnabled and player ~= LocalPlayer then
            notify("Auto-Leave", ("%s joined. Leaving."):format(player.Name), Theme.Warn)
            task.wait(0.5)
            pcall(LocalPlayer.Kick, LocalPlayer, "Flood GUI: Auto-Leave triggered by player joining.")
        end
    end)

    if getgenv().hookmetamethod and not getgenv().FloodSwimHooked then
        getgenv().FloodSwimHooked = true
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", function(self, index)
            if State.SwimEnabled and index == "Position" and tostring(self) == "HumanoidRootPart" and not checkcaller() then
                return Vector3.new(-23, -153, 0)
            end
            return oldIndex(self, index)
        end)
    end
end

local alive = true
local cachedPlayerSource
local function readPlayerSource()
    if cachedPlayerSource then return cachedPlayerSource end
    local ok, src = pcall(game.HttpGet, game, REPO_BASE .. "TAS/PLAYER/newtasplayer.luau")
    if ok and #src > 1000 then cachedPlayerSource = src end
    return cachedPlayerSource
end

local function runTASPlayerLoop()
    task.spawn(function()
        while alive and task.wait(1) do
            if State.AutoPlayEnabled then
                local connections = getgenv().TASConnections
                if not (connections and #connections > 0) then
                    local source = readPlayerSource()
                    if source then
                        local fn, err = loadstring(source)
                        if fn then task.spawn(fn) else warn("Error loading TAS player:", err) end
                    else
                        warn("Could not read the TAS player.")
                    end
                    task.wait(3)
                end
            end
        end
    end)
end

local function runAutoCollectLoop()
    task.spawn(function()
        while alive do
            local Map = Multiplayer:WaitForChild("NewMap")
            Map:GetPropertyChangedSignal("Name"):Wait()
            if State.AutoCollectEnabled then
                local skipCollect = false
                if getgenv().FloodSkipMap then
                    local settings = Map:WaitForChild("Settings", 10)
                    local mapNameNow = settings and settings:GetAttribute("MapName")
                    if mapNameNow and getgenv().FloodSkipMap(mapNameNow) then skipCollect = true end
                end
                if not skipCollect then
                    local Character = LocalPlayer.Character
                    local Rescue = Map:FindFirstChild("_Rescue", true)
                    local LostPage = Map:FindFirstChild("_LostPage", true)
                    if Character and Rescue then Touch(Character, Rescue.Contact) end
                    if Character and LostPage then Touch(Character, LostPage) end
                end
            end
        end
    end)
end

UI.OnDestroy = function()
    alive = false
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    getgenv().FloodGUI_Loaded = false
end
getgenv().FloodGUI_Destroy = function() UI:Destroy() end

local ok, err = pcall(function()
    loadFE2Library()
    populateMaps()
    setupAntiIdle()
    disableAntiExploit()
    getRemoteKey()
    buildUI()
    saveSettings()
    setupEventHandlers()
    runTASPlayerLoop()
    runAutoCollectLoop()
    checkBuildVersion()
end)
if not ok then
    warn("FATAL ERROR during Flood GUI initialization:", err)
    notify("Flood GUI failed to start", tostring(err), Theme.Bad, 10)
    getgenv().FloodGUI_Loaded = false
end
