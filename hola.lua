-- ============================================================
--   Whizy — Sword Factory X | Auto Enchant Detector & TP
--   Version: 9.4 | GUI: Rayfield by Sirius
--   Made by Whizy
-- ============================================================

local Players         = game:GetService("Players")
local HttpService     = game:GetService("HttpService")
local UIS             = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Player          = Players.LocalPlayer
local MyID            = Player.UserId
local MyName          = Player.Name
local Folder          = workspace:WaitForChild("Swords")

-- ============================================================
-- EXECUTOR HTTP
-- ============================================================
local httpRequest = (syn and syn.request)
    or (http and http.request)
    or (http_request)
    or (request)
    or nil

-- ============================================================
-- RAYFIELD
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================================
-- ENCHANTS
-- ============================================================
local ENCHANTS = {
    "Fortune","Sharpness","Protection","Haste","Swiftness",
    "Critical","Resistance","Healing","Looting","Attraction",
    "Stealth","Ancient","Desperation","Insight"
}
local ENCHANT_OPTS = {"None"}
for _, e in ipairs(ENCHANTS) do table.insert(ENCHANT_OPTS, e) end

local KEYBIND_OPTS = {
    "RightControl","LeftControl","RightAlt","LeftAlt",
    "RightShift","LeftShift","F1","F2","F3","F4","F5",
    "Insert","Home","Delete","End","K","L","M","N","P"
}

-- ============================================================
-- CONFIG
-- ============================================================
local DEFAULT_CONFIG = {
    enchant1     = "Ancient",
    enchant2     = "Insight",
    enchant3     = "Fortune",
    autoTP       = true,
    notifyAll    = false,
    showAll      = false,
    webhookURL   = "https://discord.com/api/webhooks/1450527386604011712/6pqQNuH3IzCZkWojb_rowoaxjeBfrSzl6_7lE4lMaf23o_YP2kN-0OsaLbWQTBsKZmO6",
    webhookOn    = true,
    pingEveryone = true,
    toggleKey    = "RightControl",
    autoRejoin   = true,
    rejoinMins   = 15,
}

local cfg = {}
local CONFIG_FILE = "WhizyConfig.json"

local function saveCfg()
    local encoded = HttpService:JSONEncode(cfg)
    pcall(function() writefile(CONFIG_FILE, encoded) end)
    pcall(function() Player:SetAttribute("WhizyCfg9", encoded) end)
end

local function loadCfg()
    local loaded = nil
    pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            if raw and raw ~= "" then
                local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
                if ok and type(parsed) == "table" then loaded = parsed end
            end
        end
    end)
    if not loaded then
        pcall(function()
            local raw = Player:GetAttribute("WhizyCfg9") or "{}"
            local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(parsed) == "table" then loaded = parsed end
        end)
    end
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (loaded and loaded[k] ~= nil) and loaded[k] or v
    end
end

loadCfg()

-- ============================================================
-- STATS
-- ============================================================
local stats = { total=0, withEnchants=0, tpCount=0, webhookSent=0 }
local isTping = false
local updateStats
local setStatus

-- ============================================================
-- AUTO REJOIN
-- ============================================================
local rejoinActive    = false
local rejoinCountdown = 0
local rejoinThread    = nil
local LBL_RejoinStatus

local function stopRejoin()
    rejoinActive = false
    if rejoinThread then
        pcall(function() task.cancel(rejoinThread) end)
        rejoinThread = nil
    end
    pcall(function()
        if LBL_RejoinStatus then
            LBL_RejoinStatus:Set("Auto-Rejoin: OFF")
        end
    end)
end

local function doRejoin()
    Rayfield:Notify({
        Title    = "Auto-Rejoin",
        Content  = "Queuing script and reconnecting...",
        Duration = 4,
        Image    = "refresh-cw",
    })

    task.wait(2)

    -- Queue hola.lua to run after teleport (Xeno)
    if queue_on_teleport then
        local ok, content = pcall(function()
            return readfile("autoexec/hola.lua")
        end)
        if ok and content and content ~= "" then
            pcall(function()
                queue_on_teleport(content)
            end)
        end
    end

    -- Rejoin same server
    local placeId = game.PlaceId
    local jobId   = game.JobId

    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, Player)
    end)
    if not ok then
        pcall(function()
            TeleportService:Teleport(placeId, Player)
        end)
    end
