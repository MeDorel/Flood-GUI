local INPUT = loadstring(game:HttpGet("https://raw.githubusercontent.com/tomatotxt/-/refs/heads/main/input.luau"))()

local UserInputService = game:GetService("UserInputService")
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local TimeModifier = 1
local DynamicTimeScale = 1
local SwimSmoothness = 0.04

print("Welcome to the TAS Player! (V65) - Auto-Queue Active")

if getgenv().TAS_RestoreAnim then
    pcall(getgenv().TAS_RestoreAnim)
    getgenv().TAS_RestoreAnim = nil
end

if getgenv().TASConnections then
    for _, connection in pairs(getgenv().TASConnections) do
        if connection then connection:Disconnect() end
    end
end
getgenv().TASConnections = {}

local function AddConnection(conn)
    table.insert(getgenv().TASConnections, conn)
    return conn
end

local SkipMirroredMaps = {
    ["Retro Coast"] = true, ["Zemblanity"] = true, ["Northern Mill"] = true,
    ["Mysterium"] = true, ["Decaying Silo"] = true, ["Active Volcanic Mines"] = true,
    ["Snowy Stronghold"] = true, ["Classic Canyon"] = true
}
local State = getgenv().State
if State and State().HighlightOnlyMaps then
    for _,v in ipairs(State().HighlightOnlyMaps) do SkipMirroredMaps[v] = true end
end

local Mirrored = false
local NewV = Vector3.new
local NewC = CFrame.new
local AngC = CFrame.fromEulerAnglesXYZ
local LP = game.Players.LocalPlayer
local Multi = workspace.Multiplayer
local RS = game:GetService('RunService')
local HttpService = game:GetService("HttpService")

local CLMAIN = getsenv(LP.PlayerScripts:WaitForChild("CL_MAIN_GameScript", 10))

local Theme = {
    System = Color3.fromRGB(150, 150, 255),
    Info = Color3.fromRGB(220, 220, 220),
    Success = Color3.fromRGB(80, 220, 120),
    Warning = Color3.fromRGB(255, 170, 0),
    Error = Color3.fromRGB(255, 60, 60),
    Highlight = Color3.fromRGB(0, 200, 255)
}

local function Log(msg, category)
    local color = Theme[category] or Theme.Info
    local text = "[TAS] " .. msg
    print(text)
    if CLMAIN and type(CLMAIN.newAlert) == "function" then
        CLMAIN.newAlert(text, color)
    end
end

local Config = {
    WebhookUrl = "",
    Username = "Flood Tracker",
    NotifyComplete = true,
    NotifyDeath = true,
    NotifyFailed = true,
    NotifySkip = false,
    SkipUnknown = false,
    SkipDifficulties = { [5] = true, [6] = true },
}
local GuiSettings = getgenv().FloodSettings
if type(GuiSettings) == "table" then
    Config.SkipDifficulties = {}
    for dif, on in pairs(GuiSettings.skip or {}) do
        if on and tonumber(dif) then Config.SkipDifficulties[tonumber(dif)] = true end
    end
    Config.SkipUnknown = GuiSettings.skipUnknown == true
    local hook = GuiSettings.webhook or {}
    Config.WebhookUrl = hook.url or ""
    Config.NotifyComplete = hook.complete ~= false
    Config.NotifyDeath = hook.death ~= false
    Config.NotifyFailed = hook.failed ~= false
    Config.NotifySkip = hook.skipped == true
end
if type(getgenv().FloodConfig) == "table" then
    for k, v in pairs(getgenv().FloodConfig) do Config[k] = v end
end
if Config.WebhookUrl == "" and isfile and isfile("Flood-GUI/webhook.txt") then
    local okRead, txt = pcall(readfile, "Flood-GUI/webhook.txt")
    if okRead and txt then Config.WebhookUrl = (txt:gsub("%s+", "")) end
end

local Session = getgenv().FloodSession
if not Session then
    Session = { start = os.time(), maps = 0, deaths = 0, failed = 0, skipped = 0, coins = 0, gems = 0, xp = 0, runSeconds = 0 }
    getgenv().FloodSession = Session
end

local DifByMap, DifInfo = {}, nil
do
    local okLib, FE2 = pcall(function()
        return require(game:GetService("ReplicatedStorage"):FindFirstChild("FE2Library", true))
    end)
    if okLib and type(FE2) == "table" then
        pcall(function()
            for _, m in pairs(FE2.getOfficialMapData()) do
                if m.mapName and m.mapDif then DifByMap[m.mapName] = m.mapDif end
            end
        end)
        pcall(function() DifInfo = FE2.getDifInfo(1) end)
    end
end

local function DifName(dif)
    if not dif then return "Unknown difficulty" end
    local info = DifInfo and DifInfo[dif]
    return info and info.Name or ("Difficulty " .. tostring(dif))
end

local function DifColor(dif)
    local info = DifInfo and DifInfo[dif]
    local c = info and info.Color
    if typeof(c) == "Color3" then
        return math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
    end
    return 0x5865F2
end

local function ShouldSkipMap(mapName)
    local dif = DifByMap[mapName]
    if dif and Config.SkipDifficulties[dif] then return true, dif end
    if not dif and Config.SkipUnknown then return true, nil end
    return false, dif
end
getgenv().FloodSkipMap = ShouldSkipMap

