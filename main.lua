-- EXECUTOR/GITHUB LOADER:
-- Replace only this URL with the raw URL of your repository's ui.lua.
local UI_URL = "https://raw.githubusercontent.com/NetanyahuLLC/Niggas-In-Paris/refs/heads/main/ui.lua?token=GHSAT0AAAAAAENGCRHXZBZ2OXAIQN7OKCP62WYKRWQ"
assert(UI_URL ~= "https://raw.githubusercontent.com/NetanyahuLLC/Niggas-In-Paris/refs/heads/main/ui.lua?token=GHSAT0AAAAAAENGCRHXZBZ2OXAIQN7OKCP62WYKRWQ", "Set UI_URL to your raw GitHub ui.lua URL first.")
local source = game:HttpGet(UI_URL)
local chunk, parseError = loadstring(source, "ui.lua")
assert(chunk, parseError)
local UI = chunk()
assert(type(UI) == "table" and type(UI.new) == "function", "ui.lua must return the UI module")

-- In Roblox Studio, replace the loader above with:
-- local UI = require(script.Parent:WaitForChild("ui"))

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local stockFolder = player:WaitForChild("ShopStock")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EPOCH_SECONDS, UPDATE_INTERVAL = 30, 1
local SOUND_FILE, SOUND_VOLUME, SOUND_PRICE = "hitsound.wav", 1, 13

local function number(value)
    local n = tonumber(value)
    if n and n == n and n ~= math.huge and n ~= -math.huge then return n end
end
local function formatNumber(value)
    local n = number(value)
    if not n then return "N/A" end
    if n % 1 == 0 then return tostring(math.floor(n)) end
    local text = string.format("%.2f",n):gsub("0+$",""):gsub("%.$","")
    return text
end
local function seconds(n)
    n = math.max(0,math.floor(n))
    if n >= 60 then return string.format("%dm %02ds",math.floor(n/60),n%60) end
    return tostring(n) .. "s"
end
local function priceOf(data)
    for _, key in ipairs({"cost","Cost","price","Price"}) do
        local n = number(data[key])
        if n and n >= 0 then return n end
    end
end
local function sortedItems(dict)
    local items = {}
    if type(dict) ~= "table" then return items end
    for key, data in pairs(dict) do
        if type(data) == "table" then
            table.insert(items,{key = tostring(key), name = tostring(data.name or key), price = priceOf(data)})
        end
    end
    table.sort(items,function(a,b)
        if a.price == nil and b.price ~= nil then return false end
        if a.price ~= nil and b.price == nil then return true end
        if a.price ~= nil and b.price ~= nil and a.price ~= b.price then return a.price < b.price end
        if a.name:lower() == b.name:lower() then return a.key < b.key end
        return a.name:lower() < b.name:lower()
    end)
    return items
end

local view = UI.new({Name = "TokenMarketHub", Title = "Token Market", Parent = player:WaitForChild("PlayerGui")})
local alive, connections, sounds, states = true, {}, {}, {}
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections,connection)
    return connection
end
connect(view.Destroyed,function()
    alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for sound in pairs(sounds) do sound:Destroy() end
    table.clear(connections)
    table.clear(sounds)
end)

-- Audio belongs to the controller, not the UI module.
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
        warn("[Market Hub] Sound disabled:",result)
    end
else
    warn("[Market Hub] getcustomasset unavailable; sound disabled.")
end
local function playSound()
    if not alive or not soundAsset then return end
    local sound = Instance.new("Sound")
    sound.Name, sound.SoundId, sound.Volume = "MarketHubHitSound", soundAsset, SOUND_VOLUME
    sound.Parent = SoundService
    sounds[sound] = true
    sound.Destroying:Once(function() sounds[sound] = nil end)
    sound.Ended:Once(function() sound:Destroy() end)
    Debris:AddItem(sound,30)
    local ok, err = pcall(function() sound:Play() end)
    if not ok then sound:Destroy(); warn("[Market Hub] Playback error:",err) end
end
connect(view.NotificationShown,playSound)

local function readStock(id)
    -- Preserves your original script's assumption: ShopStock uses display names.
    local value = stockFolder:FindFirstChild(id)
    if value and value:IsA("ValueBase") then return number(value.Value) or 0 end
    return 0
end
local function checkAlert(id, amount)
    local state = states[id]
    if not state.enabled then return end
    if amount > 0 and not state.alerted then
        state.alerted = true
        view:Notify(state.name .. " is available  |  Stock: " .. formatNumber(amount))
    elseif amount <= 0 then
        state.alerted = false
    end
end
connect(view.AlertToggled,function(id)
    local state = states[id]
    if not state then return end
    state.enabled = not state.enabled
    state.alerted = false
    view:SetAlertEnabled(id,state.enabled)
    if state.enabled then checkAlert(id,readStock(id)) end
end)
for _, category in ipairs({
    {name = "Hardware", data = Config.Hardware},
    {name = "Data Sources", data = Config.DataSources},
    {name = "Data Packs", data = Config.Datasets},
}) do
    for index, item in ipairs(sortedItems(category.data)) do
        local id = item.name
        states[id] = states[id] or {name = item.name, enabled = false, alerted = false}
        local priceText = "Cost: N/A"
        if item.price == 0 then priceText = "Cost: Free"
        elseif item.price ~= nil then priceText = "Cost: $" .. formatNumber(item.price) end
        view:AddItem(category.name,{id = id, name = item.name, order = index, priceText = priceText})
    end
end

local lastPrice = number(Workspace:GetAttribute("TokenPrice"))
local function updatePrice(allowSound)
    if not alive then return end
    local price = number(Workspace:GetAttribute("TokenPrice"))
    view:SetTokenPrice(price ~= nil and ("$" .. formatNumber(price)) or "--")
    if allowSound and price == SOUND_PRICE and lastPrice ~= SOUND_PRICE then playSound() end
    lastPrice = price
end
connect(Workspace:GetAttributeChangedSignal("TokenPrice"),function() updatePrice(true) end)
updatePrice(false)

local function update()
    local now = Workspace:GetServerTimeNow()
    view:SetEpochTimer(seconds(EPOCH_SECONDS - math.floor(now) % EPOCH_SECONDS))
    local restock = stockFolder:FindFirstChild("RestockAt")
    local at = restock and restock:IsA("ValueBase") and number(restock.Value)
    view:SetRestockTimer(at and seconds(math.max(0,math.ceil(at-now))) or "--")
    for id, state in pairs(states) do
        local amount = readStock(id)
        if state.lastStock ~= amount then
            state.lastStock = amount
            view:SetStock(id,"Stock: " .. formatNumber(amount),amount > 0)
        end
        checkAlert(id,amount)
    end
end
task.spawn(function()
    while alive do
        local ok, err = pcall(update)
        if not ok then warn("[Market Hub] Update error:",err) end
        task.wait(UPDATE_INTERVAL)
    end
end)
print("[Market Hub] Loaded. Press Right Shift to open or close.")