end

local function startRejoin()
    if rejoinThread then
        pcall(function() task.cancel(rejoinThread) end)
    end

    rejoinActive    = true
    rejoinCountdown = cfg.rejoinMins * 60

    rejoinThread = task.spawn(function()
        while rejoinActive and rejoinCountdown > 0 do
            task.wait(1)
            rejoinCountdown -= 1

            if rejoinCountdown % 5 == 0 or rejoinCountdown <= 10 then
                local mins    = math.floor(rejoinCountdown / 60)
                local secs    = rejoinCountdown % 60
                local timeStr = string.format("%02d:%02d", mins, secs)
                pcall(function()
                    if LBL_RejoinStatus then
                        LBL_RejoinStatus:Set("Auto-Rejoin: ON — next in " .. timeStr)
                    end
                end)
            end
        end

        if rejoinActive then
            doRejoin()
        end
    end)
end

-- ============================================================
-- TP FUNCTION
-- ============================================================
local function doTP(sword)
    if isTping then return end
    isTping = true

    local char = Player.Character
    if not char then isTping = false; return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then isTping = false; return end

    local originalCF = hrp.CFrame
    local targetCF   = CFrame.new(sword:GetPivot().Position + Vector3.new(0, 5, 0))

    pcall(function() char:PivotTo(targetCF) end)

    stats.tpCount += 1
    updateStats()
    setStatus("Teleported! Returning in 1s...")

    task.wait(1)

    local char2 = Player.Character
    if char2 then
        local hrp2 = char2:FindFirstChild("HumanoidRootPart")
        if hrp2 then
            pcall(function() char2:PivotTo(originalCF) end)
            setStatus("Returned. Waiting for swords...")
        end
    end

    task.wait(0.3)
    isTping = false
end

-- ============================================================
-- WINDOW
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name                   = "Whizy — Sword Factory X",
    LoadingTitle           = "Whizy Script",
    LoadingSubtitle        = "Auto Enchant Detector v9.4",
    Theme                  = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
    ConfigurationSaving    = { Enabled = false },
    KeySystem              = false,
})

-- ============================================================
-- TABS
-- ============================================================
local TabDetector = Window:CreateTab("Detector",    "sword")
local TabRejoin   = Window:CreateTab("Auto-Rejoin", "refresh-cw")
local TabSettings = Window:CreateTab("Settings",    "settings")
local TabWebhook  = Window:CreateTab("Webhook",     "bell")
local TabStats    = Window:CreateTab("Statistics",  "bar-chart-2")

-- ============================================================
-- TAB: DETECTOR
-- ============================================================
TabDetector:CreateSection("Enchant Filters")

local DD1 = TabDetector:CreateDropdown({
    Name            = "Enchant 1",
    Options         = ENCHANT_OPTS,
    CurrentOption   = {cfg.enchant1 or "None"},
    MultipleOptions = false,
    Flag            = "DD_E1",
    Callback        = function(opts)
        cfg.enchant1 = (opts[1] == "None") and nil or opts[1]
        saveCfg()
    end,
})

local DD2 = TabDetector:CreateDropdown({
    Name            = "Enchant 2",
    Options         = ENCHANT_OPTS,
    CurrentOption   = {cfg.enchant2 or "None"},
    MultipleOptions = false,
    Flag            = "DD_E2",
    Callback        = function(opts)
        cfg.enchant2 = (opts[1] == "None") and nil or opts[1]
        saveCfg()
    end,
})

local DD3 = TabDetector:CreateDropdown({
    Name            = "Enchant 3",
    Options         = ENCHANT_OPTS,
    CurrentOption   = {cfg.enchant3 or "None"},
    MultipleOptions = false,
    Flag            = "DD_E3",
    Callback        = function(opts)
        cfg.enchant3 = (opts[1] == "None") and nil or opts[1]
        saveCfg()
    end,
})