local function ParseAmount(text)
    if not text then return nil end
    local clean = tostring(text):gsub(",", "")
    local num, suffix = clean:match("([%d%.]+)%s*([KkMmBb]?)")
    num = tonumber(num)
    if not num then return nil end
    suffix = suffix:lower()
    if suffix == "k" then num = num * 1e3 elseif suffix == "m" then num = num * 1e6 elseif suffix == "b" then num = num * 1e9 end
    return math.floor(num + 0.5)
end

local function ReadStats()
    local ok, res = pcall(function()
        local stats = LP.PlayerGui.GameGui.HUD.Main.GameStats.Stats
        local xpText = tostring(stats.XPStats.XP.Text):gsub(",", "")
        local cur, need = xpText:match("(%d+)%s*/%s*(%d+)")
        return {
            coins = ParseAmount(stats.Currency.CoinAmt.Amount.Text) or 0,
            gems = ParseAmount(stats.Currency.GemAmt.Amount.Text) or 0,
            level = ParseAmount(stats.XPStats.Icon.Info.Text) or 0,
            rebirth = tostring(stats.XPStats.Rebirth.Info.Text),
            xp = tonumber(cur) or 0,
            xpNeed = tonumber(need) or 0,
        }
    end)
    return ok and res or nil
end

local function Commas(n)
    local s = tostring(math.floor(math.abs(n) + 0.5))
    s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (n < 0 and "-" or "") .. s
end

local function Signed(n) return (n >= 0 and "+" or "-") .. Commas(math.abs(n)) end

local function FormatTime(sec)
    sec = math.max(0, sec)
    local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
    if h > 0 then return string.format("%dh %02dm", h, m) end
    return string.format("%d:%04.1f", m, sec % 60)
end

local function Bar(frac, len)
    len = len or 12
    local filled = math.clamp(math.floor(frac * len + 0.5), 0, len)
    return string.rep("▰", filled) .. string.rep("▱", len - filled)
end

local HttpRequest = request or http_request or (syn and syn.request) or (http and http.request)
local Headshot = getgenv().FloodHeadshot
local function GetHeadshot()
    if Headshot then return Headshot end
    local ok, body = pcall(game.HttpGet, game, ("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=420x420&format=Png&isCircular=false"):format(LP.UserId))
    if ok then
        local okJson, data = pcall(HttpService.JSONDecode, HttpService, body)
        local url = okJson and data and data.data and data.data[1] and data.data[1].imageUrl
        if type(url) == "string" and url ~= "" then Headshot = url end
    end
    Headshot = Headshot or ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png"):format(LP.UserId)
    getgenv().FloodHeadshot = Headshot
    return Headshot
end

local Queue = getgenv().FloodWebhookQueue
if not Queue then
    Queue = {}
    getgenv().FloodWebhookQueue = Queue
    task.spawn(function()
        while true do
            local item = table.remove(Queue, 1)
            if item and HttpRequest then
                pcall(HttpRequest, {
                    Url = item.url,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(item.payload),
                })
                task.wait(1.5)
            else
                task.wait(0.5)
            end
        end
    end)
end

local function SendEmbed(embed)
    if Config.WebhookUrl == "" or not HttpRequest then return end
    local icon = GetHeadshot()
    embed.author = {
        name = ("%s (@%s)"):format(LP.DisplayName, LP.Name),
        url = "https://www.roblox.com/users/" .. LP.UserId .. "/profile",
        icon_url = icon,
    }
    embed.thumbnail = { url = icon }
    embed.footer = { text = "Flood Escape 2  •  Flood Tracker", icon_url = icon }
    embed.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    table.insert(Queue, {
        url = Config.WebhookUrl,
        payload = { username = Config.Username, avatar_url = icon, embeds = { embed } },
    })
end

local function SessionLine()
    return ("🗺️ **%d** maps  •  💀 **%d** deaths  •  ⚠️ **%d** failed  •  ⏭️ **%d** skipped\n"
        .. "💰 %s  •  💎 %s  •  ⭐ %s XP  •  🕒 %s"):format(
        Session.maps, Session.deaths, Session.failed, Session.skipped,
        Signed(Session.coins), Signed(Session.gems), Signed(Session.xp), FormatTime(os.time() - Session.start))
end

local Webhook = {}

function Webhook.Complete(mapName, dif, seconds, before)
    Session.maps += 1
    Session.runSeconds += seconds
    task.spawn(function()
        task.wait(5)
        local after = ReadStats()
        if not after then return end
        before = before or after

        local leveled = after.level > before.level
        local dCoins, dGems = after.coins - before.coins, after.gems - before.gems
        local dXp = after.xp - before.xp
        if leveled then dXp = (before.xpNeed - before.xp) + after.xp end
        Session.coins += dCoins
        Session.gems += dGems
        Session.xp += math.max(dXp, 0)
        if not Config.NotifyComplete then return end

        local toLevel = math.max(after.xpNeed - after.xp, 0)
        local frac = after.xpNeed > 0 and after.xp / after.xpNeed or 0
        local avgXp = Session.maps > 0 and Session.xp / Session.maps or 0
        local eta = (avgXp > 0 and toLevel > 0) and ("~**%d** more map(s) at your **%s XP/map** average"):format(math.ceil(toLevel / avgXp), Commas(avgXp)) or "Keep going!"

        local fields = {
            { name = "💰 Coins", value = ("`%s`\n%s this map"):format(Commas(after.coins), Signed(dCoins)), inline = true },
            { name = "💎 Gems", value = ("`%s`\n%s this map"):format(Commas(after.gems), Signed(dGems)), inline = true },
            { name = "⭐ Level", value = ("`%s`\nRebirth %s"):format(Commas(after.level), after.rebirth), inline = true },
            {
                name = "📈 XP Progress",
                value = ("`%s` **%.1f%%**\n%s / %s XP  •  **%s XP to level up**"):format(Bar(frac), frac * 100, Commas(after.xp), Commas(after.xpNeed), Commas(toLevel)),
                inline = false,
            },
            { name = "⚡ XP Gained", value = ("`%s XP`"):format(Signed(dXp)), inline = true },
            { name = "🎯 Next Level", value = eta, inline = true },
            { name = "📊 Session", value = SessionLine(), inline = false },
        }
        SendEmbed({
            title = leveled and ("🎉  LEVEL UP!  %d → %d"):format(before.level, after.level) or "🏁  Map Completed",
            description = ("**%s**  •  %s\nCleared in **%s**"):format(mapName, dif and DifName(dif) or "Unknown difficulty", FormatTime(seconds)),
            color = leveled and 0xFFD700 or DifColor(dif),
            fields = fields,
        })
    end)
