-- ============================================================
--   Whizy — Sword Factory X | Auto Enchant Detector & TP
--   Version: 10.0 | GUI: Rayfield by Sirius
--   Made by Whizy
-- ============================================================

local Players         = game:GetService("Players")
local HttpService     = game:GetService("HttpService")
local UIS             = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser     = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player          = Players.LocalPlayer
local MyID            = Player.UserId
local MyName          = Player.Name
local Folder          = workspace:WaitForChild("Swords")

-- Framework del juego (para teletransportar con el remote real)
local paper = nil
pcall(function() paper = require(ReplicatedStorage:WaitForChild("Paper", 10)) end)

-- Zona de venta (igual que el script de referencia: check de distancia)
local maxdistance = 30
local sellsmain = nil
pcall(function()
    local bases = workspace:WaitForChild("Bases", 10)
    local base  = bases and bases:WaitForChild(MyName, 10)
    local sells = base and base:WaitForChild("SellStation", 10)
    sellsmain   = sells and sells:WaitForChild("Main", 10)
end)

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
-- Sword filters: 3 sets, each with 3 enchant slots
-- A sword matches if it has ALL active enchants of ANY set
-- ============================================================
local DEFAULT_CONFIG = {
    -- Set 1
    s1e1 = "Ancient", s1e2 = "Insight", s1e3 = "Fortune",
    -- Set 2
    s2e1 = "Ancient", s2e2 = "Ancient", s2e3 = "Fortune",
    -- Set 3
    s3e1 = nil, s3e2 = nil, s3e3 = nil,

    autoTP       = true,
    notifyAll    = false,
    showAll      = false,
    webhookURL   = "https://discord.com/api/webhooks/1450527386604011712/6pqQNuH3IzCZkWojb_rowoaxjeBfrSzl6_7lE4lMaf23o_YP2kN-0OsaLbWQTBsKZmO6",
    webhookOn    = true,
    pingEveryone = true,
    toggleKey    = "RightControl",
    autoRejoin   = false,
    rejoinMins   = 10,
    antiAfk      = true,
}

local cfg = {}
local CONFIG_FILE = "WhizyConfig.json"

local function saveCfg()
    local encoded = HttpService:JSONEncode(cfg)
    pcall(function() writefile(CONFIG_FILE, encoded) end)
    pcall(function() Player:SetAttribute("WhizyCfg10", encoded) end)
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
            local raw = Player:GetAttribute("WhizyCfg10") or "{}"
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
-- ANTI-AFK
-- ============================================================
local afkThread = nil

local function stopAntiAfk()
    if afkThread then
        pcall(function() task.cancel(afkThread) end)
        afkThread = nil
    end
end

local function startAntiAfk()
    stopAntiAfk()
    afkThread = task.spawn(function()
        while cfg.antiAfk do
            task.wait(240)
            if not cfg.antiAfk then break end
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                task.wait(0.1)
                VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end)
            pcall(function()
                local char = Player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Jump = true end
                end
            end)
        end
    end)
end

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
        if LBL_RejoinStatus then LBL_RejoinStatus:Set("Auto-Rejoin: OFF") end
    end)
end

local function doRejoin()
    Rayfield:Notify({
        Title = "Auto-Rejoin", Content = "Queuing script and reconnecting...",
        Duration = 4, Image = "refresh-cw",
    })
    task.wait(2)
    if queue_on_teleport then
        pcall(function()
            queue_on_teleport([[
                loadstring(game:HttpGet("https://raw.githubusercontent.com/wh1zy69/WS/refs/heads/main/hola.lua", true))()
            ]])
        end)
    end
    local placeId = game.PlaceId
    local jobId   = game.JobId
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, Player)
    end)
    if not ok then pcall(function() TeleportService:Teleport(placeId) end) end
end

local function startRejoin()
    if rejoinThread then pcall(function() task.cancel(rejoinThread) end) end
    rejoinActive    = true
    rejoinCountdown = cfg.rejoinMins * 60
    rejoinThread = task.spawn(function()
        while rejoinActive and rejoinCountdown > 0 do
            task.wait(1)
            rejoinCountdown -= 1
            if rejoinCountdown % 5 == 0 or rejoinCountdown <= 10 then
                local mins    = math.floor(rejoinCountdown / 60)
                local secs    = rejoinCountdown % 60
                pcall(function()
                    if LBL_RejoinStatus then
                        LBL_RejoinStatus:Set("Auto-Rejoin: ON — next in "
                            .. string.format("%02d:%02d", mins, secs))
                    end
                end)
            end
        end
        if rejoinActive then doRejoin() end
    end)
end