TabDetector:CreateSection("Options")

local TG_AutoTP = TabDetector:CreateToggle({
    Name         = "Auto-TP on match",
    CurrentValue = cfg.autoTP,
    Flag         = "TG_AutoTP",
    Callback     = function(v) cfg.autoTP = v; saveCfg() end,
})

local TG_NotifyAll = TabDetector:CreateToggle({
    Name         = "Notify unmatched swords",
    CurrentValue = cfg.notifyAll,
    Flag         = "TG_NotifyAll",
    Callback     = function(v) cfg.notifyAll = v; saveCfg() end,
})

local TG_ShowAll = TabDetector:CreateToggle({
    Name         = "Log all swords to console",
    CurrentValue = cfg.showAll,
    Flag         = "TG_ShowAll",
    Callback     = function(v) cfg.showAll = v; saveCfg() end,
})

TabDetector:CreateSection("Live Status")

local StatusBtn = TabDetector:CreateButton({
    Name     = "Status: Waiting for swords...",
    Callback = function() end,
})

setStatus = function(text)
    pcall(function() StatusBtn:Set("Status: " .. text) end)
end

-- ============================================================
-- TAB: AUTO-REJOIN
-- ============================================================
TabRejoin:CreateSection("Auto-Rejoin Settings")
TabRejoin:CreateLabel("Rejoins the SAME server every X minutes.")
TabRejoin:CreateLabel("Uses queue_on_teleport to re-run hola.lua after rejoin.")

LBL_RejoinStatus = TabRejoin:CreateLabel(
    cfg.autoRejoin
        and ("Auto-Rejoin: ON — next in "
            .. string.format("%02d:%02d", cfg.rejoinMins, 0))
        or "Auto-Rejoin: OFF"
)

local TG_AutoRejoin = TabRejoin:CreateToggle({
    Name         = "Enable Auto-Rejoin",
    CurrentValue = cfg.autoRejoin,
    Flag         = "TG_AutoRejoin",
    Callback     = function(v)
        cfg.autoRejoin = v
        saveCfg()
        if v then
            startRejoin()
            Rayfield:Notify({
                Title    = "Auto-Rejoin ON",
                Content  = "Will rejoin in " .. cfg.rejoinMins .. " minutes.",
                Duration = 4,
                Image    = "check-circle",
            })
        else
            stopRejoin()
            Rayfield:Notify({
                Title    = "Auto-Rejoin OFF",
                Content  = "Auto-Rejoin disabled.",
                Duration = 3,
                Image    = "x-circle",
            })
        end
    end,
})

local SL_Mins = TabRejoin:CreateSlider({
    Name         = "Rejoin interval (minutes)",
    Range        = {5, 60},
    Increment    = 1,
    Suffix       = "min",
    CurrentValue = cfg.rejoinMins,
    Flag         = "SL_RejoinMins",
    Callback     = function(v)
        cfg.rejoinMins = v
        saveCfg()
        if cfg.autoRejoin then startRejoin() end
    end,
})

TabRejoin:CreateSection("Manual Controls")

TabRejoin:CreateButton({
    Name     = "Restart timer",
    Callback = function()
        if cfg.autoRejoin then
            startRejoin()
            Rayfield:Notify({
                Title    = "Timer restarted",
                Content  = "Next rejoin in " .. cfg.rejoinMins .. " minutes.",
                Duration = 3,
                Image    = "refresh-cw",
            })
        else
            Rayfield:Notify({
                Title    = "Disabled",
                Content  = "Enable Auto-Rejoin first.",
                Duration = 3,
                Image    = "alert-triangle",
            })
        end
    end,
})

TabRejoin:CreateButton({
    Name     = "Rejoin NOW",
    Callback = function()
        Rayfield:Notify({
            Title    = "Rejoining...",
            Content  = "Queuing script and teleporting in 2s.",
            Duration = 3,
            Image    = "zap",
        })
        task.spawn(doRejoin)
    end,
})