end

function Webhook.Died(mapName, progress)
    Session.deaths += 1
    if not Config.NotifyDeath then return end
    local stats = ReadStats()
    local fields = {}
    if progress then
        table.insert(fields, { name = "📍 Progress", value = ("`%s` **%d%%**"):format(Bar(progress), math.floor(progress * 100)), inline = false })
    end
    if stats then
        table.insert(fields, { name = "⭐ Level", value = ("`%s`"):format(Commas(stats.level)), inline = true })
        table.insert(fields, { name = "💰 Coins", value = ("`%s`"):format(Commas(stats.coins)), inline = true })
        table.insert(fields, { name = "💎 Gems", value = ("`%s`"):format(Commas(stats.gems)), inline = true })
    end
    table.insert(fields, { name = "📊 Session", value = SessionLine(), inline = false })
    SendEmbed({
        title = "💀  Player Died",
        description = mapName and ("Died on **%s**"):format(mapName) or "Died before the map started.",
        color = 0xED4245,
        fields = fields,
    })
end

function Webhook.Failed(mapName, reason)
    Session.failed += 1
    if not Config.NotifyFailed then return end
    SendEmbed({
        title = "⚠️  Map Failed To Load",
        description = ("%s\n**Reason:** %s"):format(mapName and ("Map: **" .. mapName .. "**") or "No map name was available.", reason),
        color = 0xFAA61A,
        fields = { { name = "📊 Session", value = SessionLine(), inline = false } },
    })
end

function Webhook.Skipped(mapName, dif)
    Session.skipped += 1
    if not Config.NotifySkip then return end
    SendEmbed({
        title = "⏭️  Map Skipped",
        description = ("**%s** is **%s**, which is on your skip list. Re-queuing."):format(mapName, DifName(dif)),
        color = dif and DifColor(dif) or 0x99AAB5,
        fields = { { name = "📊 Session", value = SessionLine(), inline = false } },
    })
end

local CurrentMapName = nil
local SelfReset = false
local GetRunProgress = function() return nil end

task.spawn(function()
    local PlayerGui = LP:WaitForChild("PlayerGui", 10)
    local GameGui = PlayerGui and PlayerGui:WaitForChild("GameGui", 10)
    local HUD = GameGui and GameGui:WaitForChild("HUD", 10)
    local MapEventInfo = HUD and HUD:WaitForChild("MapEventInfo", 10)

    if MapEventInfo then
        AddConnection(MapEventInfo:GetPropertyChangedSignal("Text"):Connect(function()
            local currentText = MapEventInfo.Text
            local Events = {}
            for rawEventName in string.gmatch(currentText, ">(.-)</font>") do
                local formattedEventName = string.lower(rawEventName):gsub("%s+", "")
                table.insert(Events, formattedEventName)
            end

            if #Events > 0 then
                DynamicTimeScale = 1
                for _, eventName in ipairs(Events) do
                    if eventName == "speedup" then
                        DynamicTimeScale = DynamicTimeScale * (1 / 1.1225)
                    elseif eventName == "slowdown" then
                        DynamicTimeScale = DynamicTimeScale * (1 / (1 - 0.1091))
                    end
                end

                local speedMultiplier = 1 / DynamicTimeScale
                Log(string.format("Map event! Game speed adjusted to %.2fx", speedMultiplier), "Highlight")
            end
        end))
    end
end)

if not getgenv().alreadystarted then
    Log("Welcome to the TAS Engine! (v65)", "System")
    task.wait(0.1)
    Log("TAS Engine initialized.", "System")
    task.wait(0.1)
    Log("Current speed set to: " .. TimeModifier .. "x", "Highlight")
    getgenv().alreadystarted = true
else
    Log("TAS Engine reloaded! (v65)", "System")
    task.wait(0.15)
    Log("Current speed set to: " .. TimeModifier .. "x", "Highlight")
end

local WaterParts = {}