-- ============================================================
-- TP FUNCTION
-- ============================================================
local function doTP(sword)
    if isTping then return end
    isTping = true
    local ok, err = pcall(function()
        local main = sword:FindFirstChild("Main")
        if not main then error("no Main part") end

        stats.tpCount += 1
        updateStats()
        setStatus("Grabbing sword...")

        -- Mover el personaje ENCIMA de la espada en bucle hasta que desaparece
        -- (se recoge). Es el método que usa el script que funciona.
        local gone, tries = false, 0
        repeat
            local char = Player.Character
            if char and main and main.Parent then
                char:MoveTo(main.Position + Vector3.new(0, 6, 0))
            end
            if (not sword) or sword.Parent == nil or (not main) or main.Parent == nil then
                gone = true
            else
                task.wait(0.5)
            end
            tries += 1
        until gone or tries >= 40

        -- Volver a la zona de venta con el remote real del juego
        if paper then
            pcall(function() paper.Network.InvokeServer("Teleport In Base", "Sell") end)
            pcall(function() paper.Network.InvokeServer("Teleport In Base", "Sell") end)
        end
        setStatus("Done. Waiting for swords...")
    end)
    if not ok then
        warn("[Whizy] doTP error: " .. tostring(err))
        setStatus("TP error — check console")
    end
    task.wait(0.3)
    isTping = false
end

-- ============================================================
-- 4x SERVER DETECTION
-- ============================================================
local FINDER_STATE_FILE = "Whizy4xState.json"
local PLACE_ID = 82432929049078