-- ============================================================
-- TAB: SETTINGS
-- ============================================================
TabSettings:CreateSection("GUI Toggle Key")
TabSettings:CreateLabel("Key to show / hide the GUI.")

local DD_Key = TabSettings:CreateDropdown({
    Name            = "Toggle Key",
    Options         = KEYBIND_OPTS,
    CurrentOption   = {cfg.toggleKey or "RightControl"},
    MultipleOptions = false,
    Flag            = "DD_Key",
    Callback        = function(opts)
        cfg.toggleKey = opts[1]
        saveCfg()
        Rayfield:Notify({
            Title    = "Keybind updated",
            Content  = "Toggle key: " .. opts[1],
            Duration = 3,
            Image    = "keyboard",
        })
    end,
})

TabSettings:CreateSection("Configuration")

TabSettings:CreateButton({
    Name     = "Save config now",
    Callback = function()
        saveCfg()
        Rayfield:Notify({ Title="Saved", Content="Config saved successfully.", Duration=3, Image="check" })
    end,
})

TabSettings:CreateButton({
    Name     = "Reset to defaults",
    Callback = function()
        for k, v in pairs(DEFAULT_CONFIG) do cfg[k] = v end
        saveCfg()
        pcall(function() DD1:Set({cfg.enchant1 or "None"}) end)
        pcall(function() DD2:Set({cfg.enchant2 or "None"}) end)
        pcall(function() DD3:Set({cfg.enchant3 or "None"}) end)
        pcall(function() TG_AutoTP:Set(cfg.autoTP) end)
        pcall(function() TG_NotifyAll:Set(cfg.notifyAll) end)
        pcall(function() TG_ShowAll:Set(cfg.showAll) end)
        pcall(function() DD_Key:Set({cfg.toggleKey}) end)
        pcall(function() TG_AutoRejoin:Set(cfg.autoRejoin) end)
        pcall(function() SL_Mins:Set(cfg.rejoinMins) end)
        Rayfield:Notify({ Title="Reset", Content="Default values restored.", Duration=3, Image="refresh-cw" })
    end,
})

TabSettings:CreateSection("About")
TabSettings:CreateLabel("Whizy v9.4 — Sword Factory X")
TabSettings:CreateLabel("Player: " .. MyName .. "  |  ID: " .. tostring(MyID))
TabSettings:CreateLabel("Script file: autoexec/hola.lua")

-- ============================================================
-- TAB: WEBHOOK
-- ============================================================
TabWebhook:CreateSection("Discord Webhook")
TabWebhook:CreateLabel("Sends a Discord embed when a match is detected.")

if not httpRequest then
    TabWebhook:CreateLabel("WARNING: Your executor does not expose request(). Webhook unavailable.")
end

TabWebhook:CreateInput({
    Name                     = "Webhook URL",
    CurrentValue             = cfg.webhookURL or "",
    PlaceholderText          = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false,
    Flag                     = "WH_URL",
    Callback                 = function(text)
        cfg.webhookURL = text
        saveCfg()
    end,
})

TabWebhook:CreateToggle({
    Name         = "Enable Webhook",
    CurrentValue = cfg.webhookOn,
    Flag         = "TG_WH_On",
    Callback     = function(v) cfg.webhookOn = v; saveCfg() end,
})

TabWebhook:CreateToggle({
    Name         = "@everyone on match",
    CurrentValue = cfg.pingEveryone,
    Flag         = "TG_WH_Ping",
    Callback     = function(v) cfg.pingEveryone = v; saveCfg() end,
})

TabWebhook:CreateSection("Test")