local function CacheWaterParts(MapFolder)
    WaterParts = {}
    local attempts = 0
    repeat
        for _, v in pairs(MapFolder:GetDescendants()) do
            if v:IsA("BasePart") and (string.find(v.Name, "_Water") or v.Parent.Name == "Waters") then
                if not table.find(WaterParts, v) then
                    table.insert(WaterParts, v)
                end
            end
        end
        if #WaterParts == 0 then
            attempts = attempts + 1
            task.wait(0.5)
        end
    until #WaterParts > 0 or attempts > 10

    if #WaterParts > 0 then
        Log("Found " .. #WaterParts .. " water areas for swimming.", "Success")
    else
        Log("Couldn't find any water areas on this map.", "Error")
    end
end

local function IsInWater(Position)
    for _, water in pairs(WaterParts) do
        local halfSize = water.Size * 0.5
        local objSpace = water.CFrame:PointToObjectSpace(Position)
        if math.abs(objSpace.Y) <= halfSize.Y and math.abs(objSpace.X) <= halfSize.X and math.abs(objSpace.Z) <= halfSize.Z then
            local waterState = water:FindFirstChild("WaterState")
            if not waterState or waterState:GetAttribute("NoSwim") ~= true then
                return true
            end
        end
    end
    return false
end

if not LP.Character or not LP.Character:FindFirstChild("Animate") then
    LP.CharacterAdded:Wait()
    LP.Character:WaitForChild("Animate", 10)
end

local Animate, OriginalPlayAnim
local SuccessHook, Err = pcall(function()
    local AnimateScript = LP.Character.Animate
    Animate = getsenv(AnimateScript)
    OriginalPlayAnim = Animate.playAnimation

    getgenv().TAS_RestoreAnim = function()
        if Animate and OriginalPlayAnim then
            Animate.playAnimation = OriginalPlayAnim
        end
    end
end)

if not SuccessHook or not Animate then
    Log("Warning: Could not connect to the game's animation system.", "Warning")
    Animate = { setAnimationSpeed = function() end, playAnimation = function() end }
    OriginalPlayAnim = function() end
end

local function toggleSlide(newValue)
    if not LP.Character then return end
    if newValue == true then
        if LP.Character:FindFirstChild("HumanoidRootPart") then LP.Character.HumanoidRootPart.Size = NewV(2, 1, 1) end
        if LP.Character:FindFirstChild("FE2_Hitbox") then LP.Character.FE2_Hitbox.Size = NewV(2, 1, 1) end
        if LP.Character:FindFirstChild("Humanoid") then LP.Character.Humanoid.HipHeight = -1.5 end
    else
        if LP.Character:FindFirstChild("HumanoidRootPart") then LP.Character.HumanoidRootPart.Size = NewV(2, 2, 1) end
        if LP.Character:FindFirstChild("FE2_Hitbox") then LP.Character.FE2_Hitbox.Size = NewV(2, 2, 1) end
        if LP.Character:FindFirstChild("Humanoid") then LP.Character.Humanoid.HipHeight = 0 end
    end
    if LP.Character and LP.Character:FindFirstChild("Animate") and LP.Character.Animate:FindFirstChild("Sliding") then
        LP.Character.Animate.Sliding:Fire(newValue)
    end
end

getgenv().IsTASPlaying = true
getgenv().TASCurrentMoveDir = Vector3.new(0,0,0)

if not getgenv().TASHookApplied then
    getgenv().TASHookApplied = true
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if getgenv().IsTASPlaying and key == "MoveDirection" then
            if self:IsA("Humanoid") and self.Parent == LP.Character then
                return getgenv().TASCurrentMoveDir
            end
        end
        return oldIndex(self, key)
    end)
end

local LastPlayedAnim = nil
local IsSliding = false
local SlideStartTime = 0
local LastSlideEndTime = -3.0
local SLIDE_DEBOUNCE = 3.0
local IsCurrentlySwimming = false
local IsCurrentlyZiplining = false

local IsManualZipline = false
local IsManualSlide = false

local LiftCheckPos = Vector3.new(-25, -144, 139)
local CleanedUp = false
local function Cleanup(resetCharacter)
    if CleanedUp then return end
    CleanedUp = true
    getgenv().IsTASPlaying = false

    IsSliding = false
    SlideStartTime = 0
    LastSlideEndTime = -3.0
    IsCurrentlyZiplining = false
    IsManualZipline = false
    IsManualSlide = false

    local playerGui = LP:FindFirstChild("PlayerGui")
    if playerGui then
        local oldGui = playerGui:FindFirstChild("TAS_GUI")
        if oldGui then oldGui:Destroy() end
    end

    if getgenv().TASConnections then
        for _, connection in pairs(getgenv().TASConnections) do
            if connection then connection:Disconnect() end
        end
        getgenv().TASConnections = {}
    end

    if getgenv().TAS_RestoreAnim then
        pcall(getgenv().TAS_RestoreAnim)
        getgenv().TAS_RestoreAnim = nil
    end

    if LP.Character then
        if LP.Character:FindFirstChild("Animate") and LP.Character.Animate:FindFirstChild("ToggleSwim") then
            pcall(function() LP.Character.Animate.ToggleSwim:Fire(false) end)
        end
        if LP.Character:FindFirstChild("Humanoid") then LP.Character.Humanoid.AutoRotate = true end
        toggleSlide(false)
    end

    if resetCharacter and LP.Character and LP.Character:FindFirstChild("Humanoid") then
        SelfReset = true
        Log("You reset or died. Halting the run and re-queuing...", "Error")
        LP.Character.Humanoid.Health = 0

        task.spawn(function()
            local newChar = LP.CharacterAdded:Wait()
            local newRoot = newChar:WaitForChild("HumanoidRootPart", 10)
            local Remote = game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("AddedWaiting")

            while newChar and newChar.Parent and newRoot do
                local dist = (newRoot.Position - LiftCheckPos).Magnitude
                if dist <= 30 then
                    print("[TAS] Entered lift. Waiting for map to load...")
                    break
                end

                Remote:FireServer()
                task.wait(0.5)
            end
        end)
    end
end

