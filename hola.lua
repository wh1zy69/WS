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

        local char = Player.Character

        if not char then error("no char") end

        local hrp = char:FindFirstChild("HumanoidRootPart")

        if not hrp then error("no hrp") end

        local originalCF = hrp.CFrame

        local swordPos   = sword:GetPivot().Position + Vector3.new(0, 5, 0)

        hrp.CFrame = CFrame.new(swordPos)

        stats.tpCount += 1

        updateStats()

        setStatus("Teleported! Returning in 1s...")

        task.wait(1)

        local char2 = Player.Character

        if not char2 then error("no char2") end

        local hrp2 = char2:FindFirstChild("HumanoidRootPart")

        if not hrp2 then error("no hrp2") end

        for i = 1, 5 do hrp2.CFrame = originalCF; task.wait(0.1) end

        setStatus("Returned. Waiting for swords...")

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