TabWebhook:CreateButton({
    Name     = "Send test message",
    Callback = function()
        if not cfg.webhookURL or cfg.webhookURL == "" then
            Rayfield:Notify({ Title="No URL", Content="Enter the webhook URL first.", Duration=4, Image="alert-triangle" })
            return
        end
        if not httpRequest then
            Rayfield:Notify({ Title="Unsupported", Content="Your executor does not support http.request.", Duration=4, Image="x-circle" })
            return
        end

        local body = HttpService:JSONEncode({
            content  = cfg.pingEveryone and "@everyone" or "",
            username = "Whizy | Sword Factory X",
            embeds   = {{
                title       = "Test message",
                description = "Webhook configured correctly.\nPlayer: **" .. MyName .. "**",
                color       = 9699539,
                footer      = { text = "Whizy v9.4" },
            }}
        })

        local ok, res = pcall(function()
            return httpRequest({
                Url     = cfg.webhookURL,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = body,
            })
        end)

        if ok and res and (res.StatusCode == 200 or res.StatusCode == 204) then
            Rayfield:Notify({ Title="Webhook OK", Content="Test message sent to Discord.", Duration=4, Image="check-circle" })
        elseif ok and res then
            Rayfield:Notify({ Title="Error", Content="HTTP " .. tostring(res.StatusCode), Duration=5, Image="x-circle" })
        else
            Rayfield:Notify({ Title="Error", Content=tostring(res):sub(1,80), Duration=5, Image="x-circle" })
        end
    end,
})

-- ============================================================
-- TAB: STATISTICS
-- ============================================================
TabStats:CreateSection("Counters")

local LBL_Total    = TabStats:CreateLabel("Swords detected: 0")
local LBL_Enchants = TabStats:CreateLabel("With enchants: 0")
local LBL_TPs      = TabStats:CreateLabel("Teleports done: 0")
local LBL_Webhooks = TabStats:CreateLabel("Webhooks sent: 0")

updateStats = function()
    pcall(function() LBL_Total:Set("Swords detected: "  .. stats.total)        end)
    pcall(function() LBL_Enchants:Set("With enchants: " .. stats.withEnchants) end)
    pcall(function() LBL_TPs:Set("Teleports done: "     .. stats.tpCount)      end)
    pcall(function() LBL_Webhooks:Set("Webhooks sent: " .. stats.webhookSent)  end)
end

TabStats:CreateSection("Actions")

TabStats:CreateButton({
    Name     = "Reset statistics",
    Callback = function()
        stats.total, stats.withEnchants, stats.tpCount, stats.webhookSent = 0,0,0,0
        updateStats()
        Rayfield:Notify({ Title="Stats reset", Content="All counters set to 0.", Duration=3, Image="trash-2" })
    end,
})