if LP.Character and LP.Character:FindFirstChild("Humanoid") then
    AddConnection(LP.Character.Humanoid.Died:Connect(function()
        if not SelfReset and not CleanedUp then Webhook.Died(CurrentMapName, GetRunProgress()) end
        Cleanup(false)
    end))
end
AddConnection(LP.CharacterRemoving:Connect(function() Cleanup(false) end))

local Map = nil

while not Map and not CleanedUp do
    local ConditionsMet = false
    Log("Waiting for you to step into the lift...", "Warning")

    repeat
        task.wait(0.2)
        local Root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if Root then
            local Dist = (Root.Position - LiftCheckPos).Magnitude
            if Dist <= 30 or Dist > 800 then ConditionsMet = true end
        end
    until ConditionsMet or CleanedUp

    if CleanedUp then return end
    Log("Lift entered! Waiting for the map to load.", "System")
    local LoadWaitStart, LoadReported = os.clock(), false

    while ConditionsMet and not Map and not CleanedUp do
        task.wait(0.1)

        if not LoadReported and os.clock() - LoadWaitStart > 90 then
            LoadReported = true
            Log("The map is taking too long to load.", "Warning")
            Webhook.Failed(nil, "Waited over 90 seconds in the lift and no map loaded.")
        end

        local FoundMap = Multi:FindFirstChild("NewMap")
        if FoundMap then
            Map = FoundMap
            break
        end

        local Root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if Root then
            local Dist = (Root.Position - LiftCheckPos).Magnitude

            if Dist > 30 and Dist < 800 then
                Log("You left the lift! Pausing until you return.", "Warning")
                ConditionsMet = false
            end
        end
    end
end

if CleanedUp or not Map then return end

local MapSettings = Map:WaitForChild('Settings', 30)
local realMapName = MapSettings and MapSettings:GetAttribute("MapName")
if not realMapName then
    Log("The map never finished loading.", "Error")
    Webhook.Failed(nil, "The map settings never loaded (30 second timeout).")
    Cleanup(true)
    return
end
CurrentMapName = realMapName
local mapName = HttpService:UrlEncode(realMapName)

local SkipThisMap, MapDif = ShouldSkipMap(realMapName)
if SkipThisMap then
    Log(("Skipping %s (%s)."):format(realMapName, DifName(MapDif)), "Warning")
    Webhook.Skipped(realMapName, MapDif)
    Cleanup(true)
    return
end

local success, path
if isfolder("Flood-GUI") and isfolder("Flood-GUI/TAS FILES") then
    local TargetTASPath = "Flood-GUI/TAS FILES/" .. realMapName .. ".json"
    if isfile(TargetTASPath) then path = readfile(TargetTASPath); success = true end
end

if not path then
    success, path = pcall(function()
        local base = getgenv().FloodRepoBase or "https://raw.githubusercontent.com/tomatotxt/Flood-GUI/refs/heads/testing/"
        return game:HttpGet(base .. "TAS%20FILES/" .. mapName .. ".json")
    end)
end

if not success or #path < 50 then
    Log("Oops! We don't have a TAS file for '".. realMapName .."'.", "Error")
    Webhook.Failed(realMapName, "No TAS file exists for this map.")
    Cleanup(true)
    return
end

local TAS
local DecodeSuccess, _ = pcall(function() TAS = HttpService:JSONDecode(path) end)
if not TAS or not DecodeSuccess then
    Log("Uh oh, the TAS file for this map seems corrupted.", "Error")
    Webhook.Failed(realMapName, "The TAS file for this map is corrupted.")
    Cleanup(true)
    return
end

local OriginalFrameCount = #TAS
Log("Loaded run for " .. realMapName .. " (" .. OriginalFrameCount .. " frames).", "Info")
repeat task.wait() until Map.Name == "Map" or CleanedUp
if CleanedUp then return end

local SpawnPoint = nil
for _,v in ipairs(Map:GetChildren()) do
    if v.Name == "Part" then
        local c; c = v:GetPropertyChangedSignal("Rotation"):Connect(function() c:Disconnect(); SpawnPoint = v end)
    end
end

local t = 0
repeat task.wait(0.1); t=t+0.1; if not SpawnPoint then SpawnPoint = Map:FindFirstChild("Spawn", true) end
until SpawnPoint or t > 10 or CleanedUp

if not SpawnPoint then
    Log("Hmm, couldn't find where to spawn on this map.", "Error")
    Webhook.Failed(realMapName, "Couldn't find the spawn point.")
    Cleanup(true)
    return
end

CacheWaterParts(Map)

