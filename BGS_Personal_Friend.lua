-- Explicit allowlist: preferences only, never active automation or credentials.
local function installPersonalSettings(S, keepCurrent)
    if S.personalSettingsInstalled then
        if S.personalSaveSettings then S.personalSaveSettings() end
        return
    end
    S.personalSettingsInstalled = true
    local path = "BGSPersonal/last-settings.json"
    local Http = S.Services.HttpService
    local fields = {
        {key="selectedEgg",kind="string",handle="eggDropdownElement",options="EGG_LIST"},
        {key="selectedBox",kind="string",handle="boxDropdownElement",options="BOX_LIST"},
        {key="multiEgg",kind="boolean",handle="multiEggToggle"},
        {key="boxMulti",kind="boolean"},
        {key="eggInterval",kind="number",min=0.025,max=5,handle="eggIntervalSlider"},
        {key="boxInterval",kind="number",min=0.15,max=5},
        {key="includeBoxes",kind="boolean",handle="includeBoxesToggle"},
        {key="teleportOnLoad",kind="boolean",handle="savedTeleportToggle"},
        {key="savedPosX",kind="number",min=-1000000,max=1000000},
        {key="savedPosY",kind="number",min=-1000000,max=1000000},
        {key="savedPosZ",kind="number",min=-1000000,max=1000000},
        {key="autoOpenOnLoad",kind="boolean",handle="autoOpenOnLoadToggle"},
        {key="eggAnimationSuppressed",kind="boolean",handle="eggAnimationToggle"},
        {key="blackScreenOnLoad",kind="boolean",handle="blackScreenToggle"},
        {key="chestReturnToEgg",kind="boolean",handle="chestReturnToggle"},
        {key="optLowQuality",kind="boolean",handle="optLowQualityToggle",get=function() return S.opt.lowQuality end},
        {key="optNoShadows",kind="boolean",handle="optNoShadowsToggle",get=function() return S.opt.noShadows end},
        {key="optNoLightingFx",kind="boolean",handle="optNoLightingFxToggle",get=function() return S.opt.noLightingFx end},
        {key="optNoParticles",kind="boolean",handle="optNoParticlesToggle",get=function() return S.opt.noParticles end},
        {key="optMuteAudio",kind="boolean",handle="optMuteAudioToggle",get=function() return S.opt.muteAudio end},
        {key="optHideOtherTags",kind="boolean",handle="optHideOtherTagsToggle",get=function() return S.opt.hideOtherTags end},
        {key="optNoTerrainDecoration",kind="boolean",handle="optNoTerrainDecorationToggle",get=function() return S.opt.noTerrainDecoration end},
        {key="optNoSky",kind="boolean",handle="optNoSkyToggle",get=function() return S.opt.noSky end},
        {key="optNoReflections",kind="boolean",handle="optNoReflectionsToggle",get=function() return S.opt.noReflections end},
        {key="optTightStreaming",kind="boolean",handle="optTightStreamingToggle",get=function() return S.opt.tightStreaming end},
    }
    local paragraph
    if S.SettingsTab then
        S.SettingsTab:CreateSection("Remember Hatch / Premium settings")
        paragraph = S.SettingsTab:CreateParagraph({Title="Remember settings",Content="Loading saved preferences..."})
        S.SettingsTab:CreateSection("Multi-window teleport")
        S.savedTeleportToggle = S.SettingsTab:CreateToggle({
            Name="Teleport to saved position on load",
            CurrentValue=true,
            Flag="TeleportOnLoad",
            Callback=function(value) S.teleportOnLoad=value==true end,
        })
        S.SettingsTab:CreateButton({
            Name="Save current position",
            Callback=function()
                if not S.hrp then
                    notice("Character is not ready yet.")
                    return
                end
                local p=S.hrp.Position
                S.savedPosX,S.savedPosY,S.savedPosZ=p.X,p.Y,p.Z
                local ok,err=S.personalSaveSettings and S.personalSaveSettings()
                notice(ok and "Position saved for the next run." or ("Position save failed: "..tostring(err)))
            end,
        })
        S.SettingsTab:CreateButton({
            Name="Teleport to saved position",
            Callback=function()
                if not S.hrp then notice("Character is not ready yet."); return end
                if type(S.savedPosX)~="number" or type(S.savedPosY)~="number" or type(S.savedPosZ)~="number" then
                    notice("No saved position yet. Use Save current position first.")
                    return
                end
                local ok,err=pcall(function()
                    S.hrp.CFrame=CFrame.new(S.savedPosX,S.savedPosY,S.savedPosZ)
                end)
                notice(ok and "Teleported to saved position." or ("Teleport failed: "..tostring(err)))
            end,
        })
    end
    local lastStatus
    local function show(text)
        if text == lastStatus then return end
        lastStatus=text
        S.personalSettingsStatus=text
        if paragraph then pcall(function() paragraph:Set({Title="Remember settings",Content=text}) end) end
    end
    local function notice(text)
        if S.Rayfield then pcall(function() S.Rayfield:Notify({Title="Remember settings",Content=text,Duration=8}) end) end
    end
    if type(readfile)~="function" or type(writefile)~="function" or
        type(isfolder)~="function" or type(makefolder)~="function" or type(isfile)~="function" then
        S.personalSettingsInstalled=false
        show("File access unavailable. This executor cannot remember preferences.")
        notice(S.personalSettingsStatus)
        return
    end
    local function checked(field,value)
        if type(value)~=field.kind then return nil end
        if field.kind=="number" then
            if value~=value or value==math.huge or value==-math.huge then return nil end
            value=math.clamp(value,field.min,field.max)
            if field.integer then value=math.floor(value) end
        elseif field.kind=="string" then
            if #value==0 or #value>200 then return nil end
        end
        return value
    end
    local function fieldValue(field)
        if field.get then return field.get() end
        return S[field.key]
    end
    local function capture()
        local result={}
        for _,field in ipairs(fields) do result[field.key]=checked(field,fieldValue(field)) end
        return result
    end
    local function same(a,b)
        for _,field in ipairs(fields) do if a[field.key]~=b[field.key] then return false end end
        return true
    end
    local autoSave=true
    local restored=false
    if not keepCurrent then
        local existsOk,exists=pcall(isfile,path)
        if not existsOk then
            autoSave=false
            show("Cannot check saved settings. Auto-save paused; use Save settings now to retry.")
        elseif exists then
            local ok,saved=pcall(function() return Http:JSONDecode(readfile(path)) end)
            if not ok or type(saved)~="table" or saved.version~=1 or type(saved.values)~="table" then
                autoSave=false
                show("Saved settings unreadable or unsupported. File preserved; Save settings now replaces it with current preferences.")
                notice(S.personalSettingsStatus)
            else
                local skipped={}
                for _,field in ipairs(fields) do
                    local value=checked(field,saved.values[field.key])
                    -- Keep the measured hatch request interval at the supported
                    -- minimum. Older saved files may contain 0.15 or another
                    -- value and would otherwise overwrite the UI default.
                    if field.key=="eggInterval" then value=0.025 end
                    if value~=nil then
                        if field.options and not table.find(S[field.options] or {},value) then
                            table.insert(skipped,value)
                        else
                            local control=field.handle and S[field.handle]
                            local setOk=true
                            if control then
                                setOk=pcall(function()
                                    if field.options then control:Set({value}) else control:Set(value) end
                                end)
                            end
                            if setOk then
                                if field.set then field.set(value) else S[field.key]=value end
                            else table.insert(skipped,field.key) end
                        end
                    end
                end
                restored=true
                if #skipped>0 then notice("Unavailable settings were skipped: "..table.concat(skipped,", ")) end
            end
        end
    end
    local lastSaved=capture()
    local writing=false
    local function trialRunning()
        return S.hatchPairRunning or S.hatchTuneRunning or S.hatchTraceRunning or S.hatchABRunning or S.bufferTrialRunning
    end
    function S.personalSaveSettings()
        if writing then return false,"Save already in progress" end
        if trialRunning() then return false,"Finish the active trial before saving settings" end
        writing=true
        local values=capture()
        local ok,err=pcall(function()
            if not isfolder("BGSPersonal") then makefolder("BGSPersonal") end
            local encoded=Http:JSONEncode({version=1,values=values})
            writefile(path,encoded)
            local verified=Http:JSONDecode(readfile(path))
            assert(type(verified)=="table" and verified.version==1 and
                type(verified.values)=="table" and same(values,verified.values),"Saved settings verification failed")
        end)
        writing=false
        if ok then
            lastSaved=values
            autoSave=true
            show("Auto-save ON (1s) | Saved to "..path.."\nRestored on next run. Auto open and PC cycle start manually.")
        else
            autoSave=false
            show("Save failed: "..tostring(err).."\nUse Save settings now to retry.")
        end
        return ok,err
    end
    if S.SettingsTab then
        S.SettingsTab:CreateButton({Name="Save settings now",Callback=function()
            local ok,err=S.personalSaveSettings()
            notice(ok and "Hatch and Premium settings saved." or tostring(err))
        end})
    end
    if autoSave then
        if restored then
            show("Saved preferences restored | Auto-save ON (1s)\nAuto open and PC cycle start manually.")
        else
            S.personalSaveSettings()
        end
    end
    if restored and S.teleportOnLoad then
        task.spawn(function()
            for _=1,30 do
                if S.hrp then break end
                task.wait(0.5)
            end
            local saved=S.eggPositions and S.selectedEgg and S.eggPositions[S.selectedEgg]
            if S.hrp and type(saved)=="table" then
                pcall(function() S.hrp.CFrame=CFrame.new(saved.x,saved.y,saved.z) end)
            elseif S.hrp and type(S.savedPosX)=="number" and type(S.savedPosY)=="number" and type(S.savedPosZ)=="number" then
                pcall(function() S.hrp.CFrame=CFrame.new(S.savedPosX,S.savedPosY,S.savedPosZ) end)
            end
        end)
    end
    if S.autoOpenOnLoad then
        task.spawn(function()
            task.wait(3)
            if S.autoOpenToggle and not S.eggOpenActive then
                S.autoOpenToggle:Set(true)
            end
        end)
    end
    task.spawn(function()
        while S.personalSettingsInstalled do
            task.wait(1)
            if autoSave and not trialRunning() and not same(lastSaved,capture()) then
                S.personalSaveSettings()
            end
        end
    end)
end

-- BGS Personal 1.1. Local adaptation of BGS BY YAMAHAO recovered modules.
-- Original module attribution is preserved. Modifications are in source/.
-- Includes a local Rayfield key gate. UI dependency: https://sirius.menu/rayfield
-- Run only in a fresh original BGS session; do not load the old loader first.
local existing=_G.BGS
if existing then
    if existing.personalVersion and existing.personalReady and existing.shared then
        local ok,err=pcall(installPersonalSettings,existing.shared,true)
        if not ok then warn("Remember settings: "..tostring(err)) end
    end
    local message=existing.personalVersion and
        (existing.personalReady and (existing.shared.personalSettingsStatus or "BGS Personal is already running.") or "BGS Personal is loading or failed. Rejoin before retrying.") or
        "Another BGS script is already loaded. Rejoin once, then run only BGS_Personal.lua."
    warn(message)
    if existing.shared and existing.shared.Rayfield then
        pcall(function() existing.shared.Rayfield:Notify({Title="BGS Personal",Content=message,Duration=10}) end)
    end
    return
end
assert(game.PlaceId==2512643572,"This build is for original Bubble Gum Simulator (place 2512643572).")
_G.BGS={shared={},modules={},personalVersion="1.1.0",personalReady=false}
local modules,helpers={},{}


modules["core"]=function()
-- ============ FILE: core.lua ============
-- BGS BY YAMAHAO V1.3 — Core
-- Constantes, detección de executor, persistencia, estado global, helpers.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- Cargar Rayfield PRIMERO
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local S = _G.BGS.shared
S.Rayfield = Rayfield
S.safeNotify = function(title,content,duration)
    if not S.Rayfield then return false end
    local ok=pcall(function() S.Rayfield:Notify({Title=tostring(title),Content=tostring(content),Duration=duration or 4}) end)
    return ok
end
S.createStatusToggle = function(tab, config)
    config = config or {}
    local name = tostring(config.Name or "Toggle")
    local current = config.CurrentValue == true
    local syncing = false
    local lastContent = ""
    local status = tab:CreateParagraph({
        Title = name .. " status",
        Content = "",
    })
    local toggle

    local function render(value, detail)
        local stateText = value and "🟢 Enabled" or "🔴 Disabled"
        if detail and detail ~= "" then
            stateText = stateText .. " | " .. tostring(detail)
        end
        local content = (config.Description and (tostring(config.Description) .. "\n") or "") .. stateText
        if content == lastContent then return end
        lastContent = content
        pcall(function() status:Set({Title = name .. " status", Content = content}) end)
    end

    local api = {}
    function api:Set(value, detail, invokeCallback)
        local requested = value == true
        local previous = current
        current = requested
        if toggle and toggle.Set then
            syncing = true
            pcall(function() toggle:Set(current) end)
            syncing = false
        end
        render(current, detail)
        if invokeCallback ~= false then
            local ok, result = pcall(config.Callback or function() end, requested)
            if not ok or result == false then
                current = previous
                if toggle and toggle.Set then
                    syncing = true
                    pcall(function() toggle:Set(previous) end)
                    syncing = false
                end
                render(previous, "Error - unchanged")
                if S.safeNotify then
                    S.safeNotify(name, "Failed to change state: " .. tostring(result or "callback error"), 4)
                end
                return false, result
            end
        end
        return true
    end
    function api:Get()
        return current
    end
    api.Status = status

    toggle = tab:CreateToggle({
        Name = name,
        CurrentValue = current,
        Flag = config.Flag,
        Callback = function(value)
            if syncing then return end
            local previous = current
            local requested = value == true
            if config.Disabled then
                render(previous, config.Tooltip or "Unavailable")
                if toggle and toggle.Set then api:Set(previous, config.Tooltip or "Unavailable", false) end
                return
            end
            local ok, result = pcall(config.Callback or function() end, requested)
            if not ok or result == false then
                current = previous
                if toggle and toggle.Set then api:Set(previous, "Error - unchanged", false) end
                if S.safeNotify then
                    S.safeNotify(name, "Failed to change state: " .. tostring(result or "callback error"), 4)
                end
                return
            end
            current = requested
            render(current)
            if config.Notify ~= false and S.safeNotify then
                S.safeNotify(name, current and "Enabled" or "Disabled", 2)
            end
        end,
    })
    api.Toggle = toggle
    render(current)
    return api
end

S.Services = {
    Players = Players,
    UserInputService = UserInputService,
    RunService = RunService,
    Workspace = Workspace,
    ReplicatedStorage = ReplicatedStorage,
    Lighting = Lighting,
    SoundService = SoundService,
    Stats = Stats,
    VirtualUser = VirtualUser,
    TweenService = TweenService,
    HttpService = HttpService,
}

S.player = Players.LocalPlayer

-- Personal edition uses no account entitlement service.

S.player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

------------------------------------------------------------
-- EXECUTOR CAPABILITY DETECTION (Madium-safe)
------------------------------------------------------------
S.HAS_HOOK = false
pcall(function()
    if type(getconnections) == "function" then
        if type(hookfunction) == "function" then
            S.HAS_HOOK = true
        end
    end
end)

S.HAS_HTTP = false
S.HTTP_MODE = nil
pcall(function()
    if type(request) == "function" then
        S.HAS_HTTP = true
        S.HTTP_MODE = "request"
    else
        if type(http_request) == "function" then
            S.HAS_HTTP = true
            S.HTTP_MODE = "http_request"
        else
            if type(syn) == "table" then
                if type(syn.request) == "function" then
                    S.HAS_HTTP = true
                    S.HTTP_MODE = "syn"
                end
            end
        end
    end
end)

S.HAS_FILE = false
pcall(function()
    if type(writefile) == "function" then
        if type(readfile) == "function" then
            if type(isfolder) == "function" then
                if type(makefolder) == "function" then
                    S.HAS_FILE = true
                end
            end
        end
    end
end)

function S.httpPost(url, body)
    if not S.HAS_HTTP then
        return nil
    end
    local payload = HttpService:JSONEncode(body)
    local headers = {}
    headers["Content-Type"] = "application/json"
    local ok, res = pcall(function()
        if S.HTTP_MODE == "request" then
            return request({
                Url = url,
                Method = "POST",
                Headers = headers,
                Body = payload,
            })
        end
        if S.HTTP_MODE == "http_request" then
            return http_request({
                Url = url,
                Method = "POST",
                Headers = headers,
                Body = payload,
            })
        end
        if S.HTTP_MODE == "syn" then
            return syn.request({
                Url = url,
                Method = "POST",
                Headers = headers,
                Body = payload,
            })
        end
        return nil
    end)
    if ok then
        return res
    end
    return nil
end

------------------------------------------------------------
-- PERSISTENT STORE
------------------------------------------------------------
S.SAVE_FOLDER = "BGSPersonal"
S.GLOBAL_FILE = "global"
S.CONFIG_PREFIX = "config_"
-- Shared webhook used by every client that loads this script. A small
-- shared file is also maintained so changing it in one client persists.
S.DEFAULT_WEBHOOK_URL = ""
S.SHARED_WEBHOOK_FILE = "shared_webhook"

S.GLOBAL = {
    savedPositions = {},
    customEggs = {},
    customBoxes = {},
    webhookUrl = S.DEFAULT_WEBHOOK_URL,
    webhookMinRarityOneIn = 500000,
    webhookRarityFilterVersion = 2,
    hatchStatusWebhook = true,
    inventoryWebhook = true,
    lastConfigLoaded = 1,
    selectedTheme = "DarkBlue",
}

-- Built-in egg names that should remain available even when an older
-- BGSPersonal/global.json already exists. The actual Egg instances still
-- need to exist under Workspace.Eggs before TP/opening can use them.
local DEFAULT_CUSTOM_EGGS = {
    "Skull Egg",
    "Neon Pumpkin Egg",
    "Malevolent Egg",
}

function S.safeReadFile(name)
    if not S.HAS_FILE then
        return nil
    end
    local path = S.SAVE_FOLDER .. "/" .. name .. ".json"
    local ok, data = pcall(readfile, path)
    if ok then
        if data then
            local ok2, decoded = pcall(function()
                return HttpService:JSONDecode(data)
            end)
            if ok2 then
                return decoded
            end
        end
    end
    return nil
end

function S.safeWriteFile(name, data)
    if not S.HAS_FILE then
        return
    end
    pcall(function()
        if not isfolder(S.SAVE_FOLDER) then
            makefolder(S.SAVE_FOLDER)
        end
        local path = S.SAVE_FOLDER .. "/" .. name .. ".json"
        writefile(path, HttpService:JSONEncode(data))
    end)
end

S.EGG_LIST = {}
S.BOX_LIST = {}

function S.loadGlobal()
    local data = S.safeReadFile(S.GLOBAL_FILE)
    if data then
        if data.savedPositions then S.GLOBAL.savedPositions = data.savedPositions end
        if type(data.customEggs) == "table" then S.GLOBAL.customEggs = data.customEggs end
        if data.customBoxes then S.GLOBAL.customBoxes = data.customBoxes end
        if data.webhookUrl then S.GLOBAL.webhookUrl = data.webhookUrl end
        if data.webhookMinRarityOneIn ~= nil then
            local rarity = tonumber(data.webhookMinRarityOneIn)
            local filterVersion = tonumber(data.webhookRarityFilterVersion) or 1
            -- Migrate the previous default (1 in 100,000) to the new
            -- requested default (1 in 500,000) once.
            if filterVersion < 2 and rarity == 100000 then
                rarity = 500000
            end
            if rarity and rarity >= 0 then S.GLOBAL.webhookMinRarityOneIn = rarity end
        end
        S.GLOBAL.webhookRarityFilterVersion = 2
        if data.hatchStatusWebhook ~= nil then S.GLOBAL.hatchStatusWebhook = data.hatchStatusWebhook end
        if data.inventoryWebhook ~= nil then S.GLOBAL.inventoryWebhook = data.inventoryWebhook end
        if data.lastConfigLoaded then S.GLOBAL.lastConfigLoaded = data.lastConfigLoaded end
        if data.selectedTheme then S.GLOBAL.selectedTheme = data.selectedTheme end
    end
    for _, egg in ipairs(DEFAULT_CUSTOM_EGGS) do
        local found = false
        for _, v in ipairs(S.GLOBAL.customEggs) do
            if v == egg then
                found = true
                break
            end
        end
        if not found then
            table.insert(S.GLOBAL.customEggs, egg)
        end
    end
    for _, egg in ipairs(S.GLOBAL.customEggs) do
        local found = false
        for _, v in ipairs(S.EGG_LIST) do
            if v == egg then
                found = true
                break
            end
        end
        if not found then
            table.insert(S.EGG_LIST, egg)
        end
    end
    for _, box in ipairs(S.GLOBAL.customBoxes) do
        local found = false
        for _, v in ipairs(S.BOX_LIST) do
            if v == box then
                found = true
                break
            end
        end
        if not found then
            table.insert(S.BOX_LIST, box)
        end
    end
    table.sort(S.EGG_LIST)
    table.sort(S.BOX_LIST)
end

function S.saveGlobal()
    S.safeWriteFile(S.GLOBAL_FILE, S.GLOBAL)
end

function S.loadSharedWebhook()
    local data = S.safeReadFile(S.SHARED_WEBHOOK_FILE)
    local sharedUrl = type(data) == "table" and tostring(data.webhookUrl or "") or ""
    if sharedUrl ~= "" then
        S.GLOBAL.webhookUrl = sharedUrl
        return
    end

    -- Seed the shared file so all clients using the same executor storage
    -- converge on the same URL without requiring per-client setup.
    S.GLOBAL.webhookUrl = S.DEFAULT_WEBHOOK_URL
    S.safeWriteFile(S.SHARED_WEBHOOK_FILE, { webhookUrl = S.GLOBAL.webhookUrl })
end

S.loadGlobal()
S.loadSharedWebhook()

------------------------------------------------------------
-- STATE
------------------------------------------------------------
S.PICKUPS_FOLDER = Workspace:WaitForChild("Pickups")
S.RADIUS = 25
S.MODE = "LEGIT"
S.WALK_SPEED = 16
S.TRAVEL_SPEED = 40
S.REACH_DIST = 4
S.COLLECT_ALL = false
S.farmActive = false
S.farmConnection = nil
S.busy = false
S.hrp = nil
S.humanoid = nil
S.isTeleporting = false
S.currentTween = nil

function S.cancelMovement()
    if S.currentTween then
        pcall(function() S.currentTween:Cancel() end)
    end
    if S.humanoid then
        if S.hrp then
            pcall(function() S.humanoid:MoveTo(S.hrp.Position) end)
        end
    end
end

------------------------------------------------------------
-- SHARD QUEST STATE
------------------------------------------------------------
S.QUEST_BOARD_POS = Vector3.new(-1725.02, 1855.20, 11034.76)
S.shardQuestActive = false
S.shardQuestStatus = "Idle"
S.shardQuestTaskName = "None"
S.shardQuestPercent = 0
S.questEggMode = "default"

S.SHARD_QUEST_TYPES = {
    [3000] = "Open Eggs",
    [5000] = "Open Eggs",
    [25] = "Open Legendaries",
    [1000000000] = "Blow Bubbles",
    [30000000000] = "Collect Gems",
    [10000000000] = "Collect Other Currency",
}

S.shardProgressGui = nil

S.EGG_QUEST_POS = Vector3.new(-55.5611, 45.6686, -102.9039)
S.EGG_QUEST_NAME = "Spikey Egg"

S.HEAVEN_POS = Vector3.new(7804.4868, 100.8863, -13921.1367)
S.HEAVEN_SELL_ID = "HeavenSell"

S.GEMS_FARM_POS = Vector3.new(112.1412, 40698.7891, -324.9834)
S.GEMS_FARM_DRIFT_LIMIT = 200
S.gemsQuestSetupDone = false
S.savedFarmConfigBeforeGems = nil

S.VOID_CHEST_POS = Vector3.new(71.27, 32140.09, -321.91)
S.VOID_CHEST_ISLAND_NAME = "The Void"
S.VOID_CHEST_COOLDOWN = 90 * 60

S.GODLY_CHEST_POS = Vector3.new(93.06, 21107.09, -298.78)
S.GODLY_CHEST_ISLAND_NAME = "The Skylands"
S.GODLY_CHEST_COOLDOWN = 45 * 60

S.lastVoidChestAttempt = 0
S.lastGodlyChestAttempt = 0
S.GEMS_CHEST_RETRY_INTERVAL = 60
S.lastGemsChestRetry = 0

S.CURRENCY_CHEST_TARGETS = {
    { pos = Vector3.new(-649.5840, 40938.7695, -3039.5825), label = "Sweet Chest" },
    { pos = Vector3.new(-219.5600, 38638.7695, -5347.2261), label = "Treasure Chest" },
    { pos = Vector3.new(352.8373, 40959.0547, -8554.0605), label = "Sea Chest" },
    { pos = Vector3.new(353.0350, 40959.0508, -12963.5254), label = "Sandy Chest" },
    { pos = Vector3.new(1340.2560, 40959.0664, -17912.2988), label = "Purple Chest" },
    { pos = Vector3.new(2267.3499, 40958.9922, -20119.0898), label = "Molten Chest" },
    { pos = Vector3.new(4762.8052, 40959.0039, -16102.6504), label = "Magic Chest" },
}
S.currencyChestIndex = 1

S.selectedEgg = nil
S.eggPositions = {}
S.chestReturnToEgg = true
S.multiEgg = true
S.eggOpenActive = false
S.eggInterval = 0.025
S.autoOpenOnLoad = true
S.teleportOnLoad = true

S.selectedBox = nil
S.boxMulti = true
S.boxOpenActive = false
S.boxInterval = 0.5

S.NetworkRemoteEvent = assert(ReplicatedStorage:WaitForChild("NetworkRemoteEvent", 20), "Game NetworkRemoteEvent not available")
S.NetworkRemoteFunction = ReplicatedStorage:FindFirstChild("NetworkRemoteFunction")

S.BUBBLE_SELL_POS = Vector3.new(-158.269744873046875, 45.3501091003418, -147.18032836914062)
S.bubbleAutoSellActive = false
S.bubbleSelling = false
S.bubbleSellIntervalActive = false
S.bubbleSellInterval = 30
S.blowActive = false
S.blowInterval = 0.1

S.SELL_ZONES = {
    ["Base (x1)"] = { pos = S.BUBBLE_SELL_POS, sellId = "Sell" },
    ["Heaven (x9)"] = { pos = S.HEAVEN_POS, sellId = S.HEAVEN_SELL_ID },
}
S.selectedSellZone = "Base (x1)"

S.opt = {
    lowQuality = false,
    noParticles = false,
    noLightingFx = false,
    noShadows = false,
    muteAudio = false,
    noTerrainDecoration = false,
    noSky = false,
    noReflections = false,
    hideOtherTags = false,
    tightStreaming = false,
    fullOptimization = false,
}
S.originalQualityLevel = nil
S.disabledParticleInstances = {}
S.eggAnimationSuppressed = false
S.eggAnimationDisabledInstances = {}
S.eggAnimationConnections = {}
S.eggAnimationAnimatorSeen = {}
S.eggAnimationAssetBackups = {}
S.eggAnimationSuppressedIds = {}
S.eggAnimationBackupFolder = nil
S.eggAnimationCharacterConnection = nil
S.blackScreenOnLoad = false
S.blackScreenGui = nil
S.noclipActive = false
S.noclipConnection = nil
S.infiniteJumpActive = false
S.infiniteJumpConnection = nil
S.debugWalkSpeed = 16
S.debugJumpPower = 50
S.statsTabVisible = true

S.wheelActive = false
S.wheelIntervalHours = 1
S.wheelSpinDuration = 3.5
S.WHEEL_POS = Vector3.new(-1.9941, 45.6261, 32.0944)

S.sessionStartEggs = nil
S.sessionLegendaries = 0

-- UI elements (se llenan desde ui.lua y demás)
S.Window = nil
S.FarmTab = nil
S.HatchTab = nil
S.BubbleTab = nil
S.ClientTab = nil
S.CodeTab = nil
S.PremiumTab = nil
S.SettingsTab = nil
S.eggDropdownElement = nil
S.boxDropdownElement = nil
S.farmToggleElement = nil
S.shardToggleElement = nil
S.noclipToggleElement = nil
S.savedPosDropdown = nil
S.currentPosName = nil
S.currentConfigSlot = S.GLOBAL.lastConfigLoaded or 1

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
function S.readLeaderstat(name)
    local ls = S.player:FindFirstChild("leaderstats")
    if not ls then
        return nil
    end
    local v = ls:FindFirstChild(name)
    if not v then
        return nil
    end
    if v:IsA("IntValue") then
        return tonumber(v.Value)
    end
    if v:IsA("NumberValue") then
        return tonumber(v.Value)
    end
    if v:IsA("StringValue") then
        return tonumber((v.Value or ""):gsub(",", ""))
    end
    return nil
end

function S.createTextBox(tab, params)
    if tab.CreateTextBox then
        return tab:CreateTextBox(params)
    end
    if tab.CreateInput then
        return tab:CreateInput({
            Name = params.Name,
            PlaceholderText = params.PlaceholderText or "",
            RemoveTextAfterFocusLost = params.RemoveTextAfterFocusLost,
            Callback = params.Callback,
            Flag = params.Flag,
        })
    end
    return nil
end

