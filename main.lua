--==================================================
-- LOAD UI MODULE FROM GITHUB
--==================================================
local VERSION = "Lezor v2.1"
local UI_URL = "https://raw.githubusercontent.com/NetanyahuLLC/Niggas-In-Paris/refs/heads/main/ui.lua"

local function log(...)
    print("[Lezor]", ...)
end

-- Try every HTTP method the executor might expose
local function fetchSource()
    if type(game) == "table" or typeof(game) == "Instance" then
        local ok, result = pcall(function() return game:HttpGet(UI_URL) end)
        if ok and type(result) == "string" and result:find("%S") then
            log("ui.lua downloaded via game:HttpGet (" .. #result .. " bytes)")
            return result
        end
        log("game:HttpGet failed:", result)
    end
    if type(request) == "function" then
        local ok, result = pcall(function()
            return request({Url = UI_URL, Method = "GET"}).Body
        end)
        if ok and type(result) == "string" and result:find("%S") then
            log("ui.lua downloaded via request() (" .. #result .. " bytes)")
            return result
        end
        log("request() failed:", result)
    end
    if type(http_request) == "function" then
        local ok, result = pcall(function()
            return http_request({Url = UI_URL, Method = "GET"}).Body
        end)
        if ok and type(result) == "string" and result:find("%S") then
            log("ui.lua downloaded via http_request() (" .. #result .. " bytes)")
            return result
        end
        log("http_request() failed:", result)
    end
    return nil
end

log("starting " .. VERSION .. "...")
local source = fetchSource()
if not source then
    error("[Lezor] Could not download ui.lua from GitHub. Check your executor's HTTP settings / try a VPN.", 0)
end

if type(loadstring) ~= "function" then
    error("[Lezor] loadstring is not available in this executor.", 0)
end
local chunk, parseError = loadstring(source, "ui.lua")
if not chunk then
    error("[Lezor] Downloaded ui.lua has a syntax error:\n" .. tostring(parseError), 0)
end
log("ui.lua compiled OK")

local executeOK, result = pcall(chunk)
if not executeOK then
    error("[Lezor] ui.lua failed while executing:\n" .. tostring(result), 0)
end
log("ui.lua executed OK")
if type(result) ~= "table" or type(result.new) ~= "function" then
    error("[Lezor] ui.lua did not return a valid module with UI.new(options).", 0)
end
local UI = result

--==================================================
-- GAME SERVICES / CONFIGURATION
--==================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

-- FIX: Added timeouts to prevent infinite yields if the game structure changes
local stockFolder = player:WaitForChild("ShopStock", 10)
if not stockFolder then
    warn("[Lezor] ShopStock folder not found. Some features may not work.")
    stockFolder = Instance.new("Folder") -- Safe fallback
end

local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local Config = sharedFolder and sharedFolder:WaitForChild("Config", 10) and require(sharedFolder.Config) or {}
if not next(Config) then
    warn("[Lezor] Config module not found or empty. Using empty config.")
end

local EPOCH_SECONDS = 30
local UPDATE_INTERVAL = 1
local SOUND_FILE = "neverlose.wav"
local SOUND_VOLUME = 1

--==================================================
-- SETTINGS CACHE (executor file IO, memory fallback)
--==================================================
local CACHE_FILE = "lezor_settings.json"
local persist -- forward declaration; assigned after autobuy state exists

local function loadSettings()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return {}
    end
    local ok, data = pcall(function()
        if not isfile(CACHE_FILE) then return nil end
        return readfile(CACHE_FILE)
    end)
    if not ok or type(data) ~= "string" or not data:find("%S") then
        return {}
    end
    local okJ, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(data)
    end)
    if okJ and type(result) == "table" then
        return result
    end
    return {}
end

local function writeSettings(settings)
    if type(writefile) ~= "function" then return false end
    local okJ, data = pcall(function()
        return game:GetService("HttpService"):JSONEncode(settings)
    end)
    if not okJ or type(data) ~= "string" then return false end
    local ok = pcall(function() writefile(CACHE_FILE, data) end)
    if ok then
        log("settings cached")
    end
    return ok == true
end

--==================================================
-- DATA HELPERS
--==================================================
local function number(value)
    local n = tonumber(value)
    if n and n == n and n ~= math.huge and n ~= -math.huge then
        return n
    end
end

local WORD_SCALES = {
    {1e12, " Trillion"},
    {1e9, " Billion"},
    {1e6, " Million"},
    {1e3, "k"},
}

local function formatNumber(value)
    local n = number(value)
    if not n then return "N/A" end
    local absN = math.abs(n)
    for index, scale in ipairs(WORD_SCALES) do
        if absN >= scale[1] then
            local value = n / scale[1]
            local text = string.format("%.1f", value):gsub("%.0$", "")
            -- 999,999 would round to "1000k"; promote to the next tier instead
            local bigger = WORD_SCALES[index - 1]
            if bigger and tonumber(text) and tonumber(text) >= 1000 then
                text = string.format("%.1f", n / bigger[1]):gsub("%.0$", "")
                return text .. bigger[2]
            end
            return text .. scale[2]
        end
    end
    if n % 1 == 0 then return tostring(math.floor(n)) end
    return string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
end

local function seconds(value)
    value = math.max(0, math.floor(value))
    if value >= 60 then
        return string.format("%dm %02ds", math.floor(value / 60), value % 60)
    end
    return tostring(value) .. "s"
end

local function priceOf(data)
    for _, key in ipairs({"cost", "Cost", "price", "Price"}) do
        local n = number(data[key])
        if n and n >= 0 then return n end
    end
end

local function sortedItems(dict)
    local items = {}
    if type(dict) ~= "table" then return items end

    for key, data in pairs(dict) do
        if type(data) == "table" then
            table.insert(items, {
                key = tostring(key),
                name = tostring(data.name or key),
                price = priceOf(data),
            })
        end
    end

    table.sort(items, function(a, b)
        if a.price == nil and b.price ~= nil then return false end
        if a.price ~= nil and b.price == nil then return true end
        if a.price ~= nil and b.price ~= nil and a.price ~= b.price then
            return a.price < b.price
        end
        local nameA = a.name:lower()
        local nameB = b.name:lower()
        if nameA == nameB then return a.key < b.key end
        return nameA < nameB
    end)
    return items
end

--==================================================
-- UI / LIFECYCLE
--==================================================
log("building window...")
local view = UI.new({
    Name = "Lezor",
    Title = "Lezor",
    Parent = player:WaitForChild("PlayerGui"),
})
log("window created")

local alive = true
local connections = {}
local sounds = {}
local states = {}
local soundEnabled = true

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function stopSounds()
    for sound in pairs(sounds) do
        pcall(function() sound:Stop() end)
        pcall(function() sound:Destroy() end)
        sounds[sound] = nil
    end
end

connect(view.Destroyed, function()
    alive = false
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    stopSounds()
    table.clear(connections)
end)

--==================================================
-- SOUND
--==================================================
local soundAsset
if type(getcustomasset) == "function" then
    local ok, result = pcall(function()
        if type(isfile) == "function" and not isfile(SOUND_FILE) then
            error("Missing executor workspace file: " .. SOUND_FILE)
        end
        return getcustomasset(SOUND_FILE)
    end)
    if ok and type(result) == "string" and result ~= "" then
        soundAsset = result
    else
        warn("[Lezor] Sound disabled:", result)
    end
else
    warn("[Lezor] getcustomasset unavailable; sound disabled.")
end

local function playSound()
    if not alive or not soundEnabled or not soundAsset then return end

    local sound = Instance.new("Sound")
    sound.Name = "MarketHubPriceChange"
    sound.SoundId = soundAsset
    sound.Volume = SOUND_VOLUME
    sound.Parent = SoundService
    sounds[sound] = true

    sound.Destroying:Once(function()
        sounds[sound] = nil
    end)
    sound.Ended:Once(function()
        pcall(function() sound:Destroy() end)
    end)
    Debris:AddItem(sound, 30)

    local ok, err = pcall(function() sound:Play() end)
    if not ok then
        sounds[sound] = nil
        pcall(function() sound:Destroy() end)
        warn("[Lezor] Playback error:", err)
    end
end

--==================================================
-- STOCK / ALERTS
--==================================================
local function readStock(id)
    local value = stockFolder:FindFirstChild(id)
    if value and value:IsA("ValueBase") then
        return number(value.Value) or 0
    end
    return 0
end

local function checkAlert(id, amount)
    local state = states[id]
    if not state or not state.enabled then return end

    if amount > 0 and not state.alerted then
        state.alerted = true
        view:Notify("STOCK ALERT", state.name .. " is available  |  Stock: " .. formatNumber(amount))
    elseif amount <= 0 then
        state.alerted = false
    end
end

connect(view.AlertToggled, function(id)
    local state = states[id]
    if not state then return end
    state.enabled = not state.enabled
    state.alerted = false
    view:SetAlertEnabled(id, state.enabled)
    if state.enabled then checkAlert(id, readStock(id)) end
end)

connect(view.SoundToggled, function(enabled)
    soundEnabled = enabled == true
    if not soundEnabled then stopSounds() end
    if persist then persist() end
end)

for _, category in ipairs({
    {name = "Hardware", data = Config.Hardware},
    {name = "Data Sources", data = Config.DataSources},
    {name = "Data Packs", data = Config.Datasets},
}) do
    for index, item in ipairs(sortedItems(category.data)) do
        local id = category.name .. "/" .. item.key
        states[id] = states[id] or {
            name = item.name,
            enabled = false,
            alerted = false,
        }

        local priceText = "Cost: N/A"
        if item.price == 0 then
            priceText = "Cost: Free"
        elseif item.price ~= nil then
            priceText = "Cost: $" .. formatNumber(item.price)
        end

        view:AddItem(category.name, {
            id = id,
            name = item.name,
            order = index,
            priceText = priceText,
        })
    end
end

--==================================================
-- BLACK MARKET CRATES (dealer stock + buying)
-- Mirrors the game's BlackMarketUI client: stock lives on the
-- "CrateStock_<tierId>" player attribute, and buying fires
-- Remotes.BlackMarketBuy:InvokeServer("crate", tierId).
--==================================================
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local blackMarketBuy = remotes and remotes:WaitForChild("BlackMarketBuy", 10) or nil
if not blackMarketBuy then
    warn("[Lezor] BlackMarketBuy remote not found; crate buying disabled.")
end

local crateStates = {}
do
    local tiers = (type(Config.CrateShop) == "table") and Config.CrateShop.tiers or nil
    if type(tiers) == "table" then
        local order = 0
        for _, tier in pairs(tiers) do
            if type(tier) == "table" and tier.dealerEnabled ~= false then
                order = order + 1
                local id = tostring(tier.id)
                crateStates[id] = {tier = tier, lastStock = nil, buying = false, order = order}

                local price = number(tier.priceTokens)
                local priceText = (price ~= nil)
                    and ("Cost: " .. formatNumber(price))
                    or "Cost: N/A"

                view:AddCrate({
                    id = id,
                    name = tostring(tier.name or id),
                    order = order,
                    priceText = priceText,
                })
            end
        end
    else
        warn("[Lezor] CrateShop tiers not found in Config.")
    end
end

local function myTokens()
    return number(player:GetAttribute("Tokens")) or 0
end

local function readCrateStock(id)
    local n = number(player:GetAttribute("CrateStock_" .. id))
    if n then return math.max(0, math.floor(n)) end
    return 0
end

--==================================================
-- AUTO BUY (config widget + teleport + warp home)
--==================================================
local DEALER_CFRAME = CFrame.new(-342, 2.3499999, -43.7999992, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local warpRemote = remotes and remotes:WaitForChild("Warp", 10) or nil
if not warpRemote then
    warn("[Lezor] Warp remote not found; cannot return home after buying.")
end

local sellTokensRemote = remotes and remotes:WaitForChild("SellTokens", 10) or nil
if not sellTokensRemote then
    warn("[Lezor] SellTokens remote not found yet; will retry automatically.")
end

-- Re-resolve on every check: remotes can replicate in late, and a one-shot
-- WaitForChild timeout would otherwise disable auto-sell for the whole session.
local function getSellRemote()
    if sellTokensRemote and sellTokensRemote.Parent then return sellTokensRemote end
    if not remotes then remotes = ReplicatedStorage:FindFirstChild("Remotes") end
    if remotes then sellTokensRemote = remotes:FindFirstChild("SellTokens") end
    return sellTokensRemote
end

local function getWarpRemote()
    if warpRemote and warpRemote.Parent then return warpRemote end
    if not remotes then remotes = ReplicatedStorage:FindFirstChild("Remotes") end
    if remotes then warpRemote = remotes:FindFirstChild("Warp") end
    return warpRemote
end

local COLLECT_CFRAME = CFrame.new(51.5, 0.625, -27.2000008, 1, 0, 0, 0, 1, 0, 0, 0, 1)

-- Resolve the local player's plot via the PlotId attribute (same mechanism
-- as the game's PlotOwnerBillboard client), then return a drop CFrame 3
-- studs above the top of that plot's CollectPad model.
local function findCollectDropCFrame()
    local plotId = player:GetAttribute("PlotId")
    local map = Workspace:FindFirstChild("Map")
    local generated = map and map:FindFirstChild("Generated")
    local plots = generated and generated:FindFirstChild("Plots")

    if typeof(plotId) == "number" and plots then
        for _, plot in ipairs(plots:GetChildren()) do
            if plot:GetAttribute("PlotId") == plotId then
                local pad = plot:FindFirstChild("CollectPad")
                if pad then
                    if pad:IsA("BasePart") then
                        return CFrame.new(pad.Position + Vector3.new(0, pad.Size.Y / 2 + 3, 0))
                            * (pad.CFrame - pad.CFrame.Position)
                    end
                    local ok, cf, size = pcall(function()
                        return pad:GetBoundingBox()
                    end)
                    if ok and cf then
                        return CFrame.new(cf.Position + Vector3.new(0, (size.Y or 0) / 2 + 3, 0))
                            * (cf - cf.Position)
                    end
                end
            end
        end
    end

    return nil -- plot/pad not found yet
end

local autobuyActive = false
local autobuySession = false
local autobuyRows = {}

local function teleportToDealer()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = DEALER_CFRAME
        return true
    end
    return false
end

local function goHome()
    if warpRemote then
        pcall(function() warpRemote:FireServer("Home") end)
    end
end

for id, state in pairs(crateStates) do
    autobuyRows[id] = enabled = false, count = 1, bought = 0}
    view:SetAutobuyProgress(id, "0/1 bought")
end

--==================================================
-- SETTINGS PERSISTENCE
--==================================================
local settings = loadSettings()

persist = function()
    local crates = {}
    for id, row in pairs(autobuyRows) do
        crates[id] = {enabled = row.enabled, count = row.count}
    end
    settings.sound = soundEnabled
    settings.autosell = {enabled = autosell.active, balance = autosell.balance, price = autosell.price}
    settings.autocollect = {enabled = autocollect.active, interval = autocollect.interval}
    settings.autobuy = {master = autobuyActive, crates = crates}
    writeSettings(settings)
end

-- restore cached state onto the widgets
if settings.sound == false then
    soundEnabled = false
    view:SetSoundEnabled(false)
end
if type(settings.autosell) == "table" then
    autosell.active = settings.autosell.enabled == true
    autosell.balance = number(settings.autosell.balance)
    autosell.price = number(settings.autosell.price)
    view:SetAutosellEnabled(autosell.active)
    view:SetAutosellBalance(autosell.balance)
    view:SetAutosellPrice(autosell.price)
end
if type(settings.autocollect) == "table" then
    autocollect.active = settings.autocollect.enabled == true
    autocollect.interval = math.max(10, number(settings.autocollect.interval) or 300)
    view:SetAutocollectEnabled(autocollect.active)
    view:SetAutocollectInterval(autocollect.interval)
end
if type(settings.autobuy) == "table" then
    autobuyActive = settings.autobuy.master == true
    view:SetAutobuyMaster(autobuyActive)
    if type(settings.autobuy.crates) == "table" then
        for id, cfg in pairs(settings.autobuy.crates) do
            local row = autobuyRows[id]
            if row and type(cfg) == "table" then
                row.enabled = cfg.enabled == true
                row.count = math.clamp(math.floor(number(cfg.count) or 1), 1, 99)
                view:SetAutobuyCrate(id, row.enabled, row.count)
                view:SetAutobuyProgress(id, row.bought .. "/" .. row.count .. " bought")
            end
        end
    end
end
log("settings restored from cache")

connect(view.AutobuyRowToggled, function(id, enabled)
    local row = autobuyRows[id]
    if not row then return end
    row.enabled = enabled == true
    if row.enabled then row.bought = 0 end
    view:SetAutobuyProgress(id, row.bought .. "/" .. row.count .. " bought")
    if persist then persist() end
end)

connect(view.AutobuyCountChanged, function(id, count)
    local row = autobuyRows[id]
    if not row then return end
    row.count = math.clamp(math.floor(number(count) or 1), 1, 99)
    row.bought = 0
    view:SetAutobuyProgress(id, "0/" .. row.count .. " bought")
    if persist then persist() end
end)

connect(view.AutobuyMasterToggled, function(enabled)
    autobuyActive = enabled == true
    if persist then persist() end
end)

local autosell = {active = false, balance = nil, price = nil, busy = false, lastSell = 0}
local SELL_COOLDOWN = 120 -- seconds between auto-sells
connect(view.AutosellToggled, function(enabled)
    autosell.active = enabled == true
    if persist then persist() end
end)
connect(view.AutosellBalance, function(value)
    autosell.balance = number(value)
    if persist then persist() end
end)
connect(view.AutosellPrice, function(value)
    autosell.price = number(value)
    if persist then persist() end
end)

local autocollect = {active = false, interval = 300, last = 0}
connect(view.AutocollectToggled, function(enabled)
    autocollect.active = enabled == true
    if persist then persist() end
end)
connect(view.AutocollectInterval, function(value)
    autocollect.interval = math.max(10, number(value) or 300)
    if persist then persist() end
end)

local function updateCrates()
    local tokens = myTokens()
    for id, state in pairs(crateStates) do
        local amount = readCrateStock(id)
        local autobuyRow = autobuyRows[id]
        if autobuyRow and amount <= 0 and autobuyRow.bought > 0 then
            -- restock gives a fresh purchase window
            autobuyRow.bought = 0
            view:SetAutobuyProgress(id, "0/" .. autobuyRow.count .. " bought")
        end
        if state.lastStock ~= amount then
            state.lastStock = amount
            view:SetCrateStock(
                id,
                amount > 0 and ("Stock: " .. formatNumber(amount)) or "OUT OF STOCK",
                amount > 0
            )
        end

        local price = number(state.tier.priceTokens) or 0
        if state.buying then
            view:SetCrateBuy(id, "BUYING...", false)
        elseif amount <= 0 then
            view:SetCrateBuy(id, "SOLD OUT", false)
        elseif tokens < price then
            view:SetCrateBuy(id, "NEED " .. formatNumber(price), false)
        else
            view:SetCrateBuy(id, "BUY", true)
        end
    end
end

connect(view.CrateBuy, function(id)
    local state = crateStates[id]
    if not state or state.buying then return end

    if not blackMarketBuy then
        view:Notify("CRATES", "Buy remote unavailable")
        return
    end

    local amount = readCrateStock(id)
    if amount <= 0 then
        view:Notify("CRATES", tostring(state.tier.name or id) .. " is out of stock")
        return
    end

    local price = number(state.tier.priceTokens) or 0
    if myTokens() < price then
        view:Notify("CRATES", "Not enough tokens (need " .. formatNumber(price) .. ")")
        return
    end

    state.buying = true
    updateCrates()

    task.spawn(function()
        -- Teleport to the dealer so the server never rejects for distance
        teleportToDealer()
        task.wait(0.5)

        local ok, result = pcall(function()
            return blackMarketBuy:InvokeServer("crate", id)
        end)

        state.buying = false

        if not ok then
            view:Notify("Buy failed: " .. tostring(result))
        elseif type(result) == "table" then
            if result.ok then
                view:Notify("CRATES", "Bought " .. tostring(state.tier.name or id))
                playSound()
            else
                view:Notify(tostring(result.message or "Can't buy"))
            end
        else
            view:Notify("Unexpected server response")
        end

        goHome()
        updateCrates()
    end)
end)

--==================================================
-- AUTO BUY SESSION RUNNER
--==================================================
local function pickAutobuyTarget()
    if not blackMarketBuy then return nil end
    local tokens = myTokens()
    for id, row in pairs(autobuyRows) do
        if row.enabled and row.bought < row.count then
            local state = crateStates[id]
            local price = number(state.tier.priceTokens) or 0
            if readCrateStock(id) > 0 and tokens >= price then
                return id
            end
        end
    end
    return nil
end

local function runAutobuySession(id)
    if autobuySession then return end
    autobuySession = true
    local row = autobuyRows[id]
    local state = crateStates[id]

    view:Notify("AUTO BUY", "Heading to dealer for " .. tostring(state.tier.name or id))

    if not teleportToDealer() then
        view:Notify("AUTO BUY", "Failed: character not loaded")
        autobuySession = false
        return
    end
    task.wait(0.5) -- let the server register our position

    while alive and autobuyActive and row.enabled and row.bought < row.count do
        if readCrateStock(id) <= 0 then break end
        local price = number(state.tier.priceTokens) or 0
        if myTokens() < price then break end

        local ok, result = pcall(function()
            return blackMarketBuy:InvokeServer("crate", id)
        end)
        if not ok then
            view:Notify("Buy failed: " .. tostring(result))
            break
        end
        if type(result) == "table" and result.ok then
            row.bought = row.bought + 1
            view:SetAutobuyProgress(id, row.bought .. "/" .. row.count .. " bought")
            playSound()
        else
            view:Notify(tostring((type(result) == "table" and result.message) or "Can't buy"))
            break
        end
        task.wait(0.7) -- pace requests to avoid rate limits
    end

    goHome()
    autobuySession = false
end

task.spawn(function()
    while alive do
        local ok, err = pcall(function()
            if autobuyActive and not autobuySession and blackMarketBuy then
                local target = pickAutobuyTarget()
                if target then
                    runAutobuySession(target)
                end
            end
        end)
        if not ok then warn("[Lezor] Auto-buy error:", err) end
        task.wait(0.5)
    end
end)

--==================================================
-- TOKEN PRICE
--==================================================
local lastPrice = number(Workspace:GetAttribute("TokenPrice"))

local function updatePrice(allowNotification)
    if not alive then return end
    local price = number(Workspace:GetAttribute("TokenPrice"))

    view:SetTokenPrice(price ~= nil and ("$" .. formatNumber(price)) or "--")

    if allowNotification and price ~= nil and lastPrice ~= nil and price ~= lastPrice then
        local difference = price - lastPrice
        local direction = difference > 0 and "increased" or "decreased"
        local sign = difference > 0 and "+" or ""
        view:Notify("TOKEN EXCHANGE", string.format(
            "Token price %s: $%s -> $%s (%s$%s)",
            direction,
            formatNumber(lastPrice),
            formatNumber(price),
            sign,
            formatNumber(difference)
        ))
        playSound()
    end

    lastPrice = price
end

connect(Workspace:GetAttributeChangedSignal("TokenPrice"), function()
    updatePrice(true)
end)
updatePrice(false)

--==================================================
-- PERIODIC UPDATE
--==================================================
local function update()
    if not alive then return end
    local now = Workspace:GetServerTimeNow()

    view:SetEpochTimer(seconds(EPOCH_SECONDS - math.floor(now) % EPOCH_SECONDS))

    local restock = stockFolder:FindFirstChild("RestockAt")
    local at = restock and restock:IsA("ValueBase") and number(restock.Value)
    view:SetRestockTimer(at and seconds(math.max(0, math.ceil(at - now))) or "--")

    for id, state in pairs(states) do
        local amount = readStock(id)
        if state.lastStock ~= amount then
            state.lastStock = amount
            view:SetStock(id, "Stock: " .. formatNumber(amount), amount > 0)
        end
        checkAlert(id, amount)
    end

    updateCrates()
end

task.spawn(function()
    while alive do
        local ok, err = pcall(update)
        if not ok then warn("[Lezor] Update error:", err) end
        task.wait(UPDATE_INTERVAL)
    end
end)

--==================================================
-- AUTO SELL + AUTO COLLECT RUNNER
--==================================================
local function performSell()
    if autosell.busy then return end
    autosell.busy = true

    local ok, err = pcall(function()
        view:Notify("AUTO SELL", "Warping to exchange")

        local warp = getWarpRemote()
        if warp then
            pcall(function() warp:FireServer("Sell") end)
        end
        task.wait(1.2)

        local sell = getSellRemote()
        if sell then
            local fired, fireErr = pcall(function()
                if sell:IsA("RemoteFunction") then
                    sell:InvokeServer()
                else
                    sell:FireServer()
                end
            end)
            if not fired then
                view:Notify("Sell failed: " .. tostring(fireErr))
            else
                view:Notify("AUTO SELL", "Sold at exchange")
            end
        else
            view:Notify("AUTO SELL", "SellTokens remote still missing")
        end
        task.wait(1)

        if warp then
            pcall(function() warp:FireServer("Home") end)
        end
    end)
    if not ok then
        view:Notify("Auto-sell error: " .. tostring(err))
    end

    autosell.lastSell = tick()
    autosell.busy = false
end

task.spawn(function()
    while alive do
        local ok, err = pcall(function()
            local tokens = myTokens()
            local price = number(Workspace:GetAttribute("TokenPrice"))
            local sellR = getSellRemote()
            local warpR = getWarpRemote()

            -- auto sell: surface the exact blocker on the status line
            if not autosell.active then
                view:SetAutosellStatus("AUTO SELL off | Tokens: " .. formatNumber(tokens)
                    .. " | Exchange: " .. (price and ("$" .. formatNumber(price)) or "--"))
            elseif autosell.busy then
                view:SetAutosellStatus("SELLING...")
            elseif not sellR then
                view:SetAutosellStatus("BLOCKED: SellTokens remote missing")
            elseif not warpR then
                view:SetAutosellStatus("BLOCKED: Warp remote missing")
            elseif tick() - autosell.lastSell < SELL_COOLDOWN then
                view:SetAutosellStatus("cooldown " .. math.ceil(SELL_COOLDOWN - (tick() - autosell.lastSell)) .. "s")
            else
                local waiting = nil
                if autosell.balance and tokens < autosell.balance then
                    waiting = "tokens " .. formatNumber(tokens) .. " < " .. formatNumber(autosell.balance)
                end
                if autosell.price and (price == nil or price < autosell.price) then
                    waiting = (waiting and (waiting .. " | ") or "")
                        .. "price " .. (price and ("$" .. formatNumber(price)) or "--") .. " < $" .. formatNumber(autosell.price)
                end
                if waiting then
                    view:SetAutosellStatus("waiting: " .. waiting)
                else
                    view:SetAutosellStatus("conditions met — selling")
                    task.spawn(performSell)
                end
            end

            -- auto collect: drop onto your plot's CollectPad on interval
            if autocollect.active
                and not autobuySession
                and not autosell.busy
                and tick() - autocollect.last >= autocollect.interval then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local drop = findCollectDropCFrame()
                    if drop then
                        hrp.CFrame = drop
                        autocollect.last = tick()
                        view:Notify("AUTO COLLECT", "Dropped on your CollectPad")
                        -- land, collect, then head home
                        task.delay(3, function()
                            if alive and warpRemote then
                                pcall(function() warpRemote:FireServer("Home") end)
                            end
                        end)
                    else
                        -- plot or CollectPad not resolved yet; retry next tick
                        hrp.CFrame = COLLECT_CFRAME + Vector3.new(0, 3, 0)
                        autocollect.last = tick()
                        view:Notify("AUTO COLLECT", "Plot not found, using fallback spot")
                        task.delay(3, function()
                            if alive and warpRemote then
                                pcall(function() warpRemote:FireServer("Home") end)
                            end
                        end)
                    end
                end
            end
        end)
        if not ok then warn("[Lezor] Sell/collect error:", err) end
        task.wait(1)
    end
end)

log(VERSION .. " loaded. Press Right Shift to open or close.")
view:Notify("LEZOR", VERSION .. " loaded")