for _, v in ipairs(Map:GetDescendants()) do
    if v.Name == 'ButtonIcon' then
        pcall(function()
            local btnModel = v:FindFirstAncestorOfClass("Model") or v.Parent
            if btnModel then
                for _, p in ipairs(btnModel:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.Size = NewV(8, 8, 8)
                        p.Transparency = 1
                    end
                end
            end
        end)
    end
end
Log("Map buttons and elements processed.", "Success")

task.wait(0.1)
Log("Starting the run! Sit back and relax.", "Success")

local RootPart = LP.Character:WaitForChild("HumanoidRootPart", 10)
local Humanoid = LP.Character:WaitForChild("Humanoid", 10)

while (RootPart.Anchored == true) or (Humanoid.WalkSpeed <= 0) do
    if CleanedUp then return end
    task.wait()
end

if LP.Character and LP.Character:FindFirstChild("Humanoid") then
    LP.Character.Humanoid.AutoRotate = false
end

Animate.playAnimation = function() end

local function activateAnimation(AnimData, Elapsed)
    local character = LP.Character
    if not character or not character.Parent then return end
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")
    if not head or not humanoid or not RootPart then return end

    local n = AnimData and AnimData[1] or nil
    local animTime = AnimData and AnimData[2] or 0.1
    Elapsed = Elapsed or 0

    local checkSubmerged = IsInWater(RootPart.Position + Vector3.new(0, 1, 0))

    local gameSpeedMultiplier = TimeModifier * DynamicTimeScale
    local nativeSlideDuration = 0.5 / gameSpeedMultiplier

    if IsManualZipline then
        n = "swing"
        IsCurrentlyZiplining = true
        if IsSliding then
            toggleSlide(false)
            IsSliding = false
        end
    elseif IsManualSlide then
        n = "slide"
        IsSliding = true
    end

    if n == "zipline" or n == "swing" then
        n = "swing"
        IsCurrentlyZiplining = true
        if IsSliding then
            toggleSlide(false)
            IsSliding = false
            LastSlideEndTime = Elapsed
        end
    end

    if humanoid.FloorMaterial ~= Enum.Material.Air and not IsManualZipline then
        IsCurrentlyZiplining = false
    end

    if IsSliding then
        if not IsManualSlide and (Elapsed - SlideStartTime >= nativeSlideDuration) then
            toggleSlide(false)
            IsSliding = false
            LastSlideEndTime = Elapsed

            if checkSubmerged then
                IsCurrentlySwimming = true
                if character.Animate:FindFirstChild("ToggleSwim") then
                    pcall(function() character.Animate.ToggleSwim:Fire(true) end)
                end
                if RootPart.Velocity.Magnitude > 1.5 then n = "swim" else n = "swimidle" end
            else
                IsCurrentlySwimming = false
                if character.Animate:FindFirstChild("ToggleSwim") then
                    pcall(function() character.Animate.ToggleSwim:Fire(false) end)
                end
                if humanoid.FloorMaterial == Enum.Material.Air then
                    n = "fall"
                elseif RootPart.Velocity.Magnitude > 1 then
                    n = "walk"
                else
                    n = "idle"
                end
            end
        else
            n = "slide"
        end
    else

        if checkSubmerged then
            IsCurrentlySwimming = true
            if RootPart.Velocity.Magnitude > 1.5 then n = "swim" else n = "swimidle" end
            if character.Animate:FindFirstChild("ToggleSwim") then
                pcall(function() character.Animate.ToggleSwim:Fire(true) end)
            end
        else
            IsCurrentlySwimming = false
            if character.Animate:FindFirstChild("ToggleSwim") then
                pcall(function() character.Animate.ToggleSwim:Fire(false) end)
            end

            if not IsCurrentlyZiplining then
                if n == "slide" then

                    local absYVel = math.abs(RootPart.Velocity.Y)
                    if IsManualSlide or (Elapsed - LastSlideEndTime >= SLIDE_DEBOUNCE and absYVel <= 3 and humanoid.FloorMaterial ~= Enum.Material.Air) then
                        toggleSlide(true)
                        IsSliding = true
                        SlideStartTime = Elapsed
                        n = "slide"
                    else

                        if humanoid.FloorMaterial == Enum.Material.Air then
                            n = "fall"
                        elseif RootPart.Velocity.Magnitude > 1 then
                            n = "walk"
                        else
                            n = "idle"
                        end
                    end
                end
            end

            if not AnimData and not IsSliding and not IsManualZipline and not IsManualSlide then
                return
            end

            if not IsSliding and not IsCurrentlyZiplining then
                if humanoid:GetState() == Enum.HumanoidStateType.Physics then n = "swing" end
                if n == "idle" or not n then
                    if RootPart.Velocity.Magnitude > 1 then
                        if humanoid.FloorMaterial ~= Enum.Material.Air then n = "walk" else n = "fall" end
                    else
                        n = "idle"
                    end
                end
                if n == "fall" and RootPart.Velocity.Magnitude < 0.1 then n = "swing" end
            end
        end
    end

    if n and (n ~= LastPlayedAnim) then
        Animate.playAnimation = function() end
        pcall(function() OriginalPlayAnim(n, animTime, humanoid) end)
        if n == "walk" then pcall(function() Animate.setAnimationSpeed(.76) end) end
        LastPlayedAnim = n
    end
end

local Offset = SpawnPoint.Position - NewV(0, 1000, 0)
local OldFrame = 3
local StatsBefore = ReadStats()
local RunStartClock = os.clock()
GetRunProgress = function() return math.clamp(OldFrame / math.max(#TAS, 1), 0, 1) end
local RenderedFrames = 0
local FinishedRun = false

local SmoothSwimDirection = nil

local VisualElapsed = 0
local LastClock = os.clock()

local PAUSED = false

local function AdjustSpeed(step)
    TimeModifier = math.clamp(math.round((TimeModifier + step) * 100) / 100, 0.05, 10)

    local baseSpeed = math.round((1 / TimeModifier) * 100) / 100
    local totalSpeed = math.round((1 / (TimeModifier * DynamicTimeScale)) * 100) / 100

    local actionText = (step < 0) and "Increased" or "Decreased"
    local category = (step < 0) and "Success" or "Warning"

    Log(string.format("Speed %s! Base: %.2fx | Total: %.2fx (Modifier: %.2f)",
        actionText, baseSpeed, totalSpeed, TimeModifier), category)
end

local upKey = INPUT["Up"]
if upKey and upKey.Pressed then
    AddConnection(upKey.Pressed:Connect(function()
        AdjustSpeed(-0.05)
    end))
end

local downKey = INPUT["Down"]
if downKey and downKey.Pressed then
    AddConnection(downKey.Pressed:Connect(function()
        AdjustSpeed(0.05)
    end))
end

local zKey = INPUT["Z"]
if zKey then
    AddConnection(zKey.Pressed:Connect(function()
        IsManualZipline = true
        IsCurrentlyZiplining = true
        toggleSlide(false)
        IsSliding = false
        LastPlayedAnim = nil
    end))
    AddConnection(zKey.Released:Connect(function()
        IsManualZipline = false
        IsCurrentlyZiplining = false
        LastPlayedAnim = nil
    end))
end

local sKey = INPUT["S"]
if sKey then
    AddConnection(sKey.Pressed:Connect(function()
        IsManualSlide = true
        toggleSlide(true)
        IsSliding = true
        LastPlayedAnim = nil
    end))
    AddConnection(sKey.Released:Connect(function()
        IsManualSlide = false
        toggleSlide(false)
        IsSliding = false
        LastPlayedAnim = nil
    end))
end

local function TriggerPauseToggle()
    task.spawn(function()
        repeat task.wait() until Humanoid and Humanoid.FloorMaterial ~= Enum.Material.Air
        PAUSED = not PAUSED
        if PAUSED then
            pcall(function() OriginalPlayAnim("idle", 0.1, Humanoid) end)
            LastPlayedAnim = "idle"
            Log("TAS Paused (Grounded)", "Warning")
        else
            LastClock = os.clock()
            Log("TAS Resumed", "Success")
        end
    end)
end

local function HandlePause()
    TriggerPauseToggle()
    INPUT["P"].Pressed:Once(HandlePause)
end
INPUT["P"].Pressed:Once(HandlePause)

local function SetupGUI()
    local PlayerGui = LP:WaitForChild("PlayerGui", 10)
    if not PlayerGui then return end

    local oldGui = PlayerGui:FindFirstChild("TAS_GUI")
    if oldGui then oldGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "TAS_GUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = PlayerGui

    if IsMobile then

        local MobileFrame = Instance.new("Frame")
        MobileFrame.Name = "MobileControls"
        MobileFrame.Size = UDim2.new(0, 160, 0, 160)
        MobileFrame.Position = UDim2.new(0.02, 0, 0.35, 0)
        MobileFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        MobileFrame.BackgroundTransparency = 0.35
        MobileFrame.BorderSizePixel = 0
        MobileFrame.Parent = ScreenGui

        local UICorner = Instance.new("UICorner", MobileFrame)
        UICorner.CornerRadius = UDim.new(0, 10)

        local UIListLayout = Instance.new("UIListLayout", MobileFrame)
        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout.Padding = UDim.new(0, 8)
        UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

        local function CreateMobileButton(name, text, color)
            local btn = Instance.new("TextButton")
            btn.Name = name
            btn.Size = UDim2.new(0.88, 0, 0, 40)
            btn.BackgroundColor3 = color
            btn.Text = text
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.SourceSansBold
            btn.TextSize = 15
            btn.AutoButtonColor = true
            btn.Parent = MobileFrame

            local btnCorner = Instance.new("UICorner", btn)
            btnCorner.CornerRadius = UDim.new(0, 8)
            return btn
        end

        local pauseBtn = CreateMobileButton("PauseBtn", "Pause / Resume", Color3.fromRGB(210, 130, 30))
        local ziplineBtn = CreateMobileButton("ZiplineBtn", "Hold: Zipline", Color3.fromRGB(0, 150, 220))
        local slideBtn = CreateMobileButton("SlideBtn", "Hold: Slide", Color3.fromRGB(60, 170, 90))

        pauseBtn.MouseButton1Click:Connect(function()
            TriggerPauseToggle()
        end)

        ziplineBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                IsManualZipline = true
                IsCurrentlyZiplining = true
                toggleSlide(false)
                IsSliding = false
                LastPlayedAnim = nil
                ziplineBtn.BackgroundColor3 = Color3.fromRGB(0, 210, 255)
            end
        end)
        ziplineBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                IsManualZipline = false
                IsCurrentlyZiplining = false
                LastPlayedAnim = nil
                ziplineBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 220)
            end
        end)

        slideBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                IsManualSlide = true
                toggleSlide(true)
                IsSliding = true
                LastPlayedAnim = nil
                slideBtn.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
            end
        end)
        slideBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                IsManualSlide = false
                toggleSlide(false)
                IsSliding = false
                LastPlayedAnim = nil
                slideBtn.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
            end
        end)
    else

        local GuideFrame = Instance.new("Frame")
        GuideFrame.Name = "PCGuide"
        GuideFrame.Size = UDim2.new(0, 220, 0, 150)
        GuideFrame.Position = UDim2.new(0.015, 0, 0.35, 0)
        GuideFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        GuideFrame.BackgroundTransparency = 0.25
        GuideFrame.BorderSizePixel = 0
        GuideFrame.Parent = ScreenGui

        local UICorner = Instance.new("UICorner", GuideFrame)
        UICorner.CornerRadius = UDim.new(0, 8)

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, 0, 0, 28)
        Title.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
        Title.BackgroundTransparency = 0.2
        Title.Text = "  TAS Keybind Controls"
        Title.TextColor3 = Color3.fromRGB(0, 200, 255)
        Title.Font = Enum.Font.SourceSansBold
        Title.TextSize = 15
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = GuideFrame

        local TitleCorner = Instance.new("UICorner", Title)
        TitleCorner.CornerRadius = UDim.new(0, 8)

        local GuideText = Instance.new("TextLabel")
        GuideText.Size = UDim2.new(0.9, 0, 0.75, 0)
        GuideText.Position = UDim2.new(0.05, 0, 0.23, 0)
        GuideText.BackgroundTransparency = 1
        GuideText.Text = "[P] - Pause / Resume (Grounded)\n[Up Arrow] - Speed Up (+0.05)\n[Down Arrow] - Speed Down (-0.05)\n[Z] (Hold) - Force Zipline / Swing\n[S] (Hold) - Force Slide"
        GuideText.TextColor3 = Color3.fromRGB(220, 220, 220)
        GuideText.Font = Enum.Font.SourceSans
        GuideText.TextSize = 14
        GuideText.TextYAlignment = Enum.TextYAlignment.Top
        GuideText.TextXAlignment = Enum.TextXAlignment.Left
        GuideText.Parent = GuideFrame
    end