-- ============================================================
-- WEBHOOK SENDER
-- ============================================================
local function sendWebhook(level, enchStr, rarity, quality)
    if not cfg.webhookOn or not cfg.webhookURL or cfg.webhookURL == "" then return end
    if not httpRequest then return end

    local body = HttpService:JSONEncode({
        content  = cfg.pingEveryone and "@everyone" or "",
        username = "Whizy | Sword Factory X",
        embeds   = {{
            title       = "Match detected!",
            description = "A sword with your filtered enchants was found.",
            color       = 10181046,
            fields      = {
                { name="Sword",    value=level,             inline=true  },
                { name="Enchants", value=enchStr,           inline=true  },
                { name="Rarity",   value=tostring(rarity),  inline=true  },
                { name="Quality",  value=tostring(quality), inline=true  },
                { name="Player",   value=MyName,            inline=false },
            },
            footer    = { text="Whizy v9.4" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })

    local ok = pcall(function()
        httpRequest({
            Url     = cfg.webhookURL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = body,
        })
    end)

    if ok then stats.webhookSent += 1; updateStats() end
end

-- ============================================================
-- GUI TOGGLE KEYBIND
-- ============================================================
local guiVisible = true
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    local key = tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
    if key == cfg.toggleKey then
        guiVisible = not guiVisible
        local rf = Player.PlayerGui:FindFirstChild("Rayfield")
            or game:GetService("CoreGui"):FindFirstChild("Rayfield")
        if rf then rf.Enabled = guiVisible end
    end
end)

-- ============================================================
-- CORE DETECTION LOGIC
-- ============================================================
local function getEnchantNames(sword)
    local itemInfo = sword:FindFirstChild("ItemInfo", true)
    if not itemInfo then return {} end
    local encFolder = itemInfo:FindFirstChild("Enchants")
    if not encFolder then return {} end
    local result = {}
    for _, lbl in pairs(encFolder:GetChildren()) do
        if lbl:IsA("TextLabel") and lbl.Text ~= "" then
            local name = lbl.Text:match("^(%a+)")
            if name then table.insert(result, name:lower()) end
        end
    end
    return result
end

local function matchesFilter(sword)
    local filters = {}
    for _, v in ipairs({cfg.enchant1, cfg.enchant2, cfg.enchant3}) do
        if v then table.insert(filters, v:lower()) end
    end
    if #filters == 0 then return false end
    local enchants = getEnchantNames(sword)
    for _, f in ipairs(filters) do
        local found = false
        for _, e in ipairs(enchants) do
            if e == f then found = true; break end
        end
        if not found then return false end
    end
    return true
end

local function procesarEspada(sword)
    task.spawn(function()
        if not sword or not sword.Parent then return end

        local attr = {}
        for i = 1, 100 do
            if not sword.Parent then return end
            attr = sword:GetAttributes()
            if  attr.Owner   and attr.Owner   ~= 0
            and attr.Rarity  and attr.Rarity  >  0
            and attr.Quality and attr.Quality >  0
            and attr.Level   and attr.Level   >  1 then break end
            task.wait(0.2)
        end

        if attr.Owner ~= MyID and attr.Creator ~= MyID then return end

        local itemInfo = nil
        for i = 1, 25 do
            if not sword.Parent then return end
            itemInfo = sword:FindFirstChild("ItemInfo", true)
            if itemInfo and itemInfo:FindFirstChild("Level") then break end
            task.wait(0.2)
        end
        if not itemInfo then return end

        local levelLabel = itemInfo:FindFirstChild("Level")
        local finalLevel = "Level " .. tostring(attr.Level)
        if levelLabel then
            local last, stable = "", 0
            for i = 1, 30 do
                local t = levelLabel.Text
                if t ~= "" and t ~= "Level 1" and t ~= "Level" then
                    if t == last then
                        stable += 1
                        if stable >= 3 then finalLevel = t; break end
                    else
                        stable = 0; last = t
                    end
                end
                task.wait(0.2)
            end
        end

        local enchants = getEnchantNames(sword)
        local enchStr  = #enchants > 0 and table.concat(enchants, " | ") or "no enchants"

        stats.total += 1
        if #enchants > 0 then stats.withEnchants += 1 end
        updateStats()

        if cfg.showAll then
            print("================================")
            print("SWORD: "    .. finalLevel)
            print("Rarity: "   .. tostring(attr.Rarity) .. "  Quality: " .. tostring(attr.Quality))
            print("Value: "    .. tostring(attr.Value))
            print("Enchants: " .. enchStr)
            print("================================")
        end

        setStatus("Detected: " .. finalLevel)

        if matchesFilter(sword) then
            setStatus("MATCH! " .. enchStr)
            Rayfield:Notify({
                Title    = "Match found!",
                Content  = finalLevel .. "\n" .. enchStr,
                Duration = 6,
                Image    = "zap",
            })
            task.spawn(function() sendWebhook(finalLevel, enchStr, attr.Rarity, attr.Quality) end)
            if cfg.autoTP then doTP(sword) end
        elseif cfg.notifyAll then
            Rayfield:Notify({
                Title    = "New sword",
                Content  = finalLevel .. "  |  " .. enchStr,
                Duration = 3,
                Image    = "package",
            })
        end
    end)
end

-- ============================================================
-- START
-- ============================================================
Folder.ChildAdded:Connect(procesarEspada)

if cfg.autoRejoin then
    startRejoin()
end

setStatus("Waiting for swords from " .. MyName .. "...")

Rayfield:Notify({
    Title    = "Whizy v9.4 loaded",
    Content  = "Player: " .. MyName
        .. "\nKey: " .. (cfg.toggleKey or "RightControl")
        .. "\nAuto-Rejoin: " .. (cfg.autoRejoin and (cfg.rejoinMins .. "min") or "OFF"),
    Duration = 6,
    Image    = "check-circle",
})

print("--- Whizy v9.4 | " .. MyName .. " ---")