local function is4xServer()
    local function checkText(t)
        t = t:lower()
        return t:find("server luck") and t:find("%[%d+:%d+:%d+%]")
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local ok2, t = pcall(function() return obj.Text end)
            if ok2 and t and checkText(t) then return true end
        end
    end
    for _, obj in ipairs(Player.PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local ok2, t = pcall(function() return obj.Text end)
            if ok2 and t and checkText(t) then return true end
        end
    end
    pcall(function()
        for _, obj in ipairs(game:GetService("CoreGui"):GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                local ok2, t = pcall(function() return obj.Text end)
                if ok2 and t and checkText(t) then return true end
            end
        end
    end)
    return false
end

-- ============================================================
-- OBTENER SERVIDOR ALEATORIO DIFERENTE AL ACTUAL
-- ============================================================
local function getRandomServer()
    if not httpRequest then return nil end

    local currentJobId = game.JobId
    local targetJobId  = nil
    local cursor       = ""
    local attempts     = 0

    -- Intentar hasta 3 páginas de la API para tener más variedad
    while attempts < 3 do
        attempts += 1
        local url = "https://games.roblox.com/v1/games/" .. PLACE_ID
            .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end

        local ok, response = pcall(function()
            return httpRequest({ Url=url, Method="GET",
                Headers={["Content-Type"]="application/json"} })
        end)

        if not ok or not response or response.StatusCode ~= 200 then break end

        local parsed
        local okParse = pcall(function()
            parsed = HttpService:JSONDecode(response.Body)
        end)
        if not okParse or not parsed or not parsed.data then break end

        local available = {}
        for _, server in ipairs(parsed.data) do
            if server.id
            and server.id ~= currentJobId
            and server.playing ~= nil
            and server.maxPlayers ~= nil
            and server.playing >= 12
            and server.playing <= 15 then
                table.insert(available, server.id)
            end
        end

        if #available > 0 then
            targetJobId = available[math.random(1, #available)]
            break
        end

        -- Si no hay disponibles en esta página, pasar a la siguiente
        if parsed.nextPageCursor and parsed.nextPageCursor ~= "" then
            cursor = parsed.nextPageCursor
        else
            break
        end
    end

    return targetJobId
end

-- ============================================================
-- FIND 4x SERVER
-- ============================================================
local finding4x    = false
local find4xThread = nil
local LBL_4xStatus

local function stop4xFinder()
    finding4x = false
    if find4xThread then
        pcall(function() task.cancel(find4xThread) end)
        find4xThread = nil
    end
    pcall(function() writefile(FINDER_STATE_FILE, "{}") end)
    pcall(function()
        if LBL_4xStatus then LBL_4xStatus:Set("4x Finder: OFF") end
    end)
end

local function send4xWebhook(jobId)
    if not httpRequest or not cfg.webhookURL or cfg.webhookURL == "" then return end
    local body = HttpService:JSONEncode({
        content  = cfg.pingEveryone and "@everyone" or "",
        username = "Whizy | Sword Factory X",
        embeds   = {{
            title       = "4x Luck Server Found!",
            description = "A 4x luck server was detected!\nJoin now before it ends.",
            color       = 16776960,
            fields      = {
                { name="Player",  value=MyName,               inline=true  },
                { name="Game ID", value=tostring(PLACE_ID),   inline=true  },
                { name="Job ID",  value=tostring(jobId),      inline=false },
            },
            footer    = { text="Whizy v10.0" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    pcall(function()
        httpRequest({ Url=cfg.webhookURL, Method="POST",
            Headers={["Content-Type"]="application/json"}, Body=body })
    end)
end

local function start4xFinder()
    if find4xThread then pcall(function() task.cancel(find4xThread) end) end
    finding4x = true

    pcall(function()
        writefile(FINDER_STATE_FILE, HttpService:JSONEncode({ active=true, checked=0 }))
    end)

    find4xThread = task.spawn(function()
        local serversChecked = 0

        while finding4x do
            pcall(function()
                if LBL_4xStatus then
                    LBL_4xStatus:Set("Waiting for server to load... (" .. serversChecked .. " checked)")
                end
            end)

            -- Esperar 8s a que el servidor cargue completamente antes de checkear
            task.wait(5)
            if not finding4x then break end

            if is4xServer() then
                finding4x = false
                local jobId = game.JobId
                pcall(function() writefile(FINDER_STATE_FILE, "{}") end)

                Rayfield:Notify({
                    Title    = "4x Server Found!",
                    Content  = "Staying in this server!",
                    Duration = 10,
                    Image    = "star",
                })
                send4xWebhook(jobId)
                pcall(function()
                    if LBL_4xStatus then
                        LBL_4xStatus:Set("4x FOUND! Job: " .. jobId:sub(1,8) .. "...")
                    end
                end)
                return
            end

            -- No tiene 4x, buscar siguiente servidor
            serversChecked += 1
            pcall(function()
                if LBL_4xStatus then
                    LBL_4xStatus:Set("No 4x here. Finding next server... (" .. serversChecked .. " checked)")
                end
            end)

            pcall(function()
                writefile(FINDER_STATE_FILE, HttpService:JSONEncode({ active=true, checked=serversChecked }))
            end)

            -- Queue el script para que se re-ejecute tras el teleport
            if queue_on_teleport then
                pcall(function()
                    queue_on_teleport([[
                        loadstring(game:HttpGet("https://raw.githubusercontent.com/wh1zy69/WS/refs/heads/main/hola.lua", true))()
                    ]])
                end)
            end

            task.wait(1)

            -- Obtener un servidor diferente via API y teleportarse
            local newJobId = getRandomServer()
            if newJobId then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(PLACE_ID, newJobId)
                end)
            else
                -- Fallback si la API no devuelve nada
                pcall(function()
                    TeleportService:Teleport(PLACE_ID)
                end)
            end

            -- Esperar a que el teleport ocurra
            task.wait(8)
        end
    end)
end

-- ============================================================
-- AUTO-REANUDAR FINDER SI ESTABA ACTIVO ANTES DEL TELEPORT
-- ============================================================
task.spawn(function()
    task.wait(3)
    pcall(function()
        if isfile and isfile(FINDER_STATE_FILE) then
            local raw = readfile(FINDER_STATE_FILE)
            local ok, state = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(state) == "table" and state.active == true then
                Rayfield:Notify({
                    Title    = "4x Finder resuming",
                    Content  = "Continuing server hop search...",
                    Duration = 4,
                    Image    = "refresh-cw",
                })
                start4xFinder()
            end
        end
    end)
end)

-- ============================================================
-- WINDOW
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name                   = "Whizy — Sword Factory X",
    LoadingTitle           = "Whizy Script",
    LoadingSubtitle        = "Auto Enchant Detector v10.0",
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
local TabFinder   = Window:CreateTab("4x Finder",  "star")
local TabRejoin   = Window:CreateTab("Auto-Rejoin", "refresh-cw")
local TabSettings = Window:CreateTab("Settings",    "settings")
local TabWebhook  = Window:CreateTab("Webhook",     "bell")
local TabStats    = Window:CreateTab("Statistics",  "bar-chart-2")

-- ============================================================
-- TAB: DETECTOR
-- 3 sword filter sets, each with 3 enchant slots
-- A sword matches if it satisfies ANY of the active sets
-- ============================================================
TabDetector:CreateSection("Sword Set 1")
TabDetector:CreateLabel("Sword must have ALL active enchants in this set.")

local DS1E1 = TabDetector:CreateDropdown({
    Name="Set 1 — Enchant 1", Options=ENCHANT_OPTS,
    CurrentOption={cfg.s1e1 or "None"}, MultipleOptions=false, Flag="DS1E1",
    Callback=function(o) cfg.s1e1=(o[1]=="None") and nil or o[1]; saveCfg() end,
})
local DS1E2 = TabDetector:CreateDropdown({
    Name="Set 1 — Enchant 2", Options=ENCHANT_OPTS,
    CurrentOption={cfg.s1e2 or "None"}, MultipleOptions=false, Flag="DS1E2",
    Callback=function(o) cfg.s1e2=(o[1]=="None") and nil or o[1]; saveCfg() end,
})
local DS1E3 = TabDetector:CreateDropdown({
    Name="Set 1 — Enchant 3", Options=ENCHANT_OPTS,
    CurrentOption={cfg.s1e3 or "None"}, MultipleOptions=false, Flag="DS1E3",
    Callback=function(o) cfg.s1e3=(o[1]=="None") and nil or o[1]; saveCfg() end,
})

TabDetector:CreateSection("Sword Set 2")
TabDetector:CreateLabel("Sword must have ALL active enchants in this set.")

local DS2E1 = TabDetector:CreateDropdown({
    Name="Set 2 — Enchant 1", Options=ENCHANT_OPTS,
    CurrentOption={cfg.s2e1 or "None"}, MultipleOptions=false, Flag="DS2E1",
    Callback=function(o) cfg.s2e1=(o[1]=="None") and nil or o[1]; saveCfg() end,
})
local DS2E2 = TabDetector:CreateDropdown({
    Name="Set 2 — Enchant 2", Options=ENCHANT_OPTS,
    CurrentOption={cfg.s2e2 or "None"}, MultipleOptions=false, Flag="DS2E2",
    Callback=function(o) cfg.s2e2=(o[1]=="None") and nil or o[1]; saveCfg() end,
})
local DS2E3 = TabDetector:CreateDropdown({
    Name="Set 2 — Enchant 3", Options=ENCHANT_OPTS,
    CurrentOption={cfg.s2e3 or "None"}, MultipleOptions=false, Flag="DS2E3",
    Callback=function(o) cfg.s2e3=(o[1]=="None") and nil or o[1]; saveCfg() end,
})

TabDetector:CreateSection("Sword Set 3")
TabDetector:CreateLabel("Sword must have ALL active enchants in this set.")

local DS3E1 = TabDetector:CreateDropdown({
    Name="Set 3 — Enchant 1", Options=ENCHANT_OPTS,
    CurrentOption={cfg.s3e1 or "None"}, MultipleOptions=false, Flag="DS3E1",
    Callback=function(o) cfg.s3e1=(o[1]=="None") and nil or o[1]; saveCfg() end,
})
local DS3E2 = TabDetector:CreateDropdown({
    Name="Set 3 — Enchant 2", Options=ENCHANT_OPTS,
    CurrentOption={cfg.s3e2 or "None"}, MultipleOptions=false, Flag="DS3E2",
    Callback=function(o) cfg.s3e2=(o[1]=="None") and nil or o[1]; saveCfg() end,
})
local DS3E3 = TabDetector:CreateDropdown({
    Name="Set 3 — Enchant 3", Options=ENCHANT_OPTS,
    CurrentOption={cfg.s3e3 or "None"}, MultipleOptions=false, Flag="DS3E3",
    Callback=function(o) cfg.s3e3=(o[1]=="None") and nil or o[1]; saveCfg() end,
})

TabDetector:CreateSection("Options")

local TG_AutoTP = TabDetector:CreateToggle({
    Name="Auto-TP on match", CurrentValue=cfg.autoTP, Flag="TG_AutoTP",
    Callback=function(v) cfg.autoTP=v; saveCfg() end,
})
local TG_NotifyAll = TabDetector:CreateToggle({
    Name="Notify unmatched swords", CurrentValue=cfg.notifyAll, Flag="TG_NotifyAll",
    Callback=function(v) cfg.notifyAll=v; saveCfg() end,
})
local TG_ShowAll = TabDetector:CreateToggle({
    Name="Log all swords to console", CurrentValue=cfg.showAll, Flag="TG_ShowAll",
    Callback=function(v) cfg.showAll=v; saveCfg() end,
})

TabDetector:CreateSection("Live Status")

local StatusBtn = TabDetector:CreateButton({
    Name="Status: Waiting for swords...", Callback=function() end,
})

setStatus = function(text)
    pcall(function() StatusBtn:Set("Status: " .. text) end)
end

-- ============================================================
-- TAB: 4x FINDER
-- ============================================================
TabFinder:CreateSection("4x Luck Server Finder")
TabFinder:CreateLabel("Hops servers until a 4x luck server is found.")
TabFinder:CreateLabel("When found, sends a Discord webhook alert.")
TabFinder:CreateLabel("NOTE: Detector is paused while finder is active.")

LBL_4xStatus = TabFinder:CreateLabel("4x Finder: OFF")

TabFinder:CreateButton({
    Name     = "Start 4x Finder",
    Callback = function()
        if finding4x then
            Rayfield:Notify({ Title="Already running", Content="4x Finder is already active.", Duration=3, Image="alert-triangle" })
            return
        end
        Rayfield:Notify({ Title="4x Finder started", Content="Hopping servers to find 4x luck...", Duration=4, Image="star" })
        start4xFinder()
    end,
})

TabFinder:CreateButton({
    Name     = "Stop 4x Finder",
    Callback = function()
        stop4xFinder()
        Rayfield:Notify({ Title="4x Finder stopped", Content="Server hopping cancelled.", Duration=3, Image="x-circle" })
    end,
})

TabFinder:CreateSection("Manual Check")

TabFinder:CreateButton({
    Name     = "Check THIS server for 4x",
    Callback = function()
        if is4xServer() then
            Rayfield:Notify({ Title="YES! 4x detected", Content="This server has 4x luck!", Duration=6, Image="star" })
        else
            Rayfield:Notify({ Title="No 4x here", Content="This server does NOT have 4x luck.", Duration=4, Image="x-circle" })
        end
    end,
})

-- ============================================================
-- TAB: AUTO-REJOIN
-- ============================================================
TabRejoin:CreateSection("Anti-AFK")
TabRejoin:CreateLabel("Jumps every 4 min to avoid the 14 min AFK kick.")

local TG_AntiAfk = TabRejoin:CreateToggle({
    Name="Enable Anti-AFK", CurrentValue=cfg.antiAfk, Flag="TG_AntiAfk",
    Callback=function(v)
        cfg.antiAfk=v; saveCfg()
        if v then startAntiAfk(); Rayfield:Notify({ Title="Anti-AFK ON", Content="Jumping every 4 min.", Duration=3, Image="check-circle" })
        else stopAntiAfk(); Rayfield:Notify({ Title="Anti-AFK OFF", Content="Disabled.", Duration=3, Image="x-circle" }) end
    end,
})

TabRejoin:CreateSection("Auto-Rejoin Settings")
TabRejoin:CreateLabel("Rejoins same server every X minutes.")

LBL_RejoinStatus = TabRejoin:CreateLabel("Auto-Rejoin: OFF")

local TG_AutoRejoin = TabRejoin:CreateToggle({
    Name="Enable Auto-Rejoin", CurrentValue=cfg.autoRejoin, Flag="TG_AutoRejoin",
    Callback=function(v)
        cfg.autoRejoin=v; saveCfg()
        if v then startRejoin(); Rayfield:Notify({ Title="Auto-Rejoin ON", Content="Rejoin in "..cfg.rejoinMins.." min.", Duration=4, Image="check-circle" })
        else stopRejoin(); Rayfield:Notify({ Title="Auto-Rejoin OFF", Content="Disabled.", Duration=3, Image="x-circle" }) end
    end,
})

local SL_Mins = TabRejoin:CreateSlider({
    Name="Rejoin interval (minutes)", Range={5,60}, Increment=1, Suffix="min",
    CurrentValue=cfg.rejoinMins, Flag="SL_RejoinMins",
    Callback=function(v) cfg.rejoinMins=v; saveCfg(); if cfg.autoRejoin then startRejoin() end end,
})

TabRejoin:CreateSection("Manual Controls")

TabRejoin:CreateButton({
    Name="Restart timer",
    Callback=function()
        if cfg.autoRejoin then startRejoin(); Rayfield:Notify({ Title="Timer restarted", Content="Next rejoin in "..cfg.rejoinMins.." min.", Duration=3, Image="refresh-cw" })
        else Rayfield:Notify({ Title="Disabled", Content="Enable Auto-Rejoin first.", Duration=3, Image="alert-triangle" }) end
    end,
})
TabRejoin:CreateButton({
    Name="Rejoin NOW",
    Callback=function()
        Rayfield:Notify({ Title="Rejoining...", Content="Teleporting in 2s.", Duration=3, Image="zap" })
        task.spawn(doRejoin)
    end,
})

-- ============================================================
-- TAB: SETTINGS
-- ============================================================
TabSettings:CreateSection("GUI Toggle Key")
TabSettings:CreateLabel("Key to show / hide the GUI.")

local DD_Key = TabSettings:CreateDropdown({
    Name="Toggle Key", Options=KEYBIND_OPTS,
    CurrentOption={cfg.toggleKey or "RightControl"}, MultipleOptions=false, Flag="DD_Key",
    Callback=function(opts)
        cfg.toggleKey=opts[1]; saveCfg()
        Rayfield:Notify({ Title="Keybind updated", Content="Toggle key: "..opts[1], Duration=3, Image="keyboard" })
    end,
})

TabSettings:CreateSection("Configuration")

TabSettings:CreateButton({
    Name="Save config now",
    Callback=function()
        saveCfg()
        Rayfield:Notify({ Title="Saved", Content="Config saved.", Duration=3, Image="check" })
    end,
})

TabSettings:CreateButton({
    Name="Reset to defaults",
    Callback=function()
        for k,v in pairs(DEFAULT_CONFIG) do cfg[k]=v end
        saveCfg()
        pcall(function() DS1E1:Set({cfg.s1e1 or "None"}) end)
        pcall(function() DS1E2:Set({cfg.s1e2 or "None"}) end)
        pcall(function() DS1E3:Set({cfg.s1e3 or "None"}) end)
        pcall(function() DS2E1:Set({cfg.s2e1 or "None"}) end)
        pcall(function() DS2E2:Set({cfg.s2e2 or "None"}) end)
        pcall(function() DS2E3:Set({cfg.s2e3 or "None"}) end)
        pcall(function() DS3E1:Set({cfg.s3e1 or "None"}) end)
        pcall(function() DS3E2:Set({cfg.s3e2 or "None"}) end)
        pcall(function() DS3E3:Set({cfg.s3e3 or "None"}) end)
        pcall(function() TG_AutoTP:Set(cfg.autoTP) end)
        pcall(function() TG_NotifyAll:Set(cfg.notifyAll) end)
        pcall(function() TG_ShowAll:Set(cfg.showAll) end)
        pcall(function() DD_Key:Set({cfg.toggleKey}) end)
        pcall(function() TG_AutoRejoin:Set(cfg.autoRejoin) end)
        pcall(function() TG_AntiAfk:Set(cfg.antiAfk) end)
        pcall(function() SL_Mins:Set(cfg.rejoinMins) end)
        Rayfield:Notify({ Title="Reset", Content="Defaults restored.", Duration=3, Image="refresh-cw" })
    end,
})

TabSettings:CreateSection("About")
TabSettings:CreateLabel("Whizy v10.0 — Sword Factory X")
TabSettings:CreateLabel("Player: " .. MyName .. "  |  ID: " .. tostring(MyID))
TabSettings:CreateLabel("Source: github.com/wh1zy69/WS")

-- ============================================================
-- TAB: WEBHOOK
-- ============================================================
TabWebhook:CreateSection("Discord Webhook")
TabWebhook:CreateLabel("Sends embeds on sword match AND 4x server found.")

if not httpRequest then
    TabWebhook:CreateLabel("WARNING: executor does not expose request(). Webhook unavailable.")
end

TabWebhook:CreateInput({
    Name="Webhook URL", CurrentValue=cfg.webhookURL or "",
    PlaceholderText="https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost=false, Flag="WH_URL",
    Callback=function(text) cfg.webhookURL=text; saveCfg() end,
})
TabWebhook:CreateToggle({
    Name="Enable Webhook", CurrentValue=cfg.webhookOn, Flag="TG_WH_On",
    Callback=function(v) cfg.webhookOn=v; saveCfg() end,
})
TabWebhook:CreateToggle({
    Name="@everyone on match", CurrentValue=cfg.pingEveryone, Flag="TG_WH_Ping",
    Callback=function(v) cfg.pingEveryone=v; saveCfg() end,
})

TabWebhook:CreateSection("Test")
TabWebhook:CreateButton({
    Name="Send test message",
    Callback=function()
        if not cfg.webhookURL or cfg.webhookURL=="" then
            Rayfield:Notify({ Title="No URL", Content="Enter webhook URL first.", Duration=4, Image="alert-triangle" }); return
        end
        if not httpRequest then
            Rayfield:Notify({ Title="Unsupported", Content="Executor does not support http.request.", Duration=4, Image="x-circle" }); return
        end
        local body = HttpService:JSONEncode({
            content=cfg.pingEveryone and "@everyone" or "",
            username="Whizy | Sword Factory X",
            embeds={{
                title="Test message",
                description="Webhook configured correctly.\nPlayer: **"..MyName.."**",
                color=9699539, footer={text="Whizy v10.0"},
            }}
        })
        local ok, res = pcall(function()
            return httpRequest({ Url=cfg.webhookURL, Method="POST",
                Headers={["Content-Type"]="application/json"}, Body=body })
        end)
        if ok and res and (res.StatusCode==200 or res.StatusCode==204) then
            Rayfield:Notify({ Title="Webhook OK", Content="Test sent to Discord.", Duration=4, Image="check-circle" })
        elseif ok and res then
            Rayfield:Notify({ Title="Error", Content="HTTP "..tostring(res.StatusCode), Duration=5, Image="x-circle" })
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
    Name="Reset statistics",
    Callback=function()
        stats.total,stats.withEnchants,stats.tpCount,stats.webhookSent=0,0,0,0
        updateStats()
        Rayfield:Notify({ Title="Stats reset", Content="All counters set to 0.", Duration=3, Image="trash-2" })
    end,
})

-- ============================================================
-- WEBHOOK SENDER (sword match)
-- ============================================================
-- Limpia las etiquetas de color (rich text) del texto que devuelve Roblox
local function cleanText(s)
    if not s then return "Unknown" end
    s = tostring(s):gsub("<[^>]->", "")              -- quita <font ...> y </font>
    s = s:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1") -- recorta espacios
    return (s == "" and "Unknown") or s
end

-- Capitaliza un enchant: "ancient" -> "Ancient"
local function cap(w)
    if not w or w == "" then return nil end
    return w:sub(1,1):upper() .. w:sub(2):lower()
end

-- Formatea 3 slots como "1: X\n2: Y\n3: Z" (— si está vacío)
local function fmtSlots(list)
    local lines = {}
    for i = 1, 3 do
        local v = list[i]
        if v and v ~= "" and tostring(v):lower() ~= "none" then
            v = cap(tostring(v))
        else
            v = "—"
        end
        table.insert(lines, "`" .. i .. ":` " .. v)
    end
    return table.concat(lines, "\n")
end

-- info = { level, target = {e1,e2,e3}, actual = {..}, rarity, quality, id, creator, setNum }
local function sendWebhook(info)
    if not cfg.webhookOn or not cfg.webhookURL or cfg.webhookURL=="" then return end
    if not httpRequest then return end

    local cleanLevel = cleanText(info.level)
    local idStr   = tostring(info.id or "?")
    local idShort = #idStr > 10 and (idStr:sub(1,10) .. "...") or idStr

    local body = HttpService:JSONEncode({
        content  = cfg.pingEveryone and "@everyone" or "",
        username = "Whizy • Sword Factory X",
        embeds   = {{
            title = "🌟  God Roll Sniped!",
            color = 16766720,  -- dorado
            fields = {
                { name = "🎯  Matched Logic",
                  value = "**Set " .. info.setNum .. "** Detector",
                  inline = false },

                { name = "📝  Target Enchants", value = fmtSlots(info.target), inline = true },
                { name = "💥  Actual Roll",     value = fmtSlots(info.actual), inline = true },

                { name = "🛡️  Sword Info",
                  value = "**ID:** `" .. idShort .. "`\n"
                       .. "**Creator:** " .. tostring(info.creator or "?") .. "\n"
                       .. "**Level:** " .. cleanLevel .. "\n"
                       .. "**Rarity:** " .. tostring(info.rarity) .. "   **Quality:** " .. tostring(info.quality),
                  inline = false },
            },
            footer = { text = "Whizy User Analytics  |  " .. os.date("!%Y-%m-%d %H:%M:%S") },
        }}
    })
    local ok = pcall(function()
        httpRequest({ Url=cfg.webhookURL, Method="POST",
            Headers={["Content-Type"]="application/json"}, Body=body })
    end)
    if ok then stats.webhookSent+=1; updateStats() end
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
    -- Igual que el script que funciona: Enchant1/2/3 y el primer token en minúsculas
    for i = 1, 3 do
        local lbl = encFolder:FindFirstChild("Enchant" .. i)
        if lbl and lbl.Text ~= "" then
            local name = string.lower(lbl.Text):match("^(%S+)")
            if name and name ~= "" and name ~= "none" then
                table.insert(result, name)
            end
        end
    end
    -- Fallback por si no existen Enchant1/2/3: iterar los labels
    if #result == 0 then
        for _, lbl in pairs(encFolder:GetChildren()) do
            if lbl:IsA("TextLabel") and lbl.Text ~= "" then
                local name = lbl.Text:match("^(%a+)")
                if name then table.insert(result, name:lower()) end
            end
        end
    end
    return result
end

-- Returns the set number that matched (1, 2, or 3), or nil
-- Devuelve el nº de set que coincide, o nil.
-- Lógica del script de referencia (combinaciones): para CADA enchant listado
-- en el set, la espada debe tener EXACTAMENTE esa cantidad.
--   Set "Ancient,Ancient,Fortune" -> {ancient=2, fortune=1} -> exige 2 ancient + 1 fortune
--   Set "Fortune,None,None"       -> {fortune=1}            -> exige exactamente 1 fortune
local function matchCombos(allenchants)
    for setNum = 1, 3 do
        local combo, count = {}, 0
        for _, key in ipairs({ "s"..setNum.."e1", "s"..setNum.."e2", "s"..setNum.."e3" }) do
            local v = cfg[key]
            if v and v ~= "" and tostring(v):lower() ~= "none" then
                local lv = tostring(v):lower()
                combo[lv] = (combo[lv] or 0) + 1
                count += 1
            end
        end
        if count > 0 then
            local result = true
            for enchant, amount in pairs(combo) do
                if (allenchants[enchant] or 0) ~= amount then
                    result = false
                    break
                end
            end
            if result then return setNum end
        end
    end
    return nil
end

local function procesarEspada(sword)
    task.spawn(function()
        if finding4x then return end
        if not sword or not sword.Parent then return end

        -- Esperar la parte Main (igual que el script de referencia)
        local main, n = nil, 0
        repeat
            main = sword:FindFirstChild("Main")
            n += 1
            task.wait()
        until n >= 1000 or main
        if not main then return end

        local gui = main:WaitForChild("Gui", 10)
        if not gui then return end
        local itemInfo = gui:WaitForChild("ItemInfo", 10)
        if not itemInfo then return end

        -- Dueño por NOMBRE
        local swordowner = itemInfo:WaitForChild("Username", 5)
        if not swordowner or swordowner.Text ~= MyName then return end

        -- Esperar a que la espada entre en estado de venta
        local selling = itemInfo:WaitForChild("Selling", 5)
        if not selling then return end
        selling:GetPropertyChangedSignal("Text"):Wait()

        -- Solo seguir si la espada está en la zona de venta (check de distancia)
        if sellsmain then
            local distance = (sellsmain.Position - main.Position).Magnitude
            if distance > maxdistance then
                if cfg.showAll then print("[Whizy] espada lejos de la venta, ignorada") end
                return
            end
        end

        -- Leer los 3 enchants (Enchant1/2/3) y contarlos
        local enchF = itemInfo:WaitForChild("Enchants", 5)
        if not enchF then return end
        local e1 = enchF:WaitForChild("Enchant1", 3)
        local e2 = enchF:WaitForChild("Enchant2", 3)
        local e3 = enchF:WaitForChild("Enchant3", 3)
        if not (e1 and e2 and e3) then return end
        local e1t = string.lower(e1.Text):match("^(%S+)")
        local e2t = string.lower(e2.Text):match("^(%S+)")
        local e3t = string.lower(e3.Text):match("^(%S+)")
        if not (e1t and e2t and e3t) then return end

        local allenchants = {}
        for _, e in ipairs({ e1t, e2t, e3t }) do
            allenchants[e] = (allenchants[e] or 0) + 1
        end

        -- Datos extra para el webhook (mejor esfuerzo desde atributos)
        local attr = sword:GetAttributes()
        local levelLabel = itemInfo:FindFirstChild("Level")
        local finalLevel = (levelLabel and levelLabel.Text ~= "" and levelLabel.Text)
                           or ("Level " .. tostring(attr.Level or "?"))

        local enchList = {}
        for _, e in ipairs({ e1t, e2t, e3t }) do
            if e ~= "none" then table.insert(enchList, e) end
        end
        local enchStr = #enchList > 0 and table.concat(enchList, " | ") or "no enchants"

        stats.total += 1
        stats.withEnchants += 1
        updateStats()

        if cfg.showAll then
            print("==== SWORD ==== " .. finalLevel .. "  |  " .. enchStr)
        end

        setStatus("Detected: " .. finalLevel)

        local matchedSet = matchCombos(allenchants)
        if matchedSet then
            setStatus("MATCH (Set "..matchedSet..")! " .. enchStr)
            Rayfield:Notify({
                Title    = "Match found! (Set " .. matchedSet .. ")",
                Content  = finalLevel .. "\n" .. enchStr,
                Duration = 6, Image = "zap",
            })
            task.spawn(function()
                sendWebhook({
                    level   = finalLevel,
                    target  = { cfg["s"..matchedSet.."e1"], cfg["s"..matchedSet.."e2"], cfg["s"..matchedSet.."e3"] },
                    actual  = enchList,
                    rarity  = attr.Rarity,
                    quality = attr.Quality,
                    id      = attr.ID or attr.Id or attr.UUID or attr.GUID or sword.Name,
                    creator = attr.Creator or attr.Owner,
                    setNum  = matchedSet,
                })
            end)
            if cfg.autoTP then doTP(sword) end
        elseif cfg.notifyAll then
            Rayfield:Notify({
                Title="New sword", Content=finalLevel.."  |  "..enchStr,
                Duration=3, Image="package",
            })
        end
    end)
end

-- ============================================================
-- START
-- ============================================================
Folder.ChildAdded:Connect(procesarEspada)

-- Posicionarse en la zona de venta (como el script de referencia hace al iniciar).
-- Necesario para que el agarre y el check de distancia funcionen bien.
if cfg.autoTP and paper then
    pcall(function() paper.Network.InvokeServer("Teleport In Base", "Sell") end)
end

if cfg.antiAfk then startAntiAfk() end
if cfg.autoRejoin then startRejoin() end

setStatus("Waiting for swords from " .. MyName .. "...")

Rayfield:Notify({
    Title   = "Whizy v10.0 loaded",
    Content = "Player: " .. MyName
        .. "\nKey: " .. (cfg.toggleKey or "RightControl")
        .. "\nSets active: " .. (
            (cfg.s1e1 and "1" or "") ..
            (cfg.s2e1 and " 2" or "") ..
            (cfg.s3e1 and " 3" or "")
        ),
    Duration = 6, Image = "check-circle",
})

print("--- Whizy v10.0 | " .. MyName .. " ---")