end

SetupGUI()

local MainLoop
MainLoop = RS.Heartbeat:Connect(function()
    if not RootPart or not RootPart.Parent or not Humanoid or not Humanoid.Parent or CleanedUp then
        if MainLoop then MainLoop:Disconnect() end
        if not CleanedUp then
            Log("Player removed from game. Halting the run.", "Warning")
            Cleanup(false)
        end
        return
    end

    local CurrentClock = os.clock()
    local Delta = CurrentClock - LastClock
    LastClock = CurrentClock

    if PAUSED == true then
        RootPart.Velocity = Vector3.zero
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero
        return
    end

    RootPart.Anchored = false

    RenderedFrames = RenderedFrames + 1

    VisualElapsed = VisualElapsed + (Delta * (1 / (TimeModifier * DynamicTimeScale)))

    local liveWeld = RootPart:FindFirstChild("WalljumpWeld_Live")
    if liveWeld then liveWeld:Destroy() end
    local serverWeld = RootPart:FindFirstChild("WalljumpWeld_Server")
    if serverWeld then serverWeld:Destroy() end

    Humanoid.Health = 99999

    while OldFrame < #TAS and TAS[OldFrame + 1].time <= VisualElapsed do OldFrame = OldFrame + 1 end

    if OldFrame >= #TAS then
        if not FinishedRun then
            FinishedRun = true
            Log("Run completed successfully! Awesome.", "Success")
            Webhook.Complete(realMapName, MapDif, os.clock() - RunStartClock, StatsBefore)
            if getgenv().TAS_RestoreAnim then
                pcall(getgenv().TAS_RestoreAnim)
                getgenv().TAS_RestoreAnim = nil
            end
            pcall(function() OriginalPlayAnim("idle", 0.1, Humanoid) end)
            Cleanup(false)
        end
        return
    end

    local FA = TAS[OldFrame]
    local FB = TAS[OldFrame + 1] or FA

    local Dur = FB.time - FA.time
    local Alpha = (Dur > 0) and math.clamp((VisualElapsed - FA.time) / Dur, 0, 1) or 0

    local cfA = NewC(FA.CCFrame[1], FA.CCFrame[2], FA.CCFrame[3]) * AngC(FA.CCFrame[4], FA.CCFrame[5], FA.CCFrame[6])
    local cfB = NewC(FB.CCFrame[1], FB.CCFrame[2], FB.CCFrame[3]) * AngC(FB.CCFrame[4], FB.CCFrame[5], FB.CCFrame[6])

    local vA = NewV(FA.VVelocity[1], FA.VVelocity[2], FA.VVelocity[3])
    local vB = NewV(FB.VVelocity[1], FB.VVelocity[2], FB.VVelocity[3])

    local TargetVelocity = vA:Lerp(vB, Alpha)
    getgenv().TASCurrentMoveDir = TargetVelocity.Magnitude > 0 and TargetVelocity.Unit or Vector3.zero

    local TargetCFrame = cfA:Lerp(cfB, Alpha) + Offset

    local OverrideToSlide = false
    local startPos = TargetCFrame.Position + Vector3.new(0, 1.5, 0)
    local direction = Vector3.new(0, -4.5, 0)

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { LP.Character }

    local result = workspace:Raycast(startPos, direction, raycastParams)
    if result then
        local hitY = result.Position.Y
        local gap = TargetCFrame.Position.Y - hitY

        if gap < 1.7 and Humanoid.FloorMaterial ~= Enum.Material.Air then

            if TargetVelocity.Y <= 3 then
                OverrideToSlide = true
            end
        end
    end

    if IsCurrentlySwimming and TargetVelocity.Magnitude > 0.5 then
        if not SmoothSwimDirection then
            SmoothSwimDirection = TargetVelocity.Unit
        else
            SmoothSwimDirection = SmoothSwimDirection:Lerp(TargetVelocity.Unit, SwimSmoothness).Unit
        end
        RootPart.CFrame = NewC(TargetCFrame.Position, TargetCFrame.Position + SmoothSwimDirection)
    else
        SmoothSwimDirection = nil
        RootPart.CFrame = TargetCFrame
    end

    RootPart.Velocity = TargetVelocity

    local AnimData = FA.AAnimation

    if OverrideToSlide and not IsCurrentlyZiplining and (not AnimData or (AnimData[1] ~= "zipline" and AnimData[1] ~= "swing")) then
        AnimData = { "slide", 0.1 }
    end

    pcall(activateAnimation, AnimData, VisualElapsed)
end)
AddConnection(MainLoop)