function S.bindCharacter(newChar)
    S.hrp = newChar:WaitForChild("HumanoidRootPart")
    S.humanoid = newChar:WaitForChild("Humanoid")
    S.humanoid.WalkSpeed = S.debugWalkSpeed
    S.humanoid.UseJumpPower = true
    S.humanoid.JumpPower = S.debugJumpPower
    if S.noclipActive then
        for _, part in ipairs(newChar:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end

if S.player.Character then
    task.spawn(S.bindCharacter, S.player.Character)
end
S.player.CharacterAdded:Connect(function(newChar)
    task.spawn(S.bindCharacter, newChar)
end)

------------------------------------------------------------
-- LOCAL STOP CONTROLS
function S.stopAllFeatures()
    if S.setAutoOpen then S.setAutoOpen(false) end
    if S.hatchPairStop then pcall(S.hatchPairStop) end
    -- Detener farm
    S.farmActive = false
    if S.farmConnection then
        pcall(function() S.farmConnection:Disconnect() end)
        S.farmConnection = nil
    end
    -- Detener auto-blow
    S.blowActive = false
    -- Detener auto-sell
    S.bubbleAutoSellActive = false
    S.bubbleSellIntervalActive = false
    -- Detener auto-egg
    S.eggOpenActive = false
    -- Detener auto-box
    S.boxOpenActive = false
    -- Detener shard quest
    S.shardQuestActive = false
    -- Detener wheel
    S.wheelActive = false
    -- Restaurar velocidad
    if S.humanoid then
        pcall(function() S.humanoid.WalkSpeed = 16 end)
    end
end

_G.BGS.modules.core = true
print("[BGS] core loaded")
-- ============ END: core.lua ============
end


modules["ui"]=function()
-- ============ FILE: ui.lua ============
-- BGS BY YAMAHAO V2.0— UI
-- Ventana Rayfield, tabs, tema.

local S = _G.BGS.shared
local Rayfield = S.Rayfield

local Window = Rayfield:CreateWindow({
    Name = "BGS Personal",
    LoadingTitle = "BGS Personal",
    LoadingSubtitle = "Farm - Hatch - Bubbles - Client",
    ConfigurationSaving = { Enabled = false, FolderName = "BGSPersonal", FileName = "config" },
    Discord = { Enabled = false },
    KeySystem = true,
    KeySettings = {
        Title = "BGS Personal Friend",
        Subtitle = "Access key required",
        Note = "Enter the access key to continue.",
        FileName = "BGSFriendKey",
        SaveKey = false,
        GrabKeyFromSite = false,
        Key = {"BBG-FRIEND-2026"},
    },
})

pcall(function()
    if Rayfield.SetTheme then
        Rayfield:SetTheme(S.GLOBAL.selectedTheme or "DarkBlue")
    end
end)

S.Window = Window
S.FarmTab = Window:CreateTab("Farm")
S.HatchTab = Window:CreateTab("Hatch")
S.BubbleTab = Window:CreateTab("Bubbles")
S.ClientTab = Window:CreateTab("Client")
S.CodeTab = Window:CreateTab("Codes")
S.PremiumTab = Window:CreateTab("⭐ Premium")
S.SettingsTab = Window:CreateTab("Settings")

_G.BGS.modules.ui = true
print("[BGS] ui loaded")
-- ============ END: ui.lua ============
end


modules["farm"]=function()
-- ============ FILE: farm.lua ============
-- BGS BY YAMAHAO V1.4 — Farm
-- Farm + Shard Quest + Chests + Wheel + Overworld Unlock.

local S = _G.BGS.shared
local Rayfield = S.Rayfield

local Players = S.Services.Players
local UserInputService = S.Services.UserInputService
local RunService = S.Services.RunService
local Workspace = S.Services.Workspace
local ReplicatedStorage = S.Services.ReplicatedStorage
local TweenService = S.Services.TweenService

local player = S.player
local FarmTab = S.FarmTab

------------------------------------------------------------
-- FARM UI
------------------------------------------------------------
FarmTab:CreateSection("Farming")

S.farmToggleElement = FarmTab:CreateToggle({
    Name = "Enable farm",
    CurrentValue = false,
    Flag = "FarmActive",
    Callback = function(state)
        S.farmActive = state
        if S.farmActive then
            S.farmConnection = RunService.Heartbeat:Connect(function()
                collectNearby()
            end)
        else
            if S.farmConnection then
                S.farmConnection:Disconnect()
            end
        end
    end,
})

FarmTab:CreateKeybind({
    Name = "Toggle farm keybind",
    CurrentKeybind = "F",
    HoldToInteract = false,
    Flag = "FarmKeybind",
    Callback = function()
        S.farmToggleElement:Set(not S.farmActive)
    end,
})

FarmTab:CreateDropdown({
    Name = "Movement mode",
    Options = {"LEGIT (walk)", "FAST (tween)"},
    CurrentOption = {"LEGIT (walk)"},
    Flag = "FarmMode",
    Callback = function(option)
        if option[1] == "FAST (tween)" then
            S.MODE = "RAPIDO"
        else
            S.MODE = "LEGIT"
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Detection radius",
    Range = {5, 150},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 25,
    Flag = "FarmRadius",
    Callback = function(v) S.RADIUS = v end,
})

FarmTab:CreateSlider({
    Name = "Walk speed",
    Range = {16, 100},
    Increment = 1,
    Suffix = "",
    CurrentValue = 16,
    Flag = "FarmWalkSpeed",
    Callback = function(v)
        S.WALK_SPEED = v
        S.debugWalkSpeed = v
        if S.humanoid then S.humanoid.WalkSpeed = v end
    end,
})

FarmTab:CreateSlider({
    Name = "Travel speed",
    Range = {10, 200},
    Increment = 5,
    Suffix = " studs/s",
    CurrentValue = 40,
    Flag = "FarmTravelSpeed",
    Callback = function(v) S.TRAVEL_SPEED = v end,
})

FarmTab:CreateSlider({
    Name = "Collection distance",
    Range = {1, 10},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 4,
    Flag = "FarmReachDist",
    Callback = function(v) S.REACH_DIST = v end,
})

FarmTab:CreateToggle({
    Name = "Collect all in range",
    CurrentValue = false,
    Flag = "FarmCollectAll",
    Callback = function(v) S.COLLECT_ALL = v end,
})

------------------------------------------------------------
-- SHARD QUEST UI
------------------------------------------------------------
FarmTab:CreateSection("Shard Quest")

S.shardToggleElement = FarmTab:CreateToggle({
    Name = "Auto shard quest",
    CurrentValue = false,
    Flag = "ShardQuestActive",
    Callback = function(state)
        S.shardQuestActive = state
        if state then
            if S.shardProgressGui then
                S.shardProgressGui.Enabled = true
            end
        else
            if S.gemsQuestSetupDone then
                restoreFarmConfigAfterGems()
            end
        end
    end,
})

FarmTab:CreateDropdown({
    Name = "Egg used for quest",
    Options = {"Default egg (Spikey)", "Egg selected in Hatch"},
    CurrentOption = {"Default egg (Spikey)"},
    Flag = "ShardQuestEggMode",
    Callback = function(option)
        if option[1] == "Egg selected in Hatch" then
            S.questEggMode = "selected"
        else
            S.questEggMode = "default"
        end
    end,
})

FarmTab:CreateButton({
    Name = "Show / hide quest progress window",
    Callback = function()
        if S.shardProgressGui then
            S.shardProgressGui.Enabled = not S.shardProgressGui.Enabled
        end
    end,
})

------------------------------------------------------------
-- SECRET BOUNTY EGG SCANNER (for an owned Studio game)
------------------------------------------------------------
S.PremiumTab:CreateSection("Auto Secret Bounty")

local CollectionService = game:GetService("CollectionService")
local bountyEggStates = {}
local bountyEggTarget = nil
local bountyEggLabelName = nil
local bountyScanConnections = {}
local bountyScannerRunning = false
local bountyScanQueued = false
local bountyLastTeleport = 0
local bountyTeleportStopped = false
local BOUNTY_TAG = "SecretBountyEgg"
local BOUNTY_TAG_ALIASES = {"SecretBountyEgg", "BountyEgg"}
local BOUNTY_RESCAN_SECONDS = 3
local BOUNTY_STALE_SECONDS = 8
local BOUNTY_MAX_TELEPORT_AGE = 8
local BOUNTY_TELEPORT_COOLDOWN = 2
local bountyStatusParagraph = S.PremiumTab:CreateParagraph({
    Title = "Bounty status",
    Content = "Auto scan disabled. Use Scan Secret Bounty Egg to scan once.",
})

local function bountyLog(level, message, data)
    -- Never include credentials, webhook URLs, or personal data in bounty logs.
    if level == "ERROR" or level == "WARNING" then
        warn(string.format("[Bounty][%s] %s", tostring(level), tostring(message)))
    elseif level == "INFO" and data and data.count then
        print(string.format("[Bounty][INFO] %s: %s target(s)", tostring(message), tostring(data.count)))
    end
end

local function bountyNormalize(value)
    if type(value) ~= "string" then return "" end
    return value:lower():gsub("[%s%p_]+", "")
end

local function bountyFiniteVector(value)
    return typeof(value) == "Vector3"
        and value.X == value.X and value.Y == value.Y and value.Z == value.Z
        and math.abs(value.X) < 10000000 and math.abs(value.Y) < 10000000 and math.abs(value.Z) < 10000000
end

local function bountyNow()
    local ok, serverNow = pcall(function() return Workspace:GetServerTimeNow() end)
    return ok and type(serverNow) == "number" and serverNow or os.clock()
end

local function bountyInWorkspace(instance)
    return instance and instance:IsDescendantOf(Workspace)
end

local function bountyHasTag(instance)
    for _, tagName in ipairs(BOUNTY_TAG_ALIASES) do
        if CollectionService:HasTag(instance, tagName) then return true end
    end
    return false
end

local function bountyPivot(egg)
    if not egg or not bountyInWorkspace(egg) then return nil end
    if egg:IsA("Model") then return egg:GetPivot() end
    if egg:IsA("BasePart") then return egg.CFrame end
    return nil
end

local function bountyReadActive(egg)
    local value = egg:GetAttribute("BountyActive")
    if value ~= nil then return value == true end
    local flag = egg:FindFirstChild("BountyActive")
    return not flag or not flag:IsA("BoolValue") or flag.Value == true
end

local function bountyReadState(egg)
    if not bountyInWorkspace(egg) then return nil end
    local pivot = bountyPivot(egg)
    local endsAt = tonumber(egg:GetAttribute("BountyEndsAt"))
    local startsAt = tonumber(egg:GetAttribute("BountyStartsAt"))
    local active = bountyReadActive(egg)
    if not active or not pivot or not bountyFiniteVector(pivot.Position) then return nil end
    if endsAt and endsAt <= bountyNow() then return nil end

    local source, confidence = "Instance", "low"
    if bountyHasTag(egg) then
        source, confidence = "CollectionService", "high"
    elseif egg:GetAttribute("BountyActive") ~= nil or endsAt or egg:GetAttribute("DisplayName") then
        source, confidence = "Attributes", "medium"
    end
    local id = tostring(egg:GetAttribute("BountyId") or egg:GetAttribute("BountyID") or bountyNormalize(egg.Name))
    return {
        bountyId=id, eggName=egg.Name, displayName=tostring(egg:GetAttribute("DisplayName") or egg.Name),
        instance=egg, position=pivot.Position, isActive=true, startsAt=startsAt, endsAt=endsAt,
        source=source, confidence=confidence, lastSeen=bountyNow(), isStale=false,
    }
end

local function bountyPublish()
    local count = 0
    local lines = {}
    for _, state in pairs(bountyEggStates) do
        if state.isActive and not state.isStale then
            count += 1
            local distance = "Unknown"
            if S.hrp and bountyFiniteVector(state.position) then
                distance = tostring(math.floor((S.hrp.Position - state.position).Magnitude)) .. " studs"
            end
            local remaining = state.endsAt and tostring(math.max(0, math.floor(state.endsAt - bountyNow()))) .. "s" or "Unknown"
            table.insert(lines, string.format("%s | %s | %s | %s | %s", state.displayName, distance, remaining, state.source, state.confidence))
        end
    end
    table.sort(lines)
    if bountyStatusParagraph then
        bountyStatusParagraph:Set({Title="Bounty status (name | distance | time | source | confidence)", Content=#lines > 0 and table.concat(lines, "\n") or "No active bounty target. Latest scan found none."})
    end
    bountyLog("INFO", "scan complete", {count=count})
end

local function queueBountyRescan(instance)
    if not bountyScannerRunning then return end
    if bountyScanQueued then return end
    bountyScanQueued = true
    task.defer(function()
        bountyScanQueued = false
        if not bountyScannerRunning then return end
        if instance and bountyInWorkspace(instance) then
            local state = bountyReadState(instance)
            if state then bountyEggStates[state.bountyId] = state
            else
                for id, old in pairs(bountyEggStates) do if old.instance == instance then bountyEggStates[id] = nil end end
            end
        end
        bountyPublish()
    end)
end

local function getEggNameCandidates()
    local names = {}
    local seen = {}
    local eggsFolder = Workspace:FindFirstChild("Eggs")
    if eggsFolder then
        for _, egg in ipairs(eggsFolder:GetChildren()) do
            if (egg:IsA("Model") or egg:IsA("BasePart")) and not seen[egg.Name] then
                seen[egg.Name] = true
                table.insert(names, egg.Name)
            end
        end
    end
    for _, eggName in ipairs(S.EGG_LIST or {}) do
        if type(eggName) == "string" and not seen[eggName] then
            seen[eggName] = true
            table.insert(names, eggName)
        end
    end
    table.sort(names, function(a, b) return #a > #b end)
    return names
end

local function readBountyEggNameFromLabels()
    local roots = {S.player:FindFirstChildOfClass("PlayerGui"), Workspace}
    local names = getEggNameCandidates()
    for _, root in ipairs(roots) do
        if root then
            for _, inst in ipairs(root:GetDescendants()) do
                if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
                    local text = tostring(inst.Text or "")
                    local lower = text:lower()
                    local looksLikeBountyLine = lower:find("bounty", 1, true) or
                        (lower:find("hatchable", 1, true) and lower:find("egg", 1, true))
                    if looksLikeBountyLine then
                        for _, eggName in ipairs(names) do
                            if bountyNormalize(lower):find(bountyNormalize(eggName), 1, true) then
                                return eggName, text
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function findEggByName(eggName)
    local eggsFolder = Workspace:FindFirstChild("Eggs")
    if type(eggName) ~= "string" then return nil end
    local exact = eggsFolder and eggsFolder:FindFirstChild(eggName)
    if exact and (exact:IsA("Model") or exact:IsA("BasePart")) then return exact end
    local wanted = bountyNormalize(eggName)
    if eggsFolder then
        for _, egg in ipairs(eggsFolder:GetChildren()) do
            if bountyNormalize(egg.Name) == wanted and (egg:IsA("Model") or egg:IsA("BasePart")) then
                return egg
            end
        end
    end
    for _, egg in ipairs(Workspace:GetDescendants()) do
        if bountyNormalize(egg.Name) == wanted and (egg:IsA("Model") or egg:IsA("BasePart")) then
            return egg
        end
    end
    return nil
end

local function scanSecretBountyEgg()
    local now = bountyNow()
    local candidates = {}
    local inspected = {}
    for _, egg in ipairs(Workspace:GetDescendants()) do
        if not inspected[egg] and (bountyHasTag(egg)
            or egg:GetAttribute("BountyActive") ~= nil
            or egg:GetAttribute("BountyEndsAt") ~= nil
            or egg:GetAttribute("BountyId") ~= nil) then
            inspected[egg] = true
            local state = bountyReadState(egg)
            if state then bountyEggStates[state.bountyId] = state; table.insert(candidates, state) end
        end
    end
    for id, state in pairs(bountyEggStates) do
        if not bountyInWorkspace(state.instance) or (state.endsAt and state.endsAt <= now) or now - state.lastSeen > BOUNTY_STALE_SECONDS then
            bountyEggStates[id] = nil
        end
    end
    table.sort(candidates, function(a, b)
        local rank = {high=3, medium=2, low=1}
        return (rank[a.confidence] or 0) > (rank[b.confidence] or 0)
    end)
    local selected = candidates[1]
    if not selected then
        local labelName = readBountyEggNameFromLabels()
        local matchingEgg = findEggByName(labelName)
        local state = matchingEgg and bountyReadState(matchingEgg)
        if state then
            state.source, state.confidence = "Label", "low"
            bountyEggStates[state.bountyId] = state
            selected = state
            bountyEggLabelName = labelName
        end
    end
    bountyEggTarget = selected and selected.instance or nil
    bountyPublish()
    return bountyEggTarget
end

local function startBountyScanner()
    if bountyScannerRunning then return end
    bountyScannerRunning = true
    for _, connection in ipairs(bountyScanConnections) do connection:Disconnect() end
    table.clear(bountyScanConnections)
    table.insert(bountyScanConnections, Workspace.DescendantAdded:Connect(queueBountyRescan))
    table.insert(bountyScanConnections, Workspace.DescendantRemoving:Connect(function(instance)
        for id, state in pairs(bountyEggStates) do if state.instance == instance then bountyEggStates[id] = nil end end
        bountyPublish()
    end))
    for _, attribute in ipairs({"BountyActive", "BountyEndsAt", "BountyStartsAt", "DisplayName", "BountyId", "BountyID"}) do
        table.insert(bountyScanConnections, Workspace.DescendantAdded:Connect(function(instance)
            instance:GetAttributeChangedSignal(attribute):Connect(function() queueBountyRescan(instance) end)
        end))
    end
    task.spawn(function()
        while bountyScannerRunning do
            task.wait(BOUNTY_RESCAN_SECONDS)
            if bountyScannerRunning then scanSecretBountyEgg() end
        end
    end)
    if bountyScannerRunning then scanSecretBountyEgg() end
end

local function stopBountyScanner()
    bountyScannerRunning = false
    for _, connection in ipairs(bountyScanConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(bountyScanConnections)
end

local function bountyTargetInstance(target)
    return target and target.instance or target
end

function getBountyMachineBounds(target)
    local instance = bountyTargetInstance(target)
    if not instance or not bountyInWorkspace(instance) then return nil, "TargetNotInWorkspace" end
    if instance:IsA("Model") then
        local boxCFrame, boxSize = instance:GetBoundingBox()
        return {cframe=boxCFrame, size=boxSize, instance=instance}
    elseif instance:IsA("BasePart") then
        return {cframe=instance.CFrame, size=instance.Size, instance=instance}
    end
    return nil, "TargetNotModelOrBasePart"
end

function isPositionInsideAllowedMap(position)
    if not bountyFiniteVector(position) then return false end
    -- Optional owner-controlled bounds: Workspace attributes AllowedMapMin/Max as Vector3.
    local minBound = Workspace:GetAttribute("AllowedMapMin")
    local maxBound = Workspace:GetAttribute("AllowedMapMax")
    if typeof(minBound) == "Vector3" and typeof(maxBound) == "Vector3" then
        if position.X < minBound.X or position.Y < minBound.Y or position.Z < minBound.Z
            or position.X > maxBound.X or position.Y > maxBound.Y or position.Z > maxBound.Z then
            return false
        end
    elseif position.Y < -500 then
        return false
    end
    return true
end

local function bountyIsDangerousPart(part)
    local name = part and part.Name:lower() or ""
    return part:GetAttribute("KillPart") == true
        or part:GetAttribute("Dangerous") == true
        or name:find("kill", 1, true) ~= nil
        or name:find("lava", 1, true) ~= nil
        or name:find("void", 1, true) ~= nil
        or name:find("water", 1, true) ~= nil
end

local function bountyIsAllowedSupport(part, targetInstance)
    if not part or not part:IsA("BasePart") or bountyIsDangerousPart(part) then return false end
    if targetInstance and part:IsDescendantOf(targetInstance) then return true end
    return part:GetAttribute("BountyLandingPlatform") == true or part:GetAttribute("TeleportSupport") == true
end

function calculateTopSurfacePosition(target)
    local bounds, reason = getBountyMachineBounds(target)
    if not bounds then return nil, reason end
    local topLocal = Vector3.new(0, bounds.size.Y / 2, 0)
    local topWorld = bounds.cframe:PointToWorldSpace(topLocal)
    if not isPositionInsideAllowedMap(topWorld) then return nil, "OutsideAllowedMap" end
    return topWorld, "Center"
end

local function bountyCandidateOffsets(size)
    local insetX, insetZ = math.max(0.5, size.X * 0.22), math.max(0.5, size.Z * 0.22)
    return {
        {v=Vector3.zero, label="Center"},
        {v=Vector3.new(0, 0, -insetZ), label="Front"},
        {v=Vector3.new(0, 0, insetZ), label="Back"},
        {v=Vector3.new(-insetX, 0, 0), label="Left"},
        {v=Vector3.new(insetX, 0, 0), label="Right"},
        {v=Vector3.new(-insetX, 0, -insetZ), label="Grid"},
        {v=Vector3.new(insetX, 0, -insetZ), label="Grid"},
        {v=Vector3.new(-insetX, 0, insetZ), label="Grid"},
        {v=Vector3.new(insetX, 0, insetZ), label="Grid"},
    }
end

function isSafeLandingPosition(position, target)
    local instance = bountyTargetInstance(target)
    local character = S.player and S.player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not instance or not bountyInWorkspace(instance) then return false, "TargetNotInWorkspace" end
    if not humanoid or humanoid.Health <= 0 then return false, "CharacterNotReady" end
    if not isPositionInsideAllowedMap(position) then return false, "OutsideAllowedMap" end

    local halfHeight = math.max(2, humanoid.HipHeight + 1.5)
    local root = character:FindFirstChild("HumanoidRootPart")
    local rootSize = root and root.Size or Vector3.new(2, 2, 1)
    local castParams = RaycastParams.new()
    castParams.FilterType = Enum.RaycastFilterType.Include
    castParams.FilterDescendantsInstances = {instance}
    local surfaceHit = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -16, 0), castParams)
    if not surfaceHit or not bountyIsAllowedSupport(surfaceHit.Instance, instance) then
        return false, "NoAllowedTopSurface"
    end
    local landing = surfaceHit.Position + Vector3.new(0, halfHeight, 0)
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {character, instance}
    local occupied = Workspace:GetPartBoundsInBox(CFrame.new(landing), Vector3.new(rootSize.X + 0.25, halfHeight * 2, rootSize.Z + 0.25), overlapParams)
    for _, part in ipairs(occupied) do
        if part.CanCollide or bountyIsDangerousPart(part) then return false, "ObstructedOrDangerous" end
    end
    local floorParams = RaycastParams.new()
    floorParams.FilterType = Enum.RaycastFilterType.Exclude
    floorParams.FilterDescendantsInstances = {character}
    local floorHit = Workspace:Raycast(landing + Vector3.new(0, 2, 0), Vector3.new(0, -(halfHeight + 4), 0), floorParams)
    if not floorHit or not bountyIsAllowedSupport(floorHit.Instance, instance) then return false, "NoFloorSupport" end
    return true, "Safe"
end

function findBestLandingPosition(target)
    local bounds, reason = getBountyMachineBounds(target)
    if not bounds then return nil, reason end
    local top, topReason = calculateTopSurfacePosition(target)
    local candidates = bountyCandidateOffsets(bounds.size)
    local best, bestLabel, bestDistance
    for index, candidate in ipairs(candidates) do
        if index > 9 then break end
        local localPoint = Vector3.new(candidate.v.X, bounds.size.Y / 2 + 0.25, candidate.v.Z)
        local worldPoint = bounds.cframe:PointToWorldSpace(localPoint)
        local safe, safeReason = isSafeLandingPosition(worldPoint, target)
        if safe then
            local distance = candidate.v.Magnitude
            if not best or distance < bestDistance then
                best, bestLabel, bestDistance = worldPoint, candidate.label, distance
            end
        end
    end
    if best then return best, bestLabel end
    return nil, "NoSafeLandingPosition"
end

function verifyTeleportResult(target, position)
    local instance = bountyTargetInstance(target)
    local character = S.player and S.player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return false, "CharacterNotReady" end
    if not instance or not bountyInWorkspace(instance) then return false, "TargetRemoved" end
    if not isPositionInsideAllowedMap(root.Position) then return false, "OutsideAllowedMap" end
    if (root.Position - position).Magnitude > 8 then return false, "PositionMismatch" end
    local safe, reason = isSafeLandingPosition(root.Position - Vector3.new(0, humanoid.HipHeight + 1.5, 0), target)
    if not safe then return false, reason end
    if root.AssemblyLinearVelocity.Y < -35 then return false, "FallingTooFast" end
    return true, "Verified"
end

local function teleportToBounty(state, allowLowConfidence)
    if not state then return false, "NoTarget" end
    if os.clock() - bountyLastTeleport < BOUNTY_TELEPORT_COOLDOWN then return false, "Cooldown" end
    local character = S.player and S.player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or humanoid.Health <= 0 or not root then return false, "CharacterNotReady" end
    if not state.instance or not bountyInWorkspace(state.instance) or not state.isActive then return false, "TargetInvalid" end
    if state.isStale or bountyNow() - state.lastSeen > BOUNTY_MAX_TELEPORT_AGE then return false, "TargetStale" end
    if state.endsAt and state.endsAt <= bountyNow() then return false, "Expired" end
    if state.confidence == "low" and not allowLowConfidence then return false, "LowConfidenceConfirmationRequired" end
    local position, pointLabel = findBestLandingPosition(state)
    if not position then return false, pointLabel end
    captureAutoBountySafePivot(character:GetPivot())
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    bountyLastTeleport = os.clock()
    for attempt = 1, 2 do
        if bountyTeleportStopped then return false, "Stopped" end
        if not state.instance:IsDescendantOf(Workspace) or S.player.Character ~= character or humanoid.Health <= 0 then return false, "TargetOrCharacterChanged" end
        local ok = pcall(function()
            character:PivotTo(CFrame.new(position, position + Vector3.new(0, 0, -1)))
        end)
        if ok then
            task.wait(0.12)
            local verified, verifyReason = verifyTeleportResult(state, position)
            if verified then
                bountyLog("INFO", "teleport verified", {point=pointLabel, confidence=state.confidence})
                return true, pointLabel
            end
            if attempt == 2 then return false, verifyReason end
        else
            if attempt == 2 then return false, "PivotToFailed" end
        end
        task.wait(0.2 * attempt)
        position, pointLabel = findBestLandingPosition(state)
        if not position then return false, "FallbackUnavailable" end
    end
    return false, "VerificationFailed"
end

function teleportToVerifiedBounty(target)
    bountyTeleportStopped = false
    local state = target
    if target and target.instance == nil then
        for _, candidate in pairs(bountyEggStates) do
            if candidate.instance == target then state = candidate break end
        end
    end
    if bountyTeleportStopped then return false, "Stopped" end
    return teleportToBounty(state, false)
end

local function getCurrentBountyState()
    local egg = bountyEggTarget or scanSecretBountyEgg()
    if not egg then return nil, "NoTarget" end
    for _, state in pairs(bountyEggStates) do
        if state.instance == egg then return state end
    end
    return nil, "TargetStateUnavailable"
end

-- Auto Secret Bounty state machine.
-- Owner-game server contract:
-- ReplicatedStorage.SecretBountyRemote must be a RemoteFunction (preferred) or
-- RemoteEvent. The server must validate every request and return {ok=true,...}
-- for RemoteFunction calls. The existing generic NetworkRemoteEvent is never
-- guessed or reused for this feature.
local autoBountyState = "IDLE"
local autoBountyEnabled = false
local autoBountyScanEnabled = false
local autoBountyTeleportEnabled = true
local autoBountyOpenEnabled = true
local autoBountyMaxTeleportDistance = 1000000
local autoBountyOpenCooldown = 0.025
local autoBountyGeneration = 0
local autoBountyWorkerRunning = false
local autoBountyConnections = {}
local autoBountyLastOpenedAt = {}
local autoBountyLastOpenAt = 0
local autoBountyTarget = nil
local autoBountyLandedTargetId = nil
local autoBountyPosition = nil
local autoBountyPointLabel = nil
local autoBountyLastUiMessage = ""
local autoBountyLastUiContent = ""
local autoBountyLastUiAt = 0
local autoBountyBlockedUntil = {}
local autoBountyTeleportFailures = 0
local autoBountyScanCache = nil
local autoBountyScanReason = "NoActiveTarget"
local autoBountyLastScanAt = 0
local autoBountyScanDirty = true
local autoBountySafeTargetId = nil
local autoBountySafeTargetInstance = nil
local autoBountySafeTargetPosition = nil
local autoBountyLastLandingVerifyAt = 0
local autoBountyLastOpenUiTargetId = nil
local autoBountyToggleController
local autoBountyLastSafePivot
local autoBountyRecoveryPending = false
local recoverAutoBounty
local AUTO_BOUNTY_SCAN_INTERVAL = 1
local AUTO_BOUNTY_MIN_SCAN_GAP = 0.25
local AUTO_BOUNTY_LANDING_VERIFY_INTERVAL = 0.5
local AUTO_BOUNTY_UI_INTERVAL = 0.2
local autoBountyStatusParagraph = S.PremiumTab:CreateParagraph({
    Title="Auto Secret Bounty",
    Content="State: IDLE\nTarget: none\nServer contract: waiting",
})

local function isSafeAutoBountyPivot(pivot)
    if typeof(pivot) ~= "CFrame" or pivot.Position.Y < -500 then
        return false
    end
    local ok, allowed = pcall(function()
        return isPositionInsideAllowedMap(pivot.Position)
    end)
    return ok and allowed == true
end

local function captureAutoBountySafePivot(pivot)
    if autoBountyEnabled and isSafeAutoBountyPivot(pivot) then
        autoBountyLastSafePivot = pivot
        autoBountyRecoveryPending = false
    end
end

local function autoBountyNotify(title, message, duration)
    local text = tostring(message)
    if autoBountyLastUiMessage == title .. "|" .. text then return end
    autoBountyLastUiMessage = title .. "|" .. text
    Rayfield:Notify({Title=title, Content=text, Duration=duration or 5})
end

local function autoBountyUi(state, target, reason)
    local previousState = autoBountyState
    autoBountyState = state or autoBountyState
    local targetName = target and (target.displayName or target.eggName) or "none"
    local remaining = target and target.endsAt and tostring(math.max(0, math.floor(target.endsAt - bountyNow()))) .. "s" or "Unknown"
    local distance = "Unknown"
    if target and S.hrp and bountyFiniteVector(target.position) then
        distance = tostring(math.floor((S.hrp.Position - target.position).Magnitude)) .. " studs"
    end
    local positionText = autoBountyPosition and string.format("%.1f, %.1f, %.1f", autoBountyPosition.X, autoBountyPosition.Y, autoBountyPosition.Z) or "none"
    local content = string.format(
        "State: %s\nTarget: %s\nTime left: %s\nDistance: %s\nConfidence: %s\nSafe point: %s (%s)\nReason: %s",
        tostring(autoBountyState), tostring(targetName), remaining, distance,
        tostring(target and target.confidence or "none"), positionText, tostring(autoBountyPointLabel or "none"), tostring(reason or "none")
    )
    if content == autoBountyLastUiContent then return end
    local now = os.clock()
    if previousState == autoBountyState and now - autoBountyLastUiAt < AUTO_BOUNTY_UI_INTERVAL then return end
    autoBountyLastUiContent = content
    autoBountyLastUiAt = now
    autoBountyStatusParagraph:Set({Title="Auto Secret Bounty", Content=content})
end

local function autoBountyLog(level, message, data)
    bountyLog(level, message, data)
end

local function autoBountySameTarget(left, right)
    return left and right and left.bountyId == right.bountyId and left.instance == right.instance
end

local function clearAutoBountyPositionCache()
    autoBountyPosition = nil
    autoBountyPointLabel = nil
    autoBountySafeTargetId = nil
    autoBountySafeTargetInstance = nil
    autoBountySafeTargetPosition = nil
    autoBountyLastLandingVerifyAt = 0
end

function validateBountyTarget(target)
    if not target or not target.instance then return false, "MissingTarget" end
    if not bountyInWorkspace(target.instance) then return false, "TargetRemoved" end
    if target.isActive ~= true then return false, "NotActive" end
    if type(target.bountyId) ~= "string" or target.bountyId == "" then return false, "MissingBountyId" end
    if type(target.displayName) ~= "string" or target.displayName == "" then return false, "MissingDisplayName" end
    if not target.position or not bountyFiniteVector(target.position) then return false, "InvalidPosition" end
    if target.endsAt ~= nil and target.endsAt <= bountyNow() then return false, "Expired" end
    if target.endsAt == nil and target.source ~= "ServerScan" and target.source ~= "ReplicatedConfig" and target.source ~= "Label" then return false, "UnknownExpiry" end
    if target.isStale or bountyNow() - target.lastSeen > BOUNTY_STALE_SECONDS then return false, "Stale" end
    if target.confidence == "low" then return false, "LowConfidence" end
    if not isPositionInsideAllowedMap(target.position) then return false, "OutsideAllowedMap" end
    return true, "Valid"
end

function scoreBountyTarget(target)
    local valid, reason = validateBountyTarget(target)
    if not valid then return -math.huge, reason end
    local confidenceScore = ({high=60, medium=35, low=0})[target.confidence] or 0
    local remainingScore = target.endsAt and math.clamp((target.endsAt - bountyNow()) / 60, 0, 30) or 5
    local distanceScore = 0
    if S.hrp then distanceScore = math.max(0, 20 - (S.hrp.Position - target.position).Magnitude / 50) end
    local safetyScore = 0
    local safePosition = findSafeBountyPosition(target)
    if safePosition then safetyScore = 25 else return -math.huge, "NoSafeLandingPosition" end
    return confidenceScore + remainingScore + distanceScore + safetyScore, "confidence/time/distance/safety"
end

local function getExistingBountyRemotes()
    local folder = ReplicatedStorage:FindFirstChild("SecretBountyRemotes")
    if not folder then return nil, nil end
    local scan = folder:FindFirstChild("Scan")
    local teleport = folder:FindFirstChild("Teleport")
    return scan, teleport
end

local function readServerBountyState()
    local scan = getExistingBountyRemotes()
    if not scan or not scan:IsA("RemoteFunction") then return nil, "ServerScanUnavailable" end
    local ok, response = pcall(function() return scan:InvokeServer() end)
    if not ok then return nil, "ServerScanFailed" end
    if type(response) ~= "table" or response.found ~= true or not response.egg then
        return nil, tostring(type(response) == "table" and response.message or "NoActiveServerBounty")
    end
    local egg = response.egg
    if not egg:IsDescendantOf(Workspace) then return nil, "ServerTargetRemoved" end
    local pivot = bountyPivot(egg)
    if not pivot or not bountyFiniteVector(pivot.Position) then return nil, "ServerTargetPositionInvalid" end
    local secondsLeft = tonumber(response.secondsLeft)
    local state = {
        bountyId=tostring(egg:GetAttribute("BountyId") or egg:GetAttribute("BountyID") or bountyNormalize(egg.Name)),
        eggName=egg.Name,
        displayName=tostring(response.name or egg:GetAttribute("DisplayName") or egg.Name),
        instance=egg, position=pivot.Position, isActive=true,
        startsAt=nil, endsAt=secondsLeft and bountyNow() + math.max(0, secondsLeft) or nil,
        source="ServerScan", confidence="high", lastSeen=bountyNow(), isStale=false,
    }
    return state
end

local function readConfiguredBountyState()
    local configuredName = Workspace:GetAttribute("SecretBountyEgg")
    if type(configuredName) ~= "string" or configuredName == "" then return nil end
    local egg = findEggByName(configuredName)
    local state = egg and bountyReadState(egg)
    if not state then return nil end
    state.source, state.confidence = "ReplicatedConfig", "high"
    return state
end

local function readLabelBountyState()
    local labelName, labelText = readBountyEggNameFromLabels()
    local egg = labelName and findEggByName(labelName)
    local state = egg and bountyReadState(egg)
    if not state then return nil end
    -- Label fallback is used only when the server scan/config state is absent.
    -- It is refreshed on every scan and remains visibly marked as a fallback.
    state.source, state.confidence = "Label", "medium"
    local text = tostring(labelText or ""):lower()
    local hours = tonumber(text:match("(%d+)%s*h")) or 0
    local minutes = tonumber(text:match("(%d+)%s*m")) or 0
    local seconds = tonumber(text:match("(%d+)%s*s")) or 0
    local inferred = hours * 3600 + minutes * 60 + seconds
    if inferred > 0 then state.endsAt = bountyNow() + inferred end
    return state
end

function scanActiveSecretBounties()
    local states = {}
    local serverState, serverReason = readServerBountyState()
    if not serverState then serverState = readConfiguredBountyState() end
    if not serverState then serverState = readLabelBountyState() end
    if serverState then
        local valid = validateBountyTarget(serverState)
        if valid then
            local score = scoreBountyTarget(serverState)
            serverState.score = score
            states[#states + 1] = serverState
            bountyEggStates[serverState.bountyId] = serverState
        end
    end
    for _, instance in ipairs(Workspace:GetDescendants()) do
        if bountyHasTag(instance)
            or instance:GetAttribute("BountyActive") ~= nil
            or instance:GetAttribute("BountyEndsAt") ~= nil
            or instance:GetAttribute("BountyId") ~= nil then
            local state = bountyReadState(instance)
            if state then
                local valid = validateBountyTarget(state)
                if valid then
                    local score = scoreBountyTarget(state)
                    state.score = score
                    states[#states + 1] = state
                    bountyEggStates[state.bountyId] = state
                end
            end
        end
    end
    table.sort(states, function(a, b) return (a.score or -math.huge) > (b.score or -math.huge) end)
    return states, serverState and "LocalFallback" or serverReason
end

function findSafeBountyPosition(target)
    local position, point = findBestLandingPosition(target)
    if not position then return nil, point or "NoSafeLandingPosition" end
    if S.hrp and (S.hrp.Position - position).Magnitude > autoBountyMaxTeleportDistance then
        return nil, "BeyondTeleportDistance"
    end
    return position, point
end

local function getSecretBountyRemote()
    local remote = ReplicatedStorage:FindFirstChild("SecretBountyRemote")
    if remote and (remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent")) then return remote end
    local _, teleport = getExistingBountyRemotes()
    return teleport
end

function requestServerTeleport(target, position)
    local valid, reason = validateBountyTarget(target)
    if not valid then return false, reason end
    local safe, safeReason = isSafeLandingPosition(position, target)
    if not safe then return false, safeReason end
    if not target or not position then return false, "InvalidTeleportRequest" end
    local character = S.player and S.player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or humanoid.Health <= 0 or not root then return false, "CharacterNotReady" end
    if os.clock() - bountyLastTeleport < BOUNTY_TELEPORT_COOLDOWN then return false, "Cooldown" end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    bountyLastTeleport = os.clock()
    local targetCFrame = CFrame.new(position, position + Vector3.new(0, 0, -1))
    local ok, err = pcall(function()
        -- Restored original client-side teleport path, using the verified safe point.
        root.CFrame = targetCFrame
    end)
    if not ok then return false, "TeleportFailed" end
    return true, "ClientTeleportRequested"
end

function verifyLandingPosition(target)
    if not autoBountyPosition then return false, "NoLandingPosition" end
    return verifyTeleportResult(target, autoBountyPosition)
end

function requestOpenBountyEgg(target, skipRecentLandingCheck)
    local valid, reason = validateBountyTarget(target)
    if not valid then return false, reason end
    if not skipRecentLandingCheck then
        local landed, landingReason = verifyLandingPosition(target)
        autoBountyLastLandingVerifyAt = os.clock()
        if not landed then return false, landingReason end
    end
    local remote = ReplicatedStorage:FindFirstChild("SecretBountyRemote")
    local folder = ReplicatedStorage:FindFirstChild("SecretBountyRemotes")
    local openRemote = folder and folder:FindFirstChild("Open")
    remote = (remote and remote:IsA("RemoteFunction") and remote) or (openRemote and openRemote:IsA("RemoteFunction") and openRemote)
    if not remote then
        -- Compatibility with the existing owner-game purchase server. The server
        -- still decides currency, inventory, cooldown, and permission.
        if S.NetworkRemoteEvent and S.NetworkRemoteEvent:IsA("RemoteEvent") then
            local ok = pcall(function()
                S.NetworkRemoteEvent:FireServer("PurchaseEgg", target.eggName, S.multiEgg == true)
            end)
            return ok, ok and "ServerPurchaseRequested" or "ServerOpenError"
        end
        return false, "ServerOpenRemoteUnavailable"
    end
    if os.clock() - autoBountyLastOpenAt < autoBountyOpenCooldown then return false, "OpenCooldown" end
    autoBountyLastOpenAt = os.clock()
    if remote:IsA("RemoteFunction") then
        local ok, response = pcall(function()
            return remote:InvokeServer("OpenBountyEgg", target.bountyId)
        end)
        if not ok then return false, "ServerOpenError" end
        if type(response) == "table" and response.ok == true then return true, "Opened" end
        return false, type(response) == "table" and tostring(response.reason or "ServerRejected") or "ServerRejected"
    end
    return false, "OpenRequiresRemoteFunctionAck"
end

function cleanupAutoBountyConnections()
    for _, connection in ipairs(autoBountyConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(autoBountyConnections)
end

function stopAutoBounty(reason)
    autoBountyGeneration += 1
    autoBountyEnabled = false
    autoBountyWorkerRunning = false
    autoBountyTarget = nil
    autoBountyLandedTargetId = nil
    autoBountyLastOpenUiTargetId = nil
    clearAutoBountyPositionCache()
    autoBountyScanCache = nil
    autoBountyScanReason = "NoActiveTarget"
    autoBountyLastScanAt = 0
    autoBountyScanDirty = true
    cleanupAutoBountyConnections()
    autoBountyUi("IDLE", nil, reason or "Stopped")
    if autoBountyToggleController then
        autoBountyToggleController:Set(false, reason or "Stopped", false)
    end
end

recoverAutoBounty = function(reason)
    local safePivot = autoBountyLastSafePivot
    stopAutoBounty(reason or "Safe recovery")

    local character = S.player and S.player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if safePivot and isSafeAutoBountyPivot(safePivot)
        and character and humanoid and humanoid.Health > 0 and root then
        local ok = pcall(function()
            character:PivotTo(safePivot)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        autoBountyRecoveryPending = not ok
        if ok then
            autoBountyUi("IDLE", nil, "SafeRecoveryComplete")
            autoBountyNotify("Auto Bounty", "System stopped and returned to the safe position", 5)
        end
    else
        autoBountyRecoveryPending = safePivot ~= nil
        autoBountyUi("IDLE", nil, "SafeRecoveryPending")
        autoBountyNotify("Auto Bounty", "System stopped: waiting for Character to restore the safe position", 5)
    end
end

local function restoreAutoBountyAfterRespawn(character)
    if not autoBountyRecoveryPending or not autoBountyLastSafePivot then
        return
    end
    task.spawn(function()
        for _ = 1, 40 do
            if not autoBountyRecoveryPending then
                return
            end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local root = character:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and root and isSafeAutoBountyPivot(autoBountyLastSafePivot) then
                local ok = pcall(function()
                    character:PivotTo(autoBountyLastSafePivot)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end)
                if ok then
                    autoBountyRecoveryPending = false
                    autoBountyUi("IDLE", nil, "RecoveryCompleteAfterRespawn")
                    autoBountyNotify("Auto Bounty", "Safe position restored after respawn", 5)
                    return
                end
            end
            task.wait(0.25)
        end
        autoBountyNotify("Auto Bounty", "Could not restore the safe position: Character is not ready", 6)
    end)
end

S.player.CharacterRemoving:Connect(function()
    if autoBountyEnabled then
        recoverAutoBounty("Character respawning")
    end
end)
S.player.CharacterAdded:Connect(restoreAutoBountyAfterRespawn)

local function chooseAutoBountyTarget(states)
    for _, state in ipairs(states) do
        local lastOpenedAt = autoBountyLastOpenedAt[state.bountyId] or -math.huge
        local openReadyAt = lastOpenedAt + autoBountyOpenCooldown
        if openReadyAt <= os.clock() and (autoBountyBlockedUntil[state.bountyId] or 0) <= os.clock() then
            local score, reason = scoreBountyTarget(state)
            if score > -math.huge then return state, score, reason end
        end
    end
    if #states > 0 then return nil, nil, "TargetOpenCooldown" end
    return nil, nil, "NoActiveTarget"
end

local function startAutoBountyWorker()
    if autoBountyWorkerRunning or not autoBountyEnabled then return end
    autoBountyWorkerRunning = true
    autoBountyGeneration += 1
    local generation = autoBountyGeneration
    autoBountyScanCache = nil
    autoBountyScanReason = "NoActiveTarget"
    autoBountyLastScanAt = 0
    autoBountyScanDirty = true
    autoBountyLastOpenUiTargetId = nil
    cleanupAutoBountyConnections()
    table.insert(autoBountyConnections, Workspace.DescendantAdded:Connect(function()
        autoBountyScanDirty = true
    end))
    table.insert(autoBountyConnections, Workspace.DescendantRemoving:Connect(function()
        autoBountyScanDirty = true
    end))
    task.spawn(function()
        while autoBountyEnabled and autoBountyWorkerRunning and generation == autoBountyGeneration do
            local character = S.player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not character or not humanoid or humanoid.Health <= 0 or not root then
                recoverAutoBounty("CharacterNotReady")
                task.wait(1)
                continue
            end
            if not autoBountyScanEnabled then
                autoBountyUi("IDLE", nil, "AutoScanDisabled")
                task.wait(1)
                continue
            end
            local scanNow = os.clock()
            local states, scanReason
            local scanDue = not autoBountyScanCache
                or (autoBountyScanDirty and scanNow - autoBountyLastScanAt >= AUTO_BOUNTY_MIN_SCAN_GAP)
                or scanNow - autoBountyLastScanAt >= AUTO_BOUNTY_SCAN_INTERVAL
            if scanDue then
                autoBountyUi("SCANNING", autoBountyTarget, "Scanning active replicated bounties")
                states, scanReason = scanActiveSecretBounties()
                autoBountyScanCache = states or {}
                autoBountyScanReason = scanReason or "NoActiveTarget"
                autoBountyLastScanAt = scanNow
                autoBountyScanDirty = false
            else
                states = autoBountyScanCache
                scanReason = autoBountyScanReason
            end

            local cachedTarget
            for _, candidate in ipairs(states or {}) do
                if autoBountySameTarget(autoBountyTarget, candidate) then
                    cachedTarget = candidate
                    break
                end
            end
            local target, score, selectReason
            if cachedTarget
                and autoBountyLandedTargetId == cachedTarget.bountyId
                and (autoBountyBlockedUntil[cachedTarget.bountyId] or 0) <= os.clock() then
                target = cachedTarget
                score = cachedTarget.score or 0
                selectReason = "CachedLandedTarget"
            else
                target, score, selectReason = chooseAutoBountyTarget(states or {})
            end
            if not target then
                if autoBountyTarget and not bountyInWorkspace(autoBountyTarget.instance) then
                    recoverAutoBounty("TargetRemoved")
                    continue
                end
                if selectReason == "TargetOpenCooldown" and autoBountyTarget then
                    autoBountyUi("COMPLETE", autoBountyTarget, "OpenCooldown")
                    task.wait(0.1)
                    continue
                end
                autoBountyTarget = nil
                autoBountyLandedTargetId = nil
                clearAutoBountyPositionCache()
                autoBountyUi("SCANNING", nil, "No valid target: " .. tostring(scanReason or "Waiting for a new Secret Bounty Egg"))
                task.wait(1)
                continue
            end
            if not target.instance or not bountyInWorkspace(target.instance) then
                recoverAutoBounty("TargetRemoved")
                continue
            end
            local previousTarget = autoBountyTarget
            autoBountyTarget = target
            local targetChanged = not autoBountySameTarget(previousTarget, target)
            if targetChanged then
                autoBountyLandedTargetId = nil
                autoBountyLastOpenUiTargetId = nil
                clearAutoBountyPositionCache()
            end
            if targetChanged then
                autoBountyUi("SELECTING_TARGET", target, string.format("Selected score %.1f (%s)", score, selectReason))
            end
            task.wait(0.1)
            local valid, validReason = validateBountyTarget(target)
            if not valid then
                autoBountyScanDirty = true
                autoBountyUi("SCANNING", nil, validReason)
                task.wait(1)
                continue
            end

            local targetMoved = autoBountySafeTargetPosition
                and (autoBountySafeTargetPosition - target.position).Magnitude > 1
            local needsSafePosition = targetChanged
                or not autoBountyPosition
                or autoBountySafeTargetId ~= target.bountyId
                or autoBountySafeTargetInstance ~= target.instance
                or targetMoved
            local position, pointReason
            if needsSafePosition then
                autoBountyUi("FINDING_SAFE_POSITION", target, "Checking Center/Offsets/Grid")
                position, pointReason = findSafeBountyPosition(target)
                if not position then
                    autoBountyScanDirty = true
                    autoBountyUi("SCANNING", target, pointReason)
                    autoBountyNotify("Auto Bounty", "No safe landing point: " .. tostring(pointReason), 5)
                    task.wait(2)
                    continue
                end
                autoBountyPosition, autoBountyPointLabel = position, pointReason
                autoBountySafeTargetId = target.bountyId
                autoBountySafeTargetInstance = target.instance
                autoBountySafeTargetPosition = target.position
            else
                position, pointReason = autoBountyPosition, autoBountyPointLabel or "Cached"
            end

            local alreadyLanded = autoBountyLandedTargetId == target.bountyId
            if alreadyLanded and os.clock() - autoBountyLastLandingVerifyAt >= AUTO_BOUNTY_LANDING_VERIFY_INTERVAL then
                local stillLanded = verifyLandingPosition(target)
                autoBountyLastLandingVerifyAt = os.clock()
                if not stillLanded then
                    autoBountyLandedTargetId = nil
                    alreadyLanded = false
                end
            end
            if not alreadyLanded then
                if not autoBountyTeleportEnabled then
                    autoBountyUi("FINDING_SAFE_POSITION", target, "AutoTeleportDisabled")
                    task.wait(1)
                    continue
                end
                autoBountyUi("VERIFY_TELEPORT", target, "Teleporting to verified point")
                local teleported, teleportReason = requestServerTeleport(target, position)
                if not teleported then
                    autoBountyTeleportFailures += 1
                    if autoBountyTeleportFailures >= 2 then
                        recoverAutoBounty("Teleport failed: " .. tostring(teleportReason))
                        continue
                    end
                    autoBountyUi("IDLE", target, teleportReason)
                    autoBountyNotify("Auto Bounty teleport", tostring(teleportReason), 6)
                    task.wait(2)
                    continue
                end
                task.wait(0.2)
                local landed, landingReason = verifyLandingPosition(target)
                autoBountyLastLandingVerifyAt = os.clock()
                if not landed then
                    autoBountyTeleportFailures += 1
                    if autoBountyTeleportFailures >= 2 then
                        recoverAutoBounty("Landing failed: " .. tostring(landingReason))
                        continue
                    end
                    autoBountyUi("IDLE", target, landingReason)
                    autoBountyNotify("Auto Bounty landing", tostring(landingReason), 6)
                    task.wait(2)
                    continue
                end
                autoBountyLandedTargetId = target.bountyId
                autoBountyTeleportFailures = 0
            end
            if not autoBountyOpenEnabled then
                autoBountyUi("COMPLETE", target, "Landed; AutoOpenDisabled")
                task.wait(2)
                continue
            end
            local shouldShowOpening = autoBountyLastOpenUiTargetId ~= target.bountyId
            if shouldShowOpening then
                autoBountyUi("OPENING", target, "Server validating BountyId/player state")
            end
            local skipRecentLandingCheck = os.clock() - autoBountyLastLandingVerifyAt < AUTO_BOUNTY_LANDING_VERIFY_INTERVAL
            local opened, openReason = requestOpenBountyEgg(target, skipRecentLandingCheck)
            if opened then
                autoBountyTeleportFailures = 0
                autoBountyLastOpenedAt[target.bountyId] = os.clock()
                autoBountyLastOpenUiTargetId = target.bountyId
                autoBountyUi("COMPLETE", target, "Opened successfully")
                autoBountyNotify("Auto Bounty", "Opened " .. tostring(target.displayName), 5)
                task.wait(autoBountyOpenCooldown)
            else
                autoBountyBlockedUntil[target.bountyId] = os.clock() + math.max(5, autoBountyOpenCooldown)
                autoBountyUi("COMPLETE", target, "Open rejected: " .. tostring(openReason))
                autoBountyNotify("Auto Bounty open", tostring(openReason), 6)
                task.wait(2)
            end
        end
        autoBountyWorkerRunning = false
        cleanupAutoBountyConnections()
    end)
end

local function setAutoBountyEnabled(value)
    if value == true then
        autoBountyEnabled = true
        -- Use the maximum configured range when Auto Secret Bounty starts;
        -- this also overrides an older saved 250/1000-stud setting.
        autoBountyMaxTeleportDistance = 1000000
        startAutoBountyWorker()
        return true
    else
        stopAutoBounty("DisabledByUser")
        return true
    end
end

local previousStopAllFeatures = S.stopAllFeatures
function S.stopAllFeatures()
    if previousStopAllFeatures then previousStopAllFeatures() end
    stopAutoBounty("StopAll")
end

autoBountyToggleController = S.createStatusToggle(S.PremiumTab, {
    Name = "Enable Auto Secret Bounty",
    Description = "Auto Bounty",
    CurrentValue = false,
    Flag = "AutoSecretBounty",
    Callback = setAutoBountyEnabled,
})
S.createStatusToggle(S.PremiumTab, {
    Name = "Auto Scan",
    Description = "Bounty Scanner",
    CurrentValue = false,
    Flag = "AutoSecretBountyScan",
    Callback = function(value)
        autoBountyScanEnabled = value == true
        if autoBountyScanEnabled then
            startBountyScanner()
            autoBountyScanDirty = true
        else
            stopBountyScanner()
            bountyEggStates = {}
            bountyEggTarget = nil
            bountyEggLabelName = nil
            bountyPublish()
        end
        return true
    end,
})
S.createStatusToggle(S.PremiumTab, {
    Name = "Auto Teleport",
    Description = "Bounty Teleport",
    CurrentValue = true,
    Flag = "AutoSecretBountyTeleport",
    Callback = function(value)
        autoBountyTeleportEnabled = value == true
        if autoBountyTeleportEnabled then autoBountyTeleportFailures = 0 end
        return true
    end,
})
S.createStatusToggle(S.PremiumTab, {
    Name = "Auto Open",
    Description = "Bounty Auto Open",
    CurrentValue = true,
    Flag = "AutoSecretBountyOpen",
    Callback = function(value)
        autoBountyOpenEnabled = value == true
        return true
    end,
})
S.PremiumTab:CreateSlider({Name="Max Bounty teleport distance", Range={25,1000000}, Increment=1000, Suffix=" studs", CurrentValue=1000000, Flag="AutoSecretBountyDistance", Callback=function(value)
    autoBountyMaxTeleportDistance = math.clamp(tonumber(value) or 1000000, 25, 1000000)
end})
S.PremiumTab:CreateSlider({Name="Bounty open cooldown", Range={0.025,60}, Increment=0.025, Suffix=" s", CurrentValue=0.025, Flag="AutoSecretBountyCooldown", Callback=function(value)
    autoBountyOpenCooldown = math.clamp(tonumber(value) or 0.025, 0.025, 60)
end})
S.PremiumTab:CreateButton({Name="Stop All Auto Bounty", Callback=function()
    stopAutoBounty("StoppedByUser")
end})

S.PremiumTab:CreateButton({
    Name = "Scan Secret Bounty Egg",
    Callback = function()
        local egg = scanSecretBountyEgg()
        if not egg then
            Rayfield:Notify({Title="Bounty scan",Content="No active tagged bounty egg found.",Duration=5})
            return
        end
        local state
        for _, candidate in pairs(bountyEggStates) do if candidate.instance == egg then state = candidate break end end
        local suffix = state and state.endsAt and (" | " .. tostring(math.max(0, math.floor(state.endsAt - bountyNow()))) .. "s left") or " | Unknown time"
        Rayfield:Notify({Title="Bounty found",Content=(state and state.displayName or egg.Name) .. suffix .. "\nSource: " .. tostring(state and state.source) .. " | Confidence: " .. tostring(state and state.confidence),Duration=6})
    end,
})

S.PremiumTab:CreateButton({
    Name = "Read bounty sign and scan matching egg",
    Callback = function()
        local labelName, labelText = readBountyEggNameFromLabels()
        local matchingEgg = findEggByName(labelName)
        if not labelName then
            Rayfield:Notify({Title="Bounty sign",Content="No visible bounty sign with a recognized egg name was found.",Duration=6})
            return
        end
        if not matchingEgg then
            Rayfield:Notify({Title="Bounty sign",Content="Sign says " .. labelName .. ", but that egg is not loaded in Workspace.Eggs.",Duration=6})
            return
        end
        local state = bountyReadState(matchingEgg)
        if not state then
            Rayfield:Notify({Title="Bounty sign",Content="The matching egg is inactive, expired, or has no valid position.",Duration=6})
            return
        end
        state.source, state.confidence = "Label", "low"
        bountyEggStates[state.bountyId] = state
        bountyEggLabelName, bountyEggTarget = labelName, matchingEgg
        Rayfield:Notify({Title="Bounty egg found",Content=labelName .. "\n" .. tostring(labelText) .. "\nSource: Label | Confidence: low",Duration=7})
    end,
})

S.PremiumTab:CreateButton({
    Name = "Teleport to scanned Bounty Egg",
    Callback = function()
        local state, stateReason = getCurrentBountyState()
        local ok, reason = false, stateReason
        if state then ok, reason = teleportToVerifiedBounty(state) end
        if not ok then
            Rayfield:Notify({Title="Bounty teleport",Content="Teleport failed: " .. tostring(reason),Duration=5})
            return
        end
        Rayfield:Notify({Title="Bounty teleport",Content="Verified landing point: " .. tostring(reason) .. "\nTarget: " .. tostring(state.displayName),Duration=5})
    end,
})

S.PremiumTab:CreateButton({
    Name = "Test safe Bounty landing point",
    Callback = function()
        local state, stateReason = getCurrentBountyState()
        if not state then
            Rayfield:Notify({Title="Bounty safety",Content="Test failed: " .. tostring(stateReason),Duration=5})
            return
        end
        local position, point = findBestLandingPosition(state)
        if not position then
            Rayfield:Notify({Title="Bounty safety",Content="No safe landing point: " .. tostring(point),Duration=5})
            return
        end
        Rayfield:Notify({Title="Bounty safety",Content=string.format("Safe: %s\nPosition: %.1f, %.1f, %.1f", tostring(point), position.X, position.Y, position.Z),Duration=7})
    end,
})

S.PremiumTab:CreateButton({
    Name = "Stop Bounty teleport",
    Callback = function()
        bountyTeleportStopped = true
        bountyLastTeleport = os.clock()
        Rayfield:Notify({Title="Bounty teleport",Content="Stopped. Teleport requests are cancelled until the next manual teleport.",Duration=4})
    end,
})

local bountyWebParagraph = S.PremiumTab:CreateParagraph({
    Title = "OG.BGSI.IO Daily Bounty",
    Content = "Press Refresh to read the current bounty from og.bgsi.io.",
})

local function refreshWebBounty()
    bountyWebParagraph:Set({Title="External bounty data",Content="Disabled: no official JSON/API adapter is configured. Auto scan is off by default; use the manual scan button or enable Auto Scan.\nSource: Workspace replicated state"})
    Rayfield:Notify({Title="Bounty web",Content="HTML is not treated as verified bounty data.",Duration=6})
end

S.PremiumTab:CreateButton({Name="Refresh bounty from OG.BGSI.IO",Callback=function()
    task.spawn(refreshWebBounty)
end})

------------------------------------------------------------
-- WHEEL UI
------------------------------------------------------------
FarmTab:CreateSection("Wheel")

FarmTab:CreateToggle({
    Name = "Auto spin the wheel",
    CurrentValue = false,
    Flag = "WheelActive",
    Callback = function(state)
        S.wheelActive = state
        if state then
            task.spawn(function()
                task.wait(0.5)
                local ok, err = pcall(function()
                    runWheelCycle()
                    while S.wheelActive do
                        task.wait(S.wheelIntervalHours * 3600)
                        if not S.wheelActive then break end
                        runWheelCycle()
                    end
                end)
                if not ok then
                    warn("[BGS Wheel] ", err)
                end
            end)
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Wheel interval",
    Range = {1, 24},
    Increment = 1,
    Suffix = " h",
    CurrentValue = 1,
    Flag = "WheelInterval",
    Callback = function(v) S.wheelIntervalHours = v end,
})

FarmTab:CreateButton({
    Name = "Spin once now",
    Callback = function()
        task.spawn(function()
            local ok, err = pcall(runWheelCycle)
            if not ok then
                warn("[BGS Wheel] ", err)
            end
        end)
    end,
})

------------------------------------------------------------
-- OVERWORLD UNLOCK UI
------------------------------------------------------------
FarmTab:CreateSection("Overworld")

local OVERWORLD_UNLOCK_POSITIONS = {
    Vector3.new(90.4342, 898.7943, -340.5690),
    Vector3.new(86.2952, 5224.5195, -302.2048),
    Vector3.new(117.3760, 11383.7930, -304.8179),
    Vector3.new(111.8869, 21098.7930, -323.4909),
    Vector3.new(106.1126, 40698.7891, -325.2673),
    Vector3.new(117.8411, 32131.7910, -314.7003),
    Vector3.new(113.0688, 53431.7891, -327.0027),
}

local unlockingOverworld = false

local function unlockOverworldOnce()
    if unlockingOverworld then return end
    if not S.hrp then return end
    unlockingOverworld = true
    S.isTeleporting = true
    S.cancelMovement()
    Rayfield:Notify({ Title = "Islands", Content = "Unlocking Overworld...", Duration = 4 })
    pcall(function()
        for _, pos in ipairs(OVERWORLD_UNLOCK_POSITIONS) do
            if not S.hrp then break end
            S.hrp.CFrame = CFrame.new(pos + Vector3.new(0, 8, 0))
            task.wait(0.3)
            local touchWait = 0
            while touchWait < 3 do
                if S.humanoid and S.humanoid.FloorMaterial ~= Enum.Material.Air then
                    break
                end
                task.wait(0.1)
                touchWait = touchWait + 0.1
            end
            task.wait(2)
        end
    end)
    S.isTeleporting = false
    unlockingOverworld = false
    Rayfield:Notify({ Title = "Islands", Content = "Done.", Duration = 3 })
end

FarmTab:CreateButton({
    Name = "Unlock all islands",
    Callback = function()
        task.spawn(unlockOverworldOnce)
    end,
})

------------------------------------------------------------
-- FARM LOGIC
------------------------------------------------------------
function getPickupsInRange()
    if not S.hrp then return {} end
    local found = {}
    for _, item in ipairs(S.PICKUPS_FOLDER:GetChildren()) do
        local part = nil
        if item:IsA("BasePart") then
            part = item
        else
            part = item:FindFirstChildWhichIsA("BasePart")
        end
        if part then
            local dist = (part.Position - S.hrp.Position).Magnitude
            if dist <= S.RADIUS then
                table.insert(found, { part = part, dist = dist })
            end
        end
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
    return found
end

local function goToLegit(part)
    if not S.humanoid then return end
    S.humanoid:MoveTo(part.Position)
    local reached = false
    local moveConn = S.humanoid.MoveToFinished:Connect(function() reached = true end)
    local elapsed = 0
    while not reached do
        if elapsed >= 5 then break end
        if not S.hrp or not part.Parent or S.isTeleporting then break end
        if (part.Position - S.hrp.Position).Magnitude <= S.REACH_DIST then break end
        task.wait(0.1)
        elapsed = elapsed + 0.1
    end
    moveConn:Disconnect()
end

local function goToFast(part, dist)
    local duration = math.max(dist / S.TRAVEL_SPEED, 0.05)
    local goalCFrame = CFrame.new(part.Position.X, S.hrp.Position.Y, part.Position.Z)
    S.currentTween = TweenService:Create(S.hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = goalCFrame })
    local conn = nil
    if S.currentTween then
        conn = part.AncestryChanged:Connect(function(_, parent)
            if not parent and S.currentTween then S.currentTween:Cancel() end
        end)
    end
    S.currentTween:Play()
    task.spawn(function() S.currentTween.Completed:Wait() end)
    local t = 0
    while t < duration + 1 do
        task.wait(0.05)
        t = t + 0.05
    end
    if conn then conn:Disconnect() end
    S.currentTween = nil
end

function collectNearby()
    if S.busy or not S.hrp or S.isTeleporting then return end
    local list = getPickupsInRange()
    if #list == 0 then return end
    S.busy = true
    local ok, err = pcall(function()
        if S.COLLECT_ALL then
            for _, entry in ipairs(list) do
                if not entry.part.Parent or S.isTeleporting then continue end
                if S.MODE == "LEGIT" then
                    goToLegit(entry.part)
                else
                    goToFast(entry.part, entry.dist)
                end
                if not S.farmActive or S.isTeleporting then break end
            end
        else
            local entry = list[1]
            if S.MODE == "LEGIT" then
                goToLegit(entry.part)
            else
                goToFast(entry.part, entry.dist)
            end
        end
    end)
    S.busy = false
    if not ok then warn("[BGS Farm] ", err) end
end

------------------------------------------------------------
-- WHEEL LOGIC
------------------------------------------------------------
function runWheelCycle()
    if not S.hrp or S.isTeleporting then return end
    S.isTeleporting = true
    S.cancelMovement()

    local originalCFrame, originalVelocity, originalWalkSpeed, originalAutoRotate
    pcall(function()
        if S.hrp then
            originalCFrame = S.hrp.CFrame
            originalVelocity = S.hrp.AssemblyLinearVelocity
        end
        if S.humanoid then
            originalWalkSpeed = S.humanoid.WalkSpeed
            originalAutoRotate = S.humanoid.AutoRotate
            S.humanoid.AutoRotate = false
            S.humanoid:Move(Vector3.zero, true)
            S.humanoid.WalkSpeed = 0
        end
    end)

    local tempPlat = Instance.new("Part")
    tempPlat.Size = Vector3.new(20, 2, 20)
    tempPlat.Position = S.WHEEL_POS - Vector3.new(0, 4, 0)
    tempPlat.Anchored = true
    tempPlat.Transparency = 1
    tempPlat.CanCollide = true
    tempPlat.Parent = Workspace

    pcall(function()
        if S.hrp then S.hrp.CFrame = CFrame.new(S.WHEEL_POS) end
        task.wait(0.3)
        local elapsed = 0
        while elapsed < S.wheelSpinDuration do
            S.NetworkRemoteEvent:FireServer("SpinToWin")
            task.wait(0.1)
            elapsed = elapsed + 0.1
        end
    end)

    pcall(function()
        if S.hrp and originalCFrame then S.hrp.CFrame = originalCFrame end
        if S.humanoid then
            S.humanoid.WalkSpeed = originalWalkSpeed or S.WALK_SPEED
            S.humanoid.AutoRotate = (originalAutoRotate == nil) and true or originalAutoRotate
        end
        if S.hrp and originalVelocity then S.hrp.AssemblyLinearVelocity = originalVelocity end
    end)

    if tempPlat and tempPlat.Parent then
        pcall(function() tempPlat:Destroy() end)
    end

    task.wait(0.5)
    S.isTeleporting = false
end

------------------------------------------------------------
-- SHARD QUEST: FUNCIONES INTERNAS
------------------------------------------------------------
local shardFailCount = 0

local function getShardQuestProgress()
    local ok, current, max = pcall(function()
        local pGui = player:FindFirstChild("PlayerGui")
        if not pGui then return nil, nil end
        local sGui = pGui:FindFirstChild("ScreenGui")
        if not sGui then return nil, nil end
        local shardQ = sGui:FindFirstChild("ShardQuests")
        if not shardQ then return nil, nil end
        local content = shardQ:FindFirstChild("Content")
        if not content then return nil, nil end
        local inner = content:FindFirstChild("Inner")
        if not inner then return nil, nil end
        local quest = inner:FindFirstChild("Quest")
        if not quest then return nil, nil end
        local progress = quest:FindFirstChild("Progress")
        if not progress then return nil, nil end
        local textLabel = progress:FindFirstChild("TextLabel")
        if not textLabel then return nil, nil end
        local currentStr, maxStr = textLabel.Text:match("([%d,]+)%s*/%s*([%d,]+)")
        if not currentStr or not maxStr then return nil, nil end
        return tonumber((currentStr:gsub(",", ""))), tonumber((maxStr:gsub(",", "")))
    end)
    if not ok then
        shardFailCount = shardFailCount + 1
        if shardFailCount % 30 == 0 then
            warn("[BGS Shard] progress read failed x" .. shardFailCount)
        end
        return nil, nil
    end
    shardFailCount = 0
    return current, max
end

local function shardGoToQuestBoard()
    if not S.hrp then return end
    pcall(function()
        local tempPlat = Instance.new("Part")
        tempPlat.Size = Vector3.new(20, 2, 20)
        tempPlat.Position = S.QUEST_BOARD_POS - Vector3.new(0, 4, 0)
        tempPlat.Anchored = true
        tempPlat.Transparency = 1
        tempPlat.CanCollide = true
        tempPlat.Parent = Workspace
        S.hrp.CFrame = CFrame.new(S.QUEST_BOARD_POS)
        task.wait(1)
        tempPlat:Destroy()
    end)
end

local function findChestFolderNear(position, maxDist)
    maxDist = maxDist or 60
    local closestDist = maxDist
    local closestName = nil
    local root = Workspace:FindFirstChild("FloatingIslands") or Workspace
    for _, inst in ipairs(root:GetDescendants()) do
        if inst.Name == "Chest" and inst:IsA("BasePart") then
            local dist = (inst.Position - position).Magnitude
            if dist < closestDist then
                local islandFolder = inst.Parent and inst.Parent.Parent
                if islandFolder then
                    closestDist = dist
                    closestName = islandFolder.Name
                end
            end
        end
    end
    return closestName
end

local eggPositionCache = {}

local function findEggPosition(eggName)
    if eggPositionCache[eggName] then
        return eggPositionCache[eggName]
    end
    local eggsFolder = Workspace:FindFirstChild("Eggs")
    if not eggsFolder then return nil end
    local target = eggsFolder:FindFirstChild(eggName)
    if target then
        local pos = nil
        if target:IsA("BasePart") then
            pos = target.Position
        elseif target:IsA("Model") then
            if target.PrimaryPart then
                pos = target.PrimaryPart.Position
            else
                pcall(function() pos = target:GetPivot().Position end)
            end
        end
        if pos then
            eggPositionCache[eggName] = pos
            return pos
        end
    end
    return nil
end

local eggQuestWarned = {}

local function handleEggQuest()
    if not S.hrp then return end
    local eggName = S.EGG_QUEST_NAME
    if S.questEggMode == "selected" and S.selectedEgg then
        eggName = S.selectedEgg
    end
    local eggPos = findEggPosition(eggName)
    if not eggPos then
        eggPos = S.EGG_QUEST_POS
        if not eggQuestWarned[eggName] then
            eggQuestWarned[eggName] = true
            warn("[BGS Shard] No se encontró " .. eggName .. " en Workspace.Eggs. Usando Spikey por defecto.")
        end
    end
    if (S.hrp.Position - eggPos).Magnitude > 8 then
        pcall(function() S.hrp.CFrame = CFrame.new(eggPos + Vector3.new(0, 3, 0)) end)
        task.wait(0.3)
    end
    pcall(function()
        S.NetworkRemoteEvent:FireServer("PurchaseEgg", eggName, S.multiEgg)
    end)
end

local function handleBubbleHeavenQuest()
    if not S.hrp then return end
    if (S.hrp.Position - S.HEAVEN_POS).Magnitude > 8 then
        pcall(function() S.hrp.CFrame = CFrame.new(S.HEAVEN_POS) end)
        task.wait(0.3)
    end
    pcall(function()
        S.NetworkRemoteEvent:FireServer("BlowBubble")
    end)
end

function restoreFarmConfigAfterGems()
    if not S.gemsQuestSetupDone or not S.savedFarmConfigBeforeGems then return end
    S.RADIUS = S.savedFarmConfigBeforeGems.RADIUS
    S.WALK_SPEED = S.savedFarmConfigBeforeGems.WALK_SPEED
    S.MODE = S.savedFarmConfigBeforeGems.MODE
    S.COLLECT_ALL = S.savedFarmConfigBeforeGems.COLLECT_ALL
    if S.humanoid then S.humanoid.WalkSpeed = S.WALK_SPEED end
    if S.farmActive ~= S.savedFarmConfigBeforeGems.farmActive then
        pcall(function() S.farmToggleElement:Set(S.savedFarmConfigBeforeGems.farmActive) end)
    end
    if S.noclipActive ~= S.savedFarmConfigBeforeGems.noclipActive then
        pcall(function() S.noclipToggleElement:Set(S.savedFarmConfigBeforeGems.noclipActive) end)
    end
    S.gemsQuestSetupDone = false
    S.savedFarmConfigBeforeGems = nil
end

local function collectReservedChest(pos, islandName)
    if not S.hrp or S.isTeleporting then return end
    S.isTeleporting = true
    S.cancelMovement()
    local originalCFrame, originalWalkSpeed, originalAutoRotate
    pcall(function()
        originalCFrame = S.hrp.CFrame
        if S.humanoid then
            originalWalkSpeed = S.humanoid.WalkSpeed
            originalAutoRotate = S.humanoid.AutoRotate
        end
    end)
    pcall(function()
        S.hrp.CFrame = CFrame.new(pos)
        local elapsed = 0
        while elapsed < 4 do
            if not S.hrp then break end
            S.NetworkRemoteEvent:FireServer("CollectChestReward", islandName)
            task.wait(0.5)
            elapsed = elapsed + 0.5
        end
    end)
    pcall(function()
        if S.hrp and originalCFrame then S.hrp.CFrame = originalCFrame end
        if S.humanoid then
            S.humanoid.WalkSpeed = originalWalkSpeed or S.WALK_SPEED
            S.humanoid.AutoRotate = (originalAutoRotate == nil) and true or originalAutoRotate
        end
    end)
    S.isTeleporting = false
end

local function handleGemsQuest()
    if not S.gemsQuestSetupDone then
        S.savedFarmConfigBeforeGems = {
            RADIUS = S.RADIUS, WALK_SPEED = S.WALK_SPEED, MODE = S.MODE,
            COLLECT_ALL = S.COLLECT_ALL, farmActive = S.farmActive, noclipActive = S.noclipActive,
        }
        S.RADIUS = 120
        S.WALK_SPEED = 100
        S.MODE = "LEGIT"
        S.COLLECT_ALL = true
        if S.humanoid then S.humanoid.WalkSpeed = S.WALK_SPEED end
        if S.hrp then pcall(function() S.hrp.CFrame = CFrame.new(S.GEMS_FARM_POS) end) end
        if not S.noclipActive then pcall(function() S.noclipToggleElement:Set(true) end) end
        if not S.farmActive then pcall(function() S.farmToggleElement:Set(true) end) end
        S.lastVoidChestAttempt = os.clock() - S.VOID_CHEST_COOLDOWN
        S.lastGodlyChestAttempt = os.clock() - S.GODLY_CHEST_COOLDOWN
        S.lastGemsChestRetry = os.clock() - S.GEMS_CHEST_RETRY_INTERVAL
        S.gemsQuestSetupDone = true
    end
    if S.hrp and (S.hrp.Position - S.GEMS_FARM_POS).Magnitude > S.GEMS_FARM_DRIFT_LIMIT then
        pcall(function() S.hrp.CFrame = CFrame.new(S.GEMS_FARM_POS) end)
    end
    local now = os.clock()
    if now - S.lastVoidChestAttempt >= S.VOID_CHEST_COOLDOWN then
        S.lastVoidChestAttempt = now
        collectReservedChest(S.VOID_CHEST_POS, S.VOID_CHEST_ISLAND_NAME)
    elseif now - S.lastGodlyChestAttempt >= S.GODLY_CHEST_COOLDOWN then
        S.lastGodlyChestAttempt = now
        collectReservedChest(S.GODLY_CHEST_POS, S.GODLY_CHEST_ISLAND_NAME)
    end
    if now - S.lastGemsChestRetry >= S.GEMS_CHEST_RETRY_INTERVAL then
        S.lastGemsChestRetry = now
        pcall(function() collectReservedChest(S.VOID_CHEST_POS, S.VOID_CHEST_ISLAND_NAME) end)
        task.wait(0.25)
        pcall(function() collectReservedChest(S.GODLY_CHEST_POS, S.GODLY_CHEST_ISLAND_NAME) end)
    end
end

local function handleCurrencyChestQuest()
    if not S.hrp or S.isTeleporting then return end
    local target = S.CURRENCY_CHEST_TARGETS[S.currencyChestIndex]
    if not target then S.currencyChestIndex = 1 return end
    S.isTeleporting = true
    S.cancelMovement()
    local originalCFrame, originalWalkSpeed, originalAutoRotate
    pcall(function()
        originalCFrame = S.hrp.CFrame
        if S.humanoid then
            originalWalkSpeed = S.humanoid.WalkSpeed
            originalAutoRotate = S.humanoid.AutoRotate
        end
    end)
    pcall(function()
        local tempPlat = Instance.new("Part")
        tempPlat.Size = Vector3.new(12, 1, 12)
        tempPlat.Position = target.pos - Vector3.new(0, 4, 0)
        tempPlat.Anchored = true
        tempPlat.Transparency = 1
        tempPlat.CanCollide = true
        tempPlat.Name = "TempChestPlatform"
        tempPlat.Parent = Workspace
        if S.hrp then
            S.hrp.CFrame = CFrame.new(tempPlat.Position + Vector3.new(0, 3, 0))
            task.wait(0.15)
        end
        local prevPlatformStand
        if S.humanoid then
            pcall(function()
                prevPlatformStand = S.humanoid.PlatformStand
                S.humanoid.PlatformStand = true
            end)
        end
        local resolvedName = nil
        local resolveStart = os.clock()
        while os.clock() - resolveStart < 3 do
            resolvedName = findChestFolderNear(target.pos, 120)
            if resolvedName then break end
            task.wait(0.3)
        end
        if resolvedName then
            local elapsed = 0
            while elapsed < 3 do
                if not S.hrp then break end
                S.NetworkRemoteEvent:FireServer("CollectChestReward", resolvedName)
                task.wait(0.3)
                elapsed = elapsed + 0.3
            end
        end
        if S.humanoid then
            S.humanoid.PlatformStand = (prevPlatformStand == nil) and false or prevPlatformStand
        end
        if tempPlat and tempPlat.Parent then
            pcall(function() tempPlat:Destroy() end)
        end
    end)
    pcall(function()
        if S.hrp and originalCFrame then S.hrp.CFrame = originalCFrame end
        if S.humanoid then
            S.humanoid.WalkSpeed = originalWalkSpeed or S.WALK_SPEED
            S.humanoid.AutoRotate = (originalAutoRotate == nil) and true or originalAutoRotate
        end
    end)
    S.isTeleporting = false
    S.currencyChestIndex = S.currencyChestIndex + 1
    if S.currencyChestIndex > #S.CURRENCY_CHEST_TARGETS then
        S.currencyChestIndex = 1
    end
end

local noQuestStreak = 0
local NO_QUEST_THRESHOLD = 6
local CHECKPOINT_INTERVAL = 20
local awaitingNewQuest = false
local lastKnownMax = nil
local blindStreak = 0

local function checkpointShardProgress()
    S.isTeleporting = true
    S.cancelMovement()
    shardGoToQuestBoard()
    task.wait(0.5)
    local checkCurrent, checkMax = getShardQuestProgress()
    S.isTeleporting = false
    return checkCurrent, checkMax
end

local function dispatchQuestAction(max)
    if max == 3000 or max == 5000 or max == 25 then
        handleEggQuest()
    elseif max == 1000000000 then
        handleBubbleHeavenQuest()
    elseif max == 30000000000 then
        handleGemsQuest()
    elseif max == 10000000000 then
        handleCurrencyChestQuest()
    end
end

local function requestNewShardQuest()
    restoreFarmConfigAfterGems()
    S.shardQuestStatus = "Requesting quest..."
    S.shardQuestTaskName = "Detecting..."
    S.shardQuestPercent = 0
    if S.updateShardProgressWindow then pcall(S.updateShardProgressWindow) end
    S.isTeleporting = true
    S.cancelMovement()
    pcall(function() S.NetworkRemoteEvent:FireServer("Teleport", "ShardArea") end)
    task.wait(0.5)
    shardGoToQuestBoard()
    S.isTeleporting = false
    task.wait(0.5)
    pcall(function() S.NetworkRemoteEvent:FireServer("GetShardQuest", "Hard") end)
    task.wait(1)
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if S.shardQuestActive and not S.isTeleporting then
            local current, max = getShardQuestProgress()
            if current and max then
                noQuestStreak = 0
                blindStreak = 0
                awaitingNewQuest = false
                if current >= max then
                    lastKnownMax = nil
                    restoreFarmConfigAfterGems()
                    S.shardQuestStatus = "Claiming reward..."
                    S.shardQuestTaskName = S.SHARD_QUEST_TYPES[max] or ("Unknown (" .. max .. ")")
                    S.shardQuestPercent = 100
                    if S.updateShardProgressWindow then pcall(S.updateShardProgressWindow) end
                    S.isTeleporting = true
                    S.cancelMovement()
                    pcall(function() S.NetworkRemoteEvent:FireServer("Teleport", "ShardArea") end)
                    task.wait(0.5)
                    shardGoToQuestBoard()
                    S.isTeleporting = false
                    task.wait(0.5)
                    pcall(function() S.NetworkRemoteEvent:FireServer("ClaimShardQuestReward") end)
                    task.wait(1)
                    pcall(function() S.NetworkRemoteEvent:FireServer("GetShardQuest", "Hard") end)
                else
                    lastKnownMax = max
                    S.shardQuestStatus = "In progress"
                    S.shardQuestTaskName = S.SHARD_QUEST_TYPES[max] or ("Unknown quest (" .. max .. ")")
                    S.shardQuestPercent = math.floor((current / max) * 100)
                    if S.updateShardProgressWindow then pcall(S.updateShardProgressWindow) end
                    if max ~= 30000000000 and S.gemsQuestSetupDone then
                        restoreFarmConfigAfterGems()
                    end
                    dispatchQuestAction(max)
                end
            elseif lastKnownMax then
                blindStreak = blindStreak + 1
                S.shardQuestStatus = "In progress"
                if S.updateShardProgressWindow then pcall(S.updateShardProgressWindow) end
                dispatchQuestAction(lastKnownMax)
                if blindStreak >= CHECKPOINT_INTERVAL then
                    blindStreak = 0
                    local cc, cm = checkpointShardProgress()
                    if cc and cm then
                        lastKnownMax = cm
                        if cc >= cm then
                            restoreFarmConfigAfterGems()
                            task.wait(0.3)
                            pcall(function() S.NetworkRemoteEvent:FireServer("ClaimShardQuestReward") end)
                            task.wait(1)
                            pcall(function() S.NetworkRemoteEvent:FireServer("GetShardQuest", "Hard") end)
                            lastKnownMax = nil
                        end
                    end
                end
            else
                noQuestStreak = noQuestStreak + 1
                if noQuestStreak >= NO_QUEST_THRESHOLD and not awaitingNewQuest then
                    awaitingNewQuest = true
                    requestNewShardQuest()
                end
            end
        end
    end
end)

S.getPickupsInRange = getPickupsInRange
S.collectNearby = collectNearby
S.runWheelCycle = runWheelCycle
S.findEggPosition = findEggPosition

_G.BGS.modules.farm = true
print("[BGS] farm loaded (v1.4)")
-- ============ END: farm.lua ============
end


modules["hatch"]=function()
-- ============ FILE: hatch.lua ============
-- BGS BY YAMAHAO V1.9 — Hatch
-- Eggs + Crates (auto-scan) + Auto Open + Stats + Webhook.

local S = _G.BGS.shared
local Rayfield = S.Rayfield

local Players = S.Services.Players
local Workspace = S.Services.Workspace
local ReplicatedStorage = S.Services.ReplicatedStorage

local player = S.player
local HatchTab = S.HatchTab

------------------------------------------------------------
-- SECRET PETS LIST (fallback para detección de ultra-raros)
------------------------------------------------------------
local DEFAULT_SECRET_PETS = {
    ["Chromatic Dragon"] = true,
    ["Cursed"] = true,
    ["Djinn"] = true,
    ["Dominus Astra"] = true,
    ["Dominus Frigidus"] = true,
    ["Dominus Infernus"] = true,
    ["Dominus Hydra"] = true,
    ["Eternal"] = true,
    ["Fallen Angel"] = true,
    ["Frost Dragon"] = true,
    ["Gamer"] = true,
    ["Genesis"] = true,
    ["Hacker"] = true,
    ["Ice Dragon"] = true,
    ["King Slime"] = true,
    ["Kraken"] = true,
    ["Lunar Guardian"] = true,
    ["Mythic Dragon"] = true,
    ["Nebula"] = true,
    ["Observer"] = true,
    ["Omega"] = true,
    ["Overlord"] = true,
    ["Phantom"] = true,
    ["Rainbow Dragon"] = true,
    ["Ragnarok"] = true,
    ["Shadow Dragon"] = true,
    ["Shooting Star"] = true,
    ["Spectral"] = true,
    ["Star Dragon"] = true,
    ["Sun God"] = true,
    ["Void Dragon"] = true,
    ["Yin Yang"] = true,
    ["Zeus"] = true,
}

S.SECRET_PETS = DEFAULT_SECRET_PETS

if S.GLOBAL.customSecrets then
    for _, name in ipairs(S.GLOBAL.customSecrets) do
        S.SECRET_PETS[name] = true
    end
end

local function isSecretPet(petName)
    if not petName then return false end
    local clean = tostring(petName):gsub("^%s+", ""):gsub("%s+$", "")
    if S.SECRET_PETS[clean] then return true end
    for k, _ in pairs(S.SECRET_PETS) do
        if k:lower() == clean:lower() then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- AUTO-SCAN desde Workspace.Eggs (huevos + crates)
------------------------------------------------------------
local function isCrate(name)
    if not name then return false end
    return name:lower():find("crate", 1, true) ~= nil
end

local function crateNameToBoxName(crateName)
    if not crateName then return crateName end
    return crateName:gsub("Crate", "Box"):gsub("crate", "box")
end

local function scanWorkspace()
    local eggsFolder = Workspace:FindFirstChild("Eggs")
    if not eggsFolder then
        return {}, {}, {}
    end
    local eggList = {}
    local boxDisplayList = {}
    local crateMapping = {}
    for _, child in ipairs(eggsFolder:GetChildren()) do
        if child:IsA("BasePart") or child:IsA("Model") then
            if isCrate(child.Name) then
                local display = crateNameToBoxName(child.Name)
                if not crateMapping[display] then
                    crateMapping[display] = child.Name
                    table.insert(boxDisplayList, display)
                end
            else
                table.insert(eggList, child.Name)
            end
        end
    end
    table.sort(eggList)
    table.sort(boxDisplayList)
    return eggList, boxDisplayList, crateMapping
end

local function mergeLists(scanned, custom)
    local merged = {}
    local seen = {}
    for _, name in ipairs(scanned or {}) do
        if not seen[name] then
            seen[name] = true
            table.insert(merged, name)
        end
    end
    for _, name in ipairs(custom or {}) do
        if not seen[name] then
            seen[name] = true
            table.insert(merged, name)
        end
    end
    table.sort(merged)
    return merged
end

S.CRATE_MAPPING = {}
do
    local eggList, boxList, crateMapping = scanWorkspace()
    S.EGG_LIST = mergeLists(eggList, S.EGG_LIST)
    S.BOX_LIST = mergeLists(boxList, S.BOX_LIST)
    S.CRATE_MAPPING = crateMapping
    print(string.format("[BGS Hatch] Found %d eggs and %d crates in Workspace.Eggs", #eggList, #boxList))
end

------------------------------------------------------------
-- EGGS UI
------------------------------------------------------------
HatchTab:CreateSection("Eggs")

S.selectedEggs = {}
S.eggDropdownElement = HatchTab:CreateDropdown({
    Name = "Egg to open",
    Options = S.EGG_LIST,
    CurrentOption = {S.EGG_LIST[1] or "Select..."},
    MultipleOptions = true,
    Flag = "EggSelected",
    Callback = function(option)
        S.selectedEggs = {}
        if type(option) == "table" then
            for _, eggName in ipairs(option) do
                if type(eggName) == "string" and eggName ~= "Select..." then
                    table.insert(S.selectedEggs, eggName)
                end
            end
        end
        S.selectedEgg = S.selectedEggs[1]
        if S.eggSelectionStatus then
            local count = #S.selectedEggs
            local preview = count > 0 and table.concat(S.selectedEggs, ", ") or "none"
            pcall(function()
                S.eggSelectionStatus:Set({Title="Selected eggs",Content=tostring(count) .. " selected\n" .. preview})
            end)
        end
    end,
})

S.eggSelectionStatus = HatchTab:CreateParagraph({
    Title = "Selected eggs",
    Content = "1 selected\n" .. tostring(S.EGG_LIST[1] or "none"),
})

if S.EGG_LIST[1] then
    S.selectedEgg = S.EGG_LIST[1]
    S.selectedEggs = {S.EGG_LIST[1]}
end

HatchTab:CreateButton({
    Name = "Teleport to selected egg",
    Callback = function()
        if not S.hrp then
            Rayfield:Notify({ Title = "TP", Content = "Character not loaded.", Duration = 3 })
            return
        end
        if not S.selectedEgg then
            Rayfield:Notify({ Title = "TP", Content = "No egg selected.", Duration = 3 })
            return
        end
        local eggsFolder = Workspace:FindFirstChild("Eggs")
        if not eggsFolder then
            Rayfield:Notify({ Title = "TP", Content = "Workspace.Eggs not found.", Duration = 3 })
            return
        end
        local target = eggsFolder:FindFirstChild(S.selectedEgg)
        if not target then
            Rayfield:Notify({ Title = "TP", Content = "Egg '" .. S.selectedEgg .. "' not found.", Duration = 4 })
            return
        end
        local pos = nil
        if target:IsA("BasePart") then
            pos = target.Position
        elseif target:IsA("Model") then
            if target.PrimaryPart then
                pos = target.PrimaryPart.Position
            else
                pcall(function() pos = target:GetPivot().Position end)
            end
        end
        if not pos then
            Rayfield:Notify({ Title = "TP", Content = "Could not get position of egg.", Duration = 3 })
            return
        end
        S.eggPositions=S.eggPositions or {}
        S.eggPositions[S.selectedEgg]={x=pos.X,y=pos.Y+5,z=pos.Z}
        if S.personalSaveEggPositions then pcall(S.personalSaveEggPositions) end
        pcall(function()
            S.hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
        end)
        Rayfield:Notify({ Title = "TP", Content = "Teleported to '" .. S.selectedEgg .. "'.", Duration = 3 })
    end,
})

HatchTab:CreateButton({
    Name="Save current position for selected egg",
    Callback=function()
        if not S.selectedEgg or not S.hrp then
            Rayfield:Notify({Title="TP",Content="Select an egg and wait for your character first.",Duration=4})
            return
        end
        local p=S.hrp.Position
        S.eggPositions=S.eggPositions or {}
        S.eggPositions[S.selectedEgg]={x=p.X,y=p.Y,z=p.Z}
        local ok,err=S.personalSaveEggPositions and S.personalSaveEggPositions()
        Rayfield:Notify({Title="TP",Content=ok and ("Saved position for "..S.selectedEgg) or ("Save failed: "..tostring(err)),Duration=4})
    end,
})

HatchTab:CreateButton({
    Name="Teleport to saved position for selected egg",
    Callback=function()
        local saved=S.eggPositions and S.selectedEgg and S.eggPositions[S.selectedEgg]
        if not S.hrp or type(saved)~="table" then
            Rayfield:Notify({Title="TP",Content="No saved position for the selected egg.",Duration=4})
            return
        end
        local ok,err=pcall(function() S.hrp.CFrame=CFrame.new(saved.x,saved.y,saved.z) end)
        Rayfield:Notify({Title="TP",Content=ok and ("Teleported to "..S.selectedEgg) or ("Teleport failed: "..tostring(err)),Duration=4})
    end,
})

------------------------------------------------------------
-- BOXES UI
------------------------------------------------------------
HatchTab:CreateSection("Boxes")

S.boxDropdownElement = HatchTab:CreateDropdown({
    Name = "Box to open",
    Options = S.BOX_LIST,
    CurrentOption = {S.BOX_LIST[1] or "Select..."},
    Flag = "BoxSelected",
    Callback = function(option) S.selectedBox = option[1] end,
})

if S.BOX_LIST[1] then
    S.selectedBox = S.BOX_LIST[1]
end

HatchTab:CreateButton({
    Name = "Teleport to selected box",
    Callback = function()
        if not S.hrp then
            Rayfield:Notify({ Title = "TP", Content = "Character not loaded.", Duration = 3 })
            return
        end
        if not S.selectedBox then
            Rayfield:Notify({ Title = "TP", Content = "No box selected.", Duration = 3 })
            return
        end
        local rawName = S.CRATE_MAPPING[S.selectedBox]
        if not rawName then
            rawName = S.selectedBox:gsub("Box", "Crate"):gsub("box", "crate")
        end
        local eggsFolder = Workspace:FindFirstChild("Eggs")
        if not eggsFolder then
            Rayfield:Notify({ Title = "TP", Content = "Workspace.Eggs not found.", Duration = 3 })
            return
        end
        local target = eggsFolder:FindFirstChild(rawName)
        if not target then
            Rayfield:Notify({ Title = "TP", Content = "Crate '" .. rawName .. "' not found.", Duration = 4 })
            return
        end
        local pos = nil
        if target:IsA("BasePart") then
            pos = target.Position
        elseif target:IsA("Model") then
            if target.PrimaryPart then
                pos = target.PrimaryPart.Position
            else
                pcall(function() pos = target:GetPivot().Position end)
            end
        end
        if not pos then
            Rayfield:Notify({ Title = "TP", Content = "Could not get position of crate.", Duration = 3 })
            return
        end
        pcall(function()
            S.hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
        end)
        Rayfield:Notify({ Title = "TP", Content = "Teleported to '" .. S.selectedBox .. "'.", Duration = 3 })
    end,
})

------------------------------------------------------------
-- AUTO-REFRESH de listas (cada 30s, silencioso)
------------------------------------------------------------
local function refreshLists()
    local eggList, boxList, crateMapping = scanWorkspace()
    local mergedEggs = mergeLists(eggList, S.GLOBAL.customEggs or {})
    local mergedBoxes = mergeLists(boxList, S.GLOBAL.customBoxes or {})
    if #mergedEggs ~= #S.EGG_LIST then
        S.EGG_LIST = mergedEggs
        pcall(function()
            if S.eggDropdownElement and S.eggDropdownElement.SetOptions then
                S.eggDropdownElement:SetOptions(S.EGG_LIST)
            end
        end)
    end
    if #mergedBoxes ~= #S.BOX_LIST then
        S.BOX_LIST = mergedBoxes
        pcall(function()
            if S.boxDropdownElement and S.boxDropdownElement.SetOptions then
                S.boxDropdownElement:SetOptions(S.BOX_LIST)
            end
        end)
    end
    S.CRATE_MAPPING = crateMapping
end

task.spawn(function()
    while true do
        task.wait(30)
        pcall(refreshLists)
    end
end)

------------------------------------------------------------
-- Personal controls: one worker per feature; no automatic starts on load.
HatchTab:CreateSection("Auto Open")
S.includeBoxes = false
S.hatchGeneration = 0
S.boxGeneration = 0
local hatchWorkerRunning = false
local hatchStartPending = false
local hatchStartWaitToken = 0
local hatchEggTeleportDone = false
S.hatchWorkerRunning = false
local HATCH_WEBHOOK_DELAY = 60
local hatchFailureToken = 0

function S.setHatchInterval(value)
    local number = tonumber(value)
    if not number or number ~= number then number = 0.025 end
    S.eggInterval = math.clamp(number, 0.025, 5)
    return S.eggInterval
end

local function queueHatchStatusWebhook(title, description, color, generation)
    local token = hatchFailureToken + 1
    hatchFailureToken = token
    task.delay(HATCH_WEBHOOK_DELAY, function()
        if token ~= hatchFailureToken then return end
        if not S.eggOpenActive or S.hatchWorkerRunning then return end
        if generation and generation ~= S.hatchGeneration then return end
        if S.sendStatusWebhook then
            pcall(S.sendStatusWebhook, title, description, color)
        end
    end)
end

local function reportHatchError(err)
    S.lastHatchError = tostring(err)
    Rayfield:Notify({Title="Hatch stopped", Content=S.lastHatchError, Duration=7})
    queueHatchStatusWebhook("Hatch stopped", S.lastHatchError, 0xE74C3C, S.hatchGeneration)
end

local function stopBoxWorker()
    S.boxGeneration += 1
    S.boxOpenActive = false
end

local function startBoxWorker()
    if S.boxOpenActive or not S.eggOpenActive or not S.includeBoxes then return end
    S.boxGeneration += 1
    local generation = S.boxGeneration
    S.boxOpenActive = true
    task.spawn(function()
        while S.boxOpenActive and S.eggOpenActive and generation == S.boxGeneration do
            if S.selectedBox and S.selectedBox ~= "" then
                local ok, err = pcall(function()
                    -- Send the selected scanned name once; do not guess several purchases.
                    S.NetworkRemoteEvent:FireServer("PurchaseEgg", S.selectedBox, S.boxMulti)
                end)
                if not ok then
                    if generation == S.boxGeneration then stopBoxWorker(); reportHatchError(err) end
                    return
                end
            end
            task.wait(math.clamp(tonumber(S.boxInterval) or 0.5, 0.15, 5))
        end
    end)
end

function S.setIncludeBoxes(enabled)
    S.includeBoxes = enabled == true
    if S.includeBoxes then startBoxWorker() else stopBoxWorker() end
end

function S.setAutoOpen(enabled)
    enabled = enabled == true
    if not enabled then
        hatchFailureToken += 1
        hatchStartPending = false
        hatchStartWaitToken += 1
        hatchEggTeleportDone = false
        S.hatchGeneration += 1
        S.eggOpenActive = false
        stopBoxWorker()
        return true
    end

    -- A new activation cancels any delayed alert from an older failure.
    hatchFailureToken += 1

    -- Auto Hatch and Auto Trick or Treat are mutually exclusive. Stop the
    -- Trick worker before starting Hatch, then wait for its old coroutine to
    -- leave any in-flight teleport before creating the Hatch worker.
    if type(S.stopTrickTreat) == "function" then
        pcall(S.stopTrickTreat, "Auto Hatch enabled")
    end
    if S.trickTreatToggle then
        pcall(function() S.trickTreatToggle:Set(false, "Auto Hatch enabled", false) end)
    end
    if S.eggOpenActive then return true end
    if not S.selectedEgg or S.selectedEgg == "" then
        reportHatchError("Select an egg first, then enable Auto open.")
        task.defer(function()
            if not S.eggOpenActive and S.autoOpenToggle then S.autoOpenToggle:Set(false) end
        end)
        return false
    end

    if S.trickTreatWorkerRunning then
        hatchStartPending = true
        hatchStartWaitToken += 1
        local waitToken = hatchStartWaitToken
        task.spawn(function()
            for _ = 1, 40 do
                if not hatchStartPending or waitToken ~= hatchStartWaitToken then
                    return
                end
                if not S.trickTreatWorkerRunning then
                    hatchStartPending = false
                    S.setAutoOpen(true)
                    return
                end
                task.wait(0.05)
            end
            if hatchStartPending and waitToken == hatchStartWaitToken then
                hatchStartPending = false
                if S.autoOpenToggle then
                    pcall(function() S.autoOpenToggle:Set(false) end)
                end
            end
        end)
        return true
    end

    -- Move to the selected egg once for this Auto Hatch activation. The
    -- flag is reset only when the toggle is turned off, so the hatch loop
    -- cannot repeatedly teleport while it is running.
    if not hatchEggTeleportDone then
        local teleportFn = S.teleportToSelectedEggForHatch
        if type(teleportFn) == "function" then
            hatchEggTeleportDone = true
            local callOk, teleportOk, teleportMessage = pcall(teleportFn)
            if not callOk then
                teleportMessage = teleportOk
                teleportOk = false
            end
            if teleportOk ~= true then
                Rayfield:Notify({
                    Title = "Egg TP",
                    Content = "Teleport to selected egg failed: " .. tostring(teleportMessage or "unknown error"),
                    Duration = 5,
                })
            end
        end
    end

    if hatchWorkerRunning then
        hatchStartPending = true
        return true
    end
    S.hatchGeneration += 1
    local generation = S.hatchGeneration
    S.eggOpenActive = true
    hatchWorkerRunning = true
    S.hatchWorkerRunning = true
    S.lastHatchError = nil
    task.spawn(function()
        while S.eggOpenActive and generation == S.hatchGeneration do
            if S.selectedEgg and S.selectedEgg ~= "" then
                local ok, err = pcall(function()
                    S.NetworkRemoteEvent:FireServer("PurchaseEgg", S.selectedEgg, S.multiEgg)
                end)
                if not ok then
                    if generation == S.hatchGeneration then
                        local errorText=tostring(err)
                        if errorText:lower():find("inventory",1,true) or errorText:lower():find("capacity",1,true) or errorText:lower():find("full",1,true) then
                            queueHatchStatusWebhook("Inventory warning", errorText, 0xF1C40F, generation)
                        else
                            reportHatchError(errorText)
                        end
                    end
                    hatchWorkerRunning = false
                    S.hatchWorkerRunning = false
                    return
                end
            end
            task.wait(S.setHatchInterval(S.eggInterval))
        end
        hatchWorkerRunning = false
        S.hatchWorkerRunning = false
        if hatchStartPending and S.eggOpenActive then
            hatchStartPending = false
            S.eggOpenActive = false
            task.defer(function()
                if not S.eggOpenActive then
                    S.setAutoOpen(true)
                end
            end)
        end
        if S.trickTreatStartPending then
            S.trickTreatStartPending = false
            if type(S.startTrickTreat) == "function" then
                task.defer(S.startTrickTreat)
            end
        end
    end)
    startBoxWorker()
    return true
end

S.multiEggToggle = HatchTab:CreateToggle({Name="Multi open (x3)", CurrentValue=true,
    Flag="PersonalMultiOpen", Callback=function(value) S.multiEgg=value; S.boxMulti=value end})
S.eggIntervalSlider = HatchTab:CreateSlider({Name="Request interval", Range={0.025,5},
    Increment=0.005, Suffix=" s", CurrentValue=0.025, Flag="PersonalEggInterval",
    Callback=function(value) S.setHatchInterval(value) end})
S.includeBoxesToggle = HatchTab:CreateToggle({Name="Also open selected box", CurrentValue=false,
    Flag="PersonalIncludeBoxes", Callback=S.setIncludeBoxes})
S.autoOpenToggle = S.createStatusToggle(HatchTab, {
    Name = "Auto open selected egg",
    Description = "Auto Open",
    CurrentValue = false,
    Flag = "PersonalAutoOpen",
    Callback = S.setAutoOpen,
})
S.autoOpenOnLoadToggle = HatchTab:CreateToggle({Name="Start Auto open after script load", CurrentValue=true,
    Flag="PersonalAutoOpenOnLoad", Callback=function(value) S.autoOpenOnLoad=value==true end})

local lastInventoryAlert=0
local inventoryFullSince=nil
local inventoryAlerted=false
local function findInventoryFullText()
    local gui=player:FindFirstChildOfClass("PlayerGui")
    if not gui then return nil end
    for _,inst in ipairs(gui:GetDescendants()) do
        if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
            local text=tostring(inst.Text or ""):lower()
            if (text:find("inventory",1,true) or text:find("storage",1,true) or text:find("pet",1,true) or text:find("potion",1,true)) and
                (text:find("full",1,true) or text:find("max",1,true) or text:find("capacity",1,true)) then
                local kind = text:find("potion",1,true) and "potion" or "pet"
                return tostring(inst.Text), kind
            end
        end
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(2)
        local message, kind=findInventoryFullText()
        if message then
            if not inventoryFullSince then
                inventoryFullSince=os.clock()
                inventoryAlerted=false
            end
            if not inventoryAlerted and os.clock()-inventoryFullSince>=HATCH_WEBHOOK_DELAY then
                inventoryAlerted=true
                lastInventoryAlert=os.clock()
                local title = kind == "potion" and "Potion inventory full" or "Pet inventory full"
                Rayfield:Notify({Title=title,Content=message,Duration=8})
                if S.sendStatusWebhook then pcall(S.sendStatusWebhook,title,message,0xF1C40F) end
            end
        else
            inventoryFullSince=nil
            inventoryAlerted=false
        end
    end
end)

-- Boost detection is owned by the Boost Manager in the settings module.

function S.applyHatchPreset()
    S.setHatchInterval(0.025)
    S.multiEgg=true; S.boxMulti=true
    S.setIncludeBoxes(false)
    S.multiEggToggle:Set(true)
    S.eggIntervalSlider:Set(0.025)
    S.includeBoxesToggle:Set(false)
end
HatchTab:CreateButton({Name="Apply measured preset: x3 / 0.025s / eggs only",
    Callback=S.applyHatchPreset})
HatchTab:CreateParagraph({Title="What this setting changes",
    Content="0.025s is the request interval, not the server's hatch cooldown. Hourly stats are projections from the egg counter. A higher hatch rate is not guaranteed."})
HatchTab:CreateButton({Name="Measure actual egg gain for 5 minutes", Callback=function()
    S.personalRun("measure")
end})

------------------------------------------------------------
-- HATCH STATS
------------------------------------------------------------
HatchTab:CreateSection("Hatch Stats")

local hatchStatusPara = HatchTab:CreateParagraph({
    Title="Runtime status",
    Content="Preparing...",
})

local hatchStatsPara = HatchTab:CreateParagraph({
    Title = "Hatch Stats",
    Content = "Waiting for data...",
})

local hatchTracker = { samples = {}, windowSec = 60 }
local lastHatchStatsContent=""
local lastHatchStatusContent=""

local function sampleEggsOpened()
    local v = S.readLeaderstat("Eggs Opened")
    if v then
        local now = os.clock()
        local previous = hatchTracker.samples[#hatchTracker.samples]
        if previous and v < previous.v then hatchTracker.samples = {}; S.sessionStartEggs = v end
        table.insert(hatchTracker.samples, { t = now, v = v })
        while #hatchTracker.samples > 0 do
            if now - hatchTracker.samples[1].t > hatchTracker.windowSec then
                table.remove(hatchTracker.samples, 1)
            else
                break
            end
        end
    end
end

local function getEggsPerSecond()
    if #hatchTracker.samples < 2 then return 0 end
    local first = hatchTracker.samples[1]
    local last = hatchTracker.samples[#hatchTracker.samples]
    local dt = last.t - first.t
    if dt <= 0 then return 0 end
    local dv = last.v - first.v
    if dv < 0 then return 0 end
    return dv / dt
end

task.spawn(function()
    while true do
        sampleEggsOpened()
        local eps = getEggsPerSecond()
        local total = S.readLeaderstat("Eggs Opened") or 0
        if S.sessionStartEggs == nil and S.readLeaderstat("Eggs Opened") ~= nil then
            S.sessionStartEggs = total
        end
        local content = string.format(
            "Eggs opened (total): %d\nEggs opened this session: %d\nEggs / second: %.2f\nProjected eggs / hour (recent <=60s): %.0f\nLegendaries this session: %d",
            total,
            math.max(0, total - (S.sessionStartEggs or total)),
            eps,
            eps * 3600,
            S.sessionLegendaries
        )
        if content~=lastHatchStatsContent then
            lastHatchStatsContent=content
            pcall(function() hatchStatsPara:Set({ Title = "Hatch Stats", Content = content }) end)
        end
        local saved=S.eggPositions and S.selectedEgg and S.eggPositions[S.selectedEgg]
        local status=string.format("Auto open: %s\nEgg: %s\nSaved teleport: %s\nAnimation suppression: %s\nBlack screen: %s%s",
            S.eggOpenActive and "RUNNING" or "STOPPED",tostring(S.selectedEgg or "not selected"),
            saved and "YES" or "NO",S.eggAnimationSuppressed and "ON" or "OFF",
            S.blackScreenOnLoad and "ON" or "OFF",S.lastHatchError and ("\nLast error: "..tostring(S.lastHatchError)) or "")
        if status~=lastHatchStatusContent then
            lastHatchStatusContent=status
            pcall(function() hatchStatusPara:Set({Title="Runtime status",Content=status}) end)
        end
        task.wait(1)
    end
end)

------------------------------------------------------------
-- B6: CHAT LISTENER
------------------------------------------------------------
local lastHatchedMessage = nil
local lastHatchedTime = 0

local function cleanChatText(text)
    local cleaned = tostring(text):gsub("<[^>]+>", "")
    return cleaned
end

task.spawn(function()
    local TextChatService = game:GetService("TextChatService")
    if not TextChatService then
        warn("[BGS Hatch] TextChatService no disponible.")
        return
    end
    pcall(function()
        TextChatService.MessageReceived:Connect(function(message)
            if not message then return end
            local raw = message.Text
            if not raw then return end
            local cleaned = cleanChatText(raw)
            if cleaned:find("just hatched a Legendary", 1, true) then
                local username = cleaned:match("%[Server%]:%s*(%S+)%s+just hatched")
                if not username then
                    username = cleaned:match("^(%S+)%s+just hatched")
                end
                if username then
                    lastHatchedMessage = username
                    lastHatchedTime = os.clock()
                end
            end
        end)
    end)
end)

local function shouldSendWebhook()
    if not lastHatchedMessage then return true end
    if os.clock() - lastHatchedTime > 3 then return true end
    if lastHatchedMessage == player.Name then return true end
    return false
end

------------------------------------------------------------
-- HOOK: DisplayLegendaryInChat -> Webhook
------------------------------------------------------------
local function isPetExcluded(petName)
    if not petName then return false end
    local excluded = S.GLOBAL.excludedPets or {}
    local clean = tostring(petName):gsub("^%s+", ""):gsub("%s+$", "")
    for _, name in ipairs(excluded) do
        if name:lower() == clean:lower() then
            return true
        end
    end
    return false
end

-- Formatea la probabilidad en formato legible.
-- El valor que llega YA está en porcentaje (ej: 0.05 = 0.05%, 0.0005 = 0.0005%).
local function formatProbability(pct)
    if not pct or type(pct) ~= "number" then return tostring(pct or "?") end
    if pct <= 0 then return "0%" end
    -- Calcular "1 in X" a partir del porcentaje
    -- pct = 0.05 -> "1 in 2,000"
    -- pct = 0.0005 -> "1 in 200,000"
    local oneIn = 100 / pct
    local function addCommas(n)
        local str = tostring(math.floor(n))
        local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
        if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
        return formatted
    end
    local pctStr
    if pct >= 1 then
        pctStr = string.format("%.2f%%", pct)
    elseif pct >= 0.01 then
        pctStr = string.format("%.4f%%", pct)
    elseif pct >= 0.0001 then
        pctStr = string.format("%.6f%%", pct)
    else
        pctStr = string.format("%.8f%%", pct)
    end
    pctStr = pctStr:gsub("0+%%$", "%%"):gsub("%.%%$", "%%")
    if oneIn >= 1 then
        return pctStr .. " (1 in " .. addCommas(oneIn) .. ")"
    else
        return pctStr
    end
end

local function installRareHook()
    if not S.HAS_HOOK then return false end
    local ok, err = pcall(function()
        for _, Connection in ipairs(getconnections(S.NetworkRemoteEvent.OnClientEvent)) do
            local old
            old = hookfunction(Connection.Function, function(...)
                local args = { ... }
                local eventName = args[1]
                if eventName == "DisplayLegendaryInChat" then
                    local username = args[2]     -- username del jugador
                    local petName = args[3]      -- nombre del pet
                    local probability = args[4]  -- probabilidad EN PORCENTAJE (ej: 0.05 = 0.05%)
                    local isShiny = args[5]      -- ¿es shiny?
                    local isMythic = args[6]     -- ¿es mythical?

                    S.sessionLegendaries = S.sessionLegendaries + 1

                    task.spawn(function()
                        task.wait(0.3)
                        if not shouldSendWebhook() then return end
                        if isPetExcluded(petName) then return end

                        -- Only report results at or rarer than the configured
                        -- one-in threshold. This applies to Legendary, Mythic,
                        -- and Shiny results alike.
                        local minimumOneIn = tonumber(S.GLOBAL.webhookMinRarityOneIn) or 500000
                        local probabilityPercent = tonumber(probability)
                        if minimumOneIn > 0 then
                            local maximumProbability = 100 / minimumOneIn
                            if not probabilityPercent
                                or probabilityPercent <= 0
                                or probabilityPercent > maximumProbability then
                                return
                            end
                        end

                        local totalEggs = S.readLeaderstat("Eggs Opened") or 0
                        if S.sessionStartEggs == nil then
                            S.sessionStartEggs = totalEggs
                        end
                        local eggsThisSession = totalEggs - S.sessionStartEggs

                        local title = "Legendary Hatched!"
                        if isMythic then
                            title = "Mythical Hatched!"
                        end
                        if isShiny then
                            title = "✨ Shiny " .. (isMythic and "Mythical" or "Legendary") .. " Hatched!"
                        end

                        local petText = tostring(petName)

                        local color = 0x9B59B6
                        if isMythic then color = 0xF1C40F end
                        if isShiny then color = 0x00D4FF end

                        -- Ultra-raro: probabilidad menor a 1 en 200,000 (= 0.0005%)
                        local isUltraRare = false
                        if type(probability) == "number" and probability < 0.0005 and probability > 0 then
                            isUltraRare = true
                        end

                        if S.GLOBAL.webhookUrl and S.GLOBAL.webhookUrl ~= "" and S.HAS_HTTP then
                            local payload = {
                                username = "BBG",
                                embeds = {
                                    {
                                        title = title,
                                        color = color,
                                        fields = {
                                            { name = "Pet", value = petText, inline = true },
                                            { name = "Probability", value = formatProbability(probability), inline = true },
                                            { name = "User", value = tostring(username or "?"), inline = true },
                                            { name = "Eggs this session", value = tostring(eggsThisSession), inline = true },
                                            { name = "Legendaries this session", value = tostring(S.sessionLegendaries), inline = true },
                                        },
                                        timestamp = DateTime.now():ToIsoDate(),
                                    },
                                },
                            }
                            if isUltraRare and S.GLOBAL.pingOnSecret ~= false then
                                payload.content = "@everyone"
                            end
                            pcall(function()
                                S.httpPost(S.GLOBAL.webhookUrl, payload)
                            end)
                        end
                    end)
                end
                return old(...)
            end)
        end
    end)
    return ok, err
end

task.spawn(function()
    task.wait(2)
    if S.HAS_HOOK then
        local ok, err = installRareHook()
        if ok then
            Rayfield:Notify({ Title = "Rare Hook", Content = "Listener installed. Webhook sending requires a configured URL.", Duration = 5 })
        else
            Rayfield:Notify({ Title = "Rare Hook", Content = "Hook failed.", Duration = 5 })
        end
    else
        Rayfield:Notify({ Title = "Rare Hook", Content = "Executor doesn't support hooks. Webhook disabled.", Duration = 5 })
    end
end)

S.scanWorkspace = scanWorkspace
S.refreshLists = refreshLists

_G.BGS.modules.hatch = true
print("[BGS] hatch loaded (v1.9)")
-- ============ END: hatch.lua ============
end


modules["bubbles"]=function()
-- ============ FILE: bubbles.lua ============
-- BGS BY YAMAHAO V1.3 — Bubbles
-- Auto-blow + Auto-sell + Bubble Stats.
-- FIXES APLICADOS: B1 (auto-sell usa la zona seleccionada).

local S = _G.BGS.shared
local Rayfield = S.Rayfield

local Workspace = S.Services.Workspace

local player = S.player
local BubbleTab = S.BubbleTab

------------------------------------------------------------
-- AUTO BLOW
------------------------------------------------------------
BubbleTab:CreateSection("Auto Blow")

BubbleTab:CreateSlider({
    Name = "Blow interval",
    Range = {0.05, 2},
    Increment = 0.05,
    Suffix = " s",
    CurrentValue = 0.1,
    Flag = "BlowInterval",
    Callback = function(v) S.blowInterval = v end,
})

BubbleTab:CreateToggle({
    Name = "Auto blow",
    CurrentValue = false,
    Flag = "BlowActive",
    Callback = function(state)
        S.blowActive = state
        if state then
            task.spawn(function()
                while S.blowActive do
                    pcall(function()
                        S.NetworkRemoteEvent:FireServer("BlowBubble")
                    end)
                    task.wait(S.blowInterval)
                end
            end)
        end
    end,
})

------------------------------------------------------------
-- AUTO SELL (B1 fix)
------------------------------------------------------------
BubbleTab:CreateSection("Auto Sell")

local function sellBubblesAt(sellPos, sellId)
    if not S.hrp then return end
    if S.bubbleSelling then return end
    if S.isTeleporting then return end
    S.bubbleSelling = true
    S.isTeleporting = true
    S.cancelMovement()

    local originalCFrame = nil
    local originalVelocity = nil
    local originalWalkSpeed = nil
    local originalAutoRotate = nil
    pcall(function()
        if S.hrp then
            originalCFrame = S.hrp.CFrame
            originalVelocity = S.hrp.AssemblyLinearVelocity
        end
        if S.humanoid then
            originalWalkSpeed = S.humanoid.WalkSpeed
            originalAutoRotate = S.humanoid.AutoRotate
            S.humanoid.AutoRotate = false
            S.humanoid:Move(Vector3.zero, true)
            S.humanoid.WalkSpeed = 0
        end
    end)

    local tempPlat = Instance.new("Part")
    tempPlat.Size = Vector3.new(20, 2, 20)
    tempPlat.Position = sellPos - Vector3.new(0, 4, 0)
    tempPlat.Anchored = true
    tempPlat.Transparency = 1
    tempPlat.CanCollide = true
    tempPlat.Parent = Workspace

    local success, e = pcall(function()
        if S.hrp then S.hrp.CFrame = CFrame.new(sellPos) end
        task.wait(0.4)
        S.NetworkRemoteEvent:FireServer("SellBubble", sellId)
        task.wait(0.6)
    end)

    pcall(function()
        if S.hrp then
            if originalCFrame then S.hrp.CFrame = originalCFrame end
        end
        if S.humanoid then
            if originalWalkSpeed then
                S.humanoid.WalkSpeed = originalWalkSpeed
            else
                S.humanoid.WalkSpeed = S.WALK_SPEED
            end
            if originalAutoRotate == nil then
                S.humanoid.AutoRotate = true
            else
                S.humanoid.AutoRotate = originalAutoRotate
            end
        end
        if S.hrp then
            if originalVelocity then S.hrp.AssemblyLinearVelocity = originalVelocity end
        end
    end)

    if tempPlat then
        if tempPlat.Parent then
            pcall(function() tempPlat:Destroy() end)
        end
    end

    task.wait(0.5)
    S.isTeleporting = false
    S.bubbleSelling = false
    if not success then warn("[BGS Bubbles] ", e) end
end

-- B1: sellBubblesOnce lee S.selectedSellZone (que el dropdown actualiza)
local function sellBubblesOnce()
    local zone = S.SELL_ZONES[S.selectedSellZone]
    if not zone then zone = S.SELL_ZONES["Base (x1)"] end
    sellBubblesAt(zone.pos, zone.sellId)
end

BubbleTab:CreateToggle({
    Name = "Auto sell",
    CurrentValue = false,
    Flag = "BubbleAutoSell",
    Callback = function(state) S.bubbleAutoSellActive = state end,
})

BubbleTab:CreateButton({
    Name = "Sell now",
    Callback = function() task.spawn(sellBubblesOnce) end,
})

-- B1: el dropdown ahora escribe a S.selectedSellZone
BubbleTab:CreateDropdown({
    Name = "Sell zone",
    Options = {"Base (x1)", "Heaven (x9)"},
    CurrentOption = {S.selectedSellZone},
    Flag = "BubbleSellZone",
    Callback = function(option)
        S.selectedSellZone = option[1]
    end,
})

task.spawn(function()
    while true do
        if S.bubbleAutoSellActive then
            if not S.bubbleSelling then
                local sGui = player:FindFirstChild("PlayerGui")
                if sGui then
                    local screen = sGui:FindFirstChild("ScreenGui")
                    if screen then
                        local statsFrame = screen:FindFirstChild("StatsFrame")
                        if statsFrame then
                            local bubble = statsFrame:FindFirstChild("Bubble")
                            if bubble then
                                local label = bubble:FindFirstChild("Amount")
                                if label then
                                    local ok2, text = pcall(function() return label.Text end)
                                    if ok2 then
                                        if text then
                                            local currentStr, maxStr = text:match("([%d,]+)%s*/%s*([%d,]+)")
                                            if currentStr then
                                                if maxStr then
                                                    local current = tonumber((currentStr:gsub(",", "")))
                                                    local max = tonumber((maxStr:gsub(",", "")))
                                                    if current then
                                                        if max then
                                                            if current >= (max * 0.95) then
                                                                task.spawn(sellBubblesOnce)
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

------------------------------------------------------------
-- BACKUP INTERVAL
------------------------------------------------------------
BubbleTab:CreateSection("Backup Interval")

BubbleTab:CreateSlider({
    Name = "Sell interval",
    Range = {5, 120},
    Increment = 5,
    Suffix = " s",
    CurrentValue = 30,
    Flag = "BubbleInterval",
    Callback = function(v) S.bubbleSellInterval = v end,
})

BubbleTab:CreateToggle({
    Name = "Interval mode",
    CurrentValue = false,
    Flag = "BubbleIntervalActive",
    Callback = function(state)
        S.bubbleSellIntervalActive = state
        if state then
            task.spawn(function()
                while S.bubbleSellIntervalActive do
                    sellBubblesOnce()
                    task.wait(S.bubbleSellInterval)
                end
            end)
        end
    end,
})

------------------------------------------------------------
-- BUBBLE STATS
------------------------------------------------------------
BubbleTab:CreateSection("Bubble Stats")

local bubbleStatsPara = BubbleTab:CreateParagraph({
    Title = "Bubble Stats",
    Content = "Waiting for data...",
})

local bubbleTracker = { samples = {}, windowSec = 10 }

task.spawn(function()
    while true do
        local v = S.readLeaderstat("Bubbles Blown")
        if v then
            local now = os.clock()
            table.insert(bubbleTracker.samples, { t = now, v = v })
            while #bubbleTracker.samples > 0 do
                if now - bubbleTracker.samples[1].t > bubbleTracker.windowSec then
                    table.remove(bubbleTracker.samples, 1)
                else
                    break
                end
            end
        end
        local perSec = 0
        if #bubbleTracker.samples >= 2 then
            local a = bubbleTracker.samples[1]
            local b = bubbleTracker.samples[#bubbleTracker.samples]
            local dt = b.t - a.t
            if dt > 0 then
                local dv = b.v - a.v
                if dv > 0 then perSec = dv / dt end
            end
        end
        local content = string.format(
            "Bubbles (total): %d\nBubbles / second: %.1f\nBubbles / hour: %.0f",
            v or 0,
            perSec,
            perSec * 3600
        )
        pcall(function()
            bubbleStatsPara:Set({ Title = "Bubble Stats", Content = content })
        end)
        task.wait(1)
    end
end)

_G.BGS.modules.bubbles = true
print("[BGS] bubbles loaded")
-- ============ END: bubbles.lua ============
end


modules["client"]=function()
-- ============ FILE: client.lua ============
-- BGS BY YAMAHAO V1.5 — Client
-- Performance + Movement + Utilities + Codes.

local S = _G.BGS.shared
local Rayfield = S.Rayfield

local Players = S.Services.Players
local UserInputService = S.Services.UserInputService
local RunService = S.Services.RunService
local Workspace = S.Services.Workspace
local Lighting = S.Services.Lighting
local SoundService = S.Services.SoundService
local Stats = S.Services.Stats
local ReplicatedStorage = S.Services.ReplicatedStorage

local player = S.player
local ClientTab = S.ClientTab
local CodeTab = S.CodeTab

------------------------------------------------------------
-- PERFORMANCE
------------------------------------------------------------
ClientTab:CreateSection("Performance")

local function eggVisualName(inst)
    local text=(tostring(inst.Name).." "..tostring(inst:GetFullName())):lower()
    return text:find("egg",1,true) or text:find("hatch",1,true) or text:find("opening",1,true)
end

local function findEggService()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local modules = assets and assets:FindFirstChild("Modules")
    return modules and modules:FindFirstChild("EggService")
end

local function suppressEggServiceAnimation(inst)
    if not inst then return end
    local isAnimation = inst:IsA("Animation")
    local lowerName = tostring(inst.Name or ""):lower()
    local isNamedEggOpenObject = lowerName:find("open", 1, true)
        or lowerName:find("hatch", 1, true)
        or lowerName:find("reveal", 1, true)
    if not isAnimation and not isNamedEggOpenObject then return end
    if S.eggAnimationSuppressedIds[inst] then return end
    local animationId
    if isAnimation then
        local ok = pcall(function() animationId = inst.AnimationId end)
        if not ok then return end
    end
    local parent = inst.Parent
    local cloneOk, clone = pcall(function() return inst:Clone() end)
    if not cloneOk or not clone then return end
    local backupFolder = S.eggAnimationBackupFolder
    if not backupFolder or not backupFolder.Parent then
        local folderOk, folder = pcall(function()
            local existing = ReplicatedStorage:FindFirstChild("__BGS_EGG_ANIM_BACKUP")
            if existing then return existing end
            local created = Instance.new("Folder")
            created.Name = "__BGS_EGG_ANIM_BACKUP"
            created.Parent = ReplicatedStorage
            return created
        end)
        if not folderOk or not folder then return end
        backupFolder = folder
        S.eggAnimationBackupFolder = backupFolder
    end
    S.eggAnimationAssetBackups[clone] = parent
    S.eggAnimationSuppressedIds[inst] = true
    if animationId and animationId ~= "" then
        S.eggAnimationSuppressedIds[animationId] = true
    end
    local moved = pcall(function() clone.Parent = backupFolder end)
    if moved then pcall(function() inst:Destroy() end) end
end

local function restoreEggServiceAnimations()
    for clone,parent in pairs(S.eggAnimationAssetBackups) do
        if clone and clone.Parent then
            local restoreParent = parent
            if not restoreParent or not restoreParent.Parent then
                local eggService = findEggService()
                restoreParent = eggService
            end
            if restoreParent then
                pcall(function() clone.Parent = restoreParent end)
            end
        end
    end
    table.clear(S.eggAnimationAssetBackups)
    table.clear(S.eggAnimationSuppressedIds)
    if S.eggAnimationBackupFolder and S.eggAnimationBackupFolder.Parent then
        pcall(function() S.eggAnimationBackupFolder:Destroy() end)
    end
    S.eggAnimationBackupFolder = nil
end

local function disconnectEggAnimationConnections()
    for _,connection in ipairs(S.eggAnimationConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(S.eggAnimationConnections)
    table.clear(S.eggAnimationAnimatorSeen)
end

local function isEggVisualEffect(inst)
    return inst and (inst:IsA("ParticleEmitter") or inst:IsA("Trail") or
        inst:IsA("Beam") or inst:IsA("Smoke") or inst:IsA("Fire") or
        inst:IsA("Sparkles")) and eggVisualName(inst)
end

local function disableEggVisualEffect(inst)
    if not isEggVisualEffect(inst) then return end
    local enabled = false
    local ok = pcall(function() enabled = inst.Enabled end)
    if not ok or not enabled then return end
    table.insert(S.eggAnimationDisabledInstances, {instance=inst, enabled=true})
    pcall(function() inst.Enabled=false end)
end

local function stopEggAnimationTrack(track)
    local animation = track and track.Animation
    local animationId
    if animation then pcall(function() animationId = animation.AnimationId end) end
    if animation and (eggVisualName(animation) or S.eggAnimationSuppressedIds[animationId]) then
        pcall(function() track:Stop(0) end)
    end
end

local function connectEggAnimator(animator)
    if not animator or not animator:IsA("Animator") then return end
    if S.eggAnimationAnimatorSeen[animator] then return end
    S.eggAnimationAnimatorSeen[animator] = true
    local ok,connection=pcall(function()
        return animator.AnimationPlayed:Connect(function(track)
            if S.eggAnimationSuppressed then stopEggAnimationTrack(track) end
        end)
    end)
    if ok and connection then table.insert(S.eggAnimationConnections,connection) end
    pcall(function()
        for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
            stopEggAnimationTrack(track)
        end
    end)
end

local function attachEggAnimationBlocker(root)
    if not root then return end
    if root:IsA("Animator") then connectEggAnimator(root) end
    for _,inst in ipairs(root:GetDescendants()) do
        if inst:IsA("Animator") then connectEggAnimator(inst) end
    end
end

function S.setEggAnimationSuppressed(value)
    value=value==true
    S.eggAnimationSuppressed=value
    disconnectEggAnimationConnections()
    if S.eggAnimationCharacterConnection then
        pcall(function() S.eggAnimationCharacterConnection:Disconnect() end)
        S.eggAnimationCharacterConnection=nil
    end
    if not value then
        for _,entry in ipairs(S.eggAnimationDisabledInstances) do
            if entry.instance and entry.instance.Parent then pcall(function() entry.instance.Enabled=entry.enabled end) end
        end
        table.clear(S.eggAnimationDisabledInstances)
        restoreEggServiceAnimations()
        return
    end
    local eggPositionsPath="BGSPersonal/egg-positions.json"
    S.eggPositions=S.eggPositions or {}
    local positionsExists=pcall(isfile,eggPositionsPath) and isfile(eggPositionsPath)
    if positionsExists then
        pcall(function()
            local decoded=Http:JSONDecode(readfile(eggPositionsPath))
            if type(decoded)=="table" then S.eggPositions=decoded end
        end)
    end
    function S.personalSaveEggPositions()
        local ok,err=pcall(function()
            if not isfolder("BGSPersonal") then makefolder("BGSPersonal") end
            writefile(eggPositionsPath,Http:JSONEncode(S.eggPositions or {}))
        end)
        return ok,err
    end
    local eggService = findEggService()
    if eggService then
        for _,inst in ipairs(eggService:GetDescendants()) do
            suppressEggServiceAnimation(inst)
        end
        local ok,connection=pcall(function()
            return eggService.DescendantAdded:Connect(function(inst)
                if S.eggAnimationSuppressed then suppressEggServiceAnimation(inst) end
            end)
        end)
        if ok and connection then table.insert(S.eggAnimationConnections,connection) end
    end
    local roots={Workspace,player:FindFirstChildOfClass("PlayerGui")}
    for _,root in ipairs(roots) do
        if root then
            for _,inst in ipairs(root:GetDescendants()) do
                disableEggVisualEffect(inst)
            end
            attachEggAnimationBlocker(root)
            local ok,connection=pcall(function()
                return root.DescendantAdded:Connect(function(inst)
                    if not S.eggAnimationSuppressed then return end
                    disableEggVisualEffect(inst)
                    if inst:IsA("Animator") then connectEggAnimator(inst) end
                end)
            end)
            if ok and connection then table.insert(S.eggAnimationConnections,connection) end
        end
    end
    if player.Character then attachEggAnimationBlocker(player.Character) end
    S.eggAnimationCharacterConnection=player.CharacterAdded:Connect(function(character)
        task.defer(function() if S.eggAnimationSuppressed then attachEggAnimationBlocker(character) end end)
    end)
end

function S.setBlackScreen(value)
    value=value==true
    S.blackScreenOnLoad=value
    if not value then
        if S.blackScreenGui then pcall(function() S.blackScreenGui:Destroy() end);S.blackScreenGui=nil end
        return
    end
    if S.blackScreenGui and S.blackScreenGui.Parent then return end
    local parent
    pcall(function() parent=(gethui and gethui()) or game:GetService("CoreGui") end)
    if not parent then parent=player:FindFirstChildOfClass("PlayerGui") end
    if not parent then return end
    local gui=Instance.new("ScreenGui")
    gui.Name="BGS_Personal_BlackScreen"
    gui.IgnoreGuiInset=true
    gui.ResetOnSpawn=false
    gui.DisplayOrder=1000000
    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromScale(1,1)
    frame.BorderSizePixel=0
    frame.BackgroundColor3=Color3.new(0,0,0)
    frame.Parent=gui
    gui.Parent=parent
    S.blackScreenGui=gui
end

S.eggAnimationToggle=ClientTab:CreateToggle({Name="Remove egg open animation(s)",CurrentValue=false,
    Flag="SuppressEggAnimation",Callback=S.setEggAnimationSuppressed})
S.blackScreenToggle=ClientTab:CreateToggle({Name="Black screen (reduce rendering)",CurrentValue=false,
    Flag="BlackScreen",Callback=S.setBlackScreen})

S.optLowQualityToggle=ClientTab:CreateToggle({
    Name = "Minimum graphics quality",
    CurrentValue = false,
    Flag = "OptLowQuality",
    Callback = function(v)
        S.opt.lowQuality = v
        pcall(function()
            local gs = UserSettings():GetService("UserGameSettings")
            if v then
                S.originalQualityLevel = gs.SavedQualityLevel
                gs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            elseif S.originalQualityLevel then
                gs.SavedQualityLevel = S.originalQualityLevel
            end
        end)
    end,
})

S.optNoShadowsToggle=ClientTab:CreateToggle({
    Name = "Disable shadows",
    CurrentValue = false,
    Flag = "OptShadows",
    Callback = function(v)
        S.opt.noShadows = v
        Lighting.GlobalShadows = not v
    end,
})

S.optNoLightingFxToggle=ClientTab:CreateToggle({
    Name = "Disable lighting effects",
    CurrentValue = false,
    Flag = "OptLightingFx",
    Callback = function(v)
        S.opt.noLightingFx = v
        for _, fx in ipairs(Lighting:GetChildren()) do
            if fx:IsA("PostEffect") then fx.Enabled = not v end
        end
    end,
})

S.optNoParticlesToggle=ClientTab:CreateToggle({
    Name = "Disable map particles",
    CurrentValue = false,
    Flag = "OptParticles",
    Callback = function(v)
        S.opt.noParticles = v
        if v then
            table.clear(S.disabledParticleInstances)
            for _, inst in ipairs(Workspace:GetDescendants()) do
                if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
                   or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles") then
                    if inst.Enabled ~= false then
                        table.insert(S.disabledParticleInstances, inst)
                        inst.Enabled = false
                    end
                end
            end
        else
            for _, inst in ipairs(S.disabledParticleInstances) do
                if inst and inst.Parent then inst.Enabled = true end
            end
            table.clear(S.disabledParticleInstances)
        end
    end,
})

S.optMuteAudioToggle=ClientTab:CreateToggle({
    Name = "Mute audio",
    CurrentValue = false,
    Flag = "OptMute",
    Callback = function(v)
        S.opt.muteAudio = v
        pcall(function()
            SoundService.Volume = v and 0 or 1
        end)
    end,
})

S.optHideOtherTagsToggle=ClientTab:CreateToggle({
    Name = "Hide other name tags",
    CurrentValue = false,
    Flag = "OptHideTags",
    Callback = function(v)
        S.opt.hideOtherTags = v
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.DisplayDistanceType = v and Enum.HumanoidDisplayDistanceType.None
                        or Enum.HumanoidDisplayDistanceType.Viewer
                end
            end
        end
    end,
})

------------------------------------------------------------
-- EXTREME
------------------------------------------------------------
ClientTab:CreateSection("Extreme")

S.optNoTerrainDecorationToggle=ClientTab:CreateToggle({
    Name = "Remove terrain decoration",
    CurrentValue = false,
    Flag = "OptTerrain",
    Callback = function(v)
        S.opt.noTerrainDecoration = v
        pcall(function() Workspace.Terrain.Decoration = not v end)
    end,
})

S.optNoSkyToggle=ClientTab:CreateToggle({
    Name = "Remove sky",
    CurrentValue = false,
    Flag = "OptSky",
    Callback = function(v)
        S.opt.noSky = v
        if v then
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if sky then sky:Destroy() end
        end
    end,
})

S.optNoReflectionsToggle=ClientTab:CreateToggle({
    Name = "Reduce reflections",
    CurrentValue = false,
    Flag = "OptReflections",
    Callback = function(v)
        S.opt.noReflections = v
        Lighting.EnvironmentDiffuseScale = v and 0 or 1
        Lighting.EnvironmentSpecularScale = v and 0 or 1
    end,
})

S.optTightStreamingToggle=ClientTab:CreateToggle({
    Name = "Tighter streaming",
    CurrentValue = false,
    Flag = "OptStreaming",
    Callback = function(v)
        S.opt.tightStreaming = v
        pcall(function()
            if v then
                Workspace.StreamingTargetRadius = 128
                Workspace.StreamingMinRadius = 64
            else
                Workspace.StreamingTargetRadius = 1024
                Workspace.StreamingMinRadius = 128
            end
        end)
    end,
})

------------------------------------------------------------
ClientTab:CreateButton({
    Name = "Apply full optimization",
    Callback = function()
        S.opt.fullOptimization = true
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 200
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            for _, fx in ipairs(Lighting:GetChildren()) do
                if fx:IsA("PostEffect") then fx.Enabled = false end
            end
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if sky then sky.Parent = nil end
            if Workspace.Terrain then Workspace.Terrain.Decoration = false end
            pcall(function()
                Workspace.StreamingTargetRadius = 96
                Workspace.StreamingMinRadius = 48
            end)
            for _, inst in ipairs(Workspace:GetDescendants()) do
                if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
                   or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles") then
                    pcall(function() inst.Enabled = false end)
                end
                if inst:IsA("Decal") or inst:IsA("Texture") then
                    pcall(function() inst.Transparency = 1 end)
                end
            end
        end)
        Rayfield:Notify({ Title = "Full Optimization", Content = "Applied. Rejoin to fully restore.", Duration = 4 })
    end,
})

------------------------------------------------------------
-- ANIMATION STATUS
ClientTab:CreateParagraph({Title="Egg animation",
    Content="Blocks egg opening effects and matching animation tracks, including effects created after this toggle is enabled. Game modules are not deleted."})

------------------------------------------------------------
-- MOVEMENT
------------------------------------------------------------
ClientTab:CreateSection("Movement")

ClientTab:CreateSlider({
    Name = "Walk speed",
    Range = {16, 300},
    Increment = 2,
    Suffix = "",
    CurrentValue = 16,
    Flag = "DebugWalkSpeed",
    Callback = function(v)
        S.debugWalkSpeed = v
        S.WALK_SPEED = v
        if S.humanoid then S.humanoid.WalkSpeed = v end
    end,
})

ClientTab:CreateSlider({
    Name = "Jump power",
    Range = {50, 300},
    Increment = 5,
    Suffix = "",
    CurrentValue = 50,
    Flag = "DebugJumpPower",
    Callback = function(v)
        S.debugJumpPower = v
        if S.humanoid then
            S.humanoid.UseJumpPower = true
            S.humanoid.JumpPower = v
        end
    end,
})

ClientTab:CreateToggle({
    Name = "Infinite jump",
    CurrentValue = false,
    Flag = "DebugInfiniteJump",
    Callback = function(v)
        S.infiniteJumpActive = v
        if v then
            S.infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
                if S.humanoid then
                    S.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        elseif S.infiniteJumpConnection then
            S.infiniteJumpConnection:Disconnect()
        end
    end,
})

S.noclipToggleElement = ClientTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "DebugNoclip",
    Callback = function(v)
        S.noclipActive = v
        if v then
            S.noclipConnection = RunService.Stepped:Connect(function()
                local char = player.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end)
        else
            if S.noclipConnection then
                S.noclipConnection:Disconnect()
            end
            local char = player.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end,
})

------------------------------------------------------------
-- LIVE STATS
------------------------------------------------------------
ClientTab:CreateSection("Live Stats")

local statsParagraph = ClientTab:CreateParagraph({
    Title = "Stats",
    Content = "Loading...",
})

local frameCount = 0
local fpsAccum = 0
RunService.RenderStepped:Connect(function(dt)
    frameCount = frameCount + 1
    fpsAccum = fpsAccum + dt
end)

task.spawn(function()
    while true do
        if S.statsTabVisible then
            local fps = 0
            if fpsAccum > 0 then
                fps = math.floor(frameCount / fpsAccum)
            end
            frameCount = 0
            fpsAccum = 0
            local ping = "--"
            pcall(function()
                ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
            end)
            local parts = #Workspace:GetDescendants()
            local mem = 0
            pcall(function()
                mem = Stats:GetTotalMemoryUsageMb()
            end)
            local content = string.format("FPS: %d\nPing: %s\nParts: %d\nMemory: %.1f MB", fps, ping, parts, mem)
            pcall(function()
                statsParagraph:Set({ Title = "Stats", Content = content })
            end)
        end
        task.wait(1)
    end
end)

------------------------------------------------------------
-- UTILITIES
------------------------------------------------------------
ClientTab:CreateSection("Utilities")

ClientTab:CreateButton({
    Name = "Copy current position",
    Callback = function()
        if not S.hrp then
            Rayfield:Notify({ Title = "Copy position", Content = "Character not loaded.", Duration = 3 })
            return
        end
        local pos = S.hrp.Position
        local text = string.format("Vector3.new(%.4f, %.4f, %.4f)", pos.X, pos.Y, pos.Z)
        pcall(function()
            if setclipboard then setclipboard(text) end
        end)
        Rayfield:Notify({ Title = "Position copied", Content = text, Duration = 5 })
    end,
})

ClientTab:CreateButton({
    Name = "Reset character",
    Callback = function()
        pcall(function() player.Character.Humanoid.Health = 0 end)
    end,
})

------------------------------------------------------------
-- CODES
------------------------------------------------------------
CodeTab:CreateSection("Redeem")

local PROMO_CODES = {
    "BGSISBACK", "Celebration", "Update84", "MechRobot", "CrashFix", "Update82",
    "AlienInvasion", "MythicFallenAngel", "Update81", "SorryShutdown", "PermMythic",
    "20HourLuck", "Update78", "FrostPortal", "SuperSpooky", "Update77", "Glitch",
    "Update75", "Easter21", "Update74", "Luckiest", "Update73", "StPatrickLuck",
    "Update72", "BlizzyrdBest", "SylentlyBest", "hiddenvideocode", "Update71",
    "Valentine", "LuckyCode", "RumbleStream", "BlizzyWizzy", "BGSStream",
    "Update70", "Royalty", "Update68", "2020", "SANTACLAUS", "CHRISTMASSTREAM",
    "SUPERBOOST", "JollyChristmas2", "JollyChristmas", "ChristmasPart2", "Update67",
    "Christmas2020", "EpicSecretCode", "BGSXMAS", "Jonathan", "KingSlimeGang",
    "KingMushGang", "ChristmasHype", "HappyHolidays", "RUDOLPH", "MILKANDCOOKIES",
    "StreamLuck", "CANDYCANE", "StreamSpeed", "ShinyStream", "MythicStream",
    "SecretVideoCode", "Update65", "Split", "SylentlyOP", "FreeSpeedBoost",
    "YouTubeLuck", "BlizzyrdOP", "SuperSecretCode", "YouTubeSpeed", "SpookyCode",
    "300k", "Youtube", "Ghosts", "Update64", "Costume", "Update63",
    "SpookyHalloween", "AutumnSale", "AutumnSale2", "Update61", "Autumn",
    "Update60", "Citrus", "Update59", "Vacation", "Update58", "Carnival2",
    "Update57", "Carnival", "MegaLuckBoost", "MegaSpeedBoost", "Update55",
    "SuperSale", "Update54", "Shadow", "Update53", "Meteor", "Update52",
    "Vine", "Update51", "Spring", "Update50", "Mythic", "Update49",
    "Merchant", "Update48", "Season 8", "Update47", "Eeaster2020", "Update46",
    "Mushroom", "Update45", "Mystic", "Season7", "NewEgg", "Challenges",
    "Galactic", "Portal", "LuckyDay2", "FreeSpeed", "MegaSale", "600M",
    "600MBoost", "Valentines", "Cupid", "sircfennerNoob", "Part2", "Clown",
    "Circus", "ChristmasBoost", "HammieIsBadAtRocketLeague", "FreeHatchSpeed",
    "Season3", "Halloween", "TrickOrTreat", "Pass", "Secrets", "BubblePass",
    "Fancy", "Fancy2", "ReallyFancy", "2hourluck", "July4th", "UncleSam",
    "Fireworks", "Summer", "Colorful", "NewWorld", "Kraken", "400m",
    "Thanks", "Mythical", "Tomcat", "AncientTimes", "InThePast", "Ocean",
    "AtlantisHats", "SecretLuckCode", "Bunny", "ChocolateEgg", "HappyEaster",
    "LostCity", "UnderTheSea", "Poseidon", "Special", "Update21", "UltraSpeed",
    "FREE", "ThankYou", "300M", "SpeedyBoi", "StPatricks", "BriteJuice",
    "SecretCode", "SpeedBoost", "sircfenneriscool", "SuperBeach", "BeachBoost",
    "superspeed", "Update16", "LuckyDay", "FreeBoost", "SylentlyIsCool",
    "SuperLuck", "DeeterPlays", "SuperSecret", "SecretBoost", "ExtraLuck",
    "SecretPet", "pinkarmypet", "FreePet", "MoreCandy", "Candy", "BlueCrew",
    "Twiisted", "Santa", "Sylently", "Christmas", "CandyCanes", "SuperCoins",
    "SuperGems", "Spotted", "FreeCoins", "LotsOfGems", "FreeEgg",
    "TwitterRelease", "Sircfenner", "Tofuu", "ObscureEntity", "Minime",
    "TwitchRelease", "Golemite",
}

-- Fix del cooldown (sugerido por un usuario): 3 segundos entre códigos
local REDEEM_DELAY = 3

local function redeemCode(code)
    if not S.NetworkRemoteFunction then return false, "no remote" end
    local ok, result = pcall(function()
        return S.NetworkRemoteFunction:InvokeServer("RedeemCode", code)
    end)
    if ok then return true, tostring(result) end
    return false, tostring(result)
end

CodeTab:CreateButton({
    Name = "Redeem all codes",
    Callback = function()
        task.spawn(function()
            local count = 0
            for i, code in ipairs(PROMO_CODES) do
                local ok, result = redeemCode(code)
                if ok and result and not result:lower():find("invalid") then
                    count = count + 1
                    Rayfield:Notify({
                        Title = string.format("Code %d/%d: %s", i, #PROMO_CODES, code),
                        Content = result,
                        Duration = 4,
                    })
                end
                task.wait(REDEEM_DELAY)
            end
            Rayfield:Notify({
                Title = "Done",
                Content = count .. " valid code(s) redeemed.",
                Duration = 6,
            })
        end)
    end,
})

_G.BGS.modules.client = true
print("[BGS] client loaded (v1.5)")
-- ============ END: client.lua ============
end


modules["premium"]=function()
-- ============ FILE: premium.lua ============
-- BGS BY YAMAHAO V1.8 — Premium Tab (sin restricción).

local S = _G.BGS.shared
local Rayfield = S.Rayfield

local Players = S.Services.Players
local RunService = S.Services.RunService
local Workspace = S.Services.Workspace
local TweenService = S.Services.TweenService

local player = S.player
local PremiumTab = S.PremiumTab

------------------------------------------------------------
-- UNLOCK ALL WORLDS ⭐
------------------------------------------------------------
PremiumTab:CreateSection("Visit world islands")

PremiumTab:CreateParagraph({
    Title = "Premium Feature",
    Content = "Visits known island entry points. Unlock requirements are enforced by the game.",
})

local WORLDS_TO_UNLOCK = {
    { world = "Overworld",       island = "XP Island" },
    { world = "Candy Land",      island = "Sweet Island" },
    { world = "Toy Land",        island = "Treasure Isle" },
    { world = "Beach World",     island = "Sea Shell Isle" },
    { world = "Atlantis",        island = "Sandy Island" },
    { world = "Rainbow Land",    island = "Purple Island" },
    { world = "Underworld",      island = "Molten Island" },
    { world = "Mystic Forest",   island = "Magic Island" },
    { world = "Heaven",          island = "Demon Island" },
}

local TRAVEL_SPEED = 1500
local unlockingAll = false

local function getIslandRoot(worldName, islandName)
    local floating = Workspace:FindFirstChild("FloatingIslands")
    if not floating then return nil end
    local world = floating:FindFirstChild(worldName)
    if not world then return nil end
    local island = world:FindFirstChild(islandName)
    if not island then return nil end
    return island:FindFirstChild("RootPart")
end

local function unlockAllWorldsOnce()
    if unlockingAll then return end
    if not S.hrp then
        Rayfield:Notify({ Title = "Premium", Content = "Character not loaded.", Duration = 3 })
        return
    end
    unlockingAll = true
    S.isTeleporting = true
    S.cancelMovement()
    Rayfield:Notify({ Title = "Premium", Content = "Visiting known island entry points...", Duration = 4 })
    pcall(function()
        for _, entry in ipairs(WORLDS_TO_UNLOCK) do
            local root = getIslandRoot(entry.world, entry.island)
            if root then
                local distance = (S.hrp.Position - root.Position).Magnitude
                local duration = math.max(distance / TRAVEL_SPEED, 0.01)
                local tween = TweenService:Create(
                    S.hrp,
                    TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
                    { CFrame = root.CFrame }
                )
                tween:Play()
                tween.Completed:Wait()
                task.wait(1.5)
            else
                warn("[BGS Premium] Island not found: " .. entry.world .. " / " .. entry.island)
            end
        end
    end)
    S.isTeleporting = false
    unlockingAll = false
    Rayfield:Notify({ Title = "Premium", Content = "Island visit attempt finished; check game unlock status.", Duration = 4 })
end

PremiumTab:CreateButton({
    Name = "Visit world islands ⭐",
    Callback = function()
        task.spawn(unlockAllWorldsOnce)
    end,
})

PremiumTab:CreateSection("Hatch tools")
PremiumTab:CreateButton({Name="Apply measured hatch preset",Callback=S.applyHatchPreset})
PremiumTab:CreateButton({Name="Measure actual egg gain (5 minutes)",Callback=function() S.personalRun("measure") end})
PremiumTab:CreateButton({Name="Stop local automation",Callback=function()
    S.stopAllFeatures()
    if S.autoOpenToggle then S.autoOpenToggle:Set(false) end
    if S.safeNotify then
        S.safeNotify("BGS Personal", "Local automation stopped.", 4)
    end
end})
_G.BGS.modules.premium=true

end


modules["settings"]=function()
-- ============ FILE: settings.lua ============
-- BGS BY YAMAHAO V1.5 — Settings
-- Discord webhook + Excluded Pets + Configs + Executor Info + Shard GUI.

local S = _G.BGS.shared
local Rayfield = S.Rayfield

local Players = S.Services.Players
local UserInputService = S.Services.UserInputService
local Workspace = S.Services.Workspace

local player = S.player
local SettingsTab = S.SettingsTab

------------------------------------------------------------
-- DISCORD WEBHOOK
------------------------------------------------------------
SettingsTab:CreateSection("Discord Webhook")
S.createTextBox(SettingsTab, {Name="Webhook URL (shared)", PlaceholderText="https://discord.com/api/webhooks/...", RemoveTextAfterFocusLost=false, Flag="WebhookUrl", Callback=function(text)
    local value = tostring(text or "")
    S.GLOBAL.webhookUrl = value
    S.safeWriteFile(S.SHARED_WEBHOOK_FILE, { webhookUrl = value })
    S.saveGlobal()
end})
-- The Boost Manager scanner/UI is intentionally disabled.
-- Keep only the shared status webhook queue so unrelated notifications keep working.
local webhookQueue = {}
local webhookQueueRunning = false
local webhookEventHistory = {}
local webhookStats = {sent=0, failed=0}

local STATUS_WEBHOOK_COLORS = {
    Error=0xE74C3C, Status=0x5865F2,
}

local function webhookJobId()
    local id = tostring(game.JobId or "")
    if #id <= 10 then return id end
    return id:sub(1, 5) .. "..." .. id:sub(-4)
end

function isDuplicateEvent(event)
    local previous = webhookEventHistory[event.eventKey]
    if previous and os.clock() - previous < 60 then return true end
    webhookEventHistory[event.eventKey] = os.clock()
    return false
end

local function webhookResponseStatus(response)
    if type(response) ~= "table" then return nil end
    return tonumber(response.StatusCode or response.Status or response.ResponseCode)
end

function sendWebhookWithRetry(payload)
    if not S.HAS_HTTP or not S.GLOBAL.webhookUrl or S.GLOBAL.webhookUrl == "" then return false, "Webhook unavailable" end
    local backoff = {1, 2, 4}
    for attempt = 1, 3 do
        local ok, response = pcall(function() return S.httpPost(S.GLOBAL.webhookUrl, payload) end)
        local status = webhookResponseStatus(response)
        if ok and response ~= nil and (type(response) ~= "table" or response.Success ~= false) and (not status or (status >= 200 and status < 300)) then
            webhookStats.sent += 1
            return true
        end
        if status and status >= 400 and status < 500 and status ~= 429 then break end
        if attempt < 3 then task.wait(backoff[attempt]) end
    end
    webhookStats.failed += 1
    return false, "Webhook request failed"
end

function queueWebhook(payload, event)
    if not payload then return false, "Missing payload" end
    if event and isDuplicateEvent(event) then return false, "Duplicate suppressed" end
    webhookQueue[#webhookQueue + 1] = {payload=payload, event=event}
    if webhookQueueRunning then return true end
    webhookQueueRunning = true
    task.spawn(function()
        while #webhookQueue > 0 do
            local item = table.remove(webhookQueue, 1)
            sendWebhookWithRetry(item.payload)
            task.wait(1)
        end
        webhookQueueRunning = false
    end)
    return true
end

function S.sendStatusWebhook(title, description, color)
    local lower = tostring(title):lower()
    if lower:find("inventory", 1, true) and S.GLOBAL.inventoryWebhook == false then return false, "Inventory alerts disabled" end
    if lower:find("hatch", 1, true) and S.GLOBAL.hatchStatusWebhook == false then return false, "Hatch alerts disabled" end
    local safeDescription = tostring(description or ""):gsub("https?://%S+", "[redacted-url]"):sub(1, 1500)
    local event = {eventType="Status", eventKey="status|" .. tostring(title) .. "|" .. safeDescription}
    local payload = {username="BBG", embeds={{title=tostring(title):sub(1, 200), description=safeDescription, color=color or STATUS_WEBHOOK_COLORS.Status,
        fields={{name="PlaceId",value=tostring(game.PlaceId),inline=true},{name="Server",value=webhookJobId(),inline=true}}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ")}}}
    return queueWebhook(payload, event)
end

SettingsTab:CreateButton({
    Name = "BBG - Webhook test",
    Callback = function()
        if not S.GLOBAL.webhookUrl or S.GLOBAL.webhookUrl == "" then
            Rayfield:Notify({Title="Webhook", Content="No URL set.", Duration=3})
            return
        end
        local ok = pcall(function()
            S.httpPost(S.GLOBAL.webhookUrl, {
                username = "BBG",
                embeds = {{
                    title = "BBG - Webhook test",
                    description = "If you see this, your webhook works.",
                    color = 0x5865F2,
                    timestamp = DateTime.now():ToIsoDate(),
                }},
            })
        end)
        Rayfield:Notify({
            Title = "Webhook",
            Content = ok and "Test sent." or "Failed. Check URL.",
            Duration = 4,
        })
    end,
})

SettingsTab:CreateToggle({Name="Webhook: hatch stopped/errors",CurrentValue=S.GLOBAL.hatchStatusWebhook~=false,Flag="WebhookHatchStatus",Callback=function(v) S.GLOBAL.hatchStatusWebhook=v;S.saveGlobal() end})
SettingsTab:CreateToggle({Name="Webhook: inventory full",CurrentValue=S.GLOBAL.inventoryWebhook~=false,Flag="WebhookInventory",Callback=function(v) S.GLOBAL.inventoryWebhook=v;S.saveGlobal() end})

local WEBHOOK_RARITY_OPTIONS = {
    ["All Legendary"] = 0,
    ["1 in 2,000+ (0.05% or rarer)"] = 2000,
    ["1 in 10,000+ (0.01% or rarer)"] = 10000,
    ["1 in 100,000+ (0.001% or rarer)"] = 100000,
    ["1 in 200,000+ (0.0005% or rarer)"] = 200000,
    ["1 in 500,000+ (0.0002% or rarer)"] = 500000,
    ["1 in 1,000,000+ (0.0001% or rarer)"] = 1000000,
}
local function webhookRarityOptionForValue(value)
    local wanted = tonumber(value) or 500000
    local best, bestDistance = "1 in 500,000+ (0.0002% or rarer)", math.huge
    for label, oneIn in pairs(WEBHOOK_RARITY_OPTIONS) do
        local distance = math.abs(oneIn - wanted)
        if distance < bestDistance then
            best, bestDistance = label, distance
        end
    end
    return best
end
SettingsTab:CreateDropdown({
    Name = "Webhook minimum rarity",
    Options = {
        "All Legendary",
        "1 in 2,000+ (0.05% or rarer)",
        "1 in 10,000+ (0.01% or rarer)",
        "1 in 100,000+ (0.001% or rarer)",
        "1 in 200,000+ (0.0005% or rarer)",
        "1 in 500,000+ (0.0002% or rarer)",
        "1 in 1,000,000+ (0.0001% or rarer)",
    },
    CurrentOption = {webhookRarityOptionForValue(S.GLOBAL.webhookMinRarityOneIn)},
    Flag = "WebhookLegendaryRarity",
    Callback = function(option)
        local label = type(option) == "table" and option[1] or option
        local oneIn = WEBHOOK_RARITY_OPTIONS[label]
        if oneIn == nil then return end
        S.GLOBAL.webhookMinRarityOneIn = oneIn
        S.saveGlobal()
        Rayfield:Notify({Title="Webhook",Content="Minimum rarity: " .. tostring(label),Duration=4})
    end,
})

-- Compatibility surface for older callers. It is intentionally inert so no
-- Boost scan, refresh loop, or descendant connection is created at startup.
S.BoostManager = {
    state = {},
    getActiveBoosts = function() return {} end,
    refresh = function() return false, "Boost Manager disabled" end,
    cleanup = function() end,
}

-- @everyone toggle
local pingOnSecretValue = true
if S.GLOBAL.pingOnSecret ~= nil then
    pingOnSecretValue = S.GLOBAL.pingOnSecret
end

SettingsTab:CreateToggle({
    Name = "@everyone on ultra-rare pets",
    CurrentValue = pingOnSecretValue,
    Flag = "PingOnSecret",
    Callback = function(v)
        S.GLOBAL.pingOnSecret = v
        S.saveGlobal()
        Rayfield:Notify({ Title = "Webhook", Content = v and "@everyone enabled." or "@everyone disabled.", Duration = 3 })
    end,
})

SettingsTab:CreateParagraph({
    Title = "How @everyone works",
    Content = "The webhook will ping @everyone only when the hatched pet has a drop chance lower than 1 in 200,000.",
})

------------------------------------------------------------
-- EXCLUDED PETS (no enviar al webhook)
------------------------------------------------------------
SettingsTab:CreateSection("Excluded Pets")

SettingsTab:CreateParagraph({
    Title = "Pets ignored by the webhook",
    Content = "Pets in this list won't be sent to the webhook when hatched, even if they're legendary or higher.",
})

local function refreshExcludedDropdown()
    pcall(function()
        if not S.excludedPetsDropdown then return end
        local list = S.GLOBAL.excludedPets or {}
        local options = {}
        for _, name in ipairs(list) do
            table.insert(options, name)
        end
        if #options == 0 then
            options = { "(none)" }
        end
        if S.excludedPetsDropdown.SetOptions then
            S.excludedPetsDropdown:SetOptions(options)
            S.excludedPetsDropdown:Set({ options[1] })
        end
    end)
end

S.excludedPetsDropdown = SettingsTab:CreateDropdown({
    Name = "Excluded pet",
    Options = { "(none)" },
    CurrentOption = { "(none)" },
    Flag = "ExcludedPetSelect",
    Callback = function(option)
        S.currentExcludedPet = option[1]
    end,
})

S.createTextBox(SettingsTab, {
    Name = "Add pet to exclusion list",
    PlaceholderText = "Exact pet name (case-sensitive)",
    RemoveTextAfterFocusLost = true,
    Flag = "AddExcludedPet",
    Callback = function(text)
        if not text then return end
        local trimmed = tostring(text):gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed == "" then return end
        if not S.GLOBAL.excludedPets then S.GLOBAL.excludedPets = {} end
        for _, v in ipairs(S.GLOBAL.excludedPets) do
            if v:lower() == trimmed:lower() then
                Rayfield:Notify({ Title = "Excluded Pets", Content = "Already in list.", Duration = 3 })
                return
            end
        end
        table.insert(S.GLOBAL.excludedPets, trimmed)
        S.saveGlobal()
        refreshExcludedDropdown()
        Rayfield:Notify({ Title = "Excluded Pets", Content = "Added: " .. trimmed, Duration = 3 })
    end,
})

SettingsTab:CreateButton({
    Name = "Remove selected pet",
    Callback = function()
        if not S.currentExcludedPet or S.currentExcludedPet == "(none)" then
            Rayfield:Notify({ Title = "Excluded Pets", Content = "No pet selected.", Duration = 3 })
            return
        end
        local list = S.GLOBAL.excludedPets or {}
        local removed = false
        for i, v in ipairs(list) do
            if v == S.currentExcludedPet then
                table.remove(list, i)
                removed = true
                break
            end
        end
        if removed then
            S.saveGlobal()
            refreshExcludedDropdown()
            Rayfield:Notify({ Title = "Excluded Pets", Content = "Removed: " .. S.currentExcludedPet, Duration = 3 })
        end
    end,
})

refreshExcludedDropdown()
S.refreshExcludedDropdown = refreshExcludedDropdown

------------------------------------------------------------
-- CONFIGS
------------------------------------------------------------
SettingsTab:CreateSection("Configs")

local CONFIG_SLOTS = 5

local function captureState()
    return {
        RADIUS = S.RADIUS,
        WALK_SPEED = S.WALK_SPEED,
        TRAVEL_SPEED = S.TRAVEL_SPEED,
        REACH_DIST = S.REACH_DIST,
        COLLECT_ALL = S.COLLECT_ALL,
        MODE = S.MODE,
        selectedEgg = S.selectedEgg,
        multiEgg = S.multiEgg,
        eggInterval = S.eggInterval,
        selectedBox = S.selectedBox,
        boxMulti = S.boxMulti,
        boxInterval = S.boxInterval,
        selectedSellZone = S.selectedSellZone,
        blowInterval = S.blowInterval,
        bubbleSellInterval = S.bubbleSellInterval,
        shardQuestActive = S.shardQuestActive,
        questEggMode = S.questEggMode,
        debugWalkSpeed = S.debugWalkSpeed,
        debugJumpPower = S.debugJumpPower,
        farmActive = S.farmActive,
        wheelIntervalHours = S.wheelIntervalHours,
    }
end

local function applyState(s)
    if not s then return end
    if s.RADIUS then S.RADIUS = s.RADIUS end
    if s.WALK_SPEED then S.WALK_SPEED = s.WALK_SPEED end
    if s.TRAVEL_SPEED then S.TRAVEL_SPEED = s.TRAVEL_SPEED end
    if s.REACH_DIST then S.REACH_DIST = s.REACH_DIST end
    if s.COLLECT_ALL ~= nil then S.COLLECT_ALL = s.COLLECT_ALL end
    if s.MODE then S.MODE = s.MODE end
    if s.selectedEgg then S.selectedEgg = s.selectedEgg end
    if s.multiEgg ~= nil then S.multiEggToggle:Set(s.multiEgg == true) end
    if s.eggInterval then S.eggIntervalSlider:Set(S.setHatchInterval(s.eggInterval)) end
    if s.selectedBox then S.selectedBox = s.selectedBox end
    if s.boxMulti ~= nil then S.boxMulti = s.boxMulti end
    if s.boxInterval then S.boxInterval = s.boxInterval end
    if s.selectedSellZone then S.selectedSellZone = s.selectedSellZone end
    if s.blowInterval then S.blowInterval = s.blowInterval end
    if s.bubbleSellInterval then S.bubbleSellInterval = s.bubbleSellInterval end
    if s.shardQuestActive ~= nil then S.shardQuestActive = s.shardQuestActive end
    if s.questEggMode then S.questEggMode = s.questEggMode end
    if s.debugWalkSpeed then S.debugWalkSpeed = s.debugWalkSpeed end
    if s.debugJumpPower then S.debugJumpPower = s.debugJumpPower end
    if s.farmActive ~= nil then S.farmActive = s.farmActive end
    if s.wheelIntervalHours then S.wheelIntervalHours = s.wheelIntervalHours end
    if S.humanoid then S.humanoid.WalkSpeed = S.debugWalkSpeed end
end

local function saveConfigSlot(slot)
    S.safeWriteFile(S.CONFIG_PREFIX .. slot, captureState())
end

local function loadConfigSlot(slot)
    local data = S.safeReadFile(S.CONFIG_PREFIX .. slot)
    if data then
        applyState(data)
        S.GLOBAL.lastConfigLoaded = slot
        S.saveGlobal()
        return true
    end
    return false
end

S.saveConfigSlot = saveConfigSlot
S.loadConfigSlot = loadConfigSlot

local configOptions = {}
for i = 1, CONFIG_SLOTS do
    table.insert(configOptions, "Config " .. i)
end

SettingsTab:CreateDropdown({
    Name = "Config slot",
    Options = configOptions,
    CurrentOption = { "Config " .. S.currentConfigSlot },
    Flag = "ConfigSlot",
    Callback = function(option)
        local n = tonumber(option[1]:match("%d+"))
        if n then S.currentConfigSlot = n end
    end,
})

SettingsTab:CreateButton({
    Name = "Save config",
    Callback = function()
        saveConfigSlot(S.currentConfigSlot)
        Rayfield:Notify({ Title = "Config", Content = "Saved to slot " .. S.currentConfigSlot, Duration = 3 })
    end,
})

SettingsTab:CreateButton({
    Name = "Load config",
    Callback = function()
        local ok = loadConfigSlot(S.currentConfigSlot)
        if ok then
            Rayfield:Notify({ Title = "Config", Content = "Loaded slot " .. S.currentConfigSlot, Duration = 3 })
        else
            Rayfield:Notify({ Title = "Config", Content = "Slot " .. S.currentConfigSlot .. " empty.", Duration = 3 })
        end
    end,
})

------------------------------------------------------------
-- EXECUTOR INFO
------------------------------------------------------------
SettingsTab:CreateSection("Executor Info")

SettingsTab:CreateParagraph({
    Title = "Capabilities",
    Content = string.format(
        "Hook support: %s\nHTTP support: %s\nFile saving: %s",
        S.HAS_HOOK and "YES" or "NO",
        S.HAS_HTTP and "YES" or "NO",
        S.HAS_FILE and "YES" or "NO"
    ),
})

------------------------------------------------------------
-- SHARD QUEST GUI
------------------------------------------------------------
do
    local guiParent = (gethui and gethui()) or game:GetService("CoreGui")

    S.shardProgressGui = Instance.new("ScreenGui")
    S.shardProgressGui.Name = "ShardQuestProgress"
    S.shardProgressGui.ResetOnSpawn = false
    S.shardProgressGui.DisplayOrder = 998
    S.shardProgressGui.Enabled = false
    S.shardProgressGui.Parent = guiParent

    local win = Instance.new("Frame")
    win.Size = UDim2.new(0, 240, 0, 130)
    win.Position = UDim2.new(1, -260, 0, 20)
    win.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    win.BorderSizePixel = 0
    win.Parent = S.shardProgressGui
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", win)
    stroke.Color = Color3.fromRGB(88, 101, 242)
    stroke.Thickness = 1
    stroke.Transparency = 0.3

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 28)
    topBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    topBar.BorderSizePixel = 0
    topBar.Parent = win
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -34, 1, 0)
    titleLbl.Position = UDim2.new(0, 10, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "Shard Quest"
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextColor3 = Color3.new(1, 1, 1)
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = topBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 20)
    closeBtn.Position = UDim2.new(1, -28, 0.5, -10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    closeBtn.Text = "x"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.TextColor3 = Color3.fromRGB(200, 200, 205)
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = topBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() S.shardProgressGui.Enabled = false end)

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -20, 0, 18)
    statusLbl.Position = UDim2.new(0, 10, 0, 36)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "Status: Idle"
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 12
    statusLbl.TextColor3 = Color3.fromRGB(200, 200, 205)
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = win

    local taskLbl = Instance.new("TextLabel")
    taskLbl.Size = UDim2.new(1, -20, 0, 18)
    taskLbl.Position = UDim2.new(0, 10, 0, 56)
    taskLbl.BackgroundTransparency = 1
    taskLbl.Text = "Quest: None"
    taskLbl.Font = Enum.Font.GothamSemibold
    taskLbl.TextSize = 12
    taskLbl.TextColor3 = Color3.fromRGB(255, 200, 80)
    taskLbl.TextXAlignment = Enum.TextXAlignment.Left
    taskLbl.Parent = win

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -20, 0, 8)
    barBg.Position = UDim2.new(0, 10, 0, 82)
    barBg.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    barBg.BorderSizePixel = 0
    barBg.Parent = win
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

    local percentLbl = Instance.new("TextLabel")
    percentLbl.Size = UDim2.new(1, -20, 0, 16)
    percentLbl.Position = UDim2.new(0, 10, 0, 96)
    percentLbl.BackgroundTransparency = 1
    percentLbl.Text = "0%"
    percentLbl.Font = Enum.Font.Gotham
    percentLbl.TextSize = 11
    percentLbl.TextColor3 = Color3.fromRGB(160, 160, 170)
    percentLbl.TextXAlignment = Enum.TextXAlignment.Left
    percentLbl.Parent = win

    local dragging = false
    local dragStart = nil
    local startPos = nil

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = win.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    S.updateShardProgressWindow = function()
        statusLbl.Text = "Status: " .. S.shardQuestStatus
        taskLbl.Text = "Quest: " .. S.shardQuestTaskName
        percentLbl.Text = S.shardQuestPercent .. "%"
        local scale = math.clamp(S.shardQuestPercent / 100, 0, 1)
        barFill.Size = UDim2.new(scale, 0, 1, 0)
    end
end

------------------------------------------------------------
-- Config slots are manual. Loading a config never automatically starts hatching.

_G.BGS.modules.settings = true
print("[BGS] settings loaded (v1.5)")
-- ============ END: settings.lua ============
end


helpers["bridge_check"]=function()
-- Diagnose HTTP from Delta. GET /status and harmless POST /diagnostic/echo only.
-- No remote downloads, credentials, lag activation, or account changes.
local bgs = _G.BGS
assert(bgs and bgs.shared, "Open BGS first")
local S = bgs.shared
local Http = S.Services.HttpService
local candidates, seen, report = {}, {}, {}
local function add(name, fn, getOnly)
    if type(fn) == "function" and not seen[fn] then
        seen[fn] = true
        table.insert(candidates, {name = name, fn = fn, getOnly = getOnly})
    end
end
add("request", request)
add("http_request", http_request)
if type(http) == "table" then add("http.request", http.request) end
if type(syn) == "table" then add("syn.request", syn.request) end
add("game:HttpGet", function(opts) return game:HttpGet(opts.Url) end, true)

local function log(line)
    line = tostring(line):sub(1, 700)
    table.insert(report, line)
    print("[BGS Bridge Check] " .. line)
end
local function persist()
    S.clumsyDiagnostics = table.concat(report, "\n")
    if type(writefile) == "function" then
        pcall(writefile, "BGS_Bridge_diagnostic.txt", S.clumsyDiagnostics)
    end
end
local function call(candidate, base, path, method, body)
    if candidate.getOnly and method ~= "GET" then
        return false, "Only GET works through game:HttpGet; POST controls unavailable"
    end
    local opts = {Url = base .. path, Method = method}
    -- Delta variants may reject an empty/nil body or JSON headers on GET.
    if method ~= "GET" then
        opts.Headers = {["Content-Type"] = "application/json"}
        opts.Body = body and Http:JSONEncode(body) or "{}"
    end
    local ok, response = pcall(candidate.fn, opts)
    if not ok then return false, "exception: " .. tostring(response) end
    local text, status
    if type(response) == "string" then
        text = response
    elseif type(response) == "table" then
        text = response.Body or response.body
        status = tonumber(response.StatusCode or response.status_code or response.Status)
        if status and (status < 200 or status >= 300) then
            return false, "HTTP " .. tostring(status)
        end
    else
        return false, "response type: " .. type(response)
    end
    if type(text) ~= "string" then return false, "response has no string Body" end
    local decoded, data = pcall(function() return Http:JSONDecode(text) end)
    if not decoded or type(data) ~= "table" then return false, "invalid JSON response" end
    if path == "/status" and data.service ~= "BGS-local-bridge" then
        return false, "unexpected service; no controls installed"
    end
    if data.ok ~= true then return false, tostring(data.error or data.reason or "ok is not true") end
    return true, data
end

-- Clear old bridge transports before probing a replacement bridge.
S.bgsHatchUpdate=nil
local picked, pickedBase, lastData
for _, candidate in ipairs(candidates) do
    for _, base in ipairs({"http://127.0.0.1:17322", "http://localhost:17322"}) do
        local ok, data = call(candidate, base, "/status", "GET")
        log(candidate.name .. " " .. base .. " -> " .. (ok and ("OK mode=" .. tostring(data.mode)) or tostring(data)))
        if ok then
            picked, pickedBase, lastData = candidate, base, data
            break
        end
    end
    if picked then break end
end

local postPicked
if picked then
    S.bgsHatchUpdate = function(body)
        if not postPicked then return false, "POST unavailable" end
        return call(postPicked, pickedBase, "/hatch/update", "POST", body)
    end
    local postCandidates = {}
    if not picked.getOnly then table.insert(postCandidates, picked) end
    table.insert(postCandidates, {name = "game:HttpPost JSON", fn = function(opts)
        return game:HttpPost(opts.Url, opts.Body, "application/json")
    end})
    table.insert(postCandidates, {name = "game:HttpPost default", fn = function(opts)
        return game:HttpPost(opts.Url, opts.Body)
    end})
    table.insert(postCandidates, {name = "HttpService:RequestAsync", fn = function(opts)
        return Http:RequestAsync(opts)
    end})
    for _, candidate in ipairs(postCandidates) do
        local ok, data = call(candidate, pickedBase, "/diagnostic/echo", "POST", {probe = "delta-post-v1"})
        if ok and (data.service ~= "BGS-local-bridge" or data.probe ~= "delta-post-v1") then
            ok, data = false, "probe reply mismatch"
        end
        log(candidate.name .. " POST probe -> " .. (ok and "OK" or tostring(data)))
        if ok then postPicked = candidate; break end
    end
end

local message
if picked then
    -- The bridge is used only for status and the optional egg counter.
    S.clumsyPing = function() return call(picked, pickedBase, "/status", "GET") end
    message = "Connected via " .. picked.name .. "\nMode: " .. tostring(lastData.mode)
    if postPicked then message ..= "\nPOST bridge: " .. postPicked.name
    else message ..= "\nGET only; egg counter POST unavailable." end
    if lastData.mode == "simulation" then message ..= "\nSimulation changes no packets." end
    message ..= "\nPress Refresh status."
else
    message = "Delta could not reach the local bridge.\nDetails: BGS_Bridge_diagnostic.txt"
    -- Expose the actual failure through the existing Refresh status button.
    local detail = report[#report] or "No HTTP provider available"
    S.clumsyPing = function() return false, detail end
end
log(message)
persist()
if S.PremiumTab then
    pcall(function()
        local value = {Title = "Bridge diagnostic", Content = message}
        if S.clumsyDiagnosticParagraph then S.clumsyDiagnosticParagraph:Set(value)
        else S.clumsyDiagnosticParagraph = S.PremiumTab:CreateParagraph(value) end
    end)
end
if S.Rayfield then
    pcall(function() S.Rayfield:Notify({Title = "Bridge diagnostic", Content = message, Duration = 10}) end)
end

end


helpers["companion"]=function()
-- Connect the Premium tab and PC panel to the same bridge and live egg counter.
-- Does not enable Auto open, Lag, or start experiments on load.
local S=assert(_G.BGS and _G.BGS.shared,"Open BGS first")
assert(S.PremiumTab,"Open Premium first")
assert(type(S.bgsHatchUpdate)=="function","Run the updated BGS_Bridge_check.lua first")
local ok,state=S.clumsyPing()
assert(ok and state.companion_version==1,"Restart bridge with the updated launcher first")
S.companionGeneration=(S.companionGeneration or 0)+1
local generation=S.companionGeneration
local Http=S.Services.HttpService
local session=Http:GenerateGUID(false)
local started=os.clock();local seq=0;local last=nil
local function trial()
    if S.hatchPairRunning then return 'pair' end
    if S.hatchTuneRunning then return 'tune' end
    if S.hatchTraceRunning then return 'trace' end
    if S.hatchMeasurementRunning then return 'measure' end
    if S.bufferTrialRunning then return 'buffer' end
    return 'idle'
end
local paragraph=S.companionParagraph
if not paragraph then
    paragraph=S.PremiumTab:CreateParagraph({Title="PC companion",Content="Connecting egg counter..."})
    S.companionParagraph=paragraph
end
local function show(text) pcall(function() paragraph:Set({Title="PC companion",Content=text}) end) end
if not S.companionButtonsLoaded then
    S.PremiumTab:CreateButton({Name="Companion: run pair timing test (90s)",Callback=function()
        if S.hatchPairRunning then show("Pair test is already running");return end
        local success,err=pcall(function() local ok,err=S.personalRun("pair"); assert(ok,err) end)
        if not success then show(tostring(err)) end
    end})
    S.PremiumTab:CreateButton({Name="Companion: cancel pair test",Callback=function()
        if S.hatchPairRunning and S.hatchPairStop then S.hatchPairStop() end
    end})
    S.companionButtonsLoaded=true
end
task.spawn(function()
    while generation==S.companionGeneration do
        local success,err=pcall(function()
            local total=assert(tonumber(S.readLeaderstat("Eggs Opened")),"Egg counter unavailable")
            if last and total<last then session=Http:GenerateGUID(false);started=os.clock();seq=0 end
            last=total;seq+=1
            local result=S.hatchPairLastResult
            local resultText=''
            if result then
                resultText=result.complete and string.format('Pair test: normal %.0f/h; paired %.0f/h (short trial)',result.normalHourly,result.pairedHourly)
                    or ('Pair test incomplete: '..tostring(result.error))
                resultText=string.sub(resultText,1,230)
            end
            local posted,response=S.bgsHatchUpdate({session=session,seq=seq,seconds=os.clock()-started,total=total,
                egg=tostring(S.selectedEgg or ''),interval=tonumber(S.eggInterval) or 0,
                auto_open=S.eggOpenActive==true,trial=trial(),last_result=resultText})
            assert(posted and type(response)=='table',"Companion disconnected: "..tostring(response))
            local h=response.hatch
            local rate=h and h.rate_ready and string.format('%.0f eggs/h (recent 60s)',h.projected_hourly) or 'Measuring first 60 seconds...'
            show('PC + Premium connected | '..tostring(response.mode)..' / '..tostring(response.phase)..'\n'..rate..'\nTarget: 10,000/h; measured result required')
        end)
        if not success then show(tostring(err)) end
        task.wait(2)
    end
end)

end


helpers["measure"]=function()
-- Observe 5 minutes of the replicated egg counter. Does not buy eggs or start lag.
local S = assert(_G.BGS and _G.BGS.shared, "Open BGS first")
assert(type(S.readLeaderstat) == "function", "BGS counter reader is unavailable")
if S.hatchMeasurementRunning then warn("A hatch measurement is already running"); return end
local initial = tonumber(S.readLeaderstat("Eggs Opened"))
assert(initial, "Eggs Opened is not available yet")
local Http = S.Services.HttpService
local function settings()
    return {egg=tostring(S.selectedEgg),box=tostring(S.selectedBox),
        multiEgg=S.multiEgg == true,multiBox=S.boxMulti == true,
        eggInterval=S.eggInterval,boxInterval=S.boxInterval,
        eggsActive=S.eggOpenActive == true,boxesActive=S.boxOpenActive == true}
end
local data = {version=1,startedAt=os.time(),durationRequested=300,startEggs=initial,
    settings=settings(),samples={},complete=false,
    note="Counts come from the replicated Eggs Opened stat; hourly values are projections, not one-hour measurements."}
S.hatchMeasurementRunning = true
local paragraph
if S.HatchTab then
    pcall(function()
        if S.hatchMeasurementParagraph then paragraph=S.hatchMeasurementParagraph
        else
            paragraph=S.HatchTab:CreateParagraph({Title="5-minute hatch measurement",Content="Starting..."})
            S.hatchMeasurementParagraph=paragraph
        end
    end)
end
local function save()
    if type(writefile) == "function" then
        local ok,err=pcall(function() writefile("BGS_Hatch_measurement.json",Http:JSONEncode(data)) end)
        if not ok then warn("Measurement save failed: "..tostring(err)) end
    end
end
task.spawn(function()
    local ok,err=pcall(function()
        local started=os.clock()
        local last=initial
        while true do
            task.wait(1)
            local elapsed=os.clock()-started
            local count=tonumber(S.readLeaderstat("Eggs Opened"))
            assert(count,"Egg counter disappeared; measurement stopped")
            assert(count>=last,"Egg counter decreased; measurement invalidated")
            last=count
            local sample={seconds=elapsed,eggs=count,settings=settings()}
            table.insert(data.samples,sample)
            data.elapsed=elapsed
            data.gained=count-initial
            data.projectedPerHour=data.gained/elapsed*3600
            data.complete=elapsed>=300
            if paragraph then
                paragraph:Set({Title="5-minute hatch measurement",Content=string.format(
                    "%s: %.0f / 300 seconds\nActual gain: %d eggs\nAverage: %.2f eggs/s\nProjected rate: %.0f/h\nThis is not a completed one-hour run.",
                    data.complete and "Finished" or "Measuring",elapsed,data.gained,data.gained/elapsed,data.projectedPerHour)})
            end
            if #data.samples%10==0 or data.complete then save() end
            if data.complete then break end
        end
    end)
    if not ok then data.error=tostring(err); data.complete=false; warn(data.error) end
    S.hatchMeasurementRunning=false
    S.hatchMeasurementResult=data
    save()
    print("[BGS Measure] "..(data.complete and "Finished" or "Stopped").."; report: BGS_Hatch_measurement.json")
end)
print("[BGS Measure] Observing 5 minutes. Gameplay and lag settings were not changed.")

end


helpers["pair"]=function()
-- A/B/A timing experiment. Groups at most two existing selected-egg calls.
-- Never creates extra hatch calls or changes their arguments. Restores normal timing.
local S=assert(_G.BGS and _G.BGS.shared,"Open BGS first")
assert(not S.hatchPairRunning and not S.hatchTraceRunning and not S.hatchTuneRunning and
    not S.hatchABRunning and not S.hatchMeasurementRunning and not S.bufferTrialRunning,"Finish other trials first")
assert(S.eggOpenActive,"Enable Auto open first")
assert(type(S.clumsyPing)=="function","Run BGS_Bridge_check.lua first")
local function idle()
    local ok,state=S.clumsyPing()
    assert(ok and type(state)=="table" and not state.lag_active,"Stop Lag / Buffer first; bridge must be reachable")
end
idle()
local function count() return assert(tonumber(S.readLeaderstat("Eggs Opened")),"Egg counter unavailable") end
count()
local original=assert(S.NetworkRemoteEvent,"Remote unavailable")
local frozen={egg=S.selectedEgg,box=S.selectedBox,multi=S.multiEgg,interval=S.eggInterval,
    boxActive=S.boxOpenActive,boxInterval=S.boxInterval,boxMulti=S.boxMulti}
assert(tonumber(frozen.interval) and frozen.interval<=.15,"Pair trial requires Interval <= 0.15 seconds")
local pairWait=math.clamp(frozen.interval*1.8,.06,.3)
local report={version=1,startedAt=os.time(),settings=frozen,stages={},complete=false,
    batchSize=2,flushAfterSeconds=pairWait,
    note="Client call timing only; no extra requests. Counter replication is not a per-call server acknowledgement."}
local paragraph=S.hatchPairParagraph
if not paragraph then
    paragraph=S.HatchTab:CreateParagraph({Title="Hatch pair trial",Content="Preparing A/B/A timing trial"})
    S.hatchPairParagraph=paragraph
end
local function show(text)
    pcall(function() paragraph:Set({Title="Hatch pair trial",Content=text}) end)
    print("[BGS Pair] "..text)
end
local stage,pending,sendError=nil,nil,nil
local function send(args,owner)
    if owner then owner.dispatched+=1 end
    local result=table.pack(pcall(function() return original:FireServer(table.unpack(args,1,args.n)) end))
    if not result[1] then
        sendError=tostring(result[2])
        if owner then owner.errors+=1 end
    end
    return result
end
local function flush()
    if not pending then return end
    local item=pending;pending=nil
    item.owner.singleFlushes+=1
    item.owner.maxWaitSeconds=math.max(item.owner.maxWaitSeconds,os.clock()-item.time)
    send(item.args,item.owner)
end
local proxy={}
function proxy:FireServer(...)
    local args=table.pack(...)
    if not stage or args[1]~="PurchaseEgg" or args[2]~=frozen.egg then
        return original:FireServer(table.unpack(args,1,args.n))
    end
    local owner=stage;owner.observed+=1
    if owner.mode=="paired" and not sendError then
        if pending then
            local item=pending;pending=nil
            owner.pairs+=1
            owner.maxWaitSeconds=math.max(owner.maxWaitSeconds,os.clock()-item.time)
            send(item.args,item.owner);send(args,owner)
        else
            local item={args=args,owner=owner,time=os.clock()}
            pending=item
            task.delay(pairWait,function() if pending==item then flush() end end)
        end
        return
    end
    local result=send(args,owner)
    if not result[1] then error(result[2],0) end
    return table.unpack(result,2,result.n)
end
setmetatable(proxy,{__index=function(_,key)
    local value=original[key]
    if type(value)=="function" then return function(_,...) return value(original,...) end end
    return value
end})
local function guard()
    assert(not S.hatchPairCancel,"Cancelled")
    assert(not sendError,"Call error: "..tostring(sendError))
    assert(S.NetworkRemoteEvent==proxy,"Remote reference changed")
    assert(S.eggOpenActive,"Auto open stopped")
    assert(not S.hatchTraceRunning and not S.hatchTuneRunning and not S.hatchABRunning and
        not S.hatchMeasurementRunning and not S.bufferTrialRunning,"Another trial started")
    assert(S.selectedEgg==frozen.egg and S.selectedBox==frozen.box and S.multiEgg==frozen.multi and
        S.eggInterval==frozen.interval and S.boxOpenActive==frozen.boxActive and
        S.boxInterval==frozen.boxInterval and S.boxMulti==frozen.boxMulti,"Hatch settings changed")
end
S.hatchPairRunning=true;S.hatchPairCancel=false
S.hatchPairStop=function() S.hatchPairCancel=true;flush() end
S.NetworkRemoteEvent=proxy
task.spawn(function()
    local ok,err=pcall(function()
        for index,mode in ipairs({"normal","paired","normal"}) do
            guard();idle()
            local first=count();local clock=os.clock();local last=first;local nextCheck=5
            stage={mode=mode,observed=0,dispatched=0,errors=0,pairs=0,singleFlushes=0,maxWaitSeconds=0}
            table.insert(report.stages,stage)
            repeat
                task.wait(.1);guard()
                local value=count();assert(value>=last,"Egg counter decreased");last=value
                stage.seconds=os.clock()-clock;stage.eggs=value-first
                if stage.seconds>=nextCheck then
                    idle();nextCheck=stage.seconds+5
                    show(string.format("Stage %d/3: %s\n%.0f/30 seconds; +%d eggs\nCalls received/sent: %d/%d",index,mode,stage.seconds,stage.eggs,stage.observed,stage.dispatched))
                end
            until stage.seconds>=30
            flush();guard()
            stage.seconds=os.clock()-clock;stage.eggs=count()-first
            stage.projectedHourly=stage.eggs/stage.seconds*3600
            assert(stage.observed==stage.dispatched,"Call counts differ")
            if mode=="paired" then assert(stage.pairs>0,"No pairs formed; calls are too far apart") end
            stage=nil
        end
        local a,b,c=table.unpack(report.stages)
        report.normalHourly=(a.eggs+c.eggs)/(a.seconds+c.seconds)*3600
        report.pairedHourly=b.projectedHourly
        report.complete=true
    end)
    flush();stage=nil
    if S.NetworkRemoteEvent==proxy then S.NetworkRemoteEvent=original;report.referenceRestored=true
    else report.referenceRestored=false end
    S.hatchPairRunning=false
    if not ok then report.error=tostring(err) end
    S.hatchPairLastResult=report
    local saved,saveErr=pcall(function() writefile("BGS_Hatch_pair_trial.json",S.Services.HttpService:JSONEncode(report)) end)
    local summary=ok and string.format("Finished; normal timing restored\nNormal: %.0f/h; paired: %.0f/h\nShort A/B/A trial, not proof of bypass.",report.normalHourly,report.pairedHourly)
        or ("Stopped: "..tostring(err).."\nPending calls flushed; observer removed if still owned.")
    show(summary.."\n"..(saved and "Saved BGS_Hatch_pair_trial.json" or ("Save failed: "..tostring(saveErr))))
end)

end

modules["chestscanner"]=function()
-- ============ FILE: chestscanner.lua ============
-- Chest Scanner adapted from ChestScanner.client.luau.
-- Scanning is read-only. Auto Chest only moves to scanned targets; it does
-- not open or collect rewards.

local S = _G.BGS.shared
local FarmTab = S.FarmTab
local Workspace = S.Services.Workspace
local CollectionService = game:GetService("CollectionService")

-- Full Workspace scans are relatively expensive. Route validation still runs
-- before every TP, so a slightly slower refresh avoids periodic frame spikes
-- without delaying safety checks.
local SCAN_INTERVAL = 8
local MAX_RESULTS = 200
local MAX_DISPLAY_RESULTS = 40
local maxChestScanDistance = 1000000
local EXPECTED_CHESTS_PER_WORLD = 3
local EXPECTED_CHEST_WORLDS = {
    "Candy land",
    "Toy land",
    "Beach world",
    "Atlantis",
    "Rainbow land",
    "Underworld",
    "Mystic forest",
    "Heaven",
}

local autoScan = false
local scanning = false
local workerRunning = false
local workerToken = 0
local stopped = false
local resultsParagraph
local cooldownParagraph
local chestRouteParagraph
local teleportStatusParagraph
local lastResultsTitle
local lastResultsContent
local lastCooldownContent
local lastRouteContent
local autoScanToggle
local lastResults = {}
local lastScanAt = 0
local lastTeleportAt = 0
local MANUAL_TELEPORT_COOLDOWN = 0.75
local autoTeleportActive = false
local autoTeleportWorkerRunning = false
local autoTeleportToken = 0
local autoTeleportDelay = 0.75
local autoVisited = {}
local autoCooldownBlockedUntil = {}
local autoFailedUntil = {}
local autoSkipped = {}
local autoChestLastSafePivot
local autoChestRecoveryPending = false
local chestSafeMargin = 0.25
local renderAutoRouteProgress
local autoTeleportToggle

local function isSafeAutoChestPivot(pivot)
    if typeof(pivot) ~= "CFrame" then
        return false
    end
    local position = pivot.Position
    if position.Y < -500 then
        return false
    end
    local ok, allowed = pcall(function()
        return isPositionInsideAllowedMap(position)
    end)
    return ok and allowed == true
end

local function captureAutoChestSafePivot(pivot)
    if autoTeleportActive and isSafeAutoChestPivot(pivot) then
        autoChestLastSafePivot = pivot
        autoChestRecoveryPending = false
    end
end

local function normalized(value)
    return string.lower(string.gsub(tostring(value or ""), "%s+", ""))
end

local function compactName(value)
    return string.lower((tostring(value or ""):gsub("[%s_%-%p]", "")))
end

local function isActivationTrigger(instance)
    local ancestor = instance
    while ancestor and ancestor ~= Workspace do
        local key = compactName(ancestor.Name)
        if key == "activation" or key == "activations" then
            return true
        end
        ancestor = ancestor.Parent
    end
    return false
end

local function isExcludedChestContainer(instance)
    local ancestor = instance
    while ancestor and ancestor ~= Workspace do
        local key = compactName(ancestor.Name)
        if key == "checkpoint" or key == "checkpoints" then
            return true
        end
        ancestor = ancestor.Parent
    end
    return false
end

local KNOWN_CHEST_TYPES = {
    magicchest = "Magic Chest",
    moltenchest = "Molten Chest",
    mythicchest = "Mythic Chest",
    purplechest = "Purple Chest",
    redchest = "Red Chest",
    sandychestatlantisworld = "Sandy Chest (Atlantis World)",
    sandychestbeachworld = "Sandy Chest (Beach World)",
    santachest = "Santa Chest",
    seachest = "Sea Chest",
    shellchest = "Shell Chest",
    skychest = "Sky Chest",
    sweetchest = "Sweet Chest",
    toybox = "Toy Box",
    treasurechest = "Treasure Chest",
    voidchest = "Void Chest",
    waterchest = "Water Chest",
    xpchest = "XP Chest",
    angelchest = "Angel Chest",
    atlantischest = "Atlantis Chest",
    blockychest = "Blocky Chest",
    bluechest = "Blue Chest",
    candychestcandyland = "Candy Chest (Candy Land)",
    candychestchristmasworld = "Candy Chest (Christmas World)",
    crystalchest = "Crystal Chest",
    demonchest = "Demon Chest",
    festivechest = "Festive Chest",
    firechest = "Fire Chest",
    godlychest = "Godly Chest",
    gummychest = "Gummy Chest",
    heavenchest = "Heaven Chest",
    infernochest = "Inferno Chest",
}

local function getKnownChestType(instance)
    if not instance then
        return nil
    end
    local function lookup(target)
        local candidates = {
            target.Name,
            target:GetAttribute("DisplayName"),
            target:GetAttribute("ChestName"),
        }
        for _, value in ipairs(candidates) do
            local key = compactName(value)
            if KNOWN_CHEST_TYPES[key] then
                return KNOWN_CHEST_TYPES[key]
            end
        end
        return nil
    end

    -- Keep this lookup local to the candidate itself. Scanning every
    -- descendant of every Model would add avoidable work to each rescan.
    return lookup(instance)
end

local function getChestWorldName(instance, knownChestType)
    local path = compactName(
        instance:GetFullName()
            .. " " .. tostring(instance:GetAttribute("DisplayName") or "")
            .. " " .. tostring(knownChestType or getKnownChestType(instance) or "")
    )
    for _, worldName in ipairs(EXPECTED_CHEST_WORLDS) do
        if string.find(path, compactName(worldName), 1, true) then
            return worldName
        end
    end
    return "Other"
end

local function looksLikeChest(instance)
    local name = normalized(instance.Name)
    return getKnownChestType(instance) ~= nil
        or name == "chest"
        or name == "toybox"
        or name == "treasurechest"
        or name == "crate"
        or string.find(name, "chest", 1, true) ~= nil
        or string.find(name, "crate", 1, true) ~= nil
end

local function isTaggedChest(instance)
    local ok, tagged = pcall(function()
        return CollectionService:HasTag(instance, "Chest")
            or CollectionService:HasTag(instance, "TreasureChest")
    end)
    return ok and tagged == true
end

local function hasTaggedChestDescendant(instance)
    if not instance or not instance:IsA("Model") then
        return false
    end
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("BasePart") and isTaggedChest(descendant) then
            return true
        end
    end
    return false
end

local function canonicalChest(instance)
    if instance:IsA("BasePart") then
        local model = instance:FindFirstAncestorWhichIsA("Model")
        if model and (looksLikeChest(model) or isTaggedChest(model) or hasTaggedChestDescendant(model)) then
            return model
        end
    end
    return instance
end

local function getChestInteractionPart(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if not instance:IsA("Model") then
        return nil
    end

    -- Prefer the actual interaction geometry over a particle/effect part or
    -- an oversized model bounding box. Different map revisions use one of
    -- these conventional names.
    for _, name in ipairs({"Chest", "Hitbox", "Interaction", "RootPart", "Base", "Part"}) do
        local candidate = instance:FindFirstChild(name, true)
        if candidate and candidate:IsA("BasePart") then
            return candidate
        end
    end
    if instance.PrimaryPart then
        return instance.PrimaryPart
    end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function getPosition(instance)
    if instance:IsA("BasePart") then
        return instance.Position
    end
    if instance:IsA("Model") then
        local root = getChestInteractionPart(instance)
        if root then
            return root.Position
        end
        local ok, boxCFrame = pcall(function()
            return instance:GetBoundingBox()
        end)
        if ok and boxCFrame then
            return boxCFrame.Position
        end
    end
    return nil
end

local function isSafeChestMapPosition(position)
    if typeof(position) ~= "Vector3" or position.Y < -500 then
        return false
    end
    local ok, allowed = pcall(function()
        return isPositionInsideAllowedMap(position)
    end)
    return ok and allowed == true
end

local function getDisplayName(instance)
    local displayName = instance:GetAttribute("DisplayName")
    local path = instance:GetFullName()
    if type(displayName) == "string" and displayName ~= "" then
        return displayName .. " | " .. path
    end
    return path
end

local COOLDOWN_REMAINING_NAMES = {
    "Cooldown",
    "ChestCooldown",
    "CooldownRemaining",
    "ChestCooldownRemaining",
    "CooldownSeconds",
    "RemainingCooldown",
}

local COOLDOWN_END_NAMES = {
    "CooldownUntil",
    "CooldownEndsAt",
    "CooldownEnd",
    "NextAvailableAt",
    "NextOpenAt",
    "NextCollectAt",
    "AvailableAt",
}

local COOLDOWN_FLAG_NAMES = {
    "OnCooldown",
    "CooldownActive",
    "IsOnCooldown",
    "ChestOnCooldown",
}

local function getServerNow()
    local ok, value = pcall(function()
        return Workspace:GetServerTimeNow()
    end)
    if ok and type(value) == "number" then
        return value
    end
    return os.time()
end

local function getNumericValueObject(instance, name, recursive)
    local child = instance:FindFirstChild(name, recursive == true)
    if not child then
        return nil
    end
    if child:IsA("NumberValue") or child:IsA("IntValue") then
        return tonumber(child.Value)
    end
    if child:IsA("BoolValue") then
        return child.Value == true
    end
    if child:IsA("StringValue") then
        local text = tostring(child.Value or "")
        local number = tonumber(text)
        if number then
            return number
        end
        if string.lower(text) == "true" then
            return true
        end
        if string.lower(text) == "false" then
            return false
        end
    end
    return nil
end

local function getCooldownSources(instance)
    local sources = {}
    local seen = {}
    local function addSource(source)
        if source and not seen[source] then
            seen[source] = true
            table.insert(sources, source)
        end
    end

    addSource(instance)
    local model = instance:IsA("Model") and instance or instance:FindFirstAncestorOfClass("Model")
    addSource(model)

    -- In the older Chest layout, cooldown/Collected attributes may live on
    -- the Chest folder or the island object rather than on the visible part.
    local ancestor = instance.Parent
    local depth = 0
    while ancestor and ancestor ~= Workspace and depth < 4 do
        addSource(ancestor)
        ancestor = ancestor.Parent
        depth = depth + 1
    end
    return sources
end

local function getCooldownRaw(source, name, recursive)
    local raw = source:GetAttribute(name)
    if raw == nil then
        raw = getNumericValueObject(source, name, recursive)
    end
    if type(raw) == "string" then
        local number = tonumber(raw)
        if number then
            return number
        end
        local normalizedRaw = string.lower(raw)
        if normalizedRaw == "true" then
            return true
        end
        if normalizedRaw == "false" then
            return false
        end
    end
    return raw
end

local function getCooldownRemaining(instance)
    if not instance then
        return nil, nil
    end

    local sources = getCooldownSources(instance)
    local primaryModel = instance:IsA("Model") and instance
        or instance:FindFirstAncestorOfClass("Model")
    local function readCooldownValue(source, name)
        -- Only the Chest instance and its owning Model may search descendants.
        -- Searching through an island ancestor can accidentally read another
        -- Chest's Cooldown Value and make this target look unavailable.
        local recursive = source == instance or source == primaryModel
        return getCooldownRaw(source, name, recursive)
    end
    for _, source in ipairs(sources) do
        for _, name in ipairs(COOLDOWN_FLAG_NAMES) do
            local raw = readCooldownValue(source, name)
            if raw == true then
                return math.huge, name
            end
        end
    end

    for _, source in ipairs(sources) do
        for _, name in ipairs(COOLDOWN_REMAINING_NAMES) do
            local raw = readCooldownValue(source, name)
            if raw == true then
                return math.huge, name
            end
            if type(raw) == "number" and raw > 0 then
                -- Large values are treated as an absolute server timestamp;
                -- normal-sized values are treated as remaining seconds.
                if raw > 100000000 then
                    local remaining = raw - getServerNow()
                    if remaining > 0 then
                        return remaining, name
                    end
                else
                    return raw, name
                end
            end
        end
    end

    local now = getServerNow()
    for _, source in ipairs(sources) do
        for _, name in ipairs(COOLDOWN_END_NAMES) do
            local raw = readCooldownValue(source, name)
            if type(raw) == "number" then
                local remaining = raw - now
                if remaining > 0 then
                    return remaining, name
                end
            end
        end
    end

    return nil, nil
end

local COLLECT_KEY_ATTRIBUTES = {
    "ChestId",
    "ChestID",
    "CollectId",
    "CollectID",
    "ChestName",
    "IslandName",
    "CollectName",
    "RewardName",
}

local function appendUniqueString(list, value)
    if type(value) ~= "string" or value == "" then
        return
    end
    for _, existing in ipairs(list) do
        if existing == value then
            return
        end
    end
    table.insert(list, value)
end

local function getLegacyCollectKeys(instance)
    local keys = {}
    if not instance then
        return keys
    end

    local function addContainerKey(container)
        if not container or container == Workspace then
            return
        end
        local containerName = normalized(container.Name)
        if containerName == "floatingislands" or containerName == "workspace" then
            return
        end
        appendUniqueString(keys, container.Name)
    end

    -- This mirrors the working legacy collector: the server argument is the
    -- island name that owns the Chest folder. Include both nearby names for
    -- maps where the visible part is itself named Chest.
    if normalized(instance.Name) == "chest" then
        local parent = instance.Parent
        if parent and parent ~= Workspace then
            addContainerKey(parent)
        end
        if parent and parent.Parent and parent.Parent ~= Workspace then
            addContainerKey(parent.Parent)
        end
    end

    local ancestor = instance
    while ancestor and ancestor ~= Workspace do
        if normalized(ancestor.Name) == "chest" then
            if ancestor.Parent and ancestor.Parent ~= Workspace then
                addContainerKey(ancestor.Parent)
            end
            break
        end
        ancestor = ancestor.Parent
    end

    local model = instance:IsA("Model") and instance or instance:FindFirstAncestorOfClass("Model")
    if model and model.Parent and model.Parent ~= Workspace then
        addContainerKey(model.Parent)
    end
    if instance.Parent and instance.Parent ~= Workspace then
        addContainerKey(instance.Parent)
    end
    return keys
end

local function getCollectKey(instance)
    if not instance then
        return nil
    end

    local sources = {instance}
    local model = instance:IsA("Model") and instance or instance:FindFirstAncestorOfClass("Model")
    if model and model ~= instance then
        table.insert(sources, model)
    end

    for _, source in ipairs(sources) do
        for _, attributeName in ipairs(COLLECT_KEY_ATTRIBUTES) do
            local value = source:GetAttribute(attributeName)
            if type(value) == "string" and value ~= "" then
                return value
            end
        end
    end

    -- Keep compatibility with the existing owner-game contract, which used
    -- the parent/island name when firing CollectChestReward.
    local ancestor = instance.Parent
    while ancestor and ancestor ~= Workspace do
        if normalized(ancestor.Name) == "chest" then
            if ancestor.Parent and ancestor.Parent ~= Workspace then
                return ancestor.Parent.Name
            end
            break
        end
        ancestor = ancestor.Parent
    end
    if model and model.Parent and model.Parent ~= Workspace
        and normalized(model.Parent.Name) ~= "floatingislands" then
        return model.Parent.Name
    end
    if instance.Parent and instance.Parent ~= Workspace
        and normalized(instance.Parent.Name) ~= "floatingislands" then
        return instance.Parent.Name
    end
    return instance.Name
end

local function getCollectKeys(instance)
    local keys = getLegacyCollectKeys(instance)
    appendUniqueString(keys, getCollectKey(instance))
    if instance then
        appendUniqueString(keys, instance.Name)
    end
    return keys
end

local function getState(instance, cooldownRemaining, cooldownResolved)
    if not cooldownResolved then
        cooldownRemaining = getCooldownRemaining(instance)
    end
    if cooldownRemaining and cooldownRemaining > 0 then
        return "Cooldown"
    end
    for _, source in ipairs(getCooldownSources(instance)) do
        if source:GetAttribute("Active") == false then
            return "Inactive"
        end
        if source:GetAttribute("Collected") == true then
            return "Collected"
        end
        if source:GetAttribute("Available") == false then
            return "Unavailable"
        end
    end
    return "Detected"
end

local function scanChests()
    local results = {}
    local seen = {}

    local function addCandidate(instance)
        if #results >= MAX_RESULTS or seen[instance] then
            return
        end
        if not instance:IsDescendantOf(Workspace) then
            return
        end
        -- Workspace.Activations contains server trigger/proxy objects. They
        -- can share the name Chest but are not the physical Chest position.
        -- The route must use the real Chest in the map instead.
        if isActivationTrigger(instance) then
            return
        end
        -- Checkpoints are navigation markers, not collectible Chest objects.
        if isExcludedChestContainer(instance) then
            return
        end

        local position = getPosition(instance)
        if not position then
            return
        end
        if S.hrp and S.hrp:IsDescendantOf(Workspace)
            and (position - S.hrp.Position).Magnitude > maxChestScanDistance then
            return
        end
        -- Validate the map area once while building the scan result. The
        -- cached flag is reused by TP verification to avoid repeated map
        -- checks during physics settling.
        if not isSafeChestMapPosition(position) then
            return
        end

        seen[instance] = true
        local chestType = getKnownChestType(instance)
        local collectKeys = getCollectKeys(instance)
        local cooldownRemaining = getCooldownRemaining(instance)

        -- A single Chest can expose a model, a hitbox, and several visual
        -- parts. Treat only near-overlapping objects with the same server key
        -- as one route target; separate Chests in the same area must remain.
        for _, existing in ipairs(results) do
            if existing.collectKey == collectKeys[1]
                and existing.position
                and (existing.position - position).Magnitude <= 3 then
                return
            end
        end
        table.insert(results, {
            instance = instance,
            name = getDisplayName(instance),
            chestType = chestType,
            sortKey = compactName(chestType or getDisplayName(instance)),
            collectKeys = collectKeys,
            collectKey = collectKeys[1],
            legacyCollectKey = collectKeys[1],
            worldName = getChestWorldName(instance, chestType),
            position = position,
            areaValidated = true,
            state = getState(instance, cooldownRemaining, true),
            cooldownRemaining = cooldownRemaining,
        })
    end

    for _, instance in ipairs(Workspace:GetDescendants()) do
        if (instance:IsA("Model") or instance:IsA("BasePart"))
            and (looksLikeChest(instance) or isTaggedChest(instance)) then
            addCandidate(canonicalChest(instance))
        end
    end

    -- Keep the exact legacy map layout supported as well. In that layout the
    -- visible part may have a generic name while its parent folder is named
    -- Chest, so the normal name/tag pass cannot discover it.
    local floatingIslands = Workspace:FindFirstChild("FloatingIslands")
    if floatingIslands then
        for _, instance in ipairs(floatingIslands:GetDescendants()) do
            if instance:IsA("BasePart")
                and (normalized(instance.Name) == "chest"
                    or (instance.Parent and normalized(instance.Parent.Name) == "chest")) then
                addCandidate(canonicalChest(instance))
            end
        end
    end

    table.sort(results, function(a, b)
        if a.sortKey == b.sortKey then
            return a.name < b.name
        end
        return a.sortKey < b.sortKey
    end)
    return results
end

local function formatPosition(position)
    return string.format("X %.1f | Y %.1f | Z %.1f", position.X, position.Y, position.Z)
end

local function setResults(title, content)
    if not resultsParagraph
        or (lastResultsTitle == title and lastResultsContent == content) then
        return
    end
    local ok = pcall(function()
        resultsParagraph:Set({Title = title, Content = content})
    end)
    if ok then
        lastResultsTitle = title
        lastResultsContent = content
    end
end

local function render(results)
    if #results == 0 then
        local emptyLines = {
            string.format(
                "Found 0/%d expected chests",
                #EXPECTED_CHEST_WORLDS * EXPECTED_CHESTS_PER_WORLD
            ),
        }
        for _, worldName in ipairs(EXPECTED_CHEST_WORLDS) do
            table.insert(emptyLines, string.format("%s: 0/%d", worldName, EXPECTED_CHESTS_PER_WORLD))
        end
        table.insert(emptyLines, "No inspectable chests found in Workspace")
        setResults("Chest Scanner", table.concat(emptyLines, "\n"))
        return
    end

    local worldCounts = {}
    for _, data in ipairs(results) do
        local worldName = data.worldName or "Other"
        worldCounts[worldName] = (worldCounts[worldName] or 0) + 1
    end
    local lines = {
        string.format(
            "Found %d/%d chests | Showing up to %d entries",
            #results,
            #EXPECTED_CHEST_WORLDS * EXPECTED_CHESTS_PER_WORLD,
            MAX_DISPLAY_RESULTS
        ),
    }
    for _, worldName in ipairs(EXPECTED_CHEST_WORLDS) do
        table.insert(lines, string.format(
            "%s: %d/%d",
            worldName,
            worldCounts[worldName] or 0,
            EXPECTED_CHESTS_PER_WORLD
        ))
    end
    for index = 1, math.min(#results, MAX_DISPLAY_RESULTS) do
        local data = results[index]
        local stateText = data.state
        if data.cooldownRemaining == math.huge then
            stateText = "Cooldown (active)"
        elseif type(data.cooldownRemaining) == "number" and data.cooldownRemaining > 0 then
            stateText = string.format("Cooldown %.1fs", data.cooldownRemaining)
        end
        table.insert(lines, string.format(
            "%02d. [%s] %s%s\n    %s",
            index,
            stateText,
            data.name,
            data.chestType and (" | " .. data.chestType) or "",
            formatPosition(data.position)
        ))
    end
    if #results > MAX_DISPLAY_RESULTS then
        table.insert(lines, "... More entries exist but are hidden to prevent UI lag")
    end
    setResults("Chest Scanner", table.concat(lines, "\n"))
end

local function renderCooldowns(results)
    if not cooldownParagraph then
        return
    end

    results = results or lastResults
    if #results == 0 then
        local content = "No chest results from the latest scan"
        if lastCooldownContent == content then
            return
        end
        local ok = pcall(function()
            cooldownParagraph:Set({
                Title = "Chest Cooldown Scanner",
                Content = content,
            })
        end)
        if ok then
            lastCooldownContent = content
        end
        return
    end

    local readyCount = 0
    local cooldownCount = 0
    local unavailableCount = 0
    local lines = {}
    for index, target in ipairs(results) do
        local instance = target and target.instance
        if instance and instance:IsDescendantOf(Workspace) then
            local remaining, cooldownName = getCooldownRemaining(instance)
            local state = getState(instance, remaining, true)
            if remaining and remaining > 0 then
                cooldownCount = cooldownCount + 1
                if remaining == math.huge then
                    state = "Cooldown (unknown)"
                else
                    state = string.format("Cooldown %.1fs", remaining)
                end
            elseif state ~= "Detected" then
                unavailableCount = unavailableCount + 1
            else
                readyCount = readyCount + 1
                state = "Ready to collect"
            end

            table.insert(lines, string.format(
                "%02d. [%s] %s%s",
                index,
                state,
                target.chestType or target.name,
                cooldownName and remaining and remaining > 0
                    and (" | " .. tostring(cooldownName))
                    or ""
            ))
        end
    end

    if #lines == 0 then
        table.insert(lines, "No remaining chests found in Workspace")
    end
    table.insert(lines, 1, string.format(
        "Ready %d | Cooldown %d | Not ready %d | Updated from latest scan",
        readyCount,
        cooldownCount,
        unavailableCount
    ))
    local content = table.concat(lines, "\n")
    if lastCooldownContent == content then
        return
    end
    local ok = pcall(function()
        cooldownParagraph:Set({
            Title = "Chest Cooldown Scanner",
            Content = content,
        })
    end)
    if ok then
        lastCooldownContent = content
    end
end

local function scan()
    if scanning then
        return false, "Scanner busy or stopped"
    end

    scanning = true
    setResults("Chest Scanner", "Scanning Workspace...")
    local ok, results = pcall(scanChests)
    if ok then
        lastResults = results
        lastScanAt = os.clock()
        render(results)
        renderCooldowns(results)
        if renderAutoRouteProgress then
            renderAutoRouteProgress("Latest list scanned")
        end
        scanning = false
        return true, #results
    end

    setResults("Chest Scanner", "Scan failed: " .. tostring(results))
    scanning = false
    return false, results
end

local function setTeleportStatus(text)
    if teleportStatusParagraph then
        pcall(function()
            teleportStatusParagraph:Set({Title = "Chest TP", Content = text})
        end)
    end
    if S.safeNotify and text then
        pcall(function()
            S.safeNotify("Chest TP (Manual)", text, 4)
        end)
    end
end

local function isValidScannedTarget(target, cachedCooldownRemaining, cooldownResolved, cachedCooldownName)
    if type(target) ~= "table" or not target.instance then
        return false, "No target from the latest scan"
    end
    local instance = target.instance
    if not instance:IsDescendantOf(Workspace) then
        return false, "Chest was removed or is no longer in Workspace"
    end
    if target.areaValidated ~= true then
        return false, "Chest did not pass the scan area check"
    end
    local cooldownRemaining = cachedCooldownRemaining
    local cooldownName = cachedCooldownName
    if not cooldownResolved then
        cooldownRemaining, cooldownName = getCooldownRemaining(instance)
    end
    local targetState = getState(instance, cooldownRemaining, true)
    if targetState == "Collected" then
        return false, "Chest was already opened/collected"
    end
    if targetState == "Inactive" then
        return false, "Chest is no longer active"
    end
    if targetState == "Unavailable" then
        return false, "Chest is not ready"
    end
    if cooldownRemaining and cooldownRemaining > 0 then
        if cooldownRemaining == math.huge then
            return false, "Chest is on cooldown (" .. tostring(cooldownName) .. ")"
        end
        return false, string.format(
            "Chest is on cooldown for %.1f seconds (%s)",
            cooldownRemaining,
            tostring(cooldownName)
        )
    end
    local position = getPosition(instance)
    if not position then
        return false, "Chest has no usable position"
    end
    if S.hrp and S.hrp:IsDescendantOf(Workspace)
        and (position - S.hrp.Position).Magnitude > maxChestScanDistance then
        return false, string.format(
            "Chest is too far away (%.0f studs)",
            maxChestScanDistance
        )
    end
    return true
end

local function isSafeChestSupport(part, targetInstance, allowTargetSupport)
    if not part or not part:IsA("BasePart") or not part.CanCollide then
        return false
    end
    if targetInstance and part:IsDescendantOf(targetInstance) then
        return allowTargetSupport == true
    end
    local name = string.lower(part.Name or "")
    if part:GetAttribute("KillPart") == true
        or part:GetAttribute("Dangerous") == true
        or name:find("kill", 1, true)
        or name:find("lava", 1, true)
        or name:find("void", 1, true)
        or name:find("water", 1, true) then
        return false
    end
    return true
end

local function getChestTeleportPosition(instance)
    if not instance or not instance:IsDescendantOf(Workspace) then
        return nil, "Chest is no longer in Workspace"
    end

    local boundsCFrame
    local boundsSize
    local interactionPart = getChestInteractionPart(instance)
    if interactionPart then
        boundsCFrame = interactionPart.CFrame
        boundsSize = interactionPart.Size
    elseif instance:IsA("Model") then
        local ok, cframe, size = pcall(function()
            return instance:GetBoundingBox()
        end)
        if ok then
            boundsCFrame = cframe
            boundsSize = size
        end
    end
    if not boundsCFrame or not boundsSize then
        return nil, "Chest bounds unavailable"
    end

    local character = S.player and S.player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then
        return nil, "Character is not ready"
    end

    -- Use the actual character dimensions instead of a fixed vertical offset.
    -- This keeps the root above the support surface while avoiding excessive
    -- floating that can make the character miss a small Chest platform.
    local rootHalfHeight = math.max(0.5, root.Size.Y * 0.5)
    local standOffset = math.max(0.5, humanoid.HipHeight) + rootHalfHeight + chestSafeMargin
    local radiusX = math.max(2.5, boundsSize.X * 0.5 + root.Size.X * 0.5 + chestSafeMargin)
    local radiusZ = math.max(2.5, boundsSize.Z * 0.5 + root.Size.Z * 0.5 + chestSafeMargin)
    local rootClearance = Vector3.new(
        root.Size.X + chestSafeMargin * 2,
        root.Size.Y + chestSafeMargin * 2,
        root.Size.Z + chestSafeMargin * 2
    )
    local candidates = {
        {offset = Vector3.zero, label = "Center"},
        {offset = Vector3.new(radiusX, 0, 0), label = "Right"},
        {offset = Vector3.new(-radiusX, 0, 0), label = "Left"},
        {offset = Vector3.new(0, 0, radiusZ), label = "Back"},
        {offset = Vector3.new(0, 0, -radiusZ), label = "Front"},
        {offset = Vector3.new(radiusX, 0, radiusZ), label = "Grid"},
        {offset = Vector3.new(-radiusX, 0, radiusZ), label = "Grid"},
        {offset = Vector3.new(radiusX, 0, -radiusZ), label = "Grid"},
        {offset = Vector3.new(-radiusX, 0, -radiusZ), label = "Grid"},
    }

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character, instance}

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {character, instance}

    -- Prefer the top surface of the Chest itself. This is useful for the
    -- floating Chest locations in the owner map; the target must be
    -- collidable and the character volume must still be clear.
    local directTop = boundsCFrame:PointToWorldSpace(Vector3.new(0, boundsSize.Y * 0.5, 0))
    local directPosition = directTop + Vector3.new(0, standOffset, 0)
    local directRayParams = RaycastParams.new()
    directRayParams.FilterType = Enum.RaycastFilterType.Exclude
    directRayParams.FilterDescendantsInstances = {character}
    local directHit = Workspace:Raycast(
        directPosition + Vector3.new(0, rootHalfHeight + chestSafeMargin + 1, 0),
        Vector3.new(0, -(standOffset + boundsSize.Y + 6), 0),
        directRayParams
    )
    if directHit
        and directHit.Normal.Y >= 0.65
        and (directHit.Instance == instance or directHit.Instance:IsDescendantOf(instance)) then
        local directOccupied = Workspace:GetPartBoundsInBox(
            CFrame.new(directPosition),
            rootClearance,
            overlapParams
        )
        local directClear = true
        for _, part in ipairs(directOccupied) do
            if part.CanCollide and not part:IsDescendantOf(instance) then
                directClear = false
                break
            end
        end
        if directClear and directHit.Instance.CanCollide == true then
            return directPosition, "DirectChestTop", true
        end
    end

    local bestPosition
    local bestLabel
    local bestDistance
    local center = boundsCFrame.Position
    for _, candidate in ipairs(candidates) do
        local probe = boundsCFrame:PointToWorldSpace(candidate.offset)
        local hit = Workspace:Raycast(
            probe + Vector3.new(0, 50, 0),
            Vector3.new(0, -120, 0),
            rayParams
        )
        local chestBaseY = boundsCFrame.Position.Y - (boundsSize.Y * 0.5)
        local supportGap = chestBaseY - (hit and hit.Position.Y or -math.huge)
        if hit
            and hit.Normal.Y >= 0.65
            and supportGap >= -3
            and supportGap <= 14
            and isSafeChestSupport(hit.Instance, instance) then
            local landing = hit.Position + Vector3.new(0, standOffset, 0)
            local clear = true
            if clear then
                local occupied = Workspace:GetPartBoundsInBox(
                    CFrame.new(landing),
                    rootClearance,
                    overlapParams
                )
                for _, part in ipairs(occupied) do
                    -- Decorative/query-only parts are allowed. Only a real
                    -- collidable unsafe part should reject the landing spot.
                    if part.CanCollide and not isSafeChestSupport(part, instance) then
                        clear = false
                        break
                    end
                end
            end
            if clear then
                local flatLanding = Vector3.new(landing.X, 0, landing.Z)
                local flatCenter = Vector3.new(center.X, 0, center.Z)
                local distance = (flatLanding - flatCenter).Magnitude
                if not bestPosition or distance < bestDistance then
                    bestPosition = landing
                    bestLabel = candidate.label
                    bestDistance = distance
                end
            end
        end
    end

    if not bestPosition then
        return nil, "NoSafeGroundNearChest"
    end
    return bestPosition, bestLabel, false
end

local function findNearestScannedTarget()
    if not S.hrp or not S.hrp:IsDescendantOf(Workspace) then
        return nil, "Character is not ready"
    end

    for _, target in ipairs(lastResults) do
        local valid = isValidScannedTarget(target)
        if valid then
            local position = getPosition(target.instance)
            local distance = position and (position - S.hrp.Position).Magnitude
            if distance then
                -- lastResults is already sorted by chest name.
                return target, distance
            end
        end
    end

    return nil, "No usable chests from the latest scan"
end

local function verifyChestLanding(target, expectedPosition, allowTargetSupport)
    local character = S.player and S.player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or humanoid.Health <= 0 or not root then
        return false, "Character not ready after teleport"
    end
    if not target or not target.instance or not target.instance:IsDescendantOf(Workspace) then
        return false, "Chest disappeared while checking the landing point"
    end
    if target.areaValidated ~= true then
        return false, "This chest did not pass the scan area check"
    end
    local landingTolerance = math.max(2.5, chestSafeMargin * 4)
    if expectedPosition and (root.Position - expectedPosition).Magnitude > landingTolerance then
        return false, "Server moved the character away from the landing point"
    end
    if root.AssemblyLinearVelocity.Y < -12 then
        return false, "Character is falling too quickly"
    end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = allowTargetSupport and {character} or {character, target.instance}
    local supportHit = Workspace:Raycast(
        root.Position + Vector3.new(0, root.Size.Y * 0.5 + chestSafeMargin + 0.5, 0),
        Vector3.new(0, -(math.max(12, root.Size.Y + humanoid.HipHeight + 6)), 0),
        rayParams
    )
    if not supportHit
        or supportHit.Normal.Y < 0.65
        or not isSafeChestSupport(supportHit.Instance, target.instance, allowTargetSupport) then
        return false, "No safe ground found to support the character"
    end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {character, target.instance}
    local occupied = Workspace:GetPartBoundsInBox(
        root.CFrame,
        Vector3.new(
            root.Size.X + chestSafeMargin * 2,
            root.Size.Y + chestSafeMargin * 2,
            root.Size.Z + chestSafeMargin * 2
        ),
        overlapParams
    )
    for _, part in ipairs(occupied) do
        if part.CanCollide and isSafeChestSupport(part, target.instance) then
            return false, "Character overlapped an obstacle after teleport"
        end
    end
    return true
end

local function teleportToNearestScannedChest(preferredTarget)
    if os.clock() - lastTeleportAt < MANUAL_TELEPORT_COOLDOWN then
        return false, "Please wait for the manual teleport cooldown"
    end
    lastTeleportAt = os.clock()

    if S.isTeleporting then
        return false, "Another movement system is already running"
    end
    if not S.hrp or not S.humanoid or not S.hrp:IsDescendantOf(Workspace) then
        return false, "Character or HumanoidRootPart is not ready"
    end
    if S.humanoid.Health <= 0 then
        return false, "Character is dead or respawning"
    end
    if os.clock() - lastScanAt > 30 then
        return false, "Scan results are outdated. Please click Scan Chests Now first"
    end

    local target, distanceOrReason
    if preferredTarget then
        local valid, reason = isValidScannedTarget(preferredTarget)
        if not valid then
            return false, reason
        end
        local position = getPosition(preferredTarget.instance)
        if not position then
            return false, "Chest has no usable position"
        end
        target = preferredTarget
        distanceOrReason = (position - S.hrp.Position).Magnitude
    else
        target, distanceOrReason = findNearestScannedTarget()
    end
    if not target then
        return false, distanceOrReason
    end
    local destination, destinationReason, allowTargetSupport = getChestTeleportPosition(target.instance)
    if not destination then
        return false, destinationReason
    end

    local oldAutoRotate = S.humanoid.AutoRotate
    local character = S.player and S.player.Character
    if not character then
        return false, "Character disappeared before teleport started"
    end
    local oldPivot = character:GetPivot()
    captureAutoChestSafePivot(oldPivot)
    local rootOffset = oldPivot:ToObjectSpace(S.hrp.CFrame)
    S.isTeleporting = true

    local function restorePreviousPosition()
        local currentCharacter = S.player and S.player.Character
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
        local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
        if currentCharacter == character
            and currentHumanoid
            and currentHumanoid.Health > 0
            and currentRoot
            and oldPivot then
            pcall(function()
                currentCharacter:PivotTo(oldPivot)
                currentRoot.AssemblyLinearVelocity = Vector3.zero
                currentRoot.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end

    local function failTeleport(reason)
        restorePreviousPosition()
        pcall(function()
            if S.humanoid then
                S.humanoid.AutoRotate = oldAutoRotate
            end
        end)
        S.isTeleporting = false
        return false, reason
    end

    local ok, err = pcall(function()
        S.cancelMovement()
        S.humanoid.AutoRotate = false
        S.hrp.AssemblyLinearVelocity = Vector3.zero
        S.hrp.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(CFrame.new(destination) * rootOffset:Inverse())
        task.wait(0.05)
    end)
    if not ok then
        return failTeleport("Teleport failed: " .. tostring(err))
    end

    pcall(function()
        if S.humanoid then
            S.humanoid.AutoRotate = oldAutoRotate
        end
    end)

    local landingVerified = false
    local landingReason = "No safe ground found after teleport"
    for _, settleDelay in ipairs({0.08, 0.2, 0.35}) do
        task.wait(settleDelay)
        local verifyOk, verified, reason = pcall(
            verifyChestLanding,
            target,
            destination,
            allowTargetSupport
        )
        if verifyOk and verified then
            landingVerified = true
            break
        end
        landingReason = verifyOk
            and (reason or landingReason)
            or ("Landing point verification failed: " .. tostring(verified))
        if not S.hrp or not S.humanoid or S.humanoid.Health <= 0 then
            break
        end
    end
    if not landingVerified then
        return failTeleport(landingReason)
    end

    local finalPosition = getPosition(target.instance)
    local finalDistance = finalPosition and (S.hrp.Position - finalPosition).Magnitude or math.huge
    if finalDistance > 20 then
        return failTeleport(string.format("Post-teleport verification failed (distance %.1f studs)", finalDistance))
    end

    S.isTeleporting = false
    return true, string.format("Reached %s | Distance before teleport: %.1f studs", target.name, distanceOrReason)
end

local function markAutoCooldown(instance, remaining)
    if not instance then
        return
    end
    local retryAfter = tonumber(remaining) or 5
    if retryAfter == math.huge or retryAfter > 60 then
        retryAfter = 5
    end
    autoCooldownBlockedUntil[instance] = os.clock() + math.max(1, retryAfter)
    autoSkipped[instance] = {
        reason = retryAfter == 5 and "Cooldown (active)" or string.format("Cooldown %.1fs", retryAfter),
        cooldown = true,
    }
    if renderAutoRouteProgress then
        renderAutoRouteProgress(autoSkipped[instance].reason)
    end
end

local function findNextAutoTarget()
    if not S.hrp or not S.hrp:IsDescendantOf(Workspace) then
        return nil, "Character not ready"
    end

    local now = os.clock()
    for _, target in ipairs(lastResults) do
        local instance = target and target.instance
        if instance and not autoVisited[instance] then
            local blockedUntil = autoCooldownBlockedUntil[instance]
            local failedUntil = autoFailedUntil[instance]
            if not (blockedUntil and blockedUntil > now) and not (failedUntil and failedUntil > now) then
                local cooldownRemaining, cooldownName = getCooldownRemaining(instance)
                if cooldownRemaining and cooldownRemaining > 0 then
                    markAutoCooldown(instance, cooldownRemaining)
                else
                    local valid = isValidScannedTarget(target, cooldownRemaining, true, cooldownName)
                    if valid then
                        local position = getPosition(instance)
                        local distance = position and (position - S.hrp.Position).Magnitude
                        if distance then
                            -- lastResults is sorted by chest name; use that
                            -- deterministic order instead of nearest distance.
                            return target, distance
                        end
                    else
                        autoFailedUntil[instance] = now + 5
                        autoSkipped[instance] = {reason = "Target invalid or unavailable"}
                    end
                end
            end
        end
    end
    return nil, "No usable chests from the latest scan"
end

local function getAutoProgress()
    local completed = 0
    for _, target in ipairs(lastResults) do
        if target and target.instance and autoVisited[target.instance] then
            completed = completed + 1
        end
    end
    return completed, #lastResults
end

renderAutoRouteProgress = function(extra)
    if not chestRouteParagraph then
        return
    end

    local completed, total = getAutoProgress()
    local cooldownCount = 0
    local skippedCount = 0
    local skippedLines = {}
    for _, target in ipairs(lastResults) do
        local instance = target and target.instance
        if instance and not autoVisited[instance] then
            local remaining = getCooldownRemaining(instance)
            if remaining and remaining > 0 then
                cooldownCount = cooldownCount + 1
            elseif autoSkipped[instance] then
                skippedCount = skippedCount + 1
                if #skippedLines < 6 then
                    table.insert(skippedLines, string.format(
                        "- %s: %s",
                        tostring(target.chestType or target.name),
                        tostring(autoSkipped[instance].reason or "Waiting to retry")
                    ))
                end
            end
        end
    end

    local lines = {
        string.format("Teleported %d/%d", completed, total),
        string.format("On cooldown: %d", cooldownCount),
        string.format("Skipped/waiting to retry: %d", skippedCount),
        "Status: " .. (autoTeleportActive and "Running" or "Stopped"),
    }
    if #skippedLines > 0 then
        table.insert(lines, table.concat(skippedLines, "\n"))
    end
    if extra and extra ~= "" then
        table.insert(lines, "Latest: " .. tostring(extra))
    end
    local content = table.concat(lines, "\n")
    if lastRouteContent == content then
        return
    end
    local ok = pcall(function()
        chestRouteParagraph:Set({
            Title = "Chest Route Progress",
            Content = content,
        })
    end)
    if ok then
        lastRouteContent = content
    end
end

local function retrySkippedAutoChests()
    for instance in pairs(autoSkipped) do
        autoFailedUntil[instance] = nil
        autoCooldownBlockedUntil[instance] = nil
    end
    table.clear(autoSkipped)
    renderAutoRouteProgress("Cleared skipped entries")
    if autoTeleportActive then
        setTeleportStatus("Retry skipped chests: returned to queue")
    elseif S.safeNotify then
        S.safeNotify("Chest Route", "Cleared skipped entries. Enable Auto TP to start", 4)
    end
end

local autoToggleSyncing = false
local function stopAutoTeleport(reason)
    autoTeleportActive = false
    autoTeleportToken = autoTeleportToken + 1
    if autoTeleportToggle and not autoToggleSyncing then
        autoToggleSyncing = true
        pcall(function() autoTeleportToggle:Set(false, "Stopped", false) end)
        autoToggleSyncing = false
    end
    if reason then
        setTeleportStatus("Auto TP stopped: " .. tostring(reason))
    end
    if renderAutoRouteProgress then
        renderAutoRouteProgress(reason or "Stopped")
    end
end

local function recoverAutoChest(reason)
    local safePivot = autoChestLastSafePivot
    stopAutoTeleport(reason or "Safe recovery")

    local character = S.player and S.player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if safePivot and isSafeAutoChestPivot(safePivot)
        and character and humanoid and humanoid.Health > 0 and root then
        local ok = pcall(function()
            character:PivotTo(safePivot)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        autoChestRecoveryPending = not ok
        if ok then
            setTeleportStatus("Auto Chest System stopped and returned to the safe position")
        end
    else
        autoChestRecoveryPending = safePivot ~= nil
        setTeleportStatus("Auto Chest stopped: waiting for Character to return and restore the safe position")
    end
    if renderAutoRouteProgress then
        renderAutoRouteProgress("Safe recovery: " .. tostring(reason or "unknown"))
    end
end

local function startAutoTeleport()
    if autoTeleportWorkerRunning then
        return
    end
    autoTeleportActive = true
    table.clear(autoVisited)
    table.clear(autoCooldownBlockedUntil)
    table.clear(autoFailedUntil)
    table.clear(autoSkipped)
    local currentCharacter = S.player and S.player.Character
    if currentCharacter then
        captureAutoChestSafePivot(currentCharacter:GetPivot())
    end
    autoTeleportToken = autoTeleportToken + 1
    local token = autoTeleportToken
    autoTeleportWorkerRunning = true

    task.spawn(function()
        while autoTeleportActive and token == autoTeleportToken do
            if not S.hrp or not S.humanoid or not S.hrp:IsDescendantOf(Workspace) then
                recoverAutoChest("Character not ready or respawning")
                break
            end
            if S.humanoid.Health <= 0 then
                recoverAutoChest("Character dead")
                break
            end

            if #lastResults == 0 or os.clock() - lastScanAt > SCAN_INTERVAL then
                scan()
            end

            local target = findNextAutoTarget()
            if target then
                if not target.instance or not target.instance:IsDescendantOf(Workspace) then
                    recoverAutoChest("Target disappeared")
                    break
                end
                local success = false
                local message
                for attempt = 1, 2 do
                    if not autoTeleportActive or token ~= autoTeleportToken then
                        break
                    end
                    local ok, result = teleportToNearestScannedChest(target)
                    message = result
                    if ok then
                        success = true
                        autoVisited[target.instance] = true
                        autoSkipped[target.instance] = nil
                        local completedCount, totalCount = getAutoProgress()
                        setTeleportStatus(string.format(
                            "Auto TP [%d/%d]: %s",
                            completedCount,
                            totalCount,
                            tostring(message)
                        ))
                        renderAutoRouteProgress("Teleported to " .. tostring(target.chestType or target.name) .. " successfully")
                        break
                    end
                    local cooldownRemaining = getCooldownRemaining(target.instance)
                    if cooldownRemaining and cooldownRemaining > 0 then
                        markAutoCooldown(target.instance, cooldownRemaining)
                        break
                    end
                    if attempt < 2 then
                        task.wait(MANUAL_TELEPORT_COOLDOWN)
                    end
                end
                if not success and target.instance then
                    -- Keep the target in the queue. A short backoff prevents a
                    -- tight retry loop without permanently skipping a chest.
                    autoFailedUntil[target.instance] = os.clock() + 3
                    autoSkipped[target.instance] = {reason = tostring(message or "unknown failure")}
                    setTeleportStatus("Auto TP skipped: " .. tostring(message or "unknown failure"))
                    renderAutoRouteProgress(message or "Waiting to retry")
                end
                task.wait(math.max(0.25, autoTeleportDelay))
            else
                -- Wait briefly for new scan results or newly spawned Chest objects.
                task.wait(1)
            end
        end
        local shouldRestart = autoTeleportActive and token ~= autoTeleportToken
        autoTeleportWorkerRunning = false
        if shouldRestart then
            startAutoTeleport()
        end
    end)
end

S.player.CharacterRemoving:Connect(function()
    if autoTeleportActive then
        recoverAutoChest("Character respawning")
    end
end)

S.player.CharacterAdded:Connect(function(character)
    if not autoChestRecoveryPending or not autoChestLastSafePivot then
        return
    end
    task.spawn(function()
        for _ = 1, 40 do
            if not autoChestRecoveryPending then
                return
            end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local root = character:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and root and isSafeAutoChestPivot(autoChestLastSafePivot) then
                local ok = pcall(function()
                    character:PivotTo(autoChestLastSafePivot)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end)
                if ok then
                    autoChestRecoveryPending = false
                    setTeleportStatus("Safe position restored after respawn")
                    if renderAutoRouteProgress then
                        renderAutoRouteProgress("Recovery complete")
                    end
                    return
                end
            end
            task.wait(0.25)
        end
        setTeleportStatus("Could not restore the safe position: Character is not ready")
    end)
end)

local function stopScanner()
    stopAutoTeleport("Scanner stopped")
    autoScan = false
    workerToken = workerToken + 1
    stopped = true
    if autoScanToggle then
        pcall(function() autoScanToggle:Set(false) end)
    end
end

local function startWorker()
    if workerRunning then
        return
    end

    stopped = false
    workerToken = workerToken + 1
    local token = workerToken
    workerRunning = true
    task.spawn(function()
        while autoScan and not stopped and token == workerToken do
            scan()
            task.wait(SCAN_INTERVAL)
        end
        local shouldRestart = autoScan and not stopped and token ~= workerToken
        workerRunning = false
        if shouldRestart then
            startWorker()
        end
    end)
end

S.scanBGSChests = scan
S.scanChestCooldowns = scan
S.stopChestScanner = stopScanner
S.teleportToNearestScannedChest = teleportToNearestScannedChest
S.chestScannerAutoScan = false

-- Read-only diagnostic for the owner game's Trick or Treat houses.
-- This never teleports, opens, collects, or calls a RemoteEvent.
local function trickTreatDumpContains(value)
    local text = tostring(value or ""):lower()
    return text:find("trick", 1, true) ~= nil
        or text:find("treat", 1, true) ~= nil
end

local function dumpTrickOrTreatObjects()
    local dumped = {}
    local candidates = {}

    local function getAnchor(object)
        if object:IsA("Model") or object:IsA("BasePart") then
            return object
        end
        return object:FindFirstAncestorWhichIsA("Model")
            or object.Parent
            or object
    end

    local function addCandidate(object, reason)
        local anchor = getAnchor(object)
        if dumped[anchor] then
            return
        end
        dumped[anchor] = true
        table.insert(candidates, {
            anchor = anchor,
            source = object,
            reason = reason,
        })
    end

    for _, object in ipairs(Workspace:GetDescendants()) do
        if trickTreatDumpContains(object.Name) then
            addCandidate(object, "Name")
        end

        if object:IsA("ProximityPrompt")
            and (trickTreatDumpContains(object.ActionText)
                or trickTreatDumpContains(object.ObjectText)) then
            addCandidate(object, "ProximityPrompt")
        end

        if object:IsA("TextLabel") or object:IsA("TextButton") then
            if trickTreatDumpContains(object.Text)
                or object.Text:match("%d%d:%d%d") then
                addCandidate(object, "UI text")
            end
        end

        for attributeName in pairs(object:GetAttributes()) do
            local key = tostring(attributeName):lower()
            if key:find("cooldown", 1, true)
                or key:find("available", 1, true)
                or key:find("next", 1, true) then
                addCandidate(object, "Cooldown attribute")
                break
            end
        end
    end

    print("========== BGS TRICK OR TREAT DUMP ==========")
    print("Read-only: no TP, collect, open, or RemoteEvent call")

    for index, entry in ipairs(candidates) do
        local anchor = entry.anchor
        print(string.format("[%d] Reason=%s", index, tostring(entry.reason)))
        print(" Name:", anchor.Name)
        print(" Class:", anchor.ClassName)
        print(" Path:", anchor:GetFullName())

        local position
        if anchor:IsA("BasePart") then
            position = anchor.Position
        elseif anchor:IsA("Model") then
            pcall(function() position = anchor:GetPivot().Position end)
        end
        if position then
            print(string.format(
                " Position: %.2f, %.2f, %.2f",
                position.X,
                position.Y,
                position.Z
            ))
        end

        for attributeName, value in pairs(anchor:GetAttributes()) do
            print(" Attribute:", attributeName, "=", tostring(value))
        end

        for _, child in ipairs(anchor:GetDescendants()) do
            if child:IsA("ProximityPrompt") then
                print(" Prompt:", child:GetFullName())
                print("  ActionText:", child.ActionText)
                print("  ObjectText:", child.ObjectText)
                print("  HoldDuration:", child.HoldDuration)
                print("  Enabled:", child.Enabled)
            elseif child:IsA("TextLabel") or child:IsA("TextButton") then
                if child.Text ~= ""
                    and (trickTreatDumpContains(child.Text)
                        or child.Text:match("%d%d:%d%d")) then
                    print(" Text:", child:GetFullName(), "=", child.Text)
                end
            end

            for attributeName, value in pairs(child:GetAttributes()) do
                local key = tostring(attributeName):lower()
                if key:find("cooldown", 1, true)
                    or key:find("available", 1, true)
                    or key:find("next", 1, true) then
                    print(
                        " Cooldown attribute:",
                        child:GetFullName(),
                        attributeName,
                        "=",
                        tostring(value)
                    )
                end
            end
        end
    end

    print("Total candidates:", #candidates)
    print("========== END TRICK OR TREAT DUMP ==========")
    return #candidates
end

S.dumpTrickOrTreatObjects = dumpTrickOrTreatObjects

-- Detailed read-only inspection for the 12 FallHouse Activation models.
-- This only prints structure and metadata; it never invokes interaction APIs.
local function dumpTrickOrTreatDetails()
    local found = 0
    print("========== TRICK OR TREAT DETAILS ==========")

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("Model")
            and object.Name == "Activation"
            and object:GetAttribute("FallHouse") == true then
            found = found + 1
            print(string.format("[%d] %s", found, object:GetFullName()))

            for attributeName, value in pairs(object:GetAttributes()) do
                print(" Attribute:", attributeName, "=", tostring(value))
            end

            for _, child in ipairs(object:GetDescendants()) do
                local className = child.ClassName
                if className == "ProximityPrompt" then
                    print(" ProximityPrompt:", child:GetFullName())
                    print("  ActionText:", child.ActionText)
                    print("  ObjectText:", child.ObjectText)
                    print("  HoldDuration:", child.HoldDuration)
                    print("  MaxActivationDistance:", child.MaxActivationDistance)
                    print("  Enabled:", child.Enabled)
                elseif className == "ClickDetector" then
                    print(" ClickDetector:", child:GetFullName())
                    print("  MaxActivationDistance:", child.MaxActivationDistance)
                elseif className == "TouchTransmitter" or className == "TouchInterest" then
                    print(" Touch interaction:", child:GetFullName(), className)
                elseif child:IsA("TextLabel") or child:IsA("TextButton") then
                    if child.Text ~= "" then
                        print(" Text:", child:GetFullName(), "=", child.Text)
                    end
                end

                for attributeName, value in pairs(child:GetAttributes()) do
                    local key = tostring(attributeName):lower()
                    if key:find("cooldown", 1, true)
                        or key:find("available", 1, true)
                        or key:find("next", 1, true)
                        or key:find("collect", 1, true) then
                        print(
                            " Attribute:",
                            child:GetFullName(),
                            attributeName,
                            "=",
                            tostring(value)
                        )
                    end
                end
            end
        end
    end

    local replicatedStorage = game:GetService("ReplicatedStorage")
    print("--- Candidate interaction remotes ---")
    for _, object in ipairs(replicatedStorage:GetDescendants()) do
        if object:IsA("RemoteEvent") or object:IsA("RemoteFunction") then
            local name = object.Name:lower()
            if name:find("trick", 1, true)
                or name:find("treat", 1, true)
                or name:find("fall", 1, true)
                or name:find("house", 1, true)
                or name:find("collect", 1, true) then
                print(" Remote:", object:GetFullName(), object.ClassName)
            end
        end
    end

    print("Activation models:", found)
    print("========== END TRICK OR TREAT DETAILS ==========")
    return found
end

S.dumpTrickOrTreatDetails = dumpTrickOrTreatDetails

-- Trick or Treat route: the game collects when the character physically
-- enters the yellow Activation ring. No RemoteEvent or collect command is
-- invoked here; this manager only scans and moves to the ring centers.
local TRICK_TREAT_COOLDOWN_SECONDS = 60
local TRICK_TREAT_SCAN_INTERVAL = 5
local trickTreatTargets = {}
local trickTreatBlockedUntil = {}
local trickTreatLastScanAt = 0
local trickTreatLastContent
local trickTreatActive = false
local trickTreatWorkerRunning = false
local trickTreatStartPending = false
local trickTreatToken = 0
local trickTreatDelay = 1
S.trickTreatActive = false
S.trickTreatWorkerRunning = false
S.trickTreatStartPending = false
local trickTreatToggle
local trickTreatToggleSyncing = false
local trickTreatParagraph
local TRICK_TREAT_CANDYCORN_TARGET = 300000000
local TRICK_TREAT_CANDYCORN_POLL_INTERVAL = 5
local trickTreatToHatchActive = false
local trickTreatToHatchToken = 0
local trickTreatToHatchPhase = "Stopped"
local trickTreatToHatchLastContent
local trickTreatToHatchToggle
local trickTreatToHatchParagraph
local stopTrickTreatToHatch
local startTrickTreat

local function parseCurrencyAmount(value)
    if type(value) == "number" then
        return value
    end
    if value == nil then
        return nil
    end

    local text = tostring(value):gsub(",", ""):gsub("%s+", "")
    local number, suffix = text:match("^([%+%-]?[%d%.]+)([kKmMbB]?)$")
    number = tonumber(number)
    if not number then
        return nil
    end

    local multipliers = {
        k = 1000,
        m = 1000000,
        b = 1000000000,
    }
    return number * (multipliers[(suffix or ""):lower()] or 1)
end

local function normalizeCurrencyName(value)
    return tostring(value or "")
        :lower()
        :gsub("[%s_%-]", "")
end

local CANDYCORN_STAT_NAMES = {
    candycorn = true,
    candycorns = true,
}

local function readCandycorn()
    if not S.player then
        return nil, nil
    end

    -- Prefer the existing leaderstat reader so this stays compatible with the
    -- rest of the script's replicated-stat handling.
    for _, name in ipairs({"Candycorn", "Candy Corn", "Candy_Corn", "Candy-Corn"}) do
        local value = parseCurrencyAmount(S.readLeaderstat(name))
        if value ~= nil then
            return value, name
        end
    end

    -- Some game versions use a different capitalization or put the value in
    -- a replicated data folder. Only exact Candycorn-name matches are accepted.
    local leaderstats = S.player:FindFirstChild("leaderstats")
    local containers = {leaderstats, S.player}
    local seen = {}
    for _, container in ipairs(containers) do
        if container and not seen[container] then
            seen[container] = true
            for _, object in ipairs(container:GetDescendants()) do
                if object:IsA("ValueBase")
                    and CANDYCORN_STAT_NAMES[normalizeCurrencyName(object.Name)] then
                    local ok, raw = pcall(function()
                        return object.Value
                    end)
                    if ok then
                        local value = parseCurrencyAmount(raw)
                        if value ~= nil then
                            return value, object:GetFullName()
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

local function formatCurrencyAmount(value)
    if value == nil then
        return "Not available"
    end
    local text = tostring(math.floor(math.max(0, value)))
    local changed = true
    while changed do
        local replaced
        replaced, changed = text:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
        text = replaced
    end
    return text
end

local function renderTrickTreatToHatchStatus(extra, currentOverride)
    if not trickTreatToHatchParagraph then
        return
    end

    local current = currentOverride
    if current == nil then
        current = readCandycorn()
    end
    local lines = {
        "Candycorn target: " .. formatCurrencyAmount(TRICK_TREAT_CANDYCORN_TARGET),
        "Current: " .. formatCurrencyAmount(current),
        "Status: " .. trickTreatToHatchPhase,
    }
    if extra then
        table.insert(lines, "Latest: " .. tostring(extra))
    end
    local content = table.concat(lines, "\n")
    if content == trickTreatToHatchLastContent then
        return
    end
    local ok = pcall(function()
        trickTreatToHatchParagraph:Set({
            Title = "Auto Trick → Hatch",
            Content = content,
        })
    end)
    if ok then
        trickTreatToHatchLastContent = content
    end
end

local function isTrickTreatActivation(object)
    return typeof(object) == "Instance"
        and object
        and object:IsA("Model")
        and object.Name == "Activation"
        and object:GetAttribute("FallHouse") == true
        and object:IsDescendantOf(Workspace)
end

local function getTrickTreatCooldownRemaining(target)
    if not target then
        return 0
    end

    local now = os.clock()
    local function readFrom(instance)
        if typeof(instance) ~= "Instance" then
            return nil
        end
        for _, attributeName in ipairs({
            "CooldownUntil",
            "NextAvailableAt",
            "AvailableAt",
        }) do
            local value = tonumber(instance:GetAttribute(attributeName))
            if value then
                if value > now then
                    return value - now
                end
                return 0
            end
        end

        local cooldown = tonumber(instance:GetAttribute("Cooldown"))
        if cooldown and cooldown > 0 then
            return cooldown
        end
        return nil
    end

    local remaining = readFrom(target)
    if remaining ~= nil then
        return math.max(0, remaining)
    end
    for _, child in ipairs(target:GetDescendants()) do
        remaining = readFrom(child)
        if remaining ~= nil then
            return math.max(0, remaining)
        end
    end
    return 0
end

local function renderTrickTreatProgress(extra)
    if not trickTreatParagraph then
        return
    end

    local now = os.clock()
    local ready = 0
    local cooldown = 0
    local shortestWait = math.huge
    for _, target in ipairs(trickTreatTargets) do
        local blocked = trickTreatBlockedUntil[target.instance]
        local remaining = math.max(
            blocked and (blocked - now) or 0,
            getTrickTreatCooldownRemaining(target.instance)
        )
        if remaining > 0 then
            cooldown = cooldown + 1
            shortestWait = math.min(shortestWait, remaining)
        else
            ready = ready + 1
        end
    end

    local waitText = shortestWait < math.huge
        and string.format("Waiting %.0f seconds for the next point", shortestWait)
        or "Ready"
    local lines = {
        string.format("Found %d/12 Trick or Treat points", #trickTreatTargets),
        string.format("Ready: %d | Cooldown: %d", ready, cooldown),
        "Status: " .. (trickTreatActive and "Running" or "Stopped"),
        waitText,
    }
    if extra then
        table.insert(lines, "Latest: " .. tostring(extra))
    end
    local content = table.concat(lines, "\n")

    if content == trickTreatLastContent then
        return
    end
    local ok = pcall(function()
        trickTreatParagraph:Set({
            Title = "Trick or Treat Route",
            Content = content,
        })
    end)
    if ok then
        trickTreatLastContent = content
    end
end

local function scanTrickTreatActivations()
    local targets = {}
    local seen = {}
    for _, object in ipairs(Workspace:GetDescendants()) do
        if isTrickTreatActivation(object) and not seen[object] then
            local ok, pivot = pcall(function()
                return object:GetPivot()
            end)
            if ok and pivot then
                seen[object] = true
                table.insert(targets, {
                    instance = object,
                    ringPosition = pivot.Position,
                })
            end
        end
    end

    table.sort(targets, function(left, right)
        if left.ringPosition.X ~= right.ringPosition.X then
            return left.ringPosition.X < right.ringPosition.X
        end
        if left.ringPosition.Z ~= right.ringPosition.Z then
            return left.ringPosition.Z < right.ringPosition.Z
        end
        return left.ringPosition.Y < right.ringPosition.Y
    end)

    trickTreatTargets = targets
    trickTreatLastScanAt = os.clock()
    renderTrickTreatProgress("Scan found " .. tostring(#targets) .. " points")
    return #targets
end

local function findNextTrickTreatTarget()
    local now = os.clock()
    local shortestWait = math.huge
    for _, target in ipairs(trickTreatTargets) do
        if isTrickTreatActivation(target.instance) then
            local blockedUntil = trickTreatBlockedUntil[target.instance] or 0
            local cooldownRemaining = getTrickTreatCooldownRemaining(target.instance)
            local remaining = math.max(
                blockedUntil - now,
                cooldownRemaining
            )
            if remaining <= 0 then
                return target, 0
            end
            shortestWait = math.min(shortestWait, remaining)
        end
    end
    return nil, shortestWait < math.huge and shortestWait or 2
end

local function jumpInsideTrickTreatRing()
    local humanoid = S.humanoid
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    local ok = pcall(function()
        humanoid.Jump = true
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        task.wait(0.18)
        if S.humanoid == humanoid and humanoid.Health > 0 then
            humanoid.Jump = false
        end
        task.wait(0.25)
    end)
    return ok
end

local function teleportToTrickTreatTarget(target)
    if not target or not isTrickTreatActivation(target.instance) then
        return false, "Activation missing or not ready"
    end
    if autoTeleportActive then
        return false, "Auto Chest TP is active"
    end
    if S.isTeleporting then
        return false, "Another movement system is already running"
    end
    if not S.hrp
        or not S.hrp:IsDescendantOf(Workspace)
        or not S.humanoid
        or S.humanoid.Health <= 0 then
        return false, "Character is not ready"
    end

    local character = S.player and S.player.Character
    if not character then
        return false, "Character disappeared before teleport started"
    end

    local oldPivot = character:GetPivot()
    local rootOffset = oldPivot:ToObjectSpace(S.hrp.CFrame)
    local destination = target.ringPosition + Vector3.new(0, 2.75, 0)
    S.isTeleporting = true
    local ok, err = pcall(function()
        S.cancelMovement()
        character:PivotTo(CFrame.new(destination) * rootOffset:Inverse())
        S.hrp.AssemblyLinearVelocity = Vector3.zero
        S.hrp.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.25)
    end)
    S.isTeleporting = false

    if not ok then
        return false, "Teleport failed: " .. tostring(err)
    end
    if not S.hrp or (S.hrp.Position - target.ringPosition).Magnitude > 10 then
        return false, "Verification failed: not inside the Activation ring"
    end
    if not jumpInsideTrickTreatRing() then
        return false, "Could not jump inside the Trick or Treat ring"
    end
    return true, "Reached the Trick or Treat ring | Jumped to trigger collection"
end

local function stopTrickTreat(reason)
    trickTreatActive = false
    trickTreatStartPending = false
    S.trickTreatStartPending = false
    S.trickTreatActive = false
    trickTreatToken = trickTreatToken + 1
    if trickTreatToggle and not trickTreatToggleSyncing then
        trickTreatToggleSyncing = true
        pcall(function() trickTreatToggle:Set(false, "Stopped", false) end)
        trickTreatToggleSyncing = false
    end
    renderTrickTreatProgress(reason or "Stopped")
end

local function syncTrickTreatToHatchToggle(value)
    if not trickTreatToHatchToggle then
        return
    end
    local previous = trickTreatToggleSyncing
    trickTreatToggleSyncing = true
    pcall(function()
        trickTreatToHatchToggle:Set(value == true, value and "Running" or "Stopped", false)
    end)
    trickTreatToggleSyncing = previous
end

local function getSelectedEggPositionForHatch()
    if not S.selectedEgg or S.selectedEgg == "" then
        return nil, "No egg selected in the Hatch tab"
    end

    local eggsFolder = Workspace:FindFirstChild("Eggs")
    local target = eggsFolder and eggsFolder:FindFirstChild(S.selectedEgg)
    if target then
        local position
        if target:IsA("BasePart") then
            position = target.Position
        elseif target:IsA("Model") then
            if target.PrimaryPart then
                position = target.PrimaryPart.Position
            else
                pcall(function()
                    position = target:GetPivot().Position
                end)
            end
        end
        if position then
            return position, nil
        end
    end

    -- If Workspace.Eggs is temporarily streamed out, use the saved position
    -- for this selected egg instead of guessing another egg's location.
    local saved = S.eggPositions and S.eggPositions[S.selectedEgg]
    if type(saved) == "table"
        and tonumber(saved.x)
        and tonumber(saved.y)
        and tonumber(saved.z) then
        return Vector3.new(saved.x, saved.y, saved.z), nil
    end
    return nil, "Egg position not found for '" .. tostring(S.selectedEgg) .. "'"
end

local function teleportToSelectedEggForHatch()
    if not S.hrp
        or not S.hrp:IsDescendantOf(Workspace)
        or not S.humanoid
        or S.humanoid.Health <= 0 then
        return false, "Character is not ready"
    end
    if S.isTeleporting then
        return false, "Another movement system is already running"
    end

    local position, positionError = getSelectedEggPositionForHatch()
    if not position then
        return false, positionError
    end

    local character = S.player and S.player.Character
    if not character then
        return false, "Character disappeared before teleporting to the egg"
    end

    local oldPivot = character:GetPivot()
    local rootOffset = oldPivot:ToObjectSpace(S.hrp.CFrame)
    local destination = position + Vector3.new(0, 5, 0)
    S.isTeleporting = true
    local ok, err = pcall(function()
        S.cancelMovement()
        character:PivotTo(CFrame.new(destination) * rootOffset:Inverse())
        S.hrp.AssemblyLinearVelocity = Vector3.zero
        S.hrp.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.35)
    end)
    S.isTeleporting = false

    if not ok then
        return false, "Teleport to egg failed: " .. tostring(err)
    end
    if not S.hrp or (S.hrp.Position - position).Magnitude > 15 then
        return false, "Verification failed: egg position not reached"
    end
    return true, "Reached egg '" .. tostring(S.selectedEgg) .. "'"
end

-- Expose the existing validated egg teleport to Auto Hatch. The hatch
-- controller invokes it once per activation, then leaves movement alone.
S.teleportToSelectedEggForHatch = teleportToSelectedEggForHatch

local function finishTrickTreatToHatch(token)
    if not trickTreatToHatchActive or token ~= trickTreatToHatchToken then
        return
    end

    local current = readCandycorn()
    if not current or current < TRICK_TREAT_CANDYCORN_TARGET then
        return
    end

    trickTreatToHatchPhase = "Target reached. Stopping Trick or Treat"
    renderTrickTreatToHatchStatus("Candycorn target reached", current)
    stopTrickTreat("Candycorn reached " .. formatCurrencyAmount(TRICK_TREAT_CANDYCORN_TARGET))
    task.wait(0.3)
    if not trickTreatToHatchActive or token ~= trickTreatToHatchToken then
        return
    end

    trickTreatToHatchPhase = "Teleporting to selected egg"
    renderTrickTreatToHatchStatus()
    local teleported, teleportMessage = teleportToSelectedEggForHatch()
    if not teleported then
        if S.safeNotify then
            S.safeNotify("Auto Trick → Hatch", teleportMessage, 6)
        end
        stopTrickTreatToHatch(teleportMessage)
        return
    end

    task.wait(0.4)
    if not trickTreatToHatchActive or token ~= trickTreatToHatchToken then
        return
    end

    if type(S.setAutoOpen) ~= "function" then
        stopTrickTreatToHatch("Original Auto Hatch system not found")
        return
    end
    local started = S.setAutoOpen(true)
    if not started then
        stopTrickTreatToHatch("Could not start Auto Hatch: check the selected egg")
        return
    end

    trickTreatToHatchPhase = "300M reached | Auto Hatch Running"
    trickTreatToHatchActive = false
    trickTreatToHatchToken = trickTreatToHatchToken + 1
    syncTrickTreatToHatchToggle(false)
    renderTrickTreatToHatchStatus(teleportMessage)
    if S.safeNotify then
        S.safeNotify(
            "Auto Trick → Hatch",
            "Candycorn reached " .. formatCurrencyAmount(TRICK_TREAT_CANDYCORN_TARGET)
                .. " and started opening " .. tostring(S.selectedEgg),
            7
        )
    end
end

stopTrickTreatToHatch = function(reason)
    local wasActive = trickTreatToHatchActive
    trickTreatToHatchActive = false
    trickTreatToHatchToken = trickTreatToHatchToken + 1
    trickTreatToHatchPhase = reason and ("Stopped: " .. tostring(reason)) or "Stopped"
    syncTrickTreatToHatchToggle(false)
    if wasActive or trickTreatActive then
        stopTrickTreat(reason or "Stopped Auto Trick → Hatch")
    end
    renderTrickTreatToHatchStatus()
end

local function startTrickTreatToHatch()
    if trickTreatToHatchActive then
        return
    end
    if autoTeleportActive then
        if S.safeNotify then
            S.safeNotify("Auto Trick → Hatch", "Please disable Auto Chest TP first", 5)
        end
        syncTrickTreatToHatchToggle(false)
        return
    end
    if not S.selectedEgg or S.selectedEgg == "" then
        if S.safeNotify then
            S.safeNotify("Auto Trick → Hatch", "Select an egg in the Hatch tab first", 5)
        end
        syncTrickTreatToHatchToggle(false)
        return
    end

    local current, source = readCandycorn()
    if current == nil then
        if S.safeNotify then
            S.safeNotify(
                "Auto Trick → Hatch",
                "Candycorn value not found in player data; system not started",
                7
            )
        end
        trickTreatToHatchPhase = "Stopped: Candycorn value not found"
        syncTrickTreatToHatchToggle(false)
        renderTrickTreatToHatchStatus("Could not find a leaderstat/Value named Candycorn")
        return
    end

    trickTreatToHatchActive = true
    trickTreatToHatchToken = trickTreatToHatchToken + 1
    local token = trickTreatToHatchToken
    trickTreatToHatchPhase = current >= TRICK_TREAT_CANDYCORN_TARGET
        and "Target reached. Going to open the egg"
        or "Collecting Candycorn with Trick or Treat"
    renderTrickTreatToHatchStatus("Data source: " .. tostring(source), current)

    if current < TRICK_TREAT_CANDYCORN_TARGET then
        startTrickTreat()
        local previous = trickTreatToggleSyncing
        trickTreatToggleSyncing = true
        pcall(function()
            if trickTreatToggle then
                trickTreatToggle:Set(true, "Running", false)
            end
        end)
        trickTreatToggleSyncing = previous
    end

    task.spawn(function()
        while trickTreatToHatchActive and token == trickTreatToHatchToken do
            if autoTeleportActive then
                stopTrickTreatToHatch("Auto Chest TP was enabled while running")
                break
            end
            if not S.hrp or not S.humanoid or S.humanoid.Health <= 0 then
                stopTrickTreatToHatch("Character not ready or respawning")
                break
            end

            local value = readCandycorn()
            if value == nil then
                stopTrickTreatToHatch("Could not read Candycorn")
                break
            end
            renderTrickTreatToHatchStatus(nil, value)
            if value >= TRICK_TREAT_CANDYCORN_TARGET then
                finishTrickTreatToHatch(token)
                break
            end
            if not trickTreatActive and not trickTreatWorkerRunning then
                startTrickTreat()
            end
            task.wait(TRICK_TREAT_CANDYCORN_POLL_INTERVAL)
        end
    end)
end

startTrickTreat = function()
    -- Opening Trick or Treat always takes ownership of movement. Stop Hatch
    -- and wait for its old worker to exit before starting this worker.
    if S.eggOpenActive or S.hatchWorkerRunning then
        if type(S.setAutoOpen) == "function" then
            pcall(S.setAutoOpen, false)
        end
        if S.autoOpenToggle then
            pcall(function() S.autoOpenToggle:Set(false, "Auto Trick or Treat enabled", false) end)
        end
        if S.hatchWorkerRunning then
            S.trickTreatStartPending = true
            return
        end
    end
    if trickTreatWorkerRunning then
        if not trickTreatActive then
            trickTreatStartPending = true
            S.trickTreatStartPending = true
            trickTreatActive = true
            S.trickTreatActive = true
        end
        return
    end
    if autoTeleportActive then
        if S.safeNotify then
            S.safeNotify("Trick or Treat", "Please disable Auto Chest TP first", 5)
        end
        stopTrickTreat("Auto Chest TP Running")
        return
    end

    trickTreatActive = true
    S.trickTreatActive = true
    trickTreatToken = trickTreatToken + 1
    local token = trickTreatToken
    trickTreatWorkerRunning = true
    S.trickTreatWorkerRunning = true
    table.clear(trickTreatBlockedUntil)

    task.spawn(function()
        while trickTreatActive and token == trickTreatToken do
            if not S.hrp or not S.humanoid or S.humanoid.Health <= 0 then
                stopTrickTreat("Character not ready or respawning")
                break
            end

            if #trickTreatTargets == 0
                or os.clock() - trickTreatLastScanAt >= TRICK_TREAT_SCAN_INTERVAL then
                scanTrickTreatActivations()
            end

            local target, waitFor = findNextTrickTreatTarget()
            if target then
                local ok, message = teleportToTrickTreatTarget(target)
                if ok then
                    trickTreatBlockedUntil[target.instance] = os.clock()
                        + TRICK_TREAT_COOLDOWN_SECONDS
                    renderTrickTreatProgress(message)
                else
                    trickTreatBlockedUntil[target.instance] = os.clock() + 3
                    renderTrickTreatProgress(message)
                end
                task.wait(math.max(0.5, trickTreatDelay))
            else
                renderTrickTreatProgress(
                    waitFor > 0
                        and string.format("Waiting for cooldown %.0f seconds", waitFor)
                        or "Waiting for a ready point"
                )
                task.wait(math.clamp(waitFor, 1, 5))
            end
        end
        trickTreatWorkerRunning = false
        S.trickTreatWorkerRunning = false
        if trickTreatStartPending and trickTreatActive then
            trickTreatStartPending = false
            S.trickTreatStartPending = false
            task.defer(startTrickTreat)
        end
    end)
end

S.scanTrickTreatActivations = scanTrickTreatActivations
S.startTrickTreat = startTrickTreat
S.stopTrickTreat = stopTrickTreat

FarmTab:CreateSection("Trick or Treat")
trickTreatParagraph = FarmTab:CreateParagraph({
    Title = "Trick or Treat Route",
    Content = "Found 0/12 Trick or Treat points\nReady: 0 | Cooldown: 0\nStatus: Stopped",
})

trickTreatToggle = S.createStatusToggle(FarmTab, {
    Name = "Auto TP Trick or Treat",
    Description = "Walk into the Activation ring so the game collects normally",
    CurrentValue = false,
    Flag = "TrickTreatAutoTeleport",
    Callback = function(value)
        if trickTreatToggleSyncing then
            return true
        end
        if value == true then
            startTrickTreat()
        else
            if trickTreatToHatchActive then
                stopTrickTreatToHatch("Stopped by user")
            else
                stopTrickTreat("Stopped by user")
            end
        end
        return true
    end,
})
S.trickTreatToggle = trickTreatToggle

-- Auto Trick -> Hatch was removed; keep its legacy helpers inert for compatibility.
if false then
trickTreatToHatchParagraph = FarmTab:CreateParagraph({
    Title = "Auto Trick → Hatch",
    Content = "Candycorn target: 300,000,000\nCurrent: Not available\nStatus: Stopped",
})

trickTreatToHatchToggle = S.createStatusToggle(FarmTab, {
    Name = "Auto Trick or Treat until 300M, then open egg",
    Description = "Uses the selected egg in the Hatch tab and runs once",
    CurrentValue = false,
    Flag = "TrickTreatToHatch300M",
    Callback = function(value)
        if trickTreatToggleSyncing then
            return true
        end
        if value == true then
            startTrickTreatToHatch()
        else
            stopTrickTreatToHatch("Stopped by user")
        end
        return true
    end,
})

FarmTab:CreateButton({
    Name = "Stop Auto Trick → Hatch",
    Callback = function()
        stopTrickTreatToHatch("Stopped by user")
    end,
})

end

FarmTab:CreateSlider({
    Name = "Trick or Treat TP delay",
    Range = {0.5, 5},
    Increment = 0.5,
    Suffix = " s",
    CurrentValue = 1,
    Flag = "TrickTreatTeleportDelay",
    Callback = function(value)
        trickTreatDelay = math.clamp(tonumber(value) or 1, 0.5, 5)
    end,
})

FarmTab:CreateButton({
    Name = "Scan Trick or Treat Now",
    Callback = function()
        local ok, count = pcall(scanTrickTreatActivations)
        if S.safeNotify then
            S.safeNotify(
                "Trick or Treat",
                ok
                    and ("Found Activation " .. tostring(count) .. " points")
                    or ("Scan failed: " .. tostring(count)),
                5
            )
        end
    end,
})

FarmTab:CreateButton({
    Name = "Stop Trick or Treat TP",
    Callback = function()
        stopTrickTreat("Stopped by user")
    end,
})

FarmTab:CreateSection("Chest Manager")
autoTeleportToggle = S.createStatusToggle(FarmTab, {
    Name = "Auto TP to Scanned Chests",
    Description = "Auto Chest",
    CurrentValue = false,
    Flag = "ChestScannerAutoTeleport",
    Callback = function(value)
        if autoToggleSyncing then
            return true
        end
        if value == true then
            startAutoTeleport()
        else
            stopAutoTeleport("Stopped by user")
        end
        return true
    end,
})

FarmTab:CreateSlider({
    Name = "Auto Chest TP delay",
    Range = {0.25, 5},
    Increment = 0.25,
    Suffix = " s",
    CurrentValue = 0.75,
    Flag = "ChestScannerAutoTeleportDelay",
    Callback = function(value)
        autoTeleportDelay = math.clamp(tonumber(value) or 0.75, 0.25, 5)
    end,
})

FarmTab:CreateButton({
    Name = "Stop Auto Chest TP",
    Callback = function()
        stopAutoTeleport("Stopped by user")
    end,
})

chestRouteParagraph = FarmTab:CreateParagraph({
    Title = "Chest Route Progress",
    Content = "Teleported 0/0\nOn cooldown: 0\nSkipped/waiting to retry: 0\nStatus: Stopped",
})

FarmTab:CreateButton({
    Name = "Retry skipped chests",
    Callback = retrySkippedAutoChests,
})

FarmTab:CreateSection("Scanner & Cooldown")
resultsParagraph = FarmTab:CreateParagraph({
    Title = "Chest Scanner",
    Content = "Scanner ready | Not scanned yet",
})

autoScanToggle = S.createStatusToggle(FarmTab, {
    Name = "Auto Scan Chest",
    Description = "Scanner",
    CurrentValue = false,
    Flag = "ChestScannerAutoScan",
    Callback = function(value)
        autoScan = value == true
        S.chestScannerAutoScan = autoScan
        if autoScan then
            startWorker()
        else
            workerToken = workerToken + 1
        end
    end,
})

FarmTab:CreateButton({
    Name = "Scan Chests Now",
    Callback = function()
        local ok, result = scan()
        if S.safeNotify then
            S.safeNotify(
                "Chest Scanner",
                ok and ("Found " .. tostring(result) .. " chests") or tostring(result),
                5
            )
        end
    end,
})

FarmTab:CreateButton({
    Name = "Dump Trick or Treat (Console)",
    Callback = function()
        local ok, count = pcall(dumpTrickOrTreatObjects)
        if S.safeNotify then
            S.safeNotify(
                "Trick or Treat Dump",
                ok
                    and ("Dump complete: " .. tostring(count) .. " candidate(s); see the Console")
                    or ("Dump failed: " .. tostring(count)),
                6
            )
        end
    end,
})

FarmTab:CreateButton({
    Name = "Dump Trick or Treat Details",
    Callback = function()
        local ok, count = pcall(dumpTrickOrTreatDetails)
        if S.safeNotify then
            S.safeNotify(
                "Trick or Treat Details",
                ok
                    and ("Found Activation " .. tostring(count) .. " points; see the Console")
                    or ("Dump failed: " .. tostring(count)),
                6
            )
        end
    end,
})

cooldownParagraph = FarmTab:CreateParagraph({
    Title = "Chest Cooldown Scanner",
    Content = "Click Scan Chests Now to read the cooldown status of every found chest",
})

teleportStatusParagraph = FarmTab:CreateParagraph({
    Title = "Chest TP",
    Content = "Sort by chest name | Teleport to a safe point near the chest without opening or collecting automatically",
})

FarmTab:CreateButton({
    Name = "Teleport to Next Chest by Name",
    Callback = function()
        local ok, message = teleportToNearestScannedChest()
        setTeleportStatus(ok and message or ("Failed: " .. tostring(message)))
    end,
})

local previousStopAllFeatures = S.stopAllFeatures
function S.stopAllFeatures()
    if previousStopAllFeatures then
        previousStopAllFeatures()
    end
    stopScanner()
    stopTrickTreatToHatch("Stopped with all systems")
end

scan()
end

local S=_G.BGS.shared
local helperBusy={}
function S.personalRun(name)
    local fn=helpers[name]
    if not fn then return false,"Unknown helper: "..tostring(name) end
    if helperBusy[name] then return false,"Helper is already starting: "..name end
    helperBusy[name]=true
    local ok,err=pcall(fn)
    helperBusy[name]=nil
    if not ok then
        warn("[BGS Personal] "..name..": "..tostring(err))
        if S.Rayfield then
            pcall(function() S.Rayfield:Notify({Title="BGS Personal",Content=tostring(err),Duration=8}) end)
        end
    end
    return ok,err
end
for _,name in ipairs({"core","ui","farm","chestscanner","hatch","bubbles","client","premium","settings"}) do
    local ok,err=pcall(modules[name])
    if not ok then
        _G.BGS.personalError=name..": "..tostring(err)
        if S.stopAllFeatures then pcall(S.stopAllFeatures) end
        if S.Rayfield then
            pcall(function() S.Rayfield:Notify({Title="BGS Personal load failed",
                Content=_G.BGS.personalError.." | Rejoin before retrying.",Duration=15}) end)
        end
        error(_G.BGS.personalError)
    end
end
local settingsOk,settingsError=pcall(installPersonalSettings,S,false)
if not settingsOk then
    warn("[BGS Personal] Remember settings unavailable: "..tostring(settingsError))
    pcall(function() S.Rayfield:Notify({Title="Remember settings unavailable",Content=tostring(settingsError),Duration=10}) end)
end
_G.BGS.personalReady=true
S.Rayfield:Notify({Title="BGS Personal ready",
    Content="Hatch: select an egg, then enable Auto open. PC connection is optional under Premium.",Duration=10})
